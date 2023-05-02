module axi_stream_insert_header #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8,
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD)
) (
    input                       clk             ,
    input                       rst_n           ,
    // AXI Stream input original data
    input                       valid_in        ,
    input [DATA_WD-1 : 0]       data_in         ,
    input [DATA_BYTE_WD-1 : 0]  keep_in         ,
    input                       last_in         ,
    output                      ready_in        ,
    // AXI Stream output with header inserted
    output                      valid_out       ,
    output [DATA_WD-1 : 0]      data_out        ,
    output [DATA_BYTE_WD-1 : 0] keep_out        ,
    output                      last_out        ,
    input                       ready_out       ,
    // The header to be inserted to AXI Stream input
    input                       valid_insert    ,
    input [DATA_WD-1 : 0]       data_insert     ,
    input [DATA_BYTE_WD-1 : 0]  keep_insert     ,
    input [BYTE_CNT_WD : 0]   byte_insert_cnt ,
    output                      ready_insert
    );
    /****************outputregisters**************/
    reg                       r_ready_in        ;
    reg                       r_valid_out       ;
    reg  [DATA_WD-1 : 0]      r_data_out        ;
    reg  [DATA_BYTE_WD-1 : 0] r_keep_out        ;
    reg                       r_last_out        ;
    reg                       r_ready_insert    ;
    assign ready_in        =  r_ready_in        ;
    assign valid_out       =  r_valid_out       ;
    assign data_out        =  r_data_out        ;
    assign keep_out        =  r_keep_out        ;
    assign last_out        =  r_last_out        ;
    assign ready_insert    =  r_ready_insert    ;

    //缓冲器
    localparam BUFFER_D = 2*DATA_BYTE_WD;
    reg [7:0] buffer [0:BUFFER_D-1];
    genvar i;
    /****************握手成功标志***************/
    wire shake_in,shake_insert,shake_out;
    assign shake_in = valid_in && ready_in;
    assign shake_insert = valid_insert && ready_insert;
    assign shake_out = valid_out && ready_out;
    /****************握手信号控制***************/
    //首先将ready_insert拉高接收insert数据,此时ready_in为低电平
    //接收到一个insert数据后ready_insert拉低,ready_in拉高,接收8个数据
    //ready_in
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            r_ready_in <= 1'b0;
        end
        else begin
            if(shake_insert == 1'b1 && ready_out == 1) begin
                r_ready_in <= 1'b1;
            end
            else if(last_in && shake_in)
                r_ready_in <= 1'b0;
        end
    end
    //ready_insert
    reg r1_ready_insert;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            r1_ready_insert <= 1'b1;
        else if(r_ready_insert)
            r1_ready_insert <= 1;
        else if(shake_in)
            r1_ready_insert <= 0;
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            r_ready_insert <= 1'b1;
        end
        else begin
            if(shake_insert == 1'b1) begin
                r_ready_insert <= 1'b0;
            end
            else if(last_out && ready_out == 1)
                r_ready_insert <= 1'b1;
        end
    end

    /***************insert寄存***************/
    reg [DATA_BYTE_WD-1 : 0]r_keep_insert     ;
    reg [BYTE_CNT_WD : 0]   r_byte_insert_cnt ;
    always @(*) begin
        if(shake_insert) begin
            r_keep_insert <= keep_insert;
            r_byte_insert_cnt <= byte_insert_cnt;
        end
    end
    /***************keep_out控制******************/
    reg [BYTE_CNT_WD:0] byte_in_cnt;
    reg [BYTE_CNT_WD+1:0] keep_sum;
    reg [BYTE_CNT_WD:0] remainder;
    wire [DATA_BYTE_WD-1:0] flag_byte_in;
    reg  [DATA_BYTE_WD-1:0] w_keep_out;//立即赋1
    //计算keep_in中1的个数
    assign flag_byte_in = keep_in ^ (keep_in<<1);
    genvar k,l;
    generate
        for(k=1;k<=DATA_BYTE_WD;k=k+1) begin
            always @(*) begin
                if(flag_byte_in[DATA_BYTE_WD-k] == 1)
                    byte_in_cnt = k;
                else
                    byte_in_cnt = byte_in_cnt;
            end
        end
    endgenerate
    always @(*) begin
        if(!rst_n)
            keep_sum = 'd0;
        else begin
            if(last_in)
                keep_sum = byte_in_cnt + r_byte_insert_cnt;
            else
                keep_sum = keep_sum;
        end
    end
    always @(*) begin
        remainder = keep_sum % DATA_BYTE_WD;
    end
    generate
        for(l=0;l<=DATA_BYTE_WD-1;l=l+1) begin
            always @(posedge clk) begin
                if(remainder == 'd0)
                    w_keep_out = {DATA_BYTE_WD{1'b1}};
                else begin
                    if(l<=remainder) begin
                        w_keep_out = {{l{1'b1}},{(DATA_BYTE_WD-l){1'b0}}};
                    end
                    else
                        w_keep_out = w_keep_out;
                end
            end
        end
    endgenerate
    /***************buffer控制****************/
    wire state_insert;
    wire state_in;
    wire state_last;
    wire state_out;
    generate
        for(i=0;i<BUFFER_D;i=i+1) begin
            assign state_insert = shake_insert == 1 && r_valid_out == 0 && last_in == 0 ;
            assign state_in = shake_in == 1;
            assign state_last = last_in == 1;
            assign state_out = ready_out == 1 && shake_in == 1 && r1_ready_insert == 0;
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n)
                    buffer[i] <= 'd0;
                else if(state_insert && i >= 0 && i<r_byte_insert_cnt)
                    buffer[i] <= data_insert[DATA_WD-(DATA_BYTE_WD-r_byte_insert_cnt+i)*8-1-:8];
                else if(state_in && i>=r_byte_insert_cnt && i<(DATA_BYTE_WD+r_byte_insert_cnt))
                    buffer[i] <= data_in[DATA_WD-(i-r_byte_insert_cnt)*8-1-:8];
                else if(state_last&&i>=(DATA_BYTE_WD+r_byte_insert_cnt))
                    buffer[i] <= 'd0;
                else if(state_out ) begin
                    if(i >= r_byte_insert_cnt && i<(DATA_BYTE_WD+r_byte_insert_cnt))
                        buffer[i] <= data_in[DATA_WD-(i-r_byte_insert_cnt)*8-1-:8];
                    else if(i>= 0&&i<DATA_BYTE_WD)
                        buffer[i] <= buffer[i+DATA_BYTE_WD];
                end
                else
                    buffer[i] <= buffer[i];
            end
        end
    endgenerate
    /***************data_out控制*************/
    reg r1_last_in;
    reg r2_last_in;
    wire last_in_neg;
    reg r_last_in_neg;
    assign last_in_neg = last_in == 0 && r1_last_in == 1;
    always@(posedge clk)begin
        r1_last_in <= last_in;
        r2_last_in <= r1_last_in;
        r_last_in_neg <= last_in_neg;
    end

    reg r_valid_in;
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            r_valid_in <= 0;
        else
            r_valid_in <= valid_in;
    end
    //计算buffer前一半的拼接和后一半的拼接
    reg [DATA_WD-1:0] low_buffer_data;
    reg [DATA_WD-1:0] high_buffer_data;
    genvar m;
    generate
        for(m=0;m<DATA_BYTE_WD;m=m+1) begin
            always @(*) begin
                low_buffer_data[((DATA_BYTE_WD-m)*8-1)-:8] <= buffer[m];
                high_buffer_data[((DATA_BYTE_WD-m)*8-1)-:8] <= buffer[m+DATA_BYTE_WD];
            end
        end
    endgenerate
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            r_last_out <= 0;
            r_data_out <= 0;
            r_valid_out <= 0;
            r_keep_out <= {DATA_BYTE_WD{1'b1}};
        end
        else if(r_last_out == 1) begin
            r_last_out <= 0;
            r_valid_out <= 0;
            r_keep_out <= {DATA_BYTE_WD{1'b1}};
        end
        else if(last_in_neg == 1 && (keep_sum <= DATA_BYTE_WD)) begin//少一个data
            r_last_out <= 1;
            r_data_out <= low_buffer_data;
            //r_data_out = {buffer[0],buffer[1],buffer[2],buffer[3]};
            r_keep_out <= w_keep_out;
        end
        else if(r_last_in_neg == 1 && keep_sum > DATA_BYTE_WD) begin//正常
            r_last_out <= 1;
            r_data_out <= high_buffer_data;
            //r_data_out = {buffer[4],buffer[5],buffer[6],buffer[7]};
            r_keep_out <= w_keep_out;
        end
        else if(ready_out == 1 && r1_ready_insert == 0 && r_ready_insert == 0 && r_last_in_neg==0 && r_valid_in)begin
            r_valid_out <= 1;
            r_data_out <= low_buffer_data;
            //r_data_out = {buffer[0],buffer[1],buffer[2],buffer[3]};
        end
        else begin
            r_data_out <= r_data_out;
            r_keep_out <= {DATA_BYTE_WD{1'b1}};
        end
    end

endmodule

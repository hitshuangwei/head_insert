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
    reg [7:0] buffer [0:2*DATA_BYTE_WD-1];
    genvar i;
    reg [2:0] byte_in_cnt;
    reg [3:0] keep_sum;
    reg [2:0] remainder;
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
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            r_data_out <= 32'd0;
            r_valid_out <= 0;
            r_last_out <= 0;
            r_keep_out <= 4'b1111;
        end
        else if(r_last_out == 1) begin
            r_valid_out <= 0;
            r_last_out <= 0;
            r_keep_out <= 4'b1111;
        end
        else if(last_in_neg == 1 && (keep_sum <= 4)) begin//有效位数小于4
            r_data_out = {buffer[0],buffer[1],buffer[2],buffer[3]};
            r_last_out <= 1;
            case(remainder)
                0:r_keep_out <= 4'b1111;
                1:r_keep_out <= 4'b1000;
                2:r_keep_out <= 4'b1100;
                3:r_keep_out <= 4'b1110;
            endcase
        end
        else if(r_last_in_neg == 1 && keep_sum > 4) begin//正常
            r_data_out = {buffer[4],buffer[5],buffer[6],buffer[7]};
            r_last_out <= 1;
            case(remainder)
                0:r_keep_out <= 4'b1111;
                1:r_keep_out <= 4'b1000;
                2:r_keep_out <= 4'b1100;
                3:r_keep_out <= 4'b1110;
            endcase
        end
        else if(ready_out == 1 && r1_ready_insert == 0 && r_ready_insert == 0 && r_last_in_neg==0 && r_valid_in)begin
            r_data_out = {buffer[0],buffer[1],buffer[2],buffer[3]};
            r_valid_out <= 1;
        end
        else begin
            r_keep_out <= 4'b1111;
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

    always @(*) begin
        case(keep_in)
            'b1111:byte_in_cnt = 'd4;
            'b1110:byte_in_cnt = 'd3;
            'b1100:byte_in_cnt = 'd2;
            'b1000:byte_in_cnt = 'd1;
        endcase
    end
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
        remainder = keep_sum % 'd4;
    end
    /***************buffer控制****************/
    wire state_insert;
    wire state_in;
    wire state_last;
    wire state_out;
    generate
        for(i=0;i<8;i=i+1) begin
            assign state_insert = (last_in == 0) && (shake_insert == 1) && (r_valid_out == 0)  ;
            assign state_in = (shake_in == 1);
            assign state_last = (last_in == 1);
            assign state_out = (r1_ready_insert == 0) && (ready_out == 1) && (shake_in == 1) ;
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n)
                    buffer[i] <= 'd0;
                else if(state_insert && (i >= 0) && (i<r_byte_insert_cnt))
                    buffer[i] <= data_insert[(DATA_WD-(DATA_BYTE_WD-r_byte_insert_cnt+i)*8-1)-:8];
                else if(state_in && (i>=r_byte_insert_cnt) && (i<(DATA_BYTE_WD+r_byte_insert_cnt)))
                    buffer[i] <= data_in[(DATA_WD-(i-r_byte_insert_cnt)*8-1)-:8];
                else if(state_out) begin
                    if((i >= r_byte_insert_cnt) && (i<(DATA_BYTE_WD+r_byte_insert_cnt)))
                        buffer[i] <= data_in[(DATA_WD-(i-r_byte_insert_cnt)*8-1)-:8];
                    else if(i>= 0&&i<4)
                        buffer[i] <= buffer[i+4];
                end
                else if(state_last&&(i>=(DATA_BYTE_WD+r_byte_insert_cnt)))
                    buffer[i] <= 'd0;
            end
        end
    endgenerate

    /*wire [8-1:0] buffer_vis0 = buffer[0];
    wire [8-1:0] buffer_vis1 = buffer[1];
    wire [8-1:0] buffer_vis2 = buffer[2];
    wire [8-1:0] buffer_vis3 = buffer[3];
    wire [8-1:0] buffer_vis4 = buffer[4];
    wire [8-1:0] buffer_vis5 = buffer[5];
    wire [8-1:0] buffer_vis6 = buffer[6];
    wire [8-1:0] buffer_vis7 = buffer[7];*/

endmodule

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
    localparam BUFFER_W = 2*DATA_WD;
    localparam DOUBLE_DATA_BYTY_WD = 2*DATA_BYTE_WD;
    genvar i;
    /****************握手成功标志***************/
    wire shake_in,shake_insert,shake_out;
    assign shake_in = valid_in && ready_in;
    assign shake_insert = valid_insert && ready_insert;
    assign shake_out = valid_out && ready_out;

    /****************握手信号控制***************/
    //首先将ready_insert拉高接收insert数据,握手成功:shake_insert=1 -> ready_insert拉低,ready_in拉高
    //last_in为高并且shake_in成功时ready_in拉低
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
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            r_ready_insert <= 1'b1;
        end
        else begin
            if(shake_insert == 1'b1)
                r_ready_insert <= 1'b0;//TODO
            else if(last_out && ready_out == 1)
                r_ready_insert <= 1'b1;
        end
    end

    reg latent;//last_in到last_out潜伏期
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            latent <= 0;
        else if(last_in && shake_in)
            latent <= 1;
        else if(last_out && shake_out)
            latent <= 0;
    end
    /****************第一个输入信号*************/
    reg [1:0] first_data_flag;
    //当flag为1时表示第一个data
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            first_data_flag <= 'd0;
        else begin
            if(shake_insert)
                first_data_flag <= 'd1;
            else if(shake_in && first_data_flag =='d1)
                first_data_flag <= 'd2;
            else if(shake_in && first_data_flag =='d2)
                first_data_flag <= 'd3;
            else if(last_out && shake_out && first_data_flag == 'd3)
                first_data_flag <= 'd0;
        end
    end
    /*****************last_in后**************/
    reg [1:0] last_data_flag;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            last_data_flag <= 'd0;
        else begin
            if(last_in)
                last_data_flag <= 'd0;
            else if(last_data_flag == 'd0)
                last_data_flag <= 'd1;
            else if(last_data_flag == 'd1)
                last_data_flag <= 'd2;
            else if(last_data_flag == 'd2)
                last_data_flag <= 'd3;
        end
    end
    /***************insert寄存***************/
    reg [DATA_BYTE_WD-1 : 0]r_keep_insert     ;
    reg [BYTE_CNT_WD : 0]   r_byte_insert_cnt ;
    always @(posedge clk) begin
        if(shake_insert) begin//TODO
            r_keep_insert <= keep_insert;
            r_byte_insert_cnt <= byte_insert_cnt;
        end
        else begin
            r_keep_insert <= r_keep_insert;
            r_byte_insert_cnt <= r_byte_insert_cnt;
        end
    end
    /***************keep_out控制******************/
    reg [DOUBLE_DATA_BYTY_WD-1:0] double_wide_keep;
    wire last_less_flag;//结尾是否应该少一个数据
    wire [DATA_BYTE_WD-1:0] w_keep_out;
    always @(posedge clk) begin
        if(last_in)
            double_wide_keep <= ({r_keep_insert,keep_in} << (DATA_BYTE_WD - r_byte_insert_cnt));
            //00000111 11000000 -> 0000011111000000 -> 1111100000000000 -> 再移8位看是不是等于0
            //等于0keep_out高8位
    end
    wire [DOUBLE_DATA_BYTY_WD-1:0]test_lastflag = double_wide_keep << DATA_BYTE_WD;
    assign last_less_flag = (test_lastflag == 'd0) ? 1 : 0;//得1少一位
    assign w_keep_out = last_less_flag ? double_wide_keep[(DOUBLE_DATA_BYTY_WD-1)-:DATA_BYTE_WD] : double_wide_keep[0+:DATA_BYTE_WD];
    assign keep_out = last_out ? w_keep_out : {DATA_BYTE_WD{1'b1}};

    //**************data_out**************/
    reg [BUFFER_W-1:0]  data_double_wide_buffer;
    reg [DATA_WD-1:0]   buffer_high;
    reg [DATA_WD-1:0]   buffer_low;
    reg out_period;//out可以跳变的区间
    wire [BYTE_CNT_WD+3:0] left_num;
    wire [BUFFER_W-1:0] shift_buffer;
    assign left_num = (DATA_BYTE_WD - r_byte_insert_cnt) << 3;//左移位数
    assign shift_buffer = data_double_wide_buffer << left_num;
    //out_period
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            out_period <= 'd0;
        end
        else begin
            if(last_out == 'd1)
                out_period <= 'd0;
            else if(first_data_flag == 'd2)
                out_period <= 'd1;
        end
    end
    //拼接
    always @(posedge clk) begin
        data_double_wide_buffer <= {buffer_high,buffer_low};
    end
    //低位和高位赋值
    always @(posedge clk) begin
        if(shake_insert) begin
            buffer_high <= data_insert;
            buffer_low <= buffer_low;
        end
        else begin
            if(shake_insert) begin
                buffer_high <= data_insert;
                buffer_low <= buffer_low;
            end
            else if(shake_in && first_data_flag == 'd1) begin //存第一个数
                buffer_high <= buffer_high;
                buffer_low <= data_in;
            end
            else if(shake_in && (first_data_flag == 'd2 || first_data_flag == 'd3) && shake_out) begin//低位赋给高位,data_in赋给低位
                buffer_high <= buffer_low;
                buffer_low <= data_in;
            end
            else if(last_less_flag == 'd0 && shake_out && latent == 1) begin//不少一位
                buffer_high <= buffer_low;
                buffer_low <= 'd0;
            end
        end
    end
    //输出为左移8*byte_cnt_insert位
    always @(posedge clk) begin
        if(last_out)
            r_data_out <= r_data_out;
        else if(out_period)
            r_data_out <= shift_buffer[(BUFFER_W-1)-:DATA_WD];
    end
    //**************last_out*************/
    reg r1_last_in;
    reg r2_last_in;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            r1_last_in <= 'd0;
            r2_last_in <= 'd0;
        end
        else begin
            if(shake_out) begin
                r1_last_in <= last_in;
                r2_last_in <= r1_last_in;
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            r_last_out <= 'd0;
        else begin
            if(r_last_out && shake_out)//归零
                r_last_out <= 'd0;
            else if(last_data_flag == 'd1 && last_less_flag == 'd1)//少
                r_last_out <= 'd1;
            else if(last_data_flag == 'd2 && last_less_flag == 'd0)//不少
                r_last_out <= 'd1;
        end
    end
    //*************valid_out**************
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            r_valid_out <= 'd0;
        else begin
            if(r_last_out && shake_out)
                r_valid_out <= 'd0;
            else if(out_period == 'd1)
                r_valid_out <= 'd1;
        end
    end
endmodule

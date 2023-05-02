module axis_master_insert  #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8,
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD)
) (
    input                       clk             ,
    input                       rst_n           ,
    output                      ins_valid_m         ,
    output [DATA_WD-1 : 0]      ins_data_m          ,
    output [DATA_BYTE_WD-1 : 0] ins_keep_m          ,
    output [BYTE_CNT_WD:0]    ins_byte_insert_cnt ,
    input                       ins_ready_m
);
    integer seed;
    initial begin
        seed = 2;
    end
    reg [32-1:0] data_low;//random只能产生32位
    reg [32-1:0] data_high;
    always @(posedge clk) begin
        data_low <= $random(seed);
        data_high <= $random(seed);
    end

    reg [DATA_WD-1:0] data_out;
    reg [8-1:0] byte_cnt;
    reg [DATA_BYTE_WD-1:0] curr_keep;
    reg [BYTE_CNT_WD:0] curr_cnt;
    reg r_ins_valid_m;
    wire shake;
    assign shake = ins_valid_m && ins_ready_m;
    assign ins_valid_m = r_ins_valid_m;
    always @(posedge clk) begin
        r_ins_valid_m <= $random(seed);
    end
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            data_out <= 'h0;
            byte_cnt <= 0;
        end
        else if(shake) begin
            data_out <= {data_high,data_low};
        end
    end
    reg [BYTE_CNT_WD:0] byte_cnt_insert;
    reg [BYTE_CNT_WD:0] r_byte_cnt_insert;
    always @(posedge clk) begin
        r_byte_cnt_insert <= byte_cnt_insert;
        if(shake) begin
            byte_cnt_insert <= $urandom_range(DATA_BYTE_WD-1) + 1;//生成1~DATA_BYTE_WD之间的随机数
        end
    end
    genvar l;
    generate
        for(l=1;l<=DATA_BYTE_WD;l=l+1) begin
            always @(posedge clk) begin
                if(byte_cnt_insert == DATA_BYTE_WD)
                    curr_keep <= {DATA_BYTE_WD{1'b1}};
                else begin
                    if(l<=byte_cnt_insert)
                    curr_keep <= {{DATA_BYTE_WD{1'b0}},{l{1'b1}}};
                end
            end
        end
    endgenerate
    assign ins_data_m = data_out;
    assign ins_keep_m = curr_keep;
    assign ins_byte_insert_cnt = r_byte_cnt_insert;
endmodule //axis_master
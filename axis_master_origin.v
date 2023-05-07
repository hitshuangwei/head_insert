module axis_master_origin  #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8,
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD),
    parameter BURST_LENGTH = 8
) (
    input                       clk             ,
    input                       rst_n           ,
    output                      valid_m         ,
    output [DATA_WD-1 : 0]      data_m          ,
    output [DATA_BYTE_WD-1 : 0] keep_m          ,
    output                      last_m          ,
    input                       ready_m
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
    reg [8-1:0] burst_cnt;
    reg [DATA_BYTE_WD-1:0] curr_keep;
    reg r_valid_m;
    always@(posedge clk) begin
        r_valid_m <= $random(seed);
        //r_valid_m <= 1;
    end
    wire shake;
    assign shake = valid_m && ready_m;
    assign valid_m = r_valid_m;
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            data_out <= 0;
            burst_cnt <= 0;
        end
        else if(shake) begin
            data_out <= {data_high,data_low};
            burst_cnt <= (burst_cnt == BURST_LENGTH-1) ? 0 : burst_cnt + 1;
        end
    end
    //生成随机keep,data
    reg [BYTE_CNT_WD:0] byte_cnt_origin;
    reg [BYTE_CNT_WD:0] r_byte_cnt_origin;
    always @(posedge clk) begin
            byte_cnt_origin <= $urandom_range(DATA_BYTE_WD-1) + 1;//生成1~DATA_BYTE_WD之间的随机数
            r_byte_cnt_origin <= byte_cnt_origin;
    end
    genvar l;
    generate
        for(l=0;l<=DATA_BYTE_WD-1;l=l+1) begin
            always @(posedge clk) begin
                if(shake) begin
                if(byte_cnt_origin == DATA_BYTE_WD)
                    curr_keep <= {DATA_BYTE_WD{1'b1}};
                else begin
                    if(l<=byte_cnt_origin) begin
                        curr_keep <= {{l{1'b1}},{(DATA_BYTE_WD-l){1'b0}}};
                    end
                end
                end
            end
        end
    endgenerate
    assign data_m = data_out;
    assign keep_m = (burst_cnt == BURST_LENGTH-1) ? curr_keep : {DATA_BYTE_WD{1'b1}};
    assign last_m = (burst_cnt == BURST_LENGTH-1) ? 1'b1 : 1'b0;

endmodule //axis_master
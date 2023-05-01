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
reg [DATA_WD-1:0] data_out;
reg [8-1:0] byte_cnt;
reg [DATA_BYTE_WD-1:0] curr_keep;
reg [BYTE_CNT_WD:0] curr_cnt;
reg r_ins_valid_m;
wire shake;
assign shake = ins_valid_m && ins_ready_m;
assign ins_valid_m = r_ins_valid_m;
always @(posedge clk) begin
    r_ins_valid_m <= $random;
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        data_out <= 'hffffffff;
        byte_cnt <= 0;
    end
    else if(shake) begin
        data_out <= $random;
    end
end
reg [1:0] rand;
always @(posedge clk) begin
    if(shake) begin
    rand <= $random;
    case(rand)
    2'b00:begin
        curr_keep <= 4'b1111;
        curr_cnt <= 'd4;
    end
    2'b01:begin
        curr_keep <= 4'b0111;
        curr_cnt <= 'd3;
    end
    2'b10:begin
        curr_keep <= 4'b0011;
        curr_cnt <= 'd2;

    end
    2'b11:begin
        curr_keep <= 4'b0001;
        curr_cnt <= 'd1;
    end
    endcase
    end
end
assign ins_data_m = data_out;
assign ins_keep_m = curr_keep;
assign ins_byte_insert_cnt = curr_cnt;
endmodule //axis_master
module axis_master_origin  #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8,
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD),
    parameter BURST_LENGTH = 16
) (
    input                       clk             ,
    input                       rst_n           ,
    output                      valid_m         ,
    output [DATA_WD-1 : 0]      data_m          ,
    output [DATA_BYTE_WD-1 : 0] keep_m          ,
    output                      last_m          ,
    input                       ready_m
);
reg [DATA_WD-1:0] data_out;
reg [8-1:0] byte_cnt;
reg [DATA_BYTE_WD-1:0] curr_keep;
reg r_valid_m;
always@(posedge clk) begin
    r_valid_m <= $random;
end
wire shake;
assign shake = valid_m && ready_m;
//assign valid_m = (byte_cnt == 0) ? 1'b1 : 1'b0;
assign valid_m = r_valid_m;
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        data_out <= 0;
        byte_cnt <= 0;
    end
    else if(shake) begin
        data_out <= $random;
        byte_cnt <= (byte_cnt == BURST_LENGTH-1) ? 0 : byte_cnt + 1;
    end
end
//生成随机keep
reg [1:0] rand;
always @(posedge clk) begin
    if(shake) begin
    rand <= $random;
    case(rand)
    2'b00:begin
        curr_keep <= 4'b1111;
    end
    2'b01:begin
        curr_keep <= 4'b1110;
    end
    2'b10:begin
        curr_keep <= 4'b1100;
    end
    2'b11:begin
        curr_keep <= 4'b1000;
    end
    endcase
    end
end

assign data_m = data_out;
assign keep_m = (byte_cnt == BURST_LENGTH-1) ? curr_keep : 4'b1111;
assign last_m = (byte_cnt == BURST_LENGTH-1) ? 1'b1 : 1'b0;

endmodule //axis_master
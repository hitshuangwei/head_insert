module axi_stream_insert_header_tb ();

    localparam  DATA_WD = 32;
    localparam  DATA_BYTE_WD = DATA_WD / 8;
    localparam  BYTE_CNT_WD = $clog2(DATA_BYTE_WD);

    reg                       clk             ;
    reg                       rst_n           ;

    wire                      valid_in        ;
    wire [DATA_WD-1 : 0]      data_in         ;
    wire [DATA_BYTE_WD-1 : 0] keep_in         ;
    wire                      last_in         ;
    wire                      ready_in        ;

    wire                      valid_out       ;
    wire [DATA_WD-1 : 0]      data_out        ;
    wire [DATA_BYTE_WD-1 : 0] keep_out        ;
    wire                      last_out        ;
    reg                       ready_out       ;

    wire                      valid_insert    ;
    wire [DATA_WD-1 : 0]      data_insert     ;
    wire [DATA_BYTE_WD-1 : 0] keep_insert     ;
    wire [BYTE_CNT_WD : 0]  byte_insert_cnt ;
    wire                      ready_insert    ;

    axi_stream_insert_header axi_stream_insert_header_u(
        .clk            (clk            ),
        .rst_n          (rst_n          ),
        .valid_in       (valid_in       ),
        .data_in        (data_in        ),
        .keep_in        (keep_in        ),
        .last_in        (last_in        ),
        .ready_in       (ready_in       ),
        .valid_out      (valid_out      ),
        .data_out       (data_out       ),
        .keep_out       (keep_out       ),
        .last_out       (last_out       ),
        .ready_out      (ready_out      ),
        .valid_insert   (valid_insert   ),
        .data_insert    (data_insert    ),
        .keep_insert    (keep_insert    ),
        .byte_insert_cnt(byte_insert_cnt),
        .ready_insert   (ready_insert   )
    );
    //发生origin信号
    axis_master_origin axis_master_origin_u(
        .clk    (clk        ),
        .rst_n  (rst_n      ),
        .valid_m(valid_in   ),
        .data_m (data_in    ),
        .keep_m (keep_in    ),
        .last_m (last_in    ),
        .ready_m(ready_in   )
    );
    //发生insert信号
    axis_master_insert axis_master_insert_u(
        .clk    (clk            ),
        .rst_n  (rst_n          ),
        .ins_valid_m(valid_insert   ),
        .ins_data_m (data_insert    ),
        .ins_keep_m (keep_insert    ),
        .ins_byte_insert_cnt(byte_insert_cnt),
        .ins_ready_m(ready_insert   )
    );

    always #5 clk = !clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        #100
        rst_n = 1'b1;
    end
    always @(posedge clk) begin
        ready_out <= 1;
    end
endmodule
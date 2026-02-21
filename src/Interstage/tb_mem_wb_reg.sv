`timescale 1ns/1ps

module tb_mem_wb_reg;

    localparam int XLEN = 32;

    logic clk, rst;
    logic flush_i, stall_i;

    logic        ex_mem_valid_i;
    logic [4:0]  ex_mem_rd_i;
    logic        ex_mem_regwrite_i;
    logic        ex_mem_write_data_i;
    logic [31:0] ex_mem_alu_out_i;

    logic        mem_load_valid_i;
    logic [31:0] mem_load_data_i;

    logic        mem_wb_valid_o;
    logic [4:0]  mem_wb_rd_o;
    logic        mem_wb_regwrite_o;
    logic        mem_wb_write_data_o;
    logic [31:0] mem_wb_alu_out_o;
    logic        mem_wb_load_valid_o;
    logic [31:0] mem_wb_load_data_o;

    // DUT
    mem_wb_reg #(.XLEN(XLEN)) dut (
        .clk(clk),
        .rst(rst),
        .flush_i(flush_i),
        .stall_i(stall_i),

        .ex_mem_valid_i(ex_mem_valid_i),
        .ex_mem_rd_i(ex_mem_rd_i),
        .ex_mem_regwrite_i(ex_mem_regwrite_i),
        .ex_mem_write_data_i(ex_mem_write_data_i),
        .ex_mem_alu_out_i(ex_mem_alu_out_i),

        .mem_load_valid_i(mem_load_valid_i),
        .mem_load_data_i(mem_load_data_i),

        .mem_wb_valid_o(mem_wb_valid_o),
        .mem_wb_rd_o(mem_wb_rd_o),
        .mem_wb_regwrite_o(mem_wb_regwrite_o),
        .mem_wb_write_data_o(mem_wb_write_data_o),
        .mem_wb_alu_out_o(mem_wb_alu_out_o),
        .mem_wb_load_valid_o(mem_wb_load_valid_o),
        .mem_wb_load_data_o(mem_wb_load_data_o)
    );

    // clock
    initial clk = 0;
    always #5 clk = ~clk; // 10 ns period

    // expected regs (scoreboard)
    logic        exp_valid;
    logic [4:0]  exp_rd;
    logic        exp_regwrite;
    logic        exp_write_data;
    logic [31:0] exp_alu_out;
    logic        exp_load_valid;
    logic [31:0] exp_load_data;

    bit check_en;

    // Update expected on posedge (same as DUT)
    always_ff @(posedge clk) begin
        if (rst || flush_i) begin
            exp_valid      <= 1'b0;
            exp_rd         <= 5'd0;
            exp_regwrite   <= 1'b0;
            exp_write_data <= 1'b0;
            exp_alu_out    <= 32'd0;
            exp_load_valid <= 1'b0;
            exp_load_data  <= 32'd0;
            check_en       <= 1'b0;
        end else begin
            check_en <= 1'b1;
            if (!stall_i) begin
                exp_valid      <= ex_mem_valid_i;
                exp_rd         <= ex_mem_rd_i;
                exp_regwrite   <= ex_mem_regwrite_i;
                exp_write_data <= ex_mem_write_data_i;
                exp_alu_out    <= ex_mem_alu_out_i;
                exp_load_valid <= mem_load_valid_i;
                exp_load_data  <= mem_load_data_i;
            end
            // else stall: hold expected
        end
    end

    // Check on negedge (avoid same-edge scheduling issues)
    always @(negedge clk) begin
        if (check_en) begin
            if (mem_wb_valid_o      !== exp_valid)      $fatal(1, "valid mismatch: got=%b exp=%b", mem_wb_valid_o, exp_valid);
            if (mem_wb_rd_o         !== exp_rd)         $fatal(1, "rd mismatch: got=%0d exp=%0d", mem_wb_rd_o, exp_rd);
            if (mem_wb_regwrite_o   !== exp_regwrite)   $fatal(1, "regwrite mismatch: got=%b exp=%b", mem_wb_regwrite_o, exp_regwrite);
            if (mem_wb_write_data_o !== exp_write_data) $fatal(1, "write_data mismatch: got=%b exp=%b", mem_wb_write_data_o, exp_write_data);
            if (mem_wb_alu_out_o    !== exp_alu_out)    $fatal(1, "alu_out mismatch: got=%h exp=%h", mem_wb_alu_out_o, exp_alu_out);
            if (mem_wb_load_valid_o !== exp_load_valid) $fatal(1, "load_valid mismatch: got=%b exp=%b", mem_wb_load_valid_o, exp_load_valid);
            if (mem_wb_load_data_o  !== exp_load_data)  $fatal(1, "load_data mismatch: got=%h exp=%h", mem_wb_load_data_o, exp_load_data);
        end
    end

    task automatic drive(
        input logic        v,
        input logic [4:0]  rd,
        input logic        regw,
        input logic        sel_mem,
        input logic [31:0] alu,
        input logic        ldv,
        input logic [31:0] ld,
        input logic        st,
        input logic        fl
    );
    begin
        ex_mem_valid_i       = v;
        ex_mem_rd_i          = rd;
        ex_mem_regwrite_i    = regw;
        ex_mem_write_data_i  = sel_mem;
        ex_mem_alu_out_i     = alu;
        mem_load_valid_i     = ldv;
        mem_load_data_i      = ld;
        stall_i              = st;
        flush_i              = fl;
    end
    endtask

    initial begin
        // init
        rst = 1;
        stall_i = 0;
        flush_i = 0;
        drive(0, 0, 0, 0, 32'd0, 0, 32'd0, 0, 0);

        // release reset on negedge (clean)
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;

        // normal latch
        @(negedge clk); drive(1, 5'd10, 1, 0, 32'hAAAA_0001, 0, 32'h1111_2222, 0, 0);
        @(posedge clk);

        @(negedge clk); drive(1, 5'd11, 1, 1, 32'hBBBB_0002, 1, 32'h3333_4444, 0, 0);
        @(posedge clk);

        // stall holds
        @(negedge clk); drive(1, 5'd12, 1, 1, 32'hCCCC_0003, 1, 32'h5555_6666, 1, 0);
        @(posedge clk);

        // release stall
        @(negedge clk); drive(1, 5'd13, 0, 0, 32'hDDDD_0004, 0, 32'h7777_8888, 0, 0);
        @(posedge clk);

        // flush clears
        @(negedge clk); drive(1, 5'd14, 1, 1, 32'hEEEE_0005, 1, 32'h9999_AAAA, 0, 1);
        @(posedge clk);

        $display("TB PASSED.");
        $finish;
    end

endmodule

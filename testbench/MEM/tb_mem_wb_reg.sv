`timescale 1ns/1ps

module tb_mem_wb_reg;

  logic clk, rst;
  localparam time T = 10ns;
  initial clk = 1'b0;
  always #(T/2) clk = ~clk;

  // Inputs
  logic        flush_i, stall_i;

  logic        ex_mem_valid_i;
  logic [4:0]  ex_mem_rd_i;
  logic        ex_mem_regwrite_i;
  logic        ex_mem_write_data_i;
  logic [31:0] ex_mem_alu_out_i;

  logic        mem_load_valid_i;
  logic [31:0] mem_load_data_i;

  // Outputs
  logic        mem_wb_valid_o;
  logic [4:0]  mem_wb_rd_o;
  logic        mem_wb_regwrite_o;
  logic        mem_wb_write_data_o;
  logic [31:0] mem_wb_alu_out_o;
  logic        mem_wb_load_valid_o;
  logic [31:0] mem_wb_load_data_o;

  mem_wb_reg dut (
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

  task automatic tb_check(input logic cond, input string msg);
    if (!cond) begin
      $error("FAIL: %s @ t=%0t", msg, $time);
      $fatal(1);
    end
  endtask

  task automatic drive_defaults();
    flush_i = 1'b0;
    stall_i = 1'b0;

    ex_mem_valid_i      = 1'b0;
    ex_mem_rd_i         = 5'd0;
    ex_mem_regwrite_i   = 1'b0;
    ex_mem_write_data_i = 1'b0;
    ex_mem_alu_out_i    = 32'd0;

    mem_load_valid_i    = 1'b0;
    mem_load_data_i     = 32'd0;
  endtask

  task automatic do_reset();
    rst = 1'b1;
    drive_defaults();
    repeat (2) @(posedge clk);
    rst = 1'b0;
    @(posedge clk);
    #1;
  endtask

  initial begin
    $display("Starting tb_mem_wb_reg...");

    drive_defaults();
    do_reset();

    // After reset -> outputs should be cleared
    tb_check(mem_wb_valid_o == 1'b0, "reset: mem_wb_valid_o should be 0");
    tb_check(mem_wb_regwrite_o == 1'b0, "reset: mem_wb_regwrite_o should be 0");

    // Normal capture
    @(negedge clk);
    ex_mem_valid_i      = 1'b1;
    ex_mem_rd_i         = 5'd10;
    ex_mem_regwrite_i   = 1'b1;
    ex_mem_write_data_i = 1'b1;
    ex_mem_alu_out_i    = 32'hAAAA_0000;

    mem_load_valid_i    = 1'b1;
    mem_load_data_i     = 32'h1234_5678;

    @(posedge clk); #1;
    tb_check(mem_wb_valid_o == 1'b1, "capture: mem_wb_valid_o mismatch");
    tb_check(mem_wb_rd_o == 5'd10, "capture: rd mismatch");
    tb_check(mem_wb_regwrite_o == 1'b1, "capture: regwrite mismatch");
    tb_check(mem_wb_write_data_o == 1'b1, "capture: write_data mismatch");
    tb_check(mem_wb_alu_out_o == 32'hAAAA_0000, "capture: alu_out mismatch");
    tb_check(mem_wb_load_valid_o == 1'b1, "capture: load_valid mismatch");
    tb_check(mem_wb_load_data_o == 32'h1234_5678, "capture: load_data mismatch");

    // Stall holds outputs (do not update)
    @(negedge clk);
    stall_i            = 1'b1;
    ex_mem_rd_i         = 5'd11;
    ex_mem_alu_out_i    = 32'hBBBB_0000;
    mem_load_data_i     = 32'hDEAD_BEEF;

    @(posedge clk); #1;
    tb_check(mem_wb_rd_o == 5'd10, "stall: rd should hold");
    tb_check(mem_wb_alu_out_o == 32'hAAAA_0000, "stall: alu_out should hold");
    tb_check(mem_wb_load_data_o == 32'h1234_5678, "stall: load_data should hold");

    // Release stall, update should occur
    @(negedge clk);
    stall_i            = 1'b0;
    ex_mem_valid_i      = 1'b1;
    ex_mem_rd_i         = 5'd12;
    ex_mem_regwrite_i   = 1'b1;
    ex_mem_write_data_i = 1'b0;
    ex_mem_alu_out_i    = 32'hCCCC_0000;
    mem_load_valid_i    = 1'b0;
    mem_load_data_i     = 32'h0000_0000;

    @(posedge clk); #1;
    tb_check(mem_wb_rd_o == 5'd12, "unstall: rd mismatch");
    tb_check(mem_wb_write_data_o == 1'b0, "unstall: write_data mismatch");
    tb_check(mem_wb_alu_out_o == 32'hCCCC_0000, "unstall: alu_out mismatch");
    tb_check(mem_wb_load_valid_o == 1'b0, "unstall: load_valid mismatch");

    // Flush clears outputs
    @(negedge clk);
    flush_i = 1'b1;

    @(posedge clk); #1;
    tb_check(mem_wb_valid_o == 1'b0, "flush: mem_wb_valid_o should clear");
    tb_check(mem_wb_regwrite_o == 1'b0, "flush: regwrite should clear");
    tb_check(mem_wb_rd_o == 5'd0, "flush: rd should clear");

    $display("All mem_wb_reg tests PASSED.");
    $finish;
  end

endmodule

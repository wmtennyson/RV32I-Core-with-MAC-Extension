`timescale 1ns / 1ps

module tb_EX_MEM_reg;

  // -------------------------
  // DUT Inputs
  // -------------------------
  logic        clk, rst;
  logic        flush, stall;
  logic        ex_valid;

  logic [31:0] ex_alu_out, ex_store_data, ex_pc4;
  logic [4:0]  ex_rd;

  logic        ex_mem_read, ex_mem_write;
  logic [2:0]  ex_funct3;

  logic        ex_regwrite, ex_write_data;

  // -------------------------
  // DUT Outputs
  // -------------------------
  logic        ex_mem_valid;

  logic [31:0] ex_mem_alu_out, ex_mem_store_data, ex_mem_pc4;
  logic [4:0]  ex_mem_rd;

  logic        ex_mem_mem_read, ex_mem_mem_write;
  logic [2:0]  ex_mem_funct3;

  logic        ex_mem_regwrite, ex_mem_write_data;

  // -------------------------
  // Instantiate DUT
  // -------------------------
  EX_MEM_reg dut (
    .clk(clk),
    .rst(rst),
    .flush(flush),
    .stall(stall),
    .ex_valid(ex_valid),

    .ex_alu_out(ex_alu_out),
    .ex_store_data(ex_store_data),
    .ex_pc4(ex_pc4),
    .ex_rd(ex_rd),

    .ex_mem_read(ex_mem_read),
    .ex_mem_write(ex_mem_write),
    .ex_funct3(ex_funct3),

    .ex_regwrite(ex_regwrite),
    .ex_write_data(ex_write_data),

    .ex_mem_valid(ex_mem_valid),

    .ex_mem_alu_out(ex_mem_alu_out),
    .ex_mem_store_data(ex_mem_store_data),
    .ex_mem_pc4(ex_mem_pc4),
    .ex_mem_rd(ex_mem_rd),

    .ex_mem_mem_read(ex_mem_mem_read),
    .ex_mem_mem_write(ex_mem_mem_write),
    .ex_mem_funct3(ex_mem_funct3),

    .ex_mem_regwrite(ex_mem_regwrite),
    .ex_mem_write_data(ex_mem_write_data)
  );

  // -------------------------
  // Clock generation: 10ns period
  // -------------------------
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // -------------------------
  // Simple PASS/FAIL helpers
  // -------------------------
  int fail_count = 0;

  task automatic expect_bit(input string name, input logic got, input logic exp);
    if (got !== exp) begin
      $display("FAIL: %s got=%0b exp=%0b @ t=%0t", name, got, exp, $time);
      fail_count++;
    end else begin
      $display("PASS: %s = %0b @ t=%0t", name, got, $time);
    end
  endtask

  task automatic expect_vec32(input string name, input logic [31:0] got, input logic [31:0] exp);
    if (got !== exp) begin
      $display("FAIL: %s got=0x%08h exp=0x%08h @ t=%0t", name, got, exp, $time);
      fail_count++;
    end else begin
      $display("PASS: %s = 0x%08h @ t=%0t", name, got, $time);
    end
  endtask

  task automatic expect_vec5(input string name, input logic [4:0] got, input logic [4:0] exp);
    if (got !== exp) begin
      $display("FAIL: %s got=0x%0h exp=0x%0h @ t=%0t", name, got, exp, $time);
      fail_count++;
    end else begin
      $display("PASS: %s = 0x%0h @ t=%0t", name, got, $time);
    end
  endtask

  task automatic expect_vec3(input string name, input logic [2:0] got, input logic [2:0] exp);
    if (got !== exp) begin
      $display("FAIL: %s got=0x%0h exp=0x%0h @ t=%0t", name, got, exp, $time);
      fail_count++;
    end else begin
      $display("PASS: %s = 0x%0h @ t=%0t", name, got, exp, $time);
    end
  endtask

  // Wait for a posedge and then a tiny delay for NBAs to settle
  task automatic step();
    @(posedge clk);
    #1;
  endtask

  // -------------------------
  // Stimulus
  // -------------------------
  initial begin
    // Default inputs
    rst          = 1'b1;
    flush        = 1'b0;
    stall        = 1'b0;
    ex_valid     = 1'b0;

    ex_alu_out   = 32'h0;
    ex_store_data= 32'h0;
    ex_pc4       = 32'h0;
    ex_rd        = 5'd0;

    ex_mem_read  = 1'b0;
    ex_mem_write = 1'b0;
    ex_funct3    = 3'd0;

    ex_regwrite  = 1'b0;
    ex_write_data= 1'b0;

    // -------------------------
    // TEST 1: Reset clears outputs
    // -------------------------
    step(); // apply reset on first edge

    expect_bit ("reset ex_mem_valid",      ex_mem_valid,      1'b0);
    expect_vec32("reset ex_mem_alu_out",   ex_mem_alu_out,    32'd0);
    expect_vec32("reset ex_mem_store_data",ex_mem_store_data, 32'd0);
    expect_vec32("reset ex_mem_pc4",       ex_mem_pc4,        32'd0);
    expect_vec5 ("reset ex_mem_rd",        ex_mem_rd,         5'd0);
    expect_bit ("reset ex_mem_mem_read",   ex_mem_mem_read,   1'b0);
    expect_bit ("reset ex_mem_mem_write",  ex_mem_mem_write,  1'b0);
    expect_vec3 ("reset ex_mem_funct3",    ex_mem_funct3,     3'd0);
    expect_bit ("reset ex_mem_regwrite",   ex_mem_regwrite,   1'b0);
    expect_bit ("reset ex_mem_write_data", ex_mem_write_data, 1'b0);

    // deassert reset
    rst = 1'b0;

    // -------------------------
    // TEST 2: Normal latch when ex_valid=1 (control gated by valid)
    // -------------------------
    ex_valid      = 1'b1;
    ex_alu_out    = 32'hA0A0_0001;
    ex_store_data = 32'hB0B0_0002;
    ex_pc4        = 32'h0000_0104;
    ex_rd         = 5'd10;

    ex_mem_read   = 1'b1;
    ex_mem_write  = 1'b0;
    ex_funct3     = 3'b010;

    ex_regwrite   = 1'b1;
    ex_write_data = 1'b0;

    step();

    expect_bit ("latch ex_mem_valid",      ex_mem_valid,      1'b1);
    expect_vec32("latch ex_mem_alu_out",   ex_mem_alu_out,    32'hA0A0_0001);
    expect_vec32("latch ex_mem_store_data",ex_mem_store_data, 32'hB0B0_0002);
    expect_vec32("latch ex_mem_pc4",       ex_mem_pc4,        32'h0000_0104);
    expect_vec5 ("latch ex_mem_rd",        ex_mem_rd,         5'd10);

    // gated controls should pass through because ex_valid=1
    expect_bit ("latch ex_mem_mem_read",   ex_mem_mem_read,   1'b1);
    expect_bit ("latch ex_mem_mem_write",  ex_mem_mem_write,  1'b0);
    expect_vec3 ("latch ex_mem_funct3",    ex_mem_funct3,     3'b010);
    expect_bit ("latch ex_mem_regwrite",   ex_mem_regwrite,   1'b1);
    expect_bit ("latch ex_mem_write_data", ex_mem_write_data, 1'b0);

    // -------------------------
    // TEST 3: ex_valid=0 should zero side-effect controls and funct3, but still latch data
    // (Your RTL sets valid low and gates controls; data latches regardless.)
    // -------------------------
    ex_valid      = 1'b0;
    ex_alu_out    = 32'h1111_1111;
    ex_store_data = 32'h2222_2222;
    ex_pc4        = 32'h0000_0208;
    ex_rd         = 5'd3;

    ex_mem_read   = 1'b1;   // would be dangerous if not gated
    ex_mem_write  = 1'b1;
    ex_funct3     = 3'b001;

    ex_regwrite   = 1'b1;
    ex_write_data = 1'b1;

    step();

    expect_bit ("invalid ex_mem_valid",      ex_mem_valid,      1'b0);

    // Data latches (by your current design)
    expect_vec32("invalid data ex_mem_alu_out",    ex_mem_alu_out,    32'h1111_1111);
    expect_vec32("invalid data ex_mem_store_data", ex_mem_store_data, 32'h2222_2222);
    expect_vec32("invalid data ex_mem_pc4",        ex_mem_pc4,        32'h0000_0208);
    expect_vec5 ("invalid data ex_mem_rd",         ex_mem_rd,         5'd3);

    // Controls MUST be gated low
    expect_bit ("invalid ex_mem_mem_read",   ex_mem_mem_read,   1'b0);
    expect_bit ("invalid ex_mem_mem_write",  ex_mem_mem_write,  1'b0);
    expect_vec3 ("invalid ex_mem_funct3",    ex_mem_funct3,     3'd0);
    expect_bit ("invalid ex_mem_regwrite",   ex_mem_regwrite,   1'b0);
    expect_bit ("invalid ex_mem_write_data", ex_mem_write_data, 1'b0);

    // -------------------------
    // TEST 4: Stall holds previous outputs
    // -------------------------
    // First load a known state
    ex_valid      = 1'b1;
    ex_alu_out    = 32'hDEAD_BEEF;
    ex_store_data = 32'hCAFE_BABE;
    ex_pc4        = 32'h0000_030C;
    ex_rd         = 5'd31;

    ex_mem_read   = 1'b0;
    ex_mem_write  = 1'b1;
    ex_funct3     = 3'b010;

    ex_regwrite   = 1'b0;
    ex_write_data = 1'b0;

    stall         = 1'b0;
    step();

    // Now assert stall and change inputs; outputs should NOT change
    stall         = 1'b1;

    ex_valid      = 1'b1;
    ex_alu_out    = 32'h0000_0000;
    ex_store_data = 32'h0000_0000;
    ex_pc4        = 32'h0000_0000;
    ex_rd         = 5'd0;

    ex_mem_read   = 1'b1;
    ex_mem_write  = 1'b0;
    ex_funct3     = 3'b000;

    ex_regwrite   = 1'b1;
    ex_write_data = 1'b1;

    step();

    expect_bit ("stall holds ex_mem_valid",      ex_mem_valid,      1'b1);
    expect_vec32("stall holds ex_mem_alu_out",   ex_mem_alu_out,    32'hDEAD_BEEF);
    expect_vec32("stall holds ex_mem_store_data",ex_mem_store_data, 32'hCAFE_BABE);
    expect_vec32("stall holds ex_mem_pc4",       ex_mem_pc4,        32'h0000_030C);
    expect_vec5 ("stall holds ex_mem_rd",        ex_mem_rd,         5'd31);

    expect_bit ("stall holds ex_mem_mem_read",   ex_mem_mem_read,   1'b0);
    expect_bit ("stall holds ex_mem_mem_write",  ex_mem_mem_write,  1'b1);
    expect_vec3 ("stall holds ex_mem_funct3",    ex_mem_funct3,     3'b010);
    expect_bit ("stall holds ex_mem_regwrite",   ex_mem_regwrite,   1'b0);
    expect_bit ("stall holds ex_mem_write_data", ex_mem_write_data, 1'b0);

    // Deassert stall
    stall = 1'b0;

    // -------------------------
    // TEST 5: Flush clears outputs (bubble)
    // -------------------------
    // Load something non-zero first
    ex_valid      = 1'b1;
    ex_alu_out    = 32'h1234_5678;
    ex_store_data = 32'h8765_4321;
    ex_pc4        = 32'h0000_0410;
    ex_rd         = 5'd7;

    ex_mem_read   = 1'b1;
    ex_mem_write  = 1'b0;
    ex_funct3     = 3'b010;

    ex_regwrite   = 1'b1;
    ex_write_data = 1'b1;

    step();

    // Assert flush and verify cleared on next edge
    flush = 1'b1;
    step();
    flush = 1'b0;

    expect_bit ("flush ex_mem_valid",      ex_mem_valid,      1'b0);
    expect_vec32("flush ex_mem_alu_out",   ex_mem_alu_out,    32'd0);
    expect_vec32("flush ex_mem_store_data",ex_mem_store_data, 32'd0);
    expect_vec32("flush ex_mem_pc4",       ex_mem_pc4,        32'd0);
    expect_vec5 ("flush ex_mem_rd",        ex_mem_rd,         5'd0);
    expect_bit ("flush ex_mem_mem_read",   ex_mem_mem_read,   1'b0);
    expect_bit ("flush ex_mem_mem_write",  ex_mem_mem_write,  1'b0);
    expect_vec3 ("flush ex_mem_funct3",    ex_mem_funct3,     3'd0);
    expect_bit ("flush ex_mem_regwrite",   ex_mem_regwrite,   1'b0);
    expect_bit ("flush ex_mem_write_data", ex_mem_write_data, 1'b0);

    // -------------------------
    // Final result
    // -------------------------
    if (fail_count == 0) begin
      $display("ALL TESTS PASSED");
    end else begin
      $display("TESTS FAILED count=%0d", fail_count);
    end

    $finish;
  end

endmodule
`timescale 1ns/1ps

module tb_mem_unit;

  // Clock / reset
  logic clk, rst;
  localparam time T = 10ns;
  initial clk = 1'b0;
  always #(T/2) clk = ~clk;

  // DUT inputs
  logic        ex_mem_valid_i;
  logic [31:0] ex_mem_addr_i;
  logic [31:0] ex_mem_store_data_i;
  logic [2:0]  ex_mem_funct3_i;
  logic        ex_mem_mem_read_i;
  logic        ex_mem_mem_write_i;

  // BRAM interface
  logic [31:0] dmem_addr_o;
  logic        dmem_en_o;
  logic [3:0]  dmem_we_o;
  logic [31:0] dmem_wdata_o;
  logic [31:0] dmem_rdata_i;

  // DUT outputs
  logic        load_valid_o;
  logic [31:0] load_data_o;

  // Instantiate DUT
  mem_unit dut (
    .clk(clk),
    .rst(rst),

    .ex_mem_valid_i(ex_mem_valid_i),
    .ex_mem_addr_i(ex_mem_addr_i),
    .ex_mem_store_data_i(ex_mem_store_data_i),
    .ex_mem_funct3_i(ex_mem_funct3_i),
    .ex_mem_mem_read_i(ex_mem_mem_read_i),
    .ex_mem_mem_write_i(ex_mem_mem_write_i),

    .dmem_addr_o(dmem_addr_o),
    .dmem_en_o(dmem_en_o),
    .dmem_we_o(dmem_we_o),
    .dmem_wdata_o(dmem_wdata_o),
    .dmem_rdata_i(dmem_rdata_i),

    .load_valid_o(load_valid_o),
    .load_data_o(load_data_o)
  );

  localparam int DEPTH_WORDS = 256;
  logic [31:0] mem [0:DEPTH_WORDS-1];
  logic [31:0] rdata_q;

  assign dmem_rdata_i = rdata_q;

  function automatic int unsigned widx(input logic [31:0] byte_addr);
    return byte_addr[31:2];
  endfunction

  // apply byte enables to a word
  function automatic logic [31:0] apply_byte_we(
    input logic [31:0] oldw,
    input logic [31:0] wdata,
    input logic [3:0]  we
  );
    logic [31:0] nw;
    begin
      nw = oldw;
      if (we[0]) nw[7:0]   = wdata[7:0];
      if (we[1]) nw[15:8]  = wdata[15:8];
      if (we[2]) nw[23:16] = wdata[23:16];
      if (we[3]) nw[31:24] = wdata[31:24];
      return nw;
    end
  endfunction

  always_ff @(posedge clk) begin
    if (rst) begin
      rdata_q <= 32'd0;
    end else begin
      if (dmem_en_o) begin
        // write first (typical BRAM write-first/ read-first varies; not critical for our tests)
        if (dmem_we_o != 4'b0000) begin
          mem[widx(dmem_addr_o)] <= apply_byte_we(mem[widx(dmem_addr_o)], dmem_wdata_o, dmem_we_o);
        end
        // sync read only when no write
        if (dmem_we_o == 4'b0000) begin
          rdata_q <= mem[widx(dmem_addr_o)];
        end
      end
    end
  end

  task automatic tb_check(input logic cond, input string msg);
    if (!cond) begin
      $error("FAIL: %s @ t=%0t", msg, $time);
      $fatal(1);
    end
  endtask

  task automatic drive_defaults();
    ex_mem_valid_i      = 1'b0;
    ex_mem_addr_i       = 32'd0;
    ex_mem_store_data_i = 32'd0;
    ex_mem_funct3_i     = 3'b010;
    ex_mem_mem_read_i   = 1'b0;
    ex_mem_mem_write_i  = 1'b0;
  endtask

  task automatic do_reset();
    rst = 1'b1;
    drive_defaults();
    repeat (2) @(posedge clk);
    rst = 1'b0;
    @(posedge clk);
    #1;
  endtask

  // Store funct3: SB=000, SH=001, SW=010
  task automatic do_store(
    input logic [2:0]  funct3,
    input logic [31:0] addr,
    input logic [31:0] store_data,
    input logic [3:0]  exp_we,
    input logic [31:0] exp_wdata,
    input logic [31:0] exp_word_after
  );
    int unsigned idx;
    begin
      idx = widx(addr);

      // drive on negedge so comb signals settle before posedge
      @(negedge clk);
      ex_mem_valid_i      = 1'b1;
      ex_mem_mem_write_i  = 1'b1;
      ex_mem_mem_read_i   = 1'b0;
      ex_mem_funct3_i     = funct3;
      ex_mem_addr_i       = addr;
      ex_mem_store_data_i = store_data;
      #1;

      tb_check(dmem_en_o == 1'b1, "Store should assert dmem_en_o");
      tb_check(dmem_we_o == exp_we, "Store byte enables (dmem_we_o) mismatch");
      tb_check(dmem_wdata_o == exp_wdata, "Store aligned write data mismatch");

      @(posedge clk);
      #1;

      tb_check(mem[idx] == exp_word_after, "Memory word after store mismatch");

      // deassert
      @(negedge clk);
      drive_defaults();
    end
  endtask

  // Load funct3: LB=000, LH=001, LW=010, LBU=100, LHU=101
  task automatic do_load(
    input logic [2:0]  funct3,
    input logic [31:0] addr,
    input logic [31:0] exp_data
  );
    begin
      @(negedge clk);
      ex_mem_valid_i     = 1'b1;
      ex_mem_mem_read_i  = 1'b1;
      ex_mem_mem_write_i = 1'b0;
      ex_mem_funct3_i    = funct3;
      ex_mem_addr_i      = addr;
      #1;

      tb_check(dmem_en_o == 1'b1, "Load should assert dmem_en_o");
      tb_check(dmem_we_o == 4'b0000, "Load should have dmem_we_o=0000");

      // one cycle later: load_valid_o should assert and data should be formatted
      @(posedge clk);
      #1;
      tb_check(load_valid_o == 1'b1, "load_valid_o should be 1 one cycle after load request");
      tb_check(load_data_o == exp_data, "load_data_o mismatch");

      // deassert
      @(negedge clk);
      drive_defaults();

      // next cycle load_valid_o should drop (unless another load requested)
      @(posedge clk);
      #1;
      tb_check(load_valid_o == 1'b0, "load_valid_o should drop when no new load requested");
    end
  endtask

  // sign/zero helpers
  function automatic logic [31:0] sext8(input logic [7:0] b);
    return {{24{b[7]}}, b};
  endfunction
  function automatic logic [31:0] sext16(input logic [15:0] h);
    return {{16{h[15]}}, h};
  endfunction

  // --------------------------------------------------------------------------
  // TEST SEQUENCE
  // --------------------------------------------------------------------------
  initial begin
    $display("Starting tb_mem_unit...");

    // init memory
    for (int i = 0; i < DEPTH_WORDS; i++) mem[i] = 32'd0;

    // Word0 = 0x80FF7F01 (little-endian bytes: 01,7F,FF,80)
    mem[0] = 32'h80FF_7F01;
    mem[1] = 32'h0000_0000;

    drive_defaults();
    do_reset();

    // ---- LOAD tests from word0 ----
    // base address 0
    do_load(3'b000, 32'd0, sext8(8'h01)); 
    do_load(3'b000, 32'd1, sext8(8'h7F)); 
    do_load(3'b000, 32'd2, sext8(8'hFF)); 
    do_load(3'b000, 32'd3, sext8(8'h80)); 

    do_load(3'b100, 32'd2, {24'd0, 8'hFF});
    do_load(3'b100, 32'd3, {24'd0, 8'h80}); 

    do_load(3'b001, 32'd0, sext16(16'h7F01)); 
    do_load(3'b101, 32'd2, {16'd0, 16'h80FF});
    do_load(3'b001, 32'd2, sext16(16'h80FF));  

    do_load(3'b010, 32'd0, 32'h80FF_7F01); // LW

    do_store(
      3'b000,          
      32'd6,          
      32'h0000_00AA,
      4'b0100,
      32'h00AA_0000,
      32'h00AA_0000
    );

    // SH aligned at addr=4, store 0xBEEF -> bytes0-1 = EF BE
    // word becomes 0x00AA_BEEF
    do_store(
      3'b001,          // SH
      32'd4,           // 4 + 0
      32'h0000_BEEF,
      4'b0011,
      32'h0000_BEEF,
      32'h00AA_BEEF
    );

    // SW aligned at addr=4, store 0xDEADBEEF -> word becomes 0xDEADBEEF
    do_store(
      3'b010,          // SW
      32'd4,
      32'hDEAD_BEEF,
      4'b1111,
      32'hDEAD_BEEF,
      32'hDEAD_BEEF
    );

    // Misaligned SH at addr=5 should result in we=0000 and no change (per your mem_unit)
    // exp we=0000, wdata don't-care (we check it equals 0 in our implementation)
    do_store(
      3'b001,          // SH
      32'd5,           // misaligned
      32'h0000_1234,
      4'b0000,
      32'h0000_0000,
      32'hDEAD_BEEF
    );

    $display("All mem_unit tests PASSED.");
    $finish;
  end

endmodule

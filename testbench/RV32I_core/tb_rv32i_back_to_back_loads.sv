`timescale 1ns/1ps

// Test 1: Back-to-back loads (LW, LW) + EBREAK
// Goal: Stress the 1-entry skid buffer / MEM->WB load alignment.
// Program:
//   lw x3,0(x0)
//   lw x4,4(x0)
//   ebreak
//
// Expected:
//   x3 = DMEM[0]  (word at addr 0)
//   x4 = DMEM[1]  (word at addr 4)
//   done_o asserts (or at least WB sees EBREAK if your done logic requires it)

module tb_rv32i_back_to_back_loads;

  // clock/reset
  logic clk = 1'b0;
  logic rst = 1'b1;

  // imem
  logic [31:0] imem_addr;
  logic        imem_en;
  logic [31:0] imem_rdata;

  // dmem
  logic [31:0] dmem_addr;
  logic [31:0] dmem_wdata;
  logic [3:0]  dmem_wstrb;
  logic        dmem_we;
  logic        dmem_re;
  logic [31:0] dmem_rdata;

  // status
  logic done_o, trap_o;

  // DUT
  RV32I_Core dut (
    .clk        (clk),
    .rst        (rst),

    .imem_addr  (imem_addr),
    .imem_en    (imem_en),
    .imem_rdata (imem_rdata),

    .dmem_addr  (dmem_addr),
    .dmem_wdata (dmem_wdata),
    .dmem_wstrb (dmem_wstrb),
    .dmem_we    (dmem_we),
    .dmem_re    (dmem_re),
    .dmem_rdata (dmem_rdata),

    .done_o     (done_o),
    .trap_o     (trap_o)
  );

  // Clock: 100MHz
  always #5 clk = ~clk;

  // -----------------------------
  // Instruction memory (sync read, 1-cycle latency)
  // -----------------------------
  localparam int IMEM_WORDS = 64;
  logic [31:0] imem [0:IMEM_WORDS-1];
  logic [31:0] imem_rdata_q;

  // Encodings:
  // lw x3,0(x0)  = 0x00002183
  // lw x4,4(x0)  = 0x00402203
  // ebreak       = 0x00100073
  integer ii;
  initial begin
    for (ii = 0; ii < IMEM_WORDS; ii = ii + 1)
      imem[ii] = 32'h0000_0013; // NOP fill

    // replace your imem init with this
    imem[0] = 32'h0000_0013; // NOP padding
    imem[1] = 32'h0000_2183; // lw x3,0(x0)
    imem[2] = 32'h0040_2203; // lw x4,4(x0)
    imem[3] = 32'h0010_0073; // ebreak
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      imem_rdata_q <= 32'h0000_0013; // NOP
    end else if (imem_en) begin
      imem_rdata_q <= imem[imem_addr[31:2]];
    end else begin
      imem_rdata_q <= 32'h0000_0013;
    end
  end

  assign imem_rdata = imem_rdata_q;

  // -----------------------------
  // Data memory (sync read, 1-cycle latency, byte enables)
  // -----------------------------
  localparam int DMEM_WORDS = 256;
  logic [31:0] dmem [0:DMEM_WORDS-1];
  logic [31:0] dmem_rdata_q;

  // deterministic init: set two known words
  localparam logic [31:0] EXPECT0 = 32'h1111_1111;
  localparam logic [31:0] EXPECT1 = 32'h2222_2222;

  integer jj;
  initial begin
    for (jj = 0; jj < DMEM_WORDS; jj = jj + 1)
      dmem[jj] = 32'd0;

    dmem[0] = EXPECT0; // addr 0
    dmem[1] = EXPECT1; // addr 4
    dmem_rdata_q = 32'd0;
  end

  // temp vars declared at block top (Vivado-friendly)
  integer widx, ridx;
  logic [31:0] new_word;

  always_ff @(posedge clk) begin
    if (rst) begin
      dmem_rdata_q <= 32'd0;
    end else begin
      // WRITE (should not happen in this test)
      if (dmem_we) begin
        widx = dmem_addr[31:2];
        if (widx >= 0 && widx < DMEM_WORDS) begin
          new_word = dmem[widx];
          if (dmem_wstrb[0]) new_word[ 7: 0] = dmem_wdata[ 7: 0];
          if (dmem_wstrb[1]) new_word[15: 8] = dmem_wdata[15: 8];
          if (dmem_wstrb[2]) new_word[23:16] = dmem_wdata[23:16];
          if (dmem_wstrb[3]) new_word[31:24] = dmem_wdata[31:24];
          dmem[widx] <= new_word;
        end
      end

      // READ (registered)
      if (dmem_re) begin
        ridx = dmem_addr[31:2];
        if (ridx >= 0 && ridx < DMEM_WORDS) dmem_rdata_q <= dmem[ridx];
        else                               dmem_rdata_q <= 32'd0;
      end
    end
  end

  assign dmem_rdata = dmem_rdata_q;

  // -----------------------------
  // Scoreboard / checks
  // -----------------------------
  bit x3_seen, x4_seen;
  int cycle_count;

  always_ff @(posedge clk) begin
    if (rst) begin
      x3_seen     <= 1'b0;
      x4_seen     <= 1'b0;
      cycle_count <= 0;
    end else begin
      cycle_count++;

      // This test should not write memory
      if (dmem_we) begin
        $display("[FAIL] Unexpected store: dmem_we=1 addr=0x%08x wdata=0x%08x wstrb=%b @ t=%0t",
                 dmem_addr, dmem_wdata, dmem_wstrb, $time);
        $fatal;
      end

      // Watch RF writes (hierarchical)
      if (dut.rf_we) begin
        if (dut.rf_waddr == 5'd3) begin
          x3_seen <= 1'b1;
          if (dut.rf_wdata !== EXPECT0) begin
            $display("[FAIL] x3 <= 0x%08x expected 0x%08x @ t=%0t", dut.rf_wdata, EXPECT0, $time);
            $fatal;
          end else begin
            $display("[OK] x3 <= 0x%08x", dut.rf_wdata);
          end
        end
        if (dut.rf_waddr == 5'd4) begin
          x4_seen <= 1'b1;
          if (dut.rf_wdata !== EXPECT1) begin
            $display("[FAIL] x4 <= 0x%08x expected 0x%08x @ t=%0t", dut.rf_wdata, EXPECT1, $time);
            $fatal;
          end else begin
            $display("[OK] x4 <= 0x%08x", dut.rf_wdata);
          end
        end
      end

      if (trap_o) begin
        $display("[FAIL] trap_o asserted @ t=%0t", $time);
        $fatal;
      end

      if (cycle_count > 200) begin
        $display("[FAIL] Timeout (>200 cycles). x3_seen=%0b x4_seen=%0b done_o=%0b",
                 x3_seen, x4_seen, done_o);
        $fatal;
      end
    end
  end

  // -----------------------------
  // Test flow
  // -----------------------------
  initial begin
    // reset
    repeat (5) @(posedge clk);
    rst = 1'b0;

    // Wait until both loads have written back
    wait (x3_seen && x4_seen);

    $display("[PASS] Back-to-back loads: x3=0x%08x x4=0x%08x", EXPECT0, EXPECT1);

    // Optionally observe done_o for a few cycles (EBREAK)
    repeat (30) @(posedge clk);
    $display("[INFO] done_o=%0b trap_o=%0b", done_o, trap_o);

    $finish;
  end

endmodule

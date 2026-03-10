`timescale 1ns/1ps

module tb_rv32i_store_load_only;

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
  // Program:
  //   addi x1,x0,0      0x00000093
  //   addi x2,x0,42     0x02A00113
  //   sw   x2,0(x1)     0x0020A023
  //   lw   x3,0(x1)     0x0000A183
  //   ebreak            0x00100073
  // -----------------------------
  localparam int IMEM_WORDS = 64;
  logic [31:0] imem [0:IMEM_WORDS-1];
  logic [31:0] imem_rdata_q;

  integer ii;
  initial begin
    for (ii = 0; ii < IMEM_WORDS; ii = ii + 1)
      imem[ii] = 32'h0000_0013; // NOP fill

    imem[0] = 32'h0000_0093;
    imem[1] = 32'h02A0_0113;
    imem[2] = 32'h0020_A023;
    imem[3] = 32'h0000_A183;
    imem[4] = 32'h0010_0073;
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

  integer jj;
  initial begin
    for (jj = 0; jj < DMEM_WORDS; jj = jj + 1)
      dmem[jj] = 32'd0;
    dmem_rdata_q = 32'd0;
  end

  // temp vars declared at block top (Vivado-friendly)
  integer widx, ridx;
  logic [31:0] new_word;

  always_ff @(posedge clk) begin
    if (rst) begin
      dmem_rdata_q <= 32'd0;
    end else begin
      // WRITE
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
  // Debug prints (IF/DMEM/RF + done_o investigation)
  // -----------------------------
  localparam logic [31:0] EBREAK = 32'h0010_0073;

  always_ff @(posedge clk) begin
    if (!rst) begin
      // IF visibility
      if (imem_en) begin
        $display("[%0t] IF: imem_addr=0x%08x instr=0x%08x",
                 $time, imem_addr, imem_rdata);
      end

      // DMEM visibility
      if (dmem_we) begin
        $display("[%0t] DMEM WE: addr=0x%08x wdata=0x%08x wstrb=%b",
                 $time, dmem_addr, dmem_wdata, dmem_wstrb);
      end
      if (dmem_re) begin
        $display("[%0t] DMEM RE: addr=0x%08x rdata(curr)=0x%08x",
                 $time, dmem_addr, dmem_rdata);
      end

      // RF write visibility (hierarchical)
      if (dut.rf_we) begin
        $display("[%0t] RF WE: x%0d <= 0x%08x",
                 $time, dut.rf_waddr, dut.rf_wdata);
      end

      // stall/flush (hierarchical)
      $display("[%0t] stall=%0b flush=%0b pc=0x%08x",
               $time, dut.id_stall, dut.id_flush, dut.id_pc);

      // WB valid/instr visibility (only when wb_valid OR EBREAK appears)
      if (dut.wb_valid_i || (dut.wb_instr_i == EBREAK)) begin
        $display("[%0t] WB: wb_valid_i=%0b wb_instr_i=0x%08x done_o=%0b trap_o=%0b",
                 $time, dut.wb_valid_i, dut.wb_instr_i, done_o, trap_o);
      end

      // Special print when WB instruction equals EBREAK (even if invalid)
      if (dut.wb_instr_i == EBREAK) begin
        $display("[%0t] *** WB_INSTR==EBREAK wb_valid_i=%0b ***",
                 $time, dut.wb_valid_i);
      end
    end
  end

  // -----------------------------
  // Scoreboard
  // -----------------------------
  logic store_seen;
  logic load_wb_seen;
  integer cycle_count;

  localparam logic [31:0] EXPECT = 32'd42;

  always_ff @(posedge clk) begin
    if (rst) begin
      store_seen   <= 1'b0;
      load_wb_seen <= 1'b0;
      cycle_count  <= 0;
    end else begin
      cycle_count <= cycle_count + 1;

      if (dmem_we && (dmem_addr == 32'd0) && (dmem_wstrb == 4'hF))
        store_seen <= 1'b1;

      if (dut.rf_we && (dut.rf_waddr == 5'd3)) begin
        load_wb_seen <= 1'b1;
        if (dut.rf_wdata !== EXPECT) begin
          $display("[FAIL] LW wrote x3=0x%08x expected 0x%08x @ t=%0t",
                    dut.rf_wdata, EXPECT, $time);
          $fatal;
        end
      end

      if (cycle_count > 300) begin
        $display("[FAIL] Timeout (>300 cycles)");
        $fatal;
      end
    end
  end

  // -----------------------------
  // Test flow
  // -----------------------------
  initial begin
    repeat (5) @(posedge clk);
    rst = 1'b0;

    // Wait for the store+load to complete (this is the actual smoke test)
    wait (store_seen && load_wb_seen);

    if (dmem[0] !== EXPECT) begin
      $display("[FAIL] DMEM[0]=0x%08x expected 0x%08x", dmem[0], EXPECT);
      $fatal;
    end

    $display("[PASS] SW then LW succeeded: DMEM[0]=%0d and x3=%0d", dmem[0], EXPECT);

    // Keep running a bit to observe whether EBREAK ever reaches WB/done_o asserts
    repeat (30) @(posedge clk);

    $display("[INFO] End of observation window: done_o=%0b trap_o=%0b", done_o, trap_o);
    $finish;
  end

endmodule

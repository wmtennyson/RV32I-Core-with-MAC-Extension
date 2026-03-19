`timescale 1ns/1ps
// RV32I_Core Strenuous TB (Vivado/XSim-friendly)
// - IMEM: holds last fetched word when imem_en=0 (addr registered only when imem_en=1)
// - DMEM: BYTE-addressed + byte strobes, 1-cycle read latency (matches your working TB)
// - EXACTLY ONE terminal result: TRAP > DONE > TIMEOUT
// - Static "assembler": no strings/queues/dynamic arrays
// - On failure, dumps key internal DUT signals (stall/flush/pc/insn/mem controls)

module tb_RV32I_Core_Final;

  // --------------------------------------------------------------------------
  // Clock / reset
  // --------------------------------------------------------------------------
  logic clk, rst;
  localparam time TCLK = 10ns;

  initial begin
    clk = 1'b0;
    forever #(TCLK/2) clk = ~clk;
  end

  initial begin
    rst = 1'b1;
    repeat (8) @(posedge clk);
    rst = 1'b0;
  end

  // --------------------------------------------------------------------------
  // DUT interface
  // --------------------------------------------------------------------------
  logic [31:0] imem_addr;
  logic        imem_en;
  logic [31:0] imem_rdata;

  logic [31:0] dmem_addr;
  logic [31:0] dmem_wdata;
  logic [3:0]  dmem_wstrb;
  logic        dmem_we;
  logic        dmem_re;
  logic [31:0] dmem_rdata;

  logic done_o, trap_o;

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

  // --------------------------------------------------------------------------
  // Constants
  // --------------------------------------------------------------------------
  localparam logic [31:0] NOP    = 32'h0000_0013; // addi x0,x0,0
  localparam logic [31:0] EBREAK = 32'h0010_0073;
  localparam logic [31:0] ECALL  = 32'h0000_0073;

  // --------------------------------------------------------------------------
  // IMEM model: 1-cycle latency ROM, BRAM-ish hold behavior
  // --------------------------------------------------------------------------
  localparam integer IMEM_WORDS = 2048;
  logic [31:0] imem [0:IMEM_WORDS-1];

  logic [31:0] imem_addr_q;

  always_ff @(posedge clk) begin
    if (rst) imem_addr_q <= 32'd0;
    else if (imem_en) imem_addr_q <= imem_addr; // capture only on enable
  end
  
   

  always_comb begin
    int unsigned idx;
    idx = imem_addr_q[31:2];
    if (idx < IMEM_WORDS) imem_rdata = imem[idx];
    else                  imem_rdata = NOP;
  end

  logic [31:0] last_fetch_addr;
  always_ff @(posedge clk) begin
    if (rst) last_fetch_addr <= 32'd0;
    else if (imem_en) last_fetch_addr <= imem_addr;
  end

  // --------------------------------------------------------------------------
  // DMEM model: BYTE-addressed, byte strobes, 1-cycle read latency
  // --------------------------------------------------------------------------
  localparam integer DMEM_BYTES = 8192;
  byte dmem [0:DMEM_BYTES-1];

  logic        dmem_re_q;
  logic [31:0] dmem_addr_q;

  // write on posedge
  always_ff @(posedge clk) begin
    if (!rst && dmem_we) begin
      int unsigned a;
      a = dmem_addr;
      if (a + 3 < DMEM_BYTES) begin
        if (dmem_wstrb[0]) dmem[a+0] <= dmem_wdata[7:0];
        if (dmem_wstrb[1]) dmem[a+1] <= dmem_wdata[15:8];
        if (dmem_wstrb[2]) dmem[a+2] <= dmem_wdata[23:16];
        if (dmem_wstrb[3]) dmem[a+3] <= dmem_wdata[31:24];
      end else begin
        $display("[%0t] WARNING: DMEM write OOB addr=0x%08x", $time, dmem_addr);
      end
    end
  end

  // capture read for 1-cycle latency
  always_ff @(posedge clk) begin
    if (rst) begin
      dmem_re_q   <= 1'b0;
      dmem_addr_q <= 32'd0;
    end else begin
      dmem_re_q <= dmem_re;
      if (dmem_re) dmem_addr_q <= dmem_addr;
    end
  end

  always_comb begin
    if (dmem_re_q) begin
      int unsigned a;
      a = dmem_addr_q;
      if (a + 3 < DMEM_BYTES)
        dmem_rdata = {dmem[a+3], dmem[a+2], dmem[a+1], dmem[a+0]};
      else
        dmem_rdata = 32'h0;
    end else begin
      dmem_rdata = 32'h0;
    end
  end

  function automatic logic [31:0] read_word(input logic [31:0] addr);
    int unsigned a;
    begin
      a = addr;
      if (a + 3 < DMEM_BYTES)
        read_word = {dmem[a+3], dmem[a+2], dmem[a+1], dmem[a+0]};
      else
        read_word = 32'h0;
    end
  endfunction

  // --------------------------------------------------------------------------
  // Counters / protocol sanity
  // --------------------------------------------------------------------------
  int dmem_reads, dmem_writes;
  bit verbose;

  initial verbose = $test$plusargs("verbose");

  always_ff @(posedge clk) begin
    if (rst) begin
      dmem_reads  <= 0;
      dmem_writes <= 0;
    end else begin
      if (dmem_we && dmem_re) begin
        $display("[%0t] ERROR: dmem_we and dmem_re both 1", $time);
        $fatal(1);
      end
      if (dmem_we && (dmem_wstrb == 4'b0000)) begin
        $display("[%0t] ERROR: dmem_we=1 but wstrb=0", $time);
        $fatal(1);
      end
      if (dmem_we) begin
        dmem_writes <= dmem_writes + 1;
        if (verbose) $display("[%0t] DMEM W addr=0x%08x wdata=0x%08x wstrb=%b",
                              $time, dmem_addr, dmem_wdata, dmem_wstrb);
      end
      if (dmem_re) begin
        dmem_reads <= dmem_reads + 1;
        if (verbose) $display("[%0t] DMEM R addr=0x%08x (rdata next)", $time, dmem_addr);
      end
    end
  end

  // --------------------------------------------------------------------------
  // RV32I encoders
  // --------------------------------------------------------------------------
  localparam logic [6:0] OP_LUI    = 7'b0110111;
  localparam logic [6:0] OP_JAL    = 7'b1101111;
  localparam logic [6:0] OP_JALR   = 7'b1100111;
  localparam logic [6:0] OP_BRANCH = 7'b1100011;
  localparam logic [6:0] OP_LOAD   = 7'b0000011;
  localparam logic [6:0] OP_STORE  = 7'b0100011;
  localparam logic [6:0] OP_IMM    = 7'b0010011;
  localparam logic [6:0] OP_REG    = 7'b0110011;

  function automatic logic [31:0] enc_r(
    input logic [6:0] funct7,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [4:0] rd,
    input logic [6:0] opcode
  );
    enc_r = {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] enc_i(
    input logic signed [31:0] imm12,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [4:0] rd,
    input logic [6:0] opcode
  );
    logic [11:0] imm;
    begin
      imm = imm12[11:0];
      enc_i = {imm, rs1, funct3, rd, opcode};
    end
  endfunction

  function automatic logic [31:0] enc_s(
    input logic signed [31:0] imm12,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [6:0] opcode
  );
    logic [11:0] imm;
    begin
      imm = imm12[11:0];
      enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
    end
  endfunction

  function automatic logic [31:0] enc_b(
    input logic signed [31:0] off_bytes,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3
  );
    logic [12:0] imm;
    begin
      imm = off_bytes[12:0];
      enc_b = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], OP_BRANCH};
    end
  endfunction

  function automatic logic [31:0] enc_u(
    input logic [19:0] imm20,
    input logic [4:0]  rd
  );
    enc_u = {imm20, rd, OP_LUI};
  endfunction

  function automatic logic [31:0] enc_j(
    input logic signed [31:0] off_bytes,
    input logic [4:0] rd
  );
    logic [20:0] imm;
    begin
      imm = off_bytes[20:0];
      enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, OP_JAL};
    end
  endfunction

  // Instruction helpers used by the program
  function automatic logic [31:0] ADD  (input logic [4:0] rd, rs1, rs2); ADD  = enc_r(7'h00, rs2, rs1, 3'b000, rd, OP_REG); endfunction
  function automatic logic [31:0] SUB  (input logic [4:0] rd, rs1, rs2); SUB  = enc_r(7'h20, rs2, rs1, 3'b000, rd, OP_REG); endfunction
  function automatic logic [31:0] XORR (input logic [4:0] rd, rs1, rs2); XORR = enc_r(7'h00, rs2, rs1, 3'b100, rd, OP_REG); endfunction
  function automatic logic [31:0] ORR  (input logic [4:0] rd, rs1, rs2); ORR  = enc_r(7'h00, rs2, rs1, 3'b110, rd, OP_REG); endfunction
  function automatic logic [31:0] ANDR (input logic [4:0] rd, rs1, rs2); ANDR = enc_r(7'h00, rs2, rs1, 3'b111, rd, OP_REG); endfunction

  function automatic logic [31:0] SLT  (input logic [4:0] rd, rs1, rs2); SLT  = enc_r(7'h00, rs2, rs1, 3'b010, rd, OP_REG); endfunction
  function automatic logic [31:0] SLTU (input logic [4:0] rd, rs1, rs2); SLTU = enc_r(7'h00, rs2, rs1, 3'b011, rd, OP_REG); endfunction

  function automatic logic [31:0] ADDI (input logic [4:0] rd, rs1, input logic signed [31:0] imm); ADDI = enc_i(imm, rs1, 3'b000, rd, OP_IMM); endfunction
  function automatic logic [31:0] XORI (input logic [4:0] rd, rs1, input logic signed [31:0] imm); XORI = enc_i(imm, rs1, 3'b100, rd, OP_IMM); endfunction
  function automatic logic [31:0] ANDI (input logic [4:0] rd, rs1, input logic signed [31:0] imm); ANDI = enc_i(imm, rs1, 3'b111, rd, OP_IMM); endfunction
  function automatic logic [31:0] ORI  (input logic [4:0] rd, rs1, input logic signed [31:0] imm); ORI  = enc_i(imm, rs1, 3'b110, rd, OP_IMM); endfunction
  function automatic logic [31:0] SLTI (input logic [4:0] rd, rs1, input logic signed [31:0] imm); SLTI = enc_i(imm, rs1, 3'b010, rd, OP_IMM); endfunction
  function automatic logic [31:0] SLTIU(input logic [4:0] rd, rs1, input logic signed [31:0] imm); SLTIU= enc_i(imm, rs1, 3'b011, rd, OP_IMM); endfunction

  function automatic logic [31:0] SLLI (input logic [4:0] rd, rs1, input logic [4:0] shamt); SLLI = enc_i({7'h00, shamt}, rs1, 3'b001, rd, OP_IMM); endfunction
  function automatic logic [31:0] SRLI (input logic [4:0] rd, rs1, input logic [4:0] shamt); SRLI = enc_i({7'h00, shamt}, rs1, 3'b101, rd, OP_IMM); endfunction
  function automatic logic [31:0] SRAI (input logic [4:0] rd, rs1, input logic [4:0] shamt); SRAI = enc_i({7'h20, shamt}, rs1, 3'b101, rd, OP_IMM); endfunction

  function automatic logic [31:0] LUI  (input logic [4:0] rd, input logic [19:0] imm20); LUI  = enc_u(imm20, rd); endfunction

  function automatic logic [31:0] LW   (input logic [4:0] rd, rs1, input logic signed [31:0] imm); LW  = enc_i(imm, rs1, 3'b010, rd, OP_LOAD); endfunction
  function automatic logic [31:0] LH   (input logic [4:0] rd, rs1, input logic signed [31:0] imm); LH  = enc_i(imm, rs1, 3'b001, rd, OP_LOAD); endfunction
  function automatic logic [31:0] LHU  (input logic [4:0] rd, rs1, input logic signed [31:0] imm); LHU = enc_i(imm, rs1, 3'b101, rd, OP_LOAD); endfunction
  function automatic logic [31:0] LB   (input logic [4:0] rd, rs1, input logic signed [31:0] imm); LB  = enc_i(imm, rs1, 3'b000, rd, OP_LOAD); endfunction
  function automatic logic [31:0] LBU  (input logic [4:0] rd, rs1, input logic signed [31:0] imm); LBU = enc_i(imm, rs1, 3'b100, rd, OP_LOAD); endfunction

  function automatic logic [31:0] SW   (input logic [4:0] rs2, rs1, input logic signed [31:0] imm); SW  = enc_s(imm, rs2, rs1, 3'b010, OP_STORE); endfunction
  function automatic logic [31:0] SH   (input logic [4:0] rs2, rs1, input logic signed [31:0] imm); SH  = enc_s(imm, rs2, rs1, 3'b001, OP_STORE); endfunction
  function automatic logic [31:0] SB   (input logic [4:0] rs2, rs1, input logic signed [31:0] imm); SB  = enc_s(imm, rs2, rs1, 3'b000, OP_STORE); endfunction

  function automatic logic [31:0] BEQ  (input logic [4:0] rs1, rs2, input logic signed [31:0] off_bytes); BEQ = enc_b(off_bytes, rs2, rs1, 3'b000); endfunction
  function automatic logic [31:0] BNE  (input logic [4:0] rs1, rs2, input logic signed [31:0] off_bytes); BNE = enc_b(off_bytes, rs2, rs1, 3'b001); endfunction

  function automatic logic [31:0] JAL  (input logic [4:0] rd, input logic signed [31:0] off_bytes); JAL = enc_j(off_bytes, rd); endfunction
  function automatic logic [31:0] JALR (input logic [4:0] rd, rs1, input logic signed [31:0] imm); JALR = enc_i(imm, rs1, 3'b000, rd, OP_JALR); endfunction

  // --------------------------------------------------------------------------
  // Static assembler + fixups (no strings/queues)
  // --------------------------------------------------------------------------
  localparam integer MAX_PROG = 1400;
  localparam integer MAX_FIX  = 400;

  logic [31:0] prog [0:MAX_PROG-1];
  integer prog_len;

  localparam integer L_BR_TAKEN     = 0;
  localparam integer L_BR_NOT_TAKEN = 1;
  localparam integer L_FUNC         = 2;
  localparam integer L_AFTER_FUNC   = 3;
  localparam integer L_LU_BR_TAKEN  = 4;
  localparam integer L_LOOP         = 5;
  localparam integer L_PASS         = 6;
  localparam integer L_FAIL         = 7;

  integer label_pc [0:31];

  localparam logic [1:0] FX_BEQ = 2'd0;
  localparam logic [1:0] FX_BNE = 2'd1;
  localparam logic [1:0] FX_JAL = 2'd2;

  integer fix_count;
  integer fix_idx   [0:MAX_FIX-1];
  integer fix_label [0:MAX_FIX-1];
  logic [1:0] fix_type [0:MAX_FIX-1];
  logic [4:0] fix_rs1  [0:MAX_FIX-1];
  logic [4:0] fix_rs2  [0:MAX_FIX-1];
  logic [4:0] fix_rd   [0:MAX_FIX-1];

  task automatic emit_instr(input logic [31:0] insn);
    begin
      if (prog_len >= MAX_PROG) begin
        $display("Program too large (MAX_PROG=%0d)", MAX_PROG);
        $fatal(1);
      end
      prog[prog_len] = insn;
      prog_len = prog_len + 1;
    end
  endtask

  task automatic mark_label(input integer lid);
    begin
      label_pc[lid] = prog_len;
    end
  endtask

  task automatic emit_b_fixup(input logic [1:0] fxtype, input logic [4:0] rs1, input logic [4:0] rs2, input integer lid);
    begin
      if (fix_count >= MAX_FIX) begin
        $display("Too many fixups (MAX_FIX=%0d)", MAX_FIX);
        $fatal(1);
      end
      fix_idx[fix_count]   = prog_len;
      fix_label[fix_count] = lid;
      fix_type[fix_count]  = fxtype;
      fix_rs1[fix_count]   = rs1;
      fix_rs2[fix_count]   = rs2;
      fix_rd[fix_count]    = 5'd0;
      fix_count = fix_count + 1;
      emit_instr(NOP); // placeholder
    end
  endtask

  task automatic emit_j_fixup(input logic [4:0] rd, input integer lid);
    begin
      if (fix_count >= MAX_FIX) begin
        $display("Too many fixups (MAX_FIX=%0d)", MAX_FIX);
        $fatal(1);
      end
      fix_idx[fix_count]   = prog_len;
      fix_label[fix_count] = lid;
      fix_type[fix_count]  = FX_JAL;
      fix_rs1[fix_count]   = 5'd0;
      fix_rs2[fix_count]   = 5'd0;
      fix_rd[fix_count]    = rd;
      fix_count = fix_count + 1;
      emit_instr(NOP); // placeholder
    end
  endtask

  task automatic patch_fixups;
    integer i;
    integer src_w, dst_w;
    logic signed [31:0] off_bytes;
    begin
      for (i = 0; i < fix_count; i = i + 1) begin
        src_w = fix_idx[i];
        dst_w = label_pc[fix_label[i]];
        off_bytes = (dst_w - src_w) * 4;

        case (fix_type[i])
          FX_BEQ: prog[src_w] = BEQ(fix_rs1[i], fix_rs2[i], off_bytes);
          FX_BNE: prog[src_w] = BNE(fix_rs1[i], fix_rs2[i], off_bytes);
          FX_JAL: prog[src_w] = JAL(fix_rd[i], off_bytes);
          default: begin
            $display("Unknown fixup type");
            $fatal(1);
          end
        endcase
      end
    end
  endtask

  task automatic emit_li(input logic [4:0] rd, input logic [31:0] value);
    logic signed [31:0] sval;
    integer signed upper;
    integer signed lower;
    begin
      sval = $signed(value);
      if ((sval >= -2048) && (sval <= 2047)) begin
        emit_instr(ADDI(rd, 5'd0, sval));
      end else begin
        upper = (sval + 32'sd2048) >>> 12;
        lower = sval - (upper <<< 12);
        emit_instr(LUI(rd, upper[19:0]));
        emit_instr(ADDI(rd, rd, lower));
      end
    end
  endtask

  // If reg != expected -> x31=code; jump FAIL
  task automatic emit_check_eq(input logic [4:0] regnum,
                               input logic [31:0] expected,
                               input logic [31:0] code);
    begin
      emit_li(5'd29, expected); // x29 = expected
      emit_li(5'd31, code);     // x31 = fail code
      emit_b_fixup(FX_BNE, regnum, 5'd29, L_FAIL);
    end
  endtask

  // --------------------------------------------------------------------------
  // Build stress program
  // Signature:
  //   PASS: mem[0]=1, mem[4]=0, mem[8]=checksum; then EBREAK
  //   FAIL: mem[0]=0, mem[4]=x31, mem[8]=acc; then ECALL (trap)
  // --------------------------------------------------------------------------
task automatic build_prog_main_short;
  integer i;
  begin
    prog_len  = 0;
    fix_count = 0;
    for (i = 0; i < 32; i = i + 1) label_pc[i] = 0;

    // clear signature
    emit_instr(SW(5'd0, 5'd0, 0));
    emit_instr(SW(5'd0, 5'd0, 4));
    emit_instr(SW(5'd0, 5'd0, 8));

    // base addr = 0x40
    emit_li(5'd11, 32'h0000_0040);
    emit_li(5'd10, 32'h1122_3344);
    emit_instr(SW(5'd10,5'd11,0));

    emit_instr(LB (5'd12,5'd11,0));
    emit_instr(LBU(5'd13,5'd11,1));
    emit_instr(LH (5'd14,5'd11,0));
    emit_instr(LHU(5'd15,5'd11,2));
    emit_instr(LW (5'd16,5'd11,0));

    // write results out so branch logic is not involved
    emit_instr(SW(5'd12,5'd0,12));
    emit_instr(SW(5'd13,5'd0,16));
    emit_instr(SW(5'd14,5'd0,20));
    emit_instr(SW(5'd15,5'd0,24));
    emit_instr(SW(5'd16,5'd0,28));

    // PASS
    emit_instr(ADDI(5'd30,5'd0,1));
    emit_instr(SW(5'd30,5'd0,0));
    emit_instr(EBREAK);

    patch_fixups();
  end
endtask

  task automatic build_prog_main;
    integer i;
    begin
      prog_len  = 0;
      fix_count = 0;
      for (i = 0; i < 32; i = i + 1) label_pc[i] = 0;

      // signature clear
      emit_instr(SW(5'd0, 5'd0, 0));
      emit_instr(SW(5'd0, 5'd0, 4));
      emit_instr(SW(5'd0, 5'd0, 8));

      // x0 write ignored
      emit_instr(ADDI(5'd0, 5'd0, 123));
      emit_instr(ADDI(5'd15,5'd0, 0));
      emit_check_eq(5'd15, 32'h0000_0000, 32'h0000_0001);

      // ALU/forwarding chain
      emit_instr(ADDI(5'd1, 5'd0, 5));
      emit_instr(ADDI(5'd2, 5'd0, 7));
      emit_instr(ADD (5'd3, 5'd1, 5'd2)); // 12
      emit_check_eq(5'd3, 32'h0000_000C, 32'h0000_0002);

      emit_instr(ADD (5'd4, 5'd3, 5'd1)); // 17
      emit_check_eq(5'd4, 32'h0000_0011, 32'h0000_0003);

      emit_instr(SUB (5'd5, 5'd4, 5'd2)); // 10
      emit_check_eq(5'd5, 32'h0000_000A, 32'h0000_0004);

      emit_instr(XORR(5'd6, 5'd5, 5'd1)); // 15
      emit_check_eq(5'd6, 32'h0000_000F, 32'h0000_0005);

      emit_instr(ORR (5'd7, 5'd6, 5'd2)); // 15
      emit_check_eq(5'd7, 32'h0000_000F, 32'h0000_0006);

      emit_instr(ANDR(5'd8, 5'd7, 5'd4)); // 1
      emit_check_eq(5'd8, 32'h0000_0001, 32'h0000_0007);

      emit_instr(SLLI(5'd9, 5'd8, 5'd10)); // 1024
      emit_check_eq(5'd9, 32'h0000_0400, 32'h0000_0008);

      emit_instr(SRLI(5'd10,5'd9, 5'd5));  // 32
      emit_check_eq(5'd10,32'h0000_0020, 32'h0000_0009);

      // signed behavior
      emit_instr(ADDI(5'd11,5'd0, -16));
      emit_instr(SRAI(5'd12,5'd11,5'd2));   // -4
      emit_check_eq(5'd12,32'hFFFF_FFFC, 32'h0000_000A);

      emit_instr(SLT (5'd13,5'd11,5'd0));   // 1
      emit_check_eq(5'd13,32'h0000_0001, 32'h0000_000B);

      emit_instr(SLTU(5'd14,5'd11,5'd0));   // 0
      emit_check_eq(5'd14,32'h0000_0000, 32'h0000_000C);

      emit_instr(SLTI(5'd16,5'd11,-15));    // 1
      emit_check_eq(5'd16,32'h0000_0001, 32'h0000_000D);

      emit_instr(SLTIU(5'd17,5'd11, 1));    // 0
      emit_check_eq(5'd17,32'h0000_0000, 32'h0000_000E);

      // branch flush taken
      emit_instr(ADDI(5'd18,5'd0, 1));
      emit_instr(ADDI(5'd19,5'd0, 0));
      emit_b_fixup(FX_BEQ, 5'd18, 5'd18, L_BR_TAKEN);
      emit_instr(ADDI(5'd19,5'd0, 2047)); // should flush
      mark_label(L_BR_TAKEN);
      emit_check_eq(5'd19,32'h0000_0000, 32'h0000_000F);

      // branch not taken
      emit_instr(ADDI(5'd21,5'd0, 1));
      emit_instr(ADDI(5'd22,5'd0, 2));
      emit_b_fixup(FX_BEQ, 5'd21, 5'd22, L_BR_NOT_TAKEN);
      emit_instr(ADDI(5'd23,5'd0, 3));
      mark_label(L_BR_NOT_TAKEN);
      emit_check_eq(5'd23,32'h0000_0003, 32'h0000_0010);

      // jal/jalr call-return
      emit_instr(ADDI(5'd25,5'd0, 0));
      emit_j_fixup(5'd1, L_FUNC);
      emit_check_eq(5'd25,32'h0000_005B, 32'h0000_0011);
      emit_j_fixup(5'd0, L_AFTER_FUNC);
      mark_label(L_FUNC);
      emit_instr(ADDI(5'd24,5'd0, 8'h5A));
      emit_instr(ADDI(5'd25,5'd24,1));
      emit_instr(JALR(5'd0, 5'd1, 0));
      mark_label(L_AFTER_FUNC);

      // memory size/sign tests @ 0x40
      emit_li(5'd11, 32'h0000_0040);
      emit_li(5'd10, 32'h1122_3344);
      emit_instr(SW(5'd10,5'd11,0));

      emit_instr(LB (5'd12,5'd11,0));  emit_check_eq(5'd12,32'h0000_0044, 32'h0000_0012);
      emit_instr(LBU(5'd13,5'd11,1));  emit_check_eq(5'd13,32'h0000_0033, 32'h0000_0013);
      emit_instr(LH (5'd14,5'd11,0));  emit_check_eq(5'd14,32'h0000_3344, 32'h0000_0014);
      emit_instr(LHU(5'd15,5'd11,2));  emit_check_eq(5'd15,32'h0000_1122, 32'h0000_0015);
      emit_instr(LW (5'd16,5'd11,0));  emit_check_eq(5'd16,32'h1122_3344, 32'h0000_0016);

      emit_instr(ADDI(5'd17,5'd0, 8'hAA));
      emit_instr(SB(5'd17,5'd11,1));
      emit_instr(LW(5'd16,5'd11,0));
      emit_check_eq(5'd16,32'h1122_AA44, 32'h0000_0017);

      emit_li(5'd17, 32'h0000_BEEF);
      emit_instr(SH(5'd17,5'd11,2));
      emit_instr(LW(5'd16,5'd11,0));
      emit_check_eq(5'd16,32'hBEEF_AA44, 32'h0000_0018);

      emit_instr(ADDI(5'd17,5'd0, 8'h80));
      emit_instr(SB(5'd17,5'd11,0));
      emit_instr(LB(5'd18,5'd11,0));  emit_check_eq(5'd18,32'hFFFF_FF80, 32'h0000_0019);
      emit_instr(LBU(5'd19,5'd11,0)); emit_check_eq(5'd19,32'h0000_0080, 32'h0000_001A);

      // load-use stall test
      emit_li(5'd11, 32'h0000_0080);
      emit_instr(ADDI(5'd10,5'd0, 32'sd21));
      emit_instr(SW(5'd10,5'd11,0));
      emit_instr(LW(5'd12,5'd11,0));
      emit_instr(ADDI(5'd13,5'd12,3));
      emit_check_eq(5'd13,32'h0000_0018, 32'h0000_001B);

      // load-dependent branch flush
      emit_instr(LW(5'd14,5'd11,0));
      emit_instr(ADDI(5'd15,5'd0,0));
      emit_b_fixup(FX_BEQ, 5'd14, 5'd10, L_LU_BR_TAKEN);
      emit_instr(ADDI(5'd15,5'd0,2047));
      mark_label(L_LU_BR_TAKEN);
      emit_check_eq(5'd15,32'h0000_0000, 32'h0000_001C);

      // xorshift loop checksum (50 iters) => 0x63768D8E
      emit_li(5'd20, 32'h1234_5678);
      emit_instr(ADDI(5'd21,5'd0,0));
      emit_instr(ADDI(5'd22,5'd0,50));
      emit_li(5'd23, 32'h0000_0100);

      mark_label(L_LOOP);
      emit_instr(SLLI(5'd24,5'd20,5'd13));
      emit_instr(XORR(5'd20,5'd20,5'd24));
      emit_instr(SRLI(5'd24,5'd20,5'd17));
      emit_instr(XORR(5'd20,5'd20,5'd24));
      emit_instr(SLLI(5'd24,5'd20,5'd5));
      emit_instr(XORR(5'd20,5'd20,5'd24));

      emit_instr(ANDI(5'd24,5'd20, 32'sd63));
      emit_instr(SLLI(5'd24,5'd24,5'd2));
      emit_instr(ADD (5'd25,5'd23,5'd24));
      emit_instr(SW  (5'd20,5'd25,0));

      emit_instr(SRLI(5'd26,5'd20,5'd6));
      emit_instr(ANDI(5'd26,5'd26, 32'sd63));
      emit_instr(SLLI(5'd26,5'd26,5'd2));
      emit_instr(ADD (5'd27,5'd23,5'd26));
      emit_instr(LW  (5'd28,5'd27,0));
      emit_instr(ADD (5'd21,5'd21,5'd28));

      emit_instr(ADDI(5'd22,5'd22,-1));
      emit_b_fixup(FX_BNE, 5'd22, 5'd0, L_LOOP);

      emit_check_eq(5'd21,32'h6376_8D8E, 32'h0000_001D);

      // PASS
      mark_label(L_PASS);
      emit_instr(ADDI(5'd30,5'd0,1));
      emit_instr(SW(5'd30,5'd0,0));
      emit_instr(SW(5'd0, 5'd0,4));
      emit_instr(SW(5'd21,5'd0,8));
      emit_instr(EBREAK);

      // pipeline cushion so PASS doesn't fall into FAIL before done_o halts side effects
    emit_instr(NOP);
    emit_instr(NOP);
    emit_instr(NOP);
    emit_instr(NOP);
    emit_instr(NOP);

      // FAIL
      mark_label(L_FAIL);
      emit_instr(SW(5'd0,  5'd0,0));
      emit_instr(SW(5'd31, 5'd0,4));
      emit_instr(SW(5'd21, 5'd0,8));
      emit_instr(ECALL);

      patch_fixups();
    end
  endtask

  // --------------------------------------------------------------------------
  // Memory init / program load
  // --------------------------------------------------------------------------
  task automatic clear_memories;
    integer i;
    begin
      for (i = 0; i < IMEM_WORDS; i = i + 1) imem[i] = NOP;
      for (i = 0; i < DMEM_BYTES; i = i + 1) dmem[i] = 8'h00;
    end
  endtask

  task automatic load_imem_from_prog;
    integer i;
    begin
      for (i = 0; i < IMEM_WORDS; i = i + 1) imem[i] = NOP;
      for (i = 0; i < prog_len; i = i + 1) begin
        if (i < IMEM_WORDS) imem[i] = prog[i];
      end
    end
  endtask

  // --------------------------------------------------------------------------
  // Debug dump (called only on FAIL/TIMEOUT)
  // --------------------------------------------------------------------------
  task automatic dump_debug();
    begin
      $display("----- DEBUG DUMP -----");
      $display("IF  : imem_en=%b imem_addr=0x%08x imem_addr_q=0x%08x last_fetch_addr=0x%08x imem_rdata=0x%08x",
               imem_en, imem_addr, imem_addr_q, last_fetch_addr, imem_rdata);

      $display("CTRL: stall=%b flush=%b branch_target=0x%08x",
               dut.stall, dut.flush, dut.branch_target);

      $display("ID  : valid=%b pc=0x%08x instr=0x%08x",
               dut.id_valid, dut.id_pc, dut.id_instr);

      $display("EX  : valid=%b pc=0x%08x instr=0x%08x memR=%b memW=%b regW=%b rd=%0d",
               dut.ex_valid, dut.ex_pc, dut.ex_instr,
               dut.ex_mem_read, dut.ex_mem_write, dut.ex_regwrite, dut.ex_rd);

      $display("MEM : valid=%b instr=0x%08x memR=%b memW=%b funct3=%b addr=0x%08x",
               dut.mem_valid, dut.mem_instr,
               dut.mem_mem_read, dut.mem_mem_write, dut.mem_funct3, dut.mem_alu_out);

      $display("WB  : valid=%b instr=0x%08x rd=%0d regW=%b value=0x%08x",
               dut.wb_valid, dut.wb_instr, dut.wb_rd_raw, dut.wb_regwrite_raw, dut.wb_value);

      $display("DMEM: we=%b re=%b wstrb=%b addr=0x%08x wdata=0x%08x rdata=0x%08x",
               dmem_we, dmem_re, dmem_wstrb, dmem_addr, dmem_wdata, dmem_rdata);

      $display("WRAP: dmem_en_int=%b dmem_we_int=%b",
               dut.dmem_en_int, dut.dmem_we_int);
      $display("----------------------");
    end
  endtask

  // --------------------------------------------------------------------------
  // Terminal control: EXACTLY ONE result (TRAP > DONE > TIMEOUT)
  // --------------------------------------------------------------------------
  localparam int MAX_CYCLES = 20000;
  int cycles;
  bit timed_out;


  initial begin
    int unsigned passflag, failcode, diag;

    cycles    = 0;
    timed_out = 0;

    clear_memories();
    build_prog_main();
    load_imem_from_prog();

    @(negedge rst);

    fork
      begin : timeout_thread
        repeat (MAX_CYCLES) begin
          @(posedge clk);
          cycles++;
        end
        timed_out = 1;
      end

      begin : trap_thread
        @(posedge trap_o);
      end

      begin : done_thread
        @(posedge done_o);
      end
    join_any
    disable fork;

    #1ps;
    

    passflag = read_word(32'h0000_0000);
    failcode = read_word(32'h0000_0004);
    diag     = read_word(32'h0000_0008);

    if (timed_out) begin
      $display("\nFAIL: TIMEOUT after %0d cycles. done=%b trap=%b last_fetch_addr=0x%08x\n",
               MAX_CYCLES, done_o, trap_o, last_fetch_addr);
      $display("  sig: mem[0]=0x%08x mem[4]=0x%08x mem[8]=0x%08x  (writes=%0d reads=%0d)\n",
               passflag, failcode, diag, dmem_writes, dmem_reads);
      dump_debug();
      $finish;
    end

    if (trap_o) begin
      $display("\nFAIL: TRAP asserted at cycle %0d. done=%b last_fetch_addr=0x%08x\n",
               cycles, done_o, last_fetch_addr);
      $display("  sig: mem[0]=0x%08x mem[4]=0x%08x mem[8]=0x%08x  (writes=%0d reads=%0d)\n",
               passflag, failcode, diag, dmem_writes, dmem_reads);
      dump_debug();
      $finish;
    end

    // DONE path: require PASS signature
    if (passflag !== 32'h0000_0001 || failcode !== 32'h0000_0000) begin
      $display("\nFAIL: DONE but signature mismatch at cycle %0d. trap=%b last_fetch_addr=0x%08x\n",
               cycles, trap_o, last_fetch_addr);
      $display("  sig: mem[0]=0x%08x mem[4]=0x%08x mem[8]=0x%08x  (writes=%0d reads=%0d)\n",
               passflag, failcode, diag, dmem_writes, dmem_reads);
      dump_debug();
      $finish;
    end

    $display("\nPASS: MAIN_STRESS done at cycle %0d. checksum(mem[8])=0x%08x  (writes=%0d reads=%0d)\n",
             cycles, diag, dmem_writes, dmem_reads);
    $finish;
  end

endmodule
`timescale 1ns/1ps
`include "Def.vh"

module Execute_Unit_tb;

  // DUT inputs
  logic [31:0] PC, PC4;
  logic [31:0] RS1_IDEXE, RS1_EXEMEM, RS1_MEMWB;
  logic [31:0] RS2_IDEXE, RS2_EXEMEM, RS2_MEMWB;
  logic [31:0] imm;

  logic [2:0]  func3;
  logic [6:0]  func7;
  logic [2:0]  alu_op;

  logic [1:0]  RS1_sel, RS2_sel, OpA_sel;
  logic        OpB_sel;

  // DUT output
  logic [31:0] alu_out;

  // Pass/fail counters
  int pass_cnt = 0;
  int fail_cnt = 0;

  // DUT instance
  Execute_Unit dut (
    .PC(PC), .PC4(PC4),
    .RS1_IDEXE(RS1_IDEXE), .RS1_EXEMEM(RS1_EXEMEM), .RS1_MEMWB(RS1_MEMWB),
    .RS2_IDEXE(RS2_IDEXE), .RS2_EXEMEM(RS2_EXEMEM), .RS2_MEMWB(RS2_MEMWB),
    .imm(imm),
    .func3(func3), .func7(func7), .alu_op(alu_op),
    .RS1_sel(RS1_sel), .RS2_sel(RS2_sel), .OpA_sel(OpA_sel), .OpB_sel(OpB_sel),
    .alu_out(alu_out)
  );

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------
  task automatic check32(input logic [31:0] exp, input string name);
    #1; // settle (combinational DUT)
    if (alu_out !== exp) begin
      fail_cnt++;
      $display("FAIL: %s | expected=0x%08h got=0x%08h", name, exp, alu_out);
    end else begin
      pass_cnt++;
      $display("PASS: %s | 0x%08h", name, alu_out);
    end
  endtask

  // Decode configuration (EXE_Control uses func7[5] as "bit30 discriminator")
  task automatic set_rtype(input logic [2:0] f3, input logic bit30);
    alu_op = `R_TYPE;
    func3  = f3;
    func7  = bit30 ? 7'b0100000 : 7'b0000000; // func7[5]=1 corresponds to instr[30]
  endtask

  task automatic set_itype(input logic [2:0] f3, input logic bit30);
    alu_op = `I_TYPE;
    func3  = f3;
    func7  = bit30 ? 7'b0100000 : 7'b0000000; // for SRLI/SRAI discrimination
  endtask

  task automatic set_load(input logic [2:0] f3);
    alu_op = `LOAD;
    func3  = f3;
    func7  = 7'b0000000;
  endtask

  task automatic set_store(input logic [2:0] f3);
    alu_op = `STORE;
    func3  = f3;
    func7  = 7'b0000000;
  endtask

  task automatic set_utype();
    alu_op = `U_TYPE;
    func3  = 3'b000;
    func7  = 7'b0000000;
  endtask

  task automatic set_nop();
    alu_op = `NOP;
    func3  = 3'b000;
    func7  = 7'b0000000;
  endtask

  // Mux convenience
  task automatic mux_rs1_rs2();
    RS1_sel = 2'b00; // ID/EXE
    RS2_sel = 2'b00; // ID/EXE
    OpA_sel = 2'b10; // RS1
    OpB_sel = 1'b0;  // RS2
  endtask

  task automatic mux_rs1_imm();
    RS1_sel = 2'b00;
    RS2_sel = 2'b00;
    OpA_sel = 2'b10; // RS1
    OpB_sel = 1'b1;  // imm
  endtask

  task automatic mux_pc_imm();
    RS1_sel = 2'b00;
    RS2_sel = 2'b00;
    OpA_sel = 2'b00; // PC
    OpB_sel = 1'b1;  // imm
  endtask

  task automatic init_base();
    PC  = 32'd100;
    PC4 = 32'd104;

    RS1_IDEXE  = 32'd10;
    RS1_EXEMEM = 32'd20;
    RS1_MEMWB  = 32'd30;

    RS2_IDEXE  = 32'd1;
    RS2_EXEMEM = 32'd2;
    RS2_MEMWB  = 32'd3;

    imm = 32'd500;

    // Default decode + mux
    set_rtype(3'b000, 1'b0); // ADD
    mux_rs1_rs2();
  endtask

  // ------------------------------------------------------------
  // Test sequence
  // ------------------------------------------------------------
  initial begin
    $display("Starting Execute_Unit_tb (functional) ...");
    init_base();

    // -------------------------------------------------------------------------
    // 1) Operand mux + forwarding regression under ADD
    // -------------------------------------------------------------------------
    set_rtype(3'b000, 1'b0); // ADD
    mux_rs1_rs2();
    check32(32'd11, "MUX: RS1_IDEXE + RS2_IDEXE (10+1)");

    RS1_sel = 2'b10; // RS1_MEMWB = 30
    check32(32'd31, "FWD: RS1_MEMWB + RS2_IDEXE (30+1)");

    RS2_sel = 2'b01; // RS2_EXEMEM = 2
    check32(32'd32, "FWD: RS1_MEMWB + RS2_EXEMEM (30+2)");

    OpB_sel = 1'b1; // imm = 500
    check32(32'd530, "MUX: RS1_MEMWB + imm (30+500)");

    OpA_sel = 2'b00; // PC = 100
    check32(32'd600, "MUX: PC + imm (100+500)");

    OpA_sel = 2'b01; // PC4 = 104
    check32(32'd604, "MUX: PC4 + imm (104+500)");

    // -------------------------------------------------------------------------
    // 2) R-type ALU ops (OpA=RS1, OpB=RS2)
    // -------------------------------------------------------------------------
    init_base();
    RS1_IDEXE = 32'd10;
    RS2_IDEXE = 32'd1;
    mux_rs1_rs2();

    set_rtype(3'b000, 1'b1); check32(32'd9,  "R: SUB 10-1");
    set_rtype(3'b111, 1'b0); check32(32'd0,  "R: AND 10&1");
    set_rtype(3'b110, 1'b0); check32(32'd11, "R: OR  10|1");
    set_rtype(3'b100, 1'b0); check32(32'd11, "R: XOR 10^1");
    set_rtype(3'b001, 1'b0); check32(32'd20, "R: SLL 10<<1");
    set_rtype(3'b101, 1'b0); check32(32'd5,  "R: SRL 10>>1");

    RS1_IDEXE = 32'hFFFF_FFF0; // -16
    RS2_IDEXE = 32'd1;
    set_rtype(3'b101, 1'b1); check32(32'hFFFF_FFF8, "R: SRA -16>>>1 == -8");

    RS1_IDEXE = 32'hFFFF_FFFF; // -1
    RS2_IDEXE = 32'd1;
    set_rtype(3'b010, 1'b0); check32(32'd1, "R: SLT  (-1 < 1) signed");
    set_rtype(3'b011, 1'b0); check32(32'd0, "R: SLTU (0xFFFF_FFFF < 1) unsigned");

    // -------------------------------------------------------------------------
    // 3) I-type ALU ops (OpA=RS1, OpB=imm)
    // -------------------------------------------------------------------------
    init_base();
    mux_rs1_imm();
    RS1_IDEXE = 32'd10;

    imm = 32'd123;
    set_itype(3'b000, 1'b0); check32(32'd133, "I: ADDI 10+123");

    imm = 32'h0000_00F0;
    set_itype(3'b111, 1'b0); check32(32'd10 & 32'h0000_00F0, "I: ANDI 10 & 0xF0");

    imm = 32'h0000_0003;
    set_itype(3'b110, 1'b0); check32(32'd10 | 32'd3, "I: ORI 10 | 3");

    imm = 32'h0000_000B;
    set_itype(3'b100, 1'b0); check32(32'd10 ^ 32'd11, "I: XORI 10 ^ 11");

    imm = 32'd20;
    set_itype(3'b010, 1'b0); check32(32'd1, "I: SLTI 10 < 20 signed");

    RS1_IDEXE = 32'hFFFF_FFFF; // -1
    imm = 32'd0;
    set_itype(3'b010, 1'b0); check32(32'd1, "I: SLTI -1 < 0 signed");

    // SLTIU: 0xFFFF_FFFF < 0 unsigned => 0
    set_itype(3'b011, 1'b0); check32(32'd0, "I: SLTIU 0xFFFF_FFFF < 0 unsigned");

    // I-type shifts (shamt = imm[4:0])
    RS1_IDEXE = 32'd16;
    imm = 32'd4;
    set_itype(3'b001, 1'b0); check32(32'd256, "I: SLLI 16<<4");

    RS1_IDEXE = 32'd256;
    imm = 32'd3;
    set_itype(3'b101, 1'b0); check32(32'd32, "I: SRLI 256>>3");

    RS1_IDEXE = 32'hFFFF_FFF0; // -16
    imm = 32'd1;
    set_itype(3'b101, 1'b1); check32(32'hFFFF_FFF8, "I: SRAI -16>>>1 == -8");

    // -------------------------------------------------------------------------
    // 4) LOAD/STORE effective address: base + imm
    // -------------------------------------------------------------------------
    init_base();
    RS1_IDEXE = 32'd1000;
    imm       = 32'd64;
    mux_rs1_imm();

    set_load(3'b010);  check32(32'd1064, "LOAD: base+imm (LW)");
    set_load(3'b000);  check32(32'd1064, "LOAD: base+imm (LB)");
    set_store(3'b010); check32(32'd1064, "STORE: base+imm (SW)");
    set_store(3'b000); check32(32'd1064, "STORE: base+imm (SB)");

    // -------------------------------------------------------------------------
    // 5) U-type AUIPC-like behavior: PC + imm (if OpA_sel supports PC)
    //     LUI is intentionally NOT tested here (WB mux responsibility).
    // -------------------------------------------------------------------------
    init_base();
    PC  = 32'd2000;
    PC4 = 32'd2004;
    imm = 32'd256;

    mux_pc_imm();
    set_utype();
    check32(32'd2256, "U_TYPE: AUIPC-like PC+imm");

    // -------------------------------------------------------------------------
    // 6) NOP behavior: EXE_Control maps NOP to ADD
    //     If you want a 0 output for a bubble, drive operands to 0.
    // -------------------------------------------------------------------------
    init_base();
    set_nop();
    RS1_IDEXE = 32'd0;
    RS2_IDEXE = 32'd0;
    mux_rs1_rs2();
    check32(32'd0, "NOP: with zero operands => 0");

    // -------------------------------------------------------------------------
    // 7) Illegal select behavior: defaults should fall back to no-forward path
    //     (Your Execute_Unit sets safe defaults before the case statements.)
    // -------------------------------------------------------------------------
    init_base();
    set_rtype(3'b000, 1'b0); // ADD
    RS1_sel = 2'b11; // illegal -> keep default RS1_IDEXE
    RS2_sel = 2'b11; // illegal -> keep default RS2_IDEXE
    OpA_sel = 2'b11; // illegal -> keep default OpA=RS1_IDEXE
    OpB_sel = 1'b0;  // RS2
    check32(32'd11, "Illegal selects: fall back to defaults (10+1)");

    // -------------------------------------------------------------------------
    // Summary
    // -------------------------------------------------------------------------
    $display("---- SUMMARY ----");
    $display("PASS: %0d", pass_cnt);
    $display("FAIL: %0d", fail_cnt);
    if (fail_cnt == 0) $display("OVERALL: PASS");
    else               $display("OVERALL: FAIL");

    $finish;
  end

endmodule



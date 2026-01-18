//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/18/2026 12:42:40 PM
// Design Name: Execute Unit
// Module Name: Execute_Unit_tb
// Project Name: 32-Bit CPU Senior Project Design 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
`include "Def.vh"

module Execute_Unit_tb;

    // DUT inputs
    logic [31:0] PC, PC4;
    logic [31:0] RS1_IDEXE, RS1_EXEMEM, RS1_MEMWB;
    logic [31:0] RS2_IDEXE, RS2_EXEMEM, RS2_MEMWB, imm;

    logic [14:12] func3;
    logic [31:25] func7;
    logic [2:0]   alu_op;

    logic [1:0] RS1_sel, RS2_sel, OpA_sel;
    logic       OpB_sel;

    // DUT output
    logic [31:0] alu_out;

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

    task automatic check32(input logic [31:0] exp, input [255:0] name);
        #1; // settle for purely combinational DUT
        if (alu_out !== exp) begin
            $error("FAIL: %s | expected=0x%08h got=0x%08h", name, exp, alu_out);
        end else begin
            $display("PASS: %s | 0x%08h", name, alu_out);
        end
    endtask

    // Configure decode for R/I types 
    task automatic set_rtype(input logic [2:0] f3, input logic f7_30);
        alu_op = `R_TYPE;
        func3  = f3;
        func7  = (f7_30) ? 7'b0100000 : 7'b0000000; // sets func7[30]
    endtask

    task automatic set_itype(input logic [2:0] f3, input logic f7_30);
        alu_op = `I_TYPE;
        func3  = f3;
        func7  = (f7_30) ? 7'b0100000 : 7'b0000000; // sets func7[30]
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

    task automatic set_utype(input logic [2:0] f3);
        alu_op = `U_TYPE;
        func3  = f3;
        func7  = 7'b0000000;
    endtask

    task automatic set_nop();
        alu_op = `NOP;
        func3  = 3'b000;
        func7  = 7'b0000000;
    endtask

    task automatic set_branch(input logic [2:0] f3);
        alu_op = `BRANCH;
        func3  = f3;
        func7  = 7'b0000000;
    endtask

    task automatic set_jump();
        alu_op = `JUMP;
        func3  = 3'b000;
        func7  = 7'b0000000;
    endtask

    // Convenience: drive muxes for common datapaths
    task automatic mux_rs1_rs2();
        RS1_sel = 2'b00; // ID/EXE
        RS2_sel = 2'b00; // ID/EXE
        OpA_sel = 2'b10; // RS1
        OpB_sel = 1'b0;  // RS2
    endtask

    task automatic mux_rs1_imm();
        RS1_sel = 2'b00; // ID/EXE
        RS2_sel = 2'b00; // doesn't matter much
        OpA_sel = 2'b10; // RS1
        OpB_sel = 1'b1;  // imm
    endtask

    task automatic mux_pc_imm();
        RS1_sel = 2'b00;
        RS2_sel = 2'b00;
        OpA_sel = 2'b00; // PC
        OpB_sel = 1'b1;  // imm
    endtask

    // ------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------
    initial begin
        $display("Starting extended Execute_Unit_tb...");

        // Base stimulus
        PC  = 32'd100;
        PC4 = 32'd104;

        RS1_IDEXE  = 32'd10;
        RS1_EXEMEM = 32'd20;
        RS1_MEMWB  = 32'd30;

        RS2_IDEXE  = 32'd1;
        RS2_EXEMEM = 32'd2;
        RS2_MEMWB  = 32'd3;

        imm = 32'd500;

        // -------------------------
        // 1) Mux network regression under ADD
        // -------------------------
        set_rtype(3'b000, 1'b0); // ADD decode
        mux_rs1_rs2();
        check32(32'd11, "ADD: RS1_IDEXE + RS2_IDEXE (10+1)");

        RS1_sel = 2'b10; // MEMWB=30
        check32(32'd31, "ADD: RS1_MEMWB + RS2_IDEXE (30+1)");

        RS2_sel = 2'b01; // EXEMEM=2
        check32(32'd32, "ADD: RS1_MEMWB + RS2_EXEMEM (30+2)");

        OpB_sel = 1'b1; // imm=500
        check32(32'd530, "ADD: RS1_MEMWB + imm (30+500)");

        OpA_sel = 2'b00; // PC=100
        check32(32'd600, "ADD: PC + imm (100+500)");

        // -------------------------
        // 2) R_TYPE ALU ops (OpA=RS1, OpB=RS2)
        // -------------------------
        RS1_IDEXE = 32'd10; RS2_IDEXE = 32'd1;
        mux_rs1_rs2();

        set_rtype(3'b000, 1'b1); check32(32'd9,  "R: SUB 10-1");
        set_rtype(3'b111, 1'b0); check32(32'd0,  "R: AND 10&1");
        set_rtype(3'b110, 1'b0); check32(32'd11, "R: OR  10|1");
        set_rtype(3'b100, 1'b0); check32(32'd11, "R: XOR 10^1");
        set_rtype(3'b001, 1'b0); check32(32'd20, "R: SLL 10<<1");
        set_rtype(3'b101, 1'b0); check32(32'd5,  "R: SRL 10>>1");

        RS1_IDEXE = 32'hFFFF_FFF0; // -16
        set_rtype(3'b101, 1'b1); check32(32'hFFFF_FFF8, "R: SRA -16>>>1 == -8");

        // SLT/SLTU with edge values
        RS1_IDEXE = 32'hFFFF_FFFF; // -1
        RS2_IDEXE = 32'd1;
        set_rtype(3'b010, 1'b0); check32(32'd1, "R: SLT  (-1 < 1) signed");
        set_rtype(3'b011, 1'b0); check32(32'd0, "R: SLTU (0xFFFF_FFFF < 1) unsigned");

        // Restore
        RS1_IDEXE = 32'd10;
        RS2_IDEXE = 32'd1;

        // -------------------------
        // 3) I_TYPE ops (ADDI/ANDI/ORI/XORI/SLTI/SLTIU)
        // -------------------------
        mux_rs1_imm();
        RS1_IDEXE = 32'd10;

        imm = 32'd123;
        set_itype(3'b000, 1'b0); check32(32'd133, "I: ADDI 10+123");

        imm = 32'h0000_00F0;
        set_itype(3'b111, 1'b0); check32(32'(10 & 32'h0000_00F0), "I: ANDI 10 & 0xF0");

        imm = 32'h0000_0003;
        set_itype(3'b110, 1'b0); check32(32'(10 | 3), "I: ORI 10 | 3");

        imm = 32'h0000_000B;
        set_itype(3'b100, 1'b0); check32(32'(10 ^ 11), "I: XORI 10 ^ 11");

        // SLTI: 10 < 20 => 1
        imm = 32'd20;
        set_itype(3'b010, 1'b0); check32(32'd1, "I: SLTI 10 < 20 signed");

        // SLTI: -1 < 0 => 1
        RS1_IDEXE = 32'hFFFF_FFFF; // -1
        imm = 32'd0;
        set_itype(3'b010, 1'b0); check32(32'd1, "I: SLTI -1 < 0 signed");

        // SLTIU: 0xFFFF_FFFF < 0 => 0 (unsigned)
        set_itype(3'b011, 1'b0); check32(32'd0, "I: SLTIU 0xFFFF_FFFF < 0 unsigned");

        // Restore RS1
        RS1_IDEXE = 32'd10;

        // -------------------------
        // 4) I_TYPE shift-immediates (SLLI/SRLI/SRAI)
        //     shamt comes from imm[4:0] in your ALU
        // -------------------------
        mux_rs1_imm();
        RS1_IDEXE = 32'd16;

        imm = 32'd4;               // shamt=4
        set_itype(3'b001, 1'b0);   // SLLI requires func7[30]=0 
        check32(32'd256, "I: SLLI 16<<4");

        RS1_IDEXE = 32'd256;
        imm = 32'd3;               // shamt=3
        set_itype(3'b101, 1'b0);   // SRLI
        check32(32'd32, "I: SRLI 256>>3");

        RS1_IDEXE = 32'hFFFF_FFF0; // -16
        imm = 32'd1;               // shamt=1
        set_itype(3'b101, 1'b1);   // SRAI (func7[30]=1)
        check32(32'hFFFF_FFF8, "I: SRAI -16>>>1 == -8");

        // -------------------------
        // 5) LOAD/STORE effective address (base + imm) for multiple func3 values
        // -------------------------
        RS1_IDEXE = 32'd1000;
        imm       = 32'd64;
        mux_rs1_imm();

        set_load(3'b010);  check32(32'd1064, "LOAD: base+imm (LW style func3=010)");
        set_load(3'b000);  check32(32'd1064, "LOAD: base+imm (LB style func3=000)");
        set_store(3'b010); check32(32'd1064, "STORE: base+imm (SW style func3=010)");
        set_store(3'b000); check32(32'd1064, "STORE: base+imm (SB style func3=000)");

        // -------------------------
        // 6) U_TYPE and NOP paths (your EXE_Control maps them to ADD)
        //    - AUIPC-like: PC + imm
        //    - LUI-like: 0 + imm (using OpA_sel=2'b11 default->0 )
        // -------------------------
        PC  = 32'd2000;
        imm = 32'd256;

        // AUIPC-like
        mux_pc_imm();
        set_utype(3'b000);
        check32(32'd2256, "U_TYPE: PC+imm (AUIPC-like)");

        // LUI-like using OpA default=0 via invalid OpA_sel
        OpA_sel = 2'b11;  // Execute_Unit default => OpA='0
        OpB_sel = 1'b1;   // imm
        set_utype(3'b000);
        check32(32'd256, "U_TYPE: 0+imm (LUI-like via OpA default=0)");

        // NOP: drive selects to defaults that yield 0 result
        set_nop();
        RS1_sel = 2'b11;   // default => RS1=0
        RS2_sel = 2'b11;   // default => RS2=0
        OpA_sel = 2'b10;   // RS1 (0)
        OpB_sel = 1'b0;    // RS2 (0)
        check32(32'd0, "NOP: expect 0 with defaulted operands");

        // -------------------------
        // 7) Branch ops: BEQ/BNE/BLT/BLTU/BGE/BGEU (true & false & equality)
        //    Your ALU returns {31'b0, condition}.
        // -------------------------
        mux_rs1_rs2();

        // BEQ / BNE
        RS1_IDEXE = 32'd42; RS2_IDEXE = 32'd42;
        set_branch(3'b000); check32(32'd1, "BR: BEQ 42==42");
        set_branch(3'b001); check32(32'd0, "BR: BNE 42!=42 (false)");

        RS2_IDEXE = 32'd7;
        set_branch(3'b001); check32(32'd1, "BR: BNE 42!=7 (true)");

        // BLT (signed)
        RS1_IDEXE = 32'hFFFF_FFFF; // -1
        RS2_IDEXE = 32'd1;
        set_branch(3'b100); check32(32'd1, "BR: BLT signed (-1 < 1) true");

        RS1_IDEXE = 32'd5; RS2_IDEXE = 32'd5;
        set_branch(3'b100); check32(32'd0, "BR: BLT signed (5 < 5) false");

        // BLTU (unsigned)
        RS1_IDEXE = 32'd1; RS2_IDEXE = 32'd2;
        set_branch(3'b110); check32(32'd1, "BR: BLTU unsigned (1 < 2) true");

        RS1_IDEXE = 32'hFFFF_FFFF; RS2_IDEXE = 32'd1;
        set_branch(3'b110); check32(32'd0, "BR: BLTU unsigned (0xFFFF_FFFF < 1) false");

        // BGE / BGEU 
        RS1_IDEXE = 32'd5; RS2_IDEXE = 32'd5;
        set_branch(3'b101); check32(32'd1, "BR: BGE signed (5 >= 5) true (equality)");
        set_branch(3'b111); check32(32'd1, "BR: BGEU unsigned (5 >= 5) true (equality)");

        // BGE/BGEU true/false non-equality
        RS1_IDEXE = 32'd10; RS2_IDEXE = 32'd7;
        set_branch(3'b101); check32(32'd1, "BR: BGE signed (10 >= 7) true");

        RS1_IDEXE = 32'd7; RS2_IDEXE = 32'd10;
        set_branch(3'b101); check32(32'd0, "BR: BGE signed (7 >= 10) false");

        RS1_IDEXE = 32'd10; RS2_IDEXE = 32'd7;
        set_branch(3'b111); check32(32'd1, "BR: BGEU unsigned (10 >= 7) true");

        RS1_IDEXE = 32'd7; RS2_IDEXE = 32'd10;
        set_branch(3'b111); check32(32'd0, "BR: BGEU unsigned (7 >= 10) false");

        // -------------------------
        // 8) Jump return address (pc_plus_4 uses OpA + 4)
        // -------------------------
        PC = 32'd1000;
        OpA_sel = 2'b00; // OpA=PC
        OpB_sel = 1'b0;  // don't care
        set_jump();
        check32(32'd1004, "JUMP: PC+4");

        // -------------------------
        // 9) Explicit illegal-select behavior (defaults)
        // -------------------------
        // RS1_sel/RS2_sel illegal -> RS1/RS2 = 0; OpA_sel illegal -> OpA=0
        // With ADD decode and OpB_sel=0, output should be 0.
        set_rtype(3'b000, 1'b0); // ADD
        RS1_sel = 2'b11;
        RS2_sel = 2'b11;
        OpA_sel = 2'b11;
        OpB_sel = 1'b0;
        check32(32'd0, "Illegal selects: expect 0 (all defaults)");

        $display("Extended Execute_Unit_tb complete.");
        $finish;
    end

endmodule


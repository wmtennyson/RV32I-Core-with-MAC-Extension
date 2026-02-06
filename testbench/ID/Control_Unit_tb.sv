`timescale 1ns/1ps
`include "Def.vh"

module Control_Unit_tb;

  // -----------------------------
  // DUT I/O
  // -----------------------------
  logic [6:0] opcode;

  logic regwrite, mem_read, mem_write, branch, jump, write_data, OpA_sel, OpB_sel, lui, is_jalr;
  logic [2:0] alu_op;

  Control_Unit dut (
    .opcode(opcode),
    .regwrite(regwrite),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .branch(branch),
    .jump(jump),
    .write_data(write_data),
    .OpA_sel(OpA_sel),
    .OpB_sel(OpB_sel),
    .lui(lui),
    .is_jalr(is_jalr),
    .alu_op(alu_op)
  );

  int tests  = 0;
  int errors = 0;

  // -----------------------------
  // Golden model expectations
  // -----------------------------
  task automatic calc_expected(
    input  logic [6:0] op,

    output logic exp_regwrite,
    output logic exp_mem_read,
    output logic exp_mem_write,
    output logic exp_branch,
    output logic exp_jump,
    output logic exp_write_data,
    output logic exp_OpA_sel,
    output logic exp_OpB_sel,
    output logic exp_lui,
    output logic exp_is_jalr,
    output logic [2:0] exp_alu_op
  );
    begin
      // defaults
      exp_regwrite   = 1'b0;
      exp_mem_read   = 1'b0;
      exp_mem_write  = 1'b0;
      exp_branch     = 1'b0;
      exp_jump       = 1'b0;
      exp_write_data = 1'b0;
      exp_OpA_sel    = 1'b0;
      exp_OpB_sel    = 1'b0;
      exp_lui        = 1'b0;
      exp_is_jalr    = 1'b0;
      exp_alu_op     = `NOP;

      unique case (op)
        7'b0110011: begin // R-type
          exp_regwrite = 1'b1;
          exp_alu_op   = `R_TYPE;
        end

        7'b0010011: begin // I-type
          exp_regwrite = 1'b1;
          exp_OpB_sel  = 1'b1;
          exp_alu_op   = `I_TYPE;
        end

        7'b0000011: begin // Load
          exp_regwrite   = 1'b1;
          exp_mem_read   = 1'b1;
          exp_OpB_sel    = 1'b1;
          exp_write_data = 1'b1;
          exp_alu_op     = `LOAD;
        end

        7'b0100011: begin // Store
          exp_mem_write = 1'b1;
          exp_OpB_sel   = 1'b1;
          exp_alu_op    = `STORE;
        end

        7'b1100011: begin // Branch
          exp_branch = 1'b1;
          exp_alu_op = `BRANCH;
        end

        7'b1101111, 7'b1100111: begin // JAL / JALR
          exp_regwrite = 1'b1;
          exp_jump     = 1'b1;
          exp_OpA_sel  = 1'b1;
          exp_is_jalr  = (op == 7'b1100111);
          exp_alu_op   = `JUMP;
        end

        7'b0110111, 7'b0010111: begin // LUI / AUIPC
          exp_regwrite = 1'b1;
          exp_OpB_sel  = 1'b1;
          exp_OpA_sel  = (op == 7'b0010111); // AUIPC
          exp_lui      = (op == 7'b0110111); // LUI
          exp_alu_op   = `U_TYPE;
        end

        default: ; // keep defaults
      endcase
    end
  endtask

  // -----------------------------
  // Apply + check helper
  // -----------------------------
  task automatic apply_and_check(input logic [6:0] op, input string name);
    logic exp_regwrite, exp_mem_read, exp_mem_write, exp_branch, exp_jump, exp_write_data;
    logic exp_OpA_sel, exp_OpB_sel, exp_lui, exp_is_jalr;
    logic [2:0] exp_alu_op;

    begin
      tests++;
      opcode = op;
      #1ns; // settle combinational

      calc_expected(op,
        exp_regwrite, exp_mem_read, exp_mem_write, exp_branch, exp_jump, exp_write_data,
        exp_OpA_sel, exp_OpB_sel, exp_lui, exp_is_jalr, exp_alu_op
      );

      if (regwrite   !== exp_regwrite ||
          mem_read   !== exp_mem_read ||
          mem_write  !== exp_mem_write ||
          branch     !== exp_branch ||
          jump       !== exp_jump ||
          write_data !== exp_write_data ||
          OpA_sel    !== exp_OpA_sel ||
          OpB_sel    !== exp_OpB_sel ||
          lui        !== exp_lui ||
          is_jalr    !== exp_is_jalr ||
          alu_op     !== exp_alu_op) begin

        errors++;
        $display("FAIL [%0d] %s (opcode=%b)", tests, name, op);
        $display("  Expected: RegW=%0b MemR=%0b MemW=%0b Br=%0b J=%0b WD=%0b OpA=%0b OpB=%0b LUI=%0b JALR=%0b ALUOP=%b",
                 exp_regwrite, exp_mem_read, exp_mem_write, exp_branch, exp_jump, exp_write_data,
                 exp_OpA_sel, exp_OpB_sel, exp_lui, exp_is_jalr, exp_alu_op);
        $display("  Got     : RegW=%0b MemR=%0b MemW=%0b Br=%0b J=%0b WD=%0b OpA=%0b OpB=%0b LUI=%0b JALR=%0b ALUOP=%b",
                 regwrite, mem_read, mem_write, branch, jump, write_data,
                 OpA_sel, OpB_sel, lui, is_jalr, alu_op);
      end else begin
        $display("PASS [%0d] %s", tests, name);
      end
    end
  endtask

  // -----------------------------
  // Test plan
  // -----------------------------
  initial begin
    opcode = 7'h00;
    #1ns;

    apply_and_check(7'b0110011, "R-type");
    apply_and_check(7'b0010011, "I-type");
    apply_and_check(7'b0000011, "Load");
    apply_and_check(7'b0100011, "Store");
    apply_and_check(7'b1100011, "Branch");
    apply_and_check(7'b1101111, "JAL");
    apply_and_check(7'b1100111, "JALR");
    apply_and_check(7'b0110111, "LUI");
    apply_and_check(7'b0010111, "AUIPC");

    // A few defaults/unknown opcodes -> all defaults
    apply_and_check(7'b1111111, "Default opcode -> NOP controls");
    apply_and_check(7'b0000000, "Default opcode -> NOP controls");
    apply_and_check(7'b1010101, "Default opcode -> NOP controls");

    // Random sweep (sanity regression)
    repeat (200) begin
      apply_and_check($urandom_range(0,127), "Random opcode");
    end

    $display("========================================");
    if (errors == 0) $display("PASS: %0d tests, 0 errors", tests);
    else             $display("FAIL: %0d tests, %0d errors", tests, errors);
    $display("========================================");
    $finish;
  end

endmodule

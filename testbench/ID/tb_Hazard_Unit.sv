`timescale 1ns/1ps

module tb_Hazard_Unit_final;

  // -----------------------------
  // DUT ports
  // -----------------------------
  logic        instr_valid_i;
  logic [6:0]  opcode_i;
  logic [4:0]  rs1_i, rs2_i;

  logic        id_ex_mem_read_i;
  logic [4:0]  id_ex_rd_i;

  logic        ex_mem_mem_read_i;
  logic [4:0]  ex_mem_rd_i;

  logic        stall_o;

  // -----------------------------
  // RISC-V opcodes
  // -----------------------------
  localparam logic [6:0] OP_LUI    = 7'b0110111;
  localparam logic [6:0] OP_AUIPC  = 7'b0010111;
  localparam logic [6:0] OP_JAL    = 7'b1101111;
  localparam logic [6:0] OP_JALR   = 7'b1100111;
  localparam logic [6:0] OP_BRANCH = 7'b1100011;
  localparam logic [6:0] OP_STORE  = 7'b0100011;
  localparam logic [6:0] OP_LOAD   = 7'b0000011;
  localparam logic [6:0] OP_OPIMM  = 7'b0010011;
  localparam logic [6:0] OP_OP     = 7'b0110011;

  // -----------------------------
  // Instantiate DUT (updated hazard unit)
  // -----------------------------
  Hazard_Unit dut (
    .instr_valid_i     (instr_valid_i),
    .opcode_i          (opcode_i),
    .rs1_i             (rs1_i),
    .rs2_i             (rs2_i),
    .id_ex_mem_read_i  (id_ex_mem_read_i),
    .id_ex_rd_i        (id_ex_rd_i),
    .ex_mem_mem_read_i (ex_mem_mem_read_i),
    .ex_mem_rd_i       (ex_mem_rd_i),
    .stall_o           (stall_o)
  );

  // -----------------------------
  // Pass/Fail bookkeeping
  // -----------------------------
  int pass_count = 0;
  int fail_count = 0;

  task automatic defaults();
    begin
      instr_valid_i     = 1'b0;
      opcode_i          = OP_OP;
      rs1_i             = 5'd0;
      rs2_i             = 5'd0;
      id_ex_mem_read_i  = 1'b0;
      id_ex_rd_i        = 5'd0;
      ex_mem_mem_read_i = 1'b0;
      ex_mem_rd_i       = 5'd0;
    end
  endtask

  task automatic check(input logic exp, input string name);
    begin
      #1; // settle combinational logic

      // Treat X/Z as fail (should always be 0 or 1)
      if ($isunknown(stall_o)) begin
        fail_count++;
        $display("FAIL: %-70s | stall_o is X/Z (%b)", name, stall_o);
      end
      else if (stall_o === exp) begin
        pass_count++;
        $display("PASS: %-70s | stall_o=%0b", name, stall_o);
      end
      else begin
        fail_count++;
        $display("FAIL: %-70s | expected=%0b got=%0b", name, exp, stall_o);
      end
    end
  endtask

  // -----------------------------
  // Tests
  // -----------------------------
  initial begin
    defaults();
    #1;

    // 1) Invalid instruction => never stall
    instr_valid_i     = 1'b0;
    opcode_i          = OP_OP;
    rs1_i             = 5'd5;
    rs2_i             = 5'd6;
    id_ex_mem_read_i  = 1'b1;
    id_ex_rd_i        = 5'd5;
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd6;
    check(1'b0, "instr_valid=0 => no stall even if hazard-like signals present");

    // 2) Classic load-use: ID/EX load, R-type uses rs1/rs2, rd matches rs1 => stall
    defaults();
    instr_valid_i    = 1'b1;
    opcode_i         = OP_OP;
    rs1_i            = 5'd10;
    rs2_i            = 5'd3;
    id_ex_mem_read_i = 1'b1;
    id_ex_rd_i       = 5'd10;
    check(1'b1, "ID/EX load-use (R-type) rd matches rs1 => stall");

    // 3) Classic load-use: ID/EX load, R-type rd matches rs2 => stall
    defaults();
    instr_valid_i    = 1'b1;
    opcode_i         = OP_OP;
    rs1_i            = 5'd1;
    rs2_i            = 5'd11;
    id_ex_mem_read_i = 1'b1;
    id_ex_rd_i       = 5'd11;
    check(1'b1, "ID/EX load-use (R-type) rd matches rs2 => stall");

    // 4) I-type OP-IMM uses rs1 only: rd matches rs2 field should NOT stall (prevents false stalls)
    defaults();
    instr_valid_i    = 1'b1;
    opcode_i         = OP_OPIMM;   // uses rs1 only
    rs1_i            = 5'd2;
    rs2_i            = 5'd7;       // would be imm[4:0] in real encoding
    id_ex_mem_read_i = 1'b1;
    id_ex_rd_i       = 5'd7;
    check(1'b0, "OP-IMM uses rs1 only; rd matches rs2 field => no stall");

    // 5) I-type OP-IMM: rd matches rs1 => stall
    defaults();
    instr_valid_i    = 1'b1;
    opcode_i         = OP_OPIMM;
    rs1_i            = 5'd7;
    rs2_i            = 5'd0;
    id_ex_mem_read_i = 1'b1;
    id_ex_rd_i       = 5'd7;
    check(1'b1, "OP-IMM uses rs1; rd matches rs1 => stall");

    // 6) STORE uses rs1 and rs2: rd matches rs2 => stall
    defaults();
    instr_valid_i    = 1'b1;
    opcode_i         = OP_STORE;
    rs1_i            = 5'd4;
    rs2_i            = 5'd12;
    id_ex_mem_read_i = 1'b1;
    id_ex_rd_i       = 5'd12;
    check(1'b1, "STORE uses rs1/rs2; rd matches rs2 => stall");

    // 7) rd == x0 should never create hazard
    defaults();
    instr_valid_i    = 1'b1;
    opcode_i         = OP_OP;
    rs1_i            = 5'd0;
    rs2_i            = 5'd5;
    id_ex_mem_read_i = 1'b1;
    id_ex_rd_i       = 5'd0;
    check(1'b0, "ID/EX load with rd=x0 => no stall");

    // 8) LUI uses no regs: even if rd matches rs1/rs2, no stall
    defaults();
    instr_valid_i    = 1'b1;
    opcode_i         = OP_LUI;
    rs1_i            = 5'd9;
    rs2_i            = 5'd9;
    id_ex_mem_read_i = 1'b1;
    id_ex_rd_i       = 5'd9;
    check(1'b0, "LUI uses no regs; ID/EX load rd matches => no stall");

    // 9) EX/MEM load hazard should stall ONLY for BRANCH/JALR (needs operand in ID)
    //    BRANCH uses rs1/rs2 and needs compare in ID => stall when EX/MEM rd matches rs1
    defaults();
    instr_valid_i     = 1'b1;
    opcode_i          = OP_BRANCH;
    rs1_i             = 5'd6;
    rs2_i             = 5'd7;
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd6;
    check(1'b1, "EX/MEM load + BRANCH rd matches rs1 => stall");

    // 10) EX/MEM load + BRANCH rd matches rs2 => stall
    defaults();
    instr_valid_i     = 1'b1;
    opcode_i          = OP_BRANCH;
    rs1_i             = 5'd1;
    rs2_i             = 5'd8;
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd8;
    check(1'b1, "EX/MEM load + BRANCH rd matches rs2 => stall");

    // 11) EX/MEM load + R-type (not branch/jalr) should NOT stall (gated)
    defaults();
    instr_valid_i     = 1'b1;
    opcode_i          = OP_OP;
    rs1_i             = 5'd6;
    rs2_i             = 5'd2;
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd6;
    check(1'b0, "EX/MEM load + R-type rd matches rs1 => no stall (not branch/jalr)");

    // 12) EX/MEM load + JALR needs rs1 in ID => stall when rd matches rs1
    defaults();
    instr_valid_i     = 1'b1;
    opcode_i          = OP_JALR;
    rs1_i             = 5'd13;
    rs2_i             = 5'd0;
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd13;
    check(1'b1, "EX/MEM load + JALR rd matches rs1 => stall");

    // 13) EX/MEM load + JAL (uses no regs) => no stall
    defaults();
    instr_valid_i     = 1'b1;
    opcode_i          = OP_JAL;
    rs1_i             = 5'd13;
    rs2_i             = 5'd13;
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd13;
    check(1'b0, "EX/MEM load + JAL uses no regs => no stall");

    // 14) Both hazards present: ID/EX load-use should stall (regardless of EX/MEM gating)
    defaults();
    instr_valid_i     = 1'b1;
    opcode_i          = OP_BRANCH; // also needs ID operand
    rs1_i             = 5'd3;
    rs2_i             = 5'd4;
    id_ex_mem_read_i  = 1'b1;
    id_ex_rd_i        = 5'd3;      // triggers classic load-use
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd4;
    check(1'b1, "ID/EX load-use + EX/MEM load + BRANCH => stall");

    // -----------------------------
    // Summary
    // -----------------------------
    $display("\n====================================================");
    $display("Hazard_Unit FINAL TB Summary: PASS=%0d  FAIL=%0d", pass_count, fail_count);
    $display("====================================================\n");

    if (fail_count != 0) $fatal(1, "Hazard_Unit testbench: one or more cases FAILED.");
    else                 $finish;
  end

endmodule

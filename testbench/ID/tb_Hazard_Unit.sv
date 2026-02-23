`timescale 1ns/1ps

module tb_Hazard_Unit;

  // -----------------------------
  // DUT inputs
  // -----------------------------
  logic        instr_valid_i;
  logic [6:0]  opcode_i;
  logic [4:0]  rs1_i, rs2_i;

  logic        id_ex_mem_read_i;
  logic [4:0]  id_ex_rd_i;

  logic        ex_mem_mem_read_i;
  logic [4:0]  ex_mem_rd_i;

  // DUT output
  logic        stall_o;

  // -----------------------------
  // Opcode localparams (RISC-V)
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
  // Instantiate DUT
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
  // Simple pass/fail scoreboard
  // -----------------------------
  int pass_count = 0;
  int fail_count = 0;

  task automatic apply_defaults();
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

  task automatic check_case(input logic expected, input string name);
    begin
      #1; // allow combinational settle
      if (stall_o === expected) begin
        pass_count++;
        $display("PASS: %-55s | stall_o=%0b", name, stall_o);
      end else begin
        fail_count++;
        $display("FAIL: %-55s | expected=%0b got=%0b", name, expected, stall_o);
      end
    end
  endtask

  // -----------------------------
  // Test sequence
  // -----------------------------
  initial begin
    apply_defaults();
    #1;

    // 1) instr_valid=0 should never stall (even if hazard-like signals present)
    instr_valid_i     = 1'b0;
    opcode_i          = OP_OP;
    rs1_i             = 5'd5;
    rs2_i             = 5'd6;
    id_ex_mem_read_i  = 1'b1;
    id_ex_rd_i        = 5'd5;
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd6;
    check_case(1'b0, "Invalid instruction => no stall");

    // 2) Classic load-use: ID/EX load rd matches rs1 of R-type => stall
    apply_defaults();
    instr_valid_i    = 1'b1;
    opcode_i         = OP_OP;      // R-type uses rs1,rs2
    rs1_i            = 5'd5;
    rs2_i            = 5'd1;
    id_ex_mem_read_i = 1'b1;
    id_ex_rd_i       = 5'd5;
    check_case(1'b1, "ID/EX load-use (R-type) rd matches rs1 => stall");

    // 3) No false stall on I-type "rs2 field" (imm[4:0]): only rs1 is used
    //    Set rs2_i equal to ID/EX rd, but rs1_i does NOT match => should NOT stall
    apply_defaults();
    instr_valid_i    = 1'b1;
    opcode_i         = OP_OPIMM;   // I-type ALU uses rs1 only
    rs1_i            = 5'd1;
    rs2_i            = 5'd5;       // looks like a reg, but is immediate field in real encoding
    id_ex_mem_read_i = 1'b1;
    id_ex_rd_i       = 5'd5;
    check_case(1'b0, "I-type uses rs1 only; rd matches rs2 field => no stall");

    // 4) Classic load-use: store uses rs1 and rs2, match on rs2 => stall
    apply_defaults();
    instr_valid_i    = 1'b1;
    opcode_i         = OP_STORE;   // store uses rs1,rs2
    rs1_i            = 5'd2;
    rs2_i            = 5'd5;
    id_ex_mem_read_i = 1'b1;
    id_ex_rd_i       = 5'd5;
    check_case(1'b1, "ID/EX load-use (STORE) rd matches rs2 => stall");

    // 5) rd==x0 should never trigger hazard stall
    apply_defaults();
    instr_valid_i    = 1'b1;
    opcode_i         = OP_OP;
    rs1_i            = 5'd0;
    rs2_i            = 5'd0;
    id_ex_mem_read_i = 1'b1;
    id_ex_rd_i       = 5'd0;
    check_case(1'b0, "ID/EX load rd=x0 => no stall");

    // 6) EX/MEM load hazard should stall ONLY for branch/jalr (needs operand in ID)
    //    Branch uses rs1/rs2; EX/MEM load rd matches rs1 => stall
    apply_defaults();
    instr_valid_i     = 1'b1;
    opcode_i          = OP_BRANCH;
    rs1_i             = 5'd7;
    rs2_i             = 5'd8;
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd7;
    check_case(1'b1, "EX/MEM load + BRANCH rd matches rs1 => stall");

    // 7) EX/MEM load hazard should NOT stall for normal ALU op (consumer can wait for forwarding later)
    apply_defaults();
    instr_valid_i     = 1'b1;
    opcode_i          = OP_OP;      // R-type, but NOT branch/jalr
    rs1_i             = 5'd7;
    rs2_i             = 5'd1;
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd7;
    check_case(1'b0, "EX/MEM load + R-type rd matches rs1 => no stall (not branch/jalr)");

    // 8) EX/MEM load hazard + JALR base register needed in ID => stall
    apply_defaults();
    instr_valid_i     = 1'b1;
    opcode_i          = OP_JALR;    // needs rs1 in ID for target
    rs1_i             = 5'd7;
    rs2_i             = 5'd0;
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd7;
    check_case(1'b1, "EX/MEM load + JALR rd matches rs1 => stall");

    // 9) JAL uses no rs1/rs2 => never stalls even if ex_mem_rd matches
    apply_defaults();
    instr_valid_i     = 1'b1;
    opcode_i          = OP_JAL;     // uses_rs1=0 uses_rs2=0
    rs1_i             = 5'd7;
    rs2_i             = 5'd7;
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd7;
    check_case(1'b0, "JAL uses no regs; EX/MEM load rd matches => no stall");

    // 10) Both hazards present: ID/EX load-use should stall regardless
    apply_defaults();
    instr_valid_i     = 1'b1;
    opcode_i          = OP_BRANCH; // uses rs1/rs2 and needs operand in ID
    rs1_i             = 5'd3;
    rs2_i             = 5'd4;
    id_ex_mem_read_i  = 1'b1;
    id_ex_rd_i        = 5'd3;      // triggers classic load-use
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd4;      // would also trigger branch hazard
    check_case(1'b1, "ID/EX load-use + EX/MEM load + BRANCH => stall");

    // 11) EX/MEM load + BRANCH hazard via rs2 match => stall
    apply_defaults();
    instr_valid_i     = 1'b1;
    opcode_i          = OP_BRANCH;
    rs1_i             = 5'd1;
    rs2_i             = 5'd9;
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd9;
    check_case(1'b1, "EX/MEM load + BRANCH rd matches rs2 => stall");

    // Summary
    $display("\n--------------------------------------------");
    $display("Hazard_Unit TB Summary: PASS=%0d FAIL=%0d", pass_count, fail_count);
    $display("--------------------------------------------\n");

    if (fail_count != 0) $fatal(1, "One or more Hazard_Unit test cases FAILED.");
    else                 $finish;
  end

endmodule

`timescale 1ns/1ps

module Forwarding_Unit_tb;

  // -----------------------------
  // DUT inputs
  // -----------------------------
  logic [4:0] IF_ID_rs1, IF_ID_rs2;
  logic [4:0] ID_EX_rd, ID_EX_rs1, ID_EX_rs2;
  logic [4:0] EX_MEM_rd, MEM_WB_rd;

  logic EX_MEM_RegWrite, MEM_WB_RegWrite, ID_EX_RegWrite;
  logic ID_EX_mem_read, EX_MEM_mem_read;

  // -----------------------------
  // DUT outputs
  // -----------------------------
  logic [1:0] BrFwd_A, BrFwd_B, RS1_Sel, RS2_Sel;

  // -----------------------------
  // Instantiate DUT
  // -----------------------------
  Forwarding_Unit dut (
    .IF_ID_rs1(IF_ID_rs1),
    .IF_ID_rs2(IF_ID_rs2),
    .ID_EX_rd(ID_EX_rd),
    .ID_EX_rs1(ID_EX_rs1),
    .ID_EX_rs2(ID_EX_rs2),
    .EX_MEM_rd(EX_MEM_rd),
    .MEM_WB_rd(MEM_WB_rd),
    .EX_MEM_RegWrite(EX_MEM_RegWrite),
    .MEM_WB_RegWrite(MEM_WB_RegWrite),
    .ID_EX_RegWrite(ID_EX_RegWrite),
    .ID_EX_mem_read(ID_EX_mem_read),
    .EX_MEM_mem_read(EX_MEM_mem_read),
    .BrFwd_A(BrFwd_A),
    .BrFwd_B(BrFwd_B),
    .RS1_Sel(RS1_Sel),
    .RS2_Sel(RS2_Sel)
  );

  int errors = 0;
  int tests  = 0;

  // -----------------------------
  // Golden model (expected outputs)
  // -----------------------------
  task automatic calc_expected(
    output logic [1:0] exp_BrA,
    output logic [1:0] exp_BrB,
    output logic [1:0] exp_RS1,
    output logic [1:0] exp_RS2
  );
    logic ex_match_rs1, ex_match_rs2, mem_match_rs1, mem_match_rs2;

    logic ex_alu_valid, exmem_alu_valid;
    logic id_ex_match_br_rs1, id_ex_match_br_rs2;
    logic exmem_match_br_rs1, exmem_match_br_rs2;
    logic memwb_match_br_rs1, memwb_match_br_rs2;

    begin
      // Defaults
      exp_BrA = 2'b00;
      exp_BrB = 2'b00;
      exp_RS1 = 2'b00;
      exp_RS2 = 2'b00;

      // -------- EX forwarding (ALU operand forwarding) --------
      ex_match_rs1  = EX_MEM_RegWrite && (EX_MEM_rd != 5'd0) && (EX_MEM_rd == ID_EX_rs1);
      ex_match_rs2  = EX_MEM_RegWrite && (EX_MEM_rd != 5'd0) && (EX_MEM_rd == ID_EX_rs2);

      mem_match_rs1 = MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == ID_EX_rs1);
      mem_match_rs2 = MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == ID_EX_rs2);

      if (ex_match_rs1)       exp_RS1 = 2'b10;
      else if (mem_match_rs1) exp_RS1 = 2'b01;

      if (ex_match_rs2)       exp_RS2 = 2'b10;
      else if (mem_match_rs2) exp_RS2 = 2'b01;

      // -------- ID (branch) forwarding --------
      ex_alu_valid    = ID_EX_RegWrite  && !ID_EX_mem_read;
      exmem_alu_valid = EX_MEM_RegWrite && !EX_MEM_mem_read;

      id_ex_match_br_rs1  = ex_alu_valid    && (ID_EX_rd  != 5'd0) && (ID_EX_rd  == IF_ID_rs1);
      exmem_match_br_rs1  = exmem_alu_valid && (EX_MEM_rd != 5'd0) && (EX_MEM_rd == IF_ID_rs1);
      memwb_match_br_rs1  = MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == IF_ID_rs1);

      id_ex_match_br_rs2  = ex_alu_valid    && (ID_EX_rd  != 5'd0) && (ID_EX_rd  == IF_ID_rs2);
      exmem_match_br_rs2  = exmem_alu_valid && (EX_MEM_rd != 5'd0) && (EX_MEM_rd == IF_ID_rs2);
      memwb_match_br_rs2  = MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == IF_ID_rs2);

      if (id_ex_match_br_rs1)       exp_BrA = 2'b11;
      else if (exmem_match_br_rs1)  exp_BrA = 2'b10;
      else if (memwb_match_br_rs1)  exp_BrA = 2'b01;

      if (id_ex_match_br_rs2)       exp_BrB = 2'b11;
      else if (exmem_match_br_rs2)  exp_BrB = 2'b10;
      else if (memwb_match_br_rs2)  exp_BrB = 2'b01;
    end
  endtask

  // -----------------------------
  // Apply + check helper
  // -----------------------------
  task automatic apply_and_check(string name);
    logic [1:0] expBrA, expBrB, expRS1, expRS2;
    begin
      tests++;

      // settle combinational logic
      #1ns;

      calc_expected(expBrA, expBrB, expRS1, expRS2);

      if (BrFwd_A !== expBrA ||
          BrFwd_B !== expBrB ||
          RS1_Sel !== expRS1 ||
          RS2_Sel !== expRS2) begin
        errors++;
        $display("FAIL [%0d] %s", tests, name);
        $display("  Inputs: IF/ID rs1=%0d rs2=%0d | ID/EX rd=%0d rs1=%0d rs2=%0d | EX/MEM rd=%0d | MEM/WB rd=%0d",
                 IF_ID_rs1, IF_ID_rs2, ID_EX_rd, ID_EX_rs1, ID_EX_rs2, EX_MEM_rd, MEM_WB_rd);
        $display("          Ctrl : ID_EX(RegW=%0b MemR=%0b) EX_MEM(RegW=%0b MemR=%0b) MEM_WB(RegW=%0b)",
                 ID_EX_RegWrite, ID_EX_mem_read, EX_MEM_RegWrite, EX_MEM_mem_read, MEM_WB_RegWrite);
        $display("  Expected: BrA=%b BrB=%b RS1=%b RS2=%b", expBrA, expBrB, expRS1, expRS2);
        $display("  Got     : BrA=%b BrB=%b RS1=%b RS2=%b", BrFwd_A, BrFwd_B, RS1_Sel, RS2_Sel);
      end else begin
        $display("PASS [%0d] %s", tests, name);
      end
    end
  endtask

  // -----------------------------
  // Test sequence
  // -----------------------------
  initial begin
    // Default everything to 0
    IF_ID_rs1 = 0; IF_ID_rs2 = 0;
    ID_EX_rd  = 0; ID_EX_rs1 = 0; ID_EX_rs2 = 0;
    EX_MEM_rd = 0; MEM_WB_rd = 0;

    EX_MEM_RegWrite = 0; MEM_WB_RegWrite = 0; ID_EX_RegWrite = 0;
    ID_EX_mem_read  = 0; EX_MEM_mem_read = 0;

    apply_and_check("Default (no hazards) => all 00");

    // ---------------- EX forwarding directed tests ----------------
    // EX/MEM forwards to RS1
    ID_EX_rs1 = 5'd7; EX_MEM_rd = 5'd7; EX_MEM_RegWrite = 1;
    apply_and_check("EX fwd: RS1 from EX/MEM => RS1_Sel=10");
    EX_MEM_RegWrite = 0; EX_MEM_rd = 0; ID_EX_rs1 = 0;

    // MEM/WB forwards to RS2
    ID_EX_rs2 = 5'd9; MEM_WB_rd = 5'd9; MEM_WB_RegWrite = 1;
    apply_and_check("MEM fwd: RS2 from MEM/WB => RS2_Sel=01");
    MEM_WB_RegWrite = 0; MEM_WB_rd = 0; ID_EX_rs2 = 0;

    // Priority: EX/MEM beats MEM/WB for RS1
    ID_EX_rs1 = 5'd3;
    EX_MEM_rd = 5'd3; EX_MEM_RegWrite = 1;
    MEM_WB_rd = 5'd3; MEM_WB_RegWrite = 1;
    apply_and_check("Priority: RS1 EX/MEM beats MEM/WB => RS1_Sel=10");
    EX_MEM_RegWrite = 0; MEM_WB_RegWrite = 0; EX_MEM_rd = 0; MEM_WB_rd = 0; ID_EX_rs1 = 0;

    // rd == x0 should never forward
    ID_EX_rs1 = 5'd0;
    EX_MEM_rd = 5'd0; EX_MEM_RegWrite = 1;
    MEM_WB_rd = 5'd0; MEM_WB_RegWrite = 1;
    apply_and_check("No forward on rd==x0 => RS1_Sel=00");
    EX_MEM_RegWrite = 0; MEM_WB_RegWrite = 0; EX_MEM_rd = 0; MEM_WB_rd = 0;

    // ---------------- ID (branch) forwarding directed tests ----------------
    // EX->ID branch forward (valid ALU producer in EX)
    IF_ID_rs1 = 5'd10;
    ID_EX_rd = 5'd10; ID_EX_RegWrite = 1; ID_EX_mem_read = 0;
    apply_and_check("Branch fwd: BrA from EX (valid) => BrFwd_A=11");
    ID_EX_RegWrite = 0; ID_EX_rd = 0; IF_ID_rs1 = 0;

    // EX->ID should be blocked for load in EX (mem_read=1)
    IF_ID_rs1 = 5'd6;
    ID_EX_rd = 5'd6; ID_EX_RegWrite = 1; ID_EX_mem_read = 1;  // load in EX, invalid for 11
    MEM_WB_rd = 5'd6; MEM_WB_RegWrite = 1;                    // should fall back to 01
    apply_and_check("Branch fwd: EX is load => BrA should NOT be 11; falls to MEM/WB => BrFwd_A=01");
    MEM_WB_RegWrite = 0; MEM_WB_rd = 0; ID_EX_RegWrite = 0; ID_EX_mem_read = 0; ID_EX_rd = 0; IF_ID_rs1 = 0;

    // EX/MEM->ID branch forward (valid non-load producer in EX/MEM)
    IF_ID_rs2 = 5'd12;
    EX_MEM_rd = 5'd12; EX_MEM_RegWrite = 1; EX_MEM_mem_read = 0;
    apply_and_check("Branch fwd: BrB from EX/MEM (valid) => BrFwd_B=10");
    EX_MEM_RegWrite = 0; EX_MEM_rd = 0; IF_ID_rs2 = 0;

    // EX/MEM branch forward blocked if EX/MEM is a load (mem_read=1), use MEM/WB if matches
    IF_ID_rs2 = 5'd13;
    EX_MEM_rd = 5'd13; EX_MEM_RegWrite = 1; EX_MEM_mem_read = 1; // load in EX/MEM => invalid for branch forward
    MEM_WB_rd = 5'd13; MEM_WB_RegWrite = 1;
    apply_and_check("Branch fwd: EX/MEM is load => ignore 10, use MEM/WB => BrFwd_B=01");
    EX_MEM_RegWrite = 0; EX_MEM_mem_read = 0; EX_MEM_rd = 0;
    MEM_WB_RegWrite = 0; MEM_WB_rd = 0; IF_ID_rs2 = 0;

    // Branch priority: EX beats EX/MEM beats MEM/WB
    IF_ID_rs1 = 5'd20;
    ID_EX_rd = 5'd20; ID_EX_RegWrite = 1; ID_EX_mem_read = 0;
    EX_MEM_rd = 5'd20; EX_MEM_RegWrite = 1; EX_MEM_mem_read = 0;
    MEM_WB_rd = 5'd20; MEM_WB_RegWrite = 1;
    apply_and_check("Branch priority: EX wins => BrFwd_A=11");
    ID_EX_RegWrite = 0; ID_EX_rd = 0; IF_ID_rs1 = 0;
    EX_MEM_RegWrite = 0; EX_MEM_rd = 0;
    MEM_WB_RegWrite = 0; MEM_WB_rd = 0;

    // Both branch operands forwarded simultaneously (different sources)
    IF_ID_rs1 = 5'd1; IF_ID_rs2 = 5'd2;
    ID_EX_rd = 5'd1; ID_EX_RegWrite = 1; ID_EX_mem_read = 0;     // rs1 from EX => 11
    MEM_WB_rd = 5'd2; MEM_WB_RegWrite = 1;                       // rs2 from WB => 01
    apply_and_check("Branch both ops: rs1 from EX (11), rs2 from MEM/WB (01)");
    ID_EX_RegWrite = 0; ID_EX_rd = 0; IF_ID_rs1 = 0; IF_ID_rs2 = 0;
    MEM_WB_RegWrite = 0; MEM_WB_rd = 0;

    // ---------------- Random regression ----------------
    repeat (500) begin
      IF_ID_rs1 = $urandom_range(0,31);
      IF_ID_rs2 = $urandom_range(0,31);
      ID_EX_rd  = $urandom_range(0,31);
      ID_EX_rs1 = $urandom_range(0,31);
      ID_EX_rs2 = $urandom_range(0,31);
      EX_MEM_rd = $urandom_range(0,31);
      MEM_WB_rd = $urandom_range(0,31);

      EX_MEM_RegWrite = $urandom_range(0,1);
      MEM_WB_RegWrite = $urandom_range(0,1);
      ID_EX_RegWrite  = $urandom_range(0,1);

      ID_EX_mem_read  = $urandom_range(0,1);
      EX_MEM_mem_read = $urandom_range(0,1);

      apply_and_check("Random");
    end

    // ---------------- Summary ----------------
    $display("========================================");
    if (errors == 0) $display("PASS: %0d tests, 0 errors", tests);
    else             $display("FAIL: %0d tests, %0d errors", tests, errors);
    $display("========================================");
    $finish;
  end

endmodule

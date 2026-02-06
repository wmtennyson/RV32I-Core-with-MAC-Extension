`timescale 1ns/1ps
`include "Def.vh"

module Hazard_Unit_tb;

  // -----------------------------
  // DUT inputs
  // -----------------------------
  logic        ID_regwrite,
               ID_mem_read,
               ID_mem_write,
               ID_branch,
               ID_jump,
               ID_write_data,
               ID_is_jalr;
  logic [2:0]  ID_alu_op;

  logic [4:0]  IF_ID_rs1,
               IF_ID_rs2,
               ID_EX_rd,
               EX_MEM_rd;

  logic        ID_EX_mem_read,
               EX_MEM_mem_read_i;

  logic        redirect_taken;
  logic [31:0] redirect_target;

  // -----------------------------
  // DUT outputs
  // -----------------------------
  logic        fetch_stall,
               fetch_flush,
               ID_EX_flush;
  logic [31:0] target;

  logic        ID_EX_regwrite,
               ID_EX_mem_read_o,
               ID_EX_mem_write,
               ID_EX_branch,
               ID_EX_jump,
               ID_EX_write_data;
  logic [2:0]  ID_EX_alu_op;

  // -----------------------------
  // Instantiate DUT
  // -----------------------------
  Hazard_Unit dut (
    .ID_regwrite(ID_regwrite),
    .ID_mem_read(ID_mem_read),
    .ID_mem_write(ID_mem_write),
    .ID_branch(ID_branch),
    .ID_jump(ID_jump),
    .ID_write_data(ID_write_data),
    .ID_is_jalr(ID_is_jalr),
    .ID_alu_op(ID_alu_op),

    .IF_ID_rs1(IF_ID_rs1),
    .IF_ID_rs2(IF_ID_rs2),
    .ID_EX_rd(ID_EX_rd),
    .EX_MEM_rd(EX_MEM_rd),

    .ID_EX_mem_read(ID_EX_mem_read),
    .EX_MEM_mem_read_i(EX_MEM_mem_read_i),

    .redirect_taken(redirect_taken),
    .redirect_target(redirect_target),

    .fetch_stall(fetch_stall),
    .fetch_flush(fetch_flush),
    .ID_EX_flush(ID_EX_flush),
    .target(target),

    .ID_EX_regwrite(ID_EX_regwrite),
    .ID_EX_mem_read_o(ID_EX_mem_read_o),
    .ID_EX_mem_write(ID_EX_mem_write),
    .ID_EX_branch(ID_EX_branch),
    .ID_EX_jump(ID_EX_jump),
    .ID_EX_write_data(ID_EX_write_data),
    .ID_EX_alu_op(ID_EX_alu_op)
  );

  int errors = 0;
  int tests  = 0;

  // -----------------------------
  // Golden model (expected outputs)
  // -----------------------------
  task automatic calc_expected(
    output logic        exp_fetch_stall,
    output logic        exp_fetch_flush,
    output logic        exp_idex_flush,
    output logic [31:0] exp_target,

    output logic        exp_IDEX_regwrite,
    output logic        exp_IDEX_mem_read_o,
    output logic        exp_IDEX_mem_write,
    output logic        exp_IDEX_branch,
    output logic        exp_IDEX_jump,
    output logic        exp_IDEX_write_data,
    output logic [2:0]  exp_IDEX_alu_op
  );
    logic load_use_hazard;
    logic load_branch_hazard;

    begin
      // defaults (pass-through)
      exp_fetch_stall = 1'b0;
      exp_fetch_flush = 1'b0;
      exp_idex_flush  = 1'b0;
      exp_target      = redirect_target;

      exp_IDEX_regwrite    = ID_regwrite;
      exp_IDEX_mem_read_o  = ID_mem_read;
      exp_IDEX_mem_write   = ID_mem_write;
      exp_IDEX_branch      = ID_branch;
      exp_IDEX_jump        = ID_jump;
      exp_IDEX_write_data  = ID_write_data;
      exp_IDEX_alu_op      = ID_alu_op;

      // hazards (mirror DUT logic exactly)
      load_use_hazard =
          ID_EX_mem_read && (ID_EX_rd != 5'd0) &&
          ((ID_EX_rd == IF_ID_rs1) || (ID_EX_rd == IF_ID_rs2));

      load_branch_hazard =
          (ID_branch || ID_is_jalr) &&
          (
            (ID_EX_mem_read && (ID_EX_rd != 5'd0) &&
              ((ID_EX_rd == IF_ID_rs1) || (ID_EX_rd == IF_ID_rs2)))
            ||
            (EX_MEM_mem_read_i && (EX_MEM_rd != 5'd0) &&
              ((EX_MEM_rd == IF_ID_rs1) || (EX_MEM_rd == IF_ID_rs2)))
          );

      if (load_use_hazard || load_branch_hazard) begin
        // stall + bubble
        exp_fetch_stall = 1'b1;
        exp_idex_flush  = 1'b1;

        exp_IDEX_regwrite    = 1'b0;
        exp_IDEX_mem_read_o  = 1'b0;
        exp_IDEX_mem_write   = 1'b0;
        exp_IDEX_branch      = 1'b0;
        exp_IDEX_jump        = 1'b0;
        exp_IDEX_write_data  = 1'b0;
        exp_IDEX_alu_op      = `NOP;
      end
      else if (redirect_taken) begin
        exp_fetch_flush = 1'b1;
      end
    end
  endtask

  // -----------------------------
  // Apply + check helper
  // -----------------------------
  task automatic apply_and_check(string name);
    logic        exp_fetch_stall, exp_fetch_flush, exp_idex_flush;
    logic [31:0] exp_target;
    logic        exp_IDEX_regwrite, exp_IDEX_mem_read_o, exp_IDEX_mem_write;
    logic        exp_IDEX_branch, exp_IDEX_jump, exp_IDEX_write_data;
    logic [2:0]  exp_IDEX_alu_op;

    begin
      tests++;
      #1ns; // settle combinational

      calc_expected(exp_fetch_stall, exp_fetch_flush, exp_idex_flush, exp_target,
                    exp_IDEX_regwrite, exp_IDEX_mem_read_o, exp_IDEX_mem_write,
                    exp_IDEX_branch, exp_IDEX_jump, exp_IDEX_write_data, exp_IDEX_alu_op);

      if (fetch_stall      !== exp_fetch_stall ||
          fetch_flush      !== exp_fetch_flush ||
          ID_EX_flush      !== exp_idex_flush  ||
          target           !== exp_target      ||
          ID_EX_regwrite   !== exp_IDEX_regwrite ||
          ID_EX_mem_read_o !== exp_IDEX_mem_read_o ||
          ID_EX_mem_write  !== exp_IDEX_mem_write ||
          ID_EX_branch     !== exp_IDEX_branch ||
          ID_EX_jump       !== exp_IDEX_jump ||
          ID_EX_write_data !== exp_IDEX_write_data ||
          ID_EX_alu_op     !== exp_IDEX_alu_op) begin

        errors++;
        $display("FAIL [%0d] %s", tests, name);
        $display("  Inputs: ID_branch=%0b ID_jump=%0b ID_is_jalr=%0b | ID_EX_mem_read=%0b EX_MEM_mem_read=%0b redirect_taken=%0b",
                 ID_branch, ID_jump, ID_is_jalr, ID_EX_mem_read, EX_MEM_mem_read_i, redirect_taken);
        $display("          IF/ID rs1=%0d rs2=%0d | ID/EX rd=%0d | EX/MEM rd=%0d",
                 IF_ID_rs1, IF_ID_rs2, ID_EX_rd, EX_MEM_rd);
        $display("  Expected: stall=%0b flush=%0b idex_flush=%0b target=%h",
                 exp_fetch_stall, exp_fetch_flush, exp_idex_flush, exp_target);
        $display("            ctrl: RegW=%0b MemR=%0b MemW=%0b Br=%0b J=%0b WD=%0b ALUOP=%b",
                 exp_IDEX_regwrite, exp_IDEX_mem_read_o, exp_IDEX_mem_write,
                 exp_IDEX_branch, exp_IDEX_jump, exp_IDEX_write_data, exp_IDEX_alu_op);
        $display("  Got     : stall=%0b flush=%0b idex_flush=%0b target=%h",
                 fetch_stall, fetch_flush, ID_EX_flush, target);
        $display("            ctrl: RegW=%0b MemR=%0b MemW=%0b Br=%0b J=%0b WD=%0b ALUOP=%b",
                 ID_EX_regwrite, ID_EX_mem_read_o, ID_EX_mem_write,
                 ID_EX_branch, ID_EX_jump, ID_EX_write_data, ID_EX_alu_op);
      end else begin
        $display("PASS [%0d] %s", tests, name);
      end
    end
  endtask

  // -----------------------------
  // Stimulus
  // -----------------------------
  initial begin
    // baseline defaults
    ID_regwrite = 0; ID_mem_read = 0; ID_mem_write = 0;
    ID_branch = 0; ID_jump = 0; ID_write_data = 0; ID_is_jalr = 0;
    ID_alu_op = `NOP;

    IF_ID_rs1 = 0; IF_ID_rs2 = 0; ID_EX_rd = 0; EX_MEM_rd = 0;
    ID_EX_mem_read = 0; EX_MEM_mem_read_i = 0;

    redirect_taken = 0; redirect_target = 32'h0000_0000;

    apply_and_check("Default: no hazards, no redirect => pass-through, no stall/flush");

    // -----------------------------
    // Load-use hazard tests
    // -----------------------------
    // ID/EX is load to rd=5, IF/ID uses rs1=5
    ID_EX_mem_read = 1; ID_EX_rd = 5'd5;
    IF_ID_rs1 = 5'd5; IF_ID_rs2 = 5'd1;
    ID_regwrite = 1; ID_mem_read = 0; ID_mem_write = 0; ID_branch = 0; ID_jump = 0;
    ID_alu_op = 3'b101;
    apply_and_check("Load-use: ID/EX load feeds IF/ID rs1 => stall + bubble");

    // rd==0 should not stall
    ID_EX_rd = 5'd0;
    IF_ID_rs1 = 5'd0;
    apply_and_check("Load-use: rd==x0 => no stall");

    // reset load-use inputs
    ID_EX_mem_read = 0; ID_EX_rd = 0; IF_ID_rs1 = 0; IF_ID_rs2 = 0;

    // -----------------------------
    // Load -> Branch-in-ID hazard tests
    // -----------------------------
    // Branch in ID depends on load in ID/EX
    ID_branch = 1; ID_is_jalr = 0;
    ID_EX_mem_read = 1; ID_EX_rd = 5'd8;
    IF_ID_rs1 = 5'd8; IF_ID_rs2 = 5'd3;
    apply_and_check("Load->Branch: load in ID/EX produces rs1 for branch => stall + bubble");

    // Branch depends on load in EX/MEM (second cycle of stall)
    ID_EX_mem_read = 0; ID_EX_rd = 0;
    EX_MEM_mem_read_i = 1; EX_MEM_rd = 5'd9;
    IF_ID_rs1 = 5'd2; IF_ID_rs2 = 5'd9;
    apply_and_check("Load->Branch: load in EX/MEM produces rs2 for branch => stall + bubble");

    // JALR behaves like branch-like (rs1 used)
    ID_branch = 0; ID_is_jalr = 1;
    EX_MEM_mem_read_i = 1; EX_MEM_rd = 5'd12;
    IF_ID_rs1 = 5'd12; IF_ID_rs2 = 5'd0;
    apply_and_check("Load->JALR: load in EX/MEM produces jalr base rs1 => stall + bubble");

    // JAL (ID_jump=1 but ID_is_jalr=0): should NOT create load-branch hazard by this unit's logic
    // (Your hazard logic intentionally ignores ID_jump here; this checks no unintended bubble)
    ID_is_jalr = 0;
    ID_jump = 1;
    ID_branch = 0;
    EX_MEM_mem_read_i = 1; EX_MEM_rd = 5'd15;
    IF_ID_rs1 = 5'd15; IF_ID_rs2 = 5'd0;
    apply_and_check("JAL should not be treated as branch-like: no stall (unless load-use)");

    // cleanup branch/jump
    ID_branch = 0; ID_jump = 0; ID_is_jalr = 0;
    EX_MEM_mem_read_i = 0; EX_MEM_rd = 0; IF_ID_rs1 = 0; IF_ID_rs2 = 0;

    // -----------------------------
    // Redirect/flush tests
    // -----------------------------
    redirect_taken = 1;
    redirect_target = 32'h0000_1234;
    apply_and_check("Redirect taken: flush fetch asserted, no stall, controls pass-through");

    // Priority: stall beats redirect
    // Create load-use hazard AND redirect_taken=1, should stall+flush bubble, NOT fetch_flush
    redirect_taken = 1;
    ID_EX_mem_read = 1; ID_EX_rd = 5'd7;
    IF_ID_rs1 = 5'd7; IF_ID_rs2 = 5'd1;
    apply_and_check("Priority: load-use stall beats redirect => fetch_stall=1, fetch_flush=0");

    // cleanup
    redirect_taken = 0; redirect_target = 32'h0;
    ID_EX_mem_read = 0; ID_EX_rd = 0; IF_ID_rs1 = 0; IF_ID_rs2 = 0;

    // -----------------------------
    // Random regression (optional)
    // -----------------------------
    repeat (300) begin
      ID_regwrite    = $urandom_range(0,1);
      ID_mem_read    = $urandom_range(0,1);
      ID_mem_write   = $urandom_range(0,1);
      ID_branch      = $urandom_range(0,1);
      ID_jump        = $urandom_range(0,1);
      ID_write_data  = $urandom_range(0,1);
      ID_is_jalr     = $urandom_range(0,1);
      ID_alu_op      = $urandom_range(0,7);

      IF_ID_rs1      = $urandom_range(0,31);
      IF_ID_rs2      = $urandom_range(0,31);
      ID_EX_rd       = $urandom_range(0,31);
      EX_MEM_rd      = $urandom_range(0,31);

      ID_EX_mem_read     = $urandom_range(0,1);
      EX_MEM_mem_read_i  = $urandom_range(0,1);

      redirect_taken  = $urandom_range(0,1);
      redirect_target = $urandom();

      apply_and_check("Random");
    end

    $display("========================================");
    if (errors == 0) $display("PASS: %0d tests, 0 errors", tests);
    else             $display("FAIL: %0d tests, %0d errors", tests, errors);
    $display("========================================");
    $finish;
  end

endmodule


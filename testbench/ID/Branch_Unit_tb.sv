`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/26/2026 09:07:55 AM
// Design Name: 
// Module Name: Branch_Unit_tb
// Project Name: 
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

module Branch_Unit_tb;

  // DUT inputs
  logic [31:0] pc, pc4, rs1, rs2, imm;
  logic        branch, jump, pcsrc;
  logic [2:0]  funct3;

  // DUT outputs
  logic        redirect;
  logic [31:0] target_pc, link_register;

  Branch_Unit dut (
    .pc(pc), .pc4(pc4),
    .rs1(rs1), .rs2(rs2),
    .imm(imm),
    .branch(branch), .jump(jump), .pcsrc(pcsrc),
    .funct3(funct3),
    .redirect(redirect),
    .target_pc(target_pc),
    .link_register(link_register)
  );

  int pass_cnt = 0;
  int fail_cnt = 0;

  task automatic set_defaults();
    pc     = 32'h0000_1000;
    pc4    = pc + 32'd4;
    rs1    = 32'd0;
    rs2    = 32'd0;
    imm    = 32'd0;
    branch = 1'b0;
    jump   = 1'b0;
    pcsrc  = 1'b0;
    funct3 = 3'b000;
  endtask

  task automatic run_case(
    input string name,
    input logic exp_redirect,
    input logic [31:0] exp_target,
    input logic [31:0] exp_link
  );
    #1; // settle
    if ((redirect === exp_redirect) &&
        (target_pc === exp_target) &&
        (link_register === exp_link)) begin
      pass_cnt++;
      $display("PASS: %s", name);
    end else begin
      fail_cnt++;
      $display("FAIL: %s | got r=%b t=0x%08h l=0x%08h | exp r=%b t=0x%08h l=0x%08h",
               name, redirect, target_pc, link_register, exp_redirect, exp_target, exp_link);
    end
  endtask

  initial begin
    // 0) Baseline fall-through
    set_defaults();
    run_case("baseline_fallthrough", 1'b0, pc4, pc4);

    // BEQ taken
    set_defaults();
    branch = 1'b1; funct3 = 3'b000;
    rs1 = 32'h1234_5678; rs2 = 32'h1234_5678; imm = 32'sd16;
    run_case("beq_taken", 1'b1, pc + imm, pc4);

    // BEQ not taken
    set_defaults();
    branch = 1'b1; funct3 = 3'b000;
    rs1 = 32'h1; rs2 = 32'h2; imm = 32'sd16;
    run_case("beq_not_taken", 1'b0, pc4, pc4);

    // BNE taken (neg imm)
    set_defaults();
    branch = 1'b1; funct3 = 3'b001;
    rs1 = 32'hAAAA_AAAA; rs2 = 32'hBBBB_BBBB; imm = -32'sd8;
    run_case("bne_taken_neg_imm", 1'b1, pc + imm, pc4);

    // BLT signed taken: -1 < 1
    set_defaults();
    branch = 1'b1; funct3 = 3'b100;
    rs1 = 32'hFFFF_FFFF; rs2 = 32'h0000_0001; imm = 32'sd12;
    run_case("blt_signed_taken", 1'b1, pc + imm, pc4);

    // BGE signed not taken: -1 >= 1 false
    set_defaults();
    branch = 1'b1; funct3 = 3'b101;
    rs1 = 32'hFFFF_FFFF; rs2 = 32'h0000_0001; imm = 32'sd12;
    run_case("bge_signed_not_taken", 1'b0, pc4, pc4);

    // BLTU unsigned not taken: 0xFFFF_FFFF < 1 false
    set_defaults();
    branch = 1'b1; funct3 = 3'b110;
    rs1 = 32'hFFFF_FFFF; rs2 = 32'h0000_0001; imm = 32'sd20;
    run_case("bltu_unsigned_not_taken", 1'b0, pc4, pc4);

    // BGEU unsigned taken: 0xFFFF_FFFF >= 1 true
    set_defaults();
    branch = 1'b1; funct3 = 3'b111;
    rs1 = 32'hFFFF_FFFF; rs2 = 32'h0000_0001; imm = 32'sd20;
    run_case("bgeu_unsigned_taken", 1'b1, pc + imm, pc4);

    // JAL redirect + priority over branch
    set_defaults();
    jump = 1'b1; pcsrc = 1'b0; imm = 32'sd128;
    branch = 1'b1; funct3 = 3'b000; rs1 = 32'h1; rs2 = 32'h1; // would be taken, but jump wins anyway
    run_case("jal_priority_over_branch", 1'b1, pc + imm, pc4);

    // JALR redirect + LSB clear (odd sum becomes even)
    set_defaults();
    jump = 1'b1; pcsrc = 1'b1;
    rs1 = 32'h0000_2001; imm = 32'sd6; // sum 0x2007 -> 0x2006
    run_case("jalr_lsb_clear", 1'b1, ((rs1 + imm) & ~32'd1), pc4);

    // Summary
    $display("---- SUMMARY ----");
    $display("PASS: %0d", pass_cnt);
    $display("FAIL: %0d", fail_cnt);

    if (fail_cnt == 0) $display("OVERALL: PASS");
    else               $display("OVERALL: FAIL");

    $finish;
  end

endmodule

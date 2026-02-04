`timescale 1ns/1ps
`include "Def.vh"

module tb_decode_unit;

  // -------------------------
  // Clock / Reset
  // -------------------------
  logic clk, rst;

  localparam time T = 10ns;

  initial clk = 1'b0;
  always #(T/2) clk = ~clk;

  // -------------------------
  // DUT inputs
  // -------------------------
  logic        instr_valid_i;
  logic [31:0] instr_i;
  logic [31:0] pc_i;
  logic [31:0] pc4_i;

  logic        wb_we_i;
  logic [4:0]  wb_rd_i;
  logic [31:0] wb_wdata_i;

  logic [4:0]  id_ex_rd_i, id_ex_rs1_i, id_ex_rs2_i;
  logic        id_ex_regwrite_i, id_ex_mem_read_i;
  logic [31:0] ex_alu_out_i;

  logic [4:0]  ex_mem_rd_i;
  logic        ex_mem_regwrite_i, ex_mem_mem_read_i;
  logic [31:0] ex_mem_alu_out_i;

  logic [4:0]  mem_wb_rd_i;
  logic        mem_wb_regwrite_i;
  logic [31:0] mem_wb_value_i;

  // -------------------------
  // DUT outputs
  // -------------------------
  logic        stall_o, flush_o;
  logic [31:0] branch_target_o;

  logic        id_ex_valid_o;
  logic [31:0] id_ex_pc_o, id_ex_pc4_o, id_ex_rs1_val_o, id_ex_rs2_val_o, id_ex_imm_o;
  logic [4:0]  id_ex_rs1_o, id_ex_rs2_o, id_ex_rd_o;
  logic [2:0]  id_ex_funct3_o;
  logic [6:0]  id_ex_funct7_o;

  logic        id_ex_regwrite_o, id_ex_mem_read_o, id_ex_mem_write_o, id_ex_branch_o, id_ex_jump_o;
  logic        id_ex_write_data_o, id_ex_lui_o, id_ex_is_jalr_o;
  logic [2:0]  id_ex_alu_op_o;

  logic [1:0]  id_ex_opA_sel_o;
  logic        id_ex_opB_sel_o;
  logic [1:0]  id_ex_rs1_sel_o, id_ex_rs2_sel_o;

  // -------------------------
  // Instantiate DUT
  // -------------------------
  decodeunit dut (
    .clk(clk),
    .rst(rst),

    .instr_valid_i(instr_valid_i),
    .instr_i(instr_i),
    .pc_i(pc_i),
    .pc4_i(pc4_i),

    .wb_we_i(wb_we_i),
    .wb_rd_i(wb_rd_i),
    .wb_wdata_i(wb_wdata_i),

    .id_ex_rd_i(id_ex_rd_i),
    .id_ex_rs1_i(id_ex_rs1_i),
    .id_ex_rs2_i(id_ex_rs2_i),
    .id_ex_regwrite_i(id_ex_regwrite_i),
    .id_ex_mem_read_i(id_ex_mem_read_i),
    .ex_alu_out_i(ex_alu_out_i),

    .ex_mem_rd_i(ex_mem_rd_i),
    .ex_mem_regwrite_i(ex_mem_regwrite_i),
    .ex_mem_mem_read_i(ex_mem_mem_read_i),
    .ex_mem_alu_out_i(ex_mem_alu_out_i),

    .mem_wb_rd_i(mem_wb_rd_i),
    .mem_wb_regwrite_i(mem_wb_regwrite_i),
    .mem_wb_value_i(mem_wb_value_i),

    .stall_o(stall_o),
    .flush_o(flush_o),
    .branch_target_o(branch_target_o),

    .id_ex_valid_o(id_ex_valid_o),

    .id_ex_pc_o(id_ex_pc_o),
    .id_ex_pc4_o(id_ex_pc4_o),
    .id_ex_rs1_val_o(id_ex_rs1_val_o),
    .id_ex_rs2_val_o(id_ex_rs2_val_o),
    .id_ex_imm_o(id_ex_imm_o),

    .id_ex_rs1_o(id_ex_rs1_o),
    .id_ex_rs2_o(id_ex_rs2_o),
    .id_ex_rd_o(id_ex_rd_o),
    .id_ex_funct3_o(id_ex_funct3_o),
    .id_ex_funct7_o(id_ex_funct7_o),

    .id_ex_regwrite_o(id_ex_regwrite_o),
    .id_ex_mem_read_o(id_ex_mem_read_o),
    .id_ex_mem_write_o(id_ex_mem_write_o),
    .id_ex_branch_o(id_ex_branch_o),
    .id_ex_jump_o(id_ex_jump_o),
    .id_ex_write_data_o(id_ex_write_data_o),
    .id_ex_lui_o(id_ex_lui_o),
    .id_ex_is_jalr_o(id_ex_is_jalr_o),
    .id_ex_alu_op_o(id_ex_alu_op_o),

    .id_ex_opA_sel_o(id_ex_opA_sel_o),
    .id_ex_opB_sel_o(id_ex_opB_sel_o),
    .id_ex_rs1_sel_o(id_ex_rs1_sel_o),
    .id_ex_rs2_sel_o(id_ex_rs2_sel_o)
  );

  // -------------------------
  // Helpers: instruction encoders
  // -------------------------
  function automatic logic [31:0] enc_addi(input logic [4:0] rd, input logic [4:0] rs1, input int imm);
    logic [11:0] i12;
    begin
      i12 = imm[11:0];
      enc_addi = {i12, rs1, 3'b000, rd, 7'b0010011};
    end
  endfunction

  function automatic logic [31:0] enc_lw(input logic [4:0] rd, input logic [4:0] rs1, input int imm);
    logic [11:0] i12;
    begin
      i12 = imm[11:0];
      enc_lw = {i12, rs1, 3'b010, rd, 7'b0000011};
    end
  endfunction

  function automatic logic [31:0] enc_sw(input logic [4:0] rs2, input logic [4:0] rs1, input int imm);
    logic [11:0] s12;
    begin
      s12 = imm[11:0];
      enc_sw = {s12[11:5], rs2, rs1, 3'b010, s12[4:0], 7'b0100011};
    end
  endfunction

  function automatic logic [31:0] enc_beq(input logic [4:0] rs1, input logic [4:0] rs2, input int imm);
    // imm is byte offset, must be multiple of 2
    logic [12:0] b13;
    begin
      b13 = imm[12:0];
      enc_beq = {b13[12], b13[10:5], rs2, rs1, 3'b000, b13[4:1], b13[11], 7'b1100011};
    end
  endfunction

  function automatic logic [31:0] enc_jal(input logic [4:0] rd, input int imm);
    // imm is byte offset, must be multiple of 2 (J-type)
    logic [20:0] j21;
    begin
      j21 = imm[20:0];
      enc_jal = {j21[20], j21[10:1], j21[11], j21[19:12], rd, 7'b1101111};
    end
  endfunction

  // -------------------------
  // Helpers: sign-extend immediates (tb_checked ImmGen output)
  // -------------------------
  function automatic logic [31:0] sext12(input int imm);
    logic [11:0] i12;
    begin
      i12 = imm[11:0];
      sext12 = {{20{i12[11]}}, i12};
    end
  endfunction

  function automatic logic [31:0] sext13(input int imm);
    logic [12:0] b13;
    begin
      b13 = imm[12:0];
      sext13 = {{19{b13[12]}}, b13};
    end
  endfunction

  // -------------------------
  // Common TB utilities
  // -------------------------
task automatic tb_check(input logic cond, input string msg);
  if (!cond) begin
    $error("FAIL: %s @ t=%0t", msg, $time);
    $fatal(1);
  end
endtask


  task automatic drive_defaults();
    begin
      instr_valid_i     = 1'b0;
      instr_i           = 32'h0000_0013;
      pc_i              = 32'd0;
      pc4_i             = 32'd4;

      wb_we_i           = 1'b0;
      wb_rd_i           = 5'd0;
      wb_wdata_i        = 32'd0;

      id_ex_rd_i        = 5'd0;
      id_ex_rs1_i       = 5'd0;
      id_ex_rs2_i       = 5'd0;
      id_ex_regwrite_i  = 1'b0;
      id_ex_mem_read_i  = 1'b0;
      ex_alu_out_i      = 32'd0;

      ex_mem_rd_i       = 5'd0;
      ex_mem_regwrite_i = 1'b0;
      ex_mem_mem_read_i = 1'b0;
      ex_mem_alu_out_i  = 32'd0;

      mem_wb_rd_i       = 5'd0;
      mem_wb_regwrite_i = 1'b0;
      mem_wb_value_i    = 32'd0;
    end
  endtask

  task automatic do_reset();
    begin
      rst = 1'b1;
      drive_defaults();
      repeat (2) @(posedge clk);
      rst = 1'b0;
      @(posedge clk);
      #1;
    end
  endtask

  task automatic wb_write(input logic [4:0] rd, input logic [31:0] data);
    begin
      @(negedge clk);
      wb_we_i    = 1'b1;
      wb_rd_i    = rd;
      wb_wdata_i = data;
      @(posedge clk);
      #1;
      @(negedge clk);
      wb_we_i    = 1'b0;
      wb_rd_i    = 5'd0;
      wb_wdata_i = 32'd0;
    end
  endtask

  task automatic apply_instr(input logic valid, input logic [31:0] instr, input logic [31:0] pc);
    begin
      @(negedge clk);
      instr_valid_i = valid;
      instr_i       = instr;
      pc_i          = pc;
      pc4_i         = pc + 32'd4;
      #1; // allow combinational flush/stall to settle before next posedge
    end
  endtask

  // -------------------------
  // Tests
  // -------------------------
  initial begin
    $display("Starting decode_unit TB...");
    drive_defaults();
    rst = 1'b0;

    do_reset();

    // After reset, pipeline outputs should be bubbled
    tb_check(id_ex_valid_o == 1'b0, "After reset, id_ex_valid_o should be 0");
    tb_check(stall_o == 1'b0, "After reset, stall_o should be 0");
    tb_check(flush_o == 1'b0, "After reset, flush_o should be 0");

    // 1) instr_valid gating: invalid JAL should not flush
    apply_instr(1'b0, enc_jal(5'd1, 16), 32'h0000_1000);
    tb_check(flush_o == 1'b0, "instr_valid=0 must prevent flush on JAL bits");
    tb_check(stall_o == 1'b0, "instr_valid=0 should not create stall");
    @(posedge clk); #1;
    tb_check(id_ex_valid_o == 1'b0, "instr_valid=0 should produce bubble");

    // 2) Regfile write then ADDI read + immediate + control
    wb_write(5'd5, 32'hDEAD_BEEF);

    apply_instr(1'b1, enc_addi(5'd6, 5'd5, 1), 32'h0000_1000);
    tb_check(flush_o == 1'b0, "ADDI should not flush");
    tb_check(stall_o == 1'b0, "ADDI should not stall (no hazards injected)");
    @(posedge clk); #1;
    tb_check(id_ex_valid_o == 1'b1, "ADDI should be valid into ID/EX");
    tb_check(id_ex_rs1_o == 5'd5, "ADDI rs1 field wrong");
    tb_check(id_ex_rd_o  == 5'd6, "ADDI rd field wrong");
    tb_check(id_ex_rs1_val_o == 32'hDEAD_BEEF, "ADDI rs1 value readback wrong");
    tb_check(id_ex_imm_o == sext12(1), "ADDI immediate wrong");
    tb_check(id_ex_opB_sel_o == 1'b1, "ADDI OpB_sel should select imm");
    tb_check(id_ex_regwrite_o == 1'b1, "ADDI regwrite should be 1");
    tb_check(id_ex_alu_op_o == `I_TYPE, "ADDI alu_op should be I_TYPE");

    // 3) LW control + imm
    apply_instr(1'b1, enc_lw(5'd7, 5'd5, 8), 32'h0000_1010);
    tb_check(flush_o == 1'b0, "LW should not flush");
    tb_check(stall_o == 1'b0, "LW should not stall (no hazards injected)");
    @(posedge clk); #1;
    tb_check(id_ex_valid_o == 1'b1, "LW should be valid into ID/EX");
    tb_check(id_ex_mem_read_o == 1'b1, "LW mem_read should be 1");
    tb_check(id_ex_write_data_o == 1'b1, "LW write_data (Mem->WB) should be 1");
    tb_check(id_ex_regwrite_o == 1'b1, "LW regwrite should be 1");
    tb_check(id_ex_opB_sel_o == 1'b1, "LW OpB_sel should select imm");
    tb_check(id_ex_alu_op_o == `LOAD, "LW alu_op should be LOAD");
    tb_check(id_ex_imm_o == sext12(8), "LW immediate wrong");

    // 4) SW control + imm (S-type)
    apply_instr(1'b1, enc_sw(5'd7, 5'd5, 16), 32'h0000_1020);
    tb_check(flush_o == 1'b0, "SW should not flush");
    tb_check(stall_o == 1'b0, "SW should not stall (no hazards injected)");
    @(posedge clk); #1;
    tb_check(id_ex_valid_o == 1'b1, "SW should be valid into ID/EX");
    tb_check(id_ex_mem_write_o == 1'b1, "SW mem_write should be 1");
    tb_check(id_ex_regwrite_o == 1'b0, "SW regwrite should be 0");
    tb_check(id_ex_opB_sel_o == 1'b1, "SW OpB_sel should select imm");
    tb_check(id_ex_alu_op_o == `STORE, "SW alu_op should be STORE");
    tb_check(id_ex_imm_o == sext12(16), "SW immediate wrong");

    // 5) Branch NOT taken (beq x5,x6,+8) where x5=1, x6=2
    wb_write(5'd5, 32'd1);
    wb_write(5'd6, 32'd2);
    apply_instr(1'b1, enc_beq(5'd5, 5'd6, 8), 32'h0000_2000);
    tb_check(flush_o == 1'b0, "BEQ not-taken should not flush");
    tb_check(stall_o == 1'b0, "BEQ not-taken should not stall (no hazards injected)");
    @(posedge clk); #1;
    tb_check(id_ex_valid_o == 1'b1, "BEQ not-taken currently passes into ID/EX");
    tb_check(id_ex_branch_o == 1'b1, "BEQ branch control should be 1");
    tb_check(id_ex_alu_op_o == `BRANCH, "BEQ alu_op should be BRANCH");
    tb_check(id_ex_imm_o == sext13(8), "BEQ B-type immediate wrong");

    // 6) Branch TAKEN (beq x5,x6,+8) where x5=3, x6=3
    wb_write(5'd5, 32'd3);
    wb_write(5'd6, 32'd3);
    apply_instr(1'b1, enc_beq(5'd5, 5'd6, 8), 32'h0000_2000);
    tb_check(flush_o == 1'b1, "BEQ taken should flush (redirect)");
    tb_check(branch_target_o == 32'h0000_2008, "BEQ target_pc should be PC+imm");
    // In your decode_unit implementation, flush bubbles ID/EX on redirect:
    @(posedge clk); #1;
    tb_check(id_ex_valid_o == 1'b0, "On flush, ID/EX should be bubbled");

    // 7) Branch compare forwarding into ID-stage compare:
    // Regfile has x5=0, x6=0 but forwarded values make them equal (4 == 4)
    wb_write(5'd5, 32'd0);
    wb_write(5'd6, 32'd0);

    // Setup forwarding sources for branch compare:
    // rs1 (x5) forwarded from EX/MEM, rs2 (x6) forwarded from MEM/WB
    @(negedge clk);
    ex_mem_regwrite_i = 1'b1;
    ex_mem_mem_read_i = 1'b0;        // must be 0 to be "usable" for branch forward
    ex_mem_rd_i       = 5'd5;
    ex_mem_alu_out_i  = 32'd4;

    mem_wb_regwrite_i = 1'b1;
    mem_wb_rd_i       = 5'd6;
    mem_wb_value_i    = 32'd4;

    // Also clear EX-stage "load hazard" inputs
    id_ex_mem_read_i  = 1'b0;
    id_ex_rd_i        = 5'd0;
    id_ex_regwrite_i  = 1'b0;

    // Apply branch
    apply_instr(1'b1, enc_beq(5'd5, 5'd6, 8), 32'h0000_3000);
    tb_check(flush_o == 1'b1, "BEQ should take due to forwarded compare values");
    tb_check(branch_target_o == 32'h0000_3008, "Forwarded BEQ target_pc should be PC+imm");
    @(posedge clk); #1;
    tb_check(id_ex_valid_o == 1'b0, "On flush, ID/EX should be bubbled (forwarded branch taken)");

    // Return forwarding sources to default
    @(negedge clk);
    ex_mem_regwrite_i = 1'b0;
    ex_mem_mem_read_i = 1'b0;
    ex_mem_rd_i       = 5'd0;
    ex_mem_alu_out_i  = 32'd0;
    mem_wb_regwrite_i = 1'b0;
    mem_wb_rd_i       = 5'd0;
    mem_wb_value_i    = 32'd0;

    // 8) Load-use stall: EX stage has a load writing x5; current instr uses x5 -> stall
    @(negedge clk);
    id_ex_mem_read_i  = 1'b1;
    id_ex_rd_i        = 5'd5;
    id_ex_regwrite_i  = 1'b1;

    apply_instr(1'b1, enc_addi(5'd6, 5'd5, 1), 32'h0000_4000);
    tb_check(flush_o == 1'b0, "Load-use hazard should not flush");
    tb_check(stall_o == 1'b1, "Load-use hazard should assert stall_o");
    @(posedge clk); #1;
    tb_check(id_ex_valid_o == 1'b0, "On stall, ID/EX should be bubbled");

    // Clear hazard inputs
    @(negedge clk);
    id_ex_mem_read_i  = 1'b0;
    id_ex_rd_i        = 5'd0;
    id_ex_regwrite_i  = 1'b0;

    $display("All decode_unit tests PASSED.");
    $finish;
  end

endmodule

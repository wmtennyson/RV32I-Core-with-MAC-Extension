`timescale 1ns/1ps
`include "Def.vh"

// ============================================================
// Testbench: Decode_Unit (updated version with Hazard_Unit inst)
// - Pass/Fail cases focused on:
//   * bubble behavior (rst / instr_valid=0)
//   * stall behavior (ID/EX load-use, EX/MEM load + branch/jalr)
//   * flush behavior (jump taken when not stalled)
//   * flush suppression while stalled (jalr + load hazard)
// ============================================================

module tb_Decode_Unit;

  // -----------------------------
  // Clock / Reset
  // -----------------------------
  logic clk, rst;

  initial clk = 1'b0;
  always #5 clk = ~clk;

  // -----------------------------
  // DUT inputs
  // -----------------------------
  logic        instr_valid_i;
  logic [31:0] instr_i, pc_i, pc4_i;

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

  // -----------------------------
  // DUT outputs
  // -----------------------------
  logic        stall_o, flush_o;
  logic [31:0] branch_target_o;

  logic [31:0] rs1_val_o, rs2_val_o, imm_o;
  logic [4:0]  rs1_o, rs2_o, rd_o;
  logic [2:0]  funct3_o;
  logic [6:0]  funct7_o;

  logic        regwrite_o, mem_read_o, mem_write_o, branch_o, jump_o;
  logic        write_data_o, lui_o, is_jalr_o;
  logic [2:0]  alu_op_o;

  logic        opA_sel_o, opB_sel_o;
  logic [1:0]  rs1_sel_o, rs2_sel_o;

  // -----------------------------
  // Instantiate DUT
  // -----------------------------
  Decode_Unit dut (
    .clk               (clk),
    .rst               (rst),

    .instr_valid_i     (instr_valid_i),
    .instr_i           (instr_i),
    .pc_i              (pc_i),
    .pc4_i             (pc4_i),

    .wb_we_i           (wb_we_i),
    .wb_rd_i           (wb_rd_i),
    .wb_wdata_i        (wb_wdata_i),

    .id_ex_rd_i        (id_ex_rd_i),
    .id_ex_rs1_i       (id_ex_rs1_i),
    .id_ex_rs2_i       (id_ex_rs2_i),
    .id_ex_regwrite_i  (id_ex_regwrite_i),
    .id_ex_mem_read_i  (id_ex_mem_read_i),
    .ex_alu_out_i      (ex_alu_out_i),

    .ex_mem_rd_i       (ex_mem_rd_i),
    .ex_mem_regwrite_i (ex_mem_regwrite_i),
    .ex_mem_mem_read_i (ex_mem_mem_read_i),
    .ex_mem_alu_out_i  (ex_mem_alu_out_i),

    .mem_wb_rd_i       (mem_wb_rd_i),
    .mem_wb_regwrite_i (mem_wb_regwrite_i),
    .mem_wb_value_i    (mem_wb_value_i),

    .stall_o           (stall_o),
    .flush_o           (flush_o),
    .branch_target_o   (branch_target_o),

    .rs1_val_o         (rs1_val_o),
    .rs2_val_o         (rs2_val_o),
    .imm_o             (imm_o),

    .rs1_o             (rs1_o),
    .rs2_o             (rs2_o),
    .rd_o              (rd_o),
    .funct3_o          (funct3_o),
    .funct7_o          (funct7_o),

    .regwrite_o        (regwrite_o),
    .mem_read_o        (mem_read_o),
    .mem_write_o       (mem_write_o),
    .branch_o          (branch_o),
    .jump_o            (jump_o),
    .write_data_o      (write_data_o),
    .lui_o             (lui_o),
    .is_jalr_o         (is_jalr_o),
    .alu_op_o          (alu_op_o),

    .opA_sel_o         (opA_sel_o),
    .opB_sel_o         (opB_sel_o),
    .rs1_sel_o         (rs1_sel_o),
    .rs2_sel_o         (rs2_sel_o)
  );

  // -----------------------------
  // RISC-V opcodes (for encoding)
  // -----------------------------
  localparam logic [6:0] OP_JAL    = 7'b1101111;
  localparam logic [6:0] OP_JALR   = 7'b1100111;
  localparam logic [6:0] OP_BRANCH = 7'b1100011;
  localparam logic [6:0] OP_LOAD   = 7'b0000011;
  localparam logic [6:0] OP_STORE  = 7'b0100011;
  localparam logic [6:0] OP_OPIMM  = 7'b0010011;
  localparam logic [6:0] OP_OP     = 7'b0110011;

  // -----------------------------
  // Instruction builders
  // -----------------------------
  function automatic logic [31:0] make_rtype(
      input logic [6:0] opcode,
      input logic [4:0] rd,
      input logic [4:0] rs1,
      input logic [4:0] rs2,
      input logic [2:0] funct3,
      input logic [6:0] funct7
  );
    make_rtype = {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] make_itype(
      input logic [6:0] opcode,
      input logic [4:0] rd,
      input logic [4:0] rs1,
      input logic [2:0] funct3,
      input logic [11:0] imm12
  );
    make_itype = {{20{imm12[11]}}, imm12, rs1, funct3, rd, opcode};
  endfunction

  // JAL: offset is signed byte offset (must be multiple of 2)
  function automatic logic [31:0] make_jal(
      input logic [4:0] rd,
      input integer offset
  );
    logic signed [20:0] imm;
    imm = offset;
    // J-type immediate mapping
    make_jal = {
      imm[20],         // bit 31
      imm[10:1],       // bits 30:21
      imm[11],         // bit 20
      imm[19:12],      // bits 19:12
      rd,              // bits 11:7
      OP_JAL           // bits 6:0
    };
  endfunction

  // BEQ: offset is signed byte offset (must be multiple of 2)
  function automatic logic [31:0] make_beq(
      input logic [4:0] rs1,
      input logic [4:0] rs2,
      input integer offset
  );
    logic signed [12:0] imm;
    imm = offset;
    // B-type immediate mapping: imm[12|10:5|4:1|11] spread across instr
    make_beq = {
      imm[12],         // bit 31
      imm[10:5],       // bits 30:25
      rs2,             // bits 24:20
      rs1,             // bits 19:15
      3'b000,          // funct3 BEQ
      imm[4:1],        // bits 11:8
      imm[11],         // bit 7
      OP_BRANCH        // bits 6:0
    };
  endfunction

  // -----------------------------
  // Pass/Fail harness
  // -----------------------------
  int pass_count = 0;
  int fail_count = 0;

  task automatic expect_eq_bit(input logic got, input logic exp, input string name);
    begin
      #1;
      if ($isunknown(got)) begin
        fail_count++;
        $display("FAIL: %-70s | got=X/Z (%b)", name, got);
      end else if (got === exp) begin
        pass_count++;
        $display("PASS: %-70s | %0b", name, got);
      end else begin
        fail_count++;
        $display("FAIL: %-70s | expected=%0b got=%0b", name, exp, got);
      end
    end
  endtask

  task automatic expect_eq32(input logic [31:0] got, input logic [31:0] exp, input string name);
    begin
      #1;
      if ($isunknown(got)) begin
        fail_count++;
        $display("FAIL: %-70s | got=X/Z (%h)", name, got);
      end else if (got === exp) begin
        pass_count++;
        $display("PASS: %-70s | %h", name, got);
      end else begin
        fail_count++;
        $display("FAIL: %-70s | expected=%h got=%h", name, exp, got);
      end
    end
  endtask

  task automatic defaults();
    begin
      instr_valid_i = 1'b0;
      instr_i       = 32'd0;
      pc_i          = 32'h0000_1000;
      pc4_i         = pc_i + 32'd4;

      wb_we_i       = 1'b0;
      wb_rd_i       = 5'd0;
      wb_wdata_i    = 32'd0;

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

  task automatic write_reg(input logic [4:0] rd, input logic [31:0] val);
    begin
      wb_we_i    = 1'b1;
      wb_rd_i    = rd;
      wb_wdata_i = val;
      @(posedge clk);
      #1;
      wb_we_i    = 1'b0;
      wb_rd_i    = 5'd0;
      wb_wdata_i = 32'd0;
    end
  endtask

  // -----------------------------
  // Test sequence
  // -----------------------------
  initial begin
    defaults();

    // Reset
    rst = 1'b1;
    @(posedge clk);
    @(posedge clk);
    rst = 1'b0;
    #1;

    // ------------------------------------------------------------
    // CASE 0: rst asserted => downstream outputs are bubbled
    // ------------------------------------------------------------
    rst = 1'b1;
    instr_valid_i = 1'b1;
    instr_i       = make_rtype(OP_OP, 5'd1, 5'd2, 5'd3, 3'b000, 7'b0000000);
    expect_eq_bit(regwrite_o, 1'b0, "RST=1 bubbles: regwrite_o=0");
    expect_eq_bit(mem_read_o, 1'b0, "RST=1 bubbles: mem_read_o=0");
    expect_eq_bit(mem_write_o, 1'b0, "RST=1 bubbles: mem_write_o=0");
    rst = 1'b0;
    #1;

    // ------------------------------------------------------------
    // CASE 1: instr_valid=0 => no redirect, no stall; downstream bubble
    // ------------------------------------------------------------
    defaults();
    instr_valid_i = 1'b0;
    instr_i       = make_rtype(OP_OP, 5'd1, 5'd5, 5'd6, 3'b000, 7'b0000000);
    expect_eq_bit(stall_o,    1'b0, "instr_valid=0 => stall_o=0");
    expect_eq_bit(flush_o,    1'b0, "instr_valid=0 => flush_o=0");
    expect_eq_bit(regwrite_o, 1'b0, "instr_valid=0 bubbles: regwrite_o=0");

    // ------------------------------------------------------------
    // CASE 2: ID/EX load-use hazard => stall_o=1, flush_o=0, downstream bubble
    // Current instr: R-type uses rs1/rs2 (rs1=5)
    // ID/EX: load with rd=5
    // ------------------------------------------------------------
    defaults();
    instr_valid_i    = 1'b1;
    instr_i          = make_rtype(OP_OP, 5'd1, 5'd5, 5'd6, 3'b000, 7'b0000000);
    id_ex_mem_read_i = 1'b1;
    id_ex_rd_i       = 5'd5;
    expect_eq_bit(stall_o,    1'b1, "ID/EX load-use => stall_o=1");
    expect_eq_bit(flush_o,    1'b0, "ID/EX load-use => flush_o=0 (redirect suppressed)");
    expect_eq_bit(regwrite_o, 1'b0, "ID/EX load-use bubbles: regwrite_o=0");

    // ------------------------------------------------------------
    // CASE 3: EX/MEM load hazard should stall ONLY for BRANCH/JALR
    // Current instr: BEQ rs1=7 rs2=8
    // EX/MEM: load rd=7 => stall_o=1
    // ------------------------------------------------------------
    defaults();
    instr_valid_i     = 1'b1;
    instr_i           = make_beq(5'd7, 5'd8, 8);
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd7;
    expect_eq_bit(stall_o,    1'b1, "EX/MEM load + BRANCH => stall_o=1");
    expect_eq_bit(flush_o,    1'b0, "EX/MEM load + BRANCH => flush_o=0");
    expect_eq_bit(regwrite_o, 1'b0, "EX/MEM load + BRANCH bubbles: regwrite_o=0");

    // ------------------------------------------------------------
    // CASE 4: EX/MEM load hazard should NOT stall for normal ALU op
    // Current instr: R-type rs1=5 rs2=6
    // EX/MEM: load rd=5 => stall should be 0 (gated)
    // Also check rs1_val_o/rs2_val_o pass through regfile when not bubbled.
    // ------------------------------------------------------------
    defaults();
    // seed regfile via WB
    write_reg(5'd5, 32'hAAAA_0005);
    write_reg(5'd6, 32'hBBBB_0006);

    instr_valid_i     = 1'b1;
    instr_i           = make_rtype(OP_OP, 5'd1, 5'd5, 5'd6, 3'b000, 7'b0000000);
    ex_mem_mem_read_i = 1'b1;
    ex_mem_rd_i       = 5'd5;

    expect_eq_bit(stall_o,    1'b0, "EX/MEM load + R-type => stall_o=0");
    expect_eq_bit(flush_o,    1'b0, "EX/MEM load + R-type => flush_o=0");
    // not bubbled => should see regfile values
    expect_eq32(rs1_val_o, 32'hAAAA_0005, "No bubble: rs1_val_o matches regfile");
    expect_eq32(rs2_val_o, 32'hBBBB_0006, "No bubble: rs2_val_o matches regfile");

    // ------------------------------------------------------------
    // CASE 5: JAL => redirect/flush when not stalled
    // - Expect flush_o=1, stall_o=0
    // - branch_target_o should be pc + 16 (since we encode jal offset=16)
    // - downstream is bubbled because flush_o participates in bubble
    // ------------------------------------------------------------
    defaults();
    pc_i          = 32'h0000_2000;
    pc4_i         = pc_i + 32'd4;
    instr_valid_i = 1'b1;
    instr_i       = make_jal(5'd1, 16);  // jal x1, +16

    expect_eq_bit(stall_o,    1'b0, "JAL (no hazards) => stall_o=0");
    expect_eq_bit(flush_o,    1'b1, "JAL (no hazards) => flush_o=1");
    expect_eq32(branch_target_o, (32'h0000_2000 + 32'd16), "JAL target: branch_target_o = pc + 16");
    expect_eq_bit(regwrite_o, 1'b0, "flush bubbles downstream: regwrite_o=0");

    // ------------------------------------------------------------
    // CASE 6: JALR would redirect, BUT stall must suppress redirect/flush
    // - Current instr: JALR rs1=5
    // - ID/EX: load rd=5 => stall=1
    // - Expect flush_o=0 due to gating (~stall_o)
    // ------------------------------------------------------------
    defaults();
    // seed rs1 for completeness (branch unit target uses rs1+imm for jalr)
    write_reg(5'd5, 32'h0000_3000);

    pc_i          = 32'h0000_2100;
    pc4_i         = pc_i + 32'd4;
    instr_valid_i = 1'b1;
    // jalr x1, 0(x5) : opcode=JALR, funct3=000, imm=0
    instr_i       = make_itype(OP_JALR, 5'd1, 5'd5, 3'b000, 12'd0);

    id_ex_mem_read_i = 1'b1;
    id_ex_rd_i       = 5'd5;

    expect_eq_bit(stall_o, 1'b1, "JALR + ID/EX load-use => stall_o=1");
    expect_eq_bit(flush_o, 1'b0, "JALR + stall => flush_o=0 (redirect suppressed)");

    // -----------------------------
    // Summary
    // -----------------------------
    $display("\n====================================================");
    $display("Decode_Unit TB Summary: PASS=%0d  FAIL=%0d", pass_count, fail_count);
    $display("====================================================\n");

    if (fail_count != 0) $fatal(1, "Decode_Unit testbench: one or more cases FAILED.");
    $finish;
  end

endmodule


// ============================================================================
// OPTIONAL STUBS (only if you want a more isolated unit test)
// If you compile with your full project sources, DO NOT enable these.
// To enable in Icarus: iverilog -g2012 -DDECODE_TB_STUBS ...
// ============================================================================

`ifdef DECODE_TB_STUBS

// ---- Minimal regfile stub (sync write, async read)
module regfile(
  input  logic        clk,
  input  logic        rst,
  input  logic        we_i,
  input  logic [4:0]  waddr_i,
  input  logic [31:0] wdata_i,
  input  logic [4:0]  raddr1_i,
  input  logic [4:0]  raddr2_i,
  output logic [31:0] rdata1_o,
  output logic [31:0] rdata2_o
);
  logic [31:0] regs [0:31];
  integer k;

  always_ff @(posedge clk) begin
    if (rst) begin
      for (k=0; k<32; k++) regs[k] <= 32'd0;
    end else begin
      if (we_i && (waddr_i != 5'd0)) regs[waddr_i] <= wdata_i;
      regs[5'd0] <= 32'd0;
    end
  end

  always_comb begin
    rdata1_o = regs[raddr1_i];
    rdata2_o = regs[raddr2_i];
  end
endmodule

// ---- ImmGen stub (decode real immediates in your design; stub is not used by the tb's expectations)
module ImmGen(
  input  logic [31:0] instr_i,
  output logic [31:0] imm_o
);
  // Simple: default to 0 (tb uses real-encoded jal target; if you want, implement full RV imm decode)
  assign imm_o = 32'd0;
endmodule

// ---- Control_Unit stub (basic opcode mapping)
module Control_Unit(
  input  logic [6:0] opcode,
  output logic       regwrite,
  output logic       mem_read,
  output logic       mem_write,
  output logic       branch,
  output logic       jump,
  output logic       write_data,
  output logic       OpA_sel,
  output logic       OpB_sel,
  output logic       lui,
  output logic       is_jalr,
  output logic [2:0] alu_op
);
  always_comb begin
    regwrite   = 1'b0;
    mem_read   = 1'b0;
    mem_write  = 1'b0;
    branch     = 1'b0;
    jump       = 1'b0;
    write_data = 1'b0;
    OpA_sel    = 1'b0;
    OpB_sel    = 1'b0;
    lui        = 1'b0;
    is_jalr    = 1'b0;
    alu_op     = 3'b001;

    unique case (opcode)
      7'b0110111: begin regwrite = 1'b1; lui = 1'b1; end                // LUI
      7'b0010111: begin regwrite = 1'b1; end                            // AUIPC
      7'b1101111: begin regwrite = 1'b1; jump = 1'b1; end               // JAL
      7'b1100111: begin regwrite = 1'b1; jump = 1'b1; is_jalr = 1'b1; end // JALR
      7'b1100011: begin branch   = 1'b1; end                            // BRANCH
      7'b0100011: begin mem_write= 1'b1; end                            // STORE
      7'b0000011: begin regwrite = 1'b1; mem_read = 1'b1; write_data=1'b1; end // LOAD
      7'b0010011: begin regwrite = 1'b1; end                            // OP-IMM
      7'b0110011: begin regwrite = 1'b1; end                            // OP
      default: ;
    endcase
  end
endmodule

// ---- Forwarding_Unit stub (simple priority: EX then MEM then WB)
module Forwarding_Unit(
  input  logic [4:0] IF_ID_rs1,
  input  logic [4:0] IF_ID_rs2,
  input  logic [4:0] ID_EX_rd,
  input  logic [4:0] ID_EX_rs1,
  input  logic [4:0] ID_EX_rs2,
  input  logic [4:0] EX_MEM_rd,
  input  logic [4:0] MEM_WB_rd,

  input  logic       EX_MEM_RegWrite,
  input  logic       MEM_WB_RegWrite,
  input  logic       ID_EX_RegWrite,
  input  logic       ID_EX_mem_read,
  input  logic       EX_MEM_mem_read,

  output logic [1:0] BrFwd_A,
  output logic [1:0] BrFwd_B,
  output logic [1:0] RS1_Sel,
  output logic [1:0] RS2_Sel
);
  always_comb begin
    BrFwd_A = 2'b00;
    BrFwd_B = 2'b00;
    RS1_Sel = 2'b00;
    RS2_Sel = 2'b00;

    // EX stage (ID/EX result) -> encode as 11
    if (ID_EX_RegWrite && (ID_EX_rd != 0) && (ID_EX_rd == IF_ID_rs1)) begin BrFwd_A = 2'b11; RS1_Sel = 2'b11; end
    if (ID_EX_RegWrite && (ID_EX_rd != 0) && (ID_EX_rd == IF_ID_rs2)) begin BrFwd_B = 2'b11; RS2_Sel = 2'b11; end

    // MEM stage (EX/MEM alu out) -> 10
    if (EX_MEM_RegWrite && (EX_MEM_rd != 0) && (EX_MEM_rd == IF_ID_rs1)) begin BrFwd_A = 2'b10; RS1_Sel = 2'b10; end
    if (EX_MEM_RegWrite && (EX_MEM_rd != 0) && (EX_MEM_rd == IF_ID_rs2)) begin BrFwd_B = 2'b10; RS2_Sel = 2'b10; end

    // WB stage value -> 01
    if (MEM_WB_RegWrite && (MEM_WB_rd != 0) && (MEM_WB_rd == IF_ID_rs1)) begin BrFwd_A = 2'b01; RS1_Sel = 2'b01; end
    if (MEM_WB_RegWrite && (MEM_WB_rd != 0) && (MEM_WB_rd == IF_ID_rs2)) begin BrFwd_B = 2'b01; RS2_Sel = 2'b01; end
  end
endmodule

// ---- Branch_Unit stub (jump always redirects; BEQ redirects on equality)
module Branch_Unit(
  input  logic [31:0] pc,
  input  logic [31:0] pc4,
  input  logic [31:0] rs1,
  input  logic [31:0] rs2,
  input  logic [31:0] imm,
  input  logic        branch,
  input  logic        jump,
  input  logic        pcsrc,
  input  logic [2:0]  funct3,
  output logic        redirect,
  output logic [31:0] target_pc,
  output logic [31:0] link_register
);
  always_comb begin
    redirect      = 1'b0;
    target_pc     = pc4;
    link_register = pc4;

    if (jump) begin
      redirect  = 1'b1;
      target_pc = pc + imm;
      if (pcsrc) target_pc = rs1 + imm; // jalr
    end else if (branch) begin
      // only BEQ in stub
      if ((funct3 == 3'b000) && (rs1 == rs2)) begin
        redirect  = 1'b1;
        target_pc = pc + imm;
      end
    end
  end
endmodule

`endif

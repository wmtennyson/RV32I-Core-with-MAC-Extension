`include "Def.vh"
`timescale 1ns / 1ps

module Decode_Unit (
    input  logic        clk,
    input  logic        rst,

    // From IF/ID register
    input  logic        instr_valid_i,
    input  logic [31:0] instr_i,
    input  logic [31:0] pc_i,
    input  logic [31:0] pc4_i,

    // From Writeback (register file write port)
    input  logic        wb_we_i,
    input  logic [4:0]  wb_rd_i,
    input  logic [31:0] wb_wdata_i,

    // From pipeline — for Hazard Unit
    input  logic        id_ex_mem_read_i,
    input  logic        id_ex_regwrite_i,
    input  logic        id_ex_wb_pc4_sel_i,
    input  logic [4:0]  id_ex_rd_i,
    input  logic        ex_mem_mem_read_i,
    input  logic [4:0]  ex_mem_rd_i,

    // Branch-compare forwarding (from Forwarding_Unit at top level)
    input  logic [1:0]  br_fwd_a_i,
    input  logic [1:0]  br_fwd_b_i,
    input  logic        br_fwd_a_use_pc4_i,
    input  logic        br_fwd_b_use_pc4_i,

    // Forwarded values for branch compare
    input  logic [31:0] ex_alu_out_i,       // from EX (combinational)
    input  logic [31:0] ex_mem_alu_out_i,   // from MEM (EX/MEM register)
    input  logic [31:0] ex_mem_pc4_i,       // from MEM (EX/MEM register)
    input  logic [31:0] wb_value_i,         // from WB

    // To Fetch / IF/ID (pipeline control)
    output logic        stall_o,
    output logic        flush_o,         // redirect PC + kill IF/ID (all redirects)
    output logic        kill_o,          // kill ID/EX (taken branches only, NOT jumps)
    output logic [31:0] branch_target_o,

    // Decoded outputs → ID/EX register
    output logic [31:0] rs1_val_o,
    output logic [31:0] rs2_val_o,
    output logic [31:0] imm_o,

    output logic [4:0]  rs1_o,
    output logic [4:0]  rs2_o,
    output logic [4:0]  rd_o,
    output logic [2:0]  funct3_o,
    output logic [6:0]  funct7_o,

    output logic        regwrite_o,
    output logic        mem_read_o,
    output logic        mem_write_o,
    output logic        branch_o,
    output logic        jump_o,
    output logic        is_jalr_o,
    output logic        lui_o,
    output logic        opA_sel_o,
    output logic        opB_sel_o,
    output logic        wb_sel_o,
    output logic        wb_pc4_sel_o,
    output logic [2:0]  alu_op_o,
    output logic        valid_o
);

    // Field decode, use assign (NOT logic-with-initializer!)
    logic [6:0] opcode;   assign opcode = instr_i[6:0];
    logic [4:0] rd;       assign rd     = instr_i[11:7];
    logic [4:0] rs1;      assign rs1    = instr_i[19:15];
    logic [4:0] rs2;      assign rs2    = instr_i[24:20];
    logic [2:0] funct3;   assign funct3 = instr_i[14:12];
    logic [6:0] funct7;   assign funct7 = instr_i[31:25];

    // Register file
    logic [31:0] rs1_rf, 
                 rs2_rf;

    regfile RF (
        .clk        (clk), 
        .rst        (rst),
        
        .we_i       (wb_we_i), 
        .waddr_i    (wb_rd_i), 
        .wdata_i    (wb_wdata_i),
        .raddr1_i   (rs1), 
        .raddr2_i   (rs2),
        .rdata1_o   (rs1_rf), 
        .rdata2_o   (rs2_rf)
    );

    // WB-ID bypass (same-cycle write-read)
    logic [31:0] rs1_data, 
    rs2_data;
    
    always_comb begin
        rs1_data = rs1_rf;
        rs2_data = rs2_rf;
        
        if (wb_we_i && (wb_rd_i != 5'd0) && (wb_rd_i == rs1)) rs1_data = wb_wdata_i;
        if (wb_we_i && (wb_rd_i != 5'd0) && (wb_rd_i == rs2)) rs2_data = wb_wdata_i;
    end

    // Immediate generator
    logic [31:0] imm_d;
    ImmGen IG (
        .instr_i    (instr_i), 
        .imm_o      (imm_d)
    );

    // Control Unit
    logic       ctrl_regwrite, 
                ctrl_mem_read, 
                ctrl_mem_write,
                ctrl_branch, 
                ctrl_jump, 
                ctrl_is_jalr, 
                ctrl_lui,
                ctrl_opA_sel, 
                ctrl_opB_sel, 
                ctrl_wb_sel, 
                ctrl_wb_pc4_sel;
    logic [2:0] ctrl_alu_op;

    Control_Unit CU (
        .opcode         (opcode),
        .regwrite       (ctrl_regwrite), 
        .mem_read       (ctrl_mem_read), 
        .mem_write      (ctrl_mem_write),
        .branch         (ctrl_branch), 
        .jump           (ctrl_jump), 
        .is_jalr        (ctrl_is_jalr), 
        .lui            (ctrl_lui),
        .opA_sel        (ctrl_opA_sel), 
        .opB_sel        (ctrl_opB_sel),
        .wb_sel         (ctrl_wb_sel), 
        .wb_pc4_sel     (ctrl_wb_pc4_sel),
        .alu_op         (ctrl_alu_op)
    );

    // Gate control signals with instr_valid
    logic   g_branch, 
            g_jump, 
            g_is_jalr;
            
    assign g_branch  = ctrl_branch  & instr_valid_i;
    assign g_jump    = ctrl_jump    & instr_valid_i;
    assign g_is_jalr = ctrl_is_jalr & instr_valid_i;

    // Hazard Unit
    logic stall_hz;

    Hazard_Unit HU (
        .instr_valid_i          (instr_valid_i), 
        .opcode_i               (opcode),
        .rs1_i                  (rs1), 
        .rs2_i                  (rs2),
        .id_ex_mem_read_i       (id_ex_mem_read_i), 
        .id_ex_regwrite_i       (id_ex_regwrite_i),
        .id_ex_wb_pc4_sel_i     (id_ex_wb_pc4_sel_i), 
        .id_ex_rd_i             (id_ex_rd_i),
        .ex_mem_mem_read_i      (ex_mem_mem_read_i), 
        .ex_mem_rd_i            (ex_mem_rd_i),
        .stall_o                (stall_hz)
    );

    assign stall_o = stall_hz;

    // Branch forwarding muxes
    logic [31:0] br_rs1, 
                 br_rs2;

    always_comb begin
        unique case (br_fwd_a_i)
            2'b00:   br_rs1 = rs1_data;
            2'b01:   br_rs1 = wb_value_i;
            2'b10:   br_rs1 = br_fwd_a_use_pc4_i ? ex_mem_pc4_i : ex_mem_alu_out_i;
            2'b11:   br_rs1 = ex_alu_out_i;
            default: br_rs1 = rs1_data;
        endcase

        unique case (br_fwd_b_i)
            2'b00:   br_rs2 = rs2_data;
            2'b01:   br_rs2 = wb_value_i;
            2'b10:   br_rs2 = br_fwd_b_use_pc4_i ? ex_mem_pc4_i : ex_mem_alu_out_i;
            2'b11:   br_rs2 = ex_alu_out_i;
            default: br_rs2 = rs2_data;
        endcase
    end

    // Branch / Jump resolution (in ID stage)
    logic        redirect;
    logic [31:0] target_pc;

    Branch_Unit BU (
        .pc         (pc_i), 
        .pc4        (pc4_i),
        .rs1        (br_rs1), 
        .rs2        (br_rs2), 
        .imm        (imm_d),
        .branch     (g_branch & ~stall_o),
        .jump       (g_jump & ~stall_o),
        .is_jalr    (g_is_jalr & ~stall_o),
        .funct3     (funct3),
        .redirect   (redirect),
        .target_pc  (target_pc)
    );

    // flush_o: redirect PC + kill IF/ID, for ALL redirects (branch, JAL, JALR)
    assign flush_o         = redirect & ~stall_o;
    assign branch_target_o = target_pc;

    // kill_o: kill ID/EX, ONLY for taken branches (they don't write registers)
    //   JAL/JALR must NOT be killed because they must reach WB to write PC+4 to rd.
    assign kill_o = (redirect & g_branch) & ~stall_o;

    // Drive outputs (bubble on invalid / reset / taken-branch-kill)
    logic bubble;
    assign bubble = rst | !instr_valid_i | kill_o;

    always_comb begin
        if (bubble) begin
            valid_o         = 1'b0;   
            rs1_val_o       = 32'd0;   
            rs2_val_o       = 32'd0;
            imm_o           = 32'd0;  
            rs1_o           = 5'd0;    
            rs2_o           = 5'd0;
            rd_o            = 5'd0;   
            funct3_o        = 3'd0;    
            funct7_o        = 7'd0;
            regwrite_o      = 1'b0;  
            mem_read_o      = 1'b0;  
            mem_write_o     = 1'b0;
            branch_o        = 1'b0;  
            jump_o          = 1'b0;  
            is_jalr_o       = 1'b0;  
            lui_o           = 1'b0;
            opA_sel_o       = 1'b0; 
            opB_sel_o       = 1'b0;  
            wb_sel_o        = 1'b0;
            wb_pc4_sel_o    = 1'b0;  
            alu_op_o        = `OP_NOP;
        end
        else begin
            valid_o         = 1'b1;
            rs1_val_o       = rs1_data;   
            rs2_val_o       = rs2_data;
            imm_o           = imm_d;
            rs1_o           = rs1;     
            rs2_o           = rs2;    
            rd_o            = rd;
            funct3_o        = funct3;  
            funct7_o        = funct7;
            regwrite_o      = ctrl_regwrite;   
            mem_read_o      = ctrl_mem_read;
            mem_write_o     = ctrl_mem_write; 
            branch_o        = ctrl_branch;
            jump_o          = ctrl_jump;       
            is_jalr_o       = ctrl_is_jalr;
            lui_o           = ctrl_lui;        
            opA_sel_o       = ctrl_opA_sel;
            opB_sel_o       = ctrl_opB_sel;    
            wb_sel_o        = ctrl_wb_sel;
            wb_pc4_sel_o    = ctrl_wb_pc4_sel;  
            alu_op_o        = ctrl_alu_op;
        end
    end

endmodule



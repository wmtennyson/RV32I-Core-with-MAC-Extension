`include "Def.vh"
`timescale 1ns / 1ps

module id_ex_reg (
    input  logic            clk,
    input  logic            rst,
    input  logic            flush_i,
    input  logic            stall_i,

    // From Decode
    input  logic            valid_i,
    input  logic [31:0]     instr_i,
    input  logic [31:0]     pc_i,
    input  logic [31:0]     pc4_i,
    input  logic [31:0]     rs1_val_i,
    input  logic [31:0]     rs2_val_i,
    input  logic [31:0]     imm_i,
    input  logic [4:0]      rs1_i, 
                            rs2_i, 
                            rd_i,
    input  logic [2:0]      funct3_i,
    input  logic [6:0]      funct7_i,
    input  logic            regwrite_i, 
                            mem_read_i, 
                            mem_write_i,
                            branch_i, 
                            jump_i, 
                            is_jalr_i, 
                            lui_i,
                            opA_sel_i, 
                            opB_sel_i,
                            wb_sel_i, 
                            wb_pc4_sel_i,
    input  logic [2:0]      alu_op_i,

    // Registered outputs
    output logic        valid_o,
    output logic [31:0] instr_o,
    output logic [31:0] pc_o, pc4_o,
    output logic [31:0] rs1_val_o, rs2_val_o, imm_o,
    output logic [4:0]  rs1_o, rs2_o, rd_o,
    output logic [2:0]  funct3_o,
    output logic [6:0]  funct7_o,
    output logic        regwrite_o, 
                        mem_read_o, 
                        mem_write_o,
                        branch_o, 
                        jump_o, 
                        is_jalr_o, 
                        lui_o,
                        opA_sel_o, 
                        opB_sel_o,
                        wb_sel_o, 
                        wb_pc4_sel_o,
    output logic [2:0]  alu_op_o
);

    always_ff @(posedge clk) begin
        if (rst || flush_i) begin
            valid_o         <= 1'b0;   
            instr_o         <= 32'h0000_0013;
            pc_o            <= 32'd0;  
            pc4_o           <= 32'd0;
            rs1_val_o       <= 32'd0;  
            rs2_val_o       <= 32'd0;  
            imm_o           <= 32'd0;
            rs1_o           <= 5'd0;   
            rs2_o           <= 5'd0;    
            rd_o            <= 5'd0;
            funct3_o        <= 3'd0;   
            funct7_o        <= 7'd0;
            regwrite_o      <= 1'b0;   
            mem_read_o      <= 1'b0;  
            mem_write_o     <= 1'b0;
            branch_o        <= 1'b0;   
            jump_o          <= 1'b0;    
            is_jalr_o       <= 1'b0;
            lui_o           <= 1'b0;   
            opA_sel_o       <= 1'b0;    
            opB_sel_o       <= 1'b0;
            wb_sel_o        <= 1'b0;   
            wb_pc4_sel_o    <= 1'b0;
            alu_op_o        <= `OP_NOP;
        end
        else if (!stall_i) begin
            valid_o         <= valid_i;     
            instr_o         <= instr_i;
            pc_o            <= pc_i;        
            pc4_o           <= pc4_i;
            rs1_val_o       <= rs1_val_i;   
            rs2_val_o       <= rs2_val_i;  
            imm_o           <= imm_i;
            rs1_o           <= rs1_i;       
            rs2_o           <= rs2_i;       
            rd_o            <= rd_i;
            funct3_o        <= funct3_i;    
            funct7_o        <= funct7_i;
            regwrite_o      <= regwrite_i & valid_i;
            mem_read_o      <= mem_read_i  & valid_i;
            mem_write_o     <= mem_write_i & valid_i;
            branch_o        <= branch_i    & valid_i;
            jump_o          <= jump_i      & valid_i;
            is_jalr_o       <= is_jalr_i   & valid_i;
            lui_o           <= lui_i       & valid_i;
            opA_sel_o       <= opA_sel_i;   
            opB_sel_o       <= opB_sel_i;
            wb_sel_o        <= wb_sel_i    & valid_i;
            wb_pc4_sel_o    <= wb_pc4_sel_i & valid_i;
            alu_op_o        <= valid_i ? alu_op_i : `OP_NOP;
        end
    end

endmodule


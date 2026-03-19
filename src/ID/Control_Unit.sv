`include "Def.vh"
`timescale 1ns / 1ps

module Control_Unit (
    input  logic [6:0] opcode,

    output logic       regwrite,
    output logic       mem_read,
    output logic       mem_write,
    output logic       branch,
    output logic       jump,
    output logic       is_jalr,
    output logic       lui,
    output logic       opA_sel,      // 0=PC, 1=RS1
    output logic       opB_sel,      // 0=RS2, 1=IMM
    output logic       wb_sel,       // 0=ALU, 1=MEM data
    output logic       wb_pc4_sel,   // 1=write PC+4 (JAL/JALR link)
    output logic [2:0] alu_op
);

    always_comb begin
        // NOP-safe defaults
        regwrite    = 1'b0;  
        mem_read    = 1'b0;  
        mem_write   = 1'b0;
        branch      = 1'b0;  
        jump        = 1'b0;  
        is_jalr     = 1'b0;
        lui         = 1'b0;  
        opA_sel     = 1'b1;  
        opB_sel     = 1'b0;
        wb_sel      = 1'b0;  
        wb_pc4_sel  = 1'b0;  
        alu_op      = `OP_NOP;

        unique case (opcode)
            7'b0110011: begin                           // R-type
                regwrite = 1'b1;
                alu_op   = `OP_RTYPE;
            end
            7'b0010011: begin                           // I-type ALU
                regwrite = 1'b1;  
                opB_sel = 1'b1;
                alu_op   = `OP_ITYPE;
            end
            7'b0000011: begin                           // Load
                regwrite = 1'b1;  
                mem_read = 1'b1;
                opB_sel  = 1'b1; 
                wb_sel   = 1'b1;
                alu_op   = `OP_LOAD;
            end
            7'b0100011: begin                           // Store
                mem_write = 1'b1;  
                opB_sel = 1'b1;
                alu_op    = `OP_STORE;
            end
            7'b1100011: begin                           // Branch
                branch = 1'b1;
                alu_op = `OP_BRANCH;
            end
            7'b1101111: begin                           // JAL
                regwrite   = 1'b1;  
                jump       = 1'b1;
                wb_pc4_sel = 1'b1;
                opA_sel    = 1'b0;  
                opB_sel    = 1'b1;    // PC + imm
                alu_op     = `OP_JUMP;
            end
            7'b1100111: begin                           // JALR
                regwrite   = 1'b1;  
                jump       = 1'b1;
                is_jalr    = 1'b1;  
                wb_pc4_sel = 1'b1;
                opB_sel    = 1'b1;                      // RS1 + imm
                alu_op     = `OP_JUMP;
            end
            7'b0110111: begin                           // LUI
                regwrite = 1'b1;  
                lui      = 1'b1;
                opB_sel  = 1'b1;
                alu_op   = `OP_UTYPE;
            end
            7'b0010111: begin                           // AUIPC
                regwrite = 1'b1;
                opA_sel  = 1'b0;  
                opB_sel  = 1'b1;      // PC + imm
                alu_op   = `OP_UTYPE;
            end
            default: ;
        endcase
    end

endmodule


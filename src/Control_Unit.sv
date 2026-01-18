`include "Def.vh"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Senior Project
// Engineer: William Tennyson
// 
// Create Date: 01/11/2026 07:38:49 PM
// Design Name: CPU High Level View
// Module Name: Control_Unit
// Project Name: Senior Project 32-Bit CPU
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision: 0
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Control_Unit(
    // Inputs 
    input  logic [6:0] opcode,
    
    // Output Signals
    output logic regwrite,
                 mem_read,
                 mem_write,
                 branch,
                 jump,
                 write_data,
                 OpA_sel,
                 OpB_sel,
                 lui,
                 pcsrc,
    output logic [2:0] alu_op
    );
    
    always_comb begin
        // Set Default Control Signals
        regwrite = 0; 
        mem_read = 0; 
        mem_write = 0; 
        branch = 0; 
        jump = 0; 
        write_data = 0; 
        OpA_sel = 0; 
        OpB_sel = 0; 
        lui = 0; 
        pcsrc = 0; 
        alu_op = `NOP;
        
        // Set Control Signals Depending on OPCODE
        unique case (opcode)
        
            // R-type
            7'b0110011: begin 
                regwrite = 1;
                alu_op    = `R_TYPE;
            end
            
            // I-type
            7'b0010011: begin 
                regwrite = 1;
                OpA_sel  = 1;
                alu_op    = `I_TYPE;
            end
            
            // Load
            7'b0000011: begin
                regwrite = 1;
                mem_read  = 1;
                OpB_sel  = 1;
                write_data = 1;
                alu_op    = `LOAD;
            end
            
            // Store
            7'b0100011: begin 
                mem_write = 1;
                OpB_sel  = 1;
                alu_op    = `STORE;
            end
            
            // Branch
            7'b1100011: begin 
                branch   = 1;
                alu_op    = `BRANCH;
            end
            
            // JAL and JALR
            7'b1101111, 7'b1100111: begin 
                regwrite = 1;
                jump     = 1;
                OpA_sel  = 1; // For JALR immediate offset
                pcsrc    = (opcode == 7'b1100111) ? 1 : 0; // JALR only
                alu_op    = `JUMP;
            end
            
            // LUI and AUIPC
            7'b0110111, 7'b0010111: begin 
                regwrite = 1;
                OpB_sel  = 1;
                OpA_sel  = (opcode == 7'b0010111) ? 1 : 0; // AUIPC only
                lui      = (opcode == 7'b0110111) ? 1 : 0; // LUI only
                alu_op    = `U_TYPE;
            end
            
            default: ; // Do nothing; defaults already set
        endcase 
    end
   
endmodule

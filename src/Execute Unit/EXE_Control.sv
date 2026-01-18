`include "Def.vh"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Senior Project
// Engineer: William Tennyson
// 
// Create Date: 01/10/2026 04:12:31 PM
// Design Name: Execute Unit
// Module Name: EXE_Control
// Project Name: 32-Bit CPU with MAC Extension
// Target Devices: 
// Tool Versions: 
// Description: This Unit Decides which operation the ALU needs to do complete the required task.
// 
// Dependencies: N/A     
// 
// Revision: 0
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module EXE_Control(
        // Inputs
        input  logic [2:0] alu_op,
        input  logic [31:25] func7,
        input  logic [14:12] func3,
        
        // Outputs
        output logic [3:0] alu_ctrl
    );
    
    // Begin Switch Statement for Class
    always_comb begin
        unique casez ({alu_op, func7[30], func3})
            
            // ADD, LW, SW, AUIPC, ADDI, NOP
            {`STORE, 1'b?, 3'b???}, 
            {`U_TYPE, 1'b?, 3'b???}, 
            {`NOP, 1'b?, 3'b???}, 
            {`R_TYPE, 1'b0, 3'b000}, 
            {`I_TYPE, 1'b?, 3'b000}, 
            {`LOAD, 1'b?, 3'b???}: alu_ctrl = `ADD;  
            
            // SUB
            {`R_TYPE, 1'b1, 3'b000}: alu_ctrl = `SUB;  
            
            // AND, ANDI
            {`R_TYPE, 1'b0, 3'b111}, 
            {`I_TYPE, 1'b?, 3'b111}: alu_ctrl = `AND;  
            
            // OR, ORI
            {`R_TYPE, 1'b0, 3'b110}, 
            {`I_TYPE, 1'b?, 3'b110}: alu_ctrl = `OR; 
            
            // XOR, XORI
            {`R_TYPE, 1'b0, 3'b100}, 
            {`I_TYPE, 1'b?, 3'b100}: alu_ctrl = `XOR;  
            
            // SLL, SLLI
            {`I_TYPE, 1'b0, 3'b001}, 
            {`R_TYPE, 1'b0, 3'b001}: alu_ctrl = `SLL;  
            
             // SRL, SRLI
            {`I_TYPE, 1'b0, 3'b101}, 
            {`R_TYPE, 1'b0, 3'b101}: alu_ctrl = `SRL;  
            
            // SRA, SRAI
            {`R_TYPE, 1'b1, 3'b101}, 
            {`I_TYPE, 1'b1, 3'b101}: alu_ctrl = `SRA;  
            
            // SLT, SLTI, BLT
            {`BRANCH, 1'b?, 3'b100},{`I_TYPE,  
            1'b?, 3'b010},{`R_TYPE,  1'b0, 3'b010}: alu_ctrl = `less_than;
             
            // SLTU, SLTIU, BLTU
            {`BRANCH, 1'b?, 3'b110}, 
            {`I_TYPE,  1'b?, 3'b011}, 
            {`R_TYPE,  1'b0, 3'b011}: alu_ctrl = `less_than_unsigned;   
            
            // BGE 
            {`BRANCH, 1'b?, 3'b101}: alu_ctrl = `greater_than;  
            
            // BGEU
            {`BRANCH, 1'b?, 3'b111}: alu_ctrl = `greater_than_unsigned;  
           
            // BEQ
            {`BRANCH, 1'b?, 3'b000}: alu_ctrl = `equal;      
            
            // BNE
            {`BRANCH, 1'b?, 3'b001}: alu_ctrl = `not_equal;  
            
            // JAL and JALR
            {`JUMP, 1'b?, 3'b???}: alu_ctrl = `pc_plus_4;  
            
            default: alu_ctrl = 4'b0000;
    
        endcase
    end

endmodule

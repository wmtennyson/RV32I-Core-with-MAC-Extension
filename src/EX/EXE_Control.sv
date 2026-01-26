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
// Description: This Unit decides which operation the ALU needs to do complete the required task.
// 
// Dependencies: N/A     
// 
// Revision: 0
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module EXE_Control(
    input  logic [2:0] alu_op,
    input  logic [6:0] func7,
    input  logic [2:0] func3,
    output logic [3:0] alu_ctrl
);

    always_comb begin
        // Default
        alu_ctrl = `ADD;

        unique casez ({alu_op, func7[5], func3})

            // ADD-like (address calc, etc.)
            {`STORE,  1'b?, 3'b???},
            {`U_TYPE, 1'b?, 3'b???},
            {`NOP,    1'b?, 3'b???},
            {`LOAD,   1'b?, 3'b???},
            {`JUMP,   1'b?, 3'b???},  
            {`R_TYPE, 1'b0, 3'b000},
            {`I_TYPE, 1'b?, 3'b000}: alu_ctrl = `ADD;

            // SUB
            {`R_TYPE, 1'b1, 3'b000}: alu_ctrl = `SUB;

            // AND / ANDI
            {`R_TYPE, 1'b0, 3'b111},
            {`I_TYPE, 1'b?, 3'b111}: alu_ctrl = `AND;

            // OR / ORI
            {`R_TYPE, 1'b0, 3'b110},
            {`I_TYPE, 1'b?, 3'b110}: alu_ctrl = `OR;

            // XOR / XORI
            {`R_TYPE, 1'b0, 3'b100},
            {`I_TYPE, 1'b?, 3'b100}: alu_ctrl = `XOR;

            // SLL / SLLI
            {`R_TYPE, 1'b0, 3'b001},
            {`I_TYPE, 1'b0, 3'b001}: alu_ctrl = `SLL;

            // SRL / SRLI
            {`R_TYPE, 1'b0, 3'b101},
            {`I_TYPE, 1'b0, 3'b101}: alu_ctrl = `SRL;

            // SRA / SRAI
            {`R_TYPE, 1'b1, 3'b101},
            {`I_TYPE, 1'b1, 3'b101}: alu_ctrl = `SRA;

            // SLT / SLTI
            {`R_TYPE, 1'b0, 3'b010},
            {`I_TYPE, 1'b?, 3'b010}: alu_ctrl = `SLT;

            // SLTU / SLTIU
            {`R_TYPE, 1'b0, 3'b011},
            {`I_TYPE, 1'b?, 3'b011}: alu_ctrl = `SLTU;

            // Branch Types (Redundancy)
            {`BRANCH, 1'b?, 3'b???}: alu_ctrl = `SUB;

            default: ; // keep default `ADD
        endcase
    end

endmodule

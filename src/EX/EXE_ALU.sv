`include "Def.vh"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Senior Project
// Engineer: William Tennyson
// 
// Create Date: 01/10/2026 04:12:31 PM
// Design Name: Execute Unit
// Module Name: EXE_ALU
// Project Name: 32-Bit CPU with MAC Extension
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: N/A     
// 
// Revision: 0
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module EXE_ALU(
        // Inputs
        input logic [31:0] OpA,
                           OpB,
        input logic [3:0]  alu_ctrl,
              
        // Outputs-Variable
        output logic [31:0] alu_out
    );    
       
    // Get Shift Amount
    logic [4:0] shamt;
    assign shamt = OpB[4:0];   
        
    // Begin Switch Statement
    always_comb begin
    
        // Default
        alu_out = '0;  
    
        unique case(alu_ctrl)
            `ADD  : alu_out = OpA + OpB;                                            // Addtion
            `SUB  : alu_out = OpA - OpB;                                            // Subtraction
            `AND  : alu_out = OpA & OpB;                                            // AND
            `OR   : alu_out = OpA | OpB;                                            // OR
            `XOR  : alu_out = OpA ^ OpB;                                            // XOR
            `SLL  : alu_out = OpA << shamt;                                         // Shift Left Logical
            `SRL  : alu_out = OpA >> shamt;                                         // Shift Right Logical
            `SRA  : alu_out = $signed(OpA) >>> shamt;                               // Arithmetic Right Shift, Signed 
            `less_than  : alu_out = {31'b0, ($signed(OpA) < $signed(OpB))};         // Signed Less-Than
            `less_than_unsigned : alu_out = {31'b0, OpA < OpB};                     // Unsinged Less-Than
            `greater_than  : alu_out = {31'b0, ($signed(OpA) >= $signed(OpB))};      // Signed Greater-Than
            `greater_than_unsigned : alu_out = {31'b0, OpA >= OpB};                  // Unsinged Greater-Than 
            `equal  : alu_out = {31'b0, OpA == OpB};                                // Bit Patterns Equal
            `not_equal: alu_out = {31'b0, OpA != OpB};                              // Bit Patterns Not Equal
            `pc_plus_4: alu_out = OpA + 32'd4;                                      
             default : alu_out = '0;                                                // Error
                
        endcase
    end

endmodule


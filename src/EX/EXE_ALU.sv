`include "Def.vh"
`timescale 1ns / 1ps

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
            `SLT  : alu_out = {31'b0, ($signed(OpA) < $signed(OpB))};               // Set Signed Less-Than
            `SLTU : alu_out = {31'b0, OpA < OpB};                                   // Set Unsinged Less-Than
             default : ;                                                            // Error
                
        endcase
    end

endmodule

`include "Def.vh"
`timescale 1ns / 1ps

module EXE_ALU (
    input  logic [31:0] OpA,
    input  logic [31:0] OpB,
    input  logic [3:0]  alu_ctrl,
    output logic [31:0] alu_out
);

    logic [4:0] shamt;
    assign shamt = OpB[4:0];

    always_comb begin
        alu_out = 32'd0;
        unique case (alu_ctrl)
            `ALU_ADD  : alu_out = OpA + OpB;
            `ALU_SUB  : alu_out = OpA - OpB;
            `ALU_AND  : alu_out = OpA & OpB;
            `ALU_OR   : alu_out = OpA | OpB;
            `ALU_XOR  : alu_out = OpA ^ OpB;
            `ALU_SLL  : alu_out = OpA << shamt;
            `ALU_SRL  : alu_out = OpA >> shamt;
            `ALU_SRA  : alu_out = $signed(OpA) >>> shamt;
            `ALU_SLT  : alu_out = {31'b0, ($signed(OpA) < $signed(OpB))};
            `ALU_SLTU : alu_out = {31'b0, (OpA < OpB)};
            default   : ;
        endcase
    end

endmodule

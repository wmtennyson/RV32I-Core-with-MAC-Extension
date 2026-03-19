`include "Def.vh"
`timescale 1ns / 1ps

module EXE_Control (
    input  logic [2:0] alu_op,
    input  logic [6:0] func7,
    input  logic [2:0] func3,
    output logic [3:0] alu_ctrl
);

    always_comb begin
        alu_ctrl = `ALU_ADD;

        unique casez ({alu_op, func7[5], func3})
            {`OP_STORE,  1'b?, 3'b???},
            {`OP_UTYPE,  1'b?, 3'b???},
            {`OP_NOP,    1'b?, 3'b???},
            {`OP_LOAD,   1'b?, 3'b???},
            {`OP_JUMP,   1'b?, 3'b???},
            {`OP_RTYPE,  1'b0, 3'b000},
            {`OP_ITYPE,  1'b?, 3'b000}: alu_ctrl = `ALU_ADD;

            {`OP_RTYPE,  1'b1, 3'b000}: alu_ctrl = `ALU_SUB;

            {`OP_RTYPE,  1'b0, 3'b111},
            {`OP_ITYPE,  1'b?, 3'b111}: alu_ctrl = `ALU_AND;

            {`OP_RTYPE,  1'b0, 3'b110},
            {`OP_ITYPE,  1'b?, 3'b110}: alu_ctrl = `ALU_OR;

            {`OP_RTYPE,  1'b0, 3'b100},
            {`OP_ITYPE,  1'b?, 3'b100}: alu_ctrl = `ALU_XOR;

            {`OP_RTYPE,  1'b0, 3'b001},
            {`OP_ITYPE,  1'b0, 3'b001}: alu_ctrl = `ALU_SLL;

            {`OP_RTYPE,  1'b0, 3'b101},
            {`OP_ITYPE,  1'b0, 3'b101}: alu_ctrl = `ALU_SRL;

            {`OP_RTYPE,  1'b1, 3'b101},
            {`OP_ITYPE,  1'b1, 3'b101}: alu_ctrl = `ALU_SRA;

            {`OP_RTYPE,  1'b0, 3'b010},
            {`OP_ITYPE,  1'b?, 3'b010}: alu_ctrl = `ALU_SLT;

            {`OP_RTYPE,  1'b0, 3'b011},
            {`OP_ITYPE,  1'b?, 3'b011}: alu_ctrl = `ALU_SLTU;

            {`OP_BRANCH, 1'b?, 3'b???}: alu_ctrl = `ALU_SUB;

            default: ;
        endcase
    end

endmodule

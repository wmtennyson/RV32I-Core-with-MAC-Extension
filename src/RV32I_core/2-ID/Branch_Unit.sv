`timescale 1ns / 1ps

module Branch_Unit (
    input  logic [31:0] pc,
    input  logic [31:0] pc4,
    input  logic [31:0] rs1,
    input  logic [31:0] rs2,
    input  logic [31:0] imm,
    input  logic        branch,
    input  logic        jump,
    input  logic        is_jalr,
    input  logic [2:0]  funct3,

    output logic        redirect,
    output logic [31:0] target_pc
);

    logic cond;

    always_comb begin
        redirect  = 1'b0;
        target_pc = pc4;
        cond      = 1'b0;

        // Branch condition evaluation
        unique case (funct3)
            3'b000:  cond = (rs1 == rs2);                          // BEQ
            3'b001:  cond = (rs1 != rs2);                          // BNE
            3'b100:  cond = ($signed(rs1) <  $signed(rs2));        // BLT
            3'b101:  cond = ($signed(rs1) >= $signed(rs2));        // BGE
            3'b110:  cond = (rs1 <  rs2);                          // BLTU
            3'b111:  cond = (rs1 >= rs2);                          // BGEU
            default: cond = 1'b0;
        endcase

        // Jumps have highest priority
        if (jump) begin
            redirect  = 1'b1;
            target_pc = is_jalr ? ((rs1 + imm) & ~32'd1) : (pc + imm);
        end
        else if (branch && cond) begin
            redirect  = 1'b1;
            target_pc = pc + imm;
        end
    end

endmodule

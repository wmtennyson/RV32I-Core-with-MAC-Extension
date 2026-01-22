`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/22/2026 12:09:35 PM
// Design Name: 
// Module Name: immgena
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module immgena(
    input  logic [31:0] instr_i,
    output logic [31:0] imm_o
);
    logic [6:0] opcode;
    assign opcode = instr_i[6:0];

    always_comb begin
        unique case (opcode)
            // I-type (ADDI, ANDI, ORI, XORI, SLTI, loads, JALR)
            7'b0010011, 7'b0000011, 7'b1100111: begin
                imm_o = {{20{instr_i[31]}}, instr_i[31:20]};
            end

            // S-type (stores)
            7'b0100011: begin
                imm_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
            end

            // B-type (branches)
            7'b1100011: begin
                imm_o = {{19{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
            end

            // U-type (LUI/AUIPC)
            7'b0110111, 7'b0010111: begin
                imm_o = {instr_i[31:12], 12'b0};
            end

            // J-type (JAL)
            7'b1101111: begin
                imm_o = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
            end

            default: imm_o = 32'd0;
        endcase
    end
endmodule

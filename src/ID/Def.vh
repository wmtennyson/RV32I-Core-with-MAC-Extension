// File: Def.vh
// Shared macro definitions for the whole CPU project.

`ifndef DEF_VH
`define DEF_VH

// -------------------------
// ALU Control Codes (4-bit)
// Used by EXE_Control -> EXE_ALU via alu_ctrl[3:0]
// -------------------------
`define ADD                  4'b0000
`define SUB                  4'b0001
`define AND                  4'b0010
`define OR                   4'b0011
`define XOR                  4'b0100
`define SLL                  4'b0101
`define SRL                  4'b0110
`define SRA                  4'b0111
`define less_than            4'b1000
`define less_than_unsigned   4'b1001
`define greater_than         4'b1010
`define greater_than_unsigned 4'b1011
`define equal                4'b1100
`define not_equal            4'b1101
`define pc_plus_4            4'b1110
// 4'b1111 reserved

// -------------------------
// ALU Op Class Codes (3-bit)
// Used by Control_Unit -> EXE_Control via alu_op[2:0]
// -------------------------
`define NOP     3'b000
`define R_TYPE  3'b001
`define I_TYPE  3'b010
`define LOAD    3'b011
`define STORE   3'b100
`define BRANCH  3'b101
`define JUMP    3'b110
`define U_TYPE  3'b111

`endif // DEF_VH

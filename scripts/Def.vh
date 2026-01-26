// File: Def.vh
// Shared macro definitions for the whole CPU project.

`ifndef DEF_VH
`define DEF_VH

// -------------------------
// ALU Control Codes (4-bit)
// Used by EXE_Control -> EXE_ALU via alu_ctrl[3:0]
// -------------------------
`define ADD         4'b0000         // Addtion
`define SUB         4'b0001         // Subtraction
`define AND         4'b0010         // AND
`define OR          4'b0011         // OR
`define XOR         4'b0100         // XOR
`define SLL         4'b0101         // Shift Left Logical
`define SRL         4'b0110         // Shift Right Logical
`define SRA         4'b0111         // Arithmetic Right Shift, Signed 
`define SLT         4'b1000         // Set Less Than, Signed
`define SLTU        4'b1001         // Set Less Than, Unsigned
// 4'b1111 reserved

// -------------------------
// ALU Op Class Codes (3-bit)
// Used by Control_Unit -> EXE_Control via alu_op[2:0]
// -------------------------
`define R_TYPE      3'b000          // ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA
`define I_TYPE      3'b001          //ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI, JALR
`define STORE       3'b010          // SB, SH, SW
`define BRANCH      3'b011          // BEQ, BNE, BLT, BGE, BLTU, BGEU
`define U_TYPE      3'b100          // LUI, AUIPC
`define JUMP        3'b101          // JAL, JALR
`define LOAD        3'b110          // LW, LH, LB, LHU, LBU
`define NOP         3'b111          // No operation

`endif // DEF_VH


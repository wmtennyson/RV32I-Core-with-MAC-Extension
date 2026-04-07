`ifndef DEF_VH
`define DEF_VH

// ALU Control Codes (4-bit)
// Used by EXE_Control -> EXE_ALU via alu_ctrl[3:0]
`define ALU_ADD         4'b0000         // Addtion
`define ALU_SUB         4'b0001         // Subtraction
`define ALU_AND         4'b0010         // AND
`define ALU_OR          4'b0011         // OR
`define ALU_XOR         4'b0100         // XOR
`define ALU_SLL         4'b0101         // Shift Left Logical
`define ALU_SRL         4'b0110         // Shift Right Logical
`define ALU_SRA         4'b0111         // Arithmetic Right Shift, Signed 
`define ALU_SLT         4'b1000         // Set Less Than, Signed
`define ALU_SLTU        4'b1001         // Set Less Than, Unsigned
// 4'b1111 reserved

// ALU Op Class Codes (3-bit)
// Used by Control_Unit -> EXE_Control via alu_op[2:0]
`define OP_RTYPE        3'b000          // ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA
`define OP_ITYPE        3'b001          //ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI, JALR
`define OP_STORE        3'b010          // SB, SH, SW
`define OP_BRANCH       3'b011          // BEQ, BNE, BLT, BGE, BLTU, BGEU
`define OP_UTYPE        3'b100          // LUI, AUIPC
`define OP_JUMP         3'b101          // JAL, JALR
`define OP_LOAD         3'b110          // LW, LH, LB, LHU, LBU
`define OP_NOP          3'b111          // No operation

// MAC Unit Operation Codes and Associated Definitions
`define MAC_OP_NONE     3'b000
`define MAC_OP_MAC      3'b001
`define MAC_OP_MACCLR   3'b010
`define MAC_OP_RDLO     3'b011
`define MAC_OP_RDHI     3'b100

// Custom-0 opcode for MAC extension
`define OP_CUSTOM0      7'b0001011

// Fixed-point fractional bits (Q16.16 default)
`define MAC_FRAC_BITS  16

`endif // DEF_VH

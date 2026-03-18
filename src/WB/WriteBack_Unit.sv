`timescale 1ns / 1ps

module writeback_unit (

    // from mem/wb pipeline register
    input  logic        mem_wb_valid,
    input  logic [4:0]  mem_wb_rd,
    input  logic        mem_wb_regwrite,
    input  logic        mem_wb_write_data,   // 1 = memory result, 0 = alu result
    input  logic [31:0] mem_wb_alu_out,
    input  logic        mem_wb_load_valid,
    input  logic [31:0] mem_wb_load_data,
    
    input  logic [31:0] mem_wb_pc4,            // NEW
    input  logic        mem_wb_wb_pc4_sel,

    // register file write port
    output logic        rf_we,
    output logic [4:0]  rf_waddr,
    output logic [31:0] rf_wdata,

    // writeback stage outputs (forwarding / debug visibility)
    output logic        wb_valid,
    output logic        wb_regwrite_eff,     // regwrite after gating
    output logic [4:0]  wb_rd,
    output logic [31:0] wb_value
);

    always_comb begin
        wb_valid = mem_wb_valid;
        wb_rd    = mem_wb_rd;

        // NEW: PC4 has highest priority
        if (mem_wb_wb_pc4_sel) begin
            wb_value = mem_wb_pc4;
        end else begin
            wb_value = mem_wb_write_data ? mem_wb_load_data : mem_wb_alu_out;
        end

        // NEW: allow regwrite even if load_valid is 0 when selecting PC4 or ALU
        wb_regwrite_eff = mem_wb_valid
                       && mem_wb_regwrite
                       && (mem_wb_rd != 5'd0)
                       && ( mem_wb_wb_pc4_sel
                            || !mem_wb_write_data
                            || mem_wb_load_valid );

        rf_we    = wb_regwrite_eff;
        rf_waddr = mem_wb_rd;
        rf_wdata = wb_value;
    end

endmodule


`timescale 1ns / 1ps

module WriteBack_Unit (
    // From MEM/WB register
    input  logic        valid_i,
    input  logic [4:0]  rd_i,
    input  logic        regwrite_i,
    input  logic        wb_sel_i,       // 0=ALU, 1=memory
    input  logic        wb_pc4_sel_i,   // 1=PC+4 (JAL/JALR link)
    input  logic [31:0] alu_out_i,
    input  logic        load_valid_i,
    input  logic [31:0] load_data_i,
    input  logic [31:0] pc4_i,

    // Register file write port
    output logic        rf_we_o,
    output logic [4:0]  rf_waddr_o,
    output logic [31:0] rf_wdata_o,

    // Forwarding / debug outputs
    output logic        wb_valid_o,
    output logic        wb_regwrite_o,
    output logic [4:0]  wb_rd_o,
    output logic [31:0] wb_value_o
);

    always_comb begin
        wb_valid_o = valid_i;
        wb_rd_o    = rd_i;

        // Data selection: PC+4 > MEM > ALU
        if (wb_pc4_sel_i)
            wb_value_o = pc4_i;
        else if (wb_sel_i)
            wb_value_o = load_data_i;
        else
            wb_value_o = alu_out_i;

        // Gate regwrite: valid && regwrite && rd!=x0 &&
        wb_regwrite_o = valid_i && regwrite_i && (rd_i != 5'd0)
                     && (wb_pc4_sel_i || !wb_sel_i || load_valid_i);

        rf_we_o    = wb_regwrite_o;
        rf_waddr_o = rd_i;
        rf_wdata_o = wb_value_o;
    end

endmodule

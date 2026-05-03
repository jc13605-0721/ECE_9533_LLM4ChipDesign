// Single MAC Unit: Multiply-Accumulate
// Performs: accumulator = accumulator + (a * b)
module mac_unit #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 20  // Wide enough to prevent overflow
)(
    input  logic                    clock,
    input  logic                    reset,
    input  logic                    enable,      // Enable accumulation
    input  logic                    clear,       // Clear accumulator
    input  logic [DATA_WIDTH-1:0]   a,           // First operand
    input  logic [DATA_WIDTH-1:0]   b,           // Second operand
    output logic [ACC_WIDTH-1:0]    accumulator  // Accumulated result
);

    logic [2*DATA_WIDTH-1:0] product;
    
    // Multiply inputs
    assign product = a * b;
    
    // Accumulate on clock edge
    always_ff @(posedge clock or posedge reset) begin
        if (reset || clear) begin
            accumulator <= '0;
        end else if (enable) begin
            accumulator <= accumulator + product;
        end
    end

endmodule


// 2x2 MAC Array
// Contains 4 MAC units arranged in a 2x2 grid
module mac_array_2x2 #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 20
)(
    input  logic                    clock,
    input  logic                    reset,
    input  logic                    enable,        // Global enable for all MACs
    input  logic                    clear_all,     // Clear all accumulators
    
    // Inputs for MAC[0][0] - top-left
    input  logic [DATA_WIDTH-1:0]   a_00,
    input  logic [DATA_WIDTH-1:0]   b_00,
    output logic [ACC_WIDTH-1:0]    acc_00,
    
    // Inputs for MAC[0][1] - top-right
    input  logic [DATA_WIDTH-1:0]   a_01,
    input  logic [DATA_WIDTH-1:0]   b_01,
    output logic [ACC_WIDTH-1:0]    acc_01,
    
    // Inputs for MAC[1][0] - bottom-left
    input  logic [DATA_WIDTH-1:0]   a_10,
    input  logic [DATA_WIDTH-1:0]   b_10,
    output logic [ACC_WIDTH-1:0]    acc_10,
    
    // Inputs for MAC[1][1] - bottom-right
    input  logic [DATA_WIDTH-1:0]   a_11,
    input  logic [DATA_WIDTH-1:0]   b_11,
    output logic [ACC_WIDTH-1:0]    acc_11
);

    // Instantiate MAC[0][0]
    mac_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) mac_00 (
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .clear(clear_all),
        .a(a_00),
        .b(b_00),
        .accumulator(acc_00)
    );
    
    // Instantiate MAC[0][1]
    mac_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) mac_01 (
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .clear(clear_all),
        .a(a_01),
        .b(b_01),
        .accumulator(acc_01)
    );
    
    // Instantiate MAC[1][0]
    mac_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) mac_10 (
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .clear(clear_all),
        .a(a_10),
        .b(b_10),
        .accumulator(acc_10)
    );
    
    // Instantiate MAC[1][1]
    mac_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) mac_11 (
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .clear(clear_all),
        .a(a_11),
        .b(b_11),
        .accumulator(acc_11)
    );

endmodule

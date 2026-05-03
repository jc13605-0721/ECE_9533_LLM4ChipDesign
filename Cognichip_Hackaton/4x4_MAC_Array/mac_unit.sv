// =============================================================================
// Module: mac_unit
// Description: Signed Multiply-Accumulate Unit
//              Computes: result = accumulator + (a * b)
//              Reusable building block for MAC array
// =============================================================================

module mac_unit #(
    parameter int DATA_W = 8,   // Input operand width
    parameter int MUL_W  = 16,  // Multiplier output width
    parameter int ACC_W  = 32   // Accumulator width
) (
    input  logic signed [DATA_W-1:0] a,           // Multiplicand
    input  logic signed [DATA_W-1:0] b,           // Multiplier
    input  logic signed [ACC_W-1:0]  accumulator, // Current accumulator value
    output logic signed [ACC_W-1:0]  result       // MAC result
);

    // Internal product register
    logic signed [MUL_W-1:0] product;

    // Combinational multiply
    assign product = a * b;

    // Combinational accumulate with sign extension
    assign result = accumulator + { {(ACC_W-MUL_W){product[MUL_W-1]}}, product };

endmodule

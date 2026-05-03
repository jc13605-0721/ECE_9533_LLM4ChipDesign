// =============================================================================
// Module: mac_array_4x4
// Description: 4x4 MAC Array Accelerator for Matrix Multiplication
//              Computes C[i][j] = sum(A[i][k] * B[k][j]) for k=0 to N-1
//              Features:
//              - Internal A and B register buffers
//              - 16 MAC units computing all products in parallel
//              - N-cycle accumulation (one k-iteration per cycle)
//              - Register-mapped load/readout interface
// =============================================================================

module mac_array_4x4 #(
    parameter int N      = 4,   // Matrix dimension (4x4)
    parameter int DATA_W = 8,   // Input data width (int8)
    parameter int MUL_W  = 16,  // Multiplier output width
    parameter int ACC_W  = 32   // Accumulator width
) (
    input  logic                    clock,
    input  logic                    reset_n,
    
    // Load interface for A matrix
    input  logic                    load_A,
    input  logic [3:0]              a_addr,     // Linear address 0-15
    input  logic signed [DATA_W-1:0] a_wdata,
    
    // Load interface for B matrix
    input  logic                    load_B,
    input  logic [3:0]              b_addr,     // Linear address 0-15
    input  logic signed [DATA_W-1:0] b_wdata,
    
    // Control interface
    input  logic                    start,      // Start computation
    output logic                    done,       // Computation complete
    output logic                    out_valid,  // Output valid flag
    
    // Readout interface for C matrix
    input  logic [3:0]              out_addr,   // Linear address 0-15
    output logic signed [ACC_W-1:0] out_rdata   // C matrix element
);

    // =========================================================================
    // Internal Storage Arrays
    // =========================================================================
    logic signed [DATA_W-1:0] A_buf [0:N-1][0:N-1];
    logic signed [DATA_W-1:0] B_buf [0:N-1][0:N-1];
    logic signed [ACC_W-1:0]  C_acc [0:N-1][0:N-1];

    // =========================================================================
    // Controller Signals
    // =========================================================================
    logic       clear_acc;
    logic       compute_en;
    logic       ld_a_en;
    logic       ld_b_en;
    logic [3:0] k_index;

    // =========================================================================
    // Controller FSM Instance
    // =========================================================================
    controller_fsm #(
        .N(N)
    ) u_controller (
        .clock      (clock),
        .reset_n    (reset_n),
        .load_A     (load_A),
        .load_B     (load_B),
        .start      (start),
        .done       (done),
        .out_valid  (out_valid),
        .clear_acc  (clear_acc),
        .compute_en (compute_en),
        .ld_a_en    (ld_a_en),
        .ld_b_en    (ld_b_en),
        .k_index    (k_index)
    );

    // =========================================================================
    // A Buffer Write Logic
    // =========================================================================
    always_ff @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    A_buf[i][j] <= '0;
                end
            end
        end else if (ld_a_en && load_A) begin
            // Linear addressing: a_addr = i*N + j
            A_buf[a_addr[3:2]][a_addr[1:0]] <= a_wdata;
        end
    end

    // =========================================================================
    // B Buffer Write Logic
    // =========================================================================
    always_ff @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    B_buf[i][j] <= '0;
                end
            end
        end else if (ld_b_en && load_B) begin
            // Linear addressing: b_addr = i*N + j
            B_buf[b_addr[3:2]][b_addr[1:0]] <= b_wdata;
        end
    end

    // =========================================================================
    // MAC Array - Compute and Accumulate
    // =========================================================================
    // MAC unit outputs for all 16 elements
    logic signed [ACC_W-1:0] mac_result [0:N-1][0:N-1];

    // Instantiate 16 MAC units (one per output element)
    generate
        for (genvar i = 0; i < N; i++) begin : gen_row
            for (genvar j = 0; j < N; j++) begin : gen_col
                mac_unit #(
                    .DATA_W(DATA_W),
                    .MUL_W (MUL_W),
                    .ACC_W (ACC_W)
                ) u_mac (
                    .a          (A_buf[i][k_index]),
                    .b          (B_buf[k_index][j]),
                    .accumulator(C_acc[i][j]),
                    .result     (mac_result[i][j])
                );
            end
        end
    endgenerate

    // =========================================================================
    // Accumulator Array Update Logic
    // =========================================================================
    always_ff @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    C_acc[i][j] <= '0;
                end
            end
        end else if (clear_acc) begin
            // Clear before computation
            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    C_acc[i][j] <= '0;
                end
            end
        end else if (compute_en) begin
            // Update accumulators with MAC results
            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    C_acc[i][j] <= mac_result[i][j];
                end
            end
        end
    end

    // =========================================================================
    // Readout Logic
    // =========================================================================
    always_comb begin
        // Linear addressing: out_addr = i*N + j
        out_rdata = C_acc[out_addr[3:2]][out_addr[1:0]];
    end

endmodule

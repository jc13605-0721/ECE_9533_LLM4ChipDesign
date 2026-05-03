module controller_fsm #(
    parameter int N = 4
) (
    input  logic       clock,
    input  logic       reset_n,
    input  logic       load_A,
    input  logic       load_B,
    input  logic       start,
    output logic       done,
    output logic       out_valid,
    output logic       clear_acc,
    output logic       compute_en,
    output logic       ld_a_en,
    output logic       ld_b_en,
    output logic [3:0] k_index
);

    typedef enum logic [2:0] {
        IDLE    = 3'b000,
        LOAD    = 3'b001,
        CLEAR   = 3'b010,
        SETUP   = 3'b011,
        COMPUTE = 3'b100,
        DONE    = 3'b101
    } state_t;

    state_t current_state, next_state;

    logic [3:0] k_counter, k_counter_next;
    logic       k_counter_en;
    logic       k_counter_rst;

    always_ff @(posedge clock or negedge reset_n) begin
        if (!reset_n) current_state <= IDLE;
        else          current_state <= next_state;
    end

    always_ff @(posedge clock or negedge reset_n) begin
        if (!reset_n) k_counter <= 4'h0;
        else          k_counter <= k_counter_next;
    end

    always_comb begin
        if (k_counter_rst)       k_counter_next = 4'h0;
        else if (k_counter_en)   k_counter_next = k_counter + 4'h1;
        else                     k_counter_next = k_counter;
    end

    assign k_index = k_counter;

    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE:    if (load_A || load_B) next_state = LOAD; else if (start) next_state = CLEAR;
            LOAD:    if (!load_A && !load_B) next_state = IDLE;
            CLEAR:   next_state = SETUP;
            SETUP:   next_state = COMPUTE;
            COMPUTE: if (k_counter == (N-1)) next_state = DONE;
            DONE:    if (load_A || load_B) next_state = LOAD; else if (start) next_state = CLEAR;
            default: next_state = IDLE;
        endcase
    end

    always_comb begin
        clear_acc     = 1'b0;
        compute_en    = 1'b0;
        ld_a_en       = 1'b0;
        ld_b_en       = 1'b0;
        done          = 1'b0;
        out_valid     = 1'b0;
        k_counter_en  = 1'b0;
        k_counter_rst = 1'b0;

        case (current_state)
            IDLE: begin
                ld_a_en   = load_A;
                ld_b_en   = load_B;
                out_valid = 1'b0;
            end
            LOAD: begin
                ld_a_en = load_A;
                ld_b_en = load_B;
            end
            CLEAR: begin
                clear_acc     = 1'b1;
                k_counter_rst = 1'b1;
            end
            COMPUTE: begin
                compute_en = 1'b1;
                if (k_counter < (N-1)) k_counter_en = 1'b1;
            end
            DONE: begin
                done      = 1'b1;
                out_valid = 1'b1;
                ld_a_en   = load_A;
                ld_b_en   = load_B;
            end
            default: ;
        endcase
    end

endmodule

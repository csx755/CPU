`timescale 1ns / 1ps

// =============================================================================
// lpf.v — First-order IIR lowpass filter (2-stage pipeline, full-precision)
// =============================================================================
//   y[n+1] = y[n] + (2^cutoff / 2^16) * (x[n] - y[n])
//
//   2-stage pipeline breaks the diff→shift→add critical path:
//     Stage 1: diff = x - y  (subtraction)  →  diff_reg
//     Stage 2: update = diff_reg >>> shift, y = y + update  →  y
//
//   f_c ≈ f_clk * 2^cutoff / (2π * 2^16)
//   cutoff=0: ~243Hz  cutoff=4: ~3.9kHz  cutoff=8: ~62kHz
//   cutoff=12: ~995kHz  cutoff=14: ~4MHz  cutoff>=16: bypass
// =============================================================================

module lpf (
    input             clk,
    input             rst,
    input      [9:0]  audio_in,
    input      [4:0]  cutoff_val,
    output reg [9:0]  audio_out
);

    // ---- internal state: 27-bit signed Q11.16 ----
    reg signed [26:0] y;

    // input in same fixed-point format
    wire signed [26:0] x_scaled = {1'b0, audio_in, 16'd0};

    // ---- Stage 1: compute error ----
    wire signed [27:0] diff        = x_scaled - y;
    wire               bypass      = (cutoff_val >= 5'd16);
    wire [4:0]         shift       = 5'd16 - cutoff_val;

    reg signed [27:0] diff_reg;
    reg               bypass_s1;
    reg [4:0]         shift_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            diff_reg   <= 28'd0;
            bypass_s1  <= 1'b0;
            shift_reg  <= 5'd0;
        end else begin
            diff_reg   <= diff;
            bypass_s1  <= bypass;
            shift_reg  <= shift;
        end
    end

    // ---- Stage 2: apply update ----
    wire signed [26:0] update = diff_reg >>> shift_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            y <= 27'd0;
        end else if (bypass_s1) begin
            y <= x_scaled;
        end else begin
            y <= y + update;
        end
    end

    // ---- output extraction ----
    always @(posedge clk) begin
        audio_out <= (y[26]) ? 10'd0 : y[25:16];
    end

endmodule

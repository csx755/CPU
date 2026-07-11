`timescale 1ns / 1ps

// =============================================================================
// piano_env.v — 3-stage piano envelope (ATTACK→BODY→TAIL)
// =============================================================================
//   Triggered by gate rising edge (one-shot, does not retrigger until idle)
//   Outputs crossfade weight + table selects for dual-port piano_table
//
//   Parameters (8-bit, from register):
//     attack_rate : crossfade step per ms (0=instant, 1=slow, 128=~2ms attack)
//     body_hold   : body duration (×16 ms, 0-4080ms)
//     tail_rate   : decay step per ms (0=instant, 1=slow, 128=~2ms tail)
//     noise_level : noise gain at attack start, ramps to 0 during attack
//
//   State flow:
//     IDLE —gate_rise→ ATTACK (attack→body crossfade + noise)
//     ATTACK —cf=255→ BODY   (body table only, full volume)
//     BODY   —timeout→ TAIL  (body→tail crossfade + volume decay)
//     TAIL   —env=0→  IDLE
// =============================================================================

module piano_env (
    input  clk,
    input  rst,
    input  gate,

    input  [7:0] attack_rate,
    input  [7:0] body_hold,
    input  [7:0] tail_rate,
    input  [7:0] noise_level,

    output [7:0] env_out,       // overall volume (0-255)
    output [7:0] cf_weight,     // crossfade: 0=table_a, 255=table_b
    output [1:0] table_sel_a,   // table select port A
    output [1:0] table_sel_b,   // table select port B
    output       noise_en,      // noise enable flag
    output [7:0] noise_gain     // noise gain (0-255)
);

    // ---- 1ms tick ----
    reg [16:0] tick_cnt;
    wire tick = (tick_cnt >= 17'd100_000);

    always @(posedge clk) begin
        if (rst || tick) tick_cnt <= 17'd0;
        else             tick_cnt <= tick_cnt + 17'd1;
    end

    // ---- gate edge detect (sampled at tick rate) ----
    reg gate_d;
    always @(posedge clk or posedge rst) begin
        if (rst) gate_d <= 1'b0;
        else if (tick) gate_d <= gate;
    end
    wire gate_rise = gate && !gate_d;

    // ---- state machine ----
    localparam IDLE   = 2'd0;
    localparam ATTACK = 2'd1;
    localparam BODY   = 2'd2;
    localparam TAIL   = 2'd3;

    reg [1:0]  state;
    reg [15:0] cf_acc;         // crossfade accumulator (8.8 fixed-point)
    reg [15:0] env_acc;        // envelope accumulator (8.8)
    reg [15:0] body_cnt;       // body hold counter (ticks)
    reg [15:0] body_max;       // body hold target

    // ---- step values derived from parameters ----
    wire [15:0] att_step = {attack_rate, 8'd0};   // attack_rate << 8
    wire [15:0] body_ticks = {body_hold, 4'd0};   // body_hold × 16
    wire [15:0] tail_step = {tail_rate, 8'd0};    // tail_rate << 8

    // outputs from accumulators
    assign cf_weight  = cf_acc[15:8];
    assign env_out    = env_acc[15:8];
    assign table_sel_a = (state == ATTACK) ? 2'd0 :            // attack→body crossfade
                         (state == TAIL)   ? 2'd1 :            // body→tail crossfade
                                             2'd1;             // body only (or idle)
    assign table_sel_b = (state == ATTACK) ? 2'd1 :
                         (state == TAIL)   ? 2'd2 :
                                             2'd1;

    assign noise_en   = (state == ATTACK);
    // noise_gain = noise_level * (1 - cf_weight/255)
    wire [15:0] ng_mul = noise_level * (16'd255 - {8'd0, cf_weight});
    assign noise_gain  = ng_mul[15:8];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            cf_acc   <= 16'd0;
            env_acc  <= 16'd0;
            body_cnt <= 16'd0;
            body_max <= 16'd0;
        end else if (tick) begin
            case (state)
                IDLE: begin
                    cf_acc  <= 16'd0;
                    env_acc <= 16'd0;
                    if (gate_rise) begin
                        if (attack_rate == 8'd0) begin
                            // instant attack: skip to body
                            state  <= BODY;
                            cf_acc <= 16'hFF00;  // 255 in 8.8
                            env_acc <= 16'hFF00;
                            body_cnt <= 16'd0;
                            body_max <= body_ticks;
                        end else begin
                            state <= ATTACK;
                            cf_acc <= 16'd0;
                            env_acc <= 16'hFF00;  // full volume during attack
                        end
                    end
                end

                ATTACK: begin
                    // linear ramp cf_weight from 0 to 255
                    if (cf_acc >= 16'hFF00 - att_step) begin
                        cf_acc  <= 16'hFF00;
                        state   <= BODY;
                        body_cnt <= 16'd0;
                        body_max <= body_ticks;
                    end else begin
                        cf_acc <= cf_acc + att_step;
                    end
                end

                BODY: begin
                    if (gate_rise) begin
                        state    <= ATTACK;
                        cf_acc   <= 16'd0;
                        env_acc  <= 16'hFF00;
                    end else begin
                        // hold at full volume, 100% body table
                        cf_acc  <= 16'hFF00;
                        env_acc <= 16'hFF00;
                        if (body_cnt >= body_max) begin
                            if (tail_rate == 8'd0) begin
                                state   <= IDLE;
                                env_acc <= 16'd0;
                            end else begin
                                state <= TAIL;
                                cf_acc <= 16'd0;
                            end
                        end else begin
                            body_cnt <= body_cnt + 16'd1;
                        end
                    end
                end

                TAIL: begin
                    if (gate_rise) begin
                        state    <= ATTACK;
                        cf_acc   <= 16'd0;
                        env_acc  <= 16'hFF00;
                    end else begin
                        // crossfade body→tail (cf_acc 0→255)
                        // volume decay (env_acc 255→0)
                        if (cf_acc >= 16'hFF00 - tail_step) begin
                            cf_acc  <= 16'hFF00;
                        end else begin
                            cf_acc <= cf_acc + tail_step;
                        end

                        if (env_acc <= tail_step) begin
                            env_acc <= 16'd0;
                            state   <= IDLE;
                        end else begin
                            env_acc <= env_acc - tail_step;
                        end
                    end
                end
            endcase
        end
    end

endmodule

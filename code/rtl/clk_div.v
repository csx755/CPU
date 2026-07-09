`timescale 1ns / 1ps
`define SIM 1
module clk_div(
    input               clk,
    input               rst,
    input               SW2,
    output reg [31:0]   clkdiv,
    output              Clk_CPU
);

    initial begin
        clkdiv = 32'b0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            clkdiv <= 32'b0;
        else
            clkdiv <= clkdiv + 1'b1;
    end

    // 仿真时 Clk_CPU = clk (100MHz, 10ns/cycle), 快速验证
    // 下板时用正常分频: SW2=0 → 6.25MHz, SW2=1 → ~6Hz
    `ifdef SIM
    assign Clk_CPU = clk;
    `else
    assign Clk_CPU = (SW2) ? clkdiv[24] : clkdiv[3];
    `endif

endmodule

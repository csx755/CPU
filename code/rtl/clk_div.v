`timescale 1ns / 1ps
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

    assign Clk_CPU = (SW2) ? clkdiv[24] : clkdiv[3];

endmodule

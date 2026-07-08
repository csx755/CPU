// GRE_array — 通用流水线寄存器 (含 write_enable / flush)
// 在 negedge Clk 锁存, posedge Rst 异步复位
module GRE_array #(
    parameter WIDTH = 64
)(
    input                   Clk,
    input                   Rst,
    input                   write_enable,   // 1=正常流动, 0=保持 (冻结)
    input                   flush,          // 1=清零输出 (插入 NOP)
    input  [WIDTH-1:0]      in,
    output reg [WIDTH-1:0]  out
);
    always @(negedge Clk) begin
        if (write_enable) begin
            if (flush)
                out <= 0;
            else
                out <= in;
        end
    end

    always @(posedge Rst) begin
        out <= 0;
    end
endmodule

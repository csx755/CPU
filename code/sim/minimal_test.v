// minimal_test — 最小化定位性能瓶颈
`timescale 1ns / 1ps
module minimal_test();

    reg clk, rst;

    // === Test A: 纯 ROM, 无 CPU ===
    reg [9:0] rom_addr;
    wire [31:0] rom_data;

    ROM U_ROM (.a(rom_addr), .spo(rom_data));

    initial clk = 1'b0;
    always #50 clk = ~clk;

    integer tick;
    initial begin
        clk = 0; rst = 1; tick = 0; rom_addr = 10'd0;

        $display("=== Minimal: ROM only ===");

        repeat(100) begin
            @(posedge clk);
            tick = tick + 1;
            rom_addr <= rom_addr + 1;
        end
        $display("  100 ROM reads done");

        $display("=== Minimal: Clock only (no modules) ===");

        // Test B: 纯时钟, 什么都不接
        // (需要另一个模块避免编译优化)
        $finish;
    end

endmodule

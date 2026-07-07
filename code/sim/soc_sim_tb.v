// soc_sim_tb — 逐步集成, 定位性能瓶颈
`timescale 1ns / 1ps

module soc_sim_tb();

    reg clk, rstn;
    reg [4:0] btn_i;
    reg [15:0] sw_i;
    wire [7:0] disp_an_o, disp_seg_o;
    wire [15:0] led_o;

    soc_top U_SOC (
        .clk(clk), .rstn(rstn), .btn_i(btn_i), .sw_i(sw_i),
        .disp_an_o(disp_an_o), .disp_seg_o(disp_seg_o), .led_o(led_o)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    function [31:0] read_ram(input [9:0] addr);
        read_ram = U_SOC.U_RAM_B.mem[addr];
    endfunction

    integer tick;
    initial begin
        clk = 0; rstn = 0; btn_i = 0; sw_i = 0; tick = 0;

        #200 rstn = 1'b1;
        sw_i[2] = 1'b0;
        #200;

        $display("=== SoC Sim: 2000 cycles ===");

        // 只跑 2000 个 clk 周期 (相当于 ~125 条 CPU 指令)
        repeat(2000) begin
            @(posedge clk);
            tick = tick + 1;
            // 每 500 周期打印进度
            if (tick % 500 == 0)
                $display("  %0d cycles, PC=0x%08X", tick, U_SOC.PC);
        end

        $display("\nRAM dump:");
        $display("  RAM[0]=0x%08X", read_ram(10'd0));
        $display("  RAM[1]=0x%08X", read_ram(10'd1));
        $display("  RAM[2]=0x%08X", read_ram(10'd2));
        $display("  RAM[3]=0x%08X", read_ram(10'd3));
        $display("  PC=0x%08X inst=0x%08X", U_SOC.PC, U_SOC.inst_in);

        if (read_ram(10'd0) == 32'h000000EF)
            $display("[PASS] SW @ 0x000 = 0xEF");
        else
            $display("[FAIL] SW @ 0x000 = 0x%08X", read_ram(10'd0));

        $display("=== Done ===");
        $finish;
    end

endmodule

// soc_top_tb — Vivado 仿真基础版本 (已验证可用)
// sw_i[6]=1, 观察 PC 轨迹
`timescale 1ns / 1ps

module soc_top_tb();

    reg         clk, rstn;
    reg  [4:0]  btn_i;
    reg  [15:0] sw_i;
    wire [7:0]  disp_an_o, disp_seg_o;
    wire [15:0] led_o;

    soc_top U_SOC (
        .clk(clk), .rstn(rstn), .btn_i(btn_i), .sw_i(sw_i),
        .disp_an_o(disp_an_o), .disp_seg_o(disp_seg_o), .led_o(led_o)
    );

    // ---- 100MHz 时钟 ----
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- 仿真主体 ----
    integer cycle;
    reg [31:0] prev_pc;

    initial begin
        rstn    = 1'b0;
        btn_i   = 5'b0;
        sw_i    = 16'b0;
        cycle   = 0;
        prev_pc = 32'hffff_ffff;

        sw_i[6] = 1'b1;

        #200 rstn = 1'b1;

        $display("============================================");
        $display(" soc_top simulation — testac.coe");
        $display(" sw_i[6]=1 (SW[7:5]=010 → inst_in channel)");
        $display(" CPU clock = 100MHz");
        $display("============================================");
        $display("");
        $display(" Cycle | Time        | PC       | inst_in   | mem_w | Addr_out  ");
        $display("-------|-------------|----------|-----------|-------|-----------");
    end

    always @(posedge U_SOC.Clk_CPU) begin
        if (rstn) begin
            cycle = cycle + 1;
            if (U_SOC.PC != prev_pc || U_SOC.mem_w) begin
                $display(" %5d | %12t | 0x%06X | 0x%08X | %b     | 0x%08X",
                         cycle, $time, U_SOC.PC, U_SOC.inst_in,
                         U_SOC.mem_w, U_SOC.Addr_out);
                prev_pc = U_SOC.PC;
            end
        end
    end

    // ---- 中断信号监控 ----
    always @(posedge U_SOC.Clk_CPU) begin
        if (rstn && U_SOC.counter0_out !== 1'b0)
            $display(" %8d | %5d | -------- | *** counter0_out = %b, PC = 0x%06X ***",
                     $time, cycle, U_SOC.counter0_out, U_SOC.PC);
    end

    // ---- 仿真超时 ----
    initial begin
        #5000000;  // 5ms
        $display("");
        $display("============================================");
        $display(" Simulation timeout after 5ms");
        $display(" CPU PC = 0x%06X, inst = 0x%08X",
                 U_SOC.PC, U_SOC.inst_in);
        $display(" mem_w = %b, Addr_out = 0x%08X, Data_out = 0x%08X",
                 U_SOC.mem_w, U_SOC.Addr_out, U_SOC.Data_out);
        $display(" counter0_out = %b", U_SOC.counter0_out);
        $display("============================================");
        $finish;
    end

endmodule

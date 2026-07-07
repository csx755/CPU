// soc_top Post-Synthesis 仿真 - 带断点长时间测试
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

    integer test_no;
    integer prev_an_count;

    initial begin
        clk = 0; rstn = 0; btn_i = 0; sw_i = 0;
        test_no = 0; prev_an_count = 0;

        // 复位
        #100 rstn = 1;
        #100;

        // 慢速模式 SW[2]=1, 等扫描启动
        sw_i[2] = 1'b1;

        // ========================================================
        // Test 0: 等扫描启动, 看 clkdiv[14] 翻转
        // ========================================================
        $display("\n[Test %0d] 初始化 + 等扫描...", test_no);
        test_no = test_no + 1;
        wait_ms(2);
        report("扫描就绪");

        // ========================================================
        // Test 1-7: SW[7:5] 各通道
        // ========================================================
        ch_test(3'b000, "CPU输出");
        ch_test(3'b001, "PC");
        ch_test(3'b010, "指令");
        ch_test(3'b011, "计数器");
        ch_test(3'b100, "RAM地址");
        ch_test(3'b101, "数据输出");
        ch_test(3'b110, "数据输入");

        // ========================================================
        // Test 8: 图形模式
        // ========================================================
        sw_i[0]   = 1'b1;
        sw_i[7:5] = 3'b000;
        $display("\n[Test %0d] 图形:跑马灯", test_no); test_no = test_no + 1;
        wait_ms(5);
        report("跑马灯");

        // ========================================================
        // Test 9: 快时钟
        // ========================================================
        sw_i[2]   = 1'b0;
        sw_i[0]   = 1'b0;
        sw_i[7:5] = 3'b000;
        $display("\n[Test %0d] 快时钟 6.25MHz", test_no); test_no = test_no + 1;
        wait_ms(1);
        report("快时钟");

        $display("\n===== ALL TESTS DONE =====");
        $finish;
    end

    // ================================================================
    // ch_test: 设置 SW[7:5] + 运行
    // ================================================================
    task ch_test(input [2:0] ch, input [8*8:1] name);
        begin
            sw_i[0]   = 1'b0;
            sw_i[7:5] = ch;
            $display("\n[Test %0d] SW[7:5]=%b %s", test_no, ch, name);
            test_no = test_no + 1;
            wait_ms(1);
            report(name);
        end
    endtask

    // ================================================================
    // wait_ms: 等 N 毫秒 (100MHz时钟)
    // ================================================================
    task wait_ms(input integer n);
        begin
            repeat(n * 100000) @(posedge clk);
        end
    endtask

    // ================================================================
    // report: 打印关键信号 + $stop 断点
    // ================================================================
    task report(input [8*8:1] name);
        begin
            $display("--- %s ---", name);
            $display("  disp_an =%b  disp_seg=%b", disp_an_o, disp_seg_o);
            $display("  clkdiv[14]=%b  clkdiv[0]=%b  Clk_CPU=%b",
                     U_SOC.clkdiv[14], U_SOC.clkdiv[0], U_SOC.Clk_CPU);
            $display("  PC=0x%08X  inst_in=0x%08X", U_SOC.PC, U_SOC.inst_in);
            $display("  Addr_out=0x%08X  Data_in=0x%08X  Data_out=0x%08X",
                     U_SOC.Addr_out, U_SOC.Data_in, U_SOC.Data_out);
            $display("  Disp_num=0x%08X  led_o=0x%04X", U_SOC.Disp_num, led_o);
            $display("  >> Type 'run -continue' in Tcl <<");
            $stop;
        end
    endtask

    // 100MHz
    always #5 clk = ~clk;

endmodule

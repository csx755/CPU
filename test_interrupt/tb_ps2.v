`timescale 1ns / 1ps

module tb_ps2;

    // 时钟和复位
    reg clk;
    reg rstn;
    
    // 按钮和开关
    reg [4:0] btn_i;
    reg [15:0] sw_i;
    
    // 输出
    wire [7:0] disp_an_o;
    wire [7:0] disp_seg_o;
    wire [15:0] led_o;
    
    // PS2 接口（双向）
    wire PS2C;
    wire PS2D;
    
    // PS2 键盘模拟
    reg ps2_clk_en;
    reg ps2_data_en;
    reg ps2_clk_out;
    reg ps2_data_out;
    
    // 三态缓冲器控制
    assign PS2C = ps2_clk_en ? ps2_clk_out : 1'bz;
    assign PS2D = ps2_data_en ? ps2_data_out : 1'bz;
    
    // 实例化顶层模块
    top u_top(
        .rstn(rstn),
        .btn_i(btn_i),
        .sw_i(sw_i),
        .clk(clk),
        .disp_an_o(disp_an_o),
        .disp_seg_o(disp_seg_o),
        .led_o(led_o),
        .PS2C(PS2C),
        .PS2D(PS2D)
    );
    
    // 时钟生成：100MHz
    initial clk = 0;
    always #5 clk = ~clk;
    
    // PS2 时序任务：发送一个字节
    // PS2 协议：起始位(0) + 8位数据(LSB first) + 奇偶校验 + 停止位(1)
    task send_ps2_byte;
        input [7:0] data;
        integer i;
        reg parity;
        begin
            // 计算奇偶校验（PS2 用奇校验：data+parity 中 1 的个数为奇数）
            parity = ~^data;
            
            // 起始位
            ps2_data_out = 0;
            ps2_clk_out = 1;
            ps2_data_en = 1;
            ps2_clk_en = 1;
            #20000;  // 等待约 20us（PS2 时钟约 10-16kHz）
            ps2_clk_out = 0;
            #20000;
            
            // 发送 8 位数据（LSB first）
            for (i = 0; i < 8; i = i + 1) begin
                ps2_data_out = data[i];
                ps2_clk_out = 1;
                #20000;
                ps2_clk_out = 0;
                #20000;
            end
            
            // 奇偶校验位
            ps2_data_out = parity;
            ps2_clk_out = 1;
            #20000;
            ps2_clk_out = 0;
            #20000;
            
            // 停止位
            ps2_data_out = 1;
            ps2_clk_out = 1;
            #20000;
            ps2_clk_out = 0;
            #20000;
            
            // 释放总线
            ps2_data_en = 0;
            ps2_clk_en = 0;
            ps2_data_out = 1;
            ps2_clk_out = 1;
        end
    endtask
    
    // 测试序列
    initial begin
        // 初始化
        rstn = 0;
        btn_i = 0;
        sw_i = 16'h0000;  // SW2=0 → Clk_CPU = clkdiv[2]（仿真用快速时钟）
        ps2_clk_en = 0;
        ps2_data_en = 0;
        ps2_clk_out = 1;
        ps2_data_out = 1;
        
        // 复位
        #100;
        rstn = 1;
        
        // 等待 CPU 启动
        #1000000;
        
        // 打印初始状态
        $display("=== PS2 键盘中断测试 ===");
        $display("初始 LED: %h", led_o);
        
        // 等待 ecall 执行（main 函数会调用 ecall）
        #5000000;
        
        $display("ecall 后 LED: %h", led_o);
        
        // 发送 PS2 扫描码：按下数字键 '1'（扫描码 0x16）
        $display("发送 PS2 扫描码 0x16 (数字键 1)...");
        send_ps2_byte(8'h16);
        
        // 等待中断处理
        #1000000;
        
        $display("中断后 LED: %h", led_o);
        
        // 发送松开信号（0xF0 + 0x16）
        $display("发送 PS2 松开信号 0xF0...");
        send_ps2_byte(8'hF0);
        #500000;
        $display("发送 PS2 扫描码 0x16 (松开)...");
        send_ps2_byte(8'h16);
        
        #1000000;
        $display("松开后 LED: %h", led_o);
        
        // 发送数字键 '2'（扫描码 0x1E）
        $display("发送 PS2 扫描码 0x1E (数字键 2)...");
        send_ps2_byte(8'h1E);
        
        #1000000;
        $display("中断后 LED: %h", led_o);
        
        // 结束仿真
        #1000000;
        $display("=== 测试完成 ===");
        $finish;
    end
    
    // 监控关键信号
    initial begin
        $monitor("Time=%0t PS2Ready=%b INT=%b MIE=%b LED=%h", 
                 $time, 
                 u_top.ps2_ready, 
                 u_top.INT,
                 u_top.U1_SCPU.mstatus[3],
                 led_o);
    end
    
    // 生成波形文件
    initial begin
        $dumpfile("tb_ps2.vcd");
        $dumpvars(0, tb_ps2);
    end

endmodule

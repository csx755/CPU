module Counter_x (
    input  wire         clk,          // ~Clk_CPU, 已不使用（同步简化）
    input  wire         rst,          // 高有效复位
    input  wire         clk0,         // 通道0时钟, ~780kHz
    input  wire         clk1,         // 通道1时钟, ~97kHz
    input  wire         clk2,         // 通道2时钟, ~24kHz
    input  wire         counter_we,   // CPU写使能
    input  wire [31:0]  counter_val,  // 写入初值
    input  wire [1:0]   counter_ch,   // 通道选择
    output reg          counter0_OUT, // 通道0溢出
    output reg          counter1_OUT, // 通道1溢出
    output reg          counter2_OUT, // 通道2溢出
    output wire [31:0]  counter_out   // 当前选中通道计数值
);

    // 三个计数器（各自时钟域）
    reg [31:0] cnt0, cnt1, cnt2;
    reg        loaded0, loaded1, loaded2;  // 已加载初值标志，防止复位后误判溢出

    //------ 通道0 ------
    always @(posedge clk0 or posedge rst) begin
        if (rst) begin
            cnt0    <= 32'd0;
            loaded0 <= 1'b0;
        end else begin
            if (counter_we && (counter_ch == 2'd0)) begin
                cnt0    <= counter_val;
                loaded0 <= 1'b1;
            end else if (cnt0 > 32'd0)
                cnt0 <= cnt0 - 1'd1;
        end
    end
    always @(*) counter0_OUT = loaded0 && (cnt0 == 32'd0);

    //------ 通道1 ------
    always @(posedge clk1 or posedge rst) begin
        if (rst) begin
            cnt1    <= 32'd0;
            loaded1 <= 1'b0;
        end else begin
            if (counter_we && (counter_ch == 2'd1)) begin
                cnt1    <= counter_val;
                loaded1 <= 1'b1;
            end else if (cnt1 > 32'd0)
                cnt1 <= cnt1 - 1'd1;
        end
    end
    always @(*) counter1_OUT = loaded1 && (cnt1 == 32'd0);

    //------ 通道2 ------
    always @(posedge clk2 or posedge rst) begin
        if (rst) begin
            cnt2    <= 32'd0;
            loaded2 <= 1'b0;
        end else begin
            if (counter_we && (counter_ch == 2'd2)) begin
                cnt2    <= counter_val;
                loaded2 <= 1'b1;
            end else if (cnt2 > 32'd0)
                cnt2 <= cnt2 - 1'd1;
        end
    end
    always @(*) counter2_OUT = loaded2 && (cnt2 == 32'd0);

    //------ 当前选中通道值输出（组合逻辑） ------
    assign counter_out = (counter_ch == 2'd0) ? cnt0 :
                         (counter_ch == 2'd1) ? cnt1 : cnt2;

endmodule
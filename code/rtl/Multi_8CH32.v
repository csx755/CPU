// Multi_8CH32 — 8通道32位显示多路选择器 (替代老师 .edf 黑盒)
//   Switch[2:0] 选择通道 → Disp_num, point_out, LE_out
//   point_in[63:0] = 8组×8bit 小数点 (每通道一组)
//   LES[63:0]     = 8组×8bit 位使能   (每通道一组)
module Multi_8CH32(
    input           clk,
    input           rst,
    input           EN,                 // 使能 (接受但不用, 输出始终有效)
    input  [2:0]    Switch,             // 通道选择 (SW[7:5])
    input  [63:0]   point_in,           // 小数点输入 (8ch × 8bit)
    input  [63:0]   LES,                // 位使能输入 (8ch × 8bit)
    input  [31:0]   data0, data1, data2, data3,
    input  [31:0]   data4, data5, data6, data7,
    output [7:0]    point_out,          // 当前通道小数点
    output [7:0]    LE_out,             // 当前通道位使能
    output [31:0]   Disp_num            // 选中通道的数据
);

    reg [31:0] disp_reg;
    reg [7:0]  point_reg, le_reg;

    assign Disp_num   = disp_reg;
    assign point_out  = point_reg;
    assign LE_out     = le_reg;

    // EN 来自 MIO_BUS 的 GPIOe0000000_we (单周期脉冲), 不能门控输出
    // 始终根据 Switch[2:0] 输出选中通道数据 (实时切换)
    always @(*) begin
        case (Switch)
            3'd0: begin
                disp_reg   = data0;
                point_reg  = point_in[7:0];
                le_reg     = LES[7:0];
            end
            3'd1: begin
                disp_reg   = data1;
                point_reg  = point_in[15:8];
                le_reg     = LES[15:8];
            end
            3'd2: begin
                disp_reg   = data2;
                point_reg  = point_in[23:16];
                le_reg     = LES[23:16];
            end
            3'd3: begin
                disp_reg   = data3;
                point_reg  = point_in[31:24];
                le_reg     = LES[31:24];
            end
            3'd4: begin
                disp_reg   = data4;
                point_reg  = point_in[39:32];
                le_reg     = LES[39:32];
            end
            3'd5: begin
                disp_reg   = data5;
                point_reg  = point_in[47:40];
                le_reg     = LES[47:40];
            end
            3'd6: begin
                disp_reg   = data6;
                point_reg  = point_in[55:48];
                le_reg     = LES[55:48];
            end
            3'd7: begin
                disp_reg   = data7;
                point_reg  = point_in[63:56];
                le_reg     = LES[63:56];
            end
            default: begin
                disp_reg   = data0;
                point_reg  = point_in[7:0];
                le_reg     = LES[7:0];
            end
        endcase
    end

endmodule

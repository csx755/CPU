// RAM_B — 数据存储器行为模型 (替代 Vivado Block Memory Generator IP)
// 1024 × 32-bit, 同步写 (带字节使能), 异步读
module RAM_B (
    input           clka,       // 时钟 (soc_top 接 ~clk)
    input  [3:0]    wea,        // 字节写使能
    input  [9:0]    addra,      // 字地址
    input  [31:0]   dina,       // 写数据
    output [31:0]   douta       // 读数据 (异步)
);

    reg [31:0] mem [0:1023];

    // 异步读
    assign douta = mem[addra];

    // 调试: 导出 mem 供 testbench 层次化访问
    // iVerilog 中可通过 U_SOC.U_RAM_B.mem[addr] 读取

    // 同步写 (字节使能)
    integer i;
    always @(posedge clka) begin
        if (wea[0]) mem[addra][7:0]   <= dina[7:0];
        if (wea[1]) mem[addra][15:8]  <= dina[15:8];
        if (wea[2]) mem[addra][23:16] <= dina[23:16];
        if (wea[3]) mem[addra][31:24] <= dina[31:24];
    end

    // 初始化为 0
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            mem[i] = 32'h00000000;
    end

endmodule

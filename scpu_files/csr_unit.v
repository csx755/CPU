`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// CSR 寄存器组模块
// 管理 STATUS, INTMASK, SEPC, SCAUSE 四个控制状态寄存器
//
// CSR 地址映射:
//   0x100 = STATUS   [7:0]  状态寄存器
//   0x101 = INTMASK  [7:0]  中断屏蔽寄存器
//   0x102 = SEPC     [31:0] 保存的异常返回地址
//   0x103 = SCAUSE   [7:0]  异常原因编码
//
// STATUS[7:0] 寄存器位定义:
//   bit0: IE  - 全局中断使能 (1=使能, 0=禁止)
//   bit1: IM[0] - 定时器中断使能 (1=使能, 0=禁止)
//   bit2: IM[1] - 外部中断源0使能
//   bit3: IM[2] - 外部中断源1使能
//   bit4: IM[3] - 外部中断源2使能
//   bit5: IM[4] - 外部中断源3使能
//   bit6: IM[5] - 外部中断源4使能
//   bit7: IM[6] - 外部中断源5使能
//
// INTMASK[7:0] 寄存器位定义:
//   对应位为1则屏蔽该中断源 (1=屏蔽, 0=不屏蔽)
//
// SCAUSE[7:0] 异常原因编码:
//   0: 定时器中断
//   1: 外部中断源0
//   2: 外部中断源1
//   3: 外部中断源2
//   4: 外部中断源3
//   5: 外部中断源4
//   6: 外部中断源5
//   8: ECALL 指令 (Environment call from U-mode)
//
// CSR 指令操作:
//   CSRRW  rd, csr, rs1  →  rd = csr; csr = rs1
//   CSRRS  rd, csr, rs1  →  rd = csr; csr = csr | rs1
//   CSRRC  rd, csr, rs1  →  rd = csr; csr = csr & ~rs1
//   CSRRWI rd, csr, imm  →  rd = csr; csr = imm (零扩展)
//   CSRRSI rd, csr, imm  →  rd = csr; csr = csr | imm
//   CSRRCI rd, csr, imm  →  rd = csr; csr = csr & ~imm
//////////////////////////////////////////////////////////////////////////////////

module csr_unit(
    input         clk,
    input         rst,
    // CSR 指令读写端口
    input         csr_we,        // CSR 写使能
    input  [1:0]  csr_op,        // 00=none, 01=CSRRW, 10=CSRRS, 11=CSRRC
    input  [11:0] csr_addr,      // CSR 地址
    input  [31:0] csr_wdata,     // 写入数据 (来自 rs1 或 zero-extended imm)
    output reg [31:0] csr_rdata, // 读出数据 (写入 rd)
    // 中断处理端口
    input         exl_set,       // 中断响应：保存 PC、设置 SCAUSE
    input  [31:0] ret_addr,      // 要保存的返回地址 (当前 PC)
    input  [7:0]  scause_in,     // 异常原因编码输入
    input         eret,          // ERET 指令：清除 EXL
    input         ecall,         // ECALL 指令：触发异常，SCAUSE=8
    // 输出给 exception_ctrl
    output [7:0]  STATUS,
    output [7:0]  INTMASK,
    output [31:0] SEPC,
    output        EXL            // 当前是否在异常处理中
);

    // ========== CSR 寄存器 ==========
    reg [7:0]  status_reg;   // STATUS
    reg [7:0]  intmask_reg;  // INTMASK
    reg [31:0] sepc_reg;     // SEPC
    reg [7:0]  scause_reg;   // SCAUSE
    reg        exl_reg;      // EXL (异常级别位，内嵌在STATUS中或单独)

    // 输出赋值
    assign STATUS  = status_reg;
    assign INTMASK = intmask_reg;
    assign SEPC    = sepc_reg;
    assign EXL     = exl_reg;

    // ========== CSR 读逻辑 ==========
    always @(*) begin
        case (csr_addr)
            12'h100: csr_rdata = {24'b0, status_reg};
            12'h101: csr_rdata = {24'b0, intmask_reg};
            12'h102: csr_rdata = sepc_reg;
            12'h103: csr_rdata = {24'b0, scause_reg};
            default: csr_rdata = 32'b0;
        endcase
    end

    // ========== CSR 写逻辑 + 中断处理 ==========
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            status_reg  <= 8'h01;  // 默认 IE=1（全局中断使能），其余为0
            intmask_reg <= 8'hFF;  // 默认全部屏蔽
            sepc_reg    <= 32'b0;
            scause_reg  <= 8'b0;
            exl_reg     <= 1'b0;
        end
        else begin
            // 优先级1: 中断响应 —— 保存现场
            if (exl_set) begin
                // 对于ECALL指令，返回地址应该是ECALL指令的下一条指令的地址
                // 对于中断，返回地址应该是中断发生时正在执行的指令的PC
                sepc_reg   <= ecall ? (ret_addr + 32'd4) : ret_addr;
                scause_reg <= ecall ? 8'd8 : scause_in;
                exl_reg    <= 1'b1;
            end
            // 优先级2: ERET —— 返回原程序
            else if (eret) begin
                exl_reg    <= 1'b0;        // 退出异常处理模式
            end
            // 优先级3: CSR 指令写入
            else if (csr_we) begin
                case (csr_addr)
                    12'h100: begin
                        case (csr_op)
                            2'b01: status_reg  <= csr_wdata[7:0];           // CSRRW
                            2'b10: status_reg  <= status_reg | csr_wdata[7:0];  // CSRRS
                            2'b11: status_reg  <= status_reg & ~csr_wdata[7:0]; // CSRRC
                            default: status_reg <= status_reg;
                        endcase
                    end
                    12'h101: begin
                        case (csr_op)
                            2'b01: intmask_reg <= csr_wdata[7:0];
                            2'b10: intmask_reg <= intmask_reg | csr_wdata[7:0];
                            2'b11: intmask_reg <= intmask_reg & ~csr_wdata[7:0];
                            default: intmask_reg <= intmask_reg;
                        endcase
                    end
                    12'h102: begin
                        case (csr_op)
                            2'b01: sepc_reg <= csr_wdata;
                            2'b10: sepc_reg <= sepc_reg | csr_wdata;
                            2'b11: sepc_reg <= sepc_reg & ~csr_wdata;
                            default: sepc_reg <= sepc_reg;
                        endcase
                    end
                    12'h103: begin
                        case (csr_op)
                            2'b01: scause_reg <= csr_wdata[7:0];
                            2'b10: scause_reg <= scause_reg | csr_wdata[7:0];
                            2'b11: scause_reg <= scause_reg & ~csr_wdata[7:0];
                            default: scause_reg <= scause_reg;
                        endcase
                    end
                    default: ;
                endcase
            end
        end
    end

endmodule
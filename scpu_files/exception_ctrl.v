`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 中断控制模块 (Exception Control Unit)
// 功能：检测中断源、判断优先级、生成中断响应信号
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
// EXL: 当前是否在中断处理中（1=是，禁止嵌套）
//
// 中断优先级（编号越小优先级越高）:
//   [0] = timer (最高优先级)
//   [1] = external source 0
//   [2] = external source 1
//   ...
//   [6] = external source 5 (最低优先级)
//
// 输出:
//   EXL_Set:    中断响应信号（刷新流水线、保存PC）
//   INT_PEND:   当前响应的中断编号（0-6）
//   INT_Signal: 全局中断请求（给外部使用）
//   EXC_Vector: 中断向量地址（根据中断源计算）
//////////////////////////////////////////////////////////////////////////////////

module exception_ctrl(
    input  [7:0]  STATUS,
    input  [7:0]  INTMASK,
    input         EXL,
    input  [6:0]  int_sources,
    input         ECALL,
    output        EXL_Set,
    output [2:0]  INT_PEND,
    output        INT_Signal,
    output [31:0] EXC_Vector
);

    // 中断使能判断：全局IE=1 且 对应中断使能位=1 且 未被屏蔽 且 不在异常处理中
    wire [6:0] int_enabled;
    
    // 定时器中断 (最高优先级)
    assign int_enabled[0] = int_sources[0] & STATUS[0] & STATUS[1] & ~INTMASK[0] & ~EXL;
    
    // 外部中断源0-5
    assign int_enabled[1] = int_sources[1] & STATUS[0] & STATUS[2] & ~INTMASK[1] & ~EXL;
    assign int_enabled[2] = int_sources[2] & STATUS[0] & STATUS[3] & ~INTMASK[2] & ~EXL;
    assign int_enabled[3] = int_sources[3] & STATUS[0] & STATUS[4] & ~INTMASK[3] & ~EXL;
    assign int_enabled[4] = int_sources[4] & STATUS[0] & STATUS[5] & ~INTMASK[4] & ~EXL;
    assign int_enabled[5] = int_sources[5] & STATUS[0] & STATUS[6] & ~INTMASK[5] & ~EXL;
    assign int_enabled[6] = int_sources[6] & STATUS[0] & STATUS[7] & ~INTMASK[6] & ~EXL;

    // 全局中断请求
    assign INT_Signal = |int_enabled;

    // 中断响应：有待处理中断或 ECALL 指令时响应
    assign EXL_Set = INT_Signal | ECALL;

    // 中断编号（优先级编码）
    assign INT_PEND = int_enabled[0] ? 3'd0 :
                      int_enabled[1] ? 3'd1 :
                      int_enabled[2] ? 3'd2 :
                      int_enabled[3] ? 3'd3 :
                      int_enabled[4] ? 3'd4 :
                      int_enabled[5] ? 3'd5 :
                      int_enabled[6] ? 3'd6 : 3'd7;

    // 中断向量地址计算
    // 根据中断编号计算向量地址，每个中断源占4字节
    // 基地址 0x100，偏移 = 中断编号 * 4
    assign EXC_Vector = 32'h00000100 + {29'b0, INT_PEND, 2'b00};

endmodule
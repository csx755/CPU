`timescale 1ns / 1ps

// 最简中断控制：INT 有效 且 MIE=1 才触发
module exception_ctrl(
    input  INT,        // 外部中断线
    input  MIE,        // 全局中断使能（1bit）
    output INT_Signal  // 中断响应
);
    assign INT_Signal = INT & MIE;
endmodule

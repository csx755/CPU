// Hazard_Unit — 流水线冒险检测
// 检测 Load-Use 冒险 (需阻塞) + 控制冒险 (需冲刷)
module Hazard_Unit (
    input        ID_EX_MemRead,       // ID/EX 级指令是否 Load
    input [4:0]  ID_EX_rd,            // ID/EX 级目的寄存器
    input [4:0]  ID_rs1,              // ID 级源寄存器 1
    input [4:0]  ID_rs2,              // ID 级源寄存器 2
    input        ID_is_JAL,           // ID 级是 JAL 指令
    input        EX_taken,            // EX 级分支/跳转成立
    output       load_use_hazard,     // Load-Use 冒险标志
    output       IF_ID_flush,         // 冲刷 IF/ID
    output       ID_EX_flush,         // 冲刷 ID/EX (插入气泡)
    output       IF_ID_write          // IF/ID 写使能 (0=冻结)
);
    // Load-Use 冒险: ID/EX 是 Load, 且 rd 与 ID 级的 rs1 或 rs2 相同
    assign load_use_hazard = ID_EX_MemRead &&
                             ((ID_EX_rd == ID_rs1 && ID_rs1 != 5'd0) ||
                              (ID_EX_rd == ID_rs2 && ID_rs2 != 5'd0));

    // 冲刷信号: JAL (ID 级) 或分支成立 (EX 级)
    assign IF_ID_flush = ID_is_JAL | EX_taken;

    // ID/EX 冲刷: Load-Use (插入气泡) 或分支成立
    assign ID_EX_flush = load_use_hazard | EX_taken;

    // IF/ID 冻结: Load-Use 时保持, 让 dependent 指令等一周期
    assign IF_ID_write = ~load_use_hazard;
endmodule

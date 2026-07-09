// Hazard_Unit — 流水线冒险检测 (统一 Kill + Stall)
// 对照 doc/15_中断扩展设计.md §9.2 / §11 / Kill Matrix
module Hazard_Unit (
    // 数据冒险检测
    input        ID_EX_MemRead,       // ID/EX 级指令是否 Load
    input [4:0]  ID_EX_rd,            // ID/EX 级目的寄存器
    input [4:0]  ID_rs1,              // ID 级源寄存器 1
    input [4:0]  ID_rs2,              // ID 级源寄存器 2
    // 控制冒险
    input        EX_taken,            // EX 级分支/跳转成立
    input        ID_is_JAL,           // ID 级是 JAL 指令
    // 中断 / MRET / ECALL
    input        interrupt_accept,    // 当前周期接受中断
    input        ID_is_MRET,          // ID 级是 MRET 指令
    input        ID_is_ECALL,         // ID 级是 ECALL 指令 (特权异常)
    // CSR RAW hazard
    input        csr_raw_hazard,      // 连续 CSR 指令 RAW 检测
    // 输出
    output       pipeline_stall,      // 流水线阻塞标志
    output       kill_IF,             // Kill IF 级 (→ IF_ID_flush)
    output       kill_ID,             // Kill ID 级 (→ ID_EX_flush)
    output       IF_ID_freeze         // 冻结 IF/ID (→ ~IF_ID_write)
);

    // ---- Load-Use 冒险 ----
    wire load_use = ID_EX_MemRead &&
                    ((ID_EX_rd == ID_rs1 && ID_rs1 != 5'd0) ||
                     (ID_EX_rd == ID_rs2 && ID_rs2 != 5'd0));

    // ---- 统一 Pipeline Stall ----
    // 当前: Load-Use + CSR RAW; 未来可扩展 cache miss / 乘法器 busy 等
    assign pipeline_stall = load_use | csr_raw_hazard;

    // ---- 统一 Kill 信号 (分层写法, 对照 Kill Matrix) ----
    // 所有 Redirect (JAL/Branch/JALR/Interrupt/MRET) 不 Kill IF——
    //   PC 跳转后 IF 自然取目标指令, Kill IF 会冲掉刚取到的第一条目标指令
    // Kill IF only:  无 (negedge 流水线中, JAL 的 redirect 先于下一 fetch, 无需 Kill IF)
    // Kill IF + ID:  无
    // Kill ID only:  EX_taken (Branch/JALR) / Interrupt / MRET
    //   JAL 不 Kill ID —— 必须完整通过流水线到 WB 才能写 PC+4 到 rd
    // Pipeline Stall: Kill ID (插入气泡)
    wire kill_ID_only = EX_taken | interrupt_accept | ID_is_MRET | ID_is_ECALL;

    assign kill_IF = 1'b0;                    // 永远不 Kill IF
    assign kill_ID = pipeline_stall | kill_ID_only;
    assign IF_ID_freeze = pipeline_stall;

    // ---- IF/ID 冻结 ----
    assign IF_ID_freeze = pipeline_stall;

endmodule

// Forwarding_Unit — 数据前递单元
// 检测 RAW 冒险并产生 ForwardA/ForwardB 选择信号
module Forwarding_Unit (
    input [4:0]  ID_EX_rs1,           // EX 级源寄存器 1 地址
    input [4:0]  ID_EX_rs2,           // EX 级源寄存器 2 地址
    input        EX_MEM_RegWrite,     // EX/MEM 级是否写寄存器
    input [4:0]  EX_MEM_rd,           // EX/MEM 级目的寄存器
    input [31:0] EX_MEM_ALU_result,   // EX/MEM 级 ALU 结果 (未使用, 仅接口)
    input        MEM_WB_RegWrite,     // MEM/WB 级是否写寄存器
    input [4:0]  MEM_WB_rd,           // MEM/WB 级目的寄存器
    input [31:0] WB_WD,               // MEM/WB 级最终写回数据
    output [1:0] ForwardA,            // ALU A 输入选择: 00=ID_EX.RD1, 01=EX_MEM, 10=MEM_WB
    output [1:0] ForwardB             // ALU B 输入选择: 00=ID_EX.RD2, 01=EX_MEM, 10=MEM_WB
);
    // ForwardA: rs1 的前递检测
    // 优先级: EX/MEM > MEM/WB (最新结果优先)
    wire ex_hazard_rs1  = EX_MEM_RegWrite && (EX_MEM_rd != 5'd0)
                          && (EX_MEM_rd == ID_EX_rs1);
    wire mem_hazard_rs1 = MEM_WB_RegWrite && (MEM_WB_rd != 5'd0)
                          && (MEM_WB_rd == ID_EX_rs1)
                          && ~ex_hazard_rs1;   // EX/MEM 优先级更高
    assign ForwardA = ex_hazard_rs1  ? 2'b01 :   // 转发 EX/MEM.ALU_result
                      mem_hazard_rs1 ? 2'b10 :   // 转发 WB_WD
                                       2'b00;    // 不转发 (用 ID_EX.RD1)

    // ForwardB: rs2 的前递检测
    wire ex_hazard_rs2  = EX_MEM_RegWrite && (EX_MEM_rd != 5'd0)
                          && (EX_MEM_rd == ID_EX_rs2);
    wire mem_hazard_rs2 = MEM_WB_RegWrite && (MEM_WB_rd != 5'd0)
                          && (MEM_WB_rd == ID_EX_rs2)
                          && ~ex_hazard_rs2;   // EX/MEM 优先级更高
    assign ForwardB = ex_hazard_rs2  ? 2'b01 :   // 转发 EX_MEM.ALU_result
                      mem_hazard_rs2 ? 2'b10 :   // 转发 WB_WD
                                       2'b00;    // 不转发 (用 ID_EX.RD2)
endmodule

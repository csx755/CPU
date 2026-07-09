`include "ctrl_encode_def.v"

module NPC(PC, NPCOp, IMM, NPC, aluout, PCWrite, PC_GRE,
           // 新增：中断/ERET 支持
           SEPC, ERET, ERETN, EXL_Set, EXC_Vector);

    input  [31:0] PC;
    input  [2:0]  NPCOp;
    input  [31:0] IMM;
    input  [31:0] aluout;
    input         PCWrite;
    input  [31:0] PC_GRE;
    // 新增输入
    input  [31:0] SEPC;        // 保存的异常返回地址
    input         ERET;        // ERET 指令（返回到 SEPC）
    input         ERETN;       // ERETN 指令（返回到 SEPC+4）
    input         EXL_Set;     // 中断响应信号
    input  [31:0] EXC_Vector;  // 中断向量地址（由exception_ctrl计算）
    output reg [31:0] NPC;

    wire [31:0] PCPLUS4;

    assign PCPLUS4 = PC + 4;

    always @(*) begin
        // 最高优先级：中断响应 → 跳转到中断向量
        if (EXL_Set) begin
            NPC = EXC_Vector;
        end
        // 次高优先级：ERET → 返回到 SEPC（异常返回）
        else if (ERET) begin
            NPC = SEPC;
        end
        // 次高优先级：ERETN → 返回到 SEPC+4（异常返回并跳过下一条指令）
        else if (ERETN) begin
            NPC = SEPC + 4;
        end
        // 正常流水线控制
        else if (PCWrite) begin
            case (NPCOp)
                `NPC_PLUS4:  NPC = PCPLUS4;
                `NPC_BRANCH: NPC = PC_GRE + IMM;
                `NPC_JUMP:   NPC = PC_GRE + IMM;
                `NPC_JALR:   NPC = aluout;
                default:     NPC = PCPLUS4;
            endcase
        end
        else begin
            NPC = PC;
        end
    end

endmodule
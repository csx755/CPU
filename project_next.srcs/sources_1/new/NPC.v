`include "ctrl_encode_def.v"

module NPC(PC, NPCOp, IMM, NPC, aluout,PCWrite, PC_GRE,
           int_signal, mtvec, ecall, mret, mepc);

    input  [31:0] PC;
    input  [2:0]  NPCOp;
    input  [31:0] IMM;
    input  [31:0] aluout;
    input PCWrite;
    input  [31:0] PC_GRE;
    input  int_signal;
    input  [31:0] mtvec;
    input  ecall;
    input  mret;
    input  [31:0] mepc;
    output reg [31:0] NPC;

    wire [31:0] PCPLUS4;

    assign PCPLUS4 = PC + 4;

    always @(*) begin
        if(int_signal) begin
            // 中断响应，跳转到中断入口
            NPC = mtvec;
        end else if(ecall) begin
            // ecall 异常，跳转到中断入口
            NPC = mtvec;
        end else if(mret) begin
            // mret 返回，跳转到 mepc
            NPC = mepc;
        end else if(PCWrite)begin
            case (NPCOp)
                `NPC_PLUS4:  NPC = PCPLUS4;
                `NPC_BRANCH: NPC = PC_GRE + IMM;
                `NPC_JUMP:   NPC = PC_GRE + IMM;
                `NPC_JALR:   NPC = aluout;
                default:     NPC = PCPLUS4;
            endcase
        end
        else begin
            NPC=PC;
        end
    end

endmodule

# NPC — 下一条指令地址计算

## 功能描述

NPC（Next PC）根据当前 PC、控制信号 NPCOp、立即数和 ALU 输出，计算下一条要执行的指令地址。支持四种跳转模式。

## 接口信号

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| `PC` | input | 32 | 当前指令地址 |
| `NPCOp` | input | 3 | NPC 操作码，决定跳转类型 |
| `IMM` | input | 32 | 扩展后的立即数（来自 EXT 模块） |
| `aluout` | input | 32 | ALU 计算结果（用于 JALR） |
| `NPC` | output | 32 | 计算得到的下一条指令地址 |

## 内部数据结构

| 名称 | 类型 | 位宽 | 描述 |
|------|------|------|------|
| `PCPLUS4` | wire | 32 | PC + 4，顺序执行时的默认下一地址 |
| `NPC` | reg | 32 | 组合逻辑输出，根据 NPCOp 选择 |

## NPCOp 编码（来自 `ctrl_encode_def.v`）

| NPCOp 值 | 宏定义 | 含义 | NPC = ? |
|--------|--------|------|--------|
| `3'b000` | `NPC_PLUS4` | 顺序执行 | PC + 4 |
| `3'b001` | `NPC_BRANCH` | 条件分支 | PC + IMM（BEQ 跳转） |
| `3'b010` | `NPC_JUMP` | 无条件跳转 | PC + IMM（JAL） |
| `3'b100` | `NPC_JALR` | 间接跳转 | aluout（JALR，RS1+IMM） |

## 工作逻辑

```
PCPLUS4 = PC + 4

case (NPCOp):
    NPC_PLUS4:  NPC = PCPLUS4     // 默认：顺序执行下一条
    NPC_BRANCH: NPC = PC + IMM     // BEQ 条件分支
    NPC_JUMP:   NPC = PC + IMM     // JAL 跳转
    NPC_JALR:   NPC = aluout       // JALR 跳转到寄存器地址
    default:    NPC = PCPLUS4
```

## 连接关系

- **输入来源**：PC → PC、ctrl → NPCOp、EXT → IMM、ALU → aluout
- **输出去向**：PC 模块（下一周期锁存）

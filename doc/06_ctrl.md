# ctrl — 控制单元

## 功能描述

ctrl（Control Unit）是指令译码和控制信号生成的核心模块。根据输入的 32-bit 指令的操作码（Op）、Funct3 和 Funct7 字段，以及 ALU 的 Zero 标志，生成所有数据通路控制信号。

## 接口信号

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| `Op` | input | 7 | 指令操作码 `instr[6:0]` |
| `Funct7` | input | 7 | Funct7 字段 `instr[31:25]` |
| `Funct3` | input | 3 | Funct3 字段 `instr[14:12]` |
| `Zero` | input | 1 | ALU 零标志，用于 BEQ 分支判断 |
| `RegWrite` | output | 1 | 寄存器写使能，1=写 RF |
| `MemWrite` | output | 1 | 数据存储器写使能，1=写 DM |
| `EXTOp` | output | 6 | 立即数扩展操作码（独热码），指示立即数格式 |
| `ALUOp` | output | 5 | ALU 操作码，决定 ALU 做何种运算 |
| `NPCOp` | output | 3 | NPC 操作码，决定下一 PC 计算方式 |
| `ALUSrc` | output | 1 | ALU B 输入来源，0=RD2 (寄存器)，1=立即数 |
| `GPRSel` | output | 2 | 通用寄存器选择（当前未用） |
| `WDSel` | output | 2 | 寄存器写数据来源选择 |
| `DMType` | output | 3 | 数据存储器访问类型（当前未用） |

## 内部数据结构

### 指令类型译码（wire 信号）

| 信号 | 条件 | 匹配指令 |
|------|------|----------|
| `rtype` | Op == 011_0011 | ADD, SUB, OR, AND |
| `itype_l` | Op == 000_0011 | LW |
| `itype_r` | Op == 001_0011 | ADDI, ORI |
| `stype` | Op == 010_0011 | SW |
| `sbtype` | Op == 110_0011 | BEQ |
| `i_jalr` | Op == 110_0111 | JALR |
| `i_jal` | Op == 110_1111 | JAL |

### 具体指令译码

| 信号 | 类型 | Funct7 | Funct3 | 指令 |
|------|------|--------|--------|------|
| `i_add` | rtype | 000_0000 | 000 | ADD |
| `i_sub` | rtype | 010_0000 | 000 | SUB |
| `i_or` | rtype | 000_0000 | 110 | OR |
| `i_and` | rtype | 000_0000 | 111 | AND |
| `i_addi` | itype_r | — | 000 | ADDI |
| `i_ori` | itype_r | — | 110 | ORI |
| `i_sw` | stype | — | 010 | SW |
| `i_beq` | sbtype | — | 000 | BEQ |

## 控制信号生成规则

| 控制信号 | 生成逻辑 | 说明 |
|----------|----------|------|
| `RegWrite` | rtype \| itype_r \| i_jalr \| i_jal | ⚠️ 当前缺少 `itype_l`，LW 无法写寄存器 |
| `MemWrite` | stype | 仅 SW 写内存 |
| `ALUSrc` | itype_r \| stype \| i_jal \| i_jalr | 立即数类指令 ALU B 选立即数 |
| `ALUOp[0]` | itype_l \| stype \| i_addi \| i_ori \| i_add \| i_or | |
| `ALUOp[1]` | i_jalr \| itype_l \| stype \| i_addi \| i_add \| i_and | |
| `ALUOp[2]` | i_and \| i_ori \| i_or \| i_beq \| i_sub | |
| `ALUOp[3]` | i_and \| i_ori \| i_or | |
| `ALUOp[4]` | 0 | 保留 |
| `EXTOp[4]` | i_ori | I-type 立即数 |
| `EXTOp[3]` | stype | S-type 立即数 |
| `EXTOp[2]` | sbtype | B-type 立即数 |
| `EXTOp[0]` | i_jal | J-type 立即数 |
| `WDSel[0]` | itype_l | LW 写回来自 MEM |
| `WDSel[1]` | i_jal \| i_jalr | JAL/JALR 写回 PC+4 |
| `NPCOp[0]` | sbtype & Zero | BEQ 且相等时分支 |
| `NPCOp[1]` | i_jal | JAL 无条件跳转 |
| `NPCOp[2]` | i_jalr | JALR 间接跳转 |

## 已知问题

1. **RegWrite 缺少 `itype_l`**：`assign RegWrite = rtype | itype_r | i_jalr | i_jal;` 没有包含 `itype_l`，导致 `lw` 指令无法写入目的寄存器。应改为：
   ```verilog
   assign RegWrite = rtype | itype_r | i_jalr | i_jal | itype_l;
   ```

2. **GPRSel 和 DMType 已定义端口但未使用**：这些信号是为后续扩展预留的

## WDSel 编码

| 值 | 宏定义 | 写回数据来源 |
|----|--------|-------------|
| `2'b00` | `WDSel_FromALU` | ALU 输出（ALU 类指令） |
| `2'b01` | `WDSel_FromMEM` | 数据存储器输出（LW） |
| `2'b10` | `WDSel_FromPC` | PC+4（JAL/JALR 返回地址） |

## 连接关系

- **输入来源**：inst（IM → SCPU）→ Op, Funct7, Funct3、ALU → Zero
- **输出去向**：
  - RF → RegWrite, WDSel（WD mux 选择）
  - ALU → ALUOp, ALUSrc（B 选择）
  - EXT → EXTOp
  - NPC → NPCOp
  - DM → MemWrite

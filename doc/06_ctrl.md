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
| `DMType` | output | 3 | 数据存储器访问类型（Wave 3 启用） |

## 内部数据结构

### 指令类型译码（wire 信号）

| 信号 | Opcode | 匹配指令 |
|------|--------|----------|
| `rtype` | 011_0011 | ADD, SUB, OR, AND, XOR, SLL, SRL, SRA, SLT, SLTU |
| `itype_l` | 000_0011 | LW, LB, LH, LBU, LHU |
| `itype_r` | 001_0011 | ADDI, ORI, XORI, ANDI, SLLI, SRLI, SRAI, SLTI, SLTIU |
| `stype` | 010_0011 | SW, SB, SH |
| `sbtype` | 110_0011 | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| `utype_lui` | 011_0111 | LUI |
| `utype_auipc` | 001_0111 | AUIPC |
| `i_jalr` | 110_0111 | JALR |
| `i_jal` | 110_1111 | JAL |

### Phase 1 已实现指令译码

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

### Wave 1 新增指令译码

| 信号 | 类型 | Funct7 | Funct3 | 指令 |
|------|------|--------|--------|------|
| `i_xori` | itype_r | — | 100 | XORI |
| `i_andi` | itype_r | — | 111 | ANDI |
| `i_slli` | itype_r | 000_0000 | 001 | SLLI |
| `i_srli` | itype_r | 000_0000 | 101 | SRLI |
| `i_srai` | itype_r | 010_0000 | 101 | SRAI |
| `i_slti` | itype_r | — | 010 | SLTI |
| `i_sltiu` | itype_r | — | 011 | SLTIU |

### Wave 2 新增指令译码（待实现）

| 信号 | 类型 | Funct7 | Funct3 | 指令 |
|------|------|--------|--------|------|
| `i_sll` | rtype | 000_0000 | 001 | SLL |
| `i_srl` | rtype | 000_0000 | 101 | SRL |
| `i_sra` | rtype | 010_0000 | 101 | SRA |
| `i_xor` | rtype | 000_0000 | 100 | XOR |
| `i_bne` | sbtype | — | 001 | BNE |
| `i_blt` | sbtype | — | 100 | BLT |
| `i_bge` | sbtype | — | 101 | BGE |
| `i_bltu` | sbtype | — | 110 | BLTU |
| `i_bgeu` | sbtype | — | 111 | BGEU |

### Wave 3 新增指令译码（待实现）

| 信号 | 类型 | Funct7 | Funct3 | 指令 |
|------|------|--------|--------|------|
| `i_slt` | rtype | 000_0000 | 010 | SLT |
| `i_sltu` | rtype | 000_0000 | 011 | SLTU |
| `i_lb` | itype_l | — | 000 | LB |
| `i_lh` | itype_l | — | 001 | LH |
| `i_lbu` | itype_l | — | 100 | LBU |
| `i_lhu` | itype_l | — | 101 | LHU |
| `i_sb` | stype | — | 000 | SB |
| `i_sh` | stype | — | 001 | SH |

## 控制信号生成规则（Phase 2 Wave 1 最新状态）

| 控制信号 | 生成逻辑 | 说明 |
|----------|----------|------|
| `RegWrite` | rtype \| itype_r \| itype_l \| utype_lui \| utype_auipc \| i_jalr \| i_jal | 所有写寄存器指令 |
| `MemWrite` | stype | SW/SB/SH 写内存 |
| `ALUSrc` | itype_r \| itype_l \| stype \| utype_lui \| utype_auipc \| i_jal \| i_jalr | 立即数类指令 |
| `ALUOp[0]` | i_jalr \| itype_l \| stype \| i_addi \| i_ori \| i_add \| i_or | ADD/OR 类 |
| `ALUOp[1]` | i_jalr \| itype_l \| stype \| i_addi \| i_add \| i_and \| i_andi | ADD/AND 类 |
| `ALUOp[2]` | i_and \| i_andi \| i_ori \| i_or \| i_beq \| i_sub \| i_slli \| i_srli \| i_srai \| i_xor \| i_xori | 移位/异或/比较 |
| `ALUOp[3]` | i_and \| i_andi \| i_ori \| i_or \| i_slli \| i_srli \| i_srai \| i_slti \| i_sltiu | I-type ALU 高位 |
| `ALUOp[4]` | i_srai \| i_srli \| i_srl \| i_sra | 右移指令（区分逻辑/算术） |
| `EXTOp[5]` | i_slli \| i_srli \| i_srai | I-type 移位量（5-bit 零扩展） |
| `EXTOp[4]` | itype_r \| itype_l \| i_jalr | I-type 12-bit 符号扩展 |
| `EXTOp[3]` | stype | S-type 立即数 |
| `EXTOp[2]` | sbtype | B-type 立即数（所有分支） |
| `EXTOp[1]` | utype_lui \| utype_auipc | U-type 立即数 |
| `EXTOp[0]` | i_jal | J-type 立即数 |
| `WDSel[0]` | itype_l | LW/LB/LH 等写回来自 MEM |
| `WDSel[1]` | i_jal \| i_jalr | JAL/JALR 写回 PC+4 |
| `NPCOp[0]` | sbtype & branch_cond | 分支条件满足时跳转 |
| `NPCOp[1]` | i_jal | JAL 无条件跳转 |
| `NPCOp[2]` | i_jalr | JALR 间接跳转 |

## ALUOp 完整映射表

| ALUOp 值 | 宏定义 | 操作 | 使用指令 |
|----------|--------|------|----------|
| `5'b00000` | `ALUOp_nop` | C = A | — |
| `5'b00001` | `ALUOp_lui` | C = B | LUI |
| `5'b00010` | `ALUOp_auipc` | C = PC+B | AUIPC |
| `5'b00011` | `ALUOp_add` | C = A+B | ADD, ADDI, LW, SW, JALR |
| `5'b00100` | `ALUOp_sub` | C = A-B | SUB, BEQ |
| `5'b00101` | `ALUOp_bne` | C = (A==B) | BNE |
| `5'b00110` | `ALUOp_blt` | C = (A>=B) | BLT |
| `5'b00111` | `ALUOp_bge` | C = (A<B) | BGE |
| `5'b01000` | `ALUOp_bltu` | C = ($u(A)>=$u(B)) | BLTU |
| `5'b01001` | `ALUOp_bgeu` | C = ($u(A)<$u(B)) | BGEU |
| `5'b01010` | `ALUOp_slt` | C = (A<B) | SLT, SLTI |
| `5'b01011` | `ALUOp_sltu` | C = ($u(A)<$u(B)) | SLTU, SLTIU |
| `5'b01100` | `ALUOp_xor` | C = A^B | XOR, XORI |
| `5'b01101` | `ALUOp_or` | C = A\|B | OR, ORI |
| `5'b01110` | `ALUOp_and` | C = A&B | AND, ANDI |
| `5'b01111` | `ALUOp_sll` | C = A<<B | SLL, SLLI |
| `5'b10000` | `ALUOp_srl` | C = A>>B | SRL, SRLI |
| `5'b10001` | `ALUOp_sra` | C = A>>>B | SRA, SRAI |

## WDSel 编码

| 值 | 宏定义 | 写回数据来源 |
|----|--------|-------------|
| `2'b00` | `WDSel_FromALU` | ALU 输出（ALU 类指令） |
| `2'b01` | `WDSel_FromMEM` | 数据存储器输出（LW） |
| `2'b10` | `WDSel_FromPC` | PC+4（JAL/JALR 返回地址） |

## DMType 编码（Wave 3 启用）

| 值 | 宏定义 | 含义 |
|----|--------|------|
| `3'b000` | `dm_word` | 32-bit 字访问 |
| `3'b001` | `dm_halfword` | 16-bit 半字（有符号） |
| `3'b010` | `dm_halfword_unsigned` | 16-bit 半字（无符号） |
| `3'b011` | `dm_byte` | 8-bit 字节（有符号） |
| `3'b100` | `dm_byte_unsigned` | 8-bit 字节（无符号） |

## 连接关系

- **输入来源**：inst（IM → SCPU）→ Op, Funct7, Funct3、ALU → Zero
- **输出去向**：
  - RF → RegWrite, WDSel（WD mux 选择）
  - ALU → ALUOp, ALUSrc（B 选择）
  - EXT → EXTOp
  - NPC → NPCOp
  - DM → MemWrite, DMType

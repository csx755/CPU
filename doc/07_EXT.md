# EXT — 立即数扩展

## 功能描述

EXT（Immediate Extension）将指令中不同格式的立即数字段（I/S/B/U/J 型），按 RISC-V 规范进行符号/零扩展为 32-bit 的立即数。6-bit 独热码 EXTOp 选择扩展方式。

## 接口信号

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| `iimm_shamt` | input | 5 | I-type 移位立即数 `instr[24:20]` |
| `iimm` | input | 12 | I-type 立即数 `instr[31:20]` |
| `simm` | input | 12 | S-type 立即数 `{instr[31:25], instr[11:7]}` |
| `bimm` | input | 12 | B-type 立即数 `{instr[31], instr[7], instr[30:25], instr[11:8]}` |
| `uimm` | input | 20 | U-type 立即数 `instr[31:12]` |
| `jimm` | input | 20 | J-type 立即数 `{instr[31], instr[19:12], instr[20], instr[30:21]}` |
| `EXTOp` | input | 6 | 扩展操作码（独热码），选择立即数格式 |
| `immout` | output | 32 | 扩展后的 32-bit 立即数 |

## 内部数据结构

| 名称 | 类型 | 位宽 | 描述 |
|------|------|------|------|
| `immout` | reg | 32 | 组合逻辑输出，根据 EXTOp 拼接 |

## EXTOp 编码（来自 ctrl_encode_def.v，独热码）

| EXTOp 值 | 宏定义 | 立即数格式 | 扩展方式 | 对应指令 |
|----------|--------|-----------|----------|----------|
| `6'b100000` | `EXT_CTRL_ITYPE_SHAMT` | I-type 移位 | 零扩展（27'b0 + shamt） | SLLI, SRLI… |
| `6'b010000` | `EXT_CTRL_ITYPE` | I-type | 符号扩展 | ORI, ADDI, LW, JALR |
| `6'b001000` | `EXT_CTRL_STYPE` | S-type | 符号扩展 | SW |
| `6'b000100` | `EXT_CTRL_BTYPE` | B-type | 符号扩展 + 低位补0 | BEQ |
| `6'b000010` | `EXT_CTRL_UTYPE` | U-type | 左移 12 位 | LUI, AUIPC |
| `6'b000001` | `EXT_CTRL_JTYPE` | J-type | 符号扩展 + 低位补0 | JAL |

## 工作逻辑

```
case (EXTOp):
    EXT_CTRL_ITYPE_SHAMT: immout = {27'b0, iimm_shamt}                     // 零扩展 5→32
    EXT_CTRL_ITYPE:       immout = {{20{iimm[11]}}, iimm}                   // 符号扩展 12→32
    EXT_CTRL_STYPE:       immout = {{20{simm[11]}}, simm}                   // 符号扩展 12→32
    EXT_CTRL_BTYPE:       immout = {{19{bimm[11]}}, bimm, 1'b0}             // 符号扩展 13→32
    EXT_CTRL_UTYPE:       immout = {uimm, 12'b0}                            // 高位加载，低位补0
    EXT_CTRL_JTYPE:       immout = {{11{jimm[19]}}, jimm, 1'b0}             // 符号扩展 21→32
    default:              immout = 32'b0
```

## RISC-V 立即数格式（各指令字段位置）

```
instr[31:0]:
    31     25 24  20 19  15 14  12 11    7 6      0
    funct7    rs2    rs1    funct3 rd      opcode

I-type (ADDI, ORI, LW, JALR):
    imm[11:0]                 rs1    funct3 rd      opcode
    31     20 19           15 14  12 11    7 6      0

S-type (SW):
    imm[11:5]     rs2         rs1    funct3 imm[4:0] opcode
    31     25 24  20 19     15 14  12 11    7 6      0

B-type (BEQ):
    imm[12|10:5]  rs2         rs1    funct3 imm[4:1|11] opcode
    31         25 24  20 19  15 14  12 11         7 6    0

U-type (LUI, AUIPC):
    imm[31:12]                              rd       opcode
    31                          12 11     7 6        0

J-type (JAL):
    imm[20|10:1|11|19:12]                   rd       opcode
    31                  12 11            7 6        0
```

## 连接关系

- **输入来源**：inst（IM → SCPU）→ 各立即数字段、ctrl → EXTOp
- **输出去向**：ALU B 输入（通过 ALUSrc mux）、NPC（用于跳转偏移计算）

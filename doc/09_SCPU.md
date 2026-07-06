# SCPU — 单周期 CPU 核心

## 功能描述

SCPU（Single-Cycle CPU）是单周期 CPU 的核心模块。它将 PC、NPC、RF、ctrl、EXT、ALU 和数据通路选择器整合在一起，组成完整的数据通路。所有指令在一个时钟周期内完成：取指（IF）→ 译码（ID）→ 执行（EX）→ 访存（MEM）→ 写回（WB）。

## 接口信号

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| `clk` | input | 1 | 时钟信号 |
| `reset` | input | 1 | 复位信号 |
| `inst_in` | input | 32 | 从 IM 读入的 32-bit 指令 |
| `Data_in` | input | 32 | 从 DM 读入的 32-bit 数据 |
| `mem_w` | output | 1 | 数据存储器写使能（传到 DM） |
| `PC_out` | output | 32 | 当前 PC（供 IM 取指用） |
| `Addr_out` | output | 32 | ALU 计算出的地址（供 DM 用） |
| `Data_out` | output | 32 | 写数据存储器的数据（RD2） |
| `reg_sel` | input | 5 | 调试用：选择要监控的寄存器号 |
| `reg_data` | output | 32 | 调试用：选中寄存器的值 |

## 内部信号与数据结构

### 指令字段提取（组合逻辑）

| 信号 | 来源 | 位宽 | 描述 |
|------|------|------|------|
| `Op` | inst_in[6:0] | 7 | 操作码 |
| `Funct7` | inst_in[31:25] | 7 | Funct7 |
| `Funct3` | inst_in[14:12] | 3 | Funct3 |
| `rs1` | inst_in[19:15] | 5 | 源寄存器 1 地址 |
| `rs2` | inst_in[24:20] | 5 | 源寄存器 2 地址 |
| `rd` | inst_in[11:7] | 5 | 目的寄存器地址 |
| `iimm_shamt` | inst_in[24:20] | 5 | I-type 移位量 |
| `iimm` | inst_in[31:20] | 12 | I-type 立即数 |
| `simm` | {inst_in[31:25], inst_in[11:7]} | 12 | S-type 立即数 |
| `bimm` | {inst_in[31], inst_in[7], inst_in[30:25], inst_in[11:8]} | 12 | B-type 立即数 |
| `uimm` | inst_in[31:12] | 20 | U-type 立即数 |
| `jimm` | {inst_in[31], inst_in[19:12], inst_in[20], inst_in[30:21]} | 20 | J-type 立即数 |

### 控制信号（来自 ctrl）

- `RegWrite`, `ALUSrc`, `MemWrite`, `EXTOp`, `ALUOp`, `NPCOp`, `WDSel`, `GPRSel`

### 数据通路关键信号

| 信号 | 位宽 | 描述 |
|------|------|------|
| `RD1`, `RD2` | 32 | RF 读出的源操作数 |
| `B` | 32 | ALU 的 B 操作数，ALUSrc 为 1 时选立即数 |
| `immout` | 32 | EXT 扩展后的立即数 |
| `aluout` | 32 | ALU 运算结果 |
| `WD` | 32 | 写回 RF 的数据 |
| `NPC` | 32 | 下一条 PC |
| `Zero` | 1 | ALU 零标志 |

## 内部模块实例化

| 实例名 | 模块 | 功能 |
|--------|------|------|
| `U_ctrl` | ctrl | 控制信号生成 |
| `U_PC` | PC | 程序计数器 |
| `U_NPC` | NPC | 下一条地址计算 |
| `U_EXT` | EXT | 立即数扩展 |
| `U_RF` | RF | 寄存器文件 |
| `U_alu` | alu | 算术逻辑单元 |

## 数据通路关键路径

### 1. R-type 指令 (ADD, SUB, OR, AND)
```
RF(RD1, RD2) → ALU(A, B=RD2) → WD(FromALU) → RF(WD)
```

### 2. I-type 指令 (ORI)
```
RF(RD1) + EXT(immout) → ALU(A=RD1, B=immout) → WD(FromALU) → RF(WD)
```

### 3. LW 指令
```
RF(RD1) + EXT(immout) → ALU(A=RD1, B=immout) → DM(addr) → Data_in → WD(FromMEM) → RF(WD)
```

### 4. SW 指令
```
RF(RD1) + EXT(immout) → ALU(addr) + RF(RD2) → DM(din) → 写入内存
```

### 5. BEQ 指令
```
RF(RD1, RD2) → ALU(A, B) → Zero → ctrl → NPCOp → NPC(PC+IMM)
```

### 6. JAL 指令
```
NPC(PC+IMM) → PC
WD(FromPC: PC+4) → RF(rd=ra)
```

### 7. JALR 指令
```
RF(RD1) + EXT(immout) → ALU → NPC(aluout)
WD(FromPC: PC+4) → RF(rd)
```

## 写回数据选择器（WD mux）

```verilog
always @*:
    case (WDSel):
        WDSel_FromALU: WD = aluout      // ALU 类指令
        WDSel_FromMEM: WD = Data_in     // LW
        WDSel_FromPC:  WD = PC_out + 4  // JAL/JALR 返回地址
```

## 连接关系

- **输入来源**：IM → inst_in、DM → Data_in
- **输出去向**：DM → mem_w, Addr_out, Data_out、IM → PC_out

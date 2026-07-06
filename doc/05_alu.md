# ALU — 算术逻辑单元

## 功能描述

ALU（Arithmetic Logic Unit）执行算术和逻辑运算。根据 5-bit 的 ALUOp 控制信号，对两个 32-bit 操作数 A、B 进行运算，输出结果 C 和零标志 Zero。当前 ALUOp 编码支持 17 种操作（8 指令版本实际使用约 5 种）。

## 接口信号

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| `A` | input | 32 | 操作数 A，来自 RF 的 RD1（rs1 的值） |
| `B` | input | 32 | 操作数 B，来自 RF 的 RD2 或 EXT 的立即数（ALUSrc 选择） |
| `ALUOp` | input | 5 | ALU 操作码，决定运算类型 |
| `PC` | input | 32 | 当前 PC 值（用于 AUIPC 指令） |
| `C` | output | 32 | ALU 运算结果 |
| `Zero` | output | 1 | 零标志。C==0 时为 1，用于 BEQ 分支判断 |

## 内部数据结构

| 名称 | 类型 | 位宽 | 描述 |
|------|------|------|------|
| `C` | reg | 32 | 组合逻辑输出，根据 ALUOp 计算 |

## ALUOp 完整编码（来自 `ctrl_encode_def.v`）

| ALUOp 值 | 宏定义 | 操作 | 计算 | 8 指令使用 |
|----------|--------|------|------|-----------|
| `5'b00000` | `ALUOp_nop` | 空操作 | C = A | |
| `5'b00001` | `ALUOp_lui` | 加载立即数高位 | C = B | |
| `5'b00010` | `ALUOp_auipc` | PC+立即数高位 | C = PC + B | |
| `5'b00011` | `ALUOp_add` | 加法 | C = A + B | ✅ ADD/LW/SW |
| `5'b00100` | `ALUOp_sub` | 减法 | C = A - B | ✅ SUB/BEQ |
| `5'b00101` | `ALUOp_bne` | 不等比较 | C = (A==B) | |
| `5'b00110` | `ALUOp_blt` | 有符号小于 | C = (A>=B) | |
| `5'b00111` | `ALUOp_bge` | 有符号大于等于 | C = (A<B) | |
| `5'b01000` | `ALUOp_bltu` | 无符号小于 | C = ($unsigned(A)>=$unsigned(B)) | |
| `5'b01001` | `ALUOp_bgeu` | 无符号大于等于 | C = ($unsigned(A)<$unsigned(B)) | |
| `5'b01010` | `ALUOp_slt` | 有符号小于置位 | C = (A<B) | |
| `5'b01011` | `ALUOp_sltu` | 无符号小于置位 | C = ($unsigned(A)<$unsigned(B)) | |
| `5'b01100` | `ALUOp_xor` | 异或 | C = A ^ B | |
| `5'b01101` | `ALUOp_or` | 或 | C = A \| B | ✅ OR/ORI |
| `5'b01110` | `ALUOp_and` | 与 | C = A & B | ✅ AND |
| `5'b01111` | `ALUOp_sll` | 左移 | C = A << B | |
| `5'b10000` | `ALUOp_srl` | 逻辑右移 | C = A >> B | |
| `5'b10001` | `ALUOp_sra` | 算术右移 | C = A >>> B | |

## 注意事项

1. **符号处理**：A、B 声明为 `signed [31:0]`，算术运算使用有符号比较。部分指令使用 `$unsigned()` 做无符号比较
2. **比较类指令**：将比较结果扩展为 32-bit（`{31'b0, result}`），Zero 标志由 C 是否为 0 决定
3. **8 指令版本实际使用**：ADD、SUB、OR、AND 四个 ALUOp。LW 和 SW 复用 ADD（地址计算），ORI 复用 OR，BEQ 复用 SUB（Zero 标志）

## 连接关系

- **输入来源**：RF → A (RD1)、B mux → B、ctrl → ALUOp、PC → PC
- **输出去向**：WD mux → C (aluout)、ctrl → Zero（用于 BEQ）、NPC → aluout（用于 JALR）、DM → aluout（作为存储地址）

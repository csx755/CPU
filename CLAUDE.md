# CLAUDE.md — 开发规范

> RISC-V 单周期→流水线 CPU 项目 · 大二计算机组成实践

## 1. 项目总览

```
vivado/
├── code/
│   ├── rtl/          ← 可综合 Verilog 设计文件
│   ├── sim/          ← 仿真文件（testbench, .dat, .asm）
│   └── xdc/          ← FPGA 引脚约束文件
├── doc/              ← 模块文档（每个模块一份 .md）
├── project_1/        ← Vivado 工程
├── CPU实现计划.md     ← 三阶段总计划
└── .gitignore
```

**三阶段路线**：8指令单周期 → RV32I 全指令 → 5级流水线

## 2. 核心开发原则：文档驱动开发

### 2.1 开发流程（严格按此顺序）

```
文档 → 代码 → 仿真 → 验证
  │      │      │      │
  │      │      │      └── 结果与文档预期一致 → commit
  │      │      └── 自主跑 iVerilog，高频仿真
  │      └── 严格对照文档中的接口/功能编写
  └── 先更新 doc/ 下对应模块文档
```

**任何代码修改前，必须：**

1. **先修改 `doc/` 下的对应模块文档** — 更新接口信号表、功能描述、数据路径
2. **再对照文档修改代码** — 信号名、位宽、逻辑必须与文档一致
3. **出现错误时** — 回到文档寻找代码与文档的差异，不要盲目改代码

### 2.2 文档规范

每个模块文档位于 `doc/`，包含：

| 章节 | 内容 |
|------|------|
| 功能描述 | 模块做什么 |
| 接口信号表 | 信号名、方向、位宽、含义 |
| 内部数据结构 | reg/wire 变量、数组、参数 |
| 工作逻辑 | 伪代码或行为描述 |
| 连接关系 | 输入从哪来、输出到哪去 |
| 注意事项 | 边界条件、已知限制 |

## 3. 仿真规范

### 3.1 工具与命令

使用 iVerilog（位于 `C:\Users\34955\Program\iverilog\bin\`）：

```bash
export PATH="/c/Users/34955/Program/iverilog/bin:$PATH"
cd /d/Desktop/study_computer/vivado/code/sim

# 编译（所有 .v 文件）
iverilog -o cpu_test -I ../rtl \
  ../rtl/alu.v ../rtl/ctrl.v ../rtl/ctrl_encode_def.v \
  ../rtl/dm.v ../rtl/EXT.v ../rtl/im.v ../rtl/NPC.v \
  ../rtl/PC.v ../rtl/RF.v ../rtl/SCPU.v ../rtl/sccomp.v \
  sccomp_tb.v

# 运行仿真
vvp -n cpu_test

# 查看输出
cat results.txt
```

### 3.2 频率约定

| 场景 | 频率 | 周期 | 说明 |
|------|------|------|------|
| **仿真** | **10 MHz** 或更高 | `#(50)` = 100ns | 高频快速验证，不必等真实时序 |
| **下板** | **由约束文件决定** | `icf.xdc` 中指定 | 取决于开发板时钟源 |

> iVerilog 仿真时 `timescale 1ns/1ps`，`#50` 代表半周期 50ns → 10 MHz。仿真用高频没有问题；下板前检查 `icf.xdc` 的时钟约束是否匹配板载晶振。

### 3.3 仿真验证标准

- DM 写入数据与 ASM 预期一致
- 寄存器终值与预期一致
- `$finish` 正常退出（不卡死、不超时）

## 4. Vivado 工程规范

### 4.1 文件角色

| 文件夹 | Vivado 目标 | 说明 |
|--------|------------|------|
| `code/rtl/*.v` | **Design Sources** | 可综合设计文件 |
| `code/sim/sccomp_tb.v` | **Simulation Sources** | 仿真顶层 |
| `code/xdc/icf.xdc` | **Constraints** | 引脚约束 |
| `code/sim/*.dat`, `*.coe` | 不加入工程 | 仿真/BRAM 初始化数据 |

### 4.2 下板流程

1. 仿真验证通过
2. 检查 `icf.xdc` 时钟频率匹配板载晶振
3. Vivado: Synthesis → Implementation → Generate Bitstream
4. Open Hardware Manager → Program Device

## 5. 代码规范

### 5.1 模块编写

- 端口声明使用注释标注方向和描述
- 组合逻辑使用 `always @(*)` / `assign`，时序逻辑使用 `always @(posedge clk)`
- 控制信号统一通过 `ctrl_encode_def.v` 的宏定义引用
- 每个模块实例化时加注释说明功能

### 5.2 命名规范

| 元素 | 规范 | 示例 |
|------|------|------|
| 模块名 | 小写或大写缩写 | `alu`, `PC`, `RF`, `ctrl` |
| 信号名 | 小写下划线 | `reg_write`, `alu_out` |
| 控制宏 | 大写+路径风格 | `` `ALUOp_add `` |
| 实例名 | `U_` + 模块名 | `U_SCPU`, `U_RF` |
| 低有效信号 | `_n` 后缀 | `rstn` |

### 5.3 兼容性

- **避免 `{N-M{...}}` 这类计算出的复制宽度**，iVerilog 不支持 → 直接写常量
- 所有 `.v` 文件使用 LF 行尾（Git Bash 下避免 CRLF 警告）

## 6. 排错流程

遇到仿真错误时，按以下顺序排查：

```
1. 检查 doc/ 文档 → 确认模块功能与接口是否正确
2. 检查 ctrl.v 控制信号 → 新指令是否遗漏了 RegWrite/ALUSrc/EXTOp 等
3. 检查 ALUOp 映射 → alu.v 是否支持所需运算
4. 检查 EXT → 立即数格式是否正确
5. 检查数据通路 → SCPU.v 中信号连接是否完整
6. 检查测试程序 → .asm 和 .dat 是否匹配
```

**不盲目试错**，每一步修改都要有文档依据。

## 7. 当前状态

| 项目 | 状态 |
|------|------|
| 8 指令 CPU 仿真 | ✅ 通过（commit `818b8a2`） |
| Vivado 工程 | 待配置（加入 RTL + XDC） |
| 下板验证 | 待完成 |
| 下一阶段 | 扩展至 RV32I 全指令集 |

## 8. 阶段开发检查清单

每次进入新阶段前：

- [ ] 阅读 `CPU实现计划.md` 中对应阶段的说明
- [ ] 阅读 `doc/00_整体架构.md` 确认模块层次
- [ ] 更新或新增受影响的 `doc/` 模块文档
- [ ] 编写测试汇编程序（.asm）并生成机器码（.dat）
- [ ] 修改 RTL 代码，对照文档逐模块修改
- [ ] iVerilog 高频仿真验证
- [ ] Vivado 综合/实现（如有需要，调整频率下板）
- [ ] Commit with tag

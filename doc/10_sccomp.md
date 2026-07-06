# sccomp — 单周期计算机顶层模块

## 功能描述

sccomp（Single-Cycle Computer）是整个单周期计算机的顶层模块。它将 IM（指令存储器）、SCPU（CPU 核心）和 DM（数据存储器）例化并互连，同时提供调试用的寄存器数据输出。

## 接口信号

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| `clk` | input | 1 | 时钟信号 |
| `rstn` | input | 1 | 复位信号（低有效？见注意事项） |
| `reg_sel` | input | 5 | 调试用：选择要监控的寄存器号 |
| `reg_data` | output | 32 | 调试用：选中寄存器的值 |
| `PC` | output | 32 | 当前 PC（供仿真监控用） |
| `instr` | output | 32 | 当前指令（供仿真监控用） |

## 内部数据结构

| 名称 | 类型 | 位宽 | 描述 |
|------|------|------|------|
| `im_out` | wire | 32 | IM 输出的指令 → SCPU.inst_in |
| `mem_w` | wire | 1 | SCPU 产生的 DM 写使能 |
| `PC_out` | wire | 32 | SCPU 产生的 PC → IM.addr |
| `mem_addr` | wire | 32 | SCPU 产生的 DM 地址 |
| `Write_data` | wire | 32 | 写入 DM 的数据 |
| `Data_out` | wire | 32 | 从 DM 读出的数据 → SCPU.Data_in |

## 内部模块实例化

| 实例名 | 模块 | 功能 |
|--------|------|------|
| `U_IM` | im | 指令存储器 |
| `U_SCPU` | scpu | CPU 核心 |
| `U_DM` | dm | 数据存储器 |

## 模块互联拓扑

```
         clk ──┬────→ U_IM
               ├────→ U_SCPU
               └────→ U_DM

       rstn ──────→ U_SCPU

      U_IM(ROM) ──→ inst ←── im_out ──→ U_SCPU(inst_in)
                                        U_SCPU(PC_out) ──→ PC_out ←──→ U_IM(addr)
                                        U_SCPU(mem_w)  ──→ U_DM(DMWr)
                                        U_SCPU(Addr_out) ──→ U_DM(addr)
                                        U_SCPU(Data_out) ──→ U_DM(din)
      U_DM(dout) ──→ Data_out ──→ U_SCPU(Data_in)

      RF(rf[reg_sel]) ──→ reg_data   （调试输出）
```

## 地址映射

| PC 范围 | 访问设备 | 说明 |
|---------|---------|------|
| 0x0000_0000 ~ 0x0000_01FC | IM (ROM) | 指令存储器，128 字 |
| ALU 地址输出 | DM (dmem) | 数据存储器，128 字 |

## 注意事项

1. **rstn 命名**：信号名为 `rstn`（通常暗示低有效），但代码中用作高有效复位。信号命名存在不一致
2. **IM 初始化**：`IM.ROM` 由 testbench 通过 `$readmemh` 在仿真开始时初始化，综合时需用 `.coe` 文件初始化 BRAM IP
3. **调试接口**：`reg_sel` 和 `reg_data` 用于仿真时读取 RF 值，综合时可移除

## 连接关系

- **输入来源**：外部（开关/按键 → 约束文件）→ clk, rstn, reg_sel
- **输出去向**：外部（LED/数码管 → 约束文件）→ reg_data

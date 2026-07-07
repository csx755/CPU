# 单周期 CPU SoC 系统接口文档

> 基于 schematic (1).pdf —— Nexys4 A7-100T (xc7a100tcsg324-1)
> 最后更新：2026-07-07

## 1. 系统架构总览

```
                         clk (100MHz)
                              │
              ┌───────────────┼───────────────┐
              │               │               │
          clk_div          Enter          SSeg7.clk
              │           (消抖)          (直连100MHz)
           Clk_CPU      BTN_OK,SW_OK         │
              │               │               │
        ┌─────┴──────────┐    │               │
        │                │    │               │
      SCPU           Counter_x │              │
     ┌──┴──┐       (clk0/1/2)  │              │
     │     │            │      │              │
  ROM_D   MIO_BUS ─────┴──────┘              │
     │     │   │                             │
     │     │   ├─ RAM_B ─ dm_ctrl            │
     │     │   ├─ SPIO ─ led[15:0] → 板子    │
     │     │   └─ Multi_8CH32 ──→ SSeg7 ─→ 数码管
     │     │
     │     └──→ Multi_8CH32 (PC, Addr_out, Data_out)
     └────→ Multi_8CH32 (inst_in)
```

> **模块实现状态**：`dm_ctrl` `SPIO` `Counter_x` `Enter` `MIO_BUS` `Multi_8CH32` `SSeg7` 均已替换为手写 Verilog，仅 `SCPU` 仍为 .edf 黑盒。

**核心设计思想**：Memory-Mapped I/O —— CPU 通过 MIO_BUS 用地址空间区分访问目标（RAM / LED / 开关 / 计数器），对 CPU 而言所有外设都像读写内存一样操作。

---

## 2. 顶层模块端口（soc_top.v）


| 端口              | 方向   | 位宽 | 连接目标         | 说明         |
| ----------------- | ------ | ---- | ---------------- | ------------ |
| `clk`             | input  | 1    | 板子 E3 (100MHz) | 系统时钟     |
| `rstn`            | input  | 1    | 板子 C12 (btnC)  | 复位，低有效 |
| `btn_i[4:0]`      | input  | 5    | 板子按键         | 5 个按钮     |
| `sw_i[15:0]`      | input  | 16   | 板子拨码开关     | 16 个开关    |
| `disp_an_o[7:0]`  | output | 8    | 板子 AN0-AN7     | 数码管位选   |
| `disp_seg_o[7:0]` | output | 8    | 板子 CA-CG,DP    | 数码管段码   |
| `led_o[15:0]`     | output | 16   | 板子 LED0-LED15  | LED 输出     |

---

## 3. 模块接口与连接表

### 3.1 SCPU — 单周期 CPU（老师 .edf 黑盒，唯一未替换模块）


| 端口        | 方向   | 位宽 | 连接目标                                                             | 说明                      |
| ----------- | ------ | ---- | -------------------------------------------------------------------- | ------------------------- |
| `clk`       | input  | 1    | clk_div.Clk_CPU                                                      | CPU 工作时钟              |
| `reset`     | input  | 1    | ~rstn                                                                | 高有效复位                |
| `inst_in`   | input  | 32   | ROM_D.spo                                                            | 取指                      |
| `Data_in`   | input  | 32   | dm_ctrl.Data_read                                              | Load 数据                 |
| `INT`       | input  | 1    | Counter_x.counter0_OUT                                               | 中断信号                  |
| `mem_w`     | output | 1    | MIO_BUS.mem_w + dm_ctrl.mem_w                                  | 写使能（扇出两路）        |
| `PC_out`    | output | 32   | ROM_D.a(PC[11:2]) + MIO_BUS.PC + Multi_8CH32.data7+Multi_8CH32.data1 | PC（扇出三路）            |
| `Addr_out`  | output | 32   | MIO_BUS.addr_bus + dm_ctrl.Addr_in + Multi_8CH32.data4         | 访存地址（扇出三路）      |
| `Data_out`  | output | 32   | MIO_BUS.Cpu_data2bus + Multi_8CH32.data5                             | 写数据（扇出两路）        |
| `dm_ctrl`   | output | 3    | dm_ctrl.dm_ctrl                                                | 访存类型                  |

> **注意**：新版 SCPU.edf 无 `CPU_MIO` / `MIO_ready` 端口，原自环逻辑已移除。

---

### 3.2 ROM_D — 指令存储器（Vivado Block ROM IP）


| 端口        | 方向   | 位宽 | 连接目标                         | 说明                   |
| ----------- | ------ | ---- | -------------------------------- | ---------------------- |
| `a[9:0]`    | input  | 10   | SCPU.PC_out[11:2]                | 字地址（PC 右移 2 位） |
| `spo[31:0]` | output | 32   | SCPU.inst_in + Multi_8CH32.data2 | 指令（扇出两路）       |

> ROM 规格：1024 × 32-bit = 4KB，.coe 初始化

---

### 3.3 RAM_B — 数据存储器（Vivado Block RAM IP）


| 端口          | 方向   | 位宽 | 连接目标                       | 说明       |
| ------------- | ------ | ---- | ------------------------------ | ---------- |
| `addra[9:0]`  | input  | 10   | MIO_BUS.ram_addr[9:0]          | 字地址     |
| `dina[31:0]`  | input  | 32   | dm_controller.Data_write_to_dm | 写数据     |
| `douta[31:0]` | output | 32   | MIO_BUS.ram_data_out           | 读数据     |
| `wea[3:0]`    | input  | 4    | dm_controller.wea_mem[3:0]     | 字节写使能 |
| `clka`        | input  | 1    | ~clk (系统时钟取反)            | 时钟       |

> RAM 规格：1024 × 32-bit = 4KB

---

### 3.4 dm_ctrl — 数据存储器访问控制器（手写模块）

> 替换原 .edf 黑盒，模块名 `dm_ctrl`，端口 `dm_ctrl[2:0]`。

| 端口                       | 方向   | 位宽 | 连接目标                                                | 说明                            |
| -------------------------- | ------ | ---- | ------------------------------------------------------- | ------------------------------- |
| `mem_w`                    | input  | 1    | SCPU.mem_w                                              | 写使能                          |
| `Addr_in[31:0]`            | input  | 32   | SCPU.Addr_out                                           | 访存地址                        |
| `Data_write[31:0]`         | input  | 32   | MIO_BUS.ram_data_in                                     | 写数据（经 MIO_BUS 中转）       |
| `dm_ctrl[2:0]`             | input  | 3    | SCPU.dm_ctrl                                            | 访存类型编码                    |
| `Data_read_from_dm[31:0]`  | input  | 32   | MIO_BUS.Cpu_data4bus                                    | RAM 原始数据（经 MIO_BUS 中转） |
| `Data_read[31:0]`          | output | 32   | SCPU.Data_in                                            | Load 数据（经对齐/扩展后送 CPU）|
| `Data_write_to_dm[31:0]`   | output | 32   | RAM_B.dina                                              | 写入 RAM 的数据                 |
| `wea_mem[3:0]`             | output | 4    | RAM_B.wea                                               | 字节写使能                      |

**dm_ctrl 编码**：

| 值       | 含义                     |
| -------- | ------------------------ |
| `3'b000` | word (32-bit)            |
| `3'b001` | halfword signed (16-bit) |
| `3'b010` | halfword unsigned        |
| `3'b011` | byte signed (8-bit)      |
| `3'b100` | byte unsigned            |

**内部逻辑**：纯组合逻辑，分读写两路。

**写路径**（mem_w=1 时有效）：

| dm_ctrl   | wea_mem[3:0]                        | Data_write_to_dm                        |
| --------- | ----------------------------------- | --------------------------------------- |
| 000 (SW)  | `4'b1111`                           | `Data_write`（直通）                    |
| 001/010 (SH) | addr[1] ? `4'b1100` : `4'b0011` | `{2{Data_write[15:0]}}`（半字复制）     |
| 011/100 (SB) | addr[1:0] → 独热码                | `{4{Data_write[7:0]}}`（字节复制）      |
| 其他      | `4'b0000`                           | `32'b0`                                 |

**读路径**（始终有效）：

| dm_ctrl   | 输入字节                        | Data_read                                   |
| --------- | ------------------------------- | ------------------------------------------- |
| 000 (LW)  | —                               | `Data_read_from_dm`（直通）                 |
| 001 (LH)  | addr[1] ? [31:16] : [15:0]      | `{{16{半字[15]}}, 半字[15:0]}`（符号扩展） |
| 010 (LHU) | addr[1] ? [31:16] : [15:0]      | `{16'b0, 半字[15:0]}`（零扩展）            |
| 011 (LB)  | addr[1:0] → 字节位置            | `{{24{字节[7]}}, 字节[7:0]}`（符号扩展）   |
| 100 (LBU) | addr[1:0] → 字节位置            | `{24'b0, 字节[7:0]}`（零扩展）             |

**注意事项**：
- 所有输出为纯组合逻辑，`Data_read` 直接由 `Data_read_from_dm` + `dm_ctrl` + `Addr_in` 计算
- `wea_mem` 仅在 `mem_w=1` 时有效，否则为 `4'b0000`
- 存储指令通过复制数据到对应字节位置实现非对齐写入（SB/SH 的 4 份/2 份复制 + wea 掩码）

---

### 3.5 MIO_BUS — 存储器映射 IO 总线（手写模块）

> 纯组合逻辑地址解码 + 数据路由。clk/rst 保留接口兼容但未使用。


| 端口                    | 方向   | 位宽 | 连接目标                                                | 说明                     |
| ----------------------- | ------ | ---- | ------------------------------------------------------- | ------------------------ |
| `clk`                   | input  | 1    | clk (100MHz)                                            | 总线时钟 (未使用)        |
| `rst`                   | input  | 1    | ~rstn                                                   | 复位 (未使用)            |
| `BTN[4:0]`              | input  | 5    | Enter.BTN_out                                           | 按键状态                 |
| `SW[15:0]`              | input  | 16   | Enter.SW_out                                            | 拨码开关                 |
| `PC[31:0]`              | input  | 32   | SCPU.PC_out                                             | PC 值                    |
| `mem_w`                 | input  | 1    | SCPU.mem_w                                              | 写使能                   |
| `Cpu_data2bus[31:0]`    | input  | 32   | SCPU.Data_out                                           | CPU 写数据               |
| `addr_bus[31:0]`        | input  | 32   | SCPU.Addr_out                                           | CPU 地址                 |
| `ram_data_out[31:0]`    | input  | 32   | RAM_B.douta                                             | RAM 读数据               |
| `led_out[15:0]`         | input  | 16   | SPIO.LED_out                                            | LED 状态                 |
| `counter_out[31:0]`     | input  | 32   | Counter_x.counter_out                                   | 计数器值                 |
| `counter0/1/2_out`      | input  | 1    | Counter_x.counterX_OUT                                  | 计数器溢出               |
| `Cpu_data4bus[31:0]`    | output | 32   | dm_ctrl.Data_read_from_dm                               | CPU 读数据               |
| `ram_data_in[31:0]`     | output | 32   | dm_ctrl.Data_write                                      | RAM 写数据               |
| `ram_addr[9:0]`         | output | 10   | RAM_B.addra                                             | RAM 字地址               |
| `data_ram_we`           | output | 1    | (中间信号)                                              | RAM 写使能               |
| `GPIOf0000000_we`       | output | 1    | SPIO.EN (GPIOFO)                                        | LED 写使能               |
| `GPIOe0000000_we`       | output | 1    | Multi_8CH32.EN (GPIOEO)                                 | 数码管写使能 (单周期脉冲)|
| `counter_we`            | output | 1    | Counter_x.counter_we                                    | 计数器写使能             |
| `Peripheral_in[31:0]`   | output | 32   | data0 + SPIO.P_Data + Counter_x.counter_val (CPU2IO)    | 外设数据 (扇出三路)      |

**地址空间映射**：

| 地址 | 设备 | 读 | 写 |
|------|------|----|----|
| `0x0000_0000 ~ 0x0000_0FFF` | RAM_B | ram_data_out | Cpu_data2bus |
| `0xFFFF_F000` | SPIO (LED) | {16'b0, led_out} | Peripheral_in |
| `0xFFFF_F004` | Multi_8CH32 (数码管) | 0 | Peripheral_in |
| `0xFFFF_F008` | Counter_x | {counter_out[31:3], overflow[2:0]} | Peripheral_in |
| `0xFFFF_F010` | SW 拨码开关 | {16'b0, SW} | — |
| `0xFFFF_F014` | BTN 按键 | {27'b0, BTN} | — |

---

### 3.6 clk_div — 时钟分频器


| 端口            | 方向   | 位宽 | 连接目标                                                     | 说明     |
| --------------- | ------ | ---- | ------------------------------------------------------------ | -------- |
| `clk`           | input  | 1    | 板子 clk (100MHz)                                            | 系统时钟 |
| `rst`           | input  | 1    | ~rstn                                                        | 复位     |
| `SW2`           | input  | 1    | SW_OK[2]                                                     | 频率选择 |
| `clkdiv[31:0]`  | output | 32   | Counter_x.clk0/1/2 + SSeg7.flash + Multi_8CH32.point_in      | 分频计数 |
| `Clk_CPU`       | output | 1    | SCPU.clk                                                     | CPU 时钟 |

**频率计算**：`Clk_CPU = SW_OK[2] ? clkdiv[24] : clkdiv[3]`

| 模式 | 频率 | 用途 |
|------|------|------|
| SW2=0 | ≈6.25MHz | 正常运行 |
| SW2=1 | ≈2.98Hz | 慢速调试 |

**clkdiv 位分配**：

| clkdiv 位 | 连接目标 | 频率 | 用途 |
|-----------|----------|------|------|
| bit 3 | Clk_CPU (SW2=0) | 6.25MHz | CPU 时钟 |
| bit 6 | Counter_x.clk0 | 780kHz | 计数器 0 |
| bit 9 | Counter_x.clk1 | 97kHz | 计数器 1 |
| bit 10 | SSeg7.flash | 48kHz | 暂未使用 |
| bit 11 | Counter_x.clk2 | 24kHz | 计数器 2 |
| bit 24 | Clk_CPU (SW2=1) | 2.98Hz | 慢速调试 |
| 全 32 位 | Multi_8CH32.point_in | — | 小数点 |

> **注**：SSeg7.SW0 已改用 SW_OK[0]（物理开关），不再用 clkdiv[0]。SSeg7.clk 直连 100MHz 系统时钟（内部预分频）。

---

### 3.7 Counter_x — 3 通道计数器（手写模块）

> 3 个独立递减计数器，各自 clkX 时钟域。含 `loaded` 标志位防止复位后误判溢出。


| 端口                  | 方向   | 位宽 | 连接目标                                | 说明               |
| --------------------- | ------ | ---- | --------------------------------------- | ------------------ |
| `clk`                 | input  | 1    | ~Clk_CPU                                | 系统时钟 (未使用)  |
| `rst`                 | input  | 1    | ~rstn                                   | 复位               |
| `clk0`                | input  | 1    | clkdiv[6]                               | 通道 0 时钟        |
| `clk1`                | input  | 1    | clkdiv[9]                               | 通道 1 时钟        |
| `clk2`                | input  | 1    | clkdiv[11]                              | 通道 2 时钟        |
| `counter_we`          | input  | 1    | MIO_BUS.counter_we                      | 写使能             |
| `counter_val[31:0]`   | input  | 32   | CPU2IO                                  | 初值               |
| `counter_ch[1:0]`     | input  | 2    | SPIO.counter_set                        | 通道选择           |
| `counter0/1/2_OUT`    | output | 1    | SCPU.INT + MIO_BUS                      | 溢出标志           |
| `counter_out[31:0]`   | output | 32   | MIO_BUS + Multi_8CH32.data3             | 当前值             |

> **关键修复**：复位后 `counterX_OUT = 0`，只有 CPU 通过 `counter_we` 加载初值后才在递减到 0 时拉高，避免误触发 `SCPU.INT`。

---

### 3.8 SPIO — LED 外设控制器（手写模块）

> 替换原 SPIO.edf。EN=1 时锁存 P_Data。


| 端口                | 方向   | 位宽 | 连接目标                  | 说明                |
| ------------------- | ------ | ---- | ------------------------- | ------------------- |
| `clk`               | input  | 1    | ~Clk_CPU                  | 时钟                |
| `rst`               | input  | 1    | ~rstn                     | 复位                |
| `EN`                | input  | 1    | GPIOFO                    | 写使能              |
| `P_Data[31:0]`      | input  | 32   | CPU2IO                    | 外设数据            |
| `counter_set[1:0]`  | output | 2    | Counter_x.counter_ch      | 计数器通道选择      |
| `LED_out[15:0]`     | output | 16   | MIO_BUS.led_out           | LED 读回            |
| `led[15:0]`         | output | 16   | 板子 led_o                | LED 输出            |
| `GPIOf0[13:0]`      | output | 14   | (悬空)                    | 预留 GPIO           |

> **寄存器映射**：`P_Data[15:0] → led`, `P_Data[17:16] → counter_set`, `LED_out ≡ led`。

---

### 3.9 Enter — 按键/开关输入（手写模块）

> 拨码开关直通，按键含 10ms 消抖（饱和计数器法）。


| 端口              | 方向   | 位宽 | 连接目标           | 说明            |
| ----------------- | ------ | ---- | ------------------ | --------------- |
| `clk`             | input  | 1    | 板子 clk (100MHz)  | 系统时钟        |
| `BTN[4:0]`        | input  | 5    | 板子 btn_i         | 按键输入        |
| `SW[15:0]`        | input  | 16   | 板子 sw_i          | 拨码开关        |
| `BTN_out[4:0]`    | output | 5    | MIO_BUS.BTN        | 消抖后按键      |
| `SW_out[15:0]`    | output | 16   | MIO_BUS.SW         | 直通开关        |

> **消抖**：5 个按键各有一个 20-bit 饱和计数器，阈值 ~10ms @ 100MHz。开关直通无消抖。

---

### 3.10 Multi_8CH32 — 8 通道 32 位显示多路选择器（手写模块）

> 纯组合逻辑。EN 保留接口兼容但不门控输出，始终根据 Switch[2:0] 实时切换。


| 端口                    | 方向   | 位宽 | 连接目标                          | 说明                         |
| ----------------------- | ------ | ---- | --------------------------------- | ---------------------------- |
| `clk`                   | input  | 1    | ~Clk_CPU                          | 时钟 (未使用)                |
| `rst`                   | input  | 1    | ~rstn                             | 复位 (未使用)                |
| `EN`                    | input  | 1    | MIO_BUS.GPIOe0000000_we (GPIOEO)  | 使能 (保留但不门控输出)      |
| `Switch[2:0]`           | input  | 3    | SW_OK[7:5]                        | 通道选择 (实时切换)          |
| `point_in[63:0]`        | input  | 64   | {clkdiv[31:0], clkdiv[31:0]}      | 小数点输入 (8ch x 8bit)      |
| `LES[63:0]`             | input  | 64   | {64{1'b1}}                        | 位使能输入 (全亮)            |
| `data0`                 | input  | 32   | CPU2IO                            | 外设数据                     |
| `data1`                 | input  | 32   | {2'b0, PC[31:2]}                  | PC 字地址                    |
| `data2`                 | input  | 32   | inst_in                           | 当前指令                     |
| `data3`                 | input  | 32   | counter_out                       | 计数器值                     |
| `data4`                 | input  | 32   | Addr_out                          | ALU 地址                     |
| `data5`                 | input  | 32   | Data_out                          | 写数据                       |
| `data6`                 | input  | 32   | Cpu_data4bus                      | MIO_BUS 返回数据             |
| `data7`                 | input  | 32   | PC                                | PC 完整值                    |
| `point_out[7:0]`        | output | 8    | SSeg7.point                       | 小数点                       |
| `LE_out[7:0]`           | output | 8    | SSeg7.LES                         | 位使能                       |
| `Disp_num[31:0]`        | output | 32   | SSeg7.Hexs                        | 显示数据                     |

> **设计要点**：EN = GPIOEO 是 MIO_BUS 的单周期写脉冲，不能门控输出，否则显示 99.99% 时间全暗。

**Switch[7:5] 通道映射**：

| SW[7:5] | 数据源 | 显示内容            |
| ------- | ------ | ------------------- |
| 000     | data0  | 外设数据 (CPU2IO)   |
| 001     | data1  | PC 字地址           |
| 010     | data2  | 当前指令 (inst_in)  |
| 011     | data3  | 计数器值            |
| 100     | data4  | ALU 地址 (Addr_out) |
| 101     | data5  | 写数据 (Data_out)   |
| 110     | data6  | Cpu_data4bus        |
| 111     | data7  | PC 完整值           |

---

### 3.11 SSeg7 — 7 段数码管驱动（手写模块）

> 替换原 SSeg7.edf 黑盒。含文本/图形双模式 + 扫描预分频。


| 端口            | 方向   | 位宽 | 连接目标       | 说明                          |
| --------------- | ------ | ---- | -------------- | ----------------------------- |
| `clk`           | input  | 1    | 板子 clk (100MHz) | 系统时钟 (内部 17-bit 预分频) |
| `rst`           | input  | 1    | ~rstn          | 复位                          |
| `SW0`           | input  | 1    | SW_OK[0]       | 0=文本, 1=图形                |
| `flash`         | input  | 1    | clkdiv[10]     | PWM 调光 (暂未使用)           |
| `Hexs[31:0]`    | input  | 32   | Disp_num       | 32-bit 显示数据               |
| `point[7:0]`    | input  | 8    | point_out      | 小数点                        |
| `LES[7:0]`      | input  | 8    | LE_out         | 位使能 (0=灭)                 |
| `seg_an[7:0]`   | output | 8    | disp_an_o      | 位选 (低有效)                 |
| `seg_sout[7:0]` | output | 8    | disp_seg_o     | 段码 (低有效, 共阳极)         |

**内部设计**：

| 特性 | 实现 |
|------|------|
| 扫描预分频 | `clk / 2^17 ≈ 763Hz/位`, 95Hz 完整刷新 |
| 文本模式 (SW0=0) | Hexs[31:0] → 8 位十六进制, 无调光, 100% 亮度 |
| 图形模式 (SW0=1) | 64-bit 跑马灯, 25-bit 移位计时器, ~0.34s/步 |
| 小数点 | `point[digit]` 控制 (仅文本模式) |
| 位消隐 | `LES[digit]=0` 时该位全灭 |

---

## 4. 信号扇出汇总


| 信号来源                           | 扇出目标                                                         |
| ---------------------------------- | ---------------------------------------------------------------- |
| **SCPU.PC_out**                    | ROM_D.a(PC[11:2]), MIO_BUS.PC, Multi_8CH32.data7                 |
| **SCPU.Addr_out**                  | MIO_BUS.addr_bus, dm_ctrl.Addr_in, Multi_8CH32.data4             |
| **SCPU.Data_out**                  | MIO_BUS.Cpu_data2bus, Multi_8CH32.data5                          |
| **SCPU.mem_w**                     | MIO_BUS.mem_w, dm_ctrl.mem_w                                     |
| **dm_ctrl.Data_read**              | SCPU.Data_in                                                     |
| **MIO_BUS.Peripheral_in (CPU2IO)** | Multi_8CH32.data0, SPIO.P_Data, Counter_x.counter_val            |
| **Counter_x.counter0_OUT**         | SCPU.INT, MIO_BUS.counter0_out                                   |
| **ROM_D.spo (inst_in)**            | SCPU.inst_in, Multi_8CH32.data2                                  |
| **clk_div.Clk_CPU**                | SCPU.clk                                                         |
| **clk_div.clkdiv**                 | Counter_x.clk0/1/2, SSeg7.flash, Multi_8CH32.point_in            |
| **Counter_x.counter_out**          | MIO_BUS.counter_out, Multi_8CH32.data3                           |
| **SPIO.LED_out**                   | MIO_BUS.led_out                                                  |

---

## 5. 已知问题


| # | 问题                    | 描述                                                     | 状态   |
| - | ----------------------- | -------------------------------------------------------- | ------ |
| 1 | **point_in 位宽不匹配** | Multi_8CH32.point_in 是 64bit，clkdiv 是 32bit → 复制拼接 | 照图连接 |
| 2 | **data_ram_we 去向**    | MIO_BUS.data_ram_we 仅内部产生，未扇出到其他模块          | 信号保留 |
| 3 | **SSeg7.flash 暂未使用**| PWM 调光导致小数点频闪，当前禁用                          | 后续优化 |
| 4 | **SCPU.edf 仍为黑盒**   | 唯一未替换的 .edf 模块                                    | 待替换 |

---

## 6. 时钟树

```
板子 clk (100MHz, pin E3)
    │
    ├── Enter.clk (直连)
    ├── MIO_BUS.clk (直连, 未使用)
    ├── SSeg7.clk (直连, 内部 17-bit 预分频 → 763Hz/位)
    ├── RAM_B.clka = ~clk (取反)
    │
    └── clk_div.clk
            │
            ├── Clk_CPU ─── SCPU.clk
            ├── ~Clk_CPU ─── Counter_x.clk, SPIO.clk, Multi_8CH32.clk
            │
            ├── clkdiv[6]  ─── Counter_x.clk0 (780kHz)
            ├── clkdiv[9]  ─── Counter_x.clk1 (97kHz)
            ├── clkdiv[10] ─── SSeg7.flash (暂未使用)
            ├── clkdiv[11] ─── Counter_x.clk2 (24kHz)
            └── clkdiv[31:0] ─── Multi_8CH32.point_in
```

---

## 7. 复位树

```
板子 rstn (btnC, pin C12, 低有效)
    │
    └── ~rstn (取反 → 高有效复位 rst)
            │
            ├── SCPU.reset
            ├── MIO_BUS.rst
            ├── clk_div.rst
            ├── dm_ctrl (无复位, 纯组合逻辑)
            ├── Counter_x.rst
            ├── SPIO.rst
            ├── Multi_8CH32.rst
            ├── SSeg7.rst
            └── Enter (无复位, 开关直通 / 按键自复位)
```

---

## 8. 中间信号命名对照

顶层模块内部需要定义的中间 wire 信号：


| 中间信号名          | 位宽 | 说明 |
| ------------------- | ---- | ---- |
| `rst`               | 1    | `~rstn`，全局高有效复位 |
| `BTN_OK[4:0]`       | 5    | Enter 消抖后按键 → MIO_BUS.BTN |
| `SW_OK[15:0]`       | 16   | Enter 直通开关 → MIO_BUS.SW + clk_div.SW2 |
| `inst_in[31:0]`     | 32   | ROM_D.spo → SCPU.inst_in + Multi_8CH32.data2 |
| `Data_in[31:0]`     | 32   | dm_ctrl.Data_read → SCPU.Data_in |
| `Data_out[31:0]`    | 32   | SCPU.Data_out → MIO_BUS.Cpu_data2bus + Multi_8CH32.data5 |
| `Addr_out[31:0]`    | 32   | SCPU.Addr_out → MIO_BUS.addr_bus + dm_ctrl.Addr_in + Multi_8CH32.data4 |
| `PC[31:0]`          | 32   | SCPU.PC_out → ROM_D.a + MIO_BUS.PC + Multi_8CH32.data7 |
| `douta[31:0]`       | 32   | RAM_B.douta → MIO_BUS.ram_data_out |
| `dina[31:0]`        | 32   | dm_ctrl.Data_write_to_dm → RAM_B.dina |
| `wea_mem[3:0]`      | 4    | dm_ctrl.wea_mem → RAM_B.wea |
| `CPU2IO[31:0]`      | 32   | MIO_BUS.Peripheral_in → data0 + SPIO.P_Data + Counter_x.counter_val |
| `GPIOFO`            | 1    | MIO_BUS.GPIOf0000000_we → SPIO.EN |
| `GPIOEO`            | 1    | MIO_BUS.GPIOe0000000_we → Multi_8CH32.EN |
| `counter_out[31:0]` | 32   | Counter_x.counter_out → MIO_BUS.counter_out + Multi_8CH32.data3 |
| `Cpu_data4bus[31:0]`| 32   | MIO_BUS.Cpu_data4bus → dm_ctrl.Data_read_from_dm + Multi_8CH32.data6 |

# 单周期 CPU SoC 系统接口文档

> 基于 schematic (1).pdf —— Nexys4 A7-100T (xc7a100tcsg324-1)
> 最后更新：2026-07-06

## 1. 系统架构总览

```
                         clk (100MHz)
                              │
                    ┌─────clk_div──────┐
                    │                  │
                 Clk_CPU          clkdiv[31:0]
                    │                  │
              ┌─────┴──────────────┐   ├──→ clkdiv[0]  → SSeg7.SW0
              │                    │   ├──→ clkdiv[10] → SSeg7.flash
            SCPU              Counter_x ← clkdiv[25], clkdiv[28], clkdiv[30]
           ┌──┴──┐               │
           │     │          counter0/1/2_OUT → SCPU.INT, MIO_BUS
           │     │               │
        ROM_D   MIO_BUS ────────┤
           │     │   │          │
           │     │   ├─ RAM_B ──┤
           │     │   │     │    │
           │     │   │  dm_controller
           │     │   │     │
           │     │   ├─ SPIO ── led[15:0] → 板子
           │     │   ├─ Counter_x
           │     │   └─ Enter ← BTN[4:0], SW[15:0]
           │     │
           │     └──→ Multi_8CH32 ──→ SSeg7 ──→ 数码管
           │
           ├──→ Multi_8CH32 (PC_out, Addr_out, Data_out)
           └──→ dm_controller (mem_w, Addr_in, dm_ctrl)
```

**核心设计思想**：Memory-Mapped I/O —— CPU 通过 MIO_BUS 用地址空间区分访问目标（RAM / LED / 开关 / 计数器），对 CPU 而言所有外设都像读写内存一样操作。

---

## 2. 顶层模块端口（soc_top.v）

| 端口 | 方向 | 位宽 | 连接目标 | 说明 |
|------|------|------|----------|------|
| `clk` | input | 1 | 板子 E3 (100MHz) | 系统时钟 |
| `rstn` | input | 1 | 板子 C12 (btnC) | 复位，低有效 |
| `btn_i[4:0]` | input | 5 | 板子按键 | 5 个按钮 |
| `sw_i[15:0]` | input | 16 | 板子拨码开关 | 16 个开关 |
| `disp_an_o[7:0]` | output | 8 | 板子 AN0-AN7 | 数码管位选 |
| `disp_seg_o[7:0]` | output | 8 | 板子 CA-CG,DP | 数码管段码 |
| `led_o[15:0]` | output | 16 | 板子 LED0-LED15 | LED 输出 |

---

## 3. 模块接口与连接表

### 3.1 SCPU — 单周期 CPU（老师黑盒 .edf）

| 端口 | 方向 | 位宽 | 连接目标 | 说明 |
|------|------|------|----------|------|
| `clk` | input | 1 | clk_div.Clk_CPU | CPU 工作时钟 |
| `reset` | input | 1 | ~rstn | 高有效复位 |
| `MIO_ready` | input | 1 | SCPU.CPU_MIO（自环） | [已知问题] 自己输出给自己 |
| `inst_in` | input | 32 | ROM_D.spo | 取指 |
| `Data_in` | input | 32 | dm_controller.Data_read | Load 数据 |
| `INT` | input | 1 | Counter_x.counter0_OUT | 中断信号 |
| `mem_w` | output | 1 | MIO_BUS.mem_w + dm_controller.mem_w | 写使能（扇出两路） |
| `PC_out` | output | 32 | ROM_D.a(PC[11:2]) + MIO_BUS.PC + Multi_8CH32.data7 | PC（扇出三路） |
| `Addr_out` | output | 32 | MIO_BUS.addr_bus + dm_controller.Addr_in + Multi_8CH32.data4 | 访存地址（扇出三路） |
| `Data_out` | output | 32 | MIO_BUS.Cpu_data2bus + Multi_8CH32.data5 | 写数据（扇出两路） |
| `dm_ctrl` | output | 3 | dm_controller.dm_ctrl | 访存类型 |
| `CPU_MIO` | output | 1 | SCPU.MIO_ready（自环） | [已知问题] CPU MIO 握手 |

---

### 3.2 ROM_D — 指令存储器（Vivado Block ROM IP）

| 端口 | 方向 | 位宽 | 连接目标 | 说明 |
|------|------|------|----------|------|
| `a[9:0]` | input | 10 | SCPU.PC_out[11:2] | 字地址（PC 右移 2 位） |
| `spo[31:0]` | output | 32 | SCPU.inst_in + Multi_8CH32.data2 | 指令（扇出两路） |

> ROM 规格：1024 × 32-bit = 4KB，.coe 初始化

---

### 3.3 RAM_B — 数据存储器（Vivado Block RAM IP）

| 端口 | 方向 | 位宽 | 连接目标 | 说明 |
|------|------|------|----------|------|
| `addra[9:0]` | input | 10 | MIO_BUS.ram_addr[9:0] | 字地址 |
| `dina[31:0]` | input | 32 | dm_controller.Data_write_to_dm | 写数据 |
| `douta[31:0]` | output | 32 | MIO_BUS.ram_data_out | 读数据 |
| `wea[3:0]` | input | 4 | dm_controller.wea_mem[3:0] | 字节写使能 |

> RAM 规格：1024 × 32-bit = 4KB

---

### 3.4 dm_controller — 数据存储器访问控制器（.edf 黑盒）

| 端口 | 方向 | 位宽 | 连接目标 | 说明 |
|------|------|------|----------|------|
| `mem_w` | input | 1 | SCPU.mem_w | 写使能 |
| `Addr_in[31:0]` | input | 32 | SCPU.Addr_out | 访存地址 |
| `Data_write[31:0]` | input | 32 | MIO_BUS.ram_data_in | 写数据（经 MIO_BUS 中转） |
| `dm_ctrl[2:0]` | input | 3 | SCPU.dm_ctrl | 访存类型编码 |
| `Data_read_from_dm[31:0]` | input | 32 | MIO_BUS.Cpu_data4bus | RAM 原始数据（经 MIO_BUS 中转） |
| `Data_read[31:0]` | output | 32 | SCPU.Data_in + Multi_8CH32.data6 + MIO_BUS.Cpu_data4bus | Load 数据（扇出三路） |
| `Data_write_to_dm[31:0]` | output | 32 | RAM_B.dina | 写入 RAM 的数据 |
| `wea_mem[3:0]` | output | 4 | RAM_B.wea | 字节写使能 |

**dm_ctrl 编码**：

| 值 | 含义 |
|----|------|
| `3'b000` | word (32-bit) |
| `3'b001` | halfword signed (16-bit) |
| `3'b010` | halfword unsigned |
| `3'b011` | byte signed (8-bit) |
| `3'b100` | byte unsigned |

---

### 3.5 MIO_BUS — 存储器映射 IO 总线（.edf 黑盒）

**核心功能**：根据 `addr_bus` 的地址空间，将 CPU 的访存请求路由到对应设备。

| 端口 | 方向 | 位宽 | 连接目标 | 说明 |
|------|------|------|----------|------|
| `clk` | input | 1 | clk_div.Clk_CPU | 总线时钟 |
| `rst` | input | 1 | ~rstn | 复位 |
| `BTN[4:0]` | input | 5 | Enter.BTN_out | 按键状态 |
| `SW[15:0]` | input | 16 | Enter.SW_out | 拨码开关状态 |
| `PC[31:0]` | input | 32 | SCPU.PC_out | PC 值 |
| `mem_w` | input | 1 | SCPU.mem_w | 写使能 |
| `Cpu_data2bus[31:0]` | input | 32 | SCPU.Data_out | CPU 发出的写数据 |
| `addr_bus[31:0]` | input | 32 | SCPU.Addr_out | CPU 发出的地址 |
| `ram_data_out[31:0]` | input | 32 | RAM_B.douta | RAM 读出的原始数据 |
| `led_out[15:0]` | input | 16 | SPIO.LED_out | LED 状态反馈 |
| `counter_out[31:0]` | input | 32 | Counter_x.counter_out | 计数器值 |
| `counter0_out` | input | 1 | Counter_x.counter0_OUT | 计数器0溢出 |
| `counter1_out` | input | 1 | Counter_x.counter1_OUT | 计数器1溢出 |
| `counter2_out` | input | 1 | Counter_x.counter2_OUT | 计数器2溢出 |
| `Cpu_data4bus[31:0]` | output | 32 | dm_controller.Data_read_from_dm | 送回 CPU 的数据 |
| `ram_data_in[31:0]` | output | 32 | dm_controller.Data_write | 写入 RAM 的数据 |
| `ram_addr[9:0]` | output | 10 | RAM_B.addra | RAM 字地址 |
| `data_ram_we` | output | 1 | wea_mio（中间信号） | RAM 写使能 |
| `GPIOf0000000_we` | output | 1 | SPIO.EN（GPIOFO） | LED 写使能 |
| `GPIOe0000000_we` | output | 1 | Multi_8CH32.EN（GPIOEO） | 数码管使能 |
| `counter_we` | output | 1 | Counter_x.counter_we | 计数器写使能 |
| `Peripheral_in[31:0]` | output | 32 | Multi_8CH32.data0 + SPIO.P_Data + Counter_x.counter_val | 外设数据（扇出三路，中间信号 CPU2IO） |

---

### 3.6 clk_div — 时钟分频器

| 端口 | 方向 | 位宽 | 连接目标 | 说明 |
|------|------|------|----------|------|
| `clk` | input | 1 | 板子 clk (100MHz) | 系统时钟 |
| `rst` | input | 1 | ~rstn | 复位 |
| `SW2` | input | 1 | SW_OK[2]（Enter 消抖后） | 频率选择 |
| `clkdiv[31:0]` | output | 32 | Counter_x(clk0/1/2: bit25/28/30) + SSeg7.SW0(bit0) + SSeg7.flash(bit10) + Multi_8CH32.point_in({div,div}) | 分频计数 |
| `Clk_CPU` | output | 1 | SCPU.clk + MIO_BUS.clk + Counter_x.clk + SPIO.clk + Multi_8CH32.clk | CPU 时钟 |

**频率计算**：`Clk_CPU = SW_OK[2] ? clkdiv[24] : clkdiv[3]`

| SW2 | 频率 | 用途 |
|-----|------|------|
| 0（高频）| ~6.25MHz | 正常运行 |
| 1（低频）| ~2.98Hz | 慢速调试 |

**clkdiv 其他位用途**：

| clkdiv 位 | 连接目标 | 用途 |
|-----------|----------|------|
| bit 0 | SSeg7.SW0 | 显示模式自动切换 |
| bit 10 | SSeg7.flash | 闪烁控制 |
| bit 25 | Counter_x.clk0 | 计数器0时钟 |
| bit 28 | Counter_x.clk1 | 计数器1时钟 |
| bit 30 | Counter_x.clk2 | 计数器2时钟 |
| 全 32 位 | Multi_8CH32.point_in({div,div}) | 小数点控制 |

---

### 3.7 Counter_x — 3 通道计数器/定时器

| 端口 | 方向 | 位宽 | 连接目标 | 说明 |
|------|------|------|----------|------|
| `clk` | input | 1 | clk_div.Clk_CPU | 系统时钟 |
| `rst` | input | 1 | ~rstn | 复位 |
| `clk0` | input | 1 | clk_div.clkdiv[25] | 计数器0时钟 |
| `clk1` | input | 1 | clk_div.clkdiv[28] | 计数器1时钟 |
| `clk2` | input | 1 | clk_div.clkdiv[30] | 计数器2时钟 |
| `counter_we` | input | 1 | MIO_BUS.counter_we | 写使能 |
| `counter_val[31:0]` | input | 32 | CPU2IO (MIO_BUS.Peripheral_in) | 计数器初值 |
| `counter_ch[1:0]` | input | 2 | SPIO.counter_set | 通道选择 |
| `counter0_OUT` | output | 1 | SCPU.INT + MIO_BUS.counter0_out | 通道0溢出 |
| `counter1_OUT` | output | 1 | MIO_BUS.counter1_out | 通道1溢出 |
| `counter2_OUT` | output | 1 | MIO_BUS.counter2_out | 通道2溢出 |
| `counter_out[31:0]` | output | 32 | MIO_BUS.counter_out + Multi_8CH32.data3 | 计数器当前值 |

---

### 3.8 SPIO — LED 外设控制器（.edf 黑盒）

| 端口 | 方向 | 位宽 | 连接目标 | 说明 |
|------|------|------|----------|------|
| `clk` | input | 1 | clk_div.Clk_CPU | 时钟 |
| `rst` | input | 1 | ~rstn | 复位 |
| `EN` | input | 1 | MIO_BUS.GPIOf0000000_we (GPIOFO) | 写使能 |
| `P_Data[31:0]` | input | 32 | CPU2IO (MIO_BUS.Peripheral_in) | LED 数据 |
| `counter_set[1:0]` | output | 2 | Counter_x.counter_ch | 计数器通道选择 |
| `LED_out[15:0]` | output | 16 | MIO_BUS.led_out | LED 状态反馈 |
| `led[15:0]` | output | 16 | 板子 led_o[15:0] | LED 输出（led[7:5] 经 IBUF，其余直连） |
| `GPIOf0[13:0]` | output | 14 | 悬空 | GPIO（预留） |

---

### 3.9 Enter — 按键/开关输入

| 端口 | 方向 | 位宽 | 连接目标 | 说明 |
|------|------|------|----------|------|
| `clk` | input | 1 | 板子 clk (100MHz 直连) | 系统时钟 |
| `BTN[4:0]` | input | 5 | 板子 btn_i（经 IBUF） | 按键输入 |
| `SW[15:0]` | input | 16 | 板子 sw_i（经 IBUF） | 拨码开关 |
| `BTN_out[4:0]` | output | 5 | MIO_BUS.BTN (BTN_OK) | 消抖后按键 |
| `SW_out[15:0]` | output | 16 | MIO_BUS.SW (SW_OK) | 消抖后开关 |

> ⚠️ 内部 `// TODO 防抖` — 按键消抖待实现

---

### 3.10 Multi_8CH32 — 8 通道 32 位显示多路选择器（.edf 黑盒）

| 端口 | 方向 | 位宽 | 连接目标 | 说明 |
|------|------|------|----------|------|
| `clk` | input | 1 | clk_div.Clk_CPU (I0_clk) | 时钟 |
| `rst` | input | 1 | ~rstn | 复位 |
| `EN` | input | 1 | MIO_BUS.GPIOe0000000_we (GPIOEO) | 使能 |
| `Switch[2:0]` | input | 3 | SW_OK[7:5] | 通道选择 |
| `point_in[63:0]` | input | 64 | {clkdiv[31:0], clkdiv[31:0]} | [已知问题] 32→64 位宽不匹配，当前复制拼接 |
| `LES[63:0]` | input | 64 | 64'h0000_0000_0000_0000（接地） | 亮度控制 |
| **8 路数据** | | | | |
| `data0[31:0]` | input | 32 | CPU2IO (MIO_BUS.Peripheral_in) | 外设数据 |
| `data1[31:0]` | input | 32 | {2'b0, PC[31:2]} | PC 字地址 |
| `data2[31:0]` | input | 32 | ROM_D.spo (inst_in) | 当前指令 |
| `data3[31:0]` | input | 32 | Counter_x.counter_out | 计数器值 |
| `data4[31:0]` | input | 32 | SCPU.Addr_out | ALU 地址 |
| `data5[31:0]` | input | 32 | SCPU.Data_out | 写数据 |
| `data6[31:0]` | input | 32 | dm_controller.Data_read (Data_in) | Load 数据 |
| `data7[31:0]` | input | 32 | SCPU.PC_out (PC) | PC 完整值 |
| **输出** | | | | |
| `point_out[7:0]` | output | 8 | SSeg7.point | 小数点 |
| `LE_out[7:0]` | output | 8 | SSeg7.LES | 亮度 |
| `Disp_num[31:0]` | output | 32 | SSeg7.Hexs | 显示数据 |

**Switch[7:5] 通道映射**：

| SW[7:5] | 数据源 | 显示内容 |
|---------|--------|---------|
| 000 | data0 | 外设数据 (CPU2IO) |
| 001 | data1 | PC 字地址 |
| 010 | data2 | 当前指令 (inst_in) |
| 011 | data3 | 计数器值 |
| 100 | data4 | ALU 地址 (Addr_out) |
| 101 | data5 | 写数据 (Data_out) |
| 110 | data6 | Load 数据 (Data_in) |
| 111 | data7 | PC 完整值 |

---

### 3.11 SSeg7 — 7 段数码管驱动（.edf 黑盒）

| 端口 | 方向 | 位宽 | 连接目标 | 说明 |
|------|------|------|----------|------|
| `clk` | input | 1 | clk_div.clkdiv[?]（待确认具体位） | 扫描时钟 |
| `rst` | input | 1 | ~rstn | 复位 |
| `SW0` | input | 1 | clk_div.clkdiv[0] | 显示模式切换（自动翻转） |
| `flash` | input | 1 | clk_div.clkdiv[10] | 闪烁控制 |
| `Hexs[31:0]` | input | 32 | Multi_8CH32.Disp_num | 32-bit 显示数据 |
| `point[7:0]` | input | 8 | Multi_8CH32.point_out | 小数点 |
| `LES[7:0]` | input | 8 | Multi_8CH32.LE_out | 亮度 |
| `seg_an[7:0]` | output | 8 | 板子 disp_an_o[7:0] | 位选（低有效） |
| `seg_sout[7:0]` | output | 8 | 板子 disp_seg_o[7:0] | 段码（低有效） |

---

## 4. 信号扇出汇总

| 信号来源 | 扇出目标 |
|----------|---------|
| **SCPU.PC_out** | ROM_D.a(PC[11:2]), MIO_BUS.PC, Multi_8CH32.data7 |
| **SCPU.Addr_out** | MIO_BUS.addr_bus, dm_controller.Addr_in, Multi_8CH32.data4 |
| **SCPU.Data_out** | MIO_BUS.Cpu_data2bus, Multi_8CH32.data5 |
| **SCPU.mem_w** | MIO_BUS.mem_w, dm_controller.mem_w |
| **dm_controller.Data_read** | SCPU.Data_in, Multi_8CH32.data6, MIO_BUS.Cpu_data4bus |
| **MIO_BUS.Peripheral_in (CPU2IO)** | Multi_8CH32.data0, SPIO.P_Data, Counter_x.counter_val |
| **Counter_x.counter0_OUT** | SCPU.INT, MIO_BUS.counter0_out |
| **ROM_D.spo (inst_in)** | SCPU.inst_in, Multi_8CH32.data2 |
| **clk_div.Clk_CPU** | SCPU.clk, MIO_BUS.clk, Counter_x.clk, SPIO.clk, Multi_8CH32.clk |
| **clk_div.clkdiv** | Counter_x.clk0/1/2, SSeg7.SW0, SSeg7.flash, Multi_8CH32.point_in |
| **Counter_x.counter_out** | MIO_BUS.counter_out, Multi_8CH32.data3 |
| **SPIO.LED_out** | MIO_BUS.led_out |

---

## 5. 已知问题

| # | 问题 | 描述 | 处理方式 |
|---|------|------|----------|
| 1 | **point_in 位宽不匹配** | Multi_8CH32.point_in 是 64bit，clkdiv 是 32bit。当前 `{clkdiv, clkdiv}` 复制拼接 | 照图连接 |
| 2 | **data_ram_we 去向** | MIO_BUS.data_ram_we → wea_mio（中间信号），最终连接待确认 | 先定义 wea_mio wire |
| 3 | **SSeg7.clk 来源** | 图中 SSeg7 的 clk 输入从 clkdiv 哪一位取？ | 待确认 |
| 4 | **Enter 按键消抖** | Enter.v 内 `TODO 防抖` 未实现 | 后续实现 |

---

## 6. 时钟树

```
板子 clk (100MHz, pin E3)
    │
    ├── Enter.clk (100MHz 直连)
    │
    └── clk_div.clk
            │
            ├── Clk_CPU ─── SCPU.clk, MIO_BUS.clk, Counter_x.clk, SPIO.clk, Multi_8CH32.clk
            │
            ├── clkdiv[0]  ─── SSeg7.SW0
            ├── clkdiv[10] ─── SSeg7.flash
            ├── clkdiv[25] ─── Counter_x.clk0
            ├── clkdiv[28] ─── Counter_x.clk1
            ├── clkdiv[30] ─── Counter_x.clk2
            ├── clkdiv[?]  ─── SSeg7.clk（扫描时钟，待确认）
            └── clkdiv[31:0] ─── Multi_8CH32.point_in ({div, div})
```

---

## 7. 复位树

```
板子 rstn (btnC, pin C12, 低有效)
    │
    └── ~rstn (取反 → 高有效复位)
            │
            ├── SCPU.reset
            ├── MIO_BUS.rst
            ├── clk_div.rst
            ├── Counter_x.rst
            ├── SPIO.rst
            ├── Multi_8CH32.rst
            └── SSeg7.rst
```

---

## 8. 中间信号命名对照

顶层模块内部需要定义的中间 wire 信号：

| 中间信号名 | 位宽 | 说明 |
|-----------|------|------|
| `rst` | 1 | `~rstn`，全局高有效复位 |
| `BTN_OK[4:0]` | 5 | Enter 消抖后按键 → MIO_BUS.BTN |
| `SW_OK[15:0]` | 16 | Enter 消抖后开关 → MIO_BUS.SW + clk_div.SW2 |
| `inst_in[31:0]` | 32 | ROM_D.spo → SCPU.inst_in + Multi_8CH32.data2 |
| `Data_in[31:0]` | 32 | dm_controller.Data_read → SCPU.Data_in + Multi_8CH32.data6 + MIO_BUS.Cpu_data4bus |
| `Data_out[31:0]` | 32 | SCPU.Data_out → MIO_BUS.Cpu_data2bus + Multi_8CH32.data5 |
| `Addr_out[31:0]` | 32 | SCPU.Addr_out → MIO_BUS.addr_bus + dm_controller.Addr_in + Multi_8CH32.data4 |
| `PC[31:0]` | 32 | SCPU.PC_out → ROM_D.a + MIO_BUS.PC + Multi_8CH32.data7 |
| `douta[31:0]` | 32 | RAM_B.douta → MIO_BUS.ram_data_out |
| `dina[31:0]` | 32 | dm_controller.Data_write_to_dm → RAM_B.dina |
| `wea_mem[3:0]` | 4 | dm_controller.wea_mem → RAM_B.wea |
| `CPU2IO[31:0]` | 32 | MIO_BUS.Peripheral_in → Multi_8CH32.data0 + SPIO.P_Data + Counter_x.counter_val |
| `GPIOFO` | 1 | MIO_BUS.GPIOf0000000_we → SPIO.EN |
| `GPIOEO` | 1 | MIO_BUS.GPIOe0000000_we → Multi_8CH32.EN |
| `counter_out[31:0]` | 32 | Counter_x.counter_out → MIO_BUS.counter_out + Multi_8CH32.data3 |
| `wea_mio` | 1 | MIO_BUS.data_ram_we → ?（待确认） |

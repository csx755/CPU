## Pmod Header JA — 音频 PWM 输出
## 蜂鸣器正极接 JA[1]，负极接 JA[GND]
set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { audio_out }]; # IO_L20N_T3_A19_VREF_15 Sch=ja[1]

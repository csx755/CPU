/**
 * PS2 键盘钢琴
 *
 * 按键映射：
 *   1=C4  2=D4  3=E4  4=F4  5=G4
 *   6=A4  7=B4  8=C5  9=D5  0=E5
 *   松开 → 静音
 *
 * 硬件：
 *   PS2 键盘 → 中断 → 写频率到 0xB0000000 → PWM 蜂鸣器出声
 *   LED 显示当前按下的键（1~10）
 */

#define LED_BASE  0xF0000000
#define PS2_BASE  0xD0000000
#define TONE_BASE 0xB0000000

#define ecall() __asm__ volatile ("ecall")

/* 频率控制字（100MHz 时钟，半周期计数值） */
#define FREQ_C4  191106   /* 261.63 Hz */
#define FREQ_D4  170294   /* 293.66 Hz */
#define FREQ_E4  151686   /* 329.63 Hz */
#define FREQ_F4  143168   /* 349.23 Hz */
#define FREQ_G4  127551   /* 392.00 Hz */
#define FREQ_A4  113636   /* 440.00 Hz */
#define FREQ_B4  101240   /* 493.88 Hz */
#define FREQ_C5   95554   /* 523.25 Hz */
#define FREQ_D5   85147   /* 587.33 Hz */
#define FREQ_E5   75842   /* 659.25 Hz */

/* 扫描码 → 频率控制字 */
unsigned int scancode_to_freq(unsigned int code) {
    switch (code) {
        case 0x16: return FREQ_C4;  /* 1 */
        case 0x1E: return FREQ_D4;  /* 2 */
        case 0x26: return FREQ_E4;  /* 3 */
        case 0x25: return FREQ_F4;  /* 4 */
        case 0x2E: return FREQ_G4;  /* 5 */
        case 0x36: return FREQ_A4;  /* 6 */
        case 0x3D: return FREQ_B4;  /* 7 */
        case 0x3E: return FREQ_C5;  /* 8 */
        case 0x46: return FREQ_D5;  /* 9 */
        case 0x45: return FREQ_E5;  /* 0 */
        default:   return 0;        /* 静音 */
    }
}

/* 扫描码 → LED 显示（第 N 位亮） */
unsigned int scancode_to_led(unsigned int code) {
    switch (code) {
        case 0x16: return 0x0001;  /* 1 → LED0 */
        case 0x1E: return 0x0002;  /* 2 → LED1 */
        case 0x26: return 0x0004;  /* 3 → LED2 */
        case 0x25: return 0x0008;  /* 4 → LED3 */
        case 0x2E: return 0x0010;  /* 5 → LED4 */
        case 0x36: return 0x0020;  /* 6 → LED5 */
        case 0x3D: return 0x0040;  /* 7 → LED6 */
        case 0x3E: return 0x0080;  /* 8 → LED7 */
        case 0x46: return 0x0100;  /* 9 → LED8 */
        case 0x45: return 0x0200;  /* 0 → LED9 */
        default:   return 0;
    }
}

void interrupt_handler(void) {
    volatile unsigned int *led  = (volatile unsigned int *)LED_BASE;
    volatile unsigned int *ps2  = (volatile unsigned int *)PS2_BASE;
    volatile unsigned int *tone = (volatile unsigned int *)TONE_BASE;

    unsigned int code = *ps2 & 0xFF;

    /* 0xF0 = 松开前缀，下一个字节才是释放码。
       简化处理：收到 0xF0 就静音，不等下一个字节 */
    if (code == 0xF0) {
        *tone = 0;       /* 静音 */
        *led  = 0;
    } else {
        *tone = scancode_to_freq(code);  /* 发声 */
        *led  = scancode_to_led(code);   /* 亮灯 */
    }
}

int main(void) {
    volatile unsigned int *led  = (volatile unsigned int *)LED_BASE;
    volatile unsigned int *tone = (volatile unsigned int *)TONE_BASE;

    *led  = 0x0001;
    *tone = 0;

    ecall();

    while (1) {
        __asm__ volatile ("nop");
    }
}

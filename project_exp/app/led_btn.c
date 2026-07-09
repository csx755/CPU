#pragma GCC push_options
#pragma GCC optimize ("O0")
__attribute__((section(".text.start")))
void start() {
  asm("li sp, 1024\n\t"
      "call main");
}
#pragma GCC pop_options

// 地址宏定义
#define LED_BASE    0xF0000000
#define SEG7_BASE   0xE0000000
#define SW_BTN_BASE 0xE0000000

// 按键位定义（对应 Nexys A7 的 5 个按钮）
// 读 0xE0000000 返回 {11'b0, BTN[4:0], SW[15:0]}
//   btn[0] = UP     btn[1] = RIGHT
//   btn[2] = DOWN   btn[3] = LEFT
//   btn[4] = CENTER
#define BTN_CENTER  0x10
#define BTN_UP      0x01
#define BTN_DOWN    0x04
#define BTN_LEFT    0x08
#define BTN_RIGHT   0x02

// 简单延时
__attribute__((noinline)) void delay(int n) {
    volatile int i;
    for (i = 0; i < n; i++);
}

void main() {
    volatile unsigned int *led    = (unsigned int *)LED_BASE;
    volatile unsigned int *seg7   = (unsigned int *)SEG7_BASE;
    volatile unsigned int *sw_btn = (unsigned int *)SW_BTN_BASE;

    unsigned int last_btn = 0;
    unsigned char digit = 0;       // 数码管计数器
    unsigned char led_mode = 0;    // LED 模式: 0=开关直通, 1=流水灯

    while (1) {
        // 读取开关和按键
        unsigned int val = *sw_btn;
        unsigned int sw  = val & 0x7FFF;       // 低15位: 开关
        unsigned int btn = (val >> 16) & 0x1F; // [20:16]: 5个按键

        // === 按键上升沿检测 ===
        unsigned int pressed = btn & (~last_btn); // 新按下的键

        if (pressed) {
            // CENTER: 计数器 +1
            if (pressed & BTN_CENTER) {
                digit = (digit + 1) & 0xFF;
            }
            // UP: 计数器 -1
            if (pressed & BTN_UP) {
                digit = (digit - 1) & 0xFF;
            }
            // DOWN: 计数器归零
            if (pressed & BTN_DOWN) {
                digit = 0;
            }
            // LEFT: LED 模式切换（开关直通 / 流水灯）
            if (pressed & BTN_LEFT) {
                led_mode = led_mode ^ 1;
            }
        }

        // === LED 输出 ===
        // 硬件 bit[1:0] 未接 LED，所有写入统一 +2 对齐
        if (led_mode == 0) {
            // 模式0: 开关直通，左移2位
            *led = (sw << 2) & 0xFFFF;
        } else {
            // 模式1: 流水灯，16个灯循环
            *led = (1 << ((digit & 0x0F) + 2)) & 0xFFFF;
        }

        // === 数码管输出 ===
        // RIGHT 按下时：显示开关值（低8位）；否则显示计数器
        if (btn & BTN_RIGHT) {
            *seg7 = sw & 0xFF;
        } else {
            *seg7 = digit;
        }

        last_btn = btn;
        delay(50000);
    }
}

// ============================================================
// RISC-V 流水线 CPU 中断测试程序
// 目标: Nexys A7 (XC7A100T)
//
// 测试项目:
//   1. ecall 指令 (软件异常)
//   2. 定时器中断
//   3. 按键外部中断
//   4. 5 按键功能 (计数器 + LED 模式 + 数码管)
//
// 地址空间:
//   0xF0000000  LED 输出 (写)
//   0xE0000000  7-Segment (写) / {BTN,SW} (读)
//
// STATUS[7:0]:
//   bit0 = IE   全局中断使能
//   bit1 = IM0  定时器中断使能
//   bit2 = IM1  外部中断源0 使能 (按键)
//   bit3~7  = IM2~IM6 (预留)
// ============================================================

#pragma GCC push_options
#pragma GCC optimize ("O0")
__attribute__((section(".text.start")))
void start() {
    asm volatile(
        "li sp, 4096\n\t"
        "call main"
    );
}
#pragma GCC pop_options

// ---- 地址 ----
#define LED     (*(volatile unsigned int *)0xF0000000)
#define SEG7    (*(volatile unsigned int *)0xE0000000)
#define SW_BTN  (*(volatile unsigned int *)0xE0000000)

// ---- CSR 地址 ----
#define CSR_STATUS  0x100
#define CSR_INTMASK 0x101
#define CSR_SEPC    0x102
#define CSR_SCAUSE  0x103

// ---- 按键位定义 ----
#define BTN_CENTER  0x10
#define BTN_UP      0x01
#define BTN_RIGHT   0x02
#define BTN_DOWN    0x04
#define BTN_LEFT    0x08

// ---- 全局变量 (由中断 handler 修改) ----
volatile int g_timer_flag  = 0;
volatile int g_timer_count = 0;
volatile int g_btn_count   = 0;
volatile int g_ecall_count = 0;
volatile int g_last_btn    = 0;

// 共享给主循环使用的变量 (由按键 handler 更新, 用 int 保证 lw/sw 安全)
volatile int g_counter  = 0;
volatile int g_led_mode = 0;

// ---- CSR 工具函数 ----
static inline void csr_write(unsigned int addr, unsigned int val) {
    asm volatile ("csrw %0, %1" :: "i"(addr), "r"(val));
}
static inline unsigned int csr_read(unsigned int addr) {
    unsigned int v;
    asm volatile ("csrr %0, %1" : "=r"(v) : "i"(addr));
    return v;
}

__attribute__((noinline)) void delay(int n) {
    volatile int i;
    for (i = 0; i < n; i++);
}

// ---- 简单数码管: 显示低 8 位 ----
static void show_hex(unsigned char val) {
    SEG7 = val;
}

// ============================================================
// 测试 1: ecall 指令
//   执行 ecall → 触发异常 → 硬件保存 SEPC=PC+4
//   handler 更新 g_ecall_count, eret 返回
// ============================================================
static void test_ecall(void) {
    csr_write(CSR_STATUS, 0x00);       // 先禁中断
    csr_write(CSR_INTMASK, 0xFF);      // 屏蔽所有

    asm volatile ("ecall");

    // 能到这里说明 ecall 正确返回
}

// ============================================================
// 测试 2: 按键外部中断
//   使能按键中断后, 等待任意按键按下
// ============================================================
static void test_btn_interrupt(void) {
    csr_write(CSR_STATUS, 0x04 | 0x01); // IE=1, IM1=1 (外部中断源0)
    csr_write(CSR_INTMASK, 0x00);

    int old = g_btn_count;
    int timeout = 5000000;
    while (g_btn_count == old && timeout > 0) timeout--;
}

// ============================================================
// 测试 3: 定时器中断
//   使能定时器中断, 等待 counter0 下溢触发
// ============================================================
static void test_timer_interrupt(void) {
    csr_write(CSR_STATUS, 0x02 | 0x01); // IE=1, IM0=1 (定时器)
    csr_write(CSR_INTMASK, 0x00);

    int old = g_timer_count;
    int timeout = 5000000;
    while (g_timer_count == old && timeout > 0) timeout--;
}

// ============================================================
// 主函数
// ============================================================
void main(void) {
    // 初始化: 禁用所有中断
    csr_write(CSR_STATUS, 0x00);
    csr_write(CSR_INTMASK, 0xFF);

    LED  = 0x0000;
    SEG7 = 0x00;

    // === 测试 1: ecall ===
    test_ecall();
    show_hex((unsigned char)g_ecall_count);
    delay(3000000);

    // === 测试 2: 按键中断 ===
    test_btn_interrupt();
    show_hex((unsigned char)g_btn_count);
    delay(3000000);

    // === 测试 3: 定时器中断 ===
    test_timer_interrupt();
    show_hex((unsigned char)g_timer_count);
    delay(3000000);

    // === 使能所有中断, 进入主循环 ===
    // IE=1, IM0=1(定时器), IM1=1(按键)
    csr_write(CSR_STATUS, 0x01 | 0x02 | 0x04);
    csr_write(CSR_INTMASK, 0x00);

    unsigned char last_counter = 0;
    unsigned char last_led_mode = 0;

    while (1) {
        // 读取开关
        unsigned int val = SW_BTN;
        unsigned int sw  = val & 0x7FFF;
        unsigned int btn = (val >> 16) & 0x1F;

        int counter  = g_counter;
        int led_mode = g_led_mode;

        // === LED 输出 ===
        if (led_mode == 0) {
            // 模式0: 拨开关直接控制 LED (左移2位对齐)
            LED = (sw << 2) & 0xFFFF;
        } else {
            // 模式1: 流水灯, counter 值决定哪个灯亮
            LED = (1 << ((counter & 0x0F) + 2)) & 0xFFFF;
        }

        // === 数码管输出 ===
        // RIGHT 按下时: 显示开关低8位; 否则显示计数器
        if (btn & BTN_RIGHT) {
            SEG7 = sw & 0xFF;
        } else {
            SEG7 = counter;
        }

        delay(50000);
    }
}

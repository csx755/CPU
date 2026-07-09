// ============================================================
// RISC-V 流水线 CPU 中断测试程序
// 目标: Nexys A7 (XC7A100T)
//
// 测试项目:
//   1. ecall 指令 (软件异常)
//   2. 定时器中断
//   3. 按键外部中断
//
// 地址空间:
//   0xF0000000  LED 输出 (写) / LED 寄存器回读 (读)
//   0xE0000000  7-Segment (写) / {BTN,SW} (读)
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
volatile int g_btn_press   = 0;
volatile int g_btn_count   = 0;
volatile int g_ecall_count = 0;

// ---- 工具函数 ----
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

// ---- 数码管显示: 把低8位显示为2位十六进制 ----
static void show_hex(unsigned char val) {
    SEG7 = val;
}

// ============================================================
// 测试 1: ecall 指令
//   执行 ecall → 触发异常 → handler 保存 SEPC
//   handler 会将 SEPC+4 写回 SEPC, 使 eret 跳过 ecall
//   返回后 g_ecall_count++ 证明 ecall 正确返回
// ============================================================
static void test_ecall(void) {
    // 先禁中断, 避免干扰
    csr_write(CSR_STATUS, 0x00);

    // 执行 ecall → handler_ecall 会 SEPC+=4 并更新 g_ecall_count
    asm volatile ("ecall");

    // 返回到这里说明 ecall 正确处理并返回
}

// ============================================================
// 测试 2: 按键外部中断
//   使能按键中断后, 按任意键触发中断
//   handler 读取按键并更新 g_btn_count
// ============================================================
static void test_btn_interrupt(void) {
    // 使能: 全局 IE=1, 外部中断源0 (bit2) 使能
    // STATUS: bit0=IE, bit1=IM[0]=timer, bit2=IM[1]=ext0
    unsigned int status = 0x01;       // IE=1
    status |= (1 << 2);              // 使能外部中断源0 (按键)
    csr_write(CSR_STATUS, status);
    csr_write(CSR_INTMASK, 0x00);    // 不屏蔽任何中断

    // 等待按键按下
    int old_count = g_btn_count;
    int timeout = 5000000;
    while (g_btn_count == old_count && timeout > 0) {
        timeout--;
    }
}

// ============================================================
// 测试 3: 定时器中断
//   Counter_x 模块复位后 counter0 从 0 递减 → 立即下溢
//   counter0_OUT 变高 → 只要使能定时器中断就会立刻触发
//   handler 翻转 g_timer_flag 并闪烁 LED
// ============================================================
static void test_timer_interrupt(void) {
    // 先关闭所有中断
    csr_write(CSR_STATUS, 0x00);

    // 恢复 LED 显示
    LED = 0x0000;

    // 使能定时器中断: STATUS bit0=IE=1, bit1=IM[0]=1
    unsigned int status = 0x01 | (1 << 1);
    csr_write(CSR_STATUS, status);
    csr_write(CSR_INTMASK, 0x00);

    // 等待定时器中断触发 (应该很快)
    int old_flag = g_timer_flag;
    int timeout = 5000000;
    while (g_timer_flag == old_flag && timeout > 0) {
        timeout--;
    }
}

// ============================================================
// 主函数
// ============================================================
void main(void) {
    // 初始化: 禁用所有中断
    csr_write(CSR_STATUS, 0x00);
    csr_write(CSR_INTMASK, 0xFF);   // 全部屏蔽

    LED  = 0x0000;
    SEG7 = 0x00;

    // === 测试 1: ecall ===
    test_ecall();
    // 用数码管显示 ecall 次数
    show_hex((unsigned char)g_ecall_count);
    delay(2000000);

    // === 测试 2: 按键中断 ===
    test_btn_interrupt();
    // 数码管显示按键中断次数
    show_hex((unsigned char)g_btn_count);
    delay(2000000);

    // === 测试 3: 定时器中断 ===
    test_timer_interrupt();
    // 数码管显示定时器中断翻转次数
    show_hex((unsigned char)g_timer_flag);
    delay(2000000);

    // === 主循环: 持续响应中断, LED 显示状态 ===
    // 使能所有中断
    unsigned int status = 0x01;            // IE=1
    status |= (1 << 1);                   // IM[0]=1 定时器
    status |= (1 << 2);                   // IM[1]=1 按键
    csr_write(CSR_STATUS, status);
    csr_write(CSR_INTMASK, 0x00);

    while (1) {
        // LED[0] = timer_flag, LED[1] = btn_count bit0
        unsigned int led_val = (g_timer_flag & 1) | ((g_btn_count & 1) << 1);
        led_val <<= 2;  // 对齐到 LED 硬件位
        LED = led_val;

        // 数码管交替显示 ecall 次数和按键次数
        static int mode = 0;
        if (g_btn_count != 0 || g_timer_flag != 0) {
            mode ^= 1;
        }
        if (mode == 0)
            show_hex((unsigned char)g_ecall_count);
        else
            show_hex((unsigned char)g_btn_count);

        delay(1000000);
    }
}

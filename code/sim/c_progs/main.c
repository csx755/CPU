/* main.c — 三中断验收: 定时器 + 按钮 + ECALL
 *
 * 中断区分: 读 COUNTER_STATUS(0xF0000018) 的 bit0 = counter0_OUT
 *   counter0_OUT=1 → 定时器中断 → reload counter
 *   counter0_OUT=0 → 按钮中断   → 无需 reload
 *
 * ECALL: mepc+=4 由 crt0.S trap_handler 处理, 这里只做业务逻辑
 *
 * SoC 外设:
 *   LED:           0xF0000000 (写)
 *   数码管:        0xE0000000 (写)
 *   Counter load:  0xF0000008 (写)
 *   Counter val:   0xF0000008 (读, 当前计数值)
 *   Counter status:0xF0000018 (读, bit0=counter0_OUT)
 *   SW:            0xF0000010 (读)
 *   BTN:           0xF0000014 (读)
 */

#define CSR_MSTATUS  0x300
#define CSR_MTVEC    0x305

#define LED_BASE       0xF0000000
#define SEG7_BASE      0xE0000000
#define COUNTER_ADDR   0xF0000008
#define COUNTER_STATUS 0xF0000018
#define SW_ADDR        0xF0000010
#define BTN_ADDR        0xF0000014

#define LED            (*(volatile unsigned int *)LED_BASE)
#define SEG7           (*(volatile unsigned int *)SEG7_BASE)
#define COUNTER        (*(volatile unsigned int *)COUNTER_ADDR)
#define CSTATUS        (*(volatile unsigned int *)COUNTER_STATUS)
#define SW             (*(volatile unsigned int *)SW_ADDR)
#define BTN            (*(volatile unsigned int *)BTN_ADDR)

#define csr_write(csr, val) \
    __asm__ volatile ("csrrw x0, %0, %1" :: "i"(csr), "r"(val) : "memory")
#define csr_read(csr, dst) \
    __asm__ volatile ("csrrw %0, %1, x0" : "=r"(dst) : "i"(csr))

extern unsigned int _trap_vector;

volatile unsigned int timer_count = 0;
volatile unsigned int btn_count   = 0;
volatile unsigned int ecall_count = 0;

// ==== 中断处理 ====
void c_interrupt_handler(void) {
    unsigned int mcause_val;
    csr_read(0x342, mcause_val);  // CSR_MCAUSE

    if (mcause_val == 0x8000000B) {
        // 读 counter 状态寄存器区分来源
        unsigned int st = CSTATUS;  // bit0 = counter0_OUT

        if (st & 0x1) {
            // === 定时器中断 ===
            timer_count++;
            LED = timer_count;
            SEG7 = timer_count & 0xFF;
            COUNTER = 800;   // reload (~1ms in sim)

        } else {
            // === 按钮中断 ===
            btn_count++;
            LED = (btn_count << 16) | BTN;
            SEG7 = btn_count & 0xFF;
            // 按钮中断不需要 reload counter
        }
    }
}

// ==== ECALL 处理 (mepc+=4 由 crt0.S 完成) ====
void c_ecall_handler(void) {
    ecall_count++;
    LED = (ecall_count << 16) | 0xEC00;
    SEG7 = 0xEC00 | (ecall_count & 0xFF);
}

// ==== 主程序 ====
int main(void) {
    // 1. 设置中断向量 (硬件 CSR 转发已修复, 无需 barrier)
    csr_write(CSR_MTVEC, (unsigned int)&_trap_vector);

    // 2. 启动定时器
    COUNTER = 80;  // ~100us (仿真), 下板改 78000

    // 3. 开中断
    csr_write(CSR_MSTATUS, 0x8);

    // 4. 初始显示
    LED  = 0xDEAD;
    SEG7 = 0x00000000;

    // 5. 主循环 — 用 led_state 避免与中断的读-改-写竞态
    volatile unsigned int led_state = 0xDEAD;
    unsigned int last_btn = 0;

    while (1) {
        unsigned int sw_val  = SW;
        unsigned int btn_val = BTN;

        // 按钮按下 → ECALL (演示特权中断)
        if (btn_val != 0 && last_btn == 0) {
            __asm__ volatile ("ecall");
        }
        last_btn = btn_val;

        // 主循环只改低 16 位; 高 16 位由中断维护
        led_state = (led_state & 0xFFFF0000) | (sw_val & 0xFFFF);
        LED = led_state;
        SEG7 = sw_val;
    }

    return 0;
}

/* main.c — 三中断验收: 定时器 + 按钮 + ECALL
 *
 * 中断区分: 读 COUNTER_STATUS(0xF0000018) 的 bit0 = counter0_OUT
 *   counter0_OUT=1 → 定时器中断 → reload COUTER
 *   counter0_OUT=0 → 按钮中断   → 无需 reload
 *
 * LED / SEG7 统一管理: 所有地方只改 led_state / seg7_state, 仅 main 写入硬件
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

extern unsigned int _trap_vector;

volatile unsigned int timer_count = 0;
volatile unsigned int btn_count   = 0;
volatile unsigned int ecall_count = 0;

// 全局状态: 中断 + main 共享, 仅 main 写入 LED/SEG7
volatile unsigned int led_state  = 0xDEAD;
volatile unsigned int seg7_state = 0;

// ==== 中断处理 ====
void c_interrupt_handler(void) {
    unsigned int mcause_val;
    __asm__ volatile ("csrrw %0, 0x342, x0" : "=r"(mcause_val));

    if (mcause_val == 0x8000000B) {
        if (CSTATUS & 0x1) {
            // === 定时器中断 ===
            timer_count++;
            led_state  = (led_state & 0xFFFF0000) | (timer_count & 0xFFFF);
            seg7_state = timer_count & 0xFFFF;
            COUNTER = 800;   // reload (~1ms sim)
        } else {
            // === 按钮中断 ===
            btn_count++;
            led_state  = ((btn_count & 0xFFFF) << 16) | (led_state & 0xFFFF);
            seg7_state = btn_count & 0xFFFF;
        }
    }
}

// ==== ECALL 处理 (mepc+=4 由 crt0.S 完成) ====
void c_ecall_handler(void) {
    ecall_count++;
    led_state  = ((ecall_count & 0xFFFF) << 16) | 0xEC00;
    seg7_state = 0xEC00 | (ecall_count & 0xFF);
}

// ==== 主程序 ====
int main(void) {
    csr_write(CSR_MTVEC, (unsigned int)&_trap_vector);
    COUNTER = 80;   // 仿真用, 下板改 78000
    csr_write(CSR_MSTATUS, 0x8);

    LED  = led_state;
    SEG7 = seg7_state;

    unsigned int last_btn = 0;

    while (1) {
        unsigned int sw_val  = SW;
        unsigned int btn_val = BTN;

        // 按钮按下 → ECALL (演示特权中断)
        if (btn_val != 0 && last_btn == 0) {
            __asm__ volatile ("ecall");
        }
        last_btn = btn_val;

        // 主循环更新低 16 位; 高 16 位由中断维护
        led_state  = (led_state & 0xFFFF0000) | (sw_val & 0xFFFF);
        LED        = led_state;
        SEG7       = seg7_state;
    }

    return 0;
}

/* main.c — 三中断下板验收
 *
 *  定时器: 自动周期触发 → LED 全亮 0xFFFFFFFF
 *  按钮:   BTN[0..3] 按下 → LED=0x000B000X (X=按钮编号)
 *  ECALL:  BTN[4] 按下 → LED=0xEEEEEEEE
 *
 * 下板: COUNTER 初值改为 80000 (~100ms), 仿真用 80
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

volatile unsigned int led_state  = 0x00000000;
volatile unsigned int seg7_state = 0;

// 中断/异常计数
volatile unsigned int timer_count = 0;
volatile unsigned int btn_count   = 0;
volatile unsigned int ecall_count = 0;

// ==== 中断处理 ====
void c_interrupt_handler(void) {
    unsigned int mcause_val;
    __asm__ volatile ("csrrw %0, 0x342, x0" : "=r"(mcause_val));

    if (mcause_val == 0x8000000B) {
        if (CSTATUS & 0x1) {
            // === 定时器中断 ===
            timer_count++;
            led_state  = 0xFFFFFFFF;          // 全亮
            seg7_state = timer_count & 0xFFFF;
            COUNTER = 800;                    // reload (下板改 80000)
        } else {
            // === 按钮中断: 显示按钮编号 ===
            unsigned int btn = BTN & 0x1F;    // 5 位按键
            btn_count++;
            led_state  = 0x000B0000 | btn;    // 0x000B000X
            seg7_state = btn;
            // 按钮不 reload timer
        }
    }
}

// ==== ECALL 处理 ====
void c_ecall_handler(void) {
    ecall_count++;
    led_state  = 0xEEEEEEEE;                  // ECALL 特征
    seg7_state = 0xEC00 | (ecall_count & 0xFF);
}

// ==== 主程序 ====
int main(void) {
    csr_write(CSR_MTVEC, (unsigned int)&_trap_vector);
    COUNTER = 80;   // 仿真用, 下板改 80000
    csr_write(CSR_MSTATUS, 0x8);

    LED  = led_state;
    SEG7 = seg7_state;

    unsigned int last_btn4 = 0;

    while (1) {
        unsigned int sw_val  = SW;
        unsigned int btn_val = BTN;

        // BTN[4] 按下 → ECALL (特权中断)
        if ((btn_val & 0x10) && !(last_btn4 & 0x10)) {
            __asm__ volatile ("ecall");
        }
        last_btn4 = btn_val;

        // 仅高 16 位全是 F 或 E 时, 被中断占据, 主循环不改
        // 否则低 16 位显示开关状态
        unsigned int hi = led_state >> 16;
        if (!(hi == 0xFFFF || hi == 0xEEEE || hi == 0x000B)) {
            led_state = (led_state & 0xFFFF0000) | (sw_val & 0xFFFF);
        }
        LED  = led_state;
        SEG7 = seg7_state;
    }

    return 0;
}

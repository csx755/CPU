/* main.c — 三中断下板验收
 *
 *  定时器: LED = 0xFFFFFFFF  (全亮)
 *  按钮 BTN[0..3]: LED = 0x00000001 ~ 0x00000004
 *  ECALL (BTN[4]): LED = 0xEEEEEEEE
 *
 *  display_lock: 中断显示保持, 不被主循环覆盖
 *  下板: COUNTER = 80000, 仿真 = 80
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

volatile unsigned int led_state     = 0x00000000;
volatile unsigned int seg7_state    = 0;
volatile unsigned int display_lock  = 0;   // >0 = 中断独占, 主循环不写

volatile unsigned int timer_count = 0;
volatile unsigned int btn_count   = 0;
volatile unsigned int ecall_count = 0;

// ==== 中断处理 ====
void c_interrupt_handler(void) {
    unsigned int mcause_val;
    __asm__ volatile ("csrrw %0, 0x342, x0" : "=r"(mcause_val));

    if (mcause_val == 0x8000000B) {
        // 读 counter 当前值区分: 接近 0 = 定时器到期; 否则 = 按钮
        if (COUNTER < 10) {
            // === 定时器中断 ===
            timer_count++;
            led_state    = 0xFFFFFFFF;
            seg7_state   = timer_count & 0xFFFF;
            display_lock = 5000;
            COUNTER = 800;                     // reload (下板改 80000)
        } else {
            // === 按钮中断: LED = 按钮编号 ===
            unsigned int btn = BTN & 0x0F;
            btn_count++;
            led_state    = btn;
            seg7_state   = btn;
            display_lock = 5000;
        }
    }
}

// ==== ECALL 处理 ====
void c_ecall_handler(void) {
    ecall_count++;
    led_state    = 0xEEEEEEEE;
    seg7_state   = 0xEC00 | (ecall_count & 0xFF);
    display_lock = 5000;                      // 倒计数, 保持约 5000 次循环
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

        // BTN[4] 按下 → ECALL
        if ((btn_val & 0x10) && !(last_btn4 & 0x10)) {
            __asm__ volatile ("ecall");
        }
        last_btn4 = btn_val;

        // 倒计数 display_lock, 仅在锁=0 时刷新常态显示
        if (display_lock > 0) {
            display_lock--;
        } else {
            led_state = (led_state & 0xFFFF0000) | (sw_val & 0xFFFF);
        }
        LED  = led_state;
        SEG7 = seg7_state;
    }

    return 0;
}

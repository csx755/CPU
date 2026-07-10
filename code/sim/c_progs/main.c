/* main.c — 三中断下板验收
 *
 *  数码管 SW[7:5]=000 时显示 CPU 输出:
 *    常态:   递增数字 (1, 2, 3, ...)
 *    定时器: 0xFFFFFFFF
 *    按钮:   0x00000001 ~ 0x00000004
 *    ECALL:  0xEEEEEEEE
 *
 *  display_lock: 中断显示倒计数, 保持可见
 *  下板: COUNTER = 80000, 仿真 = 80
 */

#define CSR_MSTATUS  0x300
#define CSR_MTVEC    0x305

#define LED_BASE       0xF0000000
#define SEG7_BASE      0xE0000000
#define COUNTER_ADDR   0xF0000008
#define SW_ADDR        0xF0000010
#define BTN_ADDR        0xF0000014

#define LED            (*(volatile unsigned int *)LED_BASE)
#define SEG7           (*(volatile unsigned int *)SEG7_BASE)
#define COUNTER        (*(volatile unsigned int *)COUNTER_ADDR)
#define SW             (*(volatile unsigned int *)SW_ADDR)
#define BTN            (*(volatile unsigned int *)BTN_ADDR)

#define csr_write(csr, val) \
    __asm__ volatile ("csrrw x0, %0, %1" :: "i"(csr), "r"(val) : "memory")

extern unsigned int _trap_vector;

volatile unsigned int display_val  = 0x00000001;  // 当前显示值
volatile unsigned int display_lock = 0;            // >0 = 中断独占倒计数
volatile unsigned int normal_count = 1;            // 常态递增计数器

// ==== 中断处理 ====
void c_interrupt_handler(void) {
    unsigned int mcause_val;
    __asm__ volatile ("csrrw %0, 0x342, x0" : "=r"(mcause_val));

    if (mcause_val == 0x8000000B) {
        if (COUNTER < 10) {
            // === 定时器中断 ===
            display_val  = 0xFFFFFFFF;
            display_lock = 5000;
            COUNTER = 800;                   // reload (下板改 80000)
        } else {
            // === 按钮中断 ===
            unsigned int btn = BTN & 0x0F;
            display_val  = btn;              // 0x00000001 ~ 0x00000004
            display_lock = 5000;
        }
    }
}

// ==== ECALL 处理 ====
void c_ecall_handler(void) {
    display_val  = 0xEEEEEEEE;
    display_lock = 5000;
}

// ==== 主程序 ====
int main(void) {
    csr_write(CSR_MTVEC, (unsigned int)&_trap_vector);
    COUNTER = 80;   // 仿真用, 下板改 80000
    csr_write(CSR_MSTATUS, 0x8);

    LED  = 0;
    SEG7 = 0;

    unsigned int last_btn4 = 0;

    while (1) {
        unsigned int btn_val = BTN;

        // BTN[4] 按下 → ECALL
        if ((btn_val & 0x10) && !(last_btn4 & 0x10)) {
            __asm__ volatile ("ecall");
        }
        last_btn4 = btn_val;

        // 中断独占期间倒计数; 结束后恢复递增
        if (display_lock > 0) {
            display_lock--;
        } else {
            display_val = normal_count;
            normal_count++;
        }

        LED  = display_val;
        SEG7 = display_val;
    }

    return 0;
}

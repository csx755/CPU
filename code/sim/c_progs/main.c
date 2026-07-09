/* main.c — 三中断验收测试: 定时器 + 按钮 + ECALL
 *
 * 中断源:
 *   1. 定时器: Counter_x (0xF0000008) 触发 INT
 *   2. 按钮:   BTN (0xF0000014) 触发 INT
 *   3. ECALL:  软件异常 (mcause=0x0000000B)
 *
 * SoC 外设:
 *   LED:    0xF0000000 (写)
 *   数码管: 0xE0000000 (写)
 *   Counter:0xF0000008 (写初值)
 *   SW:     0xF0000010 (读)
 *   BTN:    0xF0000014 (读)
 */

#define CSR_MSTATUS  0x300
#define CSR_MTVEC    0x305
#define CSR_MEPC     0x341
#define CSR_MCAUSE   0x342

#define LED_BASE      0xF0000000
#define SEG7_BASE     0xE0000000
#define COUNTER_ADDR  0xF0000008
#define SW_ADDR       0xF0000010
#define BTN_ADDR      0xF0000014

#define LED     (*(volatile unsigned int *)LED_BASE)
#define SEG7    (*(volatile unsigned int *)SEG7_BASE)
#define COUNTER (*(volatile unsigned int *)COUNTER_ADDR)
#define SW      (*(volatile unsigned int *)SW_ADDR)
#define BTN     (*(volatile unsigned int *)BTN_ADDR)

#define csr_write(csr, val) \
    __asm__ volatile ("csrrw x0, %0, %1" :: "i"(csr), "r"(val))
#define csr_read(csr, dst) \
    __asm__ volatile ("csrrw %0, %1, x0" : "=r"(dst) : "i"(csr))

extern void trap_handler(void);
extern unsigned int _trap_vector;

// 全局计数器
volatile unsigned int timer_count = 0;
volatile unsigned int btn_count   = 0;
volatile unsigned int ecall_count = 0;

// =================== 中断处理 ===================
void c_interrupt_handler(void) {
    unsigned int mcause_val;
    csr_read(CSR_MCAUSE, mcause_val);

    if (mcause_val == 0x8000000B) {
        // 外部中断 —— 读状态寄存器区分来源
        unsigned int btn_state = BTN;  // 读按键

        if (btn_state != 0) {
            // === 按钮中断 ===
            btn_count++;
            // LED 高16位 = btn_count, 低16位 = 按键值
            LED = (btn_count << 16) | btn_state;
            // 数码管显示按键号
            SEG7 = btn_state;
        } else {
            // === 定时器中断 ===
            timer_count++;
            // LED 显示定时器计数
            LED = timer_count;
            // 数码管显示秒数
            SEG7 = timer_count & 0xFF;
        }

        // 重载定时器
        COUNTER = 800;  // ~1ms
    }
}

// =================== ECALL 处理 ===================
void c_ecall_handler(void) {
    ecall_count++;

    // LED 闪烁 ECALL 特征
    LED = (ecall_count << 16) | 0xEC00;

    // 数码管显示 "EC" + count
    SEG7 = 0xEC00 | (ecall_count & 0xFF);
}

// =================== 主程序 ===================
int main(void) {
    // 1. 设置中断向量
    csr_write(CSR_MTVEC, (unsigned int)&_trap_vector);

    // 2. 启动定时器 (~100ms 第一次中断)
    COUNTER = 80000;

    // 3. 开中断
    csr_write(CSR_MSTATUS, 0x8);  // MIE=1

    // 4. 初始显示
    LED  = 0xDEAD;
    SEG7 = 0x00000000;

    // 5. 主循环
    unsigned int last_btn = 0;

    while (1) {
        // 读取开关
        unsigned int sw_val = SW;
        unsigned int btn_val = BTN;

        // 按钮按下 → ECALL (演示特权中断)
        if (btn_val != 0 && last_btn == 0) {
            __asm__ volatile ("ecall");
        }
        last_btn = btn_val;

        // LED 低16位显示开关状态 (高16位由中断更新)
        LED = (LED & 0xFFFF0000) | (sw_val & 0xFFFF);
    }

    return 0;
}

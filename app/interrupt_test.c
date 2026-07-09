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

// CSR 地址定义
#define CSR_STATUS  0x100
#define CSR_INTMASK 0x101
#define CSR_SEPC    0x102
#define CSR_SCAUSE  0x103

// 中断向量地址
#define EXC_VECTOR_BASE 0x100

// 简单延时
__attribute__((noinline)) void delay(int n) {
    volatile int i;
    for (i = 0; i < n; i++);
}

// CSR 读写函数
static inline unsigned int csr_read(unsigned int csr) {
    unsigned int result;
    asm volatile ("csrr %0, %1" : "=r"(result) : "i"(csr));
    return result;
}

static inline void csr_write(unsigned int csr, unsigned int val) {
    asm volatile ("csrw %0, %1" :: "i"(csr), "r"(val));
}

// 中断处理函数
void interrupt_handler() {
    unsigned int scause = csr_read(CSR_SCAUSE);
    unsigned int sepc = csr_read(CSR_SEPC);
    
    // 根据异常原因处理中断
    switch (scause) {
        case 0:  // 定时器中断
            // 处理定时器中断
            break;
        case 1:  // 外部中断源0
            // 处理外部中断源0
            break;
        case 2:  // 外部中断源1
            // 处理外部中断源1
            break;
        case 8:  // ECALL 指令
            // 处理环境调用
            break;
        default:
            // 未知异常
            break;
    }
    
    // 返回到异常发生前的下一条指令
    // 对于ECALL，返回到SEPC+4
    // 对于其他异常，返回到SEPC
    if (scause == 8) {
        // ECALL: 返回到SEPC+4
        asm volatile ("csrw sepc, %0" :: "r"(sepc + 4));
    } else {
        // 其他异常: 返回到SEPC
        asm volatile ("csrw sepc, %0" :: "r"(sepc));
    }
}

void main() {
    volatile unsigned int *led    = (unsigned int *)LED_BASE;
    volatile unsigned int *seg7   = (unsigned int *)SEG7_BASE;
    volatile unsigned int *sw_btn = (unsigned int *)SW_BTN_BASE;
    
    unsigned int last_btn = 0;
    unsigned char digit = 0;
    unsigned char led_mode = 0;
    
    // 初始化中断
    // 1. 设置中断向量基地址
    // 2. 使能全局中断
    // 3. 使能定时器中断
    // 4. 使能外部中断源0
    // 5. 不屏蔽任何中断
    
    unsigned int status = 0x01;  // IE=1，使能全局中断
    status |= (1 << 1);  // IM[0]=1，使能定时器中断
    status |= (1 << 2);  // IM[1]=1，使能外部中断源0
    
    csr_write(CSR_STATUS, status);
    csr_write(CSR_INTMASK, 0x00);  // 不屏蔽任何中断
    
    // 测试ECALL指令
    // asm volatile ("ecall");
    
    while (1) {
        // 读取开关和按键
        unsigned int val = *sw_btn;
        unsigned int sw  = val & 0x7FFF;
        unsigned int btn = (val >> 16) & 0x1F;
        
        // 按键上升沿检测
        unsigned int pressed = btn & (~last_btn);
        
        if (pressed) {
            if (pressed & 0x10) {  // CENTER
                digit = (digit + 1) & 0xFF;
            }
            if (pressed & 0x01) {  // UP
                digit = (digit - 1) & 0xFF;
            }
            if (pressed & 0x04) {  // DOWN
                digit = 0;
            }
            if (pressed & 0x08) {  // LEFT
                led_mode = led_mode ^ 1;
            }
        }
        
        // LED 输出
        if (led_mode == 0) {
            *led = (sw << 2) & 0xFFFF;
        } else {
            *led = (1 << ((digit & 0x0F) + 2)) & 0xFFFF;
        }
        
        // 数码管输出
        if (btn & 0x02) {  // RIGHT
            *seg7 = sw & 0xFF;
        } else {
            *seg7 = digit;
        }
        
        last_btn = btn;
        delay(50000);
    }
}
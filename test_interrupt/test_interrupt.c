/**
 * 中断测试程序
 *
 * 流程：
 *   1. 复位后 MIE=0，中断关闭，主程序正常跑流水灯
 *   2. 主程序执行 ecall → 硬件自动 MIE=1（开中断），返回下一条指令
 *   3. 定时器中断触发 → LED 全亮（0xFFFF），硬件自动 MIE=0
 *   4. mret 返回 → MIE 恢复为 MPIE=0，继续流水灯
 *
 * 验证方法：
 *   - LED 流水灯中偶尔"啪"一下全亮再恢复 → 中断正常工作！
 *   - LED 一直全亮不动 → mret 有问题
 *   - LED 一直流水灯从不全亮 → 中断没触发
 */

#define LED_BASE 0xF0000000

/* ecall 指令：触发异常，硬件自动开中断(MIE=1)并返回下一条指令 */
#define ecall() __asm__ volatile ("ecall")

/**
 * 中断处理函数
 * 进入时：MIE=0（硬件自动关中断），mepc 已保存返回地址
 */
void interrupt_handler(void) {
    volatile unsigned int *led = (volatile unsigned int *)LED_BASE;

    /* 16 颗 LED 全亮，证明中断处理程序执行了 */
    *led = 0x0000FFFF;
}

/**
 * 主程序：先跑流水灯，然后 ecall 开中断
 */
int main(void) {
    volatile unsigned int *led = (volatile unsigned int *)LED_BASE;
    volatile unsigned int pattern = 0x00000001;
    volatile int i;

    /* 第一阶段：MIE=0，中断关闭，纯流水灯 */
    for (i = 0; i < 2500000; i++) {
        *led = pattern;
        pattern = pattern << 1;
        if (pattern > 0x00008000)
            pattern = 0x00000001;
    }

    /* ecall → 硬件开中断(MIE=1)，返回下一条指令继续执行 */
    ecall();

    /* 第二阶段：MIE=1，中断开启，流水灯 + 偶尔被中断全亮 */
    pattern = 0x00000001;
    while (1) {
        *led = pattern;
        for (i = 0; i < 2500000; i++) {
            __asm__ volatile ("nop");
        }
        pattern = pattern << 1;
        if (pattern > 0x00008000)
            pattern = 0x00000001;
    }

    return 0;
}

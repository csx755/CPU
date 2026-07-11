// 麦克风测试程序
// 读取麦克风输入并通过LED显示

#define TONE (*(volatile unsigned int *)0xB0000000)
#define LED  (*(volatile unsigned int *)0xF0000000)
#define MIC  (*(volatile unsigned int *)0xC0000000)  // 麦克风输入地址

void delay(int n) {
    volatile int i;
    while (n--) {
        i = 726000;
        while (i--);
    }
}

int main(void) {
    while (1) {
        // 读取麦克风值
        unsigned int mic_val = MIC;

        // 显示在LED上 (低8位)
        LED = mic_val;

        // 延时
        delay(1);
    }
}

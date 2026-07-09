// ============================================================
// PS2 键盘 + VGA 显示 测试程序
// 功能: 读取键盘按键，在 VGA 上显示按键值
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

// ---- 地址定义 ----
#define LED     (*(volatile unsigned int *)0xF0000000)
#define SEG7    (*(volatile unsigned int *)0xE0000000)
#define PS2     (*(volatile unsigned int *)0xD0000000)  // PS2 键盘
#define VRAM_BASE ((volatile unsigned short *)0xC0000000) // VRAM 显存基地址

// ---- VRAM 地址计算 ----
// 字符模式: 80列 x 30行
// 每个字符: 16位 = [15:12]前景色 [11:8]背景色 [7:0]ASCII
#define VRAM_ADDR(row, col) ((row) * 80 + (col))

// ---- 颜色定义 (RGBI) ----
#define COLOR_BLACK   0x0
#define COLOR_BLUE    0x1
#define COLOR_GREEN   0x2
#define COLOR_CYAN    0x3
#define COLOR_RED     0x4
#define COLOR_MAGENTA 0x5
#define COLOR_YELLOW  0x6
#define COLOR_WHITE   0x7
#define COLOR_BRIGHT_BLACK   0x8
#define COLOR_BRIGHT_BLUE    0x9
#define COLOR_BRIGHT_GREEN   0xA
#define COLOR_BRIGHT_CYAN    0xB
#define COLOR_BRIGHT_RED     0xC
#define COLOR_BRIGHT_MAGENTA 0xD
#define COLOR_BRIGHT_YELLOW  0xE
#define COLOR_BRIGHT_WHITE   0xF
#define COLOR_DARK_GRAY      0x8

// ---- 工具函数 ----
static inline void csr_write(unsigned int addr, unsigned int val) {
    asm volatile ("csrw %0, %1" :: "i"(addr), "r"(val));
}

__attribute__((noinline)) void delay(int n) {
    volatile int i;
    for (i = 0; i < n; i++);
}

// 写一个字符到 VRAM
static void vram_write(int row, int col, char ch, int fg, int bg) {
    unsigned short val = (unsigned short)((fg << 12) | (bg << 8) | (unsigned char)ch);
    *(VRAM_BASE + VRAM_ADDR(row, col)) = val;
}

// 写一个字符串到 VRAM
static void vram_puts(int row, int col, const char *str, int fg, int bg) {
    while (*str) {
        vram_write(row, col, *str, fg, bg);
        col++;
        str++;
    }
}

// 清屏
static void vram_clear(int fg, int bg) {
    int i, j;
    for (i = 0; i < 60; i++) {
        for (j = 0; j < 80; j++) {
            vram_write(i, j, ' ', fg, bg);
        }
    }
}

// 显示数字
static void vram_putnum(int row, int col, int num, int fg, int bg) {
    char buf[12];
    int i = 0;
    if (num == 0) {
        vram_write(row, col, '0', fg, bg);
        return;
    }
    while (num > 0) {
        buf[i++] = '0' + (num % 10);
        num /= 10;
    }
    // 反转
    int j;
    for (j = 0; j < i; j++) {
        vram_write(row, col + i - 1 - j, buf[j], fg, bg);
    }
}

// ---- 主函数 ----
void main(void) {
    // 清屏: 黑底白字
    vram_clear(COLOR_WHITE, COLOR_BLACK);
    
    // 显示标题
    vram_puts(0, 30, "PS2 Keyboard Test", COLOR_BRIGHT_CYAN, COLOR_BLACK);
    vram_puts(1, 25, "Press any key to see scancode", COLOR_YELLOW, COLOR_BLACK);
    vram_puts(2, 20, "----------------------------------------", COLOR_DARK_GRAY, COLOR_BLACK);
    
    // 显示地址信息
    vram_puts(4, 0, "PS2 Address: 0xD0000000", COLOR_GREEN, COLOR_BLACK);
    vram_puts(5, 0, "VRAM Address: 0xC0000000", COLOR_GREEN, COLOR_BLACK);
    
    // 显示按键区域标题
    vram_puts(7, 0, "Key History:", COLOR_BRIGHT_WHITE, COLOR_BLACK);
    vram_puts(8, 0, "------------", COLOR_DARK_GRAY, COLOR_BLACK);
    
    int row = 9;
    int col_pos = 0;
    int key_count = 0;
    
    while (1) {
        // 读取 PS2 键盘
        unsigned int ps2_val = PS2;
        unsigned char scancode = ps2_val & 0xFF;
        int has_data = (ps2_val >> 8) & 1;
        
        if (has_data && scancode != 0) {
            // 显示扫描码
            vram_puts(4, 30, "Scancode: 0x", COLOR_WHITE, COLOR_BLACK);
            
            // 十六进制显示
            char hex[3];
            hex[0] = "0123456789ABCDEF"[(scancode >> 4) & 0xF];
            hex[1] = "0123456789ABCDEF"[scancode & 0xF];
            hex[2] = 0;
            vram_puts(4, 42, hex, COLOR_BRIGHT_YELLOW, COLOR_BLACK);
            
            // 显示按键名
            vram_puts(5, 30, "Key: ", COLOR_WHITE, COLOR_BLACK);
            
            // 简单的扫描码到字符映射
            char key_char = '?';
            if (scancode >= 0x10 && scancode <= 0x19) {
                key_char = '1' + (scancode - 0x10);
            } else if (scancode >= 0x1E && scancode <= 0x26) {
                key_char = '1' + (scancode - 0x1E);
            } else if (scancode >= 0x27 && scancode <= 0x32) {
                key_char = 'a' + (scancode - 0x27);
            } else if (scancode == 0x39) {
                key_char = ' ';
            } else if (scancode == 0x5A) {
                key_char = 'E';  // Enter
            }
            
            vram_write(5, 35, key_char, COLOR_BRIGHT_GREEN, COLOR_BLACK);
            vram_write(5, 36, ' ', COLOR_BLACK, COLOR_BLACK);  // 清除旧字符
            
            // 在历史区域显示
            vram_write(row, col_pos, key_char, COLOR_BRIGHT_WHITE, COLOR_BLUE);
            col_pos++;
            if (col_pos >= 78) {
                col_pos = 0;
                row++;
                if (row >= 28) row = 9;
            }
            
            key_count++;
            
            // 更新计数
            vram_puts(23, 0, "Keys pressed: ", COLOR_WHITE, COLOR_BLACK);
            vram_putnum(23, 14, key_count, COLOR_BRIGHT_YELLOW, COLOR_BLACK);
            
            // LED 显示按键计数
            LED = key_count;
            
            delay(100000);  // 消抖
        }
        
        delay(1000);
    }
}

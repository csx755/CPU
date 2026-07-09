// ============================================================
// 打地鼠游戏 - RISC-V 流水线 CPU 版本
// 
// 硬件平台: 自研 RISC-V CPU + PS2键盘 + VGA显示
// 游戏规则:
//   - 3x3 地鼠洞，数字键 1-9 对应
//   - 按 Space 开始/暂停
//   - 30 秒倒计时，打中地鼠得分
//   - 地鼠出现速度随时间加快
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
#define PS2     (*(volatile unsigned int *)0xD0000000)
#define VRAM_BASE ((volatile unsigned short *)0xC0000000)

// ---- VRAM 地址计算 ----
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

// ---- 游戏状态 ----
#define STATE_MENU      0
#define STATE_PLAYING   1
#define STATE_PAUSED    2
#define STATE_GAMEOVER  3

// ---- 游戏参数 ----
#define GAME_TIME       30      // 游戏时间（秒）
#define MOLE_MIN_TIME   20      // 地鼠最少出现时间（帧）
#define MOLE_MAX_TIME   60      // 地鼠最多出现时间（帧）
#define FRAME_DELAY     50000   // 帧延迟

// ---- 全局变量 ----
int game_state = STATE_MENU;
int score = 0;
int time_left = GAME_TIME;
int frame_count = 0;
int mole_timer = 0;
int mole_holes[9] = {0};  // 0=空, 1=有地鼠
int last_key = 0;
int combo = 0;             // 连击数

// ---- 工具函数 ----
static inline void csr_write(unsigned int addr, unsigned int val) {
    asm volatile ("csrw %0, %1" :: "i"(addr), "r"(val));
}

__attribute__((noinline)) void delay(int n) {
    volatile int i;
    for (i = 0; i < n; i++);
}

// 简单的伪随机数生成器
static unsigned int rng_seed = 12345;
static int random(void) {
    rng_seed = rng_seed * 1103515245 + 12345;
    return (rng_seed >> 16) & 0x7FFF;
}

// ---- VRAM 操作 ----
static void vram_write(int row, int col, char ch, int fg, int bg) {
    unsigned short val = (unsigned short)((fg << 12) | (bg << 8) | (unsigned char)ch);
    *(VRAM_BASE + VRAM_ADDR(row, col)) = val;
}

static void vram_puts(int row, int col, const char *str, int fg, int bg) {
    while (*str) {
        vram_write(row, col, *str, fg, bg);
        col++;
        str++;
    }
}

static void vram_clear(int fg, int bg) {
    int i, j;
    for (i = 0; i < 30; i++) {
        for (j = 0; j < 80; j++) {
            vram_write(i, j, ' ', fg, bg);
        }
    }
}

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
    int j;
    for (j = 0; j < i; j++) {
        vram_write(row, col + i - 1 - j, buf[j], fg, bg);
    }
}

// ---- 地鼠洞绘制 ----
// 每个洞占 8x3 字符区域
// 洞位置: 第 8-20 行, 第 10-70 列
static const int HOLE_START_ROW = 8;
static const int HOLE_START_COL = 10;
static const int HOLE_WIDTH = 18;   // 每个洞的宽度（含间距）
static const int HOLE_HEIGHT = 5;   // 每个洞的高度

static void draw_hole_empty(int hole) {
    int row = HOLE_START_ROW + (hole / 3) * HOLE_HEIGHT;
    int col = HOLE_START_COL + (hole % 3) * HOLE_WIDTH;
    
    // 空洞: 棕色边框
    int i, j;
    for (i = 0; i < 3; i++) {
        for (j = 0; j < 14; j++) {
            vram_write(row + i, col + j, ' ', COLOR_BLACK, COLOR_BLACK);
        }
    }
    // 洞口
    vram_puts(row, col, "+------------+", COLOR_YELLOW, COLOR_BLACK);
    vram_puts(row + 1, col, "|            |", COLOR_YELLOW, COLOR_BLACK);
    vram_puts(row + 2, col, "+------------+", COLOR_YELLOW, COLOR_BLACK);
}

static void draw_hole_mole(int hole) {
    int row = HOLE_START_ROW + (hole / 3) * HOLE_HEIGHT;
    int col = HOLE_START_COL + (hole % 3) * HOLE_WIDTH;
    
    // 有地鼠: 绿色地鼠
    vram_puts(row, col, "+------------+", COLOR_YELLOW, COLOR_BLACK);
    vram_puts(row + 1, col, "|  @(^_^)@   |", COLOR_BRIGHT_GREEN, COLOR_BLACK);
    vram_puts(row + 2, col, "+------------+", COLOR_YELLOW, COLOR_BLACK);
}

static void draw_hole_hit(int hole) {
    int row = HOLE_START_ROW + (hole / 3) * HOLE_HEIGHT;
    int col = HOLE_START_COL + (hole % 3) * HOLE_WIDTH;
    
    // 打中: 红色闪烁
    vram_puts(row, col, "+------------+", COLOR_RED, COLOR_BLACK);
    vram_puts(row + 1, col, "|  X(>_<)X   |", COLOR_BRIGHT_RED, COLOR_BLACK);
    vram_puts(row + 2, col, "+------------+", COLOR_RED, COLOR_BLACK);
}

// ---- 画面绘制 ----
static void draw_frame(void) {
    // 标题
    vram_puts(0, 30, "WHACK A MOLE", COLOR_BRIGHT_YELLOW, COLOR_BLACK);
    vram_puts(1, 28, "=== Whack-a-Mole ===", COLOR_YELLOW, COLOR_BLACK);
    
    // 分数和时间
    vram_puts(3, 0, "Score: ", COLOR_WHITE, COLOR_BLACK);
    vram_putnum(3, 7, score, COLOR_BRIGHT_GREEN, COLOR_BLACK);
    
    vram_puts(3, 20, "Time: ", COLOR_WHITE, COLOR_BLACK);
    vram_putnum(3, 26, time_left, COLOR_BRIGHT_RED, COLOR_BLACK);
    vram_puts(3, 29, "s", COLOR_WHITE, COLOR_BLACK);
    
    vram_puts(3, 40, "Combo: ", COLOR_WHITE, COLOR_BLACK);
    vram_putnum(3, 47, combo, COLOR_BRIGHT_CYAN, COLOR_BLACK);
    
    // 操作提示
    vram_puts(28, 0, "Keys: 1-9=Hit  Space=Start/Pause  Q=Quit", COLOR_DARK_GRAY, COLOR_BLACK);
    
    // 绘制地鼠洞
    int i;
    for (i = 0; i < 9; i++) {
        if (mole_holes[i] == 0) {
            draw_hole_empty(i);
        } else if (mole_holes[i] == 1) {
            draw_hole_mole(i);
        } else if (mole_holes[i] == 2) {
            draw_hole_hit(i);
        }
    }
}

static void draw_menu(void) {
    vram_clear(COLOR_WHITE, COLOR_BLACK);
    
    vram_puts(5, 25, "=== WHACK A MOLE ===", COLOR_BRIGHT_YELLOW, COLOR_BLACK);
    vram_puts(8, 20, "Press SPACE to start!", COLOR_WHITE, COLOR_BLACK);
    vram_puts(10, 15, "Use number keys 1-9 to whack moles", COLOR_GREEN, COLOR_BLACK);
    vram_puts(12, 18, "Whack as many as you can in 30s!", COLOR_CYAN, COLOR_BLACK);
    
    vram_puts(15, 20, "Controls:", COLOR_BRIGHT_WHITE, COLOR_BLACK);
    vram_puts(16, 20, "  1 2 3  - Top row", COLOR_WHITE, COLOR_BLACK);
    vram_puts(17, 20, "  4 5 6  - Middle row", COLOR_WHITE, COLOR_BLACK);
    vram_puts(18, 20, "  7 8 9  - Bottom row", COLOR_WHITE, COLOR_BLACK);
    vram_puts(19, 20, "  Space  - Start/Pause", COLOR_WHITE, COLOR_BLACK);
    
    vram_puts(22, 25, "Ready to play?", COLOR_BRIGHT_GREEN, COLOR_BLACK);
}

static void draw_gameover(void) {
    vram_puts(12, 25, "=== GAME OVER ===", COLOR_BRIGHT_RED, COLOR_BLACK);
    vram_puts(14, 25, "Final Score: ", COLOR_WHITE, COLOR_BLACK);
    vram_putnum(14, 38, score, COLOR_BRIGHT_YELLOW, COLOR_BLACK);
    
    vram_puts(16, 25, "Press SPACE to restart", COLOR_GREEN, COLOR_BLACK);
    vram_puts(17, 25, "Press Q to quit", COLOR_RED, COLOR_BLACK);
}

// ---- 游戏逻辑 ----
static void start_game(void) {
    score = 0;
    time_left = GAME_TIME;
    frame_count = 0;
    combo = 0;
    int i;
    for (i = 0; i < 9; i++) mole_holes[i] = 0;
    game_state = STATE_PLAYING;
    vram_clear(COLOR_WHITE, COLOR_BLACK);
}

static void spawn_mole(void) {
    // 随机选择一个空洞
    int empty_holes[9];
    int count = 0;
    int i;
    
    for (i = 0; i < 9; i++) {
        if (mole_holes[i] == 0) {
            empty_holes[count++] = i;
        }
    }
    
    if (count > 0) {
        int idx = random() % count;
        mole_holes[empty_holes[idx]] = 1;
    }
}

static void whack_mole(int hole) {
    if (hole >= 0 && hole < 9 && mole_holes[hole] == 1) {
        // 打中!
        mole_holes[hole] = 2;  // 显示打中效果
        combo++;
        score += 10 * combo;  // 连击加分
        
        // LED 闪烁表示打中
        LED = score;
    } else {
        // 打空或打已死的地鼠
        combo = 0;
    }
}

static int scancode_to_hole(unsigned char scancode) {
    // 扫描码到地鼠洞的映射
    // 主键盘数字键: 1-9
    if (scancode >= 0x10 && scancode <= 0x19) {
        return scancode - 0x10;  // 0-8
    }
    // 小键盘数字键
    if (scancode >= 0x69 && scancode <= 0x72) {
        return scancode - 0x69;  // 0-8
    }
    return -1;
}

static unsigned char read_ps2_key(void) {
    unsigned int ps2_val = PS2;
    unsigned char scancode = ps2_val & 0xFF;
    int has_data = (ps2_val >> 8) & 1;
    
    if (has_data && scancode != 0) {
        return scancode;
    }
    return 0;
}

// ---- 主函数 ----
void main(void) {
    // 初始化
    csr_write(0x100, 0x01);  // 使能全局中断
    LED = 0;
    SEG7 = 0;
    
    draw_menu();
    
    while (1) {
        unsigned char key = read_ps2_key();
        
        switch (game_state) {
            case STATE_MENU:
                if (key == 0x39) {  // Space
                    start_game();
                }
                break;
                
            case STATE_PLAYING:
                // 处理按键
                if (key == 0x39) {  // Space = 暂停
                    game_state = STATE_PAUSED;
                    vram_puts(12, 30, "PAUSED", COLOR_BRIGHT_YELLOW, COLOR_BLACK);
                } else if (key == 0x1D) {  // Q = 退出
                    game_state = STATE_MENU;
                    draw_menu();
                } else {
                    int hole = scancode_to_hole(key);
                    if (hole >= 0) {
                        whack_mole(hole);
                    }
                }
                
                // 游戏逻辑
                frame_count++;
                
                // 地鼠生成（根据时间调整频率）
                mole_timer--;
                if (mole_timer <= 0) {
                    spawn_mole();
                    // 随时间加快
                    int min_time = MOLE_MIN_TIME - (GAME_TIME - time_left) / 5;
                    if (min_time < 5) min_time = 5;
                    mole_timer = min_time + random() % (MOLE_MAX_TIME - min_time);
                }
                
                // 地鼠消失（随机）
                for (int i = 0; i < 9; i++) {
                    if (mole_holes[i] == 1) {
                        if (random() % 100 < 5) {  // 5% 概率消失
                            mole_holes[i] = 0;
                        }
                    } else if (mole_holes[i] == 2) {
                        if (random() % 100 < 20) {  // 打中效果持续
                            mole_holes[i] = 0;
                        }
                    }
                }
                
                // 时间更新（每秒）
                if (frame_count % 20 == 0) {
                    time_left--;
                    if (time_left <= 0) {
                        game_state = STATE_GAMEOVER;
                        vram_clear(COLOR_WHITE, COLOR_BLACK);
                        draw_gameover();
                    }
                }
                
                // 更新画面
                draw_frame();
                break;
                
            case STATE_PAUSED:
                if (key == 0x39) {  // Space = 继续
                    game_state = STATE_PLAYING;
                    vram_clear(COLOR_WHITE, COLOR_BLACK);
                } else if (key == 0x1D) {  // Q = 退出
                    game_state = STATE_MENU;
                    draw_menu();
                }
                break;
                
            case STATE_GAMEOVER:
                if (key == 0x39) {  // Space = 重新开始
                    start_game();
                } else if (key == 0x1D) {  // Q = 退出
                    game_state = STATE_MENU;
                    draw_menu();
                }
                break;
        }
        
        delay(FRAME_DELAY);
    }
}

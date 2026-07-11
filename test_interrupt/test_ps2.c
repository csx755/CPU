/**
 * 按钮钢琴测试（C4 D4 E4 F4 G4 大调五音）
 *
 * Nexys A7 按钮映射：
 *   btn_i[0] = BTNC(中)  = C4 (Do)   261.63Hz
 *   btn_i[1] = BTNU(上)  = D4 (Re)   293.66Hz
 *   btn_i[2] = BTNL(左)  = E4 (Mi)   329.63Hz
 *   btn_i[3] = BTNR(右)  = F4 (Fa)   349.23Hz
 *   btn_i[4] = BTND(下)  = G4 (Sol)  392.00Hz
 *
 * 按住发声，松开静音。
 */

#define BTN_SW   (*(volatile unsigned int *)0xE0000000)
#define LED_BASE (*(volatile unsigned int *)0xF0000000)
#define TONE     (*(volatile unsigned int *)0xB0000000)

/* DDS 频率字 (32位相位累加器, 100MHz时钟) */
#define FREQ_C4   11237   /* 261.63 Hz */
#define FREQ_D4   12613   /* 293.66 Hz */
#define FREQ_E4   14158   /* 329.63 Hz */
#define FREQ_F4   14999   /* 349.23 Hz */
#define FREQ_G4   16836   /* 392.00 Hz */

void interrupt_handler(void) {}

int main(void) {
    while (1) {
        /* MIO_BUS: E0000000 读出 {11'b0, BTN[4:0], SW[15:0]} */
        unsigned int btn = (BTN_SW >> 16) & 0x1F;

        if      (btn & 0x01) { TONE = FREQ_C4; LED_BASE = 0x0001; }  /* BTNC 中 → C4 */
        else if (btn & 0x02) { TONE = FREQ_D4; LED_BASE = 0x0002; }  /* BTNU 上 → D4 */
        else if (btn & 0x04) { TONE = FREQ_E4; LED_BASE = 0x0004; }  /* BTNL 左 → E4 */
        else if (btn & 0x08) { TONE = FREQ_F4; LED_BASE = 0x0008; }  /* BTNR 右 → F4 */
        else if (btn & 0x10) { TONE = FREQ_G4; LED_BASE = 0x0010; }  /* BTND 下 → G4 */
        else                 { TONE = 0;       LED_BASE = 0x0000; }
    }
}

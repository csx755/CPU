// 牵丝戏 - 自动生成
// 1=F, 4/4, tempo=86
// 简谱对照: _5=C4 _6=D4 _7=E4 1=F4 2=G4 3=A4 4=Bb4 5=C5 6=D5 7=E5
//           1+=F5 2+=G5 3+=A5 4+=Bb5 5+=C6 6+=D6 7+=E6
// 时值: s=十六分 e=八分 q=四分 h=二分 w=全音符 d=附点

#define TONE (*(volatile unsigned int *)0xB0000000)
#define LED  (*(volatile unsigned int *)0xF0000000)
#define LYRIC (*(volatile unsigned int *)0xC0000000)

// ===== DDS 频率字 (32位相位累加器, 100MHz时钟) =====
#define E6   56630
#define D6   50451
#define C6   44947
#define Bb5  40043
#define A5   37796
#define G5   33672
#define F5   29999
#define E5   28315
#define D5   25226
#define C5   22473
#define Bb4  20021
#define A4   18898
#define G4   16836
#define F4   14999
#define E4   14158
#define D4   12613
#define C4   11237
#define Bb3  10011
#define A3   9449
#define REST 0

// ===== 时值宏定义 (单位: 十六分音符) =====
#define DUR_s   1
#define DUR_e   2
#define DUR_ed  3
#define DUR_q   4
#define DUR_qd  6
#define DUR_h   8
#define DUR_hd  12
#define DUR_w   16

// 延时: n个十六分音符 (50MHz CPU, tempo=86)
void delay(int n) {
    volatile int i;
    while (n--) {
        i = 726000;
        while (i--);
    }
}

void interrupt_handler(void) {}

int main(void) {
    while (1) {
        LYRIC = 0;
        //从现在开始是：（前奏）
        TONE = D5; delay(DUR_q);  // 6 q
        TONE = REST; delay(1);
        TONE = E5; delay(DUR_q);  // 7 q
        TONE = REST; delay(1);
        TONE = F5; delay(DUR_q);  // 1. q
        TONE = REST; delay(1);
        TONE = G5; delay(DUR_q);  // 2. q
        TONE = REST; delay(1);
        TONE = A5; delay(DUR_qd);  // 3. qd
        TONE = REST; delay(1);
        TONE = D5; delay(DUR_qd);  // 6 qd
        TONE = REST; delay(1);
        TONE = E5; delay(DUR_s);  // 7 s
        TONE = REST; delay(1);
        TONE = F5; delay(DUR_s);  // 1. s
        TONE = REST; delay(1);
        TONE = E5; delay(DUR_e);  // 7 e
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_q);  // 5 q
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_h);  // 3 h
        TONE = REST; delay(1);
        TONE = REST; delay(DUR_q);  // 休 q
        TONE = D5; delay(DUR_s);  // 6 s
        TONE = REST; delay(1);
        TONE = E5; delay(DUR_s);  // 7 s
        TONE = REST; delay(1);
        TONE = F5; delay(DUR_e);  // 1. e
        TONE = REST; delay(1);
        TONE = G5; delay(DUR_e);  // 2. e
        TONE = REST; delay(1);
        TONE = A5; delay(DUR_qd);  // 3. qd
        TONE = REST; delay(1);
        TONE = D5; delay(DUR_qd);  // 6 qd
        TONE = REST; delay(1);
        TONE = E5; delay(DUR_s);  // 7 s
        TONE = REST; delay(1);
        TONE = F5; delay(DUR_s);  // 1. s
        TONE = REST; delay(1);
        TONE = E5; delay(DUR_e);  // 7 e
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_e);  // 5 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_q);  // 3 q
        TONE = REST; delay(1);
        TONE = F5; delay(DUR_q);  // 1. q
        TONE = REST; delay(1);
        TONE = E5; delay(DUR_q);  // 7 q
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_s);  // 5 s
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_s);  // 3 s
        TONE = REST; delay(1);
        TONE = D5; delay(DUR_s);  // 6 s
        TONE = REST; delay(1);
        TONE = E5; delay(DUR_s);  // 7 s
        TONE = REST; delay(1);
        TONE = F5; delay(DUR_e);  // 1. e
        TONE = REST; delay(1);
        TONE = G5; delay(DUR_e);  // 2. e
        TONE = REST; delay(1);
        TONE = A5; delay(DUR_qd);  // 3. qd
        TONE = REST; delay(1);
        TONE = D5; delay(DUR_qd);  // 6 qd
        TONE = REST; delay(1);
        TONE = E5; delay(DUR_s);  // 7 s
        TONE = REST; delay(1);
        TONE = F5; delay(DUR_s);  // 1. s
        TONE = REST; delay(1);
        TONE = E5; delay(DUR_e);  // 7 e
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_qd);  // 5 qd
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_e);  // 5 e
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_e);  // 5 e
        TONE = REST; delay(1);
        TONE = E5; delay(DUR_ed);  // 7 ed
        TONE = REST; delay(1);
        TONE = F5; delay(DUR_q);  // 1. q
        TONE = REST; delay(1);
        TONE = E5; delay(DUR_s);  // 7 s
        TONE = REST; delay(1);
        TONE = F5; delay(DUR_s);  // 1. s
        TONE = REST; delay(1);
        TONE = E5; delay(DUR_e);  // 7 e
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_e);  // 5 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_qd);  // 3 qd
        TONE = REST; delay(1);
        TONE = D5; delay(DUR_qd);  // 6 qd
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_qd);  // 3 qd
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_ed);  // 5 ed
        TONE = REST; delay(1);
        TONE = D5; delay(DUR_w);  // 6 w
        TONE = REST; delay(1);
        //现在进入主歌
        //现在开始原唱为：银临
        LYRIC = 1;
        //从现在开始，歌词：“嘲笑谁侍美扬威”
        TONE = F4; delay(DUR_qd);  // 1 qd
        TONE = REST; delay(1);
        TONE = E4; delay(DUR_e);  // 低7 e
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_q);  // 低5 q
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_e);  // 低5 e
        TONE = REST; delay(1);
        TONE = A3; delay(DUR_e);  // ? e
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_qd);  // 低5 qd
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_qd);  // 低6 qd
        TONE = REST; delay(1);
        TONE = REST; delay(DUR_q);  // 休 q
        TONE = REST; delay(DUR_q);  // 休 q
        LYRIC = 2;
        //从现在开始，歌词：“没了心如何相配”
        TONE = F4; delay(DUR_qd);  // 1 qd
        TONE = REST; delay(1);
        TONE = E4; delay(DUR_e);  // 低7 e
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_q);  // 低5 q
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_e);  // 低5 e
        TONE = REST; delay(1);
        TONE = A3; delay(DUR_e);  // ? e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_qd);  // 2 qd
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_qd);  // 3 qd
        TONE = REST; delay(1);
        TONE = REST; delay(DUR_q);  // 休 q
        LYRIC = 3;
        //从现在开始，歌词：“盘铃声清脆”
        TONE = A4; delay(DUR_s);  // 3 s
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_s);  // 5 s
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_qd);  // 2 qd
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        LYRIC = 4;
        //从现在开始，歌词：“帷幕间灯火幽微”
        TONE = REST; delay(1);
        TONE = F4; delay(DUR_e);  // 1 e
        TONE = REST; delay(1);
        TONE = E4; delay(DUR_e);  // 低7 e
        TONE = REST; delay(1);
        TONE = F4; delay(DUR_e);  // 1 e
        TONE = REST; delay(1);
        TONE = E4; delay(DUR_e);  // 低7 e
        TONE = REST; delay(1);
        TONE = F4; delay(DUR_e);  // 1 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_qd);  // 3 qd
        TONE = REST; delay(1);
        LYRIC = 5;
        //从现在开始，歌词：“我和你最天生一对”
        TONE = G4; delay(DUR_s);  // 2 s
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_s);  // 3 s
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_qd);  // 低6 qd
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_q);  // 低6 q
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_q);  // 低5 q
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_h);  // 低6 h
        TONE = REST; delay(1);
        TONE = REST; delay(DUR_q);  // 休 q
        TONE = REST; delay(DUR_q);  // 休 q
        LYRIC = 6;
        //从现在开始，歌词：“没了你才算原罪”
        TONE = F4; delay(DUR_qd);  // 1 qd
        TONE = REST; delay(1);
        TONE = E4; delay(DUR_e);  // 低7 e
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_q);  // 低5 q
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_e);  // 低5 e
        TONE = REST; delay(1);
        TONE = A3; delay(DUR_e);  // ? e
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_qd);  // 低5 qd
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_qd);  // 低6 qd
        TONE = REST; delay(1);
        TONE = REST; delay(DUR_q);  // 休 q
        LYRIC = 7;
        //从现在开始，歌词：“没了心才好相配”
        TONE = F4; delay(DUR_qd);  // 1 qd
        TONE = REST; delay(1);
        TONE = E4; delay(DUR_e);  // 低7 e
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_q);  // 低5 q
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_e);  // 低5 e
        TONE = REST; delay(1);
        TONE = A3; delay(DUR_e);  // ? e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_qd);  // 2 qd
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_qd);  // 3 qd
        TONE = REST; delay(1);
        TONE = REST; delay(DUR_q);  // 休 q
        LYRIC = 8;
        //从现在开始，歌词：“你褴褛我彩绘”
        TONE = A4; delay(DUR_s);  // 3 s
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_s);  // 5 s
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_q);  // 2 q
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_s);  // 3 s
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_s);  // 5 s
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_q);  // 2 q
        TONE = REST; delay(1);
        LYRIC = 9;
        //从现在开始，歌词：“并肩行过山与水”
        TONE = F4; delay(DUR_e);  // 1 e
        TONE = REST; delay(1);
        TONE = E4; delay(DUR_e);  // 低7 e
        TONE = REST; delay(1);
        TONE = F4; delay(DUR_e);  // 1 e
        TONE = REST; delay(1);
        TONE = E4; delay(DUR_e);  // 低7 e
        TONE = REST; delay(1);
        TONE = F4; delay(DUR_e);  // 1 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_qd);  // 3 qd
        TONE = REST; delay(1);
        LYRIC = 10;
        //从现在开始，歌词：“你憔悴我替你明媚”
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_qd);  // 低6 qd
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_q);  // 低6 q
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_q);  // 低5 q
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_h);  // 低6 h
        TONE = REST; delay(1);
        TONE = REST; delay(DUR_q);  // 休 q
        LYRIC = 11;
        //从现在开始，歌词：“是你吻开笔墨”
        TONE = D4; delay(DUR_s);  // 低6 s
        TONE = REST; delay(1);
        TONE = F4; delay(DUR_s);  // 1 s
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_q);  // 3 q
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_e);  // 低6 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        LYRIC = 12;
        //从现在开始，歌词：“染我眼角珠泪”
        TONE = D4; delay(DUR_e);  // 低6 e
        TONE = REST; delay(1);
        TONE = F4; delay(DUR_e);  // 1 e
        TONE = REST; delay(1);
        TONE = E4; delay(DUR_q);  // 低7 q
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_q);  // 低5 q
        TONE = REST; delay(1);
        TONE = A3; delay(DUR_e);  // ? e
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_e);  // 低5 e
        TONE = REST; delay(1);
        LYRIC = 13;
        //从现在开始，歌词：“演离合相遇悲喜为谁”
        TONE = D4; delay(DUR_e);  // 低6 e
        TONE = REST; delay(1);
        TONE = F4; delay(DUR_q);  // 1 q
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_q);  // 3 q
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_e);  // 低6 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_q);  // 3 q
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_e);  // 5 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_q);  // 3 q
        TONE = REST; delay(1);
        TONE = REST; delay(DUR_q);  // 休 q
        LYRIC = 14;
        //从现在开始，歌词：“他们迂回误会”
        TONE = D4; delay(DUR_s);  // 低6 s
        TONE = REST; delay(1);
        TONE = F4; delay(DUR_s);  // 1 s
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_q);  // 3 q
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_e);  // 低6 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        LYRIC = 15;
        //从现在开始，歌词：“我却只由你支配”
        TONE = F4; delay(DUR_e);  // 1 e
        TONE = REST; delay(1);
        TONE = E4; delay(DUR_e);  // 低7 e
        TONE = REST; delay(1);
        TONE = F4; delay(DUR_e);  // 1 e
        TONE = REST; delay(1);
        TONE = E4; delay(DUR_e);  // 低7 e
        TONE = REST; delay(1);
        TONE = F4; delay(DUR_e);  // 1 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_qd);  // 3 qd
        TONE = REST; delay(1);
        LYRIC = 16;
        //从现在开始，歌词：“问世间哪有更完美”
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_qd);  // 低6 qd
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_e);  // 低6 e
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_q);  // 低5 q
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_h);  // 低6 h
        TONE = REST; delay(1);
        TONE = REST; delay(DUR_q);  // 休 q
        //现在开始原唱为：Aki阿杰
        LYRIC = 17;
        //从现在开始，歌词：“兰花指捻红尘似水”
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_e);  // 5 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_q);  // 2 q
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_q);  // 2 q
        TONE = REST; delay(1);
        TONE = F4; delay(DUR_e);  // 1 e
        TONE = D4; delay(DUR_q);  // 低6 q
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_ed);  // 3 ed
        TONE = REST; delay(1);
        TONE = REST; delay(DUR_s);  // 休 s
        LYRIC = 18;
        //从现在开始，歌词：“三尺红台万事入歌吹”
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_e);  // 5 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_q);  // 2 q
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_q);  // 2 q
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_e);  // 5 e
        TONE = REST; delay(1);
        TONE = D5; delay(DUR_q);  // 6 q
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_ed);  // 3 ed
        TONE = REST; delay(1);
        TONE = REST; delay(DUR_s);  // 休 s
        LYRIC = 19;
        //从现在开始，歌词：“唱别久悲不成悲”
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = C5; delay(DUR_e);  // 5 e
        TONE = REST; delay(1);
        TONE = D5; delay(DUR_e);  // 6 e
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_e);  // 5 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_e);  // 5 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_q);  // 2 q
        TONE = REST; delay(1);
        LYRIC = 20;
        //从现在开始，歌词：“十分红处竟成灰”
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = F4; delay(DUR_e);  // 1 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = C5; delay(DUR_e);  // 5 e
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_q);  // 低6 q
        TONE = REST; delay(1);
        LYRIC = 21;
        //从现在开始，歌词：“愿谁记得谁最好的年岁”
        TONE = D4; delay(DUR_e);  // 低6 e
        TONE = REST; delay(1);
        TONE = F4; delay(DUR_e);  // 1 e
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_q);  // 低6 q
        TONE = REST; delay(1);
        TONE = G4; delay(DUR_e);  // 2 e
        TONE = REST; delay(1);
        TONE = A4; delay(DUR_e);  // 3 e
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_e);  // 低6 e
        TONE = REST; delay(1);
        TONE = C4; delay(DUR_q);  // 低5 q
        TONE = REST; delay(1);
        TONE = D4; delay(DUR_h);  // 低6 h
        TONE = REST; delay(1);
    }
}

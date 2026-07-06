// 8位7段数码管动态扫描显示（16进制）
module seg7_display(
    input  clk,               // 扫描时钟 (~1kHz)
    input  rst,
    input  [31:0] data,       // 要显示的 32-bit 数据
    output reg [7:0] seg,     // 段码 (CA-CG+DP, 低有效)
    output reg [7:0] an       // 位选 (AN0-AN7, 低有效)
);
    // 4-bit → 7-seg 共阳极编码 (低有效)
    // 段顺序: DP, CG, CF, CE, CD, CC, CB, CA
    function [7:0] hex2seg(input [3:0] h);
        case (h)
            4'h0: hex2seg = 8'b11000000;  // 0
            4'h1: hex2seg = 8'b11111001;  // 1
            4'h2: hex2seg = 8'b10100100;  // 2
            4'h3: hex2seg = 8'b10110000;  // 3
            4'h4: hex2seg = 8'b10011001;  // 4
            4'h5: hex2seg = 8'b10010010;  // 5
            4'h6: hex2seg = 8'b10000010;  // 6
            4'h7: hex2seg = 8'b11111000;  // 7
            4'h8: hex2seg = 8'b10000000;  // 8
            4'h9: hex2seg = 8'b10010000;  // 9
            4'hA: hex2seg = 8'b10001000;  // A
            4'hB: hex2seg = 8'b10000011;  // b
            4'hC: hex2seg = 8'b11000110;  // C
            4'hD: hex2seg = 8'b10100001;  // d
            4'hE: hex2seg = 8'b10000110;  // E
            4'hF: hex2seg = 8'b10001110;  // F
        endcase
    endfunction

    reg [2:0] digit;  // 当前扫描位 (0-7)

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            digit <= 3'b0;
            an <= 8'b11111111;
            seg <= 8'b11111111;
        end else begin
            digit <= digit + 1;
            case (digit)
                3'd0: begin an <= 8'b11111110; seg <= hex2seg(data[3:0]);   end
                3'd1: begin an <= 8'b11111101; seg <= hex2seg(data[7:4]);   end
                3'd2: begin an <= 8'b11111011; seg <= hex2seg(data[11:8]);  end
                3'd3: begin an <= 8'b11110111; seg <= hex2seg(data[15:12]); end
                3'd4: begin an <= 8'b11101111; seg <= hex2seg(data[19:16]); end
                3'd5: begin an <= 8'b11011111; seg <= hex2seg(data[23:20]); end
                3'd6: begin an <= 8'b10111111; seg <= hex2seg(data[27:24]); end
                3'd7: begin an <= 8'b01111111; seg <= hex2seg(data[31:28]); end
            endcase
        end
    end

endmodule

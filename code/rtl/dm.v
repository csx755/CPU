`include "ctrl_encode_def.v"

// 数据存储器 — 支持 byte/halfword/word 读写
module dm(clk, DMWr, addr, din, dout, DMType);
   input          clk;
   input          DMWr;
   input  [8:0]   addr;       // 字节地址 (512 字节范围)
   input  [31:0]  din;        // 写数据
   output [31:0]  dout;       // 读数据 (带符号/零扩展)
   input  [2:0]   DMType;     // 访存类型

   reg [31:0] dmem[127:0];     // 128 x 32-bit

   // 仿真初始化清零
   integer init_i;
   initial begin
      for (init_i = 0; init_i < 128; init_i = init_i + 1)
         dmem[init_i] = 32'b0;
   end

   wire [6:0] word_addr;       // 字地址
   wire [1:0] byte_off;        // 字内字节偏移
   wire [31:0] rd_word;        // 读出的完整字

   assign word_addr = addr[8:2];
   assign byte_off  = addr[1:0];
   assign rd_word   = dmem[word_addr];

   // === 读数据：字→按类型截取+扩展 ===
   reg [31:0] dout;
   always @(*) begin
      case (DMType)
         `dm_word: dout = rd_word;

         `dm_halfword, `dm_halfword_unsigned: begin
            // 半字选择 (2字节对齐，只需 bit1)
            dout = byte_off[1] ? {16'b0, rd_word[31:16]} : {16'b0, rd_word[15:0]};
            // 有符号扩展
            if (DMType == `dm_halfword)
               dout = {{16{dout[15]}}, dout[15:0]};
         end

         `dm_byte, `dm_byte_unsigned: begin
            // 字节选择
            case (byte_off)
               2'b00: dout = {24'b0, rd_word[7:0]};
               2'b01: dout = {24'b0, rd_word[15:8]};
               2'b10: dout = {24'b0, rd_word[23:16]};
               2'b11: dout = {24'b0, rd_word[31:24]};
            endcase
            // 有符号扩展
            if (DMType == `dm_byte)
               dout = {{24{dout[7]}}, dout[7:0]};
         end

         default: dout = rd_word;
      endcase
   end

   // === 写数据：按类型部分写入 ===
   always @(posedge clk) begin
      if (DMWr) begin
         $display("dmem[0x%8X] = 0x%8X,", addr, din);
         case (DMType)
            `dm_word: dmem[word_addr] <= din;

            `dm_halfword, `dm_halfword_unsigned: begin
               if (byte_off[1])
                  dmem[word_addr][31:16] <= din[15:0];
               else
                  dmem[word_addr][15:0]  <= din[15:0];
            end

            `dm_byte, `dm_byte_unsigned: begin
               case (byte_off)
                  2'b00: dmem[word_addr][7:0]   <= din[7:0];
                  2'b01: dmem[word_addr][15:8]  <= din[7:0];
                  2'b10: dmem[word_addr][23:16] <= din[7:0];
                  2'b11: dmem[word_addr][31:24] <= din[7:0];
               endcase
            end
         endcase
      end
   end

endmodule

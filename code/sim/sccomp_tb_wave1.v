// Wave 1 testbench — 测试新增 10 条指令 (ADDI,XORI,ANDI,SLLI,SRLI,SRAI,SLTI,SLTIU,JAL,JALR)
module sccomp_tb_wave1();

   reg  clk, rstn;
   reg  [4:0] reg_sel;
   wire [31:0] reg_data;

   sccomp U_SCCOMP(
      .clk(clk), .rstn(rstn), .reg_sel(reg_sel), .reg_data(reg_data)
   );

   integer foutput;
   integer counter;
   integer loop_count;  // 死循环检测计数

   initial begin
      $readmemh("Test_Wave1.dat", U_SCCOMP.U_IM.ROM);
      foutput = $fopen("results_wave1.txt");
      clk = 1;
      rstn = 1;
      counter = 0;
      loop_count = 0;
      #5;
      rstn = 0;
      #20;
      rstn = 1;
      #1000;
      reg_sel = 7;
   end

   // 检测死循环（beq x0,x0 自跳转，PC 连续相同）
   reg [31:0] prev_PC;

   always begin
      #(50) clk = ~clk;

      if (clk == 1'b1) begin
         // 超时保护
         if (counter >= 2000) begin
            $display("TIMEOUT: counter=%0d", counter);
            $fclose(foutput);
            $finish;
         end

         // 死循环检测：PC 连续相同 3 次 → 程序终止
         if (U_SCCOMP.PC == prev_PC && U_SCCOMP.PC > 32'h40) begin
            loop_count = loop_count + 1;
            if (loop_count >= 3) begin
               $display("Program terminated at PC=0x%08X", U_SCCOMP.PC);

               // 打印关键寄存器值
               $fdisplay(foutput, "=== Wave 1 测试结果 ===");
               $fdisplay(foutput, "PC: 0x%08X", U_SCCOMP.PC);
               $fdisplay(foutput, "x1  (0xFF):     0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[1],
                         U_SCCOMP.U_SCPU.U_RF.rf[1] == 32'h000000FF ? "OK" : "FAIL");
               $fdisplay(foutput, "x2  (0x100):    0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[2],
                         U_SCCOMP.U_SCPU.U_RF.rf[2] == 32'h00000100 ? "OK" : "FAIL");
               $fdisplay(foutput, "x4  (0x101):    0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[4],
                         U_SCCOMP.U_SCPU.U_RF.rf[4] == 32'h00000101 ? "OK" : "FAIL");
               $fdisplay(foutput, "x5  (0x7FF):    0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[5],
                         U_SCCOMP.U_SCPU.U_RF.rf[5] == 32'h000007FF ? "OK" : "FAIL");
               $fdisplay(foutput, "x6  (-1):       0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[6],
                         U_SCCOMP.U_SCPU.U_RF.rf[6] == 32'hFFFFFFFF ? "OK" : "FAIL");
               $fdisplay(foutput, "x7  (0x0F):     0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[7],
                         U_SCCOMP.U_SCPU.U_RF.rf[7] == 32'h0000000F ? "OK" : "FAIL");
               $fdisplay(foutput, "x8  (0x0F):     0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[8],
                         U_SCCOMP.U_SCPU.U_RF.rf[8] == 32'h0000000F ? "OK" : "FAIL");
               $fdisplay(foutput, "x9  (1):        0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[9],
                         U_SCCOMP.U_SCPU.U_RF.rf[9] == 32'h00000001 ? "OK" : "FAIL");
               $fdisplay(foutput, "x10 (1):        0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[10],
                         U_SCCOMP.U_SCPU.U_RF.rf[10] == 32'h00000001 ? "OK" : "FAIL");
               $fdisplay(foutput, "x11 (1):        0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[11],
                         U_SCCOMP.U_SCPU.U_RF.rf[11] == 32'h00000001 ? "OK" : "FAIL");
               $fdisplay(foutput, "x12 (0):        0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[12],
                         U_SCCOMP.U_SCPU.U_RF.rf[12] == 32'h00000000 ? "OK" : "FAIL");
               $fdisplay(foutput, "x13 (0x10):     0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[13],
                         U_SCCOMP.U_SCPU.U_RF.rf[13] == 32'h00000010 ? "OK" : "FAIL");
               $fdisplay(foutput, "x14 (0x80000000):0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[14],
                         U_SCCOMP.U_SCPU.U_RF.rf[14] == 32'h80000000 ? "OK" : "FAIL");
               $fdisplay(foutput, "x15 (0x08000000):0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[15],
                         U_SCCOMP.U_SCPU.U_RF.rf[15] == 32'h08000000 ? "OK" : "FAIL");
               $fdisplay(foutput, "x16 (1):        0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[16],
                         U_SCCOMP.U_SCPU.U_RF.rf[16] == 32'h00000001 ? "OK" : "FAIL");
               $fdisplay(foutput, "x17 (0xFFFF8000):0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[17],
                         U_SCCOMP.U_SCPU.U_RF.rf[17] == 32'hFFFF8000 ? "OK" : "FAIL");
               $fdisplay(foutput, "x18 (-1):       0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[18],
                         U_SCCOMP.U_SCPU.U_RF.rf[18] == 32'hFFFFFFFF ? "OK" : "FAIL");
               $fdisplay(foutput, "x19 (ra=0x4C):  0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[19],
                         U_SCCOMP.U_SCPU.U_RF.rf[19] == 32'h0000004C ? "OK" : "FAIL");
               $fdisplay(foutput, "x20 (42):       0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[20],
                         U_SCCOMP.U_SCPU.U_RF.rf[20] == 32'h0000002A ? "OK" : "FAIL");
               $fdisplay(foutput, "x21 (77):       0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[21],
                         U_SCCOMP.U_SCPU.U_RF.rf[21] == 32'h0000004D ? "OK" : "FAIL");
               $fdisplay(foutput, "x3  (1):        0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[3],
                         U_SCCOMP.U_SCPU.U_RF.rf[3] == 32'h00000001 ? "OK" : "FAIL");

               $fclose(foutput);
               #10 $finish;
            end
         end else begin
            loop_count = 0;
         end

         prev_PC = U_SCCOMP.PC;
         counter = counter + 1;
      end
   end

endmodule

// Wave 2 testbench — 测试新增 11 条指令 (LUI,AUIPC,BNE,BLT,BGE,BLTU,BGEU,SLL,SRL,SRA,XOR)
module sccomp_tb_wave2();

   reg  clk, rstn;
   reg  [4:0] reg_sel;
   wire [31:0] reg_data;

   sccomp U_SCCOMP(
      .clk(clk), .rstn(rstn), .reg_sel(reg_sel), .reg_data(reg_data)
   );

   integer foutput;
   integer counter, loop_count;
   reg [31:0] prev_PC;

   initial begin
      $readmemh("Test_Wave2.dat", U_SCCOMP.U_IM.ROM);
      foutput = $fopen("results_wave2.txt");
      clk = 1; rstn = 1; counter = 0; loop_count = 0;
      #5; rstn = 0;
      #20; rstn = 1;
   end

   always begin
      #(50) clk = ~clk;

      if (clk == 1'b1) begin
         if (counter >= 2000) begin
            $display("TIMEOUT");
            $fclose(foutput);
            $finish;
         end

         if (U_SCCOMP.PC == prev_PC && U_SCCOMP.PC > 32'h40) begin
            loop_count = loop_count + 1;
            if (loop_count >= 3) begin
               $display("Program done at PC=0x%08X", U_SCCOMP.PC);
               $fdisplay(foutput, "=== Wave 2 测试结果 ===");
               $fdisplay(foutput, "x1  LUI+ADDI  = 0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[1],
                         U_SCCOMP.U_SCPU.U_RF.rf[1] == 32'h12345678 ? "OK" : "FAIL");
               $fdisplay(foutput, "x3  AUIPC     = 0x%08X", U_SCCOMP.U_SCPU.U_RF.rf[3]);
               $fdisplay(foutput, "x8  SLL       = 0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[8],
                         U_SCCOMP.U_SCPU.U_RF.rf[8] == 32'h00000140 ? "OK" : "FAIL");
               $fdisplay(foutput, "x9  SRL       = 0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[9],
                         U_SCCOMP.U_SCPU.U_RF.rf[9] == 32'h04000000 ? "OK" : "FAIL");
               $fdisplay(foutput, "x10 SRA       = 0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[10],
                         U_SCCOMP.U_SCPU.U_RF.rf[10] == 32'hFC000000 ? "OK" : "FAIL");
               $fdisplay(foutput, "x11 XOR       = 0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[11],
                         U_SCCOMP.U_SCPU.U_RF.rf[11] == 32'h0000001E ? "OK" : "FAIL");
               $fdisplay(foutput, "x12 XOR self  = 0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[12],
                         U_SCCOMP.U_SCPU.U_RF.rf[12] == 32'h00000000 ? "OK" : "FAIL");
               $fdisplay(foutput, "x13 BNE       = 0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[13],
                         U_SCCOMP.U_SCPU.U_RF.rf[13] == 32'h00000001 ? "OK" : "FAIL");
               $fdisplay(foutput, "x14 BEQ(no)   = 0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[14],
                         U_SCCOMP.U_SCPU.U_RF.rf[14] == 32'h00000001 ? "OK" : "FAIL");
               $fdisplay(foutput, "x15 BLT       = 0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[15],
                         U_SCCOMP.U_SCPU.U_RF.rf[15] == 32'h00000002 ? "OK" : "FAIL");
               $fdisplay(foutput, "x16 BGE       = 0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[16],
                         U_SCCOMP.U_SCPU.U_RF.rf[16] == 32'h00000003 ? "OK" : "FAIL");
               $fdisplay(foutput, "x17 BLTU      = 0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[17],
                         U_SCCOMP.U_SCPU.U_RF.rf[17] == 32'h00000004 ? "OK" : "FAIL");
               $fdisplay(foutput, "x18 BGEU      = 0x%08X %s", U_SCCOMP.U_SCPU.U_RF.rf[18],
                         U_SCCOMP.U_SCPU.U_RF.rf[18] == 32'h00000005 ? "OK" : "FAIL");

               // 打印 DM 写入
               $fdisplay(foutput, "DM[0x00]=0x%08X %s", U_SCCOMP.U_DM.dmem[0],
                         U_SCCOMP.U_DM.dmem[0] == 32'h12345678 ? "OK" : "FAIL");
               $fdisplay(foutput, "DM[0x08]=0x%08X %s", U_SCCOMP.U_DM.dmem[2],
                         U_SCCOMP.U_DM.dmem[2] == 32'h00000140 ? "OK" : "FAIL");
               $fdisplay(foutput, "DM[0x14]=0x%08X %s", U_SCCOMP.U_DM.dmem[5],
                         U_SCCOMP.U_DM.dmem[5] == 32'h0000001E ? "OK" : "FAIL");

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

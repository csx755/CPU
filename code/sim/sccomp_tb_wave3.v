module sccomp_tb_wave3();
   reg clk, rstn;
   wire [31:0] reg_data, PC, instr;
   sccomp U_SCCOMP(.clk(clk), .rstn(rstn), .reg_sel(5'b0), .reg_data(reg_data), .PC(PC), .instr(instr));
   integer fp, cnt, lc;
   reg [31:0] prev_PC;
   initial begin
      $readmemh("Test_Wave3.dat", U_SCCOMP.U_IM.ROM);
      fp = $fopen("results_wave3.txt");
      clk=1; rstn=1; cnt=0; lc=0;
      #5; rstn=0; #20; rstn=1;
   end
   always begin
      #50 clk=~clk;
      if (clk==1'b1) begin
         if (cnt>=2000) begin $display("TIMEOUT"); $fclose(fp); $finish; end
         if (PC==prev_PC && PC>32'd64) begin
            lc=lc+1;
            if (lc>=3) begin
               $display("Done PC=%h", PC);
               $fdisplay(fp, "=== Wave 3 ===");
               $fdisplay(fp, "x8  SLT  =%d %s", U_SCCOMP.U_SCPU.U_RF.rf[8],  U_SCCOMP.U_SCPU.U_RF.rf[8]==1?"OK":"FAIL");
               $fdisplay(fp, "x9  SLT  =%d %s", U_SCCOMP.U_SCPU.U_RF.rf[9],  U_SCCOMP.U_SCPU.U_RF.rf[9]==0?"OK":"FAIL");
               $fdisplay(fp, "x10 SLT  =%d %s", U_SCCOMP.U_SCPU.U_RF.rf[10], U_SCCOMP.U_SCPU.U_RF.rf[10]==1?"OK":"FAIL");
               $fdisplay(fp, "x11 SLTU =%d %s", U_SCCOMP.U_SCPU.U_RF.rf[11], U_SCCOMP.U_SCPU.U_RF.rf[11]==1?"OK":"FAIL");
               $fdisplay(fp, "x12 SLTU =%d %s", U_SCCOMP.U_SCPU.U_RF.rf[12], U_SCCOMP.U_SCPU.U_RF.rf[12]==0?"OK":"FAIL");
               $fdisplay(fp, "x13 LB+  =%h %s", U_SCCOMP.U_SCPU.U_RF.rf[13], U_SCCOMP.U_SCPU.U_RF.rf[13]==120?"OK":"FAIL");
               $fdisplay(fp, "x14 LB-  =%h %s", U_SCCOMP.U_SCPU.U_RF.rf[14], $signed(U_SCCOMP.U_SCPU.U_RF.rf[14])==-85?"OK":"FAIL");
               $fdisplay(fp, "x15 LB-2 =%h %s", U_SCCOMP.U_SCPU.U_RF.rf[15], $signed(U_SCCOMP.U_SCPU.U_RF.rf[15])==-1?"OK":"FAIL");
               $fdisplay(fp, "x16 LBU  =%h %s", U_SCCOMP.U_SCPU.U_RF.rf[16], U_SCCOMP.U_SCPU.U_RF.rf[16]==171?"OK":"FAIL");
               $fdisplay(fp, "x17 LBU+ =%h %s", U_SCCOMP.U_SCPU.U_RF.rf[17], U_SCCOMP.U_SCPU.U_RF.rf[17]==120?"OK":"FAIL");
               $fdisplay(fp, "x18 LH+  =%h %s", U_SCCOMP.U_SCPU.U_RF.rf[18], U_SCCOMP.U_SCPU.U_RF.rf[18]==564?"OK":"FAIL");
               $fdisplay(fp, "x19 LH-  =%h %s", U_SCCOMP.U_SCPU.U_RF.rf[19], $signed(U_SCCOMP.U_SCPU.U_RF.rf[19])==-85?"OK":"FAIL");
               $fdisplay(fp, "x20 LHU  =%h %s", U_SCCOMP.U_SCPU.U_RF.rf[20], U_SCCOMP.U_SCPU.U_RF.rf[20]==65451?"OK":"FAIL");
               $fdisplay(fp, "x21 LHU+ =%h %s", U_SCCOMP.U_SCPU.U_RF.rf[21], U_SCCOMP.U_SCPU.U_RF.rf[21]==564?"OK":"FAIL");
               $fdisplay(fp, "x23 SB   =%h %s", U_SCCOMP.U_SCPU.U_RF.rf[23], U_SCCOMP.U_SCPU.U_RF.rf[23]==165?"OK":"FAIL");
               $fdisplay(fp, "x25 SH   =%h %s", U_SCCOMP.U_SCPU.U_RF.rf[25], U_SCCOMP.U_SCPU.U_RF.rf[25]==2031?"OK":"FAIL");
               $fclose(fp); #10 $finish;
            end
         end else lc=0;
         prev_PC = PC; cnt=cnt+1;
      end
   end
endmodule

module dbg_tb();
   reg clk, rstn;
   reg [4:0] reg_sel;
   wire [31:0] reg_data;
   sccomp U_SCCOMP(.clk(clk), .rstn(rstn), .reg_sel(reg_sel), .reg_data(reg_data));

   integer cnt;
   initial begin
      $readmemh("Test_Wave2.dat", U_SCCOMP.U_IM.ROM);
      clk=1; rstn=1; cnt=0;
      #5; rstn=0; #20; rstn=1;
   end

   always begin
      #50 clk=~clk;
      if (clk==1'b1) begin
         cnt=cnt+1;
         // 在分支指令执行周期打印信号
         if (U_SCCOMP.PC >= 32'h30 && U_SCCOMP.PC <= 32'h74) begin
            $display("t=%0t PC=%h instr=%h ALUOp=%b Zero=%d NPCOp=%b",
                     $time, U_SCCOMP.PC, U_SCCOMP.instr,
                     U_SCCOMP.U_SCPU.U_ctrl.ALUOp,
                     U_SCCOMP.U_SCPU.U_alu.Zero,
                     U_SCCOMP.U_SCPU.U_ctrl.NPCOp);
            $display("  RD1=%h RD2=%h immout=%h NPCgo=%h",
                     U_SCCOMP.U_SCPU.U_RF.RD1,
                     U_SCCOMP.U_SCPU.U_RF.RD2,
                     U_SCCOMP.U_SCPU.immout,
                     U_SCCOMP.U_SCPU.NPC);
         end
         if (cnt>35) $finish;
      end
   end
endmodule

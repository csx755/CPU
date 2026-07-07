module debug_tb();
   reg clk, rstn;
   reg [4:0] reg_sel;
   wire [31:0] reg_data;
   sccomp U_SCCOMP(.clk(clk), .rstn(rstn), .reg_sel(reg_sel), .reg_data(reg_data));
   integer counter;
   initial begin
      $readmemh("Test_Wave2.dat", U_SCCOMP.U_IM.ROM);
      clk=1; rstn=1; counter=0;
      #5; rstn=0; #20; rstn=1;
   end
   always begin
      #50 clk=~clk;
      if (clk==1'b1) begin
         counter=counter+1;
         if (counter>30) begin $finish; end
         // BNE at 0x34: dump ALUOp
         if (U_SCCOMP.PC >= 32'h30 && U_SCCOMP.PC <= 32'h40) begin
            $display("t=%0t PC=0x%h instr=0x%h ALUOp=%b Zero=%b NPCOp=%b NPC=%h",
                     $time, U_SCCOMP.PC, U_SCCOMP.instr,
                     U_SCCOMP.U_SCPU.U_ctrl.ALUOp,
                     U_SCCOMP.U_SCPU.U_alu.Zero,
                     U_SCCOMP.U_SCPU.U_ctrl.NPCOp,
                     U_SCCOMP.U_SCPU.NPC);
            $display("  i_beq=%b i_bne=%b i_blt=%b i_bge=%b i_bltu=%b i_bgeu=%b sbtype=%b regw=%b",
                     U_SCCOMP.U_SCPU.U_ctrl.i_beq,
                     U_SCCOMP.U_SCPU.U_ctrl.i_bne,
                     U_SCCOMP.U_SCPU.U_ctrl.i_blt,
                     U_SCCOMP.U_SCPU.U_ctrl.i_bge,
                     U_SCCOMP.U_SCPU.U_ctrl.i_bltu,
                     U_SCCOMP.U_SCPU.U_ctrl.i_bgeu,
                     U_SCCOMP.U_SCPU.U_ctrl.sbtype,
                     U_SCCOMP.U_SCPU.U_ctrl.RegWrite);
         end
      end
   end
endmodule

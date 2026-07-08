// sccomp_pipelined — 流水线 CPU 验证顶层 (SCPU_pipelined + DM + IM)
// 与单周期 sccomp.v 接口一致, 用于 Vivado 综合 / 独立仿真
module sccomp_pipelined(clk, rstn, reg_sel, reg_data, PC, instr);
   input          clk;
   input          rstn;
   input [4:0]    reg_sel;
   output [31:0]  reg_data;
   output [31:0]  PC;
   output [31:0]  instr;

   wire rst = ~rstn;

   wire        MemWrite;
   wire [31:0] dm_addr, dm_din, dm_dout;
   wire [2:0]  dm_type;

   // 流水线 CPU
   SCPU_pipelined U_SCPU(
       .clk(clk), .reset(rst),
       .MIO_ready(1'b1),             // 独立模式: 总线始终就绪
       .inst_in(instr),              // 取自 IM
       .Data_in(dm_dout),            // 取自 DM
       .INT(1'b0),
       .mem_w(MemWrite),
       .CPU_MIO(),
       .PC_out(PC),
       .Addr_out(dm_addr),
       .Data_out(dm_din),
       .dm_ctrl(dm_type),
       .reg_sel(reg_sel),
       .reg_data(reg_data)
   );

   // 数据存储器 (复用单周期 dm.v)
   dm U_DM(
       .clk(clk),
       .DMWr(MemWrite),
       .addr(dm_addr[8:0]),         // 字节地址, 低 9 位
       .din(dm_din),
       .dout(dm_dout),
       .DMType(dm_type)
   );

   // 指令存储器 (用于仿真, 综合时会被 ROM IP 替换)
   im U_IM(
       .addr(PC[8:2]),              // 字地址
       .dout(instr)
   );

endmodule

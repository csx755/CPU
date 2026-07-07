module sccomp(clk, rstn, reg_sel, reg_data, PC, instr);
   input          clk;
   input          rstn;
   input [4:0]    reg_sel;
   output [31:0]  reg_data;
   output [31:0]  PC;
   output [31:0]  instr;

   wire           MemWrite;
   wire [31:0]    dm_addr, dm_din, dm_dout;
   wire [2:0]     dm_type;

   wire rst = ~rstn;

  // instantiation of single-cycle CPU
   SCPU U_SCPU(
         .clk(clk),                  // input:  cpu clock
         .reset(rst),                // input:  reset
         .MIO_ready(1'b1),           // input:  bus always ready (standalone)
         .inst_in(instr),            // input:  instruction
         .Data_in(dm_dout),          // input:  data to cpu
         .mem_w(MemWrite),           // output: memory write signal
         .CPU_MIO(),                 // output: bus request (unused standalone)
         .PC_out(PC),                // output: PC
         .Addr_out(dm_addr),         // output: address from cpu to memory
         .Data_out(dm_din),          // output: data from cpu to memory
         .dm_ctrl(dm_type),          // output: memory access type
         .reg_sel(reg_sel),          // input:  register selection (debug)
         .reg_data(reg_data)         // output: register data (debug)
         );

  // instantiation of data memory
   dm    U_DM(
         .clk(clk),                  // input:  cpu clock
         .DMWr(MemWrite),            // input:  ram write
         .addr(dm_addr[8:0]),        // input:  byte address (Wave 3)
         .din(dm_din),               // input:  data to ram
         .dout(dm_dout),             // output: data from ram
         .DMType(dm_type)            // input:  access type (Wave 3)
         );

  // instantiation of instruction memory (used for simulation)
   im    U_IM (
      .addr(PC[8:2]),                // input:  rom word address
      .dout(instr)                   // output: instruction
   );

endmodule

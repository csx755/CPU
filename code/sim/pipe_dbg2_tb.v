// Minimal debug: print pipeline stage per cycle
`timescale 1ns / 1ps

module pipe_dbg2_tb();
    reg clk, rst;
    wire [31:0] inst_in, Data_in;
    wire mem_w;
    wire [31:0] PC, Addr_out, Data_out;
    wire [2:0] dm_ctrl;

    SCPU_pipelined U_P (.clk(clk),.reset(rst),.MIO_ready(1'b1),
        .inst_in(inst_in),.Data_in(Data_in),.INT(1'b0),
        .mem_w(mem_w),.CPU_MIO(),.PC_out(PC),.Addr_out(Addr_out),
        .Data_out(Data_out),.dm_ctrl(dm_ctrl),
        .reg_sel(5'd0),.reg_data());

    dm U_DM (.clk(clk),.DMWr(mem_w),
        .addr(Addr_out[8:0]),.din(Data_out),
        .dout(Data_in),.DMType(dm_ctrl));

    reg [31:0] rom [0:31];
    integer i;
    initial begin
        for (i=0;i<32;i=i+1) rom[i]=32'h00000013; // NOP
        rom[0]=32'h00500113; // addi x2,x0,5
        rom[1]=32'h00500193; // addi x3,x0,5
        rom[2]=32'h00310663; // beq  x2,x3,+12 (skip rom[3,4])
        rom[3]=32'h06300113; // addi x2,x0,99 (flushed)
        rom[4]=32'h00202023; // sw   x2,0(x0) (flushed)
        rom[5]=32'h00100113; // addi x2,x0,1  (target)
        rom[6]=32'h00202023; // sw   x2,0(x0) (DM[0]=1)
        rom[7]=32'h0000006f; // jal  x0,0    (halt)
    end
    assign inst_in = rom[PC[8:2]];

    always #50 clk = ~clk;

    // Print pipeline stage instruction addresses
    integer tick;
    always @(negedge clk) begin
        if (!rst) begin
            tick = tick + 1;
            // Grep relevant fields from pipeline registers
            $display("[%0d neg] IF=%08X ID=%08X EX=%08X MEM=%08X WB=%08X | "
                     , tick,
                U_P.IF_ID_out[63:32],       // ID_instruction
                U_P.ID_EX_out,              // raw ID_EX (shows what's in this stage)
                U_P.EX_MEM_out,             // raw EX_MEM
                U_P.MEM_WB_out,             // raw MEM_WB
                32'h0                       // WB not stored as instruction
            );
        end
    end

    initial begin
        clk=0; rst=1; tick=0;
        #200 rst=0;
        repeat(15) @(negedge clk);
        $display("DM[0]=%08X", U_DM.dmem[0]);
        $finish;
    end
endmodule

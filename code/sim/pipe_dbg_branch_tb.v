// pipe_dbg_branch_tb — 调试 Branch flush
`timescale 1ns / 1ps

module pipe_dbg_branch_tb();

    reg clk, rst;
    wire [31:0] inst_in, Data_in;
    wire mem_w, ex_taken, id_is_jal, load_use;
    wire if_id_flush, id_ex_flush;
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

    assign ex_taken = U_P.EX_taken;
    assign id_is_jal = U_P.ID_is_JAL;
    assign load_use = U_P.load_use_hazard;
    assign if_id_flush = U_P.IF_ID_flush;
    assign id_ex_flush = U_P.ID_EX_flush;

    reg [31:0] rom [0:31];
    integer i;
    initial begin
        for (i=0;i<32;i=i+1) rom[i]=32'h00000013; // NOP
        rom[0] = 32'h00500113;  // addi x2, x0, 5     → sp=5
        rom[1] = 32'h00500193;  // addi x3, x0, 5     → gp=5
        rom[2] = 32'h00310663;  // beq  x2, x3, +12   → TAKEN (5==5), skip 3
        rom[3] = 32'h06300113;  // addi x2, x0, 99    → FLUSHED
        rom[4] = 32'h00202023;  // sw   x2, 0(x0)     → FLUSHED (would write 99)
        rom[5] = 32'h00100113;  // addi x2, x0, 1     → sp=1 (target)
        rom[6] = 32'h00202023;  // sw   x2, 0(x0)     → DM[0]=1
        rom[7] = 32'h0000006f;  // jal  x0, 0          → halt
    end
    assign inst_in = rom[PC[8:2]];

    always #50 clk = ~clk;

    integer tick;
    initial begin
        clk=0; rst=1; tick=0;
        #200 rst=0;
        $display("=== Branch Flush Debug ===");
        $display("Tk | PC       | Inst    | EX_tkn | JAL | Stall| F_flush| D_flush| Addr/Data");
        repeat(25) begin
            @(posedge clk);
            tick = tick + 1;
            if (mem_w)
                $display("%2d | %08X | %08X | %b      | %b   | %b    | %b      | %b      | W: A=%08X D=%08X",
                    tick, PC, inst_in, ex_taken, id_is_jal, load_use, if_id_flush, id_ex_flush,
                    Addr_out, Data_out);
            else
                $display("%2d | %08X | %08X | %b      | %b   | %b    | %b      | %b      | -",
                    tick, PC, inst_in, ex_taken, id_is_jal, load_use, if_id_flush, id_ex_flush);
        end
        $display("DM[0] = %08X (expect 1)", U_DM.dmem[0]);
        $finish;
    end

endmodule

// compare_tb — 单周期 vs 流水线 DM 输出精确对比 (各自独立取指)
`timescale 1ns / 1ps

module compare_tb();

    reg clk, rst;
    wire [31:0] inst_in_s, inst_in_p;
    wire [31:0] Data_in_s, Data_in_p;
    wire mem_w_s, mem_w_p;
    wire [31:0] PC_s, PC_p, Addr_s, Addr_p, Dout_s, Dout_p;
    wire [2:0] dm_s, dm_p;

    SCPU U_S (.clk(clk),.reset(rst),.MIO_ready(1'b1),
        .inst_in(inst_in_s),.Data_in(Data_in_s),.INT(1'b0),
        .mem_w(mem_w_s),.CPU_MIO(),.PC_out(PC_s),.Addr_out(Addr_s),
        .Data_out(Dout_s),.dm_ctrl(dm_s),.reg_sel(5'd0),.reg_data());

    dm U_DM_S (.clk(clk),.DMWr(mem_w_s),.addr(Addr_s[8:0]),
        .din(Dout_s),.dout(Data_in_s),.DMType(dm_s));

    SCPU_pipelined U_P (.clk(clk),.reset(rst),.MIO_ready(1'b1),
        .inst_in(inst_in_p),.Data_in(Data_in_p),.INT(1'b0),
        .mem_w(mem_w_p),.CPU_MIO(),.PC_out(PC_p),.Addr_out(Addr_p),
        .Data_out(Dout_p),.dm_ctrl(dm_p),.reg_sel(5'd0),.reg_data());

    dm U_DM_P (.clk(clk),.DMWr(mem_w_p),.addr(Addr_p[8:0]),
        .din(Dout_p),.dout(Data_in_p),.DMType(dm_p));

    // 两个独立 ROM (运行同一程序)
    reg [31:0] rom_s [0:255], rom_p [0:255];
    integer i;
    initial begin
        for (i=0; i<256; i=i+1) begin rom_s[i]=0; rom_p[i]=0; end
        rom_s[0]=32'h43506293; rom_p[0]=32'h43506293;
        rom_s[1]=32'h00001337; rom_p[1]=32'h00001337;
        rom_s[2]=32'h0062e2b3; rom_p[2]=32'h0062e2b3;
        rom_s[3]=32'h98765337; rom_p[3]=32'h98765337;
        rom_s[4]=32'h57828393; rom_p[4]=32'h57828393;
        rom_s[5]=32'hc0030413; rom_p[5]=32'hc0030413;
        rom_s[6]=32'h7bc2c493; rom_p[6]=32'h7bc2c493;
        rom_s[7]=32'h0193b193; rom_p[7]=32'h0193b193;
        rom_s[8]=32'hfff2b213; rom_p[8]=32'hfff2b213;
        rom_s[9]=32'h7654f913; rom_p[9]=32'h7654f913;
        rom_s[10]=32'h12332a13; rom_p[10]=32'h12332a13;
        rom_s[11]=32'h405309b3; rom_p[11]=32'h405309b3;
        rom_s[12]=32'h006a4ab3; rom_p[12]=32'h006a4ab3;
        rom_s[13]=32'h014a8b33; rom_p[13]=32'h014a8b33;
        rom_s[14]=32'h005b0b33; rom_p[14]=32'h005b0b33;
        rom_s[15]=32'h406b0bb3; rom_p[15]=32'h406b0bb3;
        rom_s[16]=32'h016becb3; rom_p[16]=32'h016becb3;
        rom_s[17]=32'h016bfd33; rom_p[17]=32'h016bfd33;
        rom_s[18]=32'h01acadb3; rom_p[18]=32'h01acadb3;
        rom_s[19]=32'h01acbe33; rom_p[19]=32'h01acbe33;
        rom_s[20]=32'h00418193; rom_p[20]=32'h00418193;
        rom_s[21]=32'h003d1db3; rom_p[21]=32'h003d1db3;
        rom_s[22]=32'h003cde33; rom_p[22]=32'h003cde33;
        rom_s[23]=32'h403cdeb3; rom_p[23]=32'h403cdeb3;
        rom_s[24]=32'h01899d93; rom_p[24]=32'h01899d93;
        rom_s[25]=32'h0049de13; rom_p[25]=32'h0049de13;
        rom_s[26]=32'h4049de93; rom_p[26]=32'h4049de93;
        rom_s[27]=32'h00000193; rom_p[27]=32'h00000193;
        rom_s[28]=32'h0ef00293; rom_p[28]=32'h0ef00293;
        rom_s[29]=32'h0131a023; rom_p[29]=32'h0131a023;
        rom_s[30]=32'h0151a223; rom_p[30]=32'h0151a223;
        rom_s[31]=32'h0171a423; rom_p[31]=32'h0171a423;
        rom_s[32]=32'h01a19223; rom_p[32]=32'h01a19223;
        rom_s[33]=32'h01319523; rom_p[33]=32'h01319523;
        rom_s[34]=32'h005183a3; rom_p[34]=32'h005183a3;
        rom_s[35]=32'h005184a3; rom_p[35]=32'h005184a3;
        rom_s[36]=32'h00518423; rom_p[36]=32'h00518423;
        rom_s[37]=32'h0001a283; rom_p[37]=32'h0001a283;
        rom_s[38]=32'h0051a623; rom_p[38]=32'h0051a623;
        rom_s[39]=32'h00219383; rom_p[39]=32'h00219383;
        rom_s[40]=32'h0071a823; rom_p[40]=32'h0071a823;
        rom_s[41]=32'h0021d383; rom_p[41]=32'h0021d383;
        rom_s[42]=32'h0071aa23; rom_p[42]=32'h0071aa23;
        rom_s[43]=32'h00318403; rom_p[43]=32'h00318403;
        rom_s[44]=32'h0081ac23; rom_p[44]=32'h0081ac23;
        rom_s[45]=32'h0031c403; rom_p[45]=32'h0031c403;
        rom_s[46]=32'h0081ae23; rom_p[46]=32'h0081ae23;
        rom_s[47]=32'h0011c403; rom_p[47]=32'h0011c403;
        rom_s[48]=32'h0281a023; rom_p[48]=32'h0281a023;
        rom_s[49]=32'h0001a023; rom_p[49]=32'h0001a023;
        rom_s[50]=32'h009074b3; rom_p[50]=32'h009074b3;
        rom_s[51]=32'h00729463; rom_p[51]=32'h00729463;
        rom_s[52]=32'h00248493; rom_p[52]=32'h00248493;
        rom_s[53]=32'h0072d463; rom_p[53]=32'h0072d463;
        rom_s[54]=32'h00748493; rom_p[54]=32'h00748493;
        rom_s[55]=32'h0072f463; rom_p[55]=32'h0072f463;
        rom_s[56]=32'h00548493; rom_p[56]=32'h00548493;
        rom_s[57]=32'h0072c463; rom_p[57]=32'h0072c463;
        rom_s[58]=32'h00348493; rom_p[58]=32'h00348493;
        rom_s[59]=32'h0072e063; rom_p[59]=32'h0072e063;
        rom_s[60]=32'h00648493; rom_p[60]=32'h00648493;
        rom_s[61]=32'h00838463; rom_p[61]=32'h00838463;
        rom_s[62]=32'h00148493; rom_p[62]=32'h00148493;
        rom_s[63]=32'h0091a023; rom_p[63]=32'h0091a023;
        rom_s[64]=32'h0001a503; rom_p[64]=32'h0001a503;
        rom_s[65]=32'h00c000ef; rom_p[65]=32'h00c000ef;
        rom_s[66]=32'h00350513; rom_p[66]=32'h00350513;
        rom_s[67]=32'h00a1a023; rom_p[67]=32'h00a1a023;
        rom_s[68]=32'h7a156513; rom_p[68]=32'h7a156513;
        rom_s[69]=32'h00a1a023; rom_p[69]=32'h00a1a023;
        rom_s[70]=32'h00008067; rom_p[70]=32'h00008067;
    end
    assign inst_in_s = rom_s[PC_s[8:2]];
    assign inst_in_p = rom_p[PC_p[8:2]];

    always #50 clk = ~clk;

    integer tick, errors;
    initial begin
        clk=0; rst=1; tick=0; errors=0;
        #200 rst=0;
        $display("=== Single vs Pipeline (independent fetch) ===");

        repeat(400) @(posedge clk);

        $display("PC: single=%08X  pipe=%08X", PC_s, PC_p);
        for (i=0; i<32; i=i+1) begin
            if (U_DM_S.dmem[i] !== U_DM_P.dmem[i]) begin
                $display("[MISMATCH] DM[%0d] S=%08X P=%08X",
                    i, U_DM_S.dmem[i], U_DM_P.dmem[i]);
                errors = errors + 1;
            end else if (U_DM_S.dmem[i] != 0)
                $display("[MATCH]    DM[%0d] = %08X", i, U_DM_S.dmem[i]);
        end

        if (errors==0) $display("\n=== ALL %0d DM locations MATCH ===", i);
        else $display("\n=== %0d MISMATCHES ===", errors);
        $finish;
    end

endmodule

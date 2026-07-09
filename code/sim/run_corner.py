#!/usr/bin/env python3
"""Run all corner case tests and produce report."""
import os, subprocess, sys

SIM = "d:/Desktop/study_computer/vivado/code/sim"
RTL = "d:/Desktop/study_computer/vivado/code/rtl"
RTLFL = " ".join(f'"{RTL}/{f}"' for f in
    ["ctrl_encode_def.v","alu.v","ctrl.v","EXT.v","PC.v","RF.v",
     "dm.v","GRE_array.v","Forwarding_Unit.v","Hazard_Unit.v","SCPU_pipelined.v"])

os.chdir(SIM)

def run_test(dat, check, maxc=200, pc_trigger=None, hold_cycles=1):
    """Create and run a testbench. If pc_trigger, fire INT when IF_PC matches."""
    if pc_trigger is not None:
        int_code = f'''
        if(!done && IF_PC==={pc_trigger}) begin INT_sig<=1; end
        if(!done && cyc>{pc_trigger//4+5} && INT_sig) INT_sig<=0;
'''
    else:
        int_code = ''

    tb = f'''`timescale 1ns / 1ps
module tb();
    reg clk,rst,INT_sig;
    wire[31:0] inst_in,Data_in; wire mem_w;
    wire[31:0] PC,Addr_out,Data_out; wire[2:0] dm_ctrl;
    wire[31:0] IF_PC = U_P.IF_PC;
    SCPU_pipelined U_P(.clk(clk),.reset(rst),.MIO_ready(1'b1),.inst_in(inst_in),.Data_in(Data_in),.INT(INT_sig),.mem_w(mem_w),.CPU_MIO(),.PC_out(PC),.Addr_out(Addr_out),.Data_out(Data_out),.dm_ctrl(dm_ctrl),.reg_sel(5'd0),.reg_data());
    reg[31:0] rom[0:1023]; initial $readmemh("{dat}",rom);
    assign inst_in=rom[PC[11:2]]; dm U_DM(.clk(clk),.DMWr(mem_w),.addr(Addr_out[8:0]),.din(Data_out),.dout(Data_in),.DMType(dm_ctrl));
    always #50 clk=~clk; integer cyc; reg done;
    initial begin clk=0;rst=1;INT_sig=0;cyc=0;done=0;repeat(10)@(posedge clk);@(negedge clk);rst=0;end
    always@(posedge clk) if(!rst) begin cyc<=cyc+1; {int_code}
        if(cyc>{maxc}&&!done) begin done=1; {check} $finish; end end
endmodule
'''
    tb_file = f"_tb_cor_{dat.replace('.dat','')}.v"
    with open(tb_file, 'w') as f: f.write(tb)

    r = os.system(f'iverilog -o _s_{dat.replace(".dat","")} -I "{RTL}" {RTLFL} {tb_file} 2>&1')
    if r != 0: return "COMPILE_FAIL"

    out = os.popen(f'vvp -n _s_{dat.replace(".dat","")}').read()
    if "PASS" in out:
        for l in out.split('\n'):
            if "PASS" in l: return l.strip()
        return "PASS"
    elif "FAIL" in out:
        for l in out.split('\n'):
            if "FAIL" in l: return l.strip()
        return "FAIL"
    return "TIMEOUT"

# Test definitions: (dat, check, maxc, pc_trigger, description)
TESTS = [
    ("cor_011.dat", 'if(U_DM.dmem[0]===32\'h1234)$display("PASS COR-011");else $display("FAIL COR-011 DM0=%h",U_DM.dmem[0]);', 100),
    ("regr_002.dat", 'if(U_DM.dmem[0]===8)$display("PASS REGR-002");else $display("FAIL REGR-002");', 100),
]

for dat, check, maxc in TESTS:
    r = run_test(dat, check, maxc)
    print(f"  {r}")

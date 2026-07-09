#!/usr/bin/env python3
"""Run ALL interrupt extension tests and produce report."""
import os, time, subprocess

SIM = "d:/Desktop/study_computer/vivado/code/sim"
RTL = "d:/Desktop/study_computer/vivado/code/rtl"
RTL_FILES = [f"{RTL}/{f}" for f in [
    "ctrl_encode_def.v","alu.v","ctrl.v","EXT.v","PC.v","RF.v",
    "dm.v","GRE_array.v","Forwarding_Unit.v","Hazard_Unit.v","SCPU_pipelined.v"]]
RTL_FL = " ".join(f'"{f}"' for f in RTL_FILES)

def make_tb(dat, check, maxc=200, int_pc=None):
    int_trig = ""
    if int_pc is not None:
        int_trig = f'if(cyc==30) INT_sig<=1; if(cyc==31) INT_sig<=0;'
    return f'''`timescale 1ns / 1ps
module tb();
    reg clk,rst,INT_sig;
    wire[31:0] inst_in,Data_in; wire mem_w;
    wire[31:0] PC,Addr_out,Data_out; wire[2:0] dm_ctrl;
    SCPU_pipelined U_P(.clk(clk),.reset(rst),.MIO_ready(1'b1),.inst_in(inst_in),.Data_in(Data_in),.INT(INT_sig),.mem_w(mem_w),.CPU_MIO(),.PC_out(PC),.Addr_out(Addr_out),.Data_out(Data_out),.dm_ctrl(dm_ctrl),.reg_sel(5'd0),.reg_data());
    reg[31:0] rom[0:1023]; initial $readmemh("{dat}",rom);
    assign inst_in=rom[PC[11:2]];
    dm U_DM(.clk(clk),.DMWr(mem_w),.addr(Addr_out[8:0]),.din(Data_out),.dout(Data_in),.DMType(dm_ctrl));
    always #50 clk=~clk; integer cyc; reg done;
    initial begin clk=0;rst=1;INT_sig=0;cyc=0;done=0;repeat(10)@(posedge clk);@(negedge clk);rst=0;$display("=== {dat} ===");end
    always@(posedge clk) if(!rst) begin cyc<=cyc+1;
    {int_trig}
    if(cyc>{maxc}&&!done) begin done=1; {check} $finish; end end
endmodule
'''

TESTS = [
    ("csr_001.dat", 'if(U_DM.dmem[0]===0&&U_DM.dmem[1]===8)$display("PASS");else $display("FAIL");'),
    ("csr_003.dat", 'if(U_DM.dmem[0]===8)$display("PASS");else $display("FAIL");'),
    ("mret_001.dat", 'if(U_DM.dmem[0]===4660)$display("PASS");else $display("FAIL DM=%h",U_DM.dmem[0]);', 150),
    ("mret_002.dat", 'if(U_DM.dmem[0]===8)$display("PASS");else $display("FAIL DM=%h",U_DM.dmem[0]);'),
    ("int_001.dat", 'if(U_DM.dmem[10]===2147483659&&U_DM.dmem[12]===292)$display("PASS");else $display("FAIL",U_DM.dmem[10],U_DM.dmem[12]);', 300, 1),
    ("cor_010.dat", 'if(U_DM.dmem[0]===8)$display("PASS");else $display("FAIL");'),
    ("cor_014.dat", 'if((U_DM.dmem[0]&8)&&!(U_DM.dmem[1]&8))$display("PASS");else $display("FAIL",U_DM.dmem[0],U_DM.dmem[1]);'),
    ("cor_015.dat", 'if(U_DM.dmem[0]===0&&U_DM.dmem[1]===0)$display("PASS");else $display("FAIL");'),
    ("neg_001.dat", 'if(U_DM.dmem[4]===291)$display("PASS");else $display("FAIL");'),
    ("neg_002.dat", 'if(U_DM.dmem[4]===291)$display("PASS");else $display("FAIL");', 300),
    ("neg_003.dat", 'if(U_DM.dmem[0]===0)$display("PASS");else $display("FAIL",U_DM.dmem[0]);'),
    ("neg_004.dat", 'if(U_DM.dmem[0]===4660)$display("PASS");else $display("FAIL",U_DM.dmem[0]);', 150),
    ("neg_005.dat", 'if(U_DM.dmem[10]===2147483659)$display("PASS");else $display("FAIL");', 300, 1),
]

os.chdir(SIM)
results = []

for t in TESTS:
    dat, check = t[0], t[1]
    maxc = t[2] if len(t) > 2 else 150
    intpc = t[3] if len(t) > 3 else None

    tb_code = make_tb(dat, check, maxc, intpc)
    tb_name = f"_tb_{dat.replace('.dat','')}.v"
    with open(tb_name, 'w') as f: f.write(tb_code)

    compile_cmd = f'iverilog -o _sim_{dat.replace(".dat","")} -I "{RTL}" {RTL_FL} {tb_name}'
    rc = os.system(compile_cmd + " 2>&1")
    if rc != 0:
        results.append((dat, "COMPILE FAIL"))
        continue

    start = time.time()
    r = os.popen(f'vvp -n _sim_{dat.replace(".dat","")}').read()
    elapsed = time.time() - start

    if "PASS" in r: results.append((dat, "PASS"))
    else:
        fail_line = ""
        for line in r.split('\n'):
            if "FAIL" in line: fail_line = line.strip(); break
        results.append((dat, fail_line or "FAIL (no PASS)"))

    print(f"  {dat}: {results[-1][1]} ({elapsed:.1f}s)")

print(f"""
========================================
 INTERRUPT CONTROLLER VERIFICATION REPORT
========================================""")
passed = sum(1 for _, r in results if r == "PASS")
failed = sum(1 for _, r in results if r != "PASS")
print(f"Total : {len(results)}  Pass : {passed}  Fail : {failed}")
print()
for n, r in results:
    tag = "OK" if r == "PASS" else "FAIL"
    print(f"  [{tag}] {n}: {r}")
if failed:
    print(f"\n❌ {failed} FAILURES")
else:
    print(f"\n✅ ALL {passed} TESTS PASSED")

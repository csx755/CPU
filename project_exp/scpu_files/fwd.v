`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/07/07 15:59:18
// Design Name: 
// Module Name: fwd
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fwd(
    input RegWrite_MEM,
    input [4:0] rd_MEM,
    input RegWrite_WB,
    input [4:0] rd_WB,
    input [4:0] rs1_EX,
    input [4:0] rs2_EX,
    output [1:0] ForwardA,
    output [1:0] ForwardB
    );
    wire MEM_A;
    assign MEM_A=~(|(rd_MEM^rs1_EX))&RegWrite_MEM;
    wire WB_A;
    assign WB_A=~(|(rd_WB^rs1_EX))&RegWrite_WB&~MEM_A;
    assign ForwardA={MEM_A,WB_A};
    wire MEM_B;
    assign MEM_B=~(|(rd_MEM^rs2_EX))&RegWrite_MEM;
    wire WB_B;
    assign WB_B=~(|(rd_WB^rs2_EX))&RegWrite_WB&~MEM_B;
    assign ForwardB={MEM_B,WB_B};
endmodule

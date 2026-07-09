`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/07/07 14:52:18
// Design Name: 
// Module Name: GRE_array
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


module GRE_array #(parameter WIDTH = 200)(
    input Clk,Rst,write_enable,flush,
    input [WIDTH-1:0] in,
    output reg [WIDTH-1:0] out
    );
    always @(posedge Clk or posedge Rst)
    begin
        if (Rst) begin
        out <= {WIDTH{1'b0}};
        end
        else if(write_enable)
        begin
            if(flush)
                out<=0;
            else
                out<=in;
        end      
    end
endmodule

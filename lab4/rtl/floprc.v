`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/29 23:35:36
// Design Name: 
// Module Name: floprc
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


module floprc #(parameter WIDTH = 8) 
    (   input clk,reset,clear,
        input [WIDTH-1:0] d,
        output reg [WIDTH-1:0] q
    );

    always@(posedge clk, posedge reset) begin
        if(reset) q <= 0;
        else if(clear) q <= 0;
        else q <= d;
    end

endmodule

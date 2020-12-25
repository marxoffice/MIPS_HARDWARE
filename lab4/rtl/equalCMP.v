`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/06/22 21:37:21
// Design Name: 
// Module Name: equalCMP
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


module equalCMP #(parameter WIDTH = 8)
    (
        input wire[WIDTH-1:0] in0,in1,
        output isEqual
    );

    assign isEqual = (in0 == in1) ;
endmodule

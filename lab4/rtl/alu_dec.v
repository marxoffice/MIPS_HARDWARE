`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/14 00:10:57
// Design Name: 
// Module Name: alu_dec
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


module alu_dec(
	input wire [5:0] funct,
	input wire [1:0] aluop,
	output wire [2:0] alucontrol
    );

    wire [2:0] func_tran;

    assign alucontrol = (aluop == 2'b00) ? 3'b010 : // add lw/sw
                        (aluop == 2'b01) ? 3'b110 : // sub beq 
                        (aluop == 2'b10) ? func_tran : // up to funct R-type
                        3'b100; // wrong
    
    assign func_tran = (funct == 6'b100000) ? 3'b010 : // add Add
                       (funct == 6'b100010) ? 3'b110 : // sub Sub
                       (funct == 6'b100100) ? 3'b000 : // and And
                       (funct == 6'b100101) ? 3'b001 : // or Or
                       (funct == 6'b101010) ? 3'b111 : // slt SLT
                       3'b000; // wrong

endmodule

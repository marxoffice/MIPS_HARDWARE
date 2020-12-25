`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/14 00:10:33
// Design Name: 
// Module Name: main_dec
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


module main_dec(
	input wire [5:0] op,
    output wire regwrite,regdst,alusrc,branch,
    output wire memwrite,memtoreg,
	output wire jump,
    output wire [1:0] aluop
    );

    assign {regwrite,regdst,alusrc,branch,memwrite,memtoreg,aluop,jump}
          = (op ==6'b000000) ? 9'b110000100 : // R-type
            (op ==6'b000010) ? 9'b000000001 : // j
            (op ==6'b000100) ? 9'b000100010 : // beq
            (op ==6'b001000) ? 9'b101000000 : // addi
            (op ==6'b100011) ? 9'b101001000 : // lw
            (op ==6'b101011) ? 9'b001010000 : // sw
							   9'b000000000; // wrong

endmodule

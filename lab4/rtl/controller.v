`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/14 01:06:07
// Design Name: 
// Module Name: Controller
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

module controller(
	input wire [5:0] op,funct,
	output wire memtoreg,memwrite,
    output wire branch,alusrc,
    output wire regdst,regwrite,
	output wire jump,
	output wire[2:0] alucontrol
    );

	wire[1:0] aluop;

	main_dec my_maindec(.op(op),.regwrite(regwrite),.regdst(regdst),.alusrc(alusrc),.branch(branch),
    			.memwrite(memwrite),.memtoreg(memtoreg),.jump(jump),.aluop(aluop));
	
	alu_dec my_aludec(.funct(funct),.aluop(aluop),.alucontrol(alucontrol));

endmodule

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
	input wire [4:0] rt,                // 特殊指令 bltz bltzal等
	output wire memtoreg,memwrite,
    output wire branch,alusrc,
    output wire regdst,regwrite,
	output wire write_al,
	output wire jump,jumpr,
	output wire[7:0] alucontrol
    );

	// wire[1:0] aluop;

	main_dec my_maindec(.op(op),.funct(funct),.rt(rt),.regwrite(regwrite),.regdst(regdst),.alusrc(alusrc),.branch(branch),
    			.memwrite(memwrite),.memtoreg(memtoreg),.al_regdst(write_al),.jump(jump),.jumpr(jumpr));
	
	alu_dec my_aludec(.funct(funct),.op(op),.rt(rt),.alucontrol(alucontrol));

endmodule

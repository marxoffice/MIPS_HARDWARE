`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/14 15:01:45
// Design Name: 
// Module Name: datapath
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


module datapath(
    input wire clk,rst,
	input wire memtoreg,pcsrc,
	input wire alusrc,regdst,
	input wire regwrite,jump,
	input wire[2:0] alucontrol,
	output wire overflow,zero,
	output wire[31:0] pc,
	input wire[31:0] instr,
	output wire[31:0] aluout,writedata,
	input wire[31:0] readdata
    );

    wire [31:0] pc_in,pc_add4,pc_branch,inst_ce,pc_temp;
	wire [31:0] after_shift;
	wire [4:0] WriteReg;
	wire [31:0] Result;
	wire [31:0] SrcA,SrcB;
	wire [31:0]	SignImm;
	wire [31:0] after_shift_inst;

	wire[31:0] instrD;

	// flopr 1
    mux2 #(32) before_pc(pc_temp,pc_add4,pc_branch,pcsrc);
	sl2 for_jump({6'b0,instr[25:0]},after_shift_inst);
	mux2 #(32) before_pc_jump(pc_in,pc_temp,{pc_add4[31:28],after_shift_inst[27:0]},jump);
	pc my_pc(clk,rst,pc_in,pc,inst_ce);
	adder my_adder_pc(inst_ce,32'b100,pc_add4);
	

	// flopr 2
	flopr #(32) (clk,rst,instr,instrD);
	flopr #(32) (clk,rst,pc_add4,pc_add4D);

	


	adder my_adder_branch(after_shift,pc_add4,pc_branch);

	mux2 #(5) befor_regfile(WriteReg,instrD[20:16],instrD[15:11],regdst);
	regfile my_register_file(clk,regwrite,instrD[25:21],instrD[20:16],WriteReg,Result,SrcA,writedata);
	mux2 #(32) after_regfile(SrcB,writedata,SignImm,alusrc);

	alu my_alu(SrcA,SrcB,alucontrol,aluout,zero);
	mux2 #(32) afer_data_mem(Result,aluout,readdata,memtoreg);

	signext my_sign_extend(instrD[15:0],SignImm);
	sl2 my_shift_left(SignImm,after_shift);

endmodule

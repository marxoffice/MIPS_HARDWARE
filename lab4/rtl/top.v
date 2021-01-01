`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/11/07 13:50:53
// Design Name: 
// Module Name: top
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


module top(
	input wire clk,rst,
	output wire[31:0] writedata,dataadr,
	output wire memwrite,
	output wire [39:0] ascii
    );

	// 实验包里面已经给top文件
	// 注意 inst_mem  pc[7:2] 指令 2^6=64 
	// pc从第三位开始用 pc+4

	// wire clk;
	wire[31:0] pc,instr,readdata;
	wire [3:0] selM;

	//   clk_div instance_name(
	//   // Clock out ports
	//   .clk_out1(hclk),     // output clk_out1
	//   // Clock in ports
	//   .clk_in1(clk)
	//   );
   	

	flowmips flowmipsInstance(clk,rst,pc,instr,memwrite,dataadr,writedata,readdata,selM);
	inst_mem imem(~clk,pc[11:2],instr);
	data_mem dmem(~clk,memwrite,selM,dataadr[11:2],writedata,readdata); // 只生成了1024条存储位的数据存储器
	instdec my_instdec(instr,ascii);
//	wire [31:0] inputInst;
//	adder my_add(pc,32'hfffffff8,inputInst);

//	inst_mem_ram imem(clk,1'b1,inputInst[7:2],32'b0,instr);
endmodule

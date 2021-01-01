`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/06/01 22:43:30
// Design Name: 
// Module Name: hazard
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


module hazard(
    input wire[4:0] rsD, rtD, rsE, rtE, writeregE, writeregM, writeregW,
    input wire regwriteE, regwriteM, regwriteW, memtoregD, memtoregE, branchD,
    output wire[1:0] forwardAE, forwardBE,
    output wire forwardAD, forwardBD,
    output wire stallF, stallD, flushE
    );
    // TODO: 注意Load指令后面加jr、branch类型指令的数据前推未解决

    // 数据前推处理 如果寄存器号对上了就可以前推 
    // 注意：如果寄存器号为0 不需要前推

    assign forwardAE = ((rsE != 5'b0) & (rsE == writeregM) & regwriteM) ? 2'b10:
                        ((rsE != 5'b0) & (rsE == writeregW) & regwriteW) ? 2'b01: 2'b00;
    assign forwardBE = ((rtE != 2'b0) & (rtE == writeregM) & regwriteM) ? 2'b10:
                        ((rtE != 5'b0) & (rtE == writeregW) & regwriteW) ? 2'b01: 2'b00;

    assign forwardAD = (rsD != 5'b0) & (rsD == writeregM) & regwriteM;
    assign forwardBD = (rtD != 5'b0) & (rtD == writeregM) & regwriteW;


    // 流水线暂停 lw操作需要读存储器 所以必须进行暂停操作
    wire lwstall, branchstall;
    assign lwstall = ((rsD == rtE) | (rtD == rtE)) & memtoregE & ~memtoregD;
    assign branchstall = branchD & regwriteE & ((writeregE == rsD) | (writeregE == rtD)) |
                         branchD & regwriteE & ((writeregM == rsD) | (writeregM == rtD));

    assign stallD = lwstall;
    assign stallF = lwstall;
    assign flushE = lwstall;
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/13 21:00:12
// Design Name: 
// Module Name: alu
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

module alu(
    input wire [31:0] num1,
    input wire [31:0] num2,
    input wire [2:0] op,
    output wire [31:0] ans,
    output wire zero
    );

    // 根据实验图的要求.在实验1的alu基础上增加 zero值

    // 重要错误 zero = (ans == 32'b0);
    // assign zero = 1'b0;
    assign zero = (ans == 32'b0);

    assign ans = (op == 3'b010) ? num1 + num2 :            // + add
           (op == 3'b110) ? num1 - num2 :                  // - sub
           (op == 3'b000) ? num1 & num2 :                  // & and
           (op == 3'b001) ? num1 | num2 :                  // | or
           (op == 3'b100) ? ~num1 :                        // ! not
           (op == 3'b111) ? (num1 < num2) : 32'h00000000;  // slt if(num1 < num2) ans = 1; ans = 0;

endmodule

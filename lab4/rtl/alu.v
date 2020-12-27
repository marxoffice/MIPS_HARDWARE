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
`include "defines.vh"

module alu(
    input wire [31:0] num1,
    input wire [31:0] num2,
    input wire [5:0] sa,
    input wire [7:0] alucontrol,
    output reg [31:0] ans,
    output wire zero
    );

    // 根据实验图的要求.在实验1的alu基础上增加 zero值

    // 重要错误 zero = (ans == 32'b0);
    // assign zero = 1'b0;
    assign zero = (ans == 32'b0);

    // assign ans = (op == 3'b010) ? num1 + num2 :            // + add
    //        (op == 3'b110) ? num1 - num2 :                  // - sub
    //        (op == 3'b000) ? num1 & num2 :                  // & and
    //        (op == 3'b001) ? num1 | num2 :                  // | or
    //        (op == 3'b100) ? ~num1 :                        // ! not
    //        (op == 3'b111) ? (num1 < num2) : 32'h00000000;  // slt if(num1 < num2) ans = 1; ans = 0;
    always @(*) begin
        case (alucontrol)
            //logic op
            `EXE_AND_OP     :ans <= num1 & num2         ;
            `EXE_OR_OP      :ans <= num1 | num2         ;
            `EXE_XOR_OP     :ans <= num1 ^ num2         ;
            `EXE_NOR_OP     :ans <= ~(num1 | num2)      ;
            //TODO 由于传进来的immediate是有符号扩展，这里为了节省一个zero_extend,直接在alu中修改高16位
            `EXE_ANDI_OP    :ans <= num1 & { {16{1'b0}} , num2[15:0]}   ;
            `EXE_XORI_OP    :ans <= num1 ^ { {16{1'b0}} , num2[15:0]}   ;
            `EXE_LUI_OP     :ans <= {num2[15:0] , {16{1'b0}} }          ;
            `EXE_ORI_OP     :ans <= num1 | { {16{1'b0}} , num2[15:0]}   ;

            //shift inst
            //TODO 注意算术右移指令 这里不确定vivado的signed是否可以通过
            //TODO 需要测试 使用31bit和32bit的数字来测试一下
            `EXE_SLL_OP     :ans <= num2 << sa          ;
            `EXE_SRL_OP     :ans <= num2 >> sa          ;
            `EXE_SRA_OP     :ans <= ($signed(num2)) >>> sa;
            `EXE_SLLV_OP    :ans <= num2 << num1;
            `EXE_SRLV_OP    :ans <= num2 >> num1;
            `EXE_SRAV_OP    :ans <= ($signed(num2)) >>> num1;

            //move inst
            // Arithmetic inst
            `EXE_ADD_OP     :ans <= num1 + num2         ;
            `EXE_SUB_OP     :ans <= num1 - num2         ;
            `EXE_SLT_OP     :ans <= num1 < num2         ;
            `EXE_ADDI_OP    :ans <= num1 + num2         ;

            //J type
            `EXE_J_OP       :ans <= num1 + num2         ;
            `EXE_BEQ_OP     :ans <= num1 - num2         ;

            // memory insts
            `EXE_LW_OP      :ans <= num1 + num2         ;
            `EXE_SW_OP      :ans <= num1 + num2         ;

            // sink in inst
            default: ans <= 32'b0;
        endcase
        //logic op
    end


endmodule

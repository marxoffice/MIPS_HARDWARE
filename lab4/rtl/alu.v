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
    input wire clk,
    input wire rst,
    input wire [31:0] num1,
    input wire [31:0] num2, // 注意传进来的immediate是默认有符号扩展
    input wire [4:0] sa,
    input wire [7:0] alucontrol,
    input wire [31:0] hi,
    input wire [31:0] lo,
    input wire flush_endE,  // 清除D->E阶段寄存器的信号，同时用于打断清除DIV的运算
    input wire stallM, // E->M中间寄存器的停顿信号，用于div的接收信号
    input wire [31:0] pc_add4E,
    output wire [31:0] real_ans,
    output reg [63:0] hilo_out,
    output wire overflowE,
    output wire zero,     // zero为1表示跳转 否则不跳
    output wire div_stallE  // 除法运算的停顿
    );
    reg [31:0] ans;
    wire [63:0] hilo_out_mul; // 用于连接mul、div模块结果
    wire [63:0] hilo_out_div; // 用于连接mul、div模块结果
    reg [63:0] hilo_out_move; // 用于连接mul、div模块结果

    // 根据实验图的要求.在实验1的alu基础上增加 zero值

    // TODO 可以考虑将此功能独立成模块 branch_judge
    assign zero = (alucontrol == `EXE_BEQ_OP) ? (num1 == num2):                       // == 0
                  (alucontrol == `EXE_BNE_OP) ? (num1 != num2):                       // != 0
                  (alucontrol == `EXE_BGTZ_OP) ? ((num1[31]==1'b0) && (num1!=32'b0)): // > 0 
                  (alucontrol == `EXE_BLEZ_OP) ? ((num1[31]==1'b1) || (num1==32'b0)): // <= 0
                  (alucontrol == `EXE_BLTZ_OP) ? (num1[31] == 1'b1):                  // < 0
                  (alucontrol == `EXE_BGEZ_OP) ? (num1[31] == 1'b0):                  // >= 0
                  // 下面两条是特殊指令 无论是否跳转 必须写GHR[31]
                  (alucontrol == `EXE_BLTZAL_OP) ? (num1[31] == 1'b1):                // < 0
                  (alucontrol == `EXE_BGEZAL_OP) ? (num1[31] == 1'b0):                // >= 0
                  (ans == 32'b0);

    // assign ans = (op == 3'b010) ? num1 + num2 :            // + add
    //        (op == 3'b110) ? num1 - num2 :                  // - sub
    //        (op == 3'b000) ? num1 & num2 :                  // & and
    //        (op == 3'b001) ? num1 | num2 :                  // | or
    //        (op == 3'b100) ? ~num1 :                        // ! not
    //        (op == 3'b111) ? (num1 < num2) : 32'h00000000;  // slt if(num1 < num2) ans = 1; ans = 0;

    // hilo
    always@(*) begin
        if(alucontrol == `EXE_MTHI_OP) begin
            hilo_out_move <= {num1,lo};
        end else if(alucontrol == `EXE_MTLO_OP) begin
            hilo_out_move <= {hi,num1};
        end else hilo_out_move <= {hi,lo};
    end

    // overflow check
    wire overflow_temp; // 用于检测溢出位
    wire overflow_temp2;
    assign overflow_temp = (ans[31] & (~num1[31] & ~num2[31])) 
                || (~ans[31] & (num1[31] & num2[31]));
    assign overflow_temp2 = (alucontrol == `EXE_ADD_OP || alucontrol == `EXE_SUB_OP || alucontrol == `EXE_ADDI_OP );
    assign overflowE = overflow_temp && overflow_temp2;
    // always@(ans)begin
    //     if(overflowE == 1) ans = 0;
    // end
    assign real_ans = (overflowE == 1) ? 0:ans;

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
            `EXE_SLL_OP     :ans <= num2 << sa              ;
            `EXE_SRL_OP     :ans <= num2 >> sa              ;
            `EXE_SRA_OP     :ans <= ($signed(num2)) >>> sa  ;
            `EXE_SLLV_OP    :ans <= num2 << num1            ;
            `EXE_SRLV_OP    :ans <= num2 >> num1            ;
            `EXE_SRAV_OP    :ans <= ($signed(num2)) >>> num1;

            //move inst
            `EXE_MFHI_OP    :ans <= hi  ;
            `EXE_MTHI_OP    :ans <= num1;
            `EXE_MFLO_OP    :ans <= lo  ;
            `EXE_MTLO_OP    :ans <= num1;

            // Arithmetic inst
            `EXE_ADD_OP     :ans <= num1 + num2;
            `EXE_ADDU_OP    :ans <= num1 + num2                     ;
            `EXE_SUB_OP     :ans <= num1 - num2;
            `EXE_SUBU_OP    :ans <= num1 - num2                     ;
            `EXE_SLT_OP     :ans <= $signed(num1) < $signed(num2)   ;
            `EXE_SLTU_OP    :ans <= num1 < num2                     ;
            // 注意这个所有立即数都是有符号扩展得出来的再做有无溢出区别的相加
            `EXE_ADDI_OP    :ans <= num1 + num2                     ;
            `EXE_ADDIU_OP   :ans <= num1 + num2                     ;
            `EXE_SLTI_OP    :ans <= $signed(num1) < $signed(num2)   ;
            `EXE_SLTIU_OP   :ans <= num1 < num2                     ;

            //J type
            `EXE_J_OP       :ans <= num1 + num2         ;
            `EXE_BEQ_OP     :ans <= num1 - num2         ;

            //b type
            `EXE_BEQ_OP     :ans <= num1 - num2         ;
            `EXE_BNE_OP     :ans <= num1 - num2         ;
            `EXE_BLTZAL_OP  :ans <= + 32'b100;

            // memory insts
            `EXE_LW_OP      :ans <= num1 + num2         ;
            `EXE_SW_OP      :ans <= num1 + num2         ;

            // sink in inst
            default: ans <= 32'b0;
        endcase
        //logic op
    end

    //multiply
    wire mul_sign;
	assign mul_sign = (alucontrol == `EXE_MULT_OP);
    wire mul_valid;  // 用于判断是否为乘法
    assign mul_valid = (alucontrol == `EXE_MULT_OP || alucontrol == `EXE_MULTU_OP);
	my_mul MUL(
		.a(num1),
		.b(num2),
		.sign(mul_sign),   //1:signed
		.result(hilo_out_mul)
	);

    //divide
    wire div_sign;
    wire div_valid;
    assign div_sign  = (alucontrol == `EXE_DIV_OP);
	assign div_valid = (alucontrol == `EXE_DIV_OP || alucontrol == `EXE_DIVU_OP);

    wire div_res_valid;
    wire div_res_ready;

    assign div_res_ready = div_valid & ~stallM;  // E-M寄存器没有停顿
    assign div_stallE = div_valid & ~div_res_valid;

	div_radix2 DIV(
		.clk(clk),
		.rst(rst | flush_endE),
		.a(num1),         //divident
		.b(num2),         //divisor
		.sign(div_sign),    //1 signed

		.opn_valid(div_valid), //master操作数准备好
        .res_ready(div_res_ready), //master可以接收计算结果
        .res_valid(div_res_valid), //slave计算结果准备好
		.result(hilo_out_div)  // 计算结果
	);

    always@(hilo_out_div,hilo_out_mul,hilo_out_move,div_res_valid) begin
        hilo_out = (div_res_valid == 1)? hilo_out_div :
                        (mul_valid == 1)   ? hilo_out_mul :
                        hilo_out_move;
    end


endmodule

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

`include "defines.vh"

module main_dec(
	input wire [5:0] op,
    input wire[5:0] funct,
    input wire[4:0] rt,
    output wire regwrite,regdst,alusrc,branch,
    output wire memwrite,memtoreg,
    output wire al_regdst,
	output wire jump
    // output wire [1:0] aluop
    );

    // assign {regwrite,regdst,alusrc,branch,memwrite,memtoreg,aluop,jump}
    //       = (op ==6'b000000) ? 9'b110000100 : // R-type
    //         (op ==6'b000010) ? 9'b000000001 : // j
    //         (op ==6'b000100) ? 9'b000100010 : // beq
    //         (op ==6'b001000) ? 9'b101000000 : // addi
    //         (op ==6'b100011) ? 9'b101001000 : // lw
    //         (op ==6'b101011) ? 9'b001010000 : // sw
	// 						   9'b000000000; // wrong
    
    reg [5:0] main_signal;
    assign {regwrite,regdst,alusrc,branch,memwrite,memtoreg} = main_signal;
    // regwrite  写寄存器堆        regdst  选择rd还是rt作为写的目标(一般只有immediate需要选rt:0)
    // alusrc  选择立即数还是reg输入alu(一般只有immediate需要选立即数:1)
    // branch  branch指令          memwrite  写内存           memtoreg 内存写到寄存器堆
    // jump    j跳转指令
    // al_regdst 指令BLTZAL BGEZAL和jal 需要写31号寄存器

    // 将jump信号分出来
    assign jump = (op == `EXE_J) ? 1 : 0;

    assign al_regdst = (((op == `EXE_REGIMM_INST) && (rt == `EXE_BLTZAL || rt == `EXE_BGEZAL)) // 两条bzal指令
                        || (op == `EXE_JAL)) ? 1 : 0;  // jal指令
    
    always@(*) begin
        case(op)
            `EXE_NOP: case(funct)
                //logic inst
                `EXE_AND, `EXE_OR, `EXE_XOR, `EXE_NOR: main_signal <= 6'b110000; // R-type
                //shift inst
                `EXE_SLL, `EXE_SRL, `EXE_SRA, `EXE_SLLV, `EXE_SRLV, `EXE_SRAV: main_signal <= 6'b110000; // R-type
                //TODO `EXE_MFHI `EXE_MTHI `EXE_MFLO `EXE_MTLO
                // Arithmetic inst
                `EXE_ADD, `EXE_ADDU, `EXE_SUB, `EXE_SUBU, `EXE_SLT, `EXE_SLTU, `EXE_MULT, `EXE_MULTU, `EXE_DIV, `EXE_DIVU: main_signal <= 6'b110000; // R-type
                
                `EXE_MFHI, `EXE_MFLO: main_signal <= 6'b110000;
                `EXE_MTHI, `EXE_MTLO: main_signal <= 6'b000000;

                default: main_signal <= 6'b000000;
            endcase
            //logic inst
            `EXE_ANDI ,`EXE_XORI, `EXE_LUI, `EXE_ORI: main_signal <= 6'b101000; // Immediate
            
            `EXE_ADDI, `EXE_ADDIU ,`EXE_SLTI, `EXE_SLTIU: main_signal <= 6'b101000; // Immediate
            
            // branch inst
            `EXE_BEQ, `EXE_BGTZ, `EXE_BLEZ, `EXE_BNE    :main_signal <= 6'b000100    ;
            
            `EXE_REGIMM_INST: case(rt)
                `EXE_BLTZ   :main_signal <= 6'b000100      ;
                `EXE_BLTZAL :main_signal <= 6'b000100      ;
                `EXE_BGEZ   :main_signal <= 6'b000100      ;
                `EXE_BGEZAL :main_signal <= 6'b000100      ;
            endcase
            `EXE_LW: main_signal <= 6'b101001;  // lab4 lw
            `EXE_SW: main_signal <= 6'b001010;  // lab4 sw
            `EXE_J: main_signal <= 6'b000000;   // lab4 j
            default: main_signal <= 6'b000000;  // error op
        endcase
    end
endmodule

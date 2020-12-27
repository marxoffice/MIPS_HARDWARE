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
    output wire regwrite,regdst,alusrc,branch,
    output wire memwrite,memtoreg,
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
    
    reg [6:0] main_signal;
    assign {regwrite,regdst,alusrc,branch,memwrite,memtoreg,jump} = main_signal;
    
    always@(*) begin
        case(op)
            `EXE_NOP: case(funct)
                //logic inst
                `EXE_AND, `EXE_OR, `EXE_XOR, `EXE_NOR: main_signal <= 7'b1100000; // R-type
                //shift inst
                `EXE_SLL, `EXE_SRL, `EXE_SRA, `EXE_SLLV, `EXE_SRLV, `EXE_SRAV: main_signal <= 7'b1100000; // R-type
                //TODO `EXE_MFHI `EXE_MTHI `EXE_MFLO `EXE_MTLO
                // Arithmetic inst
                `EXE_ADD, `EXE_ADDU, `EXE_SUB, `EXE_SUBU, `EXE_SLT, `EXE_SLTU, `EXE_MULT, `EXE_MULTU, `EXE_DIV, `EXE_DIVU: main_signal <= 7'b1100000; // R-type
                
                default: main_signal <= 7'b0000000;
            endcase
            //logic inst
            `EXE_ANDI ,`EXE_XORI, `EXE_LUI, `EXE_ORI: main_signal <= 7'b1010000; // Immediate
            
            `EXE_ADDI, `EXE_ADDIU ,`EXE_SLTI, `EXE_SLTIU: main_signal <= 7'b1010000; // Immediate
            `EXE_BEQ: main_signal <= 7'b0001000; // lab4 beq
            `EXE_LW: main_signal <= 7'b1010010;  // lab4 lw
            `EXE_SW: main_signal <= 7'b0010100;  // lab4 sw
            `EXE_J: main_signal <= 7'b0000001;   // lab4 j
            default: main_signal <= 7'b0000000;  // error op
        endcase
    end
endmodule

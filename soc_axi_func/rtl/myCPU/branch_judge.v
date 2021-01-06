`include "defines.vh"
module branch_judge(
    input wire [31:0] num1,num2,
    input wire [7:0] alucontrolD,
    output wire take
);
    assign take = (alucontrolD == `EXE_BEQ_OP) ? (num1 == num2):                       // == 0
                  (alucontrolD == `EXE_BNE_OP) ? (num1 != num2):                       // != 0
                  (alucontrolD == `EXE_BGTZ_OP) ? ((num1[31]==1'b0) && (num1!=32'b0)): // > 0 
                  (alucontrolD == `EXE_BLEZ_OP) ? ((num1[31]==1'b1) || (num1==32'b0)): // <= 0
                  (alucontrolD == `EXE_BLTZ_OP) ? (num1[31] == 1'b1):                  // < 0
                  (alucontrolD == `EXE_BGEZ_OP) ? (num1[31] == 1'b0):                  // >= 0
                  // 下面两条是特殊指令 无论是否跳转 必须写GHR[31]
                  (alucontrolD == `EXE_BLTZAL_OP) ? (num1[31] == 1'b1):                // < 0
                  (alucontrolD == `EXE_BGEZAL_OP) ? (num1[31] == 1'b0):                // >= 0
                  1'b0;
endmodule
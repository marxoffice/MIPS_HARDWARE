module flowmips(
	input wire clk,rst,
	output wire[31:0] pc,
	input wire[31:0] instr,
	output wire memwriteM,
	output wire[31:0] aluoutM,WriteDataM,
	input wire[31:0] readdata,
    output wire [3:0] selM // 写存储的字节选择 
    );

    // 将datapath和controller直接合并起来
    wire pcsrcD,pcsrcE;
    wire [31:0] pc_in,pc_add4F,pc_add4D,pc_add4E,inst_ce,pc_temp1,pc_temp2,pc_temp3,pc_temp4;
	wire [31:0] after_shift;
	wire [31:0] SrcAD,SrcAE,SrcBE,defaultSrcAE;
	wire [31:0]	SignImmD,SignImmE;
    wire [31:0] pc_branchD, pc_branchE;
    wire [31:0] ra;
	wire[31:0] instrD,aluoutE;
    wire [7:0] alucontrolD,alucontrolE,alucontrolM,alucontrolW;
    wire branchD,branchE,branchM,jumpD,memtoregD,memwriteD,alusrcD,regdstD,regwriteD;
    wire jumprD;
    wire regwriteE,memtoregE,memwriteE,alusrcE,regdstE;
    wire regwriteM,memtoregM;
    wire regwriteW,zeroE,memtoregW;
    wire [4:0] WriteRegTemp,WriteRegE,WriteRegM,WriteRegW;
	wire [31:0] ResultW,writedataD,WriteDataE,defaultWriteDataE,handled_WriteDataE,readdataW,aluoutW;
    wire [4:0] rsD,rsE,rtD,RtE,RdE,rdD,saD,saE;
    wire [3:0] selE;
    wire stallF,stallD,flushE,EqualD;
    wire [31:0] eq1,eq2;
    wire [1:0] forwardAE,forwardBE;
    wire forwardAD,forwardBD;

    wire [31:0] pcF,pcD,pcE,pcM;

    // 针对al型指令的PC值 例如jal bltzal等
    wire [4:0] pc_al_dst;
    assign pc_al_dst = 5'b11111;
    wire write_alD,write_alE;

    wire overflowE; // 溢出信号
    wire div_stall; // div运算stallE信号
    wire laddressError;  // 读地址错误例外
    wire saddressError;  // 写地址错误例外

    // 预测模块
    wire predictF,predictD, predictE, predict_wrong,predict_wrongM;
    wire actual_takeM, actual_takeE;
    // assign predictD = 1'b1;
    // assign predictD = 1'b0;
    assign predict_wrong = (predictE != zeroE);

	// flopr 1
    mux2 #(32) before_pc_which_wrong(pc_temp1,pc_branchE,pc_add4E, predictE);
    mux2 #(32) before_pc_wrong(pc_temp2,pc_add4F,pc_branchD, branchD & predictD);
    //mux2 #(32) before_pc_predict(pc_temp3,pc_add4F,pc_temp2,pcsrcD);
    mux2 #(32) before_pc_predict(pc_temp3,pc_temp2,pc_temp1,predict_wrong & branchE);
    mux2 #(32) before_pc_jump(pc_temp4,pc_temp3,{pc_add4D[31:28],instrD[25:0],2'b00},jumpD);
    mux2 #(32) before_pc_jumpr(pc_in,pc_temp4,eq1,jumprD);   // 注意这里可能有数据冒�? eq1是数据前�?
	
    
    pc my_pc(clk,rst,~stallF & ~div_stall,pc_in,pc,inst_ce);
	adder my_adder_pc(inst_ce,32'b100,pc_add4F);
    assign pcF = pc;

    wire flushD;
    // 前一条为branch 且 预测错误，则需要flushD
    // 若当前预测要跳, 则flushD
    assign flushD = (branchE & predict_wrong) | (predictD & branchD);
	// flopr 2
	flopenrc #(32) fp2_1(clk,rst,~stallD & ~div_stall,flushD,instr,instrD);
	flopenrc #(32) fp2_2(clk,rst,~stallD & ~div_stall,flushD,pc_add4F,pc_add4D);
    flopenrc #(32) fp2_3(clk, rst, ~stallD & ~div_stall, flushD, pcF, pcD);

    controller c(instrD[31:26],instrD[5:0],rtD,memtoregD,
	memwriteD,branchD,alusrcD,regdstD,regwriteD,write_alD,jumpD,jumprD,alucontrolD);

	signext my_sign_extend(instrD[15:0],SignImmD);
	regfile my_register_file(clk,regwriteW,instrD[25:21],instrD[20:16],WriteRegW,ResultW,SrcAD,writedataD,ra);
    // regfile(i clk,i we3,i w[4:0] ra1,ra2,wa3, i w[31:0] wd3,o w[31:0] rd1,rd2);
    sl2 my_shift_left(SignImmD,after_shift);

	adder my_adder_branch(after_shift,pc_add4D,pc_branchD);

    // 分支预判 + 数据前推 注意这里是预判不是预测
    equalCMP #(32) cmp1(eq1,eq2,EqualD);
    assign pcsrcD = EqualD & branchD;

    mux2 #(32) forward1_1(eq1,SrcAD,aluoutM,forwardAD);
    mux2 #(32) forward1_2(eq2,writedataD,aluoutM,forwardBD);


    wire flush_endE;
    assign flush_endE = flushE | (predict_wrong & branchE);

    // flopr 3
    flopenrc #(13) fp3_1(clk,rst,~div_stall,flush_endE,{regwriteD,memtoregD,memwriteD,alucontrolD,alusrcD,regdstD},{regwriteE,memtoregE,memwriteE,alucontrolE,alusrcE,regdstE});
    flopenrc #(32) fp3_2(clk,rst,~div_stall,flush_endE,SrcAD,defaultSrcAE);
    flopenrc #(32) fp3_3(clk,rst,~div_stall,flush_endE,writedataD,defaultWriteDataE);
    flopenrc #(5) fp3_4(clk,rst,~div_stall,flush_endE,rsD,rsE);
    flopenrc #(5) fp3_5(clk,rst,~div_stall,flush_endE,rtD,RtE);
    flopenrc #(5) fp3_6(clk,rst,~div_stall,flush_endE,rdD,RdE);
    flopenrc #(32) fp3_7(clk,rst,~div_stall,flush_endE,SignImmD,SignImmE);
    flopenrc #(32) fp3_8(clk,rst,~div_stall,1'b0,pc_add4D,pc_add4E); // 不受flush影响
    flopenrc #(1) fp3_9(clk,rst,~div_stall,flush_endE,pcsrcD,pcsrcE);
    flopenrc #(32) fp3_10(clk,rst,~div_stall,flush_endE,pc_branchD,pc_branchE);
    flopenrc #(1) fp3_11(clk, rst, ~div_stall, flush_endE, EqualD, EqualE);
    flopenrc #(1) fp3_12(clk, rst, ~div_stall, flush_endE, predictD, predictE);
    flopenrc #(1) fp3_13(clk, rst, ~div_stall, flush_endE, branchD, branchE);
    flopenrc #(32) fp3_14(clk,rst, ~div_stall, flush_endE, pcD, pcE);
    flopenrc #(5) fp3_15(clk, rst, ~div_stall, flush_endE, saD, saE);
    flopenrc #(1) fp3_16(clk, rst, ~div_stall, 1'b0, write_alD, write_alE); // 不受flush影响


    // 信号数据
    assign rsD = instrD[25:21];
    assign rtD = instrD[20:16];
    assign rdD = instrD[15:11];
    assign saD = instrD[10:6];

    // 是否真的跳转
    assign actual_takeE = zeroE;


    wire we;
    assign we = 1'b0;
    wire [31:0] hi,lo,hi_o,lo_o;
    wire [63:0] hilo_o;
    assign hi = 32'b0;
    assign lo = 32'b0;

    // 数据前推补充
    mux3 #(32) forward2_1(SrcAE,defaultSrcAE,ResultW,aluoutM,forwardAE);
    mux3 #(32) forward2_2(WriteDataE,defaultWriteDataE,ResultW,aluoutM,forwardBE);

    mux2 #(5) after_regfile(WriteRegTemp,RtE,RdE,regdstE);

    // 处理al型指令的选择
    mux2 #(5) mux_for_al(WriteRegE,WriteRegTemp,pc_al_dst,write_alE);

	mux2 #(32) before_alu(SrcBE,WriteDataE,SignImmE,alusrcE);

    

    alu my_alu(clk,rst,SrcAE,SrcBE,saE,alucontrolE,hilo_o[63:32],hilo_o[31:0], flush_endE,1'b0,
                pc_add4E,aluoutE,hilo_o,overflowE,zeroE,div_stall,laddressError,saddressError);

    // 处理写入SH、SB
    WriteData_handle my_WriteData_handle(alucontrolE,WriteDataE,selE,handled_WriteDataE);

    // flopr 4
    flopr #(3) fp4_1(clk,rst,{regwriteE,memtoregE,memwriteE},{regwriteM,memtoregM,memwriteM});
    flopr #(32) fp4_2(clk,rst,aluoutE,aluoutM);
    flopr #(32) fp4_3(clk,rst,handled_WriteDataE,WriteDataM);
    flopr #(5) fp4_4(clk,rst,WriteRegE,WriteRegM);
    // flopr #(32) fp4_5(clk,rst,pc_branchE,pc_branchM);
    flopr #(1) fp4_6(clk, rst, branchE, branchM);
    flopr #(32) fp4_7(clk,rst,pcE,pcM);
    flopr #(1) fp4_8(clk, rst, actual_takeE, actual_takeM);
    flopr #(1) fp4_9(clk, rst, predict_wrong,predict_wrongM);
    flopr #(4) fp4_10(clk, rst, selE,selM);
    flopr #(8) fp4_11(clk, rst, alucontrolE,alucontrolM);
    
    hilo_reg hilo_at4(clk,rst,we,hi,lo,hi_o,lo_o);

    // flopr 5
    flopr #(2) fp5_1(clk,rst,{regwriteM,memtoregM},{regwriteW,memtoregW});
	flopr #(32) fp5_2(clk,rst,aluoutM,aluoutW);
    flopr #(32) fp5_3(clk,rst,readdata,readdataW);
    flopr #(5) fp5_4(clk,rst,WriteRegM,WriteRegW);
    flopr #(8) fp5_5(clk,rst,alucontrolM,alucontrolW);

    // 处理lh lhu lbu lb lw
    ReadData_handle my_ReadData_handle(alucontrolW,readdataW,aluoutW,handled_readdataW);

    mux2 #(32) afer_data_mem(ResultW,aluoutW,handled_readdataW,memtoregW);

    hazard my_hazard_unit(rsD, rtD, rsE, RtE, WriteRegE, WriteRegM, WriteRegW,
    regwriteE, regwriteM, regwriteW, memtoregE, branchD,
    forwardAE, forwardBE, forwardAD, forwardBD,
    stallF, stallD, flushE);

    compete_predict branch_predict(clk, rst, flushD, stallD, pcF, pcM,
    branchD, branchM, actual_takeM, actual_takeE,
    predict_wrongM, predictD, predictF);
    
endmodule
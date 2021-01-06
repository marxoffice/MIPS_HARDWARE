module mycpu_top (
    input clk,resetn,
    input [5:0] int,

    //instr
    output inst_sram_en,
    output inst_sram_wen    ,
    output [31:0] inst_sram_addr  ,
    output [31:0] inst_sram_wdata ,
    input [31:0] inst_sram_rdata  , 

    //data
    output data_sram_en,
    output [3:0] data_sram_wen    ,
    output [31:0] data_sram_addr  ,
    output [31:0] data_sram_wdata ,
    input [31:0] data_sram_rdata  ,

    //debug
    output [31:0] debug_wb_pc     ,
    output [3:0] debug_wb_rf_wen  ,
    output [4:0] debug_wb_rf_wnum ,
    output [31:0] debug_wb_rf_wdata
);
    assign inst_sram_wen = 0;
    assign inst_sram_wdata = 32'b0;
    // wire[31:0] data_sram_addr_temp;
    
    // TODO inst_en = 1;
    // 如果需要 更改为inst_enF(inst_sram_en),

    wire [31:0] cpu_inst_addr;
    wire [31:0] cpu_data_addr;
    wire no_dcache;

    mmu my_addr_translate(.inst_vaddr(cpu_inst_addr),.inst_paddr(inst_sram_addr),
    .data_vaddr(cpu_data_addr),.data_paddr(data_sram_addr),.no_dcache(no_dcache));

    flowmips datapath(
        .clk(~clk), .rst(~resetn), // low active
        .int(int),

        //inst
        .inst_sram_en(inst_sram_en),
        .pc(cpu_inst_addr),
        .instr(inst_sram_rdata),

        //data
        .memwriteM(data_sram_en),
        .aluoutM(cpu_data_addr),
        .WriteDataM(data_sram_wdata),
        .readdata(data_sram_rdata),
        .selM(data_sram_wen),

        .debug_wb_pc       (debug_wb_pc       ),  
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),  
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),  
        .debug_wb_rf_wdata (debug_wb_rf_wdata )  
    );

    // BUG fix for addr translate 已找到参考资料中的mmu模块转换地址
    // assign data_sram_addr = data_sram_addr_temp[31:16] == 16'hbfaf ? {3'b0, data_sram_addr_temp[28:0]} : data_sram_addr_temp;
endmodule
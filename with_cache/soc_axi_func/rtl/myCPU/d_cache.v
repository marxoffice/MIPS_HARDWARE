// module d_cache (
//     input wire clk, rst,
//     //mips core
//     input         cpu_data_req     ,
//     input         cpu_data_wr      ,
//     input  [1 :0] cpu_data_size    ,
//     input  [31:0] cpu_data_addr    ,
//     input  [31:0] cpu_data_wdata   ,
//     output [31:0] cpu_data_rdata   ,
//     output        cpu_data_addr_ok ,
//     output        cpu_data_data_ok ,

//     //axi interface
//     output         cache_data_req     ,
//     output         cache_data_wr      ,
//     output  [1 :0] cache_data_size    ,
//     output  [31:0] cache_data_addr    ,
//     output  [31:0] cache_data_wdata   ,
//     input   [31:0] cache_data_rdata   ,
//     input          cache_data_addr_ok ,
//     input          cache_data_data_ok 
// );
//     //Cache配置
//     parameter  INDEX_WIDTH  = 10, OFFSET_WIDTH = 2;
//     localparam TAG_WIDTH    = 32 - INDEX_WIDTH - OFFSET_WIDTH;
//     localparam CACHE_DEEPTH = 1 << INDEX_WIDTH;
    
//     //Cache存储单元
//     reg                 cache_valid [CACHE_DEEPTH - 1 : 0];
//     reg [TAG_WIDTH-1:0] cache_tag   [CACHE_DEEPTH - 1 : 0];
//     reg [31:0]          cache_block [CACHE_DEEPTH - 1 : 0];

//     //访问地址分解
//     wire [OFFSET_WIDTH-1:0] offset;
//     wire [INDEX_WIDTH-1:0] index;
//     wire [TAG_WIDTH-1:0] tag;
    
//     assign offset = cpu_data_addr[OFFSET_WIDTH - 1 : 0];
//     assign index = cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
//     assign tag = cpu_data_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];

//     //访问Cache line
//     wire c_valid;
//     wire [TAG_WIDTH-1:0] c_tag;
//     wire [31:0] c_block;

//     assign c_valid = cache_valid[index];
//     assign c_tag   = cache_tag  [index];
//     assign c_block = cache_block[index];

//     //判断是否命中
//     wire hit, miss;
//     assign hit = c_valid & (c_tag == tag);  //cache line的valid位为1，且tag与地址中tag相等
//     assign miss = ~hit;

//     //读或写
//     wire read, write;
//     assign write = cpu_data_wr;
//     assign read = ~write;

//     //FSM
//     parameter IDLE = 2'b00, RM = 2'b01, WM = 2'b11;
//     reg [1:0] state;
//     always @(posedge clk) begin
//         if(rst) begin
//             state <= IDLE;
//         end
//         else begin
//             case(state)
//                 IDLE:   state <= cpu_data_req & read & miss ? RM :
//                                  cpu_data_req & read & hit  ? IDLE :
//                                  cpu_data_req & write       ? WM : IDLE;
//                 RM:     state <= read & cache_data_data_ok ? IDLE : RM;
//                 WM:     state <= write & cache_data_data_ok ? IDLE : WM;
//             endcase
//         end
//     end

//     //读内存
//     //变量read_req, addr_rcv, read_finish用于构造类sram信号。
//     wire read_req;      //一次完整的读事务，从发出读请求到结束
//     reg addr_rcv;       //地址接收成功(addr_ok)后到结束
//     wire read_finish;   //数据接收成功(data_ok)，即读请求结束
//     always @(posedge clk) begin
//         addr_rcv <= rst ? 1'b0 :
//                     read & cache_data_req & cache_data_addr_ok ? 1'b1 :
//                     read_finish ? 1'b0 : addr_rcv;
//     end
//     assign read_req = state==RM;
//     assign read_finish = read & cache_data_data_ok;

//     //写内存
//     wire write_req;     
//     reg waddr_rcv;      
//     wire write_finish;   
//     always @(posedge clk) begin
//         waddr_rcv <= rst ? 1'b0 :
//                      write & cache_data_req & cache_data_addr_ok ? 1'b1 :
//                      write_finish ? 1'b0 : waddr_rcv;
//     end
//     assign write_req = state==WM;
//     assign write_finish = write & cache_data_data_ok;

//     //output to mips core
//     assign cpu_data_rdata   = hit ? c_block : cache_data_rdata;
//     assign cpu_data_addr_ok = read & cpu_data_req & hit | cache_data_req & cache_data_addr_ok;
//     assign cpu_data_data_ok = read & cpu_data_req & hit | cache_data_data_ok;

//     //output to axi interface
//     assign cache_data_req   = read_req & ~addr_rcv | write_req & ~waddr_rcv;
//     assign cache_data_wr    = cpu_data_wr;
//     assign cache_data_size  = cpu_data_size;
//     assign cache_data_addr  = cpu_data_addr;
//     assign cache_data_wdata = cpu_data_wdata;

//     //写入Cache
//     //保存地址中的tag, index，防止addr发生改变
//     reg [TAG_WIDTH-1:0] tag_save;
//     reg [INDEX_WIDTH-1:0] index_save;
//     always @(posedge clk) begin
//         tag_save   <= rst ? 0 :
//                       cpu_data_req ? tag : tag_save;
//         index_save <= rst ? 0 :
//                       cpu_data_req ? index : index_save;
//     end

//     wire [31:0] write_cache_data;
//     wire [3:0] write_mask;

//     //根据地址低两位和size，生成写掩码（针对sb，sh等不是写完整一个字的指令），4位对应1个字（4字节）中每个字的写使能
//     assign write_mask = cpu_data_size==2'b00 ?
//                             (cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100):
//                                                 (cpu_data_addr[0] ? 4'b0010 : 4'b0001)) :
//                             (cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) : 4'b1111);

//     //掩码的使用：位为1的代表需要更新的。
//     //位拓展：{8{1'b1}} -> 8'b11111111
//     //new_data = old_data & ~mask | write_data & mask
//     assign write_cache_data = cache_block[index] & ~{{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}} | 
//                               cpu_data_wdata & {{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}};

//     integer t;
//     always @(posedge clk) begin
//         if(rst) begin
//             for(t=0; t<CACHE_DEEPTH; t=t+1) begin   //刚开始将Cache置为无效
//                 cache_valid[t] <= 0;
//             end
//         end
//         else begin
//             if(read_finish) begin //读缺失，访存结束时
//                 cache_valid[index_save] <= 1'b1;             //将Cache line置为有效
//                 cache_tag  [index_save] <= tag_save;
//                 cache_block[index_save] <= cache_data_rdata; //写入Cache line
//             end
//             else if(write & cpu_data_req & hit) begin   //写命中时需要写Cache
//                 cache_block[index] <= write_cache_data;      //写入Cache line，使用index而不是index_save
//             end
//         end
//     end
// endmodule


// module d_cache (
//     input wire clk, rst,
//     //mips core
//     input         cpu_data_req     ,
//     input         cpu_data_wr      ,
//     input  [1 :0] cpu_data_size    ,
//     input  [31:0] cpu_data_addr    ,
//     input  [31:0] cpu_data_wdata   ,
//     output [31:0] cpu_data_rdata   ,
//     output        cpu_data_addr_ok ,
//     output        cpu_data_data_ok ,

//     //axi interface
//     output         cache_data_req     ,
//     output         cache_data_wr      ,
//     output  [1 :0] cache_data_size    ,
//     output  [31:0] cache_data_addr    ,
//     output  [31:0] cache_data_wdata   ,
//     input   [31:0] cache_data_rdata   ,
//     input          cache_data_addr_ok ,
//     input          cache_data_data_ok 
// );
//     //Cache配置
//     parameter  INDEX_WIDTH  = 10, OFFSET_WIDTH = 2;
//     localparam TAG_WIDTH    = 32 - INDEX_WIDTH - OFFSET_WIDTH;
//     localparam CACHE_DEEPTH = 1 << INDEX_WIDTH;
    
//     //Cache存储单元
//     reg                 cache_valid [CACHE_DEEPTH - 1 : 0];
//     reg [TAG_WIDTH-1:0] cache_tag   [CACHE_DEEPTH - 1 : 0];
//     reg [31:0]          cache_block [CACHE_DEEPTH - 1 : 0];

//     //===========
//     //这里是添加脏块的地址所需要添加的cache结构
//     // reg [INDEX_WIDTH-1:0] cache_index   [CACHE_DEEPTH - 1 : 0];
//     reg [OFFSET_WIDTH-1:0] cache_offset   [CACHE_DEEPTH - 1 : 0];
//     reg [TAG_WIDTH-1:0] cache_dirty_tag [CACHE_DEEPTH - 1 : 0];
//     reg                 cache_dirty [CACHE_DEEPTH - 1 : 0];
//     //===========



//     // 访问地址分解
//     wire [OFFSET_WIDTH-1:0] offset;
//     wire [INDEX_WIDTH-1:0] index;
//     wire [TAG_WIDTH-1:0] tag;
    
//     assign offset = cpu_data_addr[OFFSET_WIDTH - 1 : 0];
//     assign index = cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
//     assign tag = cpu_data_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];


//     //== 为了记录是否为脏位
//     wire c_dirty;
//     //访问Cache line
//     wire c_valid;
//     wire [TAG_WIDTH-1:0] c_tag;
//     wire [31:0] c_block;

//     assign c_valid = cache_valid[index];
//     assign c_tag   = cache_tag  [index];
//     assign c_block = cache_block[index];

//     //==
//     assign c_dirty = cache_dirty[index];

//     //判断是否命中
//     wire hit, miss;
//     assign hit = c_valid & (c_tag == tag);  //cache line的valid位为1，且tag与地址中tag相等
//     assign miss = ~hit;

//     //读或写
//     wire read, write;
//     assign write = cpu_data_wr;
//     assign read = ~write;

//     //FSM
//     // parameter IDLE = 2'b00, RM = 2'b01, WM = 2'b11;
//     // reg [1:0] state;
//     // always @(posedge clk) begin
//     //     if(rst) begin
//     //         state <= IDLE;
//     //     end
//     //     else begin
//     //         case(state)
//     //             IDLE:   state <= cpu_data_req & read & miss ? RM :
//     //                              cpu_data_req & read & hit  ? IDLE :
//     //                              cpu_data_req & write       ? WM : IDLE;
//     //             RM:     state <= read & cache_data_data_ok ? IDLE : RM;
//     //             WM:     state <= write & cache_data_data_ok ? IDLE : WM;
//     //         endcase
//     //     end
//     // end


//     //===========
//     //新的状态机
//     // reg read_cache_ok;
//     // reg write_cache_ok;

//     // SuperWarning 重大bug 由于CPU支持短指令读取，必须为这些指令的操作进行读memory操作
//     // 以write & miss为例,此时存储的数据是 ABCD四个字节,如果写指令是写sw,则没什么
//     // 但是如果 此时是sb或sh 比如想把C 改成 c,则新的数据就是ABcD,问题来了,c真正的邻居数据是abd,
//     // 它们还在内存里面,没被读出来
//     // 由于之前我们自己实现的CPU都是直接读写cache line根本没考虑这个问题
//     // IDLE (hit) ===> IDLE
//     // IDLE (miss & dirty) ==> WD
//     // IDLE (miss & ~dirty) ==> RM
//     // WD ==> RM
//     // RM ==> IDLE

//     // FSM
//     parameter IDLE = 2'b00, RM = 2'b01, WD = 2'b11;
//     reg [1:0] state;
//     always @(posedge clk) begin
//         if(rst) begin
//             state <= IDLE;
//         end
//         else begin
//             case(state)
//                 IDLE:   state <= cpu_data_req & read & miss ? RM :
//                                  cpu_data_req & read & hit  ? IDLE :
//                                  cpu_data_req & write       ? WD : IDLE;
//                 RM:     state <= read & cache_data_data_ok ? IDLE : RM;
//                 WD:     state <= write & cache_data_data_ok ? IDLE : WD;
//             endcase
//         end
//     end

//     reg dirty;
//     // parameter IDLE = 3'b000, RM = 3'b001, WM = 3'b010, WC = 3'b011, RC = 3'b100, WD = 3'b101;
//     // reg [2:0] state;
//     // always @(posedge clk) begin
//     //     if(rst) begin
//     //         state <= IDLE;
//     //     end
//     //     else begin
//     //         case(state)
//     //             IDLE:  begin
//     //                 if (cpu_data_req) begin
//     //                     if (miss & read & dirty)
//     //                         state <= WD; //== 
//     //                     else if(miss & read & ~dirty)
//     //                         state <= RM;
//     //                     else if(miss & ~read & dirty)
//     //                         state <= WD; //== 写dirty数据
//     //                     else if(miss & ~read & ~dirty)
//     //                         state <= WC; //== 直接写cache
//     //                     else if(~miss & read)
//     //                         state <= RC; //== 实际上等于IDLE
//     //                     else if(~miss & ~read)
//     //                         state <= IDLE;
//     //                 end else state <= IDLE;
//     //             end 
                
//     //             // state <= miss ? (read ? (dirty ? WD : RM) : (dirty ? WD : WC) ) : 
//     //             //                 (read ? RC : WC) ;
//     //             WD:     state <= cache_data_data_ok ? (read ? RM : WC) : WD;
//     //             RM:     state <= read & cache_data_data_ok ? IDLE : RM;
//     //             //WM:     state <= write & cache_data_data_ok ? IDLE : WM;
//     //             // == 下面两个等价于IDLE
//     //             RC: begin
//     //                 if (cpu_data_req) begin
//     //                     if (miss & read & dirty)
//     //                         state <= WD; //== 
//     //                     else if(miss & read & ~dirty)
//     //                         state <= RM;
//     //                     else if(miss & ~read & dirty)
//     //                         state <= WD; //== 写dirty数据
//     //                     else if(miss & ~read & ~dirty)
//     //                         state <= WC; //== 直接写cache
//     //                     else if(~miss & read)
//     //                         state <= RC; //== 实际上等于IDLE
//     //                     else if(~miss & ~read)
//     //                         state <= IDLE;
//     //                 end else state <= IDLE;
//     //             end     
//     //             WC: begin
//     //                 if (cpu_data_req) begin
//     //                     if (miss & read & dirty)
//     //                         state <= WD; //== 
//     //                     else if(miss & read & ~dirty)
//     //                         state <= RM;
//     //                     else if(miss & ~read & dirty)
//     //                         state <= WD; //== 写dirty数据
//     //                     else if(miss & ~read & ~dirty)
//     //                         state <= WC; //== 直接写cache
//     //                     else if(~miss & read)
//     //                         state <= RC; //== 实际上等于IDLE
//     //                     else if(~miss & ~read)
//     //                         state <= IDLE;
//     //                 end else state <= IDLE;
//     //             end  
//     //         endcase
//     //     end
//     // end

//     assign onlyThroughCache = (state == RC | state == WC);
//     assign afterAccessMemorey = (state == IDLE) & cache_data_data_ok;


//     //===========

//     //读内存
//     //变量read_req, addr_rcv, read_finish用于构造类sram信号。
//     wire read_req;      //一次完整的读事务，从发出读请求到结束
//     reg addr_rcv;       //地址接收成功(addr_ok)后到结束
//     wire read_finish;   //数据接收成功(data_ok)，即读请求结束
//     always @(posedge clk) begin
//         addr_rcv <= rst ? 1'b0 :
//                     read_req & cache_data_req & cache_data_addr_ok ? 1'b1 : //当cache_data_addr_ok为0，也就是没有地址准备好信息时，那么我们就去寻找是否要去找发送获取地址请求
//                     read_finish ? 1'b0 : addr_rcv;                      //如果此时read_finish为0的话，发送读取内存请求
//     end
//     assign read_req = (state == RM) | (state == WD);
//     assign read_finish = read_req & cache_data_data_ok;//这里应该将这个ok标注为RM
    

//     //写内存
//     wire write_req;     
//     reg waddr_rcv;      
//     wire write_finish;   
//     always @(posedge clk) begin
//         waddr_rcv <= rst ? 1'b0 :
//                      write_req & cache_data_req & cache_data_addr_ok ? 1'b1 :
//                      write_finish ? 1'b0 : waddr_rcv;
//     end
//     assign write_req = (state == WM) | (state == WD);
//     assign write_finish = write_req & cache_data_data_ok;


//     //==========
//     //这里是记录脏块写回的数据
//     reg [31:0] dirty_addr;
//     reg [31:0] dirty_wdata;
//     reg dirty_wr;
//     reg dirty_is_change;
//     reg dirty_req;
//     reg sign;
//     always @(posedge clk) begin
//         dirty_addr <= {cache_dirty_tag[index],index,offset};
//         dirty_wdata <= cache_block[index];

//         if(miss & cache_dirty[index]) begin
//             dirty <= 1'b1;
//             dirty_wr <= 1'b1;
//             // cache_dirty[index] <= 1'b0; //TODO
//         end else begin
//             dirty <= 1'b0;
//             dirty_req <= 1'b0;
//         end
//     end


//     //==========



//     //output to mips core
//     assign cpu_data_rdata   = hit ? c_block : cache_data_rdata;
//     assign cpu_data_addr_ok = cpu_data_req & hit | state == WC | cache_data_req & cache_data_addr_ok & ((state == WD & write) | state == RM);//==后面的括号 RM需要返回 WD并且是write的WD(read的WD到RM再返回)
//     assign cpu_data_data_ok = cpu_data_req & hit | (cache_data_data_ok & state == RM) | (state == WC);

//     //output to axi interface
//     assign cache_data_req   = read_req & ~addr_rcv | write_req & ~waddr_rcv;
//     assign cache_data_wr    = dirty ? dirty_wr : cpu_data_wr;
//     assign cache_data_size  = cpu_data_size;
//     assign cache_data_addr  = dirty ? dirty_addr : cpu_data_addr;
//     assign cache_data_wdata = dirty ? dirty_wdata : cpu_data_wdata;

//     //写入Cache
//     //保存地址中的tag, index，防止addr发生改变
//     reg [TAG_WIDTH-1:0] tag_save;
//     reg [OFFSET_WIDTH-1:0] offset_save;
//     reg [INDEX_WIDTH-1:0] index_save;
//     always @(posedge clk) begin
//         tag_save   <= rst ? 0 :
//                       cpu_data_req ? tag : tag_save;
//         index_save <= rst ? 0 :
//                       cpu_data_req ? index : index_save;
//         offset_save <= rst ? 0 :
//                       cpu_data_req ? offset : offset_save;
//     end

//     wire [31:0] write_cache_data;
//     wire [3:0] write_mask;

//     //根据地址低两位和size，生成写掩码（针对sb，sh等不是写完整一个字的指令），4位对应1个字（4字节）中每个字的写使能
//     assign write_mask = cpu_data_size==2'b00 ?
//                             (cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100):
//                                                 (cpu_data_addr[0] ? 4'b0010 : 4'b0001)) :
//                             (cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) : 4'b1111);

//     //掩码的使用：位为1的代表需要更新的。
//     //位拓展：{8{1'b1}} -> 8'b11111111
//     //new_data = old_data & ~mask | write_data & mask
//     // assign old_data = (write & read_finish) ? cache_data_rdata : cache_block[index];
//     assign write_cache_data = cache_block[index] & ~{{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}} | 
//                               cpu_data_wdata & {{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}};

//     integer t;
//     always @(posedge clk) begin
//         if(rst) begin
//             for(t=0; t<CACHE_DEEPTH; t=t+1) begin   //刚开始将Cache置为无效
//                 cache_valid[t] <= 0;
//                 cache_dirty[t] <= 0;
//             end
//         end
//         else begin
//             if(read_finish & state == RM) begin //读缺失，访存结束时 普通的read miss ~dirty也需要改cache
//                 cache_valid[index_save] <= 1'b1;             //将Cache line置为有效
//                 cache_tag  [index_save] <= tag_save;
//                 cache_block[index_save] <= cache_data_rdata; //写入Cache line
//                 cache_offset[index_save] <= offset_save;
//                 // cache_index[index_save] <= index_save;
//                 cache_dirty_tag[index_save] <= tag_save;
//             end
//             else if((hit & write) & cpu_data_req) begin   //写命中时需要写Cache
//                 cache_block[index] <= write_cache_data;      //写入Cache line，使用index而不是index_save
//                 cache_dirty[index] <= 1'b1;
//                 cache_valid[index] <= 1'b1;
//                 // cache_tag[index] <= tag_save;
//             end else if(miss & write & (~dirty | write_finish)) begin
//                 cache_block[index] <= write_cache_data;
//                 cache_dirty[index] <= 1'b1;
//                 cache_valid[index] <= 1'b1;
//                 cache_tag[index] <= tag_save;
//                 cache_dirty_tag[index] <= tag_save;
//                 cache_offset[index] <= offset_save;
//             end
//         end
//     end
// endmodule


// // 可以运行 writeback版本
// module d_cache (
//     input wire clk, rst,
//     //mips core
//     input         cpu_data_req     ,
//     input         cpu_data_wr      ,
//     input  [1 :0] cpu_data_size    ,
//     input  [31:0] cpu_data_addr    ,
//     input  [31:0] cpu_data_wdata   ,
//     output [31:0] cpu_data_rdata   ,
//     output        cpu_data_addr_ok ,
//     output        cpu_data_data_ok ,

//     //axi interface
//     output         cache_data_req     ,
//     output         cache_data_wr      ,
//     output  [1 :0] cache_data_size    ,
//     output  [31:0] cache_data_addr    ,
//     output  [31:0] cache_data_wdata   ,
//     input   [31:0] cache_data_rdata   ,
//     input          cache_data_addr_ok ,
//     input          cache_data_data_ok 
// );
//     //Cache配置
//     parameter  INDEX_WIDTH  = 10, OFFSET_WIDTH = 2;
//     localparam TAG_WIDTH    = 32 - INDEX_WIDTH - OFFSET_WIDTH;
//     localparam CACHE_DEEPTH = 1 << INDEX_WIDTH;
    
//     //Cache存储单元
//     reg                 cache_valid [CACHE_DEEPTH - 1 : 0];
//     reg [TAG_WIDTH-1:0] cache_tag   [CACHE_DEEPTH - 1 : 0];
//     reg [31:0]          cache_block [CACHE_DEEPTH - 1 : 0];

//     //===========
//     //这里是添加脏块的地址所需要添加的cache结构
//     // reg [INDEX_WIDTH-1:0] cache_index   [CACHE_DEEPTH - 1 : 0];
//     // reg [OFFSET_WIDTH-1:0] cache_offset   [CACHE_DEEPTH - 1 : 0];
//     // reg [TAG_WIDTH-1:0] cache_dirty_tag [CACHE_DEEPTH - 1 : 0];
//     reg                 cache_dirty [CACHE_DEEPTH - 1 : 0];
//     //===========



//     // 访问地址分解
//     wire [OFFSET_WIDTH-1:0] offset;
//     wire [INDEX_WIDTH-1:0] index;
//     wire [TAG_WIDTH-1:0] tag;
    
//     assign offset = cpu_data_addr[OFFSET_WIDTH - 1 : 0];
//     assign index = cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
//     assign tag = cpu_data_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];


//     //== 为了记录是否为脏位
//     wire c_dirty;
//     //访问Cache line
//     wire c_valid;
//     wire [TAG_WIDTH-1:0] c_tag;
//     wire [31:0] c_block;

//     assign c_valid = cache_valid[index];
//     assign c_tag   = cache_tag  [index];
//     assign c_block = cache_block[index];

//     //==
//     assign c_dirty = cache_dirty[index];

//     //判断是否命中
//     wire hit, miss;
//     assign hit = c_valid & (c_tag == tag);  //cache line的valid位为1，且tag与地址中tag相等
//     assign miss = ~hit;

//     //读或写
//     wire read, write;
//     assign write = cpu_data_wr;
//     assign read = ~write;


//     //===========
//     //新的状态机
//     // reg read_cache_ok;
//     // reg write_cache_ok;

//     // SuperWarning 重大bug 由于CPU支持短指令读取，必须为这些指令的操作进行读memory操作
//     // 以write & miss为例,此时存储的数据是 ABCD四个字节,如果写指令是写sw,则没什么
//     // 但是如果 此时是sb或sh 比如想把C 改成 c,则新的数据就是ABcD,问题来了,c真正的邻居数据是abd,
//     // 它们还在内存里面,没被读出来
//     // 由于之前我们自己实现的CPU都是直接读写cache line根本没考虑这个问题
//     // IDLE (hit) ===> IDLE
//     // IDLE (miss & dirty) ==> WD
//     // IDLE (miss & ~dirty) ==> RM
//     // WD ==> RM
//     // RM ==> IDLE

//     // FSM
//     wire dirty;
//     assign dirty = cache_dirty[index];
//     parameter IDLE = 2'b00, RM = 2'b01, WD = 2'b11;
//     reg [1:0] state;
//     always @(posedge clk) begin
//         if(rst) begin
//             state <= IDLE;
//         end
//         else begin
//             case(state)
//                 IDLE:   state <= cpu_data_req & hit ? IDLE :
//                                  cpu_data_req & miss & dirty  ? WD :
//                                  cpu_data_req & miss & ~dirty ? RM : IDLE;
//                 RM:     state <= cache_data_data_ok ? IDLE : RM;
//                 WD:     state <= cache_data_data_ok ? RM : WD;
//             endcase
//         end
//     end


//     // assign onlyThroughCache = (state == RC | state == WC);
//     assign afterAccessMemorey = (state == IDLE) & cache_data_data_ok;


//     //===========

//     //读内存
//     //变量read_req, addr_rcv, read_finish用于构造类sram信号。
//     wire read_req;      //一次完整的读事务，从发出读请求到结束
//     reg addr_rcv;       //地址接收成功(addr_ok)后到结束
//     wire read_finish;   //数据接收成功(data_ok)，即读请求结束
//     always @(posedge clk) begin
//         addr_rcv <= rst ? 1'b0 :
//                     read_req & cache_data_req & cache_data_addr_ok ? 1'b1 : //当cache_data_addr_ok为0，也就是没有地址准备好信息时，那么我们就去寻找是否要去找发送获取地址请求
//                     read_finish ? 1'b0 : addr_rcv;                      //如果此时read_finish为0的话，发送读取内存请求
//     end
//     assign read_req = state == RM;
//     assign read_finish = read_req & cache_data_data_ok;//这里应该将这个ok标注为RM
    

//     //写内存
//     wire write_req;     
//     reg waddr_rcv;      
//     wire write_finish;   
//     always @(posedge clk) begin
//         waddr_rcv <= rst ? 1'b0 :
//                      write_req & cache_data_req & cache_data_addr_ok ? 1'b1 :
//                      write_finish ? 1'b0 : waddr_rcv;
//     end
//     assign write_req = state == WD;
//     assign write_finish = write_req & cache_data_data_ok;



//     wire [31:0] dirty_addr,dirty_wdata;
//     assign dirty_addr = {cache_tag[index],index,offset};
//     assign dirty_wdata = cache_block[index];
//     //==========
//     //这里是记录脏块写回的数据
//     // reg [31:0] dirty_addr;
//     // reg [31:0] dirty_wdata;
//     // reg dirty_wr;
//     // reg dirty_is_change;
//     // reg dirty_req;
//     // reg sign;
//     // always @(posedge clk) begin
//     //     dirty_addr <= {cache_tag[index],index,offset};
//     //     dirty_wdata <= cache_block[index];

//     //     if(miss & cache_dirty[index]) begin
//     //         // dirty <= 1'b1;
//     //         dirty_wr <= 1'b1;
//     //         // cache_dirty[index] <= 1'b0; //TODO
//     //     end else begin
//     //         // dirty <= 1'b0;
//     //         dirty_req <= 1'b0;
//     //     end
//     // end


//     //==========



//     //output to mips core
//     assign cpu_data_rdata   = hit ? c_block : cache_data_rdata;
//     assign cpu_data_addr_ok = cpu_data_req & hit | cache_data_req & cache_data_addr_ok & (state == RM); // ((state == WD & write) | state == RM);//==后面的括号 RM需要返回 WD并且是write的WD(read的WD到RM再返回)
//     assign cpu_data_data_ok = cpu_data_req & hit | (cache_data_data_ok & state == RM);

//     //output to axi interface
//     assign cache_data_req   = read_req & ~addr_rcv | write_req & ~waddr_rcv;
//     assign cache_data_wr    = write_req; // dirty ? dirty_wr : cpu_data_wr;
//     assign cache_data_size  = cpu_data_size;
//     assign cache_data_addr  = cache_data_wr ? dirty_addr : cpu_data_addr; //== 重点BUG 完成dirty写之后 还需要RM
//     assign cache_data_wdata = dirty ? dirty_wdata : cpu_data_wdata;

//     //写入Cache
//     //保存地址中的tag, index，防止addr发生改变
//     reg [TAG_WIDTH-1:0] tag_save;
//     reg [OFFSET_WIDTH-1:0] offset_save;
//     reg [INDEX_WIDTH-1:0] index_save;
//     always @(posedge clk) begin
//         tag_save   <= rst ? 0 :
//                       cpu_data_req ? tag : tag_save;
//         index_save <= rst ? 0 :
//                       cpu_data_req ? index : index_save;
//         offset_save <= rst ? 0 :
//                       cpu_data_req ? offset : offset_save;
//     end

//     wire [31:0] write_cache_data;
//     wire [3:0] write_mask;

//     //根据地址低两位和size，生成写掩码（针对sb，sh等不是写完整一个字的指令），4位对应1个字（4字节）中每个字的写使能
//     assign write_mask = cpu_data_size==2'b00 ?
//                             (cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100):
//                                                 (cpu_data_addr[0] ? 4'b0010 : 4'b0001)) :
//                             (cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) : 4'b1111);

//     //掩码的使用：位为1的代表需要更新的。
//     //位拓展：{8{1'b1}} -> 8'b11111111
//     //new_data = old_data & ~mask | write_data & mask
//     assign old_data = (write & read_finish) ? cache_data_rdata : cache_block[index];
//     assign write_cache_data = old_data & ~{{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}} | 
//                               cpu_data_wdata & {{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}};

//     integer t;
//     always @(posedge clk) begin
//         if(rst) begin
//             for(t=0; t<CACHE_DEEPTH; t=t+1) begin   //刚开始将Cache置为无效
//                 cache_valid[t] <= 0;
//                 cache_dirty[t] <= 0;
//             end
//         end
//         else begin
//             if(read_finish & state == RM & read) begin //读缺失，访存结束时 普通的read miss ~dirty也需要改cache
//                 cache_valid[index_save] <= 1'b1;             //将Cache line置为有效
//                 cache_tag  [index_save] <= tag_save;
//                 cache_block[index_save] <= cache_data_rdata; //写入Cache line
//                 cache_dirty[index_save] <= 1'b0;
//                 // cache_offset[index_save] <= offset_save;
//                 // cache_index[index_save] <= index_save;
//                 // cache_dirty_tag[index_save] <= tag_save;
//             end else if(read_finish & state == RM & write) begin
//                 cache_valid[index_save] <= 1'b1;             //将Cache line置为有效
//                 cache_tag  [index_save] <= tag_save;
//                 cache_block[index_save] <= write_cache_data; //写入Cache line
//                 cache_dirty[index_save] <= 1'b1;
//             end else if((hit & write) & cpu_data_req) begin   //写命中时需要写Cache
//                 cache_block[index] <= write_cache_data;      //写入Cache line，使用index而不是index_save
//                 cache_dirty[index] <= 1'b1;
//                 // cache_valid[index] <= 1'b1;
//                 // cache_tag[index] <= tag_save;
//             end // else if(miss & write & (~dirty | write_finish)) begin
//             //     cache_block[index] <= write_cache_data;
//             //     cache_dirty[index] <= 1'b1;
//             //     cache_valid[index] <= 1'b1;
//             //     cache_tag[index] <= tag_save;
//             //     // cache_dirty_tag[index] <= tag_save;
//             //     // cache_offset[index] <= offset_save;
//             // end
//         end
//     end
// endmodule


// // 2way cache
// module d_cache(
//     input wire clk, rst,
//     //mips core
//     input         cpu_data_req     ,
//     input         cpu_data_wr      ,
//     input  [1 :0] cpu_data_size    ,
//     input  [31:0] cpu_data_addr    ,
//     input  [31:0] cpu_data_wdata   ,
//     output [31:0] cpu_data_rdata   ,
//     output        cpu_data_addr_ok ,
//     output        cpu_data_data_ok ,

//     //axi interface
//     output         cache_data_req     ,
//     output         cache_data_wr      ,
//     output  [1 :0] cache_data_size    ,
//     output  [31:0] cache_data_addr    ,
//     output  [31:0] cache_data_wdata   ,
//     input   [31:0] cache_data_rdata   ,
//     input          cache_data_addr_ok ,
//     input          cache_data_data_ok 
// );

//     //Cache配置
//     parameter  INDEX_WIDTH  = 10, OFFSET_WIDTH = 2;
//     localparam TAG_WIDTH    = 32 - INDEX_WIDTH - OFFSET_WIDTH;
//     localparam CACHE_DEEPTH = 1 << INDEX_WIDTH;

//     // 对Cache的定义
//     reg                 cache_valid [CACHE_DEEPTH - 1 : 0][1:0];
//     reg [TAG_WIDTH-1:0] cache_tag   [CACHE_DEEPTH - 1 : 0][1:0];
//     reg [31:0]          cache_block [CACHE_DEEPTH - 1 : 0][1:0];
//     reg                 cache_dirty [CACHE_DEEPTH - 1 : 0][1:0];
//     reg                 cache_ru    [CACHE_DEEPTH - 1 : 0][1:0]; // recently used

//     // 访问地址分解
//     wire [OFFSET_WIDTH-1:0] offset;
//     wire [INDEX_WIDTH-1:0] index;
//     wire [TAG_WIDTH-1:0] tag;

//     assign offset = cpu_data_addr[OFFSET_WIDTH - 1 : 0];
//     assign index = cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
//     assign tag = cpu_data_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];

//     //为了记录Cache Line的访问
//     wire                 c_valid[1:0];
//     wire                 c_dirty[1:0];
//     wire [TAG_WIDTH-1:0] c_tag[1:0];
//     wire [31:0]          c_block[1:0];
//     wire                 c_ru[1:0];


//     assign c_valid[0] = cache_valid[index][0];
//     assign c_valid[1] = cache_valid[index][1];
//     assign c_dirty[0] = cache_dirty[index][0];
//     assign c_dirty[1] = cache_dirty[index][1];
//     assign c_tag[0] = cache_tag[index][0];
//     assign c_tag[1] = cache_tag[index][1];
//     assign c_ru[0] = cache_ru[index][0];
//     assign c_ru[1] = cache_ru[index][1];
//     assign c_tag[0] = cache_tag[index][0];
//     assign c_tag[1] = cache_tag[index][1];
//     assign c_block[0] = cache_block[index][0];
//     assign c_block[1] = cache_block[index][1];



//     //判断是否命hit中
//     wire hit, miss;
//     assign hit = (c_valid[0] & (c_tag[0] == tag))|c_valid[1] & (c_tag[1] == tag);
//     assign miss = ~hit;

//     wire way;
//     // 判断是哪一路
//     // 如果是hit了，如果是0对应上tag 就选0否则选1
//     // 如果是没有hit，找最近没有用的一路
//     assign way = hit ? (c_valid[0] & (c_tag[0] == tag) ? 0 : 1) : (c_ru[0] ? 1 : 0);
    
//     //判断读或写，即使load还是store
//     wire read, write;
//     assign write = cpu_data_wr;
//     assign read = ~write;


//     //FSM
//     wire dirty, clean;
//     assign dirty = cache_dirty[index][way];
//     assign clean = ~dirty;
//     parameter IDLE = 2'b00, RM = 2'b01, WD = 2'b11;
//     reg [1:0] state;
//     always @(posedge clk) begin
//         if(rst) begin
//             state <= IDLE;
//         end
//         else begin
//             case(state)
//                 IDLE:   state <= cpu_data_req & hit ? IDLE :
//                                  cpu_data_req & miss & dirty  ? WD :
//                                  cpu_data_req & miss & ~dirty ? RM : IDLE;
//                 RM:     state <= cache_data_data_ok ? IDLE : RM;
//                 WD:     state <= cache_data_data_ok ? RM : WD;
//             endcase
//         end
//     end

//     //读内存
//     //变量read_req, addr_rcv, read_finish用于构造类sram信号。
//     wire read_req;      //一次完整的读事务，从发出读请求到结束
//     reg addr_rcv;       //地址接收成功(addr_ok)后到结束
//     wire read_finish;   //数据接收成功(data_ok)，即读请求结束
//     always @(posedge clk) begin
//         addr_rcv <= rst ? 1'b0 :
//                     read_req & cache_data_req & cache_data_addr_ok ? 1'b1 : //当cache_data_addr_ok为0，也就是没有地址准备好信息时，那么我们就去寻找是否要去找发送获取地址请求
//                     read_finish ? 1'b0 : addr_rcv;                      //如果此时read_finish为0的话，发送读取内存请求
//     end
//     assign read_req = state == RM;
//     assign read_finish = read_req & cache_data_data_ok;//这里应该将这个ok标注为RM
    

//     //写内存
//     wire write_req;     
//     reg waddr_rcv;      
//     wire write_finish;   
//     always @(posedge clk) begin
//         waddr_rcv <= rst ? 1'b0 :
//                      write_req & cache_data_req & cache_data_addr_ok ? 1'b1 :
//                      write_finish ? 1'b0 : waddr_rcv;
//     end
//     assign write_req = state == WD;
//     assign write_finish = write_req & cache_data_data_ok;

//     // dirty机制
//     wire [31:0] dirty_addr,dirty_wdata;
//     assign dirty_addr = {c_tag[way],index,offset};
//     assign dirty_wdata = c_block[way];


//     //output to mips core
//     assign cpu_data_rdata   = hit ? c_block[way] : cache_data_rdata;
//     assign cpu_data_addr_ok = cpu_data_req & hit | cache_data_req & cache_data_addr_ok & (state == RM); // ((state == WD & write) | state == RM);//==后面的括号 RM需要返回 WD并且是write的WD(read的WD到RM再返回)
//     assign cpu_data_data_ok = cpu_data_req & hit | (cache_data_data_ok & state == RM);

//     //output to axi interface
//     assign cache_data_req   = read_req & ~addr_rcv | write_req & ~waddr_rcv;
//     assign cache_data_wr    = write_req; // dirty ? dirty_wr : cpu_data_wr;
//     assign cache_data_size  = cpu_data_size;
//     assign cache_data_addr  = cache_data_wr ? dirty_addr : cpu_data_addr; //== 重点BUG 完成dirty写之后 还需要RM
//     assign cache_data_wdata = c_block[way];

//     //写入Cache
//     //保存地址中的tag, index，防止addr发生改变
//     reg [TAG_WIDTH-1:0] tag_save;
//     reg [OFFSET_WIDTH-1:0] offset_save;
//     reg [INDEX_WIDTH-1:0] index_save;
//     always @(posedge clk) begin
//         tag_save   <= rst ? 0 :
//                       cpu_data_req ? tag : tag_save;
//         index_save <= rst ? 0 :
//                       cpu_data_req ? index : index_save;
//         offset_save <= rst ? 0 :
//                       cpu_data_req ? offset : offset_save;
//     end

//     wire [31:0] write_cache_data;
//     wire [3:0] write_mask;

//     //根据地址低两位和size，生成写掩码（针对sb，sh等不是写完整一个字的指令），4位对应1个字（4字节）中每个字的写使能
//     assign write_mask = cpu_data_size==2'b00 ?
//                             (cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100):
//                                                 (cpu_data_addr[0] ? 4'b0010 : 4'b0001)) :
//                             (cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) : 4'b1111);

//     //掩码的使用：位为1的代表需要更新的。
//     //位拓展：{8{1'b1}} -> 8'b11111111
//     //new_data = old_data & ~mask | write_data & mask
//     assign old_data = (write & read_finish) ? cache_data_rdata : cache_block[index][way];
//     assign write_cache_data = old_data & ~{{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}} | 
//                               cpu_data_wdata & {{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}};
//     integer t;
//     integer j;
//     always @(posedge clk) begin
//         if(rst) begin
//             for(t=0; t<CACHE_DEEPTH; t=t+1) begin   //刚开始将Cache置为无效
//             	for(j = 0; j < 2; j = j + 1) begin
//                     cache_valid[t][j] <= 0;
//                 	cache_dirty[t][j] <= 0;
//                 	cache_ru[t][j] <= 0;
//             	end
//             end
//         end
//         else begin
//             if(read_finish & state == RM & read) begin //读缺失，访存结束时 普通的read miss ~dirty也需要改cache
//                 cache_valid[index_save][way] <= 1'b1;             //将Cache line置为有效
//                 cache_tag  [index_save][way] <= tag_save;
//                 cache_block[index_save][way] <= cache_data_rdata; //写入Cache line
//                 cache_dirty[index_save][way] <= 1'b0;
//             end else if(read_finish & state == RM & write) begin
//                 cache_valid[index_save][way] <= 1'b1;             //将Cache line置为有效
//                 cache_tag  [index_save][way] <= tag_save;
//                 cache_block[index_save][way] <= write_cache_data; //写入Cache line
//                 cache_dirty[index_save][way] <= 1'b1;
//             end else if((hit & write) & cpu_data_req) begin   //写命中时需要写Cache
//                 cache_block[index][way] <= write_cache_data;      //写入Cache line，使用index而不是index_save
//                 cache_dirty[index][way] <= 1'b1;
//             end

//             if(cpu_data_data_ok) begin
//             	cache_ru[index][way] <= 1'b1; // recently used
//             	cache_ru[index][~way] <= 1'b0; // recently not used
//             end
//         end
//     end



// endmodule

module d_cache(
    input wire clk, rst,
    //mips core
    input         cpu_data_req     ,
    input         cpu_data_wr      ,
    input  [1 :0] cpu_data_size    ,
    input  [31:0] cpu_data_addr    ,
    input  [31:0] cpu_data_wdata   ,
    output [31:0] cpu_data_rdata   ,
    output        cpu_data_addr_ok ,
    output        cpu_data_data_ok ,

    //axi interface
    output         cache_data_req     ,
    output         cache_data_wr      ,
    output  [1 :0] cache_data_size    ,
    output  [31:0] cache_data_addr    ,
    output  [31:0] cache_data_wdata   ,
    input   [31:0] cache_data_rdata   ,
    input          cache_data_addr_ok ,
    input          cache_data_data_ok 
);

    //Cache配置
    parameter  INDEX_WIDTH  = 10, OFFSET_WIDTH = 2;
    localparam TAG_WIDTH    = 32 - INDEX_WIDTH - OFFSET_WIDTH;
    localparam CACHE_DEEPTH = 1 << INDEX_WIDTH;

    // 对Cache的定义
    reg                 cache_valid [CACHE_DEEPTH - 1 : 0][3:0];
    reg [TAG_WIDTH-1:0] cache_tag   [CACHE_DEEPTH - 1 : 0][3:0];
    reg [31:0]          cache_block [CACHE_DEEPTH - 1 : 0][3:0];
    reg                 cache_dirty [CACHE_DEEPTH - 1 : 0][3:0];
// recently used
    reg [2:0]           flru_tree   [CACHE_DEEPTH - 1 : 0];

    wire [2:0] tree;

    // 访问地址分解
    wire [OFFSET_WIDTH-1:0] offset;
    wire [INDEX_WIDTH-1:0] index;
    wire [TAG_WIDTH-1:0] tag;

    assign offset = cpu_data_addr[OFFSET_WIDTH - 1 : 0];
    assign index = cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
    assign tag = cpu_data_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];
    assign tree = flru_tree[index];
    //为了记录Cache Line的访问
    wire                 c_valid[3:0];
    wire                 c_dirty[3:0];
    wire [TAG_WIDTH-1:0] c_tag[3:0];
    wire [31:0]          c_block[3:0];
 

    assign c_valid[0] = cache_valid[index][0];
    assign c_valid[1] = cache_valid[index][1];
    assign c_valid[2] = cache_valid[index][2];
    assign c_valid[3] = cache_valid[index][3];

    assign c_dirty[0] = cache_dirty[index][0];
    assign c_dirty[1] = cache_dirty[index][1];
    assign c_dirty[2] = cache_dirty[index][2];
    assign c_dirty[3] = cache_dirty[index][3];

    assign c_tag[0] = cache_tag[index][0];
    assign c_tag[1] = cache_tag[index][1];
    assign c_tag[2] = cache_tag[index][2];
    assign c_tag[3] = cache_tag[index][3];

    assign c_block[0] = cache_block[index][0];
    assign c_block[1] = cache_block[index][1];
    assign c_block[2] = cache_block[index][2];
    assign c_block[3] = cache_block[index][3];

    wire hit00,hit01,hit10,hit11;
    assign hit00 = c_valid[0] & (c_tag[0] == tag);
    assign hit01 = c_valid[1] & (c_tag[1] == tag);
    assign hit10 = c_valid[2] & (c_tag[2] == tag);
    assign hit11 = c_valid[3] & (c_tag[3] == tag);

    wire hit, miss;
    assign hit = hit00 | hit01 | hit10 | hit11;
    assign miss = ~hit;

    wire [1:0] way;

    // 如果hit，选择 否则使用flru选择最近没有使用的路
    assign way = hit ? (hit00 ? 2'b00 : 
                        hit01 ? 2'b01 : 
                        hit10 ? 2'b10 : 
                        2'b11) 
                    : tree[2] ? {tree[2],tree[0]} : {tree[2], tree[1]};
    

    wire read, write;
    assign write = cpu_data_wr;
    assign read = ~write;

    //FSM
    wire dirty, clean;
    assign dirty = cache_dirty[index][way];
    assign clean = ~dirty;
    parameter IDLE = 2'b00, RM = 2'b01, WD = 2'b11;
    reg [1:0] state;
    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;
        end
        else begin
            case(state)
                IDLE:   state <= cpu_data_req & hit ? IDLE :
                                 cpu_data_req & miss & dirty  ? WD :
                                 cpu_data_req & miss & ~dirty ? RM : IDLE;
                RM:     state <= cache_data_data_ok ? IDLE : RM;
                WD:     state <= cache_data_data_ok ? RM : WD;
            endcase
        end
    end


    //读内存
    //变量read_req, addr_rcv, read_finish用于构造类sram信号。
    wire read_req;      //一次完整的读事务，从发出读请求到结束
    reg addr_rcv;       //地址接收成功(addr_ok)后到结束
    wire read_finish;   //数据接收成功(data_ok)，即读请求结束
    always @(posedge clk) begin
        addr_rcv <= rst ? 1'b0 :
                    read_req & cache_data_req & cache_data_addr_ok ? 1'b1 : //当cache_data_addr_ok为0，也就是没有地址准备好信息时，那么我们就去寻找是否要去找发送获取地址请求
                    read_finish ? 1'b0 : addr_rcv;                      //如果此时read_finish为0的话，发送读取内存请求
    end
    assign read_req = state == RM;
    assign read_finish = read_req & cache_data_data_ok;//这里应该将这个ok标注为RM
    

    //写内存
    wire write_req;     
    reg waddr_rcv;      
    wire write_finish;   
    always @(posedge clk) begin
        waddr_rcv <= rst ? 1'b0 :
                     write_req & cache_data_req & cache_data_addr_ok ? 1'b1 :
                     write_finish ? 1'b0 : waddr_rcv;
    end
    assign write_req = state == WD;
    assign write_finish = write_req & cache_data_data_ok;

    // dirty机制
    wire [31:0] dirty_addr,dirty_wdata;
    assign dirty_addr = {c_tag[way],index,offset};
    assign dirty_wdata = c_block[way];


    //output to mips core
    assign cpu_data_rdata   = hit ? c_block[way] : cache_data_rdata;
    assign cpu_data_addr_ok = cpu_data_req & hit | cache_data_req & cache_data_addr_ok & (state == RM); // ((state == WD & write) | state == RM);//==后面的括号 RM需要返回 WD并且是write的WD(read的WD到RM再返回)
    assign cpu_data_data_ok = cpu_data_req & hit | (cache_data_data_ok & state == RM);

    //output to axi interface
    assign cache_data_req   = read_req & ~addr_rcv | write_req & ~waddr_rcv;
    assign cache_data_wr    = write_req; // dirty ? dirty_wr : cpu_data_wr;
    assign cache_data_size  = cpu_data_size;
    assign cache_data_addr  = cache_data_wr ? dirty_addr : cpu_data_addr; //== 重点BUG 完成dirty写之后 还需要RM
    assign cache_data_wdata = c_block[way];



   //写入Cache
    //保存地址中的tag, index，防止addr发生改变
    reg [TAG_WIDTH-1:0] tag_save;
    reg [OFFSET_WIDTH-1:0] offset_save;
    reg [INDEX_WIDTH-1:0] index_save;
    always @(posedge clk) begin
        tag_save   <= rst ? 0 :
                      cpu_data_req ? tag : tag_save;
        index_save <= rst ? 0 :
                      cpu_data_req ? index : index_save;
        offset_save <= rst ? 0 :
                      cpu_data_req ? offset : offset_save;
    end

    wire [31:0] write_cache_data;
    wire [3:0] write_mask;

    //根据地址低两位和size，生成写掩码（针对sb，sh等不是写完整一个字的指令），4位对应1个字（4字节）中每个字的写使能
    assign write_mask = cpu_data_size==2'b00 ?
                            (cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100):
                                                (cpu_data_addr[0] ? 4'b0010 : 4'b0001)) :
                            (cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) : 4'b1111);

    //掩码的使用：位为1的代表需要更新的。
    //位拓展：{8{1'b1}} -> 8'b11111111
    //new_data = old_data & ~mask | write_data & mask
    assign old_data = (write & read_finish) ? cache_data_rdata : cache_block[index][way];
    assign write_cache_data = old_data & ~{{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}} | 
                              cpu_data_wdata & {{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}};
    integer t;
    integer j;
    always @(posedge clk) begin
        if(rst) begin
            for(t=0; t<CACHE_DEEPTH; t=t+1) begin   //刚开始将Cache置为无效
                for(j = 0; j < 4; j = j + 1) begin
                    cache_valid[t][j] <= 0;
                    cache_dirty[t][j] <= 0;
                end
                flru_tree[t] <= 3'b000;
            end
        end
        else begin
            if(read_finish & state == RM & read) begin //读缺失，访存结束时 普通的read miss ~dirty也需要改cache
                cache_valid[index_save][way] <= 1'b1;             //将Cache line置为有效
                cache_tag  [index_save][way] <= tag_save;
                cache_block[index_save][way] <= cache_data_rdata; //写入Cache line
                cache_dirty[index_save][way] <= 1'b0;
            end else if(read_finish & state == RM & write) begin
                cache_valid[index_save][way] <= 1'b1;             //将Cache line置为有效
                cache_tag  [index_save][way] <= tag_save;
                cache_block[index_save][way] <= write_cache_data; //写入Cache line
                cache_dirty[index_save][way] <= 1'b1;
            end else if((hit & write) & cpu_data_req) begin   //写命中时需要写Cache
                cache_block[index][way] <= write_cache_data;      //写入Cache line，使用index而不是index_save
                cache_dirty[index][way] <= 1'b1;
            end

            // if((state == IDLE) & (hit | (state == RM))) begin
            if(cpu_data_data_ok) begin
                if(way[1] == 1'b0) // use right
                    {flru_tree[index][2], flru_tree[index][1]} <= ~way;
                else // use left
                    {flru_tree[index][2], flru_tree[index][0]} <= ~way;
            end
        end
    end
endmodule

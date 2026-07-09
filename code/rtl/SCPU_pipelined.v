`include "ctrl_encode_def.v"

// SCPU_pipelined — 5 级流水线 RISC-V CPU 顶层 (含中断 + CSR)
//   IF → ID → EX → MEM → WB
//   对外接口与单周期 SCPU.v 完全一致
module SCPU_pipelined (
    input           clk,
    input           reset,          // 高有效复位
    input           MIO_ready,      // [SoC] 暂不使用 (保留兼容)
    input  [31:0]   inst_in,        // 取指 (来自 ROM)
    input  [31:0]   Data_in,        // Load 数据 (来自外部 DM/MIO_BUS)
    input           INT,            // 中断 (来自 Counter_x)
    output          mem_w,          // DM 写使能 (MEM 级)
    output          CPU_MIO,        // [SoC] 访存标志 (保留兼容)
    output [31:0]   PC_out,         // 当前 PC (IF 级)
    output [31:0]   Addr_out,       // 访存地址 (MEM 级)
    output [31:0]   Data_out,       // Store 数据 (MEM 级)
    output [2:0]    dm_ctrl,        // 访存类型 (MEM 级)
    input  [4:0]    reg_sel,        // [调试] 寄存器选择
    output [31:0]   reg_data        // [调试] 寄存器值
);

// =================== IF 级 ===================
wire [31:0] IF_PC, IF_pcplus4, IF_NPC;
reg  [31:0] WB_WD;                  // writeback data

// === VRFC 前向声明 ===
// pipeline_stall/kill_IF/kill_ID/IF_ID_freeze 在模块顶部声明
// 避免 IF/ID 流水线寄存器 VRFC 隐式声明警告
wire pipeline_stall, kill_IF, kill_ID, IF_ID_freeze;
wire        MEM_WB_RegWrite;
wire [4:0]  MEM_WB_rd;
wire        ID_EX_MemRead;
wire [4:0]  ID_EX_rd;
wire        EX_taken;
wire        EX_MEM_RegWrite;
wire [4:0]  EX_MEM_rd;
wire [31:0] EX_MEM_ALU_result;
wire [11:0] ID_EX_csr_addr;
wire [31:0] ID_EX_csr_wdata;
wire [11:0] EX_MEM_csr_addr;
wire [31:0] EX_MEM_csr_wdata;
wire [11:0] MEM_WB_csr_addr;
wire [31:0] MEM_WB_csr_wdata;
wire [31:0] EX_ALU_result;

PC U_PC (
    .clk(clk), .rst(reset), .NPC(IF_NPC), .PC(IF_PC)
);
assign IF_pcplus4 = IF_PC + 32'd4;

// =================== IF/ID 寄存器 (64-bit) ===================
// [63:32]=inst_in, [31:0]=pcplus4
wire [63:0] IF_ID_in  = {inst_in, IF_pcplus4};
wire [63:0] IF_ID_out;
GRE_array #(.WIDTH(64)) IF_ID (
    .Clk(clk), .Rst(reset),
    .write_enable(~IF_ID_freeze), .flush(kill_IF),
    .in(IF_ID_in), .out(IF_ID_out)
);
wire [31:0] ID_instruction = IF_ID_out[63:32];
wire [31:0] ID_pcplus4     = IF_ID_out[31:0];

// =================== ID 级 ===================
// 指令字段提取
wire [4:0]  rs1    = ID_instruction[19:15];
wire [4:0]  rs2    = ID_instruction[24:20];
wire [4:0]  rd     = ID_instruction[11:7];
wire [6:0]  Op     = ID_instruction[6:0];
wire [2:0]  Funct3 = ID_instruction[14:12];
wire [6:0]  Funct7 = ID_instruction[31:25];
wire [11:0] csr_addr = ID_instruction[31:20];  // CSR 地址

// 立即数 — 字段提取
wire [4:0]  ID_iimm_shamt = ID_instruction[24:20];
wire [11:0] ID_iimm       = ID_instruction[31:20];
wire [11:0] ID_simm       = {ID_instruction[31:25], ID_instruction[11:7]};
wire [11:0] ID_bimm       = {ID_instruction[31], ID_instruction[7],
                             ID_instruction[30:25], ID_instruction[11:8]};
wire [19:0] ID_uimm       = ID_instruction[31:12];
wire [19:0] ID_jimm       = {ID_instruction[31], ID_instruction[19:12],
                             ID_instruction[20], ID_instruction[30:21]};

// 控制信号译码 (ctrl.v 完全复用)
wire        ID_RegWrite, ID_MemWrite;
wire [1:0]  ID_WDSel;
wire [2:0]  ID_DMType;
wire [4:0]  ID_ALUOp;
wire        ID_ALUSrc;
wire [5:0]  ID_EXTOp;
wire [2:0]  ID_NPCOp;
wire [1:0]  ID_GPRSel;
ctrl U_CTRL (
    .Op(Op), .Funct7(Funct7), .Funct3(Funct3), .Zero(1'b0),
    .RegWrite(ID_RegWrite), .MemWrite(ID_MemWrite),
    .EXTOp(ID_EXTOp), .ALUOp(ID_ALUOp), .NPCOp(ID_NPCOp),
    .ALUSrc(ID_ALUSrc), .GPRSel(ID_GPRSel),
    .WDSel(ID_WDSel), .DMType(ID_DMType)
);

// 立即数扩展 (EXT.v 完全复用)
wire [31:0] ID_imm32;
EXT U_EXT (
    .iimm_shamt(ID_iimm_shamt), .iimm(ID_iimm),
    .simm(ID_simm), .bimm(ID_bimm),
    .uimm(ID_uimm), .jimm(ID_jimm),
    .EXTOp(ID_EXTOp), .immout(ID_imm32)
);

// 跳转指令检测
wire ID_is_JAL    = (Op == 7'b1101111);
wire ID_is_JALR   = (Op == 7'b1100111);
wire ID_is_branch = (Op == 7'b1100011);
wire ID_is_MRET   = (ID_instruction == 32'h30200073);
wire ID_is_ECALL  = (ID_instruction == 32'h00000073);   // ECALL 特权中断

// 分支类型编码 (3-bit):
//   000=非分支  001=BEQ  010=BNE   011=BLT
//   100=BGE     101=BLTU 110=BGEU  111=JALR
reg [2:0] ID_branch_type;
always @(*) begin
    if (ID_is_JALR)
        ID_branch_type = 3'b111;
    else if (ID_is_branch)
        case (Funct3)
            3'b000: ID_branch_type = 3'b001;
            3'b001: ID_branch_type = 3'b010;
            3'b100: ID_branch_type = 3'b011;
            3'b101: ID_branch_type = 3'b100;
            3'b110: ID_branch_type = 3'b101;
            3'b111: ID_branch_type = 3'b110;
            default: ID_branch_type = 3'b000;
        endcase
    else
        ID_branch_type = 3'b000;
end

// 跳转目标地址 (ID 级预计算)
wire [31:0] ID_PC            = ID_pcplus4 - 32'd4;
wire [31:0] ID_jal_target    = ID_PC + ID_imm32;
wire [31:0] ID_branch_target = ID_PC + ID_imm32;

// 是否 Load (WDSel[0]=FromMEM)
wire ID_MemRead = ID_WDSel[0];

// === CSR 指令标志 ===
wire ID_is_CSRRW = (Op == 7'b1110011) && (Funct3 == 3'b001);       // CSRRW
wire ID_is_CSRRS = (Op == 7'b1110011) && (Funct3 == 3'b010);       // CSRRS
wire ID_is_CSRRC = (Op == 7'b1110011) && (Funct3 == 3'b011);       // CSRRC
wire ID_is_CSR_write = ID_is_CSRRW | ID_is_CSRRS | ID_is_CSRRC;
wire ID_csr_do_write = (rs1 != 5'd0);  // CSRRW/CSRRS/CSRRC with rs1=x0 → read-only
wire [1:0] ID_csr_funct3 = ID_is_CSRRW ? 2'b01 :
                            ID_is_CSRRS ? 2'b10 :
                            ID_is_CSRRC ? 2'b11 : 2'b00;

// === CSR 寄存器 (posedge clk) ===
reg [31:0] mstatus, mtvec, mepc, mcause;
reg        cpu_in_interrupt;

// CSR 读 (组合逻辑, ID 级使用)
wire [31:0] CSR_read_val;
assign CSR_read_val =
    (csr_addr == `CSR_mstatus) ? mstatus :
    (csr_addr == `CSR_mtvec)   ? mtvec   :
    (csr_addr == `CSR_mepc)    ? mepc    :
    (csr_addr == `CSR_mcause)  ? mcause  :
                                 32'b0;

// === 中断检测 ===
// 前向声明移至模块顶部
wire interrupt_accept;
assign interrupt_accept = INT && mstatus[3]       // INT=1, MIE=1
                          && !pipeline_stall       // 无阻塞
                          && !EX_taken             // 无 EX redirect
                          && !ID_is_JAL            // 无 JAL redirect
                          && !ID_is_MRET           // 不是 MRET
                          && !ID_is_ECALL          // 不是 ECALL (异常优先于中断)
                          && !cpu_in_interrupt;     // 不在中断处理中

// === CSR RAW hazard (连续 CSR 指令) ===
// 检查 ID/EX, EX/MEM, MEM/WB — 直到 CSR 写真正生效 (posedge 之后)
wire csr_raw_hazard;
assign csr_raw_hazard = ID_is_CSR_write && (
    (ID_EX_is_CSR_write  && (ID_EX_csr_addr == csr_addr)) ||
    (EX_MEM_is_CSR_write && (EX_MEM_csr_addr == csr_addr)) ||
    (MEM_WB_is_CSR_write && (MEM_WB_csr_addr == csr_addr))
);

// === mepc 前递 (MRET 读流水线中的最新 mepc 值, 不需要 stall) ===
wire [31:0] mepc_fwd;
assign mepc_fwd =
    (ID_EX_is_CSR_write  && ID_EX_csr_do_write && (ID_EX_csr_addr == `CSR_mepc)) ? ID_EX_csr_wdata :
    (EX_MEM_is_CSR_write && EX_MEM_csr_do_write && (EX_MEM_csr_addr == `CSR_mepc)) ? EX_MEM_csr_wdata :
    (MEM_WB_is_CSR_write && MEM_WB_csr_do_write && (MEM_WB_csr_addr == `CSR_mepc)) ? MEM_WB_csr_wdata :
    mepc;



// 寄存器堆 — 读在 ID 级, 写在 WB 级
wire [31:0] RD1, RD2;
RF U_RF (
    .clk(clk), .rst(reset),
    .RFWr(MEM_WB_RegWrite),
    .A1(rs1), .A2(rs2), .A3(MEM_WB_rd),
    .WD(WB_WD),
    .RD1(RD1), .RD2(RD2),
    .reg_sel(reg_sel), .reg_data(reg_data)
);

// WB→ID 前递
wire WB_fwd_rs1 = MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == rs1);
wire WB_fwd_rs2 = MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == rs2);
wire [31:0] ID_RD1 = WB_fwd_rs1 ? WB_WD : RD1;
wire [31:0] ID_RD2 = WB_fwd_rs2 ? WB_WD : RD2;

// =================== 冒险检测 ===================
Hazard_Unit U_Hazard (
    .ID_EX_MemRead(ID_EX_MemRead),
    .ID_EX_rd(ID_EX_rd),
    .ID_rs1(rs1), .ID_rs2(rs2),
    .ID_is_JAL(ID_is_JAL),
    .EX_taken(EX_taken),
    .interrupt_accept(interrupt_accept),
    .ID_is_MRET(ID_is_MRET),
    .ID_is_ECALL(ID_is_ECALL),
    .csr_raw_hazard(csr_raw_hazard),
    .pipeline_stall(pipeline_stall),
    .kill_IF(kill_IF),
    .kill_ID(kill_ID),
    .IF_ID_freeze(IF_ID_freeze)
);

// =================== ID/EX 寄存器 (304-bit) ===================
// 原有 224-bit + CSR 80-bit (is_csr + do_write + funct3 + addr + wdata + old)
localparam ID_EX_W = 304;
wire [ID_EX_W-1:0] ID_EX_in;
wire [ID_EX_W-1:0] ID_EX_out;

GRE_array #(.WIDTH(ID_EX_W)) ID_EX (
    .Clk(clk), .Rst(reset),
    .write_enable(1'b1), .flush(kill_ID),
    .in(ID_EX_in), .out(ID_EX_out)
);

// csr_wdata = rs1 value (完整前递: EX 组合 → EX/MEM → WB)
// 类似 alu_A 的三级前递, 但增加了 EX 级组合前递 (因消费者在 ID 而非 EX)
wire ex_fwd_csr1 = ID_EX_RegWrite && (ID_EX_rd != 5'd0) && (ID_EX_rd == rs1);
wire ex_fwd_csr2 = EX_MEM_RegWrite && (EX_MEM_rd != 5'd0) && (EX_MEM_rd == rs1);
wire [31:0] ID_csr_wdata = ex_fwd_csr1 ? EX_ALU_result :       // ID_EX 优先 (更新)
                            ex_fwd_csr2 ? EX_MEM_ALU_result :
                                          ID_RD1;  // 含 WB→ID 前递

// store_fwd: rs2 前递 (SW rs2 与 LI/ADDI 等背靠背时, ID_RD2 读到旧值)
wire store_fwd_ex  = ID_EX_RegWrite && (ID_EX_rd != 5'd0) && (ID_EX_rd == rs2);
wire store_fwd_mem = EX_MEM_RegWrite && (EX_MEM_rd != 5'd0) && (EX_MEM_rd == rs2) && ~store_fwd_ex;
wire [31:0] ID_RD2_fwd = store_fwd_ex  ? EX_ALU_result :
                           store_fwd_mem ? EX_MEM_ALU_result :
                                           ID_RD2;

assign ID_EX_in = {
    ID_RegWrite, ID_MemWrite, ID_ALUSrc,          //  3 bits [303:301]
    ID_WDSel,                                      //  2 bits [300:299]
    ID_DMType,                                     //  3 bits [298:296]
    ID_MemRead,                                    //  1 bit  [295]
    ID_branch_type,                                //  3 bits [294:292]
    ID_ALUOp,                                      //  5 bits [291:287]
    ID_RD1,                                        // 32 bits [286:255]
    ID_RD2_fwd,                                    // 32 bits [254:223] (含 rs2 前递)
    ID_imm32,                                      // 32 bits [222:191]
    ID_PC,                                         // 32 bits [190:159]
    ID_pcplus4,                                    // 32 bits [158:127]
    ID_branch_target,                              // 32 bits [126:95]
    rs1,                                           //  5 bits [94:90]
    rs2,                                           //  5 bits [89:85]
    rd,                                            //  5 bits [84:80]
    // === CSR 扩展 ===
    ID_is_CSR_write,                               //  1 bit  [79]
    ID_csr_do_write,                               //  1 bit  [78]
    ID_csr_funct3,                                 //  2 bits [77:76]
    csr_addr,                                      // 12 bits [75:64]
    ID_csr_wdata,                                  // 32 bits [63:32]
    CSR_read_val                                   // 32 bits [31:0]
};

// 解包 ID/EX
assign        ID_EX_RegWrite      = ID_EX_out[303];
assign        ID_EX_MemWrite      = ID_EX_out[302];
assign        ID_EX_ALUSrc        = ID_EX_out[301];
wire [1:0]  ID_EX_WDSel         = ID_EX_out[300:299];
wire [2:0]  ID_EX_DMType        = ID_EX_out[298:296];
assign        ID_EX_MemRead       = ID_EX_out[295];
wire [2:0]  ID_EX_branch_type   = ID_EX_out[294:292];
wire [4:0]  ID_EX_ALUOp         = ID_EX_out[291:287];
wire [31:0] ID_EX_RD1           = ID_EX_out[286:255];
wire [31:0] ID_EX_RD2           = ID_EX_out[254:223];
wire [31:0] ID_EX_imm32         = ID_EX_out[222:191];
wire [31:0] ID_EX_PC            = ID_EX_out[190:159];
wire [31:0] ID_EX_pcplus4       = ID_EX_out[158:127];
wire [31:0] ID_EX_branch_target = ID_EX_out[126:95];
wire [4:0]  ID_EX_rs1           = ID_EX_out[94:90];
wire [4:0]  ID_EX_rs2           = ID_EX_out[89:85];
assign      ID_EX_rd            = ID_EX_out[84:80];
// CSR
assign        ID_EX_is_CSR_write  = ID_EX_out[79];
assign        ID_EX_csr_do_write  = ID_EX_out[78];
wire [1:0]  ID_EX_csr_funct3    = ID_EX_out[77:76];
assign      ID_EX_csr_addr      = ID_EX_out[75:64];
assign      ID_EX_csr_wdata     = ID_EX_out[63:32];
wire [31:0] ID_EX_old_csr_val   = ID_EX_out[31:0];

// =================== EX 级 ===================
// 前递多路选择
wire [1:0] ForwardA, ForwardB;
Forwarding_Unit U_Forward (
    .ID_EX_rs1(ID_EX_rs1), .ID_EX_rs2(ID_EX_rs2),
    .EX_MEM_RegWrite(EX_MEM_RegWrite), .EX_MEM_rd(EX_MEM_rd),
    .EX_MEM_ALU_result(EX_MEM_ALU_result),
    .MEM_WB_RegWrite(MEM_WB_RegWrite), .MEM_WB_rd(MEM_WB_rd),
    .WB_WD(WB_WD),
    .ForwardA(ForwardA), .ForwardB(ForwardB)
);

// ALU 操作数 (含前递)
wire [31:0] alu_A = (ForwardA == 2'b01) ? EX_MEM_ALU_result :
                    (ForwardA == 2'b10) ? WB_WD : ID_EX_RD1;
wire [31:0] alu_B = ID_EX_ALUSrc ? ID_EX_imm32 :
                    (ForwardB == 2'b01) ? EX_MEM_ALU_result :
                    (ForwardB == 2'b10) ? WB_WD : ID_EX_RD2;
// Store 数据
wire [31:0] store_data = (ForwardB == 2'b01) ? EX_MEM_ALU_result :
                         (ForwardB == 2'b10) ? WB_WD : ID_EX_RD2;

// ALU (alu.v 完全复用)
wire        EX_Zero;
alu U_ALU (
    .A(alu_A), .B(alu_B), .ALUOp(ID_EX_ALUOp),
    .C(EX_ALU_result), .Zero(EX_Zero), .PC(ID_EX_PC)
);

// 分支条件决议
reg  branch_taken_reg;
always @(*) begin
    case (ID_EX_branch_type)
        3'b001: branch_taken_reg = (alu_A == alu_B);
        3'b010: branch_taken_reg = (alu_A != alu_B);
        3'b011: branch_taken_reg = ($signed(alu_A) < $signed(alu_B));
        3'b100: branch_taken_reg = ($signed(alu_A) >= $signed(alu_B));
        3'b101: branch_taken_reg = (alu_A < alu_B);
        3'b110: branch_taken_reg = (alu_A >= alu_B);
        3'b111: branch_taken_reg = 1'b1;  // JALR
        default: branch_taken_reg = 1'b0;
    endcase
end
wire branch_taken_cond = branch_taken_reg;

wire EX_is_branch = (ID_EX_branch_type >= 3'b001) && (ID_EX_branch_type <= 3'b110);
wire EX_is_JALR   = (ID_EX_branch_type == 3'b111);
assign EX_taken     = EX_is_JALR | (EX_is_branch && branch_taken_cond);

// 跳转目标
wire [31:0] EX_branch_target = EX_is_JALR
    ? ((alu_A + ID_EX_imm32) & ~32'd1)
    : ID_EX_branch_target;

// =================== EX/MEM 寄存器 (188-bit) ===================
// 原有 108-bit + CSR 80-bit
localparam EX_MEM_W = 188;
wire [EX_MEM_W-1:0] EX_MEM_in;
wire [EX_MEM_W-1:0] EX_MEM_out;

GRE_array #(.WIDTH(EX_MEM_W)) EX_MEM (
    .Clk(clk), .Rst(reset),
    .write_enable(1'b1), .flush(1'b0),
    .in(EX_MEM_in), .out(EX_MEM_out)
);

assign EX_MEM_in = {
    ID_EX_RegWrite, ID_EX_MemWrite,                //  2 bits [187:186]
    ID_EX_WDSel,                                    //  2 bits [185:184]
    ID_EX_DMType,                                   //  3 bits [183:181]
    EX_ALU_result,                                  // 32 bits [180:149]
    store_data,                                     // 32 bits [148:117]
    ID_EX_rd,                                       //  5 bits [116:112]
    ID_EX_pcplus4,                                  // 32 bits [111:80]
    // === CSR 透传 ===
    ID_EX_is_CSR_write,                             //  1 bit  [79]
    ID_EX_csr_do_write,                             //  1 bit  [78]
    ID_EX_csr_funct3,                               //  2 bits [77:76]
    ID_EX_csr_addr,                                 // 12 bits [75:64]
    ID_EX_csr_wdata,                                // 32 bits [63:32]
    ID_EX_old_csr_val                               // 32 bits [31:0]
};

assign        EX_MEM_RegWrite   = EX_MEM_out[187];
assign        EX_MEM_MemWrite   = EX_MEM_out[186];
wire [1:0]  EX_MEM_WDSel      = EX_MEM_out[185:184];
wire [2:0]  EX_MEM_DMType     = EX_MEM_out[183:181];
assign      EX_MEM_ALU_result = EX_MEM_out[180:149];
wire [31:0] EX_MEM_RD2        = EX_MEM_out[148:117];
assign      EX_MEM_rd         = EX_MEM_out[116:112];
wire [31:0] EX_MEM_pcplus4    = EX_MEM_out[111:80];
// CSR
assign        EX_MEM_is_CSR_write = EX_MEM_out[79];
assign        EX_MEM_csr_do_write = EX_MEM_out[78];
wire [1:0]  EX_MEM_csr_funct3   = EX_MEM_out[77:76];
assign      EX_MEM_csr_addr    = EX_MEM_out[75:64];
assign      EX_MEM_csr_wdata   = EX_MEM_out[63:32];
wire [31:0] EX_MEM_old_csr_val = EX_MEM_out[31:0];

// =================== MEM 级 ===================
// DM 在 SCPU 外部, 通过 Addr_out/Data_out/mem_w/dm_ctrl 输出

// =================== MEM/WB 寄存器 (184-bit) ===================
// 原有 104-bit + CSR 80-bit
localparam MEM_WB_W = 184;
wire [MEM_WB_W-1:0] MEM_WB_in;
wire [MEM_WB_W-1:0] MEM_WB_out;

GRE_array #(.WIDTH(MEM_WB_W)) MEM_WB (
    .Clk(clk), .Rst(reset),
    .write_enable(1'b1), .flush(1'b0),
    .in(MEM_WB_in), .out(MEM_WB_out)
);

assign MEM_WB_in = {
    EX_MEM_RegWrite,                                //  1 bit  [183]
    EX_MEM_WDSel,                                   //  2 bits [182:181]
    Data_in,                                        // 32 bits [180:149]
    EX_MEM_ALU_result,                              // 32 bits [148:117]
    EX_MEM_rd,                                      //  5 bits [116:112]
    EX_MEM_pcplus4,                                 // 32 bits [111:80]
    // === CSR 透传 ===
    EX_MEM_is_CSR_write,                            //  1 bit  [79]
    EX_MEM_csr_do_write,                            //  1 bit  [78]
    EX_MEM_csr_funct3,                              //  2 bits [77:76]
    EX_MEM_csr_addr,                                // 12 bits [75:64]
    EX_MEM_csr_wdata,                               // 32 bits [63:32]
    EX_MEM_old_csr_val                              // 32 bits [31:0]
};

assign        MEM_WB_RegWrite   = MEM_WB_out[183];
wire [1:0]  MEM_WB_WDSel      = MEM_WB_out[182:181];
wire [31:0] MEM_WB_Data_in    = MEM_WB_out[180:149];
wire [31:0] MEM_WB_ALU_result = MEM_WB_out[148:117];
assign      MEM_WB_rd         = MEM_WB_out[116:112];
wire [31:0] MEM_WB_pcplus4    = MEM_WB_out[111:80];
// CSR
assign        MEM_WB_is_CSR_write = MEM_WB_out[79];
assign        MEM_WB_csr_do_write = MEM_WB_out[78];
wire [1:0]  MEM_WB_csr_funct3   = MEM_WB_out[77:76];
assign      MEM_WB_csr_addr    = MEM_WB_out[75:64];
assign      MEM_WB_csr_wdata   = MEM_WB_out[63:32];
wire [31:0] MEM_WB_old_csr_val = MEM_WB_out[31:0];

// =================== WB 级 ===================
// 写回数据多路选择
always @(*) begin
    case (MEM_WB_WDSel)
        `WDSel_FromALU: WB_WD = MEM_WB_ALU_result;
        `WDSel_FromMEM: WB_WD = MEM_WB_Data_in;
        `WDSel_FromPC:  WB_WD = MEM_WB_pcplus4;
        `WDSel_FromCSR: WB_WD = MEM_WB_old_csr_val;
        default:        WB_WD = 32'b0;
    endcase
end

// === CSR 写 (posedge clk, 硬件优先级 > 软件) ===
wire [31:0] mtvec_base;
assign mtvec_base = mtvec & ~32'h3;  // 清最低2位(Direct模式)

// CSR 读-改-写: WB 级 combinational 重读 + funct3 译码
wire [31:0] WB_csr_cur =
    (MEM_WB_csr_addr == `CSR_mstatus) ? mstatus :
    (MEM_WB_csr_addr == `CSR_mtvec)   ? mtvec   :
    (MEM_WB_csr_addr == `CSR_mepc)    ? mepc    :
    (MEM_WB_csr_addr == `CSR_mcause)  ? mcause  : 32'b0;
wire [31:0] WB_csr_write_val =
    (MEM_WB_csr_funct3 == 2'b01) ? MEM_WB_csr_wdata :               // CSRRW
    (MEM_WB_csr_funct3 == 2'b10) ? (WB_csr_cur | MEM_WB_csr_wdata) : // CSRRS
    (MEM_WB_csr_funct3 == 2'b11) ? (WB_csr_cur & ~MEM_WB_csr_wdata) : // CSRRC
                                    MEM_WB_csr_wdata;

always @(posedge clk) begin
    if (reset) begin
        mstatus <= 32'h0;
        mtvec   <= 32'h0;
        mepc    <= 32'h0;
        mcause  <= 32'h0;
        cpu_in_interrupt <= 1'b0;
    end else begin
        // --- 硬件写入 (优先级最高) ---
        if (interrupt_accept) begin
            mepc        <= ID_PC;          // 保存 ID 级 PC
            mcause      <= 32'h8000000B;   // 外部中断
            mstatus[3]  <= 1'b0;           // 关 MIE
            cpu_in_interrupt <= 1'b1;
        end
        else if (ID_is_ECALL && !pipeline_stall) begin
            mepc        <= ID_PC;          // 保存 ECALL 的 PC
            mcause      <= 32'h0000000B;   // ECALL from M-mode
            mstatus[3]  <= 1'b0;           // 关 MIE
            cpu_in_interrupt <= 1'b1;
        end
        else if (ID_is_MRET && !pipeline_stall) begin
            mstatus[3]  <= 1'b1;           // 开 MIE
            cpu_in_interrupt <= 1'b0;
        end
        // --- 软件写入 (CSRRW/CSRRS/CSRRC, WB 级) ---
        else if (MEM_WB_is_CSR_write && MEM_WB_csr_do_write) begin
            // mcause 在中断处理中禁止软件写入
            if (MEM_WB_csr_addr == `CSR_mcause && cpu_in_interrupt) begin
                ; // 忽略
            end else begin
                case (MEM_WB_csr_addr)
                    `CSR_mstatus: mstatus <= WB_csr_write_val;
                    `CSR_mtvec:   mtvec   <= WB_csr_write_val;
                    `CSR_mepc:    mepc    <= WB_csr_write_val;
                    `CSR_mcause:  mcause  <= WB_csr_write_val;
                    default:      ;       // 未定义 CSR, 忽略
                endcase
            end
        end
    end
end

// =================== NPC 选择 (IF 级) ===================
// 优先级: Stall > MRET > Interrupt > ECALL > EX > JAL > PC+4
assign IF_NPC = pipeline_stall   ? IF_PC :
                ID_is_MRET       ? mepc_fwd :
                interrupt_accept ? mtvec_base :
                ID_is_ECALL      ? mtvec_base :       // ECALL → mtvec
                EX_taken         ? EX_branch_target :
                ID_is_JAL        ? ID_jal_target :
                                   IF_pcplus4;

// =================== 对外输出 (MEM 级信号) ===================
assign Addr_out = EX_MEM_ALU_result;
assign Data_out = EX_MEM_RD2;
assign mem_w    = EX_MEM_MemWrite;
assign dm_ctrl  = EX_MEM_DMType;
assign PC_out   = IF_PC;
assign CPU_MIO  = EX_MEM_MemWrite | (EX_MEM_WDSel == `WDSel_FromMEM);

endmodule

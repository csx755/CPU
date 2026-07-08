`include "ctrl_encode_def.v"

// SCPU_pipelined — 5 级流水线 RISC-V CPU 顶层
//   IF → ID → EX → MEM → WB
//   对外接口与单周期 SCPU.v 完全一致, 可直接替换到 sccomp/soc_top 中
module SCPU_pipelined (
    input           clk,
    input           reset,          // 高有效复位
    input           MIO_ready,      // [SoC] 暂不使用 (保留兼容)
    input  [31:0]   inst_in,        // 取指 (来自 ROM)
    input  [31:0]   Data_in,        // Load 数据 (来自外部 DM/MIO_BUS)
    input           INT,            // 中断 (暂不使用)
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
    .write_enable(IF_ID_write), .flush(IF_ID_flush),
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

// WB→ID 前递: MEM_WB 正在写且 ID 级正在读同一寄存器时, 直接用 WB_WD
// (解决 RF 的 NBA 写与组合读在同一 posedge 的竞态)
wire WB_fwd_rs1 = MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == rs1);
wire WB_fwd_rs2 = MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == rs2);
wire [31:0] ID_RD1 = WB_fwd_rs1 ? WB_WD : RD1;
wire [31:0] ID_RD2 = WB_fwd_rs2 ? WB_WD : RD2;

// =================== 冒险检测 ===================
wire load_use_hazard, IF_ID_flush, ID_EX_flush, IF_ID_write;
Hazard_Unit U_Hazard (
    .ID_EX_MemRead(ID_EX_MemRead),
    .ID_EX_rd(ID_EX_rd),
    .ID_rs1(rs1), .ID_rs2(rs2),
    .ID_is_JAL(ID_is_JAL),
    .EX_taken(EX_taken),
    .load_use_hazard(load_use_hazard),
    .IF_ID_flush(IF_ID_flush),
    .ID_EX_flush(ID_EX_flush),
    .IF_ID_write(IF_ID_write)
);

// =================== ID/EX 寄存器 (224-bit) ===================
// Packing: [223]=RegWrite [222]=MemWrite [221]=ALUSrc
//   [220:219]=WDSel [218:216]=DMType [215]=MemRead
//   [214:212]=branch_type [211:207]=ALUOp
//   [206:175]=RD1 [174:143]=RD2 [142:111]=imm32
//   [110:79]=PC [78:47]=pcplus4 [46:15]=branch_target
//   [14:10]=rs1 [9:5]=rs2 [4:0]=rd
localparam ID_EX_W = 224;
wire [ID_EX_W-1:0] ID_EX_in;
wire [ID_EX_W-1:0] ID_EX_out;

GRE_array #(.WIDTH(ID_EX_W)) ID_EX (
    .Clk(clk), .Rst(reset),
    .write_enable(1'b1), .flush(ID_EX_flush),
    .in(ID_EX_in), .out(ID_EX_out)
);

assign ID_EX_in = {
    ID_RegWrite, ID_MemWrite, ID_ALUSrc,          //  3 bits [223:221]
    ID_WDSel,                                      //  2 bits [220:219]
    ID_DMType,                                     //  3 bits [218:216]
    ID_MemRead,                                    //  1 bit  [215]
    ID_branch_type,                                //  3 bits [214:212]
    ID_ALUOp,                                      //  5 bits [211:207]
    ID_RD1,                                        // 32 bits [206:175]  (WB→ID 前递后)
    ID_RD2,                                        // 32 bits [174:143]  (WB→ID 前递后)
    ID_imm32,                                      // 32 bits [142:111]
    ID_PC,                                         // 32 bits [110:79]
    ID_pcplus4,                                    // 32 bits [78:47]
    ID_branch_target,                              // 32 bits [46:15]
    rs1,                                           //  5 bits [14:10]
    rs2,                                           //  5 bits [9:5]
    rd                                             //  5 bits [4:0]
};

// 解包 ID/EX
wire        ID_EX_RegWrite      = ID_EX_out[223];
wire        ID_EX_MemWrite      = ID_EX_out[222];
wire        ID_EX_ALUSrc        = ID_EX_out[221];
wire [1:0]  ID_EX_WDSel         = ID_EX_out[220:219];
wire [2:0]  ID_EX_DMType        = ID_EX_out[218:216];
wire        ID_EX_MemRead       = ID_EX_out[215];
wire [2:0]  ID_EX_branch_type   = ID_EX_out[214:212];
wire [4:0]  ID_EX_ALUOp         = ID_EX_out[211:207];
wire [31:0] ID_EX_RD1           = ID_EX_out[206:175];
wire [31:0] ID_EX_RD2           = ID_EX_out[174:143];
wire [31:0] ID_EX_imm32         = ID_EX_out[142:111];
wire [31:0] ID_EX_PC            = ID_EX_out[110:79];
wire [31:0] ID_EX_pcplus4       = ID_EX_out[78:47];
wire [31:0] ID_EX_branch_target = ID_EX_out[46:15];
wire [4:0]  ID_EX_rs1           = ID_EX_out[14:10];
wire [4:0]  ID_EX_rs2           = ID_EX_out[9:5];
wire [4:0]  ID_EX_rd            = ID_EX_out[4:0];

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
// ALU B: 当 ALUSrc=1 (store/load/I-type) 时用立即数, 否则用寄存器值 (含前递)
wire [31:0] alu_B = ID_EX_ALUSrc ? ID_EX_imm32 :
                    (ForwardB == 2'b01) ? EX_MEM_ALU_result :
                    (ForwardB == 2'b10) ? WB_WD : ID_EX_RD2;
// Store 数据: 始终是 rs2 的值 (含前递), 独立于 ALU B
wire [31:0] store_data = (ForwardB == 2'b01) ? EX_MEM_ALU_result :
                         (ForwardB == 2'b10) ? WB_WD : ID_EX_RD2;

// ALU (alu.v 完全复用)
wire [31:0] EX_ALU_result;
wire        EX_Zero;
alu U_ALU (
    .A(alu_A), .B(alu_B), .ALUOp(ID_EX_ALUOp),
    .C(EX_ALU_result), .Zero(EX_Zero), .PC(ID_EX_PC)
);

// 分支条件决议 (直接比较, 不依赖 ALU Zero)
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
wire EX_taken     = EX_is_JALR | (EX_is_branch && branch_taken_cond);

// 跳转目标 (JALR 用 ALU 结果并清除 LSB)
wire [31:0] EX_branch_target = EX_is_JALR
    ? ((alu_A + ID_EX_imm32) & ~32'd1)
    : ID_EX_branch_target;

// =================== EX/MEM 寄存器 (108-bit) ===================
// Packing: [107]=RegWrite [106]=MemWrite [105:104]=WDSel
//   [103:101]=DMType [100:69]=ALU_result [68:37]=RD2
//   [36:32]=rd [31:0]=pcplus4
localparam EX_MEM_W = 108;
wire [EX_MEM_W-1:0] EX_MEM_in;
wire [EX_MEM_W-1:0] EX_MEM_out;

GRE_array #(.WIDTH(EX_MEM_W)) EX_MEM (
    .Clk(clk), .Rst(reset),
    .write_enable(1'b1), .flush(1'b0),
    .in(EX_MEM_in), .out(EX_MEM_out)
);

assign EX_MEM_in = {
    ID_EX_RegWrite, ID_EX_MemWrite,                //  2 bits [107:106]
    ID_EX_WDSel,                                    //  2 bits [105:104]
    ID_EX_DMType,                                   //  3 bits [103:101]
    EX_ALU_result,                                  // 32 bits [100:69]
    store_data,                                     // 32 bits [68:37]  (Store 数据 = RD2 前递)
    ID_EX_rd,                                       //  5 bits [36:32]
    ID_EX_pcplus4                                   // 32 bits [31:0]
};

wire        EX_MEM_RegWrite   = EX_MEM_out[107];
wire        EX_MEM_MemWrite   = EX_MEM_out[106];
wire [1:0]  EX_MEM_WDSel      = EX_MEM_out[105:104];
wire [2:0]  EX_MEM_DMType     = EX_MEM_out[103:101];
wire [31:0] EX_MEM_ALU_result = EX_MEM_out[100:69];
wire [31:0] EX_MEM_RD2        = EX_MEM_out[68:37];
wire [4:0]  EX_MEM_rd         = EX_MEM_out[36:32];
wire [31:0] EX_MEM_pcplus4    = EX_MEM_out[31:0];

// =================== MEM 级 ===================
// DM 在 SCPU 外部, 通过 Addr_out/Data_out/mem_w/dm_ctrl 输出
// Data_in 来自外部 DM, 锁存到 MEM/WB

// =================== MEM/WB 寄存器 (104-bit) ===================
// Packing: [103]=RegWrite [102:101]=WDSel [100:69]=Data_in
//   [68:37]=ALU_result [36:32]=rd [31:0]=pcplus4
localparam MEM_WB_W = 104;
wire [MEM_WB_W-1:0] MEM_WB_in;
wire [MEM_WB_W-1:0] MEM_WB_out;

GRE_array #(.WIDTH(MEM_WB_W)) MEM_WB (
    .Clk(clk), .Rst(reset),
    .write_enable(1'b1), .flush(1'b0),
    .in(MEM_WB_in), .out(MEM_WB_out)
);

assign MEM_WB_in = {
    EX_MEM_RegWrite,                                //  1 bit  [103]
    EX_MEM_WDSel,                                   //  2 bits [102:101]
    Data_in,                                        // 32 bits [100:69]
    EX_MEM_ALU_result,                              // 32 bits [68:37]
    EX_MEM_rd,                                      //  5 bits [36:32]
    EX_MEM_pcplus4                                  // 32 bits [31:0]
};

wire        MEM_WB_RegWrite   = MEM_WB_out[103];
wire [1:0]  MEM_WB_WDSel      = MEM_WB_out[102:101];
wire [31:0] MEM_WB_Data_in    = MEM_WB_out[100:69];
wire [31:0] MEM_WB_ALU_result = MEM_WB_out[68:37];
wire [4:0]  MEM_WB_rd         = MEM_WB_out[36:32];
wire [31:0] MEM_WB_pcplus4    = MEM_WB_out[31:0];

// =================== WB 级 ===================
// 写回数据多路选择
reg [31:0] WB_WD;
always @(*) begin
    case (MEM_WB_WDSel)
        `WDSel_FromALU: WB_WD = MEM_WB_ALU_result;
        `WDSel_FromMEM: WB_WD = MEM_WB_Data_in;
        `WDSel_FromPC:  WB_WD = MEM_WB_pcplus4;
        default:        WB_WD = 32'b0;
    endcase
end

// =================== NPC 选择 (IF 级) ===================
// 优先级: Load-Use 阻塞 > EX 跳转 > ID JAL > 默认 PC+4
assign IF_NPC = (load_use_hazard) ? IF_PC :
                (EX_taken)        ? EX_branch_target :
                (ID_is_JAL)       ? ID_jal_target :
                                    IF_pcplus4;

// =================== 对外输出 (MEM 级信号) ===================
assign Addr_out = EX_MEM_ALU_result;
assign Data_out = EX_MEM_RD2;
assign mem_w    = EX_MEM_MemWrite;
assign dm_ctrl  = EX_MEM_DMType;
assign PC_out   = IF_PC;
assign CPU_MIO  = EX_MEM_MemWrite | (EX_MEM_WDSel == `WDSel_FromMEM);

endmodule

`include "ctrl_encode_def.v"
module SCPU(
    input      clk,
    input      reset,
    input [31:0]  inst_in,
    input [31:0]  Data_in,
    output        mem_w,
    output [31:0] PC_out,
    output [31:0] Addr_out,
    output [31:0] Data_out,
    output [2:0]  DMType,
    input INT,
    input  [4:0]  reg_sel,
    output [31:0] reg_data,
    output CPU_MIO,
    input MIO_ready
);

    // ===== 最简中断：mepc + mtvec + mie（1bit） =====
    reg [31:0] mepc;     // 保存返回地址
    reg [31:0] mtvec;    // 中断入口地址 = 0x200
    reg        mie;      // 全局中断使能（1bit，替代整个 mstatus）

    wire int_signal;

    wire        RegWrite;
    wire MemWrite;
    wire [5:0]  EXTOp;
    wire [4:0]  ALUOp;
    wire [2:0]  NPCOp;
    wire [1:0]  WDSel;
    wire [1:0]  GPRSel;
    wire        ALUSrc;
    wire [31:0] NPC;
    wire [2:0] DMType_ID;

    wire [4:0]  rs1, rs2, rd;
    wire [6:0]  Op;
    wire [6:0]  Funct7;
    wire [2:0]  Funct3;
    wire [31:0] immout;
    wire [31:0] RD1, RD2;
    reg  [31:0] WD;
    wire ecall, mret;

    wire [4:0]  iimm_shamt;
    wire [11:0] iimm, simm, bimm;
    wire [19:0] uimm, jimm;
    wire [1:0] ForwardA, ForwardB;

    assign iimm_shamt = IF_ID_inst[24:20];
    assign iimm       = IF_ID_inst[31:20];
    assign simm       = {IF_ID_inst[31:25], IF_ID_inst[11:7]};
    assign bimm       = {IF_ID_inst[31], IF_ID_inst[7], IF_ID_inst[30:25], IF_ID_inst[11:8]};
    assign uimm       = IF_ID_inst[31:12];
    assign jimm       = {IF_ID_inst[31], IF_ID_inst[19:12], IF_ID_inst[20], IF_ID_inst[30:21]};

    // ===== 中断控制（最简） =====
    exception_ctrl u_exception_ctrl(
        .INT(INT),
        .MIE(mie),
        .INT_Signal(int_signal)
    );

    // ===== CSR 更新（mepc + mie） =====
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mepc  <= 32'h00000000;
            mtvec <= 32'h00000200;  // 固定中断入口
            mie   <= 1'b0;         // 复位关中断
        end else if (int_signal) begin
            mepc <= PC_out;        // 保存当前 PC
            mie  <= 1'b0;          // 中断响应：关中断（防风暴）
        end else if (ecall) begin
            mepc <= PC_out + 4;    // ecall 返回下一条
            mie  <= 1'b1;          // ecall：开中断
        end else if (mret) begin
            mie  <= 1'b1;          // mret：恢复开中断
        end
    end

    // ===== 流水线控制 =====
    hzd u_hzd (
       .IF_ID_rs1(rs1),
       .IF_ID_rs2(rs2),
       .ID_EX_rd(rd_EX),
       .ID_EX_MemRead(ID_EX_MemRead),
       .ID_EX_NPCOp(NPCOp_EX),
       .stall(stall_signal),
       .IF_ID_flush(IF_ID_flush_hzd),
       .PCWrite(PCWrite_hzd)
    );

    fwd u_fwd(
       .RegWrite_MEM(RegWrite_MEM),
       .rd_MEM(rd_MEM),
       .RegWrite_WB(RegWrite_WB),
       .rd_WB(rd_WB),
       .rs1_EX(rs1_EX),
       .rs2_EX(rs2_EX),
       .ForwardA(ForwardA),
       .ForwardB(ForwardB)
    );

    wire stall_signal;
    wire PCWrite_hzd;
    wire IF_ID_flush_hzd;
    wire Branch_or_Jump = |NPCOp_EX;
    wire ID_EX_flush_base = stall_signal | Branch_or_Jump;

    wire ID_EX_flush;
    wire IF_ID_flush;
    wire IF_ID_write_enable;
    wire PCWrite;
    wire flush_all = int_signal | ecall | mret;
    assign ID_EX_flush = ID_EX_flush_base | flush_all;
    assign IF_ID_write_enable = (~stall_signal & ~flush_all) | flush_all;
    assign IF_ID_flush = IF_ID_flush_hzd | flush_all;
    assign PCWrite = PCWrite_hzd | flush_all;

    // ===== 流水线寄存器 =====
    GRE_array #(.WIDTH(200)) IF_ID (
       .Clk(clk), .Rst(reset),
       .write_enable(IF_ID_write_enable), .flush(IF_ID_flush),
       .in(IF_ID_in), .out(IF_ID_out)
    );
    GRE_array #(.WIDTH(200)) ID_EX (
       .Clk(clk), .Rst(reset),
       .write_enable(1'b1), .flush(ID_EX_flush),
       .in(ID_EX_in), .out(ID_EX_out)
    );
    GRE_array #(.WIDTH(200)) EX_MEM (
       .Clk(clk), .Rst(reset),
       .write_enable(1'b1), .flush(1'b0),
       .in(EX_MEM_in), .out(EX_MEM_out)
    );
    GRE_array #(.WIDTH(200)) MEM_WB (
       .Clk(clk), .Rst(reset),
       .write_enable(1'b1), .flush(1'b0),
       .in(MEM_WB_in), .out(MEM_WB_out)
    );

    // IF
    wire [63:0]IF_ID_in;
    assign IF_ID_in = {PC_out, inst_in};

    // IF-ID
    wire [63:0]  IF_ID_out;
    wire [31:0] IF_ID_PC = IF_ID_out[63:32];
    wire [31:0] IF_ID_inst = IF_ID_out[31:0];
    assign Op = IF_ID_inst[6:0];
    assign Funct3 = IF_ID_inst[14:12];
    assign Funct7 = IF_ID_inst[31:25];
    assign rs1 = IF_ID_inst[19:15];
    assign rs2 = IF_ID_inst[24:20];
    assign rd = IF_ID_inst[11:7];

    wire [160:0] ID_EX_in;
    assign ID_EX_in = {RegWrite, MemWrite, ALUOp, ALUSrc,
    GPRSel, WDSel, DMType_ID, NPCOp,
    RD1, RD2, immout, rs1, rs2, rd, IF_ID_PC};

    // ID-EX
    wire [160:0] ID_EX_out;
    wire RegWrite_EX = ID_EX_out[160];
    wire MemWrite_EX = ID_EX_out[159];
    wire [4:0] ALUOp_EX = ID_EX_out[158:154];
    wire ALUSrc_EX = ID_EX_out[153];
    wire [1:0] GPRSel_EX = ID_EX_out[152:151];
    wire [1:0] WDSel_EX = ID_EX_out[150:149];
    wire [2:0] DMType_EX = ID_EX_out[148:146];
    wire [2:0] NPCOp_EX = {ID_EX_out[145:144],ID_EX_out[143]&Zero_EX};
    wire [31:0] RD1_EX = ID_EX_out[142:111];
    wire [31:0] RD2_EX = ID_EX_out[110:79];
    wire [31:0] immout_EX = ID_EX_out[78:47];
    wire [4:0] rs1_EX = ID_EX_out[46:42];
    wire [4:0] rs2_EX = ID_EX_out[41:37];
    wire [4:0] rd_EX = ID_EX_out[36:32];
    wire [31:0] PC_EX = ID_EX_out[31:0];
    wire [31:0] aluout_EX;
    wire Zero_EX;

    wire ID_EX_MemRead;
    assign ID_EX_MemRead = WDSel_EX[0];

    wire [109:0] EX_MEM_in;
    assign EX_MEM_in = {PC_EX,RegWrite_EX, MemWrite_EX,
    WDSel_EX, GPRSel_EX, DMType_EX,
    aluout_EX, RD2_forwarded, rd_EX};

    // EX-MEM
    wire [109:0] EX_MEM_out;
    wire [31:0] PC_MEM = EX_MEM_out[109:78];
    wire RegWrite_MEM = EX_MEM_out[77];
    wire MemWrite_MEM = EX_MEM_out[76];
    wire [1:0] WDSel_MEM = EX_MEM_out[75:74];
    wire [1:0] GPRSel_MEM = EX_MEM_out[73:72];
    wire [2:0] DMType_MEM = EX_MEM_out[71:69];
    wire [31:0] aluout_MEM = EX_MEM_out[68:37];
    wire [31:0] RD2_MEM = EX_MEM_out[36:5];
    wire [4:0] rd_MEM = EX_MEM_out[4:0];

    assign Addr_out = aluout_MEM;
    assign Data_out = RD2_MEM;
    assign mem_w = MemWrite_MEM;
    assign DMType = DMType_MEM;
    assign CPU_MIO = 1'b0;

    wire [103:0] MEM_WB_in;
    assign MEM_WB_in = {PC_MEM,RegWrite_MEM, WDSel_MEM,
     Data_in, aluout_MEM, rd_MEM};

    // MEM-WB
    wire [103:0] MEM_WB_out;
    wire [31:0]PC_WB=MEM_WB_out[103:72];
    wire RegWrite_WB=MEM_WB_out[71];
    wire [1:0] WDSel_WB=MEM_WB_out[70:69];
    wire [31:0] Data_in_WB=MEM_WB_out[68:37];
    wire [31:0] aluout_WB=MEM_WB_out[36:5];
    wire [4:0] rd_WB=MEM_WB_out[4:0];

    wire [31:0] RD1_forwarded = (ForwardA == 2'b00)? RD1_EX :
                                (ForwardA == 2'b01)? WD:
                                (ForwardA == 2'b10)? aluout_MEM : 32'b0;
    wire [31:0] RD2_forwarded = (ForwardB == 2'b00)? RD2_EX :
                                (ForwardB == 2'b01)? WD:
                                (ForwardB == 2'b10)? aluout_MEM : 32'b0;
    wire [31:0] B_EX = ALUSrc_EX? immout_EX : RD2_forwarded;

    // control unit
    ctrl U_ctrl(
        .Op(Op), .Funct7(Funct7), .Funct3(Funct3), .Zero(Zero_EX), .rs2(rs2),
        .RegWrite(RegWrite), .MemWrite(MemWrite),
        .EXTOp(EXTOp), .ALUOp(ALUOp), .NPCOp(NPCOp),
        .ALUSrc(ALUSrc), .GPRSel(GPRSel), .WDSel(WDSel), .DMType(DMType_ID),
        .ecall(ecall), .mret(mret)
    );

    // PC
    PC U_PC(.clk(clk), .rst(reset), .NPC(NPC), .PC(PC_out), .PCWrite(PCWrite));

    // NPC
    NPC U_NPC(.PC(PC_out),.PC_GRE(PC_EX), .NPCOp(NPCOp_EX),
    .IMM(immout_EX), .NPC(NPC), .aluout(aluout_EX),
    .PCWrite(PCWrite),
    .int_signal(int_signal), .mtvec(mtvec), .ecall(ecall), .mret(mret), .mepc(mepc));

    // EXT
    EXT U_EXT(
        .iimm_shamt(iimm_shamt), .iimm(iimm), .simm(simm), .bimm(bimm),
        .uimm(uimm), .jimm(jimm),
        .EXTOp(EXTOp), .immout(immout)
    );

    // Register File
    RF U_RF(
        .clk(clk), .rst(reset),
        .RFWr(RegWrite_WB),
        .A1(rs1), .A2(rs2), .A3(rd_WB),
        .WD(WD),
        .RD1(RD1), .RD2(RD2)
    );

    // ALU
    alu U_alu(.A(RD1_forwarded), .B(B_EX), .ALUOp(ALUOp_EX),
    .C(aluout_EX), .Zero(Zero_EX), .PC(PC_EX));

    // Write data mux
    always @(*) begin
        case (WDSel_WB)
            `WDSel_FromALU: WD = aluout_WB;
            `WDSel_FromMEM: WD = Data_in_WB;
            `WDSel_FromPC:  WD = PC_WB + 4;
            default:        WD = 32'b0;
        endcase
    end

endmodule

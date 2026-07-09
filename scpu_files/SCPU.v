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
    input [4:0]  reg_sel,
    output [31:0] reg_data,
    output CPU_MIO,
    input MIO_ready,
    // 新增：外部中断源
    input [6:0]  int_sources  // [0]=timer, [1-6]=外部中断
);

    wire        RegWrite;
    wire MemWrite;
    wire [5:0]  EXTOp;
    wire [4:0]  ALUOp;
    wire [2:0]  NPCOp;
    wire [1:0]  WDSel;
    wire [1:0]  GPRSel;
    wire        ALUSrc;
    wire [31:0] NPC;
    wire [2:0]  DMType_ID;

    wire [4:0]  rs1, rs2, rd;
    wire [6:0]  Op;
    wire [6:0]  Funct7;
    wire [2:0]  Funct3;
    wire [31:0] immout;
    wire [31:0] RD1, RD2;
    reg  [31:0] WD;

    // ======== 新增：中断/CSR 信号 ========
    wire        ERET_w, ERETN_w, ECALL_w;
    wire        CSR_WE_w;
    wire [1:0]  CSR_OP_w;
    wire [11:0] CSR_ADDR_w;
    wire [31:0] CSR_RDATA;
    wire [7:0]  STATUS_w, INTMASK_w;
    wire [31:0] SEPC_w;
    wire        EXL_w;
    wire        EXL_Set_w;
    wire [2:0]  INT_PEND_w;
    wire        INT_Signal_w;
    wire [31:0] EXC_Vector_w;  // 中断向量地址（由exception_ctrl计算）

    // instruction field extraction
    wire [4:0]  iimm_shamt;
    wire [11:0] iimm, simm, bimm;
    wire [19:0] uimm, jimm;
    wire [11:0] csr_addr_imm;  // CSR指令的imm[31:20]，即CSR地址

    assign iimm_shamt = IF_ID_inst[24:20];
    assign iimm       = IF_ID_inst[31:20];
    assign simm       = {IF_ID_inst[31:25], IF_ID_inst[11:7]};
    assign bimm       = {IF_ID_inst[31], IF_ID_inst[7], IF_ID_inst[30:25], IF_ID_inst[11:8]};
    assign uimm       = IF_ID_inst[31:12];
    assign jimm       = {IF_ID_inst[31], IF_ID_inst[19:12], IF_ID_inst[20], IF_ID_inst[30:21]};
    assign csr_addr_imm = IF_ID_inst[31:20];  // CSR地址是imm[31:20]
    wire [1:0] ForwardA, ForwardB;

    // ======== 流水线控制 ========
    wire stall_signal;
    wire PCWrite;
    wire Branch_or_Jump = |NPCOp_EX | ERET_EX | ERETN_EX;
    wire IF_ID_flush_raw;

    hzd u_hzd (
       .IF_ID_rs1(rs1),
       .IF_ID_rs2(rs2),
       .ID_EX_rd(rd_EX),
       .ID_EX_MemRead(ID_EX_MemRead),
       .ID_EX_NPCOp(NPCOp_EX),
       .stall(stall_signal),
       .IF_ID_flush(IF_ID_flush_raw),
       .PCWrite(PCWrite)
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

    assign ID_EX_flush = stall_signal | Branch_or_Jump;

    // 中断响应时也刷新 IF_ID，冻结 PC
    // 当异常或中断发生时，需要：
    // 1. 保存当前PC和异常原因
    // 2. 刷新前级流水线 (IF/ID, ID/EX)
    // 3. 注意：MEM和WB阶段的指令必须正常完成，不能被阻塞
    // 4. EX/MEM阶段的指令需要根据情况处理：如果已经进入MEM阶段，则继续执行
    wire exc_flush = EXL_Set_w;
    wire eret_flush = ERET_EX | ERETN_EX;
    wire IF_ID_flush = IF_ID_flush_raw | exc_flush | eret_flush;
    // 关键：exc_flush时必须write_enable=1+flush=1才能让GRE_array清零
    // 如果write_enable=0，GRE_array会忽略flush信号，寄存器保持旧值
    wire IF_ID_write_enable = exc_flush | eret_flush | ~stall_signal;
    wire PCWrite_final = PCWrite & ~exc_flush;

    // ======== exception_ctrl ========
    // 根据图片，exception_ctrl应该接收来自EX阶段的异常原因
    // ECALL信号来自EX阶段，这样可以在EX阶段检测到ECALL指令
    exception_ctrl u_exception_ctrl (
        .STATUS     (STATUS_w),
        .INTMASK    (INTMASK_w),
        .EXL        (EXL_w),
        .int_sources(int_sources),
        .ECALL      (ECALL_EX),  // 使用EX阶段的ECALL信号
        .EXL_Set    (EXL_Set_w),
        .INT_PEND   (INT_PEND_w),
        .INT_Signal (INT_Signal_w),
        .EXC_Vector (EXC_Vector_w)
    );

    // ======== csr_unit ========
    csr_unit u_csr_unit (
        .clk       (clk),
        .rst       (reset),
        .csr_we    (CSR_WE_EX),
        .csr_op    (CSR_OP_EX),
        .csr_addr  (CSR_ADDR_EX),
        .csr_wdata (RD1_forwarded),
        .csr_rdata (CSR_RDATA),
        .exl_set   (EXL_Set_w),
        .ret_addr  (PC_EX),           // 异常/中断时保存EX阶段PC（异常指令的PC）
        .scause_in ({5'b0, INT_PEND_w}),
        .eret      (ERET_EX | ERETN_EX),
        .ecall     (ECALL_EX),        // 使用EX阶段的ECALL信号
        .STATUS    (STATUS_w),
        .INTMASK   (INTMASK_w),
        .SEPC      (SEPC_w),
        .EXL       (EXL_w)
    );

    // ======== IF-ID ========
    wire [63:0]IF_ID_in;
    assign IF_ID_in = {PC_out, inst_in};

    wire [63:0]  IF_ID_out;
    wire [31:0] IF_ID_PC = IF_ID_out[63:32];
    wire [31:0] IF_ID_inst = IF_ID_out[31:0];
    assign Op = IF_ID_inst[6:0];
    assign Funct3 = IF_ID_inst[14:12];
    assign Funct7 = IF_ID_inst[31:25];
    assign rs1 = IF_ID_inst[19:15];
    assign rs2 = IF_ID_inst[24:20];
    assign rd = IF_ID_inst[11:7];

    GRE_array #(.WIDTH(64)) IF_ID (
       .Clk(clk),
       .Rst(reset),
       .write_enable(IF_ID_write_enable),
       .flush(IF_ID_flush),
       .in(IF_ID_in),
       .out(IF_ID_out)
    );

    // ======== ID-EX ========
    // 宽度: RegWrite(1)+MemWrite(1)+ALUOp(5)+ALUSrc(1)+GPRSel(2)+WDSel(2)
    //       +DMType(3)+NPCOp(3)+RD1(32)+RD2(32)+immout(32)+rs1(5)+rs2(5)+rd(5)+PC(32)
    //       +ERET(1)+ERETN(1)+ECALL(1)+CSR_WE(1)+CSR_OP(2)+CSR_ADDR(12) = 179
    wire [178:0] ID_EX_in;

    assign ID_EX_in = {RegWrite, MemWrite, ALUOp, ALUSrc,
    GPRSel, WDSel, DMType_ID, NPCOp,
    RD1, RD2, immout, rs1, rs2, rd, IF_ID_PC,
    ERET_w, ERETN_w, ECALL_w, CSR_WE_w, CSR_OP_w, CSR_ADDR_w};

    wire [178:0] ID_EX_out;
    wire RegWrite_EX = ID_EX_out[178];
    wire MemWrite_EX = ID_EX_out[177];
    wire [4:0] ALUOp_EX = ID_EX_out[176:172];
    wire ALUSrc_EX = ID_EX_out[171];
    wire [1:0] GPRSel_EX = ID_EX_out[170:169];
    wire [1:0] WDSel_EX = ID_EX_out[168:167];
    wire [2:0] DMType_EX = ID_EX_out[166:164];
    wire [2:0] NPCOp_EX = {ID_EX_out[163:162], ID_EX_out[161]&Zero_EX};
    wire [31:0] RD1_EX = ID_EX_out[160:129];
    wire [31:0] RD2_EX = ID_EX_out[128:97];
    wire [31:0] immout_EX = ID_EX_out[96:65];
    wire [4:0] rs1_EX = ID_EX_out[64:60];
    wire [4:0] rs2_EX = ID_EX_out[59:55];
    wire [4:0] rd_EX = ID_EX_out[54:50];
    wire [31:0] PC_EX = ID_EX_out[49:18];
    wire ERET_EX     = ID_EX_out[17];
    wire ERETN_EX    = ID_EX_out[16];
    wire ECALL_EX    = ID_EX_out[15];
    wire CSR_WE_EX   = ID_EX_out[14];
    wire [1:0] CSR_OP_EX = ID_EX_out[13:12];
    wire [11:0] CSR_ADDR_EX = ID_EX_out[11:0];

    wire [31:0] aluout_EX;
    wire Zero_EX;

    wire ID_EX_MemRead;
    assign ID_EX_MemRead = WDSel_EX[0];

    GRE_array #(.WIDTH(179)) ID_EX (
       .Clk(clk),
       .Rst(reset),
       .write_enable(1'b1),
       .flush(ID_EX_flush | exc_flush),
       .in(ID_EX_in),
       .out(ID_EX_out)
    );

    // ======== EX-MEM ========
    wire [109:0] EX_MEM_in;

    assign EX_MEM_in = {PC_EX,RegWrite_EX, MemWrite_EX,
    WDSel_EX, GPRSel_EX, DMType_EX,
    aluout_EX, RD2_forwarded, rd_EX};

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

    // 注意：当exc_flush有效时，ID/EX流水线寄存器被清零，EX阶段没有指令
    // 因此EX/MEM流水线寄存器不会被写入新的指令，不需要刷新
    GRE_array #(.WIDTH(110)) EX_MEM (
       .Clk(clk),
       .Rst(reset),
       .write_enable(1'b1),
       .flush(1'b0),  // 不在中断响应时刷新EX/MEM流水线寄存器
       .in(EX_MEM_in),
       .out(EX_MEM_out)
    );

    assign Addr_out = aluout_MEM;
    assign Data_out = RD2_MEM;
    assign mem_w = MemWrite_MEM;
    assign DMType = DMType_MEM;
    assign CPU_MIO = 1'b0;

    // ======== MEM-WB ========
    wire [103:0] MEM_WB_in;

    assign MEM_WB_in = {PC_MEM,RegWrite_MEM, WDSel_MEM,
     Data_in, aluout_MEM, rd_MEM};

    wire [103:0] MEM_WB_out;
    wire [31:0]PC_WB=MEM_WB_out[103:72];
    wire RegWrite_WB=MEM_WB_out[71];
    wire [1:0] WDSel_WB=MEM_WB_out[70:69];
    wire [31:0] Data_in_WB=MEM_WB_out[68:37];
    wire [31:0] aluout_WB=MEM_WB_out[36:5];
    wire [4:0] rd_WB=MEM_WB_out[4:0];

    GRE_array #(.WIDTH(104)) MEM_WB (
       .Clk(clk),
       .Rst(reset),
       .write_enable(1'b1),
       .flush(1'b0),
       .in(MEM_WB_in),
       .out(MEM_WB_out)
    );

    // ======== forwarding mux ========
    wire [31:0] RD1_forwarded = (ForwardA == 2'b00)? RD1_EX :
                                (ForwardA == 2'b01)? WD:
                                (ForwardA == 2'b10)? aluout_MEM : 32'b0;
    wire [31:0] RD2_forwarded = (ForwardB == 2'b00)? RD2_EX :
                                (ForwardB == 2'b01)? WD:
                                (ForwardB == 2'b10)? aluout_MEM : 32'b0;
    wire [31:0] B_EX = ALUSrc_EX? immout_EX : RD2_forwarded;

    // ======== control unit ========
    ctrl U_ctrl(
        .Op(Op), .Funct7(Funct7), .Funct3(Funct3), .Zero(Zero_EX),
        .RegWrite(RegWrite), .MemWrite(MemWrite),
        .EXTOp(EXTOp), .ALUOp(ALUOp), .NPCOp(NPCOp),
        .ALUSrc(ALUSrc), .GPRSel(GPRSel), .WDSel(WDSel), .DMType(DMType_ID),
        .ERET(ERET_w), .ERETN(ERETN_w), .ECALL(ECALL_w),
        .CSR_WE(CSR_WE_w), .CSR_OP(CSR_OP_w), .CSR_ADDR(CSR_ADDR_w),
        .csr_addr_imm(csr_addr_imm)  // 新增：CSR地址输入
    );

    // ======== PC ========
    PC U_PC(.clk(clk), .rst(reset), .NPC(NPC), .PC(PC_out));

    // ======== NPC ========
    NPC U_NPC(.PC(PC_out),.PC_GRE(PC_EX),.NPCOp(NPCOp_EX),
    .IMM(immout_EX),.NPC(NPC),.aluout(aluout_EX),
    .PCWrite(PCWrite_final),
    .SEPC(SEPC_w), .ERET(ERET_EX), .ERETN(ERETN_EX),
    .EXL_Set(EXL_Set_w), .EXC_Vector(EXC_Vector_w));

    // ======== EXT ========
    EXT U_EXT(
        .iimm_shamt(iimm_shamt), .iimm(iimm), .simm(simm), .bimm(bimm),
        .uimm(uimm), .jimm(jimm),
        .EXTOp(EXTOp), .immout(immout)
    );

    // ======== Register File ========
    RF U_RF(
        .clk(clk), .rst(reset),
        .RFWr(RegWrite_WB),
        .A1(rs1), .A2(rs2), .A3(rd_WB),
        .WD(WD),
        .RD1(RD1), .RD2(RD2)
    );

    // ======== ALU ========
    alu U_alu(.A(RD1_forwarded),.B(B_EX),.ALUOp(ALUOp_EX),
    .C(aluout_EX),.Zero(Zero_EX),.PC(PC_EX));

    // ======== Write data mux ========
    always @(*) begin
        case (WDSel_WB)
            `WDSel_FromALU: WD = aluout_WB;
            `WDSel_FromMEM: WD = Data_in_WB;
            `WDSel_FromPC:  WD = PC_WB + 4;
            `WDSel_FromCSR: WD = CSR_RDATA;
            default:        WD = 32'b0;
        endcase
    end

endmodule

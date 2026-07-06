// `include "ctrl_encode_def.v"

// ctrl — RISC-V RV32I 控制单元
module ctrl(Op, Funct7, Funct3, Zero,
            RegWrite, MemWrite,
            EXTOp, ALUOp, NPCOp,
            ALUSrc, GPRSel, WDSel,DMType
            );

   input  [6:0] Op;       // opcode
   input  [6:0] Funct7;    // funct7
   input  [2:0] Funct3;    // funct3
   input        Zero;

   output       RegWrite; // control signal for register write
   output       MemWrite; // control signal for memory write
   output [5:0] EXTOp;    // control signal to signed extension
   output [4:0] ALUOp;    // ALU opertion
   output [2:0] NPCOp;    // next pc operation
   output       ALUSrc;   // ALU source for A
   output [2:0] DMType;
   output [1:0] GPRSel;   // general purpose register selection
   output [1:0] WDSel;    // (register) write data selection

  // === 指令类型译码（按 opcode） ===
  // r format: 0110011
    wire rtype  = ~Op[6]&Op[5]&Op[4]&~Op[3]&~Op[2]&Op[1]&Op[0];
  // i format (load): 0000011
    wire itype_l  = ~Op[6]&~Op[5]&~Op[4]&~Op[3]&~Op[2]&Op[1]&Op[0];
  // i format (ALU imm): 0010011
    wire itype_r  = ~Op[6]&~Op[5]&Op[4]&~Op[3]&~Op[2]&Op[1]&Op[0];
  // s format: 0100011
    wire stype  = ~Op[6]&Op[5]&~Op[4]&~Op[3]&~Op[2]&Op[1]&Op[0];
  // sb format: 1100011
    wire sbtype  = Op[6]&Op[5]&~Op[4]&~Op[3]&~Op[2]&Op[1]&Op[0];
  // jalr: 1100111
    wire i_jalr = Op[6]&Op[5]&~Op[4]&~Op[3]&Op[2]&Op[1]&Op[0];
  // jal: 1101111
    wire i_jal  = Op[6]&Op[5]&~Op[4]&Op[3]&Op[2]&Op[1]&Op[0];

  // === 具体指令译码 ===
  // R-type
    wire i_add  = rtype & ~Funct7[6]&~Funct7[5]&~Funct7[4]&~Funct7[3]&~Funct7[2]&~Funct7[1]&~Funct7[0] & ~Funct3[2]&~Funct3[1]&~Funct3[0]; // add  0000000 000
    wire i_sub  = rtype & ~Funct7[6]& Funct7[5]&~Funct7[4]&~Funct7[3]&~Funct7[2]&~Funct7[1]&~Funct7[0] & ~Funct3[2]&~Funct3[1]&~Funct3[0]; // sub  0100000 000
    wire i_or   = rtype & ~Funct7[6]&~Funct7[5]&~Funct7[4]&~Funct7[3]&~Funct7[2]&~Funct7[1]&~Funct7[0] &  Funct3[2]& Funct3[1]&~Funct3[0]; // or   0000000 110
    wire i_and  = rtype & ~Funct7[6]&~Funct7[5]&~Funct7[4]&~Funct7[3]&~Funct7[2]&~Funct7[1]&~Funct7[0] &  Funct3[2]& Funct3[1]& Funct3[0]; // and  0000000 111

  // I-type ALU (itype_r)
    wire i_addi  = itype_r & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // addi  000
    wire i_ori   = itype_r &  Funct3[2] &  Funct3[1] & ~Funct3[0]; // ori   110
    // Wave 1 新增
    wire i_xori  = itype_r &  Funct3[2] & ~Funct3[1] & ~Funct3[0]; // xori  100
    wire i_andi  = itype_r &  Funct3[2] &  Funct3[1] &  Funct3[0]; // andi  111
    wire i_slli  = itype_r & ~Funct3[2] & ~Funct3[1] &  Funct3[0] & ~Funct7[5]; // slli  001,f7=00
    wire i_srli  = itype_r &  Funct3[2] & ~Funct3[1] &  Funct3[0] & ~Funct7[5]; // srli  101,f7=00
    wire i_srai  = itype_r &  Funct3[2] & ~Funct3[1] &  Funct3[0] &  Funct7[5]; // srai  101,f7=20
    wire i_slti  = itype_r & ~Funct3[2] &  Funct3[1] & ~Funct3[0]; // slti  010
    wire i_sltiu = itype_r & ~Funct3[2] &  Funct3[1] &  Funct3[0]; // sltiu 011

  // S-type
    wire i_sw   =  stype & ~Funct3[2] &  Funct3[1] & ~Funct3[0]; // sw 010

  // Wave 2: U-type
    wire i_lui   = ~Op[6]& Op[5]& Op[4]&~Op[3]& Op[2]& Op[1]& Op[0]; // 0110111
    wire i_auipc = ~Op[6]&~Op[5]& Op[4]&~Op[3]& Op[2]& Op[1]& Op[0]; // 0010111

  // Wave 2: R-type 扩展
    wire i_sll = rtype & ~Funct7[6]&~Funct7[5]&~Funct7[4]&~Funct7[3]&~Funct7[2]&~Funct7[1]&~Funct7[0] & ~Funct3[2]&~Funct3[1]& Funct3[0]; // sll 0000000 001
    wire i_srl = rtype & ~Funct7[6]&~Funct7[5]&~Funct7[4]&~Funct7[3]&~Funct7[2]&~Funct7[1]&~Funct7[0] &  Funct3[2]&~Funct3[1]& Funct3[0]; // srl 0000000 101
    wire i_sra = rtype & ~Funct7[6]& Funct7[5]&~Funct7[4]&~Funct7[3]&~Funct7[2]&~Funct7[1]&~Funct7[0] &  Funct3[2]&~Funct3[1]& Funct3[0]; // sra 0100000 101
    wire i_xor = rtype & ~Funct7[6]&~Funct7[5]&~Funct7[4]&~Funct7[3]&~Funct7[2]&~Funct7[1]&~Funct7[0] &  Funct3[2]&~Funct3[1]&~Funct3[0]; // xor 0000000 100

  // SB-type
    wire i_beq  = sbtype & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // beq 000
    // Wave 2: 分支扩展
    wire i_bne  = sbtype & ~Funct3[2] & ~Funct3[1] &  Funct3[0]; // bne  001
    wire i_blt  = sbtype &  Funct3[2] & ~Funct3[1] & ~Funct3[0]; // blt  100
    wire i_bge  = sbtype &  Funct3[2] & ~Funct3[1] &  Funct3[0]; // bge  101
    wire i_bltu = sbtype &  Funct3[2] &  Funct3[1] & ~Funct3[0]; // bltu 110
    wire i_bgeu = sbtype &  Funct3[2] &  Funct3[1] &  Funct3[0]; // bgeu 111

  // === 控制信号生成 ===

  // RegWrite: 需要写寄存器的指令
  assign RegWrite = rtype | itype_r | itype_l | i_jalr | i_jal | i_lui | i_auipc;

  // MemWrite: 需要写数据存储器的指令（S-type）
  assign MemWrite = stype;

  // ALUSrc: ALU 的 B 操作数选择 0=RD2, 1=立即数
  assign ALUSrc = itype_r | itype_l | stype | i_jal | i_jalr | i_lui | i_auipc;

  // EXTOp[5:0] — 独热码，选择立即数格式
  // [5]=ITYPE_SHAMT, [4]=ITYPE, [3]=STYPE, [2]=BTYPE, [1]=UTYPE, [0]=JTYPE
  assign EXTOp[5] = i_slli | i_srli | i_srai;                     // 移位立即数(5-bit 零扩展)
  assign EXTOp[4] = itype_r & ~(i_slli | i_srli | i_srai) | itype_l | i_jalr; // I-type 12-bit (排除移位指令)
  assign EXTOp[3] = stype;                                          // S-type
  assign EXTOp[2] = sbtype;                                         // B-type
  assign EXTOp[1] = i_lui | i_auipc;                                   // U-type
  assign EXTOp[0] = i_jal;                                          // J-type

  // WDSel[1:0] — 写回数据选择
  // 00=FromALU, 01=FromMEM, 10=FromPC
  assign WDSel[0] = itype_l;                    // Load 指令从 MEM 写回
  assign WDSel[1] = i_jal | i_jalr;              // JAL/JALR 从 PC+4 写回

  // NPCOp[2:0] — 下一 PC 选择
  // 000=PLUS4, 001=BRANCH, 010=JUMP, 100=JALR
  assign NPCOp[0] = sbtype & Zero;               // 分支条件满足
  assign NPCOp[1] = i_jal;                       // JAL
  assign NPCOp[2] = i_jalr;                      // JALR

  // ALUOp[4:0] — ALU 操作码
  // 编码规则：按指令映射到 5-bit 操作码（见 ctrl_encode_def.v）
  assign ALUOp[0] = itype_l | stype | i_addi | i_add | i_or | i_ori | i_jalr | i_slli | i_sll | i_srai | i_sra | i_sltiu | i_lui | i_bne | i_bge | i_bgeu;
  assign ALUOp[1] = i_jalr | itype_l | stype | i_addi | i_add | i_and | i_andi | i_slli | i_sll | i_slti | i_sltiu | i_auipc | i_blt | i_bge;
  assign ALUOp[2] = i_sub | i_beq | i_or | i_ori | i_and | i_andi | i_xori | i_xor | i_slli | i_sll | i_bne | i_blt | i_bge;
  assign ALUOp[3] = i_or | i_ori | i_and | i_andi | i_xori | i_xor | i_slli | i_sll | i_slti | i_sltiu | i_bltu | i_bgeu;
  assign ALUOp[4] = i_srli | i_srai | i_srl | i_sra;

  // DMType — 访存类型 (Wave 3 启用，当前 word-only)
  assign DMType = `dm_word;

  // GPRSel — 通用寄存器选择 (预留，未用)
  assign GPRSel = `GPRSel_RD;

endmodule

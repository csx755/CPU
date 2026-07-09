`include "ctrl_encode_def.v"

module ctrl(Op, Funct7, Funct3, Zero,
            RegWrite, MemWrite,
            EXTOp, ALUOp, NPCOp,
            ALUSrc, GPRSel, WDSel, DMType,
            // 新增：中断/CSR 控制信号
            ERET, ERETN, ECALL, CSR_WE, CSR_OP, CSR_ADDR,
            csr_addr_imm);  // 新增：CSR地址输入

   input  [6:0] Op;
   input  [6:0] Funct7;
   input  [2:0] Funct3;
   input        Zero;
   input  [11:0] csr_addr_imm;  // 新增：CSR地址输入（imm[31:20]）

   output       RegWrite;
   output       MemWrite;
   output [5:0] EXTOp;
   output [4:0] ALUOp;
   output [2:0] NPCOp;
   output       ALUSrc;
   output [1:0] GPRSel;
   output [1:0] WDSel;
   output [2:0] DMType;
   // 新增输出
   output       ERET;        // ERET 指令
   output       ERETN;       // ERETN 指令
   output       ECALL;       // ECALL 指令（软件触发异常）
   output       CSR_WE;      // CSR 写使能
   output [1:0] CSR_OP;      // CSR 操作: 01=CSRRW, 10=CSRRS, 11=CSRRC
   output [11:0] CSR_ADDR;   // CSR 地址

   // ======== R-type (0110011) ========
   wire rtype  = ~Op[6] & Op[5] & Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0];
   wire i_add  = rtype & ~Funct7[6] & ~Funct7[5] & ~Funct7[4] & ~Funct7[3] & ~Funct7[2] & ~Funct7[1] & ~Funct7[0]
                 & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // add  0000000 000
   wire i_sub  = rtype & ~Funct7[6] &  Funct7[5] & ~Funct7[4] & ~Funct7[3] & ~Funct7[2] & ~Funct7[1] & ~Funct7[0]
                 & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // sub  0100000 000
   wire i_sll  = rtype & ~Funct7[6] & ~Funct7[5] & ~Funct7[4] & ~Funct7[3] & ~Funct7[2] & ~Funct7[1] & ~Funct7[0]
                 & ~Funct3[2] & ~Funct3[1] &  Funct3[0]; // sll  0000000 001
   wire i_slt  = rtype & ~Funct7[6] & ~Funct7[5] & ~Funct7[4] & ~Funct7[3] & ~Funct7[2] & ~Funct7[1] & ~Funct7[0]
                 & ~Funct3[2] &  Funct3[1] & ~Funct3[0]; // slt  0000000 010
   wire i_sltu = rtype & ~Funct7[6] & ~Funct7[5] & ~Funct7[4] & ~Funct7[3] & ~Funct7[2] & ~Funct7[1] & ~Funct7[0]
                 & ~Funct3[2] &  Funct3[1] &  Funct3[0]; // sltu 0000000 011
   wire i_xor  = rtype & ~Funct7[6] & ~Funct7[5] & ~Funct7[4] & ~Funct7[3] & ~Funct7[2] & ~Funct7[1] & ~Funct7[0]
                 &  Funct3[2] & ~Funct3[1] & ~Funct3[0]; // xor  0000000 100
   wire i_srl  = rtype & ~Funct7[6] & ~Funct7[5] & ~Funct7[4] & ~Funct7[3] & ~Funct7[2] & ~Funct7[1] & ~Funct7[0]
                 &  Funct3[2] & ~Funct3[1] &  Funct3[0]; // srl  0000000 101
   wire i_sra  = rtype & ~Funct7[6] &  Funct7[5] & ~Funct7[4] & ~Funct7[3] & ~Funct7[2] & ~Funct7[1] & ~Funct7[0]
                 &  Funct3[2] & ~Funct3[1] &  Funct3[0]; // sra  0100000 101
   wire i_or   = rtype & ~Funct7[6] & ~Funct7[5] & ~Funct7[4] & ~Funct7[3] & ~Funct7[2] & ~Funct7[1] & ~Funct7[0]
                 &  Funct3[2] &  Funct3[1] & ~Funct3[0]; // or   0000000 110
   wire i_and  = rtype & ~Funct7[6] & ~Funct7[5] & ~Funct7[4] & ~Funct7[3] & ~Funct7[2] & ~Funct7[1] & ~Funct7[0]
                 &  Funct3[2] &  Funct3[1] &  Funct3[0]; // and  0000000 111

   // ======== I-type load (0000011) ========
   wire itype_l = ~Op[6] & ~Op[5] & ~Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0];
   wire i_lb    = itype_l & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // lb  000
   wire i_lh    = itype_l & ~Funct3[2] & ~Funct3[1] &  Funct3[0]; // lh  001
   wire i_lw    = itype_l & ~Funct3[2] &  Funct3[1] & ~Funct3[0]; // lw  010
   wire i_lbu   = itype_l &  Funct3[2] & ~Funct3[1] & ~Funct3[0]; // lbu 100
   wire i_lhu   = itype_l &  Funct3[2] & ~Funct3[1] &  Funct3[0]; // lhu 101

   // ======== I-type reg-imm (0010011) ========
   wire itype_r = ~Op[6] & ~Op[5] & Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0];
   wire i_addi  = itype_r & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // addi  000
   wire i_slti  = itype_r & ~Funct3[2] &  Funct3[1] & ~Funct3[0]; // slti  010
   wire i_sltiu = itype_r & ~Funct3[2] &  Funct3[1] &  Funct3[0]; // sltiu 011
   wire i_xori  = itype_r &  Funct3[2] & ~Funct3[1] & ~Funct3[0]; // xori  100
   wire i_ori   = itype_r &  Funct3[2] &  Funct3[1] & ~Funct3[0]; // ori   110
   wire i_andi  = itype_r &  Funct3[2] &  Funct3[1] &  Funct3[0]; // andi  111
   wire i_slli  = itype_r & ~Funct7[6] & ~Funct7[5] & ~Funct7[4] & ~Funct7[3] & ~Funct7[2] & ~Funct7[1] & ~Funct7[0]
                  & ~Funct3[2] & ~Funct3[1] &  Funct3[0]; // slli 0000000 001
   wire i_srli  = itype_r & ~Funct7[6] & ~Funct7[5] & ~Funct7[4] & ~Funct7[3] & ~Funct7[2] & ~Funct7[1] & ~Funct7[0]
                  &  Funct3[2] & ~Funct3[1] &  Funct3[0]; // srli 0000000 101
   wire i_srai  = itype_r & ~Funct7[6] &  Funct7[5] & ~Funct7[4] & ~Funct7[3] & ~Funct7[2] & ~Funct7[1] & ~Funct7[0]
                  &  Funct3[2] & ~Funct3[1] &  Funct3[0]; // srai 0100000 101

   // ======== I-type JALR (1100111) ========
   wire i_jalr = Op[6] & Op[5] & ~Op[4] & ~Op[3] & Op[2] & Op[1] & Op[0];

   // ======== S-type (0100011) ========
   wire stype  = ~Op[6] & Op[5] & ~Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0];
   wire i_sb   = stype & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // sb 000
   wire i_sh   = stype & ~Funct3[2] & ~Funct3[1] &  Funct3[0]; // sh 001
   wire i_sw   = stype & ~Funct3[2] &  Funct3[1] & ~Funct3[0]; // sw 010

   // ======== B-type (1100011) ========
   wire sbtype  = Op[6] & Op[5] & ~Op[4] & ~Op[3] & ~Op[2] & Op[1] & Op[0];
   wire i_beq  = sbtype & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]; // beq  000
   wire i_bne  = sbtype & ~Funct3[2] & ~Funct3[1] &  Funct3[0]; // bne  001
   wire i_blt  = sbtype &  Funct3[2] & ~Funct3[1] & ~Funct3[0]; // blt  100
   wire i_bge  = sbtype &  Funct3[2] & ~Funct3[1] &  Funct3[0]; // bge  101
   wire i_bltu = sbtype &  Funct3[2] &  Funct3[1] & ~Funct3[0]; // bltu 110
   wire i_bgeu = sbtype &  Funct3[2] &  Funct3[1] &  Funct3[0]; // bgeu 111

   // ======== U-type ========
   wire i_lui   = ~Op[6] &  Op[5] &  Op[4] & ~Op[3] &  Op[2] &  Op[1] &  Op[0]; // lui   0110111
   wire i_auipc = ~Op[6] & ~Op[5] &  Op[4] & ~Op[3] &  Op[2] &  Op[1] &  Op[0]; // auipc 0010111

   // ======== J-type (1101111) ========
   wire i_jal = Op[6] & Op[5] & ~Op[4] & Op[3] & Op[2] & Op[1] & Op[0];

   // ======== SYSTEM type (1110011) — ECALL/ERET/ERETN/CSR ========
   wire system_type = Op[6] & Op[5] & ~Op[4] & Op[3] & Op[2] & Op[1] & Op[0]; // 1110011

   // SYSTEM类型指令使用 imm[11:0] (即 csr_addr_imm) 来区分 ECALL/ERET/ERETN
   // ECALL: imm[11:0] = 0x000 (000000000000)
   // ERET:  imm[11:0] = 0x002 (000000000010)
   // ERETN: imm[11:0] = 0x003 (000000000011)
   wire i_ecall = system_type & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]
                  & (csr_addr_imm == 12'h000);

   wire i_eret = system_type & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]
                 & (csr_addr_imm == 12'h002);

   wire i_eretn = system_type & ~Funct3[2] & ~Funct3[1] & ~Funct3[0]
                  & (csr_addr_imm == 12'h003);

   // CSR instructions: funct3=001(CSRRW), 010(CSRRS), 011(CSRRC)
   wire i_csr   = system_type & ~Funct3[2] & ((Funct3[1] ^ Funct3[0])); // funct3=001,010,011
   wire i_csrrw = i_csr & ~Funct3[1] &  Funct3[0]; // CSRRW 001
   wire i_csrrs = i_csr &  Funct3[1] & ~Funct3[0]; // CSRRS 010
   wire i_csrrc = i_csr &  Funct3[1] &  Funct3[0]; // CSRRC 011

   // ==================== control signals ====================

   // RegWrite — CSR 指令也写 rd
   assign RegWrite = rtype | itype_r | itype_l | i_jalr | i_jal | i_lui | i_auipc
                    | i_csrrw | i_csrrs | i_csrrc;

   // MemWrite
   assign MemWrite = stype;

   // ALUSrc: 0=RD2, 1=immout
   assign ALUSrc = itype_r | stype | itype_l | i_jalr | i_lui | i_auipc;

   // EXTOp
   assign EXTOp[5] = i_slli | i_srli | i_srai; // ITYPE_SHAMT
   assign EXTOp[4] = (itype_r & ~i_slli & ~i_srli & ~i_srai) | itype_l | i_jalr; // ITYPE (exclude shift-imm)
   assign EXTOp[3] = stype;                       // STYPE
   assign EXTOp[2] = sbtype;                      // BTYPE
   assign EXTOp[1] = i_lui | i_auipc;             // UTYPE
   assign EXTOp[0] = i_jal;                       // JTYPE

   // WDSel: 00=ALU, 01=MEM, 10=PC+4, 11=CSR
   assign WDSel[0] = itype_l | i_csrrw | i_csrrs | i_csrrc;
   assign WDSel[1] = i_jal | i_jalr | i_csrrw | i_csrrs | i_csrrc;

   // GPRSel (kept simple, rd always used)
   assign GPRSel = `GPRSel_RD;

   // NPCOp
   assign NPCOp[0] = sbtype;//&Zero // branch taken
   assign NPCOp[1] = i_jal;
   assign NPCOp[2] = i_jalr;

   // ALUOp encoding
   assign ALUOp[0] = i_add | i_addi | stype | itype_l | i_jalr
                    | i_bne | i_bge | i_sltu | i_sltiu | i_bgeu
                    | i_or  | i_ori | i_sll  | i_slli | i_sra | i_srai | i_lui;
   assign ALUOp[1] = i_add | i_addi | stype | itype_l | i_jalr
                    | i_blt | i_bge | i_slt | i_slti | i_sltiu
                    | i_and | i_andi | i_sll | i_slli | i_auipc;
   assign ALUOp[2] = i_sub | i_beq | i_bne | i_blt | i_bge
                    | i_xor | i_xori | i_or | i_ori | i_and | i_andi | i_sll | i_slli;
   assign ALUOp[3] = i_bltu | i_bgeu
                    | i_slt  | i_slti | i_sltu | i_sltiu
                    | i_xor  | i_xori | i_or   | i_ori
                    | i_and  | i_andi | i_sll  | i_slli;
   assign ALUOp[4] = i_srl | i_srli | i_sra | i_srai;

   // DMType
   assign DMType[2] = i_lbu;
   assign DMType[1] = i_lb | i_sb | i_lhu;
   assign DMType[0] = i_lh | i_sh | i_lb | i_sb;

   // ======== 新增：中断/CSR 控制信号 ========
   assign ERET     = i_eret;
   assign ERETN    = i_eretn;
   assign ECALL    = i_ecall;
   assign CSR_WE   = i_csrrw | i_csrrs | i_csrrc;
   assign CSR_OP   = i_csrrw ? 2'b01 :
                     i_csrrs ? 2'b10 :
                     i_csrrc ? 2'b11 : 2'b00;
   // CSR 地址 = imm[31:20]，即指令的[31:20]位
   // 对于CSR指令，imm[31:20]就是CSR地址
   assign CSR_ADDR = csr_addr_imm;  // 使用从SCPU传入的CSR地址

endmodule

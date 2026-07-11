`include "ctrl_encode_def.v"

module ctrl(Op, Funct7, Funct3, Zero, rs2,
            RegWrite, MemWrite,
            EXTOp, ALUOp, NPCOp,
            ALUSrc, GPRSel, WDSel, DMType,
            ecall, mret);

   input  [6:0] Op;
   input  [6:0] Funct7;
   input  [2:0] Funct3;
   input        Zero;
   input  [4:0] rs2;

   output       RegWrite;
   output       MemWrite;
   output [5:0] EXTOp;
   output [4:0] ALUOp;
   output [2:0] NPCOp;
   output       ALUSrc;
   output [1:0] GPRSel;
   output [1:0] WDSel;
   output [2:0] DMType;
   output       ecall;
   output       mret;

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

   // ======== SYSTEM (1110011) ========
   wire i_ecall = (Op == 7'b1110011) & (Funct3 == 3'b000) & (Funct7 == 7'b0000000) & (rs2 == 5'b00000);
   wire i_mret  = (Op == 7'b1110011) & (Funct3 == 3'b000) & (Funct7 == 7'b0011000) & (rs2 == 5'b00010);

   // ==================== control signals ====================

   // RegWrite
   assign RegWrite = rtype | itype_r | itype_l | i_jalr | i_jal | i_lui | i_auipc;

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

   // WDSel: 00=ALU, 01=MEM, 10=PC+4
   assign WDSel[0] = itype_l;
   assign WDSel[1] = i_jal | i_jalr;

   // GPRSel (kept simple, rd always used)
   assign GPRSel = `GPRSel_RD;

   // NPCOp
   assign NPCOp[0] = sbtype;//&Zero // branch taken (beq/bne/bge/bgeu use Zero from ALU)
   assign NPCOp[1] = i_jal;
   assign NPCOp[2] = i_jalr;

   // ALUOp encoding (matches ctrl_encode_def.v one-hot style)
   // Bit0: 00001 LUI; 00011 ADD/ADDI/LW/SW/JALR; 00101 BNE; 00111 BGE;
   //       01011 SLTU/SLTIU; 01101 OR/ORI; 01111 SLL/SLLI; 10001 SRA/SRAI
   assign ALUOp[0] = i_add | i_addi | stype | itype_l | i_jalr
                    | i_bne | i_bge | i_sltu | i_sltiu | i_bgeu
                    | i_or  | i_ori | i_sll  | i_slli | i_sra | i_srai | i_lui;
   // Bit1: 00010 AUIPC; 00011 ADD/ADDI/LW/SW/JALR; 00110 BLT; 00111 BGE;
   //       01010 SLT/SLTI; 01110 AND/ANDI; 01111 SLL/SLLI
   assign ALUOp[1] = i_add | i_addi | stype | itype_l | i_jalr
                    | i_blt | i_bge | i_slt | i_slti | i_sltiu
                    | i_and | i_andi | i_sll | i_slli | i_auipc;
   // Bit2: 00100 SUB/BEQ; 00101 BNE; 00110 BLT; 00111 BGE;
   //       01100 XOR/XORI; 01101 OR/ORI; 01111 SLL/SLLI
   assign ALUOp[2] = i_sub | i_beq | i_bne | i_blt | i_bge
                    | i_xor | i_xori | i_or | i_ori | i_and | i_andi | i_sll | i_slli;
   // Bit3: 01000 BLTU; 01001 BGEU; 01010 SLT/SLTI; 01011 SLTU/SLTIU;
   //       01100 XOR/XORI; 01101 OR/ORI; 01110 AND/ANDI; 01111 SLL/SLLI
   assign ALUOp[3] = i_bltu | i_bgeu
                    | i_slt  | i_slti | i_sltu | i_sltiu
                    | i_xor  | i_xori | i_or   | i_ori
                    | i_and  | i_andi | i_sll  | i_slli;
   // Bit4: 10000 SRL/SRLI; 10001 SRA/SRAI
   assign ALUOp[4] = i_srl | i_srli | i_sra | i_srai;

   // DMType (matches ctrl_encode_def.v: 000=word, 001=half, 010=half_u, 011=byte, 100=byte_u)
   assign DMType[2] = i_lbu;                   // 100=byte_unsigned
   assign DMType[1] = i_lb | i_sb | i_lhu;     // 010=halfword_unsigned, 011=byte
   assign DMType[0] = i_lh | i_sh | i_lb | i_sb; // 001=halfword, 011=byte

   // ecall and mret
   assign ecall = i_ecall;
   assign mret = i_mret;

endmodule

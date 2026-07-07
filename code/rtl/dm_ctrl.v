// =============================================================================
// dm_ctrl — 数据存储器访问控制器
// 功能：处理 byte/halfword/word 内存访问的对齐和扩展
//   - 读路径：从 32-bit 原始数据中提取对应字节/半字，做符号/零扩展
//   - 写路径：生成字节写使能 + 数据复制到对应字节位置
// 纯组合逻辑，替换原 .edf 黑盒
// =============================================================================

module dm_ctrl(
    input           mem_w,              // 写使能 (1=写, 0=读)
    input  [31:0]   Addr_in,            // 访存地址
    input  [31:0]   Data_write,         // 写数据 (来自 MIO_BUS)
    input  [2:0]    dm_ctrl,            // 访存类型
    input  [31:0]   Data_read_from_dm,  // RAM 原始读数据 (来自 MIO_BUS)
    output [31:0]   Data_read,          // 处理后读数据 → SCPU
    output [31:0]   Data_write_to_dm,   // 对齐后写数据 → RAM_B
    output [3:0]    wea_mem             // 字节-写使能
);

// =============================================================================
// dm_ctrl 编码 (来自 ctrl_encode_def.v)
// =============================================================================
localparam DM_WORD           = 3'b000;  // SW / LW
localparam DM_HALF_SIGNED    = 3'b001;  // LH
localparam DM_HALF_UNSIGNED  = 3'b010;  // LHU
localparam DM_BYTE_SIGNED    = 3'b011;  // LB
localparam DM_BYTE_UNSIGNED  = 3'b100;  // LBU

// =============================================================================
// 内部变量
// =============================================================================
reg [31:0] read_data;
reg [31:0] write_data;
reg [3:0]  wea;

// =============================================================================
// 写路径：生成 wea_mem + Data_write_to_dm
// =============================================================================
always @(*) begin
    if (mem_w) begin
        case (dm_ctrl)
            DM_WORD: begin
                // SW: 全字写入
                wea        = 4'b1111;
                write_data = Data_write;
            end
            DM_HALF_SIGNED, DM_HALF_UNSIGNED: begin
                // SH: 半字写入，wea 由地址[1] 决定写低/高 16 位
                // 数据复制到两个半字，配合 wea 掩码实现正确写入
                if (Addr_in[1])
                    wea = 4'b1100;      // 写高 16 位 [31:16]
                else
                    wea = 4'b0011;      // 写低 16 位 [15:0]
                write_data = {Data_write[15:0], Data_write[15:0]};
            end
            DM_BYTE_SIGNED, DM_BYTE_UNSIGNED: begin
                // SB: 字节写入，wea 由地址[1:0] 决定写哪个字节
                // 数据复制到 4 个字节，配合 wea 掩码实现正确写入
                case (Addr_in[1:0])
                    2'b00: wea = 4'b0001;   // [7:0]
                    2'b01: wea = 4'b0010;   // [15:8]
                    2'b10: wea = 4'b0100;   // [23:16]
                    2'b11: wea = 4'b1000;   // [31:24]
                endcase
                write_data = {4{Data_write[7:0]}};
            end
            default: begin
                wea        = 4'b0000;
                write_data = 32'b0;
            end
        endcase
    end else begin
        // 读操作
        wea        = 4'b0000;
        write_data = 32'b0;
    end
end

// =============================================================================
// 读路径：从 Data_read_from_dm 提取并进行符号/零扩展
// =============================================================================
always @(*) begin
    case (dm_ctrl)
        DM_WORD: begin
            // LW: 直通
            read_data = Data_read_from_dm;
        end
        DM_HALF_SIGNED: begin
            // LH: 按地址[1] 选择半字，符号扩展
            if (Addr_in[1])
                read_data = {{16{Data_read_from_dm[31]}}, Data_read_from_dm[31:16]};
            else
                read_data = {{16{Data_read_from_dm[15]}}, Data_read_from_dm[15:0]};
        end
        DM_HALF_UNSIGNED: begin
            // LHU: 按地址[1] 选择半字，零扩展
            if (Addr_in[1])
                read_data = {16'b0, Data_read_from_dm[31:16]};
            else
                read_data = {16'b0, Data_read_from_dm[15:0]};
        end
        DM_BYTE_SIGNED: begin
            // LB: 按地址[1:0] 选择字节，符号扩展
            case (Addr_in[1:0])
                2'b00: read_data = {{24{Data_read_from_dm[7]}},   Data_read_from_dm[7:0]};
                2'b01: read_data = {{24{Data_read_from_dm[15]}},  Data_read_from_dm[15:8]};
                2'b10: read_data = {{24{Data_read_from_dm[23]}},  Data_read_from_dm[23:16]};
                2'b11: read_data = {{24{Data_read_from_dm[31]}},  Data_read_from_dm[31:24]};
            endcase
        end
        DM_BYTE_UNSIGNED: begin
            // LBU: 按地址[1:0] 选择字节，零扩展
            case (Addr_in[1:0])
                2'b00: read_data = {24'b0, Data_read_from_dm[7:0]};
                2'b01: read_data = {24'b0, Data_read_from_dm[15:8]};
                2'b10: read_data = {24'b0, Data_read_from_dm[23:16]};
                2'b11: read_data = {24'b0, Data_read_from_dm[31:24]};
            endcase
        end
        default: begin
            read_data = Data_read_from_dm;
        end
    endcase
end

// =============================================================================
// 输出赋值
// =============================================================================
assign Data_read        = read_data;
assign Data_write_to_dm = write_data;
assign wea_mem          = wea;

endmodule

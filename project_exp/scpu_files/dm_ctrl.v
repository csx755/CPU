module dm_ctrl(
    input mem_w,
    input [31:0]Addr_in,
    input [31:0]Data_write,
    input [2:0]dm_ctrl,
    input [31:0]Data_read_from_dm,
    output reg[31:0]Data_read,
    output reg[31:0]Data_write_to_dm,
    output reg[3:0]wea_mem
    );

always @(*) 
    begin
        if (mem_w) begin
            case (dm_ctrl)
                `dm_word:begin
                    Data_write_to_dm=Data_write;
                    wea_mem=4'b1111;
                end
                `dm_halfword,`dm_halfword_unsigned:begin
                    case(Addr_in[1])
                        1'b1:begin
                            Data_write_to_dm[31:16]=Data_write[15:0];
                            wea_mem=4'b1100;
                        end         
                        1'b0:begin
                            Data_write_to_dm[15:0]=Data_write[15:0];
                            wea_mem=4'b0011;
                        end
                    endcase
                end
                `dm_byte,`dm_byte_unsigned:begin
                    case(Addr_in[1:0])
                        2'b00:begin
                            Data_write_to_dm[7:0]=Data_write[7:0];
                            wea_mem = 4'b0001;
                        end
                        2'b01:begin
                            Data_write_to_dm[15:8]=Data_write[7:0];
                            wea_mem = 4'b0010;
                        end
                        2'b10:begin
                            Data_write_to_dm[23:16]=Data_write[7:0];
                            wea_mem = 4'b0100;
                        end
                        2'b11:begin
                            Data_write_to_dm[31:24]=Data_write[7:0];
                            wea_mem = 4'b1000;
                        end
                    endcase
                end
                default:begin
                    Data_write_to_dm=32'b0;
                    wea_mem=4'b0000;
                end
            endcase
            Data_read = 32'b0;
        end
        else begin
            case (dm_ctrl)
                `dm_word:begin
                    Data_read = Data_read_from_dm;
                end
                `dm_halfword:begin
                    case(Addr_in[1])
                        1'b1:begin
                            Data_read={{16{Data_read_from_dm[31]}},Data_read_from_dm[31:16]};
                        end         
                        1'b0:begin
                            Data_read ={{16{Data_read_from_dm[15]}},Data_read_from_dm[15:0]};
                        end
                    endcase
                end
                `dm_halfword_unsigned:begin
                    case(Addr_in[1])
                        1'b1:begin
                            Data_read={{16'b0},Data_read_from_dm[31:16]};
                        end         
                        1'b0:begin
                            Data_read={{16'b0},Data_read_from_dm[15:0]};
                        end
                    endcase
                end
                `dm_byte:begin
                    case(Addr_in[1:0])
                        2'b00:begin
                            Data_read={{24{Data_read_from_dm[7]}},Data_read_from_dm[7:0]};
                        end
                        2'b01:begin
                            Data_read={{24{Data_read_from_dm[15]}},Data_read_from_dm[15:8]};
                        end
                        2'b10:begin
                            Data_read={{24{Data_read_from_dm[23]}},Data_read_from_dm[23:16]};
                        end
                        2'b11:begin
                            Data_read={{24{Data_read_from_dm[31]}},Data_read_from_dm[31:24]};
                        end
                    endcase
                end
                `dm_byte_unsigned:begin
                    case(Addr_in[1:0])
                        2'b00:begin
                            Data_read={{24'b0},Data_read_from_dm[7:0]};
                        end
                        2'b01:begin
                            Data_read={{24'b0},Data_read_from_dm[15:8]};
                        end
                        2'b10:begin
                            Data_read={{24'b0},Data_read_from_dm[23:16]};
                        end
                        2'b11:begin
                            Data_read={{24'b0},Data_read_from_dm[31:24]};
                        end
                    endcase
                end
                default:begin
                    Data_read=32'b0;
                end
            endcase
            Data_write_to_dm=32'b0;
            wea_mem=4'b0000;
        end
    end
endmodule

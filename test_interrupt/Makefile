# 中断测试程序 Makefile
# 工具链：riscv64-unknown-elf-gcc（已安装在虚拟机）

CC = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump

CFLAGS = -march=rv32i -mabi=ilp32 -O2 -nostdlib -nostartfiles
LDFLAGS = -T linker.ld -nostdlib -nostartfiles

# 默认编译 PS2 键盘中断测试
TARGET = test_ps2

all: $(TARGET).coe

$(TARGET).elf: start.S interrupt_stub.S $(TARGET).c linker.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ start.S interrupt_stub.S $(TARGET).c

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -R .comment -O verilog --reverse-bytes=4 $< $@

$(TARGET).coe: $(TARGET).hex
	python3 hex2coe.py $< $@

$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -d $< > $@

clean:
	rm -f *.elf *.hex *.coe *.dump

.PHONY: all clean

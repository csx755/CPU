# Makefile for RISC-V bare-metal test programs
# Usage:
#   1. On Ubuntu/WSL, source the riscv toolchain env
#   2. make             → build test.elf
#   3. make coe         → build and generate test.coe

CROSS   ?= riscv32-unknown-elf-
CC      := $(CROSS)gcc
AS      := $(CROSS)gcc
LD      := $(CROSS)ld
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump

BASENAME ?= test

ARCH_FLAGS  = -march=rv32i -mabi=ilp32
CFLAGS      = $(ARCH_FLAGS) -nostartfiles -nostdlib -ffreestanding \
              -Os -fno-pic -fno-stack-protector -Wall -Wextra
ASFLAGS     = $(ARCH_FLAGS) -nostartfiles -nostdlib
LDFLAGS     = -nostartfiles -nostdlib -T link.ld

OBJS = crt0.o main.o

.PHONY: all clean coe

all: $(BASENAME).elf

$(BASENAME).elf: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) $(LDFLAGS)
	$(OBJDUMP) -d $@ > $(BASENAME).disasm

crt0.o: crt0.S
	$(CC) $(CFLAGS) -c -o $@ $<

main.o: main.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Generate .coe file from ELF
coe: $(BASENAME).elf
	python3 elf2coe.py $(BASENAME).elf $(BASENAME).coe

# Generate .coe with explicit binary approach
bin: $(BASENAME).elf
	$(OBJCOPY) -O binary $(BASENAME).elf $(BASENAME).bin
	python3 bin2coe.py $(BASENAME).bin $(BASENAME).coe

clean:
	rm -f *.o *.elf *.disasm *.coe *.bin

CROSS   ?= riscv32-unknown-elf
CC      := $(CROSS)-gcc
OBJCOPY := $(CROSS)-objcopy
PYTHON  ?= python3

CFLAGS  := -march=rv32i -mabi=ilp32 -Os -ffreestanding -fno-builtin \
           -nostdlib -nostartfiles -mstrict-align -mno-relax -msmall-data-limit=0 \
           -Wall -Wextra
LDFLAGS := -T bootloader.ld -Wl,-Map=bootloader.map,--gc-sections

all: bootloader.elf bootloader.bin bootloader.mem

bootloader.elf: boot_crt0.S bootloader.c bootloader.ld
	$(CC) $(CFLAGS) $(LDFLAGS) boot_crt0.S bootloader.c -lgcc -o $@

bootloader.bin: bootloader.elf
	$(OBJCOPY) -O binary $< $@

bootloader.mem: bootloader.bin ../../tools/bin_to_mem.py
	$(PYTHON) ../../tools/bin_to_mem.py bootloader.bin bootloader.mem

clean:
	rm -f bootloader.elf bootloader.bin bootloader.mem bootloader.map

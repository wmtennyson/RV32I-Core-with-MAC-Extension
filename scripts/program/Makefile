CROSS   ?= riscv32-unknown-elf
CC      := $(CROSS)-gcc
OBJCOPY := $(CROSS)-objcopy

CFLAGS  := -march=rv32i -mabi=ilp32 -Os -ffreestanding -fno-builtin \
           -nostdlib -nostartfiles -mstrict-align -mno-relax -msmall-data-limit=0 \
           -Wall -Wextra
LDFLAGS := -T app.ld -Wl,-Map=app.map,--gc-sections

all: app.elf app.bin

app.elf: crt0.S main.c app.ld
	$(CC) $(CFLAGS) $(LDFLAGS) crt0.S main.c -lgcc -o $@

app.bin: app.elf
	$(OBJCOPY) -O binary $< $@

clean:
	rm -f app.elf app.bin app.map

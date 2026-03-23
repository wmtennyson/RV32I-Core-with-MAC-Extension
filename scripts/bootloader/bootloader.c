#include <stdint.h>

#define APP_BASE      0x20000000u
#define UART_DATA_REG (*(volatile uint32_t*)0x40000000u)
#define UART_STAT_REG (*(volatile uint32_t*)0x40000004u)
#define UART_RX_VALID 0x1u
#define UART_TX_READY 0x2u

typedef void (*entry_t)(void);

static void uart_putc(char c) {
    while ((UART_STAT_REG & UART_TX_READY) == 0u) {
    }
    UART_DATA_REG = (uint32_t)(uint8_t)c;
}

static char uart_getc(void) {
    while ((UART_STAT_REG & UART_RX_VALID) == 0u) {
    }
    return (char)(UART_DATA_REG & 0xFFu);
}

static void uart_puts(const char *s) {
    while (*s != '\0') {
        if (*s == '\n') {
            uart_putc('\r');
        }
        uart_putc(*s++);
    }
}

static uint32_t recv_length_ascii(void) {
    uint32_t size = 0u;
    char c;

    do {
        c = uart_getc();
    } while (c == '\r' || c == '\n' || c == ' ');

    while (c >= '0' && c <= '9') {
        size = size * 10u + (uint32_t)(c - '0');
        c = uart_getc();
    }

    return size;
}

void boot_main(void) {
    volatile uint8_t *dst = (volatile uint8_t *)APP_BASE;
    uint32_t size;
    uint32_t i;

    uart_puts("BOOT\n");
    uart_puts("Send: <decimal_size><space><raw_binary>\n");

    while (1) {
        size = recv_length_ascii();
        uart_puts("LOAD\n");

        for (i = 0u; i < size; i++) {
            dst[i] = (uint8_t)uart_getc();
        }

        uart_puts("JUMP\n");
        ((entry_t)APP_BASE)();

        // If the application returns, drop back into loader mode.
        uart_puts("RET\n");
    }
}

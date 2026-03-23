#include <stdint.h>

#define UART_DATA_REG (*(volatile uint32_t*)0x40000000u)
#define UART_STAT_REG (*(volatile uint32_t*)0x40000004u)
#define UART_RX_VALID 0x1u
#define UART_TX_READY 0x2u

#define SIG0 (*(volatile uint32_t*)0x2000FF00u)
#define SIG1 (*(volatile uint32_t*)0x2000FF04u)

static void uart_putc(char c) {
    while ((UART_STAT_REG & UART_TX_READY) == 0u) {
    }
    UART_DATA_REG = (uint32_t)(uint8_t)c;
}

static void uart_puts(const char *s) {
    while (*s != '\0') {
        if (*s == '\n') {
            uart_putc('\r');
        }
        uart_putc(*s++);
    }
}

int main(void) {
    SIG0 = 0x12345678u;
    SIG1 = 0xCAFEBABEu;

    uart_puts("APP OK\n");

    // EBREAK to raise done_o on your current core.
    __asm__ volatile (".word 0x00100073");

    while (1) {
    }
}

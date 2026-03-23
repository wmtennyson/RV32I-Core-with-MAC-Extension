    .section .text.start
    .globl _start
_start:
    la   sp, _stack_top
    call boot_main
1:  j    1b

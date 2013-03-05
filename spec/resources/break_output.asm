; break_output.asm
    .ORIG x3000
    LEA R0, HELLO
    PUTS
BREAK
    LEA R0, WORLD
    PUTS
    HALT
HELLO
    .STRINGZ "Hello, "
WORLD
    .STRINGZ "world!\n"
    .END

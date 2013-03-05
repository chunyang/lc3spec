; short_output.asm
    .ORIG x3000
    LEA R0, STRING
    PUTS
    HALT
STRING
    .STRINGZ "Hello, world!"
    .END

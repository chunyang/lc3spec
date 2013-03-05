; spaces_output.asm
    .ORIG x3000
    LEA R0, STRING
    PUTS
    HALT
STRING
    .STRINGZ " abc\n\nd \n \ne\n"
    .END

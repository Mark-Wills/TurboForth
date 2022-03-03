
       .defm rt
       b * r11
       .endm

       .defm nop
       jmp $+2
       .endm

; bank 0 source files
    copy "./bank0/0-00-Header.asm"
    copy "./bank0/0-01-Startup.asm"
    copy "./bank0/0-02-Stack.asm"
    copy "./bank0/0-03-Math.asm"
    copy "./bank0/0-04-Comparison.asm"
    copy "./bank0/0-05-FlowControl.asm"
    copy "./bank0/0-06-Logical.asm"
    copy "./bank0/0-07-Memory.asm"
    copy "./bank0/0-08-Parsing.asm"
    copy "./bank0/0-09-Console.asm"
    copy "./bank0/0-10-Compilation.asm"
    copy "./bank0/0-11-Interpreter.asm"
    copy "./bank0/0-12-Errors.asm"
    copy "./bank0/0-13-Double.asm"
    copy "./bank0/0-14-Variables.asm"
    copy "./bank0/0-15-Strings.asm"
    copy "./bank0/0-16-Graphics.asm"
    copy "./bank0/0-17-Speech.asm"
    copy "./bank0/0-18-Blocks.asm"
    copy "./bank0/0-19-File-IO.asm"
    copy "./bank0/0-20-Sound.asm"
    copy "./bank0/0-21-Editor.asm"
    copy "./bank0/0-22-VDP.asm"
    copy "./bank0/0-23-System.asm"

; bank 1 source files
    copy "./bank1/1-00-Header.asm"
    copy "./bank1/1-01-ISR.asm"
    copy "./bank1/1-02-Console.asm"
    copy "./bank1/1-03-Graphics.asm"
    copy "./bank1/1-04-Memory.asm"
    copy "./bank1/1-05-Speech.asm"
    copy "./bank1/1-06-Blocks.asm"
    copy "./bank1/1-07-Double.asm"
    copy "./bank1/1-08-Parsing.asm"
    copy "./bank1/1-09-Compilation.asm"
    copy "./bank1/1-10-Strings.asm"
    copy "./bank1/1-11-Editor.asm"
    copy "./bank1/1-12-VDP.asm"
    copy "./bank1/1-13-Stack.asm"
    copy "./bank1/1-14-File-IO.asm"
    copy "./bank1/1-15.Sound.asm"
    copy "./bank1/1-16-Initialise.asm"
    copy "./bank1/1-17-End.asm"

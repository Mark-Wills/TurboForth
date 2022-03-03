;  _____                _              __          __            _     
; |  __ \              (_)             \ \        / /           | |    
; | |__) |__ _ _ __ ___ _ _ __   __ _   \ \  /\  / /___  _ __ __| |___ 
; |  ___// _` | '__/ __| | '_ \ / _` |   \ \/  \/ // _ \| '__/ _` / __|
; | |   | (_| | |  \__ \ | | | | (_| |    \  /\  /| (_) | | | (_| \__ \
; |_|    \__,_|_|  |___/_|_| |_|\__, |     \/  \/  \___/|_|  \__,_|___/
;                                __/ |                                 
;                               |___/                                  
; Dictionary lookup and associated parsing words

;[ WORD ( delimiter address -- address length )
;
; Moves through TIB in VDP memory, discarding leading delimiters, 
; looking for a word. A word is identified when a trailing delimiter is
; detected. The identified word is copied from VDP to a buffer in CPU memory.
; Pushes the start address of the word (in CPU memory), and the length of
; the word to the stack. If no word is found (for example if we hit the 
; end of the TIB without detecting a word then 0 0 is pushed on the 
; stack.
_word   mov *stack,r0               ; buffer address
        a @in,r0                    ; add offset
        mov @2(stack),r2            ; delimeter
        sla r2,8                    ; move to high-byte
        li r6,wrdbuf+1              ; address of cpu word buffer
        mov r6,@2(stack)            ; push it to stack
        clr r8                      ; length counter
        mov @_span,r7               ; number of chars in buffer
        jeq noword                  ; if 0 then there's no word
        c @in,@_span                ; hit end of buffer?
        jhe noword                  ; if yes then exit
        
wrd1    bl @wrdgb                   ; read a character and advance along input
        inc @in                     ; advance >IN
        cb r1,r2                    ; was the character a delimiter?
        jeq wrd1                    ; if yes then get another character
        c @in,@_span                ; hit end of buffer?
        jgt wrdfin                  ; if yes then quit        
wrd2    movb r1,*r6+                ; move character to word buffer
        inc r8                      ; increment length
        c r8,@tibsiz                ; have we fully populated the word buffer?
        jeq wrdfin                  ; if yes then exit
        bl @wrdgb                   ; read a character and advance along input
        inc @in                     ; advance >in
        c @in,@_span                ; hit end of buffer?
        jgt wrdfin                  ; if yes then quit
        cb r1,r2                    ; was the character a delimeter?
        jne wrd2                    ; if not then get another character
wrdfin  mov r8,*stack               ; push length to stack
        jmp wrdxit1                 ; exit
noword  clr *stack                  ; no word found, push 0 length
        clr @2(stack)               ; zero address 
        clr r8
wrdxit1 swpb r8                     ; populate length byte (for packed string)
        movb r8,@wrdbuf
wrdxit2 b @retB0

wrdgb   mov @source,r15             ; check source
        jeq vread                   ; if 0 then read from vdp
    ; special case: if EVALUATE is active then the evaluation string will be in
    ; CPU RAM
        movb *r0+,r1                ; otherwise read from cpu and advance buffer
        .rt                         ; return to caller
vread   mov r11,r14                 ; save return address
vread1  bl @_vsbr                   ; read from vdp
vread2  inc r0                      ; advance input buffer address
        b *r14                      ; return to caller
;]

;[ code for processing \ type comments
; assembly equivalent of : \ >IN @ 64 + -64 AND >IN ! ; IMMEDIATE
_trcom  mov @blknum,r0              ; loading a block?
        jeq trcom1                  ; jump if not
        mov @in,r0
        ai r0,64
        andi r0,-64
        mov r0,@in
        jmp wrdxit2                 ; exit (jump is smaller than a branch!)
trcom1  mov @tibsiz,@in             ; set >IN to the end of the line
comxit  jmp wrdxit2                 ; exit (jump is smaller than a branch!)
;]

;[ NUMBER ( address length -- (numberMSW) numberLSW error )
; Attempts to convert the string at cpu address address into a number. 
; If fully successful, the number is placed on the stack and flag will be 0. 
; If it fails (for example contains an illegal character) then a partial number
; will be placed on the stack (the value computed up until the failure) and 
; flag will be -1. This allows neat trapping with ABORT""
; Thus, if flag<>0 the string failed to parse fully as a number.
; A minus sign is permitted for negative numbers.
; This routine uses BASE to parse numbers in the current BASE. 
; Eg. If BASE=16 then digits 0-9 and A-F are considered legal and will be 
; parsed properly.
; A facility also exists called 'quick hex' that allows a number to be entered
; in base 16, by placing a $ symbol at the beginning of the string. This avoids
; the need to change BASE to enter a number. E.g. instead of HEX FEED DECIMAL 
; you can simply do $FEED. The number will be parsed as a HEX number without the
; need to change BASE.
; The same facility also exists for binary numbers: use a % symbol. 
; E.g. %1001 = 9 decimal
; The numbers returned are (by default) singles (16 bits). NUMBER can can also
; return a double (32-bit (2 stack cells)) value by including a period in the
; number string. E.g. 100. 1.00 10.0 .100 will all return 100 decimal as a 
; double.
; The various facilities can be mixed. For example, -$.F means -15 as a double.
_numbr  mov *stack+,r1              ; pop length
        mov *stack,r0               ; get address from stack
       ; parse the number string...
parsnm  clr r6                      ; initialise MSW
        clr r8                      ; initialise LSW
        clr r13                     ; clear negative flag
        clr r12                     ; clear 'double required' flag
        seto @dpl                   ; assume single precision
    ; begin ugly hack - check the end of the number for a period character
    ; if found, set double indicator (R12) to on and reduce length of string
    ; by 1. Added for TF V1.1 double precision library support
        mov r0,r15                  ; copy string address
        a r1,0                      ; add length
        dec r0                      ; point to last character in the buffer
        movb *r0+,r2                ; get character from buffer
        srl r2,8                    ; move it to low byte    
        ci r2,'.'                   ; is it a period character?
        jne xugly                   ; if not then skip
        seto r12                    ; otherwise set the double flag to on
        dec r1                      ; and reduce the length for the string so 
                                    ; that the period will not be seen by the 
                                    ; number parser 
        seto @dpl                   ; double integer
    ; end ugly hack
xugly   mov r15,r0
        mov @base,r14               ; get base
        dec r14                     ; base-1=highest legal digital for base
num0    movb *r0+,r2                ; get character from buffer
        srl r2,8                    ; move it to low byte
num4    ci r2,'%'                   ; is it a % sign (binary)
        jne num5
        li r14,1                    ; set binary base
        jmp num3                    ; do next character
num5    ci r2,'.'                   ; is it a dot?
        jne num1                    ; skip if not
    ; double detected - set r12 as flag, and calculate value for DPL
        seto r12                    ; else double is required - set flag
        mov @2(stack),r15           ; get string length
        mov r15,r7                  ; 
        s r1,r7                     ; subtract current position from length
        s r7,r15                    ; get length to the right of the dec. point
        dec r15                     ; correcty length due to decimal point 
        mov r15,@dpl                ; store in DPL
        jmp num3                    ; do next character
num1    ci r2,'$'                   ; is it a dollar sign?
        jne num2                    ; skip if not
        li r14,15                   ; force base temporarily to 16-1 for hex
        jmp num3                    ; check next character
num2    ci r2,'-'                   ; is it a negative sign?
        jne numlz                   ; skip if not
        seto r13                    ; else set negative flag
num3    dec r1                      ; decrement counter
        jmp num0                    ; get next character

    ; digit range checks...
numlz   ci r2,'0'                   ; check if ascii code < "0"
        jl ohshit                   ; error if yes
        ci r2,'z'                   ; check if ascii code > "z"
        jh ohshit                   ; error if yes

    ; check if is numeric digit
        ci r2,'9'
        jle numisd                  ; it IS a digit

    ; check if is upper case digit
        ci r2,'A'
        jhe numt1
        jmp ohshit
numt1   ci r2,'Z'
        jle numisl                  ; 

    ; check if is lower case digit
        ci r2,'a'
        jhe numt2
        jmp ohshit
numt2   ci r2,'z'
        jhe ohshit 
        ai r2,-87                   ; convert to number 
        jmp numgo 

    ; illegal digit 
ohshit  seto r0                     ; else illegal digit was detected
        jmp nexit                   ; indicate error
        
numisl  ai r2,-55                   ; convert from upper case to number
                                    ; ("A" (65) becomes 10)
        jmp numgo                   ; start the conversion
numisd  ai r2,-48                   ; convert from ascii to decimal 
                                    ; ("0" (48) becomes 0)
; parse the string into a 32 bit number...
numgo   c r2,r14                    ; compare to base
        jh ohshit                   ; if digit outside current base's legal 
                                    ; range then exit
        a r2,r8                     ; add digit to LSW
        dec r1                      ; finished?
        jeq numend                  ; jump if yes
        mov r14,r2                  ; base-1 to r2
        inc r2                      ; correct to base
        mov r8,r7                   ; get our lsw in r7
        mpy r2,r7                   ; multiply it by current base
        mov r6,r9                   ; get our MSW
        mpy r2,r9                   ; multiply it by current base
        mov r10,r6                  ; move it back
        a r7,r6                     ; add MSW from MPY to *our* MSW
        jmp num0                    ; do next digit
numend  clr r0                      ; finished with no errors, clear error flag
        mov r13,r13                 ; and check negative flag
        jeq nexit                   ; jump if not set (positive number)
        inv r6                      ; else two's complement the 32 bit word
        neg r8
nexit   mov r8,*stack               ; push least sig word
        dect stack                  ; advance stack
        mov r12,@isdbl              ; was a double returned?
        jeq pusher                  ; if not, skip
        mov r6,*stack               ; push most sig word
        dect stack                  ; advance stack
pusher  mov r0,*stack               ; push error flag
        li r12,_next                ; restore r12
        jmp comxit                  ; exit
                                    ; (a jump is 2 bytes shorter than a branch)
;]

_space  data >2000
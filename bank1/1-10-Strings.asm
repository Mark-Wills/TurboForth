;   _____ _        _              __          __            _     
;  / ____| |      (_)             \ \        / /           | |    
; | (___ | |_ _ __ _ _ __   __ _   \ \  /\  / /___  _ __ __| |___ 
;  \___ \| __| '__| | '_ \ / _` |   \ \/  \/ // _ \| '__/ _` / __|
;  ____) | |_| |  | | | | | (_| |    \  /\  /| (_) | | | (_| \__ \
; |_____/ \__|_|  |_|_| |_|\__, |     \/  \/  \___/|_|  \__,_|___/
; string related words      __/ |                                 
;                          |___/ 

;[ RND ( limit -- n)
; pushes a pseudo random number between 0 and limit-1 (rnd MOD limit)
; For the full range (0-65535) use a limit of 0
_rnd    mov @seed,r1
        li r0,>6fe5                 ; multiplier
        mpy r0,r1                   ; mpultiply r1 by r0
        ai r2,>7ab9                 ; add 7ab9 to r2
        src r2,5                    ; rotate r2 5 bits right
        mov r2,@seed                ; update seed for next call
        clr r1                      ; msw of dividend
        div *stack,r1               ; divide R1 by # on stack
        mov r2,*stack               ; copy remainder, R2, to stack
rndx    b @retb0
;]

;[ COUNT ( addr1 -- addr2 len )
; addr2 is addr1+1 and len is the length of the counted string at addr1.
; The byte at addr1 contains the byte count len. Range of len is {0.255}
_count  mov *stack,r0               ; get addr1
        movb *r0,r7                 ; get length byte from addr1
        srl r7,8                    ; move to low byte
        inc *stack                  ; increment addr1 to make addr2
PAE     dect stack                  ; make space on stack
        mov r7,*stack               ; push length    
        jmp rndx
;]

;[ -TRAILING ( addr len -- addr len )
; modifies len such that trailing spaces are excluded from the string
_trail  mov *stack,*stack           ; check length
        jeq trlout                  ; if 0 then exit
        jlt trlout                  ; if negative then exit
        mov @2(stack),r0            ; address
        a *stack,r0                 ; move to end of string+1
        dec r0                      ; correct to point to last character
trail2  cb *r0,@_space              ; compare to a space
        jeq trail1                  ; if a space, reduce length
trlout  jmp rndx                    ; else exit
trail1  dec *stack                  ; reduce length
        jeq rndx                    ; if we get to 0 then exit
        dec r0                      ; else check next address
        jmp trail2
;]

;[ S" Compile time:( -- ) Immediate:( -- address length )
; When Compiling:
; compiles: (S")<length><string>
; e.g S" HELLO" compiles (S") 5 H E L L O
; At the end of string compilation, HERE is aligned to an even address.
; At run time, (S") (see below) pushes the address of the beginning of 
; the string and the length to the stack.
; 
; When Interpreting:
; Compiles the string to the address PAD, as above, and pushes the address and
; length to the stack.
_strin  mov @_state,r0              ; check state   
        jne _stri1                  ; jump if compiling
        
    ; not compiling, move string to PAD and adjust address
        mov *stack+,r0              ; get pad address
        mov r0,r6                   ; copy it
        mov *stack,r2               ; get length
        mov @2(stack),r1            ; get source address
        
strc1   movb *r1+,*r0+              ; copy to pad
        dec r2
        jne strc1
        mov r6,@2(stack)            ; put PAD address in place of original
                                    ; address
        jmp rndx
        
    ; compiling. compile (S") <length_byte> <string>     
_stri1  mov *stack+,r0              ; discard pad address on stack
        mov @here,r0                ; compilation address
        li r1,str                   ; CFA of (S")
        mov r1,*r0+                 ; compile (S")
        mov *stack+,r2              ; get length
        swpb r2                     ; move to high byte
        movb r2,*r0+                ; compile length byte
        
        swpb r2                     ; restore length
        mov *stack+,r1              ; address of string in cpu memory
_stri2  movb *r1+,*r0+              ; copy string to definition
        dec r2                      ; finished?
        jne _stri2
        inc r0                      ; round up HERE 
        andi r0,>fffe               ; mask off LSB
        mov r0,@here                ; store it
        jmp mpadj                   ; adjust memory pointers and exit via mpadj
;]

;[ (S") ( -- cpu_addr len )
; pushes the address and length of the string (compiled by S") onto the stack 
; On entry, PC is actually pointing at the length byte. The address of the
; string is actually the address of the length byte+1. The length is just the
; value of the length byte. PC is adjusted to resume execution at the first even 
; cell following the string.
_str    movb *pc+,r0                ; get length
        dect stack                  ; make space on stack
        mov pc,*stack               ; move address of string to stack
        dect stack                  ; make space on stack
        srl r0,8                    ; place length in low byte
        mov r0,*stack               ; place length on stack
        a r0,pc                     ; advance program counter
        ai pc,1                     ; round up PC...
        andi pc,>fffe               ; ...to an even value
        b @retB0
;]

;[ NUMBER TO STRING ( num -- addr len )
; Takes a number off the stack and converts it to a signed string equivalent,
; with respect to the current number base. Number base may be between
; 2 and 36. The routine checks location DOSIGN, and if 0, the
; number is treated as signed, else its unsigned. The routine also checks 
; location LZI, and, if zero, leading zero's will be supressed. 
; This is quite a bitch of a routine. Since any number base (between 2 and 36)
; can be employed this routine is rather complex. The routine must first
; determine the appropriate powers of the number base so we can divide the 
; target number later. Obviously this is expensive, so the routine remembers
; what the active number base was the last time it was called, and ONLY
; re-computes the exponents if the base has changed since the last time it was
; called. 
; This first part computes the column values.
; So, if the base is 10, you end up with 1,10,100,1000,10000
_nts    mov rstack,r14              ; save rstack 'cos we're using it
        mov *stack,r9               ; get number off stack
        li r7,2                     ; exponent counter (base^0 and base^1 are 
                                    ; easy to compute ;-) 
                                    ; used as a word offset into workbuffer so 
                                    ; counts in multiples of 2.
        c @base,@lbase              ; check if base has chaged since the last 
                                    ; time we were called
        jeq dodiv                   ; base hasn't changed, no need to compute 
                                    ; powers of the base.
        mov @base,@lbase            ; base has changed, store it in 'last base'
        li r0,1                     ; base^0 is always 1 - easy ;-)
        li r1,wrkbuf                ; place to store the powers of our base
    ; determine base^x until result > 65535
        mov r0,*r1+                 ; store base^0 and move forward in buffer
        mov @base,*r1               ; base^1 is always base ;-) store it
pwr     mov *r1+,r5                 ; get previous exponent
        mpy @base,r5                ; multiply it by base - lower 16 bit result
                                    ; in r6
        mov r5,r5                   ; see if the result overflowed into upper 
                                    ; 16 bits
        jne pwrout                  ; there was an overflow, exit loop
        mov r6,*r1                  ; otherwise store result
        inct r7                     ; and increment exponent counter
        jmp pwr                     ; and repeat
    ; Ok we have computed the 'column values' (powers) for our base. Now we
    ; sucessively divide the number down until nothing is left, building
    ; the string equivalent as we compute each digit. Just to make life
    ; harder for ourselves, we will optionally allow leading zero's to be
    ; supressed. If the word at LZI<>0 then leading zero's are suppressed.
pwrout  mov r7,@expcnt              ; save exponent count for next time routine
                                    ; is run
dodiv   mov @expcnt,r7              ; entry point when exponents arent computed.
                                    ; restore exponent count
        li r0,strbuf                ; address of string buffer where we build 
                                    ; the string 
        clr r1                      ; buffer length counter
        mov @dosign,r8              ; check if producing an unsigned number
        jne ninn                    ; skip if we are
        mov r9,r8                   ; else, check if number is negative and if 
                                    ; so, add "-" character
        andi r8,>8000               ; is it negative
        jeq ninn                    ; its not negative, jump
        li r8,'-'*256               ; the number is negative, add a minus sign 
                                    ; to the string buffer
        movb r8,*r0+                ; place it in the buffer
        inc r1                      ; increment length counter
        neg r9                      ; change the number to positive
ninn    clr r8                      ; div instruction uses 32 bit dividend, our
                                    ; 16 bit argument is in r9
        mov @lzi,r10                ; leading zero indicator 0=suppress
nxtdig  div @wrkbuf(r7),r8          ; divide our number by exponent value.
                                    ; result=r8, remainder=r9
        mov r8,r8                   ; was the result 0?
        jeq testlz                  ; if yes then check if ignoring leading 
                                    ; zeros
        seto r10                    ; not zero, so reset leading zero indicator
dodig   movb @tlut(r8),*r0+         ; lookup digit value, move it to string 
                                    ; buffer and advance buffer address
        clr r8                      ; clear result for next interation
        inc r1                      ; increment length counter
iglz    dect r7                     ; done all our columns/exponents?
        jne nxtdig                  ; loop if not
        movb @tlut(r9),*r0+         ; lookup digit value, move it to string 
                                    ; buffer and advance buffer address
    ; we've done our division, push address & length to the stack and exit
        li r0,strbuf                ; address of string buffer
        mov r0,*stack               ; move address to stack
        dect stack                  ; new stack entry
        inc r1                      ; adjust length for remainder
        mov r1,*stack               ; move length to stack
        mov r14,rstack              ; restore return stack pointer
        b @retB0
    ; we're looking for leading zero's and ignoring them
testlz  mov r10,r10                 ; are we ignoring leading zero's?
        jeq iglz                    ; 0=ignore leading digit
        jmp dodig                   ; else do digit normally
    ; character lookup table for printing numbers between bases 2 to 36
tlut    text '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
;]

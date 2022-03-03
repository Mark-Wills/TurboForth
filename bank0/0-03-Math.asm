;  __  __       _   _      __          __            _     
; |  \/  |     | | | |     \ \        / /           | |    
; | \  / | __ _| |_| |__    \ \  /\  / /___  _ __ __| |___ 
; | |\/| |/ _` | __| '_ \    \ \/  \/ // _ \| '__/ _` / __|
; | |  | | (_| | |_| | | |    \  /\  /| (_) | | | (_| \__ \
; |_|  |_|\__,_|\__|_| |_|     \/  \/  \___/|_|  \__,_|___/


;[ 1+           w1 -- w2                      79         "one-plus" 
; w2 is the result of adding one to w1 according to the operations of + 
plus1h  data rspoph,2
        text '1+'
plus1   data _plus1                 ; code is in high-speed ram.
                                    ; see 1-15-Initialise.a99
;]

;[ 1-           w1 -- w2                      79        "one-minus" 
; w2 is the result of subtracting one from w1 according to the operation of -
sub1h   data plus1h,2
        text '1-'
sub1    data $+2
        dec *stack
        b *next
;]

;[ 2+           w1 -- w2                      79         "two-plus" 
; w2 is the result of adding two to w1 according to the operation of +
plus2h  data sub1h,2
        text '2+'
plus2   data _plus2                 ; code is in high-speed ram.
                                    ; see 1-15-Initialise.a99
;]

;[ CELL+        w1 -- w2+2
; adds two (the cell size) to top of stack
cellph  data plus2h,5
        text 'CELL+ '
cellp   data _plus2
;]

;[ CHAR+        w1 -- w2+2
; adds two (the cell size) to top of stack
charph  data cellph,5
        text 'CHAR+ '
charp   data _plus1
;]

;[ 2-           w1 -- w2                      79        "two-minus" 
; w2 is the result of subtracting two from w1 according to the operation of -
sub2h   data charph,2
        text '2-'
sub2    data _sub2                  ; code is in high-speed ram.
                                    ; see 1-15-Initialise.a99
;]

;[ 2* ( x -- x<<1 )
; shifts the value on the stack left by one bit.
mul2h   data sub2h,2
        text '2*'
mul2    data $+2
mul3    a *stack,*stack             ; :-)
        b *next
;]

;[ CELLS ( x1 -- x1*2 )
; returns the memory size required to hold x1 cells 
cellsh  data mul2h,5
        text 'CELLS '
cells   data mul3                   ; use the word 2* to do our work for us
;]

;[ 2/           n1 -- n2                      83       "two-divide" 
; n2 is the result of arithmetically shifting n1 right one bit.  
; The sign is included in the shift and remains unchanged.
div2h   data cellsh,2
        text '2/'
div2    data $+2
        mov *stack,r8               ; TOS in r8
        sra r8,1                    ; shift right
        mov r8,*stack               ; store on stack
        b *next
;]

;[ +            w1 w2 -- w3                   79             "plus" 
; w3 is the arithmetic sum of w1 plus w2.
addh    data div2h,1
        text '+ '
add     data _add                   ; code is in high-speed ram.
                                    ; see 1-15-Initialise.a99
;]

;[ -            w1 w2 -- w3                   79            "minus" 
; w3 is the result of subtracting w2 from w1.
subh    data addh,1
        text '- '
sub     data _sub                   ; code is in high-speed ram.
                                    ; see 1-15-Initialise.a99
;]

;[ *            w1 w2 -- w3                   79            "times" 
; w3 is the least-significant 16 bits of the arithmetic product of w1 times w2.
mulh    data subh,1
        text '* '
mul     data _mul                   ; code is in high-speed ram.
                                    ; see 1-15-Initialise.a99
;]

;[ */           n1 n2 n3 -- n4                83     "times-divide" 
; n1 is first multiplied by n2 producing an intermediate 32-bit result.
; n4 is the floor of the quotient of the intermediate 32-bit result divided by
; the divisor n3.
; The product of n1 times n2 is maintained as an intermediate 32-bit result for
; greater precision than the otherwise equivalent sequence: n1 n2 * n3 / .
; An error condition results if the divisor is zero or if the quotient falls
; outside of the range {-32,768..32,767}. 
sslash  data mulh,2
        text '*/'
        data docol
        data ssm                    ; */MOD
        data nip                    ; discard remainder
        data exit
        b *next
;]

;[ UM*          u1 u2 -- ud                   83        "u-m-times"
; ud is the unsigned-double product of u1 times u2.  
; All values and arithmetic are unsigned.
; high word of ud to top of stack
umsh    data sslash,3
        text 'UM* '
        data $+2
        mov *stack,r0               ; get u2
        mov @2(stack),r1            ; get r1
        mpy r0,r1                   ; perform unsigned multiply
        mov r1,*stack               ; push high word
        mov r2,@2(stack)            ; push low word
        b *next
;]

;[ /MOD         n1 n2 -- n3 n4                83       "divide-mod" 
; n3 is the remainder and n4 the floor of the quotient of n1 divided by the 
; divisor n2.
; n3 has the same sign as n2 or is zero.
; An error condition results if the divisor is zero or if the quotient falls 
; outside of the range {-32,768..32,767}.
smodh   data umsh,4
        text '/MOD'
smod    data $+2
        mov *stack,r0               ; get n2 (divisor)
        seto r1                     ; dividend is 32-bit, assume negative 
        mov @2(stack),r2            ; get n1 (dividend)
        jlt smod1                   ; if negative then skip
        clr r1                      ; otherwise it's positive. clear upper word
smod1   bl @sidiv                   ; do a signed division
        mov r1,*stack               ; push quotient
        mov r2,@2(stack)            ; push remainder
        b *next
;]

;[ */MOD        n1 n2 n3 -- n4 n5             83 "times-divide-mod" 
; n1 is first multiplied by n2 producing an intermediate 32-bit result.
; n4 is the remainder and n5 is the floor of the quotient of the intermediate
; 32-bit result divided by the divisor n3.  A 32-bit intermediate product is
; used as for */ .  n4 has the same sign as n3 or is zero.  An error condition
; results if the divisor is zero or if the quotient falls outside of the range
; {-32,768..32,767}.  
ssmh    data smodh,5
        text '*/MOD '
ssm     data $+2
        mov @2(stack),r0            ; get n2
        mov @4(stack),r1            ; get n1
        bl @simul                   ; signed multiply 
        mov *stack+,r0              ; pop n3 to r0 (divisor)
        bl @sidiv                   ; signed divide
        mov r1,*stack               ; push quotient
        mov r2,@2(stack)            ; push remainder
        b *next
;]

;[ UM/MOD       ud u1 -- u2 u3                83   "u-m-divide-mod" 
; u2 is the remainder and u3 is the floor of the quotient after dividing ud by
; the divisor u1.  All values and arithmetic are unsigned.  An error condition
; results if the divisor is zero or if the quotient lies outside the range
umodh   data ssmh,6
        text 'UM/MOD'
usmod   data $+2
        mov *stack+,r0              ; pop u1 to r0 (divisor)
        mov *stack,r1               ; high word of ud to r1
        mov @2(stack),r2            ; low word of ud to r2
        div r0,r1                   ; perform unsigned division
        mov r1,*stack               ; push quotient
        mov r2,@2(stack)            ; push remainder
        b *next
;]

;[ /            n1 n2 -- n3                   83           "divide" 
; n3 is the floor of the quotient of n1 divided by the divisor n2. 
; An error condition results if the divisor is zero or if the quotient falls 
; outside of the range {-32,768..32,767}.
sdivh   data umodh,1
        text '/ '
sdiv    data docol,smod,nip,exit
;]

;[ MOD          n1 n2 -- n3                   83                   
; n3 is the remainder after dividing n1 by the divisor n2.
; n3 has the same sign as n2 or is zero.
; An error condition results if the divisor is zero or if the quotient falls
; outside of the range {-32,768..32,767}.  
modh    data sdivh,3
        text 'MOD '
mod     data docol,smod,drop,exit
;]

;[ NEGATE       n1 -- n2                      79                   
; n2 is the two's complement of n1, i.e, the difference of zero less n1.
negh    data modh,6
        text 'NEGATE'
neg_    data $+2
neg2    neg *stack                  ; negate the word on TOS
        b *next
;]

;[ ABS          n -- u                        79         "absolute" 
; u is the absolute value of n.  If n is -32,768 then u is the same value.
; STATUS: TESTED OK 13 APR 2009
absh    data negh,3
        text 'ABS '
abs_    data $+2
        abs *stack                  ; compute abs of the word on TOS
        b *next
;]

;[ MIN          n1 n2 -- n3                   79              "min" 
; n3 is the lesser of n1 and n2 according to the operation of < .
minh    data absh,3
        text 'MIN '
min     data $+2
        c *stack+,*stack            ; compare n2 and n1 (and pop n2)
        jlt keepn2                  ; keep n2 if it's lower
        b *next                     ; otherwise keep n1
keepn2  mov @-2(stack),*stack       ; keep n2
        b *next
;]

;[ MAX          n1 n2 -- n3                   79              "max" 
; n3 is the greater of n1 and n2 according to the operation of > .
maxh    data minh,3
        text 'MAX '
max     data $+2
        c *stack+,*stack            ; compare n2 and n1 (and pop n2)
        jgt keepn2                  ; keep n2 if it's higher
        b *next                     ; otherwise keep n1
;]


; Floored math subroutines:

;[ Signed divide using Floored Integer Division
; Divides a 32 bit value in r1 and r2 by a 16 bit value in r0
; Inputs:
;   r0=divisor
;   r1=upper 16 bits dividend
;   r2=lower 16 bits dividend
; Outputs:
;   r1=16-bit quotient
;   r2=16-bit remainder
sidiv   ; set flags to reflect signs of operands, and force operands positive...
        clr r14                     ; sign of divisor (-1=negative sign)
        clr r15                     ; sign of dividend (-1=negative sign)
        abs r0                      ; force divisor positive
        jgt sdiv1                   ; if positive then jump
        seto r14                    ; flag negative divisor
sdiv1   mov r1,r1                   ; check sign of dividend
        jeq sdiv2
        jgt sdiv2                   ; if positive then jump
        inv r1                      ; otherwise negate the dividend
        neg r2                      ;
        seto r15                    ; and flag dividend as negative
    ; perform division...
sdiv2   mov r2,r8                   ; store a copy of the dividend
        div r0,r1                   ; perform the division. r1=quot, r2=rem
    ; check if floor should be applied... (signs different and remainder<>0)
sdiv3   c r14,r15                   ; compare signs of dividend and divisor
        jeq signdo                  ; if same then jump
        neg r1                      ; negate quotient
        mov r2,r2                   ; check remainder
        jeq signdo                  ; jump if no remainder
    ; apply floor rule...
floor   dec r1                      ; floor the quotient
        ; compute remainder remainder=(divisor*quotient)-dividend
        mov r1,r9                   ; get floored quotient
        abs r9                      ; force positive
        mpy r0,r9                   ; divisor*quotient (result in r10)
        s r8,r10                    ; subtract dividend
        mov r10,r2                  ; overwrite original remainder
    ; apply sign of divisor to remainder
signdo  mov r14,r14                 ; check sign of divisor
        jlt floor1                  ; if negative then jump
        .rt                          ; otherwise we're done
floor1  neg r2                      ; remainder takes sign of divisor
        .rt                         ; done
;]

;[ Signed Multiply
; multiplies two signed 16-bit values, n1 & n2, giving a signed 32-bit product
; Inputs:
;   r0=n1
;   r1=n2
; Outputs:
;   r1=product, upper 16-bits
;   r2=product, lower 16-bits
    ; check if signs of inputs are different
simul   mov r0,r6                   ; copy n1
        xor r1,r6                   ; check signs (r6=negative if signs differ)
        abs r0                      ; force positive
        abs r1                      ; force positive
        mpy r0,r1                   ; n1*n2 (product in r1 & r2)
    ; if input signs were different then negate results
        mov r6,r6                   ; check signs flag
        jgt simul1                  ; if same then leave positive
        inv r1                      ; invert high word
        neg r2                      ; negate low word
        jnc simul1                  ; skip if no carry
        inc r1                      ; add 1 to high word to compensate for carry
simul1  .rt
;]

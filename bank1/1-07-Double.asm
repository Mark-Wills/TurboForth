
; Double Number Words - removed and included in the 32-bit library

; 2DROP ( d -- )
;_drop2 dect stack               ; move back up the stack 4 bytes
;       dect stack
;drop2x b @retB0


; 2DUP ( d -- d d )
_dup2   mov *stack,@-4(stack)       ; copy tos
        dect stack
        mov @4(stack),*stack
        dect stack
        b @retB0

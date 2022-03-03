;  _                  _            _  __          __            _     
; | |                (_)          | | \ \        / /           | |    
; | |      ___   __ _ _  ___  __ _| |  \ \  /\  / /___  _ __ __| |___ 
; | |     / _ \ / _` | |/ __|/ _` | |   \ \/  \/ // _ \| '__/ _` / __|
; | |____| (_) | (_| | | (__| (_| | |    \  /\  /| (_) | | | (_| \__ \
; |______|\___/ \__, |_|\___|\__,_|_|     \/  \/  \___/|_|  \__,_|___/
;                __/ |                                                
;               |___/                                                 
;
;[ AND          16b1 16b2 -- 16b3             79                   
; 16b3 is the bit-by-bit logical 'and' of 16b1 with 16b2.
andh    data getjh,3
        text 'AND '
and     data $+2
        inv *stack                  ; invert 16b2 for SZC instruction
                                    ; (see ED/AS manual, page 190)
        szc *stack+,*stack          ; perform AND function and pop 16b2
        b *next
;]

;[ OR           16b1 16b2 -- 16b3             79                   
; 16b3 is the bit-by-bit inclusive-or of 16b1 with 16b2.
orh     data andh,2
        text 'OR'
or_     data $+2
        soc *stack+,*stack          ; or 16b2 and 16b1. pop 16b2
        b *next
;]

;[ XOR          16b1 16b2 -- 16b3             79             "x-or" 
; 16b3 is the bit-by-bit exclusive-or of 16b1 with 16b2.
xorh    data orh,3
        text 'XOR '
xor_    data $+2
        mov *stack+,r8              ; pop 16b2 in r8
        xor *stack,r8               ; xor 16b1 with 16b2. result in r8
        mov r8,*stack               ; result to TOS
        ; (what a total shitter that I can't do a simple XOR *STACK+,*STACK )
        b *next
;]

;[ NOT          16b1 -- 16b2                  83                   
; 16b2 is the one's complement of 16b1.
invh    data xorh,3
        text 'NOT '
inv_    data $+2
        inv *stack                  ; invert the word on TOS
        b *next
;]

;[ << (bitwise) ( x count -- x )
; left shift x count bits (arithmetic shift)
lsfth   data invh,2
        text '<<'
lsft    data $+2
        mov *stack+,r0              ; pop shift count into r0
        mov *stack,r8               ; x
        sla r8,r0                   ; shift x by r0 bits
        mov r8,*stack               ; result back onto stack
        b *next
;]

;[ >> ( x count -- x )
; right shift x count bits (logical shift)
rsfth   data lsfth,2
        text '>>'
rsft    data $+2
        mov *stack+,r0              ; pop shift count into r0
        mov *stack,r8               ; x
        srl r8,r0                   ; shift x by r0 bits
        mov r8,*stack               ; result back onto stack
        b *next
;]

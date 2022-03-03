;   _____ _              _     __          __            _     
;  / ____| |            | |    \ \        / /           | |    
; | (___ | |_  __ _  ___| | __  \ \  /\  / /___  _ __ __| |___ 
;  \___ \| __|/ _` |/ __| |/ /   \ \/  \/ // _ \| '__/ _` / __|
;  ____) | |_| (_| | (__|   <     \  /\  /| (_) | | | (_| \__ \
; |_____/ \__|\__,_|\___|_|\_\     \/  \/  \___/|_|  \__,_|___/
; Core words pertaining to data and return stack manipulation

; PICK ( x1 x2 x3 x4 n -- x1 x2 x3 x4 x5 )
; picks the nth value from the data stack and places a copy of it on the top 
; of the data stack.
; note: parameters start from 0. 0 PICK is equivalent to DUP.
; 1 PICK is equivalent to OVER
_pick   mov *stack,r6               ; get required stack parameter number
        inc r6                      ; adjust for parameter n on stack
        sla r6,1                    ; convert to byte offset
        a stack,r6                  ; add stack address to offset
        mov *r6,*stack              ; read that address and place on stack
pickx   b @retB0                    ; NEXT


; ROLL ( +n -- n )
; The +nth stack value, not counting +n itself is first removed and then 
; transferred to the top of the stack, moving the remaining values into the
; vacated position.  {0..the number of elements on the stack-1}
; 2 ROLL is equivalent to ROT. 0 ROLL is a null operation
_roll   mov *stack+,r8              ; pop roll value in r8
        mov r8,r8                   ; test for zero value
        jeq pickx                   ; if zero, take no action
        mov stack,r10               ; copy stack pointer
        mov r8,r9                   ; copy roll value
        sla r8,1                    ; multiply by two, to get the offset into 
                                    ; the stack
        a r8,r10                    ; compute stack address to start from
        mov *r10,r0                 ; store stack value, this will go to TOS
        mov r10,r1                  ; move everything above this stack entry 
                                    ; back one
        dect r10                    ; source
rolllp  mov *r10,*r1                ; move source back one word
        dect r10
        dect r1
        dec r9                      ; decrement counter. finished?
        jne rolllp                  ; loop if not
        mov r0,*stack               ; place earlier saved value to TOS
exroll  jmp pickx                   ; NEXT


; DEPTH ( -- depth )
; depth is the number of 16-bit values contained in the data stack before depth
; was placed on the stack.
_depth  mov stack,r7                ; copy address of TOS
        inct r7
        mov @s0,r6                  ; base of stack
        s r7,r6                     ; subtract tos from base of stack
        sra r6,1                    ; convert to cells
        dect stack                  ; new stack entry
        mov r6,*stack               ; push depth
        jmp pickx                   ; NEXT


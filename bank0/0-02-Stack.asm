;   _____ _              _     __          __            _     
;  / ____| |            | |    \ \        / /           | |    
; | (___ | |_  __ _  ___| | __  \ \  /\  / /___  _ __ __| |___ 
;  \___ \| __|/ _` |/ __| |/ /   \ \/  \/ // _ \| '__/ _` / __|
;  ____) | |_| (_| | (__|   <     \  /\  /| (_) | | | (_| \__ \
; |_____/ \__|\__,_|\___|_|\_\     \/  \/  \___/|_|  \__,_|___/
; Core words pertaining to data and return stack manipulation


; DROP         16b --                        79                   
; 16b is removed from the stack.
droph   data coldh,4                ; link to previous word and length of word
        text 'DROP'                 ; name of word
drop    data _drop                  ; code is in high-speed ram.
                                    ; see 1-15-Initialise.a99


; SWAP         16b1 16b2 -- 16b2 16b1        79                   
; The top two stack entries are exchanged.
swaph   data droph,4
        text 'SWAP'
swap    data _swap                  ; code is in high-speed ram.
                                    ; see 1-15-Initialise.a99


; DUP          16b -- 16b 16b                79             "dupe" 
; Duplicate 16b.
duph    data swaph,3
        text 'DUP '
dup     data _dup                   ; code is in high-speed ram.
                                    ; see 1-15-Initialise.a99


; ROT          16b1 16b2 16b3 -- 16b2 16b3 16b1  79         "rote" 
; The top three stack entries are rotated, bringing the deepest to the top.
roth    data duph,3
        text 'ROT '
rot     data $+2
        mov @4(stack),r6            ; save x1
        mov @2(stack),@4(stack)     ; move x2 backwards on stack
        mov *stack,@2(stack)        ; move x3 bacwards on stack
        mov r6,*stack               ; put x1 on top of stack
        b *next


; -ROT         16b1 16b2 16b3 -- 16b3 16b1 16b2
; The top three stack entries are rotated, sending the top item to the deepest
; poisition
nroth   data roth,4
        text '-ROT'
nrot    data $+2
        mov *stack,r6               ; save x3
        mov @2(stack),*stack        ; move x2 forwards on stack
        mov @4(stack),@2(stack)     ; move x1 forwards on stack
        mov r6,@4(stack)            ; put x3 on bottom
        b *next


; OVER         16b1 16b2 -- 16b1 16b2 16b3   79                   
; 16b3 is a copy of 16b1.
overh   data nroth,4
        text 'OVER'
over    data _over                  ; code is in high-speed ram.
                                    ; see 1-15-Initialise.a99


; NIP          16b1 16b2 -- 16b2
; 16b1 is removed from the stack
niph    data overh,3
        text 'NIP '
nip     data $+2
        mov *stack+,*stack          ; copy 16b2 and perform pop
        b *next


; TUCK         16b1 16b2 -- 16b2 16b1 16b2
; places a copy of 16b2 at the third data stack position.
; 16b1 and 16b2 move upwards.
tuckh   data niph,4
        text 'TUCK'
tuck    data $+2
        dect stack
        mov @2(stack),*stack
        mov @4(stack),@2(stack)
        mov *stack,@4(stack)
        b *next


; ?DUP         16b -- 16b 16b                79    "question-dupe" 
; or: 0 -- 0. Duplicate 16b if it is non-zero.
dup0h   data tuckh,4
        text '?DUP'
qdup    data $+2
        mov *stack,*stack           ; set EQ bit in status register if TOS=0
        jeq qdupx                   ; jump if TOS=0 and exit
        dect stack                  ; create stack entry
        mov @2(stack),*stack        ; copy tos
qdupx   b *next


; PICK         +n -- 16b                     83                   
; 16b is a copy of the +nth stack value, not counting +n itself.  
; {0..the number of elements on stack-1}            
;    0 PICK is equivalent to DUP   
;    1 PICK is equivalent to OVER
pickh   data dup0h,4
        text 'PICK'
pick    data $+2
        bl @bank1
        data _pick


; >< ( xy -- yx )
; Swaps bytes in the top data stack cell. For example $1234 becomes $3412
swpbh   data pickh,2
        text '><'
swpb_   data $+2
        swpb *stack                 ; swap bytes in TOS
        b *next


; ROLL         +n --                         83                   
; The +nth stack value, not counting +n itself is first removed and then 
; transferred to the top of the stack, moving the remaining values into the 
; vacated position.  
; {0..the number of elements on the stack-1}    
;    2 ROLL is equivalent to ROT   
;    0 ROLL is a null operation
rollh   data swpbh,4
        text 'ROLL'
roll    data $+2
        bl @bank1
        data _roll


; DEPTH        -- +n                         79                   
; +n is the number of 16-bit values contained in the data stack before +n was 
; placed on the stack.
depthh  data rollh,5
        text 'DEPTH '
depth   data $+2
        bl @bank1
        data _depth


; .S ( -- )
; produce non-destructive stack dump to the screen.
ndsh    data depthh,2
        text '.S'
dots    data docol,depth,zbrnch,dotst
        data lit1,depth,sub1
        data do,dotst
dots1   data   geti,sub1,pick,nts,type,space1
        data   litm1
        data ploop,dots1
dotst   data toterm,dottxt
        data exit
dottxt  byte 5  ; length of text 
        text '<TOP '

        
; RETURN STACK WORDS:

; >R           16b --                        C,79           "to-r" 
; Transfers 16b to the return stack.
rspshh  data ndsh,2
        text '>R'
rspush  data $+2
        dect rstack                 ; move return stack to the next position
        mov *stack+,*rstack         ; pop word on data stack to return stack
        b *next


; R@           -- 16b                        C,79        "r-fetch" 
; 16b is a copy of the top of the return stack.
rsch    data rspshh,2
        text 'R@'
rsc     data $+2
        dect stack                  ; move forward on data stack
        mov *rstack,*stack          ; copy word from return stack to data stack
        b *next


; R>           -- 16b                        C,79         "r-from" 
; 16b is removed from the return stack and transferred to the data stack.
rspoph  data rsch,2
        text 'R>'
rspop   data $+2
        dect stack                  ; move forward on data stack
        mov *rstack+,*stack         ; pop top of return stack to data stack
        b *next


;   _____ _              _               
;  / ____| |            | |              
; | (___ | |_  __ _ _ __| |_ _   _ _ __  
;  \___ \| __|/ _` | '__| __| | | | '_ \ 
;  ____) | |_| (_| | |  | |_| |_| | |_) |
; |_____/ \__|\__,_|_|   \__|\__,_| .__/ 
;                                 | |    
;                                 |_|    
; STARTUP - general initialisation code for bank 0
; and a few high level Forth kernal words for starting
; the interpreter, cold starting, etc

; START
startB0 limi 0                      ; no interrupts thank-you, we're British
        
        clr @>6000                  ; we're now in bank 1 
        ; note, bank 1 has identical code at these addresses so we
        ; can safely bank switch
        b @init                     ; init is defined in 1-15-Initialise.a99
        
afteri  li next ,_next              ; we'll use r12 as a pointer to NEXT
        li pc,cstart                ; setup Forth instruction pointer (R3)
        b *r12                      ; call NEXT (start execution)
        ; from this point we're actually running in forth


    ;    pc = instruction pointer (R3)
    ;    stack = data stack pointer (R4)
    ;    rstack = return stack pointer (R5)
    
; space saving routines... these replace common phrases found in the source
; The following four routines save 2 bytes each time they are used    
lit0    data $+2                ; push 0 to stack
        dect stack
        clr *stack
        b *next
        
lit1    data docol,lit,1,exit   ; push 1 to stack
lit8    data docol,lit,8,exit   ; push 8 to stack

litm1   data $+2                ; push -1 to stack
        dect stack
        seto *stack
        b *next
        
; another common phrase is COMPILE BRANCH
combra  data docol,compile,branch,exit

; COMPILE LIT COMMA
clc     data docol,compile,lit,comma,exit

; Alternative to TYPE. A typical phrase is LIT <ADDR> LIT <LEN> TYPE
; This routine allows the above phrase to be replaced with TOTERM <ADDR> <LEN>
; Saving 4 bytes each time it is used. Net saving ~80 bytes.
toterm  data docol,term1,type,exit
term1   data $+2
        mov *rstack,r1              ; get address of address of length byte 
        mov *r1,r1                  ; point to address byte
        movb *r1+,r2                ; get length 
        srl r2,8                    ; move to low byte 
        dect stack                  ; create stack entry
        mov r1,*stack               ; push address of text 
        dect stack                  ; create stack entry
        mov r2,*stack               ; push length
        inct *rstack 
        b *next
        
    
; COLD START
; This routine is called when the system starts for the first time.
cstart  data bootup
bootup  data docol,synth            ; check if speech synth is fitted
        ; the graphics mode is loaded by the cart startup menus
        data lit,sumode,fetch,gmode ; set appropriate graphics mode
        data lit,mtext,lit,37,type,cr    ; type title to screen
        data keyq,cboot             ; scan keyboard and call cboot
        data zbrnch,skipld          ; skip bootloader if enter key was pressed
        data lit1,load              ; boot from disk - load block 1
        data lit,doboot,store0      ; reset booting flag
skipld  data ab0rt                  ; call QUIT.
synth   data $+2                    ; check if speech synth is fitted
        bl @bank1
        data isspch                 ; see 1-05-speech.a99
        
; permit booting from DSKx where x is any ASCII character
; To boot from something other than DSK1 just hold down the appropriate key at
; boot-time.
cboot   data $+2
        bl @bank1
        data _cboot                 ; defined in 1-15-Initialise.a99


; EXIT         --                            C,79                 
; Compiled within a colon definition such that when executed, that colon 
; definition returns control to the definition that passed control to it by 
; returning control to the return point on the top of the return stack.  
; An error condition exists if the top of the return stack does not contain a 
; valid return point.
; See: ;  "stack, return"  "9.3 Return Stack"
;
; Note: This word is the last word in the dictionary. Consequently it's link
; field has a value of 0. FIND uses this to determine if it has searched every
; word in the dictionary.
exith   data 0,4
        text 'EXIT'
exitt   data $+2
        b @exit+2


; QUIT         --                            79                   
; Clears the return stack, sets interpret state, accepts new input from the
; current input device, and begins text interpretation.  No message is
; displayed.
quith   data exith,4
        text 'QUIT'
quit    data docol
quitlp  data lit,>0500,lit,keydev,store ; set keyscan code
        data rrstack                    ; reset return stack
        data tib_,fetch,lit,80,expect   ; get some input
        data interp                     ; call INTERPRET
        data stkuf                      ; check for stack underflow
        data toterm,oktxt               ; type OK
        data depth,dot,cr               ; display stack depth
        data branch,quitlp              ; repeat endlessly
oktxt   byte 3  ; length of text 
        text 'ok:'
        even
rrstack data $+2
        li rstack,retstk                ; reset return stack pointer
        b *next


; COLD ( -- ) 
; performs a cold reset of the system
coldh   data quith,4
        text 'COLD'
        data $+2
cold    jmp startB0                      ; restart the whole shebang


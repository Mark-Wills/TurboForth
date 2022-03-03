;   _____                       _ _ _              __          __            _     
;  / ____|                     (_) (_)             \ \        / /           | |    
; | |      ___  _ __ ___  _ __  _| |_ _ __   __ _   \ \  /\  / /___  _ __ __| |___ 
; | |     / _ \| '_ ` _ \| '_ \| | | | '_ \ / _` |   \ \/  \/ // _ \| '__/ _` / __|
; | |____| (_) | | | | | | |_) | | | | | | | (_| |    \  /\  /| (_) | | | (_| \__ \
;  \_____|\___/|_| |_| |_| .__/|_|_|_|_| |_|\__, |     \/  \/  \___/|_|  \__,_|___/
;                        | |                 __/ |                                 
;                        |_|                |___/                                  
; Compilation words...

;[ HEADER ( address length -- )
; creates a dictionary entry starting at HERE, and links it to the previous 
; dictionary entry.
_headr  mov *stack+,r1              ; length in r1
        andi r1,15                  ; restrict length to 15
hdr0    mov r1,r6                   ; copy length of word to use as a counter
    ;    mov @blknum,r0              ; get 'are we loading?' flag
        mov @lstblk,r0              ; get 'are we loading?' flag
        jeq hdr1                    ; if not then skip
        dec r0                      ; decrement by 1 to give room for 0 to 1023
        sla r0,4                    ; shift into position
        soc r0,r1                   ; OR into length word
hdr1    mov *stack+,r0              ; pop address of word to r0
        mov @here,r2                ; here to r2
        mov @latest,*r2             ; create link to previous dictionary entry
        mov r2,@latest              ; update latest to point to this entry
        inct r2                     ; move forward in memory
        mov r1,*r2+                 ; append length of word to dictionary entry
crtlp   movb *r0+,*r2+              ; get a character
        dec r6                      ; finished copying name?
        jne crtlp                   ; repeat if not
        inc r2                      ; we're gonna force r2 to an even address...
        andi r2,>fffe               ; force to even address
        mov r2,@here                ; update here
        mov r2,@patch               ; update most recent CFA locaation
        mov r2,r0                   ; copy to r0 for memory pointer adjust rtn.
        jmp mpadj                   ; update memory free pointers and exit
;]

;[ , (COMMA) ( value -- )
; appends 16 bit word on TOS to the user memory addressed by HERE and updates
; HERE to point to next word
_comma  mov @here,r0                ; get next free address in r0
        mov *stack+,*r0+            ; pop value to HERE
        mov r0,@here                ; update HERE
mpadj   ci r0,>a000                 ; are we in high memory?
        jl  lomadj                  ; no, take the jump
        mov r0,@ffaihm              ; we must be writing in low ram. update low
                                    ; mem pointer
        jmp commax
lomadj  mov r0,@ffailm              ; update high memory pointer
commax  b @retB0
;]

;[ C, (COMMA) ( value -- )
; appends an 8 bit value, from the least significant byte of TOS to HERE.
; Here is incremented by ONE BYTE, not one WORD.
; For safety, use ALIGN to align HERE to a word boundary afterwards.
_comab  mov @here,r0                ; get next free address in r0
        mov *stack+,r1              ; get stack value in r1
        swpb r1                     ; get TOS in most significant byte
        movb r1,*r0+                ; mov data in TOS to HERE and increment by 
                                    ; one byte
        mov r0,@here                ; update HERE
        jmp mpadj                   ; update memory pointers
;]

;[ ALIGN ( -- )
; Aligns HERE to an even word boundary by rounding up if required
; Call it after using C!
_align  mov @here,r0                ; get HERE
        inc r0                      ; add 1
        andi r0,>fffe               ; round up if required
        mov r0,@here                ; store it
        jmp mpadj                   ; update memory pointers
;]

;[ HIDDEN ( dictionary_address -- )
; toggles the hidden attribute on the dictionary entry
; normally you would hide a word after defining it with: LATEST @ HIDDEN
_hide   mov *stack+,r0              ; pop address of dictionary entry to r0
        inct r0                     ; point to length entry
        mov *r0,r1                  ; get the length entry
        xor @_bit1,r1               ; toggle hidden bit (weight >4000)
        mov r1,*r0                  ; store it
        jmp commax
;]

;[ IMMEDIATE ( -- )
; toggles the immediate bit in the dictionary entry pointed to by LATEST.
_imm    mov @latest,r0              ; get address of latest dictionary entry
        inct r0                     ; point to length entry
        mov *r0,r1                  ; get the length entry
        xor @_bit0,r1               ; toggle immediate bit (weight >8000)
        mov r1,*r0                  ; store it
        jmp commax
;]

;[ ALLOT ( n -- )
; reserves n BYTES of memory, staring from HERE
_allot  a *stack+,@here             ; pop and add n to HERE
        mov @here,r0                ; get HERE in r0 for mpadj routine
        jmp mpadj                   ; adjust memory pointers
;]

;[ COMPILE ( -- )
; Used in colon definitiona. Compiles the next word into the current definition
; the word is not executed. E.g. COMPILE DROP compiles DROP to HERE. DROP is not
; actually executed
; important note: see COMPILE in 0-10-Compilation.a99
_compil mov @here,r0                ; get HERE
        mov r1,*r0+                 ; compile next word to HERE & increase HERE
        mov r0,@here                ; save HERE
        jmp mpadj                   ; adjust memory pointers
;]

;  __  __                                                                  
; |  \/  |                                     /\                          
; | \  / | ___ _ __ ___   ___  _ __ _   _     /  \   ___  ___  ___ ___ ___ 
; | |\/| |/ _ \ '_ ` _ \ / _ \| '__| | | |   / /\ \ / __|/ __|/ _ | __/ __|
; | |  | |  __/ | | | | | (_) | |  | |_| |  / ____ \ (__| (__|  __|__ \__ \
; |_|  |_|\___|_| |_| |_|\___/|_|   \__, | /_/    \_\___|\___|\___|___/___/
; Memory access words                __/ |                                 
;                                   |___/                                  
; FILL ( addr count value -- )
_fill   bl @sget3                   ; get 3 parameters
        mov r9,r9                   ; if value=0 then...
        jeq cmvext                  ; ...just exit
        swpb r8                     ; get byte value in msb
filllp  movb r8,*r10+               ; move to addr and increment addr
        dec r9                      ; finished?
        jne filllp                  ; repeat if not
        jmp cmvext                  ; clean up and exit


; CMOVE ( addr1 addr2 count -- )
; Move count bytes beginning at address addr1 to addr2. The byte at addr1 is 
; moved first, proceeding toward high memory. If count is zero nothing is moved
_cmove  bl @sget3                   ; get 3 parameters
        mov r8,r8                   ; if count=0 then...
        jeq cmvext                  ; ...just exit
cmovlp  movb *r10+,*r9+             ; move a byte
        dec r8                      ; finished?
        jne cmovlp                  ; repeat if not
        jmp cmvext                  ; clean up and exit


; CMOVE> ( addr1 addr2 count -- )
; Move the count bytes at address addr1 to addr2. The move begins by moving the
; byte at addr1 plus count minus 1 to addr2 plus count minus 1 and proceeds to
; successively lower addresses for count bytes.
; If count is zero nothing is moved.
; (Useful for sliding a string towards higher addresses)
_cmovf  bl @sget3                   ; get 3 parameters
        mov r8,r8                   ; if count=0 then...
        jeq cmvext                  ; ...just exit
        dec r8                      ; count-1
        a r8,r9                     ; addr2=addr2+count-1
        a r8,r10                    ; addr1=addr1+count-1
        inc r8                      ; restore count
cmvflp  movb *r10,*r9               ; move a byte
        dec r10                     ; decrement addr 1
        dec r9                      ; decrement addr 2
        dec r8                      ; decrement count
        jne cmvflp                  ; loop if not finished
cmvext  b @retB0


; COPYW (source destination count -- )
; copy WORDS from source to destination for 'count' words
; no action taken if count=0
_copyw  bl @sget3
        mov r8,r8                   ; if count=0 then...
        jeq cmvext                  ; ...just exit
copywl  mov *r10+,*r9+              ; copy a word
        dec r8                      ; decrement counter
        jne copywl                  ; loop if counter not zero
        jmp cmvext                  ; clean up and exit


; ; >MAP ( bank address -- )
; If a SAMS card is present, maps memory bank "bank" to address "address"
_sams   mov r12,r11                 ; save address of NEXT
        mov *stack+,r1              ; get address
        andi r1,>f000               ; set to 4k boundary
        srl r1,11                   ; divide by 2048
        ai r1,>4000                 ; convert to SAMS register address
        mov *stack+,r2              ; get bank
        andi r2,>ff                 ; mask off any crap
        mov r2,r0                   ; keep a copy
        sla r2,8                    ; move to high byte
        xor r0,r2                   ; combine r0 & r2. Hi & lo bytes are now identical
        li r12,>1e00                ; cru address of SAMS
        sbo 0                       ; enable SAMS registers
        mov r2,*r1                  ; poke sams register
        sbz 0                       ; disable sams registers
        mov r11,r12                 ; restore address of NEXT
        b @retB0                    ; return to caller


; VDP Write To Register ( value register -- )
_vwtrf  mov *stack+,r0              ; get register
        sla r0,8                    ; move to high byte
        mov *stack+,r1              ; get value
        andi r1,>00ff               ; mask off high byte
        soc r1,r0                   ; merge
        bl @_vwtr                   ; write it
        b @retB0


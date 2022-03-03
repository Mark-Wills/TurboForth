;  __  __                                                                  
; |  \/  |                                     /\                          
; | \  / | ___ _ __ ___   ___  _ __ _   _     /  \   ___  ___  ___ ___ ___ 
; | |\/| |/ _ \ '_ ` _ \ / _ \| '__| | | |   / /\ \ / __|/ __|/ _ | __/ __|
; | |  | |  __/ | | | | | (_) | |  | |_| |  / ____ \ (__| (__|  __|__ \__ \
; |_|  |_|\___|_| |_| |_|\___/|_|   \__, | /_/    \_\___|\___|\___|___/___/
; Memory access words                __/ |                                 
;                                   |___/                                  

grmwa    equ >9c02                  ; GROM Write Address Register
grmra    equ >9802                  ; GROM Read Address Register
grmrd    equ >9800                  ; GROM Read Data Register
grmwd    equ >9c00                  ; GROM Write Data Register

; @            addr -- 16b                   79            "fetch" 
; 16b is the value at addr.
fetchh  data rsfth,1
        text '@ '
fetch   data $+2
        mov *stack,r8               ; get address
        mov *r8,*stack              ; peek address and put on data stack
        b *next


; @++  ( addr -- addr+2 value )
; fetches the cell at memory address "address" then increments address
; and leaves it on the stack
faddph  data fetchh,3
        text '@++'
ftchpp  data $+2
        mov *stack,r8               ; get addr
        inct *stack                 ; advance addr to get addr+2
        dect stack                  ; new stack entry
        mov *r8,*stack              ; peek address and value put on  data stack
        b *next


; !            16b addr --                   79            "store" 
; 16b is stored at addr.
storeh  data faddph,1
        text '! '
store   data $+2
        mov *stack+,r8              ; pop addr
        mov *stack+,*r8             ; pop 16b and write to addr
        b *next


; +!           w1 addr --                    79       "plus-store" 
; w1 is added to the w value at addr using the convention for + .  
; This sum replaces the original value at addr.
staddh  data storeh,2
        text '+!'
stadd   data $+2
        mov *stack+,r8              ; pop addr
        a *stack+,*r8               ; pop w1 and add to value at addr
        b *next


; C@           addr -- 8b                    79          "c-fetch" 
; 8b is the contents of the byte at addr.
chrfh   data staddh,2
        text 'C@'
chrftc  data $+2
        mov *stack,r8               ; address in r8
        movb *r8,r8                 ; peek address and store in msb of r8
        srl r8,8                    ; move to low byte
        mov r8,*stack               ; move msb of r8 onto data stack
        b *next


; C!           16b addr --                   79          "c-store" 
; The least-significant 8 bits of 16b are stored into the byte at addr.
stbh    data chrfh,2
        text 'C!'
stb     data $+2
        mov *stack+,r8              ; pop addr
        mov *stack+,r7              ; pop 16b
        swpb r7                     ; rotate LOW BYTE into MSB
        movb r7,*r8                 ; move the byte into the address in r8
        b *next


; 0! ( addr -- )
; store 0 at addr
stor0h  data stbh,2
        text '0!'
store0  data $+2
        mov *stack+,r8              ; pop address
        clr *r8                     ; zero it
stor0x  b *next


; CHARS ( x1 -- x1 )
; return the memory size required to hold x2 chars (bytes)
; note: since this word does nothing, it is immediate, to avoid a run-time 
; speed penalty
charsh  data stor0h,immed+5
        text 'CHARS '
chars   data stor0x     ; do nothing, and use the exit in 0! to do it! 
                        ; (saves 2 bytes)


; V@ ( address -- value )
; read vdp address and return BYTE as 16 bit right justified cell
vdpfh   data charsh,2
        text 'V@'
vdpftc  data $+2
        mov *stack,r0               ; vdp address from data stack to r0
        bl @vsbr                    ; execute VDP single byte read routine
        srl r1,8                    ; value move to low byte
        mov r1,*stack               ; place it on the stack
        b *next


; V! ( value addr -- )
; store BYTE value (as 16 bit right justified cell) at VDP address
vdpwh   data vdpfh,2
        text 'V!'
vdpstr  data $+2
        mov *stack+,r0              ; pop addr 
        mov *stack+,r1              ; pop value
        swpb r1                     ; get lsb of value into msb
        bl @vsbw                    ; write to vdp
        b *next


; VDP Write Word ( address value -- )
vdpwwh  data vdpwh,3
        text 'V2! '
        data docol,swap,vdpww,drop,exit        


; VDP Read Word ( vdp_address -- word_value)
vdprwh  data vdpwwh,3
;       DUP V@ >< SWAP 1+ V@ OR ;
        text 'V2@ '
vdprw   data docol,dup,vdpftc,swpb_,swap,plus1,vdpftc,or_,exit


; VDP Write To Register ( value register -- )
vwtrfh  data vdprwh,4
        text 'VWTR'
vwtrf   data $+2
        bl @bank1
        data _vwtrf                 ; see 1-04-Memory.a99


; VMBR ( vdp_address cpu_address byte_count -- )
vmbrh   data vwtrfh,4
        text 'VMBR'
fvmbr   data $+2
        li r6,vmbr                  ; address of vdp routine to call
        jmp vdpm


; VMBW ( vdp_address cpu_address byte_count -- )
vmbwh   data vmbrh,4
        text 'VMBW'
fvmbw   data $+2
        li r6,vmbw                  ; address of vdp routine to call
        ; fall down to vdpm routine below...


; utility routine used by VMBR & VMBW above
vdpm    
        mov *stack+,r2              ; pop byte count
        mov *stack+,r1              ; pop cpu address
        mov *stack+,r0              ; pop vdp address
        mov r2,r2                   ; check for zero byte count
        jeq vdpx                    ; if zero then just exit
        bl *r6                      ; execute appropriate routine
vdpx    b *next


; ; >MAP ( bank address -- )
; If a SAMS card is present, maps memory bank "bank" to address "address"
samsh   data vmbwh,4
        text '>MAP'
sams_   data $+2
        bl @bank1
        data _sams                  ; implemented in 1-04-Memory.a99


; HFREE ( -- free_bytes )
; returns the number of free bytes in upper 24k RAM
hfreeh  data samsh,5
        text 'HFREE '
hfree   data docol,lit,>ffff,ffaih,fetch,sub,plus1,exit


; LFREE ( -- free_bytes )
; returns the number of free bytes in lower 8k RAM
lfreeh  data hfreeh,5
        text 'LFREE '
lfree   data docol,lit
bit1    data >4000                  ; note: also used by VSBW to save 2 bytes
                                    ; yes! memory is THAT tight!
        data ffaml,fetch,sub,exit


; FILL         addr u 8b --                  83                   
; u bytes of memory beginning at addr are set to 8b.  
; No action is taken if u is zero.
fillh   data lfreeh,4
        text 'FILL'
fill    data $+2
        bl @bank1
        data _fill                  ; implemented in 1-04-Memory.a99


; CMOVE        addr1 addr2 u --              83           "c-move" 
; Move u bytes beginning at address addr1 to addr2.  
; The byte at addr1 is moved first, proceeding toward high memory.  
; If u is zero nothing is moved.
cmoveh  data fillh,5
        text 'CMOVE '
cmove   data $+2
        bl @bank1
        data _cmove                 ; implemented in 1-04-Memory.a99


; CMOVE>       addr1 addr2 u --              83        "c-move-up" 
; Move the u bytes at address addr1 to addr2.  
; The move begins by moving the byte at (addr1 plus u minus 1) to 
; (addr2 plus u minus 1) and proceeds to successively lower addresses for u 
; bytes.  
; If u is zero nothing is moved. Useful for sliding a string towards higher
; addresses.
cmovfh  data cmoveh,6
        text 'CMOVE>'
cmovf   data $+2
        bl @bank1
        data _cmovf                 ; implemented in 1-04-Memory.a99


; MEM ( -- ) 
; Displays the number of free bytes in low memory, high memory, and the total 
; number of free bytes to the screen.
freeh   data cmovfh,3
        text 'MEM '
        data docol
        data hfree,lfree,dup2,udot,udot,add,udot,exit


; COPYW (source destination count -- )
; copy WORDS from source to destination for 'count' words
; no action taken if count=0
copywh  data freeh,5
        text 'COPYW '
copyw   data $+2
        bl @bank1
        data _copyw                 ; implemented in 1-04-Memory.a99



;   _____                 _     _           __          __            _     
;  / ____|               | |   (_)          \ \        / /           | |    
; | |  __ _ __ __ _ _ __ | |__  _  ___ ___   \ \  /\  / /___  _ __ __| |___ 
; | | |_ | '__/ _` | '_ \| '_ \| |/ __/ __|   \ \/  \/ // _ \| '__/ _` / __|
; | |__| | | | (_| | |_) | | | | | (__\__ \    \  /\  /| (_) | | | (_| \__ \
;  \_____|_|  \__,_| .__/|_| |_|_|\___|___/     \/  \/  \___/|_|  \__,_|___/
;                  | |                                                      
;                  |_|                                                      
; graphics related commands

;[ GMODE ( gmode -- )
_gmode  mov *stack+,r8              ; pop gmode
        ci r8,0                     ; 40 column mode?
        jeq s40col                  ; jump if yes
        ci r8,1                     ; 32 column mode?
        jeq s32col                  ; jump if yes
        ci r8,2                     ; 80 column mode?
        jeq s80col                  ; jump if yes
                                    ; otherwise illegal graphics mode selected,
                                    ; so fall through to 40 column mode...
s40col  li r2,col40d                ; vdp register data for 40 column mode
        jmp ldvdpr                  ; go load the vdp registers
s32col  li r2,col32d                ; vdp register data for 32 column mode
        jmp ldvdpr                  ; go load the vdp registers
s80col  li r2,col80d                ; vdp register data for 80 column mode
    ; load the vdp registers
ldvdpr  mov r2,r7                   ; save address for later
        movb *r2+,r1                ; number of registers to load
        sra r1,8                    ; move the count to the low byte
        clr r0                      ; start with register 0
ldvdpl  movb *r2+,r0                ; get register data in r0 MSB
        swpb r0                     ; swap it over
        bl @_vwtr                   ; write the register
        swpb r0                     ; swap it back again
        inc r0                      ; add 1 to register
        dec r1                      ; finished?
        jne ldvdpl                  ; repeat if not
    ; set XMAX...
        movb *r2,r0                 ; get xmax
        sra r0,8                    ; move to low byte
        mov r0,@xmax                ; set xmax
        inct r7                     ; point to vdp r1 data
        movb *r7,@>83d4             ; write vdp r1 to >83d4
        movb *r7,@VDPR1             ; save copy        
    ; now clear the screen...
        mov @xmax,r1                ; calculate the character count
        li r0,24                    ; according to the...
        mpy r0,r1                   ; ...text mode
        clr r0                      ; screen address
        li r1,>2000                 ; space character
        bl @vsbwmi                  ; wipe screen
        clr @scrX                   ; zero x coordinate
        clr @scrY                   ; zero y coordinate
        ci r8,1                     ; was 32 column mode selected?
        jne gmodex                  ; if not, then exit
    ; load colour table for pattern mode...
        li r0,>380                  ; color table
        li r1,>f000                 ; white on transparent
        li r2,16                    ; count
        bl @vsbwmi                  ; load colour table
    ; initialise sprite attribute list...
        li r0,>303                  ; address of colour byte
        clr r1                      ; transparent colour
        li r2,32                    ; 32 sprites
dovdp2  bl @_vsbw0                  ; write to sprite
        ai r0,4                     ; move to next sprite
        dec r2                      ; decrement count
        jne dovdp2                  ; repeat if not finished
gmodex  jmp gexit
col40d    ; register count and data
        byte 8,>00,>f0,>00,>0e,>01,>06,>00,>f4
        byte 40    ; XMAX
col32d    ; register count and data
        byte 8,>00,>e0,>00,>0e,>01,>06,>02,>f4
        byte 32 ; XMAX
col80d    ; register count and data
        byte 15,>04,>70,>03,>e8,>01,>06,>00,>f4,>88,>00,>00,>00,>94,>10,>00
        byte 80 ; XMAX
        even
;]

;[ HCHAR ( y x ascii count -- )
_hchar  bl @get4                    ; get parameters from stack and calculate 
                                    ; screen address
        bl @_vsbwm                  ; write to screen
gexit   b @retB0
;]
    
;[ VCHAR ( y x ascii count -- )
_vchar  bl @get4                    ; get parameters from stack and calculate 
                                    ; screen address
        li r6,24                    ; row count
        mpy @xmax,r6                ; max visible address+1 (in r7)
        dec r7                      ; correct max visible (we count from 0)
        mov @xmax,r6                ; get xmax in a register
vchar1  bl @_vsbw                   ; write a character
        a r6,r0                     ; move down one line
        c r0,r7                     ; gone off end of screen?
        jle vchar2                  ; skip if not
        s r7,r0                     ; reduce address
vchar2  dec r2                      ; decrement count
        jne vchar1                  ; repeat if not finished
        jmp gexit
;]

;[ GCHAR ( y x -- ascii )
_gchar  bl @get2                    ; get y & x from stack
        mpy @xmax,r6                ; compute y
        a r7,r0                     ; compute screen address
        clr r1                      ; use r1 for byte operations
        bl @_vsbr                   ; read byte from vdp
        swpb r1                     ; move byte to lsb
        dect stack                  ; make space on stack
        mov r1,*stack               ; place on stack as 16 bit word
        jmp gexit
;]

;[ DCHAR ( address count ascii -- )
; Equivalent to CALL CHAR in BASIC.
; Used to define a character.
; Moves count words from address to ascii address in VDP memory
_dchar  bl @sget3                   ; get 3 parameters
        mov r9,r9                   ; if count=0 then...
        jeq gexit                   ; ...just exit
        mov r8,r0                   ; ascii
        sla r0,3                    ; multiply by 8
        ai r0,>800                  ; add pattern table offset
        mov r10,r1                  ; source address
        mov r9,r2                   ; count
        sla r2,1                    ; convert from words to bytes
        bl @_vmbw                   ; write to vdp
        jmp gexit
;]

;[ SPRITE ( sprite y x ascii color -- )
; sprite attribute list begins at 6*80h=300h
_sprit  bl @sget5                   ; get 5 parameters
        dec r9                      ; correct for screen to char alignment
        sla r10,2                   ; multiply sprite by 4 (offset into SAL)
        li r11,sal                  ; address of SAL in CPU ram
        li r0,>300                  ; address of SAL in VDP ram
        a r10,r11                   ; add offset to cpu addr according to 
                                    ; sprite number
        mov r11,r1                  ; cpu source for vmbw
        a r10,r0                    ; destination address for vmbw
        swpb r6                     ; rotate colour
        swpb r7                     ; rotate ascii
        swpb r8                     ; rotate x
        swpb r9                     ; rotate y
        movb r9,*r11+               ; move y to cpu buffer
        movb r8,*r11+               ; move x to cpu buffer
        movb r7,*r11+               ; move ascii to cpu buffer
        movb r6,*r11+               ; move colour to cpu buffer
        li r2,4
        bl @_vmbw                   ; copy entry from SAL to appropriate sprite
                                    ; address in VDP 
sprtx   b @retB0
;]

;[ COINC ( tolerance spr1 spr2 -- flag )
; check for coincidence between sprite spr1 and spr2. If both the horizontal
; and vertical difference between the two sprites is < tolerance then the 
; sprites are considered to be in coincidence with each other and flag shall be
; true, otherwise it shall be false.
_coinc  mov @bank1_,@retbnk         ; return to bank 1 if taking interrupt
        limi 2                      ; let interrupts run 
        limi 0
        mov *stack+,r2              ; get spr2
        mov *stack+,r1              ; get spr1
        movb @>837b,r0              ; get vdp status register (ed/as pg. 405)
        andi r0,>2000               ; check collision bits
        jeq miss                    ; if NO sprites are in collision then
                                    ; don't do the rest of the test.
    ; some sprites are in collision, so....
        sla r1,2                    ; spr1 * 4 
        sla r2,2                    ; spr2 * 4
        li r6,sal                   ; address of sprite attribute list
        a r6,r1                     ; address of spr1 in sal
        a r6,r2                     ; address of spr2 in sal
    ; check row coordinates
        bl @chkcnc                  ; check for coincidence
        jhe miss                    ; if more than tolerance it's a miss so...
    ; check column coordinates
chkrow  bl @chkcnc
        jhe miss                    ; if distance > tolerance then its a miss 
        seto *stack                 ; otherwise it's a hit
        jmp sprtx                   ; exit
; subroutine: check distance between sprites
chkcnc  movb *r1+,r8                ; get spr1 coordinate
        movb *r2+,r9                ; get spr2 coordinate
        srl r8,8                    ; spr2 row to low byte
        srl r9,8                    ; spr2 row to low byte
        s r8,r9                     ; subtract
        abs r9                      ; ignore sign 
        c r9,*stack                 ; compare to tolerance
        .rt                         ; return to caller
    ; report a miss...
miss    clr *stack
coincx  jmp sprtx                   ; exit
        
;]

;[ MAGNIFY ( x -- )
; sets sprite magnification:
; only the least significant bits are used:
; bit 7: 1=magnified (0=not magnified)
; bit 6: 1=double size (4 character)
; Remember: TI number their bits backwards! Idiots!
_magfy  mov *stack+,r10             ; pop x
        swpb r10                    ; get value in msb
        andi r10,>0300              ; mask out any crap
        li r0,>0001                 ; vdp register number in lsb
        clr r2                      ; prepare for byte operations
        movb @VDPR1,r2              ; get copy of VDP R1
        andi r2,>fc00               ; mask out magnification bits
        socb r2,r10                 ; OR in new magnification value
        movb r10,r0                 ; place in r0 msb
        movb r0,@>83d4              ; place copy in 83d4
        movb r0,@VDPR1              ; reserve copy (VDP regs are read only)
        swpb r0                     ; rotate
        bl @_vwtr                   ; set the register
        jmp sprtx
;]

;[ SPRCOL ( sprite# colour -- )
; sets the colour of a sprite
_spcol  mov *stack+,r9              ; pop colour
        mov *stack+,r10             ; pop sprite#
        li r0,>300+3                ; SAL in vdp (offset to colour byte added)
        li r8,SAL+3                 ; SAL in CPU (offset to colour byte added)
        sla r10,2                   ; multiply sprite number by 4
        a r10,r0                    ; point to correct address in vdp
        a r10,r8                    ; point to correct address in CPU SAL        
        swpb r9                     ; rotate colour into MSB
        mov r9,r1                   ; into r1 for VSBW
        movb r9,*r8                 ; load into CPU SAL
        bl @_vsbw                   ; write colour byte into VDP
        jmp sprtx
;]

;[ SPRLOC ( sprite y x -- )
; sets the location of a sprite
_sploc  bl @sget3                   ; get 3 parameters from stack
        dec r9                      ; correct for screen to char alignment
        li r0,>300                  ; address of SAL in VDP
        li r1,SAL                   ; address of SAL in CPU
        sla r10,2                   ; get offset into tables
        a r10,r0                    ; add to vdp addr
        a r10,r1                    ; add to cpu addr
        swpb r8                     ; rotate x
        swpb r9                     ; rotate y
        movb r9,*r1+                ; write y to cpu SAL
        movb r8,*r1                 ; write x to cpu SAL
        dec r1                      ; point to beginning of entry in SAL
        li r2,2                     ; two bytes to write
        bl @_vmbw                   ; write to VDP
        jmp sprtx
;]

;[ SPRLOC? ( sprite -- y x )
; gets the location of a sprite
_spget  mov *stack,r10              ; pop sprite#
        li r0,sal                   ; address of SAL in CPU ram
        sla r10,2                   ; get offset
        a r10,r0                    ; point to correct address in SAL
        clr r1                      ; prepare for byte operations
        movb *r0+,r1                ; get y and point to x
        ai r1,>0100                 ; correct for screen to char alignment
        swpb r1                     ; move to lsb
        mov r1,*stack               ; place on stack 
        dect stack                  ; make new stack entry
        clr r1
        movb *r0,r1                 ; get x
        swpb r1                     ; move to lsb
        mov r1,*stack               ; place on stack
        jmp sprtx
;]

;[ SPRPAT ( sprite# ascii -- )
; sets the pattern of a sprite
_sppat  mov *stack+,r9              ; pop ascii
        mov *stack+,r10             ; pop sprite#
        li r0,>300+2                ; address of SAL in vdp
        li r2,SAL+2                 ; address of SAL in cpu
        sla r10,2                   ; calculate offset
        a r10,r0                    ; offset into vdp
        a r10,r2                    ; offset into cpu
        swpb r9                     ; rotate ascii into msb
        mov r9,r1                   ; for vsbw
        movb r9,*r2                 ; set in cpu ram
        bl @_vsbw                   ; set in vdp ram
        jmp sprtx
;]

;[ SPRVEC ( sprite y x -- )
; sets the Y and X movement offsets for sprite movement with SPRMOV
_smlst  bl @sget3                   ; get 3 parameters
        li r0,smlist                ; address of sprite movement list
        sla r10,1                   ; multiply sprite number by 2
        a r10,r0                    ; r0=address of appropriate entry in smlist 
                                    ; table.
        swpb r9                     ; get y in MSB
        swpb r8                     ; get x in MSB
        movb r9,*r0+                ; load y into smlist
        movb r8,*r0                 ; load x into smlist
        jmp gexit1
;]

;[ SPRMOV ( start_sprite number_of_sprites -- )
; moves sprites according to the entries in SMLIST, starting from start_sprite
; and continuing for number_of_sprites
;
; UPDATED MARCH 2012 SO THAT ONLY SPRITES WHO HAVE THEIR COORDINATES CHANGED
; ARE ACTUALLY UPDATED IN VDP
_spmov  mov *stack+,r9              ; pop number of sprites
        mov *stack+,r10             ; pop start sprite
        abs r9                      ; force positive & compare to zero. Nice.
        jeq gexit1                  ; just exit if number of sprites=0
        mov r9,r2                   ; save no. of sprites to move in r2
        mov r10,r11                 ; copy start sprite
        mov r10,r6                  ; copy again
        sla r10,1                   ; adjust for start sprite smlist
        ai r10,smlist               ; point to correct entry in smlist
        sla r11,2                   ; adjust destination for sal
        ai r11,sal                  ; point to correct entry in the sal
sprmv1  ab *r10+,*r11+              ; add y
        ab *r10+,*r11+              ; add x
        inct r11                    ; skip ascii code and colour in sal
        dec r9                      ; decrement count
        jne sprmv1                  ; repeat if not finished
        li r0,>300                  ; vdp address of sal
        sla r6,2                    ; calculate offset into sal
        a r6,r0                     ; calculate vdp sal address
        li r1,sal                   ; cpu address of sal
        a r6,r1                     ; calculate cpu source address of sal
        sla r2,2                    ; calculate number of bytes to write
        bl @_vmbw                   ; copy cpu sal to vdp sal
        jmp gexit1
;]

;[ COLOR ( char_set foreground background -- )
; sets the color sets in 32 column mode
_color  bl @sget3                   ; get 3 parameters
        li r0,>380                  ; address of colour table
        a r10,r0                    ; point to correct colour set entry
        sla r9,4                    ; move foreground into ms nybble
        soc r9,r8                   ; OR foreground into background
        mov r8,r1                   ; move to r1 for vsbw
        swpb r1                     ; move to ms byte
        bl @_vsbw0                  ; write to vdp
gexit1  b @retB0
;]

;[ SCREEN ( colour -- )
; sets the screen colour
_scren  mov *stack+,r10             ; pop colour
        li r0,>0700                 ; vdp register number
        andi r10,>00ff              ; mask out any crap
        soc r10,r0                  ; or colour into register
        bl @_vwtr
        jmp gexit1
;]

;[ SCROLL ( direction -- ) 
; scrolls the screen, according to the coodinates in PANEL
; 0=left 2=right 4=up 6=down
; I'm not happy with these routines. I'm sure they could be shorter and faster
; I'll have to revisit them later.
_scrol  
        mov @panxy,r9               ; screen address to start
        mov @panc,r6                ; column count
        mov @panr,r7                ; row count
        li r8,>2000                 ; space character (used if no wrap around)
        mov @wrap,r10               ; get WRAP in a register
        mov @xmax,r15               ; get xmax in a register
        mov @bank1_,@retbnk         ; interrupts should return to bank 1
        ; check direction and call appropriate routine...
        li r0,scrlut                ; address of look up table 
        a *stack+,r0                ; add and pop parameter to get address of 
;                                   ; routine.
        mov *r0,r0                  ; get the address in a register
        b *r0                       ; call the routine
scrlut  data _left,_right,_up,_down ; addresses of the routines to call

;[      ; left scroll...
_left   ; read a line from screen into buffer...
        mov r9,r0                   ; vdp address
        mov r6,r2                   ; number of bytes to read
        mov @here,r1                ; cpu buffer
        bl @_vmbr2                  ; read a line
        mov @here,r0                ; start of buffer
        mov r0,r1                   ; one character to the right
        inc r1                      ; one character to the right
        mov r10,r10                 ; check WRAP
        jne _lwrap                  ; jump if true (wrap=on)
        movb r8,r14                 ; else load a space character for the 
                                    ; wrap-around.
        jmp $+4                     ; skip next instruction
_lwrap  movb *r0,r14                ; save leftmost char for wrap around
        mov r6,r2                   ; x count
        dec r2                      ; point to end of line for wrap-around
_left1  movb *r1+,*r0+              ; copy character to the left
        dec r2                      ; reduce x count
        jne _left1                  ; loop if not finished
        movb r14,*r0                ; copy saved character for wrap around
        mov r9,r0                   ; set screen address
        mov @here,r1                ; source
        mov r6,r2                   ; count
        bl @_vmbw2                  ; write to screen
        dec r7                      ; finished?
        jeq gexit1                  ; if so exit
        a r15,r9                    ; move down one line
        jmp _left                   ; repeat
;]

;[      ; right scroll...
_right  ; read a line from screen into buffer...
        mov r9,r0                   ; vdp address
        mov r6,r2                   ; number of bytes to read
        mov @here,r1                ; cpu buffer
        bl @_vmbr2                  ; read a line
        mov @here,r0                ; start of buffer
        a r6,r0                     ; end of buffer +1
        dec r0                      ; correct to point to end of buffer
        mov r0,r1                   ; r1 will hold...
        dec r1                      ; ...end of buffer -1
        mov r10,r10                 ; check WRAP
        jne _rwrap                  ; jump if true (wrap=on)
        movb r8,r14                 ; else load a space character for the wrap-around
        jmp $+4                     ; skip next instruction
_rwrap  movb *r0,r14                ; save leftmost char for wrap around
        mov r6,r2                   ; x count
        dec r2                      ; point to end of line for wrap-around
_right1 movb *r1,*r0                ; copy character to the left
        dec r0                      ; decrement pointer
        dec r1                      ; decrement pointer
        dec r2                      ; reduce x count
        jne _right1                 ; loop if not finished
        movb r14,*r0                ; copy saved character for wrap around
        mov r9,r0                   ; set screen address
        mov @here,r1                ; source
        mov r6,r2                   ; count
        bl @_vmbw2                  ; write to screen
        dec r7                      ; finished?
        jeq gexit1                  ; if so exit
        a r15,r9                    ; move down one line
        jmp _right                  ; repeat
;]

;[      ; up scroll...
_up     mov r10,r10                 ; check wrap
        jeq _up0                    ; jump if no wrap
        mov r9,r0                   ; top left address
        mov r6,r2                   ; x count
        li r1,tib                   ; we'll use the terminal input buffer for storage
        bl @_vmbr2                  ; read the liine
_up0    mov r9,r0                   ; top left screen address to r0
_up1    a r15,r0                    ; move down one line
        mov @here,r1                ; buffer address
        mov r6,r2                   ; x count
        bl @_vmbr2                  ; read from screen
        s r15,r0                    ; move up a line
        mov @here,r1                ; buffer address
        mov r6,r2                   ; number of bytes to write (x count)
        bl @_vmbw2                  ; write them
        dec r7                      ; decrement counter
        jeq _up2                    ; exit if finished
        a r15,r0                    ; move down a line
        jmp _up1                    ; repeat
_up2    mov r10,r10                 ; check wrap
        jeq _up3                    ; blank line if not required
        li r1,tib                   ; else get ready to write the buffered line
        mov r6,r2                   ; x count
        bl @_vmbw2                  ; write it
        jmp _upout                  ; see ya
_up3    li r1,>2000                 ; write a blank line
        mov r6,r2                   ; x count
        bl @_vsbwm2                 ; write it
_upout  clr @tib                    ; clear tib
gexit2  b @retB0
;]

;[      ; down scroll...
_down   dec r7
        mov r7,r0                   ; y length
        mpy r15,r0                  ; convert to address (result in r1)
        a r9,r1                     ; add top of panel offset
        mov r1,r0                   ; vdp address in r0
        mov r10,r10                 ; check wrap
        jeq _down0                  ; skip if not required
        li r1,tib                   ; we'll use the terminal input buffer for storage
        mov r6,r2                   ; x count
        bl @_vmbr2                  ; read the line
_down0  s r15,r0                    ; move up a line
        mov @here,r1                ; buffer address
        mov r6,r2                   ; x count
        bl @_vmbr2                  ; read a line
        a r15,r0                    ; move down a line
        mov @here,r1                ; buffer address
        mov r6,r2                   ; x count
        bl @_vmbw2                  ; write it
        dec r7                      ; decrement line count
        jeq _down1                  ; jump if finished
        s r15,r0                    ; otherwise move up a line
        jmp _down0                  ; and repeat
_down1  s r15,r0                    ; up a line
        mov r10,r10                 ; check wrap
        jeq _down2                  ; blank line if not required
        li r1,tib                   ; source
        mov r6,r2                   ; x count
        bl @_vmbw2                  ; write saved line
        jmp _dnout                  ; see ya
_down2  li r1,>2000                 ; write a blank line
        mov r6,r2                   ; x count
        bl @_vsbwm2                 ; write it
_dnout  clr @tib                    ; clear tib
        jmp gexit2
;]
;]

;[ PANEL ( x y xl yl -- )
; defines a screen panel to be used by SCROLL
_panel          
        bl @sget4                   ; get 4 parameters off stack
        mov r9,r0                   ; move y
        mpy @xmax,r0                ; multiply y by line length
        a r10,r1                    ; add x
        mov r1,@panxy               ; save it
        mov r7,@panr                ; save yl
        mov r8,@panc                ; save xl
        jmp gexit2
;]

;[
; subroutine to get parameters off the stack
sget5   mov *stack+,r6
sget4   mov *stack+,r7
sget3   mov *stack+,r8
        mov *stack+,r9
        mov *stack+,r10
        .rt
;]

;[
; subroutine to get parameters off the stack for HCHAR VCHAR and GCHAR
; Has two entry points:
; get4: gets four parameters (HCHAR & VHCAR)
; get2: gets two parameters (GCHAR)
get4    mov *stack+,r2              ; pop count
        jeq gabort                  ; if count=0 then cancel the instruction
        mov *stack+,r1              ; pop ascii
        swpb r1                     ; move to high byte
get2    mov *stack+,r0              ; pop x
        mov *stack+,r6              ; pop y
        mpy @xmax,r6                ; multiply by screen size
        a r7,r0                     ; calculate screen start address
        .rt
gabort  ai stack,6                  ; pop remaining parameters off the stack
        b @retB0                    ; and just exit
;]

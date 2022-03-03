
;  ______     _ _ _               __          __            _
; |  ____|   | (_) |              \ \        / /           | |    
; | |__    __| |_| |_  ___  _ __   \ \  /\  / /___  _ __ __| |___ 
; |  __|  / _` | | __|/ _ \| '__|   \ \/  \/ // _ \| '__/ _` / __|
; | |____| (_| | | |_| (_) | |       \  /\  /| (_) | | | (_| \__ \
; |______|\__,_|_|\__|\___/|_|        \/  \/  \___/|_|  \__,_|___/
; block editor

keyCC   equ -125                    ; key code for ctrl c (copy line)
keyCV   equ -106                    ; key code for ctrl v (paste line)
keyCI   equ -119                    ; key code for ctrl i (insert line)
keyCD   equ -124                    ; key code for ctrl d (delete line)
keyCO   equ -113                    ; key code for ctrl o (previous block)
keyCP   equ -112                    ; key code for ctrl p (next block)
keyF9   equ 15                      ; key code for function 9 (back)

keyF7   equ 1                       ; key code for function 7 (tab)
keyF4   equ 2                       ; key code for function 4 (escape)
keyF3   equ 7                       ; key code for function 3 (erase line)
keyF2   equ 4                       ; key code for function 2 (insert/overwrite)
keyF1   equ 3                       ; key code for function 1 (del)
keyFE   equ 11                      ; cursor up keycode
keyFS   equ 8                       ; cursor left keycode
keyFD   equ 9                       ; cursor right keycode
keyFX   equ 10                      ; cursor down keycode
keyFeq  equ 5                       ; keycode for function = (quit)
keyRET  equ 13                      ; keycode for ENTER key

savkey  equ scrx                    ; borrow scrX memory location for saving 
                                    ; keypresses

_edit   clr @csrflg                 ; clear shared cursor flash flag 
                                    ; (shared with forcnt)
        clr @temp2                  ; next block to load
        mov *stack,r0               ; get address from BLOCK
        mov r0,r7                   ; copy it
        jne _edit1                  ; if not zero then continue
        
        inct stack                  ; else BLOCK failed to load block. 
        b @retB0                    ; Remove vdp address from stack and exit

    ; determine if block is dirty or clean:
    ; display * next to block number if dirty otherwise display a space
_edit1  jgt _edit4                  ; jump if dirty bit not set
        li r6,_edit4                ; load return address 
        bl @disupd                  ; write CHANGED to screen 
        
_edit4  andi r7,>7fff               ; remove dirty bit if set
        mov r7,*stack               ; write it back, we'll use it further on...
        bl @csrdef                  ; define cursor udg
        clr @epage                  ; set page to first page
        clr @temp                   ; initialise insert/overwrite mode
        bl @draws                   ; draw static parts of the display
        bl @drawd                   ; draw dynamic parts of the display
        bl @insovr                  ; display mode
        clr @csrx                   ; used for cursor x
        clr @csry                   ; used for cursor y
        clr @cursrd                 ; reset cursor delay

        bl @delay                   ; small delay to give the user time to
        data 30000                  ; release the enter key!

; editor main loop
; keyboard scanning and auto-repeat
edml2   bl @scnkey                  ; get key in r7
edml4   mov r7,@savkey              ; save the keypress
        ci r7,>ffff                 ; nothing pressed?
        jeq docfl                   ; if nothing pressed then do cursor flash
        li r13,edml3                ; set something pressed - set return point 
                                    ; for post keypress processing
        jmp chkent                  ; process the key press
edml3   mov @kdel,r0                ; get keyboard repeat delay from kdel
        srl r0,8                    ; upper byte to lower byte
        sla r0,1                    ; move right one. multiplied by 2
edml5   bl @scnkey                  ; scan again
        c r7,@savkey                ; same key as last time?
        jeq edml6                   ; if yes then decrement delay
        jmp edml4                   ; different key - go process it
edml6   dec r0                      ; decrement counter
        jne edml5                   ; check again
        li r13,edml7                ; counter expired. set return point
        jmp chkent                  ; go process key
edml7   movb @kdel+1,r0             ; get short delay from kdel low-byte
        srl r0,8                    ; to low byte 
        jmp edml5                   ; repeat



; do cursorflash
docfl   li r0,>0100
        a r0,@cursrd
        jne edml2                   ; time to flash cursor? loop if not
        inv @csrflg                 ; invert the cursor flag
        jeq oncsr                   ; if 0 do cursor on
        bl @csroff                  ; else do cursor off
        jmp edml2
oncsr   bl @csron
        jmp edml2


; check for enter key
chkent  ci r7,keyRET                ; return/enter pressed?
        jne keycor                  ; skip if not
        clr @csrx                   ; move to left most column
        clr @epage                  ; move to left page
        inc @csry                   ; move down a line
        mov @csry,r0                ; check y
        ci r0,16                    ; 16?
        jne keyen1                  ; skip if not
        clr @csry                   ; clip to 15
keyen1  bl @drawd                   ; render display
        b *r13                      ; continue


; check control keys
;    ; check CTRL O (previous block)
keycor  ci r7,keyCO
        jne keycpr
        mov @lstblk,@temp2
        dec @temp2                  ; decrement block number to load
rt4th   inct stack                  ; remove BLOCK address from stack
        li r12,_next                ; restore pointer to NEXT
        b @retB0                    ; return to forth


;    ; check CTRL P (next block)
keycpr  ci r7,keyCP
        jne keycdr
        mov @lstblk,@temp2
        inc @temp2                  ; increment block number to load
        jmp rt4th                   ; return to forth


;    ; check CTRL D (delete line)
keycdr  ci r7,keyCD                 ; ctrl d pressed?
        jne keycir                  ; skip if not
        bl @needud                  ; set this blocks' status to dirty
    ; calculate end address of buffer
        mov *stack,r6               ; vdp buffer address
        ai r6,1023                  ; point to last byte of buffer
    ; calculate start point
        mov @csry,r0                ; get current line
        inc r0                      ; move down a line
        sla r0,6                    ; multiply by buffer line length
        a *stack,r0                 ; add vdp buffer start address
keycd1  li r2,64                    ; read a line...
        mov @here,r1                ; ...into scroll buffer
        bl @_vmbr                   ; read the line
        ai r0,-64                   ; move up one line
        mov @here,r1                ; source
        li r2,64                    ; count
        bl @_vmbw0                  ; write the line
        ai r0,128                   ; move down 2 lines
        c r0,r6                     ; done all?
        jlt keycd1                  ; loop if not
    ; blank the last line... r6 points to last byte, so...
        mov r6,r0                   ; place in r0 for VDP
        ai r0,-63                   ; move to start of last line in buffer
        li r1,>2000                 ; space character
        li r2,64                    ; line length
        bl @vsbwmi                  ; write spaces
        bl @rsrc                    ; render source
        b *r13                      ; continue


;    ; check CTRL I (insert line)
keycir  ci r7,keyCI                 ; ctrl i pressed?
        jne keyccr                  ; skip if not
        bl @needud                  ; set this blocks' status to dirty
    ; get current line address
        mov @csry,r6                ; current y
        ci r6,15                    ; on the last line?
        jeq keyci2                  ; if so, just erase last line
        sla r6,6                    ; multiply by line length
        a *stack,r6                 ; add vdp buffer address
    ; find last line of buffer
        mov *stack,r0               ; buffer start address
        ai r0,14*64                 ; move to last line but 1 (15th line)
keyci1  mov @here,r1                ; buffer address
        li r2,64                    ; count
        bl @_vmbr                   ; read into buffer
        ai r0,64                    ; move down a line
        mov @here,r1                ; buffer address
        li r2,64                    ; count
        bl @_vmbw0                  ; write the line
        ai r0,-128                  ; move up 2 lines
        c r0,r6                     ; finished?
        jhe keyci1                  ; repeat if not
    ; erase current line, address is in r6
keyci2  mov r6,r0                   ; for vdp
        li r1,>2000                 ; space
        li r2,64                    ; count
        bl @vsbwmi                  ; write 64 spaces
        bl @rsrc                    ; render source window
        b *r13                      ; continue


;    ; check CTRL C (copy)
keyccr  ci r7,keyCC                 ; ctrl C pressed?
        jne keyCVr                  ; skip if not
        li r0,64                    ; buffer pitch
        mov @csry,r1                ; get cursor y
        mpy r0,r1                   ; multiply them (result in r2)
        a *stack,r2                 ; add vdp buffer address
        mov r2,r0                   ; move to r0 for vdp actions
        li r1,tib                   ; destination
        li r2,64                    ; number of bytes to read
        bl @_vmbr                   ; read them into scroll buffer
        b *r13                      ; continue


;    ; check CTRL V (paste)
keyCVr  ci r7,keyCV                 ; ctrl V pressed?
        jne keyf1r                  ; skip if not
        mov @tib,r0                 ; check buffer contents
        jeq nopast                  ; if 0, nothing to paste
        li r0,64                    ; buffer pitch
        mov @csry,r1                ; get cursor y
        mpy r0,r1                   ; multiply them (result in r2)
        a *stack,r2                 ; add vdp buffer address
        mov r2,r0                   ; move to r0 for vdp actions
        li r1,tib                   ; source
        li r2,64                    ; number of bytes to write
        bl @_vmbw0                  ; write them into source buffer
        bl @rsrc                    ; render window
        bl @needud                  ; mark block for update
nopast  b *r13                      ; continue


; check function keys
;    ; check f1 (del)
keyf1r  ci r7,keyF1                 ; f1 pressed?
        jne keyf9r                  ; skip if not
        bl @needud                  ; set this blocks' status to dirty
    ; calculate endpoint
        mov @csry,r1                ; get y
        inc r1                      ; move down one line
        sla r1,6                    ; multiply by buffer line length (64)
        dec r1                      ; point to last char on current line
        a *stack,r1                 ; add in vdp buffer address
        mov r1,r6                   ; save it
    ; calculate start point
        mov @csry,r2                ; get y
        sla r2,6                    ; multiply by buffer line length (64)
        a @csrx,r2                  ; add x
        a *stack,r2                 ; add in vdp address
        mov @epage,r0               ; check page
        jeq keyf1s                  ; skip if 0
        ai r2,30                    ; account for page offset
keyf1s  mov r2,r0                   ; set start point for vdp read
        s r2,r1                     ; calculate length
        mov r1,r2                   ; put in r2 for vmbr
        inc r2
        mov r0,r8                   ; save buffer address
        mov r2,r9                   ; save length
    ; read from source buffer
        mov @here,r1                ; cpu buffer
        bl @_vmbr                   ; read into buffer
        mov r8,r0                   ; restore addresds
        mov r9,r2                   ; restore count
        dec r2                      ; reduce by 1
        jeq f1eol                   ; if on last column then skip
        mov @here,r1                ; move forward...
        inc r1                      ; ...1 char in the buffer
        bl @_vmbw0                  ; write it
f1eol   mov r6,r0                   ; end of line address
        li r1,>2000                 ; write a space character to end of line
        bl @_vsbw0        
        bl @rsrc                    ; render source to window
        b *r13                      ; continue


;    ; check f9 (back)
keyf9r  ci r7,keyF9
        jne keyf3r
        clr @tib                    ; clr length byte in TIB to stop Forth from
                                    ; trying to process the copy/paste buffer as
                                    ; input!
ret4th  b @rt4th                    ; return to forth


;    ; check f3 (erase line)
keyf3r  ci r7,keyF3
        jne keyf7r
        li r0,64                    ; buffer pitch
        mov @csry,r1                ; get cursor y
        mpy r0,r1                   ; multiply them (result in r2)
        a *stack,r2                 ; add vdp buffer address
        mov r2,r0                   ; move to r0 for vdp actions
        li r1,>2000                 ; space character
        li r2,64                    ; 64 bytes to erase
        bl @vsbwmi                  ; erase them
        clr @csrx                   ; move to leftmost column
        clr @epage                  ; left page
        bl @rsrc                    ; render source in window
        bl @needud                  ; set block for update
        b *r13                      ; continue


;    ; check f7 key
keyf7r  ci r7,keyF7                 ; F7 pressed?
        jne keyfqr                  ; skip if not
        bl @is80c                   ; 80 column mode?
        jeq f7exit                  ; dump the keypress if yes - f7 key not used
                                    ; in 80 column mode
        bl @csroff                  ; restore character under cursor
        inv @epage                  ; switch page
        bl @drawd                   ; re-draw screen
f7exit  b *r13


;    ; check quit key
keyfqr  ci r7,keyFeq                ; quit pressed?
        jne keyf2r                  ; skip if not
edF4    mov @lstblk,r0              ; get current block
        bl @scnblk                  ; locate it (blk address in r0)
        clr *r1                     ; un-assign this buffer
        inct r1                     ; point to VDP address pointer
        mov *r1,r0                  ; get the VDP address
        andi r0,>7fff               ; reset dirty bit
        mov r0,*r1                  ; write it back
        clr @tib                    ; clr length byte in TIB to stop Forth from
                                    ; trying to process the copy/paste buffer as
                                    ; input!
        jmp ret4th                  ; return to Forth


;    ; check f2 key
keyf2r  ci r7,keyF2                 ; F2 pressed?
        jne keyd                    ; skip if not
        bl @insovr
        b *r13


;    ; check for fctn + d
keyd    ci r7,keyFD                 ; fctn & d?
        jne keys                    ; skip if not
        bl @csroff                  ; restore character currently under cursor
        bl @is80c
        jne keyd1
        mov @csrx,r0
        ci r0,63
        jmp keyd2
keyd1   mov @csrx,r0                ; get cursor x
        ci r0,33                    ; check limit
keyd2   jeq clipxh                  ; clip if on limit
        inc r0                      ; otherwise increment
        mov r0,@csrx                ; write it back
        bl @csron                   ; set cursor to on state
        b *r13
clipxh  clr @csrx                   ; clip cursor
clipxg  bl @is80c                   ; 80 column?
        jeq keydx
        inv @epage                  ; change page
        bl @drawd                   ; draw window contents
        bl @csron                   ; set cursor to on state
keydx   b *r13


;    ; check for fctn + s
keys    ci r7,keyFS                 ; fctn & s
        jne keye                    ; skip if not
        bl @csroff                  ; restore character currently under cursor
        mov @csrx,r0                ; get cursor x
        jeq clipxl                  ; clip if on limit
        dec r0                      ; otherwise decrement
        mov r0,@csrx                ; write it back
        bl @csron                   ; set cursor on
        b *r13 
clipxl  bl @is80c                   ; 80 column?
        jeq clipx2
        li r0,33                    ; set cursor to the other end
        mov r0,@csrx                ; write it
        jmp clipxg                  ; change page and render
clipx2  li r0,63                    ; set cursor to other end (80 col mode)
        mov r0,@csrx
        b *r13


;    ; check for fctn + e    
keye    ci r7,keyFE                 ; fctn & e
        jne keyx                    ; skip if not
        bl @csroff                  ; restore character currently under cursor
        mov @csry,r0                ; get cursor y
        dec r0                      ; decrement
        mov r0,@csry                ; write it back
        jlt clipyl                  ; clip if on limit
clipyg  bl @csron                   ; set cursor on
        b *r13
clipyl  li r0,15                    ; set cursor to the other end
        mov r0,@csry                ; write it
        jmp clipyg


;    ; check for fctn + x
keyx    ci r7,keyFX                 ; fctn & x?
        jne genkey                  ; skip if not
        bl @csroff                  ; restore character currently under cursor
        mov @csry,r0                ; get cursor y
        inc r0                      ; increment it
        mov r0,@csry                ; write it back
        ci r0,16                    ; compare to limit
        jeq clipyh                  ; clip if on limit
        jmp clipyg
clipyh  clr r0                      ; set cursor to the other end
        mov r0,@csry                ; write it
        jmp clipyg


; process general keypress
genkey  bl @needud                  ; mark the block for update
        bl @doins                   ; do insert if insert mode is selected
        li r0,64                    ; buffer pitch
        mov @csry,r1                ; current y
        mpy r0,r1                   ; calculate buffer address
        a @csrx,r2                  ; add x
        mov @epage,r0               ; check page
        jeq gkno                    ; skip if on page 0
        ai r2,30                    ; else account for page offset
gkno    mov r2,r0                   ; move to r0 for vdp address
        a *stack,r0                 ; add vdp buffer address
        mov r7,r1                   ; get keypress
        swpb r1                     ; move to high byte
        bl @_vsbw0                  ; write it into vdp
        bl @csroff                  ; display it
        mov @csrx,r0                ; get x
        inc r0                      ; move to the right
        mov r0,@csrx                ; store it
        mov @xmax,r1                ; get xmax
        ci r1,80                    ; 80 column
        jeq chk80                   ; jump if in 80 column mode
        ci r0,34                    ; need to clip? (40 column mode check)
        jne upkey                   ; jump if not
        jmp gkeycx                  ; else do clip
chk80   ci r0,64                    ; limit for 80 column mode
        jne upkey                   ; jump if clip not required
        clr @csrx                   ; zero x
        mov @csry,r0                ; get y
        inc r0                      ; add 1
        andi r0,15                  ; clip to 16th line
        mov r0,@csry                ; store y again
        jmp upkey                   ; and continue
        ; clip x and change page
gkeycx  clr @csrx                   ; zero x
        inv @epage                  ; change page
        jeq ncos                    ; no cursor offset required if page=0
        li r0,4                     ; cursor position
        mov r0,@csrx                ; set it
ncos    mov @epage,r0               ; get page
        jne ncos1                   ; skip if page=1
incyc   inc @csry                   ; move down to next line
        mov @csry,r0                ; check y
        ci r0,16                    ; need to clip y
        jne ncos1                   ; skip if no need
        dec @csry                   ; else reset to 15th line
ncos1   bl @drawd                   ; draw window and rulers etc
upkey   b *r13



; insert mode
; move everything *on the current line only* forward, from the cursor
doins   mov r11,r10
        mov @temp,r0                ; check insert mode
        jne doinsx                  ; if not 0 then exit
    ; calculate endpoint address in vdp buffer...
        mov @csry,r2                ; get y
        inc r2                      ; move to next line
        sla r2,6                    ; multiply by 64
        dec r2                      ; point to last byte on current line
        a *stack,r2                 ; add in vdp buffer address
    ; calculate startpoint address in vdp buffer...
        mov @csry,r0                ; current line
        sla r0,6                    ; multiply by block line length (64)
        a @csrx,r0                  ; add x
        mov @epage,r1               ; check page
        jeq doins1                  ; skip if page=0
        ai r0,30                    ; else add offset
doins1  a *stack,r0                 ; add in vdp buffer address
        s r0,r2                     ; calculate length
        jeq doinsx                  ; exit if 0
    ; read buffer contents into temporary buffer and write them out again,
    ; forward by 1 character...
        mov @here,r1                ; buffer to store the data in
        mov r0,r9                   ; save address
        mov r2,r8                   ; save length 
        bl @_vmbr                   ; read data into buffer
        mov r9,r0                   ; restore address
        inc r0                      ; move forward 1
        mov r8,r2                   ; restore length
        mov @here,r1                ; source for vdp write
        bl @_vmbw0                  ; write the characters
        mov r7,@temp3               ; save keypress
        bl @rsrc                    ; render source window
        mov @temp3,r7               ; restore keypress for handling by keypress
                                    ; routine
doinsx  b *r10



; set insert/overwrite mode
insovr  mov r11,r7                  ; save return address
        inc @temp                   ; advance to next mode
        c @temp,@modmax             ; compare to maximum allowed value
        jne ins1                    ; if <= to max then ok
        clr @temp                   ; else reset to 0
ins1    bl @xya                     ; set screen address
        data >2200        
        mov @temp,r1                ; get mode
        jne ovr                     ; set insert mode if 1
        bl @wstr                    ; else insert mode 0
        data instxt,6
        b *r7
ovr     bl @wstr                    ; overwrite (1)
        data ovrtxt,6
        b *r7
modmax  data 2



; cursor blinking routines
    ; display cursor character
csron   mov r11,r6
        clr r7
        jmp calcsr                  ; calculate cursor position and display r7
        
    ; restore character under cursor
csroff  mov r11,r6                  ; save return address
        mov @csry,r0                ; cursor y
        sla r0,6                    ; multiply by block line pitch (64)
        a @csrx,r0                  ; add x
        a *stack,r0                 ; add buffer address
        mov @epage,r1               ; check page
        jeq csr1                    ; skip if on page 0
        ai r0,30                    ; else add page offset
csr1    bl @_vsbr                   ; read byte from buffer
        movb r1,r7                  ; save character
calcsr  mov @csry,r0                ; cursor y
        ai r0,3                     ; account for editor window
        mpy @xmax,r0                ; multiply by screen pitch (result in r1)
        mov @csrx,r0                ; get x
        ai r0,3                     ; account for editor window
        a r1,r0                     ; sum to r0 for vdp address
        mov r7,r1                   ; get the character we saved
        bl @_vsbw0                  ; write it
        b *r6                       ; return to caller



; screen handling routines
; draw dynamic parts of the screen
drawd   mov r11,r10                 ; save return address
    ; draw left vertical line
        bl @lftlin
    ; draw right vertical line
        bl @rtlin
    ; draw top ruler
        bl @is80c                   ; 80 column mode?
        jeq ru80c                   ; jump if yes
        bl @xya
        data >0301                  ; get screen address for x=3 y=1
        mov @epage,r1
        jne trul1
        bl @wstr                    ; write string
        data txt0,31                ; source,length
        jmp ednext
trul1   bl @wstr                    ; write string
        data txt1,31                ; source,length
        jmp ednext
    ; render ruler (80 column mode)
ru80c   bl @xya
        data >0301                  ; get screen address for x=3 y=1 
        bl @wstr                    ; write string
        data txt0,30                ; source,length
        bl @xya
        data >2101                  ; get screen address for x=33 y=1 
        bl @wstr                    ; write string
        data txt1,31                ; source,length
        
    ; render block text into editor window
    ; vdp address is on the stack        
ednext  bl @rsrc                    ; render source into window
        b *r10                      ; return to caller


; draw static parts of the screen
draws   mov r11,r10                 ; save return address
    ; write block text
        bl @xya
        data >0000
        bl @wstr
        data blktxt,6
    ; write mode text
        bl @xya
        data >1d00
        bl @wstr
        data modtxt,5
    ; draw 2nd ruler line
        bl @xya
        data >0302                  ; get screen address for x=3 y=2
        bl @wstr                    ; write string
        data txt2,34                ; source,length
        bl @is80c                   ; running 80 column?
        jne lhl                     ; jump if not
        bl @xya
        data >2502                  ; x=37 y=2
        bl @wstr
        data txt2+4,30
    ; draw lower horizontal line
lhl     bl @is80c                   ; in 80 column mode?
        jne lhl1
        bl @xya
        data >0313                  ; x=3 y=19
        bl @hline
        data 1*256,64
        jmp rownum
lhl1    bl @xya
        data >0313                  ; x=3 y=19
        bl @hline
        data 1*256,35
        
    ; place row numbers
rownum  bl @xya
        data >0103                  ; get screen address for x=1 y=3
        li r2,16                    ; count
        li r6,rowtxt                ; source
rl1     movb *r6+,r1                ; get source character
        bl @_vsbw0                  ; write a character
        inc r1                      ; next source character
        a @xmax,r0                  ; move down a line
        dec r2                      ; finished?
        jne rl1                     ; loop if not
        bl @xya
        data >000d                  ; x=0 y=13
        bl @vline
        data '1'*256,6
    
    ; place corner peices
        li r7,4                     ; count
        li r6,cnrdat                ; address of corner data
        bl @is80c                   ; 80 column?
        jne corner                  ; jump if not
        ai r6,8                     ; else point to 80 column data
corner  li r1,4*256                 ; ascii 4 in msb
crnlp   mov *r6+,r0                 ; get address
        bl @_vsbw0                  ; write to screen
        ai r1,>0100                 ; increment ascii character
        dec r7                      ; decrement counter
        jne crnlp                   ; loop if not finished

    ; draw help text
        bl @xya
        data >0014
        bl @wstr
        data help,4*40
        b *r10                      ; return to caller
        
; location data for corner UDGs - 40 column mode
cnrdat  data 2*40+2                 ; top left
        data 2*40+37                ; top right
        data 19*40+2                ; bottom left
        data 19*40+37               ; bottom right

; location data for corner UDGs - 80 column mode
        data 2*80+2                 ; top left
        data 2*80+67                ; top right
        data 19*80+2                ; bottom left
        data 19*80+67               ; bottom right


; render source subroutine 
pitch   equ 35
rsrc    mov r11,r14                 ; save return address
        li r15,pitch                ; load pitch for 40 column mode
        bl @is80c
        jne rsrc_
        li r15,65                   ; load pitch for 80 column mode
rsrc_   bl @xya
        data >0303                  ; screen address
        mov r0,r9                   ; save it
        mov *stack,r6               ; source vdp address
        mov @epage,r8               ; check page
        jeq rsrc1
        ai r6,30                    ; calculate page offset
rsrc1   li r12,16                   ; line count
rloop   mov r6,r0                   ; source
        mov @here,r1                ; destination
        mov r15,r2                  ; count
        dec r2
        bl @_vmbr                   ; read a line
        mov r9,r0                   ; destination address
        mov @here,r1                ; source
        mov r15,r2                  ; count
        dec r2
        bl @_vmbw0                  ; write it
        a @xmax,r9                  ; down a line
        ai r6,64                    ; next line in source
        dec r12                     ; finished?
        jne rloop                   ; loop if not
        b *r14                      ; return


; draw left hand vertical line (dependant on which page we're on)
lftlin  mov r11,r7                  ; save return addressd
        bl @xya
        data >0203                  ; get screen address for x=2 y=3
        mov @epage,r1               ; get page
        jne lft1                    ; do if page=1
        bl @vline
        data 3*256,16
        b *r7
lft1    bl @vline
        data >9c00,16
        b *r7


; draw right hand vertical line (dependant on which page we're on)
rtlin   mov r11,r7                  ; save return address
        bl @is80c                   ; 80 column?
        jeq rt2
        bl @xya
        data >2503                  ; get screen address for x=37 y=3
        mov @epage,r1               ; get page
        jne rt1                     ; do if page=1
        bl @vline
        data >9e00,16
        b *r7                       ; return
rt1     bl @vline
        data 3*256,16
        b *r7                       ; return
rt2     bl @xya                     ; 80 column mode only: place vertical bar on
                                    ; rhs of screen
        data >4303
        jmp rt1


; calculate screen address from XY coordinates
xya     mov *r11+,r0                ; get xy
        mov r0,r1                   ; copy
        sla r1,8                    ; get y (move x out)
        sra r1,8                    ; adjust to correct position
        sra r0,8                    ; get x (move y out)
        mpy @xmax,r1                ; do y multiply (result in r2)
        a r2,r0                     ; screen address in r0
        .rt


; draw a vertical line subroutine
; r0=screen address
; character and length follow as DATA directives in caller code
vline   mov *r11+,r1
        mov *r11+,r2
        mov r11,r6
vline1  bl @_vsbw0
        a @xmax,r0
        dec r2
        jne vline1
        b *r6


; draw a horizontal line subroutine
; r0=screen address
; character and length follow as DATA directives in caller code
hline   mov *r11+,r1
        mov *r11+,r2
        mov r11,r6
        bl @vsbwmi
        b *r6


; write string subroutine
; r0=screen address
; source and length follow as DATA directives in caller code
wstr    mov *r11+,r1                ; source
        mov *r11+,r2                ; count
        mov r11,r6                  ; return address
        bl @_vmbw0                  ; write the string
        b *r6                       ; return




; scan keyboard
scnkey  movb @keybd,@>8374          ; set keyboard to scan
        lwpi >83e0                  ; use gpl workspace
        bl @>000e                   ; call keyboard scanning routine
    ; ########## added for V1.2 ###########
        ; restore TF workspace
        ; load a program into r0,r1,r2 & r3 as follows:
        ; R0=LWPI
        ; R1=<address of workspace (argument to LWPI instruction>
        ; R2=BRANCH
        ; R3=<branch address>
    ; ########## added for V1.2 ###########
        li r0,>02e0     ; lwpi instruction
        mov @wp,r1      ; lwpi operand
        li r2,>0460     ; branch opcode
        li r3,scnky1    ; operand for branch instruction
        b r0            ; execute the code in workspace memory
scnky1  clr r7
        movb @keyin,r7              ; a new key was pressed: get ascii code
        sra r7,8                    ; move to low byte
        .rt                          ; return to caller
keybd   data >0500                  ; all keys



; miscellaneous routines
; delay routine
delay   mov *r11+,r0
dlylop  dec r0
        jne dlylop                  ; Dave Westwood would be proud
        .rt


; define cursor characters and corner edges etc
csrdef  mov r11,r6                  ; save return address
        li r0,>800                  ; ascii 1 address
        li r1,ascii0                ; source
        li r2,8*8
        bl @_vmbw0
        b *r6


; set block status to dirty
needud  mov r11,r6
        mov @lstblk,r0              ; get current block
        bl @scnblk                  ; locate it (blk address in r1)
        inct r1                     ; point to VDP address pointer
        mov *r1,r0                  ; get the VDP address
        jlt skipud                  ; skip if already set
        ori r0,>8000                ; set dirty bit
        mov r0,*r1                  ; write it back
disupd  li r0,12                    ; screen address
        li r1,cngtxt                ; address of changed text
        li r2,7                     ; count
        bl @_vmbw0                  ; write it
skipud  b *r6



; check if 80 column mode is on or not...
is80c   mov @xmax,r0    ; get xmax
        ci r0,80        ; compare to 80 (80-column)
        .rt


txt0    text '0         1         2         3'
txt1    text '3         4         5         6'
txt2    byte 1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,2,1,1,1,1,1
        byte 1,1,1

rowtxt  text '0123456789012345'
blktxt  text 'Block '
modtxt  text 'Mode:'
instxt  text 'INSERT'
ovrtxt  text 'OVER  '
cngtxt  text 'CHANGED '

ascii0  byte >fc,>fc,>fc,>fc,>fc,>fc,>fc,0      ; solid cursor character
ascii1  byte 0,0,0,255,255,0,0,0                ; straight line
ascii2  byte 16,16,16,255,255,0,0,0             ; straight line with marker
ascii3  byte >30,>30,>30,>30,>30,>30,>30,>30    ; vertical line
ascii4  byte 0,0,0,>3f,>3f,>30,>30,>30          ; top left corner
ascii5  byte 0,0,0,>f0,>f0,>30,>30,>30          ; top right corner
ascii6  byte >30,>30,>30,>3f,>3f,0,0,0          ; bottom left corner
ascii7  byte >30,>30,>30,>f0,>f0,0,0,0          ; bottom right corner

help    text 'F1:Delete F2:Mode F3:Erase Line  F7:Page'
        text 'F9:Exit F=:Quit ESDX:Cursor ENT:New Line'
        text '^C:Copy Line  ^V:Paste Line  ^I:Ins Line'
        text '^D:Del Line ^O:Prev Block  ^P:Next block'
        even

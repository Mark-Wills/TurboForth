;   _____                       _       __          __            _     
;  / ____|                     | |      \ \        / /           | |    
; | |      ___  _ __  ___  ___ | | ___   \ \  /\  / /___  _ __ __| |___ 
; | |     / _ \| '_ \/ __|/ _ \| |/ _ \   \ \/  \/ // _ \| '__/ _` / __|
; | |____| (_) | | | \__ \ (_) | |  __/    \  /\  /| (_) | | | (_| \__ \
;  \_____|\___/|_| |_|___/\___/|_|\___|     \/  \/  \___/|_|  \__,_|___/
;  Console IO words

;[ BREAK? ( -- )
; scans keyboard and does an ABORT if break (FCTN 4) is pressed
breakh  data dfah,6
        text 'BREAK?'
break   data docol,keyq,lit,2,eq,zbrnch,break1
        data cr,toterm,brkmsg,cr,ab0rt
break1  data exit
brkmsg  byte 5 ; length of text 
        text 'Break '
;]

;[ GOTOXY ( x y -- )
; sets the screen cursor to the specified (0 based) x y screen coordinates
goxyh   data breakh,6
        text 'GOTOXY'
gotoxy  data $+2
        mov *stack+,@scry           ; pop y
        mov *stack+,@scrx           ; pop x
        b *next
;]

;[ TYPE         addr +n --                    M,79                 
; +n characters are displayed from memory beginning with the character at addr 
; and continuing through consecutive addresses.  
; Nothing is displayed if +n is zero.  
; See: "9.5.4 TYPE"
typeh   data goxyh,4
        text 'TYPE'
type    data $+2
type1   mov *stack+,r13             ; pop length in r13
        mov *stack+,r10             ; address in r10
        mov r13,r13                 ; check the length 
        jle typout                  ; if 0 or negative then exit
typlp   movb *r10+,r7               ; get byte from string in r7 MSB
        swpb r7                     ; rotate MSB into LSB
        dect stack                  ; create space on stack
        mov r7,*stack               ; place on stack
        bl @emit_                   ; call emit
        dec r13                     ; have we finished?
        jne typlp                   ; if not, repeat
typout  b *next
;]

;[ WORDS ( -- )
; displays a list of all the words in the dictionary
wordsh  data typeh,5
        text 'WORDS '
words_  data docol
        data cr,lit0,lates_
words1  data fetch,dup,zbrnch,words2
        data dup,plus2,dup,fetch,lit,15,and
        data swap,plus2,swap,type
words3  data break
words4  data keyq,lit,>ffff,eq,zbrnch,words4
        data space1,swap,plus1,swap
        data branch,words1
words2  data drop,cr,dot
        data toterm,wftxt
        data exit
wftxt   byte 6
        text 'Words '
;]

;[ XY? ( -- x y )
; places the cursor x and y coordinates on the stack
xyh     data wordsh,3
        text 'XY? '
xy      data $+2
        dect stack                  ; new stack entry
        mov @scrX,*stack            ; push scrX to stack
        dect stack                  ; new stack entry
        mov @scrY,*stack            ; push scrY to stack
        b *next
;]

;[ SPACE        --                            M,79                 
; Displays an ASCII space.
spaceh  data xyh,5
        text 'SPACE '
space1  data $+2
        dect stack                  ; new stack entry
        li r0,32                    ; space character
        mov r0,*stack               ; push it to stack
        bl @emit_                   ; call emit
        b *next
;]

;[ SPACES       +n --                         M,79                 
; Displays +n ASCII spaces.  Nothing is displayed if +n is zero.
spcesh  data spaceh,6
        text 'SPACES'
spces   data $+2
        mov *stack+,r7              ; pop count in r7
        mov r7,r7                   ; check for 0
        jeq spcesx                  ; if zero, just quit
        abs r7                      ; make positive if negative
spces1  dect stack                  ; create stack entry
        li r8,32                    ; space character
        mov r8,*stack               ; put space on stack
        bl @emit_                   ; display the space via emit
        dec r7                      ; decrement count
        jne spces1                  ; repeat if not finished
spcesx  b *next
;]

;[ PAGE ( -- )
; clears screen
clsh    data spcesh,4
        text 'PAGE'
cls     data $+2        
        bl @bank1
        data _cls                   ; see 1-02-Console.a99
;]

;[ JOYST ( joystick# -- value )
; Scans the joystick returning the direction value
joysth  data clsh,5
        text 'JOYST '
joyst   data $+2
        bl @bank1                   ; see 1-02-Console.a99
        data _joyst
;]

;[ EMIT         16b --                        M,83                 
; The least-significant 8-bit ASCII character is displayed. SEE:  "9.5.3 EMIT"
emith   data joysth,4
        text 'EMIT'
emit    data $+2
    ; EMIT as called from the Forth environment:
        bl @emit_                   ; call emit routine (see below)
        b *next
        
    ; emit as an internal assembly sub-routine (used by SPACE, SPACES & TYPE):
emit_   
        mov r11,r9                  ; save return address
        bl @ccp                     ; compute cursor position (loaded into r0)
        mov *stack+,r1              ; pop character
        swpb r1                     ; get byte in msb
        bl @vsbw                    ; write char to screen at computed position
        inc @scrX                   ; increment x postion of cursor
        c @scrx,@xmax               ; have we hit the right-most column?
        jeq clipx                   ; if yes, reset x
        b *r9                       ; else return
clipx   clr @scrX                   ; reset x to 0
        inc @scrY                   ; increment y
        c @scrY,@ymax               ; have we hit the bottom of the screen?
        jeq scrlup                  ; if yes then scroll screen up
emitx   b *r9                       ; else return
;]

;[ KEY          -- 16b                        M,83                 
; The least-significant 7 bits of 16b is the next ASCII character received.  
; All valid ASCII characters can be received.
; Control characters are not processed by the system for any editing purpose.
; Characters received by KEY will not be displayed.  
; See:  "9.5.1 KEY"
nokey   equ >ff00                   ; keycode for no key pressed
delkey  equ 3                       ; keycode for delete key

kscnh   data emith,3
        text 'KEY '
key     data $+2
        clr @cursrd
        bl @kscn                    ; call key scan routine
        b *next                     ; NEXT
    ; keyscan has been split from the forth word KEY. 
    ; this allows it to be called both as a forth word (KEY) and as a machine 
    ; code routine.
kscn    mov r11,r8                  ; save return address
kscn1   bl @cflash                  ; call cursor flash routine
        movb @keydev,@>8374         ; set keyboard to scan
        lwpi >83e0                  ; use gpl workspace
        bl @>000e                   ; call keyboard scanning routine
    ; restore the turboforth workspace
    ; TFs workspace is held in 'wp'. This routine writes a program in the GPL 
    ; workspace  starting at R0 which performs an LWPI instruction, and then 
    ; jumps the remainder of this keyscan routine below.
    ;
    li r0,>02e0     ; lwpi instruction
    mov @wp,r1      ; lwpi operand
    li r2,>0460     ; branch opcode
    li r3,kscn2     ; operand for branch instruction
    b r0
kscn2   movb @gplst,r7              ; get GPL STATUS byte in r7 MSB
        sla r7,3                    ; shift COND bit into carry bit
        jnc kscn1                   ; no key pressed, or same key pressed as 
                                    ; previous scan. ignore and re-scan.
        movb @keyin,r7              ; a new key was pressed: get ascii code in 
                                    ; r7 msb
        ci r7,nokey                 ; compare against 'no key pressed' code
        jeq kscn1                   ; no key was pressed
        srl r7,8                    ; a key was pressed. move to low byte
        dect stack                  ; new stack entry
        mov r7,*stack               ; place ascii code onto stack
        b *r8                       ; return to caller

    ; cursor flashing
cflash  mov @bank0,@retbnk          ; return to bank 0
        limi 2                      ; service isr
        limi 0
        mov r11,r6                  ; save return address
        li r7,>2000                 ; load space & ascii 0 characters for cursor
        mov @cursrd,r0              ; get cursor delay
        ai r0,>80                   ; increment
        mov r0,@cursrd              ; save it
        jeq csrwrt                  ; if zero, write a blank cursor character
        swpb r7                     ; load _ cursor character
        ci r0,>8000                 ; cursror delay = >8000?
        jeq csrwrt                  ; if yes, write an _ cursor character
        b *r6                       ; if neither, just return
csrwrt  bl @ccp                     ; call compute cursor position
        mov r7,r1                   ; move cursor character to r1 for VSBW
        bl @vsbw                    ; write the cursror character to the screen
        b *r6                       ; return to caller
;]

;[ KEY? ( -- ascii/-1 )
; Scans keyboard and returns the ascii code of the key pressed, 
; or -1 if no key pressed
keyqh   data kscnh,4
        text 'KEY?'
keyq    data $+2
        bl @keyqsr                  ; call as subroutine 
        b *next                     
keyqsr  movb @keydev,@>8374         ; set keyboard to scan
        lwpi >83e0                  ; use gpl workspace
        bl @>000e                   ; call keyboard scanning routine
        lwpi wkspc                  ; restore to our workspace
        movb @keyin,r7              ; a new key was pressed: get ascii code in r7 msb
        sra r7,8                    ; move to low byte
        dect stack                  ; make space on stack
        mov r7,*stack               ; place value on stack
        mov r12,@>83d6              ; defeat auto screen blanking
        .rt                         ; return to caller
;]

;[ CR           --                            M,79            "c-r" 
; Displays a carriage-return and line-feed or equivalent operation.
crh     data keyqh,2
        text 'CR'
cr      data $+2
        mov next,r9             ; return address if we take the jump to scrlup
        clr @scrx                   ; clear cursor x coordinate
        inc @scry                   ; move to next screen row
        c @scry,@ymax               ; have we hit the bottom of the screen?
        jeq scrlup                  ; if yes, then scroll the screen
crexit  b *next                     ; NEXT
;]

; Scroll screen up by one line. Used by EMIT and CR to scroll the screen up if
; necessary (sub-routine, not a FORTH word).
scrlup  mov @noscrl,r8              ; test NOSCROLL
        jeq scrlno                  ; scrolling is supressed
        dec @scrY                   ; clip y coordinate to 23
        mov @here,r8
        ai r8,4
        li r6,23                    ; 23 lines to shift
        clr r0                      ; screen address
sclup_  a @xmax,r0                  ; move down one line
        mov r8,r1                   ; address of buffer to store in
        mov @xmax,r2                ; number of bytes to store in the screen 
                                    ; line buffer
        bl @vmbr                    ; read screen data into buffer
        neg @xmax                   ; set x negative
        a @xmax,r0                  ; move up one line
        neg @xmax                   ; restore x to positive
        mov @xmax,r2                ; number of bytes to write
        mov r8,r1                   ; address of screen buffer
        bl @vmbw                    ; write buffer to screen
        a @xmax,r0                  ; move down a line
        dec r6                      ; decrement number of lines left to shift
        jne sclup_                  ; repeat if not finished
        mov @here,r2
        ai r2,4
        mov @xmax,r6                ; screen width
        li r1,>2020                 ; two space characters
blnkln  mov r1,*r2+                 ; write two spaces to the buffer
        dect r6                     ; decrement character count
        jne blnkln                  ; loop if not finished
        mov @here,r1
        ai r1,4
        mov @xmax,r2                ; number of bytes to write in r2
        bl @vmbw                    ; write blank line        
        b *r9                       ; return
scrlno  clr @scrY                   ; scrolling is supressed, so zero Y
        clr @scrX                   ; and x
        b *r9                       ; and return
        
; compute cursor position. common utility routine.
; used by EMIT and the cursor flash routine in KEY
ccp     mov @scry,r0                ; y coordinate of screen in r0
        mov @xmax,r1                ; horizontal screen size in r1
        mpy r0,r1                   ; multiply y by horizontal screen size. 
                                    ; result in r2
        mov r2,r0                   ; move to r0 for vdp access routines
        a @scrX,r0                  ; add x coordinate
        .rt

;[ BYE ( -- )
; resets the console back to the title screen
byeh    data crh,3
        text 'BYE '
bye     data $+2
        clr @isr                    ; remove isr hook
        blwp @0                     ; cold reset console. So long, old pal.
;]

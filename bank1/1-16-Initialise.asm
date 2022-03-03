;  _____       _ _   _       _ _           _   _
; |_   _|     (_) | (_)     | (_)         | | (_)
;   | |  _ __  _| |_ _  __ _| |_ ___  __ _| |_ _  ___  _ __
;   | | | '_ \| | __| |/ _` | | / __|/ _` | __| |/ _ \| '_ \
;  _| |_| | | | | |_| | (_| | | \__ \ (_| | |_| | (_) | | | |
; |_____|_| |_|_|\__|_|\__,_|_|_|___/\__,_|\__|_|\___/|_| |_|
; this code runs at startup to bring TurboForth to life

; general initialisation of RAM variables etc

init

        mov @sumode,r3              ; save graphics startup mode value

        li r0,>0190                 ; turn the screen off while we set things up
        bl @_vwtr


;[ initialise SAMS card if fitted
        li r12,>1e00                ; sams CRU base
        sbo 0                       ; enable access to mapper registers
        sbz 1                       ; disable mapping while we set it up
        li r0,>4004                 ; register for >2000
        li r1,>f8f8                 ; map bank >f8 into >2000
        mov r1,*r0+                 ; do it
        li r1,>f9f9                 ; map bank >f9...
        mov r1,*r0+                 ; ...into >3000
    ; now set up the banks for high memory...
        li r0,>4014                 ; register address
        li r1,>fafa                 ; register value
        li r2,6                     ; loop count
sams    mov r1,*r0+                 ; write to the register
        ai r1,>0101                 ; next register value
        dec r2                      ; finished?
        jne sams                    ; loop if not
        sbo 1                       ; enable mapping
        sbz 0                       ; lock the mapper registers
;]

;[ clear variables area
cva     li r0,>a000                 ; start address
        li r1,prgtop                ; end address
clrlop  clr *r0+                    ; clear a word
        c r0,r1                     ; finished?
        jne clrlop                  ; repeat if not
;]

        mov r3,@sumode              ; restore start up graphics mode
        mov @>83c0,@seed            ; initialise random number seed

;[ set up boot file name (DSK1.BLOCKS)
        li r0,bootfn                ; address of boot filename
        li r1,pabnln                ; destination
        li r2,12                    ; 12 bytes to copy
bootlp  movb *r0+,*r1+              ; copy a byte
        dec r2                      ; finished?
        jne bootlp                  ; repeat if not
;]

;[ initialise console stuff
        li r0,cursrd                ; address of cursor delay
        clr *r0+                    ; initialise cursor delay
        seto *r0+                   ; enable screen scrolling
        clr *r0+                    ; zero current x coordinate
        clr *r0+                    ; zero current y coordinate

    ; initialise vdp environment
    ; disable interrupts, sound and sprites...
    ;    li r0,>8000                 ; no sprite motion
    ;                                ; no auto sound
    ;                                ; no quit key
    ;    mov r0,@>83c2               ; see page 4 smart programmer
    ;                                ; oct 86-vol 2 issue 5
    ; note: this has now been moved into the intialisation list, below.
;]

;[ load character sets...
chrset
    ; initialise control characters to something visible
    ; we do this by writing the TF logo to ALL 256 characters
    ; later we define the capital and lower case character sets.
cclop   li r0,>800                  ; address of ascii 0
        li r7,123                   ; number of characters to write
cclop1  li r1,logo                  ; source (TF logo character)
        li r2,8                     ; bytes to copy
        bl @_vmbw0                  ; write them
        ai r0,8                     ; next character
        dec r7                      ; decrement count
        jne cclop1                  ; loop if not finished

    ; load small ascii character set
        li r0,>08ff                 ; vdp address of upper case A
        mov r0,@fac                 ; vdp address for small capitals
        blwp @gpllnk                ; load small capitals character set
        data >0018                  ; gpl command code

    ; load true lower case characters
        li r0,>b08                  ; vdp address of lower case a
        li r1,lowcas                ; source
        li r2,26*8                  ; count
        bl @_vmbw0                  ; write true lower case char set


    ; load miscellaneous characters from data list
        li r1,lbrace                ; address of list
lmiscl  clr r0
        movb *r1+,r0                ; get ascii code
        jeq doinv                   ; exit if end of list
        srl r0,5                    ; move to low byte and multiply by 8
        ai r0,>800                  ; add pattern table base address
        li r2,8                     ; number of bytes to write
        bl @_vmbw0                  ; write to vdp
        jmp lmiscl


    ; initialise inverse characters
    ; ascii codes 144 to 218 are inverse of 48 to 122
doinv   li r13,>900                 ; vdp source
        li r6,>c00                  ; vdp destination
        li r14,728                  ; count
invlop  mov r13,r0                  ; get source address in r0 for VDP ops
        bl @_vsbr                   ; go read the vdp data (result in R1)
        inv r1                      ; invert it
        mov r6,r0                   ; load destination address
        bl @_vsbw0                  ; write r1 to destination address
        inc r13                     ; advance source address
        inc r6                      ; advance destination address
        dec r14                     ; decrement counter
        jne invlop                  ; loop until finished

        bl @csrdef                  ; define cursor and edge characters
                                    ; (see 1-11-Editor.a99)
;]

;[ Copy PAD routines into PAD RAM
cpypad  bl @rstsp                   ; use the restore routine in 1-06-Blocks.a99
;]

;[ general initialisation - initialised from an address/data list
        li r0,adrlst                ; pointer to address/data table
        li r2,41                    ; number of items to load
nxtdat  mov *r0+,r1                 ; get address to load
        mov *r0+,*r1                ; load the address with data
        dec r2                      ; finished?
        jne nxtdat                  ; loop if not
;]

;[ set up data and return stacks...
        li stack,dstack             ; data stack pointer
        li rstack,retstk            ; return stack pointer

        clr @spcsvc                 ; clear speech service routine pointer

        li r12,afteri               ; force return point in bank 0
        b @retB0                    ; return to caller in bank 0
;]

;[ initialisation data
adrlst
        data base, 10             ; default number base
        data keydev, 50           ; default keyboard scan code
        data ymax, 24             ; 24 rows
        data latest, lastwd       ; last word in the dictionary
        data here, prgtop         ; start of compiled code area
        data s0, dstack           ; start of data stack
        data rs0, retstk          ; start of return stack
        data ffailm, >2000        ; first free address in low memory
        data ffaihm, himem        ; first free address in high memory
        data >fffc, wkspc         ; pointer to workspace for load-interrupt
        data >fffe, startB0       ; pointer to start of code for load-interrupt
        data retbnk, >6002        ; return to bank 1
        data tibsiz, 80           ; 80 characters input buffer length
        data tibadr, tib          ; location of input buffer
                                  ; (defined in 0-23-System.a99)
        data doboot, 1            ; booting flag (default:on)
        data sdelim, '"'*256      ; default string delimiter character
        data totblk, blocks       ; default number of block buffers available
        data intvec, intgo        ; default vector for interpret
        data blkvec, block2       ; default vector for block
        data numvec, numbr1       ; default vector for number
        data fndvec, vfind        ; default vector for find
        data falloc, f1pab        ; address of pab for 1st file
        data falloc+2, f2pab      ; address of pab for 2nd file
        data falloc+4, f3pab      ; address of pab for 3rd file
        data gplvec, gpllnk       ; pointer to gpllnk
        data padvec, rstsp        ; pointer to scratchpad code in bank 1
        data _WARN, -1            ; default value for warn
        data isr, runisr          ; pointer to isr launcher in pad
        data wp, >8300            ; initial workspace pointer
        data pnext, _next         ; address of next
        data dsrvec, dsrlnk       ; load pointer to DSRLNK vector
        data pdocon, docon        ; load pointer to DOCON's executable code
        data pcreate, crtime      ; load pointer to CREATE's executable code
        data kdel, >ed1e          ; auto-repeat delay for block editor
    ; VDP block buffer addresses for disk block IO...
        data blk0+2, bufadd+>1400 ; vdp address of buffer 0
        data blk0+6, bufadd+>1000 ; vdp address of buffer 1
        data blk0+10,bufadd+>c00  ; vdp address of buffer 2
        data blk0+14,bufadd+>800  ; vdp address of buffer 3
        data blk0+18,bufadd+>400  ; vdp address of buffer 4
        data blk0+22,bufadd       ; vdp address of buffer 5
        data >83c2, 0             ; ISR mask (everything off)

    ; boot filename - system looks for this file on startup and attempts to load
    ; from block 1 if found. holding any key supresses this behaviour ala XB.
bootfn  byte 11 ; length
        text 'DSK1.BLOCKS'        ; file to boot from
        even

lowcas
    ; funnelweb editor lower case font:
        data >0000,>3808,>7848,>7c00
        data >4040,>7844,>4444,>7800
        data >0000,>3844,>4040,>3c00
        data >0404,>3c44,>4444,>3c00
        data >0000,>3844,>7c40,>3c00
        data >1c20,>7820,>2020,>2000
        data >0000,>3c44,>443c,>0438
        data >4040,>7844,>4444,>4400
        data >1000,>3010,>1010,>3800
        data >0800,>1808,>0808,>4830
        data >2020,>2428,>3028,>2400
        data >3010,>1010,>1010,>3800
        data >0000,>7854,>5454,>5400
        data >0000,>7844,>4444,>4400
        data >0000,>3844,>4444,>3800
        data >0000,>7844,>4478,>4040
        data >0000,>3c44,>443c,>0404
        data >0000,>5c60,>4040,>4000
        data >0000,>3c40,>3804,>7800
        data >0020,>7820,>2024,>1800
        data >0000,>4444,>4444,>3c00
        data >0000,>4444,>2828,>1000
        data >0000,>4444,>5454,>2800
        data >0000,>4428,>1028,>4400
        data >0000,>4424,>1808,>1020
        data >0000,>7c08,>1020,>7c00

logo    data >00e0,>405c,>5018,>1000    ; represents control characters

        ; left curly brace  (123) {
lbrace  byte '{'
        byte >18,>20,>20,>40,>20,>20,>18,>00

        ; bar character     (124) |
        byte '|'
        byte >10,>10,>10,>00,>10,>10,>10,>00

        ; right curly brace (125) }
        byte '}'
        byte >30,>08,>08,>04,>08,>08,>30,>00

        ; tilde             (126) ~
        byte '~'
        byte >00,>00,>20,>54,>08,>00,>00,>00

        ; slashed zero
        byte '0'
zerochr byte >38,>4c,>54,>54,>54,>64,>38,>00

        ; circular O
        byte 'O'
ochar   byte >38,>44,>44,>44,>44,>44,>38,>00
        byte 0 ; end of list
        even
;]

;[ GPLLNK
; This routine is based on the routine published in the July 1986 edition of
; Smart Programmer. Modified by yours truly to allow it be executed from ROM.
gplws   equ >83e0                   ; GPL workspace
gr4     equ gplws+8                 ; GPL R4
gr6     equ gplws+12                ; GPL R6
stkpnt  equ >8373                   ; GPL stack pointer
ldgadd  equ >60                     ; load and execute grom address entry point
xtab27  equ >200e                   ; low mem XML table location 27
getstk  equ >166c

; cpu register data - this data is copied into >200e onwards, so that it sits
; in R7 onwards
gpllnk  data glnkws                 ; [mapped to R7] set up BLWP vectors
        data glink1                 ; [mapped to R8]
rtnad   data xmlrtn                 ; [mapped to R9]
gxmlad  data >176c                  ; [mapped to R10] GROM address for GPL XML 0F27
                                    ; opcode
        data >50                    ; [mapped to R11] Initialised to >50 where
                                    ; PUTSTK address resides

; this routine runs in it's own workspace, starting at >2000
glnkws  equ >2000                   ; GPLLNKs workspace of which only registers
                                    ; R7 thru R15 are used

glink1  li r0,gpllnk                ; we need to copy the cpu register data
        li r1,>200e                 ; (above) to RAM. R0=Source, R1=Destination
gpllop  mov *r0+,*r1+               ; copy the data above into r7
        mov *r0+,*r1+               ; copy the data above into r8
        mov *r0+,*r1+               ; copy the data above into r9
        mov *r0+,*r1+               ; copy the data above into r10
        mov *r0+,*r1+               ; copy the data above into r11
        mov *r11,@gr4               ; put PUTSTK address into R4 of GPL WS
        mov *r14+,@gr6              ; put GPL routine address in r6 of GPL WS
        mov r9,@xtab27              ; put XMLRTN address into >200e
        lwpi gplws                  ; load GPL workspace
        bl *r4                      ; save current GROM address on stack
        mov @gxmlad,@>8302(r4)      ; push GPL XML address on stack for GPL ret
        inct @stkpnt                ; adjust the stack pointer
        b @ldgadd                   ; execute our GPL routine
xmlrtn  mov @getstk,r4              ; get GETSTK pointer
        bl *r4                      ; restore GROM address off the stack
        lwpi glnkws                 ; load our ws
        rtwp                        ; all done - return to caller
;]

;[ Check boot device routine
; this routine is called from 0-01-Startup.a99 to modify the disk boot device
; from DSK1 to DSKx where x is the ascii character of the key held down during
; cartridge boot-up
_cboot  mov *stack,r0               ; get key-code from the stack
        ci r0,13                    ; enter pressed?
        jne cboot1                  ; jump if not
        clr *stack                  ; enter was pressed. zero top of stack to
                                    ; supress auto loading.
        jmp cbootx                  ; return
cboot1  ci r0,-1                    ; nothing pressed?
        jeq cbootx                  ; if nothing pressed then exit routine
        sla r0,8                    ; otherwise move key code move to high byte
        movb r0,@pabfil+3           ; place the digit in cpu PAB
cbootx  b @retB0
;]

;[
; ***************************************************
; The following routines are copied to PAD on startup
; ***************************************************
;DOCOL
; Executes a high-level colon definition.
; Saves return address on the return stack, loads new execution thread and
; drops down into NEXT to begin executing the thread.
; Note: These three routines are actually copied to scratchpad ram for extra
; speed. See the equates below for their addresses in PAD

docol   equ >8320                   ; address of this routine in PAD
toRAM   dect rstack                 ; make space on return stack
        mov pc,*rstack              ; save PC to return stack
        mov r6,pc                   ; place in PC and drop down to NEXT

;NEXT
; loads the next CFA and branches to the address in the CFA.
_next   equ docol+6                 ; 8326 address of this routine in PAD
        mov *pc+,r6                 ; get CFA in r6
        mov *r6+,r7                 ; get contents of CFA
        b *r7                       ; execute it

;EXIT
; exits from a FORTH high level word (i.e. a word entered with DOCOL)
exit    equ _next+6                 ; 832c address of this routine in PAD
        data exit+2                 ; called by NEXT, so needs a pointer
        mov *rstack+,pc             ; place saved PC into PC & pop return stack
        b *next                     ; do next instruction

;BANK1
; routine to perform a bank switch and branch
bank1   equ exit+6                  ; 8332 address of this routine in PAD
        mov *r11,r11                ; get branch address
        clr @>6000                  ; select bank 1
        b *r11                      ; branch to the desired address

;RETB0
; routine to return to a calling routine in bank 0
retB0   equ bank1+8                 ; 833a address of this routine in PAD
cpypnt  clr @>6002                  ; select bank 0
        b *next


; speech synth status routine
spstat  equ retB0+6
        movb @spchrd,@spdata        ; 8340 move data from synth to memory
        src r0,12                   ; wait 12uS - see editor assembler page 349,
                                    ; paragraph 5.
        .rt
; the speech synth status will be placed into the following memory location:
spdata  equ spstat+10
        .nop                         ; 834a dummy space for spdata

; routine to call the ISRs in bank1 (actually located 'in' FAC)
runisr  equ spdata+2
        clr @>6000                  ; 834c select bank 1
        b @isrdes                   ; jump to ISR despatch handler in bank 1

; ISR return code - select appropriate bank and resume
isrxit  equ runisr+8
        mov @retbnk,r0              ; 8354 get bank to return to
        clr *r0                     ; select that bank
        b *r10                      ; return to console ISR routine in console
                                    ; ROM

; SWAP - runs from high-speed RAM
_swap   equ isrxit+8
        mov *stack,r7               ; 835c save TOS
        mov @2(stack),*stack        ; move TOS-1 to TOS
        mov r7,@2(stack)            ; move previous TOS to TOS-1
        b *next                     ;

; LIT - runs from high-speed RAM
_lit    equ _swap+12
        dect stack                  ; 8368 create space on the data stack
        mov *pc+,*stack             ; push in-line number to data stack
        b *next

; DUP - runs from high-speed RAM
_dup    equ _lit+26 ; >8382         ; (jump over TI reserved PAD locations)
__dup   dect stack                  ; 8382 create stack entry
        mov @2(stack),*stack        ; mov word @ TOS+1 to TOS
        b *next                     ;

; DROP - runs from high-speed RAM
_drop   equ _dup+8 ; >8388
        inct stack                  ; 8388 pop stack
        b *next                     ; return

; OVER - runs from high-speed RAM
_over   equ _drop+4 ; >838c
        dect stack                  ; 838c move forward one stack position
        mov @4(stack),*stack        ; copy x1 to TOS
        b *next                     ;

; 1+ - runs from high-speed RAM
_plus1  equ _over+8 ; >8394
        inc *stack                  ; 8394 increment contents of data stack by 1
        b *next                     ;

; 2+ - runs from high-speed RAM
_plus2  equ _plus1+4 ;
        inct *stack                 ; 839c increment contents of data stack by 2
        b *next                     ;

; 2- - runs from high-speed RAM
_sub2   equ _plus2+4 ;
        dect *stack                 ; 83a0 decrement contents of data stack by 2
        b *next                     ;

; + - runs from high-speed RAM
_add    equ _sub2+4 ;
        a *stack+,*stack            ; 83a4 pop tos and add to datastack-1
        b *next                     ;

; - - runs from high-speed RAM
_sub    equ _add+4 ;
        s *stack+,*stack            ; 83a8 pop tos and subtract from datastack-1
        b *next                     ;

; * - runs from high-speed RAM
_mul    equ _sub+4 ;
        mov @2(stack),r8            ; 83ac word under TOS into r8
        mpy *stack+,r8              ; pop tos and multiply by r8
                                    ; (lsw of result in r9)
        mov r9,*stack               ; place result onto data stack
        b *next

; 0BRANCH
_zbrnch equ _mul+10
        ; at entry, R3 is pointing at the branch address...
        mov *stack+,r0              ; 83b6 test and pop flag
        jne zbq                     ; if NOT zero, remove from stack and quit
        mov *pc,pc                  ; stack was zero, we're taking the jump...
                                    ; move address to instruction pointer
        b *next
zbq     inct pc                     ; otherwise move past address
        b *next
padend                              ; end of secod source block
                                    ; end of copy to PAD section
;]

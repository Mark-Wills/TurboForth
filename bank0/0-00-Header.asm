;  _____            _           _____           _   _     
; |_   _|_   _ _ __| |__   ___ |  ___|___  _ __| |_| |__  
;   | | | | | | '__| '_ \ / _ \| |_  / _ \| '__| __| '_ \ 
;   | | | |_| | |  | |_) | (_) |  _|| (_) | |  | |_| | | |
;   |_|  \__,_|_|  |_.__/ \___/|_|   \___/|_|   \__|_| |_|
; ################################################
; TurboForth
; (C) Mark Wills 2009-2012
; Written in TMS9900 machine code for the TI-99/4A
; May the Forth be with you.
; ################################################
;  ____              _       ___  
; | __ )  __ _ _ __ | | __  / _ \ 
; |  _ \ / _` | '_ \| |/ / | | | |
; | |_) | (_| | | | |   <  | |_| |
; |____/ \__,_|_| |_|_|\_\  \___/ 
;
; This is bank 0 - the main bank, containing:
;    Forth dictionary
;    Any words written in Forth
;    Console routines (keyboard, scrolling, cursor etc)
;
;    Due to memory contraints, some dictionary entries are stub entries
;    containing only the dictionary entry and a call into bank 1 where the
;    main code resides. I have tried to keep routines that need to run quickly
;    (i.e. without the overhead of a bank-switch/branch and bank-switch/return
;    in this bank.

;  _    _                _           
; | |  | |              | |          
; | |__| | ___  __ _  __| | ___ _ __ 
; |  __  |/ _ \/ _` |/ _` |/ _ \ '__|
; | |  | |  __/ (_| | (_| |  __/ |   
; |_|  |_|\___|\__,_|\__,_|\___|_|   

        aorg >6000                  ; cartridge rom
        
    ; cartridge ROM header
        
        byte >aa                    ; standard header
        byte >0c                    ; version number
        byte >01                    ; number of programs
        byte >00                    ; not used
        data >0000                  ; pointer to power-up list
        data menu                   ; pointer to program list
        data 0                      ; pointer to DSRL list
        data 0                      ; pointer to subprogram list
        
menu    data menu40                 ; pointer to next menu item
        data start80                ; code entry point 
        byte 20                     ; length of text
        text 'TURBOFORTH 80 COLUMN'
        even
menu40  data 0                      ; no more menu entries
        data start40                ; code entry point (see 0-01-Startup.a99)
        byte 17                     ; length of text
mtext   text 'TURBOFORTH V1.2.3 (c) 2016 Mark Wills'
        even

; 40 column mode entry point
start40 lwpi wkspc
        clr @sumode
        jmp startB0                 ; defined in 0-01-Startup.a99

; 80 column mode entry point
start80 lwpi wkspc
        li r0,2
        mov r0,@sumode 
        jmp startB0                 ; defined in 0-01-Startup.a99

; codes for bank 0 and bank 1 - used by the interrupt handler to determine which
; bank to return to after processing an interrupt.
; Set by the VDP routines (see 0-22-VDP.a99)
; DO NOT MOVE THESE! Identical definitions are made in bank 1, and they MUST 
; be at identical addresses!
bank0    data >6002                 ; code to select bank 0
bank1_   data >6000                 ; code to select bank 1


; General Equates
wkspc    equ  >8300                 ; workspace pointer
link     equ 0                      ; chain of links
gplst    equ >837c                  ; gpl status byte
keyin    equ >8375                  ; location of ascii key pressed (via KSCAN)
quitky   equ 157                    ; key code for cold reset (157=CTRL and =)
fac      equ >834a                  ; FAC
ISR      equ >83c4                  ; address of isr hook

pc       equ 3                     ; friendly name for program counter register
stack    equ 4                     ; friendly name for data stack register
rstack   equ 5                     ; friendly name for return stack register
NEXT     equ 12                    ; friendly name for NEXT routine

immed    equ >8000                  ; flag for immediate words

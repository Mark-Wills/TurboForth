;  _____            _           _____           _   _     
; |_   _|_   _ _ __| |__   ___ |  ___|___  _ __| |_| |__  
;   | | | | | | '__| '_ \ / _ \| |_  / _ \| '__| __| '_ \ 
;   | | | |_| | |  | |_) | (_) |  _|| (_) | |  | |_| | | |
;   |_|  \__,_|_|  |_.__/ \___/|_|   \___/|_|   \__|_| |_|
; ################################################
; TurboForth
; (C) Mark Wills 2010-2012
; Written in TMS9900 machine code for the TI-99/4A
; May the Forth be with you.
; ################################################
;  ____              _      _ 
; | __ )  __ _ _ __ | | __ / |
; |  _ \ / _` | '_ \| |/ / | |
; | |_) | (_| | | | |   <  | |
; |____/ \__,_|_| |_|_|\_\ |_|
;
; This is bank 1 - the secondary bank
; This bank consists of subroutines called by bank 0
;
; Cartridge header. Unfortunatley, we cannot know for sure that the
; correct bank will be selected at power-up, thus we need to duplicate
; the cartridge header here. This header is slightly different however,
; it copies a simple bootstrap routine to pad ram which selects bank 0
; and then jumps to the real bootstrap code in bank 0

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
        
        data menu40                 ; pointer to next menu item
        data start80                ; code entry point
        byte 20                     ; length of text
        text 'TURBOFORTH 80 COLUMN'
        even
        data 0                      ; no more menu entries
        data start40                ; code entry point (see below)
        byte 17                     ; length of text
        text 'TURBOFORTH V1.2.3 (c) 2016 Mark Wills'
        even

; 40 column mode entry point
        lwpi wkspc
        clr @sumode
        jmp startB1
        
; 80 column mode entry point
        lwpi wkspc
        li r0,2
        mov r0,@sumode
        jmp startB1
              
; codes for bank 0 and bank 1 - used by the interrupt handler to determine 
; which bank to return to after processing an interrupt. 
; Set by the VDP routines (see 0-21-VDP.a99). 
; DO NOT MOVE THESE! Identical definitions are made in bank 0, and they MUST 
; be at identical addresses!
        data >6002                  ; code to select bank 0
        data >6000                  ; code to select bank 1


startB1 limi 0                      ; no interrupts - we're British
        clr @>6000                  ; select bank1
        b @init                     ; init is defined in 1-15-Initialise.a99
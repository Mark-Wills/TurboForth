;  _____       _                              _   
; |_   _|     | |                            | |  
;   | |  _ __ | |_  ___ _ __ _ __ _   _ _ __ | |_ 
;   | | | '_ \| __|/ _ \ '__| '__| | | | '_ \| __|
;  _| |_| | | | |_|  __/ |  | |  | |_| | |_) | |_ 
; |_____|_| |_|\__|\___|_|  |_|   \__,_| .__/ \__|
;                                      | |        
;                                      |_|        
;  _____                       _        _               
; |  __ \                     | |      | |              
; | |  | | ___ ___ _ __   __ _| |_  ___| |__   ___ _ __ 
; | |  | |/ _ | __| '_ \ / _` | __|/ __| '_ \ / _ \ '__|
; | |__| |  __|__ \ |_) | (_| | |_| (__| | | |  __/ |   
; |_____/ \___|___/ .__/ \__,_|\__|\___|_| |_|\___|_|   
;                 | |                                   
;                 |_|                                   
; ISR despatcher - determines which ISR to call
; Speech is serviced every frame, sprites and music are serviced every alternate
; frame.

isrdes  mov r11,r10                 ; save return address to pad isr

; Speech Handling ISR
; Called every frame
; Checks to see if there is any speech to process, if not, just exits
; If there is, either calls ROMSPK to speak words from the speech ROM or calls
; STRSPK to send a raw byte stream to the synth, depending on the address loaded
; into SPCSVC.
; 
; First service any speech that is waiting to be sent to the speech synth
; if no speech is outstanding then exit the isr completely...
speech  mov @spcsvc,r0              ; get speech service address in r0
        jeq isrnxt                  ; if 0 then there is no speech to process so
        b *r0                       ; exit otherwise jump to the routine

; check user isr
isrnxt  mov @usrisr,r0              ; get user interrupt service routine address
        jeq isrout                  ; if zero then quit isr processing
        bl *r0                      ; otherwise branch and link to user ISR
                                    ; (user ISR code should execute an RT to 
                                    ; return here)

isrout  b @isrxit                   ; return to Forth environment

; ------------------------------------------------------------------------------

refill  equ 8                       ; # of bytes to refill the synth fifo with
; 'stream-speak' routine to feed raw speech bytes to the speech synth
strspk    
    ; if speech synth is already busy then just exit, we'll start up proper
    ; when the synth is idle...
        bl @spstat                  ; get speech synth status
        mov @spdata,r0              ; get the status from pad ram
        andi r0,>8000               ; check busy flag
        jne strxit                  ; exit if busy
    ; speech unit is idle... fill fifo with 16 bytes of speech data...
        mov @spadr,r0               ; address of speech data
        li r2,16                    ; 16 bytes to fill the fifo
strsp2  movb *r0+,@spchwt           ; write a byte to the speech synth
        dec r2                      ; decrement loop counter
        jne strsp2                  ; loop if not finished
        li r1,-16                   ; reduce bytes remaining by 16
        a r1,@spcnt                 ; store it
        mov r0,@spadr               ; store address of data
        li r0,strsp3                ; new entry point for the next interrupt
        mov r0,@spcsvc              ; load it
        jmp strxit                  ; quit. we'll enter at STRSP3 on the next 
                                    ; interrupt
    ; check fifo level. If fifo low, stream 8 bytes (or until data is exhausted)
    ; to the fifo
strsp3  bl @spstat                  ; get synth status
        mov @spdata,r0              ; move status from pad ram
        andi r0,>4000               ; check fifo low bit
        jeq strxit                  ; if not on, then exit - fifo doesn't need 
                                    ; filling
        mov @spadr,r0               ; buffer address
        mov @spcnt,r1               ; bytes remaining
        li r2,refill                ; 'refill' bytes to stream
strnb   movb *r0+,@spchwt           ; send a byte to the fifo
        dec r1                      ; decrement bytes remaining count
        jeq strcu                   ; if all data exhausted then clean up
        dec r2                      ; decrement counter
        jne strnb                   ; do next byte if not finished
        mov r0,@spadr               ; store address
        mov r1,@spcnt               ; store count
strxit  jmp isrnxt                  ; go check user isr
    ; we've streamed all the data, clean up and exit
strcu   clr @spcsvc                 ; clear speech service pointer - we're done
        clr @spcnt                  ; there's no bytes left to stream
        jmp isrnxt                  ; go check user isr


; 'rom-speak' routine to feed rom addresses to the speech synth
romspk  ; check speech synth, exit if synth is busy...
        bl @spstat                  ; get status from speech synth into 
                                    ; scratch-pad ram
        mov @spdata,r0              ; get the data from speech synth
        andi r0,>8000               ; speech synth busy?
        jne romspx                  ; exit if busy
    ; speech synth isn't busy... send a word of data...
        mov @spadr,r1               ; get address of data word
        mov *r1+,r0                 ; get the word in r0 for spaddr
        mov r1,@spadr               ; update buffer address
    ; convert the address to nybbles and send to the speech synth...
        bl @spaddr                  ; load the address contained in r0
    ; 42uS delay required before the 'talk' command can be issued to the speech
    ; synth. see editor/assembler manual, section 22.1.1, page 349
        li r0,20
dly42   dec r0                      ; spin the wheels...
        jne dly42
    ; send 'talk from rom' opcode to speech synth to make the synth actually 
    ; talk...
        movb @spkROM,@spchwt        ; send 'speak from rom op-code'
                                    ; synth is now talking
    ; do isr housekeeping...
        dec @spcnt                  ; decrement 'speech data remaining' counter
        jne romspx                  ; if not zero then just exit
        clr @spcsvc                 ; otherwise clear speech-service-routine
                                    ; pointer since there is no more data to 
                                    ; service.
romspx  b @isrxit                   ; return to next stage of isr handler 
                                    ; (in 1-15-initialise.a99)

; end of speech ISR
; -----------------------------------------------------------------------------

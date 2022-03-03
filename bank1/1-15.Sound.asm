;          _____                       _  __          __           _     
;         / ____|                     | | \ \        / /          | |    
;        | (___   ___  _   _ _ __   __| |  \ \  /\  / /__  _ __ __| |___ 
;         \___ \ / _ \| | | | '_ \ / _` |   \ \/  \/ / _ \| '__/ _` / __|
;         ____) | (_) | |_| | | | | (_| |    \  /\  / (_) | | | (_| \__ \
;        |_____/ \___/ \__,_|_| |_|\__,_|     \/  \/ \___/|_|  \__,_|___/
                                                                        

; SN76489 register writes
; -----------------------
; When a byte is written to the SN76489, it processes it as follows:
;  %1cctdddd
;    d=data bits
;    t=type bits
;    c=channel bits 
;If bit 7 is 1 then the byte is a LATCH/DATA byte.
;
; Bits 6 and 5 (cc) give the channel to be latched, ALWAYS. 
; This selects the row in the above table.
; %00 is channel 0, %01 is channel 1, %10 is channel 2, %11 is channel 3.
; Bit 4 (t) determines whether to latch volume (1) or tone/noise (0) data. 
; The remaining 4 bits (dddd) are placed into the low 4 bits of the relevant 
; register. 
; For the three-bit noise register, the highest bit is discarded.
; The latched register is NEVER cleared by a data byte.
; If bit 7 is 0 then the byte is a DATA byte.
;
;  %0-DDDDDD
;    |``````-- Data
;    `-------- Unused
;
; If the currently latched register is a tone register then the low 6 bits of 
; the byte (DDDDDD) are placed into the high 6 bits of the latched register. 
; If the latched register is less than 6 bits wide (ie. not one of the tone 
; registers), instead the low bits are placed into the corresponding bits of the
; register, and any extra high bits are discarded.
; The data have the following meanings (described more fully later):
;
; Tone registers
;    DDDDDDdddd = cccccccccc
;    DDDDDDdddd gives the 10-bit half-wave counter reset value. 
;
; Volume registers
;    (DDDDDD)dddd = (--vvvv)vvvv
;
;    dddd gives the 4-bit volume value.
;    If a data byte is written, the low 4 bits of DDDDDD update the 4-bit volume
;    value. However, this is unnecessary. 
;
; Noise register
;    (DDDDDD)dddd = (---trr)-trr
;
;    The low 2 bits of dddd select the shift rate and the next highest bit 
;    (bit 2) selects the mode (white (1) or "periodic" (0)).
;    If a data byte is written, its low 3 bits update the shift rate and mode 
;    in the same way. 

; called from bank0 - see 0-20-Sound.a99
sound1  mov @bank1_,@retbnk
        limi 2
        limi 0 
        li r7,>8400                 ; address of sound chip
    ; set the channel...
        mov *stack+,r1              ; pop channel
        mov r1,r8                   ; save it
        li r0,>9000                 ; set msb and volume latch bit
        src r1,3                    ; move channel into correct bit position
        soc r0,r1                   ; combine
    ; set the volume...
        mov *stack+,r0              ; pop volume
        swpb r0                     ; move to high byte
        soc r0,r1                   ; combine
        movb r1,*r7                 ; move to sound chip
    ; get pitch...
        andi r1,>e000               ; reset t bit (to latch pitch)
        mov *stack+,r0              ; pop pitch
        mov r0,r2                   ; copy it
        andi r0,>000f               ; get the low 4 bits
        swpb r0                     ; move to high byte
        soc r0,r1                   ; combine
        movb r1,*r7                 ; move to sound chip
    ; process noise channel if ch#=3...
        ci r8,3                     ; noise channel?
        jeq sndxit                  ; if so then just exit
        sla r2,4                    ; get upper 6 bits in upper byte
        movb r2,*r7                 ; send to sound chip
sndxit  b @retB0

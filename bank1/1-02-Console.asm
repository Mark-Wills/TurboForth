;   _____                       _       __          __            _     
;  / ____|                     | |      \ \        / /           | |    
; | |      ___  _ __  ___  ___ | | ___   \ \  /\  / /___  _ __ __| |___ 
; | |     / _ \| '_ \/ __|/ _ \| |/ _ \   \ \/  \/ // _ \| '__/ _` / __|
; | |____| (_) | | | \__ \ (_) | |  __/    \  /\  /| (_) | | | (_| \__ \
;  \_____|\___/|_| |_|___/\___/|_|\___|     \/  \/  \___/|_|  \__,_|___/
;  Console IO words

; PAGE ( -- ) see 0-09-Console.a99
_cls    mov @xmax,r1                ; calculate the character count
        li r0,24                    ; according to the...
        mpy r0,r1                   ; ...text mode
        clr r0                      ; screen address
        li r1,>2000                 ; space character
        bl @vsbwmi                  ; wipe screen
        clr @scrX                   ; zero x coordinate
        clr @scrY                   ; zero y coordinate
        b @retB0


; JOYST ( joystick# -- value )
; Scans the joystick returning the direction value
_joyst  mov *stack,r1               ; get unit number
        ai r1,6                     ; use keyboard select 6 for #0, 7 for #1
        swpb r1
        li r12,36
        ldcr r1,3
        li r12,6
        stcr r1,5
        swpb r1
        inv r1
        andi r1,>001f
        mov r1,*stack
        li r12,_next
        mov r12,@>83d6              ; defeat auto screen blanking
        mov @bank1_,@retbnk         ; return to bank 1 if interuupts should fire
        limi 2                      ; briefly enable interrupts
        limi 0                      ; and turn 'em off again
        b @retb0                    ; return to caller in bank 0


; __      _______  _____    _    _ _   _ _ _ _   _          
; \ \    / /  __ \|  __ \  | |  | | | (_) (_) | (_)         
;  \ \  / /| |  | | |__) | | |  | | |_ _| |_| |_ _  ___ ___ 
;   \ \/ / | |  | |  ___/  | |  | | __| | | | __| |/ _ | __|
;    \  /  | |__| | |      | |__| | |_| | | | |_| |  __|__ \
;     \/   |_____/|_|       \____/ \__|_|_|_|\__|_|\___|___/
; VDP access utility routines

; vdp single byte read
; inputs: r0=address in vdp to read, r1(msb), the byte read from vdp
; side effects: none
_vsbr   swpb r0
        movb r0,@vdpa
        swpb r0
        movb r0,@vdpa
        .nop
        movb @vdpr,r1
        .rt


; vdp multiple byte read
; inputs: r0=vdp source address, r1=cpu ram destination address
; r2=number of bytes to read
; side effects: r1, r2 & r13 changed
_vmbri  mov @bank1_,@retbnk         ; return to bank 1
_vmbr2  limi 2
        limi 0
    ; entry point for no interrupts:
_vmbr   swpb r0
        movb r0,@vdpa
        swpb r0
        movb r0,@vdpa
        .nop
_vmbr1  movb @vdpr,*r1+
        dec r2
        jne _vmbr1
        .rt


; vdp single byte write
; inputs: r0=address in vdp to write to, r1(msb)=the byte to write
; side effects: none
_vsbw   mov @bank1_,@retbnk         ; return to bank 1
        limi 2
        limi 0
    ; entry point for no interrupts:
_vsbw0  ori r0,>4000
        swpb r0
        movb r0,@vdpa
        swpb r0
        movb r0,@vdpa
        movb r1,@vdpw
        xor @_bit1,r0               ; reset bit 1
        .rt


; vdp multiple byte write
; r0=destination in vdp, r1=source address in cpu ram, r2=number of bytes
; side effects: r1, r2 & r13 changed
_vmbw    
        mov @bank1_,@retbnk         ; return to bank 1
_vmbw2  limi 2
        limi 0
    ; entry point for no interrupts:
_vmbw0  ; mov r2,r2                   ; check for zero length
        ; jeq _vmbwx                  ; if zero then exit
        ori r0,>4000
        swpb r0
        movb r0,@vdpa
        swpb r0
        movb r0,@vdpa
_vmbw1  movb *r1+,@vdpw
        dec r2
        jne _vmbw1
        xor @_bit1,r0               ; reset bit 1
_vmbwx  .rt


; vdp single byte write many
; writes the same bytes multiple times to consequtive VDP address
; r0=vdp destination address
; r1=the byte to write (in msb)
; r2=number of times to write
_vsbwm  mov @bank1_,@retbnk         ; return to bank 1
_vsbwm2 limi 2
        limi 0
    ; entry point for no interrupts:
vsbwmi  ori r0,>4000                ; this is a vdp write command
        swpb r0                     ; low byte first
        movb r0,@vdpa               ; load low byte into address register
        swpb r0                     ; get high byte
        movb r0,@vdpa               ; write high byte
_vsbm1  movb r1,@vdpw
        dec r2                      ; decrement count
        jne _vsbm1                  ; loop if not finished
        xor @_bit1,r0               ; reset bit 1
        .rt                         ; return to caller


; vdp write to vdp register
; inputs: r0(msb)=the register to write to, r0(lsb)=the value to write
; side effects: none
_vwtr   ori r0,>8000
        swpb r0
        movb r0,@vdpa
        swpb r0
        movb r0,@vdpa
        xor @_bit0,r0               ; reset bit 0
        .rt

_bit0   data >8000                  ; used for re-setting bits
_bit1   data >4000

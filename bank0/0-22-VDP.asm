; __      _______  _____    _    _ _   _ _ _ _   _          
; \ \    / /  __ \|  __ \  | |  | | | (_) (_) | (_)         
;  \ \  / /| |  | | |__) | | |  | | |_ _| |_| |_ _  ___ ___ 
;   \ \/ / | |  | |  ___/  | |  | | __| | | | __| |/ _ | __|
;    \  /  | |__| | |      | |__| | |_| | | | |_| |  __|__ \
;     \/   |_____/|_|       \____/ \__|_|_|_|\__|_|\___|___/
; VDP access utility routines

; VDP addresses:
vblnk	equ >83D7                      ; vertical blank counter
vdpr	equ >8800                      ; vdp read register
vdpw	equ >8C00                      ; vdp write register
vdpa	equ >8C02                      ; vdp address register
vdpst   equ >8802                      ; vdp status register


; bit1	data >4000	; used for re-setting bit 1
; note: bit1 is now defined in LFREE in 0-07-Memory.a99

; vdp single byte read
; inputs: r0=address in vdp to read, r1(msb), the byte read from vdp
; side effects: none
vsbr	mov @bank0,@retbnk      ; return to bank 0 if interrupt should trigger
        limi 2                  ; briefly enable interrupts
        limi 0                  ; and switch 'em off again
        swpb r0                 ; get low byte of address
		movb r0,@vdpa           ; write it to vdp address register
		swpb r0                 ; get high byte
		movb r0,@vdpa           ; write
        .nop
		movb @vdpr,r1           ; write payload
		.rt                     ; see ya

    
; vdp multiple byte read
; inputs: r0=vdp source address, r1=cpu ram destination address
; r2=number of bytes to read
; side effects: r1 & r2 changed
vmbr	swpb r0                 ; get low byte of address
		movb r0,@vdpa           ; write it
		swpb r0                 ; get high byte of address
		movb r0,@vdpa           ; write it
		li r15,vdpr             ; cache vdp write register address in r15
vmbr1	movb *r15,*r1+          ; fast write to vdp register
		dec r2                  ; finished?
		jne vmbr1               ; loop if not
		.rt                     ; so long


; vdp single byte write
; inputs: r0=address in vdp to write to, r1(msb)=the byte to write
; side effects: none
vsbw	mov @bank0,@retbnk      ; return to bank 0 if interrupt should trigger
		limi 2                  ; briefly enable interrupts
		limi 0                  ; but too long, we're British you know
vsbw0	ori r0,>4000            ; tell VDP processor "hey, this is a *write*"
		swpb r0                 ; get low byte of address
		movb r0,@vdpa           ; write it to vdp address register
		swpb r0                 ; get high byte of address
		movb r0,@vdpa           ; write it
		movb r1,@vdpw           ; write payload
		xor @bit1,r0            ; reset bit 1
		.rt                     ; we'd love to stay, but we have a long drive...


; vdp multiple byte write
; r0=destination in vdp, r1=source address in cpu ram, r2=number of bytes
; side effects: r1 & r2 changed
vmbw	mov @bank0,@retbnk      ; return to bank 0 if interrupt should trigger
		limi 2                  ; briefly enable interrupts
		limi 0                  ; this is getting boring now
vmbw0	ori r0,>4000            ; if you can't figure this out by now
		swpb r0                 ; then try the Commodore 64
		movb r0,@vdpa           ; it's a much inferior machine
		swpb r0                 ; with the worlds worst processor
		movb r0,@vdpa           ; though Chuck Peddle is extremely cool
		li r15,vdpw             ; and you have to hand it to Jack Tramiel too.
vmbw1	movb *r1+,*r15          ; Anyway the C64 has much simpler hardware
		dec r2                  ; and a super simple (i.e. super sucky) CPU
		jne vmbw1               ; but hey, it *does* have 64K of ram, the lucky 
		xor @bit1,r0            ; old git.
		.rt                     ; been nice chatting with ya...

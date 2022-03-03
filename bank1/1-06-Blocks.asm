;  ____  _            _      _____     ______   __          __            _     
; |  _ \| |          | |    |_   _|   / / __ \  \ \        / /           | |    
; | |_) | | ___   ___| | __   | |    / / |  | |  \ \  /\  / /___  _ __ __| |___ 
; |  _ <| |/ _ \ / __| |/ /   | |   / /| |  | |   \ \/  \/ // _ \| '__/ _` / __|
; | |_) | | (_) | (__|   <   _| |_ / / | |__| |    \  /\  /| (_) | | | (_| \__ \
; |____/|_|\___/ \___|_|\_\ |_____/_/   \____/      \/  \/  \___/|_|  \__,_|___/
; block file system words & subroutines
; Some heavy stuff in here. In here be demons.
; Turn back all ye faint of heart...

;[ pab opcodes
open    equ 0                       ; open opcode
close   equ >1                      ; close opcode
read    equ >2                      ; read opcode
write   equ >3                      ; write opcode
fwdrew  equ >4                      ; restore/rewind opcode (fwd/rew)
status  equ >9                      ; status op-code
;]

;[ USE ( addr len -- )
; Tells the system which block file to use for block IO
; e.g. USE DSK1.BLOCKS
; Simply sets the filename and length in the blockIO PAB
; Syntax: S" DSKn.FILENAME" USE
_use    mov *stack+,r2              ; length of filename
        swpb r2                     ; move to MSB
        mov *stack+,r0              ; address of file name
        li r9,pabnln                ; address of filename length in blockIO PAB
        movb r2,*r9+                ; write length to PAB length byte, now 
                                    ; pointing at filename
        swpb r2                     ; move to LSB
_use3   movb *r0+,*r9+              ; copy byte of filename to pab
        dec r2                      ; finished copying?
        jne _use3                   ; repeat if not
    ; clear all blk pointers...
        clr @lstblk
        clr @blk0
        clr @blk1
        clr @blk2
        clr @blk3
        clr @blk4
        clr @blk5
usexit  b @retB0
;]

;[ BLOCK ( block# -- addr )
; Brings a block into a buffer, if not already in memory
;  1) If already in memory, the block is not re-loaded from device
;  2) If not in memory:
;  3)  Scans for a free buffer
;  4)  If no free buffer:
;  5)   flush all buffers back to device
;  6)   Repeat from 3
;  7) If free buffer:
;  9)  Load block from device into free buffer
; 10)  Return address of buffer
; 11) If disk error, or block not found etc, return 0
; Note: If a block number of 0 is given 0 is returned
_block  clr @errnum                 ; clear last disk io error 
        mov *stack,r0               ; block number in r0 for scnblk
        jeq usexit                  ; if zero then just exit
        mov r0,@lstblk              ; update last block accessed (for UPDATE)
        bl @scnblk                  ; see if the block is already in memory
        mov r1,r1                   ; check returned result
        jeq blknim                  ; block is not in memory
        inct r1                     ; block is in memory. point to vdp address
                                    ; pointer
        mov *r1,*stack              ; place vdp address on stack
        jmp usexit                  ; exit
    ; look for a free buffer
blknim  bl @frebuf                  ; block is not in memory, scan for a buffer
        mov r0,r0                   ; check returned result
        jeq bnfb                    ; jump if no free buffers
    ; we have a free buffer, it's blk address is in r0...
blkfb   mov *stack,*r0              ; update block indicator in block buffer
        mov r0,r8                   ; copy blk address
        mov *r0,r2                  ; copy block number
        dec r2                      ; reduce by one (so we can use block 0)
        sla r2,3                    ; calculate record number (block no. x 8)
        inct r0                     ; point to vdp address
        mov *r0,r9                  ; save vdp address
        mov r9,*stack               ; place vdp address on stack
    ; put the pab into vdp ram, with an open opcode and open the file...
        li r1,>8000                 ; logical record length: 128 bytes (in msb)
        movb r1,@pablrl             ; set logical record length in pab
        mov r2,@pabrec              ; set record number in PAB
        mov r9,@pabbuf              ; address to load data into in VDP
        bl @diskio                  ; witchcraft
        byte open,5                 ; dis/fix input
        jeq blkerr                  ; jump if an an error occurred
    ; read 8 128 byte records (1K)...
        li r7,8                     ; 8 records to read
blknxt  bl @diskio                  ; call disk system
        byte read,5                 ; dis/fix input
        jeq blkerr                  ; jump if an an error occurred
        ai r9,128                   ; increment vdp address
        mov r9,@pabbuf              ; address to load data into in VDP
        inc @pabrec                 ; set next record in PAB
        dec r7                      ; finished reading all the records?
        jne blknxt                  ; repeat if not
        bl @diskio                  ; more alchemy
        byte close,5                ; dis/fix input
        bl @rstsp                   ; restore code in scratchpad
                                    ; (destroyed by DSR access)
        jmp usexit                  ; exit
    ; no free buffers :-( we need to do a flush...
bnfb    bl @flush1                  ; flush all our buffers to device
        li r0,blk0                  ; point to first (which is now free) block
        jmp blkfb                   ; repeat
    ; an error occurred, return 0 on the stack
blkerr  clr *stack                  ; zero the TOS
        swpb r0
        mov r0,@errnum              ; set disk io error number
        bl @diskio                  ; close the file
        byte close,5
        bl @rstsp                   ; restore code in scratchpad 
                                    ; (destroyed by DSR access)
        jmp usexit                  ; exit
;]

;[ FLUSH ( -- )
; Flushes all dirty blocks back to disk
; If a blocks' DIRTY flag is set, the block is physically written back to disk.
; If the block is NOT dirty, it's (BLK) status is simply set to un-used.
; Sets DSKERR to reflect disk DSR error status (0=no error)
_flush  bl @flush1
flushx  jmp usexit
flush1  clr @errnum                 ; reset last disk io error
        mov r11,r14                 ; save return address of caller
    ;    li r6,6                     ; 6 buffers to check
    mov @totblk,r6              ; number of buffers to check 
        li r7,blk0+2                ; start with the first vdp address pointer
flnext  mov *r7,r8                  ; get address
        andi r8,>8000               ; check dirty flag
        jeq flush2                  ; if 0, not dirty, just reset pointers
    ; else flush to disk...
        li r1,>8000                 ; logical record length: 128 bytes (in msb)
        movb r1,@pablrl             ; set logical record length
        clr @pabrec                 ; set record number to 0 
        bl @diskio
        byte open,1                 ; dis/fixed update
        jeq flerr                   ; jump if error
        li r12,8                    ; 8 128 byte records (1024 bytes)
        mov *r7,r8                  ; vdp address
        andi r8,>7fff               ; remove dirty bit
        mov @-2(r7),r1              ; get block number
        dec r1                      ; account for blocks starting at 1
        sla r1,3                    ; convert to record count
        mov r1,@pabrec              ; set record number
flnrec  mov r8,@pabbuf              ; set source vdp address
        bl @diskio                  ; write the record to disk
        byte write,1                ; dis/fix update
        jeq flerr                   ; jump if error
        ai r8,128                   ; next 128 bytes of vdp
        inc @pabrec                 ; next record on disk
        dec r12                     ; decrement counter
        jne flnrec                  ; loop if not finished
        bl @diskio                  ; close the file
        byte close,1                ; dis/fix update
        jeq flerr                   ; jump if error
    ; reset blk & dirty flag...
flush2  clr @-2(r7)                 ; clear blk indicator
        mov *r7,r1                  ; get vdp address from pointer
        andi r1,>7fff               ; reset dirty bit
        mov r1,*r7                  ; write it back
    ; loop back for remaining blks...
        ai r7,4                     ; point to next vdp address
        dec r6                      ; finished?
        jne flnext                  ; repeat if not
flexit  li r12,_next                ; restore pointer to NEXT
        bl @rstsp                   ; restore code in scratchpad (destroyed by 
                                    ; DSR access)
        b *r14                      ; return to caller
    ; an error occurred... exit...
flerr   swpb r0                     ; move error into low byte
        mov r0,@errnum              ; set DSKERR with error code
        bl @diskio                  ; set the file to closed
        byte close,1
        jmp flexit
;]

;[ UPDATE ( -- )
; marks the last accessed block as dirty so that it will subsequently be flushed
; to disk.
_updat  mov @lstblk,r0              ; get current block
        bl @scnblk                  ; locate it (blk address in r1)
        inct r1                     ; point to VDP address pointer
        mov *r1,r0                  ; get the VDP address
        ori r0,>8000                ; set dirty bit
        mov r0,*r1                  ; write it back
        jmp flushx
;]

;[ EMPTY-BUFFERS ( -- )
; marks all buffers as unused.
_mtbuf  li r2,6                     ; counter
        li r0,blk0                  ; address of first blk
mtbufl  clr *r0+                    ; zero block number then point to vdp
                                    ; address
        mov *r0,r1                  ; get vdp address
        andi r1,>7fff               ; set dirty to zero
        mov r1,*r0+                 ; write it back, point to next blk
        dec r2                      ; decrement counter
        jne mtbufl                  ; repeat if not finished
        clr @lstblk                 ; no blocks in memory
        jmp flushx
;]

;[ CLEAN ( buffer -- )
; forces a buffers' status to clean
_clean  bl @cba                     ; compute blk address
        andi r1,>7fff               ; reset dirty bit
        mov r1,*r0                  ; write it back
        jmp flushx

;]

;[ DIRTY ( buffer -- )
; forces a buffers' status to dirty
_dirty  bl @cba                     ; compute blk address
        ori r1,>8000                ; set dirty bit
        mov r1,*r0                  ; write it back
        jmp flushx
;]

;[ DIRTY? ( buffer -- flag )
; interrogates a buffers' status, returning true if the buffer is dirty, else
; returning false
_qdirt  bl @cba                     ; compute blk address
        dect stack                  ; make space on stack (cba reduces stack 
                                    ; pointer)
        andi r1,>8000               ; mask out everything except dirty bit
        jeq ndirt                   ; if 0 then it's not dirty
        seto *stack                 ; it's dirty
        b @retB0
ndirt   clr *stack                  ; it's clean
        jmp flushx
;]

;[ BLK? ( buffer -- block vdp_address )
; For a given buffer, returns the actual block stored in that buffer
; and the vdp address of that buffer
_blkq   bl @cba                     ; compute blk address
        dect stack                  ; make space on stack
        dect r0                     ; point to blk 
        mov *r0,*stack              ; place on stack
        andi r1,>7fff               ; mask out dirty bit
        dect stack
        mov r1,*stack               ; place vdp address of buffer on stack
        jmp flushx
;]

;[ BUF? ( block -- buffer vdp_address )
; For a given block, return the buffer number, and the vdp address of the buffer
; returns 0 0 if the block is not in memory
_buf    mov *stack,r1               ; get block
        li r2,0                     ; six buffers to check
        li r0,blk0                  ; point to top of buffer descriptor table
bufrpt  c *r0,r1                    ; compare block to block being sought
        jeq fndbuf                  ; jump if we found it
        ai r0,4                     ; else point to next buffer in the table
        inc r2                      ; increment counter
        ci r2,6                     ; finished?
        jne bufrpt
        clr *stack                  ; the block was not found - return 0 0
        dect stack                  ; new stack entry
        clr *stack
        jmp bufxit
fndbuf  mov r2,*stack               ; push buffer number
        dect stack                  ; new stack entry
        inct r0                     ; point to vdp address
        mov *r0,*stack              ; push it to stack
bufxit  b @retB0
;]

;[ SETBLK ( buffer block -- )
; For a given buffer, changes the block that it is associated with. 
; Allows blocks to copied to other blocks, using FLUSH.
_setbk  mov *stack+,r1              ; pop the block
        mov *stack+,r2              ; pop the buffer
        sla r2,2                    ; multiply buffer by 4 to act as offset into
                                    ; buffer descriptor table
        li r0,blk0                  ; point to top of buffer descriptor table
        a r2,r0                     ; point to correct entry in buffer 
                                    ; descriptor table
        mov r1,*r0                  ; change block entry
        jmp bufxit
;]

;[ MKBLK ( filename size_in_kilobytes -- )
; makes a block file on disk. Sets DSKERR with result code. >0=some error
_mkblk  clr @errnum                 ; clear last disk error
        mov *stack+,r0              ; length of file name
        mov *stack+,r1              ; address of filename
        mov *stack+,r6              ; pop number of kilobytes
        swpb r0                     ; get file name length in MSB
        movb r0,@pabnln             ; load name length byte in CPU PAB
        swpb r0
    ; check size against limits...
        ci r6,1                     ; minimum size
        jlt toosml                  ; size is too small, force to 1
        ci r6,1024                  ; maximum size
        jgt toobig                  ; size is too big, force to 1024
        jmp cont
toosml  li r6,1                     ; force size to 1
        jmp cont                    ; continue
toobig  li r6,1024                  ; force size to 1024
    ; copy the filename into the cpu ram PAB...
cont    li r2,pabfil                ; address of filename in CPU PAB
mkdskl  movb *r1+,*r2+              ; copy character of filename
        dec r0                      ; finished copying filename?
        jne mkdskl
    ; create a 128 byte block of space characters in vdp ram
        li r0,recbuf                ; vdp target address
        mov r0,@pabbuf              ; set vdp source buffer address
        li r1,>2000                 ; space character
        li r2,128                   ; 128 bytes to write
        bl @vsbwmi                  ; write bytes
    ; put the pab into vdp ram, with an open opcode. open the file, dis/fix 128
        li r1,>8000                 ; logical record length: 128 bytes (in msb)
        movb r1,@pablrl             ; set logical record length
        clr @pabrec                 ; set record number to 0 
        bl @diskio
        byte open,3                 ; dis/fix output
        jeq mkderr                  ; jump if error
    ; the file should be created at this point. now write a record:
    ; the number of kilobytes to create is in r6
next1k  li r7,8                     ; number of records for 1k. 8x128 bytes=1024
nxtrec  bl @diskio                  ; write the pab to vdp
        byte write,3                ; dis/fix output
        jeq mkderr                  ; jump if error
        inc @pabrec                 ; increment record number
        dec r7                      ; decrement record counter
        jne nxtrec                  ; repeat if we haven't written 8 records
        dec r6                      ; decrement kilobyte counter
        jne next1k                  ; repeat if not finished
    ; close the file
mkclse  bl @diskio                  ; write the pab to vdp
        byte close,3                ; dis/fix output
        bl @rstsp                   ; restore code in scratchpad
                                    ; (destroyed by DSR access)
        jmp bufxit
    ; something went wrong...
mkderr  swpb r0
        mov r0,@errnum              ; set disk io error number
        jmp mkclse                  ; close file (for what it's worth) and exit
;]

;[ compute block address routine
; given buffer number on the stack, gives address of appropriate blk in r0
; and the associated vdp address in r1
; Used by CLEAN, DIRTY, and DIRTY?
cba     mov *stack+,r0              ; get blk number
        sla r0,2                    ; convert to offset
        li r1,blk0                  ; address of first blk
        a r1,r0                     ; get address of blk
        inct r0                     ; point to vdp address pointer
        mov *r0,r1                  ; get vdp address
        .rt                          ; return to caller
;]

;[ Free Buffer subroutine. Scans for a free buffer. 
; Returns a free blk address in r0.
; r0=0 means there are no free buffers
; a buffer will treated as free if it's dirty flag is not set
frebuf  mov @totblk,r2              ; number of buffers to check
        li r0,blk0                  ; buffer status pointer for 1st buffer
nxtfb   mov *r0,r1                  ; check block assignment
        jeq bfree                   ; jump if buffer is free
        ai r0,4                     ; point to next blk
        dec r2                      ; finished?
        jne nxtfb                   ; check again if not
        clr r0                      ; there are no free buffers
bfree   .rt
;]

;[ scan buffers to see if the block in question is already in memory
; expects block number in r0
; returns address of blk in r1, or 0 if the block is not in memory
scnblk  li r1,blk0                  ; address of first buffer
        mov @totblk,r2              ; number of buffers to check
scnnxt  c r0,*r1                    ; is this the block we're looking for?
        jeq fndblk                  ; jump if yes
        ai r1,4                     ; check next buffer
        dec r2                      ; finished?
        jne scnnxt                  ; repeat if not
        clr r1                      ; not in memory
fndblk  .rt
;]

;[ put the pab into vdp ram with the appropriate opcode in byte 0 of pab
; then call dos...
diskio  mov *r11+,@pabopc           ; load opcode and file format into ram pab
        mov r11,r10                 ; save return address, as BL below will 
                                    ; destroy it
        li r1,pabloc+9              ; vdp address of name length byte
        mov r1,@namptr              ; move it to >8356 as per DSR requirements
    ; write the PAB into VDP ram...
        li r0,pabloc                ; vdp destination
        li r1,pabopc                ; source
        li r2,30                    ; number of bytes to copy to vdp
        bl @_vmbw0                  ; write the pab to vdp
        blwp @dsrlnk                ; call dos
        data 8                      ; disk op parameter, level 3 command    
        b *r10
;]

;[ dsr link routine - Written by Paolo Bagnaresi
dsrlnk  data dsrlws                 ; dsrlnk workspace
        data dlentr                 ; entry point

dlentr  li r0,>aa00
        movb r0,@haa                ; load haa
        mov *r14+,r5                ; get pgm type for link
        mov r5,@sav8a               ; save data following blwp @dsrlnk (8 or >a)
        szcb @h20,r15               ; reset equal bit
        mov @>8356,r0               ; get ptr to pab
        mov r0,r9                   ; save ptr
        mov r0,@flgptr              ; save again pointer to pab+1 for dsrlnk 
                                    ; data 8
        ai r9,>fff8                 ; adjust to flag
        bl @_vsbr                   ; read device name length
        movb r1,r3                  ; copy it
        srl r3,8                    ; make it lo byter
        seto r4                     ; init counter
        li r2,namsto                ; point to buffer
lnkslp  inc r0                      ; point to next char of name
        inc r4                      ; incr char counter
        ci r4,>0007                 ; see if length more than 7 chars
        jgt lnkerr                  ; yes, error
        c r4,r3                     ; end of name?
        jeq lnksln                  ; yes
        bl @_vsbr                   ; read curr char
        movb r1,*r2+                ; move into buffer
        cb r1,@decmal               ; is it a period?
        jne lnkslp                  ; no
lnksln  mov r4,r4                   ; see if 0 length
        jeq lnkerr                  ; yes, error
        clr @>83d0
        mov r4,@>8354               ; save name length for search
        mov r4,@savlen              ; save it here too
        inc r4                      ; adjust for period
        a r4,@>8356                 ; point to position after name
        mov @>8356,@savpab          ; save pointer to position after name
srom    lwpi >83e0                  ; use gplws
        clr r1                      ; version found of dsr
        li r12,>0f00                ; init cru addr
norom   mov r12,r12                 ; anything to turn off?
        jeq nooff                   ; no
        sbz 0                       ; yes, turn off
nooff   ai r12,>0100                ; next rom to turn on
        clr @>83d0                  ; clear in case we are done
        ci r12,>2000                ; see if done
        jeq nodsr                   ; yes, no dsr match
        mov r12,@>83d0              ; save addr of next cru
        sbo 0                       ; turn on rom
        li r2,>4000                 ; start at beginning of rom
        cb *r2,@haa                 ; check for a valid rom
        jne norom                   ; no rom here
        a @dstype,r2                ; go to first pointer
        jmp sgo2
sgo     mov @>83d2,r2               ; continue where we left off
        sbo 0                       ; turn rom back on
sgo2    mov *r2,r2                  ; is addr a zero (end of link)
        jeq norom                   ; yes, no programs to check
        mov r2,@>83d2               ; remember where to go next
        inct r2                     ; go to entry point
        mov *r2+,r9                 ; get entry addr just in case
        movb @>8355,r5              ; get length as counter
        jeq namtwo                  ; if zero, do not check
        cb r5,*r2+                  ; see if length matches
        jne sgo                     ; no, try next
        srl r5,8                    ; yes, move to lo byte as counter
        li r6,namsto                ; point to buffer
namone  cb *r6+,*r2+                ; compare buffer with rom
        jne sgo                     ; try next if no match
        dec r5                      ; loop til full length checked
        jne namone
namtwo  inc r1                      ; next version found
        mov r1,@savver              ; save version
        mov r9,@savent              ; save entry addr
        mov r12,@savcru             ; save cru
        bl *r9                      ; go run routine
        jmp sgo                     ; error return
        sbz 0                       ; turn off rom if good return
        lwpi dsrlws                 ; restore workspace
        mov r9,r0                   ; point to flag in pab
frmdsr  mov @sav8a,r1               ; get back data following blwp @dsrlnk
                                    ; (8 or >a)
        ci r1,8                     ; was it 8?
        jeq dsrdt8                  ; yes, jump: normal dsrlnk
        movb @>8350,r1              ; no, we have a data >a. get error byte from
                                    ; >8350
        jmp dsrdta                  ; go and return error byte to the caller
dsrdt8  bl @_vsbr                   ; read flag
dsrdta  srl r1,13                   ; just keep error bits
        jne ioerr                   ; handle error
        rtwp
nodsr   lwpi dsrlws                 ; no dsr, restore workspace
lnkerr  clr r1                      ; clear flag for error 0 = bad device name
ioerr   swpb r1                     ; put error in hi byte
        movb r1,*r13                ; store error flags in callers r0
        socb @h20,r15               ; set equal bit to indicate error
        rtwp

data8   data >8                     ; just to compare. 8 is the data that
                                    ; usually follows a blwp @dsrlnk
decmal  text '.'                    ; for finding end of device name
        even
h20     data >2000
;]

;[ restore code to scratch-pad ram
; accessing the disk via the disk DSR destroys some code in scratch pad
; restore the code in scratch pad before returning    
rstsp   li r0,toram                 ; address of 1st source block
        li r1,docol                 ; destination        
rstsp1  mov *r0+,*r1+               ; copy a cell
        ci r0,__dup
        jne rstsp3 
        li r1,_dup
rstsp3  ci r0,padend                ; hit end of first block of code?
        jne rstsp1                  ; loop if not
        .rt
;]

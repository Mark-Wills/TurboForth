;  ______ _ _         _____     ______  
; |  ____(_) |       |_   _|   / / __ \ 
; | |__   _| | ___     | |    / / |  | |
; |  __| | | |/ _ \    | |   / /| |  | |
; | |    | | |  __/   _| |_ / / | |__| |
; |_|    |_|_|\___|  |_____/_/   \____/ 
; File IO implementation                                       

; FILE ( s-addr  s-len  buf-addr -- )
; Builds a PAB in the buffer whose address is passed as buf_addr using the data
; in the string represented by s_addr and s_len.
; For example:
;     FBUF: PRINTER
;     S" PIO.CR DV80O" PRINTER FILE
; The above builds a PAB in the buffer called PRINTER which references the PIO 
; device. Subsequent file IO words that wish to send data to the PIO shall use
; the buffer name to reference it:
; e.g. 
;     PRINTER #OPEN DROP ( open PIO and drop success/fail flag)
;     S" HELLO WORLD" PRINTER #PUT DROP 
;     ( write HELLO WORLD to the PIO and drop success/fail flag)
;
; Internally, FILE builds a PAB in the buffer which will be used by #OPEN and 
; all file IO words. 
; Word 0 of the reserved memory is used to point to the actual PAB in VDP 
; memory. Enough space should be reserved (with ALLOT) in the buffer to hold the
; PAB and the filename.
;
; The string which specifies the file name and file characteristics is defined 
; as below. 
; The filename *must* come first followed by a space character. After that, the
; file options can be specified in any order.
;
; File Options:
;  F=Fixed      - Fixed record type
;  V=Variable   - Variable record type
;
;  D=Display    - Display data type
;  L=InternaL   - Internal data type
;
;  U=Update     - Update file mode
;  O=Output     - Output file mode
;  I=Input      - Inoput file mode
;  A=Append     - Append file mode
;
;  S=Sequential - Sequential file type
;  R=Relative   - Relative file type
;
; Note that Internal type files require L
; this is because I is used to specify INPUT
_file   clr r8                      ; zero the record length accumulator
        mov *stack+,r10             ; pop buffer address from stack
    ; zero the first 10 bytes of the alloted buffer 
    ; (holds the PAB data - no need to zero the filename length byte or the 
    ; file, as they'll be populated later)
        mov r10,r13                 ; copy buffer address
        li r1,10                    ; number of bytes to clear
_ficll  clr *r13+                   ; clear two bytes in buffer
        dect r1                     ; decrement counter
        jne _ficll                  ; repeat if not finished
    ; transfer filename to PAB...
        clr r6                      ; byte ops
        mov @2(stack),r0            ; address of string in pad
        mov r10,r1                  ; copy buffer address
        ai r1,12                    ; point to 1st filename byte
        clr r2                      ; filename length
tfnl    movb *r0+,r6                ; get a character
        dec *stack                  ; decrement string length
        ci r6,' '*256               ; space?
        jeq wfnlb                   ; jump if yes
        movb r6,*r1+                ; otherwise copy the byte
        inc r2                      ; increment length count
        jmp tfnl                    ; and repeat
    ; write filename length byte...
wfnlb   swpb r2                     ; get length in high byte
        movb r2,@11(r10)            ; move length byte into length byte position
    ; process file options...
fdochr  movb *r0+,r6                ; get a character
        dec *stack                  ; end of string?
        jlt fdone                   ; jump if yes
        ci r6,' '*256               ; is it a space?
        jeq fdochr                  ; if yes then ignore it
        ci r6,'9'*256               ; found a digit?
        jle fdodig                  ; if so then do digit
    ; the option is a character.
    ; process it against the allowed list of characters
        li r7,foopts                ; pointer to options list
        li r13,10                   ; 10 options in the list
fnxtop  cb r6,*r7                   ; compare a character
        jeq ffopt                   ; jump if match detected
        inc r7                      ; move to next charater in list
        dec r13                     ; decrement count
        jne fnxtop                  ; check next option
        jmp fdochr                  ; check next character
    ; process numeric digit
fdodig  mov r8,r9                   ; copy accumulator
        sla r8,3                    ; multiply accumulator by 8
        sla r9,1                    ; multiply copy by 2
        a r9,r8                     ; add them - we just did a multiply by 10
        ; (MPY needs consecutive registers, and sometimes its just too much 
        ; like hard work, know what I mean?)
        srl r6,8                    ; shift byte into low byte
        ai r6,-48                   ; remove ascii offset
        a r6,r8                     ; add to accumulator
        clr r6                      ; byte ops
        jmp fdochr                  ; process next character
    ; set file option...
ffopt   ai r7,-20                   ; point to appropriate mask byte (the bits
                                    ; to reset)
        movb @3(r10),r1             ; get flag byte from PAB
        szcb *r7,r1                 ; reset appropriate bit(s)
        ai r7,10                    ; point to bits table (the bits to set)
        socb *r7,r1                 ; set appropriate bit(s)
        movb r1,@3(r10)             ; write it back
        ai r7,10                    ; restore pointer
        jmp fdochr                  ; process next character in the string
fdone   swpb r8                     ; get record length in msb
        movb r8,@6(r10)             ; move it into the pab
    ;    dect stack                  ; pop length
    ;    dect stack                  ; pop address
        c *stack+,*stack+           ; pop length & address
        jmp _fcxit

fomask  byte >10,>10                ; F & V mask
        byte >08,>08                ; D & I mask
        byte >06,>06,>06,>06        ; U O I & A masks
        byte >01,>01                ; S & R masks
        
bitmsk  byte >00,>10                ; F & V bits
        byte >00,>08                ; D & I bits
        byte >00,>02,>04,>06        ; U O I & A bits
        byte >00,>01                ; S & R bits
foopts  text 'FVDLUOIASR'           ; file options (L=internaL)


; #OPEN ( file_addr -- t|f )
; Opens a file with the file name and attributes specified in the buffer 
; starting at file_addr.
; The buffer (actually a PAB) is set-up with FILE.
; E.g. FBUF: SERIAL
;      S" RS232.BA=9600 DV80SO" SERIAL FILE
;      SERIAL #OPEN
; The above shall attempt to open the serial port for output as a Display 
; Variable 80 type file. 
;
; #OPEN leaves a FALSE on the stack if the file was opened sucessfully. 
; If the file could not be opened then it leaves a TRUE on the stack. 
; This allows easy trapping with ABORT" as shown below: 
; SERIAL #OPEN ABORT" Could not open serial port"
;
; In the event of a file error, IOERR can be read to get the DSR error code. 
; If IOERR returns -1 (>FFFF) then this means that no free file IO slots were 
; found. A maximum of 3 open files is supported (2 if block files are also to 
; be used). Note that block files are immediately closed after they are accessed
; for either reading or writing, so 3 generic file io streams are available
; when no blocks files are being used.

    ; find a free file slot...
_fopen  li r0,falloc                ; address of file allocation table
        li r2,3                     ; three slots
nxtslt  mov *r0,r1                  ; first slot address
        jgt foend                   ; if msb is not set then the slot is empty
        inct r0                     ; otherwise move to next slot address
        dec r2                      ; and try it
        jne nxtslt
    ; no free slots... sorry, no can do...
        seto @errnum                ; set ioerr to -1 (no available files)
        seto *stack                 ; leave a TRUE on the stack
        b @retB0
    ; ok, the slot is free...
foend   mov *stack,r10              ; cpu pab address
        mov r1,*r10                 ; store vdp address of the free PAB in word
                                    ; 0 of CPU RAM PAB
        mov r1,r2                   ; copy the vdp address
        ori r2,>8000                ; set its most-sig bit to indicate this slot
                                    ; is in use
        mov r2,*r0                  ; write it back falloc table
        ai r1,40                    ; record buffer in vdp is 40 bytes after PAB
        mov r1,@4(r10)              ; store it in bytes 2 & 3 of the PAB
        ai r1,-40                   ; restore r1 to point to PAB address in VDP
    ; transfer the PAB in CPU RAM to the appropriate place in VDP
        mov r1,r0                   ; get in r0 for VMBW
        mov r0,r8                   ; keep a copy
        mov r10,r1                  ; source address
        inct r1                     ; move past word 0 in CPU PAB (vdp address 
                                    ; pointer)
        li r2,40                    ; byte count
        bl @_vmbw0                  ; write it to VDP
        ai r8,9                     ; adjust vdp address copy to point to 
                                    ; filename length byte
        mov r8,@namptr              ; store in >8356 as per DSR requirements
        blwp @dsrlnk                ; call dos
        data 8                      ; disk op parameter, level 3 command    
        jeq _foerr                  ; jump if an error
        clr *stack                  ; set top of stack to FALSE (success)
        clr @errnum                 ; clear io error
        jmp fexit
    ; the file could not be opened
_foerr  srl r0,8                    ; move error code to lower byte
        mov r0,@errnum              ; set disk io error number
        seto *stack                 ; set true flag (failure)
        jmp fexit


; #CLOSE ( fid -- )
; closes a file
; Where a file is opened thus: S" DSK1.README DV80IS" #OPEN MYFILE
; the following will close the same file: MYFILE #CLOSE
_fclos  bl @dodcmd
        data close*256
    ; now reset the pab pointer in the file allocation table...
    ; r13 holds the vdp address of the start of the pab
        li r1,falloc                ; address of file allocation table
        li r2,3                     ; 3 entries in the table
_fclop  mov *r1,r6                  ; get an entry
        andi r6,>7fff               ; remove msb
        c r6,r13                    ; found the entry?
        jeq _fcfnd                  ; jump if yes
        inct r1                     ; try next word
        dec r2                      ; decrement counter
        jne _fclop                  ; repeat if not finished
_fcxit  jmp fexit
_fcfnd  mov r13,*r1                 ; move address (with msb reset) back into 
                                    ; file allocation table
        jmp _fcxit


; #GET ( buff_addr fid -- t|f )
; reads a line of input from the file specified by fid. 
; The address of an appropriately sized buffer must be supplied. 
; If the read is successful, the buffer is filled with the data read from the
; input device, with the first cell being the length count of the data 
; immediately following it.
; This can be converted into a address/length pair with COUNT.
; Returns:
;  False if successful
;  True if not successful
; This allows trapping with ABORT" as follows:
; <address> MYFILE #GET ABORT" Could not read from the file"
; If the read fails, IOERR is set to the error code, otherwise it is zero'd
_fget    bl @dodcmd                 ; read from disk
        data read*256
        jeq _fgerr                  ; jump if error
        ; r13 holds the vdp address of the start of the pab
        mov r13,r0                  ; transfer to r0 for vdp access
        ai r0,5                     ; point to character count
        bl @_vsbr                   ; read the length of the returned record
        mov *stack,r9               ; get cpu ram buffer address from stack
        movb r1,*r9+                ; move length of record to the buffer
        movb r1,r2                  ; copy length byte to r2 for vdp counter in 
                                    ; vmbr
        srl r2,8                    ; move length byte to low byte of r2
        jeq recln0                  ; jump if the record read had a length of 0
        mov r13,r0                  ; start of pab
        ai r0,40                    ; point to associated data buffer
        mov r9,r1                   ; cpu ram buffer address
        bl @_vmbr                   ; transfer from the buffer in vdp to the 
                                    ; buffer in CPU
recln0  clr *stack                  ; place false on stack (succeeded)
_fgxit  jmp fexit
    ; an error occurred
_fgerr  srl r0,8                    ; move error code to lower byte
        mov r0,@errnum              ; set disk io error number
        seto *stack                 ; set stack to true (failed)
        ; fall down into fexit...




fexit   bl @rstsp                   ; restore code in scratchpad
                                    ; (destroyed by DSR access)
        b @retB0



; #PUT ( buff_addr len  fid - t|f )
; Places a string from buffer_addr with length len to the file represented by 
; fid. 
; Returns false if successful, else returns true. 
; This can be trapped with ABORT"
_fput   mov *stack,r0               ; get fid
        mov *r0,r0                  ; get vdp pab address
        mov @2(stack),r1            ; get length from stack
        swpb r1                     ; move to high byte
        ai r0,5                     ; point to length byte in pab
        bl @_vsbw0                  ; write the length byte to the pab
        mov @blknum,r6              ; processing a block?
        jne _fpvdp                  ; if so then the data we want to write is 
                                    ; aleady in vdp
        ai r0,-3                    ; else back up to point data buffer address
        mov *stack,r1               ; pointer to vdp pab address in r1
        mov *r1,r1                  ; get the vdp pab address
        ai r1,40                    ; compute vdp buffer address(pab address+40)
        bl @_vsbw0                  ; write msb of address
        inc r0                      ; advance vdp address
        swpb r1                     ; get lsb
        bl @_vsbw0                  ; write it
_fp1    mov *stack,r0               ; get vdp address of pab again
        mov *r0,r0                  ; get vdp pab address
        ai r0,40                    ; point to record buffer
        mov @2(stack),r2            ; length
        mov @4(stack),r1            ; cpu source address
        bl @_vmbw0                  ; write to vdp
_fp2    bl @dodcmd
        data write*256
        jeq _fperr                  ; jump if error
        inct stack                  ; pop length
        clr *stack                  ; success
_fpxit  jmp fexit
_fperr  inct stack                  ; pop length
        seto *stack                 ; failed
        jmp _fpxit
_fpvdp  mov *stack,r0               ; vdp address of pab in r0
        mov *r0,r0                  ; get vdp pab address
        ai r0,2                     ; point to data buffer address
        mov @-4(stack),r1           ; buffer address
        bl @_vsbw0                  ; write msb of address
        inc r0                      ; advance vdp address
        swpb r1                     ; get lsb
        bl @_vsbw0                  ; write it
        jmp _fp2


; #REC ( record# fid -- )
; Sets the record number for reading or writing for relative files
_frec   mov *stack+,r0              ; get fid
        mov *r0,r0                  ; get vdp address of associated pab
        ai r0,6                     ; point to record number in vdp
        movb *stack+,r1             ; get record number high byte
        bl @_vsbw0                  ; write it
        inc r0                      ; point to record# low byte in pab
        movb *stack+,r1             ; get low byte of record number
        bl @_vsbw0                  ; write it
        b @retB0



; #EOF? ( fid -- t|f )
; returns true if currently positioned at the end of the file referenced by fid
_feof   bl @dodcmd
        data status*256
        mov r13,r0                  ; vdp address of pab to r0
        ai r0,8                     ; point to screen offset byte (where status
                                    ; is stored)
        bl @_vsbr                   ; read the byte
        andi r1,>0100               ; isolate bit 7 (eof bit)
        sla r1,7                    ; move bit to bit 0 (msb)
        sra r1,15                   ; shift it back to lsb
    ; at this point, if bit 7 was 0 then r1 is 0000000000000000(2) (i.e. false)
    ; if bit 7 was 1 then r1 is 1111111111111111(2) (i.e. true)
        dect stack                  ; make space on stack (dodcmd pops the fid)
        mov r1,*stack               ; move to stack
        jmp fexit


;
_opt5   ; addr len size loadAddr opcode
        ; build a PAB in CPU ram
        mov @here,r0                ; get here
        mov r0,r8                   ; save a copy 
        clr r2
        mov *stack+,r1              ; opcode 
        mov r1,*r0+                 ; to here       0 1
        mov *stack+,*r0+            ; loadAddr      2 3
        mov r2,*r0+                 ; not used      4 5
        mov *stack+,*r0+            ; size of file  6 7
        mov *stack+,r7              ; get length of filename
        mov r7,*r0+                 ; to pab        8 9
        li r0,>37b8                 ; vdp address of pab
        mov r8,r1                   ; cpu source address
        li r2,10                    ; 10 bytes
        bl @_vmbw0                  ; write to vdp
        ; now write filename to vdp
        li r0,>37b8+10              ; destination address in vdp 
        mov *stack+,r1              ; address of filename 
        mov r7,r2                   ; length of filename
        bl @_vmbw0                  ; write it
        li r0,>37b8+9               ; address of length byte
        mov r0,@>8356               ; ...to >8356
        
        blwp @dsrlnk                ; witchcraft and wizardry
        data 8                      ; standard file access 
        bl @rstsp                   ; restore scratchpad
        b @retB0                    ; see ya 

        
        
        

; Do Disk Command subroutine - executes the disk command passed by the caller
dodcmd  mov *r11+,r1                ; get opcode
        mov r11,r14                 ; save return address
        mov *stack+,r0              ; get pointer to cpu ram pab
        mov *r0,r0                  ; get vdp address of the pab
        mov r0,r13                  ; copy it (used by #CLOSE, #PUT, #EOF etc)
docmd1  bl @_vsbw                   ; write the op-code to the pab
    ; clear bits 0, 1 & 2 of byte 1 of the PAB...
        inc r0                      ; move to byte 1 of the pab
        bl @_vsbr                   ; read it
        andi r1,>1f00               ; reset bits 0,1 & 2
        bl @_vsbw                   ; write it back
        ai r0,8                     ; point to filename length byte
        mov r0,@namptr              ; load >8356 with pointer to name length as
                                    ; per DSR requirements
    ; call the DSR...
        blwp @dsrlnk
        data 8
        b *r14                      ; return to caller


; close all open files
; called by abort in bank 0
_clall  li r6,6                     ; offset into file allocation table, and 
                                    ; also counter
_ca1    mov @falloc(r6),r0          ; get address of PAB in vdp from file 
                                    ; allocation table
        mov r0,r7                   ; copy it
        andi r7,>8000               ; check 'in-use' bit
        jeq _cart                   ; skip if the entry in the table isn't 
                                    ; open/in-use
        andi r0,>7fff               ; reset 'in-use' bit
        mov r0,@falloc(r6)          ; write it back to the file allocation table
        li r14,_cart                ; make #CLOSE return to us ;-)
        li r1,close*256             ; close opcode for #CLOSE
        jmp docmd1                  ; borrow part of the DODCMD routine to do
                                    ; the work for us ;-)
_cart   dect r6                     ; decrement counter
        ci r6,-2                    ; finished?
        jne _ca1                    ; close next file if not
        b @fexit

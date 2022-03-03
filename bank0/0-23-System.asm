;  ____         __  __                                _ 
; |  _ \       / _|/ _|                              | |
; | |_) |_   _| |_| |_ ___ _ __ ___    __ _ _ __   __| |
; |  _ <| | | |  _|  _/ _ \ '__/ __|  / _` | '_ \ / _` |
; | |_) | |_| | | | ||  __/ |  \__ \ | (_| | | | | (_| |
; |____/ \__,_|_| |_| \___|_|  |___/  \__,_|_| |_|\__,_|
;     __      __         _       _     _          
;     \ \    / /        (_)     | |   | |         
;      \ \  / /__ _ _ __ _  __ _| |__ | | ___ ___ 
;       \ \/ // _` | '__| |/ _` | '_ \| |/ _ | __|
;        \  /| (_| | |  | | (_| | |_) | |  __|__ \
;         \/  \__,_|_|  |_|\__,_|_.__/|_|\___|___/

endB0   equ $       ; end of bank 0 marker

        dorg >a000
        ; note: during initialisation, GPLLNK uses >A000 to >A01F as workspace
        ; to load the upper case characters from console GROM. After this, 
        ; the space is re-used.

; Vectors - the locations of these vectors MUST NOT change between builds
intvec  bss 2       ; vector for INTERPRET       >a000
blkvec  bss 2       ; vector for BLOCK           >a002
numvec  bss 2       ; vector for NUMBER          >a004
fndvec  bss 2       ; vector for FIND            >a006
usrisr  bss 2       ; vector for user isr        >a008
kdel    bss 2       ; keyboard auto-repeat delay >a00a
dsrvec  bss 2       ; pointer to DSRLNK vector in bank 1    >a00c
gplvec  bss 2       ; pointer to GPLLNK vector in bank 1    >a00e
padvec  bss 2       ; pointer to scratchpad restore code in bank 1. >a010
    ; Assembly language vector for returning to TF from external assembly code 
    ; that runs in a different workspace.
    ; External assembly code (for example, code written with the TF assembler) 
    ; that changes workspace can simply perform a BLWP @>A012 to restore TF's
    ; workspace and jump to NEXT in the inner interpreter, which will restore 
    ; normal Forth execution perfectly.
wp      bss 2       ; >a012 - workspace pointer.
                    ; software can actually change TF's workspace while running.
                    ; a copy of the desired workspace address MUST be written 
                    ; here so that KEY can restore the correct workspace address
                    ; after its call into the TI ROM.
                    
pnext   bss 2       ; >a014 pointer to next
pdocon  bss 2       ; >a016 pointer to DOCON's executable code
pcreate bss 2       ; >a018 pointer to CREATE's executable code
optvec  bss 2       ; vector for installable optimiser
    ; new vectors MUST be added here


; memory space pointers
ffailm  bss 2       ; >a01a first free address in low memory pointer
ffaihm  bss 2       ; >a01c first free address in hi memory pointer


; stack pointers
s0      bss 2       ; reserved for FORTH variable S0 - holds the address of the
                    ; start of the data stack (r4)
                    
rs0     bss 2       ; address of start of return stack (r5)


; screen, keyboard and file I/O
keydev  bss 2       ; keyboard device to use for KSCAN routine in console ROM 
cursrd  bss 2       ; cursor delay used in KEY and the editor
noscrl  bss 2       ; suppress screen scrolling. 0=suppress
scrX    bss 2       ; x co-ordinate of next character to be displayed on screen 
scrY    bss 2       ; y co-ordinate of next character to be displayed on screen
xmax    bss 2       ; screen width - 32, 40  or 80
ymax    bss 2       ; screen height - always 24
wrap    bss 2       ; used to determine if wrap-around is used by SCROLL
panxy   bss 2       ; starting screen address (top left) of panel
panr    bss 2       ; number of rows in panel
panc    bss 2       ; number of columns in panel
errnum  bss 2       ; holds io error number of last error


; speech synthesis
spcnt   bss 2       ; number of bytes remaining in speech buffer
spadr   bss 2       ; address of next byte in speech buffer
spcsvc  bss 2       ; speech service: address of the speech service which should
                    ; be called by the ISR is placed here. (either the routine
                    ; to stream raw speech data, or the routine to feed speech 
                    ; ROM addresses).
                    
synyes  bss 2       ; 0=speech synth not fitted. >FFFF=speech synth detected


; parsing/compilation
in      bss 2       ; holds the current index into the terminal input buffer 
                    ; (TIB) - used by variable >IN
                    
latest  bss 2       ; reserved for FORTH variable LATEST, which points to the 
                    ; most recently defined word in the dictionary.
                    
here    bss 2       ; points to the next free byte of memory. When compiling,
                    ; compiled words go HERE.
                    
_state  bss 2       ; is the interpreter interpreting (0) or compiling a word 
                    ; (!=0).
                    
tibsiz  bss 2       ; characters per line: 80 on command line, 64 in blocks
_span   bss 2       ; the number of characters received by EXPECT. 
                    ; See variable #TIB.
                    
doboot  bss 2       ; "we're booting" flag (>0=booting)
sdelim  bss 2       ; stores the end of string marker (normally ") for S". 
                    ; the word .( sets it temporarily to a ) character.
                    
isdbl   bss 2       ; flag to indicate if NUMBER pushed a double (>0=yes)
dpl     bss 2       ; decimal point location. set by NUMBER (doubles only)
cassen  bss 2       ; if 0 dictionary searches are case sensitive
source  bss 2       ; source-id. -1=string (via evaluate). 
                    ; 0=user input (keyboard/block).
                    
dotsin  bss 2       ; flag for .S to use signed or unsigned numbers
base    bss 2       ; the current base for printing and reading numbers
lbase   bss 2       ; last number base, used by Number to String routine
expcnt  bss 2       ; exponent count, used by Number to String routine
lzi     bss 2       ; leading zero indicator, used by N>S routine to determine 
                    ; if leading 0's are ignored.
                    
dosign  bss 2       ; flag for NTS routine. If >0, then NTS will treat numbers 
                    ; as unsigned, set by U. and .
                    
_warn   bss 2       ; redefinition warnings are suppressed if _warn=0
coding  bss 2       ; !0 if CODE: compiling is active
patch   bss 2       ; holds the CFA of latest word created with CREATE in case 
                    ; DOES> needs to patch it


; misc
vdpr1   bss 2       ; copy of vdp register 1 (stored at 83d4)
retbnk  bss 2       ; holds bank number to return to as a memory address
                    ; (>6000 or >6002)
temp    bss 2       ; for temporary storage
temp2   bss 2       ; for temporary storage
temp3   bss 2       ; for temporary storage
seed    bss 2       ; seed for random number generation
sumode  bss 2       ; graphics mode selected from cartridge menu screen 


; editor variables - only used by the built in editor
epage   bss 2   ; holds block editor page
; note: These variables use the same addresses as the compiler reference
; counters (below). This is safe to do, as the compiler is never in use when 
; the editor is in use, and vice versa. Hence it makes sense to use the same
; addresses and save some valuable user RAM in low-memory. I'm nice like that.
csrx    equ $       ; cursor x for editor
csry    equ $+2     ; cursor y for editor
csrflg  equ $+4     ; cursor blink flag for editor
autorp  equ $+6     ; keyboard auto repeat counter
autorl  equ $+8     ; keyboard auto repeat re-load value
edblk   equ $+10    ; block number of the block currently being edited


; reference counters for compiler security
; see the words : and ; in 0-10-Compilation.a99
ifcnt   bss 2       ; incremented by IF, decremented by THEN
docnt   bss 2       ; incremented by DO, decremented by LOOP & +LOOP
forcnt  bss 2       ; incremented by FOR, decremented by NEXT
cascnt  bss 2       ; incremented by CASE, decremented by ENDCASE
ofcnt   bss 2       ; incremented by OF, decremented by ENDOF
begcnt  bss 2       ; incremented by BEGIN, decremented by UNTIL, REPEAT & AGAIN


; sprite buffers
sal     bss 128     ; sprite attribute list
smlist  bss 64      ; sprite movement list


; Persistable data for file IO
sav8a   bss 2       ; save data following blwp @dsrlnk (8 or >a)
savcru  bss 2       ; cru address of the peripheral
savent  bss 2       ; entry address of dsr or subprogram
savlen  bss 2       ; device or subprogram name length
savpab  bss 2       ; pointer to device or subprogram in the pab
savver  bss 2       ; version # of dsr
flgptr  bss 2       ; pointer to flag in pab (byte 1 in pab)
dsrlws  bss 10      ; data 0,0,0,0,0	; dsrlnk workspace 
dstype  bss 22      ; data 0,0,0,0,0,0,0,0,0,0,0
haa     bss 2       ; used to store AA pattern for DSR ROM detection
namsto  bss 8       ; dsrlnk 8 bytes device name buffer


; scratch pab - used for block IO
pabopc  byte 0      ; opcode: open, read, etc
pabflg  byte 0      ; error code & file type
pabbuf  data 0      ; vdp address of data
pablrl  byte 0      ; logical record length
pabcc   byte 0      ; output character count
pabrec  data 0      ; record number
pabsco  byte 0      ; screen offset for char
pabnln  byte 0      ; name length
pabfil  bss 32      ; file name starts here
        even


; set up the pab pointers:
namptr  equ >8356   ; address of pointer to name length in PABs
f1pab   equ >1800   ; vdp address of 40 byte PAB buffer for file 1
f1buf   equ >1828   ; vdp address of 256 byte record buffer for file 1
f2pab   equ >1928   ; vdp address of 40 byte PAB buffer for file 2
f2buf   equ >1950   ; vdp address of 256 byte record buffer for file 2
f3pab   equ >1a50   ; vdp address of 40 byte PAB buffer for file 3
f3buf   equ >1a78   ; vdp address of 256 byte record buffer for file 3
pabloc  equ >1b78   ; vdp address of block IO PAB
recbuf  equ >1ba0   ; vdp address of data buffer. 128 bytes to store 1 record
bufadd  equ >1c20   ; vdp address of block buffer 0

falloc  bss 6       ; allocation table for file IO
; at run time, these 3 words are filled with addresses f1pab, f2pab & f3pab. 
; The MSB is set when a file is in use (i.e. when opened with #OPEN). 
; The MSB is reset when #CLOSE is executed, and thus the file 'slot' can be 
; re-used.


; block related data
    ; see 0-18-Blocks.a99
blocks  equ 6       ; number of block buffers
totblk  bss 2       ; number of block buffers available
blknum  bss 2       ; holds the block currently being compiled by INTERPRET
lstblk  bss 2       ; holds the block currently being worked on
blk0    bss 2       ; block number of the block stored in buf0 (0=unassigned)
        bss 2       ; VDP address of block0 MSB=1=dirty block
blk1    bss 2       ; block number of the block stored in buf1 (0=unassigned)
        bss 2       ; VDP address of block1  MSB=1=dirty block
blk2    bss 2       ; block number of the block stored in buf2 (0=unassigned)
        bss 2       ; VDP address of block2  MSB=1=dirty block
blk3    bss 2       ; block number of the block stored in buf3 (0=unassigned)
        bss 2       ; VDP address of block3  MSB=1=dirty block
blk4    bss 2       ; block number of the block stored in buf4 (0=unassigned)
        bss 2       ; VDP address of block4  MSB=1=dirty block
blk5    bss 2       ; block number of the block stored in buf5 (0=unassigned)
        bss 2       ; VDP address of block5  MSB=1=dirty block
                    ; note: the vdp addresses of the block buffers are defined in
                    ; 1-15-Initialise.a99


; stacks and buffers
    ; don't change the order of these buffers!
tibadr  bss 2       ; address of the terminal input buffer
tib     equ >3420   ; vdp address of terminal input buffer
wrdbuf  bss 82
wrkbuf  bss 32      ; work buffer for Number to String routine (holds exponents)
strbuf  bss 18      ; string buffer for Number to String routine to construct 
                    ; a string in


; data stack and return stack
stacks  bss 114         ; reserve space for data stack and return stack
retstk  equ stacks+54   ; return stack grows to lower addresses
dstack  equ $           ; data stack grows to lower addresses


; start of user memory... FORTH programs go here!
himem   equ $       ; first free address in hi memory
prgtop  equ himem   ; program space - user defined FORTH words start here
                    ; at startup, HERE points to prgtop


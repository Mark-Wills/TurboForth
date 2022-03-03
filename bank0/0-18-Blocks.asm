;  ____  _            _      _____     ______   __          __            _     
; |  _ \| |          | |    |_   _|   / / __ \  \ \        / /           | |    
; | |_) | | ___   ___| | __   | |    / / |  | |  \ \  /\  / /___  _ __ __| |___ 
; |  _ <| |/ _ \ / __| |/ /   | |   / /| |  | |   \ \/  \/ // _ \| '__/ _` / __|
; | |_) | | (_) | (__|   <   _| |_ / / | |__| |    \  /\  /| (_) | | | (_| \__ \
; |____/|_|\___/ \___|_|\_\ |_____/_/   \____/      \/  \/  \___/|_|  \__,_|___/
; block file system words & subroutines

; Notes:
;  Since File IO on the TI takes place in VDP RAM, the block system is
;  implemented using VDP ram to hold the blocks. In other words, blocks live
;  in VDP RAM, *not* CPU ram. Might as well use VDP for something and it has
;  the added benefit of leaving *lots* more CPU ram available for Forth code.
;
;  The 'system' is designed to support up to six blocks in VDP ram at once.
;  I.e. there are six 1K buffers in VDP, each buffer can hold any block.
;  The buffers are allocated in sequential order until they are used. When no
;  more buffers are available, a previously used buffer is used, it's contents
;  are overwritten. However, *if* the contents of a block have been changed
;  (i.e. they are more up-to-date than the copy on the disk) the block is
;  automatically flushed back to disk before being re-used.
;
;  The VDP addresses of the block buffers are defined in 1-15-Initialise.a99
;

; USE ( addr len -- )
; Tells the system which block file to use for block IO
; e.g. S" DSK1.BLOCKS" USE
; Simply sets the filename and length in the blockIO PAB
useh    data rtdath,3
        text 'USE '
use     data docol,mtbuf,use1,exit
use1    data $+2
        bl @bank1
        data _use               ; see 1-06-Blocks.a99


; WHERE ( -- block# )
; returns the block number of word that has been loaded into memory with LOAD
; eg: WHERE FOO 
; can only be used from the command line
; returns 0 if not found, or if the word is in ROM
whereh  data useh,immed+5
        text 'WHERE '
where   data docol,spword,find,zbrnch,where1
        data dfa,plus2,fetch,lit,4,rsft,lit,>3ff,and,plus1,exit
where1  data drop,lit0,exit


; BLK          -- addr                       U,79          "b-l-k" 
; The address of a variable containing the number of the mass storage block 
; being interpreted as the input stream.  
; If the value of BLK is zero the input stream is taken from the text input 
; buffer.  {{0..the number of blocks available -1}}
; See:  TIB  "input stream"
blkh    data whereh,3
        text 'BLK '
blk     data $+2
        li r6,blknum            ; address of block variable in ram
        b @dovar                ; push it


; --> ( -- )
; loads the next block
nblkh   data blkh,immed+3
        text '--> '
nblk    data docol
        data blk,fetch,plus1,blk,store,in_,store0
        data exit
      

; THRU ( start end -- )
; loads blocks start thru end inclusive by calling LOAD for each block.
thruh   data nblkh,4
        text 'THRU'
thru    data docol,plus1,swap
        data do,xthru
thrulp  data    geti,load
        data loop,thrulp
xthru   data exit
; : THRU ( start-block end-block -- ) 1+ SWAP DO I LOAD LOOP ;


; BLOCK        u -- vdpaddr                  M,83                 
; addr is the address of the assigned buffer of the first byte of block u.
; If the block occupying that buffer is not block u and has been UPDATEed it is
; transferred to mass storage before assigning the buffer.  
; If block u is not already in memory, it is transferred from mass storage into
; an assigned block buffer.  A block may not be assigned to more than one 
; buffer.  
; If u is not an available block number, an error condition exists.  
; Only data within the last buffer referenced by BLOCK or BUFFER is valid. 
; The contents of a block buffer must not be changed unless the change may be 
; transferred to mass storage.BLOCK ( block# -- addr )
;
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
blockh  data thruh,5
        text 'BLOCK '
block   data docol,lit,blkvec,fetch,execut,exit
block2  data $+2
        bl @bank1
        data _block             ; see 1-06-Blocks.a99


; LIST ( block# -- )
; lists a blocks' contents to the screen without loading it
listh   data blockh,4
        text 'LIST'
list_   data docol,fblock,dup,zbrnch,lstxit
        data lit,16,lit0
        data do,lstxit
list1   data cr,geti,lit,2,dotr
        data    lit,3,emit,dup,ghere,lit,64,fvmbr,ghere
        data    lit,64,trail,type,lit,64,add
        data loop,list1
lstxit  data drop,cr,blk,store0
        data lit,lstblk,store0,exit


; LOAD ( block# -- )
; interprets a block
loadh   data listh,4
        text 'LOAD'
load    data docol
        data in_,fetch,rspush
        data blk,fetch,rspush
        data span,fetch,rspush
        data lit,1024,span,store
        data in_,store0
        data blk,store 
        data interp
        data rspop,span,store
        data rspop,blk,store
        data rspop,in_,store
        data exit


fblock  ; ( blk# --)
        ; fetch block and strip off dirty bit
        data docol,block,lit,>7fff,and,exit 

; CLOAD ( blk -- )
; Conditionally loads a block if the referenced word (passed in the TIB) is 
; not found.
; e.g. 69 CLOAD SAMS? will load block 69 if the word SAMS? is not found.
; If the word *is* found then no further action is taken.
cloadh  data loadh,immed+5
        text 'CLOAD '
cload   data docol,spword,find,nip
        data zbrnch,cload1
        data drop,exit
cload1  data load,exit


; UPDATE       --                            79                   
; The currently valid block buffer is marked as modified. 
; Blocks marked as modified will subsequently be automatically transferred to 
; mass storage should its memory buffer be needed for storage of a different 
; block or upon execution of FLUSH.
updath  data cloadh,6
        text 'UPDATE'
update  data $+2
        bl @bank1
        data _updat             ; see 1-06-Blocks.a99


; FLUSH        --                            M,83                 
; Flushes all modified buffers to the storage device then unassigns all block 
; buffers.
flushh  data updath,5
        text 'FLUSH '
flush   data $+2
        bl @bank1
        data _flush             ; see 1-06-Blocks.a99


; EMPTY-BUFFERS ( -- )
; immediately sets all buffers to unsaasigned.
; DOES NOT flush dirty buffers to disk
mtbufh  data flushh,13
        text 'EMPTY-BUFFERS '
mtbuf   data $+2
        bl @bank1
        data _mtbuf             ; see 1-06-Blocks.a99


; CLEAN ( buffer -- )
; forces a buffers' status to clean
cleanh  data mtbufh,5
        text 'CLEAN '
bclean  data $+2
        bl @bank1
        data _clean             ; see 1-06-Blocks.a99

        
; DIRTY ( buffer -- )
; forces a buffers' status to dirty
dirtyh  data cleanh,5
        text 'DIRTY '
dirty   data $+2
        bl @bank1
        data _dirty             ; see 1-06-Blocks.a99


; DIRTY? ( buffer -- flag )
; interrogates a buffers' status, returning true if the buffer is dirty, else
; returning false
dirtih  data dirtyh,6
        text 'DIRTY?'
dirtyq  data $+2
        bl @bank1
        data _qdirt             ; see 1-06-Blocks.a99


; BLK? ( buffer -- block vdp_address )
; For a given buffer, returns the actual block stored in that buffer
; and the vdp address of that buffer
blkqh   data dirtih,4
        text 'BLK?'
blkq    data $+2
        bl @bank1
        data _blkq             ; see 1-06-Blocks.a99


; BUF? ( block -- buffer vdp_address )
; For a given block, return the buffer number, and the vdp address of the buffer
; returns 0 0 if the block is not in memory
bufh    data blkqh,4
        text 'BUF?'
buf     data $+2
        bl @bank1
        data _buf             ; see 1-06-Blocks.a99


; SETBLK ( buffer block -- )
; For a given buffer, changes the block that it is associated with. 
; Allows blocks to copied to other blocks, using FLUSH. 
; Blocks can also be copied to a different block file by changing the blocks 
; file (with USE) before using FLUSH.
setblh  data bufh,6
        text 'SETBLK'
setblk  data $+2
        bl @bank1
        data _setbk             ; see 1-06-Blocks.a99


; MKBLK ( block_count -- )
; makes a block file on disk.
; E.G. 80 MKBLOCK DSK1.BLOCKS
; The above creates an 80K file on disk 1 called BLOCKS.
; use IOERR to check success.
; IOERR contains 0 for success or the disk error code
mkblkh  data setblh,immed+5
        text 'MKBLK '
mkblk   data docol
        data spword                     ; get the filename
        data mkblkc,exit                ; branch to bank 1
mkblkc  data $+2
        bl @bank1
        data _mkblk                     ; see 1-06-Blocks.a99

    
; WriteHeader ( vdp_addr -- vdp_addr+8)
; : WRITE-HEADER ( vdp_addr -- vdp_addr+8)
;     $994A VW!  LATEST @ VW!  HERE VW!  3 PICK VW! ;
whead   data docol
        data lit,>994a,vdpww,lates_,fetch,vdpww,ghere,vdpww,lit,3,pick,vdpww
        data exit

vdpww   data docol ; V2! ( addr val -- addr+2 )
        data swpb_,swap,dup,nrot,dup2,vdpstr,plus1,swap,swpb_,swap,vdpstr,plus2
        data exit

        
; BSAVE ( start_address  start_block -- first_free_block)
; : BSAVE ( addr block - next_free_block)
;   OVER HERE SWAP -
;   BEGIN DUP 1008 > WHILE
;       OVER GBASD
;       WRITE-HEADER
;       3 PICK 1008 VMBW
;       1008 - ROT 1008 + -ROT SWAP 1+ SWAP  
;   REPEAT
;   SWAP DUP GBASD WRITE-HEADER 3 PICK 3 PICK VMBW
;   1+ NIP NIP FLUSH ;
bsaveh  data mkblkh,5
        text 'BSAVE '
bsave   data docol
        data over,ghere,swap,sub
bsave1  data dup,lit,1008,gt,zbrnch,bsave2
        data over,block,update
        data whead
        data lit,3,pick,lit,1008,fvmbw
        data lit,1008,sub,rot,lit,1008,add,nrot,swap,plus1,swap
        data branch,bsave1
bsave2  data swap,dup,block,update,whead,lit,3,pick,lit,3,pick,fvmbw
        data plus1,nip,nip,flush
        data exit


; BLOAD ( start_block -- )
; : BLOAD ( block -- next_free_block)
;   BEGIN DUP BLOCK DUP VW@ $994A = WHILE
;     2+ DUP VW@ LATEST !  2+ DUP VW@ H !  2+ DUP VW@ SWAP 2+ SWAP 
;     1008 VMBR 1+
;   REPEAT DROP ;
bloadh  data bsaveh,5
        text 'BLOAD '
        data docol
bload1  data dup,fblock,dup,vdprw,lit,>994a,eq,zbrnch,bload2
        data plus2,dup,vdprw,lates_,store
        data plus2,dup,vdprw,here_,store
        data plus2,dup,vdprw,swap,plus2,swap
        data lit,1008,fvmbr,plus1
        data branch,bload1
bload2  data drop
        data memptr         ; adjust ffaihm & ffailm as appropriate 
        data exit 
memptr  data $+2
        mov @here,r0
        bl @bank1
        data mpadj          ; see 1-09-Compilation.a99
        b *next

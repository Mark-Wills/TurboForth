;  ______                       __  __                                   
; |  ____|                     |  \/  |                                  
; | |__   _ __ _ __ ___  _ __  | \  / | ___ ___ ___  __ _  __ _  ___ ___ 
; |  __| | '__| '__/ _ \| '__| | |\/| |/ _ | __/ __|/ _` |/ _` |/ _ | __|
; | |____| |  | | | (_) | |    | |  | |  __|__ \__ \ (_| | (_| |  __|__ \
; |______|_|  |_|  \___/|_|    |_|  |_|\___|___/___/\__,_|\__, |\___|___/
; Error reporting routines                                 __/ |         
;                                                         |___/          


    ; word not found error, used by INTERPRET
nferr   data docol,toterm,nftxt            ; echo 'not found'
        data lit1,colnam    ; report name of colon definition if in a colon 
                            ; definition
        data exit

        
    ; type the word 'Unbalanced ' to the terminal... used by ;
unbal   data docol,toterm,baltxt,exit


    ; warning message. issued when a word is re-defined. used by ;
rdferr  data docol,warn,fetch,zbrnch,rdfer1
        data cr,toterm,rdftxt,lit0,colnam  ; issue warning
rdfer1  data exit




    ; if we are in a colon definition (state!=0) then echo the name of the 
    ; colon definition (via LATEST), else skip.
colnam  data docol
        data lit,_state,fetch,zbrnch,errxit
        data zbrnch,colnm1
        data toterm,intxt
colnm1  data lit,latest,fetch       ; get latest
        data plus2                  ; move to length word
        data dup,fetch              ; copy address, and fetch length
        data lit,>f,and             ; get length only
        data swap,plus2             ; compute address of word text
        data swap,type,space1       ; type the name to the terminal

errxit  ; reports block number if loading...
        data blk,fetch,zbrnch,repxit
        data toterm,blctxt,lit,lstblk,fetch,udot
        data cr,toterm,linnum,in_,fetch,lit,64,sdiv,dot
repxit  data exit


    ; writes "ERROR:" used by all error routines
error   data docol,cr
        data toterm,errtxt        ; write ERROR:
        data exit

nobootm data docol,cr,lit,pabfil,lit,pabnln,chrftc,type
        data toterm,nftxt,lit,doboot,store0,ab0rt
        
        
    ; text for the various error types trapped by ;...
iferr   byte 7 
        text 'IF/THEN'
        
doertx  byte 9
        text 'FOR or DO'
        
castxt  byte 12 
        text 'CASE/ENDCASE'
        
oftxt   byte 8
        text 'OF/ENDOF'
        
begtxt  byte 5
        text 'BEGIN'


    ; general error text...
rdftxt  byte 10
        text 'Redefined '
        
errtxt  byte 6
        byte 69+96,82+96,82+96,79+96,82+96,58+96 ; ERROR: in inverse video
        
baltxt  byte 11 
        text 'Unbalanced '
        
nftxt   byte 10 
        text ' not found' 
        
intxt   byte 4 
        text ' in '
        
stktxt  byte 10 
        text 'Underflow!'
        
blctxt  byte 10 
        text ' in block '
        
linnum  byte 8 
        text 'on line '
        
blkmsg  byte 10
        text 'IO error #'
        

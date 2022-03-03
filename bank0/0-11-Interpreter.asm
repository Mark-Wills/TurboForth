;  ______         _   _       _____       _                            _             
; |  ____|       | | | |     |_   _|     | |                          | |            
; | |__ ___  _ __| |_| |__     | |  _ __ | |_  ___ _ __ _ __  _ __ ___| |_  ___ _ __ 
; |  __/ _ \| '__| __| '_ \    | | | '_ \| __|/ _ \ '__| '_ \| '__/ _ \ __|/ _ \ '__|
; | | | (_) | |  | |_| | | |  _| |_| | | | |_|  __/ |  | |_) | | |  __/ |_|  __/ |   
; |_|  \___/|_|   \__|_| |_| |_____|_| |_|\__|\___|_|  | .__/|_|  \___|\__|\___|_|   
; The interpreter/compiler                             | |                           
;                                                      |_|                           

; INTERPRET ( -- )
inth    data exeh,9                 ; points to execute in Compilation.a99
        text 'INTERPRET '
interp  data docol
        data lit,intvec,fetch,execut ; get the vector for INTERPRET and call it
        data exit

; standard, un-vectored INTERPRET
; (an alternative interpreter can be installed by patching address INTVEC 
; defined in 0-22.system.a99)
intgo   data docol
intlp   data spword                 ; (addr len) get a word from TIB
        data dup                    ; (addr len len)
        data zbrnch,ok              ; (addr len) if len is zero no identifiable
                                    ; word was found, or TIB is empty
    ; check the word identified by WORD, see if it's in the dictionary
        data dup2                   ; (addr len addr len)
        data find                   ; (addr len cfa flag) see if the word is in
                                    ; dictionary (flag=0 if not found)
        data dup                    ; (addr len cfa flag flag)
        data zbrnch,chknum          ; (addr len cfa flag) branch if not found
        
    ; the word was found in the dictionary.
    ; check STATE to see what to do with it.
        ; (addr len cfa flag)
        data lit,_state,fetch       ; (addr len cfa flag state)
        data zbrnch,state0          ; (addr len cfa flag) jump if interpreting
    
    ; we're in compile mode (state=1)
    ; compile the word, UNLESS the word is immediate
        data plus1                  ; (addr len cfa flag) flag=0 if not 
                                    ; immediate
        data zbrnch,nimm            ; (addr len cfa) jump if not immediate
        
    ; it's immediate - execute it
        ; (addr len cfa)
        data nip,nip                ; clean up stack
        data execut                 ; execute the word
        data branch,intlp           ; repeat

    ; we're interpreting. clean up stack and execute
        ; (addr len cfa flag)
state0  data drop,nip,nip           ; (cfa)
        data execut                 ; (--)
        data branch,intlp           ; repeat
    ; word is not immediate - compile it
        ; (addr len cfa)
nimm    data comma                  ; (addr len)
        data drop2                  ; (--)
        data branch,intlp           ; repeat

    ; no word found in dictionary, check to see if it's a number
    ; on entry: (addr len cfa flag)
chknum  data drop2                  ; (addr len)
        data dup2                   ; (addr len addr len)
        data number                 ; (addr len number ucc )
        data zbrnch,clean           ; (addr len number ) if ucc=0 then number is
                                    ; on the stack
                                    ; clean up stack & check rest of tib
        
    ; it's not a number or a word so we don't know what it is, error
ierr    data drop                   ; (addr len) drop double number
        data error                  ; type ERROR: to the screen        
        data type                   ; echo name of word
        data nferr                  ; issue not found error
        data cr,ab0rt

    ; WORD didn't find anything...
    ; on entry (addr len)
ok      data drop2                  ; (--) clean up addr & len
okx     data exit
        
        ; (addr len number )
        ; at this point the number is on the top of the stack.
        ; It may consist of one OR two words, depends if NUMBER returned a 
        ; double or not.
        ; location isdbl shall be non zero if a double was returned
        
clean   data lit,isdbl,fetch        ; double on the stack?
        data zbrnch,nodbl           ; jump if not
        data rot,drop,rot,drop      ; clean up and leave 32 bit number on stack
        data branch,clean1
nodbl   data nip,nip                ; clean up and leave 16 bit number on stack

; check for CODE: here...
        data lit,coding,fetch,zbrnch,nocode,comma
        
        
nocode
clean1  data lit,_state,fetch       ; ( number state ) get state
        data zbrnch,intlp           ; ( number ) if not compiling just leave on
                                    ; the stack
        data lit,isdbl,fetch,zbrnch,csing ; jump if not compiling a double
        data swap,clc               ; compile high word of double
csing   data clc                    ; ( ) compile a single or low word of double
        
intout  data branch,intlp

badblk  data lit,doboot,fetch
        data zbrnch,badbk1
        data nobootm                ; display no boot message and abort
badbk1  data cr,toterm,blkmsg
        data ioerr1,hexdot
noboot  data ab0rt


; STK? ( -- )
; checks stack for underflow, aborts if underflow, else does nothing
stkufh  data inth,4
        text 'STK?'
stkuf   data docol,depth,ltz,zbrnch,stkx
        data error,toterm,stktxt,cr,ab0rt
stkx    data exit


; FORGET       --                            M,83                 
; Used in the form:                     
;       FORGET <name>                 
; If <name> is found in the compilation vocabulary, delete <name> from the 
; dictionary and all words added to the dictionary after <name> regardless of 
; their vocabulary.
forgth  data stkufh,6
        text 'FORGET'
forget  data docol,spword,find,zbrnch,notfnd    ; find word cfa in dictionary
        data dfa,dup                            ; get dictionary entry address
        data fetch,lates_,store                 ; update latest
        data here_,store                        ; update H
        data align          ; force update of appropriate hi or low mem pointer
forg1   data ghere                              ; save HERE
        data ffaih,fetch,here_,store,align      ; force update of FFAIHM
        data ffaml,fetch,here_,store,align      ; force update of FFAILM
        data here_,store                        ; restore here
        data exit
notfnd  data drop,exit                          ; take no action if not found


; ABORT"       flag --                       C,I,83  "abort-quote" 
;                       --   (compiling)              
; Used in the form:                     
;       flag ABORT" ccc"              
; When later executed, if flag is true the characters ccc, delimited by " 
; (close-quote), are displayed and then a system dependent error abort sequence,
; including the function of ABORT , is performed.
; If flag is false, the flag is dropped and execution continues.
; The blank following ABORT" is not part of ccc.
aborth  data forgth,immed+6
abttxt  text 'ABORT"'
abort   data docol,string,compile,rot,compile,zbrnch,ghere,lit,4,add,comma
        data compile,abort_,compile,drop2,exit
abort_  data docol,type,cr,ab0rt


; ABORT                                      79                   
; Clears the data stack and performs the function of QUIT. 
; No message is displayed.
ab0rth  data aborth,5
        text 'ABORT '
ab0rt   data docol
        data cr,s0_,sps,lbrack,clsall
        data blk,store0             ; reset block to 0 in case we're loading
        data lit,lstblk,store0
        data lit,tib,tib_,store     ; reset address of terminal input buffer
        data in_,store0             ; set >IN to 0
        data lit,80,cpl,store       ; set 80 characters per line
        data lit,source,store0      ; reset EVALUATE source
        data quit                   ; call quit

clsall  data $+2
        bl @bank1                   ; close all open files
        data _clall                 ; see 1-14-File-IO.a99


; VTYPE ( vdp_addr len -- )
; types a string stored in vdp to the screen
; vtypeh  data ab0rth,5
;         text 'VTYPE '
; vtype   data docol,dup,nrot,pad,swap,fvmbr,pad,swap,type,exit


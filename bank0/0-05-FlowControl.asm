;  ______ _                  _____             _             _ 
; |  ____| |                / ____|           | |           | |
; | |__  | | _____      __ | |      ___  _ __ | |_ _ __ ___ | |
; |  __| | |/ _ \ \ /\ / / | |     / _ \| '_ \| __| '__/ _ \| |
; | |    | | (_) \ V  V /  | |____| (_) | | | | |_| | | (_) | |
; |_|    |_|\___/ \_/\_/    \_____|\___/|_| |_|\__|_|  \___/|_|
; Flow control words

; MARK & AHEAD: Utilities for flow control words
;   : MARK  ( -- addr) HERE 0 , ;
mark    data docol
        data ghere,lit0,comma
        data exit
        
;   : AHEAD  ( -- addr ) POSTPONE BRANCH  MARK ;  IMMEDIATE
ahead   data docol
        data compile,branch,mark
        data exit


; FOR ( loop_count -- )
; Implements FOR...NEXT looping as in COUNT FOR .. .. NEXT 
; I is available for retrieving the index. 
; : FOR ( start--) COMPILE LIT 0 , COMPILE SWAP [COMPILE] DO ; IMMEDIATE
forh    data gtezh,immed+3
        text 'FOR '
for     data docol
        data compile,lit0
        data compile,swap,do1
        data exit


; NEXT
; : NEXT ( --) COMPILE LIT -1 , [COMPILE] +LOOP ; IMMEDIATE
nexth   data forh,immed+4
        text 'NEXT'
fnext1  data docol
        data litm1,clc,ploop1
        data exit


;   : IF ( -- addr )    POSTPONE ?BRANCH  MARK ;  IMMEDIATE
; IF           flag --                       C,I,79               
;                       -- sys   (compiling)
; Used in the form:                     
;        flag IF ... ELSE ... THEN     
; or     flag IF ... THEN              
; If flag is true, the words following IF are executed and the words following 
; ELSE until just after THEN are skipped.  The ELSE part is optional.                
; If flag is false, the words from IF through ELSE , or from IF through THEN 
; (when no ELSE is used), are skipped.  
; sys is balanced with its corresponding ELSE or THEN .  
; See:  "9.9 Control Structures"
ifh     data nexth,immed+2
        text 'IF'
if      data docol
        data lit,ifcnt,refup
        data compile,zbrnch,mark
        data exit
               

;   : THEN  HERE SWAP ! ;  IMMEDIATE
; THEN         --                            C,I,79               
;             sys --   (compiling)
; Used in the form:                     
;       flag IF ... ELSE ... THEN     
; or    flag IF ... THEN              
; THEN is the point where execution continues after ELSE , or IF when no ELSE 
; is present.  
; sys is balanced with its corresponding IF or ELSE .  See:  IF  ELSE
thenh   data ifh,immed+4
        text 'THEN'
then    data docol
        data lit,ifcnt,refdn
        data ghere,swap,store
        data exit


;   : ELSE  POSTPONE AHEAD  SWAP  POSTPONE THEN ;  IMMEDIATE
; ELSE         --                            C,I,79               
;            sys1 -- sys2   (compiling)    
; Used in the form:                     
;       flag IF ... ELSE ... THEN     
; ELSE executes after the true part following IF .  ELSE forces execution to 
; continue at just after THEN .  sys1 is balanced with its corresponding IF .
; sys2 is balanced with its corresponding THEN .  See:  IF  THEN
elseh   data thenh,immed+4
        text 'ELSE'
else    data docol
        data ahead,swap,ghere,swap,store
        data exit


; BRANCH ( -- )
; unconditional branch: e.g: BRANCH 4 will branch forwards four words.
; Negative offsets supported.
brnchh  data elseh,6
        text 'BRANCH'
branch  data $+2
        ; at entry, R3 is pointing at the branch address...
        mov *pc,pc              ; get the in-line address and move to the
        b *next                 ; instruction pointer
        

        
; 0BRANCH ( flag -- )
; Branch if data on the stack is 0. e.g: 0BRANCH 4 will branch forwards 4
; bytes if the value on the data stack is 0
zbrchh  data brnchh,7
        text '0BRANCH '
zbrnch  data _zbrnch            ; code is in high-speed ram.
                                ; see 1-15-Initialise.a99


; CASE..OF..ENDCASE ( -- )
; Part of CASE..OF..ENDCASE
; CASE
caseh   data zbrchh,immed+4
        text 'CASE'
case    data docol
        data lit,cascnt,refup   ; reference count
        data lit0
        data exit

; OF
ofh     data caseh,immed+2
        text 'OF'
of      data docol
        data lit,ofcnt,refup
        data compile,over,compile,eq,if,compile,drop
        data exit

; ENDOF
endofh  data ofh,immed+5
        text 'ENDOF '
endof   data docol
        data lit,ofcnt,refdn,else
        data exit

; ENDCASE
endcah  data endofh,immed+7
        text 'ENDCASE '
endcas  data docol
        data lit,cascnt,refdn   ; reference count
        data compile,drop,qdup,zbrnch,$+8,then,branch,$-10
        data exit


;   : BEGIN  HERE ; IMMEDIATE \ synonym purely for readability
; BEGIN        --                            C,I,79               
;                 -- sys   (compiling)          
; Used in the form:                     
;       BEGIN ... flag UNTIL          
; or    BEGIN ... flag WHILE ... REPEAT                    
; BEGIN marks the start of a word sequence for repetitive execution.  
; A BEGIN-UNTIL loop will be repeated until flag is true.  
; A BEGIN-WHILE-REPEAT will be repeated until flag is false.
; The words after UNTIL or REPEAT will be executed when either loop is finished.
; sys is balanced with its corresponding UNTIL or WHILE .  
; See:  "9.9 Control Structures"
beginh  data endcah,immed+5
        text 'BEGIN '
begin   data docol
        data lit,begcnt,refup
        data ghere
        data exit


;   : UNTIL  POSTPONE ?BRANCH , ;  IMMEDIATE
; UNTIL ( address -- )
untilh  data beginh,immed+5
        text 'UNTIL '
until   data docol
        data lit,begcnt,refdn
        data compile,zbrnch,comma
        data exit


;   : AGAIN  POSTPONE BRANCH , ; IMMEDIATE
; AGAIN ( address -- )
againh  data untilh,immed+5
        text 'AGAIN '
again   data docol
        data lit,begcnt,refdn
        data compile,branch,comma
        data exit


;   : WHILE  POSTPONE IF  SWAP ; IMMEDIATE
; WHILE        flag --                       C,I,79               
;                  sys1 -- sys2   (compiling)    
; Used in the form:                     
;       BEGIN ... flag WHILE ... REPEAT                    
; Selects conditional execution based on flag.  When flag is true, execution 
; continues to just after the WHILE through to the REPEAT which then continues
; execution back to just after the BEGIN.  
; When flag is false, execution continues to just after the REPEAT, exiting the
; control structure.
; sys1 is balanced with its corresponding BEGIN.
; sys2 is balanced with its corresponding REPEAT.  See:  BEGIN
whileh  data againh,immed+5
        text 'WHILE '
while   data docol
        data if,swap
        data exit


;   : REPEAT  POSTPONE AGAIN  POSTPONE THEN ; IMMEDIATE
; REPEAT       --                            C,I,79               
;             sys --   (compiling)          
; Used in the form:                     
;       BEGIN ... flag WHILE ... REPEAT                    
; At execution time, REPEAT continues execution to just after the corresponding
; BEGIN.  
; sys is balanced with its corresponding WHILE.  See:  BEGIN
repeth  data whileh,immed+6
        text 'REPEAT'
repeat  data docol
        data again,then
        data exit


; DO           w1 w2 --                      C,I,83               
;                        -- sys   (compiling)          
; Used in the form:                     
;       DO ... LOOP                   
; or    DO ... +LOOP                  
; Begins a loop which terminates based on control parameters.
; The loop index begins at w2, and terminates based on the limit w1.
; See LOOP and +LOOP for details on how the loop is terminated.
; The loop is always executed at least once.  
; For example: w DUP DO ... LOOP executes 65,536 times.  
; sys is balanced with its corresponding LOOP or +LOOP .  
; See:  "9.9 Control Structures"
; note: DO is immediate and compiles a reference to (DO)
;
; Loop frame format:
;  0 = current loop index   <----- RSTACK points to this value
; +2 = loop limit
; +4 = loop exit address
; To drop a loop frame, add 6 to RSTACK
;
; In words, for A B DO ... LOOP
; (DO) puts three things on to the return stack
; 1. the address of the word after LOOP - where execution continues when
; the loop executes
; 2. A + >8000  (A with its sign bit 'permuted')
; 3. B minus the value computed at step 2 <-- top of return stack
; 
; LOOP and +LOOP add 1 or whatever to the value at 3.
; If the overflow flag is set, drop two elements from the return stack, 
; pop the final value from R (the address at 1. above)
; into I and execute next.
; 
; I becomes:
; 4.  Move the value at 2. above to the data stack
; 5.  Add the value at 3. above to the data stack
;
do1h    data repeth,immed+2
        text 'DO'
do1     data docol
        data lit,docnt,refup    ; increase reference counters
        data compile,do,ghere,lit0,comma ; compile (do) here 0 ,
        data exit

doh     data do1h,4
        text '(DO)'
do      data $+2
        mov *stack+,r0          ; pop initial index
        mov *stack+,r1          ; pop loop termination value
        ai r1,>8000             ; flip sign bit
        s r1,r0                 ; calculate initial index
        dect rstack             ; new return stack entry
        mov *pc+,*rstack        ; loop exit address to return stack
        dect rstack             ; new return stack entry
        mov r1,*rstack          ; loop limit to return stack
        dect rstack             ; new return stack entry
        mov r0,*rstack          ; loop index to return stack
        b *next


; LOOP         --                            C,I,83               
;             sys --   (compiling)          
; Increments the DO-LOOP index by one.  If the new index was incremented across
; the boundary between limit-1 and limit the loop is terminated and loop control
; parameters are discarded.  When the loop is not terminated, execution 
; continues to just after the corresponding DO.  
; sys is balanced with its corresponding DO .  See:  DO
; note: LOOP is immediate and compiles a reference to (LOOP)
loop1h  data doh,immed+4
        text 'LOOP'
loop1   data docol
        data lit,docnt,refdn    ; reduce DO/LOOP reference counters
        data dup,compile,loop
loop2   data ghere,plus2,swap,store,plus2,comma
        data exit

looph   data loop1h,6
        text '(LOOP)'
loop    data $+2
        inc *rstack             ; increment loop count
loopchk jno lagain              ; if no overflow then loop again
loopx   ai rstack,6             ; otherwise pop loop frame
        inct pc                 ; move past (LOOP)'s in-line parameter
        b *next
lagain  mov *pc,pc              ; reload loop address
        b *next


; +LOOP        n --                          C,I,83    "plus-loop" 
;               sys --   (compiling)          
; n is added to the loop index.  If the new index was incremented across the
; boundary between limit-1 and limit then the loop is terminated and loop 
; control parameters are discarded.  When the loop is not terminated, execution
; continues to just after the corresponding DO.
; sys is balanced with its corresponding DO.  See:  DO
; note: +LOOP is immediate and compiles a reference to (+LOOP)
plooh1  data looph,immed+5
        text '+LOOP '
ploop1  data docol
        data lit,docnt,refdn
        data dup,compile,ploop,branch,loop2   ; compile (+LOOP) then as (LOOP)

plooph  data plooh1,7
        text '(+LOOP) '
ploop   data $+2
        a *stack+,*rstack       ; pop increment and add to index on return stack
        jmp loopchk


; LEAVE        --                            C,I,83               
;                 --   (compiling)              
; Transfers execution to just beyond the next LOOP or +LOOP .
; The loop is terminated and loop control parameters are discarded.  
; May only be used in the form:                  
;       DO ... LEAVE ... LOOP         
; or    DO ... LEAVE ... +LOOP        
; LEAVE may appear within other control structures which are nested within the 
; do-loop structure.  More than one LEAVE may appear within a do-loop.  
; See:  "9.3 Return Stack"
; Note: LEAVE *must* appear within an IF ... THEN block for correct operation.
leaveh  data plooph,5
        text 'LEAVE '
leave   data $+2
        mov @4(rstack),pc       ; load pc with exit address
        ai rstack,6             ; pop loop frame from return stack
        b *next


; I            -- w                          C,79                 
; w is a copy of the loop index.  May only be used in the
; form:   
;       DO ... I ... LOOP             
; or    DO ... I ... +LOOP
; or    FOR .. I ... NEXT
getih   data leaveh,1
        text 'I '
geti    data $+2
        dect stack              ; new data stack entry
        mov @2(rstack),*stack   ; place index on data stack        
        a *rstack,*stack        ; adjust
        b *next


; J            -- w                          C,79                 
; w is a copy of the index of the next outer loop.
; May only be used within a nested DO-LOOP or DO-+LOOP in the form, for example:                              
; DO ... DO ... J ... LOOP ... +LOOP
; Also active in nested FOR...NEXT loops.
getjh   data getih,1
        text 'J '
getj    data $+2
        dect stack              ; new data stack entry
        mov @8(rstack),*stack   ; place outer loop index on data stack
        a @6(rstack),*stack     ; adjust
        b *next


; utility routines for reference counting
refup   data $+2
        mov *stack+,r0          ; pop address of reference counter
        inc *r0                 ; increase reference counter
        b *next
        
refdn   data $+2
        mov *stack+,r0          ; pop address of reference of counter
        dec *r0                 ; decrease reference counter
        b *next


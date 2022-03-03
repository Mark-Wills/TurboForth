;   _____                       _ _ _              __          __            _     
;  / ____|                     (_) (_)             \ \        / /           | |    
; | |      ___  _ __ ___  _ __  _| |_ _ __   __ _   \ \  /\  / /___  _ __ __| |___ 
; | |     / _ \| '_ ` _ \| '_ \| | | | '_ \ / _` |   \ \/  \/ // _ \| '__/ _` / __|
; | |____| (_) | | | | | | |_) | | | | | | | (_| |    \  /\  /| (_) | | | (_| \__ \
;  \_____|\___/|_| |_| |_| .__/|_|_|_|_| |_|\__, |     \/  \/  \___/|_|  \__,_|___/
;                        | |                 __/ |                                 
;                        |_|                |___/                                  
; Compilation words...

;[ HEADER ( TIB:string -- )
; creates a word (from the input source) in the dictionary and links the
; dictionary
; *********************************************************************
; NOTE: FOR VERSIONS 1.2.1 ONWARDS:
; HEADER NOW DOES A "BL WORD" SEQUENCE INTERNALLY.
; NO NEED TO DO A "BL WORD HEADER" SEQUENCE IN CODE THAT USES HEADER.
; HEADER NOW DOES IT FOR YOU.
; *********************************************************************
headrh  data byeh,6
        text 'HEADER'
header  data docol
        data align          ; ensure HERE is aligned
        data spword         ; get a word from the input source
        data headr          ; create and link new dictionary entry
        data exit
headr   data $+2
        bl @bank1
        data _headr         ; see 1-09-Compilation.a99
;]

;[ MARKER ( -- )
; creates a marker in the dictionary that, when executed, removes all words 
; following the marker from the dictionary, and resets the compilation address 
; to the first free address following the marker.
; Example:
; MARKER RESET      \ create a marker called reset
; : test1 1 2 3 ;   \ define some words
; : test2 4 5 6 ;
; : test3 7 8 9 ;
; RESET
; In the example above, upon execution of RESET, the words test1 test2 & test3 
; are removed from the dictionary, LATEST points to the link field of RESET and
; H points to the next cell after the end of the definition of RESET.
; FFAIHM & FFAILM are also updated.
markrh  data headrh,6
        text 'MARKER'
markr   data docol
        data header
        data compile,docol
        data compile,domark
        data lates_,fetch,comma
        data ghere,lit,6,add,comma
        ; branch to code in FORGET to force update of FFAILM & FFAIHM...
        data compile,align
        data compile,exit
        data exit
domark  data $+2
        mov *pc+,@latest
        mov *pc+,@here
        b *next
;]

;[ CREATE       --                            M,79                  
; A defining word executed in the form: 
;       CREATE <name>                 
; Creates a dictionary entry for <name>.  After <name> is created, the next 
; available dictionary location is the first byte of <name>'s parameter field.  
; When <name> is subsequently executed, the address of the first byte of 
; <name>'s parameter field is left on the stack.
; CREATE does not allocate space in <name>'s parameter field.
creath  data markrh,6
        text 'CREATE'
create  data docol
        data header                 ; create and link dictionary entry
        data compile,crtime         ; compile create's run-time to CREATEd CFA
        data exit

; the run-time behaviour of all words created with CREATE is to leave their PFA
; on the stack... Children of CREATE invoke the following code, called by the
; inner interpreter:
crtime  dect stack                   ; make room for PFA
        mov r6,*stack                ; place PFA on stack
        b *next
;]

;[ patches CFA of last created word with address of run-time code of parent.
; address contained in PATCH. Used by DOES> 
altcfa  data $+2
        mov   @patch,r0         ; CFA of most recent definition
        mov   pc,*r0            ; patch it with parent's code field
        mov   *rstack+,pc       ; in-line EXIT that "ends" the definition
        b     *next             ; into which altcfa is compiled
;]

;[ DODOES
; dynamically compiles instructions (for run-time transition from child to 
; parent for DOES> words) into the parent DOES> word.
dodoes  data docol              
        data compile,>0644      ; compile: "dect stack" instruction
        data compile,>C506      ; compile: "mov r6,*stack" instruction
        data compile,>0645      ; compile: "dect rstack" instruction
        data compile,>C543      ; compile: "mov pc,*rstack" instruction
        data compile,>0203      ; compile: "li pc,xxx" instruction
        ; calculate & compile address of xxx for li instruction:
        data ghere,lit,4,add,comma
        data compile,>045C      ; compile "b *next" instruction
        data exit
;]

;[ DOES>        -- addr                       C,I,83         "does" 
;                 --   (compiling)              
; Defines the execution-time action of a word created by a high-level defining 
; word.  
; Used in the form:               
;       : <namex> ... <create> ... DOES> ... ;             
; and then                              
;       <namex> <name>                
; where <create> is CREATE or any user defined word which executes CREATE.
;
; Marks the termination of the defining part of the defining word <namex> and 
; then begins the definition of the execution-time action for words that will 
; later be defined by <namex>.  When <name> is later executed, the address of 
; <name>'s parameter field is placed on the stack and then the sequence of words
; between DOES> and ; are executed.
doesh   data creath,immed+5
        text 'DOES> '
does    data docol,align,compile,altcfa,dodoes,exit
;]

;[ CONSTANT     16b --                        M,83                 
; A defining word executed in the form: 
;       16b CONSTANT <name>           
; Creates a dictionary entry for <name> so that when <name> is later executed,
; 16b will be left on the stack.
consth  data doesh,8
        text 'CONSTANT'
const   data docol
        data header                     ; create and link dictionary entry
        data compile,docon              ; compile reference to docon
        data comma                      ; compile in the value of constant as an
                                        ; argument to docon
        data exit

; children of constant run this code...
docon   dect stack                      ; make space on the data stack
        mov *r6,*stack                  ; push payload to the stack
        b *next
;]

;[ VARIABLE     --                            M,79                 
; A defining word executed in the form: 
;       VARIABLE <name>               
; A dictionary entry for <name> is created and two bytes are ALLOTted in its 
; parameter field.
; This parameter field is to be used for contents of the variable.
; When <name> is later executed, the address of its parameter field is placed 
; on the stack.
varh    data consth,8
        text 'VARIABLE'
var     data docol,create,lit0,comma,exit
;]

;[ VALUE ( n -- )
; A "value" is actually a variable, but with more friendly syntax. VALUEs work
; in conjunction with TO and +TO. (Perversely, they are implemented internally
; using constants!)
; A value can be initialised with a value at the time of creation:
; 10 VALUE TEN - creates a word that pushes 10 to the stack when executed.
; Note how the value was created and intialised at the same time. Using
; standard variables, we would have to do:
; VARIABLE TEN  10 TEN ! - two distinct steps.
; To get the value of the value, just execute it:
; 10 VALUE TEN  TEN . 10 ok
; Values, once created can have their values changed with the TO command:
; 100 VALUE DELAY (creates a VALUE called delay with the value of 100)
; 55 TO DELAY (changes the value of DELAY to 55)
; Using standard variables, we would have to do:
; VARIABLE DELAY
; 100 DELAY !
; 55 DELAY !
valueh  data varh,5
        text 'VALUE '
value   data docol,const,exit
        ; no coolness here, it's just a constant, the coolness is in TO & +TO
;]

;[ TO ( n -- )
; Allows the value of an already created VALUE to be changed:
; 100 VALUE SETPOINT (create a SETPOINT value with the value of 100)
; 65 TO SETPOINT (change SETPOINTs value to 65)
toh     data valueh,immed+2
        text 'TO'
        data docol,toutil,zbrnch,tohx
        ; runs if in compile state. In compile state, a number will be on the
        ; stack, so compile a reference to doto 
        data compile,doto       ; compile reference to "do to"
        data comma              ; compile body address
        data exit
        
        ; runs in interpret state - write the value on the stack to the body
        ; address....
tohx    data store,exit

dotoh   data toh,4
        text '(TO)'
doto    data $+2
        mov *pc+,r0         ; get in-line body address
        mov *stack+,*r0     ; move tos to values' body
        b *next
;]

;[ +TO ( n -- )
; Similar to TO above, but adds the value on the stack to the value.
; 100 VALUE SETPOINT (create a value called SETPOINT with the value 100)
; 25 +TO SETPOINT (changes SETPOINTs value to 125)
addtoh  data dotoh,immed+3
        text '+TO '
        data docol,ToUtil,zbrnch,addtox
        ; runs if in compile state. In compile state, a number will be on the
        ; stack, so compile a reference to dopto ("do plus-to")
        data compile,dopto      ; compile reference to "do plus-to"
        data comma              ; compile body address
        data exit
        ; runs in interpret state - write the value on the stack to the body
        ; address....
addtox  data stadd,exit

ptoh    data addtoh,5
        text '(+TO) '
dopto   data $+2
        mov *pc+,r0         ; get in-line body address
        a *stack+,*r0       ; pop and add tos to value in the values' body
        b *next
;]

; common routine to get body and state. Used by TO and +TO save a few bytes by
; making it common, and no run time penalty since this bit of code executes at
; compile time.
; ( -- body state)
ToUtil  data docol,getword,tobody,state_,fetch,exit

;[ ALLOT        w --                          79            
; Allocates w bytes in the dictionary.
; The address of the next available dictionary entry is updated accordingly.
alloth  data ptoh,5
        text 'ALLOT '
allot   data $+2
        bl @bank1
        data _allot         ; see 1-09-Compilation.a99
;]

;[ LIT ( -- n )
; places the literal number on the datastack
lith    data alloth,3
        text 'LIT '
lit     data _lit           ; runs from 16-bit ram
;]

;[ LITERAL      -- 16b                        C,I,79               
; 16b --   (compiling)          
; Typically used in the form:           
;       [ 16b ] LITERAL               
; Compiles a system dependent operation so that when later executed, 
; 16b will be left on the stack.
literh  data lith,immed+7
        text 'LITERAL '
litral  data docol
        data clc                    ; compile lit and value from stack
        data exit
;]

;[ ,            16b --                        79            "comma" 
; ALLOT space for 16b then store 16b at HERE 2- .
commah  data literh,1
        text ', '
comma   data $+2
        bl @bank1
        data _comma         ; see 1-09-Compilation.a99
;]

;[ C, (COMMA) ( value -- )
; appends an 8 bit value, from the least significant byte of TOS to HERE.
; Here is incremented by ONE BYTE, not one WORD.
; For safety, use ALIGN to align HERE to a word boundary afterwards.
ccommh  data commah,2
        text 'C,'
ccomma  data $+2
        bl @bank1
        data _comab         ; see 1-09-Compilation.a99
;]

;[ ALIGN ( -- )
; Aligns HERE to an even word boundary by rounding up if required
; Call it after using C!
alignh  data ccommh,5
        text 'ALIGN '
align   data $+2
        bl @bank1
        data _align         ; see 1-09-Compilation.a99
;]

;[ [            --                            I,79   "left-bracket" 
;                 --   (compiling)              
; Sets interpret state.
; The text from the input stream is subsequently interpreted. 
; For typical usage see LITERAL . See:  ]
lbrakh  data alignh,immed+1
        text '[ '
lbrack  data $+2
        clr @_state                 ; set state to 0
        b *next
;]

;[ ]            --                            79    "right-bracket" 
; Sets compilation state.
; The text from the input stream is subsequently compiled. 
; For typical usage see LITERAL . See:  [
rbrakh  data lbrakh,1
        text '] '
rbrack  data $+2
        seto @_state                ; set state to non zero
        b *next
;]

;[ :            -- sys                        M,79          "colon" 
; A defining word executed in the form: 
;       : <name> ... ;                
; Create a word definition for <name> in the compilation vocabulary and set 
; compilation state.  
; The search order is changed so that the first vocabulary in the search order 
; is changed so that the first vocabulary in the search order is replaced by the
; compilation vocabulary.
; The compilation vocabulary is unchanged.  The text from the input stream is
; subsequently compiled.  
; <name> is called a "colon definition".  
; The newly created word definition for <name> cannot be found in the dictionary
; until the corresponding ; or ; ;CODE is successfully processed.   
; An error condition exists if a word is not found and cannot be converted to a
; number or if, during compilation from mass storage, the input stream is 
; exhausted before encountering ; or ;CODE.  
; sys is balanced with its corresponding ;
; See: "compilation"  "9.4 Compilation"
colonh  data rbrakh,1
        text ': '
colon   data docol
    ; reset error detection reference counts....
        data lit,ifcnt,lit,sal-ifcnt,lit0,fill
    ; begin compilation...
        data in_,fetch              ; save >IN
        data header                 ; create entry and link dictionary
        data lates_,fetch,hideme    ; set *this* entry as hidden
        data in_,store              ; restore >IN
        data spword,find            ; see if word already exists. 
                                    ; FIND won't find *this* instance!
        data lit,temp,store,drop    ; store result in temp. used later by ;
        data compile,docol          ; compile DOCOL
        data rbrack                 ; switch on compile mode 
        data exit
        
;]

;[ CODE: ( -- )
; Defines a machine code word. 
codeh   data colonh,5
        text 'CODE: '
        data docol
        data header 
        data ghere,plus2,comma
        data litm1,lit,coding,store
        data exit
;]

;[ ;CODE ( -- )
; ends a machine code definition
ecodeh  data codeh,immed+5
        text ';CODE '
ecode   data docol
        data lit,>045c,comma,lit,coding,store0
        data exit
;]

;[ ;            --                            C,I,79   "semi-colon" 
;           sys --   (compiling)          
; Stops compilation of a colon definition, allows the <name> of this colon 
; definition to be found in the dictionary, sets interpret state and compiles 
; EXIT (or a system dependent word which performs an equivalent function).
; sys is balanced with its corresponding : .  
; See:  EXIT  :  "stack, return"  "9.4 Compilation"
semih   data ecodeh,immed+1
        text '; '
semi    data docol
        data compile,exit           ; compile EXIT
        data lates_,fetch,hideme    ; un-hide the word

        ; flag to indicate no unbalanced errors detected...
        data lit0

        ; check IF...THEN reference counts, error if count>0...
        data lit,ifcnt,fetch,zbrnch,doerr
        data isserr
        data toterm,iferr
        
    ; check DO...LOOP reference counts, error if count>0...
doerr   data lit,docnt,fetch,zbrnch,caserr
        data isserr
        data toterm,doertx
        
    ; check CASE...ENDCASE reference counts, error if count>0
caserr  data lit,cascnt,fetch,zbrnch,oferr
        data isserr
        data toterm,castxt
        
    ; check OF...ENDOF reference counts, error if count>0
oferr   data lit,ofcnt,fetch,zbrnch,begerr
        data isserr
        data toterm,oftxt
        
    ; check BEGIN/UNTIL/REPEAT reference counts, error if count>0
begerr  data lit,begcnt,fetch,zbrnch,allfin
        data isserr
        data toterm,begtxt

    ; abort if one of the above error conditions exist
allfin  data zbrnch,semi2 ; test unbalanced error flag
        data ab0rt
    
    ; issue warning if this word is a re-definition...
semi2   data lit,temp,fetch,zbrnch,semi3  ; skip if not a redefinition
        data rdferr                       ; else issue warning if enabled
    ; end of colon definition, reset compile state...
semi3   data lbrack                       ; go into interpret mode
        data exit
        
isserr  data docol,cr,error,toterm,intxt,colnam,unbal
        data plus1 ; set unbalanced error detect to non-zero value
        data exit
;]    

;[ HIDDEN ( dictionary_address -- )
; toggles the hidden attribute on the dictionary entry
; normally you would hide a word after defining it with: LATEST @ HIDDEN
hidh    data semih,6
        text 'HIDDEN'
hideme  data $+2
        bl @bank1
        data _hide
;]

;[ IMMEDIATE    --                            79                   
; Marks the most recently created dictionary entry as a word which will be 
; executed when encountered during compilation rather than compiled.
immh    data hidh,9
        text 'IMMEDIATE '
imm     data $+2
        bl @bank1
        data _imm
;]

;[ [']          -- addr                       C,I,M,83    "bracket-tick"
;                 --   (compiling)
; Used in the form:                     
;       ['] <name>                    
; Compiles the compilation address addr of <name> as a literal.  
; When the colon definition is later executed addr is left on the stack.
; An error condition exists if <name> is not found in the currently active 
; search order.  See:  LITERAL
tickh   data immh,immed+3
        text '[''] '
tick    data docol,getword,litral,exit

;]

;[ '            -- addr                       M,83           "tick" 
; Used in the form:
;       ' <name>
; addr is the compilation address of <name>.  
; An error condition exists if <name> is not found in the currently active 
; search order.
tick2h  data tickh,1
        text ''' '
tick2   data docol,getword,exit
;]

;[ COMPILE      --                            C,83                 
; Typically used in the form:           
;       : <name> ... COMPILE <namex> ... ;                 
; When <name> is executed, the compilation address compiled for <namex> is 
; compiled and not executed.  
; <name> is typically immediate and <namex> is typically not immediate.
; See:  "compilation"
compih  data tick2h,7
        text 'COMPILE '
compile data $+2
        ; note: the following line of code MUST be executed from bank 0. 
        ; It cannot execute in bank 1 because all the Forth CFAs are in bank 0.
        mov *pc+,r1                 ; get cfa of next word in thread
        bl @bank1                   ; do the rest in bank 1
        data _compil                ; see 1-09-Compilation.a99
;]

;[ [COMPILE]    --                            C,I,M,79    "bracket-compile"
;                 --   (compiling)
; Used in the form:                     
;       [COMPILE] <name>              
; Forces compilation of the following word <name>.  
; This allows compilation of an immediate word when it would otherwise have been
; executed.
icomph  data compih,immed+9
        text '[COMPILE] '
icomp   data docol
        data spword                 ; get a word from TIB
        data find,drop              ; find it in the dictionary
        data comma                  ; compile the CFA to HERE
        data exit
;]

;[ RECURSE ( -- )
; RECURSE makes a recursive call to the current word that is being compiled.
; Normally while a word is being compiled, it is marked HIDDEN so that
; references to the same word within are calls to the previous definition of
; the word. However we still have access to the word which we are currently
; compiling through the LATEST pointer so we can use that to compile a
; recursive call.
recrsh  data icomph,immed+7
        text 'RECURSE '
recurs  data docol
        data lates_,fetch           ; get LATEST on stack
        data cfa                    ; convert to CFA
        data comma                  ; compile it
        data exit
;]

;[ EXECUTE      addr --                       79                   
; The word definition indicated by addr is executed.  
; An error condition exists if addr is not a compilation address
exeh    data recrsh,7
        text 'EXECUTE '
execut  data $+2
        mov *stack+,r6              ; pop addr to r6
        mov *r6+,r7                 ; get cfa
        b *r7                       ; execute it
;]

; little utility word to get a word using a space as a delimiter.
; Saves a few bytes as it is used in multiple places.
spword  data docol,bl_,word,exit


; another utility word
; gets a word from the input stream, finds it in the dictionary.
; aborts if the word is not found in the dictionary.
getword data docol
        data in_,fetch,rspush
        data spword,find,zbrnch,finderr
        data rspop,drop
        data exit
        
finderr data rspop,in_,store
        data spword,type
        data toterm,notick
        data colnam
        data ab0rt
        data exit
notick  byte 10 
        text ' not found'
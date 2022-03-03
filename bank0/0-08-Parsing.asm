;  _____                _              __          __            _     
; |  __ \              (_)             \ \        / /           | |    
; | |__) |__ _ _ __ ___ _ _ __   __ _   \ \  /\  / /___  _ __ __| |___ 
; |  ___// _` | '__/ __| | '_ \ / _` |   \ \/  \/ // _ \| '__/ _` / __|
; | |   | (_| | |  \__ \ | | | | (_| |    \  /\  /| (_) | | | (_| \__ \
; |_|    \__,_|_|  |___/_|_| |_|\__, |     \/  \/  \___/|_|  \__,_|___/
;                                __/ |                                 
;                               |___/                                  
; Dictionary lookup and associated parsing words

; EXPECT       addr +n --                    M,83                 
; Receive characters and store each into memory.  The transfer begins at addr 
; proceeding towards higher addresses one byte per character until either a 
; "return" is received or until +n characters have been transferred.  
; No more than +n characters will be stored. 
; The "return" is not stored into memory.  
; No characters are received or transferred if +n is zero.  
; All characters actually received and stored into memory will be displayed, 
; with the "return" displaying as a space.  See:  SPAN  "9.5.2 EXPECT"
expcth  data copywh,6
        text 'EXPECT'
expect  data $+2
        clr @in                     ; clear >IN variable
        clr r14                     ; counter for number of characters 
                                    ; *actually* in the buffer
        mov *stack+,r13             ; pop length in r13
        mov *stack+,r10             ; pop address address in r10
        mov r13,r13                 ; check length
        jeq zchars                  ; quit if 0 characters requested
expnxt  bl @kscn                    ; scan keyboard (wait for a keypress) 
                                    ; ascii code returned on the stack
    ; check for enter key...
        c *stack,@datCR             ; compare to carriage return (enter key)
        jeq exp2                    ; exit routine if enter was pressed 
;    ; check for backspace key...
        c *stack,@lit8+4            ; compare to backspace key
        jne skipbs                  ; skip if backspace not pressed
        inct stack                  ; remove backspace from stack
        mov r14,r14                 ; check if anything in the buffer
        jeq expnxt                  ; tib is empty, ignore...
    ; do backspace...
        bl @ccp                     ; compute cursor position
        li r1,>2000                 ; load a space character
        bl @vsbw                    ; erase the cursor
        mov @scrX,r0                ; get current x position
        jne back1                   ; if x>0 we don't need to move up one line
        mov @xmax,@scrX             ; move to end of line
        dec @scrX                   ; correct X
        dec @scrY                   ; up one screen line
        mov @scrY,r0                ; check y
        jlt bumpY                   ; if <0 then reset to 0
        jmp back2
back1   dec @scrX                   ; move back one character
back2   dec r14                     ; decrement buffer index pointer
        dec r10                     ; decrement buffer position
        jmp expnxt                  ; get another keypress
bumpY   inc @scrY                   ; prevent Y from going <0
        jmp back2

    ; process keypress...
skipbs  dect stack                  ; new stack entry
        mov @2(stack),*stack        ; duplicate value on stack for EMIT
        bl @emit_                   ; call emit (which may/may not call SCRLUP)
        swpb *stack                 ; shift ascii code into MSB
        mov *stack+,r1
        mov r10,r0
        inc r10
        bl @vsbw0
        inc r14                     ; increment 'number of characters in buffer so far'
                                    ; counter
        c r14,@tibsiz               ; do we have #TIB characters in the buffer?
        jeq exp1                    ; if so, exit the routine
        c r13,r14                   ; have we got 'length' characters?
        jne expnxt                  ; read another key if not
exp1    mov r14,@_span              ; move character count into _span
        b @space1+2                 ; type a space to the console and exit
exp2    inct stack                  ; pop ascii 13 off the stack
        jmp exp1

; special case if 0 characters were requested for some weird reason...
zchars  clr @_span
        b *next
datCR   data 13                     ; ascii code for carriage return


; Comments: ( \ & .(
; Allows comments e.g. : 1TO3 ( comment) 1 2 3 ;
; Reads through the TIB until ) is found or end of line
remh    data expcth,immed+1
        text '( '
rem     data docol
        data lit,')',word,drop2
        data exit

trcomh  data remh,immed+1
        text '\ '
trcom   data $+2
        bl @bank1
        data _trcom
        
typcmh  data trcomh,immed+2
        text '.('
        data docol,lit,41,word,type,cr,exit


; WORD ( delimiter -- address length )
; Moves through TIB in VDP memory, discarding leading delimiters, looking for 
; a word. A word is identified when a trailing delimiter is detected. 
; The word is copied from VDP to CPU memory.
; Pushes the start address of the word (in CPU memory), and the length of
; the word to the stack. 
; If no word is found (for example if we hit the end of the TIB without 
; detecting a word then 0 0 is pushed on the stack.

wordh   data typcmh,4
        text 'WORD'
word    data docol
        ; tib @ blk @ ?dup if nip block then 
        data tib_,fetch
word0   data blk,fetch,qdup,zbrnch,word2,nip,fblock
word2   data word1
        data exit

; at this point, data stack is ( delimeter address -- )
; where address is the address in vdp to start searching from.
; address is either TIB+>IN (if BLK=0) or block address+>IN 
; if BLK>0. (the code to add >IN to the address is in _word)
word1   data $+2
        bl @bank1
        data _word                  ; see 1-08-Parsing.a99


; BL ( -- 32 )
; pushes 32 decimal to the stack. BL is short for 'BLANK' often used in with 
; word to specify the delimeter: e.g. BL WORD
blh     data wordh,2
        text 'BL'
bl_     data docol,lit,32,exit  


; FIND         addr1 len -- addr2 n              83                   
; addr1 is the address of a string.  The string contains a word name to be 
; located in the currently active search order.  If the word is not found, addr2
; is the string address addr1, and n is zero.  
; If the word is found, addr2 is the compilation address and n is set to one of
; two non-zero values.  If the word found has the immediate attribute,
; n is set to one.  If the word is non-immediate, n is set to minus one (true).
; Len indicates the length of the string beginnig at addr1.
findh   data blh,4
        text 'FIND'
find    data docol,lit,fndvec,fetch,execut,exit
vfind   data $+2                    ; vectored find
        mov *stack+,r6              ; pop length to r6
        mov @latest,r7              ; get address of last dictionary entry
fndnxt  mov @2(r7),r8               ; length of dictionary entry
        andi r8,>400f               ; mask out immediate bit and block numbers
        c r8,r6                     ; are they the same length?
        jeq lmatch                  ; jump if yes
find1   mov *r7,r7                  ; point to next dictionary entry
        jeq nomatch                 ; if 0 then no match. end of dictionary.
        jmp fndnxt                  ; else check the next entry
    ; the length matches.
    ; now do a character comparison between the word in the buffer and the word
    ; in the dictionary
lmatch  mov r7,r10
        ai r10,4                    ; point to text of dictionary entry
        mov *stack,r0               ; buffer address in r0
cnxtch  movb *r0+,r1                ; otherwise get a character from buffer
        bl @caschk                  ; convert case if case sensitive=off
        mov r1,r14                  ; save the character
        movb *r10+,r1               ; get character from dictionary entry
        bl @caschk                  ; convert case if case sensitive=off
find2   cb r1,r14                   ; compare the two characters
        jne find1                   ; if not equal then check next dict entry
        dec r8                      ; decrememnt length
        jne cnxtch                  ; if not 0 then check next character
    ; we have a match push cfa and word type
        mov @2(r7),r8               ; get length of dictionary entry
        mov r8,r9                   ; make a copy
        andi r8,>f                  ; retain length only
        a r8,r7                     ; add length
        ai r7,4                     ; take account of address & link field
        inc r7                      ; round up...
        andi r7,>fffe               ; ...to even address
        mov r7,*stack               ; push cfa
        dect stack                  ; prepare to push 'n' (see stack sig)
l8000   andi r9,immed               ; check immediate bit
        jeq noimm                   ; if not set then push -1 for status
        li r1,1                     ; else push a 1
        mov r1,*stack
        b *next
noimm   seto *stack                 ; not immediate - push -1
        b *next
nomatch dect stack                  ; leave address unchanged on stack
        clr *stack                  ; 0=not found
        b *next
; Convert lower case characters to upper case if case sensitivity is turned off
;  Input: r1 msb = character to test
; Output: r1 msb = upper case character
caschk  movb @cassen,r13            ; case sensitive mode switched off?
        jne casout                  ; skip case conversion if switched off
        movb r1,r13                 ; get the character in a spare register
        srl r13,8                   ; move to low byte
        ci r13,'a'                  ; compare to a
        jlt casout                  ; if less than it's not a lower case char
        ci r13,'z'                  ; else compare to z
        jgt casout                  ; if greater than it's not a lower case char
        li r13,-32*256              ; it's lower case. load -32 in the upper byte
        ab r13,r1                   ; subtract -32 from the upper byte.
        ; char is now upper case
casout  .rt


; NUMBER ( address length -- number flag )
; Attempts to convert the string at address into a number. If fully successful,
; the number is placed on the stack and flag will be 0. If it fails (for example
; contains an illegal character) then a partial number will be placed on the 
; stack (the value computed up until the failure) and flag will be >0.
; Thus, if flag>0 the string failed to parse fully as a number.
; A minus sign is permitted for negative numbers.
; This routine uses BASE to parse numbers in the current BASE. 
; Eg. If BASE=16 then digits 0-9 and A-F are considered legal and will be 
; parsed properly.
; A facility also exists called 'quick hex' that allows a number to be entered
; in base 16, by placing a $ symbol at the end of the string. This avoids the
; need to change BASE to enter a number. E.g. instead of HEX FEED DECIMAL you
; can simply do $FEED. The number will be parsed as a HEX number without the
; need to change BASE.
; The numbers returned are (by default) singles (16 bits). NUMBER can can also
; return a double (32-bit (2 stack cells)) value by including a period in the
; number string. E.g. 100. 1.00 10.0 .100 will all return 100 decimal as a 
; double.
; The various facilities can be mixed. For example, f. means -15 as a double.
; - $ and . can be specified in any order. However, $ if required, should be
; specified before any number digits. - and . can come anywhere in the string.
; in the number string.
numbrh  data findh,6
        text 'NUMBER'
number  data docol,lit,numvec,fetch,execut,exit ; fetch NUMBER vector & execute
numbr1  data $+2
        bl @bank1
        data _numbr                 ; see 1-08-Parsing.a99


; EVALUATE ( i*x c-addr u -- j*x)
; evaluates the string specified by c-addr u 
; the interpretation state is stored before evaluation and restored afterwards
; should not be directly called within a block (or when BLK>0)
evalh   data numbrh,8
        text 'EVALUATE'
eval    data docol
        data in_,fetch,rspush
        data blk,fetch,rspush
        data span,fetch,rspush
        data tib_,fetch,rspush
          
        data in_,store0             ; zero >IN
        data blk,store0             ; zero BLK
        data span,store             ; load #tib with u
        data tib_,store             ; load tib with c-addr

        data litm1,lit,source,store ; set SOURCE-ID to -1
        data interp                 ; call interpreter
        data lit,source,store0      ; zero SOURCE-ID
        
        data rspop,tib_,store
        data rspop,span,store
        data rspop,blk,store
        data rspop,in_,store
        data exit


; >CFA ( dictionary_address -- code_field_address)
; Given a dictionary address returns the code-field address (CFA) of the word
cfah    data evalh,4
        text '>CFA'
cfa     data $+2
_cfa    mov *stack,r2               ; dictionary address
        mov @2(r2),r1               ; word length
        inc r1                      ; round word length up to even number if odd
        andi r1,>000e               ; keep only rounded up length value
        a r2,r1                     ; add length to dictionary address
        c *r1+,*r1+                 ; adjust by two words, one word for header 
                                    ; word, one word for length word. 
                                    ; we're now pointing at the CFA. nice trick
                                    ; to add 4 to a register in only 2 bytes!
        mov r1,*stack               ; move to stack
        b *next                     ; NEXT


; >BODY ( cfa -- body_address )
; Given a CFA, returns the address of the body (the address of the "payload")
; of words created with CREATE. E.g. VARIABLE, VALUE, CONSTANT
tbodyh  data cfah,5
        text '>BODY '
tobody  data _plus2                 ; execute 2+ (see 0-03-Math.a99)


; >LINK ( cfa -- link_field_address )
; given a code field address, returns the address of the beginning of the dictionary
; entry (the address of the link field).
dfah    data tbodyh
        data 5
        text '>LINK '
dfa     data $+2
        mov @latest,r0              ; get latest dictionary entry
dfa1    mov r0,r1                   ; copy it
        inct r0                     ; point to length 
        mov *r0,r2                  ; get the length
        dect r0                     ; point to beginning of dict entry again
        andi r2,>f                  ; mask out immediate, hidden, and block 
                                    ; number, leaving length
        a r2,r1                     ; add length
        inc r1                      ; round up to...
        andi r1,>fffe               ; ...word address
        inct r1                     ; account for the length word itself
        inct r1
        c r1,*stack                 ; is it what we're looking for?
        jeq dfafnd                  ; jump if yes
        mov *r0,r0                  ; otherwise walk the list
        jeq dfafnd                  ; if zero, we didn't find - push zero
        jmp dfa1                    ; otherwise check the next entry in the list
dfafnd  mov r0,*stack               ; place on stack
        b *next


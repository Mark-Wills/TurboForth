;   _____ _        _              __          __            _     
;  / ____| |      (_)             \ \        / /           | |    
; | (___ | |_ _ __ _ _ __   __ _   \ \  /\  / /___  _ __ __| |___ 
;  \___ \| __| '__| | '_ \ / _` |   \ \/  \/ // _ \| '__/ _` / __|
;  ____) | |_| |  | | | | | (_| |    \  /\  /| (_) | | | (_| \__ \
; |_____/ \__|_|  |_|_| |_|\__, |     \/  \/  \___/|_|  \__,_|___/
;                           __/ |                                 
;                          |___/                                  
; string related words

;[ U.           u --                          M,79          "u-dot" 
; u is displayed as an unsigned number in a free-field format.
udoth   data rndh,2
        text 'U.'
udot    data docol,usign,type,space1,exit
;]

;[ .            n --                          M,79            "dot" 
; The absolute value of n is displayed in a free field format with a leading 
; minus sign if n is negative.
doth    data udoth,1
        text '. '
dot     data docol,sign
dot1    data type,space1,exit
;]

;[ U.R ( num width -- )
udotrh  data doth,3
        text 'U.R '
udotr   data docol
        data swap           ; width num
        data usign          ; width addr len
        data setw           ; addr len
        data branch,dot1
;]

;[ .R ( num width --)
dotrh   data udotrh,2
        text '.R'
dotr    data docol          
        data swap           ; width num
        data sign           ; width addr len
        data setw           ; addr len
        data branch,dot1
;]

;[ subroutines used by . U. .R and U.R
setw    data docol,rot,swap,tuck,sub,spces,exit
;]

;[ $. ( num -- )
; prints a number as an unsigned hex value
hdoth   data dotrh,2
        text '$.'
hexdot  data docol
        data base_,fetch,swap
        data hex
        data usign,type
        data space1
        data base_,store,exit
;]

;[ N>S ( num -- addr len )
; Takes a number off the stack and converts it to a signed string equivalent, 
; with respect to the current number base.
; The variable UNSIGNED is checked, and if true, the strings generated shall be
; the unsigned equivalents of the number on the stack, otherwise the string 
; shall be the signed equivalent of the number of the stack.
;
; sign and usign below are entry points into N>S for . and U. respectively to 
; force N>S to produce an appropriately signed string.
ntsh    data hdoth,3
        text 'N>S '
nts     data $+2
        mov @dotsin,@dosign     ; set/reset signed/unsigned mode according to 
                                ; the Forth variable UNSIGNED
nts1    bl @bank1
        data _nts               ; see 1-10-Strings.a99
    ; entry points for . and U. :
sign    data $+2
        clr @dosign
        jmp nts1
usign   data $+2
        seto @dosign
        jmp nts1
;]

;[ CHAR ( -- ascii )
; puts the ASCII code of the first character of the following word on the stack
; For example CHAR A puts 65 on the stack.
charh   data ntsh,immed+4
        text 'CHAR'
char    data docol,spword,drop,chrftc,exit
;]

;[ ASCII ( ascii -- )
; In interpretation state:
;    pushes the ascii value of the character immediately following
;    ASCII to the stack. 
; In compilation state: 
;    compiles the ascii value of the character immediately following
;    ASCII as a literal
asciih  data charh,immed+5
        text 'ASCII '
ascii   data docol,char,state_,fetch,zbrnch,asciix
        data clc        ; compile lit , 
asciix  data exit
;]

;[ COUNT        addr1 -- addr2 +n             79                   
; addr2 is addr1+1 and +n is the length of the counted string at addr1.
; The byte at addr1 contains the byte count +n. 
; Range of +n is {0.255}  See:  "string, counted"
counth  data asciih,5
        text 'COUNT '
count   data $+2
        bl @bank1
        data _count                 ; see 1-10-Strings.a99
;]

;[ S" Compile time:( -- ) Immediate:( -- address length )
; When Compiling:
; compiles: (S")<length><string>
; e.g S" HELLO" compiles (S") 5 H E L L O
; Note the 0 padding byte for odd length strings. 
; The length is a BYTE. At the end of string compilation, HERE is aligned to an
; even address.
; At run time, (S") pushes the address of the beginning of the string 
;(address of length byte+1) and the length to the stack.
; 
; When Interpreting:
; Compiles the string to the address PAD, and pushes the address and 
; length to the stack.
strngh  data counth,immed+2
        text 'S"'
string  data docol,lit,34,word,pad,strng1,exit
strng1  data $+2
        bl @bank1
        data _strin                 ; see 1-10-Strings.a99
        
; (S") ( -- addr len ) 
; internal string. S" compiles (S") into a word
; At run time, (S") pushes the address and length of the string following it
; to the stack.
strh    data strngh,4
        text '(S")'
str     data $+2
        bl @bank1
        data _str                   ; see 1-10-Strings.a99
;]

;[ -TRAILING    addr +n1 -- addr +n2          79    "dash-trailing" 
; The character count +n1 of a text string beginning at addr is adjusted to 
; exclude trailing spaces.  
; If +n1 is zero, then +n2 is also zero.  
; If the entire string consists of spaces, then +n2 is zero.
trailh  data strh,9
        text '-TRAILING '
trail   data $+2
        bl @bank1
        data _trail                 ; see 1-10-Strings.a99
;]

;[ ."           --                            C,I,83    "dot-quote" 
;                 --   (compiling)              
; Used in the form:                     
;       ." ccc"                       
; Later execution will display the characters ccc up to but not including the 
; delimiting " (close-quote).  The blank following ." is not part of ccc.
tstrh   data trailh,immed+2
        text '."'
typstr  data docol
        data string,state_,fetch,zbrnch,typst1,compile
typst1  data type,exit

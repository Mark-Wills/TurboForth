;   _____                      _      __          __            _     
;  / ____|                    | |     \ \        / /           | |    
; | (___  _ __   ___  ___  ___| |__    \ \  /\  / /___  _ __ __| |___ 
;  \___ \| '_ \ / _ \/ _ \/ __| '_ \    \ \/  \/ // _ \| '__/ _` / __|
;  ____) | |_) |  __/  __/ (__| | | |    \  /\  /| (_) | | | (_| \__ \
; |_____/| .__/ \___|\___|\___|_| |_|     \/  \/  \___/|_|  \__,_|___/
;        | |                                                          
;        |_|                                                          

; these routines are just dictionary entry stubs.
; see 1-04-Speech.a99 for the actual implementation.

; TALKING? ( -- flag )
; returns >0 if the speech synth is busy, else returns 0
spkngh  data panelh,8
        text 'TALKING?'
spkng   data $+2
        bl @bank1
        data _spkng             ; see 1-05-Speech.a99


; SAY ( addr cnt -- )
; says words from the speech synth's ROM. Use with DATA
; the addresses of the built in words are in ED/AS manual page 422
sayh    data spkngh,3
        text 'SAY '
say     data $+2
        bl @bank1
        data _say             ; see 1-05-Speech.a99


; STREAM ( addr cnt -- )
; streams raw speech data to the speech synth. Use with DATA
strmh   data sayh,6
        text 'STREAM'
strm    data $+2
        bl @bank1
        data _strem             ; see 1-05-Speech.a99


; DATA
; Compiling: DATA ( -- )  Executing: DATA ( -- addr count )
; E.g.
; When compiling:
;  DATA 5 9 8 7 6 5
;  Compiles 5 values (9 8 7 6 & 5) to memory
; At runtime:
;  When DATA is encountered, will push the start address (the address of 9)
;  to the stack, and the count (5). Execution will continue at the word 
; immediately following the data list.
datah   data strmh,immed+4
        text 'DATA'
        data docol
        data compile,rtdata     ; compile data run-time code
        data spword,number,drop ; get number of data items from input stream
        data dup,comma          ; and append to definition
        
        data lit0,do,data2      ; for each data item
data1   data spword,number,drop ; get number from input stream
        data comma              ; append directly to memory
        data loop,data1
data2   data exit

; (DATA) - run-time code for DATA
rtdath  data datah,6
        text '(DATA)'
rtdata  data $+2
        bl @bank1               
        data _data              ; see 1-05-Speech.a99


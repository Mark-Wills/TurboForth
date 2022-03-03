
; __      __         _       _     _
; \ \    / /        (_)     | |   | | 
;  \ \  / /__ _ _ __ _  __ _| |__ | | ___ ___
;   \ \/ // _` | '__| |/ _` | '_ \| |/ _ | __|
;    \  /| (_| | |  | | (_| | |_) | |  __|__ \
;     \/  \__,_|_|  |_|\__,_|_.__/|_|\___|___/

;[ UNSIGNED ( -- address ) (variable)
; places the address of the signed number variable on the stack
; this variable is used by the number to string routine to determine if a number should be
; treated as signed or unsigned when converting into a string (normally for displaying).
; If >0, then numbers will be converted as unsigned. This variable is set by U. and .
; but can also be useful in user programs.
usignh  data dup2h,8
        text 'UNSIGNED'
usignd  data $+2
        li r6,dotsin
        jmp span1
;]

;[ KDEL ( -- address )
; places the address of the keyboard auto-repeat delay
; used mainly for the geneve, which is a lot faster and needs a longer
; initial delay and repeat delay.
; The value stored in KDEL has the following format:
; 0xiiss
; Where ii is the initial delay (before auto-repeat starts) divided by 2.
; At power up, this value is 237 decimal.
; ss is the short delay (when auto-repeat is active). At power-up this value
; is 30 decimal. Maximum value is 255.
kdelh   data usignh,4
        text 'KDEL'
kdel_   data $+2
        li r6,kdel
        jmp span1
;]

;[ #BUF ( -- address ) (variable)
; number of disk buffers - minimum is one
nbufh   data kdelh,4
        text '#BUF'
nbuf    data $+2
        li r6,totblk
        jmp span1
;]

;[ SSCROLL ( -- address ) (variable)
; places address of NOSCROLL variable on the stack
; used to determine if the command line environment 
noscrh  data nbufh,7
        text 'SSCROLL '
noscr   data $+2
        li r6,noscrl
        jmp span1
;]

;[ CSEN ( -- address ) (variable)
; places address of CASE variable on the stack
; When CSEN>0 the system is case sensitive
sensh   data noscrh,4
        text 'CSEN'
sens    data $+2
        li r6,cassen
        jmp span1
;]

;[ SPAN         -- addr                       U,83   "number-t-i-b" 
; The address of a variable containing the number of bytes placed into the text input buffer by EXPECT.
htibh   data sensh,4
        text 'SPAN'
span    data $+2
        li r6,_span
span1   jmp !                          ; dovar is out of range, so take a small hop...
;]

;[ #TIB ( -- address ) (variable)
; returns a pointer to the size of the text input buffer
cplh    data HTIBH,4
        text '#TIB'
cpl     data $+2
        li r6,tibsiz
!       jmp dovar
;]

;[ WRAP ( -- address ) (variable)
; places address of WRAP variable on the stack
; used to determine if the SCROLL command does wrap-around or not
wraph   data cplh,4
        text 'WRAP'
wrap_   data $+2
        li r6,wrap
        jmp dovar
;]

;[ ZEROS ( -- address ) (variable)
; places address of LZI variable on the stack
; used to set if leading zeros are displyed when displaying numbers
zerosh  data wraph,5
        text 'ZEROS '
zeros   data $+2
        li r6,lzi
        jmp dovar
;]

;[ SP@ ( -- address ) (constant)
; places current address of stack pointer on the stack
spfh    data zerosh,3
        text 'SP@ '
spf     data $+2
        mov stack,r6                ; address of stack pointer in r6
        jmp dovar
;]

;[ SP! ( address -- ) (function)
; set stack pointer address - use with caution!
spsh    data spfh,3
        text 'SP! '
sps     data $+2
        mov *stack,stack            ; set stack pointer
        mov stack,@s0               ; set S0
spsx    dect stack                  ; adjust for pre-increment
        b *next
;]

;[ RP@ ( -- address ) (variable)
; places current address of return stack pointer on the stack
rpfh    data spsh,3
        text 'RP@'
rpf     data $+2
        mov rstack,r6               ; address of return stack pointer in r6
        jmp dovar
;]

;[ STATE        -- addr                       U,79                 
; The address of a variable containing the compilation state. A non-zero content indicates
; compilation is occurring, but the value itself is system dependent.  A Standard Program
; may not modify this variable.
stateh  data rpfh,5
        text 'STATE '
state_  data $+2
        li r6,_state
        jmp dovar
;]

;[ LATEST ( -- address ) (variable)
; returns the *address* of LATEST on the stack
latesh  data stateh,6
        text 'LATEST'
lates_  data $+2
        li r6,latest
        jmp dovar
;]

;[ H ( -- address ) (variable)
; returns the *address* of HERE on the stack - note lowercase
; see the constant, HERE
hereh   data latesh,1
        text 'H '
here_   data $+2
        li r6,here
        jmp dovar
;]

;[ BASE         -- addr                       U,83                 
; The address of a variable containing the current numeric conversion radix.
; {{2..36}}
baseh   data hereh,4
        text 'BASE'
base_   data $+2
        li r6,base
        jmp dovar
;]

;[ >IN          -- addr                       U,79          "to-in" 
; The address of a variable which contains the present character offset within
; the input stream {{0..the number of characters in the input stream}}.  
; See:  WORD
inh     data baseh,3
        text '>IN '
in_     data $+2
        li r6,in
        jmp dovar
;]

;[ KMODE ( -- address ) (variable)
; returns the address of keydev, the keyscan mode
kmodh   data inh,5
        text 'KMODE '
kmode   data $+2
        li r6,keydev
        jmp dovar
;]

;[ WARN ( -- address ) (variable)
; returns the address of keydev, the keyscan mode
warnh   data kmodh,4
        text 'WARN'
warn    data $+2
        li r6,_warn
        jmp dovar
;]

;[ TIB          -- addr                       83            "t-i-b" 
; The address of the text input buffer.
; This buffer is used to hold characters when the input stream is coming from 
; the current input device.  The minimum capacity of TIB is 80 characters.
; Note: TIB is a VDP address, unless SOURCE=-1, in which case it is interpreted
; as a CPU address.
tibh    data warnh,3
        text 'TIB '
tib_    data $+2
        li r6,tibadr
        jmp dovar
;]

;[ FFAIHM ( -- address )
; returns the first free address in high memory
ffahh   data tibh,6
        text 'FFAIHM'
ffaih   data $+2
        li r6,ffaihm
        ; fall down into dovar...
;]

; DOVAR: common routine used by variables and constants to push their data onto
; the stack. NOTE: this code is also used by code in Variables.a99
; This code is placed here so that it falls within the 256 byte JMP limit of
; both Constants.a99 and Variables.a99 - sneaky ;-)
dovar   dect stack              ; new stack entry
        mov r6,*stack           ; move value to data stack
        b *next

;[ FFAILM ( -- address )
; returns the first free address in low memory
ffalh   data ffahh,6
        text 'FFAILM'
ffaml   data $+2
        li r6,ffailm
        jmp dovar
;]


;   _____                 _               _       
;  / ____|               | |             | |      
; | |      ___  _ __  ___| |_  __ _ _ __ | |_ ___ 
; | |     / _ \| '_ \/ __| __|/ _` | '_ \| __/ __|
; | |____| (_) | | | \__ \ |_| (_| | | | | |_\__ \
;  \_____|\___/|_| |_|___/\__|\__,_|_| |_|\__|___/
        
;[ PAD          -- addr                       83                   
; The lower address of a scratch area used to hold data for intermediate
; processing.
; The address or contents of PAD may change and the data lost if the address of
; the next available dictionary location is changed.
; The minimum capacity of PAD is 84 characters.
padh    data ffalh,3
        text 'PAD '
pad     data $+2
        mov @ffaihm,r6              ; get first free address in HIGH memory
        ci r6,>ffa8                 ; compare to end of low memory-86 bytes
        jlt padx                    ; if less than then ok, just exit
        ; otherwise, we're close to end of high memory, so...
        mov @ffailm,r6              ; offer an address in low memory
padx    ai r6,80                    ; add a margin
        jmp dovar
;]

;[ IOERR ( -- io_error ) (constant)
; places last IO error code on the stack
ioerrh  data padh,5
        text 'IOERR '
ioerr1  data $+2
        mov @errnum,r6
        jmp dovar
;]

;[ XMAX ( -- xmax ) (constant)
; places the horizontal screen size (32, 40 or 80) on the stack
xmaxh   data ioerrh,4
        text 'XMAX'
gxmax   data $+2
        mov @xmax,r6
        jmp dovar
;]

;[ S0 ( -- address ) (constant)
; *BEGINNING* address of data stack on data stack, used to reset the data stack
s0h     data xmaxh,2
        text 'S0'
s0_     data $+2
        mov @S0,r6                  ; S0 defined in system.a99
        jmp dovar
;]

;[ HEX ( -- ) (function)
; sets the number base to 16 decimal
hexh    data s0h,3
        text 'HEX '
hex     data $+2
        li r0,16
        mov r0,@base
        b *next
;]

;[ DECIMAL ( -- ) (function)
; sets the number base to 10 decimal
dech    data hexh,7
        text 'DECIMAL '
deci    data $+2
        li r0,10
        mov r0,@base
        b *next
;]

;[ TRUE ( -- flag ) (constant)
; places TRUE (>FFFF) on the stack
trueh   data dech,4
        text 'TRUE'
true    data $+2
        seto r6
        jmp dovar
;]

;[ FALSE ( -- flag ) (constant)
; places FALSE (0) on the stack
falseh  data trueh,5
        text 'FALSE '
false   data $+2
        clr r6
        jmp dovar
;]

;[ HERE ( -- addr ) (constant)
; places the current compilation address on the stack
; see the variable here (lower case) which allows the
; current compilation address to be changed
hhereh  data falseh,4
        text 'HERE'
ghere   data $+2
        mov @here,r6
        jmp dovar
;]

;[ RND ( limit -- n)
; pushes a pseudo random number between 0 and limit-1 (rnd MOD limit)
; For the full range (0-65535) use a limit of 0
rndh    data hhereh,3
        text 'RND '
rnd     data $+2
        bl @bank1
        data _rnd
;]

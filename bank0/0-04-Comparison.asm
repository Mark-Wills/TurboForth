;   _____                                  _                   
;  / ____|                                (_)                
; | |      ___  _ __ ___  _ __   __ _ _ __ _ ___  ___  _ __  
; | |     / _ \| '_ ` _ \| '_ \ / _` | '__| / __|/ _ \| '_ \ 
; | |____| (_) | | | | | | |_) | (_| | |  | \__ \ (_) | | | |
;  \_____|\___/|_| |_| |_| .__/ \__,_|_|  |_|___/\___/|_| |_|
;                        | |                                 
;                        |_|                                 
; __          __            _     
; \ \        / /           | |    
;  \ \  /\  / /___  _ __ __| |___ 
;   \ \/  \/ // _ \| '__/ _` / __|
;    \  /\  /| (_) | | | (_| \__ \
;     \/  \/  \___/|_|  \__,_|___/

;[ =            n1 n2 -- flag                 83           "equals" 
; flag is true if n1 is equal to n2.
eqh     data maxh,1
        text '= '
eq      data $+2
        c *stack+,*stack            ; compare and pop n2
        jeq sTrue                   ; set true if n1=n2
        jmp sFalse                  ; else set result to false
;]
        
;[ >            n1 n2 -- flag                 83     "greater-than" 
; flag is true if n1 is greater than n2.                     
;    -32768 32767 > must return false.                  
;    -32768 0 > must return false.
gth     data eqh,1
        text '> '
gt      data $+2
        c *stack+,*stack            ; compare n2 to n1. pop n2
        jlt sTrue                   ; set true if n2<n1
        jmp sFalse                  ; else set result to false
;]

;[ <            n1 n2 -- flag                 83        "less-than" 
; flag is true if n1 is less than n2.   
;    -32678 32767 < must return true.                   
;    -32768 0 < must return true.
lth     data gth,1
        text '< '
lt      data $+2
        c *stack+,*stack            ; compare n2 to n1. pop n2
        jgt sTrue                   ; set true if n2>n1
        jmp sFalse                  ; else set result to false
;]

;[ >=           n1 n2 -- flag
; returns true if n1>=n2
gteh    data lth,2
        text '>='
gte     data $+2
        c *stack+,*stack            ; compare n2 to n2. pop n2
        jlt sTrue                   ; set true if n2<n1
        jeq sTrue                   ; or if n2=n1
        jmp sFalse                  ; else set result to false
;]

;[ <= (SIGNED)  ( n1 n2 -- flag )
; returns true if n1<=n2
lteh    data gteh,2
        text '<='
lte     data $+2
        c *stack+,*stack            ; compare n2 to n1. pop n2
        jgt sTrue                   ; set true if n2>n1
        jeq sTrue                   ; or if n2=n1
        jmp sFalse                  ; else set result to false
;]

;[ <>  ( n1 n2 -- flag )
; returns true if n1!=n2
neqhh   data lteh,2
        text '<>'
neq     data $+2
        c *stack+,*stack            ; compare n2 to n1. pop n2
        jne sTrue                   ; set true if n2<>n1
        jmp sFalse                  ; else set result to false
;]

;[ 0=           w -- flag                     83      "zero-equals" 
; flag is true if w is zero.
eqzh    data neqhh,2
        text '0='
eqz     data $+2
        mov *stack,*stack           ; compare to tos to 0
        jeq sTrue                   ; set true if tos=0
        jmp sFalse                  ; else set result to false
;]

;[ 0<>  ( x -- flag )
; returns true if x!=0
neqzh   data eqzh,3
        text '0<> '
neqz    data $+2
        mov *stack,*stack           ; compare tos to 0
        jne sTrue                   ; set true if tos<>0
        jmp sFalse                  ; else set result to false
;]
    
;[ 0<           n -- flag                     83        "zero-less" 
; flag is true if n is less than zero (negative).
ltzh    data neqzh,2
        text '0<'
ltz     data $+2
        mov *stack,*stack           ; compare tos to 0
        jlt sTrue                   ; set true if tos<0
        jmp sFalse                  ; else set result to false
;]

;[ 0>           n -- flag                     83     "zero-greater" 
; flag is true if n is greater than zero.
gtzh    data ltzh,2
        text '0>'
gtz     data $+2
        mov *stack,*stack           ; compare tos to 0
        jgt sTrue                   ; set true if tos>0
        jmp sFalse                  ; else set result to false
;]

;[ U<           u1 u2 -- flag                 83      "u-less-than" 
; flag is true if u1 is less than u2.
ulessh  data gtzh,2
        text 'U<'
uless   data $+2
        c *stack+,*stack            ; compare u2 to u1. pop u2
        jh sTrue                    ; set true if u2>u1
        jmp sFalse                  ; else set false
;]

;[ WITHIN ( n low high -- true|false )
; returns true if n is within low and high+1
withh   data ulessh,6
        text 'WITHIN'
within  data docol,over,sub,rspush,sub,rspop,uless,exit
;]

;[ 0<=  ( x -- flag )
; returns true if x<=0
ltezh   data withh,3
        text '0<= '
ltez    data $+2
        mov *stack,*stack           ; compare tos to 0
        jlt sTrue                   ; set true if tos<0
        jeq sTrue                   ; or if tos=0
        jmp sFalse                  ; else set result to false
;]

;[ 0>=  ( x -- flag )
; returns true if x>=0
gtezh   data ltezh,3
        text '0>= '
gtez    data $+2
        mov *stack,*stack           ; compare tos to 0
        jgt sTrue                   ; set true if tos>0
        jeq sTrue                   ; or if tos=0
        jmp sFalse                  ; else set result to false
;]

; The following routines are common to all the routines above.
; The first routine returns a true result, the second routine a false result.
; Each routine has two entry points, depending on whether 1 or 2 parameters
; should be removed from the stack.

    ; called when the result of the comparison is true
sTrue   seto *stack                 ; set value to -1 (true)
        b *next
        
    ; called when the result of the comparison is false
sFalse  clr *stack                  ; set result to 0 (false)
        b *next

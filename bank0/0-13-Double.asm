;  ____ ___         _     _ _    __          __            _     
; |___ \__ \       | |   (_) |   \ \        / /           | |    
;   __) | ) |______| |__  _| |_   \ \  /\  / /___  _ __ __| |___ 
;  |__ < / /|______| '_ \| | __|   \ \/  \/ // _ \| '__/ _` / __|
;  ___) / /_       | |_) | | |_     \  /\  /| (_) | | | (_| \__ \
; |____/____|      |_.__/|_|\__|     \/  \/  \___/|_|  \__,_|___/

; ########################################
; Double Number Extension Word Set
; Words to provide 32 bit math facilities
; ########################################
; Note: To save memory, these words may be removed completely and added to a
; support file on disk.

;[ 2DROP ( d -- )
drop2h  data ab0rth,5
        text '2DROP '
drop2   data $+2            
        c *stack+,*stack+       ; pop 2 words off the stack (cool, eh?)
        b *next
;]

;[ 2DUP ( d -- d d )
dup2h   data drop2h,4
        text '2DUP'
dup2    data $+2
        bl @bank1
        data _dup2              ; see 1-07-Double.a99
;]

; 2SWAP ( a b c d -- c d a b )

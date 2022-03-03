;  ______     _ _ _               __          __            _     
; |  ____|   | (_) |              \ \        / /           | |    
; | |__    __| |_| |_  ___  _ __   \ \  /\  / /___  _ __ __| |___ 
; |  __|  / _` | | __|/ _ \| '__|   \ \/  \/ // _ \| '__/ _` / __|
; | |____| (_| | | |_| (_) | |       \  /\  /| (_) | | | (_| \__ \
; |______|\__,_|_|\__|\___/|_|        \/  \/  \___/|_|  \__,_|___/
; block editor

lastwd    ; this is the last word in the built-in dictionary

; EDIT ( block# -- )
; loads 'block' and invokes the editor
; on exit from the editor, location TEMP is checked. If not 0, it loads
; the block number in TEMP. 
edith   data soundh,4
        text 'EDIT'
edit    data docol
        data qdup,zbrnch,edit1      ; just exit if block#=0
        
    ; if we happen to be in 32 column mode then switch to 40 column mode
        data gxmax                  ; get xmax
        data lit,32,eq              ; is it equal to 32?
        data zbrnch,edit0           ; just continue if not
        data lit0,gmode             ; otherwise set 40 column mode as default
        
edit0   data dup,block,swap         ; get block, block# to tos
        data cls                    ; clear screen 
        data lit,6,lit0,gotoxy      ; set cursor position for block number 
        data dot                    ; display block number 
        data edit3                  ; invoke editor

    ; at this point, we have returned from the editor.
    ; Check if the editor has requested another block...
        ;data cls
        data lit,lstblk,store0
        data lit,temp2,fetch,qdup   ; get value in temp
        data zbrnch,edit1           ; if 0 just exit
        data branch,edit0           ; otherwise, load next block

edit1   data cls,exit

edit3   data $+2
        bl @bank1
        data _edit                  ; see 1-11-Editor.a99


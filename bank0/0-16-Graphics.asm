;   _____                 _     _           __          __            _     
;  / ____|               | |   (_)          \ \        / /           | |    
; | |  __ _ __ __ _ _ __ | |__  _  ___ ___   \ \  /\  / /___  _ __ __| |___ 
; | | |_ | '__/ _` | '_ \| '_ \| |/ __/ __|   \ \/  \/ // _ \| '__/ _` / __|
; | |__| | | | (_| | |_) | | | | | (__\__ \    \  /\  /| (_) | | | (_| \__ \
;  \_____|_|  \__,_| .__/|_| |_|_|\___|___/     \/  \/  \___/|_|  \__,_|___/
;                  | |                                                      
;                  |_|                                                      
; graphics related commands
; the guts of these commands is in bank1 in 1-03-Graphics.a99

;[ GMODE ( graphics_mode -- )
gmodeh  data tstrh,5
        text 'GMODE '
gmode   data $+2
        bl @bank1
        data _gmode                 ; see 1-03-Graphics.a99
;]

;[ HCHAR ( y x ascii count -- )
hcharh  data gmodeh,5
        text 'HCHAR '
hchar   data $+2
        bl @bank1
        data _hchar                 ; see 1-03-Graphics.a99
;]
    
;[ VCHAR ( y x ascii count -- )
vcharh  data hcharh,5
        text 'VCHAR '
vchar   data $+2
        bl @bank1
        data _vchar                 ; see 1-03-Graphics.a99
;]

;[ GCHAR ( y x -- ascii )
gcharh  data vcharh,5
        text 'GCHAR '
gchar   data $+2
        bl @bank1
        data _gchar                 ; see 1-03-Graphics.a99
;]

;[ DCHAR ( W1..Wx  word_count ascii -- )
; loads words from the stack into VDP memory at the ASCII
; code specified. Equivalent to CALL CHAR in BASIC.
dcharh  data gcharh,5
        text 'DCHAR '
dchar   data $+2
        bl @bank1
        data _dchar                 ; see 1-03-Graphics.a99
;]

;[ SPRITE ( sprite y x ascii color -- )
; sprite attribute list begins at 6*80h=300h
sprith  data dcharh,6
        text 'SPRITE'
sprite  data $+2
        bl @bank1
        data _sprit                 ; see 1-03-Graphics.a99
;]

;[ MAGNIFY ( x -- )
; sets sprite magnification:
; only the least significant bits are used:
; bit 7: 1=magnified (0=not magnified)
; bit 6: 1=double size (4 character)
; Remember: TI number their bits backwards! Idiots!
magfyh  data sprith,7
        text 'MAGNIFY '
magfy   data $+2
        bl @bank1
        data _magfy                 ; see 1-03-Graphics.a99
;]

;[ SPRCOL ( sprite colour -- )
; sets the colour of a sprite
sprclh  data magfyh,6
        text 'SPRCOL'
sprcol  data $+2
        bl @bank1
        data _spcol                 ; see 1-03-Graphics.a99
;]

;[ SPRLOC ( sprite y x -- )
; sets the location of a sprite
sprlch  data sprclh,6
        text 'SPRLOC'
sprloc  data $+2
        bl @bank1
        data _sploc                 ; see 1-03-Graphics.a99
;]

;[ SPRLOC? ( sprite -- y x )
; gets the location of a sprite
locsph  data sprlch,7
        text 'SPRLOC? '
locspr  data $+2
        bl @bank1
        data _spget                 ; see 1-03-Graphics.a99
;]

;[ SPRPAT ( sprite ascii -- )
; sets the pattern of a sprite
sppath  data locsph,6
        text 'SPRPAT'
sprpat  data $+2
        bl @bank1
        data _sppat                 ; see 1-03-Graphics.a99
;]

;[ SPRVEC ( sprite y x -- )
; sets the Y and X movement vectors for sprite movement with SPRMOV
smlsth  data sppath,6
        text 'SPRVEC'
smlst   data $+2
        bl @bank1
        data _smlst                 ; see 1-03-Graphics.a99
;]

;[ SPRMOV ( start_sprite number_of_sprites -- )
; moves sprites according to the entries in SMLIST, starting from start_sprite
; and continuing for number_of_sprites
sprmvh  data smlsth,6
        text 'SPRMOV'
sprmov  data $+2
        bl @bank1
        data _spmov                 ; see 1-03-Graphics.a99
;]

;[ COINC ( tolerance spr1 spr2 -- flag )
; check for coincidence between sprite spr1 and spr2. If both the horizontal
; and vertical difference between the two sprites is < tolerance then the 
; sprites are considered to be in coincidence with each other and flag shall be
; true, otherwise it shall be false.
coinch  data sprmvh,5
        text 'COINC '
coinc   data $+2
        bl @bank1
        data _coinc                 ; see 1-03-Graphics.a99
;]

;[ COLOR ( char_set foreground background -- )
; sets the color sets in 32 column mode
colorh  data coinch,5
        text 'COLOR '
color   data $+2
        bl @bank1
        data _color                 ; see 1-03-Graphics.a99
;]

;[ SCREEN ( colour -- )
; sets the screen colour
scrnh   data colorh,6
        text 'SCREEN'
screen  data $+2
        bl @bank1
        data _scren                 ; see 1-03-Graphics.a99
;]

;[ SCROLL ( direction -- )
; scrolls the panel defined by PANEL in the direction specified
; 0=left 1=right 2=up 3=down
scrolh  data scrnh,6
        text 'SCROLL'
scroll  data $+2
        bl @bank1
        data _scrol                 ; see 1-03-Graphics.a99
;]

;[ PANEL ( x y xl yl -- )
; defines a screen area to be scrolled by SCROLL
panelh  data scrolh,5
        text 'PANEL '
panel   data $+2
        bl @bank1
        data _panel                 ; see 1-03-Graphics.a99
;]

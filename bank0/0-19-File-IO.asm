;  ______ _ _         _____     ______  
; |  ____(_) |       |_   _|   / / __ \ 
; | |__   _| | ___     | |    / / |  | |
; |  __| | | |/ _ \    | |   / /| |  | |
; | |    | | |  __/   _| |_ / / | |__| |
; |_|    |_|_|\___|  |_____/_/   \____/ 
; File IO implementation                                       

;[ FILE ( s_addr  s_len  buf_addr -- )
; Builds a PAB in the buffer whose address is passed as buf_addr using the data
; in the string represented by s_addr and s_len.
; For example:
;     FBUF: PRINTER
;     S" PIO.CR DV80O" PRINTER FILE
; The above builds a PAB in the buffer called PRINTER which references the PIO
; device. Subsequent file IO words that wish to send data to the PIO shall use
; the buffer name to reference it:
; e.g. 
;     PRINTER #OPEN DROP ( open PIO and drop success/fail flag)
;     S" HELLO WORLD" PRINTER #PUT DROP 
;     ( write HELLO WORLD to the PIO and drop success/fail flag)
;
; Internally, FILE builds a PAB in the buffer which will be used by #OPEN and 
; all file IO words. 
; Word 0 of the reserved memory is used to point to the actual PAB in VDP 
; memory. 
; Enough space should be reserved (with ALLOT) in the buffer to hold the PAB 
; and the filename.
;
; The string which specifies the file name and file characteristics is defined 
; as below. 
; The filename *must* come first followed by a space character. 
; After that, the file options can be specified in any order.
;
; File Options:
;  F=Fixed    - Fixed record type
;  V=Variable    - Variable record type
;
;  D=Display    - Display data type
;  L=InternaL    - Internal data type
;
;  U=Update    - Update file mode
;  O=Output    - Output file mode
;  I=Input    - Inoput file mode
;  A=Append    - Append file mode
;
;  S=Sequential - Sequential file type
;  R=Relative    - Relative file type
;
; Note that Internal type files require L - this is because I is used to 
; specify INPUT
fileh   data bloadh,4
        text 'FILE'
file1   data $+2
        bl @bank1
        data _file              ; see 1-14-File-IO.a99
;]

;[ FBUF: ( -- )
; builds a buffer with the name given for use with File IO. 
; The buffer is used to hold the PAB during construction by FILE.
; e.g. FBUF: MYFILE
; creates a 42 byte buffer for holding a PAB.
; MYFILE becomes a word in the dictionary which, when executed, returns the 
; address of the start of the buffer.
; The buffer is supplied as an input to the file IO words. E.g.
;   FBUF: DV80 ( create a 42 byte buffer called DV80)
;   S" DSK1.TEST DV80SO" DV80 FILE  
;   DV80 #OPEN DROP
;   S" HELLO WORLD" DV80 #PUT DROP
;   DV80 #CLOSE 
; 
fbufh   data fileh,immed+5
        text 'FBUF: '
fbuf    data docol
        data create         ; create dictionary entry
        data lit,42,allot   ; reserve 42 bytes
        data exit
;]

;[ #OPEN ( buf_addr -- t|f )
; Opens a file with the file name and attributes specified in the buffer
; starting at file_addr.
; The buffer (actually a PAB) is set-up with FILE.
; E.g. FBUF: SERIAL
;      S" RS232.BA=9600 DV80SO" SERIAL FILE
;      SERIAL #OPEN
; The above shall attempt to open the serial port for output as a Display 
; Variable 80 type file. 
;
; #OPEN leaves a FALSE on the stack if the file was opened sucessfully. 
; If the file could not be opened then it leaves a TRUE on the stack. 
; This allows easy trapping with ABORT" as shown below:
;   SERIAL #OPEN ABORT" Could not open serial port"
;
; In the event of a file error, IOERR can be read to get the DSR error code. 
; If IOERR returns -1 (>FFFF) then this means that no free file IO slots were 
; found. A maximum of 3 open files is supported (2 if block files are also to 
; be used).
; Note that block files are immediately closed after they are accessed for 
; either reading or writing, so 3 generic file io streams are available
; when no blocks files are being used.
fopenh  data fbufh,5
        text '#OPEN '        
fopen1  data $+2
        bl @bank1
        data _fopen              ; see 1-14-File-IO.a99
;]

;[ #CLOSE ( fid -- )
; closes a file
; Where a file is opened thus: MYFILE #OPEN
; the following will close the same file: MYFILE #CLOSE
fclosh  data fopenh,6
        text '#CLOSE'
fclose  data $+2
        bl @bank1
        data _fclos              ; see 1-14-File-IO.a99
;]

;[ #GET ( buff_addr fid -- t|f )
; reads a line of input from the file specified by fid.
; The address of an appropriately sized buffer must be supplied. 
; If the read is successful, the buffer is filled with the data read from the
; input device, with the first byte being the length count of the data 
; immediately following it.
; This can be converted into an address/length pair with COUNT.
; Returns:
;  False if successful
;  True if not successful
; This allows trapping with ABORT" as follows:
; MYFILE #GET ABORT" Could not read from the file"
; If the read fails, IOERR is set to the error code, otherwise it is zero'd
fgeth   data fclosh,4
        text '#GET'
fget    data $+2
        bl @bank1
        data _fget              ; see 1-14-File-IO.a99
;]

;[ #PUT ( buff_addr len fid - t|f )
; Places a string from buffer_addr with length len to the file represented by 
; fid. 
; Returns false if successful, else returns true. 
; This can be trapped with ABORT"
fputh   data fgeth,4
        text '#PUT'
fput    data $+2
        bl @bank1
        data _fput              ; see 1-14-File-IO.a99
;]

;[ #REC ( record# fid -- )
; Sets the record number for reading or writing for relative files
frech   data fputh,4
        text '#REC'
frec    data $+2
        bl @bank1
        data _frec              ; see 1-14-File-IO.a99
;]

;[ #5LOAD ( "filename" loadAddr -- )
load5h  data frech,6
        text 'LOAD#5'
load5   data docol
        data lit,8192,swap
        data lit,>0500
        data opt5
        data exit 
;]

;[ #5SAVE ( "filename" size saveAddr -- )
save5h  data load5h,6
        text 'SAVE#5'
        data docol
        data lit,>0600
        data opt5
        data exit 

opt5    data $+2
        bl @bank1           ; addr len size loadAddr opcode
        data _opt5
;]
        
;[ #EOF? ( fid -- t|f )
; returns true if currently positioned at the end of the file referenced by fid
feofh   data save5h,5
        text '#EOF? '
feof    data $+2
        bl @bank1
        data _feof              ; see 1-14-File-IO.a99
;]

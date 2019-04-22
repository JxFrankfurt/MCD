*-----------------------------------------------------------
* Title      : Menu Program
* Written by : Jackson Frankfurt
* Date       : 4/4/2019
* Description: This monitor program has 6 user facing functions:
	
*-----------------------------------------------------------
SUPER_STACK     EQU     $201400	; MUST BE A VALID RAM LOCATION
    ORG    $1000
START                  ; first instruction of program
	;0. Setup duart constants like the book (ACIAs?)
	;1. Display a menu
	;2. Get a char to see what the user wants to do
	;3. Do the thing
	;4. Redisplay the menu
		;all the menu options could be put into one string to make things faster

	JSR INIT_DUART		
	;JMP OPTION_DISPLAY
	;JMP OPTION_SELECTION ;Most of the program's execution happens in this loop
	
OPTION_DISPLAY
	MOVE.L A1,-(SP)
	LEA menu, A1 
	JSR PUT_STRING
	LEA optionOne, A1 
	JSR PUT_STRING
	LEA optionTwo, A1 
	JSR PUT_STRING
	LEA optionThree, A1 
	JSR PUT_STRING
 	LEA optionFour, A1 
	JSR PUT_STRING
	LEA optionFive, A1 
	JSR PUT_STRING
	LEA optionSix, A1 
	JSR PUT_STRING
	MOVE.L (SP)+,A1

OPTION_SELECTION
	MOVE.L D1,-(SP)	
OPTION_SELECTION_LOOP
	JSR GET_HEX ;output to D1 '06' ;contaminates D1
	;compare to 1,2,3,4,5,6
	CMP.B #1,D1
	BEQ dispMem ; Display a memory location
	CMP.B #2,D1
	BEQ editMem ; edit  a memory location
	CMP.B #3,D1
	BEQ dispReg ; Display a register
	CMP.B #4,D1
	BEQ editReg ; edit a register
	CMP.B #5,D1
	BEQ loadSRec ; load an S record
	CMP.B #6,D1
	BEQ exeSRec ; execute an S record
notAnOption ;if the user input is not a 1 through 6, print the menu and wait for another input.
	LEA menu, A1 
	JSR PUT_STRING
	BRA OPTION_SELECTION_LOOP	

dispMem
	MOVE.L (SP)+,D1
	JSR READ_MEMORY
	;JSR OPTION_DISPLAY
	JMP OPTION_DISPLAY
	
editMem
	MOVE.L (SP)+,D1
	JSR WRITE_MEMORY ;can only write word/long on even addresses. I only implemented byte inputs.
	;JSR OPTION_DISPLAY
	JMP OPTION_DISPLAY
	
dispReg
	MOVE.L (SP)+,D1
	;pop D1 here instead of at the end of selection?
	JSR READ_REGISTER
	;JSR OPTION_DISPLAY
	JMP OPTION_DISPLAY

editReg
	MOVE.L (SP)+,D1
	JSR WRITE_REGISTER
	;JSR OPTION_DISPLAY
	JMP OPTION_DISPLAY

loadSRec
	MOVE.L (SP)+,D1
	JSR LOAD_SREC
	;JSR OPTION_DISPLAY
	JMP OPTION_DISPLAY

exeSRec
	MOVE.L (SP)+,D1
	JSR EXE_SREC
	;JSR OPTION_DISPLAY
	JMP OPTION_DISPLAY
	
EXE_SREC ;execute the S-Record file stored in RAM: 00201500. Don't do this before loading an S-record. That's undefined behavior.
	JSR SRecLocation
	;the S-RECORD should end in an RTS
	RTS
	
LOAD_SREC ;Load all S-Record files to the same destination: RAM: 00201500 (offset by the number in the S-record?)
	;1. throw away S byte. 2. check how many bytes 3. check if it's a 0,1,or 8.
	;MOVEM D0-D2/A0,-(SP)
	MOVE.L D0,-(SP)
	MOVE.L D1,-(SP)
	MOVE.L D2,-(SP)
	MOVE.L A0,-(SP)
	MOVE.L A1,-(SP)
	MOVEA.L #SRecLocation,A0 ;(magic number) the address is actually within the S-Record, but I'm ignoring that for now.
	LEA SRecPrompt,A1
	JSR PUT_STRING
LS_NEXT_LINE
	JSR GET_CHAR ;throw away S byte
	JSR GET_HEX ;D1 will have '00', '01', or '08'
	MOVE.B D1,D0
	JSR GET_BYTE ;D1 has number of bytes to eat/read
	MOVE.B D1,D2
	CMPI.B #$01,D0
	BEQ READ_SREC
	CMPI.B #$08, D0
	BEQ CONSUME_BYTES_AND_END
	BRA CONSUME_BYTES
END_LOAD_SREC
	;MOVEM (SP)+,D0-D2/A0
	MOVE.L (SP)+,A1
	MOVE.L (SP)+,A0
	MOVE.L (SP)+,D2
	MOVE.L (SP)+,D1
	MOVE.L (SP)+,D0
	RTS
	
READ_SREC ;INPUT: D2 Contains number of bytes to read. The first two and the last byte read can be ignored.
	JSR GET_BYTE ;ignore the address in the S-Record. Magic number will be the starting address. All code must follow one ORG in the S-Record.
	JSR GET_BYTE
	SUBQ #$2, D2
RS_LOOP ;After each byte, increment the address
	JSR GET_BYTE ;D1 will have
	MOVE.B D1,(A0)+
	SUBQ.B #$1, D2
	CMPI.B #$1, D2 ;only one byte left-> eat checksum and get next line
	BGT RS_LOOP
	JSR GET_BYTE ;eat the checksum
	BRA LS_NEXT_LINE
	
CONSUME_BYTES ;INPUT: D2 contains the number in hex of bytes to eat with get_char
	JSR GET_BYTE ;gets one hex byte from 2 ascii bytes. This is okay.
	SUBQ #$1, D2
	BEQ LS_NEXT_LINE 	; not END_LOAD_SREC, instead: go to the next line.
	BRA CONSUME_BYTES
	
CONSUME_BYTES_AND_END ;INPUT: D2 contains the number of bytes to eat with get_char
	JSR GET_BYTE ;gets one hex byte from 2 ascii bytes. This is okay.
	SUBQ #$1, D2
	BEQ END_LOAD_SREC
	BRA CONSUME_BYTES_AND_END
	
WRITE_MEMORY ;ram only
	MOVEM D1/A0-A1,-(SP)
WMGet_Location	
	LEA promptWriteMemory1,A1 ;What location? RAM:(1000-FFFF)
	JSR PUT_STRING
	CLR.L D1
	JSR GET_WORD ;to D1 (hopefully this doesn't contaminate the upper word of D1)
	CMPI.L #$00001000,D1 ;make sure it's not less than 1000 (to keep it out of the stack)
	BLT WMGet_Location
	ADDI.L #$00200000,D1
	MOVE.L D1,A0
	LEA promptWriteMemory2,A1 ;What value? (00-FF)
	JSR PUT_STRING
	JSR GET_BYTE ;to D1
	JSR WRITE_BYTE
	MOVEM (SP)+,D1/A0-A1
	RTS
	
WRITE_BYTE
	;INPUTS: D1: BYTE TO WRITE A0: LOCATION TO WRITE
	MOVE.B D1,(A0)+ ;ODD OR EVEN LOCATIONS WORK
	RTS

WRITE_WORD ;INPUTS: D1: WORD TO WRITE A0: LOCATION TO WRITE
	MOVE.L D1,-(SP)
	JSR WRITE_BYTE ;writes the low byte of D1
	LSR.W #$8,D1
	JSR WRITE_BYTE
	MOVE.L (SP)+,D1
	RTS

WRITE_LONGWORD ;INPUTS: D1: LONGWORD TO WRITE A0: LOCATION TO WRITE
	MOVE.L D1,-(SP)
	JSR WRITE_WORD
	SWAP D1
	JSR WRITE_WORD
	MOVE.L (SP)+,D1
	RTS
	
READ_MEMORY ;print the contents of a memory location to putty ROM:(000000-00FFFF), RAM:(200000-20FFFF)
	;MOVEM	D0-D1/A0-A1,-(SP)
	MOVE.L D0,-(SP)
	MOVE.L D1,-(SP)
	MOVE.L A0,-(SP)
	MOVE.L A1,-(SP)
	LEA promptReadMemory1,A1 ;RAM(1) or RAM(2)
	JSR PUT_STRING
	JSR GET_CHAR ;D1 has the 31 or 32
	MOVE D1,D0
	LEA promptReadMemory2,A1 ;what address would you like to read? (0000-FFFF)
	JSR PUT_STRING
	CLR.L D1
	JSR GET_WORD ;D1 has the memory location (00FFFF) (hopefully GET_WORD doesn't contaminate the upper word)
	CMPI #$31,D0
	BEQ READ_RAM
	BRA READ_ROM
END_READ_MEMORY
	;MOVEM (SP)+, D0-D1/A0-A1
	MOVE.L (SP)+,A1
	MOVE.L (SP)+,A0
	MOVE.L (SP)+,D1
	MOVE.L (SP)+,D0
	RTS
READ_ROM
	
	;This code segment is intended to clear D1, except for the lower Word. It might not be needed.
	SWAP D1
	CLR.W D1
	SWAP D1
	MOVEA.L D1,A0 

	MOVE.L (A0),D0 ;I can access the location with (A0)
	JSR READ_D0 ;prints D0
	BRA END_READ_MEMORY
	
READ_RAM
	ADDI.L #$00200000,D1
	MOVEA.L D1,A0 ;A0 has 0020FFFF
	MOVE.L (A0),D0 ;this only works for even locations. (every other even location maybe?
	JSR READ_D0
	BRA END_READ_MEMORY
	
READ_REGISTER ;print the contents of a register to putty
	;MOVEM D0-D1/A1,-(SP)
	MOVE.L D0,-(SP)
	MOVE.L D1,-(SP)
	MOVE.L A1,-(SP)
	LEA promptReadReg1, A1 ;ask for which register to print
	JSR PUT_STRING
	MOVE.L (SP)+,A1 ;added this line to fix contaminated A1 (contaminated by prompt)
	JSR GET_BYTE ;D1 contains reg to print contents
	CMP.B #$D0,D1
	BEQ READ_D0_BRA
	CMP.B #$D1,D1
	BEQ READ_D1_BRA
	CMP.B #$D2,D1
	BEQ READ_D2_BRA
	CMP.B #$D3,D1
	BEQ READ_D3_BRA
	CMP.B #$D4,D1
	BEQ READ_D4_BRA
	CMP.B #$D5,D1
	BEQ READ_D5_BRA
	CMP.B #$D6,D1
	BEQ READ_D6_BRA
	CMP.B #$D7,D1
	BEQ READ_D7_BRA
	**Edit an address register
	CMP.B #$A0,D1
	BEQ READ_A0_BRA
	CMP.B #$A1,D1
	BEQ READ_A1_BRA
	CMP.B #$A2,D1
	BEQ READ_A2_BRA
	CMP.B #$A3,D1
	BEQ READ_A3_BRA
	CMP.B #$A4,D1
	BEQ READ_A4_BRA
	CMP.B #$A5,D1
	BEQ READ_A5_BRA
	CMP.B #$A6,D1
	BEQ READ_A6_BRA
	CMP.B #$A7,D1
	BEQ READ_A7_BRA
endRead
	;MOVEM (SP)+,D0-D1/A1
	*MOVE.L (SP)+,A1
	MOVE.L (SP)+,D1
	MOVE.L (SP)+,D0
	RTS
	
READ_D0_BRA
	JSR READ_D0
	JMP endRead
READ_D1_BRA
	;MOVE.L D1,D0
	;pop D1 before this. or do pointer arith? or just set it equal to the item without popping
	MOVE.L (SP),D0
	JSR READ_D0
	JMP endRead
READ_D2_BRA
	MOVE.L D2,D0
	JSR READ_D0
	JMP endRead
READ_D3_BRA
	MOVE.L D3,D0
	JSR READ_D0
	JMP endRead
READ_D4_BRA
	MOVE.L D4,D0
	JSR READ_D0
	JMP endRead
READ_D5_BRA
	MOVE.L D5,D0
	JSR READ_D0
	JMP endRead
READ_D6_BRA
	MOVE.L D6,D0
	JSR READ_D0
	JMP endRead
READ_D7_BRA
	MOVE.L D7,D0
	JSR READ_D0
	JMP endRead
READ_A0_BRA
	MOVE.L A0,D0
	JSR READ_D0
	JMP endRead
READ_A1_BRA
	MOVE.L A1,D0
	JSR READ_D0
	JMP endRead
READ_A2_BRA
	MOVE.L A2,D0
	JSR READ_D0
	JMP endRead
READ_A3_BRA
	MOVE.L A3,D0
	JSR READ_D0
	JMP endRead
READ_A4_BRA
	MOVE.L A4,D0
	JSR READ_D0
	JMP endRead
READ_A5_BRA
	MOVE.L A5,D0
	JSR READ_D0
	JMP endRead
READ_A6_BRA
	MOVE.L A6,D0
	JSR READ_D0
	JMP endRead
READ_A7_BRA
	MOVE.L A7,D0
	JSR READ_D0
	JMP endRead


READ_D0 ;Register(AABBCCDD) -> to ASCII(4141424243434444) -> PUT_CHAR
	;MOVEM D0-D2,-(SP)
	MOVE.L D0,-(SP)
	MOVE.L D1,-(SP)
	MOVE.L D2,-(SP)
	MOVE #$8,D2 ;loop counter
	JSR PUT_CRLF
D0_READ_LOOP ;currently prints "DDCCBBAA"
	*right now I'm printing the Bytes right to left. I want left to right. I can do this simply if I don't use a loop. :( I want a loop.
	ROL.L #$4, D0 ; "ABBCCDDA"
	JSR GET_ASCII ;D0 doesn't change, D1.B contains ascii to print
	JSR PUT_CHAR	;D1.B gets printed
	SUBQ #$1,D2
	BNE D0_READ_LOOP
	;MOVEM (SP)+,D0-D2
	MOVE.L (SP)+,D2
	MOVE.L (SP)+,D1
	MOVE.L (SP)+,D0
	RTS


*TODO: I currently compare the case value to all of D0. I just want to look at a nibble of D0
GET_ASCII
;input: D0 has a hex 0-9,A-F in lower nibble ex: 'XF' or 'X3'
;output: D1 has ascii character in the LSByte ex: '46' or '33'
;for instance, D0 holds 'XF' Hex which should be swapped to '46' by adding 37
	;throw away values that are not 0-9,A-F
	*0-9 go to 30-39
	MOVE.L D0,-(SP)
	*Clear most significant 4 bits of byte
	LSL.B #4,D0	;'F0'
	LSR.B #4,D0	;'0F'
	CMPI.B	#$A,D0	
	BLT	ADD_30
	;CMPI	#$10,D1
	BRA	ADD_37
END_GET_ASCII	
	MOVE.B D0,D1 ;D1 is output
	MOVE.L (SP)+,D0 ;restore D0
	RTS
	
ADD_30
	ADDI.B #$30, D0 ;D0 contains 37H which represents 7 in ascii
	BRA END_GET_ASCII

ADD_37
	ADDI.B #$37, D0 ;D0 contains 41H which represents A in ascii
	BRA END_GET_ASCII	
	
*Be careful changing the stack here. There are operations in write D0,D1,A1 which rely on pointer arithmetic using the stack.
WRITE_REGISTER
	MOVE.L  D0,-(SP)
	MOVE.L	D1,-(SP)
	MOVE.L	A1,-(SP)
	LEA promptWriteReg1, A1 ;print prompt asking for which register (registers D0-D7, A0-A6[no stack pointer editing. That would break things])
	JSR PUT_STRING
	JSR GET_BYTE ;D1 contains the register to edit
	MOVE.B D1,D0 ;save D1 in D0 so it isn't overwritten
	LEA promptWriteReg2, A1 ;print prompt asking for the value to write into the register
	JSR PUT_STRING
	JSR GET_LONGWORD ;D1 contains the value to put into the register
	**Branch to the section of code that will edit their desired register
	CMP.B #$D0,D0
	BEQ WRITE_D0
	CMP.B #$D1,D0
	BEQ WRITE_D1
	CMP.B #$D2,D0
	BEQ WRITE_D2
	CMP.B #$D3,D0
	BEQ WRITE_D3
	CMP.B #$D4,D0
	BEQ WRITE_D4
	CMP.B #$D5,D0
	BEQ WRITE_D5
	CMP.B #$D6,D0
	BEQ WRITE_D6
	CMP.B #$D7,D0
	BEQ WRITE_D7
	**Edit an address register
	CMP.B #$A0,D0
	BEQ WRITE_A0
	CMP.B #$A1,D0
	BEQ WRITE_A1
	CMP.B #$A2,D0
	BEQ WRITE_A2
	CMP.B #$A3,D0
	BEQ WRITE_A3
	CMP.B #$A4,D0
	BEQ WRITE_A4
	CMP.B #$A5,D0
	BEQ WRITE_A5
	CMP.B #$A6,D0
	BEQ WRITE_A6
END_WRITE_REGISTER
	MOVE.L (SP)+,A1
	MOVE.L (SP)+,D1
	MOVE.L (SP)+,D0
	RTS

*Write D0, D1, A1 while they're still on the stack
WRITE_D0
	MOVE.L A2,-(SP)
	MOVEA #$C,A2 ;D0 is C bytes from the top of the stack
	ADD.L SP,A2 ;A2 now points at the value we will restore to D0
	MOVE.L D1,(A2)
	MOVE.L (SP)+,A2
	BRA END_WRITE_REGISTER
WRITE_D1
	MOVE.L A2,-(SP)
	MOVEA #$8,A2 
	ADD.L SP,A2
	MOVE.L D1,(A2)
	MOVE.L (SP)+,A2
	BRA END_WRITE_REGISTER
WRITE_D2
	MOVE.L D1,D2
	BRA END_WRITE_REGISTER
WRITE_D3
	MOVE.L D1,D3
	BRA END_WRITE_REGISTER
WRITE_D4
	MOVE.L D1,D4
	BRA END_WRITE_REGISTER
WRITE_D5
	MOVE.L D1,D5
	BRA END_WRITE_REGISTER
WRITE_D6
	MOVE.L D1,D6
	BRA END_WRITE_REGISTER
WRITE_D7
	MOVE.L D1,D7
	BRA END_WRITE_REGISTER
WRITE_A0
	MOVE.L D1,A0
	BRA END_WRITE_REGISTER
WRITE_A1
	MOVE.L D1,(SP)
	BRA END_WRITE_REGISTER
WRITE_A2
	MOVE.L D1,A2
	BRA END_WRITE_REGISTER
WRITE_A3
	MOVE.L D1,A3
	BRA END_WRITE_REGISTER
WRITE_A4
	MOVE.L D1,A4
	BRA END_WRITE_REGISTER
WRITE_A5
	MOVE.L D1,A5
	BRA END_WRITE_REGISTER
WRITE_A6
	MOVE.L D1,A6
	BRA END_WRITE_REGISTER


* Put program code here
;input: GET_CHAR -> D1 has an ascii character representing 0-9,a-f,A-F
;output: D1.B contains a hex value in the lower nibble. ex: 'XF' or 'X3'
;for instance, D1 holds '41'Hex which should be swapped to 'A'
GET_HEX 
	JSR GET_CHAR
	
 	*compare d1 to hex ranges if they match, branch to a system to deal with them. else, process the next character
	*BETWEEN 30 AND 39 ARE DIGITS
	CMP.B	#$30,D1
	BLT	GET_HEX
	
	CMP.B	#$40,D1
	BLT	SUB_30
	*BETWEEN 41 AND 46 ARE UPPERCASE LETTERS
	CMP.B	#$41,D1
	BLT	GET_HEX
	
	CMP.B	#$47,D1
	BLT	UP_LETTER
	*BETWEEN 61 AND 66 ARE LOWERCASE LETTERS
	CMP.B	#$61,D1
	BLT	GET_HEX
	
	CMP.B	#$67,D1
	BLT	LOW_LETTER
	*ANYTHING ELSE NOT LOWER THAN 67 IS AN ERROR-> skip to the next character
	BRA GET_HEX
	RTS
	
*TAKES INPUT IN D1, SUBTRACTS 30H FROM IT, AND PUTS IT IN D1
SUB_30 
	SUB.B	#$30,D1
	RTS
	
UP_LETTER
*SUBTRACT LIKE 37H TO GET TO THE LETTER
	SUB.B	#$37,D1
	RTS
	
LOW_LETTER
*SUBTRACT LIKE 57H TO GET THE LETTER
	SUB.B	#$57,D1
	RTS
	
GET_BYTE ;D1 output
	MOVE.L    D0,-(SP) ;put D0 onto the stack
	JSR GET_HEX ;D1 has '0A'
	LSL.B #4,D1 ;D1 has 'A0'
	;copy D1 to D0
	MOVE.B    D1,D0 ;D0 has 'A0'
	
	JSR GET_HEX ;D1 has '05'
	ADD.B D0,D1 ;D1 has 'A5'
	MOVE.L (SP)+,D0 ;pop D0 back off the stack
	RTS
	
GET_WORD ;D1 output
	JSR GET_BYTE ;D1 has 'XXA5'
	LSL.W #8,D1 ;D1 has 'A500'
	JSR GET_BYTE ; D1 has 'A542'
	RTS
	
GET_LONGWORD ;D1 output
	JSR GET_WORD ;D1 has 'XXXXA542'
	SWAP D1 ;D1 has 'A542XXXX'
	JSR GET_WORD ;D1 has 'A5421012'
	RTS
PUT_CRLF
	MOVE.L A1,-(SP)
	LEA CRLF,A1
	JSR PUT_STRING
	MOVE.L (SP)+,A1
	RTS
*-----------------------------------------
;PUT STRING SUBROUTINE
PUT_STRING
	;LEA (menu,PC),A1 ;assume A1 contains the address to the the string to be printed
	MOVE.B D1,-(SP)
PUT_STRING_CHECK_NULL
	;compare (A1) to null terminator (null terminator is zero)
	MOVE.B (A1)+,D1
	CMP.B #$00,D1
	;if so-> rts
	BEQ NULL_TERMINATOR
	;else-> putchar,A++
	JSR PUT_CHAR
	JMP PUT_STRING_CHECK_NULL ;Unconditional jump to the top of this code block (BRA or JMP?)
NULL_TERMINATOR
	MOVE.B (SP)+,D1
	RTS
;TODO: Figure out how I should access the string that is hardcoded below.
*-----------------------------------------------
*----------------------------------------------
;GET CHAR SUBROUTINE, takes it from putty and puts it into D1
*GET_CHAR 
*;SRA = Status Register A; "Is there something there to receive?"
*;RBA = Receive buffer A; "Get the data that is there."
*;We flush the extra data b/c (for some reason) multiple are sent via putty.
*		;DUARTAddress -> A0
*		MOVE.L	D0,-(SP)
*		LEA DUART, A0
*IN_POLL  MOVE.B SRA(A0),D0
*         BTST   #RxRDY,D0
*         BEQ    IN_POLL
*         
*CLEAR_BUFFER
*         MOVE.B RBA(A0),D1
*         MOVE.B SRA(A0),D0
*         BTST   #RxRDY,D0
*         BNE CLEAR_BUFFER
*
*         JSR PUT_CHAR *display what you get everytime
*		MOVE.L (SP)+,D0
*         RTS
*----------------------------------------------
*----------------------------------------------
;PUT CHAR SUBROUTINE, Takes D1 and outputs it to putty
*PUT_CHAR 
*;TBA = Transmit buffer A; "put stuff here to send it through serial connection"
*         MOVE.W D2, -(SP)
*;Status Register A
*OUT_POLL MOVE.B SRA(A0),D2
*         BTST   #TxRDY,D2
*         BEQ    OUT_POLL
*;Transmitter Buffer A
*         MOVE.B D1,TBA(A0)
*
*         MOVE.W (SP)+,D2
*
*         RTS 
*----------------------------------------------  
*----------------------------------------------  SIM
;	 Read a single character from the keyboard into D1.B.
GET_CHAR   MOVE.L      D0,-(SP)
	         MOVE.L	    #5, D0
	         TRAP	    #15
	         ;jsr put_char
            MOVE.L      (SP)+,D0
            RTS
*---------------------------------------------- SIM
PUT_CHAR    MOVE.L      D0,-(SP)
            MOVE.L      #6,D0           Trap task 6 does the following:
            TRAP        #15             DISPLAY a CHARACTER from D1.B
            MOVE.L      (SP)+,D0
            RTS
*----------------------------------------------
INIT_DUART 
	MOVE.L	A0,-(SP)
	LEA DUART,A0 ;A0 points to base DUART address
; Software reset:
	MOVE.B #$30,CRA(A0) ;Reset TxA
	MOVE.B #$20,CRA(A0) ;Reset RxA
	MOVE.B #$10,CRA(A0) ;Reset MRA pointer

; Initialization:

	MOVE.B #$80,ACR(A0) ;selects baud rate set 2
	MOVE.B #BAUD,CSRA(A0) ;set 19.2k baud Rx/Tx

	MOVE.B #$13,MR1A(A0) ;8-bits, no parity, 1 stop bit
; This is the most important register to set in the 68681 DUART.
; 07 sets: Normal mode, CTS and RTS disabled, stop bit length = 1
; For testing load $#47 to enable auto-echo
	MOVE.B #$07,MR2A(A0)
	MOVE.B #$05,CRA(A0) ;enable Tx and Rx
	MOVE.L (SP)+,A0
	RTS
	

* Put variables and constants here
; *******************************************************************
; Constants: (Note the offsets to account for no A0)
DUART EQU $400000 ;loaded in A0 when needed, regs are offsets
MR1A EQU 1 ;Mode Register1
MR2A EQU 1 ;points here after MR1A is set
SRA EQU 3 ;Status Register (read)
CSRA EQU 3 ;Clock Select Register
CRA EQU 5 ;Command Register
TBA EQU 7 ;Transfer Holding Register
RBA EQU 7 ;Receive Holding Register
ACR EQU 9 ;Auxiliary control register
RxRDY EQU 0 ;Recieve ready bit position
TxRDY EQU 2 ;Transmit ready bit position
BAUD EQU $CC ;baud rate value = 19,200 baud
; *******************************************************************
SRecLocation EQU $00201500 ;This is where I put the user's S-record
menu DC.B 10,13,'This is my menu. Type a number 1 through 6.',0
optionOne DC.B 10,13,'1. Display a memory location',0
optionTwo DC.B 10,13,'2. Write to a memory location',0
optionThree DC.B 10,13,'3. Display a register',0
optionFour DC.B 10,13,'4. Write to a register',0
optionFive DC.B 10,13,'5. Load an S record',0
optionSix DC.B	10,13,'6. Execute the program',10,13,0 
promptReadReg1 DC.B 10,13,'What register would you like to read? (D0-D7/A0-A7)',10,13,0
promptWriteReg1 DC.B 10,13,'What register would you like to edit? (D0-D7/A0-A6)',10,13,0
promptWriteReg2 DC.B 10,13,'What hexidecimal value do you want to put into that register? (000000-FFFFFF)',10,13,0
promptReadMemory1 DC.B 10,13,'Read RAM(1) or ROM(2)?',10,13,0
promptReadMemory2 DC.B 10,13,'What memory location would you like to read? (0000-FFFF)',10,13,0
promptWriteMemory1 DC.B 10,13,'What memory location would you like to edit? RAM:(1000-FFFF)',10,13,0
promptWriteMemory2 DC.B 10,13,'What hexidecimal value do you want to put into that memory location? (00-FF)',10,13,0 ;LONGWORD/WORD doens't work on odd addresses. This is a place to add functionality if I have time.
SRecPrompt DC.B 10,13,'Copy and paste an SRec[0,1,8] here:',10,13,0
CRLF DC.B 10,13,0
    END    START        ; last line of source





*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~

*-----------------------------------------------------------
* Program    : Test Loop
* Written by : Instructor
* Date       : 2010
* Description: Testing RAM with a subroutine jump. To jump
*              to a subroutine, the PC and SR are pushed onto
*              the stack which is a location in RAM. If the
*              program continually loops, the RAM is working
*-----------------------------------------------------------
*-----------------------------------------------------------
* Subroutine : DUART enable
* Written by : Instructor
* Date       : 2013
* Description: used to initialize a 68681 DUART
*-----------------------------------------------------------

* Note, most DUART configurations are ignorant of UDS/LDS 
* and thus are only active on odd addresses (since the lower 
* data lines are usually run to the DUART data bus)

; *******************************************************************
; Constants:	(Note the offsets to account for no A0)
DUART   	EQU	$420000     loaded in A0 when needed, regs are offsets
MR1A   	EQU   	1	Mode Register1
MR2A  	EQU   	1	points here after MR1A is set
SRA    	EQU   	3     Status Register (read)
CSRA   	EQU   	3     Clock Select Register
CRA   	EQU   	5	Command Register
TBA		EQU   	7     Transfer Holding Register
RBA		EQU   	7	Receive Holding Register
ACR		EQU	  	9	Auxiliary control register
RxRDY		EQU		0	Recieve ready bit position
TxRDY		EQU		2	Transmit ready bit position
BAUD		EQU	  	$CC   baud rate value = 19,200 baud
; *******************************************************************




SUPER_STACK     EQU     $200800	; MUST BE A VALID RAM LOCATION


START   	ORG     $000000
        	DC.L    SUPER_STACK
        	DC.L    INIT

        	ORG     $000100
INIT        JSR INIT_DUART       
MAIN    	JSR	RAM_TEST
		    JMP	MAIN
        
RAM_TEST 	NOP
        	NOP
		    NOP
		    JSR GET_CHAR
		    RTS
*----------------------------------------------
;GET CHAR SUBROUTINE, takes it from putty and puts it into D1
GET_CHAR 
;SRA = Status Register A; "Is there something there to receive?"
;RBA = Receive buffer A; "Get the data that is there."
		;DUARTAddress -> A0
		MOVE.L	D0,-(SP)
		LEA DUART, A0
IN_POLL  MOVE.B SRA(A0),D0
         BTST   #RxRDY,D0
         BEQ    IN_POLL
         
CLEAR_BUFFER
         MOVE.B RBA(A0),D1
         MOVE.B SRA(A0),D0
         BTST   #RxRDY,D0
         BNE CLEAR_BUFFER

         JSR PUT_CHAR *display what you get everytime
		MOVE.L (SP)+,D0
         RTS
*----------------------------------------------
*----------------------------------------------
;PUT CHAR SUBROUTINE, Takes D1 and outputs it to putty
PUT_CHAR 

         MOVE.W D2, -(SP)
;Status Register A
OUT_POLL MOVE.B SRA(A0),D2

         BTST   #TxRDY,D2

         BEQ    OUT_POLL
;Transmitter Buffer A
         MOVE.B D1,TBA(A0)

         MOVE.W (SP)+,D2

         RTS 
*----------------------------------------------  

INIT_DUART  LEA	  	DUART,A0		A0 points to base DUART address

; Software reset:
      	MOVE.B	#$30,CRA(A0)	Reset TxA
		MOVE.B	#$20,CRA(A0)	Reset RxA
		MOVE.B	#$10,CRA(A0)	Reset MRA pointer

; Initialization:
    MOVE.B  	#$80,ACR(A0)	selects baud rate set 2
    MOVE.B  	#BAUD,CSRA(A0)  	set 19.2k baud Rx/Tx
    MOVE.B  	#$13,MR1A(A0)   	8-bits, no parity, 1 stop bit

; This is the most important register to set in the 68681 DUART.
; 07 sets: Normal mode, CTS and RTS disabled, stop bit length = 1
; For testing load $#47 to enable auto-echo
      	MOVE.B	#$07,MR2A(A0)	

      	MOVE.B	#$05,CRA(A0)	enable Tx and Rx
      	RTS


        	END     INIT
    





*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~

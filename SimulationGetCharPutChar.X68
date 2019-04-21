*Here is a little bit of code you can put in your monitor program to switch
*between simulating your code and running it on your hardware. The simulating
*software does not get keyboard text the same way as the DUART so this change
*in code is needed only for simulations.
*RECOMMENDATION: Use this code once you have verified ROM, RAM, and DUART are
*function properly and you have working GETCHAR and PUTCHAR subroutines.
*SIM EQU 1 ;0 = hardware state, 1 = simulation state
**************************************************
IF.B SIM <NE> #00 THEN.L ;when simulating, turn off keyboard echo
MOVE.B #$00,D1
MOVE.B #12,D0
TRAP #15
ENDI
**************************************************
*GCHAR gets an input character and stores is in D0
GCHAR IF.B SIM <EQ> #00 THEN.L
*INSERT YOUR HARDWARE GETCHAR CODE
ELSE
MOVE.L D1, -(SP)
MOVE.L #05, D0
TRAP #15
MOVE.B D1, D0
MOVE.L (SP)+, D1
ENDI
**************************************************
*PCHAR outputs the character on D0
PCHAR IF.B SIM <EQ> #00 THEN.L
*INSERT YOUR HARDWARE PUTCHAR CODE
ELSE
MOVE.L D0, -(SP) 
*Task

MOVE.L D1, -(SP) 
*Char to display

MOVE.B D0, D1
MOVE.L #06, D0
TRAP #15
MOVE.L (SP)+, D1
MOVE.L (SP)+, D0
ENDI
RTS
*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~

@SCHKUZ002, MLKTSH012

	.syntax unified
	.global _start

	.equ GPIOB_BASE, 0x48000400
	.equ GPIOA_BASE, 0x48000000
	.equ RCC_BASE, 0x40021000

@+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ INITIALISATION BLOCK +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
@ BEGIN: INITIALISATION
@ The following block of code initializes the STM32F0 Microcontroller


vectors:
	.word 0x20002000
	.word _start + 1

_start:
	@ The following block enables the GPIOB (LED Lights) and GPIOA (Push Buttons & POTs) by setting the 18th and 17th bit of the RCC_AHBENR
	LDR R0, =RCC_BASE								@ R0 = RCC base address
	LDR R1, [R0, #0x14]								@ R1 = RCC_AHBENR			
	LDR R2, =0x60000								@ 17th & 18th bit high (Clock Port A & Port B)
	ORRS R1, R1, R2 								@ Force 17th & 18th bit (IOBEN) high	
	STR R1, [R0,#0x14]								@ Write back to RCC_AHBENR

	@ The following block sets the mode of the GPIOB to output for the LEDs (1st 8 bits)
	LDR R0, =GPIOB_BASE								@ R0 = GPIOB base address
	LDR R1, [R0, #0x00]								@ R1 = GPIOB_MODER
	LDR R2, =0x5555						@ Pattern to set first 8 pairs of bits to be 01 (output)
	ORRS R1, R1, R2									@ Force the bits high, leaving the other bits unchanged
	STR R1, [R0, #0x00]								@ Write back to GPIOB_MODER

	LDR R0, =GPIOA_BASE								@ R0 = GPIOA base address		
	LDR R1, [R0, #0x00]								@ R1 = GPIOA_MODER
	LDR R2, =0x3000				 					@ Pattern to set all bits to be 00 (input) & PA6 (POT1) to Analog (11)
	ORRS R1, R1, R2									@ Force the bits low, leaving the other bits unchanged
	STR R1, [R0, #0x00]								@ Write back to GPIOA_MODER

	LDR R0, =GPIOA_BASE								@ R0 = GPIOA base address
	LDR R1, [R0, #0x0C]								@ R1 = GPIOA_PUPDR
	LDR R2, =0x5						@ Pattern to set switch 0-1 to be 01 (input)
	ORRS R1, R1, R2									@ Force the bit high, leaving the other bits unchanged
	STR R1, [R0, #0x0C]								@ Write back to GPIOA_PUPDR

@GLOBAL VARIABLES
	MOVS R7, #0xFF 									@ R7 =  DIFFERENCE = (init) 255. 	Initialise R7 to MAX(255)
	MOVS R6, #0x0 									@ R6 =	BEST LARGE = B = (init) 0.
	MOVS R5, #0x0 									@ R5 = 	BEST SMALL = A = (init) 0.
	MOVS R4, #0xFF 									@ R4 = 	BEST SMALL = A = (init) 255.

all_off:
	@ Read in the data from GPIOB_ODR, force the lower byte to 0 and write back
	LDR R0, =0x48000400								@ R0 = GPIOB base address
    LDR R1, [R0, #0x14]                 			@ R1 = GPIOB_ODR (R0 still contains GPIOB base address from above)
    LDR R2, =0xFFFFFF00								@ Pattern which will leave upper 3 bytes unchanged while clearing lower byte                 
    ANDS R1, R1, R2                     			@ Clear lower byte of ODR
    STR R1, [R0, #0x14]								@ Write back to GPIOB_ODR
    
@init_display:
	@LDR R0, =0x48000400
	@MOVS R2, #0xA									@ R2 = LED display value (#10)
	@STR R2, [R0,#0x14]								@ Write back to GPIOB_ODR
	@B main_loop										@ Branch to main_loop

@ END: INITIALISATION	
@+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ INITIALISATION BLOCK +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

	
LDR R0, DATA_START									@ R0 = DATA_START Pointer
MOVS R2, #0x0 										@ R2 = STACK_COUNT (init) 0.
MOVS R3, #0x0 										@ R3 = RUNNING_DIFFERENCE (init) 0.

data_load:
	CMP R2, #0x14 									@ COMPARE R2 : 20 (20 Elements in Dataset)
	BEQ stack_push_done
	LDRB R1, [R0,R2]
	PUSH {R1}
	ADDS R2, R2, #0x1 								@ R2 = R2 + 1 		INCREMENT STACK_COUNT
	B data_load

@>>> R1 : USAGE END

stack_push_done:
	B start_compare

start_compare:
	POP {R5}										@ R5 = STACK_POP(small) POP smallest value from stack
	B diff

diff:
	CMP R2, #0x1 									@ COMPARE R2 : 1 (Check if there are anymore elements in the database)
	BEQ main_loop
	POP {R6}										@ R6 = STACK_POP(large) POP next smallest value from stack
	SUBS R2, R2, #0x1 								@ R2 = R2 - 1 		DECREMENT STACK_COUNT
	SUBS R3, R6, R5									@ R3 = R6 - R5
	CMP R7, R3 										@ COMPARE R7 (BEST_DIFF) : R3 (RUNNING_DIFFERENCE)
	BHI update_best
	MOVS R5, R6
	B diff

update_best:
	MOVS R7, R3
	MOVS R4, R5 
	B diff

@>>> R2 : USAGE END

displayA:
	LDR R0, =GPIOB_BASE
	STR R4, [R0,#0x14]								@ Write back to GPIOB_ODR
	
	LDR R1, =0x186A00 								@ R1 = DELAY
	B delayA										

delayA:
	SUBS R1, #1 									@ Decrement loop iteration number
	CMP R1, #0 										@ Check if R3 = 0 (end of delay)
	BNE delayA										@ If not end of delay, continue to next iteration
	B displayB

displayB:
	LDR R0, =GPIOB_BASE
	ADDS R2, R4, R7
	STR R2, [R0,#0x14]								@ Write back to GPIOB_ODR
	LDR R1, =0x186A00 								@ R1 = DELAY
	B delayB

delayB:
	SUBS R1, #1 									@ Decrement loop iteration number
	CMP R1, #0 										@ Check if R3 = 0 (end of delay)
	BNE delayB										@ If not end of delay, continue to next iteration
	B displayA	


main_loop:
	B displayA
	B main_loop



    .align
DATA_START: .word DATA
@ don't modify the following. 
DATA:  
    .word 0xD8E7F2FE
    .word 0xA4B0BDC9
    .word 0x717B8B99
    .word 0x3A455E62
    .word 0x05142231
DATA_END: 

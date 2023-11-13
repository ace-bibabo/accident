.include "m2560def.inc"

;register design
; permanent values
; r11 store flight direction @Yihang
; r12 store hover or flight state @Yihang



;r16 store row in keypad @Yihang
;r17 stored speed in push button module @LiLi

;r18 store temp value use in wait macro @LiLi
;    store temp value use in flash led  @Brian 


;r19 store column in keypad @Yihang
;r20 store rmask@Yihang
;r21 store cmask@Yihang

;r22 store temp value used in keypad scanning@Yihang
;	 store temp value user in led @Brian

;r23 store temp value used in keypad scanning@Yihang


;r24 store temp value be used with r25 in func sleep_1ms @LiLi


;r25 store temp value be used with r24 in func sleep_1ms @LiLi




; sleep_1ms: delay 1ms used r25: r24   @LiLi

; macro
; wait: can delay 256ms used r18 @LiLi


; module push button @LiLi
; press pb0 inc speed; press pb1 dec speed; speed be stored in r17
; portd 0: pb0 
; portd 1: pb1
; portc: output led display for debugging


; module led @Brian
; .def tmp = r20
; .def count = r21
; .def incr = r22
; .def delay_register = r23


; module reset @Deniel
; updating

; module lcd @Chatwit
; updating

; module keypad @Yihang
; RF7-4 connect to C3-0, RF3-0 connect to R3-0.
; use PortF for input/output from keypad: PF7-4, output, PF3-0, input. 
; panel set figure
; north = 2, east = 6, south = 8, west = 4, up = A, down = B, state change = C 
;	-	N	-	 up			|	1	2	3	A
;	w	-	E	down		|	4	5	6	B
;	-	S	-	 SC			|	7	8	9	C
;	-	-	-	 --			|	*	0	#	D	





;portd 0 as pb0 portd 1 as pb1
;portc as led display
;r17 as speed register
;r18 as temp register, use in wait
;func : sleep 1ms
;macro : wait 256ms

.include "m2560def.inc"
; use for delay func
.def iH = r25
.def iL = r24
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4


;;;;;;;;;;;;;;;;;;;push button ;;;;;;;;;;;;;
.def speed = r17
.def tmp = r18


; input push button
cbi ddrd,0								;pb0
cbi ddrd,1								;pb1

;;;;;;;;;;;;;;;;;led;;;;;;;;;;;;;;;;;;;;;;;
.def tmp = r18
.def count = r22

.equ PATTERN_1 = 0b10101010
.equ PATTERN_2 = 0b01010101


;;;;;;;;;;;;;;;; keypad ;;;;;;;;;;;;;;;;;;;;
; Port F is used for keypad, high 4 bits for column selection, low four bits for reading rows. On the board, RF7-4 connect to C3-0, RF3-0 connect to R3-0.
; north = 2, east = 6, south = 8, west = 4, up = A, down = B, state change = C 
;	-	N	-	 up			|	1	2	3	A
;	w	-	E	down		|	4	5	6	B
;	-	S	-	 SC			|	7	8	9	C
;	-	-	-	 --			|	*	0	#	D	
.def row    =r16		; current row number
.def col    =r19		; current column number
.def rmask  =r20		; mask for current row
.def cmask	=r21		; mask for current column
.def temp1	=r22		
.def temp2  =r23

.equ PORTFDIR =0xF0			; use PortF for input/output from keypad: PF7-4, output, PF3-0, input. 0xF0 = 0b11110000
.equ INITCOLMASK = 0xEF		; scan from the leftmost column, the value to mask output. 0xEF = 0b11101111 
.equ INITROWMASK = 0x01		; scan from the top row. 0x01 = 0b00000001
.equ ROWMASK  =0x0F			; low four bits are output from the keypad. This value mask the high 4 bits. 0x0F = 0b00001111




;;;;;;;;;;;;;;;;;;;macro wait 256ms;;;;;;;;;;;;;;;;;;;;;
.macro wait
	ser tmp
wait_loop:
	dec tmp
	tst tmp
	breq wait_end
	rcall sleep_1ms
	rjmp wait_loop
wait_end:
	nop
.endmacro

.macro display
	; output led
	ser tmp
	out ddrc, tmp ;
	out portc, @0
	wait
end_display:
	nop	
.endmacro 





;;;;;;;;;;;;;;;;;push button start;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
speed_init:
	ldi speed, 1							; set init speed as 1
	out portC, speed
	;wait

speed_set:
	sbis pind, 0							; if pb0 pressed run inc speed
	rjmp speed_inc

	sbis pind, 1							; if pb1 pressed run desc speed
	rjmp speed_dec

	rjmp speed_set


speed_inc:
	cpi speed, 10					
	breq speed_set							;if == 8m/s go to speed set
	inc speed

	display speed							; just for debug speed

	wait
	rjmp speed_set

speed_dec:
	cpi speed, 1							;if == 1m/s go to speed set
	breq speed_set
	dec speed

	display	speed							;  just for debug speed

	wait
	rjmp speed_set

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;push button end;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;led flashing start;;;;;;;;;;;;;;;;;;;;;
; Flash macro
.macro flash_n_times
push count
clr count
flash_loop:
	cpi count, @0
	breq end_flash_loop
	rcall flash_led
	inc count
	rjmp flash_loop
end_flash_loop:
	pop count
.endmacro

;output
ser tmp
out ddrc, tmp
out ddrg, tmp
clr count

flash_start: 
	flash_n_times 2
end:
	rjmp end

; flashes the led using two pre-defined patterns
flash_led:
	push tmp
	ser tmp
	out ddrc, tmp
	out ddrg, tmp

	ldi tmp, PATTERN_1
	out portc, tmp
	ldi tmp, 2
	out portg, tmp

	wait

	ldi tmp, PATTERN_2
	out portc, tmp
	ldi tmp, 1
	out portg, tmp

	wait

	clr tmp
	out ddrc, tmp
	out ddrg, tmp
	pop tmp
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;led flashing end;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;keypad  start;;;;;;;;;;;;;;;;;;;;;;;;;;;
RESET:
	ldi temp1, PORTFDIR			; columns are outputs, rows are inputs
	out	DDRF, temp1

keypad_main:
	ldi cmask, INITCOLMASK		; initial column mask
	clr	col						; initial column
colloop:
	cpi col, 4
	breq keypad_main
	out	PORTF, cmask			; set column to mask value (one column off)
	ldi temp1, 0xFF
delay:
	dec temp1					; decrease temp1
	brne delay					; if temp1 != 0, jump to delay, otherwise continue

	in	temp1, PINF				; read PORTF
	andi temp1, ROWMASK
	cpi temp1, 0xF				; check if any rows are on
	breq nextcol
								; if yes, find which row is on
	ldi rmask, INITROWMASK		; initialise row check
	clr	row						; initial row
rowloop:
	cpi row, 4
	breq nextcol
	mov temp2, temp1
	and temp2, rmask			; check masked bit
	breq convert 				; if bit is clear, convert the bitcode
	inc row						; else move to the next row
	lsl rmask					; shift the mask to the next bit
	jmp rowloop

nextcol:
	lsl cmask					; else get new mask by shifting and
	inc col						; increment column value
	jmp colloop					; and check the next column

convert:
	cpi col, 3					; if column is 3 we have a letter
	breq letters
	cpi row, 3					; if row is 3 we have a symbol or 0
	breq symbols

	mov temp1, row				; otherwise we have a number in 1-9
	lsl temp1
	add temp1, row				; temp1 = row * 3
	add temp1, col				; add the column address to get the value
	inc temp1					; actual value = row * c + column + 1
	ldi temp2,48				; convert decimal to their ascii values, actual value + ascii shift (48)
	add temp1,temp2
	jmp convert_end

letters:
	ldi temp1, 65				; load Ascii value of 'A' 65
	add temp1, row				; increment the character 'A' by the row value
	jmp convert_end

symbols:
	cpi col, 0					; check if we have a star
	breq star
	cpi col, 1					; or if we have zero
	breq zero
	ldi temp1, 35				; if not we have hash, load ascii value of hash (35)
	jmp convert_end
star:
	ldi temp1, 42				; set to ascii value of star (42)
	jmp convert_end
zero:
	ldi temp1, 48				; set to ascii value of '0' (48)


; north = 2, east = 6, south = 8, west = 4, up = A, down = B, state change = C
;	-	N	-	 up			|	1	2	3	A
;	w	-	E	down		|	4	5	6	B
;	-	S	-	 SC			|	7	8	9	C
;	-	-	-	 --			|	*	0	#	D
convert_end:
	cpi temp1,50
	breq north
	cpi	temp1,52
	breq west
	cpi temp1,54
	breq east
	cpi temp1,56
	breq south
	cpi	temp1,65
	breq up
	cpi	temp1,66
	breq down
	cpi temp1,67
	breq statechange

north:
	ldi temp2,78							; load ascii value of "N"
	mov flightdirection,temp2				; set flight direction to north
west:
	ldi temp2,87							; load ascii value of "W"
	mov flightdirection,temp2				; set flight direction to west
east:
	ldi temp2,69							; load ascii value of "E"
	mov flightdirection,temp2				; set flight direction to east
south:
	ldi temp2,83							; load ascii value of "S"
	mov flightdirection,temp2				; set flight direction to south
up:
	ldi temp2,85							; load ascii value of "U"
	mov flightdirection,temp2				; set flight direction to up
down:
	ldi temp2,68							; load ascii value of "D"
	mov flightdirection,temp2				; set flight direction to down
statechange:
	mov temp2,hfstate						; R12 is not a register that can be used with cpi and needs to move to r16-r31 first
	cpi temp2,0xFF							; determine flight state
	breq change2hover						; flight = 0xFF, hover = 0x00
	ser temp2								; set flight state to flight
	mov hfstate,temp2						;
change2hover:
	clr temp2								; set flight state to hover
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;keypad end;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; func of sleep 1ms
sleep_1ms:
    push iL
    push iH
    ldi iH, high(DELAY_1MS)
    ldi iL, low(DELAY_1MS)

delayloop_1ms:
    sbiw iH:iL, 1
    brne delayloop_1ms

    pop iH
    pop iL
    ret







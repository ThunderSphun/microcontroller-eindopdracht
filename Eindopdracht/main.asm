; Author : merij

.include "m128def.inc"

; milliseconds needs to count to 1000, requires two registers
.def millisLSReg = r16 ; custom max 100
.def millisMSReg = r17 ; custom max 10

.def secondsReg = r18
.def minutesReg = r19
.def hoursReg = r20

.org $0000	; RESET
rjmp start
.org $0002	; INT0
rjmp second_add
.org $0004	; INT1
rjmp second_sub
.org $0006	; INT2
rjmp minute_add
.org $0008	; INT3
rjmp minute_sub
.org $000A	; INT4		; ###########################
reti					; #		broken due to		#
.org $000C	; INT5		; #		  EIMSK(5:4)		#
reti					; ###########################
.org $000E	; INT6
rjmp hour_add
.org $0010	; INT7
rjmp hour_sub
.org $0012	; TIMER2 COMP
reti
.org $0014	; TIMER2 OVF
reti
.org $0016	; TIMER1 CAPT
reti
.org $0018	; TIMER1 COMPA
rjmp increment_timer
.org $001A	; TIMER1 COMPB
reti
.org $001C	; TIMER1 OVF
reti
.org $001E	; TIMER0 COMP
reti
.org $0020	; TIMER0 OVF
reti
.org $0022	; SPI, STC
reti
.org $0024	; USART0, RX
reti
.org $0026	; USART0, UDRE
reti
.org $0028	; USART0, TX
reti
.org $002A	; ADC
reti
.org $002C	; EE READY
reti
.org $002E	; ANALOG COMP
reti

; ###################################
; #		temp registers: {r31}		#
; ###################################
start: ; entrypoint for the code
	; init stack
	; happens here to make rcall be returnable
	ldi r31, low(RAMEND)
	out SPL, r31
	ldi r31, high(RAMEND)
	out SPH, r31

	rcall init
	rcall main
	rcall infinite_loop
	
.cseg
.org $0200
; ###################################
; #		temp registers: {r31}		#
; ###################################
init: ; 
	cli ; disables interupts during init phase

	; init board lights
	ldi r31, $FF				; 0b11111111  255
	out DDRA, r31
	out DDRB, r31
	out DDRC, r31

	; set time to 0
	clr millisLSReg
	clr millisMSReg
	clr secondsReg
	clr minutesReg
	clr hoursReg

	; init interrupts
	ldi r31, $FF				; 0b11111111  255
	sts EICRA, r31
	ldi r31, $F0				; 0b11110000  240
	out EICRB, r31
	ldi r31, $CF				; 0b11001111  207
	out EIMSK, r31

	; #######################
	; #		init timer		#
	; #######################
	; OCR1A -> $04E2 needs to be split into two bytes
	ldi r31, $04				; 0b00000100	  4
	out OCR1AH, r31
	ldi r31, $E2				; 0b11100010	226
	out OCR1AL, r31

	; sets output compare match
	in r31, TIMSK
	ori r31, $10				; 0b00010000    16
	out TIMSK, r31

	; ###################################
	; #		bit (9:0) -> mode			#
	; ###################################
	; #		bit (2:0) -> prescaler		#
	; #		bit (4:3) -> wave mode		#
	; #		bit 6     -> capture edge	#
	; ###################################
	ldi r31, $00				; 0b00000000    0
	out TCCR1A, r31
	ldi r31, $4A				; 0b01001010	74
	out TCCR1B, r31

	sei ; enables interupts
	
	ret

main:
	mainloop:
		out PORTA, hoursReg
		out PORTB, minutesReg
		out PORTC, secondsReg
	rjmp mainloop
	ret

infinite_loop: ; stops code to continue on
	rjmp infinite_loop

increment_timer:
	inc millisLSReg

	test_milliseconds:
		; tests if millisLS is 100, if so increment millisMS
		cpi millisLSReg, $64	; 0b01100100  100
			brlo test_seconds
		clr millisLSReg
		inc millisMSReg

	test_seconds:
		; tests if millisLS is 0 AND millisMS is 10, if so increment seconds
		;		   (0 because just cleared)
		cpi millisLSReg, $00	; 0b00000000    0
			brne test_minutes
		cpi millisMSReg, $0A	; 0b00001010   10
			brlo test_minutes
		clr millisMSReg
		inc secondsReg

	test_minutes:
		; tests if seconds is 60, if so increment minutes
		cpi secondsReg, $3C		; 0b00111100   60
			brlo test_hours
		clr secondsReg
		inc minutesReg

	test_hours:
		; tests if minutes is 60, if so increment hours
		cpi minutesReg, $3C		; 0b00111100   60
			brlo test_days
		clr minutesReg
		inc hoursReg

	test_days:
		; tests if hours is 24, if so reset hours (one day has passed)
		cpi hoursReg, $18		; 0b00011000   24
			brlo isr_return
		clr hoursReg

isr_return:
	reti

second_add:
	inc secondsReg
	cpi secondsReg, $3C			; 0b00111100   60
		brne isr_return
	ldi secondsReg, $00			; 0b00000000    0
	reti

second_sub:
	dec secondsReg
	cpi secondsReg, $FF			; 0b11111111  255
		brne isr_return
	ldi secondsReg, $3B			; 0b00111011   59
	reti

minute_add:
	inc minutesReg
	cpi minutesReg, $3C			; 0b00111100   60
		brne isr_return
	ldi minutesReg, $00			; 0b00000000    0
	reti

minute_sub:
	dec minutesReg
	cpi minutesReg, $FF			; 0b11111111  255
		brne isr_return
	ldi minutesReg, $3B			; 0b00111011   59
	reti

hour_add:
	inc hoursReg
	cpi hoursReg, $18			; 0b00011000   24
		brne isr_return
	ldi hoursReg, $00			; 0b00000000    0
	reti

hour_sub:
	dec hoursReg
	cpi hoursReg, $FF			; 0b11111111  255
		brne isr_return
	ldi hoursReg, $17			; 0b00010111   23
	reti
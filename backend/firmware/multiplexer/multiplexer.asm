;;; 80 characters wide please ;;;;;;;;;;;;;;;;;;;;;;;;;; 8-space tabs please ;;;


;
;;;
;;;;;  TashFloppy Multiplexer
;;;
;


;;; Connections ;;;

;See pinout.py in parent directory for pin assignments


;;; Assembler Directives ;;;

	list		P=PIC16F1704, F=INHX32, ST=OFF, MM=OFF, R=DEC, X=ON
	#include	P16F1704.inc
	errorlevel	-302	;Suppress "register not in bank 0" messages
	errorlevel	-224	;Suppress TRIS instruction not recommended msgs
	__config	_CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _BOREN_OFF & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_OFF
			;_FOSC_INTOSC	Internal oscillator, I/O on RA5
			;_WDTE_OFF	Watchdog timer disabled
			;_PWRTE_ON	Keep in reset for 64 ms on start
			;_MCLRE_OFF	RA3/!MCLR is RA3
			;_CP_OFF	Code protection off
			;_BOREN_OFF	Brownout reset off
			;_CLKOUTEN_OFF	CLKOUT disabled, I/O on RA4
			;_IESO_OFF	Internal/External switch not needed
			;_FCMEN_OFF	Fail-safe clock monitor not needed
	__config	_CONFIG2, _WRT_OFF & _PPS1WAY_OFF & _ZCDDIS_ON & _PLLEN_ON & _STVREN_ON & _LVP_OFF
			;_WRT_OFF	Write protection off
			;_PPS1WAY_OFF	PPS can change more than once
			;_ZCDDIS_ON	Zero crossing detector disabled
			;_PLLEN_ON	4x PLL on
			;_STVREN_ON	Stack over/underflow causes reset
			;_LVP_OFF	High-voltage on Vpp to program


;;; Macros ;;;

DELAY	macro	value		;Delay 3*W cycles, set W to 0
	movlw	value
	decfsz	WREG,F
	bra	$-1
	endm

DNOP	macro
	bra	$+1
	endm


;;; Pin Assignments ;;;

	#include	multiplexer_pinout.inc	;Generated by pinout.py


;;; Constants ;;;

;FLAGS:


;;; Variable Storage ;;;

	cblock	0x70	;Bank-common registers
	
	FLAGS	;You've got to have flags
	X14
	X13
	X12
	X11
	X10
	X9
	X8
	X7
	X6
	X5
	X4
	X3
	X2
	X1
	X0
	
	endc


;;; Vectors ;;;

	org	0x0		;Reset vector
	movlp	high Init
	goto	Init

	org	0x4		;Interrupt vector
	;fall through


;;; Interrupt Handler ;;;

Interrupt
	movlb	0		;Grab the command port as early as possible in
	movf	CMD_PORT,W	; case CA3 was pulsed
	movlb	7		;If CA3 was pulsed, handle it
	btfsc	CA3_IOCF,CA3_PIN; "
	call	IntCa3		; "
	movlb	7		;If !ENBL changed state, handle it
	btfsc	NEN_IOCF,NEN_PIN; "
	call	IntNEnbl	; "
	retfie			;Done

IntNEnbl
	bcf	NEN_IOCF,NEN_PIN;Clear the interrupt
	movlb	0		;If !ENBL is now low, skip ahead
	btfss	NEN_PORT,NEN_PIN; "
	bra	IntNEnblFalling	; "
	;fall through		;Else fall through

IntNEnblRising
	movlb	1		;Tristate RD pin
	bsf	RD_PORT,RD_PIN	; "
	return			;Done

IntNEnblFalling
	movlb	1		;Drive RD pin
	bcf	RD_PORT,RD_PIN	; "
	return			;Done

IntCa3
	bcf	CA3_IOCF,CA3_PIN;Clear the interrupt
	movlb	0		;If !ENBL is high, this CA3 pulse is not for us,
	btfsc	NEN_PORT,NEN_PIN; so return
	return			; "
	callw			;Translate the command port read into a command
	movlb	30		;Switch to CLC bank, common need among commands
	brw			;CA2 CA1 CA0 SEL Effect
	return			;0   0   0   0   Set !DIRTN low (ignore)
	return			;0   0   0   1   none
	return			;0   0   1   0   Step drive heads (ignore)
	return			;0   0   1   1   Select MFM mode (ignore)
	return			;0   1   0   0   Turn motor on (ignore)
	return			;0   1   0   1   none
	return			;0   1   1   0   none
	return			;0   1   1   1   none
	return			;1   0   0   0   Set !DIRTN high (ignore)
	bra	IntCa3Switched	;1   0   0   1   Reset SWITCHED to low
	return			;1   0   1   0   none
	return			;1   0   1   1   Select GCR mode (ignore)
	return			;1   1   0   0   Turn motor off (ignore)
	return			;1   1   0   1   none
	bra	IntCa3Eject	;1   1   1   0   Eject disk
	return			;1   1   1   1   none

IntCa3Switched
	bcf	CLC3GLS0,7	;Set SWITCHED low
	bcf	CLC3GLS0,6	; "
	return			;Done

IntCa3Eject
	bsf	CLC3GLS0,7	;Set SWITCHED high
	bsf	CLC3GLS0,6	; "
	return			;Done


;;; Hardware Initialization ;;;

Init
	banksel	OSCCON		;32 MHz (w/PLL) high-freq internal oscillator
	movlw	B'11110000'
	movwf	OSCCON

	banksel	RCSTA		;UART async mode, 1 MHz, receiver not enabled
	movlw	B'01001000'	; just yet, transmitter not enabled at all
	movwf	BAUDCON
	clrf	SPBRGH
	movlw	7
	movwf	SPBRGL
	movlw	B'00000100'
	movwf	TXSTA
	movlw	B'10000000'
	movwf	RCSTA

	banksel	CLC1CON		;CLC1:
	clrf	CLC1SEL0;CLCIN0	;If CLCIN0 (CA1) is low, output is LC3OUT from
	movlw	B'00010';CLCIN2	; transmitter
	movwf	CLC1SEL2; (CFR)	;If CLCIN0 (CA1) is high, output is LC3OUT from
	movlw	B'00011';CLCIN3	; receiver
	movwf	CLC1SEL3; (CFT)
	movlw	B'00100000'
	movwf	CLC1GLS0
	movlw	B'00000001'
	movwf	CLC1GLS1
	movlw	B'10000000'
	movwf	CLC1GLS2
	movlw	B'00000010'
	movwf	CLC1GLS3
	clrf	CLC1POL
	movlw	B'10000000'
	movwf	CLC1CON
	movlw	B'00001';CLCIN1	;CLC3:
	movwf	CLC3SEL0; (SEL)	;If CLCIN1 (SEL) is low, output is CLC3GLS0[7:6]
	movlw	B'01010';COG1A	; (SWITCHED)
	movwf	CLC3SEL1; (TFT)	;If CLCIN1 (SEL) is high, output is COG1A
	movlw	B'11000000'	; (TACH/!INDEX from transmitter)
	movwf	CLC3GLS0
	movlw	B'00000001'
	movwf	CLC3GLS1
	movlw	B'00001000'
	movwf	CLC3GLS2
	movlw	B'00000010'
	movwf	CLC3GLS3
	clrf	CLC3POL
	movlw	B'10000000'
	movwf	CLC3CON

	banksel	COG1CON0	;COG passes COGIN through to COG1A
	movlw	B'00000001'
	movwf	COG1RIS
	movwf	COG1FIS
	movwf	COG1STR
	movlw	B'10001000'
	movwf	COG1CON0

	banksel	IOCAP		;CA3 interrupts on rising edge, !ENBL on either
	bsf	CA3_IOCP,CA3_PIN
	bsf	NEN_IOCP,NEN_PIN
	bsf	NEN_IOCN,NEN_PIN

	banksel	ANSELA		;All pins digital, not analog
	clrf	ANSELA
	clrf	ANSELC

	banksel	INLVLA		;All inputs TTL, not ST
	clrf	INLVLA
	clrf	INLVLC

	banksel	RA0PPS		;Set up PPS outputs
	movlw	B'00100';LC1OUT
	movwf	RD_PPS
	movlw	B'00110';LC3OUT
	movwf	CTR_PPS

	banksel	CKPPS		;Set up PPS inputs
	movlw	CA1_PPSI
	movwf	CLCIN0PPS
	movlw	SEL_PPSI
	movwf	CLCIN1PPS
	movlw	CFT_PPSI
	movwf	CLCIN2PPS
	movlw	CFR_PPSI
	movwf	CLCIN3PPS
	movlw	TFT_PPSI
	movwf	COGINPPS
	movlw	RX_PPSI
	movwf	RXPPS

	banksel	TRISA		;LC3OUT output, LC1OUT output sometimes but not
	bcf	CTR_PORT,CTR_PIN; yet, all others inputs

	movlp	high PortToCmd	;Initialize key globals

	banksel	OSCSTAT		;Spin until PLL is ready and instruction clock
	btfss	OSCSTAT,PLLR	; gears up to 8 MHz
	bra	$-1

	banksel	RCSTA		;Enable receiver now that PLL is ready
	bsf	RCSTA,CREN

	movlw	B'10001000'	;Interrupt subsystem and interrupt-on-change
	movwf	INTCON		; interrupts on

	;fall through


;;; Mainline ;;;

WaitCommand
	movlb	0		;Spin until a byte comes in over the UART
	btfss	PIR1,RCIF	; "
	bra	$-1		; "
	movlb	3		;Grab the received byte and store it to
	movf	RCREG,W		; reference later
	movwf	X0		; "
	swapf	X0,W		;Switch off based on the high nibble of the
	andlw	B'00001111'	; command byte
	brw			; "
	bra	WaitCommand	;0x0? - invalid
	bra	WaitCommand	;0x1? - invalid
	bra	WaitCommand	;0x2? - invalid
	bra	WaitCommand	;0x3? - invalid
	bra	WaitCommand	;0x4? - invalid
	bra	WaitCommand	;0x5? - invalid
	bra	WaitCommand	;0x6? - invalid
	bra	WaitCommand	;0x7? - invalid
	bra	WaitCommand	;0x8? - invalid
	bra	WaitCommand	;0x9? - invalid
	bra	WaitCommand	;0xA? - invalid
	bra	WaitCommand	;0xB? - invalid
	bra	HwConfig	;0xC? - hardware configuration
	bra	InsertDisk	;0xD? - insert disk
	bra	DataMode	;0xE? - enter data mode
	bra	WaitCommand	;0xF? - invalid

HwConfig
	movf	X0,W		;Switch off based on the low nibble of the
	andlw	B'00001111'	; command byte
	brw			; "
	bra	HwConfigDrive	;0xC0 - no drive
	bra	HwConfigDrive	;0xC1 - 400k drive
	bra	HwConfigDrive	;0xC2 - 800k drive
	bra	HwConfigDrive	;0xC3 - superdrive
	bra	WaitCommand	;0xC4 - invalid
	bra	WaitCommand	;0xC5 - invalid
	bra	WaitCommand	;0xC6 - invalid
	bra	WaitCommand	;0xC7 - invalid
	bra	WaitCommand	;0xC8 - invalid
	bra	WaitCommand	;0xC9 - invalid
	bra	WaitCommand	;0xCA - invalid
	bra	WaitCommand	;0xCB - invalid
	bra	WaitCommand	;0xCC - invalid
	bra	WaitCommand	;0xCD - invalid
	bra	WaitCommand	;0xCE - invalid
	bra	WaitCommand	;0xCF - invalid

InsertDisk
	movf	X0,W		;Switch off based on the low nibble of the
	andlw	B'00001111'	; command byte
	brw			; "
	bra	InsertDiskHdRo	;0xD0 - insert HD disk, read-only
	bra	InsertDiskHdRw	;0xD1 - insert HD disk, read-write
	bra	InsertDiskDdRo	;0xD2 - insert DD disk, read-only
	bra	InsertDiskDdRw	;0xD3 - insert DD disk, read-write
	bra	WaitCommand	;0xD4 - invalid
	bra	WaitCommand	;0xD5 - invalid
	bra	WaitCommand	;0xD6 - invalid
	bra	WaitCommand	;0xD7 - invalid
	bra	WaitCommand	;0xD8 - invalid
	bra	WaitCommand	;0xD9 - invalid
	bra	WaitCommand	;0xDA - invalid
	bra	WaitCommand	;0xDB - invalid
	bra	WaitCommand	;0xDC - invalid
	bra	WaitCommand	;0xDD - invalid
	bra	WaitCommand	;0xDE - invalid
	bra	InsertDiskEject	;0xDF - force eject disk

DataMode
	movf	X0,W		;Switch off based on the low nibble of the
	andlw	B'00001111'	; command byte
	brw			; "
	bra	DataModeSink	;0xE0 - auto GCR
	bra	DataModeSink	;0xE1 - raw GCR with random noise
	bra	WaitCommand	;0xE2 - invalid
	bra	WaitCommand	;0xE3 - invalid
	bra	DataModeSink	;0xE4 - auto MFM
	bra	WaitCommand	;0xE5 - invalid
	bra	WaitCommand	;0xE6 - invalid
	bra	WaitCommand	;0xE7 - invalid
	bra	WaitCommand	;0xE8 - invalid
	bra	WaitCommand	;0xE9 - invalid
	bra	WaitCommand	;0xEA - invalid
	bra	WaitCommand	;0xEB - invalid
	bra	WaitCommand	;0xEC - invalid
	bra	WaitCommand	;0xED - invalid
	bra	WaitCommand	;0xEE - invalid
	bra	WaitCommand	;0xEF - invalid

HwConfigDrive
InsertDiskEject
InsertDiskHdRo
InsertDiskHdRw
InsertDiskDdRo
InsertDiskDdRw
	movlb	30		;Set SWITCHED high
	bsf	CLC3GLS0,7	; "
	bsf	CLC3GLS0,6	; "
	bra	WaitCommand	;Done

DataModeSink
	movlb	0		;If a byte hasn't come in over the UART yet,
	btfss	PIR1,RCIF	; loop
	bra	DataModeSink	; "
	movlb	3		;If there was a framing error (or break
	btfsc	RCSTA,FERR	; character), skip ahead
	bra	DMSink0		; "
	movf	RCREG,W		;Otherwise, read the byte to clear the
	bra	DataModeSink	; interrupt, and loop
DMSink0	movf	RCREG,W		;Framing error, so check what byte was received
	btfsc	STATUS,Z	;If it was a zero, this was a break character,
	bra	WaitCommand	; so return to await a command byte, otherwise
	bra	DataModeSink	; loop to wait for the next data byte


;;; Lookup Tables ;;;

	org	0x700

;LUT for converting raw read from command port into command
PortToCmd
	#include	multiplexer_lut.inc	;Generated by pinout.py


;;; End of Program ;;;

	end
;;; 80 characters wide please ;;;;;;;;;;;;;;;;;;;;;;;;;; 8-space tabs please ;;;


;
;;;
;;;;;  TashFloppy Prototype Frontend with SPI SRAM
;;;
;


;;; Connections ;;;

;;;                                                      ;;;
;                       .--------.                         ;
;               Supply -|01 \/ 20|- Ground                 ;
;    SRAM MOSI <-- RA5 -|02    19|- RA0 <-> ICSPDAT        ;
;     SRAM SCK <-- RA4 -|03    18|- RA1 <-- ICSPCLK        ;
;        !MCLR --> RA3 -|04    17|- RA2 <-- SRAM MISO      ;
;      User Tx <-- RC5 -|05    16|- RC0 --> SRAM 0 !CS     ;
;      User Rx --> RC4 -|06    15|- RC1 --> SRAM 1 !CS     ;
;      MMC !CS <-- RC3 -|07    14|- RC2 --> SRAM 2 !CS     ;
;      MMC SCK <-- RC6 -|08    13|- RB4 <-- Backend CTS    ;
;     MMC MOSI <-- RC7 -|09    12|- RB5 <-- Backend Tx     ;
;     MMC MISO --> RB7 -|10    11|- RB6 --> Backend Rx     ;
;                       '--------'                         ;
;;;                                                      ;;;


;;; Assembler Directives ;;;

	list		P=PIC16F1708, F=INHX32, ST=OFF, MM=OFF, R=DEC, X=ON
	#include	P16F1708.inc
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

CTS_PORT	equ	PORTB
CTS_PIN		equ	RB4
BRX_PORT	equ	PORTB
BRX_PIN		equ	RB6
BRX_PPS		equ	RB6PPS
BRX_PPSI	equ	B'01110' ;RB6
BTX_PPSI	equ	B'01101' ;RB5
UTX_PORT	equ	PORTC
UTX_PIN		equ	RC5
UTX_PPS		equ	RC5PPS
UTX_PPSI	equ	B'10101' ;RC5
URX_PPSI	equ	B'10100' ;RC4
SC0_PORT	equ	PORTC
SC0_PIN		equ	RC0
SC1_PORT	equ	PORTC
SC1_PIN		equ	RC1
SC2_PORT	equ	PORTC
SC2_PIN		equ	RC2
SMI_PPSI	equ	B'00010' ;RA2
SMO_PORT	equ	PORTA
SMO_PIN		equ	RA5
SMO_PPS		equ	RA5PPS
SCK_PORT	equ	PORTA
SCK_PIN		equ	RA4
SCK_PPS		equ	RA4PPS
SCK_PPSI	equ	B'00100' ;RA4
CCS_PORT	equ	PORTC
CCS_PIN		equ	RC3
CMI_PPSI	equ	B'01111' ;RB7
CMO_PORT	equ	PORTC
CMO_PIN		equ	RC7
CMO_PPS		equ	RC7PPS
CCK_PORT	equ	PORTC
CCK_PIN		equ	RC6
CCK_PPS		equ	RC6PPS
CCK_PPSI	equ	B'10110' ;RC6


;;; Constants ;;;

;UART protocol bytes:
;Break character indicates exiting data mode
;Bytes where MSb is clear indicate stepping to new track
UPMOFF	equ	0x80	;Motor off
UPMON	equ	0x81	;Motor on
UPGCR	equ	0x82	;GCR mode
UPMFM	equ	0x83	;MFM mode
UPSEL0	equ	0x84	;SEL falling edge
UPSEL1	equ	0x85	;SEL rising edge
UPDATA0	equ	0x86	;Enter data mode on head 0
UPDATA1	equ	0x87	;Enter data mode on head 1
UPEJECT	equ	0x8E	;Eject disk

;Outbound UART protocol bytes:
;Break character returns to command mode
UPCNONE	equ	0xC0	;Configure no drive
UPC400K	equ	0xC1	;Configure 400 kB drive
UPC800K	equ	0xC2	;Configure 800 kB drive
UPCFDHD	equ	0xC3	;Configure FDHD/superdrive
UPDHDRO	equ	0xD0	;Insert HD disk, read-only
UPDHDRW	equ	0xD1	;Insert HD disk, read-write
UPDDDRO	equ	0xD2	;Insert DD disk, read-only
UPDDDRW	equ	0xD3	;Insert DD disk, read-write
UPDEJ	equ	0xDF	;Force eject disk
UPAGCR	equ	0xE0	;Auto GCR
UPRGCR	equ	0xE1	;Raw GCR with random noise
UPAMFM	equ	0xE4	;Auto MFM

;GCR bytes:
GASYNC1	equ	0x3F	;Autosync sequence
GASYNC2	equ	0xCF	; "
GASYNC3	equ	0xF3	; "
GASYNC4	equ	0xFC	; "
GASYNC5	equ	0xFF	; "
GMARK1	equ	0xD5	;Start of mark
GMARK2	equ	0xAA	; "
GADDRMK	equ	0x96	;Address mark third byte
GDATAMK	equ	0xAD	;Data mark third byte
GSLIP1	equ	0xDE	;Bit slip bytes
GSLIP2	equ	0xAA	; "

;MFM bytes:
MFMGAP	equ	0x4E	;Gap byte
MFMGIDX	equ	0xEE	;Gap byte with index mark
MFMSYNC	equ	0x00	;Sync byte
MFMIDX1	equ	0xC2	;Index mark special byte
MFMIDX2	equ	0xFC	;Index mark byte
MFMMARK	equ	0xA1	;Address/data mark special byte
MFMADDR	equ	0xFE	;Address mark byte
MFMDATA	equ	0xFB	;Data mark byte

;FLAGS:
GCCARRY	equ	7	;GCR checksum carry bit (must be MSb)
MFMDISK	equ	6	;Set for MFM disk, clear for GCR disk
TWOSIDE	equ	5	;Set if GCR disk is two-sided (MFM disks always are)
HIGHDEN	equ	5	;Set if MFM disk is high density (GCR disks never are)
FOURONE	equ	4	;Set if GCR disk has 4:1 instead of 2:1 interleave
RAWMODE	equ	3	;Set if GCR disk data should be read in raw mode

;M_FLAGS:
M_FAIL	equ	7	;Set when there's been a failure on the MMC interface
M_BKADR	equ	6	;Set when block (rather than byte) addressing is in use
M_CDVER	equ	5	;Set when dealing with a V2.0+ card, clear for 1.0


;;; Variable Storage ;;;

	cblock	0x70	;Bank-common registers
	
	FLAGS	;You've got to have flags
	CYLHEAD	;Current cylinder number (bits 7:1) and head number (bit 0)
	SECTOR	;Current sector number (always 0-relative, even with MFM)
	X12
	X11
	X10
	X9
	X8
	X7
	X6
	X5
	X4
	X3	;Various purposes
	X2	; "
	X1	; "
	X0	; "
	
	endc

	cblock	0x320	;Top of bank 6 registers
	
	;MMC registers
	M_FLAGS	;Flags
	M_CMDN	;The MMC command to be sent
	M_ADR3	;First (high) byte of the address, first byte of R3/R7 response
	M_ADR2	;Second byte of the address, second byte of R3/R7 response
	M_ADR1	;Third byte of the address, third byte of R3/R7 response
	M_ADR0	;Fourth (low) byte of the address, last byte of R3/R7 response
	M_CNTH	;Counter register
	M_CNTL	; "
	
	;UART receiver registers
	UR_QPSH	;UART receiver queue push pointer
	UR_QPOP	;UART receiver queue pop pointer
	
	Y5
	Y4
	Y3
	Y2
	Y1
	Y0
	
	endc

	;Linear Memory:
	;0x2000-0x21BF - unused
	;0x21C0-0x21DF - UART receiver queue
	;0x21E0-0x21EF - Top of bank 6 registers


;;; Vectors ;;;

	org	0x0		;Reset vector
	movlp	high Init
	goto	Init

	org	0x4		;Interrupt vector
	;fall through


;;; Interrupt Handler ;;;

Interrupt
	bra	$
	;TODO clear GIE while reading program memory if we use interrupts


;;; Hardware Initialization ;;;

Init
	banksel	OSCCON		;32 MHz (w/PLL) high-freq internal oscillator
	movlw	B'11110000'
	movwf	OSCCON

	banksel	SSPCON1		;SSP SPI master mode, clock set by baud rate
	movlw	B'00101010'	; generator to 400 kHz, clock idles low, data
	movwf	SSPCON1		; lines change on falling edge, data sampled on
	movlw	B'01000000'	; rising edge (CKP=0, CKE=1, SMP=0)
	movwf	SSP1STAT
	movlw	19
	movwf	SSP1ADD

	banksel	RCSTA		;UART async mode, 1 MHz, receiver not enabled
	movlw	B'01001000'	; just yet
	movwf	BAUDCON
	clrf	SPBRGH
	movlw	7
	movwf	SPBRGL
	movlw	B'00100100'
	movwf	TXSTA
	movlw	B'10000000'
	movwf	RCSTA
	clrf	TXREG

	banksel	ANSELA		;All pins digital, not analog
	clrf	ANSELA
	clrf	ANSELB
	clrf	ANSELC

	banksel	INLVLA		;All inputs TTL, not ST
	clrf	INLVLA
	clrf	INLVLB
	clrf	INLVLC

	banksel	LATA		;!CS pins unasserted to start with, UART Tx pins
	movlw	B'11111111'	; high when not driven by UART, SPI clock pins
	movwf	LATA		; low when not driven by SSP
	movwf	LATB
	movwf	LATC
	bcf	SCK_PORT,SCK_PIN
	bcf	CCK_PORT,CCK_PIN

	banksel	TRISA		;UART Tx pins, SPI !CS pins, SPI MOSI and SCK
	movlw	B'11111111'	; pins outputs, all others inputs
	movwf	TRISA
	movwf	TRISB
	movwf	TRISC
	bcf	BRX_PORT,BRX_PIN
	bcf	UTX_PORT,UTX_PIN
	bcf	SC0_PORT,SC0_PIN
	bcf	SC1_PORT,SC1_PIN
	bcf	SC2_PORT,SC2_PIN
	bcf	SMO_PORT,SMO_PIN
	bcf	SCK_PORT,SCK_PIN
	bcf	CCS_PORT,CCS_PIN
	bcf	CMO_PORT,CMO_PIN
	bcf	CCK_PORT,CCK_PIN

	clrf	FLAGS		;Initialize key globals
	clrf	CYLHEAD
	clrf	SECTOR
	movlb	6
	movlw	0xC0
	movwf	UR_QPSH
	movwf	UR_QPOP
	clrf	X4
	movlw	0x20
	movwf	FSR1H
	clrf	FSR1L

	banksel	OSCSTAT		;Spin until PLL is ready and instruction clock
	btfss	OSCSTAT,PLLR	; gears up to 8 MHz
	bra	$-1

	banksel	RCSTA		;Enable receiver now that PLL is ready
	bsf	RCSTA,CREN

	;fall through


;;; Mainline ;;;

	clrf	FLAGS		;Wait a bit to make sure backend is up
StrtDly	DELAY	0		; "
	decfsz	FLAGS,F		; "
	bra	StrtDly		; "
	call	SetUartBackend	;Configure UART to talk to backend
	movlb	3		;Send a break character to make sure we're in
	bsf	TXSTA,SENDB	; command mode and wait for it to complete
	clrf	TXREG		; "
	btfsc	TXSTA,SENDB	; "
	bra	$-1		; "
	movlw	UPCFDHD		;Configure backend as a superdrive
	movwf	TXREG		; "
	movlb	4		;Crank the speed of the SPI interface up to 2
	movlw	B'00100001'	; MHz
	movwf	SSPCON		; "
	call	SetSspSram	;Configure SSP to talk to SRAM
	movlb	0		;Run the SSP clock a bit with the !CS pins
	bcf	PIR1,SSP1IF	; unasserted just in case
	movlb	4		; "
	clrf	SSP1BUF		; "
	movlb	0		; "
	btfss	PIR1,SSP1IF	; "
	bra	$-1		; "
	;fall through

UserStart
	call	SetUartUser	;Configure UART to talk to user
	;fall through

UserCommand
	movlb	0		;Wait until transmitter is ready
	btfss	PIR1,TXIF	; "
	bra	$-1		; "
	movlb	3		;Send 'go' to host to prompt command
	movlw	0x60		; "
	movwf	TXREG		; "
	movlb	0		;Wait for command
	btfss	PIR1,RCIF	; "
	bra	$-1		; "
	movlb	3		;Get command byte
	movf	RCREG,W		; "
	btfsc	WREG,7		;If MSb is set, it's some variety of insert so
	goto	UserInsert	; skip ahead to handle it
	andlw	B'00000011'	;Otherwise, mask off all but two bottom bits and
	brw			; switch off by command byte:
	goto	UserCommand	;0 - nop
	goto	UserCommand	;1 - nop
	goto	UserWrite	;2 - write
	goto	UserRead	;3 - read

UserWrite
	movlw	0x02		;Address and send the command to the SPI SRAM
	call	UserAddress	; "
UserWr0	movlb	0		;Get data byte
	btfss	PIR1,RCIF	; "
	bra	$-1		; "
	movlb	3		; "
	movf	RCREG,W		; "
	movlb	0		;Make sure SSP is ready
	btfss	PIR1,SSP1IF	; "
	bra	$-1		; "
	bcf	PIR1,SSP1IF	;Write data byte to SSP
	movlb	4		; "
	movwf	SSPBUF		; "
	decfsz	X0,F		;Loop until we've gotten 256 bytes
	bra	UserWr0		; "
	movlb	0		;Make sure SSP is ready
	btfss	PIR1,SSP1IF	; "
	bra	$-1		; "
	call	DeselectSram	;Deselect all three SRAMs
	goto	UserCommand	;Go get another command

UserRead
	movlw	0x03		;Address and send the command to the SPI SRAM
	call	UserAddress	; "
	movlb	0		;Make sure SSP is ready
	btfss	PIR1,SSP1IF	; "
	bra	$-1		; "
UserRe0	bcf	PIR1,SSP1IF	;Clock a byte out of the SSP
	movlb	4		; "
	clrf	SSPBUF		; "
	movlb	0		;Make sure SSP is ready
	btfss	PIR1,SSP1IF	; "
	bra	$-1		; "
	movlb	4		;Get the received byte
	movf	SSPBUF,W	; "
	movlb	0		;Wait for the transmitter to be ready
	btfss	PIR1,TXIF	; "
	bra	$-1		; "
	movlb	3		;Send the received byte to the UART
	movwf	TXREG		; "
	movlb	0		;Loop until we've written 256 bytes
	decfsz	X0,F		; "
	bra	UserRe0		; "
	call	DeselectSram	;Deselect all three SRAMs
	goto	UserCommand	;Go get another command

UserInsert
	movwf	X0		;Save insert parameters for use momentarily
	call	SetUartBackend	;Switch UART to backend
	call	TxGetReady	;Wait for UART transmitter to be ready
	bcf	FLAGS,MFMDISK	;Clear all disk type flags to start with
	bcf	FLAGS,TWOSIDE	; "
	bcf	FLAGS,FOURONE	; "
	bcf	FLAGS,RAWMODE	; "
	btfsc	X0,6		;If bit 6 is set, MFM disk, else GCR disk
	bsf	FLAGS,MFMDISK	; "
	btfsc	X0,5		;If bit 5 is set, HD MFM disk or DS GCR disk
	bsf	FLAGS,TWOSIDE	; (HIGHDEN and TWOSIDE are the same bit)
	btfsc	X0,4		;If bit 4 is set, 4:1 interleave on GCR (no
	bsf	FLAGS,FOURONE	; effect on MFM disks)
	btfsc	X0,3		;If bit 3 is set, raw mode, else sector mode
	bsf	FLAGS,RAWMODE	; (no effect on MFM disks)
	movf	X0,W		;If bit 1 is set, high density, else double
	andlw	B'00000011'	; density; if bit 0 is set, read-write, else
	brw			; read-only
	bra	UInser0		; "
	bra	UInser1		; "
	bra	UInser2		; "
	bra	UInser3		; "
UInser0	movlb	3		;Signal to backend to insert a double-density
	movlw	UPDDDRO		; disk, read-only
	movwf	TXREG		; "
	bra	MotorOff	;Skip ahead
UInser1	movlb	3		;Signal to backend to insert a double-density
	movlw	UPDDDRW		; disk, read-write
	movwf	TXREG		; "
	bra	MotorOff	;Skip ahead
UInser2	movlb	3		;Signal to backend to insert a high-density
	movlw	UPDHDRO		; disk, read-only
	movwf	TXREG		; "
	bra	MotorOff	;Skip ahead
UInser3	movlb	3		;Signal to backend to insert a high-density
	movlw	UPDHDRW		; disk, read-write
	movwf	TXREG		; "
	bra	MotorOff	;Skip ahead

MotorOff
	call	TxBreak		;Send a break character to cut off data
MOff0	call	RxPoll		;Poll the receiver
	call	RxPop		;Try to pop a byte/character off the queue
	btfss	STATUS,Z	;If the queue is empty or the byte received was
	btfsc	STATUS,C	; a framing error/break character, loop around
	bra	MOff0		; "
	xorlw	UPEJECT		;If we got an eject event, return to user
	btfsc	STATUS,Z	; interface
	goto	UserStart	; "
	xorlw	UPSEL0 ^ UPEJECT;If we got a SEL change event, change CYLHEAD's
	btfsc	STATUS,Z	; LSb accordingly
	bcf	CYLHEAD,0	; "
	xorlw	UPSEL1 ^ UPSEL0	; "
	btfsc	STATUS,Z	; "
	bsf	CYLHEAD,0	; "
	xorlw	UPMON ^ UPSEL1	;If we got a motor on event, things get exciting
	btfsc	STATUS,Z	; "
	goto	MotorOn		; "
	xorlw	0x00 ^ UPMON	;If the MSb of the received byte was low,
	btfsc	WREG,7		; indicating a step, proceed, otherwise loop
	bra	MOff0		; "
	lslf	WREG,W		;Move the new cylinder into CYLHEAD, keeping the
	btfsc	CYLHEAD,0	; LSb (head number) as is
	iorlw	B'00000001'	; "
	movwf	CYLHEAD		; "
	bra	MOff0		;Loop

MotorOn
	btfsc	FLAGS,MFMDISK	;If emulating an MFM disk, skip ahead to that
	goto	MfmStart	; handler, else proceed to GCR handler
	btfsc	FLAGS,RAWMODE	;If GCR disk is raw mode, skip ahead to that
	goto	GcrRawStart	; handler, else proceed to sector GCR handler
	;fall through

GcrStart
	call	TxGetReady	;Wait for the transmitter to be ready
	movlb	3		;Signal the backend to enter auto GCR data mode
	movlw	UPAGCR		; "
	movwf	TXREG		; "
	movlw	35		;35 autosync groups before the address mark,
	movwf	X0		; though we start from the last byte of the
	goto	GcrPreAMAuto5	; first one so really it's 34

GcrPreAMAuto1
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the first byte of an autosync group
	movlw	GASYNC1		; "
	movwf	TXREG		; "
	;fall through

GcrPreAMAuto2
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the second byte of an autosync group
	movlw	GASYNC2		; "
	movwf	TXREG		; "
	;fall through

GcrPreAMAuto3
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the third byte of an autosync group
	movlw	GASYNC3		; "
	movwf	TXREG		; "
	;fall through

GcrPreAMAuto4
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the fourth byte of an autosync group
	movlw	GASYNC4		; "
	movwf	TXREG		; "
	;fall through

GcrPreAMAuto5
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the fifth byte of an autosync group
	movlw	GASYNC5		; "
	movwf	TXREG		; "
	decfsz	X0,F		;If there are more autosync groups to send, loop
	goto	GcrPreAMAuto1	; "
	;fall through

GcrAdMark1
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the first byte of the three-byte address
	movlw	GMARK1		; mark
	movwf	TXREG		; "
	call	LookupGcrOffs	;Look up the file offset for CHS address
	;fall through

GcrAdMark2
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the second byte of the three-byte address
	movlw	GMARK2		; mark
	movwf	TXREG		; "
	call	SelectSram	;Select the appropriate SRAM based on PMDATH
	;fall through

GcrAdMark3
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the third byte of the three-byte address
	movlw	GADDRMK		; mark
	movwf	TXREG		; "
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the SPI SRAM read command
	movlw	0x03		; "
	movwf	SSPBUF		; "
	;fall through

GcrAdCylL
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the low six bits of the cylinder number
	lsrf	CYLHEAD,W	; "
	andlw	B'00111111'	; "
	movwf	TXREG		; "
	movwf	X0		;Start the checksum with it
	;fall through

GcrAdSec
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the sector number
	movf	SECTOR,W	; "
	movwf	TXREG		; "
	xorwf	X0,F		;Update the checksum with it
	;fall through

GcrAdCylH
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send a byte that has the seventh bit of the
	movlw	0		; cylinder number in its LSb and the head bit in
	btfsc	CYLHEAD,7	; its 6th bit
	movlw	1		; "
	btfsc	CYLHEAD,0	; "
	iorlw	B'00100000'	; "
	movwf	TXREG		; "
	xorwf	X0,F		;Update the checksum with it
	;fall through

GcrAdFmt
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the format byte, which has the interleave
	movlw	0x02		; in its low five bits and sets the sixth if the
	btfsc	FLAGS,FOURONE	; disk is two-sided
	movlw	0x04		; "
	btfsc	FLAGS,TWOSIDE	; "
	iorlw	0x20		; "
	movwf	TXREG		; "
	xorwf	X0,F		;Update the checksum with it
	;fall through

GcrAdChk
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the checksum byte
	movf	X0,W		; "
	movwf	TXREG		; "
	movf	PMDATH,W	;Get the top byte of the SRAM offset
	andlw	B'00000111'	; "
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the top byte of the SRAM offset
	movwf	SSPBUF		; "
	;fall through

GcrAdSlip1
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the first of two bit slip bytes
	movlw	GSLIP1		; "
	movwf	TXREG		; "
	movf	PMDATL,W	;Get the second byte of the SRAM offset
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the second byte of the SRAM offset
	movwf	SSPBUF		; "
	;fall through

GcrAdSlip2
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the second of two bit slip bytes
	movlw	GSLIP2		; "
	movwf	TXREG		; "
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the third byte of the SRAM offset,
	clrf	SSPBUF		; which is always zero
	movlw	6		;6 autosync groups before the data mark, though
	movwf	X0		; we start from the last byte of the first one
	goto	GcrPreDMAuto5	; so really it's 5

GcrPreDMAuto1
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the first byte of an autosync group
	movlw	GASYNC1		; "
	movwf	TXREG		; "
	;fall through

GcrPreDMAuto2
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the second byte of an autosync group
	movlw	GASYNC2		; "
	movwf	TXREG		; "
	;fall through

GcrPreDMAuto3
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the third byte of an autosync group
	movlw	GASYNC3		; "
	movwf	TXREG		; "
	;fall through

GcrPreDMAuto4
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the fourth byte of an autosync group
	movlw	GASYNC4		; "
	movwf	TXREG		; "
	;fall through

GcrPreDMAuto5
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the fifth byte of an autosync group
	movlw	GASYNC5		; "
	movwf	TXREG		; "
	decfsz	X0,F		;If there are more autosync groups to send, loop
	goto	GcrPreDMAuto1	; "
	;fall through

GcrDatMark1
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the first byte of the three-byte data mark
	movlw	GMARK1		; "
	movwf	TXREG		; "
	;fall through

GcrDatMark2
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the second byte of the three-byte data
	movlw	GMARK2		; mark
	movwf	TXREG		; "
	;fall through

GcrDatMark3
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the third byte of the three-byte data mark
	movlw	GDATAMK		; "
	movwf	TXREG		; "
	;fall through

GcrPreDataSec
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the sector number again
	movf	SECTOR,W	; "
	movwf	TXREG		; "
	movlw	12		;12 zero bytes for tags before data
	movwf	X0		; "
	;fall through

GcrPreDataTag
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send one of twelve zero bytes for tags
	clrf	TXREG		; "
	decfsz	X0,F		;If there are more to send, loop around
	bra	GcrPreDataTag	; "
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the first data byte so it's ready for
	clrf	SSPBUF		; next state
	movlw	171		;Initialize the counter for 170 trios and a duo
	movwf	X0		; "
	clrf	X1		;Clear the checksum registers
	clrf	X2		; "
	clrf	X3		; "
	bcf	FLAGS,GCCARRY	; "
	;fall through

GcrDataA
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	lslf	FLAGS,W		;Load carry bit from flags register
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Load the byte read from SRAM
	movf	SSP1BUF,W	; "
	clrf	SSP1BUF		;Start clocking out the next data byte
	addwfc	X1,F		;Add it plus carry to checksum A
	xorwf	X3,W		;XOR it with checksum C and send the result
	movlb	3		; "
	movwf	TXREG		; "
	bcf	FLAGS,GCCARRY	;Save the carry bit for next time
	btfsc	STATUS,C	; "
	bsf	FLAGS,GCCARRY	; "
	;fall through

GcrDataB
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	lslf	FLAGS,W		;Load carry bit from flags register
	movlb	4		;Load the byte read from SRAM
	movf	SSP1BUF,W	; "
	addwfc	X2,F		;Add it plus carry to checksum B
	xorwf	X1,W		;XOR it with checksum A and send the result
	movlb	3		; "
	movwf	TXREG		; "
	decfsz	X0,F		;If this was the duo, don't clock out any more
	bra	GDataB0		; bytes from SRAM, instead skip ahead to send
	goto	GcrCksumA	; checksums
GDataB0	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Start clocking out the next data byte
	clrf	SSP1BUF		; "
	bcf	FLAGS,GCCARRY	;Save the carry bit for next time
	btfsc	STATUS,C	; "
	bsf	FLAGS,GCCARRY	; "
	;fall through

GcrDataC
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	lslf	FLAGS,W		;Load carry bit from flags register
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Load the byte read from SRAM
	movf	SSP1BUF,W	; "
	clrf	SSP1BUF		;Start clocking out the next data byte
	addwfc	X3,F		;Add it plus carry to checksum C
	xorwf	X2,W		;XOR it with checksum B and send the result
	movlb	3		; "
	movwf	TXREG		; "
	bcf	FLAGS,GCCARRY	;Copy the MSb of checksum C into carry for next
	btfsc	X3,7		; time
	bsf	FLAGS,GCCARRY	; "
	lslf	X3,W		;Rotate checksum C left, not through carry
	rlf	X3,F		; "
	goto	GcrDataA	;Loop around to the next 'A' byte

GcrCksumA
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the first of three checksum bytes
	movf	X1,W		; "
	movwf	TXREG		; "
	;fall through

GcrCksumB
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the second of three checksum bytes
	movf	X2,W		; "
	movwf	TXREG		; "
	;fall through

GcrCksumC
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the third of three checksum bytes
	movf	X3,W		; "
	movwf	TXREG		; "
	;fall through

GcrDatSlip1
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the first of two bit slip bytes
	movlw	GSLIP1		; "
	movwf	TXREG		; "
	call	DeselectSram	;Deselect all three SRAMs
	;fall through

GcrDatSlip2
	call	GcrReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the first of two bit slip bytes
	movlw	GSLIP2		; "
	movwf	TXREG		; "
	movf	SECTOR,W	;Advance to the next sector
	call	NextGcrSector	; "
	movwf	SECTOR		; "
	movlw	35		;35 autosync groups before the address mark,
	movwf	X0		; though we start from the last byte of the
	goto	GcrPreAMAuto5	; first one so really it's 34

GcrWriStart
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	xorlw	0xD5		;We're sitting around waiting for an 0xD5 before
	btfss	STATUS,Z	; we can do anything
	bra	GcrWriStart	; "
	;fall through

GcrWriD5
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	xorlw	0xAA		;An 0xD5 without an 0xAA means nothing
	btfss	STATUS,Z	; "
	goto	GcrWriStart	; "
	;fall through

GcrWriAA
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	xorlw	0x96		;0xD5 0xAA 0x96 is an address mark, which means
	btfsc	STATUS,Z	; Mac is formatting or writing-while-formatting
	goto	GcrWri96	; "
	xorlw	0xAD ^ 0x96	;0xD5 0xAA followed by anything else but 0xAD
	btfss	STATUS,Z	; means nothing
	goto	GcrWriStart	; "
	;fall through

GcrWriAD
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	;TODO check for correct sector number here and do something if wrong?
	call	LookupGcrOffs	;Look up the file offset for CHS address
	clrf	X1		;Clear the checksum registers
	clrf	X2		; "
	clrf	X3		; "
	bcf	FLAGS,GCCARRY	; "
	;fall through

GcrWriTag1
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleA	;Update the checksum with this 'A' byte
	call	SelectSram	;Select the appropriate SRAM for offset
	;fall through

GcrWriTag2
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleB	;Update the checksum with this 'B' byte
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the SPI SRAM write command
	movlw	0x02		; "
	movwf	SSPBUF		; "
	;fall through

GcrWriTag3
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleC	;Update the checksum with this 'C' byte
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	3		;Clock out the high byte of the address
	movf	PMDATH,W	; "
	andlw	B'00000111'	; "
	movlb	4		; "
	movwf	SSPBUF		; "
	;fall through

GcrWriTag4
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleA	;Update the checksum with this 'A' byte
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	3		;Clock out the mid byte of the address
	movf	PMDATL,W	; "
	movlb	4		; "
	movwf	SSPBUF		; "
	;fall through

GcrWriTag5
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleB	;Update the checksum with this 'B' byte
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the low byte of the address, which is
	clrf	SSPBUF		; always zero
	movlw	171		;Prepare to receive 170 trios and a duo
	movwf	X0		; "
	;fall through

GcrWriTag6
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleC	;Update the checksum with this 'C' byte
	;fall through

GcrWriTag7
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleA	;Update the checksum with this 'A' byte
	;fall through

GcrWriTag8
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleB	;Update the checksum with this 'B' byte
	;fall through

GcrWriTag9
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleC	;Update the checksum with this 'C' byte
	;fall through

GcrWriTag10
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleA	;Update the checksum with this 'A' byte
	;fall through

GcrWriTag11
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleB	;Update the checksum with this 'B' byte
	;fall through

GcrWriTag12
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleC	;Update the checksum with this 'C' byte
	;fall through

GcrWriDataA
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleA	;Demangle the received byte
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock the received byte out
	movwf	SSPBUF		; "
	;fall through

GcrWriDataB
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleB	;Demangle the received byte
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock the received byte out
	movwf	SSPBUF		; "
	decfsz	X0,F		;If this was the duo, prepare to receive the
	goto	GcrWriDataC	; checksum, else proceed to get the next data
	goto	GcrWriCsumA	; byte

GcrWriDataC
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	call	GcrDemangleC	;Demangle the received byte
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock the received byte out
	movwf	SSPBUF		; "
	goto	GcrWriDataA	;Loop to receive next 'A' data byte

GcrWriCsumA
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	xorwf	X1,W		;Assert fail if checksum is wrong
	btfss	STATUS,Z	; TODO can we do something better than this?
	bra	$		; "
	call	DeselectSram	;Deselect SRAM
	;fall through

GcrWriCsumB
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	xorwf	X2,W		;Assert fail if checksum is wrong
	btfss	STATUS,Z	; TODO can we do something better than this?
	bra	$		; "
	;fall through

GcrWriCsumC
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	xorwf	X3,W		;Assert fail if checksum is wrong
	btfss	STATUS,Z	; TODO can we do something better than this?
	bra	$		; "
	;fall through

GcrWriSlip1
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	xorlw	0xDE		;Assert fail if bit slip byte is wrong
	btfss	STATUS,Z	; TODO can we do something better than this?
	bra	$		; "
	;fall through

GcrWriSlip2
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	xorlw	0xAA		;Assert fail if bit slip byte is wrong
	btfss	STATUS,Z	; TODO can we do something better than this?
	bra	$		; "
	movf	SECTOR,W	;Increment sector in case we're formatting
	call	NextGcrSector	; "
	movwf	SECTOR		; "
	goto	GcrWriStart	;Wait for next write

GcrWri96
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	movwf	X0		;Start checksum with received byte
	lsrf	CYLHEAD,W	;Check that it equals the low six bits of the
	xorwf	X0,W		; current cylinder and assert fail if not
	andlw	B'00111111'	; TODO can we do something better than this?
	btfss	STATUS,Z	; "
	bra	$		; "
	;fall through

GcrWriAdr1
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	xorwf	X0,F		;Update checksum with the received byte
	movwf	X2		;Keep the sector number for if checksum passes
	;fall through

GcrWriAdr2
	movlw	0		;Make up a byte that has the current cylinder
	btfsc	CYLHEAD,7	; number in its LSb and the head bit in its 6th
	movlw	1		; bit
	btfsc	CYLHEAD,0	; "
	iorlw	B'00100000'	; "
	movwf	X1		;Save it for later
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	xorwf	X0,F		;Update checksum with the received byte
	xorwf	X1,W		;Check that it equals the byte we made earlier
	btfss	STATUS,Z	; and assert fail if not
	bra	$		; TODO can we do something better than this?
	;fall through

GcrWriAdr3
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	xorwf	X0,F		;Update checksum with the received byte
	btfsc	FLAGS,TWOSIDE	;Check that the two-sided bit matches what we
	xorlw	B'00100000'	; expect for this disk and assert fail if it
	andlw	B'00100000'	; doesn't
	btfss	STATUS,Z	; TODO can we do something better than this?
	bra	$		; "
	;fall through

GcrWriAdr4
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	xorwf	X0,W		;Check if the checksum matches and assert fail
	btfss	STATUS,Z	; if it doesn't
	bra	$		; TODO can we do something better than this?
	movf	X2,W		;Checksum matches, so accept the sector number
	movwf	SECTOR		; we were given
	;fall through

GcrWriASlip1
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	xorlw	0xDE		;Assert fail if bit slip byte is wrong
	btfss	STATUS,Z	; TODO can we do something better than this?
	bra	$		; "
	;fall through

GcrWriASlip2
	call	GcrWriteTxRx	;Wait for SSP while handling receiver
	xorlw	0xAA		;Assert fail if bit slip byte is wrong
	btfss	STATUS,Z	; TODO can we do something better than this?
	bra	$		; "
	goto	GcrWriStart	;Wait for next write

GcrRawStart
	call	LookupGcrRawOffs;Look up the raw GCR offset for this CYLHEAD
	bsf	STATUS,DC	;Signal to GcrRawLoop we need to enter data mode
	;fall through

GcrRawLoop
	call	SelectSram	;Select the appropriate SRAM based on PMDATH
	call	GcrRawReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the SPI SRAM read command
	movlw	0x03		; "
	movwf	SSPBUF		; "
	call	GcrRawReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Get the top byte of the SRAM offset
	movf	PMDATH,W	; "
	andlw	B'00000111'	; "
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the top byte of the SRAM offset
	movwf	SSPBUF		; "
	call	GcrRawReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Get the second byte of the SRAM offset
	movf	PMDATL,W	; "
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the second byte of the SRAM offset
	movwf	SSPBUF		; "
	call	GcrRawReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the third byte of the SRAM offset,
	clrf	SSPBUF		; which is always zero
	call	GcrRawReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock in the MSB of the track length
	clrf	SSPBUF		; "
	call	GcrRawReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Ignore the MSB of the track length
	clrf	SSPBUF		;Clock in the second byte of the track length
	call	GcrRawReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Get the second byte of the track length and
	movf	SSPBUF,W	; save it
	movwf	X2		; "
	clrf	SSPBUF		;Clock in the third byte of the track length
	call	GcrRawReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Get the third byte of the track length and
	movf	SSPBUF,W	; save it
	movwf	X1		; "
	clrf	SSPBUF		;Clock in the LSB of the track length
	call	GcrRawReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Get the LSB of the track length and
	movf	SSPBUF,W	; save it
	movwf	X0		; "
	clrf	SSPBUF		;Clock in the first byte of track data
	btfss	STATUS,DC	;If this is the start of a new track, take some
	bra	GRLoop0		; extra steps, else skip ahead
	bcf	STATUS,DC	;Clear the signal bit
	movlb	3		;Signal the backend to enter raw GCR data mode
	movlw	UPRGCR		; "
	movwf	TXREG		; "
	movlb	0x01		;Put a sentinel bit into the bit accumulator
	movwf	X3		; "
GRLoop0	comf	X2,F		;Two's complement the bit counter so it makes an
	comf	X1,F		; up counter, which is more convenient
	comf	X0,F		; "
	incf	X0,F		; "
	btfsc	STATUS,Z	; "
	incf	X1,F		; "
	btfsc	STATUS,Z	; "
	incf	X2,F		; "
	;fall through

GcrRawByte
	movf	X0,W		;If the up counter has more than 15 left before
	iorlw	B'00001111'	; it overflows, skip ahead to take a shortcut
	andwf	X1,W		; since we know we're going to run all the way
	andwf	X2,W		; through the loop
	incf	WREG,W		; "
	btfss	STATUS,Z	; "
	bra	GRByte0		; "
	call	GcrRawReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Get the next byte of track data
	movf	SSPBUF,W	; "
	clrf	SSPBUF		;Clock out the next byte of track data
	xorwf	X3,F		;Swap X3 and W so the bit accumulator is in W
	xorwf	X3,W		; and the byte read from the SSP is in X3
	xorwf	X3,F		; "
	movlb	3		;Switch to bank 3 so we can write to backend
	lslf	X3,F		;Shift the MSb of the byte read into the bit
	rlf	WREG,W		; accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	incf	X0,F		;Increment the up counter of bits in this track
	btfsc	STATUS,Z	; and if it hits zero, put back the current bit
	incf	X1,F		; accumulator and loop to read the track bits
	btfsc	STATUS,Z	; again
	incf	X2,F		; "
	btfsc	STATUS,Z	; "
	bra	GRByte1		; "
	lslf	X3,F		;Shift the next bit of the byte read into the
	rlf	WREG,W		; bit accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	incf	X0,F		;Increment the up counter of bits in this track
	btfsc	STATUS,Z	; and if it hits zero, put back the current bit
	incf	X1,F		; accumulator and loop to read the track bits
	btfsc	STATUS,Z	; again
	incf	X2,F		; "
	btfsc	STATUS,Z	; "
	bra	GRByte1		; "
	lslf	X3,F		;Shift the next bit of the byte read into the
	rlf	WREG,W		; bit accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	incf	X0,F		;Increment the up counter of bits in this track
	btfsc	STATUS,Z	; and if it hits zero, put back the current bit
	incf	X1,F		; accumulator and loop to read the track bits
	btfsc	STATUS,Z	; again
	incf	X2,F		; "
	btfsc	STATUS,Z	; "
	bra	GRByte1		; "
	lslf	X3,F		;Shift the next bit of the byte read into the
	rlf	WREG,W		; bit accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	incf	X0,F		;Increment the up counter of bits in this track
	btfsc	STATUS,Z	; and if it hits zero, put back the current bit
	incf	X1,F		; accumulator and loop to read the track bits
	btfsc	STATUS,Z	; again
	incf	X2,F		; "
	btfsc	STATUS,Z	; "
	bra	GRByte1		; "
	lslf	X3,F		;Shift the next bit of the byte read into the
	rlf	WREG,W		; bit accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	incf	X0,F		;Increment the up counter of bits in this track
	btfsc	STATUS,Z	; and if it hits zero, put back the current bit
	incf	X1,F		; accumulator and loop to read the track bits
	btfsc	STATUS,Z	; again
	incf	X2,F		; "
	btfsc	STATUS,Z	; "
	bra	GRByte1		; "
	lslf	X3,F		;Shift the next bit of the byte read into the
	rlf	WREG,W		; bit accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	incf	X0,F		;Increment the up counter of bits in this track
	btfsc	STATUS,Z	; and if it hits zero, put back the current bit
	incf	X1,F		; accumulator and loop to read the track bits
	btfsc	STATUS,Z	; again
	incf	X2,F		; "
	btfsc	STATUS,Z	; "
	bra	GRByte1		; "
	lslf	X3,F		;Shift the next bit of the byte read into the
	rlf	WREG,W		; bit accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	incf	X0,F		;Increment the up counter of bits in this track
	btfsc	STATUS,Z	; and if it hits zero, put back the current bit
	incf	X1,F		; accumulator and loop to read the track bits
	btfsc	STATUS,Z	; again
	incf	X2,F		; "
	btfsc	STATUS,Z	; "
	bra	GRByte1		; "
	lslf	X3,F		;Shift the LSb of the byte read into the bit
	rlf	WREG,W		; accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	incf	X0,F		;Increment the up counter of bits in this track
	btfsc	STATUS,Z	; and if it hits zero, put back the current bit
	incf	X1,F		; accumulator and loop to read the track bits
	btfsc	STATUS,Z	; again
	incf	X2,F		; "
	btfsc	STATUS,Z	; "
	bra	GRByte1		; "
	movwf	X3		;Put back the byte accumulator for next loop
	bra	GcrRawByte	;Loop
GRByte0	movlw	8		;Add 8 to the up counter in the knowledge that
	addwf	X0,F		; it won't overflow during this loop
	movlw	0		; "
	addwfc	X1,F		; "
	addwfc	X2,F		; "
	call	GcrRawReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Get the next byte of track data
	movf	SSPBUF,W	; "
	clrf	SSPBUF		;Clock out the next byte of track data
	xorwf	X3,F		;Swap X3 and W so the bit accumulator is in W
	xorwf	X3,W		; and the byte read from the SSP is in X3
	xorwf	X3,F		; "
	movlb	3		;Switch to bank 3 so we can write to backend
	lslf	X3,F		;Shift the MSb of the byte read into the bit
	rlf	WREG,W		; accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	lslf	X3,F		;Shift the next bit of the byte read into the
	rlf	WREG,W		; bit accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	lslf	X3,F		;Shift the next bit of the byte read into the
	rlf	WREG,W		; bit accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	lslf	X3,F		;Shift the next bit of the byte read into the
	rlf	WREG,W		; bit accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	lslf	X3,F		;Shift the next bit of the byte read into the
	rlf	WREG,W		; bit accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	lslf	X3,F		;Shift the next bit of the byte read into the
	rlf	WREG,W		; bit accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	lslf	X3,F		;Shift the next bit of the byte read into the
	rlf	WREG,W		; bit accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	lslf	X3,F		;Shift the LSb of the byte read into the bit
	rlf	WREG,W		; accumulator, set C if it's full
	btfsc	STATUS,C	;If bit accumulator is full, send its contents
	call	GRByte2		; to the backend and reset it with a sentinel
	movwf	X3		;Put back the byte accumulator for next loop
	bra	GcrRawByte	;Loop
GRByte1	movwf	X3		;Put back the byte accumulator for next loop
	call	DeselectSram	;Deselect all three SRAMs
	bcf	STATUS,DC	;Loop the track data, signalling that we do not
	goto	GcrRawLoop	; need to reenter data mode
GRByte2	movwf	TXREG		;Bit accumulator is full, send it to backend and
	retlw	0x01		; reset it with a sentinel bit

MfmStart
	call	TxGetReady	;Wait for the transmitter to be ready
	movlb	3		;Signal the backend to enter auto MFM data mode
	movlw	UPAMFM		; "
	movwf	TXREG		; "
	;fall through

MfmRestart
	movlw	12		;12 sync bytes before the address mark, for
	movwf	X0		; sectors other than the first
	movf	SECTOR,W	; "
	btfss	STATUS,Z	; "
	goto	MfmSyncToAddrMk	; "
	movlw	103		;204 (for HD) or 182 (for DD) gap bytes from
	btfss	FLAGS,HIGHDEN	; last sector to end of track, subtract 101 (for
	movlw	98		; HD) or 84 (for DD) from that for the usual
	movwf	X0		; post-sector gap and you get 103 or 98
	;fall through

MfmGapToTrackEnd
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM gap byte
	movlw	MFMGAP		; "
	movwf	TXREG		; "
	decfsz	X0,F		;If there are more bytes until the track end,
	bra	MfmGapToTrackEnd; loop
	;fall through

MfmIndexPulse
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM gap byte and index pulse
	movlw	MFMGIDX		; "
	movwf	TXREG		; "
	movlw	79		;79 more gap bytes before index mark
	movwf	X0		; "
	;fall through

MfmGapToIdxMk
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM gap byte
	movlw	MFMGAP		; "
	movwf	TXREG		; "
	decfsz	X0,F		;If there are more bytes until the index mark,
	bra	MfmGapToIdxMk	; loop
	movlw	12		;12 sync bytes before the index mark
	movwf	X0		; "
	;fall through

MfmSyncToIdxMk
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM sync byte
	movlw	MFMSYNC		; "
	movwf	TXREG		; "
	decfsz	X0,F		;If there are more bytes until the index mark,
	bra	MfmSyncToIdxMk	; loop
	movlw	3		;3 special index mark bytes after the sync bytes
	movwf	X0		; "
	;fall through

MfmIndexMark1
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM index mark special byte (missing a
	movlw	MFMIDX1		; clock)
	movwf	TXREG		; "
	decfsz	X0,F		;If there are more bytes until the next byte,
	bra	MfmIndexMark1	; loop
	;fall through

MfmIndexMark2
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM index mark byte
	movlw	MFMIDX2		; "
	movwf	TXREG		; "
	movlw	50		;50 gap bytes before first sector's address mark
	movwf	X0		; "
	;fall through

MfmGapToAddrMk
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM gap byte
	movlw	MFMGAP		; "
	movwf	TXREG		; "
	decfsz	X0,F		;If there are more bytes until the address mark,
	bra	MfmGapToAddrMk	; loop
	movlw	12		;12 sync bytes before address mark
	movwf	X0		; "
	;fall through

MfmSyncToAddrMk
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM sync byte
	movlw	MFMSYNC		; "
	movwf	TXREG		; "
	decfsz	X0,F		;If there are more bytes until the address mark,
	bra	MfmSyncToAddrMk	; loop
	movlw	3		;3 special address/data mark bytes after the
	movwf	X0		; sync bytes
	;fall through

MfmAddressMark1
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM data/address mark special byte
	movlw	MFMMARK		; (missing a clock)
	movwf	TXREG		; "
	decfsz	X0,F		;If there are more bytes until the next byte,
	bra	MfmAddressMark1	; loop
	;fall through

MfmAddressMark2
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM address mark byte
	movlw	MFMADDR		; "
	movwf	TXREG		; "
	call	LookupMfmOffs	;Look up the file offset for CHS address
	movf	PMDATH,W	;Save it, we're about to overwrite PMDATH:L with
	movwf	X1		; CRC stuff
	movf	PMDATL,W	; "
	movwf	X0		; "
	call	PointCrc	;Set up for CRC16 calculation
	movlw	0xB2		;Set the CRC16 registers to 0xB230, which is
	movwf	X3		; what the CRC-16/IBM-3740 CRC algorithm yields
	movlw	0x30		; when you feed 0xA1 0xA1 0xA1 0xFE into it
	movwf	X2		; "
	;fall through

MfmAddrCyl
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send cylinder number
	lsrf	CYLHEAD,W	; "
	movwf	TXREG		; "
	call	UpdateCrc	;Update CRC16 with it
	movf	X1,W		;Select the appropriate SRAM
	call	SelectSramW	; "
	;fall through

MfmAddrHead
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send head number
	movf	CYLHEAD,W	; "
	andlw	B'00000001'	; "
	movwf	TXREG		; "
	call	UpdateCrc	;Update CRC16 with it
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the SPI SRAM read command
	movlw	0x03		; "
	movwf	SSPBUF		; "
	;fall through

MfmAddrSector
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send sector number (and make it one-relative
	incf	SECTOR,W	; because of reasons)
	movwf	TXREG		; "
	call	UpdateCrc	;Update CRC16 with it
	movf	X1,W		;Get the top byte of the SRAM offset
	andlw	B'00000111'	; "
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the top byte of the SRAM offset
	movwf	SSPBUF		; "
	;fall through

MfmAddrFormat
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send format byte, which is always 2 to indicate
	movlw	2		; sectors are 512 bytes in length
	movwf	TXREG		; "
	call	UpdateCrc	;Update CRC16 with it
	movf	X0,W		;Get the second byte of the SRAM offset
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the second byte of the SRAM offset
	movwf	SSPBUF		; "
	;fall through

MfmAddrCrcHi
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the first (high) byte of the CRC for the
	movf	X3,W		; address header
	movwf	TXREG		; "
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the third byte of the SRAM offset,
	clrf	SSPBUF		; which is always zero
	;fall through

MfmAddrCrcLo
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the second (low) byte of the CRC for the
	movf	X2,W		; address header
	movwf	TXREG		; "
	movlw	22		;22 gap bytes before data mark
	movwf	X0		; "
	;fall through

MfmGapToDataMk
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM gap byte
	movlw	MFMGAP		; "
	movwf	TXREG		; "
	decfsz	X0,F		;If there are more bytes until the data mark,
	bra	MfmGapToDataMk	; loop
	movlw	12		;12 sync bytes before data mark
	movwf	X0		; "
	;fall through

MfmSyncToDataMk
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM sync byte
	movlw	MFMSYNC		; "
	movwf	TXREG		; "
	decfsz	X0,F		;If there are more bytes until the data mark,
	bra	MfmSyncToDataMk	; loop
	movlw	3		;3 special address/data mark bytes after the
	movwf	X0		; sync bytes
	;fall through

MfmDataMark1
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM data/address mark special byte
	movlw	MFMMARK		; (missing a clock)
	movwf	TXREG		; "
	decfsz	X0,F		;If there are more bytes until the next byte,
	bra	MfmDataMark1	; loop
	;fall through

MfmDataMark2
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM address mark byte
	movlw	MFMDATA		; "
	movwf	TXREG		; "
	movlw	0xE2		;Set the CRC16 registers to 0xE295, which is
	movwf	X3		; what the CRC-16/IBM-3740 CRC algorithm yields
	movlw	0x95		; when you feed 0xA1 0xA1 0xA1 0xFB into it
	movwf	X2		; "
	clrf	X0		;256 pairs of data bytes
	;fall through

MfmData1
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the first data byte
	clrf	SSPBUF		; "
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	4		;Get and send the next data byte
	movf	SSPBUF,W	; "
	movlb	3		; "
	movwf	TXREG		; "
	call	UpdateCrc	;Update CRC16 with it
	;fall through

MfmData2
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the first data byte
	clrf	SSPBUF		; "
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	4		;Get and send the next data byte
	movf	SSPBUF,W	; "
	movlb	3		; "
	movwf	TXREG		; "
	call	UpdateCrc	;Update CRC16 with it
	decfsz	X0,F		;Decrement the byte pair count and loop if there
	goto	MfmData1	; are more bytes to send
	call	DeselectSram	;Deselect all three SRAMs
	;fall through

MfmDataCrcHi
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the first (high) byte of the CRC for the
	movf	X3,W		; data sector
	movwf	TXREG		; "
	;fall through

MfmDataCrcLo
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send the second (low) byte of the CRC for the
	movf	X2,W		; data sector
	movwf	TXREG		; "
	movlw	101		;101 (high density) or 84 (double density) gap
	btfss	FLAGS,HIGHDEN	; bytes before end of sector
	movlw	84		; "
	movwf	X0		; "
	;fall through

MfmGapToNextSec
	call	MfmReadTxRx	;Wait for transmitter and SSP, handling receiver
	movlb	3		;Send an MFM gap byte
	movlw	MFMGAP		; "
	movwf	TXREG		; "
	decfsz	X0,F		;If there are more bytes until the next sector,
	bra	MfmGapToNextSec	; loop
	movf	SECTOR,W	;Increment sector number
	call	NextMfmSector	; "
	movwf	SECTOR		; "
	goto	MfmRestart	;Restart with next sector

MfmWriDeselect
	call	DeselectSram	;Deselect all three SRAMs
	;fall through

MfmWriStart
	call	MfmWriteTxRx	;Wait for SSP while handling receiver
	xorlw	MFMMARK		;We're sitting around waiting for an 0xA1 before
	btfss	STATUS,Z	; we can do anything
	bra	MfmWriStart	; "
	call	LookupMfmOffs	;Look up the offset of the current sector and
	call	SelectSram	; select appropriate SRAM
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the SPI SRAM write command as we need
	movlw	0x02		; to be ready in case this is a data mark
	movwf	SSPBUF		; "
	;fall through

MfmWri1A1
	call	MfmWriteTxRx	;Wait for SSP while handling receiver
	xorlw	MFMMARK		;Need another 0xA1 to proceed
	btfss	STATUS,Z	; "
	goto	MfmWriDeselect	; "
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	3		;Clock out the high byte of the address
	movf	PMDATH,W	; "
	andlw	B'00000111'	; "
	movlb	4		; "
	movwf	SSPBUF		; "
	;fall through

MfmWri2A1
	call	MfmWriteTxRx	;Wait for SSP while handling receiver
	xorlw	MFMMARK		;Need another 0xA1 to proceed
	btfss	STATUS,Z	; "
	goto	MfmWriDeselect	; "
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	3		;Clock out the mid byte of the address
	movf	PMDATL,W	; "
	movlb	4		; "
	movwf	SSPBUF		; "
	;fall through

MfmWri3A1
	call	MfmWriteTxRx	;Wait for SSP while handling receiver
	xorlw	MFMADDR		;Got three 0xA1s, an 0xFE means this is an
	btfsc	STATUS,Z	; address mark and we should bail out of the
	goto	MfmWriFE	; write we started
	xorlw	MFMDATA ^ MFMADDR;Got three 0xA1s, an 0xFB means this is a data
	btfss	STATUS,Z	; mark and the preparation we did up to now was
	goto	MfmWriDeselect	; warranted
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock out the low byte of the address, which is
	clrf	SSPBUF		; always zero
	call	PointCrc	;Set up for CRC16 calculation
	movlw	0xE2		;Set the CRC16 registers to 0xE295, which is
	movwf	X3		; what the CRC-16/IBM-3740 CRC algorithm yields
	movlw	0x95		; when you feed 0xA1 0xA1 0xA1 0xFB into it
	movwf	X2		; "
	clrf	X0		;256 pairs of data bytes
	;fall through

MfmWriData1
	call	MfmWriteTxRx	;Wait for SSP while handling receiver
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock the received byte out
	movwf	SSPBUF		; "
	call	UpdateCrc	;Update the CRC with it
	;fall through

MfmWriData2
	call	MfmWriteTxRx	;Wait for SSP while handling receiver
	movlb	0		;Clear the SSP interrupt flag as it's about to
	bcf	PIR1,SSP1IF	; be in use
	movlb	4		;Clock the received byte out
	movwf	SSPBUF		; "
	call	UpdateCrc	;Update the CRC with it
	decfsz	X0,F		;Decrement the byte pair count and loop if there
	goto	MfmWriData1	; are more bytes to receive
	;fall through

MfmWriCrc1
	call	MfmWriteTxRx	;Wait for SSP while handling receiver
	xorwf	X3,W		;Assert fail if CRC high byte is wrong
	btfss	STATUS,Z	; TODO can we do something better than this?
	bra	$		; "
	;fall through

MfmWriCrc2
	call	MfmWriteTxRx	;Wait for SSP while handling receiver
	xorwf	X2,W		;Assert fail if CRC low byte is wrong
	btfss	STATUS,Z	; TODO can we do something better than this?
	bra	$		; "
	movf	SECTOR,W	;Increment sector in case we're formatting
	call	NextMfmSector	; "
	movwf	SECTOR		; "
	goto	MfmWriDeselect	;Deselect SRAMs and wait for next write

MfmWriFE
	call	MfmWriteTxRx	;Wait for SSP while handling receiver
	movwf	X0		;Save received cylinder number
	call	DeselectSram	;Deselect all three SRAMs, cancelling write
	call	PointCrc	;Set up for CRC16 calculation
	movlw	0xB2		;Set the CRC16 registers to 0xB230, which is
	movwf	X3		; what the CRC-16/IBM-3740 CRC algorithm yields
	movlw	0x30		; when you feed 0xA1 0xA1 0xA1 0xFE into it
	movwf	X2		; "
	lsrf	CYLHEAD,W	;Check that the received cylinder number matches
	xorwf	X0,W		; the current cylinder and assert fail if not
	btfss	STATUS,Z	; TODO can we do something better than this?
	bra	$		; "
	movf	X0,W		;Update the CRC with the cylinder number
	call	UpdateCrc	; "
	;fall through

MfmWriAdrHead
	call	MfmWriteTxRx	;Wait for SSP while handling receiver
	movwf	X0		;Save received head number
	xorwf	CYLHEAD,W	;Check that the received head number matches the
	andlw	B'00000001'	; current head and assert fail if not
	btfss	STATUS,Z	; TODO can we do something better than this?
	bra	$		; "
	movf	X0,W		;Update the CRC with the head number
	call	UpdateCrc	; "
	;fall through

MfmWriAdrSec
	call	MfmWriteTxRx	;Wait for SSP while handling receiver
	movwf	X0		;Save received sector number
	call	UpdateCrc	;Update the CRC with the head number
	;fall through

MfmWriAdrSize
	call	MfmWriteTxRx	;Wait for SSP while handling receiver
	xorlw	2		;Check that the received sector size matches 2
	btfss	STATUS,Z	; (512 bytes) and assert fail if not
	bra	$		; TODO can we do something better than this?
	movlw	2		;Update the CRC with the sector size
	call	UpdateCrc	; "
	;fall through

MfmWriAdrCrc1
	call	MfmWriteTxRx	;Wait for SSP while handling receiver
	xorwf	X3,W		;Check if high byte of CRC matches and assert
	btfss	STATUS,Z	; fail if not
	bra	$		; TODO can we do something better than this?
	;fall through

MfmWriAdrCrc2
	call	MfmWriteTxRx	;Wait for SSP while handling receiver
	xorwf	X2,W		;Check if low byte of CRC matches and assert
	btfss	STATUS,Z	; fail if not
	bra	$		; TODO can we do something better than this?
	decf	X0,W		;CRC matches, so accept the sector number we
	movwf	SECTOR		; were given (adjust so it's zero-relative)
	call	STrace
	goto	MfmWriStart	;Wait for next write


;;; Specific Subprograms ;;;

STrace
	movf	SECTOR,W
	movwi	FSR1++
	btfsc	FSR1H,0
	incf	X4,F
	bcf	FSR1H,0
	return

;Read in 16-bit 256-byte block address from UART and clock out command (given in
; W) followed by byte address to SPI SRAM.  Clobbers X2, X1, X0.
UserAddress
	movwf	X0		;Save SPI command
	call	DeselectSram	;Deselect all three SRAMs
	movlb	0		;Get address MSB
	btfss	PIR1,RCIF	; "
	bra	$-1		; "
	movlb	3		; "
	movf	RCREG,W		; "
	movwf	X2		;Save it
	call	SelectSramW	;Select the appropriate SRAM
	movlb	0		;Clock out command byte
	bcf	PIR1,SSP1IF	; "
	movlb	4		; "
	movf	X0,W		; "
	movwf	SSPBUF		; "
	clrf	X0		;X0 later to be used as LSB of address
	movlb	0		;Get second byte of address
	btfss	PIR1,RCIF	; "
	bra	$-1		; "
	movlb	3		; "
	movf	RCREG,W		; "
	movwf	X1		;Save it
	movlb	0		;Make sure SSP is finished clocking out command
	btfss	PIR1,SSP1IF	; "
	bra	$-1		; "
	bcf	PIR1,SSP1IF	;Clock out MSB of address
	movlb	4		; "
	movf	X2,W		; "
	andlw	B'00000111'	; "
	movwf	SSPBUF		; "
	movlb	0		;Make sure SSP is finished clocking out MSB
	btfss	PIR1,SSP1IF	; "
	bra	$-1		; "
	bcf	PIR1,SSP1IF	;Clock out mid byte of address
	movlb	4		; "
	movf	X1,W		; "
	movwf	SSPBUF		; "
	movlb	0		;Make sure SSP is finished clocking out mid byte
	btfss	PIR1,SSP1IF	; "
	bra	$-1		; "
	bcf	PIR1,SSP1IF	;Clock out low byte of address (always 0)
	movlb	4		; "
	clrf	SSPBUF		; "
	return			;Done

;Wait for the UART transmitter and SSP to be ready while polling and handling
; the receiver for the GCR program in read mode.
GcrReadTxRx
	movlb	0		;If the transmitter and SSP are now ready and
	btfsc	PIR1,TXIF	; CTS is asserted (low), return
	btfss	PIR1,SSP1IF	; "
	bra	GRTxRx0		; "
	btfsc	CTS_PORT,CTS_PIN; "
	bra	GRTxRx0		; "
	return			; "
GRTxRx0	call	RxPoll		;Poll the receiver
	call	RxPop		;Try to pop from the receiver
	btfss	STATUS,Z	;If the queue is empty or the byte received was
	btfsc	STATUS,C	; a framing error/break character, loop around
	bra	GcrReadTxRx	; "
	xorlw	UPSEL0		;If we got a SEL change event, change CYLHEAD's
	btfsc	STATUS,Z	; LSb accordingly and restart the read program
	bra	GRTxRx1		; if it's different
	xorlw	UPSEL1 ^ UPSEL0	; "
	btfsc	STATUS,Z	; "
	bra	GRTxRx2		; "
	xorlw	UPMOFF ^ UPSEL1	;If we got a motor off event, turn the motor off
	btfsc	STATUS,Z	; "
	bra	GRTxRx4		; "
	xorlw	UPDATA0 ^ UPMOFF;If we got a data event, switch into the write
	btfsc	STATUS,Z	; program
	bra	GRTxRx5		; "
	xorlw	UPDATA1 ^ UPDATA0; "
	btfsc	STATUS,Z	; "
	bra	GRTxRx6		; "
	xorlw	0x00 ^ UPDATA1	;If the MSb of the received byte was low,
	btfsc	WREG,7		; indicating a step, proceed, otherwise loop
	bra	GcrReadTxRx	; "
	lslf	WREG,W		;Move the new cylinder into CYLHEAD, keeping the
	btfsc	CYLHEAD,0	; LSb (head number) as is
	iorlw	B'00000001'	; "
	movwf	CYLHEAD		; "
	bra	GRTxRx3		;Skip ahead to restart the read program
GRTxRx1	btfss	CYLHEAD,0	;If the head was already 0, don't do anything
	bra	GcrReadTxRx	; "
	bcf	CYLHEAD,0	;Otherwise, clear the head bit
	bra	GRTxRx3		;Skip ahead to restart the read program
GRTxRx2	btfsc	CYLHEAD,0	;If the head was already 1, don't do anything
	bra	GcrReadTxRx	; "
	bsf	CYLHEAD,0	;Otherwise, set the head bit
GRTxRx3	call	TxBreak		;Send a break character to halt transmission
	call	DeselectSram	;Deselect all three SRAMs
	movlb	31		;Abandon caller and 'return' to GcrStart
	movlw	high GcrStart	; "
	movwf	TOSH		; "
	movlw	low GcrStart	; "
	movwf	TOSL		; "
	return			; "
GRTxRx4	call	DeselectSram	;Deselect all three SRAMs
	movlb	31		;Abandon caller and 'return' to MotorOff (which
	movlw	high MotorOff	; will send a break character first thing)
	movwf	TOSH		; "
	movlw	low MotorOff	; "
	movwf	TOSL		; "
	return			; "
GRTxRx5	bcf	CYLHEAD,0	;Clear or set the side bit according to the data
	bra	GRTxRx7		; event
GRTxRx6	bsf	CYLHEAD,0	; "
GRTxRx7	call	TxBreak		;Send a break character to halt transmission
	call	DeselectSram	;Deselect all three SRAMs
	movlb	31		;Abandon caller and 'return' to GcrWriStart
	movlw	high GcrWriStart; "
	movwf	TOSH		; "
	movlw	low GcrWriStart	; "
	movwf	TOSL		; "
	return			; "

;Wait for SSP to be ready while polling the UART receiver and waiting to be able
; to pop a byte from it for the GCR program in write mode.  Return popped byte
; in W or switch back into read program on receiving a break character.
GcrWriteTxRx
	call	RxPoll		;Poll UART receiver
	movlb	0		;If SSP isn't ready yet, loop and keep polling
	btfss	PIR1,SSP1IF	; receiver
	bra	GcrWriteTxRx	; "
	call	RxPop		;If SSP is ready, try to pop from receiver queue
	btfsc	STATUS,Z	; and loop if there's nothing to pop
	bra	GcrWriteTxRx	; "
	btfss	STATUS,C	;If we did pop something from receiver queue and
	return			; it's not a break character, return it in W
	movf	WREG,W		;If it's a framing error and not a break, loop
	btfss	STATUS,Z	; to wait for the next byte
	bra	GcrWriteTxRx	; "
	movlb	31		;If it's a break character, abandon caller and
	movlw	high GcrStart	; 'return' to GcrStart (we don't need to send a
	movwf	TOSH		; break character in response because we did so
	movlw	low GcrStart	; already when switching to write program
	movwf	TOSL		; "
	return			; "

;Demangle an 'A' GCR byte, updating checksums and returning demangled byte in W.
GcrDemangleA
	rlf	FLAGS,F		;Load carry from saved carry
	bcf	STATUS,C	;Rotate checksum C left, not through carry,
	rlf	X3,F		; making its MSb the new carry
	btfsc	STATUS,C	; "
	bsf	X3,0		; "
	xorwf	X3,W		;XOR received byte with checksum C, save in W
	addwfc	X1,F		;Add received byte plus carry to checksum A
	rrf	FLAGS,F		;Save carry out
	return			;Return with demangled byte in W

;Demangle a 'B' GCR byte, updating checksums and returning demangled byte in W.
GcrDemangleB
	rlf	FLAGS,F		;Load carry from saved carry
	xorwf	X1,W		;XOR received byte with checksum A, save in W
	addwfc	X2,F		;Add received byte plus carry to checksum B
	rrf	FLAGS,F		;Save carry out
	return			;Return with demangled byte in W

;Demangle a 'C' GCR byte, updating checksums and returning demangled byte in W.
GcrDemangleC
	rlf	FLAGS,F		;Load carry from saved carry
	xorwf	X2,W		;XOR received byte with checksum B, save in W
	addwfc	X3,F		;Add received byte plus carry to checksum C
	rrf	FLAGS,F		;Save carry out
	return			;Return with demangled byte in W

;Wait for the UART transmitter and SSP to be ready while polling and handling
; the receiver for the raw GCR program in read mode.
GcrRawReadTxRx
	bra	GRRTRx1		;Make sure we poll the receiver at least once
GRRTRx0	movlb	0		;If the transmitter and SSP are now ready and
	btfsc	PIR1,TXIF	; CTS is asserted (low), return
	btfss	PIR1,SSP1IF	; "
	bra	GRRTRx1		; "
	btfsc	CTS_PORT,CTS_PIN; "
	bra	GRRTRx1		; "
	return			; "
GRRTRx1	call	RxPoll		;Poll the receiver
	call	RxPop		;Try to pop from the receiver
	btfss	STATUS,Z	;If the queue is empty or the byte received was
	btfsc	STATUS,C	; a framing error/break character, loop around
	bra	GRRTRx0		; "
	xorlw	UPSEL0		;If we got a SEL change event, change CYLHEAD's
	btfsc	STATUS,Z	; LSb accordingly and restart the read program
	bra	GRRTRx2		; if it's different
	xorlw	UPSEL1 ^ UPSEL0	; "
	btfsc	STATUS,Z	; "
	bra	GRRTRx3		; "
	xorlw	UPMOFF ^ UPSEL1	;If we got a motor off event, turn the motor off
	btfsc	STATUS,Z	; "
	bra	GRRTRx5		; "
	xorlw	UPDATA0 ^ UPMOFF;If we got a data event, switch into the write
	btfsc	STATUS,Z	; program
	bra	GRRTRx6		; "
	xorlw	UPDATA1 ^ UPDATA0; "
	btfsc	STATUS,Z	; "
	bra	GRRTRx6		; "
	xorlw	0x00 ^ UPDATA1	;If the MSb of the received byte was low,
	btfsc	WREG,7		; indicating a step, proceed, otherwise loop
	bra	GRRTRx0		; "
	lslf	WREG,W		;Move the new cylinder into CYLHEAD, keeping the
	btfsc	CYLHEAD,0	; LSb (head number) as is
	iorlw	B'00000001'	; "
	movwf	CYLHEAD		; "
	bra	GRRTRx4		;Skip ahead to restart the read program
GRRTRx2	btfss	CYLHEAD,0	;If the head was already 0, don't do anything
	bra	GRRTRx0		; "
	bcf	CYLHEAD,0	;Otherwise, clear the head bit
	bra	GRRTRx4		;Skip ahead to restart the read program
GRRTRx3	btfsc	CYLHEAD,0	;If the head was already 1, don't do anything
	bra	GRRTRx0		; "
	bsf	CYLHEAD,0	;Otherwise, set the head bit
GRRTRx4	call	TxBreak		;Send a break character to halt transmission
	call	DeselectSram	;Deselect all three SRAMs
	movlb	31		;Abandon caller and 'return' to GcrRawStart
	movlw	high GcrRawStart; "
	movwf	TOSH		; "
	movlw	low GcrRawStart	; "
	movwf	TOSL		; "
	return			; "
GRRTRx5	call	DeselectSram	;Deselect all three SRAMs
	movlb	31		;Abandon caller and 'return' to MotorOff (which
	movlw	high MotorOff	; will send a break character first thing)
	movwf	TOSH		; "
	movlw	low MotorOff	; "
	movwf	TOSL		; "
	return			; "
GRRTRx6	call	DeselectSram	;Deselect all three SRAMs
	bra	$		;TODO raw write

;Wait for the UART transmitter and SSP to be ready while polling and handling
; the receiver for the MFM program in read mode.
MfmReadTxRx
	movlb	0		;If the transmitter and SSP are now ready and
	btfsc	PIR1,TXIF	; CTS is asserted (low), return
	btfss	PIR1,SSP1IF	; "
	bra	MRTxRx0		; "
	btfsc	CTS_PORT,CTS_PIN; "
	bra	MRTxRx0		; "
	return			; "
MRTxRx0	call	RxPoll		;Poll the receiver
	call	RxPop		;Try to pop from the receiver
	btfss	STATUS,Z	;If the queue is empty or the byte received was
	btfsc	STATUS,C	; a framing error/break character, loop around
	bra	MfmReadTxRx	; "
	xorlw	UPSEL0		;If we got a SEL change event, change CYLHEAD's
	btfsc	STATUS,Z	; LSb accordingly and restart the read program
	bra	MRTxRx1		; if it's different
	xorlw	UPSEL1 ^ UPSEL0	; "
	btfsc	STATUS,Z	; "
	bra	MRTxRx2		; "
	xorlw	UPMOFF ^ UPSEL1	;If we got a motor off event, turn the motor off
	btfsc	STATUS,Z	; "
	bra	MRTxRx4		; "
	xorlw	UPDATA0 ^ UPMOFF;If we got a data event, switch into the write
	btfsc	STATUS,Z	; program
	bra	MRTxRx5		; "
	xorlw	UPDATA1 ^ UPDATA0; "
	btfsc	STATUS,Z	; "
	bra	MRTxRx6		; "
	xorlw	0x00 ^ UPDATA1	;If the MSb of the received byte was low,
	btfsc	WREG,7		; indicating a step, proceed, otherwise loop
	bra	MfmReadTxRx	; "
	lslf	WREG,W		;Move the new cylinder into CYLHEAD, keeping the
	btfsc	CYLHEAD,0	; LSb (head number) as is
	iorlw	B'00000001'	; "
	movwf	CYLHEAD		; "
	bra	MRTxRx3		;Skip ahead to restart the read program
MRTxRx1	btfss	CYLHEAD,0	;If the head was already 0, don't do anything
	bra	MfmReadTxRx	; "
	bcf	CYLHEAD,0	;Otherwise, clear the head bit
	bra	MRTxRx3		;Skip ahead to restart the read program
MRTxRx2	btfsc	CYLHEAD,0	;If the head was already 1, don't do anything
	bra	MfmReadTxRx	; "
	bsf	CYLHEAD,0	;Otherwise, set the head bit
MRTxRx3	call	TxBreak		;Send a break character to halt transmission
	call	DeselectSram	;Deselect all three SRAMs
	movlb	31		;Abandon caller and 'return' to MfmStart
	movlw	high MfmStart	; "
	movwf	TOSH		; "
	movlw	low MfmStart	; "
	movwf	TOSL		; "
	return			; "
MRTxRx4	call	DeselectSram	;Deselect all three SRAMs
	movlb	31		;Abandon caller and 'return' to MotorOff (which
	movlw	high MotorOff	; will send a break character first thing)
	movwf	TOSH		; "
	movlw	low MotorOff	; "
	movwf	TOSL		; "
	return			; "
MRTxRx5	bcf	CYLHEAD,0	;Clear or set the side bit according to the data
	bra	MRTxRx7		; event
MRTxRx6	bsf	CYLHEAD,0	; "
MRTxRx7	call	TxBreak		;Send a break character to halt transmission
	call	DeselectSram	;Deselect all three SRAMs
	movlb	31		;Abandon caller and 'return' to MfmWriStart
	movlw	high MfmWriStart; "
	movwf	TOSH		; "
	movlw	low MfmWriStart	; "
	movwf	TOSL		; "
	return			; "

;Wait for SSP to be ready while polling the UART receiver and waiting to be able
; to pop a byte from it for the MFM program in write mode.  Return popped byte
; in W or switch back into read program on receiving a break character.
MfmWriteTxRx
	call	RxPoll		;Poll UART receiver
	movlb	0		;If SSP isn't ready yet, loop and keep polling
	btfss	PIR1,SSP1IF	; receiver
	bra	MfmWriteTxRx	; "
	call	RxPop		;If SSP is ready, try to pop from receiver queue
	btfsc	STATUS,Z	; and loop if there's nothing to pop
	bra	MfmWriteTxRx	; "
	btfss	STATUS,C	;If we did pop something from receiver queue and
	return			; it's not a break character, return it in W
	movf	WREG,W		;If it's a framing error and not a break, loop
	btfss	STATUS,Z	; to wait for the next byte
	bra	MfmWriteTxRx	; "
	movlb	31		;If it's a break character, abandon caller and
	movlw	high MfmStart	; 'return' to MfmStart (we don't need to send a
	movwf	TOSH		; break character in response because we did so
	movlw	low MfmStart	; already when switching to write program
	movwf	TOSL		; "
	return			; "


;;; General Subprograms ;;;

;Point PMADRH to the CRC-16-CCITT LUT for use with UpdateCrc.
PointCrc
	movlb	3		;Point PMADRH to the CRC-16-CCITT LUT
	movlw	high LutCrc16	; "
	movwf	PMADRH		; "
	return			;Done

;Update X3:X2 with the byte in W.  PMADRH must already be pointing to the
; CRC-16-CCITT LUT.  Returns with BSR set to 3.
UpdateCrc
	movlb	3		;Switch to where program memory registers are
	xorwf	X3,W		;XOR the input byte with the high byte of the
	movwf	PMADRL		; register and look up this word in the lookup
	bsf	PMCON1,RD	; table
	nop			; "
	nop			; "
	movf	X2,W		;XOR the low byte of the register with the high
	xorwf	PMDATH,W	; byte from the lookup table, reconstructing the
	btfsc	PMDATL,2	; missing top two bits from bits 3 and 2 of the
	xorlw	B'01000000'	; low byte of the lookup table, and make this
	btfsc	PMDATL,3	; the new high byte of the register
	xorlw	B'10000000'	; "
	movwf	X3		; "
	movf	PMDATL,W	;Make the low byte from the lookup table the
	movwf	X2		; new low byte of the register
	return			;Done

;Return the next GCR sector from W in W according to CYLHEAD.
NextGcrSector
	andlw	B'00001111'	;Protect against sector numbers over 15
	btfsc	FLAGS,FOURONE	;If disk has 4:1 interleave, skip ahead to those
	bra	NGSect4		; tables
	btfsc	CYLHEAD,7	;If MSb of cylinder is set, assume we're in zone
	bra	NGSect3		; 4
	btfsc	CYLHEAD,6	;If bit 5 of cylinder is set, we're in zone 2 or
	bra	NGSect1		; 3
	btfsc	CYLHEAD,5	;If bit 4 of cylinder is set, we're in zone 1,
	bra	NGSect0		; else we're in zone 0
	brw			;2:1 LUT for zone 0 (12 sectors)
	dt	6,7,8,9,10,11,1	; "
	dt	2,3,4,5,0,0,0,0	; "
	dt	0		; "
NGSect0	brw			;2:1 LUT for zone 1 (11 sectors)
	dt	6,7,8,9,10,0,1,2; "
	dt	3,4,5,0,0,0,0,0	; "
NGSect1	btfsc	CYLHEAD,5	;If bit 4 of cylinder is set, we're in zone 3,
	bra	NGSect2		; else we're in zone 2
	brw			;2:1 LUT for zone 2 (10 sectors)
	dt	5,6,7,8,9,1,2,3	; "
	dt	4,0,0,0,0,0,0,0	; "
NGSect2	brw			;2:1 LUT for zone 3 (9 sectors)
	dt	5,6,7,8,0,1,2,3	; "
	dt	4,0,0,0,0,0,0,0	; "
NGSect3	brw			;2:1 LUT for zone 4 (8 sectors)
	dt	4,5,6,7,1,2,3,0	; "
	dt	0,0,0,0,0,0,0,0	; "
NGSect4	btfsc	CYLHEAD,7	;If MSb of cylinder is set, assume we're in zone
	bra	NGSect8		; 4
	btfsc	CYLHEAD,6	;If bit 5 of cylinder is set, we're in zone 2 or
	bra	NGSect6		; 3
	btfsc	CYLHEAD,5	;If bit 4 of cylinder is set, we're in zone 1,
	bra	NGSect5		; else we're in zone 0
	brw			;4:1 LUT for zone 0 (12 sectors)
	dt	3,4,5,6,7,8,9,10; "
	dt	11,1,2,0,0,0,0,0; "
NGSect5	brw			;4:1 LUT for zone 1 (11 sectors)
	dt	3,4,5,6,7,8,9,10; "
	dt	0,1,2,0,0,0,0,0	; "
NGSect6	btfsc	CYLHEAD,5	;If bit 4 of cylinder is set, we're in zone 3,
	bra	NGSect7		; else we're in zone 2
	brw			;4:1 LUT for zone 2 (10 sectors)
	dt	3,4,5,6,7,8,9,2	; "
	dt	0,1,0,0,0,0,0,0	; "
NGSect7	brw			;4:1 LUT for zone 3 (9 sectors)
	dt	2,3,4,5,6,7,8,0	; "
	dt	1,0,0,0,0,0,0,0	; "
NGSect8	brw			;4:1 LUT for zone 4 (8 sectors)
	dt	2,3,4,5,6,7,1,0	; "
	dt	0,0,0,0,0,0,0,0	; "

;Return the next MFM sector from W in W.  Note that sector number is 0-relative.
NextMfmSector
	btfss	FLAGS,HIGHDEN	;If this is a double density (720 kB) disk, skip
	bra	NMSect0		; ahead
	sublw	16		;If W > 16, return 0, else return W + 1
	btfss	STATUS,C	; "
	movlw	17		; "
	sublw	17		; "
	return			; "
NMSect0	sublw	7		;If W > 7, return 0, else return W + 1
	btfss	STATUS,C	; "
	movlw	8		; "
	sublw	8		; "
	return			; "

;Configure SSP for MMC card.  Caller must ensure SSP is idle.
SetSspMmc
	movlb	29		;Set SRAM MOSI pin to latch (always high) and
	clrf	SMO_PPS		; SRAM SCK pin to latch (always low)
	clrf	SCK_PPS		; "
	movlw	B'10010';SDO	;Set card MOSI pin to SSP SDO pin 
	movwf	CMO_PPS		; "
	movlw	B'10000';SCK	;Set card SCK pin to SSP SCK pin
	movwf	CCK_PPS		; "
	movlb	28		; "
	movlw	CCK_PPSI	; "
	movwf	SSPCLKPPS	; "
	movlw	CMI_PPSI	;Set SSP SDI pin to card MISO pin
	movwf	SSPDATPPS	; "
	return			;Done
	
;Configure SSP for SPI SRAM.  Caller must ensure SSP is idle.
SetSspSram
	movlb	29		;Set card MOSI pin to latch (always high) and
	clrf	CMO_PPS		; card SCK pin to latch (always low)
	clrf	CCK_PPS		; "
	movlw	B'10010';SDO	;Set SRAM MOSI pin to SSP SDO pin 
	movwf	SMO_PPS		; "
	movlw	B'10000';SCK	;Set SRAM SCK pin to SSP SCK pin
	movwf	SCK_PPS		; "
	movlb	28		; "
	movlw	SCK_PPSI	; "
	movwf	SSPCLKPPS	; "
	movlw	SMI_PPSI	;Set SSP SDI pin to SRAM MISO pin
	movwf	SSPDATPPS	; "
	return			;Done

;Configure UART for user.
SetUartUser
	movlb	3		;Wait until the transmitter is idle
	btfss	TXSTA,TRMT	; "
	bra	$-1		; "
	movlw	15		;Set baud rate generator to 500 kHz
	movwf	SPBRGL		; "
	movlb	29		;Set backend Rx (outbound) pin to latch (always
	clrf	BRX_PPS		; high)
	movlw	B'10100';TX	;Set user Tx pin to UART Tx pin
	movwf	UTX_PPS		; "
	movlb	28		; "
	movlw	UTX_PPSI	; "
	movwf	CKPPS		; "
	movlw	URX_PPSI	;Set UART Rx pin to user Rx pin
	movwf	RXPPS		; "
	goto	FlushUart	;Flush the UART FIFO

;Configure UART for backend.
SetUartBackend
	movlb	3		;Wait until the transmitter is idle
	btfss	TXSTA,TRMT	; "
	bra	$-1		; "
	movlw	7		;Set baud rate generator to 1 MHz
	movwf	SPBRGL		; "
	movlb	29		;Set user Tx pin to latch (always high)
	clrf	UTX_PPS		; "
	movlw	B'10100';TX	;Set backend Rx (outbound) pin to UART Tx pin
	movwf	BRX_PPS		; "
	movlb	28		; "
	movlw	BRX_PPSI	; "
	movwf	CKPPS		; "
	movlw	BTX_PPSI	;Set UART Rx pin to backend Tx (inbound) pin
	movwf	RXPPS		; "
	;fall through		;Flush the UART FIFO

;Flush the UART FIFO.
FlushUart
	movlb	0		;If the receive interrupt flag is not up, the
	btfss	PIR1,RCIF	; FIFO is empty, so return
	return			; "
	movlb	3		;If it is up, read a byte from the FIFO and loop
	movf	RCREG,W		; "
	bra	FlushUart	; "

;Poll the UART receiver.
RxPoll
	movlb	0		;If the receiver isn't ready to be read, return
	btfss	PIR1,RCIF	; immediately
	return			; "
	movlb	6		;Load the queue push pointer (advanced by 1)
	movlw	0x21		; into FSR0
	movwf	FSR0H		; "
	incf	UR_QPSH,W	; "
	movwf	FSR0L		; "
	incf	UR_QPSH,F	;Advance the pointer (by 2) and wrap it
	incf	UR_QPSH,F	; "
	bcf	UR_QPSH,5	; "
	movlb	3		;Push the state of the framing error bit onto
	movlw	0x00		; the queue (second byte in the pair)
	btfsc	RCSTA,FERR	; "
	movlw	0x01		; "
	movwi	FSR0--		; "
	movf	RCREG,W		;Push the received byte onto the queue (first
	movwf	INDF0		; byte in the pair)
	return			;Done

;Read a byte from the UART receiver queue, if possible.  Set Z if queue is
; empty (C unchanged, W clobbered), clear otherwise; if Z clear, W contains the
; popped byte and C is set if the byte was associated with a framing error (i.e.
; if W is zero, the popped byte is a break character).
RxPop
	movlb	6		;Check if queue is empty and return with Z set
	movf	UR_QPSH,W	; if it is
	xorwf	UR_QPOP,W	; "
	btfsc	STATUS,Z	; "
	return			; "
	movlw	0x21		;Load the queue pop pointer (advanced by 1) into
	movwf	FSR0H		; FSR0
	incf	UR_QPOP,W	; "
	movwf	FSR0L		; "
	incf	UR_QPOP,F	;Advance the pointer (by 2) and wrap it
	incf	UR_QPOP,F	; "
	bcf	UR_QPOP,5	; "
	lsrf	INDF0,W		;Put the FERR bit into C (second byte in pair)
	moviw	--FSR0		;Pop the received byte off the queue (first)
	bcf	STATUS,Z	;Clear Z so caller knows we popped a byte
	return			;Done

;Wait for the UART transmitter to be ready while polling the receiver.
TxGetReady
	movlb	0		;If the transmitter is now ready, return
	btfsc	PIR1,TXIF	; "
	return			; "
	call	RxPoll		;Poll the receiver
	bra	TxGetReady	;Loop

;Send a break character over the UART while polling the receiver.
TxBreak
	movlb	3		;Wait for the transmitter to be idle, polling
	btfsc	TXSTA,TRMT	; the receiver while we wait
	bra	TxBrk0		; "
	call	RxPoll		; "
	bra	TxBreak		; "
TxBrk0	bsf	TXSTA,SENDB	;Send a break character to make sure we're in
	clrf	TXREG		; command mode
TxBrk1	movlb	3		;Wait for the break character to finish, polling
	btfss	TXSTA,SENDB	; the receiver while we wait
	return			; "
	call	RxPoll		; "
	bra	TxBrk1		; "

;Select the appropriate SRAM chip for the address in PMDATH.
SelectSram
	movlb	3		;Get PCLATH
	movf	PMDATH,W	; "
	;fall through

;Select the appropriate SRAM chip for the address in W.
SelectSramW
	lslf	WREG,W		;Get the index of the SRAM chip select we should
	swapf	WREG,W		; use
	andlw	B'00000011'	; "
	movlb	2		;Switch off to assert it
	brw			; "
	bra	SeSram0		; "
	bra	SeSram1		; "
	bra	SeSram2		; "
	bra	SeSram3		; "
SeSram0	bcf	SC0_PORT,SC0_PIN;Assert chip select 0
	return			; "
SeSram1	bcf	SC1_PORT,SC1_PIN;Assert chip select 1
	return			; "
SeSram2	bcf	SC2_PORT,SC2_PIN;Assert chip select 2
SeSram3	return			;Done

;Deselect all SRAMs.
DeselectSram
	movlb	2		;Deselect all three SRAMs
	bsf	SC0_PORT,SC0_PIN; "
	bsf	SC1_PORT,SC1_PIN; "
	bsf	SC2_PORT,SC2_PIN; "
	return			;Done

;Look up the GCR disk file offset for the CHS address in CYLHEAD and SECTOR and
; put it in PMDATH:L.
LookupGcrOffs
	movlb	3		;Point PMADRH to the GCR image lookup tables
	movlw	high LutOffs800	; "
	movwf	PMADRH		; "
	btfss	FLAGS,TWOSIDE	;Point PMADRL to the appropriate index in the
	bra	LGOffs0		; GCR lookup tables for the current cylinder
	movf	CYLHEAD,W	; (and head, for double-sided disks)
	movwf	PMADRL		; "
	bra	LGOffs1		; "
LGOffs0	lsrf	CYLHEAD,W	; "
	addlw	0xA0		; "
	movwf	PMADRL		; "
LGOffs1	bsf	PMCON1,RD	;Execute a flash read, putting the offset into
	nop			; PMDATH:L (the high two bytes of the three byte
	nop			; offset in the SRAM)
	lslf	SECTOR,W	;Add the sector (times two, since sectors are
	addwf	PMDATL,F	; 512 bytes) to the offset read from the table
	movlw	0		; "
	addwfc	PMDATH,F	; "
	return			;Done

;Look up the GCR raw disk file offset for the CHS address in CYLHEAD and put it
; in PMDATH:L.
LookupGcrRawOffs
	movlb	3		;Point PMADRH to the GCR raw image lookup tables
	movlw	high LutOffsRaw800; "
	movwf	PMADRH		; "
	btfss	FLAGS,TWOSIDE	;Point PMADRL to the appropriate index in the
	bra	LGROff0		; GCR raw lookup tables for the current cylinder
	movf	CYLHEAD,W	; (and head, for double-sided disks)
	movwf	PMADRL		; "
	bra	LGROff1		; "
LGROff0	lsrf	CYLHEAD,W	; "
	addlw	0xA0		; "
	movwf	PMADRL		; "
LGROff1	bsf	PMCON1,RD	;Execute a flash read, putting the offset into
	nop			; PMDATH:L (the high two bytes of the three byte
	nop			; offset in the SRAM)
	return			;Done

;Look up the MFM disk file offset for the CHS address in CYLHEAD and SECTOR and
; put it in PMDATH:L.
LookupMfmOffs
	movlb	3		;Point PMADRH to the MFM lookup table
	movlw	high LutOffsMfm	; "
	movwf	PMADRH		; "
	movf	CYLHEAD,W	;Point PMADRL to the appropriate index in the
	movwf	PMADRL		; MFM lookup tables for current cylinder/head
	bsf	PMCON1,RD	;Execute a flash read, putting the offset into
	nop			; PMDATH:L (the high two bytes of the three byte
	nop			; offset in the SRAM)
	btfsc	FLAGS,HIGHDEN	;If this is a double-density (720 kB) MFM disk,
	bra	LMOffs0		; halve the offset
	lsrf	PMDATH,F	; "
	rrf	PMDATL,F	; "
LMOffs0	lslf	SECTOR,W	;Add the sector (times two, since sectors are
	addwf	PMDATL,F	; 512 bytes) to the offset read from the table
	movlw	0		; "
	addwfc	PMDATH,F	; "
	return			;Done


;;; Lookup Tables ;;;

	org	0x800

;LUT for CRC7 for card commands
LutCrc7
	dt	0x00,0x12,0x24,0x36,0x48,0x5A,0x6C,0x7E
	dt	0x90,0x82,0xB4,0xA6,0xD8,0xCA,0xFC,0xEE
	dt	0x32,0x20,0x16,0x04,0x7A,0x68,0x5E,0x4C
	dt	0xA2,0xB0,0x86,0x94,0xEA,0xF8,0xCE,0xDC
	dt	0x64,0x76,0x40,0x52,0x2C,0x3E,0x08,0x1A
	dt	0xF4,0xE6,0xD0,0xC2,0xBC,0xAE,0x98,0x8A
	dt	0x56,0x44,0x72,0x60,0x1E,0x0C,0x3A,0x28
	dt	0xC6,0xD4,0xE2,0xF0,0x8E,0x9C,0xAA,0xB8
	dt	0xC8,0xDA,0xEC,0xFE,0x80,0x92,0xA4,0xB6
	dt	0x58,0x4A,0x7C,0x6E,0x10,0x02,0x34,0x26
	dt	0xFA,0xE8,0xDE,0xCC,0xB2,0xA0,0x96,0x84
	dt	0x6A,0x78,0x4E,0x5C,0x22,0x30,0x06,0x14
	dt	0xAC,0xBE,0x88,0x9A,0xE4,0xF6,0xC0,0xD2
	dt	0x3C,0x2E,0x18,0x0A,0x74,0x66,0x50,0x42
	dt	0x9E,0x8C,0xBA,0xA8,0xD6,0xC4,0xF2,0xE0
	dt	0x0E,0x1C,0x2A,0x38,0x46,0x54,0x62,0x70
	dt	0x82,0x90,0xA6,0xB4,0xCA,0xD8,0xEE,0xFC
	dt	0x12,0x00,0x36,0x24,0x5A,0x48,0x7E,0x6C
	dt	0xB0,0xA2,0x94,0x86,0xF8,0xEA,0xDC,0xCE
	dt	0x20,0x32,0x04,0x16,0x68,0x7A,0x4C,0x5E
	dt	0xE6,0xF4,0xC2,0xD0,0xAE,0xBC,0x8A,0x98
	dt	0x76,0x64,0x52,0x40,0x3E,0x2C,0x1A,0x08
	dt	0xD4,0xC6,0xF0,0xE2,0x9C,0x8E,0xB8,0xAA
	dt	0x44,0x56,0x60,0x72,0x0C,0x1E,0x28,0x3A
	dt	0x4A,0x58,0x6E,0x7C,0x02,0x10,0x26,0x34
	dt	0xDA,0xC8,0xFE,0xEC,0x92,0x80,0xB6,0xA4
	dt	0x78,0x6A,0x5C,0x4E,0x30,0x22,0x14,0x06
	dt	0xE8,0xFA,0xCC,0xDE,0xA0,0xB2,0x84,0x96
	dt	0x2E,0x3C,0x0A,0x18,0x66,0x74,0x42,0x50
	dt	0xBE,0xAC,0x9A,0x88,0xF6,0xE4,0xD2,0xC0
	dt	0x1C,0x0E,0x38,0x2A,0x54,0x46,0x70,0x62
	dt	0x8C,0x9E,0xA8,0xBA,0xC4,0xD6,0xE0,0xF2


	org	0x900

;LUT for CRC-16-CCITT
;Note that this LUT is able to fit in 14-bit words because of the useful
; property that the missing bits 15 and 14 are the same as bits 3 and 2.
LutCrc16
	dw	0x0000,0x1021,0x2042,0x3063,0x0084,0x10A5,0x20C6,0x30E7
	dw	0x0108,0x1129,0x214A,0x316B,0x018C,0x11AD,0x21CE,0x31EF
	dw	0x1231,0x0210,0x3273,0x2252,0x12B5,0x0294,0x32F7,0x22D6
	dw	0x1339,0x0318,0x337B,0x235A,0x13BD,0x039C,0x33FF,0x23DE
	dw	0x2462,0x3443,0x0420,0x1401,0x24E6,0x34C7,0x04A4,0x1485
	dw	0x256A,0x354B,0x0528,0x1509,0x25EE,0x35CF,0x05AC,0x158D
	dw	0x3653,0x2672,0x1611,0x0630,0x36D7,0x26F6,0x1695,0x06B4
	dw	0x375B,0x277A,0x1719,0x0738,0x37DF,0x27FE,0x179D,0x07BC
	dw	0x08C4,0x18E5,0x2886,0x38A7,0x0840,0x1861,0x2802,0x3823
	dw	0x09CC,0x19ED,0x298E,0x39AF,0x0948,0x1969,0x290A,0x392B
	dw	0x1AF5,0x0AD4,0x3AB7,0x2A96,0x1A71,0x0A50,0x3A33,0x2A12
	dw	0x1BFD,0x0BDC,0x3BBF,0x2B9E,0x1B79,0x0B58,0x3B3B,0x2B1A
	dw	0x2CA6,0x3C87,0x0CE4,0x1CC5,0x2C22,0x3C03,0x0C60,0x1C41
	dw	0x2DAE,0x3D8F,0x0DEC,0x1DCD,0x2D2A,0x3D0B,0x0D68,0x1D49
	dw	0x3E97,0x2EB6,0x1ED5,0x0EF4,0x3E13,0x2E32,0x1E51,0x0E70
	dw	0x3F9F,0x2FBE,0x1FDD,0x0FFC,0x3F1B,0x2F3A,0x1F59,0x0F78
	dw	0x1188,0x01A9,0x31CA,0x21EB,0x110C,0x012D,0x314E,0x216F
	dw	0x1080,0x00A1,0x30C2,0x20E3,0x1004,0x0025,0x3046,0x2067
	dw	0x03B9,0x1398,0x23FB,0x33DA,0x033D,0x131C,0x237F,0x335E
	dw	0x02B1,0x1290,0x22F3,0x32D2,0x0235,0x1214,0x2277,0x3256
	dw	0x35EA,0x25CB,0x15A8,0x0589,0x356E,0x254F,0x152C,0x050D
	dw	0x34E2,0x24C3,0x14A0,0x0481,0x3466,0x2447,0x1424,0x0405
	dw	0x27DB,0x37FA,0x0799,0x17B8,0x275F,0x377E,0x071D,0x173C
	dw	0x26D3,0x36F2,0x0691,0x16B0,0x2657,0x3676,0x0615,0x1634
	dw	0x194C,0x096D,0x390E,0x292F,0x19C8,0x09E9,0x398A,0x29AB
	dw	0x1844,0x0865,0x3806,0x2827,0x18C0,0x08E1,0x3882,0x28A3
	dw	0x0B7D,0x1B5C,0x2B3F,0x3B1E,0x0BF9,0x1BD8,0x2BBB,0x3B9A
	dw	0x0A75,0x1A54,0x2A37,0x3A16,0x0AF1,0x1AD0,0x2AB3,0x3A92
	dw	0x3D2E,0x2D0F,0x1D6C,0x0D4D,0x3DAA,0x2D8B,0x1DE8,0x0DC9
	dw	0x3C26,0x2C07,0x1C64,0x0C45,0x3CA2,0x2C83,0x1CE0,0x0CC1
	dw	0x2F1F,0x3F3E,0x0F5D,0x1F7C,0x2F9B,0x3FBA,0x0FD9,0x1FF8
	dw	0x2E17,0x3E36,0x0E55,0x1E74,0x2E93,0x3EB2,0x0ED1,0x1EF0


	org	0xA00

;LUT for file offset of cylinder and head for 800 kB disks
;Index is cylinder in bits 7:1 and head in bit 0
;Output is bits 21:8 of file offset, bits 7:0 are always zero
LutOffs800
	dw	0x0000,0x0018,0x0030,0x0048,0x0060,0x0078,0x0090,0x00A8
	dw	0x00C0,0x00D8,0x00F0,0x0108,0x0120,0x0138,0x0150,0x0168
	dw	0x0180,0x0198,0x01B0,0x01C8,0x01E0,0x01F8,0x0210,0x0228
	dw	0x0240,0x0258,0x0270,0x0288,0x02A0,0x02B8,0x02D0,0x02E8
	dw	0x0300,0x0316,0x032C,0x0342,0x0358,0x036E,0x0384,0x039A
	dw	0x03B0,0x03C6,0x03DC,0x03F2,0x0408,0x041E,0x0434,0x044A
	dw	0x0460,0x0476,0x048C,0x04A2,0x04B8,0x04CE,0x04E4,0x04FA
	dw	0x0510,0x0526,0x053C,0x0552,0x0568,0x057E,0x0594,0x05AA
	dw	0x05C0,0x05D4,0x05E8,0x05FC,0x0610,0x0624,0x0638,0x064C
	dw	0x0660,0x0674,0x0688,0x069C,0x06B0,0x06C4,0x06D8,0x06EC
	dw	0x0700,0x0714,0x0728,0x073C,0x0750,0x0764,0x0778,0x078C
	dw	0x07A0,0x07B4,0x07C8,0x07DC,0x07F0,0x0804,0x0818,0x082C
	dw	0x0840,0x0852,0x0864,0x0876,0x0888,0x089A,0x08AC,0x08BE
	dw	0x08D0,0x08E2,0x08F4,0x0906,0x0918,0x092A,0x093C,0x094E
	dw	0x0960,0x0972,0x0984,0x0996,0x09A8,0x09BA,0x09CC,0x09DE
	dw	0x09F0,0x0A02,0x0A14,0x0A26,0x0A38,0x0A4A,0x0A5C,0x0A6E
	dw	0x0A80,0x0A90,0x0AA0,0x0AB0,0x0AC0,0x0AD0,0x0AE0,0x0AF0
	dw	0x0B00,0x0B10,0x0B20,0x0B30,0x0B40,0x0B50,0x0B60,0x0B70
	dw	0x0B80,0x0B90,0x0BA0,0x0BB0,0x0BC0,0x0BD0,0x0BE0,0x0BF0
	dw	0x0C00,0x0C10,0x0C20,0x0C30,0x0C40,0x0C50,0x0C60,0x0C70


	org	0xAA0

;LUT for file offset of cylinder for 400 kB disks
;Index is 0xA0 + cylinder
;Output is bits 21:8 of file offset, bits 7:0 are always zero
LutOffs400
	dw	0x0000,0x0018,0x0030,0x0048,0x0060,0x0078,0x0090,0x00A8
	dw	0x00C0,0x00D8,0x00F0,0x0108,0x0120,0x0138,0x0150,0x0168
	dw	0x0180,0x0196,0x01AC,0x01C2,0x01D8,0x01EE,0x0204,0x021A
	dw	0x0230,0x0246,0x025C,0x0272,0x0288,0x029E,0x02B4,0x02CA
	dw	0x02E0,0x02F4,0x0308,0x031C,0x0330,0x0344,0x0358,0x036C
	dw	0x0380,0x0394,0x03A8,0x03BC,0x03D0,0x03E4,0x03F8,0x040C
	dw	0x0420,0x0432,0x0444,0x0456,0x0468,0x047A,0x048C,0x049E
	dw	0x04B0,0x04C2,0x04D4,0x04E6,0x04F8,0x050A,0x051C,0x052E
	dw	0x0540,0x0550,0x0560,0x0570,0x0580,0x0590,0x05A0,0x05B0
	dw	0x05C0,0x05D0,0x05E0,0x05F0,0x0600,0x0610,0x0620,0x0630


	org	0xAF0

;16 unused words


	org	0xB00

;LUT for file offset of cylinder and head for raw GCR 800 kB kB disks
;Index is cylinder in bits 7:1 and head in bit 0
;Output is bits 21:8 of file offset, bits 7:0 are always zero
;This leads to the following maximum bitstream sizes:
;Tracks  0-15: 11520 bytes (960 bytes per sector)
;Tracks 16-31: 10496 bytes (~954 bytes per sector)
;Tracks 32-47:  9728 bytes (~972 bytes per sector)
;Tracks 48-63:  8704 bytes (~967 bytes per sector)
;Tracks 64-79:  7680 bytes (960 bytes per sector)
LutOffsRaw800
	dw	0x0000,0x002D,0x005A,0x0087,0x00B4,0x00E1,0x010E,0x013B
	dw	0x0168,0x0195,0x01C2,0x01EF,0x021C,0x0249,0x0276,0x02A3
	dw	0x02D0,0x02FD,0x032A,0x0357,0x0384,0x03B1,0x0400,0x042D
	dw	0x045A,0x0487,0x04B4,0x04E1,0x050E,0x053B,0x0568,0x0595
	dw	0x05C2,0x05EB,0x0614,0x063D,0x0666,0x068F,0x06B8,0x06E1
	dw	0x070A,0x0733,0x075C,0x0785,0x07AE,0x07D7,0x0800,0x0829
	dw	0x0852,0x087B,0x08A4,0x08CD,0x08F6,0x091F,0x0948,0x0971
	dw	0x099A,0x09C3,0x09EC,0x0A15,0x0A3E,0x0A67,0x0A90,0x0AB9
	dw	0x0AE2,0x0B08,0x0B2E,0x0B54,0x0B7A,0x0BA0,0x0BC6,0x0C00
	dw	0x0C26,0x0C4C,0x0C72,0x0C98,0x0CBE,0x0CE4,0x0D0A,0x0D30
	dw	0x0D56,0x0D7C,0x0DA2,0x0DC8,0x0DEE,0x0E14,0x0E3A,0x0E60
	dw	0x0E86,0x0EAC,0x0ED2,0x0EF8,0x0F1E,0x0F44,0x0F6A,0x0F90
	dw	0x0FB6,0x0FD8,0x1000,0x1022,0x1044,0x1066,0x1088,0x10AA
	dw	0x10CC,0x10EE,0x1110,0x1132,0x1154,0x1176,0x1198,0x11BA
	dw	0x11DC,0x11FE,0x1220,0x1242,0x1264,0x1286,0x12A8,0x12CA
	dw	0x12EC,0x130E,0x1330,0x1352,0x1374,0x1396,0x13B8,0x13DA
	dw	0x1400,0x141E,0x143C,0x145A,0x1478,0x1496,0x14B4,0x14D2
	dw	0x14F0,0x150E,0x152C,0x154A,0x1568,0x1586,0x15A4,0x15C2
	dw	0x15E0,0x15FE,0x161C,0x163A,0x1658,0x1676,0x1694,0x16B2
	dw	0x16D0,0x16EE,0x170C,0x172A,0x1748,0x1766,0x1784,0x17A2


	org	0xBA0

;LUT for file offset of cylinder and head for raw GCR 400 kB disks
;Index is 0xA0 + cylinder
;Output is bits 21:8 of file offset, bits 7:0 are always zero
;This leads to the following maximum bitstream sizes:
;Tracks  0-15: 22784 bytes (~1898 bytes per sector)
;Tracks 16-31: 20992 bytes (~1908 bytes per sector)
;Tracks 32-47: 18944 bytes (~1894 bytes per sector)
;Tracks 48-63: 17152 bytes (~1905 bytes per sector)
;Tracks 64-79: 15104 bytes (~1888 bytes per sector)
LutOffsRaw400
	dw	0x0000,0x0059,0x00B2,0x010B,0x0164,0x01BD,0x0216,0x026F
	dw	0x02C8,0x0321,0x037A,0x0400,0x0459,0x04B2,0x050B,0x0564
	dw	0x05BD,0x060F,0x0661,0x06B3,0x0705,0x0757,0x07A9,0x0800
	dw	0x0852,0x08A4,0x08F6,0x0948,0x099A,0x09EC,0x0A3E,0x0A90
	dw	0x0AE2,0x0B2C,0x0B76,0x0C00,0x0C4A,0x0C94,0x0CDE,0x0D28
	dw	0x0D72,0x0DBC,0x0E06,0x0E50,0x0E9A,0x0EE4,0x0F2E,0x0F78
	dw	0x1000,0x1043,0x1086,0x10C9,0x110C,0x114F,0x1192,0x11D5
	dw	0x1218,0x125B,0x129E,0x12E1,0x1324,0x1367,0x13AA,0x1400
	dw	0x1443,0x147E,0x14B9,0x14F4,0x152F,0x156A,0x15A5,0x15E0
	dw	0x161B,0x1656,0x1691,0x16CC,0x1707,0x1742,0x177D,0x17B8


	org	0xBF0

;16 unused words


	org	0xC00

;LUT for file offset of cylinder and head for 1.44 MB and 720 kB disks
;Index is cylinder in bits 7:1 and head in bit 0
;Output for 1.44 MB disks is bits 21:8 of file offset, bits 9:0 are always zero
;Output for 720 kB disks is bits 20:7 of file offset, bits 8:0 are always zero
LutOffsMfm
	dw	0x0000,0x0024,0x0048,0x006C,0x0090,0x00B4,0x00D8,0x00FC
	dw	0x0120,0x0144,0x0168,0x018C,0x01B0,0x01D4,0x01F8,0x021C
	dw	0x0240,0x0264,0x0288,0x02AC,0x02D0,0x02F4,0x0318,0x033C
	dw	0x0360,0x0384,0x03A8,0x03CC,0x03F0,0x0414,0x0438,0x045C
	dw	0x0480,0x04A4,0x04C8,0x04EC,0x0510,0x0534,0x0558,0x057C
	dw	0x05A0,0x05C4,0x05E8,0x060C,0x0630,0x0654,0x0678,0x069C
	dw	0x06C0,0x06E4,0x0708,0x072C,0x0750,0x0774,0x0798,0x07BC
	dw	0x07E0,0x0804,0x0828,0x084C,0x0870,0x0894,0x08B8,0x08DC
	dw	0x0900,0x0924,0x0948,0x096C,0x0990,0x09B4,0x09D8,0x09FC
	dw	0x0A20,0x0A44,0x0A68,0x0A8C,0x0AB0,0x0AD4,0x0AF8,0x0B1C
	dw	0x0B40,0x0B64,0x0B88,0x0BAC,0x0BD0,0x0BF4,0x0C18,0x0C3C
	dw	0x0C60,0x0C84,0x0CA8,0x0CCC,0x0CF0,0x0D14,0x0D38,0x0D5C
	dw	0x0D80,0x0DA4,0x0DC8,0x0DEC,0x0E10,0x0E34,0x0E58,0x0E7C
	dw	0x0EA0,0x0EC4,0x0EE8,0x0F0C,0x0F30,0x0F54,0x0F78,0x0F9C
	dw	0x0FC0,0x0FE4,0x1008,0x102C,0x1050,0x1074,0x1098,0x10BC
	dw	0x10E0,0x1104,0x1128,0x114C,0x1170,0x1194,0x11B8,0x11DC
	dw	0x1200,0x1224,0x1248,0x126C,0x1290,0x12B4,0x12D8,0x12FC
	dw	0x1320,0x1344,0x1368,0x138C,0x13B0,0x13D4,0x13F8,0x141C
	dw	0x1440,0x1464,0x1488,0x14AC,0x14D0,0x14F4,0x1518,0x153C
	dw	0x1560,0x1584,0x15A8,0x15CC,0x15F0,0x1614,0x1638,0x165C


;;; MMC Subprograms ;;;

;Initialize MMC card.  Sets M_FAIL on fail.  If M_FAIL is set, W is set to an
; error code that indicates where the error occurred.  Trashes SSP1MSK and
; M_CNTH:L.
MmcInit
	movlb	6		;Make sure flags are all clear to begin with
	clrf	M_FLAGS		; "
	call	MmcIni0		;Call into the function below
	movlb	2		;Always deassert !CS
	bsf	CCS_PORT,CCS_PIN; "
	movlb	6		; "
	movf	WREG,W		;If the init function returned a code other
	btfss	STATUS,Z	; than 0, set the fail flag
	bsf	M_FLAGS,M_FAIL	; "
	return			;Pass return code to caller
MmcIni0	movlb	2		;Deassert !CS
	bsf	CCS_PORT,CCS_PIN; "
	movlb	4		;This is where all the SSP registers are
	movlw	10		;Send 80 clocks on SPI interface to ensure MMC
	movwf	SSP1MSK		; card is started up and in native command mode
MmcIni1	movlw	0xFF		; "
	movwf	SSP1BUF		; "
	btfss	SSP1STAT,BF	; "
	bra	$-1		; "
	decfsz	SSP1MSK,F	; "
	bra	MmcIni1		; "
	movlb	2		;Assert !CS
	bcf	CCS_PORT,CCS_PIN; "
	movlb	6		; "
	movlw	0x40		;Send command 0 (expect R1-type response)
	movwf	M_CMDN		; which, with !CS asserted, signals to the card
	clrf	M_ADR3		; that we want to enter SPI mode
	clrf	M_ADR2		; "
	clrf	M_ADR1		; "
	clrf	M_ADR0		; "
	call	MmcCmd		; "
	btfsc	M_FLAGS,M_FAIL	;If this command failed, unrecognized or
	retlw	1		; missing MMC card, fail the init operation
	xorlw	0x01		;If this command returned any response other
	btfss	STATUS,Z	; than 0x01 ('in idle state'), unrecognized MMC
	retlw	2		; card, fail the init operation
	bsf	M_FLAGS,M_CDVER	;Assume version 2.0+ to begin with
	clrf	M_CNTH		;Set retry counter to 0 (65536) for later use
	clrf	M_CNTL		; "
	movlw	0x48		;Send command 8 (expect R7-type response) to
	movwf	M_CMDN		; check if we're dealing with a V2.0+ card
	clrf	M_ADR3		; "
	clrf	M_ADR2		; "
	movlw	0x01		; "
	movwf	M_ADR1		; "
	movlw	0xAA		; "
	movwf	M_ADR0		; "
	call	MmcCmd		; "
	andlw	B'11111110'	;If the command set any error flags or there
	btfsc	STATUS,Z	; was no response, switch assumptions and guess
	btfsc	M_FLAGS,M_FAIL	; that we're dealing with a Version 1 card and
	bcf	M_FLAGS,M_CDVER	; jump ahead to initialize it
	btfss	M_FLAGS,M_CDVER	; "
	bra	MmcIni2		; "
	call	MmcExtResponse	;Command didn't error, so get the R7 response
	movf	M_ADR1,W	;If the command didn't error, but the lower 12
	andlw	B'00001111'	; bits of the R7 response are something besides
	xorlw	0x01		; 0x1AA, we're dealing with an unknown card, so
	btfss	STATUS,Z	; raise the fail flag and return to caller
	retlw	3		; "
	movf	M_ADR0,W	; "
	xorlw	0xAA		; "
	btfss	STATUS,Z	; "
	retlw	3		; "
MmcIni2	movlw	0x77		;Send command 55 (expect R1-type response),
	movwf	M_CMDN		; which is a prelude to an 'app' command
	clrf	M_ADR3		; "
	clrf	M_ADR2		; "
	clrf	M_ADR1		; "
	clrf	M_ADR0		; "
	call	MmcCmd		; "
	andlw	B'11111110'	;If we got a status with any error bits set,
	btfss	STATUS,Z	; treat as a command failure
	bsf	M_FLAGS,M_FAIL	; "
	btfsc	M_FLAGS,M_FAIL	;If this command fails, this is an unknown card
	retlw	4		; so return the failure to caller
	movlw	0x69		;Send app command 41 (expect R1-type response)
	movwf	M_CMDN		; to initialize the card, setting the HCS
	clrf	M_ADR3		; (high-capacity support) bit if we're dealing
	btfsc	M_FLAGS,M_CDVER	; with a V2.0+ card to let the card know that
	bsf	M_ADR3,6	; we support cards bigger than 4 GB (up to 2 
	clrf	M_ADR2		; TB)
	clrf	M_ADR1		; "
	clrf	M_ADR0		; "
	call	MmcCmd		; "
	btfsc	STATUS,Z	;If it returned an 0x00 status, initialization
	bra	MmcIni3		; is finished
	andlw	B'11111110'	;If we got a status with any error bits set,
	btfss	STATUS,Z	; treat as a command failure
	bsf	M_FLAGS,M_FAIL	; "
	btfsc	M_FLAGS,M_FAIL	;If this command fails, this is an unknown card
	retlw	5		; so return the failure to caller
	DELAY	40		;If it returned an 0x01 status, delay for 120
	decfsz	M_CNTL,F	; cycles (15 us), decrement the retry counter,
	bra	MmcIni2		; and try again
	decfsz	M_CNTH,F	; "
	bra	MmcIni2		; "
	retlw	6		;If card still not ready, report failure
MmcIni3	movlw	0x7A		;Send command 58 (expect R3-type response) to
	movwf	M_CMDN		; read the operating condition register (OCR)
	clrf	M_ADR3		; "
	clrf	M_ADR2		; "
	clrf	M_ADR1		; "
	clrf	M_ADR0		; "
	call	MmcCmd		; "
	btfss	STATUS,Z	;If we got a status with any error bits set,
	bsf	M_FLAGS,M_FAIL	; treat as a command failure
	btfsc	M_FLAGS,M_FAIL	;If this command fails, something is wrong, so
	retlw	7		; return the failure to caller
	call	MmcExtResponse	;Command didn't fail, so get R3 response
	bsf	M_FLAGS,M_BKADR	;If the card capacity status (CCS) bit of the
	btfsc	M_ADR3,6	; OCR is set, we're using block addressing, so
	bra	MmcIni4		; skip ahead
	bcf	M_FLAGS,M_BKADR	;We're dealing with byte, not block addressing
	movlw	0x50		;Send command 16 (expect R1-type response) to
	movwf	M_CMDN		; tell the card we want to deal in 512-byte
	clrf	M_ADR3		; sectors
	clrf	M_ADR2		; "
	movlw	0x02		; "
	movwf	M_ADR1		; "
	clrf	M_ADR0		; "
	call	MmcCmd		; "
	btfss	STATUS,Z	;If this command returned any nonzero response,
	bsf	M_FLAGS,M_FAIL	; something is wrong, fail the init operation
	btfsc	M_FLAGS,M_FAIL	;If this command failed, something is wrong,
	retlw	8		; fail the init operation
MmcIni4	movlw	0x7B		;Send command 59 (expect R1-type response) to
	movwf	M_CMDN		; tell the card we want to make life hard on
	clrf	M_ADR3		; ourselves and have our CRCs checked by the
	clrf	M_ADR2		; card
	clrf	M_ADR1		; "
	movlw	0x01		; "
	movwf	M_ADR0		; "
	call	MmcCmd		; "
	btfss	STATUS,Z	;If this command returned any nonzero response,
	bsf	M_FLAGS,M_FAIL	; something is wrong, fail the init operation
	btfsc	M_FLAGS,M_FAIL	;If this command failed, something is wrong,
	retlw	9		; fail the init operation
	retlw	0		;Congratulations, card is initialized!

;Convert a block address to a byte address if byte addressing is in effect.
; Sets M_FAIL if the block address is above 0x7FFFFF (and thus can't fit as a
; byte address).  Requires BSR to be set to 6.
MmcConvAddr
	bcf	M_FLAGS,M_FAIL	;Assume no failure to start with
	btfsc	M_FLAGS,M_BKADR	;If block addressing is in effect, the address
	return			; does not need to be converted
	movf	M_ADR3,F	;Make sure that the top 9 bits of the block
	btfss	STATUS,Z	; address are clear; if they are not, set the
	bsf	M_FLAGS,M_FAIL	; fail flag
	btfsc	M_ADR2,7	; "
	bsf	M_FLAGS,M_FAIL	; "
	btfsc	M_FLAGS,M_FAIL	;If the fail flag is set, we're done
	return			; "
	lslf	M_ADR0,F	;Multiply the block address by 2 and then by
	rlf	M_ADR1,F	; 256
	rlf	M_ADR2,W	; "
	movwf	M_ADR3		; "
	movf	M_ADR1,W	; "
	movwf	M_ADR2		; "
	movf	M_ADR0,W	; "
	movwf	M_ADR1		; "
	clrf	M_ADR0		; "
	return

;Increment the address by one block according to the block/byte addressing
; mode.  No protection is provided against the address wrapping around.
; Requires BSR to be set to 6.
MmcIncAddr
	movlw	0x01		;Add 1 to the address if we're in block mode,
	btfss	M_FLAGS,M_BKADR	; add 512 to the address if we're in byte mode,
	movlw	0		; in either case carrying the remainder through
	addwf	M_ADR0,F	; "
	movlw	0		; "
	btfss	M_FLAGS,M_BKADR	; "
	movlw	0x02		; "
	addwfc	M_ADR1,F	; "
	movlw	0		; "
	addwfc	M_ADR2,F	; "
	addwfc	M_ADR3,F	; "
	return

;Send the command contained in M_CMDN and M_ADR3-0 to MMC card.  Sets M_FAIL on
; fail.  If M_FAIL is not set, W is set to last byte received.  Trashes SSP1MSK.
; Returns with BSR set to 6.
MmcCmd
	movlb	6		;Assume no failure to start with
	bcf	M_FLAGS,M_FAIL	; "
	movf	M_CMDN,W	;Switch to the bank with the SSP registers
	movlb	4		;If this is a CMD0, skip over the ready check
	xorlw	0x40		; as card is not in SPI mode and may not be
	btfsc	STATUS,Z	; driving the MISO pin
	bra	MmcCmd1		; "
	movlw	8		;Make sure the MMC card is ready for a command
	movwf	SSP1MSK		; by clocking up to 8 bytes to get an 0xFF
MmcCmd0	movlw	0xFF		;Clock a byte out of the MMC card while keeping
	movwf	SSP1BUF		; MOSI high
	btfss	SSP1STAT,BF	; "
	bra	$-1		; "
	xorwf	SSP1BUF,W	;If we got an 0xFF back from the MMC card, it
	btfsc	STATUS,Z	; is ready to accept a command
	bra	MmcCmd1		; "
	decfsz	SSP1MSK,F	;Decrement the attempt counter until we've
	bra	MmcCmd0		; tried eight times; if card hasn't responded
	movlb	6		; 0xFF by the eighth attempt, signal failure
	bsf	M_FLAGS,M_FAIL	; and return
	return			; "
MmcCmd1	clrf	SSP1MSK		;Start the CRC7 register out at 0
	movlp	high LutCrc7	;Point PCLATH to the CRC7 lookup table
	movlb	6		;Clock out all six MMC buffer bytes as command,
	movf	M_CMDN,W	; calculating the CRC7 along the way
	movlb	4		; "
	movwf	SSP1BUF		; "
	xorwf	SSP1MSK,W	; "
	callw			; "
	movwf	SSP1MSK		; "
	btfss	SSP1STAT,BF	; "
	bra	$-1		; "
	movlb	6		; "
	movf	M_ADR3,W	; "
	movlb	4		; "
	movwf	SSP1BUF		; "
	xorwf	SSP1MSK,W	; "
	callw			; "
	movwf	SSP1MSK		; "
	btfss	SSP1STAT,BF	; "
	bra	$-1		; "
	movlb	6		; "
	movf	M_ADR2,W	; "
	movlb	4		; "
	movwf	SSP1BUF		; "
	xorwf	SSP1MSK,W	; "
	callw			; "
	movwf	SSP1MSK		; "
	btfss	SSP1STAT,BF	; "
	bra	$-1		; "
	movlb	6		; "
	movf	M_ADR1,W	; "
	movlb	4		; "
	movwf	SSP1BUF		; "
	xorwf	SSP1MSK,W	; "
	callw			; "
	movwf	SSP1MSK		; "
	btfss	SSP1STAT,BF	; "
	bra	$-1		; "
	movlb	6		; "
	movf	M_ADR0,W	; "
	movlb	4		; "
	movwf	SSP1BUF		; "
	xorwf	SSP1MSK,W	; "
	callw			; "
	movlp	high MmcCmd	; "
	movwf	SSP1MSK		; "
	bsf	SSP1MSK,0	; "
	btfss	SSP1STAT,BF	; "
	bra	$-1		; "
	movf	SSP1MSK,W	; "
	movwf	SSP1BUF		; "
	btfss	SSP1STAT,BF	; "
	bra	$-1		; "
	;TODO for CMD12, it is necessary to clock and throw away a stuff byte?
	movlw	8		;Try to get status as many as eight times
	movwf	SSP1MSK		; "
	movlb	6		;If this is a CMD0, the bus may not be driven
	movf	M_CMDN,W	; until the first clock, so we may get an all-
	movlb	4		; ones response where the MSB reads as 0; set a
	xorlw	0x40		; flag so we can respond to that
	btfsc	STATUS,Z	; "
	bsf	SSP1MSK,7	; "
MmcCmd2	movlw	0xFF		;Clock a byte out of the MMC card while keeping
	movwf	SSP1BUF		; MOSI high
	btfss	SSP1STAT,BF	; "
	bra	$-1		; "
	xorwf	SSP1BUF,W	;Set Z flag if the received byte is all ones
	btfsc	SSP1MSK,7	;If this is the first byte from a CMD0, ignore
	andlw	0x7F		; the MSB when checking for all ones
	btfss	STATUS,Z	;If the byte read is not all ones, it's a
	bra	MmcCmd3		; result, so skip ahead
	bcf	SSP1MSK,7	;Clear the special CMD0 flag if it was set
	decfsz	SSP1MSK,F	;Decrement attempt counter; if card hasn't
	bra	MmcCmd2		; responded by eighth attempt, signal failure
	movlb	6		; "
	bsf	M_FLAGS,M_FAIL	; "
MmcCmd3	xorlw	0xFF		;Complement W so it reflects the last byte read
	movlb	4		;If we're returning the first byte from a CMD0,
	btfsc	SSP1MSK,7	; we should assume that the first bit was a 0
	andlw	0x7F		; "
	movlb	6		;Restore BSR to 6 and return
	return			; "

;Read the extended response of a command returning an R3 or R7 type response
; into M_ADR3-0.  Returns with BSR set to 6.
MmcExtResponse
	movlb	4		;Switch to the bank with the SSP registers
	movlw	0xFF		;Clock first extended response byte out of the
	movwf	SSP1BUF		; MMC card while keeping MOSI high and store it
	btfss	SSP1STAT,BF	; in the buffer
	bra	$-1		; "
	movf	SSP1BUF,W	; "
	movlb	6		; "
	movwf	M_ADR3		; "
	movlb	4		; "
	movlw	0xFF		;Clock second extended response byte out of the
	movwf	SSP1BUF		; MMC card while keeping MOSI high and store it
	btfss	SSP1STAT,BF	; in the buffer
	bra	$-1		; "
	movf	SSP1BUF,W	; "
	movlb	6		; "
	movwf	M_ADR2		; "
	movlb	4		; "
	movlw	0xFF		;Clock third extended response byte out of the
	movwf	SSP1BUF		; MMC card while keeping MOSI high and store it
	btfss	SSP1STAT,BF	; in the buffer
	bra	$-1		; "
	movf	SSP1BUF,W	; "
	movlb	6		; "
	movwf	M_ADR1		; "
	movlb	4		; "
	movlw	0xFF		;Clock fourth extended response byte out of the
	movwf	SSP1BUF		; MMC card while keeping MOSI high and store it
	btfss	SSP1STAT,BF	; in the buffer
	bra	$-1		; "
	movf	SSP1BUF,W	; "
	movlb	6		; "
	movwf	M_ADR0		; "
	return			;Return

;428 unused words


;;; Parameter Storage ;;;

	org	0xF80

;High-endurance flash memory
HighEndurance
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF
	dw	0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF,0x3FFF


;;; End of Program ;;;

	end

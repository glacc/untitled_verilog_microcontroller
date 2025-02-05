	.org	$0000
startup_vector:
	.db     $start
interrupt_vector:
	.db     $interrupt_handler

interrupt_handler:
	LDA	#40
	TAB
	LDA	$FB13
	AND
	CMP
	BEQ	$timer_interrupt
	BRA	$isr_end
timer_interrupt:
	LDA #20
	TAB
	LDA	$FB13
	AND
	CMP
	BEQ	$timer_int_reload_on
	LDA	#7F
	TAB
	LDA	$FB13
	AND
	STA	$FB13
	LDA	#A0
	TAB
	LDA	$FB13
	ORA
	STA	$FB13
	BRA	$isr_end
timer_int_reload_on:
	LDA	#40
	TAB
	LDA	$FB13
	ORA
	STA	$FB13
isr_end:
	RET

start:
	SSP	$0FFF
	LDA	#00
	STA $FB10	; TH = 0h00
	STA	$FB12	; DIV = 0h00
	LDA	#FF
	STA	$FB11	; TL = 0h10
	LDA	#90
	TAB
	LDA	$FB13
	ORA
	STA	$FB13	; Timer: EN = 1, RE = 0, IE = 1
setup_end:
	BRA	$setup_end

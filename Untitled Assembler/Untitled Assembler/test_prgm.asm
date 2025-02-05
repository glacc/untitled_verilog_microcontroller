	.org	$0000
startup_vector:
    .db     $start
interrupt_vector:
    .db     $key_count_inc
	
start:
	SSP	$0FFF
	BSR $init_1602
	LDA	#test_str.h
	TAR	A0H
	LDA	#test_str.l
	TAR	A0L
	BSR	$disp_str_1602	; Display testing string

	LDA	#01
	STA	$FB03
key_check_loop:
	LDA	#01
	TAB
	LDA	$FB02
	AND
	CMP
	BEQ	$key_check_loop
	LDA	#08
	TAR	R1
	LDA	#F7
	TAR	R2
	BSR	$delay
	LDA	#01
	TAB
	LDA	$FB02
	AND
	CMP
	BEQ	$key_check_loop
	BSR	$key_count_inc
	LDA	#01
	TAB
key_down_loop:
	LDA	$FB02
	AND
	CMP
	BLT	$key_down_loop
	BRA	$key_check_loop

key_count_inc:
	TRA	R0
	PUH
	TRA	R1
	PUH
	TRA	A0H
	PUH
	TRA	A0L
	PUH
	LDA	#key_count.h
	TAR	A0H
	LDA	#key_count.l
	TAR	A0L
	LDA	#01
	TAB
	LDA	(A0)
	ADD
	STA	(A0)
	TAR	R0
	LDA	#key_count_hex_str.h
	TAR	A0H
	LDA	#key_count_hex_str.l
	TAR	A0L
	BSR	$byte_to_hex_str
	LDA	#C0
	TAR	R0
	LDA	#00
	TAR	R1
	BSR	$write_1602		; Cursor -> 0h40
	BSR	$disp_str_1602
	POP
	TAR	A0L
	POP
	TAR	A0H
	POP
	TAR	R1
	POP
	TAR	R0
	RET

disp_str_1602:
	TRA	A0L
	PUH
	TRA	R0
	PUH
	TRA	R1
	PUH
    LDA #01
    TAR R1
disp_str_loop:
	LDA	#00
	TAB
	LDA	(A0)
	CMP
	BEQ	$disp_str_end
	TAR	R0
	BSR	$write_1602
	LDA	#01
	TAB
	TRA	A0L
	ADD
	TAR	A0L
	BRA	$disp_str_loop
disp_str_end:
	POP
	TAR	R1
	POP
	TAR	R0
	POP
	TAR	A0L
	RET

byte_to_hex_str:
	TRA	R1
	PUH
	TRA	A0L
	PUH
	LDA	#04
	TAB
	TRA	R0
	LSR
	TAR	R1
	BSR	$conv_hex_nibble
	LDA	#0F
	TAB
	TRA	R0
	AND
	TAR	R1
	BSR	$conv_hex_nibble
	LDA	#00
	STA	(A0)
	POP
	TAR	A0L
	POP
	TAR	R1
	RET
conv_hex_nibble:
	LDA	#0A
	TAB
	TRA	R1
	CMP
	BLT	$conv_0_9_h
	LDA	#37
	TAB
	TRA	R1
	ADD
	BRA	$conv_h_end
conv_0_9_h:
	LDA	#30
	TAB
	TRA	R1
	ADD
conv_h_end:
	STA	(A0)
	LDA	#01
	TAB
	TRA	A0L
	ADD
	TAR	A0L
	RET

init_1602:
	TRA	R2
	PUH
	TRA	R1
	PUH
	TRA	R0
	PUH
	LDA	#30
	TAR	R0
	STA	$FB00
	BSR	$write_1602_4bits	; 1st 0h3X
	BSR	$delay_10ms			; delay > 5ms
	BSR	$write_1602_4bits	; 2nd 0h3X
	BSR	$delay_5ms			; delay > 0.1ms
	BSR	$write_1602_4bits	; 3rd 0h3X
	BSR	$delay_5ms			; delay > 0.1ms
	LDA	#20
	TAR	R0
	STA	$FB00
	BSR	$write_1602_4bits	; 2Xh - 4-bit mode
	BSR	$delay_5ms			; delay > 0.1ms
	LDA	#28
	TAR	R0
	LDA	#00
	TAR	R1
	BSR	$write_1602			; 28h - 2 lines 5x7 char
	BSR	$delay_5ms			; delay > 0.05ms
	LDA	#08
	TAR	R0
	LDA	#00
	TAR	R1
	BSR	$write_1602			; 08h - display off
	BSR	$delay_5ms			; delay > 0.05ms
	LDA	#06
	TAR	R0
	LDA	#00
	TAR	R1
	BSR	$write_1602			; 06h - cursor increasement
	BSR	$delay_5ms			; delay > 0.05ms
	LDA	#0F
	TAR	R0
	LDA	#00
	TAR	R1
	BSR	$write_1602			; 0Ch - disp on, cursor on, blink on
	BSR	$delay_5ms			; delay > 0.05ms
	LDA	#01
	TAR	R0
	LDA	#00
	TAR	R1
	BSR	$write_1602			; 01h - clear display
	BSR	$delay_5ms			; delay > 3ms
	LDA	#02
	TAR	R0
	LDA	#00
	TAR	R1
	BSR	$write_1602			; 02h - home cursor
	BSR	$delay_5ms			; delay > 3ms, init end
	POP
	TAR R0
	POP
	TAR	R1
	POP
	TAR	R2
	RET
delay_10ms:
	LDA	#F7
	TAR	R2
	LDA	#08
	TAR	R1
	BSR	$delay
	RET
delay_5ms:
	LDA	#83
	TAR	R2
	LDA	#03
	TAR	R1
	BSR	$delay
	RET

write_1602:
	TRA	R2
	PUH
	TRA	R0
	PUH
	LDA	#00
	STA	$FB00	; P0 = 00h
	TAB
	TRA	R1
	CMP			; RS = (R1 == 0) ? 0 : 1
	BEQ	$rs_zero
	LDA	#01
	TAB
	LDA	$FB00
	ORA
	STA	$FB00	; RS = 1
	BRA	$rs_end
rs_zero:
	LDA	#FE
	TAB
	LDA	$FB00
	AND
	STA	$FB00
rs_end:
	BSR	$write_1602_4bits
	LDA	#04
	TAB
	TRA	R0
	LSL
	TAR	R0
	BSR	$write_1602_4bits
	POP
	TAR	R0
	POP
	TAR	R2
	RET
write_1602_4bits:
	LDA	#0F
	TAB
	LDA	$FB00
	AND
	TAR	R2
	LDA	#F0
	TAB
	TRA	R0
	AND
	TRB	R2
	ORA
	STA	$FB00
	TAB
	LDA	#04
	ORA
	STA	$FB00	; E = 1
	TAB
	LDA	#FB
	AND
	STA	$FB00	; E = 0
	RET	

delay:
	TRA	R0
	PUH
	TRA	R1
	PUH
	TRA	R2
	TAR	R0
loop1:
	LDA	#01
	TAB
	TRA	R0
	SUB
	TAR R0
	LDA	#00
	TAB
	TRA	R0
	CMP
	BEQ $skip1
	BRA $loop1
skip1:
	LDA	#01
	TAB
	TRA	R1
	SUB
	TAR	R1
	LDA	#00
	TAB
	TRA	R1
	CMP
	BEQ	$skip2
	TRA	R2
	TAR	R0
	BRA	$loop1
skip2:
	POP
	TAR	R1
	POP
	TAR	R0
	RET

	.org	$0900
test_str:
	.db		"Hello World !"

	.org	$0910
key_count:
	.db		#00

	.org	$0911
key_count_hex_str:
	.db		#00
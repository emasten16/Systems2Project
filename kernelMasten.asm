	.Code
	
	;; Set base and limit
	COPY	*+kernel_base 	+0
	DIV 	*+kernel_limit 	*+kernel_alloc_inKB *+bytes_per_KB
	ADD 	*+kernel_limit 	*+kernel_limit *+kernel_base

	;; tt_entries
	COPY	*+invalid_address_tt_entry	+handler_of_death
	COPY 	*+invalid_register_tt_entry 	+handler_of_death
	COPY 	*+bus_error_tt_entry 	+handler_of_death
	COPY 	*+clock_alarm_tt_entry 	+handler_of_death
	COPY 	*+divide_by_zero_tt_entry 	+handler_of_death
	COPY 	*+overflow_tt_entry 	+handler_of_death
	COPY 	*+invalid_instruction_tt_entry 	+handler_of_death
	COPY 	*+permission_violation_tt_entry 	+handler_of_death
	COPY 	*+invalid_shift_amount_tt_entry	+handler_of_death
	COPY 	*+system_call_tt_entry 	+handler_of_death
	COPY 	*+invalid_device_value_tt_entry 	+handler_of_death
	COPY 	*+device_failure_tt_entry 	+handler_of_death
	
	SETTBR 	+tt_base
	SETIBR	+ib_ip
	
	;; Finding next process in bus control (3rd 2)
	COPY 	%G0 	0
	COPY 	%G1 	2
	COPY 	%G2 	3
	COPY 	%G3 	*+devicetablestart

looptop:
	BEQ 	+foundProc 	%G0 	%G2
	ADD 	%G3 	%G3 	12
	ADD 	%G4 	%G3 	4
	ADD 	%G5 	%G4 	4
	BNEQ 	+looptop 	*%G3	%G1
	ADD 	%G0 	%G0 	1
foundROM:
	JUMP 	+looptop
foundProc:
	COPY 	%G3 	*+devicetablestart
	ADD 	%G3 	%G3 	8
	SUB 	%G3 	*%G3 	12
	COPY 	*%G3 	*%G4
	SUB 	%G2 	*%G5 	*%G4

	;; Find RAM
	COPY 	%G0 	3
	COPY	%G3	*+devicetablestart
looptop2:
	BEQ	+foundRAM	%G0	*%G3
	ADD	%G3	%G3	12
	JUMP 	+looptop2
foundRAM:
	ADD	%G5	%G3	4
	COPY	%G3 	*+devicetablestart
	ADD	%G3	%G3	8
	SUB	%G4	*%G3	8
	COPY	*%G4	*%G5
	ADD	%G4	%G4	4
	COPY 	*%G4	%G2

	;; Jump to process
	JUMPMD	*%G5 	2
	


	

handler_of_death:
	HALT
	




	.Numeric
devicetablestart:	0x00001000
bytes_per_word:	4
bytes_per_KB:	1024
words_per_KB:	256
kernel_alloc_inKB:	1024
kernel_base:	0
kernel_limit:	0
ib_ip:	0
tt_base:
invalid_address_tt_entry:	0
invalid_register_tt_entry:	0
bus_error_tt_entry:	0
clock_alarm_tt_entry:	0
divide_by_zero_tt_entry:	0
overflow_tt_entry:	0
invalid_instruction_tt_entry:	0
permission_violation_tt_entry:	0
invalid_shift_amount_tt_entry:	0
system_call_tt_entry:	0
invalid_device_value_tt_entry:	0
device_failure_tt_entry:	0
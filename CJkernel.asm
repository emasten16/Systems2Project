	.Code
	COPY	*+kernel_base	+0
	DIV	*+kernel_limit	*+kernel_allocation_in_KB	*+bytes_per_KB
	ADD	*+kernel_limit	*+kernel_limit	*+kernel_base
	
	COPY	*+invalid_address_tt_entry	+handler_of_death
	COPY	*+invalid_register_tt_entry	+handler_of_death
	COPY	*+bus_error_tt_entry	+handler_of_death
	COPY	*+clock_alarm_tt_entry	+handler_of_death
	COPY	*+divide_by_zero_tt_entry	+handler_of_death
	COPY	*+overflow_tt_entry	+handler_of_death
	COPY	*+invalid_instruction_tt_entry	+handler_of_death
	COPY	*+permission_violation_tt_entry	+handler_of_death
	COPY	*+invalid_shift_amount_tt_entry	+handler_of_death
	COPY	*+system_call_tt_entry	+handler_of_death
	;;COPY	*+invalid_device_value_tt_entry	+handler_of_death
	;;COPY	*+device_failure_tt_entry	+handler_of_death
	
	SETTBR	+tt_base
	SETIBR	+IB_IP
	

	;; Find the third ROM, DMA it into MM right after the kernel, jump to it
	COPY	%G0	0
	COPY	%G1	3
	COPY	%G2	2
	COPY	%G3	*+device_table_start
	ADD	%G5	%G3	8

looptop:
	BEQ	+found_ROM3	%G0	%G1
	ADD	%G3	%G3	12
	ADD	%G4	%G3	4
	BNEQ	+found_ROM	*%G3	%G2
	ADD	%G0	%G0	1

found_ROM:
	JUMP	+looptop
	
found_ROM3:
	;; start of new rom copied into DMA spot
	SUB	%G5	*%G5	12
	COPY	*%G5	*%G4
	;; length of rom in G1 to put in DMA spot when ready
	ADD	%G0	%G4	4
	SUB	%G1	*%G0	*%G4

;;; dmaing to a completely random address and jumping to it...should this have a rhyme or reason at some point?
	ADD	%G5	%G5	4 
	COPY	*%G5	0x0004000
	ADD	%G5	%G5	4
	COPY	*%G5	%G1
	

	JUMPMD	0x0004000	2
	
handler_of_death:	HALT


	.Numeric
bytes_per_word:	4
bytes_per_KB:	1024
words_per_KB:	256
kernel_allocation_in_KB:	1024
kernel_base:	0
kernel_limit:	0
device_table_start:	0x00001000
IB_IP:	0
IB_MISC:	0
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
;;;invalid_device_value_tt_entry:	0
;;; device_failure_tt_entry:	0

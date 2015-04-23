.Code

;;; The entry point.
__start:

;;question. will our processes be able to use functions. I assume so, but how?

;;print a message to the console
    COPY    %G5  10  
    COPY    %G0  *+_print_sysc_code
    COPY    %G1    +_string_start_init_msg

    SYSC

    ; Copy one of the source values into a register.
    COPY	%G0	*x
    ADD	%G1	%G0	*y


    
	;; Halt the processor.
end:	HALT

.Numeric
;; The source values to be added.
x:	5
y:	-3

;;SYSC codes
_exit_sysc_code: 1
_create_sysc_code: 2 
_get_rom_count_sysc_code: 3
_print_sysc_code: 4

.Text
_string_blank_line: "                                                                                "
_string_start_init_msg: "init has started\n"
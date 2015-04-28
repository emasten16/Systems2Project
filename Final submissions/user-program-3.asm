.Code
;;;user-program-3: Print to show that we have started the rom, count down from 10 to 0, throw a divide by zero interrupt
;;; The entry point.
__start:


;;print a message to the console
    COPY    %G0  *+_print_sysc_code
    COPY    %G1    +_string_start_rom3_msg
    SYSC
    
;;Do some stuff   
    COPY    %G5   10 ;%G5 = running sum
_sub_loop_top:
    ;; End the loop when running sum ==0
    BEQ    +_sub_loop_end     %G5  *+_end_of_loop
    DIV     %G5     %G5     0
    SUB    %G5     %G5     1
    JUMP    +_sub_loop_top
    

_sub_loop_end:
    ;;print end message to the console
    COPY    %G0  *+_print_sysc_code
    COPY    %G1    +_string_exit_rom3_msg
    SYSC
    ;;;exit
    COPY    %G0    *+_exit_sysc_code
    SYSC

.Numeric
_end_of_loop: 0

;;SYSC codes
_exit_sysc_code: 1
_create_sysc_code: 2 
_get_rom_count_sysc_code: 3
_print_sysc_code: 4

.Text                                                                             
_string_start_rom3_msg: "User program 3 has started.\n"
_string_exit_rom3_msg: "User program 3 is done.\n"
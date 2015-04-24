.Code
;;;ROM 1. A process that will add some numbers and throw a few interrupts 
;;; The entry point.
__start:


;;print a message to the console
    COPY    %G0  *+_print_sysc_code
    COPY    %G1    +_string_start_rom2_msg
    SYSC
    
;;Do some stuff   
    COPY    %G5   1 ;%G5 = running sum
_add_loop_top:
    ;; End the search when the running sum == 10
    BEQ    +_add_loop_end     %G5  *+_end_of_loop   
    ADD     %G5     %G5     1
    JUMP    +_add_loop_top
    

_add_loop_end:
    ;;print end message to the console
    COPY    %G0  *+_print_sysc_code
    COPY    %G1    +_string_exit_rom2_msg
    SYSC
    ;;;exit
    COPY    %G0    *+_exit_sysc_code
    SYSC

.Numeric
_end_of_loop: 10

;;SYSC codes
_exit_sysc_code: 1
_create_sysc_code: 2 
_get_rom_count_sysc_code: 3
_print_sysc_code: 4

.Text                                                                             
_string_start_rom2_msg: "rom 2 has started\n"
_string_exit_rom2_msg: "rom 2 is done\n"
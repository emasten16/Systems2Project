.Code
;;;User program 2
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
    BGT    +_add_loop_end     %G5  *+_end_of_loop   
    ADD     %G5     %G5     3
    JUMP    +_add_loop_top
     
_add_loop_end:   
    ;;print running message to the console
    COPY    %G0  *+_print_sysc_code
    COPY    %G1    +_string_running_rom2_msg
    SYSC

_sub_loop_top:
    ;; End the search when the running sum == 10
    BLT    +_sub_loop_end     %G5   0 
    SUB     %G5     %G5     3
    JUMP    +_sub_loop_top
     
_sub_loop_end:
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
_string_start_rom2_msg: "User program 2 has started\n"
_string_running_rom2_msg: "User program 2 is runnig\n"
_string_exit_rom2_msg: "User program 2 is done\n"
.Code

;;; The entry point.
__start:

;;question. will our processes be able to use functions. I assume so, but how?

;;print a message to the console
    COPY    %G5  10  ;;JUST A TEST
    COPY    %G0  *+_print_sysc_code
    COPY    %G1    +_string_start_init_msg

    SYSC

;;Get ROM Count
    COPY    %G0     *+_get_rom_count_sysc_code
    SYSC
    COPY    *+_ROM_count  %G0   ;%G0 contains the regiser value for number of ROM files
    
;;Create all processes    
    COPY    %G1   2 ; Begin with process 2, because process 1 is init
create_process_loop_top:
    ;; End the search when we have created all process and our counter 
    BGT    +create_process_loop_end     %G1  *+_ROM_count     
   
    COPY    %G0     *+_create_sysc_code
    COPY    %G1
    SYSC
    ;;process %G1 created, now move on to the next 
    ADD     %G1     %G1     1
    JUMP    +_create_process_loop_top
    
   

create_process_loop_end
    ;;print end message to the console
    COPY    %G0  *+_print_sysc_code
    COPY    %G1    +_string_exit_init_msg
    SYSC
    ;;;exit
    COPY    %G0    *+_exit_sysc_code
    SYSC

.Numeric
;; The source values to be added.
_ROM_count: 0

;;SYSC codes
_exit_sysc_code: 1
_create_sysc_code: 2 
_get_rom_count_sysc_code: 3
_print_sysc_code: 4

.Text                                                                             
_string_start_init_msg: "init has started\n"
_string_exit_init_msg: "init created all processes\n"
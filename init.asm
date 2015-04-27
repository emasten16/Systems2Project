.Code

;;; The entry point.
__start:

;;question. will our processes be able to use functions. I assume so, but how?

;;print a message to the console
    COPY    %G0  *+_print_sysc_code
    COPY    %G1    +_string_start_init_msg
    SYSC

;;Get ROM Count
    COPY    %G5     10
    COPY    %G0     *+_get_rom_count_sysc_code
    SYSC
    COPY    *+_ROM_count  %G0   ;%G0 contains the regiser value for number of ROM files
    
;;Create all processes    
    COPY    %G1   0; Counter for number ROMS created
_create_process_loop_top:
    ADD     %G1     %G1     1
    ;; Do not create the first three ROMS (bios, kernel, and init)
    BLT     +_create_process_loop_top   %G1     4
    ;; End the search when we have created all process and our counter is greater than rom count 
    BGT    +_create_process_loop_end     %G1  *+_ROM_count 
    
    COPY    %G0     *+_create_sysc_code   
    SYSC
    ;;process %G1 created, now move on to the next
    ;;print 'process created' message to the console
    COPY    %G0  *+_print_sysc_code
    COPY    %G1    +_string_process_created_msg
    SYSC
    JUMP    +_create_process_loop_top

_create_process_loop_end:
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
_string_process_created_msg: "init created process\n"
_string_exit_init_msg: "init created all processes\n"
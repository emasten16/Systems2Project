;;; The KERNEL code
;;; Tasks: 1) set up trap table
;;; 2) set TBR to base of TT
;;; 2.5) set interrupt buffer register
;;; 3) load and run one process

.Code

;;; The entry point.                                                                                                                
__start:    
    ;;Set up trap table
    COPY    *+INVALID_ADDRESS   +Dummy_Handler
    COPY    *+INVALID_REGISTER  +Dummy_Handler
    COPY    *+BUS_ERROR     +Dummy_Handler
    COPY    *+CLOCK_ALARM     +Dummy_Handler
    COPY    *+DIVIDE_BY_ZERO     +Dummy_Handler
    COPY    *+OVERFLOW    +Dummy_Handler
    COPY    *+INVALID_INSTRUCTION    +Dummy_Handler
    COPY    *+PERMISSION_VIOLATION     +Dummy_Handler
    COPY    *+INVLID_SHIFT_AMOUNT     +Dummy_Handler
    COPY    *+SYSTEM_CALL     +SYSC_Handler
    COPY    *+INVALID_DEVICE_VALUE    +Dummy_Handler
    COPY    *+DEVICE_FAILURE     +Dummy_Handler

    SETTBR +TT_BASE
    SETIBR +Interrupt_buffer_IP
    
    ;;save address of end of bus (will use for DMA)
    COPY    %G0     *+_static_device_table_base
    ADD     %G0     %G0   *+_incriment_by_two_words ; %G0 refers to address of bus limit in PAS 
    COPY   *+end_of_bus     *%G0 
    ADD     %G0     %G0     *+_incriment_by_one_word ;;%G0 now is at the next device in process table 
 
;;TASK 1: Set up the stack and call main (code from Kaplan's file)
RAM_search_loop_top:
	;; End the search with failure if we've reached the end of the table without finding RAM.
	BEQ		+RAM_search_failure	*%G0		*+_static_none_device_code

	;; If this entry is RAM, then end the loop successfully.
	BEQ		+RAM_found		*%G0		*+_static_RAM_device_code

	;; This entry is not RAM, so advance to the next entry.
	ADDUS		%G0			%G0		*+_skip_process_table_element
	JUMP		+RAM_search_loop_top

RAM_search_failure:

	;; Record a code to indicate the error, and then halt.
	COPY		%G5		*+_static_kernel_error_RAM_not_found
	HALT

RAM_found:
	
	;; RAM has been found.  If it is big enough, create a stack.
	ADDUS		%G1		%G0		*+_incriment_by_one_word; %G1 = &RAM[base]
	COPY		%G1		*%G1 					  ; %G1 = RAM[base]
	ADDUS		%G2		%G0		*+_incriment_by_two_words ; %G2 = &RAM[limit]
	COPY		%G2		*%G2 					  ; %G2 = RAM[limit]
	SUB		%G0		%G2		%G1 			  ; %G0 = |RAM|
	MULUS		%G4		*+_static_min_RAM_KB	 *+_static_bytes_per_KB ; %G4 = |min_RAM|
	BLT		+RAM_too_small	%G0		%G4
	MULUS		%G4		*+_static_kernel_KB_size *+_static_bytes_per_KB ; %G4 = |kmem|
	ADDUS		%SP		%G1		%G4  			  ; %SP = kernel[base] + |kmem| = kernel[limit]
	COPY		%FP		%SP 					  ; Initialize %FP

	;; Copy the RAM and kernel bases and limits to statically allocated spaces.
	COPY		*+_static_RAM_base		%G1
	COPY		*+_static_RAM_limit		%G2
	COPY		*+_static_kernel_base		%G1
	COPY		*+_static_kernel_limit		%SP

	;; With the stack initialized, call main() to begin booting proper.
	SUBUS		%SP		%SP		12		 ; Push pFP / ra / rv
	COPY		*%SP		%FP		  		 ; pFP = %FP
	COPY		%FP		%SP				 ; Update FP.
	ADDUS		%G5		%FP		4		 ; %G5 = &ra
	CALL		+main		*%G5

	;; We should never be here, but wrap it up properly.
	COPY		%FP		*%FP
	ADDUS		%SP		%SP		12               ; Pop pFP / args[0] / ra / rv
	COPY		%G5		*+_static_kernel_error_main_returned
	HALT

RAM_too_small:
	;; Set an error code and halt.
	COPY		%G5		*+_static_kernel_error_small_RAM
	HALT


main:
;Test needs one argument, an INT and adds the value stored in a local variable (l = 3). Then returns the result  
;;; Callee preserved registers:
;;;   [%FP - 4]:  G0
;;;   [%FP - 8]:  G1
;;;   [%FP - 12]: G2
;;;   [%FP - 16]: G4
;;;   [%FP - 20]: G5
;;; Parameters:
;;;   <none>
;;; Caller preserved registers:
;;;   [%FP + 4]: FP
;;; Return address:
;;;   [%FP + 8]
;;; Return value:
;;;  <none>
;;; Locals:
;;;   <none>
;;callee prologue for MAIN method
    COPY    %FP     %SP; Frame Pointer is now set to correct location
    ;;preserve registers
    SUBUS   %SP     %SP     4
    COPY    *%SP    %G0
    SUBUS   %SP     %SP     4
    COPY    *%SP    %G1
     SUBUS   %SP     %SP     4
    COPY    *%SP    %G2
     SUBUS   %SP     %SP     4
    COPY    *%SP    %G3
     SUBUS   %SP     %SP     4
    COPY    *%SP    %G4
    SUBUS   %SP     %SP     4
    COPY    *%SP    %G5
    
;;MAIN METHOD DOES STUFF


;;caller prolog for the print function function:
    SUBUS   %SP     %SP     8; move SP over 2 words because no return value
    COPY    *%SP    %FP; presrve FP in the PFP word
    ADDUS   %G5     %SP     4; %G5 has address for word RA
    SUBUS   %SP     %SP     4; %SP has address of first Argument
    COPY    *%SP    +_string_main_method_msg; the argument that I will pass to the test function
    COPY    %FP     %SP
    CALL   +_procedure_print  *%G5

;;caller epilogue
    ADDUS       %SP     %SP     4       ; Pop arg[0]
    COPY        %FP     *%SP                ; %FP = pfp
    ADDUS       %SP     %SP     8       ; Pop pfp / ra
 
 ;;TASK 2: Find and run init.asm
 
;;caller prolog for the find_device prcedure
    SUBUS       %SP     %SP     12      ; Push pfp / ra / rv
    COPY        *%SP    %FP             ; pFP = %FP
    SUBUS       %SP     %SP     4       ; Push arg[1]
    COPY        *%SP    3               ; Find the 3st device of the given type.
    SUBUS       %SP     %SP     4       ; Push arg[0]
    COPY        *%SP   *+_static_ROM_device_code   ; Find a console device.
    COPY        %FP     %SP             ; Update %FP
    ADDUS       %G5     %SP     12      ; %G5 = &ra
    CALL        +_procedure_find_device     *%G5
    ;;caller epilog
    ADDUS       %SP     %SP     8       ; Pop arg[0,1]
    COPY        %FP     *%SP                ; %FP = pfp
    ADDUS       %SP     %SP     8       ; Pop pfp / ra
    COPY       %G0     *%SP                ; %G0 = &dt[console]= the address of init process in bus
    ADDUS       %SP     %SP     4       ; Pop rv
    
deal_with_init:
;;store the start and end address of this process in PAS and then use DMA to copy and jump to start
    ADD     %G0      %G0    *+_incriment_by_one_word
    COPY    %G2     *%G0    ;%G2 now holds start address of process
    COPY    *+_static_init_mm_base %G2
    ADD     %G0      %G0    *+_incriment_by_one_word
    COPY    %G3     *%G0   ;%G3 has end address of process
    SUB    %G3    %G3   %G2     ;calculate length of process
    ADD     %G4    *+_static_kernel_limit *+_incriment_by_one_word; end of kernel in MM + 1 word = MM start address  

    SUB     %G5     *+end_of_bus   *+_skip_process_table_element ;%G5 now holds the address of the 3rd to last last word in bus
    COPY    *%G5     %G2     ;store the start of process in bus
    ADD     %G5     %G5     *+_incriment_by_one_word
    COPY    *%G5    %G4   ;MM start of process
    ADD     %G5     %G5     *+_incriment_by_one_word
    COPY    *%G5    %G3         ;store length of procsess at end of bus
    
    ;;DMA will move init into MM. Now change MMU registers and store base/limit in process table
    COPY    *+entry0_process_ID  1
    COPY        *+current_process_ID        1
    SETBS   %G4
    COPY    *+entry0_base   %G4  
    ADD     %G1     %G4    %G3      ;%G1 holds the MM limit of our process
    SETLM   %G1
    COPY     *+entry0_limit  %G1
    JUMPMD   0   6;jump to start of process in MM (use virtual addressing!!!!)



    ;;Callee epilogue for MAIN restore registers
    COPY    %G5     *%SP
    ADDUS   %SP     %SP     4
    COPY    %G4     *%SP
    ADDUS   %SP     %SP     4
    COPY    %G3     *%SP
    ADDUS   %SP     %SP     4
    COPY    %G2     *%SP
    ADDUS   %SP     %SP     4
    COPY    %G1     *%SP
    ADDUS   %SP     %SP     4
    COPY    %G0    *%SP
    COPY    %SP     %FP    ;pop callee subframe. SP points to PFP
    ADDUS   %FP     %SP     4; now FP points to RA (as it did before function called)
    JUMP    *%FP; return to caller function 
;;WILL BE THE END OF MAIN ()

Dummy_Handler:
    HALT

SYSC_Handler:
;;; %G0 holds 1 if EXIT, 2 if CREATE, 3 if GET_ROM_COUNT, 4 if PRINT
;;caller prolog for the pause process loop to preserve registers
    SUBUS       %SP     %SP     8      ; Push pfp / ra 
    COPY        *%SP    %FP             ; pFP = %FP
    ADDUS       %FP     %SP     4       ;%FP has address for RA
    CALL        +_pause_process    *%FP
;;caller epilogue
    COPY    %FP     *%SP
    ADDUS   %SP     %SP     4; pop the RA
    
   ;;;BEQ     +EXIT_Handler   %G0     *+_exit_sysc_code
    ;;;BEQ     +CREATE_Handler  %G0     *+_create_sysc_code
    BEQ     +GET_ROM_COUNT_Handler   %G0     *+_get_rom_count_sysc_code
    BEQ     +PRINT_Handler          %G0     *+_print_sysc_code

EXIT_Handler:
;;return process memory to free space
;;search process table for process ID,  make it 0
;;schedule a new process

GET_ROM_COUNT_Handler:
    ;;return the number of ROMs available in the system not including the bios and kernel
    ;;only ever needed by init
    ;;jump back to where you were
    ;;;quickly preserve registers so we can do this function
    COPY   %G0   *+_static_device_table_base
    ;;;skip the beginning so we don't count bios or kernel
    ADDUS  %G0   %G0    24
    COPY   %G1   0 ; %G1 = counter for number of ROM files we have seen
    rom_count_loop_top:
        ;; End the search with failure if we've reached the end of the table without finding RAM.
        BEQ	+rom_count_done	*%G0	*+_static_none_device_code
    
        ;; If this entry is ROM, then end the loop successfully.
        BEQ	+ROM_found	*%G0	*+_static_ROM_device_code
    
        ;; This entry is not RAM, so advance to the next entry.
        ADDUS	%G0	%G0	*+_skip_process_table_element
        JUMP	+rom_count_loop_top
    
    ROM_found:
        ADDUS   %G1     %G1     1
        ADDUS	%G0	%G0     *+_skip_process_table_element
        JUMP   +rom_count_loop_top 
    
    rom_count_done:
        COPY    *+entry0_G0     %G1     ;Store the count of ROM in %G0 for init 
        JUMP    +_run_process_continue

PRINT_Handler:
    ;;caller prolog for the print function function:
    SUBUS   %SP     %SP     8; move SP over 2 words because no return value
    COPY    *%SP    %FP; presrve FP in the PFP word
    ADDUS   %G5     %SP     4; %G5 has address for word RA
    SUBUS   %SP     %SP     4; %SP has address of first Argument
    ;;G1 is the relative address from 0 in process (when in user mode)
    ADD    %G1      *+_static_init_mm_base  %G1
    COPY    *%SP    %G1; the argument that I will pass to the print. When the SYSC happens, user stores 4 in G0 to call a print sysc and a pointer to the string in G1
    COPY    %FP     %SP
    CALL   +_procedure_print  *%G5
    ;;caller epilogue
    ADDUS       %SP     %SP     4       ; Pop arg[0]
    COPY        %FP     *%SP                ; %FP = pfp
    ADDUS       %SP     %SP     8       ; Pop pfp / ra

    ;;after printing, we want to jump back into the process we were in when print was called
   JUMP  +_run_process_continue
 
;; Pause process INFO
;;; Callee preserved registers:
;;;   [%FP - 8]:  G0
;;;   [%FP - 12]:  G1
;;;   [%FP - 16]: G2
;;;   [%FP - 20]: G4
;;;   [%FP - 24]: G5
;;; Parameters:
;;;  <none>
;;; Caller preserved registers:
;;;   [%FP + 0]: FP
;;; Return address:
;;;   [%FP + 4]
;;; Return value:
;;;     <none>
;;; Locals:
;;;    <none>
_pause_process:
;;callee prologue
    COPY    %FP     %SP; Frame Pointer is now set to correct location
    ;;preserve registers
    SUBUS   %SP     %SP     4
    COPY    *%SP    %G0
    SUBUS   %SP     %SP     4
    COPY    *%SP    %G1
     SUBUS   %SP     %SP     4
    COPY    *%SP    %G2
     SUBUS   %SP     %SP     4
    COPY    *%SP    %G3
     SUBUS   %SP     %SP     4
    COPY    *%SP    %G4
    SUBUS   %SP     %SP     4
    COPY    *%SP    %G5
    
;;do stuff
    COPY    *+G0_temp  %G0
    ;; loops through process table to find current process
    COPY    %G0    +process_table
 pause_proc_looptop:
     BEQ     +found_proc_preserve    *%G0    *+current_process_ID
     ADDUS   %G0    %G0    48
     JUMP    +pause_proc_looptop
 found_proc_preserve:
     ADDUS   %G0    %G0    12
     COPY    *%G0   *+Interrupt_buffer_IP   ;;; IP
     ADDUS   %G0    %G0    4
     COPY    *%G0   *+G0_temp
     ADDUS   %G0    %G0    4
     COPY    *%G0   %G1
     ADDUS   %G0    %G0    4
     COPY    *%G0   %G2
     ADDUS   %G0    %G0    4
     COPY    *%G0   %G3
     ADDUS   %G0    %G0    4
     COPY    *%G0   %G4
     ADDUS   %G0    %G0    4
     COPY    *%G0   %G5
     ADDUS   %G0    %G0    4
     COPY    *%G0   %SP
     ADDUS   %G0    %G0    4
     COPY    *%G0   %FP

;;callee epilogue
    ;;restore registers
    COPY    %G5     *%SP
    ADDUS   %SP     %SP     4
    COPY    %G4     *%SP
    ADDUS   %SP     %SP     4
    COPY    %G3     *%SP
    ADDUS   %SP     %SP     4
    COPY    %G2     *%SP
    ADDUS   %SP     %SP     4
    COPY    %G1     *%SP
    ADDUS   %SP     %SP     4
    COPY    %G0    *%SP;
    COPY    %SP     %FP;    pop callee subframe. SP points to  PFP
    ADDUS   %FP     %SP     4; now FP points to RA (as it did before function called)
    JUMP    *%FP; return to caller function 
 
   
_run_process_continue:
    ;; go back into process that has already been created
    ;; current process is already in current_process_ID
    ;; restore registers, jumps into IP, changes mode and virtual addressing, kernel indicator, set base &limit registers
    ;; loop through process table
        COPY    %G0    +process_table
    schedule_proc_looptop_continue:
        BEQ     +found_current_proc_continue  *%G0   *+current_process_ID ; branches if process is found
        ADDUS   %G0    %G0    48  ; go to next spot in
        JUMP    +schedule_proc_looptop_continue
    found_current_proc_continue:
        ADDUS   %G0    %G0    4
        SETBS   *%G0
        ADDUS   %G0    %G0    4
        SETLM   *%G0
        ADDUS   %G0    %G0    4
        ADD     *+IP_temp      *%G0      16 ;;move on to the next word when you return to the process
        ADDUS   %G0    %G0    4
        COPY    *+G0_temp    *%G0
        ADDUS   %G0    %G0    4
        COPY    %G1    *%G0
        ADDUS   %G0    %G0    4
        COPY    %G2    *%G0
        ADDUS   %G0    %G0    4
        COPY    %G3    *%G0
        ADDUS   %G0    %G0    4
        COPY    %G4    *%G0
        ADDUS   %G0    %G0    4
        COPY    %G5    *%G0
        ;; kernel indicator
        COPY    *+kernel_indicator   0 ;; 0 means we're in process
        JUMPMD  *+IP_temp   6
;;************************************************************************************************

_run_process_re_do:
    ;; go back into process that has already been created
    ;; current process is already in current_process_ID
    ;; restore registers, jumps into IP, changes mode and virtual addressing, kernel indicator, set base &limit registers
    ;; loop through process table
        COPY    %G0    +process_table
    schedule_proc_looptop_run:
        BEQ     +found_current_proc_run  *%G0   *+current_process_ID ; branches if process is found
        ADDUS   %G0    %G0    48  ; go to next spot in
        JUMP    +schedule_proc_looptop_run
    found_current_proc_run:
        ADDUS   %G0    %G0    4
        SETBS   *%G0
        ADDUS   %G0    %G0    4
        SETLM   *%G0
        ADDUS   %G0    %G0    4
        COPY    *+IP_temp    *%G0  ;; IP
        ADDUS   %G0    %G0    4
        COPY    *+G0_temp    *%G0
        ADDUS   %G0    %G0    4
        COPY    %G1    *%G0
        ADDUS   %G0    %G0    4
        COPY    %G2    *%G0
        ADDUS   %G0    %G0    4
        COPY    %G3    *%G0
        ADDUS   %G0    %G0    4
        COPY    %G4    *%G0
        ADDUS   %G0    %G0    4
        COPY    %G5    *%G0
        ;; kernel indicator
        COPY    *+kernel_indicator   0 ;; 0 means we're in process
        JUMPMD  0   6

;;; ================================================================================================================================
;;; Procedure: print
;;; Callee preserved registers:
;;;   [%FP - 4]: G0
;;;   [%FP - 8]: G3
;;;   [%FP - 12]: G4
;;; Parameters:
;;;   [%FP + 0]: A pointer to the beginning of a null-terminated string.
;;; Caller preserved registers:
;;;   [%FP + 4]: FP
;;; Return address:
;;;   [%FP + 8]
;;; Return value:
;;;   <none>
;;; Locals:
;;;   %G0: Pointer to the current position in the string.
    
_procedure_print:

    ;; Prologue: Push preserved registers.
    SUBUS       %SP     %SP     4
    COPY        *%SP        %G0
    SUBUS       %SP     %SP     4
    COPY        *%SP        %G3
    SUBUS       %SP     %SP     4
    COPY        *%SP        %G4

    COPY    %G5     100 ;test that we made it 
    ;; If not yet initialized, set the console base/limit statics.
    BNEQ        +print_init_loop    *+_static_console_base      0
    
    ;;caller prolog for the find_device prcedure
    SUBUS       %SP     %SP     12      ; Push pfp / ra / rv
    COPY        *%SP    %FP             ; pFP = %FP
    SUBUS       %SP     %SP     4       ; Push arg[1]
    COPY        *%SP    1               ; Find the 1st device of the given type.
    SUBUS       %SP     %SP     4       ; Push arg[0]
    COPY        *%SP   *+_static_console_device_code   ; Find a console device.
    COPY        %FP     %SP             ; Update %FP
    ADDUS       %G5     %SP     12      ; %G5 = &ra
    CALL        +_procedure_find_device     *%G5
    ;;caller epilog
    ADDUS       %SP     %SP     8       ; Pop arg[0,1]
    COPY        %FP     *%SP                ; %FP = pfp
    ADDUS       %SP     %SP     8       ; Pop pfp / ra
    COPY       %G4     *%SP                ; %G4 = &dt[console]
    ADDUS       %SP     %SP     4       ; Pop rv

    ;; Panic if the console was not found.
    BNEQ        +print_found_console    %G4     0
    COPY        %G5     *+_static_kernel_error_console_not_found
    HALT
    
print_found_console:    
    ADDUS       %G3     %G4     *+_static_dt_base_offset  ; %G3 = &console[base]
    COPY        *+_static_console_base      *%G3              ; Store static console[base]
    ADDUS       %G3     %G4     *+_static_dt_limit_offset ; %G3 = &console[limit]
    COPY        *+_static_console_limit     *%G3              ; Store static console[limit]
    
print_init_loop:    

    ;; Loop through the characters of the given string until the null character is found.
    COPY        %G0     *%FP                ; %G0 = str_ptr
print_loop_top:
    COPYB       %G4     *%G0                ; %G4 = current_char

    ;; The loop should end if this is a null character
    BEQ     +print_loop_end %G4     0

    ;; Scroll without copying the character if this is a newline.
    COPY        %G3     *+_static_newline_char      ; %G3 = <newline>
    BEQ     +print_scroll_call  %G4 %G3

    ;; Assume that the cursor is in a valid location.  Copy the current character into it.
    ;; The cursor position c maps to buffer location: console[limit] - width + c
    SUBUS       %G3     *+_static_console_limit *+_static_console_width    ; %G3 = console[limit] - width
    ADDUS       %G3     %G3     *+_static_cursor_column        ; %G3 = console[limit] - width + c
    COPYB       *%G3        %G4                        ; &(height - 1, c) = current_char
    
    ;; Advance the cursor, scrolling if necessary.
    ADD     *+_static_cursor_column *+_static_cursor_column     1   ; c = c + 1
    BLT     +print_scroll_end   *+_static_cursor_column *+_static_console_width ; Skip scrolling if c < width
    ;; Fall through...
    
print_scroll_call:  
    SUBUS       %SP     %SP     8               ; Push pfp / ra
    COPY        *%SP        %FP                     ; pfp = %FP
    COPY        %FP     %SP                     ; %FP = %SP
    ADDUS       %G5     %FP     4               ; %G5 = &ra
    CALL        +_procedure_scroll_console  *%G5
    COPY        %FP     *%SP                        ; %FP = pfp
    ADDUS       %SP     %SP     8               ; Pop pfp / ra

print_scroll_end:
    ;; Place the cursor character in its new position.
    SUBUS       %G3     *+_static_console_limit     *+_static_console_width ; %G3 = console[limit] - width
    ADDUS       %G3     %G3     *+_static_cursor_column         ; %G3 = console[limit] - width + c  
    COPY        %G4     *+_static_cursor_char                       ; %G4 = <cursor>
    COPYB       *%G3        %G4                         ; console@cursor = <cursor>
    
    ;; Iterate by advancing to the next character in the string.
    ADDUS       %G0     %G0     1
    JUMP        +print_loop_top

print_loop_end:
    ;; Epilogue: Pop and restore preserved registers, then return.
    COPY        %G4     *%SP
    ADDUS       %SP     %SP     4
    COPY        %G3     *%SP
    ADDUS       %SP     %SP     4
    COPY        %G0     *%SP
    ADDUS       %SP     %SP     4
    ADDUS       %G5     %FP     8       ; %G5 = &ra
    JUMP        *%G5

;;; Procedure: scroll_console
;;; Description: Scroll the console and reset the cursor at the 0th column.
;;; Callee reserved registers:
;;;   [%FP - 4]:  G0
;;;   [%FP - 8]:  G1
;;;   [%FP - 12]: G4
;;; Parameters:
;;;   <none>
;;; Caller preserved registers:
;;;   [%FP + 0]:  FP
;;; Return address:
;;;   [%FP + 4]
;;; Return value:
;;;   <none>
;;; Locals:
;;;   %G0:  The current destination address.
;;;   %G1:  The current source address.

_procedure_scroll_console:

    ;; Prologue: Push preserved registers.
    SUBUS       %SP     %SP     4
    COPY        *%SP        %G0
    SUBUS       %SP     %SP     4
    COPY        *%SP        %G1
    SUBUS       %SP     %SP     4
    COPY        *%SP        %G4

    ;; Initialize locals.
    COPY        %G0     *+_static_console_base             ; %G0 = console[base]
    ADDUS       %G1     %G0     *+_static_console_width    ; %G1 = console[base] + width

    ;; Clear the cursor.
    SUBUS       %G4     *+_static_console_limit     *+_static_console_width ; %G4 = console[limit] - width
    ADDUS       %G4     %G4     *+_static_cursor_column         ; %G4 = console[limit] - width + c
    COPYB       *%G4        *+_static_space_char                    ; Clear cursor.

    ;; Copy from the source to the destination.
    ;;   %G3 = DMA portal
    ;;   %G4 = DMA transfer length
    ADDUS       %G3     8       *+_static_device_table_base ; %G3 = &controller[limit]
    SUBUS       %G3     *%G3        12                          ; %G3 = controller[limit] - 3*|word| = &DMA_portal
    SUBUS       %G4     *+_static_console_limit %G0             ; %G4 = console[base] - console[limit] = |console|
    SUBUS       %G4     %G4     *+_static_console_width     ; %G4 = |console| - width

    ;; Copy the source, destination, and length into the portal.  The last step triggers the DMA copy.
    COPY        *%G3        %G1                     ; DMA[source] = console[base] + width
    ADDUS       %G3     %G3     4           ; %G3 = &DMA[destination]
    COPY        *%G3        %G0                     ; DMA[destination] = console[base]
    ADDUS       %G3     %G3     4           ; %G3 = &DMA[length]
    COPY        *%G3        %G4                     ; DMA[length] = |console| - width; DMA trigger

    ;; Perform a DMA transfer to blank the last line with spaces.
    SUBUS       %G3     %G3     8           ; %G3 = &DMA_portal
    COPY        *%G3        +_string_blank_line         ; DMA[source] = &blank_line
    ADDUS       %G3     %G3     4           ; %G3 = &DMA[destination]
    SUBUS       *%G3        *+_static_console_limit *+_static_console_width ; DMA[destination] = console[limit] - width
    ADDUS       %G3     %G3     4           ; %G3 = &DMA[length]
    COPY        *%G3        *+_static_console_width         ; DMA[length] = width; DMA trigger
    
    ;; Reset the cursor position.
    COPY        *+_static_cursor_column     0                           ; c = 0
    SUBUS       %G4     *+_static_console_limit     *+_static_console_width ; %G4 = console[limit] - width
    COPYB       *%G4        *+_static_cursor_char                   ; Set cursor.
    
    ;; Epilogue: Pop and restore preserved registers, then return.
    COPY        %G4     *%SP
    ADDUS       %SP     %SP     4
    COPY        %G1     *%SP
    ADDUS       %SP     %SP     4
    COPY        %G0     *%SP
    ADDUS       %SP     %SP     4
    ADDUS       %G5     %FP     4       ; %G5 = &ra
    JUMP        *%G5
;;; ================================================================================================================================
 ;;; ================================================================================================================================   
;;; Procedure: find_device
;;; Callee preserved registers:
;;;   [%FP - 4]:  G0
;;;   [%FP - 8]:  G1
;;;   [%FP - 12]: G2
;;;   [%FP - 16]: G4
;;; Parameters:
;;;   [%FP + 0]: The device type to find.
;;;   [%FP + 4]: The instance of the given device type to find (e.g., the 3rd ROM).
;;; Caller preserved registers:
;;;   [%FP + 8]:  FP
;;; Return address:
;;;   [%FP + 12]
;;; Return value:
;;;   [%FP + 16]: If found, a pointer to the correct device table entry; otherwise, null.
;;; Locals:
;;;   %G0: The device type to find (taken from parameter for convenience).
;;;   %G1: The instance of the given device type to find. (from parameter).
;;;   %G2: The current pointer into the device table.

_procedure_find_device:

    ;; Prologue: Preserve the registers used on the stack.
    SUBUS       %SP     %SP     4
    COPY        *%SP    %G0
    SUBUS       %SP     %SP     4
    COPY        *%SP    %G1
    SUBUS       %SP     %SP     4
    COPY        *%SP    %G2
    SUBUS       %SP     %SP     4
    COPY        *%SP    %G4
    
    ;; Initialize the locals.
    COPY        %G0     *%FP
    ADDUS       %G1     %FP     4
    COPY        %G1     *%G1
    COPY        %G2     *+_static_device_table_base
    
find_device_loop_top:

    ;; End the search with failure if we've reached the end of the table without finding the device.
    BEQ     +find_device_loop_failure   *%G2        *+_static_none_device_code

    ;; If this entry matches the device type we seek, then decrement the instance count.  If the instance count hits zero, then
    ;; the search ends successfully.
    BNEQ        +find_device_continue_loop  *%G2        %G0
    SUB     %G1             %G1     1
    BEQ     +find_device_loop_success   %G1     0
    
find_device_continue_loop:  

    ;; Advance to the next entry.
    ADDUS       %G2         %G2     *+_static_dt_entry_size
    JUMP        +find_device_loop_top

find_device_loop_failure:

    ;; Set the return value to a null pointer.
    ADDUS       %G4         %FP     16  ; %G4 = &rv
    COPY        *%G4            0           ; rv = null
    JUMP        +find_device_return

find_device_loop_success:

    ;; Set the return pointer into the device table that currently points to the given iteration of the given type.
    ADDUS       %G4         %FP     16  ; %G4 = &rv
    COPY        *%G4        %G2         ; rv = &dt[<device>]
    ;; Fall through...
    
find_device_return:

    ;; Epilogue: Restore preserved registers, then return.
    COPY        %G4     *%SP
    ADDUS       %SP     %SP     4
    COPY        %G2     *%SP
    ADDUS       %SP     %SP     4
    COPY        %G1     *%SP
    ADDUS       %SP     %SP     4
    COPY        %G0     *%SP
    ADDUS       %SP     %SP     4
    ADDUS       %G5     %FP     12  ; %G5 = &ra
    JUMP        *%G5
;;; ================================================================================================================================
   
    
.Numeric
end_of_bus: 0
	;; Device table location and codes.
_static_device_table_base:	0x00001000
_incriment_by_one_word:       0x00000004
_incriment_by_two_words:   0x00000008
_skip_process_table_element:       0x0000000c
_static_dt_entry_size:      12
_static_dt_base_offset:     4
_static_dt_limit_offset:    8
_static_none_device_code:	0
_static_controller_device_code:	1
_static_ROM_device_code:	2
_static_RAM_device_code:	3
_static_console_device_code:	4

    ;; Other constants.
_static_min_RAM_KB:		64
_static_bytes_per_KB:		1024
_static_bytes_per_page:		4096	; 4 KB/page
_static_kernel_KB_size:		32	; KB taken by the kernel  

;; Constants for printing and console management.
_static_console_width:      80
_static_console_height:     24
_static_space_char:     0x20202020 ; Four copies for faster scrolling.  If used with COPYB, only the low byte is used.
_static_cursor_char:        0x5f
_static_newline_char:       0x0a

	;; Error codes.
_static_kernel_error_RAM_not_found:	0xffff0001
_static_kernel_error_main_returned:	0xffff0002
_static_kernel_error_small_RAM:		0xffff0003	
_static_kernel_error_console_not_found:	0xffff0004

	;; Statically allocated variables.
_static_cursor_column:		0	; The column position of the cursor (always on the last row).
_static_RAM_base:		0
_static_RAM_limit:		0
_static_console_base:		0
_static_console_limit:		0
_static_kernel_base:		0
_static_kernel_limit:		0

_static_init_mm_base: 0
;;SYSC codes
_exit_sysc_code: 1
_create_sysc_code: 2 
_get_rom_count_sysc_code: 3
_print_sysc_code: 4

;Trap Table
TT_BASE:
INVALID_ADDRESS: 0
INVALID_REGISTER: 0
BUS_ERROR: 0
CLOCK_ALARM: 0
DIVIDE_BY_ZERO: 0
OVERFLOW: 0
INVALID_INSTRUCTION: 0
PERMISSION_VIOLATION: 0
INVLID_SHIFT_AMOUNT: 0
SYSTEM_CALL: 0
INVALID_DEVICE_VALUE: 0
DEVICE_FAILURE: 0

;Interrupt buffer register
Interrupt_buffer_IP: 0
INterrupt_buffer_MISC: 0

IP_temp: 0
G5_temp: 0
G0_temp: 0
kernel_indicator: 0
current_process_ID: 0

;;;PROCESS TABLE - room for five processes
process_table:
entry0_process_ID:  0
entry0_base:    0
entry0_limit:   0
entry0_IP:  0
entry0_G0:  0
entry0_G1:  0
entry0_G2:  0
entry0_G3:  0
entry0_G4:  0
entry0_G5:  0
entry0_SP:  0
entry0_FP:  0
entry1_process_ID:  0
entry1_base:    0
entry1_limit:   0
entry1_IP:  0
entry1_G0:  0
entry1_G1:  0
entry1_G2:  0
entry1_G3:  0
entry1_G4:  0
entry1_G5:  0
entry1_SP:  0
entry1_FP:  0
entry2_process_ID:  0
entry2_base:    0
entry2_limit:   0
entry2_IP:  0
entry2_G0:  0
entry2_G1:  0
entry2_G2:  0
entry2_G3:  0
entry2_G4:  0
entry2_G5:  0
entry2_SP:  0
entry2_FP:  0
entry3_process_ID:  0
entry3_base:    0
entry3_limit:   0
entry3_IP:  0
entry3_G0:  0
entry3_G1:  0
entry3_G2:  0
entry3_G3:  0
entry3_G4:  0
entry3_G5:  0
entry3_SP:  0
entry3_FP:  0
entry4_process_ID:  0
entry4_base:    0
entry4_limit:   0
entry4_IP:  0
entry4_G0:  0
entry4_G1:  0
entry4_G2:  0
entry4_G3:  0
entry4_G4:  0
entry4_G5:  0
entry4_SP:  0
entry4_FP:  0
entry5_process_ID:  0
entry5_base:    0
entry5_limit:   0
entry5_IP:  0
entry5_G0:  0
entry5_G1:  0
entry5_G2:  0
entry5_G3:  0
entry5_G4:  0
entry5_G5:  0
entry5_SP:  0
entry5_FP:  0
end_of_process_table:   27
;;;this is so that we can check to see if we have reached the end of the process table and it is full

.Text
_string_blank_line: "                                                                                "
_string_test_msg: "test message\n"
_string_done_msg:	"done.\n"
_string_main_method_msg: "Main method has started.\n"

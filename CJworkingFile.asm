;;; The KERNEL code
;;; Tasks: 1) set up trap table
;;; 2) set TBR to base of TT
;;; 2.5) set interrupt buffer register
;;; 3) load and run one process

.Code

;;; The entry point.                                                                                                                
__start:    
    ;;Set up trap table
    COPY    *+SYSTEM_CALL     +SYSC_Handler
    COPY    *+INVALID_ADDRESS   +INVALID_ADDRESS_Handler
    COPY    *+INVALID_REGISTER  +INVALID_REGISTER_Handler
    COPY    *+BUS_ERROR     +BUS_ERROR_Handler
    COPY    *+DIVIDE_BY_ZERO     +DIVIDE_BY_ZERO_Handler
    COPY    *+OVERFLOW    +OVERFLOW_Handler
    COPY    *+INVALID_INSTRUCTION   +INVALID_INSTRUCTION_Handler
    COPY    *+PERMISSION_VIOLATION  +PERMISSION_VIOLATION_Handler
    COPY    *+INVLID_SHIFT_AMOUNT   +INVALID_SHIFT_AMOUNT_Handler
    COPY    *+INVALID_DEVICE_VALUE  +INVALID_DEVICE_VALUE_Handler
    COPY    *+DEVICE_FAILURE     +DEVICE_FAILURE_Handler
    COPY    *+CLOCK_ALARM     +CLOCK_ALARM_Handler

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
 
 JUMP  +INVALID_ADDRESS_Handler



;;call a test function
;;caller prolog for a test function:
    SUBUS   %SP     %SP     12; move SP over 3 words
    COPY    *%SP    %FP; presrve FP in the PFP word
    ADDUS   %FP     %SP     4; %FP has address for word RA
    SUBUS   %SP     %SP     4; %SP has address of first Argument
    COPY    *%SP    3; 3 =  the argument that I will pass to the test function
    CALL   +function_test  *%FP

;;caller epilogue
    ADDUS   %SP     %SP     4; pop the arguments. %SP now points to PFP
    COPY    %FP     *%SP
    ADDUS   %SP     %SP     8; %SP now points to the return value
    
    COPY    %G5     *%SP; %G5 has the value that was returned from test function

   COPY     %G1     0 ;let %G1 be the counter for how many rom type devices have been seen
   ;;TASK 2: Find and run init.asm
start_loop: BEQ    +rom_type_device         *%G0       *+_static_ROM_device_code
    ADD     %G0    %G0  *+_skip_process_table_element
    JUMP    +start_loop

rom_type_device:
    ;; add one to the count of total rom type devices seen
    ADD     %G1     %G1     1
    BEQ    +deal_with_process1 %G1 3; branch if this is third ROM Device (1= bios, 2 = kernel, 3 = init)
    ADD     %G0    %G0  *+_skip_process_table_element
    JUMP     +start_loop          
    
deal_with_process1:
   ;;make a process table!!!!
;;store the start and end address of this process in PAS and then use DMA to copy and jump to start
    ADD     %G0      %G0    *+_incriment_by_one_word
    COPY    %G2     *%G0    ;%G2 now holds start address of process 
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
        
    JUMPMD    %G4   2;jump to start of process in MM

;;MAIN IS DONE DOING STUFF

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
    COPY    %SP     %FP;    pop callee subframe. SP points to PFP
    ADDUS   %FP     %SP     4; now FP points to RA (as it did before function called)
    JUMP    *%FP; return to caller function 
;;WILL BE THE END OF MAIN ()

;Test needs one argument, an INT and adds the value stored in a local variable (l = 3). Then returns the result  
;;; Callee preserved registers:
;;;   [%FP - 8]:  G0
;;;   [%FP - 12]:  G1
;;;   [%FP - 16]: G2
;;;   [%FP - 20]: G4
;;;   [%FP - 24]: G5
;;; Parameters:
;;;   [%FP + 0]: the int that will be added
;;; Caller preserved registers:
;;;   [%FP + 4]: FP
;;; Return address:
;;;   [%FP + 8]
;;; Return value:
;;;   [%FP + 12]: The sum of 2 ints
;;; Locals:
;;;     [%FP - 4]: the variable that will be added to the argument
function_test:
;;callee prologue
    COPY    %FP     %SP; Frame Pointer is now set to correct location
    ;store space for local variables
    SUBUS   %SP     %SP     4; %SP now holds address of variable, l
    COPY    *%SP    3; l=3
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
    
    ;;function does stuff
    COPY    %G0     *%FP; register %G0 now has the value of argument passed to our test function
    ADD     %G0     %G0     3;
    
;;callee epilogue
    ADD     %G1     %FP     12;%G1 now holds the address of the RV
    COPY    *%G1     %G0;   Store the retun value at RV
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
    COPY    %SP     %FP;    pop callee subframe. SP points to first argument
    ADDUS   %FP     %SP     8; now FP points to RA (as it did before function called)
    JUMP    *%FP; return to caller function
    

SYSC_Handler:
;;; %G0 holds 1 if EXIT, 2 if CREATE, 3 if GET_ROM_COUNT, 4 if PRINT
;; checks to see if interrupt was in kernel
    BEQ     +MEGA_HALT    *+kernel_indicator    1
    COPY    *+kernel_indicator    1
    ;;;first put all the preserve all the process info in the process table
       COPY    *+G0_temp  %G0
   ;; loops through process table to find current process
   COPY    %G0    +process_table
   pause_proc_looptop_cj:
       BEQ     +found_proc_preserve_cj    *%G0    *+current_process_ID
       ADDUS   %G0    %G0    48
       JUMP    +pause_proc_looptop_cj
found_proc_preserve_cj:
       ADDUS   %G0    %G0    8
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
    ;;;then branch to relevant handler based on codes above
    BEQ     +EXIT_Handler   %G0     0
    BEQ     +CREATE_Handler  %G0     1
    BEQ     +GET_ROM_COUNT_Handler   %G0     2
    BEQ     +PRINT_Handler          %G0     4
    ;;;if we get to here something is wrong

    ;;caller prolog for the print function function:
    SUBUS   %SP     %SP     8; move SP over 2 words because no return value
    COPY    *%SP    %FP; presrve FP in the PFP word
    ADDUS   %G5     %SP     4; %G5 has address for word RA
    SUBUS   %SP     %SP     4; %SP has address of first Argument
    COPY    *%SP    +_string_sysc_call_code; the argument that I will pass to the test function
    COPY    %FP     %SP
    CALL   +_procedure_print  *%G5

    ;;caller epilogue
    ADDUS       %SP     %SP     4       ; Pop arg[0]
    COPY        %FP     *%SP                ; %FP = pfp
    ADDUS       %SP     %SP     8       ; Pop pfp / ra
    JUMP +MEGA_HALT

CREATE_Handler:
;;;create a new process
;;;%g1 holds the ROM# of the process we want to create

;;;search through the process table and find an empty process
    COPY    %G2      0
;;;G4 is a counter so we know what to make the process ID    
    COPY    %G4      1
    COPY    %G3      +process_table
    ADDUS     %G3      %G3      4
    ;;;we use addus here instead of add right?
create_process_table_looptop:
    BEQ     +found_empty_process    %G3      %G2
    ADDUS   %G3    %G3   48
    BEQ     +no_room_in_process_table    *%G3    16
    ADDUS   %G4    %G4    1
    JUMP    +create_process_table_looptop

found_empty_process: 
;;;assign process ID
    COPY    *%G3    %G4
;;;put base and limit
;;;at this point, G3 is pointing to the process ID and G1 is telling us the rom number
    COPY    %G0    *+_static_device_table_base
    ;;;G2 holds the ROM code which is 2, G4 holds our counter (we want this to equal g1)
    COPY    %G2     *+_static_ROM_device_code
    COPY    %G4     0
found_empty_process_looptop:
    BNEQ     +create_not_a_rom    *%G0   %G2
    ADDUS    %G4    %G4   1
    BEQ      +create_yes_a_rom     %G4    %G1
    ;;if not the right rom, continue into the next insturctions to jump to the next thing in the bus    
   
create_not_a_rom:
;;jump to next item in bus if not a rom
    ADDUS   %G0    %G0    12
    JUMP    +found_empty_process_looptop

create_yes_a_rom:
    ;;;g3 is still pointing at the process ID, g0 is pointing at the bus table entry for this rom
    ;;;add base to process table
    ADDUS   %G0    %G0    4
    ADDUS   %G3    %G3    4
    COPY    *%G3   *%G0
    ;;;add limit to process table
    ADDUS   %G0    %G0    4
    ADDUS   %G3    %G3    4
    COPY    *%G3   *%G0

;;;set everything else to 0    
    ADDUS  %G0   %G0   4
    COPY   *%G0   0
    ADDUS  %G0   %G0   4
    COPY   *%G0   0
    ADDUS  %G0   %G0   4
    COPY   *%G0   0
    ADDUS  %G0   %G0   4
    COPY   *%G0   0
    ADDUS  %G0   %G0   4
    COPY   *%G0   0
    ADDUS  %G0   %G0   4
    COPY   *%G0   0
    ADDUS  %G0   %G0   4
    COPY   *%G0   0
    ADDUS  %G0   %G0   4
    COPY   *%G0   0
    ADDUS  %G0   %G0   4
    COPY   *%G0   0

;;;it is in the process table, now go back to running the process we were in!
    JUMP _run_process   

no_room_in_process_table:
;;;process table is full
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_process_table_full_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
    JUMP   +MEGA_HALT

EXIT_Handler:
;;return process memory to free space
;;search process table for process ID,  make it 0
;;schedule a new process
;;;return process memory to free space
;;;search process table for process ID,  make it 0
;;====
;;temp testing
;; prints string stored in _string_divide_by_zero_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_in_exit_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA

;;===


    COPY   %G1   *+entry0_process_ID
_exit_handler_looptop:
    BEQ   +_exit_handler_found  %G1  *+current_process_ID
    BEQ   +_process_not_found_error   %G1  27 ;;27 is stored at the end of the process table to tell us it is at its end
    ADDUS  %G1   %G1   48
    JUMP   +_exit_handler_looptop

_process_not_found_error:
;;process not found in the process table..something is wrong. Print the issue and HALT
    COPY  *+G5_temp  %G5 ;;because we use G5 in print
    ;;caller prolog for the print function function:
    SUBUS   %SP     %SP     8; move SP over 2 words because no return value
    COPY    *%SP    %FP; presrve FP in the PFP word
    ADDUS   %G5     %SP     4; %G5 has address for word RA
    SUBUS   %SP     %SP     4; %SP has address of first Argument
    COPY    *%SP    +_process_not_found_msg; the argument that I will pass to the test function
    COPY    %FP     %SP
    CALL   +_procedure_print  *%G5

;;caller epilogue
    ADDUS       %SP     %SP     4       ; Pop arg[0]
    COPY        %FP     *%SP                ; %FP = pfp
    ADDUS       %SP     %SP     8       ; Pop pfp / ra
    COPY  %G5   *+G5_temp  ;;restoringbecause we use G5 in print
    JUMP   +MEGA_HALT

_exit_handler_found:
    ;;;put a 0 in that space in the process table to free it up and then schedule a new process
    COPY   *%G1   0
    JUMP +_schedule_new_process

GET_ROM_COUNT_Handler:
;;return the number of ROMs available in the system not including the bios and kernel
;;only ever needed by init
;;jump back to where you were
;;;quickly preserve registers so we can do this function
CALL    +register_preserver     *+rp_return_address
COPY   %G0   *+_static_device_table_base
;;;skip the beginning so we don't count bios and kernel
ADDUS  %G0   %G0    24 
COPY   %G1   0
rom_count_looptop:
    BEQ   +end_of_device_table   *%G0   0
    BNEQ  +rom_count_looptop   *%G0   *+_static_ROM_device_code
    ADDUS %G1   %G1   1
    JUMP   +rom_count_looptop 


end_of_device_table:
    ;;;return value in G1 which is the counter by putting in %G0. Init needs to know to look there. This is the same register it gave us the SYSC code in
    COPY  %G0  %G1
    ;;;we preserved registers in SYSC handler, lets just restore the ones we used which is just G1
    COPY  %G1   *+G1_preserve

;;;CJ CJ CJ CJ CJ ######### YOU ARE NOT DONE HERE. ###### Use the existing method masten wrote, waiting to hear from julia on how this function will interact with init in the way she needs it to
    ;;;JUMP back to where?! What is in the interrupt buffer?!?! Does the interrupt buffer automatically add 16 so that it goes to the next instruction
    ;;6 to turn on virtual addressing and user mode. Do we have to set the base and limit registers?
   ;; JUMPMD   *+Interrupt_buffer_IP  6
   ;;do this all in run_process
   JUMP _run_process


register_preserver:
    COPY    *+G0_preserve    %G0 
    COPY    *+G1_preserve    %G1
    COPY    *+G2_preserve    %G2
    COPY    *+G3_preserve    %G3
    COPY    *+G4_preserve    %G4
    COPY    *+G5_preserve    %G5
    COPY    *+SP_preserve    %SP
    COPY    *+FP_preserve    %FP
    JUMP    *+rp_return_address 

PRINT_Handler:
;;we only ever get here from a process so we need to add the address to the base and not have a +
;;julia said she already did this
;;caller prolog for the print function:
    SUBUS   %SP     %SP     8; move SP over 2 words because no return value
    COPY    *%SP    %FP; presrve FP in the PFP word
    ADDUS   %G5     %SP     4; %G5 has address for word RA
    SUBUS   %SP     %SP     4; %SP has address of first Argument
    COPY    *%SP    *%G1; the argument that I will pass to the print. When the SYSC happens, user stores 4 in G0 to call a print sysc and a pointer to the string in G1
    COPY    %FP     %SP
    CALL   +_procedure_print  *%G5

;;caller epilogue
    ADDUS       %SP     %SP     4       ; Pop arg[0]
    COPY        %FP     *%SP                ; %FP = pfp
    ADDUS       %SP     %SP     8       ; Pop pfp / ra

;;after printing, we want to jump back into the process we were in when print was called
    JUMP  _run_process

_run_process:
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
        COPY    +IP_temp    *%G0  ;; IP
        ADDUS   %G0    %G0    4
        COPY    +G0_temp    *%G0
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
        COPY    +kernel_indicator   0 ;; 0 means we're in process
        JUMPMD  IP_temp    6


;; INVALID_ADDRESS HANDLER
;; prints "Invalid Address Interrupt"
INVALID_ADDRESS_Handler:
    ;; checks to see if interrupt was in kernel
    BEQ     +MEGA_HALT    *+kernel_indicator    1
    COPY    *+kernel_indicator    1
    ;; caller prologue for print function
    ;; prints string stored in _string_invalid_address_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_string_invalid_address_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
    JUMP    +_main_handler ; Jumps to main handler of functions


;; INVALID_REGISTER HANDLER
;; prints "Invalid Register Interrupt"
INVALID_REGISTER_Handler:
    ;; checks to see if interrupt was in kernel
    BEQ     +MEGA_HALT    *+kernel_indicator    1
    COPY    *+kernel_indicator    1
    ;; caller prologue for print function
    ;; prints string stored in _string_divide_by_zero_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_string_divide_by_zero_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
    JUMP    +_main_handler ; jumps to main handler of functions


;; BUS_ERROR HANDLER
;; prints "Bus Error Interrupt"
BUS_ERROR_Handler:
    ;; checks to see if interrupt was in kernel
    BEQ     +MEGA_HALT    *+kernel_indicator    1
    COPY    *+kernel_indicator    1
    ;; caller prologue for print function
    ;; prints string stored in _string_bus_error_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_string_bus_error_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
    JUMP    +_main_handler ; jumps to main handler of functions


;; DIVIDE_BY_ZERO HANDLER
;; prints "Divide by Zero Interrupt"
DIVIDE_BY_ZERO_Handler:
    ;; checks to see if interrupt was in kernel
    BEQ     +MEGA_HALT    *+kernel_indicator    1
    COPY    *+kernel_indicator    1
    ;; caller prologue for print function
    ;; prints string stored in _string_divide_by_zero_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_string_divide_by_zero_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
    JUMP    +_main_handler ; jumps to main handler of functions


;; OVERFLOW HANDLER
;; prints "Overflow Interrupt"
OVERFLOW_Handler:
    ;; checks to see if interrupt was in kernel
    BEQ     +MEGA_HALT    *+kernel_indicator    1
    COPY    *+kernel_indicator    1
    ;; caller prologue for print function
    ;; prints string stored in _string_overflow_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_string_overflow_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
    JUMP    +_main_handler ; jumps to main handler of functions


;; INVALID_INSTRUCTION HANDLER
;; prints "Invalid Instruction Interrupt"
INVALID_INSTRUCTION_Handler:
    ;; checks to see if interrupt was in kernel
    BEQ     +MEGA_HALT    *+kernel_indicator    1
    COPY    *+kernel_indicator    1
    ;; caller prologue for print function
    ;; prints string stored in _string_invalid_instruction_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_string_invalid_instruction_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
    JUMP    +_main_handler ; jumps to main handler of functions


;; PERMISSION_VIOLATION HANDLER
;; prints "Permission Violation Interrupt"
PERMISSION_VIOLATION_Handler:
    ;; checks to see if interrupt was in kernel
    BEQ     +MEGA_HALT    *+kernel_indicator    1
    COPY    *+kernel_indicator    1
    ;; caller prologue for print function
    ;; prints string stored in _string_permission_violation_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_string_permission_violation_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
    JUMP    +_main_handler ; jumps to main handler of functions


;; INVALID_SHIFT_AMOUNT HANDLER
;; prints "Invalid Shift Amount Interrupt"
INVALID_SHIFT_AMOUNT_Handler:
    ;; checks to see if interrupt was in kernel
    BEQ     +MEGA_HALT    *+kernel_indicator    1
    COPY    *+kernel_indicator    1
    ;; caller prologue for print function
    ;; prints string stored in _string_invalid_shift_amount_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_string_invalid_shift_amount_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
    JUMP    +_main_handler ; jumps to main handler of functions


;; INVALID_DIVICE_VALUE HANDLER
;; prints "Invalid Device Value Interrupt"
INVALID_DEVICE_VALUE_Handler:
    ;; checks to see if interrupt was in kernel
    BEQ     +MEGA_HALT    *+kernel_indicator    1
    COPY    *+kernel_indicator    1
    ;; caller prologue for print function
    ;; prints string stored in _string_invalid_device_value_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_string_invalid_device_value_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
    JUMP    +_main_handler ; jumps to main handler of functions


;; DEVICE_FAILURE HANDLER
;; prints "Device Failure Interrupt"
DEVICE_FAILURE_Handler:
    ;; checks to see if interrupt was in kernel
    BEQ     +MEGA_HALT    *+kernel_indicator    1
    COPY    *+kernel_indicator    1
    ;; caller prologue for print function
    ;; prints string stored in _string_device_failure_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_string_device_failure_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
    JUMP    +_main_handler ; jumps to main handler of functions








;; CLOCK_ALARM HANDLER
;; prints "Clock Alarm Interrupt"
CLOCK_ALARM_Handler:
    ;; checks to see if interrupt was in kernel
    BEQ     +MEGA_HALT    *+kernel_indicator    1
    COPY    *+kernel_indicator    1
    ;; caller prologue for print function
    ;; prints string stored in _string_clock_alarm_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_string_clock_alarm_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
    JUMP    +_pause_process  ; jumps to method that will preserve the current process

;; MEGA HALT
MEGA_HALT:
;; prints string stored in _mega_halt_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_mega_halt_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
   HALT


_pause_process:
   COPY    *+G0_temp  %G0
   ;; loops through process table to find current process
   COPY    %G0    +process_table
   pause_proc_looptop:
       BEQ     +found_proc_preserve    *%G0    *+current_process_ID
       ADDUS   %G0    %G0    48
       JUMP    +pause_proc_looptop
found_proc_preserve:
       ADDUS   %G0    %G0    8
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
   JUMP    +_schedule_new_process



;; MAIN HANDLER FOR INTERRUPTS
;; Since we can't actually do anything for most of these interrupts, we are just going to end the current Process then schedule new one
_main_handler:
;;====
;; prints string stored in _string_divide_by_zero_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_in_main_handler_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
;;===

   ;; caller prologue for exit function
       SUBUS    %SP    %SP    8 ; move SP over 2 words (no return value)
       COPY     *%SP   %FP  ; preserve FP into PFP
       ADDUS    %FP    %SP    4 ; add 4 to FP so that it points to return address
       ; no arguments to add
       CALL     +EXIT_Handler    *%FP
   ;; caller epilogue for exit function
       ; no arguments to pop
       COPY    %FP    *%SP ; copies PFP back into FP (PFP is where SP points)
       ADDUS   %SP    %SP     4 ; no return value so PFP and RA have been popped off and SP points to beginning of code
   ;; caller prologue for scheduling a process
    ;;   JUMP    +_schedule_new_process ;;we don't need this, it happens in exit



;; FINDS A PROCESS TO SCHEDULE
;; finds process to run, call _run_process method to run that process
;; if no process exists, print "all processes completed" and halt everything
_schedule_new_process:
;;;====
;; prints string stored in _string_divide_by_zero_msg
    SUBUS   %SP    %SP   8 ; no return value
    COPY    *%SP   %FP ; preserves FP into PFP
    ADDUS   %G5    %SP    4 ; FP has address for return address
    SUBUS   %SP    %SP    4 ; SP has address of first argument
    COPY    *%SP   +_in_schedule_msg
    COPY    %FP    %SP
    CALL    +_procedure_print   *%G5
    ;; caller epilogue
    ADDUS   %SP    %SP    4 ; pops argument
    COPY    %FP    *%SP
    ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
;;;====

   ;; not preserving registers. if registers need to be preserved, this method only uses G0  
   ;; loop through process table
       COPY    %G0    +process_table
   schedule_proc_looptop1:
       BEQ     +found_current_proc  *%G0   *+current_process_ID ; branches if process is found
       ADDUS   %G0    %G0    48  ; go to next spot in
       JUMP    +schedule_proc_looptop1
   found_current_proc:
       ;;we dont want to do this
       ;;COPY    *%G0   0 ; sets the entry ID to 0
   keep_searching:
       ADDUS   %G0    %G0    48
       BEQ     +start_from_beginning     *%G0    27
       BEQ     +keep_searching    *%G0   0
       JUMP    +found_proc 
start_from_beginning:
       COPY    %G0    +process_table 
schedule_proc_looptop2:
       BNEQ    +found_proc    *%G0     0
       ADDUS   %G0    %G0    48
       BEQ     +no_process_to_run    *%G0    27
       JUMP    +schedule_proc_looptop2
found_proc:
       COPY    *+current_process_ID      *%G0
       JUMP    +_run_process

   no_process_to_run:
       ;; prints "all processes compelted" and halts everything
       ;; string saved in _string_finished_proc_msg
       ;; caller prologue (calling print function)
       SUBUS   %SP    %SP   8 ; no return value
       COPY    *%SP   %FP ; preserves FP into PFP
       ADDUS   %FP    %SP    4 ; FP has address for return address
       SUBUS   %SP    %SP    4 ; SP has address of first argument
       COPY    *%SP   +_string_finished_proc_msg
       CALL    +_procedure_print   *%FP
       ;; caller epilogue
       ADDUS   %SP    %SP    4 ; pops argument
       COPY    %FP    *%FP
       ADDUS   %SP    %SP    8 ; no return value so just pops PFP and RA
       HALT ; theres no processes left so kernel halts



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

;;;register preservers
G0_preserve:    0
G1_preserve:    0
G2_preserve:    0
G3_preserve:    0
G4_preserve:    0
G5_preserve:    0
SP_preserve:    0
FP_preserve:    0
rp_return_address: 0

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
entry6_process_ID:  0
entry6_base:    0
entry6_limit:   0
entry6_IP:  0
entry6_G0:  0
entry6_G1:  0
entry6_G2:  0
entry6_G3:  0
entry6_G4:  0
entry6_G5:  0
entry6_SP:  0
entry6_FP:  0
entry7_process_ID:  0
entry7_base:    0
entry7_limit:   0
entry7_IP:  0
entry7_G0:  0
entry7_G1:  0
entry7_G2:  0
entry7_G3:  0
entry7_G4:  0
entry7_G5:  0
entry7_SP:  0
entry7_FP:  0
entry8_process_ID:  0
entry8_base:    0
entry8_limit:   0
entry8_IP:  0
entry8_G0:  0
entry8_G1:  0
entry8_G2:  0
entry8_G3:  0
entry8_G4:  0
entry8_G5:  0
entry8_SP:  0
entry8_FP:  0
end_of_process_table:   27
;;;this is so that we can check to see if we have reached the end of the process table and it is full

.Text
_string_blank_line: "                                                                                "
_string_test_msg: "test message\n"
_string_done_msg:	"done.\n"
_string_main_method_msg: "Main method has started.\n"
_string_invalid_address_msg: "Invalid Adress Interrupt\n"
_string_invalid_register_msg: "Invalid Register Interrupt\n"
_string_bus_error_msg: "Bus Error Interrupt\n"
_string_divide_by_zero_msg: "Divide by Zero Interrupt\n"
_string_overflow_msg: "Overflow Interrupt\n"
_string_invalid_instruction_msg: "Invalid Instruction Interrupt\n"
_string_permission_violation_msg: "Permission Violation Interrupt\n"
_string_invalid_shift_amount_msg: "Invalid Shift Amount Interrupt\n"
_string_invalid_device_value_msg: "Invalid Device Value Interrupt\n"
_string_device_failure_msg: "Device Failure Interrupt\n"
_string_clock_alarm_msg: "Clock Alarm Interrupt\n"
_string_finished_proc_msg: "Finished process\n"

_process_not_found_msg: "Process table search error. Halting\n"
_string_sysc_call_code: "SYSC without a correct SYSC code. Hatling \n"
_mega_halt_msg: "Mega halt. Kernel level interrupt\n"
_process_table_full_msg: "Process table full. Halting\n"

_in_exit_msg: "in exit\n"
_in_main_handler_msg: "in main handler\n"
_in_schedule_msg: "in schedule\n"



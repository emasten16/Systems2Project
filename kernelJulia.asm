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
    COPY    *+SYSTEM_CALL     +Dummy_Handler
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
    
Dummy_Handler:
    HALT
    
.Numeric
end_of_bus: 0
	;; Device table location and codes.
_static_device_table_base:	0x00001000
_incriment_by_one_word:       0x00000004
_incriment_by_two_words:   0x00000008
_skip_process_table_element:       0x0000000c
_static_none_device_code:	0
_static_controller_device_code:	1
_static_ROM_device_code:	2
_static_RAM_device_code:	3
_static_console_device_code:	4

    ;; Other constants.
_static_min_RAM_KB:		64
_static_bytes_per_KB:		1024
_static_bytes_per_page:		4096	; 4 KB/page
_static_kernel_KB_size:		32	; KB taken by the kerne

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
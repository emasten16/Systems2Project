;;;4/12 SYSCs are set up. Print should be set but has not been tested (waiting on FP confirmation from kaplan). Other three need to be written. (Confirm what ROM count is)


;;; The KERNEL code
;;; Tasks: 1) set up trap table
;;; 2) set TBR to base of TT
;;; 2.5) set interrupt buffer register
;;; 3) load and run one process

.Code

;;; The entry point.                                                                                                                
__start:
    COPY *+kernel_mm_base +0
    COPY %G0 *+kernel_mm_base ; for testing
    
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
    COPY    %G0     *+bus_start
    ADD     %G0     %G0   *+incriment_by_two ; %G0 refers to address of bus limit in PAS 
    COPY   *+end_of_bus *%G0 
      
    ADD     %G0     %G0     *+incriment_by_one ;;%G0 now is at the next device in bios
    COPY     %G1     0 ;let %G1 be the counter for how many rom type devices have been seen

start_loop: BEQ    +rom_type_device         *%G0       2
    ADD     %G0    %G0  *+skip_element
    JUMP    +start_loop

rom_type_device:
    ;; add one to the count of total rom type devices seen
    ADD     %G1     %G1     1
    BEQ     +deal_with_kernel   %G1 2 ;branch if this is second ROM Device seen (%G1 is counter!!!)
    BEQ    +deal_with_process1 %G1 3; branch if this is third ROM Device
    ADD     %G0    %G0  *+skip_element
    JUMP     +start_loop          
 
deal_with_kernel:
    ;;Store start address of kernel and end address of kernel- remember G1 = current address
    ADD     %G0      %G0    *+incriment_by_one
    COPY    %G2     *%G0    ;%G2 now holds start address of kernel (not IP relative)
    ADD     %G0      %G0    *+incriment_by_one
    COPY    %G3     *%G0   ;%G3 has end address of kernel (not IP relative)
    SUB     *+kernel_memory_allocation    %G3     %G2; %the length of kernel
    COPY    %G5     *+kernel_memory_allocation; testing
    ADD     *+kernel_mm_limit    *+kernel_mm_base *+kernel_memory_allocation
    COPY     %G5    *+kernel_mm_limit ;for testing
    ADD     %G0     %G0     *+incriment_by_one
    JUMP     +start_loop
    
deal_with_process1:
;;store the start and end address of this process in PAS and then use DMA to copy and jump to start
    ADD     %G0      %G0    *+incriment_by_one
    COPY    %G2     *%G0    ;%G2 now holds start address of process 
    ADD     %G0      %G0    *+incriment_by_one
    COPY    %G3     *%G0   ;%G3 has end address of process
    SUB    %G3    %G3   %G2     ;calculate length of process
    ADD     %G4    *+kernel_mm_limit *+incriment_by_one; end of kernel in MM + 1 word = MM start address 
   
   
    SUB     %G5     *+end_of_bus   *+skip_element  ;%G5 now holds the address of the 3rd to last last word in bus
    COPY    *%G5     %G2     ;store the start of process in bus
    ADD     %G5     %G5     *+incriment_by_one
    COPY    *%G5    %G4   ;MM start of process
    ADD     %G5     %G5     *+incriment_by_one
    COPY    *%G5    %G3         ;store length of process at end of bus
        
    JUMPMD    %G4   2;jump to start of process in MM

SYSC_Handler:
;;; %G0 holds 1 if EXIT, 2 if CREATE, 3 if GET_ROM_COUNT, 4 if PRINT
    CALL    +register_preserver     +return_address
    BEQ     EXIT_Handler    %G0     0
    BEQ     CREATE_Handler  %G0     1
    BEQ     GET_ROM_COUNT_Handler   %G0     2
    BEQ     PRINT_Handler           %G0     4

EXIT_Handler:
;;;return process memory to free space
;;;search process table for process ID,  make it 0

CREATE_Handler:
;;;create a new process

GET_ROM_COUNT_Handler:
;;;return the number of ROMs available in the system

PRINT_Handler:
;;;print to console -- all of this is kaplans print code
;;;=======================================================
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

    ;; If not yet initialized, set the console base/limit statics.
    BNEQ        +print_init_loop    *+_static_console_base      0
    SUBUS       %SP     %SP     12      ; Push pfp / ra / rv
    COPY        *%SP        %FP             ; pFP = %FP
    SUBUS       %SP     %SP     4       ; Push arg[1]
    COPY        *%SP        1               ; Find the 1st device of the given type.
    SUBUS       %SP     %SP     4       ; Push arg[0]
    COPY        *%SP        *+_static_console_device_code   ; Find a console device.
    COPY        %FP     %SP             ; Update %FP
    ADDUS       %G5     %SP     12      ; %G5 = &ra
    CALL        +_procedure_find_device     *%G5
    ADDUS       %SP     %SP     8       ; Pop arg[0,1]
    COPY        %FP     *%SP                ; %FP = pfp
    ADDUS       %SP     %SP     8       ; Pop pfp / ra
    COPY        %G4     *%SP                ; %G4 = &dt[console]
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
;;; ================================================================================================================================

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

;;;============end Kaplan print code

register_preserver:
    COPY    *+G0_preserve    %G0 
    COPY    *+G1_preserve    %G1
    COPY    *+G2_preserve    %G2
    COPY    *+G3_preserve    %G3
    COPY    *+G4_preserve    %G4
    COPY    *+G5_preserve    %G5
    COPY    *+SP_preserve    %SP
    COPY    *+FP_preserve    %FP
    JUMP    *+return_address

Dummy_Handler:
    HALT


      

    
.Numeric
bus_start:      0x00001000
incriment_by_one:       0x00000004
incriment_by_two:   0x00000008
skip_element:       0x0000000c

end_of_bus: 0
kernel_memory_allocation: 0  ;1 MB
kernel_mm_base: 0
kernel_mm_limit: 0

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

return_address: 0

;;;kaplan print statics
_static_console_width:      80
_static_console_height:     24
_static_space_char:     0x20202020 ; Four copies for faster scrolling.  If used with COPYB, only the low byte is used.
_static_cursor_char:        0x5f
_static_newline_char:       0x0a
_static_cursor_column:      0   ; The column position of the cursor (always on the last row).
_static_console_base:       0
_static_console_limit:      0
_static_console_device_code:    4
_static_kernel_error_console_not_found:     0xffff0004
_static_dt_base_offset:     4
_static_dt_limit_offset:    8
_static_device_table_base:  0x00001000



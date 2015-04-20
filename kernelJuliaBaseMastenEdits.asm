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
    COPY    *+CLOCK_ALARM     +Switch_Handler
    ;;;print fyi, pause current process, schedule a new process
    COPY    *+DIVIDE_BY_ZERO     +Dummy_Handler
    COPY    *+OVERFLOW    +Dummy_Handler
    COPY    *+INVALID_INSTRUCTION    +Dummy_Handler
    COPY    *+PERMISSION_VIOLATION     +Dummy_Handler
    COPY    *+INVLID_SHIFT_AMOUNT     +Dummy_Handler
    COPY    *+SYSTEM_CALL     +SYSC_Handler
    COPY    *+INVALID_DEVICE_VALUE    +Dummy_Handler
    COPY    *+DEVICE_FAILURE     +Dummy_Handler
  
   ;;; +Dummy_Handler
    ;;;print error, exit current process, schedule a new process

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
    COPY    %G0    +*bus_start
    ;;;G2 holds the ROM code which is 2, G4 holds our counter (we want this to equal g1)
    COPY    %G2     2
    COPY    %G4     0
found_empty_process_looptop:
    BNEQ     +create_a    *%G0   %G2
    ADDUS    %G4    1
    BEQ      +create_b     %G4    %G1    
   
create_a:
    ADDUS   %G0    %G0    12
    JUMP    +found_empty_process_looptop

create_b:
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

;;;it is in the process table, now what!!    

no_room_in_process_table:
;;;process table is full
    HALT
    
GET_ROM_COUNT_Handler:
;;;return the number of ROMs available in the system NOT INCLUDING BIOS AND KERNEL

COPY   %G0   +*bus_start
;;;skip the beginning so we don't count bios and kernel
ADDUS  %G0   %G0    24 
COPY   %G1   0
rom_count_looptop:
    BEQ   +end_of_device_table   *%G0   0
    BNEQ  +rom_count_looptop   *%GO   2
    ADDUS %G1   %G1   1
    JUMP   +rom_count_looptop


end_of_device_table:
    ;;;return value in G1 which is the counter by putting in %G0. Init needs to know to look there. This is the same register it gave us the SYSC code in
    COPY  %G0  %G1
    ;;;we preserved registers in SYSC handler, lets just restore the ones we used which is just G1
    COPY  %G1   +*G1_preserve

    ;;;JUMP back to where?! What is in the interrupt buffer?!?! Does the interrupt buffer automatically add 16 so that it goes to the next instruction
    JUMPMD   +*Interrupt_buffer_IP


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


current_process_ID: 0


;;;PROCESS TABLE
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
end_of_process_table:   27
;;;this is so that we can check to see if we have reached the end of the process table and it is full


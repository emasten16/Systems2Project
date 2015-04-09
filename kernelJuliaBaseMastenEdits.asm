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
    COPY    *+INVALID_ADDRESS   Dummy_Handler
    COPY    *+INVALID_REGISTER  Dummy_Handler
    COPY    *+BUS_ERROR     Dummy_Handler
    COPY    *+CLOCK_ALARM     Dummy_Handler
    COPY    *+DIVIDE_BY_ZERO     Dummy_Handler
    COPY    *+OVERFLOW    Dummy_Handler
    COPY    *+INVALID_INSTRUCTION    Dummy_Handler
    COPY    *+PERMISSION_VIOLATION     Dummy_Handler
    COPY    *+INVLID_SHIFT_AMOUNT     Dummy_Handler
    COPY    *+SYSTEM_CALL     Dummy_Handler
    COPY    *+INVALID_DEVICE_VALUE    Dummy_Handler
    COPY    *+DEVICE_FAILURE     Dummy_Handler

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
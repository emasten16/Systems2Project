;;; The BIOS code
;;; Finds the 2nd ROM device (kernel) and uses DMA to copy it into MM
;;; will jump to the MM address that represents the start of the kernel
        .Code

;;; The entry point.                                                                                                                
__start:

        ;; Initialize the stack at the limit.                                                                                       
        COPY    %SP     *+limit

        COPY    %G0     *+bus_start
        ADD     %G0     %G0   *+incriment_by_two ; %G0 refers to bus limit
        COPY    %G5     *%G0 ;%G5 now holds the limit of bus controller (not IP relative)

        ADD     %G0     %G0     *+incriment_by_one ;;%G0 now is at the next device in bios
        COPY     %G1     0 ;let %G1 be the counter for how many rom type devices have been seen
        COPY    %G4     0   ;%G4 will hold address of MM, will be set to first RAM encountered
        
              ;; if device is of type ROM, go through instructions as appropriate
start_loop: BEQ    +rom_type_device         *%G0       2
        BEQ     +deal_with_RAM     *%G0     3 ;if device is type RAM, store start address
        ADD     %G0    %G0  *+skip_element
        JUMP    +start_loop
deal_with_RAM: 
        BNEQ    +start_loop    %G4     0 ;if %G4 has a value, then we've already seen a RAM device
        ADD     %G0     %G0     *+incriment_by_one ;G0 now has address of location for MM start address
        COPY    %G4     *%G0    ;%G4 now stores the real mm start address (not ip relative)
        ADD     %G0     %G0     *+incriment_by_two ;%G0 is now at start of next device
        JUMP    +start_loop
rom_type_device:
        ;; add one to the count of total rom type devices seen
        ADD     %G1     %G1     1
        BGTE     +deal_with_kernel   %G1 2 ;branch if this is second ROM Device seen (%G1 is counter!!!)
        ADD     %G0     %G0     *+skip_element ;if this is not second ROM device, then go back to start of loop
        JUMP     +start_loop    
        
deal_with_kernel:
        ;;Store start address of kernel and end address of kernel- remember G1 = current address
        ADD     %G0      %G0    *+incriment_by_one
        COPY    %G2     *%G0    ;%G2 now holds start address of kernel (not IP relative)
        ADD     %G0      %G0    *+incriment_by_one
        COPY    %G3     *%G0   ;%G3 has end address of kernel (not IP relative)
        
        SUB     %G5     %G5     *+skip_element  ;%G5 now holds the address of the 3rd to last last word in bus
        COPY    *%G5     %G2     ;store the start of kernal in bus
        ADD     %G5     %G5     *+incriment_by_one
        COPY    *%G5    %G4     ;store the MM start address in bus
        ADD     %G5     %G5     *+incriment_by_one
        SUB    %G3    %G3   %G2     ;calculate length of kernel
        COPY    *%G5    %G3         ;store length of kernel at end of bus
        
        JUMP    %G4       ;jump to start of kernel in MM
        
.Numeric
bus_start:      0x00001000
incriment_by_one:       0x00000004
incriment_by_two:   0x00000008
skip_element:       0x0000000c


        ;; Assume (at least) a 16 KB main memory.                                                                                   
limit:  0x5000
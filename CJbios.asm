;;; worked with Masten
	
	.Code

	;; G0 is where we keep track of how many ROM's we have found
	;; we compare this to G1 because we want the 2nd ROM
	;; G3 holds the address of the start of the bus controller device table
	COPY	%G0	0
	COPY	%G1	2
	COPY	%G3	*+devicetablestart

	;; find the place where the end of the bus control table is held and store in G5
	ADD	%G5	%G3	8

	;; FIND KERNEL
	;; in looptop we check to see if we have found a ROM in which case we iterate G0
	;; if we have found the second ROM (kernel) we jump to found kernel
looptop:	
	BEQ	+foundkernel	%G0	%G1
	ADD	%G3	%G3	12
	;; store the placce where the beginning of device is held into G4
	ADD	%G4	%G3	4
	BNEQ	+foundROM	*%G3	%G1
	ADD	%G0	%G0	1
foundROM:	
	JUMP	+looptop
	
foundkernel:	
	SUB	%G5	*%G5	12
	COPY	*%G5	*%G4
	;; put length of kernel into G1 to put into DMA when ready to copy
	ADD	%G0	%G4	4
	SUB	%G1	*%G0	*%G4



	
	;; FIND RAM
	COPY	%G0	3
	COPY	%G3	*+devicetablestart
	
looptop2:	
	BEQ	+foundRAM	%G0	*%G3
	ADD	%G3	%G3	12
	JUMP	+looptop2

foundRAM:
	;; store beginning of device into G2
	ADD	%G2	%G3	4
	COPY	%G3	*+devicetablestart
	ADD	%G3	%G3	8
	SUB	%G3	*%G3	8
	COPY	*%G3	*%G2

	;; Copy length to initiate DMA
	COPY	%G3	*+devicetablestart
	ADD	%G3	%G3	8
	SUB	%G3	*%G3	4
	COPY	*%G3	%G1

	;; run kernel
	JUMP 	*%G2
	
	
	.Numeric
devicetablestart:	0x00001000

	

	
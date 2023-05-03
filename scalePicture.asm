	.data	
sourceFile:	.asciz	 "picture.bmp"
outFile: 	.asciz	 "scaled-picture.bmp"
buffer:		.space 512
	
	.text
	.global main
main:
	li	a7, 17
	la	a0, buffer
	li	a1, 512
	ecall
	
	li	a7, 4
	ecall			# print cwd

	la 	a0, sourceFile
	li 	a1, 0
	li	a7, 1024
	ecall			# open file in read-only mode
	
	mv	t0, a0		# copy file descriptor
	la	a1, buffer
	li	a2, 512
	li	a7, 63
	ecall
	
	la	t1, buffer
	lb 	a0, 0x22(t1)	# load size
	lb	t3, 0x23(t1)
	slli	t3, t3, 8	# shifting and adding because it's unaligned, little endian
	add	a0, a0, t3
	lb	t3, 0x24(t1)
	slli	t3, t3, 16
	add	a0, a0, t3
	lb	t3, 0x25(t1)
	slli	t3, t3, 24
	mv	t2, a0		# copy size
	add	a0, a0, t3	# size of bitmap in bytes  is in a0
	li	a7, 9
	ecall			# allocate memory for bitmap on the heap
	mv	t3, a0		# copy pointer
	
	mv	a0, t0		# file descriptor
	li	a1, 0x36	# offset, where bitmap data begins
	li	a2, 0		# idk??
	li	a7, 62
	ecall			# seek file dscriptor to bitmap data
	
	mv	a0, t0		# file descriptor
	mv	a1, t3		# pointer to bitmap buffer
	mv	a2, t2		# length to read
	ecall 			# read all bitmap data
	
	
	li	a7, 10
	ecall			# Exit

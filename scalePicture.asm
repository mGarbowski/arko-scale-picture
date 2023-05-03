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
	
	mv	s1, a0		# preserve file descriptor
	call	loadFileToMemory
	
	lbu	t0, (a0)	# first byte (red) of first pixel (lower left)
	lbu	t1, 1(a0)
	lbu	t2, 2(a0)
	
	# Seek to the beginning of the file
	mv	a0, s1
	li	a1, 0
	li	a2, 0
	li	a7 62
	ecall
	
	mv	a0, s1		# Close the files
	li	a7, 57
	ecall
	
	
	li	a7, 10
	ecall			# Exit


# Allocate space for the bitmap on the heap and load bitmap data
# Arguments
# a0 - file descriptor of an open .bmp file
# Returns
# a0 - pointer to bitmap data
loadFileToMemory:
	addi	sp, sp, -20	# Prologue
	sw	ra, 16(sp)
	sw	s1, 12(sp)
	sw	s2, 8(sp)
	sw	s3, 4(sp)
	sw	s4, (sp)
	
	mv	a0, s1		# Preserve file descriptor
	
	la	a1, buffer	# Read beginning of the file into buffer
	li	a2, 512
	li	a7, 63
	ecall			
	
	la	a0, buffer	# read bitmap offset from 0x0A in .bmp header
	addi	a0, a0, 0x0A
	call	read4BytesLE
	mv	s2, a0
	
	la	a0, buffer	# read bitmap size from 0x22 in .bmp header
	addi	a0, a0, 0x22
	call 	read4BytesLE
	mv	s3, a0
	
	mv	a0, s1		# Seek to the beginning of the file
	addi	a1, s2, 1	# Offset where bitmap data begins
	li	a2, 0
	li	a7 62
	ecall
	
	mv	a0, s3		# Allocate memory on heap for bitmap data
	li	a7, 9
	ecall
	mv	s4, a0		# preserve bitmap pointer
	
	mv	a0, s1		# read bitmap data to heap memory
	mv	a1, s4
	mv	a2, s3
	li	a7, 63
	ecall
	
	mv	a0, s4		# Return bitmap pointer
	
	lw	s4, (sp)	# Epilogue
	lw	s3 4(sp)
	lw	s2, 8(sp)
	lw	s1, 12(sp)
	lw	ra, 16(sp)	
	addi	sp, sp, 20
	ret
	
	

# Read 4 consecutive bytes from memory representing integer in little endian
# Arguments
# a0 - address of the first byte
# Returns
# a0 - 4B signed integer 
read4BytesLE:
	lb	t0, (a0)
	lb	t2, 1(a0)
	slli	t2, t2, 8
	add	t0, t0, t2
	lb	t2, 2(a0)
	slli	t2, t2, 16
	add	t0, t0, t2
	lb	t2, 3(a0)
	slli	t2, t2, 24
	add	t0, t0, t2
	mv	a0, t0
	ret




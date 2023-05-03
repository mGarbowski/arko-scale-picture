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
	
	# Seek to the beginning of the file
	mv	a0, s1
	li	a1, 0
	li	a2, 0
	li	a7 62
	ecall
	
	mv	a0, s1
	call 	readBitmapSize
	
	
	
	
	li	a7, 10
	ecall			# Exit


# Allocate space for the bitmap on the heap and load bitmap data
# Arguments
# a0 - file descriptor of an open .bmp file
# Returns
# a0 - pointer to bitmap data
loadFileToMemory:
	addi	sp, sp, -4	# Prologue
	sw	ra, (sp)
	
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
	
	
	lw	ra, (sp)	# Epilogue
	addi	sp, sp, 4
	ret
	

# Read offset of the bitmap data from .bmp file header, loaded into buffer
# Arguments
# -
# Returns
# a0 - offset of bitmap data	
readBitmapOffset:
	addi	sp, sp, -4
	sw	ra, (sp)
	
	la	a0, buffer
	addi	a0, a0, 0x0A	# offset of the bitmap offset field
	call 	read4BytesLE
	
	lw	ra, (sp)
	addi	sp, sp, 4
	ret
	

# Read size of the bitmap from .bmp file header, loaded into buffer
# Arguments
# -
# Returns
# a0 - size of the bitmap (4B)
readBitmapSize:
	addi	sp, sp, -4	# Save return address on the stack
	sw	ra, (sp)
	
	la	a0, buffer
	addi	a0, a0, 0x22	# Offset of bitmap size field in the header
	call 	read4BytesLE
	
	lw	ra, (sp)
	addi	sp, sp, 4	# Restore return address from the stack
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




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
	
	mv	s1, a0		# copy file descriptor
	call 	readBitmapSize
	
	li	a7, 10
	ecall			# Exit


# Allocate space for the bitmap on the heap and load bitmap data
# Arguments
# a0 - file descriptor of an open .bmp file
# Returns
# a0 - pointer to bitmap data
loadFileToMemory:
	ret
	
	
# Read size of the bitmap from .bmp file header
# Arguments
# a0 - file descriptor of an open .bmp file
# Returns
# a0 - size of the bitmap (4B)
readBitmapSize:
	addi	sp, sp, -4	# Save return address on the stack
	sw	ra, (sp)
	
	la	a1, buffer
	li	a2, 512
	li	a7, 63
	ecall			# Read beginning of the file into buffer
	
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




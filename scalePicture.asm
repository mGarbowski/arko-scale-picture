	.data	
sourceFile:	.asciz	 "src2.bmp"
outFile: 	.asciz	 "out2.bmp"
buffer:		.space 512
	
	.text
	.global main
main:	
	li	a7, 17		# print cwd
	la	a0, buffer
	li	a1, 512
	ecall
	li	a7, 4
	ecall			

	# Source file
	la 	a0, sourceFile 	# open source image in read-only mode
	li 	a1, 0
	li	a7, 1024
	ecall			
	mv	s1, a0		# preserve file descriptor
	
	
	la	a1, buffer	# Read beginning of the file into buffer
	li	a2, 512
	li	a7, 63
	ecall
	
	la	a0, buffer	# load sourceWidth
	addi	a0, a0, 0x12
	call 	read4BytesLE
	addi	sp, sp, -4	# push sourceWidth
	sw	a0, (sp)
	
	la	a0, buffer
	addi	a0, a0, 0x16
	call 	read4BytesLE 	
	addi	sp, sp, -4	# push sourceHeight
	sw	a0, (sp)
	
	call	loadFileToMemory
	mv	s2, a0		# preserve sourcePtr
	
	mv	a0, s1		# close the source file
	li	a7, 57
	ecall
	
	
	# Output file
	la	a0, outFile	# open output picture in read-only mode
	li	a1, 0
	li	a7, 1024
	ecall
	mv	s1, a0		# preserve file descriptor
	
	la	a1, buffer	# Read beginning of the file into buffer
	li	a2, 512
	li	a7, 63
	ecall
	
	la	a0, buffer	# push outputWidth
	addi	a0, a0, 0x12
	call 	read4BytesLE
	addi	sp, sp, -4	
	sw	a0, (sp)
	
	la	a0, buffer	# push outputHeight
	addi	a0, a0, 0x16
	call 	read4BytesLE 	
	addi	sp, sp, -4	
	sw	a0, (sp)
	
	call	loadFileToMemory
	mv	s3, a0		# preserve outputPtr
	
	mv	a0, s1		# close output file
	li	a7, 57
	ecall
	
	# Debugging
	lw	t0, (sp)
	lw	t1, 4(sp)
	lw	t2, 8(sp)
	lw	t3, 12(sp)
	
	lbu	t0, (s2)	# first byte (red) of first pixel (lower left) source picture
	lbu	t1, 1(s2)
	lbu	t2, 2(s2)
	
	lbu	t0, (s3)	# first byte (red) of first pixel (lower left) output picture
	lbu	t1, 1(s3)
	lbu	t2, 2(s3)
	
	mv	a0, s2		# print some pixel info
	li	a1, 2
	li	a2, 1
	li	a3, 4
	li	a4, 4
	li	a5, 0
	li 	a6, 3
	li	a7, 16
	call 	getSrcPixel
	
	li	a7, 34
	ecall
	mv	a0, a1
	ecall
	mv	a0, a2
	ecall
	
	li	a7, 10
	ecall			# Exit


# Allocate space for the bitmap on the heap and load bitmap data
# .bmp header already loaded into buffer
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
		
	
	la	a0, buffer	# read bitmap offset from 0x0A in .bmp header
	addi	a0, a0, 0x0A
	call	read4BytesLE
	mv	s2, a0
	
	la	a0, buffer	# read bitmap size from 0x22 in .bmp header
	addi	a0, a0, 0x22
	call 	read4BytesLE
	mv	s3, a0
	
	mv	a0, s1		# Seek to the beginning of the file
	addi	a1, s2, 0	# Offset where bitmap data begins
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


# Scale down picture with integer proportions
# Arguments
# a0 - sourcePtr
# a1 - outputPtr
# a2 - sourceWidth
# a3 - sourceHeight
# a4 - outputWidth
# a5 - outputHeight
scalePicture:
	ret
	
	
# Get red, green and blue values of a pixel in source image corresponding to pixel and window offset in output image
# Arguments
# a0 - sourcePtr
# a1 - outputRow
# a2 - outputCol
# a3 - windowHeight
# a4 - windowWidth
# a5 - rowOffset
# a6 - colOffset
# a7 - sourceWidth
# Returns
# a0 - red
# a1 - green
# a2 - blue
getSrcPixel:
	mul	t0, a1, a3	# srcRow = outRow * windowHeight + rowOffset
	add	t0, t0, a5
	
	mul	t1, a2, a4	# srcCol = outCol * windowWidth + colOffset
	add	t1, t1, a6
	
	mul	t2, a7, t0	# pixelOffset = srcWidth * srcRow + srcCol
	add	t2, t2, t1
	
	li	t0, 3		# pixelByteOffset = pixelOffset * 3 (24-bit)
	mul	t2, t2, t0	# TODO use shifts
	
	add	t0, a0, t2	# pixelPtr = sourcePtr + pixelByteOffset
	#addi	t0, t0, -1	# something miscalculated (?)
	
	lbu	a0, (t0)	# red
	lbu	a1, 1(t0)	# green
	lbu	a2, 2(t0)	# blue
	
	ret	


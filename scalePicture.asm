	.data	
sourceFile:	.asciz	 "9x9.bmp"
outFile: 	.asciz	 "3x3.bmp"
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

	# Load source file bitmap and metadata
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
	mv	s4, a0		# sourceWidth
	
	la	a0, buffer
	addi	a0, a0, 0x16
	call 	read4BytesLE 	
	mv	s5, a0		# sourceHeight
	
	call	loadFileToMemory
	mv	s2, a0		# preserve sourcePtr
	
	mv	a0, s1		# close the source file
	li	a7, 57
	ecall
	
	
	# Load output file bitmap and metadata
	la	a0, outFile	# open output picture in read-only mode
	li	a1, 0
	li	a7, 1024
	ecall
	mv	s1, a0		# preserve file descriptor
	
	la	a1, buffer	# Read beginning of the file into buffer
	li	a2, 512
	li	a7, 63
	ecall
	
	la	a0, buffer	
	addi	a0, a0, 0x12
	call 	read4BytesLE
	mv	s6, a0		# outputWidth
	
	la	a0, buffer	
	addi	a0, a0, 0x16
	call 	read4BytesLE 	
	mv	s7, a0		# outputHeight
	
	call	loadFileToMemory
	mv	s3, a0		# preserve outputPtr
	
	mv	a0, s1		# close output file
	li	a7, 57
	ecall
	
	# Calculate output bitmap
	mv	a0, s2
	mv	a1, s3
	mv	a2, s4
	mv	a3, s5
	mv	a4, s6
	mv	a5, s7
	call	scalePicture
	
	# Save result bitmap to output file
	la	a0, buffer	# read bitmap offset, outFile header is already in the buffer
	addi	a0, a0, 0x0A
	call	read4BytesLE
	mv	s8, a0
	
	la	a0, buffer	# read output bitmap size
	addi	a0, a0, 0x22
	call 	read4BytesLE
	mv	s9, a0
	
	la	a0, outFile	# open output file in write-only mode
	li	a1, 1
	li	a7, 1024
	ecall
	mv	t1, a0		# preserve file descriptor
	
	la	a1, buffer	# write back the original header from buffer
	mv	a2, s8
	li	a7, 64
	ecall
	
	mv	a0, t1		# write calculated bitmap from heap memory to file
	mv	a1, s3
	mv	a2, s9
	li	a7, 64
	ecall
	
	mv	a0, t1		# close output file
	li	a7, 57
	ecall
	
	
	# Exit
	li	a7, 10
	ecall			


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
	lbu	t0, (a0)
	lbu	t2, 1(a0)
	slli	t2, t2, 8
	add	t0, t0, t2
	lbu	t2, 2(a0)
	slli	t2, t2, 16
	add	t0, t0, t2
	lbu	t2, 3(a0)
	slli	t2, t2, 24
	add	t0, t0, t2
	mv	a0, t0
	ret


# Scale down picture with integer proportions
# Places calculated pixel values at outputPtr
# Arguments
# a0 - sourcePtr
# a1 - outputPtr
# a2 - sourceWidth
# a3 - sourceHeight
# a4 - outputWidth
# a5 - outputHeight
scalePicture:
	# Prologue
	# Preserve stored registers and return address
	addi	sp, sp, -44
	sw	ra, 40(sp)
	sw	s0, 36(sp)
	sw	s1, 32(sp)
	sw	s2, 28(sp)
	sw	s3, 24(sp)
	sw	s4, 20(sp)
	sw	s5, 16(sp)
	sw	s6, 12(sp)
	sw	s7, 8(sp)
	sw	s8, 4(sp)
	sw	s9, (sp)
	
	# Preserve arguments
	mv	s0, a0
	mv	s1, a1
	mv	s2, a2
	mv	s3, a3
	mv	s4, a4
	mv	s5, a5
	
	# Body
	div	s8, s2, s4	# windowWidth
	div	s9, s3, s5	# windowHeight
	
	li	s6, 0		# outRow = 0...outHeight-1
outRowLoop:
	li	s7, 0		# outCol = 0...outWidth-1
outColLoop:
	# Pass arguments
	mv	a0, s0
	mv	a1, s6
	mv	a2, s7
	mv	a3, s9
	mv	a4, s8
	mv	a5, s2
	call	calculateOutputPixel
	
	# Calculate address of output pixel
	mul	t0, s6, s4	# pixelOffset = (outRow * outputWidth) + outCol
	add	t0, t0, s7
	li	t1, 3
	mul	t0, t0, t1	# pixelBytesOffset = pixelOffset * 3 (24-bits per pixel) TODO optimize
	li	t1, 3		# TODO calculate padding
	mul	t2, s6, t1	# paddingOffset = outRow * paddingBytesPerRow
	add	t0, t0, t2	# pixelBytesOffset += paddingOffset
	add	t0, s1, t0	# pixelPtr = outputPtr + pixelBytesOffset
	
	# Store pixel RGB data
	sb	a0, (t0)
	sb	a1, 1(t0)
	sb	a2, 2(t0)
	
	addi	s7, s7, 1		# close inner loop
	blt	s7, s4, outColLoop

	addi	s6, s6, 1
	blt	s6, s3, outRowLoop	# close outer loop
	
	# Epilogue
	lw	s9, (sp)
	lw 	s8, 4(sp)
	lw 	s7, 8(sp)
	lw 	s6, 12(sp)
	lw 	s5, 16(sp)
	lw 	s4, 20(sp)
	lw 	s3, 24(sp)
	lw	s2, 28(sp)
	lw	s1, 32(sp)
	lw	s0, 36(sp)
	lw	ra, 40(sp)
	addi	sp, sp, 44
	ret
	

# Calculate red, green and blue values of the given output pixel
# Arguments
# a0 - sourcePtr
# a1 - outputRow
# a2 - outputCol
# a3 - windowHeight
# a4 - windowWidth
# a5 - sourceWidth
# Returns
# a0 - red
# a1 - green
# a2 - blue
calculateOutputPixel:
	# Preserve saved registers
	addi	sp, sp, -48
	sw	ra, 44(sp)
	sw	s0, 40(sp)
	sw	s1, 36(sp)
	sw	s2, 32(sp)
	sw	s3, 28(sp)
	sw	s4, 24(sp)
	sw	s5, 20(sp)
	sw	s6, 16(sp)
	sw	s7, 12(sp)
	sw	s8, 8(sp)
	sw	s9, 4(sp)
	sw	s10, (sp)

	# Save arguments for multiple function calls
	mv	s0, a0	
	mv	s1, a1
	mv	s2, a2
	mv	s3, a3
	mv	s4, a4
	mv	s7, a5
	
	li	s8, 0	# red
	li	s9, 0	# green
	li	s10, 0	# blue
	

	li	s6, 0	# colOffset -> 0...windowWidth-1
windowColLoop:
	li	s5, 0	# rowOffset -> 0...windowHeight-1
windowRowLoop:
	# Pass arguments TODO: optimize
	mv	a0, s0
	mv	a1, s1
	mv	a2, s2
	mv	a3, s3
	mv	a4, s4
	mv	a5, s5
	mv	a6, s6
	mv	a7, s7
	call	getSrcPixel
	
	# Add corresponding RGB values
	add	s8, s8, a0
	add	s9, s9, a1
	add	s10, s10, a2

	addi	s5, s5, 1
	blt	s5, s3, windowRowLoop	# close inner loop

	addi	s6, s6, 1
	blt	s6, s4, windowColLoop	# close outer loop
	
	# Calculate mean for each of RGB colors and put in appropriate return registers
	mul	t0, s3, s4	# pixels in window = width * height
	div	a0, s8, t0
	div	a1, s9, t0
	div	a2, s10, t0
	
	# Restore saved registers
	lw	s10, (sp)
	lw	s9, 4(sp)
	lw	s8, 8(sp)
	lw	s7, 12(sp)
	lw	s6, 16(sp)
	lw	s5, 20(sp)
	lw	s4, 24(sp)
	lw	s3, 28(sp)
	lw	s2, 32(sp)
	lw	s1, 36(sp)
	lw	s0, 40(sp)
	lw	ra, 44(sp)
	addi	sp, sp, 48
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
	
	li	t3, 3		# pixelByteOffset = pixelOffset * 3 (24-bit)
	mul	t2, t2, t3	# TODO use shifts
	
	# TODO calculate padding
	li	t3, 1		# padding pixels per row TODO
	mul	t0, t0, t3	# paddingOffset = paddingBytesInRow * srcRow
	add	t2, t2, t0	# pixelByteOffset += paddingOffset
	 
	
	add	t0, a0, t2	# pixelPtr = sourcePtr + pixelByteOffset
	
	lbu	a0, (t0)	# red
	lbu	a1, 1(t0)	# green
	lbu	a2, 2(t0)	# blue
	
	ret	


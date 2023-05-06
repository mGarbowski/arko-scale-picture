# Downscale .bmp image
# Requires hardcoded sourceFile and outFile to exist and be valid .bmp
# Source image is downscaled to output image's size
# 
# Supports .bmp files with padding
# Supports non-integer downscaling ratio
# Fixed point calculations use format with 24-bit integer part and 8-bit fraction part
#
# Author: Mikołaj Garbowski 2023
#
	
		.data	
sourceFile:	.asciz	 "czumpi.bmp"
outFile: 	.asciz	 "czumpi-out.bmp"
buffer:		.space 512
	
	.text
	.global main
main:	
	#
	# Load source file bitmap and metadata
	#
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
	
	#
	# Load output file bitmap and metadata
	#
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
	
	#
	# Calculate output bitmap
	#
	mv	a0, s2
	mv	a1, s3
	mv	a2, s4
	mv	a3, s5
	mv	a4, s6
	mv	a5, s7
	call	scalePicture
	
	#
	# Save result bitmap to output file
	#
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
# Requires .bmp header to be loaded into buffer
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
# Utility for reading non-aligned data
# Arguments
# a0 - address of the first byte
# Returns
# a0 - 4B integer 
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


# Downscale picture 
# Places calculated pixel values in ouput pixel matrix (outputPtr) 
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
	
	# Preserve arguments
	mv	s0, a0
	mv	s1, a1
	mv	s2, a2
	mv	s3, a3
	mv	s4, a4
	mv	s5, a5
	
	# Body
	slli	s8, s2, 8	# windowWidth (fiexd-point)
	div	s8, s8, s4
	slli	s9, s3, 8	# windowHeight (fixed-point)
	div	s9, s9, s5
	
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
	call	calculateOutputPixel	# output in a0, a1, a2
	mv	s10, a0			# preserve red value in saved register
	
	mv	a0, s4
	call	calculatePadding	# paddingBytesPerRow in a0
	
	
	# Calculate address of output pixel
	mul	t0, s6, s4	# pixelOffset = (outRow * outputWidth) + outCol
	add	t0, t0, s7
	slli	t1, t0, 1	# *3 by shifting and adding
	add	t0, t0, t1	# pixelBytesOffset = pixelOffset * 3 (24-bits per pixel)
	mul	t2, s6, a0	# paddingOffset = outRow * paddingBytesPerRow
	add	t0, t0, t2	# pixelBytesOffset += paddingOffset
	add	t0, s1, t0	# pixelPtr = outputPtr + pixelBytesOffset
	
	# Store pixel RGB data
	sb	s10, (t0)
	sb	a1, 1(t0)
	sb	a2, 2(t0)
	
	addi	s7, s7, 1		# close inner loop
	blt	s7, s4, outColLoop

	addi	s6, s6, 1
	blt	s6, s5, outRowLoop	# close outer loop
	
	# Epilogue
	lw	s10, (sp)
	lw	s9, 4(sp)
	lw 	s8, 8(sp)
	lw 	s7, 12(sp)
	lw 	s6, 16(sp)
	lw 	s5, 20(sp)
	lw 	s4, 24(sp)
	lw 	s3, 28(sp)
	lw	s2, 32(sp)
	lw	s1, 36(sp)
	lw	s0, 40(sp)
	lw	ra, 44(sp)
	addi	sp, sp, 48
	ret
	

# Calculate RGB values of the given output pixel
# RGB values are weighted average of pixels in source image
# weight of a source pixel is proportional to its area contained in the window 
# (1.0 in the midle and <= 1.0 in the corners and edges)
#
# Arguments
# a0 - sourcePtr
# a1 - outputRow
# a2 - outputCol
# a3 - windowHeight (fixed-point)
# a4 - windowWidth (fixed-point)
# a5 - sourceWidth
# Returns
# a0 - red
# a1 - green
# a2 - blue
calculateOutputPixel:
	# Preserve saved registers
	addi	sp, sp, -92	# allocate additional space for local variables
	sw	ra, 88(sp)
	sw	s0, 84(sp)
	sw	s1, 80(sp)
	sw	s2, 76(sp)
	sw	s3, 72(sp)
	sw	s4, 68(sp)
	sw	s5, 64(sp)
	sw	s6, 60(sp)
	sw	s7, 56(sp)
	sw	s8, 52(sp)
	sw	s9, 48(sp)
	sw	s10, 44(sp)
	sw	s11, 40(sp)

	# Save arguments for multiple function calls
	mv	s0, a0	
	mv	s1, a1
	mv	s2, a2
	mv	s3, a3
	mv	s4, a4
	mv	s7, a5
	
	# Calculate sum of weights - equal to the window surface area
	mul	s11, a3, a4	# totalWeight = windowWidth * windowHeight
	srli	s11, s11, 8	# adjust fixed-point multiplication
	
	#
	# calculate weights and corner coordinates in source image and put on the stack
	#

	# downWeight, rowStart
	# t0 = row * windowHeight
	mul	t0, s1, s3
	# t1 = rowStart = floor(row*wH) (integer)
	srli	t1, t0, 8
	sw	t1, 20(sp)	# push rowStart
	# t1 = frac(row*wH)
	slli	t1, t0, 24
	srli	t1, t1, 24
	# t2 = downWeight = 1 - frac(row*wH)
	li	t2, 256		# t2 = 1.0 (fixed point)
	sub	t2, t2, t1
	sw	t2, 36(sp)	# push downWeight
	
	# upWeight, rowEnd
	# t1 = (row+1) * wh
	add	t1, t0, s3
	# t2 = rowEnd = floor( (row+1) * wH ) - 1 (integer)
	srli	t2, t1, 8
	addi	t2, t2, -1	
	sw	t2, 16(sp)	# push rowEnd
	# t1 = frac( (row+1)*wh )
	slli	t1, t1, 24
	srli	t1, t1, 24
	# set upWeight to 1.0 if frac( (row+1) * wh) == 0
	bnez	t1, skip1
	li	t1, 256		# 1.0 fixed point
skip1:	sw	t1, 32(sp)	# push upWeight

	# leftWeight, colStart
	# t0 = col * wW
	mul	t0, s2, s4
	# t1 = colStart = floor(col*wW) (integer)
	srli	t1, t0, 8
	sw	t1, 12(sp)	# push colStart
	# t1 = frac(col*wW)
	slli	t1, t0, 24
	srli	t1, t1, 24 
	li	t2, 256		# t2 = 1.0 (fixed point)
	# t2 = leftWeight = 1.0 - frac(col*wW)
	sub	t2, t2, t1
	sw	t2, 28(sp)	# push leftWeight
	
	#rightWeight, colEnd
	# t1 = (col+1) * wW
	add	t1, t0, s4
	# t2 = colEnd = floor( (col+1) * wW ) -1 (integer)
	srli	t2, t1, 8
	addi	t2, t2, -1
	sw	t2, 8(sp)	# push colEnd
	# t1 = frac( (col+1) * wW )
	slli	t1, t1, 24
	srli	t1, t1, 24
	# set rightWeight to 1.0 if t1 was 0
	bnez	t1, skip2
	li	t1, 256		# 1.0 fixed point
skip2:	sw	t1, 24(sp)	# push rightWeight

	# innerWidth = colEnd - colStart + 1 - 2
	lw	t0, 8(sp)	# colEnd
	lw	t1, 12(sp)	# colStart
	sub	t0, t0, t1
	addi	t0, t0, -1
	sw	t0, 4(sp)	# push innerWidth
	
	# innerHeight = rowEnd - rowStart + 1 - 2
	lw	t0, 16(sp)	# rowEnd
	lw	t1, 20(sp)	# rowStart
	sub	t0, t0, t1
	addi	t0, t0, -1
	sw	t0, (sp)	# push innerHeight

	# Read RGB values from source image, storing total weighted sum of each color
	# Source image pixels are divided into 9 categories with separate weights
	# 4 corners, horizontal edges (if innerWidth > 0), vertical edges (if innerHeight > 0), middle (if both innerHeight and innerWidth > 0)
	
	li	s8, 0	# total red value (fixed-point)
	li	s9, 0	# total green value (fixed-point)
	li	s10, 0	# total blue value (fixed-point)
	
	#
	# Corners
	#
	
	# lower left corner
	mv	a0, s0
	lw	a1, 20(sp)
	lw	a2, 12(sp)
	mv	a3, s7
	call 	getSourcePixel	# results in a0, a1, a2
	# t0 = weight = downWeight * leftWeight
	lw	t0, 28(sp)
	lw	t1, 36(sp)
	mul	t0, t0, t1
	srli	t0, t0, 8	# adjust fixed-point multiplication
	mul	t1, a0, t0	# integer * fixed-point - no need to adjust
	
	add	s8, s8, t1	# add weighted RGB values
	mul	t1, a1, t0
	add	s9, s9, t1
	mul	t1, a2, t0
	add	s10, s10, t1
	
	# lower right corner
	mv	a0, s0
	lw	a1, 20(sp)	# rowStart
	lw	a2, 8(sp)	# colEnd
	mv	a3, s7
	call 	getSourcePixel	# results in a0, a1, a2
	lw	t0, 36(sp)	# downWeight
	lw	t1, 24(sp)	# rightWeight
	mul	t0, t0, t1	# weight = downWeight * rightWeight
	srli	t0, t0, 8	# adjust fixed-point multiplixation

	mul	t1, t0, a0	# add weighted RGB values
	add	s8, s8, t1
	mul	t1, t0, a1
	add	s9, s9, t1
	mul	t1, t0, a2
	add	s10, s10, t1
	
	# upper left corner
	mv	a0, s0
	lw	a1, 16(sp)	# rowEnd
	lw	a2, 12(sp)	# colStart
	mv	a3, s7
	call	getSourcePixel	# results in a0, a1, a2
	lw	t0, 32(sp)	# upWeight
	lw	t1, 28(sp)	# leftWeight
	mul	t0, t0, t1	# weight = upWeight * leftWeight
	srli	t0, t0, 8	# adjust fixed-point multiplication
	
	mul	t1, t0, a0	# add weighted RGB values
	add	s8, s8, t1
	mul	t1, t0, a1
	add	s9, s9, t1
	mul	t1, t0, a2
	add	s10, s10, t1
	
	# upper right corner
	mv	a0, s0
	lw	a1, 16(sp)	# rowEnd
	lw	a2, 8(sp)	# colEnd
	mv	a3, s7
	call	getSourcePixel	# results in a0, a1, a2
	lw	t0, 32(sp)	# upWeight
	lw	t1, 24(sp)	# rightWeight
	mul	t0, t0, t1
	srli	t0, t0, 8
	
	mul	t1, t0, a0	# add weighted RB values
	add	s8, s8, t1
	mul	t1, t0, a1
	add	s9, s9, t1
	mul	t1, t0, a2
	add	s10, s10, t1
	
	#
	# Edges
	#
	
	# lower edge 
	lw	s6, 4(sp)	# innerWidth
	li	s2, 1		# colOffset
	beqz	s6, lowerEdgeLoopEnd	# skip if no lower edge
lowerEdgeLoop:
	mv	a0, s0
	lw	a1, 20(sp)	# row start
	lw	a2, 12(sp)	# col start
	add	a2, a2, s2	# col = colStart + colOffset
	mv	a3, s7
	call	getSourcePixel
	
	lw	t0, 36(sp)	# weight = downWeight
	mul	t1, a0, t0
	add	s8, s8, t1
	mul	t1, a1, t0
	add	s9, s9, t1
	mul	t1, a2, t0
	add	s10, s10, t1
	
	addi	s2, s2, 1
	ble	s2, s6, lowerEdgeLoop		# repeat for colOffset = 1..innerWidth
lowerEdgeLoopEnd:
	
	# upper edge
	li	s2, 1		# colOffset
	lw	s3, 32(sp)	# upWeight
	beqz	s6, upperEdgeLoopEnd	# skip if no upper edge
upperEdgeLoop:
	mv	a0, s0
	lw	a1, 16(sp)	# rowEnd
	lw	a2, 12(sp)	# colStart + colOffset
	add	a2, a2, s2
	mv	a3, s7
	call	getSourcePixel	# results in a0, a1, a2
	
	mul	t0, s3, a0	# add weighted RGB values
	add	s8, s8, t0
	mul	t0, s3, a1
	add	s9, s9, t0
	mul	t0, s3, a2
	add	s10, s10, t0
	
	addi	s2, s2, 1
	ble	s2, s6, upperEdgeLoop	# colOffset = 1..innerWidth
upperEdgeLoopEnd:
	
	# left edge
	li	s2, 1		# rowOffset
	lw	s3, 28(sp)	# leftWeight
	lw	s6, (sp)	# innerHeight
	beqz	s6, leftEdgeLoopEnd	# skip if no left edge
leftEdgeLoop:
	mv	a0, s0
	lw	a1, 20(sp)	# rowStart + rowOffset
	add	a1, a1, s2
	lw	a2, 12(sp)	# colStart
	mv	a3, s7
	call	getSourcePixel	# results in a0, a1, a2
	
	mul	t0, s3, a0	# add weighted RGB values
	add	s8, s8, t0
	mul	t0, s3, a1
	add	s9, s9, t0
	mul	t0, s3, a2
	add	s10, s10, t0
	
	addi	s2, s2, 1
	ble	s2, s6, leftEdgeLoop	# rowOffset = 1..innerHeight
leftEdgeLoopEnd:

	# right edge
	li	s2, 1		# rowOffset
	lw	s3, 24(sp)	# rightWeight
	beqz	s6, rightEdgeLoopEnd	# skip if no right edge
rightEdgeLoop:
	mv	a0, s0
	lw	a1, 20(sp)	# rowStart + rowOffset
	add	a1, a1, s2
	lw	a2, 8(sp)	# colEnd
	mv	a3, s7
	call	getSourcePixel	# results in a0, a1, a2
	
	mul	t0, s3, a0	# add weighted RGB values
	add	s8, s8, t0
	mul	t0, s3, a1
	add	s9, s9, t0
	mul	t0, s3, a2
	add	s10, s10, t0

	addi	s2, s2, 1
	ble	s2, s6, rightEdgeLoop
rightEdgeLoopEnd:
	
	#
	# middle
	# TODO: optimize
	lw	t0, 12(sp)	# colStart
	addi	s1, t0, 1	# col
	lw	t1, 4(sp)	# innerWidth
	add	s3, t0, t1	# colEnd = colStart + innerWidth
	
	lw	t0, 20(sp)	# rowStart
	addi	s2, t0, 1	# row
	lw	t1, (sp)	# innerHeight
	add	s4, t0, t1	# rowEnd = rowStart + innerHeight
	
	bgt	s1, s3  midRowLoopEnd	# skip if either equal to 0 - no middle part
	bgt	s2, s4, midRowLoopEnd
midRowLoop:
midColLoop:
	mv	a0, s0
	mv	a1, s2
	mv	a2, s1
	mv	a3, s7
	call	getSourcePixel	# results in a0, a1, a2
	
	slli	a0, a0, 8	# in fixed-point format
	slli	a1, a1, 8
	slli	a2, a2, 8
	add	s8, s8, a0	# add RGB values with weight 1.0
	add	s9, s9, a1
	add	s10, s10, a2
	
	addi	s1, s1, 1
	ble	s1, s3, midColLoop	# col = colStart+1..colEnd
midColLoopEnd:
	li	s1, 1
	addi	s2, s2, 1
	ble	s2, s4, midRowLoop	# row = rowStart+1..rowEnd
midRowLoopEnd:
	
	# Calculate weighted average of RGB values
	# sum of weights is equal to the window surface area windowWidth * windowHeight
	# result of fixed-point by fixed-point division is equal to floor of the result (integer), no need to adjust by shifting
	div	a0, s8, s11
	div	a1, s9, s11
	div	a2, s10, s11
	
	# Epilogue
	lw	s11, 40(sp)
	lw	s10, 44(sp)
	lw	s9, 48(sp)
	lw	s8, 52(sp)
	lw	s7, 56(sp)
	lw	s6, 60(sp)
	lw	s5, 64(sp)
	lw	s4, 68(sp)
	lw	s3, 72(sp)
	lw	s2, 76(sp)
	lw	s1, 80(sp)
	lw	s0, 84(sp)
	lw	ra, 88(sp)
	addi	sp, sp, 92
	ret
	
	
# Calculate number of padding bytes per row
# paddedRowSize = floor((bitsPerPixel * imageWidth + 31) / 32) * 4
# padding = paddedRowSize - pixelsPerRow * 3
# Arguments
# a0 - image width
# Returns
# a0 - number of padding bytes per row
calculatePadding:
	slli	t0, a0, 4
	slli	t1, a0, 3
	add	t0, t0, t1	# 24 * imageWidth = 16*imageWidth + 8*imageWidth
	addi	t0, t0, 31
	srli	t0, t0, 5	# floor((bitsPerPixel*imageWidth + 31) / 32)
	slli	t0, t0, 2	# *= 4
	slli	t1, a0, 1
	add	t1, t1, a0	# 3*imageWidth = 2*imageWidth + imageWidth
	sub	a0, t0, t1	# padding = paddedRowSize - 3*imageWidth
	ret

# Return RGB values of given source pixel
# translate given coordinates to account for padding
# Arguments
# a0 - sourcePointer
# a1 - soure row (integer)
# a2 - source column (integer)
# a3 - image width (integer) - to calculate padding
# Returns
# a0 - red (integer)
# a1 - green (integer)
# a2 - blue (integer)
getSourcePixel:
# Prologue
	addi	sp, sp, -8
	sw	ra, 4(sp)
	sw	s0, (sp)
	
	mv	s0, a0		# preserve sourcePtr
	
	mv	a0, a3
	call	calculatePadding	# a0 = paddingBytesPerRow
	
	# pixelOffset = srcRow * imageWidth + srcCol
	mul	t0, a1, a3
	add	t0, t0, a2
	#paddingOffset = paddingBytesPerRow * srcRow
	mul	t1, a0, a1
	# bytesOffset = (pixelOffset * 3) + paddingOffset
	slli	t2, t0, 1	# 2*pixelOffset
	add	t2, t2, t0	# 2*pixelOffset + pixelOffset
	add	t2, t2, t1	# 3*pixelOffset + paddingOffset
	# pixelPointer = sourcePtr + bytesOffset
	add	t0, s0, t2
	
	# load RGB
	lbu	a0, (t0)
	lbu	a1, 1(t0)
	lbu	a2, 2(t0)
	
	# Epilogue
	lw	s0, (sp)
	lw	ra, 4(sp)
	addi	sp, sp, 8
	ret

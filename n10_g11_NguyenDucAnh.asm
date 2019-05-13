.eqv IN_ADDRESS_HEXA_KEYBOARD 0xffff0012
.eqv OUT_ADDRESS_HEXA_KEYBOARD 0xffff0014
.eqv SEVENSEG_LEFT 0xFFFF0011
.eqv SEVENSEG_RIGHT 0xFFFF0010
.eqv NUMBER_LENGTH 2	#number of digits stored before discarding oldest one for the newest one
.eqv MASK_CAUSE_KEYMATRIX 0x00000800
.eqv MASK_OVERFLOW 0x00000030

.data
	First_Number: .space NUMBER_LENGTH
	Second_Number: .space NUMBER_LENGTH
	current_number: .space 1
	operator: .space 1
	clear_before_push: .space 1	# = 0 no effect, = 1 clear both segment, = 2 clear all data
	Message_multi_operator: .asciiz "you have already enter an operator"
	Message_equal_before_finish: .asciiz "you need to enter both number and an operator before enter equal"
	Message_invalid_operator: .asciiz "ivalid operator"
	Message_divide_by_zero: .asciiz "divide by zero error"
	Message_overflow: .asciiz "an operand or the result is overflow (max is 2,147,483,647)"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# MAIN Procedure
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.text
main:
	# init data and clear old input
	la $t0, clear_data
	jalr $t0
	nop

	# Enable the interrupt of Keyboard matrix 4x4 of Digital Lab Sim
	li $t1, IN_ADDRESS_HEXA_KEYBOARD
	li $t3, 0x80
	sb $t3, 0($t1)

	# Loop forever waiting for keyboard input
Loop: 	nop
	nop
	nop
	nop
	nop
	nop
	nop	
sleep: 	addi $v0, $0, 32	# v0 = 32
	li $a0, 300		# a0 = 300
	syscall			# syscall 32: sleep
	nop
	b Loop			# infinite loop
	nop
end_main:


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# GENERAL INTERRUPT
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.ktext 0x80000180
	# find out what kind of exception it is
	mfc0 $t0, $13
	li $t1, MASK_OVERFLOW
	and $t2, $t0, $t1
	beq $t2, $t1, overflow_exception
	nop
	
	li $t1, MASK_CAUSE_KEYMATRIX
	and $t2, $t0, $t1
	beq $t2, $t1, Keymatrix_Intr
	nop

	# end exception handler
end_exception:
	# return to start of the loop instead of where the interrupt occur, since the loop doesn't do meaningful thing
	la $s3, Loop
	mtc0 $s3, $14
	eret
	
overflow_exception:
	li $v0, 55
	la $a0, Message_overflow
	li $a1, 0
	syscall
	jal clear_data
	nop
	j end_exception
	nop

#----------------------------------------------------------------------
# interrupt handler for keymatrix
#---------------------------------------------------------------------
Keymatrix_Intr:
	# SAVE the current REG FILE to stack
	# Save $ra, $at, $v0, $a0, $s0, $s1, $s2, $s3
	addi $sp, $sp, -28
	sw $ra, 24($sp)
	sw $v0, 20($sp)
	sw $a0, 16($sp)
	sw $s0, 12($sp)
	sw $s1, 8($sp)
	sw $s2, 4($sp)
	sw $s3, 0($sp)
	
	#--------------------------------------------------------
	# Processing
	li $s0, IN_ADDRESS_HEXA_KEYBOARD
	li $s1, OUT_ADDRESS_HEXA_KEYBOARD
	
	# if the seven segments still display the previous expression
	lb $t0, clear_before_push
	bne $t0, 2, get_code
	nop
	sb $0, clear_before_push
	jal clear_data
	nop
	
	#----------------
	# scan keyboard
get_code:
	# scan row 1
	li $s2, 0x81
	sb $s2, 0($s0)
	lbu $a0, 0($s1)
	bne $a0, $0, process_input
	nop
	
	# scan row 2
	li $s2, 0x82
	sb $s2, 0($s0)
	lbu $a0, 0($s1)
	bne $a0, $0, process_input
	nop
	
	# scan row 3
	li $s2, 0x84
	sb $s2, 0($s0)
	lbu $a0, 0($s1)
	bne $a0, $0, process_input
	nop
	
	# scan row 4
	li $s2, 0x88
	sb $s2, 0($s0)
	lbu $a0, 0($s1)
	bne $a0, $0, process_input
	nop

	li $s2, 0x80
	sb $s2, 0($s0)

	#---------------
process_input:
	jal convert_to_number
	nop
	bge $v0, 0xa, process_operator
	nop
	
	# process number digit
	move $a0, $v0
	lbu $a1, current_number
	move $s2, $v1
	jal push_to_memory
	nop
	move $a0, $s2
	lbu $a1, clear_before_push
	jal push_to_seven_seg
	nop
	j finish_process
	nop

process_operator:
	# check e, e button does nothing
	beq $v0, 0x0e, finish_process
	nop
	beq $v0, 0x0f, process_equal
	nop
	lbu $s2, operator
	# if user already choose an operator, then throw an error message
	beq $s2, $0, process_operator__skip_error
	nop
	li $v0, 55
	la $a0, Message_multi_operator
	li $a1, 0
	syscall
	j finish_process
	nop
process_operator__skip_error:
	sb $v0, operator
	li $t1, 2
	sb $t1, current_number
	li $t1, 1
	sb $t1, clear_before_push
	j finish_process
	nop

process_equal:
	lbu $t1, current_number
	# throw error mes if user click equal before entering 2 number and an operator
	bgt $t1, 1, process_equal__skip_error
	nop
	li $v0, 55
	la $a0, Message_equal_before_finish
	li $a1, 0
	syscall
	j finish_process
	nop
process_equal__skip_error:	# Convert 2 number into correct form then calculating expression
	la $a0, First_Number
	li $a1, NUMBER_LENGTH
	jal get_number_from_bcd
	nop
	
	move $s2, $v0
	la $a0, Second_Number
	jal get_number_from_bcd
	nop
	
	move $a0, $s2
	move $a1, $v0
	lb $a2, operator
	jal compute_expression
	nop

	move $a0, $v0
	abs $a0, $a0
	li $a1, NUMBER_LENGTH
	jal get_last_2_digit_in_seven_seg_code
	nop
	
	move $s3, $v0
	move $a0, $v1
	li $a1, 0
	jal push_to_seven_seg
	nop
	move $a0, $s3
	li $a1, 0
	jal push_to_seven_seg
	nop
	li $t6, 2
	sb $t6, clear_before_push

	## RESTORE the REG FILE from STACK
finish_process:
	lw $ra, 24($sp)
	lw $v0, 20($sp)
	lw $a0, 16($sp)
	lw $s0, 12($sp)
	lw $s1, 8($sp)
	lw $s2, 4($sp)
	lw $s3, 0($sp)
	addi $sp, $sp, 28
	## return
	j end_exception
	nop

#------------------------------------------------------------------------
# Convert digital lab sim cell coordinate into number and seven seg code
# $a0: digital lab sim cell coordinate
# $v0: number
# $v1: seven seg code, or 0 if it is an operator
#------------------------------------------------------------------------
convert_to_number:
	li $v0, 0
	li $v1, 0x3f
	beq $a0, 0x11, convert_to_number_exit
	nop
	
	li $v0, 1
	li $v1, 0x06
	beq $a0, 0x21, convert_to_number_exit
	nop

	li $v0, 2
	li $v1, 0x5b
	beq $a0, 0x41, convert_to_number_exit
	nop

	li $v0, 3
	li $v1, 0x4f
	beq $a0, 0x81, convert_to_number_exit
	nop

	li $v0, 4
	li $v1, 0x66
	beq $a0, 0x12, convert_to_number_exit
	nop

	li $v0, 5
	li $v1, 0x6d
	beq $a0, 0x22, convert_to_number_exit
	nop

	li $v0, 6
	li $v1, 0x7d
	beq $a0, 0x42, convert_to_number_exit
	nop

	li $v0, 7
	li $v1, 0x07
	beq $a0, 0x82, convert_to_number_exit
	nop

	li $v0, 8
	li $v1, 0x7f
	beq $a0, 0x14, convert_to_number_exit
	nop

	li $v0, 9
	li $v1, 0x6f
	beq $a0, 0x24, convert_to_number_exit
	nop

	li $v0, 0x0a
	li $v1, 0
	beq $a0, 0x44, convert_to_number_exit
	nop

	li $v0, 0x0b
	li $v1, 0
	beq $a0, 0x84, convert_to_number_exit
	nop

	li $v0, 0x0c
	li $v1, 0
	beq $a0, 0x18, convert_to_number_exit
	nop

	li $v0, 0x0d
	li $v1, 0
	beq $a0, 0x28, convert_to_number_exit
	nop

	li $v0, 0x0e
	li $v1, 0
	beq $a0, 0x48, convert_to_number_exit
	nop

	li $v0, 0x0f
	li $v1, 0
	beq $a0, 0x88, convert_to_number_exit
	nop
	
convert_to_number_exit:
	jr $ra
	nop

#------------------------------------------------------------------------
# push number digit to space in data segment
# $a0: number digit
# $a1: number 1 or 2, indicate current input operand
# affected register: t0, t1, t2, t3, t4
#------------------------------------------------------------------------
push_to_memory:
	# get the current input number
	beq $a1, 2, load_second_space
	nop
	la $t0, First_Number
	j shift_end_all_digit
	nop
load_second_space:
	la $t0, Second_Number
	
	# shift to the end all digit in the array space, creating new place at the start
	# discard last digit
shift_end_all_digit:
	li $t1, NUMBER_LENGTH
	addi $t1, $t1, -1
shift_loop:
	add $t2, $t0, $t1	# t2 = add[t1]
	
	addi $t3, $t1, -1	# t3 = t1 - 1
	add $t3, $t0, $t3	# t3 = add[t3]
	
	lb $t4, ($t3)		# t4 = number[t1 - 1]
	sb $t4, ($t2)		# number[t1] = t4
	
	addi $t1, $t1, -1
	bne $t1, 0, shift_loop	# loop if $t1 > 0
	nop
	
	# store the new digit in a0 to the start of the array space
	sb $a0, ($t0)		# number[0] = a0
	jr $ra
	nop
	
#------------------------------------------------------------------------
# display new digit in seven seg display, push old one to the left
# $a0: number digit in seven seg code
# $a1: = 1 will clear the 2 segments before push new digit, = 0 will have no effect
# affected register:
#------------------------------------------------------------------------
push_to_seven_seg:
	li $t0, SEVENSEG_LEFT
	li $t1, SEVENSEG_RIGHT
	
	bne $a1, $0, push_to_seven_seg__clear
	nop
	
	lb $t2, ($t1)
	sb $t2, ($t0)	# move digit in right display to left display
	j push_to_seven_seg__next
	nop
	
push_to_seven_seg__clear:
	sb $0, ($t0)
	sb $0, clear_before_push
	
push_to_seven_seg__next:
	sb $a0, ($t1)
	jr $ra
	nop
	
#------------------------------------------------------------------------------------------
# convert array in data segment into number, overflow if it could not fit into one register
# $a0: the starting address
# $a1: the length of the segment
# $v0: the number
#------------------------------------------------------------------------------------------
get_number_from_bcd:
	addi $t0, $0, 0
	addi $t1, $0, NUMBER_LENGTH
	addi $t1, $t1, -1
	addi $t5, $0, -1
get_number_from_bcd__loop:
	beq $t1, $t5, get_number_from_bcd__exit_loop
	nop
	add $t2, $a0, $t1
	lbu $t2, ($t2)		# t2 = add[t1]
	mul $t3, $t0, 10
	# check overflow
	blt $t3, 0, overflow_exception
	nop
	add $t0, $t3, $t2
	addi $t1, $t1, -1
	j get_number_from_bcd__loop
	nop
get_number_from_bcd__exit_loop:
	move $v0, $t0
	jr $ra
	nop

#------------------------------------------------------------------------------------------
# compute expression
# $a0: the 1st number
# $a1: the 2nd number
# $a2: the operator
# $v0: the result
# $v1: upper 32 bit for multiplication and remainder for division
# exeption: overflow, divide by 0
#------------------------------------------------------------------------------------------
compute_expression:
	# save register: $ra, $a0
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	beq $a2, 0xa, compute_addition
	nop
	beq $a2, 0xb, compute_subtraction
	nop
	beq $a2, 0xc, compute_multiplication
	nop
	beq $a2, 0xd, compute_division
	nop
	
	li $v0, 55
	la $a0, Message_invalid_operator
	li $a1, 0
	syscall
	j compute_expression__end
	nop
	
compute_addition:
	add $v0, $a0, $a1
	j compute_expression__end
	nop

compute_subtraction:
	sub $v0, $a0, $a1
	j compute_expression__end
	nop
	
compute_multiplication:
	mul $v0, $a0, $a1
	mfhi $v1
	bne $v1, $0, overflow_exception
	nop
	j compute_expression__end
	nop

compute_division:
	bne $a1, $0, divide_not_by_zero
	nop
	li $v0, 55
	la $a0, Message_divide_by_zero
	li $a1, 0
	syscall
	jal clear_data
	nop
	lw $ra, 0($sp)
	addi, $sp, $sp, 4
	j finish_process
	nop
divide_not_by_zero:
	div $a0, $a1
	mflo $v0
	mfhi $v1
	
compute_expression__end:
	# logging
	move $a3, $v0
	jal logging_expression
	nop
	
	# restore and return
	lw $ra, 0($sp)
	addi, $sp, $sp, 4
	jr $ra
	nop

#------------------------------------------------------------------------------------------
# get the last 2 digits in seven segment code of the input number
# $a0: the input number
# $a1: the number of digit
# $v0: the code of the least significant digit
# $v1: the code of the second least significant digit
#------------------------------------------------------------------------------------------
get_last_2_digit_in_seven_seg_code:
	# save register: $ra, $a0
	addi $sp, $sp, -8
	sw $ra, 4($sp)
	sw $a0, 0($sp)
	
	li $t0, 100
	div $a0, $t0	
	mfhi $t1	# t1 = a0 % 100
	
	li $t0, 10
	div $t1, $t0
	mflo $a0	# a0 = second least siginificant digit
	mfhi $t2	# t2 = least significant digit
	
	jal get_seven_seg_code
	nop
	move $t1, $v0
	move $a0, $t2
	jal get_seven_seg_code
	nop
	move $v1, $t1
	
	# restore and return
	lw $ra, 4($sp)
	lw $a0, 0($sp)
	addi, $sp, $sp, 8
	jr $ra
	nop

#------------------------------------------------------------------------------------------
# clear all data for the fresh new calculation
#------------------------------------------------------------------------------------------
clear_data:
	la $t0, First_Number
	la $t1, Second_Number
	
	addi $t2, $0, 0
clear_data__loop:
	beq $t2, NUMBER_LENGTH, clear_data__end_loop
	
	add $t3, $t2, $t0
	add $t4, $t2, $t1
	sb $0, ($t3)
	sb $0, ($t4)
	
	addi $t2, $t2, 1
	j clear_data__loop
	nop
clear_data__end_loop:
	li $t2, 1
	sb $t2, current_number
	sb $0, operator
	sb $0, clear_before_push
	
	li $t1, SEVENSEG_LEFT
	sb $0, 0($t1)
	li $t1, SEVENSEG_RIGHT
	sb $0, 0($t1)
	
	jr $ra
	nop

#------------------------------------------------------------------------
# Convert number into seven seg code
# $a0: number
# $v0: seven seg code
#------------------------------------------------------------------------
get_seven_seg_code:
	li $v0, 0x3f
	beq $a0, 0, get_seven_seg_code__exit
	nop
	
	li $v0, 0x06
	beq $a0, 1, get_seven_seg_code__exit
	nop

	li $v0, 0x5b
	beq $a0, 2, get_seven_seg_code__exit
	nop

	li $v0, 0x4f
	beq $a0, 3, get_seven_seg_code__exit
	nop

	li $v0, 0x66
	beq $a0, 4, get_seven_seg_code__exit
	nop

	li $v0, 0x6d
	beq $a0, 5, get_seven_seg_code__exit
	nop

	li $v0, 0x7d
	beq $a0, 6, get_seven_seg_code__exit
	nop

	li $v0, 0x07
	beq $a0, 7, get_seven_seg_code__exit
	nop

	li $v0, 0x7f
	beq $a0, 8, get_seven_seg_code__exit
	nop

	li $v0, 0x6f
	beq $a0, 9, get_seven_seg_code__exit
	nop
	
get_seven_seg_code__exit:
	jr $ra
	nop

#------------------------------------------------------------------------
# Log the expression to console for debugging
# $a0: 1st number
# $a1: 2nd number
# $a2: operator
# $a3: result
#------------------------------------------------------------------------
logging_expression:
	# save register: $ra, $v0
	addi $sp, $sp, -8
	sw $ra, 4($sp)
	sw $v0, 0($sp)

	# log expression
	move $t0, $a0
	move $t1, $a1
	move $t2, $a2
	move $t3, $a3
	li $v0, 1
	move $a0, $t0
	syscall
	
	li $v0, 11
	li $a0, '+'
	beq $t2, 0x0a, logging_cont
	nop
	li $a0, '-'
	beq $t2, 0x0b, logging_cont
	nop
	li $a0, '*'
	beq $t2, 0x0c, logging_cont
	nop
	li $a0, '/'
	beq $t2, 0x0d, logging_cont
	nop
logging_cont:
	syscall
	
	li $v0, 1
	move $a0, $t1
	syscall
	
	li $v0, 11
	li $a0, '='
	syscall
	
	li $v0, 1
	move $a0, $t3
	syscall
	
	li $v0, 11
	li $a0, '\n'
	syscall
	
	# restore
	lw $ra, 4($sp)
	lw $v0, 0($sp)
	addi $sp, $sp, 8

	jr $ra
	nop

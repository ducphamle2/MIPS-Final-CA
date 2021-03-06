.eqv SEVENSEG_LEFT    0xFFFF0011 	# LED LEFT 
.eqv SEVENSEG_RIGHT   0xFFFF0010 	# LED RIGHT 
.eqv KEY_CODE   0xFFFF0004         	# ASCII code from keyboard, 1 byte 
.eqv KEY_READY  0xFFFF0000        	# =1 if has a new keycode                                  
				        # Auto clear after lw  
.eqv DISPLAY_CODE   0xFFFF000C   	# ASCII code to show, 1 byte 
.eqv DISPLAY_READY  0xFFFF0008   	# =1 if the display has already to do  
	                                # Auto clear after sw  

.eqv MASK_CAUSE_KEYBOARD 0x0000034 	# Keyboard Cause
.eqv SLEEP_TIME 500			# sleep time for custom sleep counter
.eqv STR_LEN 24				# string length of the source string
.eqv DIVIDER 10				# 10 is used to divide the total correct characters
  
.data 
LEDAscii     : .byte 63,6,91,79,102,109,125,7,127,111 # this is the decimal representation of numbers from 0 to 9 for 7 segments. 63 is 0 and 111 is 9 
storestring : .space 1000			# maximum 25 words to store in this array
stringsource : .asciiz "Bo mon ky thuat may tinh" 
numCorrectChar: .asciiz  "\n The number of matched characters: "  
notification: .asciiz "\n Continue using or quit? "
testing: .asciiz "\n length of the typed string: "
string: .asciiz "\n String: "
startMain: .asciiz "\n Start main. "
startReadingKey: .asciiz "\n Start reading key. "

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
# MAIN Procedure
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
.text
	li   	$k0,  KEY_CODE              
	li   	$k1,  KEY_READY                    
	li   	$s0, DISPLAY_CODE              
	li   	$s1, DISPLAY_READY
MAIN:         
	li 	$s4,0 			# length of storestring later on
	li 	$t9,DIVIDER
	
	li 	$v0, 4
	la 	$a0, startMain
	syscall
	nop
	
	li	$s6, 0			# flag var to turn on / off ask loop
	li	$t3, 0			# the number of matched characters 
	li	$s7, 0			# count time
LOOP: 
	nop
WAIT_FOR_KEY:
	lb 	$t5, 0($k1)		# check if a key is pressed or not
	beq	$t5, $zero, CHECK	# if no key then we check condition
	nop
	
READ_KEY:  
	lb   	$t0, 0($k0)            	# $t0 = [$k0] = KEY_CODE. Here we use lb for efficient data storage because ASCII only goes to 127 max, which is 8 bits
                           
SHOW_KEY: 
	sb 	$t0, 0($s0)             # show the input key when key ready has a signal 1 on MMIO
	la  	$s5,storestring		# the address of our input string is stored in $s5
       	add 	$s5,$s5,$s4		
        sb 	$t0,0($s5)		# store the input key into the string
       	addi 	$s4,$s4,1		# i = i + 1 so
        nop
			
CHECK:
	addi	$s7, $s7, 1		# increase time by one
	teqi	$s7, SLEEP_TIME		# if finish 500 get into interrupt
SLEEP:  
	addi    $v0,$zero,32            # sleep service, just to get back to loop, used to avoid some unpexpected bugs
	li      $a0, 5              	# $a0 = sleep length, which is 5ms in this case         
	syscall         
	nop           	          	# WARNING: nop is mandatory here.                   
	j       LOOP          	 	# Loop
	j	LOOP
	
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# INTERRUPT SERVICE
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
.ktext    0x80000180         		# this will always be called when it comes to interrupt.

IntSR: 	#--------------------------------------------------------
	# Temporary disable interrupt
	#--------------------------------------------------------
dis_int:
	mfc0  	$t1, $13                # the cause of interrupt is stored inside $t1

KEYBOARD:
	li 	$t2, MASK_CAUSE_KEYBOARD
	and 	$at, $t1, $t2
	beq	$at, $t2, END	
	nop              
	j	END_PROCESS
END:	#PRINTING
	li 	$v0,11         
	li 	$a0,'\n'         	# new line
	syscall 
	li 	$v0, 4
	la 	$a0, testing
	syscall
	li 	$v0, 1
	add 	$a0, $s4, $zero
	syscall
	li 	$v0, 4
	la 	$a0, string
	syscall
	li 	$v0, 4
	la 	$a0, storestring
	syscall
	li 	$v0,11         
	li 	$a0,'\n'         	# new line
	syscall 
	nop
	li 	$t1,0 			# $t1 - increment index when looping
	li 	$t3,0                   # stores the number of correct characters
	li 	$t8,STR_LEN		# Length of the sourcestring.
	beq 	$s4, 0, PRINT
	nop
	slt 	$t7,$s4,$t8		# We compare two lengths: sourcestring and storestring
					# We get the smaller length.
	bne 	$t7,1, CHECK_STRING	# If $s4 > $t8 then we use $t8 as the length
	nop
	add 	$t8,$0,$s4		# If not we set $s4 as $t8, so we only need to use $t8 as our final length everytime
	
CHECK_STRING:				# when the original string has a greater length
	la 	$t2,storestring		# handle the typed string
	add 	$t2,$t2,$t1
	lb 	$t5,0($t2)		# The character index i of storestring will be compared with the character at index i of sourcestring
	
	la 	$t4,stringsource	# handle the source string
	add 	$t4,$t4,$t1
	lb 	$t6,0($t4)		# extract the character of source string at index i
	
	bne 	$t6, $t5, CONTINUE	# if they are not similar then we skip increment of corrected characters
	
	nop
	addi 	$t3,$t3,1		# if it is similar then we increase the counting register by one
CONTINUE: 
	addi 	$t1,$t1,1		# increase i to continue looping 
	beq 	$t1,$t8,PRINT		# if i reach the length of the string we are looping then we stop
	nop
	j 	CHECK_STRING		# Continue checking if we havent finished
PRINT:	li 	$v0,4
	la 	$a0,numCorrectChar
	syscall
	
	li 	$v0,1
	li 	$a0, 0
	add 	$a0, $a0, $t3
	syscall
	
DISPLAY_DIGITAL:
	li	$t9, DIVIDER		# set t9 to 10 for certainty that it is 10 to divide 
	div 	$t3,$t9			# divide by 10. If the total is >= 100 then it will be wrong
	mflo 	$t8			# quotient at the left LED
	la 	$s2,LEDAscii		# store the address of the array containing the values of 7 segment numbers
	add 	$s2,$s2,$t8		# get the correct address of the value we want
	lb 	$a0,0($s2)              # get that value
	jal   	SHOW_7SEG_LEFT       	# show it on Digital Lab
#------------------------------------------------------------------------
	mfhi 	$t7			# the right side similar with remainder
	la 	$s2,LEDAscii			
	add 	$s2,$s2,$t7
	lb 	$a0,0($s2)              # set value for segments           
	jal  	SHOW_7SEG_RIGHT      	# show    
#------------------------------------------------------------------------                                            
	li	$s6, 1			# turn on ask loop
	
	beq	$s4, 0, END_PROCESS	# if we have no storestring then we skip looping
	nop
	li 	$t3, 0			# used for index in small loop function
	nop
SMALL_LOOP:
	li	$s6, 0			# used as a value to clean buffer
	la	$s5, storestring
	add	$s5, $s5, $t3
	sb	$s6, 0($s5)		# set the whole string to 0
	add	$t3, $t3, 1		# increase index
	bne	$t3, $s4, SMALL_LOOP	# finish when i = n
	nop
	li	$s6, 1
	j	END_PROCESS
	nop		
SHOW_7SEG_LEFT:  
	li   	$t0,  SEVENSEG_LEFT 	# assign port's address                   
	sb   	$a0,  0($t0)        	# assign new value                    
	jr   	$ra 
	
SHOW_7SEG_RIGHT: 
	li   	$t0,  SEVENSEG_RIGHT 	# assign port's address                  
	sb   	$a0,  0($t0)         	# assign new value                   
	jr   	$ra 

END_PROCESS:				.
	mtc0 $zero, $13			# need to clear the cause of interrupt here ($13 = 0)
	
	
	beq	$s6, 1, ASK_LOOP	
	nop
# Evaluate the return address of main routine
# epc <= epc + 4
#--------------------------------------------------------
NEXT_PC:   
	mfc0    $at, $14	        # $at <= Coproc0.$14 = Coproc0.epc              
	addi    $at, $at, 4	        # $at = $at + 4 (next instruction)              
        mtc0    $at, $14	       	# Coproc0.$14 = Coproc0.epc <= $at
        nop
        
RETURN:   
	eret                       	# return to the next instruction after interrupt
	nop

ASK_LOOP: 
	li $v0, 50
	la $a0, notification
	syscall
	beq $a0,0,RESET_DATA		
	nop
	j EXIT
RESET_DATA:	
	li	$t3, 0			# reset corrected counter register
	li	$v0, 32			# change back to sleep service due to strange bug
	li 	$s4, 0			# reset index
	li	$s6, 0			# reset ask loop
	li	$s7, 0			# reset
	j	NEXT_PC

EXIT:
	li $v0, 10
	syscall

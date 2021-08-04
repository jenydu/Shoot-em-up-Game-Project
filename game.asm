#####################################################################
#
# CSC258 Summer 2021 Assembly Final Project
# University of Toronto
#
# Student: Name, Student Number, UTorID
#	Stanley Bryan Z. Hua, 1005977267, huastanl
#	Jun Ni Du, 1006217130, dujun1
#
# Bitmap Display Configuration:
# - Unit width in pixels: 4
# - Unit height in pixels: 4
# - Display width in pixels: 1024
# - Display height in pixels: 1024
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1 (choose the one that applies)
#
# Which approved features have been implemented for milestone 3?
# (See the assignment handout for the list of additional features)
# 1. (fill in the feature, if any)
# 2. (fill in the feature, if any)
# 3. (fill in the feature, if any)
# ... (add more if necessary)
#
# Link to video demonstration for final submission:
# - (insert YouTube / MyMedia / other URL here). Make sure we can view it!
#
# Are you OK with us sharing the video with people outside course staff?
# - yes / no / yes, and please share this project github link as well!
#
# Any additional information that the TA needs to know:
# - press 'g' to directly enter Game Over Loop
#
#####################################################################
#_________________________________________________________________________________________________________________________
# ==CONSTANTS==:
.eqv UNIT_WIDTH 4
.eqv UNIT_HEIGHT 4

.eqv column_increment 4			# 4 memory addressess will always refer to 1 unit (32 bits or 4 bytes)
.eqv row_increment 1024			# [(display_row) / UNIT_HEIGHT] * column_increment

.eqv column_max 1024			# column_increment * (display_column) / UNIT_WIDTH			# NOTE: Always equal to row_increment
.eqv row_max 262144			# row_increment * (display_row) / UNIT_HEIGHT

.eqv plane_center 15360			# offset for center of plane. = 15 bytes * row_increment

.eqv display_base_address 0x10008000		# display base address
.eqv object_base_address 0x1000C82C		# starting point for all objects and plane
#___________________________________________________________________________________________________________________________
# ==VARIABLES==:
.data
displayAddress: 	.word 0x10008000

#___________________________________________________________________________________________________________________________
.text
# ==MACROS==:
	# MACRO: Store mem. address difference of unit's row from the center
		# used in in LOOP_PLANE_ROWS
	.macro set_row_incr(%y)
		# temporarily store row_increment and y-unit value
		addi $t8, $0, row_increment
		addi $t9, $0, %y
		mult $t8, $t9
		mflo $t5				# $t5 = %y * row_increment		(lower 32 bits)
	.end_macro
	# MACRO: Check whether to color normally or black. Update $t1 accordingly.
		# $t1: contains color to be painted
		# $a1: boolean to determine if color $t1 or black.
		# NOTE: $t1 == $t1 if $a1 == 1. Otherwise, $t1 == 0.
	.macro check_color
		mult $a1, $t1
		mflo $t1
	.end_macro
	# MACRO: Updates $s0, $s3-4 for painting.
		# $s0: will hold %color
		# $s3: will hold start_idx
		# $s4: will hold end_idx
	.macro setup_general_paint (%color, %start_idx, %end_idx, %label)
		addi $s0, $0, %color		# change current color
		addi $s3, $0, %start_idx	# paint starting from column /row___
		addi $s4, $0, %end_idx		# ending at column/row ___
		jal %label			# jump to %label to paint
	.end_macro
	# MACRO: Push / Store value in register $reg to stack
	.macro push_reg_to_stack ($reg)
		addi $sp, $sp, -4			# decrement by 4
		sw $reg, ($sp)				# store register at stack pointer
	.end_macro
	# MACRO: Pop / Load value from stack to register $reg
	.macro pop_reg_from_stack ($reg)
		lw $reg, ($sp)				# load stored value from register
		addi $sp, $sp, 4			# de-allocate space;	increment by 4
	.end_macro

	# MACRO: Get column and row index from current base address
		# Inputs
			# $address: register containing address
			# $col_store: register to store column index
			# $row_store: register to store row index
		# Registers Used
			# $s1-2: for temporary operations

	.macro calculate_indices ($address, $col_store, $row_store)
		# Store curr. $s0-1 values in stack.
		push_reg_to_stack ($s1)
		push_reg_to_stack ($s2)

		# Calculate indices
		subi $s1, $address, display_base_address	# subtract base display address (0x10008000)
		addi $s2, $zero, row_increment
		div $s1, $s2				# divide by row increment
		mflo $row_store				# quotient = row index
		
		addi $s2, $zero, column_increment
		mfhi $s1				# store remainder back in $s1. NOTE: remainder = column_increment * column index
		div $s1, $s2				# divide by column increment
		mflo $col_store				# quotient = column index
		
		# Restore $s0-1 values from stack.
		pop_reg_from_stack ($s2)
		pop_reg_from_stack ($s1)
	.end_macro
	
	# MACRO: Compute boolean if pixel indices stored in registers $col_index and $row_index are within the border.
		# Inputs
			# $col: register containing column index
			# $row: register containing row index
			# $bool_store: register to store boolean output
		# Registers Used
			# $s0-2: used in logical operations
	.macro within_borders($col, $row, $bool_store)
		# Store current values of $s0-2 to stack
		push_reg_to_stack ($s0)
		push_reg_to_stack ($s1)
		push_reg_to_stack ($s2)
		# Column index in (11, 216)
		sgt $s0, $col, 11
		slti $s1, $col, 216
		and $s2, $s0, $s1			# 11 < col < 216
		# Row index in (18, 206)
		sgt $s0, $row, 18
		slti $s1, $row, 206
		and $bool_store, $s0, $s1		# 18 < row < 206
		and $bool_store, $bool_store, $s2	# make sure both inequalities are true
		# Restore $s0-1 values from stack.
		pop_reg_from_stack ($s2)
		pop_reg_from_stack ($s1)
		pop_reg_from_stack ($s0)
	.end_macro
#___________________________________________________________________________________________________________________________
# ==INITIALIZATION==:
INITIALIZE:

# ==PARAMETERS==:
addi $s0, $0, 3					# starting number of hearts

# ==SETUP==:
# Paint Border
jal PAINT_BORDER
# Paint Health
jal UPDATE_HEALTH
# Paint Plane
addi $a1, $zero, 1				# set to paint
addi $a0, $0, object_base_address		# start painting plane from top-left border
addi $a0, $a0, 96256				# center plane
push_reg_to_stack ($a0)				# store current plane address in stack
jal PAINT_PLANE					# paint plane at $a0

#---------------------------------------------------------------------------------------------------------------------------
GENERATE_OBSTACLES:
	# Used Registers:
		# $a0-2: parameters for PAINT_OBJECT
	# Outputs:
		# $s5: holds obstacle 1 base address
		# $s6: holds obstacle 2 base address
		# $s7: holds obstacle 3 base address
	# Obstacle 1
	jal RANDOM_OFFSET			# create random address offset
	add $s5, $v0, object_base_address	# store obstacle address = object_base_address + random offset
	add $a0, $s5, $0			# PAINT_OBJECT param. Load obstacle address
	addi $a1, $0, 1				# PAINT_OBJECT param. Set to paint
	add $a2, $0, 0				# PAINT_OBJECT param. 0 offset
	jal PAINT_OBJECT
	
	# Obstacle 2
	jal RANDOM_OFFSET			# create random address offset
	add $s6, $v0, object_base_address	# store obstacle address = object_base_address + random offset
	add $a0, $s6, $0			# PAINT_OBJECT param. Load obstacle address
	addi $a1, $0, 1				# PAINT_OBJECT param. Set to paint
	add $a2, $0, 0				# PAINT_OBJECT param. 0 offset
	jal PAINT_OBJECT
	
	# Obstacle 3
	jal RANDOM_OFFSET			# create random address offset
	add $s7, $v0, object_base_address		# store obstacle address = object_base_address + random offset
	add $a0, $s7, $0			# PAINT_OBJECT param. Load obstacle address
	addi $a1, $0, 1				# PAINT_OBJECT param. Set to paint
	add $a2, $0, 0				# PAINT_OBJECT param. 0 offset
	jal PAINT_OBJECT
	
#---------------------------------------------------------------------------------------------------------------------------
pop_reg_from_stack ($a0)			# restore current plane address from stack

# main game loop
MAIN_LOOP:

	AVATAR_MOVE:
		jal PAINT_PLANE
		jal check_key_press		# check for keyboard input and redraw avatar accordingly

	OBSTACLE_MOVE:
		push_reg_to_stack ($a0)	
	move_obs_1:
		addi $a0, $s5, 0			# PAINT_OBJECT param. Load obstacle 1 base address
		addi $a1, $zero, 0			# PAINT_OBJECT param. Set to erase
		add $a2, $0, 0				# PAINT_OBJECT param. 0 offset
		jal PAINT_OBJECT			
		
		calculate_indices ($s5, $t5, $t6)	# calculate column and row index
		ble $t5, 11, regen_obs_1
		
		subu $s5, $s5, 4			# shift obstacle 1 unit left
		add $a0, $s5, $0 			# PAINT_OBJECT param. Load obstacle 1 new base address
		addi $a1, $zero, 1			# PAINT_OBJECT param. Set to paint
		add $a2, $0, 0				# PAINT_OBJECT param. 0 offset
		jal PAINT_OBJECT  
	
	move_obs_2:
		addi $a0, $s6, 0			# PAINT_OBJECT param. Load obstacle 1 base address
		addi $a1, $0, 0			# PAINT_OBJECT param. Set to erase
		add $a2, $0, 0				# PAINT_OBJECT param. 0 offset
		jal PAINT_OBJECT			
		
		calculate_indices ($s6, $t5, $t6)	# calculate column and row index
		ble $t5, 11, regen_obs_2
		
		subu $s6, $s6, 4			# shift obstacle 1 unit left
		add $a0, $s6, $0 			# PAINT_OBJECT param. Load obstacle 1 new base address
		addi $a1, $0, 1				# PAINT_OBJECT param. Set to paint
		add $a2, $0, 0				# PAINT_OBJECT param. 0 offset
		jal PAINT_OBJECT  
	
	move_obs_3:
		addi $a0, $s7, 0			# PAINT_OBJECT param. Load obstacle 1 base address
		addi $a1, $0, 0			# PAINT_OBJECT param. Set to erase
		add $a2, $0, 0				# PAINT_OBJECT param. 0 offset
		jal PAINT_OBJECT			
		
		calculate_indices ($s7, $t5, $t6)	# calculate column and row index
		ble $t5, 11, regen_obs_3
		
		subu $s7, $s7, 4			# shift obstacle 1 unit left
		add $a0, $s7, $0			# PAINT_OBJECT param. Load obstacle 1 new base address
		addi $a1, $0, 1				# PAINT_OBJECT param. Set to paint
		add $a2, $0, 0				# PAINT_OBJECT param. 0 offset
		jal PAINT_OBJECT 
	
	EXIT_OBSTACLE_MOVE:	
		pop_reg_from_stack ($a0)

	j MAIN_LOOP				# repeat loop
#---------------------------------------------------------------------------------------------------------------------------
END_SCREEN_LOOP:
	jal CLEAR_SCREEN			# reset to black screen
	jal PAINT_GAME_OVER			# create game over screen
	monitor_end_key:
		# Monitor p or q key press
		lw $t8, 0xffff0000		# load the value at this address into $t8
		lw $t4, 0xffff0004		# load the ascii value of the key that was pressed
		
		beq $t4, 0x70, respond_to_p	# restart game when 'p' is pressed
		beq $t4, 0x71, respond_to_q	# exit game when 'q' is pressed
		j monitor_end_key		# keep monitoring for key response until one is chosen

# Tells OS the program ends
EXIT:	li $v0, 10
	syscall
#___________________________________________________________________________________________________________________________
regen_obs_1:	
	jal RANDOM_OFFSET			# create random address offset
	addi $s5, $v0, object_base_address	# store obstacle address = object_base_address + random offset
	add $a0, $s5, $0			# PAINT_OBJECT param. Load obstacle address
	addi $a1, $0, 1				# PAINT_OBJECT param. Set to paint
	add $a2, $0, 0				# PAINT_OBJECT param. 0 offset
	jal PAINT_OBJECT
	j move_obs_2
regen_obs_2:
	jal RANDOM_OFFSET			# create random address offset
	addi $s6, $v0, object_base_address	# store obstacle address = object_base_address + random offset
	add $a0, $s6, $0			# PAINT_OBJECT param. Load obstacle address
	addi $a1, $0, 1				# PAINT_OBJECT param. Set to paint
	add $a2, $0, 0				# PAINT_OBJECT param. 0 offset
	jal PAINT_OBJECT
	j move_obs_3
regen_obs_3:	
	jal RANDOM_OFFSET			# create random address offset
	addi $s7, $v0, object_base_address	# store obstacle address = object_base_address + random offset
	add $a0, $s7, $0			# PAINT_OBJECT param. Load obstacle address
	addi $a1, $0, 1				# PAINT_OBJECT param. Set to paint
	add $a2, $0, 0				# PAINT_OBJECT param. 0 offset
	jal PAINT_OBJECT
	j EXIT_OBSTACLE_MOVE

#___________________________________________________________________________________________________________________________
# ==FUNCTIONS==:
# FUNCTION: PAINT PLANE
	# Inputs
		# $a0: stores base address for plane
		# $a1: If 0, paint plane in black. Elif 1, paint plane in normal colors.
	# Registers Used
		# $t1: stores current color value
		# $t2: temporary memory address storage for current unit (in bitmap)
		# $t3: column index for 'for loop' LOOP_PLANE_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $t4: row index for 'for loop' LOOP_PLANE_ROWS
		# $t5: parameter for subfunction LOOP_PLANE_ROWS. Will store # rows to paint from the center row outwards
		# $t8-9: used for multiplication operations
PAINT_PLANE:
	# Store used registers to stack
	# Store current state of used registers
	push_reg_to_stack ($t1)
	push_reg_to_stack ($t2)
	push_reg_to_stack ($t3)
	push_reg_to_stack ($t4)
	push_reg_to_stack ($t5)
	push_reg_to_stack ($t8)
	push_reg_to_stack ($t9)

	# Initialize registers
	add $t1, $0, $0				# initialize current color to black
	add $t2, $0, $0				# holds temporary memory address
	add $t3, $0, $0				# holds 'column for loop' indexer
	add $t4, $0, $0				# holds 'row for loop' indexer

	# FOR LOOP (through the bitmap columns)
	LOOP_PLANE_COLS: bge $t3, 112, EXIT_PLANE_PAINT	# repeat loop until column index = column 28 (112)
		add $t4, $0, $0			# reinitialize t4; index for LOOP_PLANE_ROWS

		# SWITCH CASES: paint in row based on column value
		beq $t3, 0, PLANE_COL_0
		beq $t3, 4, PLANE_COL_1_2
		beq $t3, 8, PLANE_COL_1_2
		beq $t3, 12, PLANE_COL_3
		beq $t3, 16, PLANE_COL_4_7
		beq $t3, 20, PLANE_COL_4_7
		beq $t3, 24, PLANE_COL_4_7
		beq $t3, 28, PLANE_COL_4_7
		beq $t3, 32, PLANE_COL_8_13
		beq $t3, 36, PLANE_COL_8_13
		beq $t3, 40, PLANE_COL_8_13
		beq $t3, 44, PLANE_COL_8_13
		beq $t3, 48, PLANE_COL_8_13
		beq $t3, 52, PLANE_COL_8_13
		beq $t3, 56, PLANE_COL_14
		beq $t3, 60, PLANE_COL_15_18
		beq $t3, 64, PLANE_COL_15_18
		beq $t3, 68, PLANE_COL_15_18
		beq $t3, 72, PLANE_COL_15_18
		beq $t3, 76, PLANE_COL_19_21
		beq $t3, 80, PLANE_COL_19_21
		beq $t3, 84, PLANE_COL_19_21
		beq $t3, 88, PLANE_COL_22_24
		beq $t3, 92, PLANE_COL_22_24
		beq $t3, 96, PLANE_COL_22_24
		beq $t3, 100, PLANE_COL_25
		beq $t3, 104, PLANE_COL_26
		beq $t3, 108, PLANE_COL_27

		# If not of specified rows, end iteration without doing anything.
		j UPDATE_COL


		PLANE_COL_0:
			addi $t1, $0, 0x255E90		# change current color to dark blue
			check_color			# updates color according to func. param. $a1
	                add $t2, $a0, $t3		# update to specific column from base address
	            	addi $t2, $t2, plane_center	# update to specified center axis
	           	sw $t1, ($t2)			# paint at center axis
	           	j UPDATE_COL			# end iteration
		PLANE_COL_1_2:
			addi $t1, $0, 0x255E90		# change current color to dark blue
			check_color			# updates color according to func. param. $a1
	    		set_row_incr (6)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_3:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color			# updates color according to func. param. $a1
	    		set_row_incr (4)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_4_7:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color			# updates color according to func. param. $a1
	    		set_row_incr (2)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_8_13:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color			# updates color according to func. param. $a1
	    		set_row_incr (3)		# update row for column
    			j LOOP_PLANE_ROWS		# paint in row
                	j UPDATE_COL			# end iteration
		PLANE_COL_14:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color			# updates color according to func. param. $a1
	    		set_row_incr (8)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
        	        j UPDATE_COL			# end iteration
		PLANE_COL_15_18:
			addi $t1, $0, 0x255E90		# change current color to dark blue
			check_color			# updates color according to func. param. $a1
	    		set_row_incr (16)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_19_21:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color			# updates color according to func. param. $a1
	    		set_row_incr (3)		# update row for column
	            	j LOOP_PLANE_ROWS		# paint in row
	            	j UPDATE_COL			# end iteration
		PLANE_COL_22_24:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color			# updates color according to func. param. $a1
			set_row_incr (2)		# update row for column
			j LOOP_PLANE_ROWS		# paint in row
			j UPDATE_COL			# end iteration
		PLANE_COL_25:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color			# updates color according to func. param. $a1
			add $t2, $0, $0			# reinitialize temporary address store
			add $t2, $a0, $t3		# update to specific column from base address
			addi $t2, $t2, plane_center	# update to specified center axis
			sw $t1, ($t2)			# paint at center axis
			j UPDATE_COL			# end iteration
		PLANE_COL_26:
			addi $t1, $0, 0x255E90		# change current color to dark blue
			check_color			# updates color according to func. param. $a1
			set_row_incr (2)		# update row for column
			j LOOP_PLANE_ROWS		# paint in row
			j UPDATE_COL			# end iteration
		PLANE_COL_27:
			addi $t1, $0, 0x803635		# change current color to dark red
			check_color			# updates color according to func. param. $a1
			add $t2, $0, $0			# reinitialize temporary address store
			add $t2, $a0, $t3		# update to specific column from base address
			addi $t2, $t2, plane_center	# update to specified center axis
			sw $t1, ($t2)			# paint at center axis
			j UPDATE_COL			# end iteration

		UPDATE_COL: addi $t3, $t3, column_increment	# add 4 bits (1 byte) to refer to memory address for next row row
			j LOOP_PLANE_COLS		# repeats LOOP_PLANE_COLS

	EXIT_PLANE_PAINT:
		# Restore registers from stack
		pop_reg_from_stack ($t9)
		pop_reg_from_stack ($t8)
		pop_reg_from_stack ($t5)
		pop_reg_from_stack ($t4)
		pop_reg_from_stack ($t3)
		pop_reg_from_stack ($t2)
		pop_reg_from_stack ($t1)
		jr $ra					# return to previous instruction before PAINT_PLANE was called.

	# FOR LOOP: (through row)
	# Paints in symmetric row at given column (stored in t2) 	# from center using row (stored in $t5)
	LOOP_PLANE_ROWS: bge $t4, $t5, UPDATE_COL	# returns to LOOP_PLANE_COLS when index (stored in $t4) >= (number of rows to paint in) /2
		add $t2, $0, $0				# Reinitialize t2; temporary address store
		add $t2, $a0, $t3			# update to specific column from base address
		addi $t2, $t2, plane_center		# update to specified center axis

		add $t2, $t2, $t4			# update to positive (delta) row
		sw $t1, ($t2)				# paint at positive (delta) row

		sub $t2, $t2, $t4			# update back to specified center axis
		sub $t2, $t2, $t4			# update to negative (delta) row
		sw $t1, ($t2)				# paint at negative (delta) row

		# Updates for loop index
		addi $t4, $t4, row_increment		# t4 += row_increment
		j LOOP_PLANE_ROWS			# repeats LOOP_PLANE_ROWS
#___________________________________________________________________________________________________________________________

check_key_press:	lw $t8, 0xffff0000		# load the value at this address into $t8
			bne $t8, 1, EXIT_KEY_PRESS	# if $t8 != 1, then no key was pressed, exit the function
			lw $t4, 0xffff0004		# load the ascii value of the key that was pressed

check_border:		la $t0, ($a0)			# load ___ base address to $t0
			calculate_indices ($t0, $t5, $t6)	# calculate column and row index

			beq $t4, 0x61, respond_to_a 	# ASCII code of 'a' is 0x61 or 97 in decimal
			beq $t4, 0x77, respond_to_w	# ASCII code of 'w'
			beq $t4, 0x73, respond_to_s	# ASCII code of 's'
			beq $t4, 0x64, respond_to_d	# ASCII code of 'd'
			beq $t4, 0x70, respond_to_p	# restart game when 'p' is pressed
			beq $t4, 0x71, respond_to_q	# exit game when 'q' is pressed
			beq $t4, 0x67, respond_to_g	# if 'g', branch to END_SCREEN_LOOP
			j EXIT_KEY_PRESS		# invalid key, exit the input checking stage

respond_to_a:		ble $t5, 11, EXIT_KEY_PRESS	# the avatar is on left of screen, cannot move up
			subu $t0, $t0, column_increment	# set base position 1 pixel left
			j draw_new_avatar
respond_to_w:		ble $t6, 18, EXIT_KEY_PRESS	# the avatar is on top of screen, cannot move up
			subu $t0, $t0, row_increment	# set base position 1 pixel up
			j draw_new_avatar
respond_to_s:		bgt $t6, 206, EXIT_KEY_PRESS
			addu $t0, $t0, row_increment	# set base position 1 pixel down
			j draw_new_avatar
respond_to_d:		bgt $t5, 216, EXIT_KEY_PRESS
			addu $t0, $t0, column_increment	# set base position 1 pixel right
			j draw_new_avatar

draw_new_avatar:	addi $a1, $zero, 0		# set $a1 as 0
			jal PAINT_PLANE			# (erase plane) paint plane black

			la $a0, ($t0)			# load new base address to $a0
			addi $a1, $zero, 1		# set $a1 as 1
			jal PAINT_PLANE			# paint plane at new location
			j EXIT_KEY_PRESS

respond_to_p:		jal CLEAR_SCREEN
			j INITIALIZE

respond_to_q:		jal CLEAR_SCREEN
			j EXIT

respond_to_g:		j END_SCREEN_LOOP		# TEMPORARY OPTION: Go to ending screen

EXIT_KEY_PRESS:		j OBSTACLE_MOVE			# avatar finished moving, move to next stage
#___________________________________________________________________________________________________________________________
# FUNCTION: Create random address offset
	# Used Registers
		# $a0: used to create random integer via syscall
		# $a1: used to create random integer via syscall
		# $v0: used to create random integer via syscall
		# $s0: used to hold column/row offset
		# $s1: used to hold column/row offset
		# $s2: accumulator of random offset from column and height
	# Outputs:
		# $v0: stores return value for random address offset
RANDOM_OFFSET:
	# Store used registers to stack
	push_reg_to_stack ($a0)
	push_reg_to_stack ($a1)
	push_reg_to_stack ($s0)
	push_reg_to_stack ($s1)
	push_reg_to_stack ($s2)
	
	# Randomly generate row value
	li $v0, 42 		# Specify random integer
	li $a0, 0 		# from 0
	li $a1, 188 		# to 220
	syscall 		# generate and store random integer in $a0
	
	addi $s0, $0, row_increment	# store row increment in $s0
	mult $a0, $s0			# multiply row index to row increment
	mflo $s2			# store result in $s2

	# Randomly generate col value
	li $v0, 42 		# Specify random integer
	li $a0, 0 		# from 0
	li $a1, 22 		# to 220
	syscall 		# Generate and store random integer in $a0
	add $a0, $a0, 183

	addi $s0, $0, column_increment	# store column increment in $s0
	mult $a0, $s0			# multiply column index to column increment
	mflo $s1			# store result in t9
	add $s2, $s2, $s1		# add column address offset to base address

	add $v0, $s2, $0		# store return value (address offset) in $v0
	
	# Restore used registers from stack
	pop_reg_from_stack ($s2)
	pop_reg_from_stack ($s1)
	pop_reg_from_stack ($s0)
	pop_reg_from_stack ($a1)
	pop_reg_from_stack ($a0)
	jr $ra			# return to previous instruction
#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT OBJECT
	# Inputs
		# $a0: object base address
		# $a1: If 0, paint in black. Elif 1, paint in color specified otherwise.
		# $a2: random address offset
	# Registers Used
		# $t1: stores current color value
		# $t2: temporary memory address storage for current unit (in bitmap)
		# $t3: column index for 'for loop' LOOP_OBJ_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $t4: row index for 'for loop' LOOP_OBJ_ROWS
		# $t5: parameter for subfunction LOOP_OBJ_ROWS. Will store # rows to paint from the center row outwards
		# $t8-9: used for multiplication/logical operations
PAINT_OBJECT:
	# Store used registers to stack
	push_reg_to_stack ($t1)
	push_reg_to_stack ($t2)
	push_reg_to_stack ($t3)
	push_reg_to_stack ($t4)
	push_reg_to_stack ($t5)
	push_reg_to_stack ($t8)
	push_reg_to_stack ($t9)
	# Initialize registers
	add $t1, $0, $0				# initialize current color to black
	add $t2, $0, $0				# holds temporary memory address
	add $t3, $0, $0				# holds 'column for loop' indexer
	add $t4, $0, $0				# holds 'row for loop' indexer

	addi $t1, $0, 0xFFFFFF			# change current color to white
	check_color				# updates color according to func. param. $a1

	# FOR LOOP: (through col)
	LOOP_OBJ_COLS: bge $t3, 24, EXIT_PAINT_OBJECT
		set_row_incr (6)		# update row for column
		j LOOP_OBJ_ROWS			# paint in row
	UPDATE_OBJ_COL:				# Update column value
		addi $t3, $t3, column_increment	# add 4 bits (1 byte) to refer to memory address for next row
		add $t4, $0, $0			# reinitialize index for LOOP_OBJ_ROWS
		j LOOP_OBJ_COLS
	EXIT_PAINT_OBJECT:
		# Restore used registers from stack
		pop_reg_from_stack ($t9)
		pop_reg_from_stack ($t8)
		pop_reg_from_stack ($t5)
		pop_reg_from_stack ($t4)
		pop_reg_from_stack ($t3)
		pop_reg_from_stack ($t2)
		pop_reg_from_stack ($t1)
		jr $ra				# return to previous instruction

	# FOR LOOP: (through row)
	# Paints in symmetrically from center at given column
	LOOP_OBJ_ROWS: bge $t4, $t5, UPDATE_OBJ_COL	# returns when row index (stored in $t4) >= (number of rows to paint in) /2
		add $t2, $a0, $0			# start from base address
		add $t2, $t2, $t3			# update to specific column
		add $t2, $t2, $t4			# update to specific row
		add $t2, $t2, $a2			# update to random offset
		
		calculate_indices ($t2, $t8, $t9)	# get address indices. Store in $t8 and $t9
		within_borders ($t8, $t9, $t9)		# check within borders. Store boolean result in $t9 
		beq $t9, 0, SKIP_OBJ_PAINT		# skip painting pixel if out of border
		
		sw $t1, ($t2)				# paint pixel
		SKIP_OBJ_PAINT:
		# Updates for loop index
		addi $t4, $t4, row_increment		# t4 += row_increment
		j LOOP_OBJ_ROWS				# repeats LOOP_OBJ_ROWS

#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT BORDER
	# Registers Used
		# $t1: parameter for LOOP_BORDER_ROWS. Stores color value
		# $t2: temporary memory address storage for current unit (in bitmap)
		# $t3: column index for 'for loop' LOOP_BORDER_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $t4: beginning row index for 'for loop' LOOP_BORDER_ROWS
		# $t5: parameter for LOOP_BORDER_ROWS. Stores row index for last row to be painted in
		# $t6: parameter for LOOP_BORDER_ROWS. Stores # rows to paint from top to bottom
		# $t7: stores result from logical operations
		# $t8-9: used for logical operations
PAINT_BORDER:
	# Push $ra to stack
	push_reg_to_stack ($ra)

	# Initialize registers
	add $t1, $0, $0				# initialize current color to black
	add $t2, $0, $0				# holds temporary memory address
	add $t3, $0, $0				# 'column for loop' indexer
	add $t4, $0, $0				# 'row for loop' indexer
	add $t5, $0, $0				# last row index to paint in

	LOOP_BORDER_COLS: bge $t3, column_max, EXIT_BORDER_PAINT
		# Boolean Expressions: Paint in border piece based on column index
		BORDER_COND:
			# BORDER_OUTER
			sle $t8, $t3, 36
			sge $t9, $t3, 24
			and $t7, $t8, $t9		# 6 <= col index <= 9

			sle $t8, $t3, 996
			sge $t9, $t3, 984
			and $t9, $t8, $t9		# 246 <= col index <= 249

			or $t7, $t7, $t9		# if 6 <= col index <= 9 	|	246 <= col index <= 249
			beq $t7, 1, BORDER_OUTER

			# BORDER_OUTERMOST
			sle $t8, $t3, 20
			sge $t9, $t3, 1000
			or $t7, $t8, $t9		# if col <= 5 OR col index >= 250
			beq $t7, 1, BORDER_OUTERMOST

			# BORDER_INNER
			seq $t8, $t3, 40
			seq $t9, $t3, 980
			or $t7, $t8, $t9		# if col == 10 OR == 245
			beq $t7, 1, BORDER_INNER

			# BORDER_OUTER
			sge $t9, $t3, 44
			sle $t8, $t3, 976
			or $t7, $t8, $t9		# if col <= 11 OR col index >= 244
			beq $t7, 1, BORDER_INNERMOST

		# Paint Settings
		BORDER_OUTERMOST:
			addi $t1, $0, 0x868686		# change current color to dark gray
			add $t4, $0, $0			# paint in from top to bottom
			addi $t5, $0, row_max
	    		jal LOOP_BORDER_ROWS		# paint in column
	                j UPDATE_BORDER_COL		# end iteration
		BORDER_OUTER:
			# Paint dark gray section
			addi $t1, $0, 0x868686		# change current color to dark gray
			add $t4, $0, $0			# paint starting from row ___
			addi $t5, $0, 13312		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint light gray section
	    		addi $t1, $0, 0xC3C3C3		# change current color to light gray
			addi $t4, $0, 13312		# paint starting from row ___
			addi $t5, $0, 248832		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
			# Paint dark gray section
			addi $t1, $0, 0x868686		# change current color to dark gray
			addi $t4, $0, 248832		# paint starting from row ___
			addi $t5, $0, row_max		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	                j UPDATE_BORDER_COL		# end iteration
		BORDER_INNER:
			# Paint dark gray section
			addi $t1, $0, 0x868686		# change current color to dark gray
			add $t4, $0, $0			# paint starting from row ___
			addi $t5, $0, 13312		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint light gray section
	    		addi $t1, $0, 0xC3C3C3		# change current color to light gray
			addi $t4, $0, 13312		# paint starting from row ___
			addi $t5, $0, 17408		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint white section
	    		addi $t1, $0, 0xFFFFFF		# change current color to white
			addi $t4, $0, 17408		# paint starting from row ___
			addi $t5, $0, 244736		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint light gray section
	    		addi $t1, $0, 0xC3C3C3		# change current color to light gray
			addi $t4, $0, 244736		# paint starting from row ___
			addi $t5, $0, 248832		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
			# Paint dark gray section
			addi $t1, $0, 0x868686		# change current color to dark gray
			addi $t4, $0, 248832		# paint starting from row ___
			addi $t5, $0, row_max		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column

	                j UPDATE_BORDER_COL		# end iteration
		BORDER_INNERMOST:
			# Paint dark gray section
			addi $t1, $0, 0x868686		# change current color to dark gray
			add $t4, $0, $0			# paint starting from row ___
			addi $t5, $0, 13312		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint light gray section
	    		addi $t1, $0, 0xC3C3C3		# change current color to light gray
			addi $t4, $0, 13312		# paint starting from row ___
			addi $t5, $0, 17408		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint white section
	    		addi $t1, $0, 0xFFFFFF		# change current color to white
			addi $t4, $0, 17408		# paint starting from row ___
			addi $t5, $0, 18432		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint black selection
	    		addi $t1, $0, 0			# change current color to black
			addi $t4, $0, 18432		# paint starting from row ___
			addi $t5, $0, 243712		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint white section
	    		addi $t1, $0, 0xFFFFFF		# change current color to white
			addi $t4, $0, 243712		# paint starting from row ___
			addi $t5, $0, 244736		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
	    		# Paint light gray section
	    		addi $t1, $0, 0xC3C3C3		# change current color to light gray
			addi $t4, $0, 244736		# paint starting from row ___
			addi $t5, $0, 248832		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column
			# Paint dark gray section
			addi $t1, $0, 0x868686		# change current color to dark gray
			addi $t4, $0, 248832		# paint starting from row ___
			addi $t5, $0, row_max		# ending at row ___
	    		jal LOOP_BORDER_ROWS		# paint in column

	                j UPDATE_BORDER_COL		# end iteration

	UPDATE_BORDER_COL:				# Update column value
		addi $t3, $t3, column_increment		# add 4 bits (1 byte) to refer to memory address for next row
		j LOOP_BORDER_COLS

	# EXIT FUNCTION
	EXIT_BORDER_PAINT:
		# Restore $t registers
		pop_reg_from_stack ($ra)
		jr $ra						# return to previous instruction

	# FOR LOOP: (through row)
	# Paints in row from $t4 to $t5 at some column
	LOOP_BORDER_ROWS: bge $t4, $t5, EXIT_LOOP_BORDER_ROWS	# branch to UPDATE_BORDER_COL; if row index >= last row index to paint
		addi $t2, $0, display_base_address			# Reinitialize t2; temporary address store
		add $t2, $t2, $t3				# update to specific column from base address
		add $t2, $t2, $t4				# update to specific row
		sw $t1, ($t2)					# paint in value

		# Updates for loop index
		addi $t4, $t4, row_increment			# t4 += row_increment
		j LOOP_BORDER_ROWS				# repeats LOOP_BORDER_ROWS
	EXIT_LOOP_BORDER_ROWS:
		jr $ra
#___________________________________________________________________________________________________________________________
# FUNCTION: CLEAR_SCREEN
	# Registers Used
		# $t1: stores current color value
		# $t2: temporary memory address storage for current unit (in bitmap)
		# $t3: column index for 'for loop' LOOP_OBJ_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $t4: row index for 'for loop' LOOP_OBJ_ROWS
		# $t5: parameter for subfunction LOOP_OBJ_ROWS. Will store # rows to paint from the center row outwards
		# $t8-9: used for multiplication operations
CLEAR_SCREEN:
	# Push $ra to stack
	push_reg_to_stack ($ra)

	# Initialize registers
	add $t1, $0, $0				# initialize current color to black
	add $t2, $0, $0				# holds temporary memory address
	add $t3, $0, $0				# 'column for loop' indexer
	add $t4, $0, $0				# 'row for loop' indexer
	add $t5, $0, $0				# last row index to paint in

	LOOP_CLEAR_COL: bge $t3, column_max, EXIT_BORDER_PAINT
		CLEAR_ALL:
			addi $t1, $0, 0x000000		# change current color to black
			add $t4, $0, $0			# paint in from top to bottom
			addi $t5, $0, row_max
	    		jal LOOP_CLEAR_ROW		# paint in column
		UPDATE_CLEAR_COL:				# Update column index value
			addi $t3, $t3, column_increment		
			j LOOP_CLEAR_COL

	# EXIT FUNCTION
	EXIT_CLEAR_PAINT:
		# Restore $t registers
		pop_reg_from_stack ($ra)
		jr $ra						# return to previous instruction

	# FOR LOOP: (through row)
	# Paints in row from $t4 to $t5 at some column
	LOOP_CLEAR_ROW: bge $t4, $t5, EXIT_LOOP_CLEAR_ROW	# branch to UPDATE_CLEAR_COL; if row index >= last row index to paint
		addi $t2, $0, display_base_address			# Reinitialize t2; temporary address store
		add $t2, $t2, $t3				# update to specific column from base address
		add $t2, $t2, $t4				# update to specific row
		sw $t1, ($t2)					# paint in value

		# Updates for loop index
		addi $t4, $t4, row_increment			# t4 += row_increment
		j LOOP_CLEAR_ROW				# repeats LOOP_CLEAR_ROWS
	EXIT_LOOP_CLEAR_ROW:
		jr $ra
#___________________________________________________________________________________________________________________________
# FUNCTION: UPDATE_HEALTH
	# Inputs:
		# $s0: Current number of health points (min = 0, max = 5)
	# Registers Used:
		# $a2: address offset
		# $a3: whether to paint in or erase heart
		# $t0: for loop indexer
		# $t1: used to store column_increment temporarily
		# $t2: temporary storage for manipulating number of health points
		
UPDATE_HEALTH:
	# Store current state of used registers
	push_reg_to_stack ($ra)
	push_reg_to_stack ($s0)
	push_reg_to_stack ($a2)
	push_reg_to_stack ($a3)
	push_reg_to_stack ($t0)
	push_reg_to_stack ($t1)
	push_reg_to_stack ($t2)
	push_reg_to_stack ($t3)
	push_reg_to_stack ($t4)
	push_reg_to_stack ($t5)
	push_reg_to_stack ($t8)
	push_reg_to_stack ($t9)
	
	# Initialize for loop indexer
	add $t0, $0, $0
	# Loop 5 times through all possible hearts. Subtract 1 from number of hearts each time.
	LOOP_HEART: beq $t0, 5, EXIT_UPDATE_HEALTH	# branch if $t0 = 5
		addi $t1, $0, column_increment	# store column increment temporarily
		addi $t2, $0, 12			
		mult $t1, $t2
		mflo $t1			
		mult $t0, $t1			# address offset = current index * (3 * column_increment)
		mflo $a2			# param. for helper function to add column offset
		
		add $t2, $s0, $0		# store number of hit points
		sub $t2, $t2, $t0		# subtract number of hit points by current indexer
		sge $a3, $t2, 1			# param. for helper function to paint/erase heart. If number of hearts > curr index, paint in heart. Otherwise, erase.		
		jal PAINT_HEART			# paint/erase heart
		
		# Update for loop indexer
		addi $t0, $t0, 1		# $t0 = $t0 + 1
		j LOOP_HEART
	# Restore previouos state of used registers
	EXIT_UPDATE_HEALTH:
		pop_reg_from_stack ($t9)
		pop_reg_from_stack ($t8)
		pop_reg_from_stack ($t5)
		pop_reg_from_stack ($t4)
		pop_reg_from_stack ($t3)
		pop_reg_from_stack ($t2)
		pop_reg_from_stack ($t1)
		pop_reg_from_stack ($t0)
		pop_reg_from_stack ($a3)
		pop_reg_from_stack ($a2)
		pop_reg_from_stack ($s0)
		pop_reg_from_stack ($ra)
		jr $ra
#___________________________________________________________________________________________________________________________
# HELPER FUNCTION: PAINT_HEART
	# Inputs:
		# $a2: address offset 
		# $a3: whether to paint in or erase heart
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: column index for 'for loop' LOOP_OBJ_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $s3: starting row index for 'for loop' LOOP_OBJ_ROWS
		# $s4: ending row index for 'for loop' LOOP_OBJ_ROWS

PAINT_HEART:
	    # Store used registers in the stack
	    push_reg_to_stack ($ra)
	    push_reg_to_stack ($s0)
	    push_reg_to_stack ($s1)
	    push_reg_to_stack ($s2)
	    push_reg_to_stack ($s3)
	    push_reg_to_stack ($s4)
    
	    # Initialize registers
	    add $s0, $0, $0				# initialize current color to black
	    add $s1, $0, $0				# holds temporary memory address
	    add $s2, $0, $0				# 'column for loop' indexer
	    add $s3, $0, $0				# 'row for loop' indexer
	    add $s4, $0, $0				# last row index to paint in

		LOOP_HEART_ROW: bge $s2, row_max, EXIT_PAINT_HEART
				# Boolean Expressions: Paint in based on row index
				HEART_COND:
						beq $s2, 0, HEART_ROW_0
						beq $s2, 1024, HEART_ROW_1
						beq $s2, 2048, HEART_ROW_2
						beq $s2, 3072, HEART_ROW_3
						beq $s2, 4096, HEART_ROW_4
						beq $s2, 5120, HEART_ROW_5
						beq $s2, 6144, HEART_ROW_6
						beq $s2, 7168, HEART_ROW_7
						beq $s2, 8192, HEART_ROW_8
						
						j UPDATE_HEART_ROW		# end iteration if not at specified index
				HEART_ROW_0:
						addi $s0, $0, 0x7f7f7f		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 4			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x797979		# change current color
						addi $s3, $0, 4			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x4c4c4c		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 12			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x666666		# change current color
						addi $s3, $0, 12			# paint starting from column ___
						addi $s4, $0, 16			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x7f7f7f		# change current color
						addi $s3, $0, 16			# paint starting from column ___
						addi $s4, $0, 20			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x6b6b6b		# change current color
						addi $s3, $0, 20			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x4c4c4c		# change current color
						addi $s3, $0, 24			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x747474		# change current color
						addi $s3, $0, 28			# paint starting from column ___
						addi $s4, $0, 32			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x7f7f7f		# change current color
						addi $s3, $0, 32			# paint starting from column ___
						addi $s4, $0, 36			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_1:
						addi $s0, $0, 0x777777		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 4			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x6c2a2a		# change current color
						addi $s3, $0, 4			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xdc3131		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 12			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x9f1616		# change current color
						addi $s3, $0, 12			# paint starting from column ___
						addi $s4, $0, 16			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x545353		# change current color
						addi $s3, $0, 16			# paint starting from column ___
						addi $s4, $0, 20			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x900000		# change current color
						addi $s3, $0, 20			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xd80000		# change current color
						addi $s3, $0, 24			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x741e1e		# change current color
						addi $s3, $0, 28			# paint starting from column ___
						addi $s4, $0, 32			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x737373		# change current color
						addi $s3, $0, 32			# paint starting from column ___
						addi $s4, $0, 36			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_2:
						addi $s0, $0, 0x553131		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 4			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xed4343		# change current color
						addi $s3, $0, 4			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff4d4d		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 12			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff0000		# change current color
						addi $s3, $0, 12			# paint starting from column ___
						addi $s4, $0, 16			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xcc0000		# change current color
						addi $s3, $0, 16			# paint starting from column ___
						addi $s4, $0, 20			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xfb0000		# change current color
						addi $s3, $0, 20			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff0000		# change current color
						addi $s3, $0, 24			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xdb0000		# change current color
						addi $s3, $0, 28			# paint starting from column ___
						addi $s4, $0, 32			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x502424		# change current color
						addi $s3, $0, 32			# paint starting from column ___
						addi $s4, $0, 36			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_3:
						addi $s0, $0, 0x512424		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 4			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff3535		# change current color
						addi $s3, $0, 4			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff0000		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xe50000		# change current color
						addi $s3, $0, 28			# paint starting from column ___
						addi $s4, $0, 32			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x4f1717		# change current color
						addi $s3, $0, 32			# paint starting from column ___
						addi $s4, $0, 36			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_4:
						addi $s0, $0, 0x5f5050		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 4			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xc30000		# change current color
						addi $s3, $0, 4			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff0000		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xfa0000		# change current color
						addi $s3, $0, 24			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xb40000		# change current color
						addi $s3, $0, 28			# paint starting from column ___
						addi $s4, $0, 32			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x564343		# change current color
						addi $s3, $0, 32			# paint starting from column ___
						addi $s4, $0, 36			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_5:
						addi $s0, $0, 0x757575		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 4			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x701e1e		# change current color
						addi $s3, $0, 4			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xf80000		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 12			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff0000		# change current color
						addi $s3, $0, 12			# paint starting from column ___
						addi $s4, $0, 20			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xfe0000		# change current color
						addi $s3, $0, 20			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xe50000		# change current color
						addi $s3, $0, 24			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x6c1717		# change current color
						addi $s3, $0, 28			# paint starting from column ___
						addi $s4, $0, 32			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x707070		# change current color
						addi $s3, $0, 32			# paint starting from column ___
						addi $s4, $0, 36			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_6:
						addi $s0, $0, 0x7f7f7f		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 4			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x787878		# change current color
						addi $s3, $0, 4			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x671c1c		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 12			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xff0000		# change current color
						addi $s3, $0, 12			# paint starting from column ___
						addi $s4, $0, 20			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xe90000		# change current color
						addi $s3, $0, 20			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x651414		# change current color
						addi $s3, $0, 24			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x727272		# change current color
						addi $s3, $0, 28			# paint starting from column ___
						addi $s4, $0, 32			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x7f7f7f		# change current color
						addi $s3, $0, 32			# paint starting from column ___
						addi $s4, $0, 36			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_7:
						addi $s0, $0, 0x7f7f7f		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 8			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x7b7b7b		# change current color
						addi $s3, $0, 8			# paint starting from column ___
						addi $s4, $0, 12			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x621c1c		# change current color
						addi $s3, $0, 12			# paint starting from column ___
						addi $s4, $0, 16			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0xe60000		# change current color
						addi $s3, $0, 16			# paint starting from column ___
						addi $s4, $0, 20			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x611616		# change current color
						addi $s3, $0, 20			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x747474		# change current color
						addi $s3, $0, 24			# paint starting from column ___
						addi $s4, $0, 28			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW
				HEART_ROW_8:
						addi $s0, $0, 0x7f7f7f		# change current color
						addi $s3, $0, 0			# paint starting from column ___
						addi $s4, $0, 12			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x7a7a7a		# change current color
						addi $s3, $0, 12			# paint starting from column ___
						addi $s4, $0, 16			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x423333		# change current color
						addi $s3, $0, 16			# paint starting from column ___
						addi $s4, $0, 20			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						addi $s0, $0, 0x747373		# change current color
						addi $s3, $0, 20			# paint starting from column ___
						addi $s4, $0, 24			# ending at column ___
						jal LOOP_HEART_COLUMN		# paint in

						j UPDATE_HEART_ROW

    	UPDATE_HEART_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_HEART_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_HEART_COLUMN: bge $s3, $s4, EXIT_LOOP_HEART_COLUMN	# branch to UPDATE_HEART_COL; if column index >= last column index to paint
        		addi $s1, $0, display_base_address			# Reinitialize t2; temporary address store
        		
        		addi $s1, $s1, 250880				# shift row to bottom outermost border (row index 245)
        		addi $s1, $s1, 52				# shift column to column index 13
        		add $s1, $s1, $a2				# add offset from parameter $a2
        		
        		add $s1, $s1, $s2				# update to specific row from base address
        		add $s1, $s1, $s3				# update to specific column
        		
        		# If param. $a3 specifies to erase, then change color value stored in $s0
        		IF_ERASE: beq $a3, 1, PAINT_HEART_PIXEL
        			addi $s0, $0, 0x868686
        		
        		PAINT_HEART_PIXEL:	sw $s0, ($s1)				# paint in value
        		# Updates for loop index
        		addi $s3, $s3, column_increment			# t4 += row_increment
        		j LOOP_HEART_COLUMN				# repeats LOOP_HEART_ROW
	    EXIT_LOOP_HEART_COLUMN:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_HEART:
        		# Restore used registers
	    		pop_reg_from_stack ($s4)
	    		pop_reg_from_stack ($s3)
	    		pop_reg_from_stack ($s2)
	    		pop_reg_from_stack ($s1)
	    		pop_reg_from_stack ($s0)
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction

#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT_GAME_OVER
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: row index for 'for loop' LOOP_GAME_OVER_ROW
		# $s3: column index for 'for loop' LOOP_GAME_OVER_COLUMN
		# $s4: parameter for subfunction LOOP_GAME_OVER_COLUMN
PAINT_GAME_OVER:
	    # Store used registers in the stack
	    push_reg_to_stack ($ra)
	    push_reg_to_stack ($s0)
	    push_reg_to_stack ($s1)
	    push_reg_to_stack ($s2)
	    push_reg_to_stack ($s3)
	    push_reg_to_stack ($s4)
    
	    # Initialize registers
	    add $s0, $0, $0				# initialize current color to black
	    add $s1, $0, $0				# holds temporary memory address
	    add $s2, $0, $0	
	    add $s3, $0, $0
	    add $s4, $0, $0

		LOOP_GAME_OVER_ROW: bge $s2, row_max, EXIT_PAINT_GAME_OVER
				# Boolean Expressions: Paint in based on row index
				GAME_OVER_COND:
						beq $s2, 39936, GAME_OVER_ROW_39
						beq $s2, 40960, GAME_OVER_ROW_40
						beq $s2, 41984, GAME_OVER_ROW_41
						beq $s2, 43008, GAME_OVER_ROW_42
						beq $s2, 44032, GAME_OVER_ROW_43
						beq $s2, 45056, GAME_OVER_ROW_44
						beq $s2, 46080, GAME_OVER_ROW_45
						beq $s2, 47104, GAME_OVER_ROW_46
						beq $s2, 48128, GAME_OVER_ROW_47
						beq $s2, 49152, GAME_OVER_ROW_48
						beq $s2, 50176, GAME_OVER_ROW_49
						beq $s2, 51200, GAME_OVER_ROW_50
						beq $s2, 52224, GAME_OVER_ROW_51
						beq $s2, 53248, GAME_OVER_ROW_52
						beq $s2, 54272, GAME_OVER_ROW_53
						beq $s2, 55296, GAME_OVER_ROW_54
						beq $s2, 56320, GAME_OVER_ROW_55
						beq $s2, 57344, GAME_OVER_ROW_56
						beq $s2, 58368, GAME_OVER_ROW_57
						beq $s2, 59392, GAME_OVER_ROW_58
						beq $s2, 60416, GAME_OVER_ROW_59
						beq $s2, 61440, GAME_OVER_ROW_60
						beq $s2, 62464, GAME_OVER_ROW_61
						beq $s2, 63488, GAME_OVER_ROW_62
						beq $s2, 64512, GAME_OVER_ROW_63
						beq $s2, 65536, GAME_OVER_ROW_64
						beq $s2, 66560, GAME_OVER_ROW_65
						beq $s2, 67584, GAME_OVER_ROW_66
						beq $s2, 68608, GAME_OVER_ROW_67
						beq $s2, 69632, GAME_OVER_ROW_68
						beq $s2, 70656, GAME_OVER_ROW_69
						beq $s2, 71680, GAME_OVER_ROW_70
						beq $s2, 102400, GAME_OVER_ROW_100
						beq $s2, 103424, GAME_OVER_ROW_101
						beq $s2, 104448, GAME_OVER_ROW_102
						beq $s2, 105472, GAME_OVER_ROW_103
						beq $s2, 106496, GAME_OVER_ROW_104
						beq $s2, 107520, GAME_OVER_ROW_105
						beq $s2, 108544, GAME_OVER_ROW_106
						beq $s2, 109568, GAME_OVER_ROW_107
						beq $s2, 110592, GAME_OVER_ROW_108
						beq $s2, 111616, GAME_OVER_ROW_109
						beq $s2, 124928, GAME_OVER_ROW_122
						beq $s2, 125952, GAME_OVER_ROW_123
						beq $s2, 126976, GAME_OVER_ROW_124
						beq $s2, 128000, GAME_OVER_ROW_125
						beq $s2, 129024, GAME_OVER_ROW_126
						beq $s2, 130048, GAME_OVER_ROW_127
						beq $s2, 131072, GAME_OVER_ROW_128
						beq $s2, 132096, GAME_OVER_ROW_129
						beq $s2, 133120, GAME_OVER_ROW_130
						beq $s2, 134144, GAME_OVER_ROW_131
						beq $s2, 135168, GAME_OVER_ROW_132

						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_39:
						setup_general_paint (0x000000, 0, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 300, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001b, 764, 768, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_40:
						setup_general_paint (0x000000, 0, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000019, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 120, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000019, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001e, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000016, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 152, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000019, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 172, 224, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000016, 224, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 228, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 300, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000016, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 356, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000016, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 412, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 424, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 456, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 580, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000016, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000017, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 648, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000017, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000019, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 720, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000019, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 768, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 832, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001b, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 872, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000017, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000018, 896, 900, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_41:
						setup_general_paint (0x000000, 0, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 108, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001400, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x141a00, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 160, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 220, 224, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 224, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 228, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 368, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 536, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 692, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x141500, 840, 844, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_42:
						setup_general_paint (0x000000, 0, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x434516, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbac060, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd3d857, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdfe35a, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdadb59, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd6d556, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd7d751, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd1d344, 124, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbe455, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9e253, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd8df53, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbde5b, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe1e165, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe3e464, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdddd57, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd2d351, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcdcb64, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb5b174, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d2700, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 172, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000017, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 192, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x424818, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbec76e, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe1e76b, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbdf4d, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xccce3d, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd1d14d, 220, 224, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd6d654, 224, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdee04f, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdde250, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcdd369, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a1c00, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 244, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001a, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 260, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x595621, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc8c76d, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdfdf6d, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdddf60, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdce359, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd2da53, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd2d876, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x474723, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000018, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 316, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x655f2b, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcacb65, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd1d658, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd3d655, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdfe056, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdddd4b, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdede64, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbfbe7d, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 372, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb9b88a, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbdf67, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdade63, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdfe261, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbdd56, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcfd149, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd5d74f, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdadc55, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd7da57, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9df5b, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9e05c, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbe159, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdee259, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdfe159, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe1de59, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2dd5d, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe4dc5f, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdede5a, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdcdc56, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2e45c, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9dd52, 460, 464, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd2d850, 464, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdce16b, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd4d780, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 476, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000016, 508, 512, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 512, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x191b00, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc4c975, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd1d962, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdae259, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd8dc51, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdfe058, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe1df56, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2e155, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5da5e, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5dc5b, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe1de5b, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdadb5b, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdfe25f, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdee257, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5e75f, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdfdd6e, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc6c37c, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e1b00, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 616, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc2c278, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd5d661, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdad557, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdddb54, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbdc52, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd8da5b, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd3d476, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x262600, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 664, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3f3e29, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd5de5d, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd8de64, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdadf61, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd6dc56, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdae062, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc6ca73, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4c4c28, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 732, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd1da7f, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd1db60, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd6de54, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdee557, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd2da49, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd6dd4f, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd5de51, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdcdb4f, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbda4e, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbd950, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9da50, 780, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdcdd53, 784, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdcdf54, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdee156, 792, 800, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbde51, 800, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdde053, 804, 808, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdee154, 808, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdcdf54, 812, 816, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9db53, 816, 820, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdadc55, 820, 824, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe1e15d, 824, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7e763, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb1ac8f, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x181500, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d3d00, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd7dd73, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd2d957, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd2da50, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdae05c, 856, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdde156, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbe14d, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe1e753, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe3e755, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdee152, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdddf50, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xddde54, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdadb53, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdce04d, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdadc54, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdcde59, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdee058, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9dd55, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdee274, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd2d292, 920, 924, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_43:
						setup_general_paint (0x000000, 0, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4a4b00, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2f765, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2fa33, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4fd26, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebef28, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1f33a, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebed30, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xedf12b, 124, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6fa33, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f82f, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f630, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f535, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaf63b, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcf73b, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7f435, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2ed3b, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe1da4b, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd6cd70, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x342900, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 172, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000016, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 192, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x444600, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0f575, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeef43c, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1f620, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8ed1f, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xecf236, 220, 224, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1f838, 224, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1fb1e, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebf614, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdde23e, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x161400, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 244, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 256, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x636114, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xecef64, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f944, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6fe2f, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4fc1b, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebf51a, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdee33e, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b4700, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000020, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 316, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x746c17, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f559, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5eb29, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7fc2c, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1f616, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xedf100, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3f633, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6f588, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbdb91, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3f235, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0f12b, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7f727, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfc22, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6f618, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfc25, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f729, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeef02a, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3f635, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2f836, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2f832, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f930, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6f92e, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f631, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbf434, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcf238, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6fa34, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f933, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4fb31, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2fb2e, 460, 464, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xecf72f, 464, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3fc4b, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeaef6e, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a1900, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 480, 484, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000017, 484, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001b, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 492, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000019, 508, 512, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 512, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeff672, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebf73f, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebf729, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2fb2e, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3f633, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6f739, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f434, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfff440, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaf238, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfa40, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2f641, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f93b, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2fb28, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5fc22, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3f53a, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7e368, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a1400, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 616, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7e667, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7eb22, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfc26, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7f919, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8ff1b, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3fa2e, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2f75f, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x505200, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 664, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x686a39, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5fb43, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1f638, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3f629, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1f717, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcff33, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeeef65, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x514c14, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 732, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9ef67, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4ff39, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8fe1e, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f916, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7fb1e, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9ff29, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2fa29, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f431, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f433, 772, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f534, 780, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9f635, 784, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f836, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7f735, 792, 796, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6f835, 796, 800, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8fa35, 800, 808, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7f934, 808, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7f936, 812, 816, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f939, 816, 820, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfa3d, 820, 824, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfa3e, 824, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaf93f, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcec799, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1b1400, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x454400, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3f54c, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f82b, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffff29, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfa26, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaf922, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdff1d, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f815, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8fb26, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0f129, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f931, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfa2e, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f62f, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9f637, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1fc26, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2f92f, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0f529, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeaf118, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5fc22, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebf03e, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f48a, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 924, 928, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_44:
						setup_general_paint (0x000000, 0, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x534a00, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f24f, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8fc1f, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6f916, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfb3f, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6f05a, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f15a, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7f950, 124, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f446, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f448, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f349, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f24d, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4ef4d, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4ef4b, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7f451, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaf75e, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6f173, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd8d27e, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a2000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 172, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4a4600, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffb6b, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2ed2f, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefb30, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f53f, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeff354, 220, 224, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2f84e, 224, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9ff27, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9fd00, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3f238, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x221700, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 244, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 260, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5f5c00, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2f35a, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f82d, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f700, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6f600, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfd00, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfa35, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x514900, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x211400, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 312, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x756900, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5ef3f, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfc28, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfb1a, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffff00, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffd00, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f723, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1ec74, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 372, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2de94, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfff82e, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaf31f, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f400, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdf800, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f300, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbf815, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaf528, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3f13a, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f349, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1f44b, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeff648, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeff742, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1f73f, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f541, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f346, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6f14b, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeef140, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2f544, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f847, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeef341, 460, 464, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeff74a, 464, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9ef57, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8ea7d, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 476, 484, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001f, 484, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000020, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 492, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000018, 508, 512, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 512, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a1500, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7fa65, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1f838, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeef52d, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f841, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3f14e, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f154, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6f454, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7ed50, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4ec49, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xedec46, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7f757, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeeee42, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeef021, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffe18, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfef92b, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbf15e, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x211600, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 616, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeee856, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfd00, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfff500, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfa00, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9fb00, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7fd00, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0f247, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b4800, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 664, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x636428, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7f33a, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f22e, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaf517, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbf500, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbf614, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1ea54, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5c5016, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 732, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9ea50, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3f516, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffe00, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffb00, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaf400, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcf81d, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0ee1f, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f34f, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaf551, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7f250, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaf754, 780, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f14e, 784, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6f451, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1f24e, 792, 796, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2f34d, 796, 800, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1f24c, 800, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0f14b, 804, 808, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeff04a, 808, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0f14d, 812, 816, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2f350, 816, 820, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f454, 820, 824, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3f053, 824, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeeeb4e, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc3be94, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x221e00, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x444300, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeced2f, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfa16, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbf500, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdf500, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfff800, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f600, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfa1c, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2ee37, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f357, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3ef4e, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2f242, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f346, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1ed4c, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8ef41, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1f549, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0f036, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfafc1d, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f800, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f126, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1e964, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c1400, 924, 928, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_45:
						setup_general_paint (0x000000, 0, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x221816, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x574e27, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xafa25c, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb7a64e, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc6b23f, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcee43, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeee800, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaf52a, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x605500, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4d3d00, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4f4500, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4a4a00, 124, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4c4c00, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x494800, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x484700, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4a4800, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4a4a00, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x474700, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x444400, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x414200, 156, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x484719, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 168, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x252b00, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x747f3d, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x817336, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x80751c, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa3981a, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2e348, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefdb3a, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x756200, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4f4700, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4a4900, 220, 224, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x535800, 224, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbdbd1d, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbf628, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefe126, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb5a42e, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaf9f61, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb5ac6b, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb7b457, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x252132, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 260, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x585200, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1ec5c, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2ec28, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3e900, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcf000, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbef00, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebe014, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb2a614, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9f943b, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x958d4f, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3e3c00, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 320, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x141400, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5d5639, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9a8a3d, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcfbe32, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefe126, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcf125, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9eb16, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2e400, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdf000, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3e626, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2d66a, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9cf91, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8e735, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6e825, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2e700, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5ec00, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f000, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0e825, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb6ad00, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x645e00, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4f4a00, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x484b00, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x464d00, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x454d00, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x454e00, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x464d00, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x474b00, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x494900, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4f4d00, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b4800, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4c4800, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b4a00, 460, 464, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3f3f00, 464, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x494a00, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x464500, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 476, 484, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000019, 484, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000018, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 492, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x403a18, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6c602e, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x908245, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x978638, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7e7100, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1ea53, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f54e, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x676200, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5a5300, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b4200, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x433d00, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x504b00, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4f4900, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b4800, 580, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x454100, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b6200, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x918600, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9ed29, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfae824, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfae645, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8d658, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe0d46e, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd8cd8b, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbcac8b, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebde52, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3ee00, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe800, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbeb00, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f000, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3f000, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe4e13a, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4d4800, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 664, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5e5f26, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1e440, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1e030, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6e418, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbea00, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaeb16, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0de54, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5a4915, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 732, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xece950, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4ef1a, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7e900, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfae700, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbe717, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3e127, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbaac00, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4a4400, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4c4800, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x484400, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b4900, 780, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x454300, 784, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4a4a00, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x454800, 792, 796, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x484b00, 796, 800, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x474c00, 800, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x464b00, 804, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x474b00, 812, 816, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x494b00, 816, 824, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x484900, 824, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x474800, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x302f1d, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x494800, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeeec39, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xede600, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5e600, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7e600, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcee00, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0ea00, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9e335, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x564d00, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x493f00, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x494500, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x474900, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x424600, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x454700, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x444700, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5d5c00, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x777100, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xede731, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6ed14, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdfd300, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4e244, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9da67, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbd47c, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9d8a2, 932, 936, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_46:
						setup_general_paint (0x000000, 0, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x907e3c, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebd95b, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6e04c, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeed437, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebd716, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8ec00, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6dc22, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 120, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000019, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000017, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x716e2b, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdde06f, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5da5e, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6dd42, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2d61e, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2db29, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdde50, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4d2f00, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 220, 224, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x191d00, 224, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9c9b27, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9ef38, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1de15, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe1cc23, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3e35c, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2da53, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe0df46, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001c, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 260, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x534a00, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2da51, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xede224, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5e400, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8e100, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9e300, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdea00, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeddf24, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6dc49, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0ea7a, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x636000, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 320, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x989258, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8de5b, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3e425, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7e800, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6e500, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdea14, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7df00, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe700, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5df31, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5d46c, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcbbf85, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4d930, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8e024, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4e300, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1e100, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3e415, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0e239, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa89b28, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x231800, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 416, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x655a24, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeadb80, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xedd966, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9d54e, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1de42, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeddf38, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2d642, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x423500, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x200000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 564, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001500, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 584, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x221500, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x867300, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7e136, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfce21c, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7db1f, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3de2b, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeee33c, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xede367, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc4b270, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeddc5a, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xece200, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfedf00, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5dd00, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaea00, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1e800, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7e03a, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4f4500, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 664, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5d5c2e, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1e23f, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3df30, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8e115, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9e200, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7e300, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9d550, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x533f00, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 732, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7e34c, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xece115, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7e400, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe500, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfae019, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4de33, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbaa514, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 768, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x484400, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6df37, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2e51a, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7e300, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8e300, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6e700, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5eb17, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeae24f, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 876, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001400, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 892, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x544d00, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebe249, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2e316, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffef1c, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfae323, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefdd33, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8dd4d, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5e084, 932, 936, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_47:
						setup_general_paint (0x000000, 0, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x927d24, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9d72d, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4de19, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6da17, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfce500, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xece000, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9de20, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x260000, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000025, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000018, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 124, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001d, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000019, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x837325, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7df58, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefe43c, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3ea1f, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfef100, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfde31a, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6d049, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3f1e00, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 220, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbdbb56, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9dc2b, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6e200, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4e100, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4e727, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2ec32, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdcdc1a, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 256, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x574e00, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe4db52, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeadd1d, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7e200, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9dd00, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfee200, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7e200, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3e600, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7df24, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd6d344, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x595700, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 324, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9b9644, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe1db2f, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0e600, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6e800, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6e600, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4de00, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe400, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6d900, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbe134, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xecd868, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcbbd80, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfedf2d, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfce01b, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfde500, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9e700, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6e500, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1e03b, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xae9c38, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 424, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000016, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 448, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b5c19, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xecdc63, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0dc3f, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3de29, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1df1d, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2e326, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeadc47, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3e2e00, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 564, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x846e18, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefd72d, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfadf00, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe400, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4e000, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9df00, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xece444, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcfbe66, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6d353, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0e318, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcda00, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfce100, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5e400, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3e700, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7df36, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4e4300, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 668, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x58542f, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeadf2f, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefde1e, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7e400, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5e100, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfae600, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xecd94c, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x504000, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 732, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5e44b, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3e918, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7e500, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7e000, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8e000, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3dd2f, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbaa516, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 768, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x524900, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9de37, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1df00, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfce300, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8df00, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbe800, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9e000, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8de49, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000019, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 884, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4c4a00, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8de49, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7e718, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1d900, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbe100, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8e400, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeee22a, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8e16c, 932, 936, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_48:
						setup_general_paint (0x000000, 0, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280018, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xab7b2f, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8dc30, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9e000, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffde00, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe215, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1e61b, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5e94e, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x171600, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 116, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x856a00, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xecc52c, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6d623, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbe000, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5e100, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6e325, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2db5b, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3f2800, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 220, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb5b05e, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebe046, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4e400, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6e500, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefdc00, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3e01a, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffed2f, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180018, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 260, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5c5000, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xecdf52, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5df27, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcdc15, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcdc00, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfae400, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4e700, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0e300, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4e21e, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbe752, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x624f00, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x14001a, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa99036, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcdd2b, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe200, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffdf00, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffdd00, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffda00, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd600, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfadb00, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2dc38, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7d279, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 372, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd6c172, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcdc25, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfee121, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfee415, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfedf00, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffdd19, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9d83d, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb0993c, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 416, 520, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 520, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x745c00, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9e050, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6e32f, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8e117, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfddb00, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfed722, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8da60, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a2900, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 560, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001500, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 576, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x836e15, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebdd3f, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeee420, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeee000, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9e600, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8df00, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbe031, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd4bb57, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e1800, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6d352, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefe015, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5d300, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdda00, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe000, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8dd00, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeeda3d, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4e4000, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 668, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x595c31, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefe03b, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2e328, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4e000, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe200, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe11d, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xecd352, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x514500, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 732, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4d964, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfadd27, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7e000, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9e300, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7de00, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0d732, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbba51c, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 768, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150016, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000026, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x564000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8dd36, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfadc00, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfee000, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfde016, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6db00, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfce01a, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeed652, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 880, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x584500, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xecdd42, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1e41a, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8e115, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfddc00, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9d700, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfae317, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6dd52, 932, 936, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 936, 940, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 940, 944, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 944, 956, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 956, 960, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_49:
						setup_general_paint (0x000000, 0, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b1b00, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x997100, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3d825, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8de18, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe132, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7cb2a, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xddd739, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd7df68, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x171700, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001e, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000016, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 124, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x856400, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffdb3c, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe02a, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9db19, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe828, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7d336, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6d26f, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x413000, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 216, 224, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x181400, 224, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaea773, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7db6f, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeddb3b, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbe426, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe11d, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfddc1d, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4d117, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d2300, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x201500, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1f0000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x615300, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6d44a, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9de2b, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffda1b, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd716, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbd700, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfee200, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfde400, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8dc16, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefcf2e, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x765600, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x301400, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x372200, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x987d00, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe32e, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfed800, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffdb00, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd200, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd100, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd600, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffdc00, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5da33, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7d072, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1f0000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcfb77b, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5d423, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9dc20, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfedf15, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffdd00, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffdd19, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4d63a, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xab9839, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 412, 520, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 520, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x705c00, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4db4b, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3dd27, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8dd00, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffda00, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd620, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfad75f, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3f2a00, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 560, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x836e1d, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xedd946, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3e024, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8e115, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbda00, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffdb00, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfed835, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd8bb5f, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x260000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9d558, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4e119, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd319, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd200, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffdd00, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdde00, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xedd83f, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x514300, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 664, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x60592d, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4da3b, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5dc28, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5db00, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfad800, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfedc19, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3da5b, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x514500, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 732, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6d964, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffdd26, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe200, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffe100, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbdb14, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3d537, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb49b1a, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 768, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x554000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbda35, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffda00, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffdb00, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffdc1a, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcd900, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfddd16, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeed44c, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000017, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 880, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x543e00, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9e14b, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6db18, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5d400, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd700, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffda00, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffdb00, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebd752, 932, 936, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 936, 956, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 956, 960, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_50:
						setup_general_paint (0x000000, 0, 72, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x615100, 72, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa17d25, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb38900, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcda700, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7d923, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9c926, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdcba3e, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x836d00, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x757417, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x69722f, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000016, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 120, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x493a19, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x95792f, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbe9600, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdca21, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfad117, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xedcd1a, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe4cb30, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x837100, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x564a00, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 216, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3c3228, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x534b1d, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x615400, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe1c736, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1c818, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd51d, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdcf1a, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9c8b00, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9d9028, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x877a43, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x584400, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8d14d, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0ce24, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7c816, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffcc1d, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdca00, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfed300, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9d400, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfad300, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd423, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd5a500, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa97f00, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa58200, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa38600, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd8ba24, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4d01a, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdd000, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd200, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfccc00, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaca00, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd100, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd400, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5d029, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe1c863, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcbb289, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9d22d, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8d020, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5ce00, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8cf00, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9d215, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefd038, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa79737, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 412, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a5800, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebd043, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0d11e, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7d300, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcd000, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfacc16, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3ca54, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x412300, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 564, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x806925, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9cd46, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3d223, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdd615, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8c800, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffcd00, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfacb37, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd4b062, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x301800, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2cc55, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebd000, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfec500, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8c300, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffd200, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6d100, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2c835, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4f3e00, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 664, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5b4c21, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3ce38, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5d329, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0cf00, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbd300, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcd319, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeaca4f, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4e3d00, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 732, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xedd05b, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2cd1a, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdd400, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcd100, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6cd00, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9d340, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb79823, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 768, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4f3a00, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3cb2b, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffcd00, 848, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcce19, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbd100, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7d000, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebcb42, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001b, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 884, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001a, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5b4000, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeecd40, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9d318, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcd000, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffcc00, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc600, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfecd00, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeecc4e, 932, 936, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 936, 940, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_51:
						setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 68, 72, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x977b28, 72, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3c645, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xecbb16, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5c700, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8ca1c, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefc33e, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd2ac59, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f1a00, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 104, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000018, 116, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 124, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x715919, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6c14c, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2c021, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9c000, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4c500, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8c31d, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdec64a, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x433300, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 208, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5cb5c, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2c11c, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfac200, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xedb900, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6c900, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5ca3b, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc4ac62, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1f0000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5f4400, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeed04e, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4cd27, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3bf00, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc31d, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcc014, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9c300, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4c400, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4c300, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfac300, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8bf00, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7be17, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfccc22, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8c217, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeeca1c, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3c900, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9c700, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6c100, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9c600, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6c400, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfac500, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbc600, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3c726, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xddc25b, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc8b28d, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8c52e, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9c420, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbc400, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffca00, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5c314, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xecc539, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaa9238, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 416, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b5600, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebc943, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5ca1c, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfac900, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffcb00, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcc918, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1c152, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x482300, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 564, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7e6427, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8c046, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6c624, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6c200, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdc100, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc100, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6c039, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xccaa63, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x210000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xddc354, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xedc600, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2bf00, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1be00, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffcd00, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdcf1a, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebc63a, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x533900, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 668, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x644d23, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefc437, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeec628, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefc500, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8c600, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfac517, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebc24e, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x493400, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 732, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe0c252, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1cc1c, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5c800, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1c100, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8c418, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xedbd37, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb98d22, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 768, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x493800, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebc22a, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdc600, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdc500, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7c318, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcc900, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6c400, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6be38, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001e, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 880, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000018, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5f3c00, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7bc39, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2c718, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7ca00, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdc700, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfec200, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdc200, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeec44e, 932, 936, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 936, 940, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_52:
						setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 68, 72, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa47a24, 72, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc53b, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc315, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc100, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9b919, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfabe4c, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd8a868, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x341c00, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 104, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x260000, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x200000, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1f0000, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x250000, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x200000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x714d00, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5c12f, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc616, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffbf00, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffbc00, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6c32c, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe0be5a, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d2900, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 208, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001e, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001d, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe3c15f, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc11c, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcb700, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfabd15, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfece00, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9ba22, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xddb06c, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x260000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b4500, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdeb537, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6c522, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdc31a, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffbe1c, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffbd17, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcbd00, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcbf00, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfec300, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc000, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc100, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffb700, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc200, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9c500, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0bb00, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfec214, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffbf00, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfec200, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfac200, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7bd00, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbbc00, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdbe00, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7c12b, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe0be5c, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1f0000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc2ad80, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc039, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcb622, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbb400, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc517, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbbd1a, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7c542, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb38b33, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d0000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x210000, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x200000, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 448, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x705600, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefc346, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdc321, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfec100, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcc200, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6c018, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6b64a, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x462100, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 564, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x825f25, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9b643, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8bd23, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc615, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc100, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5af00, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xedb335, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd8b774, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe3c259, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4be16, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5c400, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3ba00, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbba00, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffbe17, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3b933, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5d2f00, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x250000, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 680, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x644300, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6c137, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0bc28, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9c019, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5b400, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfab915, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfac859, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x553600, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 732, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdfb851, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1c01d, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffcc00, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc600, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffbf1f, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfabd3e, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc98f24, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1f0000, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x250000, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x210000, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1f0000, 780, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 784, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1b0000, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 792, 796, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 796, 800, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 800, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 804, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 812, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001a, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 832, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4d3700, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebbe31, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc500, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc200, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9be1a, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc000, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffc400, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeebb3e, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000024, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000019, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 884, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x320000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x643400, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6c042, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9c61f, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2c400, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfac600, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffbd00, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffbb15, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0bd52, 932, 936, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1b0000, 936, 940, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_53:
						setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1f0000, 68, 72, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x946100, 72, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3ac2c, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaa700, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7a400, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9a916, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeaa639, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc89554, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d1e00, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 104, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a3800, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x672c00, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x712d00, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x713300, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b3800, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x623600, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x613000, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x713c00, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x633400, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x52321b, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x290000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x824c00, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4ab00, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdab00, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffb300, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffa900, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdaf29, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9a752, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x432600, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 208, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000018, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001e, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdaaa48, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffac00, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfea400, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffb118, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9ba00, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9a71d, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde9d67, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d0000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x734100, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdfa834, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7b81f, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7af00, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9ac00, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffb200, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffb300, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffb100, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfeb000, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbac00, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9a800, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdaa00, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8ad00, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdb600, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdb000, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfba700, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfeae00, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdb700, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5b400, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5ad00, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbab00, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbad00, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeeac22, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd7a84e, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x210000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb39c6a, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5a92f, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5a51c, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfca900, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffb500, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeca300, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xebaa28, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc98b28, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7f4300, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6e3600, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x683300, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x663300, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x673400, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b3400, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x683200, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x643200, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x61341f, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 452, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x714b00, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7af3e, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3b019, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4af00, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4b400, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefb314, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbaa44, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x422100, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 560, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7f561e, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe3a43a, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefab18, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6b400, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7b200, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8ad00, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe4a62b, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc3a15a, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd3a641, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdaf17, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfab700, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffb100, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffa900, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffaa00, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffb12b, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x995700, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x713600, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x632e00, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5e311a, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 680, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x533116, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x603600, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6d3c00, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x996418, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffba30, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffbb2e, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaaf15, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfead00, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbae14, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6ac40, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5c3800, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 732, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5aa4e, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2aa17, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffb600, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfeb200, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7aa00, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7a827, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd68917, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x763c00, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x793e00, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6f3400, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6f3500, 780, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b3600, 784, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a3300, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6d3400, 792, 796, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a3200, 796, 800, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x613300, 800, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x563900, 804, 808, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 808, 824, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000016, 824, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000020, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 832, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x502e00, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6ad2c, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcb400, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbb000, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5ab00, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8ab00, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8ac00, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2aa3b, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1b0000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000029, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000019, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 884, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x593515, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6c3d00, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x945700, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2ad2c, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf6b500, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4b600, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfab600, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffae00, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdac14, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xedb350, 932, 936, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 936, 940, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000017, 940, 944, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_54:
						setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 68, 72, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x895600, 72, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea9a27, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec8c00, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed8d00, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf09900, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd78f20, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb47f3d, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a1800, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 108, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 124, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe09039, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe48a3c, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe4863c, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdf8a37, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd99439, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd2943f, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd38e40, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdd9040, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd38b43, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb48058, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x380000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c0000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7e3d00, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed9600, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf49300, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef9000, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8a00, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe58400, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd3934b, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x462300, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 212, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000022, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd49335, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf89300, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff9500, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf59500, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9a300, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb9418, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc27b4d, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6e3600, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd99530, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec9b18, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe79000, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe38900, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe58600, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb8a00, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec8a00, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf19000, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf39500, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef9200, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb9500, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee9700, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee9400, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb8700, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfb9400, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf19500, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea9a00, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec9d00, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf29600, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf99400, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf49600, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe09300, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc8f3f, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c0000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x260000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa7865b, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe49425, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe48f00, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb9200, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef9700, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe69400, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb9c1b, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe69426, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd98221, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe59035, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe09134, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdd922d, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe09327, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe09223, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdc8e29, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd58f3a, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd1914a, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4e3028, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x260000, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 460, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6f4000, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdc9931, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe69a00, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe99c00, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe79c00, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe39f00, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xce9939, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a1d00, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 560, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7d4e1a, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdd9332, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe99800, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeaa000, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe89b00, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee9900, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde931e, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaf8136, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x381600, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc38629, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf08f00, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec9100, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf28900, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf17f00, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef8400, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf29600, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe28e1a, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde8e2f, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde9244, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc9459, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1f0000, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb7885a, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe09f43, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe4972b, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe89b33, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe18400, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe88c00, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb8000, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee9300, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe99700, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc5881e, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5d3500, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x250000, 732, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd38733, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee9600, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe99000, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec9200, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf89c00, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe88a00, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf39116, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb8d38, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde8c3a, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda8333, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde8833, 780, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe18d35, 784, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8923b, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe78d37, 792, 796, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe38d36, 796, 800, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdf9848, 800, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc19459, 804, 808, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 808, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 812, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x522400, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe19923, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf49c00, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf49a00, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf29800, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef9700, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe79800, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd39e3e, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00002a, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001d, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 884, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc38f44, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc28534, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe19831, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe69200, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe68e00, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe98f00, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed8d00, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf78e00, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec8900, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd89841, 932, 936, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_55:
						setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 68, 72, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x925900, 72, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2871e, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf38400, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf38100, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef8c00, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdf8c24, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc08448, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 104, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 120, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe69127, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf79534, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3882a, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb861e, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe89022, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7962a, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee922b, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb8520, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2842d, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbc7d4a, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c0000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x803b00, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee8a18, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf88d00, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf48b16, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8500, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef8726, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd18a4c, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x471c00, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 212, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x210000, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe29142, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfe8d00, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd8900, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf18700, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe69300, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe09225, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc98556, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a2f00, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd18233, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed8d29, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef8718, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf28400, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf58300, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8f00, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf68b00, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf28e16, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf09100, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf19100, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf19700, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf49100, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd8f00, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd8b00, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf58c17, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed9200, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed9900, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf39300, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc8c00, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8900, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfe8e00, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb9119, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd58f4a, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x380000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa87f61, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe68d29, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe98718, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf48d00, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf48c00, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf99315, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef8e1d, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf08b23, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfe9732, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed8722, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea8b1f, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea911b, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed9414, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee9100, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe98f17, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe38f2c, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe09440, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x512620, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 460, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x773d00, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde8c36, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe78e18, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf09300, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf08f00, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed951a, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd19340, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3e1e00, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 560, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x84491d, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe4893a, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf08c1d, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf59614, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf89400, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf88b00, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf08e2b, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb77835, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc873c, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf18926, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf28f1a, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf08014, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf77e15, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfa8815, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec8900, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf09015, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec8700, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4912b, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde9747, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x210000, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd3985c, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf19a30, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf38e18, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef891d, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf58600, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee8600, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb8b00, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef9100, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8941a, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc8c32, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x593000, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 732, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdf8d43, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb8a15, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf48e00, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf99300, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf88d00, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf98700, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8b16, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe18f2b, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe88f2b, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef8f29, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed8c21, 780, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea8819, 784, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf28d21, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0841f, 792, 796, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf48c2d, 796, 800, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe18c3b, 800, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xca955f, 804, 808, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 808, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 812, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x592100, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe9902a, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfa9200, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc9200, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfa9100, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf58e00, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed9318, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd09340, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe69836, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdf8d29, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef972b, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe98900, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf28c00, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfa911b, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfa8a1a, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd8719, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf08924, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd69a54, 932, 936, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_56:
						setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 68, 72, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9d5200, 72, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4802d, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7e27, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7a1b, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff801f, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf88a3d, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd18055, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 104, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 124, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd98f38, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe58936, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3802d, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfb7f27, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8a2c, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf98425, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfa7e1e, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd781b, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf78235, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcb8154, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c0000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7e3100, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf88534, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8428, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff832b, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7d20, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1782f, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8875a, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x530000, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x290000, 220, 224, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 224, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x200000, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x290000, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x420000, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5834d, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8225, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7f1c, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf87b21, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd8600, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf58f3b, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc87f56, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b2700, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2814a, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf88340, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7d32, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7c23, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7e18, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8621, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf08127, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe28633, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe0882f, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe48626, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf28818, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8d1b, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7e15, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfb812b, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb8a39, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe49030, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf09125, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8c26, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff751f, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff741a, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7c00, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfb8627, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd98350, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x320000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbc8473, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc883b, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc7e29, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7717, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7d1c, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7d24, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf17626, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe67229, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf2863d, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe68538, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe28c39, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe4933a, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe99535, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea9133, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe38a38, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd58443, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc8804e, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x461a17, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 460, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7a3400, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe67f44, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3802d, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8323, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8120, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf77a28, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda864a, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3f1800, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 560, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8b421f, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee7d41, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7d2f, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8126, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8223, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff751f, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff813d, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd17d4e, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x390000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc88a5b, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe28c51, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda9142, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe48741, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef7f37, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf9812b, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfe8824, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf87c18, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7a1b, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8129, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8813c, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3c0000, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe78d4e, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf17918, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8425, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7d35, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7d15, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8529, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf28a35, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe48a32, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdf913c, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xce9455, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x482300, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 732, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde854b, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7862a, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff841c, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7f1a, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7c1f, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff781d, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7a1d, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd28a35, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd88a37, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe08b38, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe18b34, 780, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda852b, 784, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe28935, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe68639, 792, 796, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe88a42, 796, 800, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda8b50, 800, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc4926f, 804, 808, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 808, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 812, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x611900, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea7c31, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd811d, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff831e, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd781b, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff7a1b, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc8124, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea8744, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 876, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x290000, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x360000, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff8836, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf47f2f, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf48a36, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2822b, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe28832, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe58b3d, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe88742, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea853f, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe08c46, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc79968, 932, 936, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_57:
						setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x340000, 68, 72, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8b2100, 72, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc02800, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd12100, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda2600, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd32700, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc32a00, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa4321a, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x410000, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 104, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 124, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3e0000, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5c0000, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x911400, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb81c00, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc92300, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf2600, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd92900, 152, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbe2700, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x96361e, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x340000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x740000, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc22e00, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcb2600, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc62600, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd62f00, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc62300, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc82c15, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa51700, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xab2629, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac2835, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaa242f, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa72225, 220, 224, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa3241e, 224, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa22626, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaa272f, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaf191a, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd2400, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf1f00, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd12600, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd02b00, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdc2200, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc22d00, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x96361e, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x380000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3c0000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6d0000, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb63516, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc02a00, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc62000, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd11d00, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb2400, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc92d00, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8c1c00, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x530000, 308, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7f2300, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb82900, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xce2a00, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xce2800, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9e1b00, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5d0000, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x681600, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9c2a00, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc42900, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd72400, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdc1d00, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd92000, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcb2e00, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac3f20, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x400000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x390000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8c3e34, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc02800, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd02a00, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd52000, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde2500, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd92a00, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc02a00, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x961b00, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b0000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x490000, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3c0000, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x380000, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3c0000, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x400000, 432, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x380000, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1f0000, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 456, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x630000, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba391a, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc42f00, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd12900, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdd2200, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf2600, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xae3d1d, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 564, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c0000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x711c00, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba3200, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc92700, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd52b00, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb2600, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda1f00, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc82300, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa1341d, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x360000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 632, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b0000, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x730000, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb42e00, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc62c00, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd12600, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd72100, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd31d00, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc02200, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa01d00, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa62f27, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9c1b00, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc62b00, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xce2000, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd51e00, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd41f00, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe21d00, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc42300, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9c2800, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x540000, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b0000, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x431700, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x200000, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 732, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x390000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xad3817, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xca2f00, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd92a00, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb2a00, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd92e00, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc72700, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xad1600, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d0000, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x390000, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x400000, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x390000, 780, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x380000, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3f0000, 792, 800, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x380000, 800, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 804, 808, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 808, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5c0000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc03300, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xce2d00, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf2800, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xce2000, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd51d00, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdf2700, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd2400, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb62000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa72122, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa42126, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xab2927, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb5342e, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x971a14, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd41c00, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc22300, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa02500, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x590000, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x360000, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3c0000, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d0000, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x340000, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 932, 936, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_58:
						setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x400000, 68, 72, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x920000, 72, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc1a00, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe01800, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdd0000, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd10000, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb51e15, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x560000, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 108, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b0000, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9b0000, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd21500, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90000, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef0000, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe70000, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd71c15, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x971c1e, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b0000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x420000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x850000, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf0000, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe30000, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdf0000, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed1400, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90000, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe60000, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90000, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe00016, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd90000, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdc0000, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe20000, 220, 224, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde0000, 224, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd90000, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde0019, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90019, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe70000, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb0000, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90000, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe00000, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd0000, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd60000, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x991f1c, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x470000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x490000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7f0000, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc01e00, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd11700, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe31800, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90000, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf00000, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd41b00, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8a0000, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3c0000, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x771917, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd52525, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd60000, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd21400, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x970000, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x420000, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5f0000, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xad2200, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd81800, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe30000, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb0000, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee0000, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdc0000, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa71f00, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4c0000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x480000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d2421, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc0000, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe41a00, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90000, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed0000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdf0000, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc31800, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8c0000, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x450000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 420, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 440, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6d0000, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba2018, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc1400, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe00000, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef0000, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe30000, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb02218, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x480000, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x200000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 564, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b0000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb81c00, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb1800, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe10000, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe60000, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee0000, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd80000, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac2823, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x400000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d0000, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5f0000, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbe2714, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd61800, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe80000, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf40000, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb0000, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe30000, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe00000, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb0000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe70000, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee0000, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea0000, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea001b, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfb0000, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd20000, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa92f2e, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d0000, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 732, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x420000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb31c00, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe41700, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf40000, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed0000, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb0000, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc1a00, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa90000, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 772, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 780, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6e0000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc91400, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe00000, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb0000, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf40000, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf90000, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec0000, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe60000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda0000, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe6191e, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd90000, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf0000, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb1900, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed0000, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd20000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9e0000, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b0000, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 916, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 924, 932, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_59:
						setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x420000, 68, 72, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8e0015, 72, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc4161f, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd6141c, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe60019, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf20015, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90000, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc91a15, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x680000, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x290000, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 108, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x970018, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda0019, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf60000, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff0000, 148, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf70000, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdd001f, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9a0021, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x500000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4e0000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8e0000, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe70018, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf90000, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf60000, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfe0000, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff0000, 196, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc0000, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb0000, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe80000, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec0000, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf10000, 220, 224, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee0000, 224, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec0016, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea0016, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90000, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf20000, 240, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf30000, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff0000, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe7001c, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa01f24, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x430000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4d0000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x860000, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc91a17, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd70000, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee0000, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf60000, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff0000, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd60000, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x840016, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6d1928, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc91834, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcb0019, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc40019, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8a191d, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x320000, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x570000, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb41d22, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe20016, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf20000, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc0000, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff0000, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xed0000, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xad1d15, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x480000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x460000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9c2529, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde0000, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90000, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf00000, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfa0000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec0000, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xca171a, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x881417, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x380000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 416, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x740000, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc7181d, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde0000, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf90000, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc0000, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf90014, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbd1b19, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x510000, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 564, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6e0000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbe1600, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe50000, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfa0000, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc0000, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf90000, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe10000, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb6201f, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x440000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 636, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x210000, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x540000, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xae1a18, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd50000, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe80000, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc0000, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff0000, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd0000, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff0000, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd0000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff0000, 684, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfe0000, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfb0000, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf90014, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd0015, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc7001e, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x972c3c, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c0000, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 720, 724, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 724, 728, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 728, 732, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 732, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x410000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbb1c19, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90000, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfb0000, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff0000, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea0015, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd51a23, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa40000, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1b0000, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 772, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x770000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda0000, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf90000, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc0000, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd0000, 856, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff0000, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea0000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe20000, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe60000, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfa0000, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc0000, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf60000, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf80000, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe00000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaf0015, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5d0000, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 920, 924, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_60:
						setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 68, 72, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7b001f, 72, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa71f2d, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb21822, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc70018, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90016, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc00000, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x810000, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x550000, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x340000, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 112, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x320000, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8c0000, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xce0000, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf10000, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc0000, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf90000, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf10000, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd4001e, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x971724, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x440000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x460000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x850000, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe00018, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf20000, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf10000, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff0000, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf50000, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef0000, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdd0000, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc91700, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc41d14, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc11717, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc5141e, 220, 224, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc51522, 224, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc01c25, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbb1d1e, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcb1d1c, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe41817, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee0000, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe80000, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe60000, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff0000, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda001a, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x921e1f, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3e0000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x770000, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc11918, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd50000, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea0000, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf20000, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd0000, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd50018, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7b0000, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x54171f, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa01830, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb32030, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa12025, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x661e21, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4c0000, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac1b22, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd70000, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf40000, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc0000, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa9201a, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x420000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x410000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x95262f, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdc0000, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe30000, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee0000, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf50000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe80000, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc91715, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x800000, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x320000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 416, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x720000, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc81920, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd80000, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf10000, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc0000, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf80000, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc41a1b, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x560000, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1f0000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 564, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x720000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xca1a1a, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee0000, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf20000, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf70000, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf80000, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe10000, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb01500, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x510000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x510000, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x92201f, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbe1d15, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb1400, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe70000, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf10000, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfa0000, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xff0000, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc0000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfb0000, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf30000, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf80000, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf40000, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xef0000, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd11c21, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa4202b, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x722c37, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x250000, 716, 720, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 720, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb5261e, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe30000, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf90000, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfb0000, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd01520, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa80000, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 772, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a0000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd80000, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf60000, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd0000, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfa0000, 856, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfc0000, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90000, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbf0000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba1c19, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd2171e, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xee0016, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf10000, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf80000, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf60000, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe10000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbc0000, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7c0000, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x580000, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x450000, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d0000, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 924, 928, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_61:
						setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 68, 72, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d0000, 72, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x520000, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5c0000, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x850000, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xce0015, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda0000, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xce1900, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa90000, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9b0019, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7d0020, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 120, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x840000, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe30000, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb0000, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90000, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe60000, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc91518, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d1a1f, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d0000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x820000, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd30015, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 184, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90000, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda0000, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb60000, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8b0000, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x610000, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x520000, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x540000, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5c0000, 220, 224, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x580000, 224, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4f0000, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4c0000, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x670000, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xae0000, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf0000, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd60000, 248, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf00000, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xca0018, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x871f1e, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x320000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6d0000, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb01500, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc60000, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb0000, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea0000, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc70000, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x700000, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 312, 316, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 316, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x450000, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x540000, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d0000, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4d0000, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa71c21, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xca0000, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd60000, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf10000, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd80000, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9a1f18, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 372, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x801f28, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd0000, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd70000, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe20000, 392, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd60000, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc11400, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x820000, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 420, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6c0000, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbc1c24, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc60000, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda0000, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec0000, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbb1517, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5b0000, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 568, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x770000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc80018, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe00000, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf00000, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90000, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd80000, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc90000, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa61816, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4a0000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 636, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3e0000, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x640000, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa81800, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc20000, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdd0000, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe30000, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe80000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe50000, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdf0000, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd50000, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd0000, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc90000, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x660000, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4e0000, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 712, 716, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 716, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9a1b14, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc0000, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe10000, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe20000, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdd0000, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc70014, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa80000, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 772, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x620000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcb0000, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe30000, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb0000, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 856, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe60014, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc40000, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6e0000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5f0000, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x820000, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbf0000, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd80000, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdc0000, 892, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd90000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd20000, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbb1400, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa61c00, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x921b00, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x751800, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 924, 928, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_62:
						setup_general_paint (0x000000, 0, 72, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 72, 76, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 76, 80, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 80, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x540000, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb61e1b, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc50000, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc00000, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba0000, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xca0000, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb8151a, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x490000, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 124, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1b0000, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d0000, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7c0000, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb10000, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf0000, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd30000, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd60000, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd30000, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc01500, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x871918, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d0000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x360000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x770000, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc50000, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xde0000, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe60000, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe10000, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc0017, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x99001c, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x510000, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x210000, 208, 212, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 212, 216, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 216, 220, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 220, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 228, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac1d17, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb0000, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe10000, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd40000, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe90016, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc90020, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x86171d, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6c0000, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xae1600, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc40000, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd20000, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe00000, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe10000, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbf0000, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a0000, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 312, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 320, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 328, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x560000, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa7181e, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc50016, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd30000, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdc0000, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe10000, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc0000, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x991e20, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x400000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3e0000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7b1f22, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcb0000, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf0000, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd10000, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd80000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd70000, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc51800, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8e0000, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4d0000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x260000, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 428, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1b0000, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 448, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 460, 464, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 464, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 468, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x600000, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa51c24, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xae0000, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbe0000, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd0000, 544, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xad0017, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5d0000, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1b0000, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 568, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x450000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7f0000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc70015, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda0000, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd60000, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xce0000, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba0000, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaa001a, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8f1b1e, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d0000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 632, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x842020, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa30000, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd00000, 672, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd10000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xce0000, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd0000, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc00000, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb71a00, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa71800, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x340000, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 708, 712, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 712, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9d161d, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd00000, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe00000, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdc0000, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd30000, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc20000, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa90000, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 780, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 784, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 792, 796, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 796, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 804, 808, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 808, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 812, 816, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 816, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5b0000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbd0014, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd80000, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdd0000, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd20000, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd70000, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda0014, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba171a, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3e0000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5e0000, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb10022, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd1001b, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xca0000, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd30000, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe10000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdd0000, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xce0000, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc40000, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbd1c14, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x961700, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x450000, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 928, 932, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_63:
						setup_general_paint (0x000000, 0, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x320000, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x981700, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb20000, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaf0000, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd0000, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe30000, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd70000, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b0000, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c0000, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x250000, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3c0000, 124, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x520000, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x820017, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb00019, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcb0000, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd10000, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd90000, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd20000, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbf1400, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x881615, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x450000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x380000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x760000, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc70000, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xda0000, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdc0000, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe00000, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc4001a, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x921d30, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x380000, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 208, 228, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 228, 232, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 232, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa50014, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe30000, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeb0000, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd90000, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb0000, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc5001d, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x931626, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3e0000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x650000, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xae0000, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd00016, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd50000, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdc0000, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd50000, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbf0000, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x720000, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 312, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x200000, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x610000, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xad1521, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc30017, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc0000, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe10000, 356, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc50000, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x94151e, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x440000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x410000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x832525, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd0001c, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf001c, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc90014, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd50016, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf0000, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb70000, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x930000, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x650000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x410000, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 432, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x290000, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280014, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2b0000, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d0000, 460, 464, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 464, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2b0000, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 476, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x530000, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8c141e, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9a1400, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaa1700, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb40000, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc2001a, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xab1520, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6c0000, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x450000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x250000, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 576, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x420000, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5e0000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8e0000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc90015, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd90000, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd00000, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb00000, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa31716, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x981c24, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x76151e, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x00001e, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 640, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x71202f, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x951627, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb2001f, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc00018, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xca0019, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc0000, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbd0000, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb70000, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa3181d, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d161c, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 704, 708, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 708, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb0142c, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9001a, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe60000, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe40000, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf0000, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc30000, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa70000, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3c0000, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x340000, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d0000, 776, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2b0000, 784, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x290000, 792, 796, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 796, 800, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x250000, 800, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 804, 808, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x320000, 808, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d0000, 812, 816, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 816, 820, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d0000, 820, 824, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2b0000, 824, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x390000, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x320000, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5e0000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb90018, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd80000, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd10000, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf0000, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd40000, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb40016, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x380000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5a001e, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac142b, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc8001d, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc20000, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd20016, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe20018, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe00000, 904, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd60000, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc20000, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9d0000, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x590000, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 932, 936, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 936, 940, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_64:
						setup_general_paint (0x000000, 0, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x420000, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5a0000, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x660000, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9e1600, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc60000, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcb0000, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x930000, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x721500, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6c1617, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7c001f, 124, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x810000, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7f0000, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8f0000, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac0000, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc60000, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd70000, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd80000, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc60000, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaa0000, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x811a1b, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x410000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d0000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x700000, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb90017, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xca0000, 184, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc80000, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc00000, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa2001e, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b0000, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 208, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x970000, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc90000, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd80000, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd20000, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd0000, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xab0000, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x781e1d, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d0000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5c0000, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa3001d, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc8001c, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc80000, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd00000, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd30000, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbb0022, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x600000, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 312, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x540000, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa21525, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb40019, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb50000, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc50000, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf0000, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba0000, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x891814, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x360000, 372, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x791d32, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb10000, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb70000, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbf0000, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc90000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xca0000, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xae0000, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9b0000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x890000, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x800000, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7c0000, 424, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7d0000, 432, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7c0000, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7a0000, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x820000, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x850000, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x820000, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7c0000, 460, 464, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7f0000, 464, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7d0017, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6f0020, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 480, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b0000, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x560000, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x650000, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9c1a18, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb00000, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa70000, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8b0000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x741400, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x700000, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x800000, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x830000, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x810000, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x800000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x890000, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9c0000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb90000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc0000, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc70000, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa80000, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x770000, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4c0000, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 628, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d0015, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x480014, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x540000, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x650000, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa30000, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbd0000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb00000, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x660000, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x410000, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d0000, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x520020, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 704, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x380000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9f141b, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd0000, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe50000, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb0000, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc80000, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbb0000, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xad0000, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d0000, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x880000, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x800000, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x790000, 780, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x780000, 784, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7c0000, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7f0000, 792, 796, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7e0000, 796, 800, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7f0000, 800, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7e0000, 804, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7f0000, 812, 820, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x790015, 820, 824, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6e1414, 824, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x661615, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5a0000, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x430000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x600000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xab0000, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd10000, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc0000, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc80000, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf0000, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa21400, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 876, 880, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a001a, 880, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a001d, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x790016, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x73001d, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb71500, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc00000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd20000, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd80000, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd00000, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc70000, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb30000, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d0000, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6d0000, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x501b17, 932, 936, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 936, 940, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_65:
						setup_general_paint (0x000000, 0, 84, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 84, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x400000, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x520000, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x930000, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbc0000, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd20000, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb60000, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9d1e17, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x971a18, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa2001a, 124, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac0000, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa60000, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac0000, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbd0000, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcb0000, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd20000, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd0000, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba0000, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa10000, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x791714, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3c0000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x700000, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb80016, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc70000, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc40000, 188, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbc0000, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa0001f, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4d0000, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 208, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x260000, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x961416, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xca0000, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd60000, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd10000, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcf0000, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaf0000, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x801817, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x340000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x620000, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa20017, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc50018, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc20000, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc70000, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd0000, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb7001e, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x600000, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1b0000, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 312, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x550000, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa1001f, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb30000, 348, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc50000, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd0000, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb70000, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8a1400, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x390000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x74192a, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb30000, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba0000, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc40000, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd10000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd70000, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd20000, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc40000, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb50000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaa0000, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa50000, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa30000, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa40000, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa50000, 432, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa40000, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa10000, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa30000, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa00000, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x980000, 460, 464, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x990000, 464, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x950019, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x851521, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x390000, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 480, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x430000, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d1715, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb50000, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbf0000, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac0000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9a0000, 564, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa70000, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa90000, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa50014, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa10016, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa20000, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb20000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc30000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc0000, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc30000, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa70000, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a0000, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3f0000, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 628, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x260000, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x340000, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x500000, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9e0015, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb80000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xae0000, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5f0000, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 704, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9f1920, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xca0000, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdf0000, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdb0000, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd0000, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba0000, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xae0000, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaa0000, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa40000, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa00000, 780, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa50000, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa90000, 792, 808, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa80000, 808, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa90014, 812, 816, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa60016, 816, 820, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9f0016, 820, 824, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x941617, 824, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d1a17, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6f1800, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x510000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x640000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaf0000, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd30000, 848, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc30000, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc50000, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc80000, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa21615, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x290000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 876, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4d0000, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x450000, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb20000, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbd0000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd0000, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd00000, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc90000, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc60000, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc00000, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac0000, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x910017, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6f2323, 932, 936, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1f0000, 936, 940, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_66:
						setup_general_paint (0x000000, 0, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x440000, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8e1816, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb60000, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd10000, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac0000, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaa0000, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb80000, 124, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb90000, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba0000, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc60000, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc80000, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc00000, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb00000, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x991500, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x701900, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x390000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6f0000, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb30016, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbf0000, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba0000, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbf0000, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb60000, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9b0025, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4d0000, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 208, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x90151a, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc00014, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc70000, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc40000, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc60000, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb00000, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x871515, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x420000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x410000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x660000, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9c0014, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb60014, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb20000, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb60000, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbc0000, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa90019, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5d0000, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 312, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x540000, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9c001b, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb10014, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb10000, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc60000, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb40000, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8b1500, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3d0000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x360000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x701824, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xab0000, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb20000, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc00000, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc0000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd70000, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd50000, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc90000, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbd0000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb70000, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb60000, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb70000, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba0000, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbe0000, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbd0000, 436, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb40000, 448, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb20000, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xad0000, 460, 464, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xab0000, 464, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa60014, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x91001b, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x410000, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 480, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 536, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c0000, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x821c1a, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb50018, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcc0014, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb30000, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb40000, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbe0000, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbc0000, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba0000, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb20000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb10000, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbc0000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc60000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc50000, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba0000, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa21700, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5b0000, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x320000, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 624, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x94191c, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaf0000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaa0000, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x580000, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x210000, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 696, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x931e24, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba0014, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xce0000, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd00000, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc90000, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbd0000, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbe0000, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc00000, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbd0000, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb90000, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb60000, 780, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb70000, 784, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbd0000, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 792, 800, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc00000, 800, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbf0000, 804, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbe0000, 812, 816, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xba0000, 816, 820, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb20000, 820, 824, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa90000, 824, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa20000, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x741700, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x590000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x680000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac0015, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc80000, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc70000, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb90000, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbf0000, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa01c1a, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 876, 884, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 884, 888, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d0000, 888, 892, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x250000, 892, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaf0000, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbe0000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc90000, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc80000, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc20000, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc10000, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc30000, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbc0000, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa6001b, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x842428, 932, 936, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 936, 940, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_67:
						setup_general_paint (0x000000, 0, 88, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 88, 92, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 92, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x781c21, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa20017, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbc0000, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb20000, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa50000, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa90000, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb80000, 124, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb50000, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xad0000, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac0000, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaf0000, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb10000, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaf0000, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa60000, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x981400, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8a1d1a, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x661d16, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x360000, 168, 172, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x390000, 172, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x660000, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9f0019, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa80000, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa10000, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa80000, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa1001b, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8b172a, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4a0018, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 208, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7f1a1e, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa9001e, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb00017, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaf0019, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb40000, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa20016, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7c1516, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x400000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3c0000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5d0000, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d0019, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa31e1f, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x971400, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x960000, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa00000, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x901819, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x530000, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 308, 312, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 312, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x460000, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x84171a, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x951516, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9c0000, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa80000, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xae0000, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa40015, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7f1c17, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x340000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b2027, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9b0015, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa10000, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xad0000, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbc0015, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc30014, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc00000, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb70000, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xab0000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa90000, 416, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac0014, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb00014, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb40000, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb50000, 436, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb40000, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaa0000, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xab0000, 452, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa80000, 460, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa40017, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d0019, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x430000, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 480, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 532, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x752023, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa2001c, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbc001a, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb40000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaa0000, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa80000, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb00000, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb60000, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb40000, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaa0000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa60000, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xad0000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb10000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xab0000, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa10000, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x891d00, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x460000, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x250000, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 624, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7a1e21, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x960014, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x940016, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x490000, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 696, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7c2126, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9d0018, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb00000, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb20000, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb10000, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa50000, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaa001a, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb60000, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb30000, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaf0000, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xad0000, 780, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb00000, 784, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb30000, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb60000, 792, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb30000, 804, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb10000, 812, 816, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaf0000, 816, 820, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa90000, 820, 824, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa10000, 824, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9b1400, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x731e19, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x540000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x590000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x960018, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb40000, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb71415, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa40000, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa70000, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xab0000, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x901e1e, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 876, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa60000, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac0015, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac0014, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa30000, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa10000, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa60000, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb00000, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb20014, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9a0014, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7a1920, 932, 936, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 936, 940, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_68:
						setup_general_paint (0x000000, 0, 96, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 96, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4d0019, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b0000, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x800000, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x770000, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6c0000, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6e0000, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6f0000, 124, 128, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x730000, 128, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6d0000, 132, 136, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6e0000, 136, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x710000, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x730000, 144, 148, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x700000, 148, 152, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x690000, 152, 156, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x620000, 156, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5c0000, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x430000, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x210000, 168, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x420000, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x690000, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b0000, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x610000, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x680000, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x640000, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x590019, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c0000, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 208, 236, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 236, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x540000, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6e0000, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6d0000, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a0000, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x710000, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a0000, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x520000, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 268, 272, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x260000, 272, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x580000, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x630000, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5c0000, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5b0000, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x640000, 296, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5d0000, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 308, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4f0000, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5c0000, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5e0000, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x670000, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6d0000, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b0000, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x550000, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x250000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4d161b, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5f0000, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x650000, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6d0000, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x770000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7b0000, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x790000, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6f0000, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x680000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6c0000, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6d0000, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x710000, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x740000, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x770000, 432, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x750000, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x740000, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x700000, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x710000, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x720000, 456, 464, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x740000, 464, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x750000, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x640000, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c0000, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 480, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x521618, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6f0000, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x800000, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x780000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6c0000, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a0000, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6e0000, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7c0000, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7a0000, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x700000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a0000, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x710000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x730000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x700000, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a0000, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x571400, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 620, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4e1615, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x620000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x600000, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2b0000, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 692, 736, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 736, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x500018, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x650000, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x750000, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x720000, 752, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b0000, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6f0000, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x770000, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x750000, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x710000, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x700000, 780, 784, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x710000, 784, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x740000, 788, 792, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x770000, 792, 796, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x740000, 796, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x720000, 804, 820, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6e0000, 820, 824, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6a0000, 824, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x670000, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x480000, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x640000, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x750000, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x720000, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x680000, 856, 860, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6f0000, 860, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x750000, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x610000, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 876, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6b0000, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x710000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6d0000, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x640000, 908, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6d0000, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x770000, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7f0000, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x710000, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x580016, 932, 936, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 936, 940, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_69:
						setup_general_paint (0x000000, 0, 100, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x200000, 100, 104, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 104, 108, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 108, 112, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x320000, 112, 116, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 116, 120, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 120, 124, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c0000, 124, 132, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x290000, 132, 140, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d0000, 140, 144, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 144, 160, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 160, 164, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 164, 168, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 168, 176, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 176, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 184, 188, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x210000, 188, 192, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d0000, 192, 196, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2b0000, 196, 200, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c0000, 200, 204, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 204, 208, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 208, 240, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2b0000, 240, 244, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 244, 248, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x390000, 248, 252, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 252, 256, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x360000, 256, 260, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 260, 264, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x250000, 264, 268, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 268, 276, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 276, 280, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c0000, 280, 284, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 284, 288, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x270000, 288, 292, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x260000, 292, 296, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 296, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x200000, 304, 308, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 308, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1e0000, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x230000, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 360, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2b0000, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d0000, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3e0000, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x360000, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 416, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 428, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d0000, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x340000, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 460, 464, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 464, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3c0000, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x340000, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 476, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2b0000, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x390000, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2b0000, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2b0000, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x320000, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x380000, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 612, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x250000, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2b0000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 688, 740, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x290000, 740, 744, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 744, 748, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3c0000, 748, 752, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 752, 756, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x340000, 756, 760, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 760, 764, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 764, 768, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x360000, 768, 772, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x330000, 772, 776, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 776, 780, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 780, 788, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 788, 796, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 796, 800, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2b0000, 800, 804, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 804, 808, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2b0000, 808, 812, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2d0000, 812, 816, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 816, 828, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c0000, 828, 832, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 832, 836, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 836, 840, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 840, 844, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2f0000, 844, 848, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3c0000, 848, 852, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x390000, 852, 856, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 856, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x410000, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 868, 872, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 872, 876, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 876, 896, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e0000, 896, 900, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 900, 904, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 904, 908, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x310000, 908, 912, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x300000, 912, 916, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x320000, 916, 920, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 920, 924, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x410000, 924, 928, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3a0000, 928, 932, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x280000, 932, 936, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_70:
						setup_general_paint (0x000000, 0, 180, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 180, 184, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 184, 300, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 300, 304, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 304, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 408, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 472, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 700, 704, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 704, 864, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 864, 868, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 868, 872, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_100:
						setup_general_paint (0x000000, 0, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x190000, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 452, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d8988, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 480, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8a8a8a, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f4f4, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 612, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 620, 628, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_101:
						setup_general_paint (0x000000, 0, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfaf8fd, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 480, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfafafa, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 612, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc6c6c6, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5e5e5, 624, 628, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_102:
						setup_general_paint (0x000000, 0, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8e8e8e, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd6d6d6, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb1b1b1, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdedede, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa2a2a2, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8e8e8e, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9d9d9, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe0e0e0, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb1b1b1, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe0e0e0, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaeaeae, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd8d8d8, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaaaaaa, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb0b0b0, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcec5c6, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb8b2b2, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc7c6c4, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xabb1af, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc9cbca, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb4b4b4, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc6c6c6, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 416, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x215b35, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x429b65, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3fa164, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x429e5f, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4ba460, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x489a5c, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x29683b, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 460, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x918b97, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfcff, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb1b1bb, 480, 484, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8f8c93, 484, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdedadb, 492, 496, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaeb0af, 496, 500, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd3d9d7, 500, 504, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa5a9a8, 504, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 508, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f5f5, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 532, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa9a9a9, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f8f8, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 560, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa3a3a3, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8c8c8c, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 576, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfcfc, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f5f5, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8c8c8c, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 604, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xadadad, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8f8f8f, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfafafa, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d8d8d, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 632, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xededed, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7e7e7e, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7d7d7d, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7b7b7b, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 684, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f4f4, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa4a4a4, 700, 704, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_103:
						setup_general_paint (0x000000, 0, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 328, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7d7d7d, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 356, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe4e4e4, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa8a8a8, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 368, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x827880, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa2acad, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffeff, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x827880, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa5abab, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 416, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001c00, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x35a863, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2ea75a, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x002900, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x002b00, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3ba259, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x459a61, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001400, 460, 464, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 464, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffdff, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 480, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdfd9db, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa5a4a2, 492, 496, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 496, 504, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbffff, 504, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 508, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdadada, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfcfc, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcacaca, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1f1f1, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb0b0b0, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbdbdb, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa7a7a7, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8f8f8f, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 596, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfcfc, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 612, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 620, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d8d8d, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 652, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 660, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5e5e5, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa6a6a6, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 700, 704, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_104:
						setup_general_paint (0x000000, 0, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 328, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 352, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb2b2b2, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb0b0b0, 368, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb5b5b5, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaaaaaa, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffeff, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9dee1, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 392, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaba6ac, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfff9ff, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5dee5, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 412, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001a00, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3e9b62, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x439b5f, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001c00, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x002300, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x439c62, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b9a6a, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001500, 460, 464, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 464, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffdff, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 480, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffdf7, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 492, 504, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfafcfb, 504, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 508, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7e7e7e, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 536, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 548, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 556, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 576, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 596, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 604, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 612, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 620, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 644, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 652, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 680, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb3b3b3, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb1b1b1, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb0b0b0, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb5b5b5, 700, 704, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_105:
						setup_general_paint (0x000000, 0, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 328, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 352, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0f0f0, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8e8e8e, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 368, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe0e5e1, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbffff, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 396, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe4e2e5, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcffff, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 416, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4e9168, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x5b986e, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001400, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001f00, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x479762, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4a9366, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001500, 460, 464, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 464, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffbfc, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 480, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffef7, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 492, 504, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffeff, 504, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 508, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 524, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 532, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 548, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 556, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfcfc, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 588, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 596, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 604, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 612, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 636, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 652, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 672, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xeeeeee, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8a8a8a, 688, 692, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_106:
						setup_general_paint (0x000000, 0, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 328, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 352, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc8c8c8, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9d9d9, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 368, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb1b1b1, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa9a9a9, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 384, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffffa, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa0aba5, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 404, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefdff, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 416, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4d966b, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b9b68, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001d00, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x002600, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x47a25f, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x529864, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 460, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfffbff, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 480, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdcdedd, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xacb1ad, 492, 496, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 496, 504, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefcff, 504, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 508, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd7d7d7, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcacaca, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa8a8a8, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xababab, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9d9d9, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaeaeae, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfcfc, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 596, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 612, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 632, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 644, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 652, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfcfc, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7e7e7e, 668, 672, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 672, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfafafa, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf4f4f4, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd6d6d6, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc3c3c3, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 700, 704, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_107:
						setup_general_paint (0x000000, 0, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc7c7c7, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb0b0b0, 332, 336, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdedede, 336, 340, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaeaeae, 340, 344, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8e8e8e, 344, 348, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 348, 352, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc4c4c4, 352, 356, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 356, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefefef, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc6c6c6, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc8c8c8, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa6a6a6, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefefef, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcfc8c0, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb6b1ab, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdadbd5, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe8f3ef, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc1cac9, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb0b3b8, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd8d7dd, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 416, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001b00, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3ba160, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x32a85c, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x35aa5b, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x43a05a, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x439354, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2e6637, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 460, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcac8cd, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe1e4e9, 480, 484, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaaafb3, 484, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd6dadd, 492, 496, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb5b6b8, 496, 500, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdadadc, 500, 504, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa9a4a8, 504, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 508, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7f7f7, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f8f8, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa2a2a2, 544, 548, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 548, 552, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfafafa, 552, 556, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 556, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa7a7a7, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8c8c8c, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 576, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb5b5b5, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 588, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb0b0b0, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcccccc, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 608, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe3e3e3, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc2c2c2, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 632, 640, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb2b2b2, 640, 644, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 644, 648, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf8f8f8, 648, 652, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb5b5b5, 652, 656, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 656, 660, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa3a3a3, 660, 664, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 664, 668, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 668, 676, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdadada, 676, 680, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 680, 684, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f5f5, 684, 688, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 688, 692, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf0f0f0, 692, 696, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 696, 700, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb6b6b6, 700, 704, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_108:
						setup_general_paint (0x000000, 0, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 328, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x001f00, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x33a256, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x30a652, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x002b00, 444, 448, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_109:
						setup_general_paint (0x000000, 0, 320, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8c8c8c, 320, 324, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 324, 328, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa5a5a5, 328, 332, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 332, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c532b, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x47965d, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x539d62, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2c672d, 444, 448, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_122:
						setup_general_paint (0x000000, 0, 484, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000015, 484, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 488, 512, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d8d8d, 512, 516, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 516, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8b8b8b, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xededed, 628, 632, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_123:
						setup_general_paint (0x000000, 0, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x170000, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 480, 484, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 484, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1b0000, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1a0000, 492, 496, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 496, 512, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfafafa, 512, 516, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 516, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc9c9c9, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe0e0e0, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf7f7f7, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 628, 632, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_124:
						setup_general_paint (0x000000, 0, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8c8c8c, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbdbdb, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb3b3b3, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9d9d9, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa8a8a8, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8a8a8a, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd5d5d5, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe4e4e4, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xafafaf, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2e2e2, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb3b3b3, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbdbdb, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xaaaaaa, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xacacac, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcacaca, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb6b6b6, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc6c6c6, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb3b3b3, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc7c7c7, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb2b1b6, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcfc4c2, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 456, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa53534, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xad3541, 480, 484, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb72d3a, 484, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd2e33, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb93735, 492, 496, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x220000, 496, 500, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 500, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x908c89, 508, 512, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 512, 516, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb2b2b2, 516, 520, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8b8b8b, 520, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9d9d9, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb1b1b1, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd8d8d8, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa9a9a9, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 544, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfafafa, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf5f5f5, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 576, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7d7d7d, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 588, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7d7d7d, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 600, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x909090, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfcfc, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d8d8d, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 624, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xacacac, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8e8e8e, 636, 640, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_125:
						setup_general_paint (0x000000, 0, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 368, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfcfc, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7b7b7b, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 396, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdfdfdf, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa4a4a4, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 408, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7c7c7c, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa4a4a4, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x787878, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb4a7a1, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 456, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1c0000, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb62424, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd32429, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb21725, 480, 484, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x790000, 484, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfa1420, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xec1b21, 492, 496, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x370000, 496, 500, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 500, 512, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 512, 516, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 516, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbdbdb, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa3a3a3, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 532, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 544, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe0e0e0, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfcfc, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcacaca, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 588, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 612, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 628, 632, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_126:
						setup_general_paint (0x000000, 0, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 368, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 392, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb8b8b8, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb5b5b5, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb0b0b0, 412, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa8a8a8, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfcfc, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe4e4e4, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 432, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa4a4a4, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc9ecf0, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 460, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x350000, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe11c2d, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd8242f, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 480, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe01f24, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfd1d28, 492, 496, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3e0000, 496, 500, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000014, 500, 504, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 504, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x210000, 508, 512, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 512, 516, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 516, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 528, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 544, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 568, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfcfc, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 588, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfcfc, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 612, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 628, 632, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_127:
						setup_general_paint (0x000000, 0, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 368, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 392, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf1f1f1, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8c8c8c, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 408, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2e2e2, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 436, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcae8f3, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfff3f8, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1f0000, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 460, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x400000, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf41834, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc62c38, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 480, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb33c36, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe41a26, 492, 496, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x410000, 496, 500, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000018, 500, 504, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 504, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x2a0000, 508, 512, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 512, 516, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 516, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 528, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 544, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 560, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 568, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 588, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfafafa, 628, 632, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_128:
						setup_general_paint (0x000000, 0, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 368, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 392, 400, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc7c7c7, 400, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd7d7d7, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 408, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb2b2b2, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa8a8a8, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 424, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xababab, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 444, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfff9fa, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 456, 460, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 460, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1b0000, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xac2220, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe2222d, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xca001f, 480, 484, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x810000, 484, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe4241f, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xbf2c22, 492, 496, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x1d0000, 496, 500, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 500, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 508, 512, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 512, 516, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 516, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdbdbdb, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb0b0b0, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 532, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 544, 560, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9d9d9, 560, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc7c7c7, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 588, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x7d7d7d, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa8a8a8, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 612, 616, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 616, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 628, 632, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_129:
						setup_general_paint (0x000000, 0, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc8c8c8, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb3b3b3, 372, 376, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdedede, 376, 380, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa7a7a7, 380, 384, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8d8d8d, 384, 388, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 388, 392, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc2c2c2, 392, 396, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 396, 404, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf3f3f3, 404, 408, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc5c5c5, 408, 412, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcbcbcb, 412, 416, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa9a9a9, 416, 420, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xededed, 420, 424, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc8c8c8, 424, 428, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb0b0b0, 428, 432, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9d9d9, 432, 436, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 436, 440, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xefefef, 440, 444, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc6c6c6, 444, 448, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa2b9b3, 448, 452, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdfd5d4, 452, 456, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 456, 468, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x180000, 468, 472, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x3b0000, 472, 476, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x9e3c39, 476, 480, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa13940, 480, 484, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc62a35, 484, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf41720, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xea1f23, 492, 496, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x380000, 496, 500, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 500, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x160000, 508, 512, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc7c7c7, 512, 516, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xe5e5e5, 516, 520, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb0b0b0, 520, 524, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 524, 528, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9d9d9, 528, 532, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb5b5b5, 532, 536, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd7d7d7, 536, 540, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa6a6a6, 540, 544, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 544, 564, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 564, 568, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 568, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfbfbfb, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 584, 588, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa9a9a9, 588, 592, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 592, 596, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfdfdfd, 596, 600, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 600, 604, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xdadada, 604, 608, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8b8b8b, 608, 612, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 612, 620, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xb3b3b3, 620, 624, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc7c7c7, 624, 628, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 628, 632, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfcfcfc, 632, 636, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xd9d9d9, 636, 640, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_130:
						setup_general_paint (0x000000, 0, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 368, 484, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x480000, 484, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf41a2b, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xf61422, 492, 496, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x4b0000, 496, 500, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 500, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x150000, 508, 512, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 512, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 580, 584, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_131:
						setup_general_paint (0x000000, 0, 360, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8c8c8c, 360, 364, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 364, 368, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa5a5a5, 368, 372, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 372, 484, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x532027, 484, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xc12f39, 488, 492, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xcd2d35, 492, 496, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x6f2327, 496, 500, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 500, 508, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x140000, 508, 512, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x000000, 512, 572, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x8e8e8e, 572, 576, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xffffff, 576, 580, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xfefefe, 580, 584, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0xa5a5a5, 584, 588, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW
				GAME_OVER_ROW_132:
						setup_general_paint (0x000000, 0, 488, LOOP_GAME_OVER_COLUMN)
						setup_general_paint (0x240000, 488, 496, LOOP_GAME_OVER_COLUMN)
						j UPDATE_GAME_OVER_ROW

    	UPDATE_GAME_OVER_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_GAME_OVER_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_GAME_OVER_COLUMN: bge $s3, $s4, EXIT_LOOP_GAME_OVER_COLUMN	# branch to UPDATE_GAME_OVER_COL; if column index >= last column index to paint
        		addi $s1, $0, display_base_address		# Reinitialize t2; temporary address store
        		addi $s1, $s1, 46080				# shift down 16 rows
        		add $s1, $s1, $s2				# update to specific row from base address
        		add $s1, $s1, $s3				# update to specific column
        		sw $s0, ($s1)					# paint in value

        		# Updates for loop index
        		addi $s3, $s3, column_increment			# t4 += row_increment
        		j LOOP_GAME_OVER_COLUMN				# repeats LOOP_GAME_OVER_ROW
	    EXIT_LOOP_GAME_OVER_COLUMN:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_GAME_OVER:
        		# Restore used registers
	    		pop_reg_from_stack ($s4)
	    		pop_reg_from_stack ($s3)
	    		pop_reg_from_stack ($s2)
	    		pop_reg_from_stack ($s1)
	    		pop_reg_from_stack ($s0)
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction

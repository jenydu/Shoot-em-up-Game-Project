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
# - Unit width in pixels: 2
# - Unit height in pixels: 2
# - Display width in pixels: 512
# - Display height in pixels: 512
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1 (choose the one that applies)
#
# Which approved features have been implemented for milestone 3?
# (See the assignment handout for the list of additional features)
# 1. Pickups (heart for health regen, and coins for score)
# 2. Scoring system (# of coins collected)
# 3. Increase in difficulty based on score (# of coins). 
# 	- Three levels (<5, <10, >=10 coins). 
# 	- More asteroids, different types (lasers that continously deducts health unless you avoid it)
# 	- Increased speed in each level and additional asteroids with surprising moving patterns in level 3 
#
# Link to video demonstration for final submission:
# - https://www.youtube.com/watch?v=6Ln81-7GRnI
#
# Are you OK with us sharing the video with people outside course staff?
# - yes
# - GitHub link: https://github.com/jenydu/Shoot-em-up-Game-Project
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
		# NOTE: $color_reg == $color_reg if $a1 == 1. Otherwise, $$color_reg == 0.
	.macro check_color ($color_reg)
		mult $a1, $color_reg
		mflo $color_reg
	.end_macro
	# MACRO: Updates $s0, $s3-4 for painting.
		# $s0: will hold %color
		# $s3: will hold start_idx
		# $s4: will hold end_idx
	.macro setup_general_paint (%color, %start_idx, %end_idx, %label)
		addi $s0, $0, %color		# change current color
		check_color ($s0)		# check if current parameter $a1 to paint/erase
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
		slti $s1, $col, 245
		and $s2, $s0, $s1			# 11 < col < 216
		# Row index in (18, 238)
		sgt $s0, $row, 18
		slti $s1, $row, 238
		and $bool_store, $s0, $s1		# 18 < row < 238
		and $bool_store, $bool_store, $s2	# make sure both inequalities are true
		# Restore $s0-1 values from stack.
		pop_reg_from_stack ($s2)
		pop_reg_from_stack ($s1)
		pop_reg_from_stack ($s0)
	.end_macro
	
	# MACRO: Generate number from [0, N]
		# Input
			# %n: value of N
		# Registers Used
			# $a0-1: used to generate random number
		# Output
			# $v0: randomly generated number
	.macro generate_random_number (%n)
		# Store used registers to stack
		push_reg_to_stack ($a0)
		push_reg_to_stack ($a1)
		# Randomly generate row value
		li $v0, 42 		# Specify random integer
		li $a0, 0 		# from 0
		li $a1, %n 		# to N
		syscall 		# generate and store random integer in $a0
		addi $v0, $a0, 0	# store result in $v0
		# Restore used registers from stack
		pop_reg_from_stack ($a1)
		pop_reg_from_stack ($a0)
	.end_macro
#___________________________________________________________________________________________________________________________
# ==INITIALIZATION==:
INITIALIZE:

# ==PARAMETERS==:
addi $s0, $0, 3					# starting number of hearts
addi $s1, $0, 0					# score counter
addi $s2, $0, 0					# stores current base address for coin
addi $s3, $0, 0					# stores current base address for heart
addi $s4, $0, column_increment			# movement speed

# ==SETUP==:
addi $a1, $0, 1					# paint param. set to paint
jal PAINT_BORDER		# Paint Border
jal UPDATE_HEALTH		# Paint Health Status
jal PAINT_BORDER_COIN		# Paint Score
# Paint Plane
addi $a0, $0, object_base_address		# start painting plane from top-left border
addi $a0, $a0, 96256				# center plane
push_reg_to_stack ($a0)				# store current plane address in stack
jal PAINT_PLANE					# paint plane at $a0
#---------------------------------------------------------------------------------------------------------------------------
GENERATE_OBSTACLES:
	# Used Registers:
		# $a0-2: parameters for painting obstacle
	# Outputs:
		# $s5: holds obstacle 1 base address
		# $s6: holds obstacle 2 base address
		# $s7: holds obstacle 3 base address
	# Obstacle 1
	jal generate_asteroid
	addi $s5, $a0, 0

	# Obstacle 2
	jal generate_asteroid
	addi $s6, $a0, 0

	# Obstacle 3
	jal generate_asteroid
	addi $s7, $a0, 0

	# coin
	jal generate_coin
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
		addi $a0, $s5, 0			# PAINT_ASTEROID param. Load obstacle 1 base address
		addi $a1, $zero, 0			# PAINT_ASTEROID param. Set to erase
		jal PAINT_ASTEROID

		calculate_indices ($s5, $t5, $t6)	# calculate column and row indexmove_heart
		ble $t5, 11, regen_obs_1

		subu $s5, $s5, $s4			# shift obstacle 1 unit left
		add $a0, $s5, $0 			# PAINT_ASTEROID param. Load obstacle 1 new base address
		addi $a1, $zero, 1			# PAINT_ASTEROID param. Set to paint
		jal PAINT_ASTEROID

	move_obs_2:
		addi $a0, $s6, 0			# PAINT_ASTEROID param. Load obstacle 1 base address
		addi $a1, $0, 0				# PAINT_ASTEROID param. Set to erase
		jal PAINT_ASTEROID

		calculate_indices ($s6, $t5, $t6)	# calculate column and row index
		ble $t5, 11, regen_obs_2

		subu $s6, $s6, $s4			# shift obstacle 1 unit left
		add $a0, $s6, $0 			# PAINT_ASTEROID param. Load obstacle 1 new base address
		addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
		jal PAINT_ASTEROID

	move_obs_3:
		addi $a0, $s7, 0			# PAINT_ASTEROID param. Load obstacle 1 base address
		addi $a1, $0, 0				# PAINT_ASTEROID param. Set to erase
		jal PAINT_ASTEROID

		calculate_indices ($s7, $t5, $t6)	# calculate column and row index
		ble $t5, 11, regen_obs_3

		subu $s7, $s7, $s4			# shift obstacle 1 unit left
		add $a0, $s7, $0			# PAINT_ASTEROID param. Load obstacle 1 new base address
		addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
		jal PAINT_ASTEROID

	level_2:
		bge $s1, 5, generate_level_2_obs	# when score reaches 5, spawn level 2 obstacles

	level_3:
		bge $s1, 10, generate_level_3_obs	# when score reaches 10, spawn level 3 obstacles
	
	move_heart: beq $s3, 0 RANDOM_GENERATE_HEART	# if heart address is not 0, move heart left
		addi $a0, $s3, 0			# PAINT_ASTEROID param. Load obstacle 1 base address
		addi $a1, $0, 0				# PAINT_ASTEROID param. Set to erase
		jal PAINT_PICKUP_HEART

		calculate_indices ($s3, $t5, $t6)	# calculate column and row index
		ble $t5, 11, RANDOM_GENERATE_HEART	# if end of screen, try to generate heart

		subu $s3, $s3, 4			# shift obstacle 1 unit left
		add $a0, $s3, $0			# PAINT_ASTEROID param. Load obstacle 1 new base address
		addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
		jal PAINT_PICKUP_HEART
	
	# Generate heart if no heart currently exists
	RANDOM_GENERATE_HEART: bne $s3, 0, EXIT_OBSTACLE_MOVE	# branch if current heart base address != 0
		generate_random_number (300)		# randomly generate number from 0 to N=511
		beq $v0, 0, regen_heart			# if equal to 0, create heart. Stores new heart address in $s3

	EXIT_OBSTACLE_MOVE:
	
	GENERATE_COIN:
		# RE-DRAW the coin every loop so that it doesn't get erased when an obstacle flies over it
		add $a0, $s2, $0			# PAINT_PICKUP_COIN param. Load base address
		addi $a1, $0, 1				# PAINT_PICKUP_COIN param. Set to paint
		jal PAINT_PICKUP_COIN

	CHECK_COLLISION:
		pop_reg_from_stack ($a0)			# restore $a0 to plane's address
		jal COLLISION_DETECTOR			# check if the plane's hitbox is overlapped with an object based on colour


	j MAIN_LOOP				# repeat loop
#---------------------------------------------------------------------------------------------------------------------------
# END GAME LOOP
END_SCREEN_LOOP:
	jal CLEAR_SCREEN			# reset to black screen
	jal PAINT_GAME_OVER			# create game over screen
	jal PAINT_FINAL_SCORE
	
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

generate_level_2_obs:
	beq $s4, 4, generate_lasers
	j move_lasers

generate_lasers:
	addi $s4, $0, 8		# double asteroid moving speed

	# generate laser 1 (in $t1)
	add $a3, $0, $0				# RANDOM_OFFSET param. Don't add random column offset.
	jal RANDOM_OFFSET			# create random address offset
	add $a0, $v0, object_base_address	# store obstacle address = object_base_address + random offset
	addi $a0, $a0, 900			# set obstacle spawn column to 225
	addi $t1, $a0, 0
	addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
	jal PAINT_LASER

	# generate laser 2 (in $t2)
	add $a3, $0, $0				# RANDOM_OFFSET param. Don't add random column offset.
	jal RANDOM_OFFSET			# create random address offset
	add $a0, $v0, object_base_address	# store obstacle address = object_base_address + random offset
	addi $a0, $a0, 900			# set obstacle spawn column to 225
	addi $t2, $a0, 0
	addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
	jal PAINT_LASER

	j move_lasers

move_lasers:
		move_laser_1:
		# laser 1
		addi $a0, $t1, 0			# PAINT_ASTEROID param. Load obstacle 1 base address
		addi $a1, $0, 0				# PAINT_ASTEROID param. Set to erase
		jal PAINT_LASER

		calculate_indices ($t1, $t5, $t6)	# calculate column and row index
		ble $t5, 11, regen_laser_1

		subu $t1, $t1, $s4			# shift obstacle 1 unit left
		add $a0, $t1, $0			# PAINT_ASTEROID param. Load obstacle 1 new base address
		addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
		jal PAINT_LASER

		move_laser_2:
		# laser 2
		addi $a0, $t2, 0			# PAINT_ASTEROID param. Load obstacle 1 base address
		addi $a1, $0, 0				# PAINT_ASTEROID param. Set to erase
		jal PAINT_LASER

		calculate_indices ($t2, $t5, $t6)	# calculate column and row index
		ble $t5, 11, regen_laser_2

		subu $t2, $t2, $s4			# shift obstacle 1 unit left
		add $a0, $t2, $0			# PAINT_ASTEROID param. Load obstacle 1 new base address
		addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
		jal PAINT_LASER

		j level_3

regen_laser_1:
	add $a3, $0, $0				# RANDOM_OFFSET param. Don't add random column offset.
	jal RANDOM_OFFSET			# create random address offset
	add $a0, $v0, object_base_address	# store obstacle address = object_base_address + random offset
	addi $a0, $a0, 900			# set obstacle spawn column to 225
	addi $t1, $a0, 0
	addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
	jal PAINT_LASER
	j move_laser_2

regen_laser_2:
	add $a3, $0, $0				# RANDOM_OFFSET param. Don't add random column offset.
	jal RANDOM_OFFSET			# create random address offset
	add $a0, $v0, object_base_address	# store obstacle address = object_base_address + random offset
	addi $a0, $a0, 900			# set obstacle spawn column to 225
	addi $t2, $a0, 0
	addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
	jal PAINT_LASER
	j level_3

generate_level_3_obs:
	beq $s4, 8, generate_obs_4_5
	j move_level_3_obs

generate_obs_4_5:
	addi $s4, $0, 12		# double asteroid moving speed

	# generate obs 4 (in $t3)
	add $a3, $0, $0				# RANDOM_OFFSET param. Don't add random column offset.
	jal RANDOM_OFFSET			# create random address offset
	add $a0, $v0, object_base_address	# store obstacle address = object_base_address + random offset
	addi $a0, $a0, 900			# set obstacle spawn column to 225
	addi $t3, $a0, 0
	addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
	jal PAINT_ASTEROID

	# generate obs 5 (in $t3)
	add $a3, $0, $0				# RANDOM_OFFSET param. Don't add random column offset.
	jal RANDOM_OFFSET			# create random address offset
	add $a0, $v0, object_base_address	# store obstacle address = object_base_address + random offset
	addi $a0, $a0, 900			# set obstacle spawn column to 225
	addi $t4, $a0, 0
	addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
	jal PAINT_ASTEROID

	j  move_level_3_obs

move_level_3_obs:
		move_obs_4:
		# obs 4
		addi $a0, $t3, 0			# PAINT_ASTEROID param. Load obstacle 1 base address
		addi $a1, $zero, 0			# PAINT_ASTEROID param. Set to erase
		jal PAINT_ASTEROID

		calculate_indices ($t3, $t5, $t6)	# calculate column and row index
		ble $t5, 11, regen_obs_4
		ble $t6, 18, regen_obs_4
		bge $t6, 238, regen_obs_4

		subu $t3, $t3, $s4			# shift obstacle 1 unit left
		addu $t3, $t3, 2048
		add $a0, $t3, $0 			# PAINT_ASTEROID param. Load obstacle 1 new base address
		addi $a1, $zero, 1			# PAINT_ASTEROID param. Set to paint
		jal PAINT_ASTEROID

		move_obs_5:
		# obs 5
		addi $a0, $t4, 0			# PAINT_ASTEROID param. Load obstacle 1 base address
		addi $a1, $zero, 0			# PAINT_ASTEROID param. Set to erase
		jal PAINT_ASTEROID

		calculate_indices ($t4, $t5, $t6)	# calculate column and row index
		ble $t5, 11, regen_obs_5
		ble $t6, 18, regen_obs_5
		bge $t6, 238, regen_obs_5
		
		subu $t4, $t4, $s4			# shift obstacle 1 unit left
		subu $t4, $t4, 2048
		add $a0, $t4, $0 			# PAINT_ASTEROID param. Load obstacle 1 new base address
		addi $a1, $zero, 1			# PAINT_ASTEROID param. Set to paint
		jal PAINT_ASTEROID

		j move_heart


#___________________________________________________________________________________________________________________________
generate_asteroid:
	# randomly generates an obstacle with address stored in $a0
	push_reg_to_stack ($ra)
	add $a3, $0, $0				# RANDOM_OFFSET param. Don't add random column offset.
	jal RANDOM_OFFSET			# create random address offset
	add $a0, $v0, object_base_address	# store obstacle address = object_base_address + random offset
	addi $a0, $a0, 900			# set obstacle spawn column to 225
	addi $a1, $0, 1				# PAINT_ASTEROID param. Set to paint
	jal PAINT_ASTEROID
	pop_reg_from_stack ($ra)
	jr $ra
# REGENERATE OBSTACLES
regen_obs_1:
	jal generate_asteroid
	addi $s5, $a0, 0
	j move_obs_2

regen_obs_2:
	jal generate_asteroid
	addi $s6, $a0, 0
	j move_obs_3

regen_obs_3:
	jal generate_asteroid
	addi $s7, $a0, 0
	j level_2

regen_obs_4:
	jal generate_asteroid
	addi $t3, $a0, 0
	j move_obs_5

regen_obs_5:
	jal generate_asteroid
	addi $t4, $a0, 0
	j move_heart

regen_heart:
	jal generate_heart
	addi $s3, $a0, 0
	j level_2
#___________________________________________________________________________________________________________________________
# FUNCTION: COLLISION_DETECTOR
	# Registers Used
		# $t0: for loop indexer for plane_hitbox_loop
		# $t1: plane_hitbox_loop param. Specifies number of rows to offset from center (above and below) to check pixels
		# $t2: used to store current color at pixel
		# $t3: used in address offset calculations
		# $t9: temporary memory address storage
	# Registers Updated
		# $s0: update global health points variable (if collision with heart)
		# $s1: update global score variable (if collision with coin)
COLLISION_DETECTOR:
	# Save used registers to stack
        	push_reg_to_stack ($t0)
        	push_reg_to_stack ($t1)
        	push_reg_to_stack ($t2)
        	push_reg_to_stack ($t5)
        	push_reg_to_stack ($t9)
        	push_reg_to_stack ($ra)

        check_plane_hitbox:			# check specific columns of plane for collision
        	# Column 26
        	addi $t0, $0, 0			# initialize for loop indexer;	i = 0
        	addi $t1, $0, 2			# plane_hitbox_loop param. check __ rows from the center
        	addi $t9, $0, 104		# specify column offset = (column index * 4)
        	addi $t9, $t9, plane_center	# begin from row center of plane
        	add $t9, $t9, $a0		# store memory address for pixel at column index and at the center of the plane
        	jal plane_hitbox_loop
        	# Column 1
        	addi $t0, $0, 0			# initialize for loop indexer;	i = 0
        	addi $t1, $0, 6		# plane_hitbox_loop param. check __ rows from the center
        	addi $t9, $0, 4		# specify column offset = (column index * 4)
        	addi $t9, $t9, plane_center	# begin from row center of plane
        	add $t9, $t9, $a0		# store memory address for pixel at column index and at the center of the plane
        	jal plane_hitbox_loop
        	# Column 23
        	addi $t0, $0, 0			# initialize for loop indexer;	i = 0
        	addi $t1, $0, 2			# plane_hitbox_loop param. check __ rows from the center
        	addi $t9, $0, 92		# specify column offset = (column index * 4)
        	addi $t9, $t9, plane_center	# begin from row center of plane
        	add $t9, $t9, $a0		# store memory address for pixel at column index and at the center of the plane
        	jal plane_hitbox_loop
        	# Column 20
        	addi $t0, $0, 0			# initialize for loop indexer;	i = 0
        	addi $t1, $0, 3			# plane_hitbox_loop param. check __ rows from the center
        	addi $t9, $0, 80		# specify column offset = (column index * 4)
        	addi $t9, $t9, plane_center	# begin from row center of plane
        	add $t9, $t9, $a0		# store memory address for pixel at column index and at the center of the plane
        	jal plane_hitbox_loop
        	# Column 18
        	addi $t0, $0, 0			# initialize for loop indexer;	i = 0
        	addi $t1, $0, 16		# plane_hitbox_loop param. check __ rows from the center
        	addi $t9, $0, 72		# specify column offset = (column index * 4)
        	addi $t9, $t9, plane_center	# begin from row center of plane
        	add $t9, $t9, $a0		# store memory address for pixel at column index and at the center of the plane
        	jal plane_hitbox_loop
        	# Column 15
        	addi $t0, $0, 0			# initialize for loop indexer;	i = 0
        	addi $t1, $0, 16		# plane_hitbox_loop param. check __ rows from the center
        	addi $t9, $0, 60		# specify column offset = (column index * 4)
        	addi $t9, $t9, plane_center	# begin from row center of plane
        	add $t9, $t9, $a0		# store memory address for pixel at column index and at the center of the plane
        	jal plane_hitbox_loop

        	j exit_check_plane_hitbox

        plane_hitbox_loop:
        	bgt $t0, $t1, exit_plane_hitbox_loop	# if i > 32, exit loop
        	addi $t5, $t0, 0			# store current row index
        	sll $t5, $t5, 10			# calculate row offset = (1024 * row index)

        	subu $t9, $t9, $t5			# check pixel $t0 rows above
        	lw $t2, ($t9)				# load pixel colour at the address
		# if incorrect pixel color found
        	beq $t2, 0x896e5d, deduct_health	# if the pixel has asteroid colour, deduct heart by 1
        	beq $t2, 0xff0000, add_health		# if pixel of heart pickup color, add heart by 1
        	beq $t2, 0xbaba00, add_score		# if pixel of coin pickup color, add score by 1

        	add $t9, $t9, $t5			# reset back to center
        	add $t9, $t9, $t5			# check pixel $t0 rows below
        	lw $t2, ($t9)				# load pixel colour at the address
		# if incorrect pixel color found
        	beq $t2, 0x896e5d, deduct_health	# if the pixel has asteroid colour, deduct heart by 1
        	beq $t2, 0x00cb0d, deduct_health
        	beq $t2, 0xff0000, add_health		# if pixel of heart pickup color, add heart by 1
        	beq $t2, 0xbaba00, add_score		# if pixel of coin pickup color, add score by 1

        	# repeat loop
        	addi $t0, $t0, 1			# update for loop indexer;	i += 1
        	subu $t9, $t9, $t5			# reset back to center
        	j plane_hitbox_loop

        	exit_plane_hitbox_loop:			# return to previous instruction
        		jr $ra

        deduct_health:
        	push_reg_to_stack ($a0)
   		push_reg_to_stack ($a1)
        	
        	jal check_asteroid_distances		# the address of the closest asteroid will be stored in $a0

		pop_reg_from_stack($a1)
        	pop_reg_from_stack($a0)
        	
        	subi $s0, $s0, 1			# health -= 1
        	jal UPDATE_HEALTH			# update health on border
        	beq $s0, 0, END_SCREEN_LOOP		# Go to game over screen if 0 health
   		
        	j exit_check_plane_hitbox		# exit collision check

        add_health:
        	beq $s0, 5, skip_add_health		# maximum health points is 5
        	addi $s0, $s0, 1			# health += 1
        	jal UPDATE_HEALTH			# update health on border

        	skip_add_health:
        	push_reg_to_stack ($a0)			# stores away plane address
        	push_reg_to_stack ($a1)
		add $a0, $s3, $0			# PAINT_PICKUP_COIN param. Load base address
		addi $a1, $0, 0				# PAINT_PICKUP_COIN param. Set to erase
		jal PAINT_PICKUP_HEART			# erase current heart
		
		addi $s3, $0, 0				# set current heart address to 0. Will regenerate heart at a 1/512 probability in main loop
		
		pop_reg_from_stack($a1)
		pop_reg_from_stack($a0)			# retrieve plane address

        	j exit_check_plane_hitbox		# exit collision check

        add_score:
        	jal UPDATE_SCORE			# score += 1

		push_reg_to_stack ($a0)			# stores away plane address
		add $a0, $s2, $0			# PAINT_PICKUP_COIN param. Load base address
		addi $a1, $0, 0				# PAINT_PICKUP_COIN param. Set to erase
		jal PAINT_PICKUP_COIN
		jal generate_coin
		pop_reg_from_stack($a0)			# retrieve plane address

        	j exit_check_plane_hitbox

	exit_check_plane_hitbox:			# return to previous instruction
        	pop_reg_from_stack($ra)
        	pop_reg_from_stack($t9)

        	pop_reg_from_stack($t5)

        	pop_reg_from_stack($t2)
        	pop_reg_from_stack($t1)
        	pop_reg_from_stack($t0)
        	jr $ra
# -------------------------------------------------------------------------------------------------------------------------
check_asteroid_distances:
	# check the distance of each asteroid in comparison to $t9 (the pixel which collision happened)
	push_reg_to_stack($ra)
	beq $t2, 0x00cb0d, exit_loop
	
	# $t5 = $s5 - $t9
	# $t6 = $s6 - $t9
	# $t7 = $s7 - $t9
	# $t8: temp. storage for the smallest difference between asteroid address and address of collision ($t9)
	sub $t5, $s5, $t9
	abs $t5, $t5
	sub $t6, $s6, $t9
	abs $t6, $t6
	sub $t7, $s7, $t9
	abs $t7, $t7

	blt $t5, $t6, L0	# t5 < t6
	blt $t6, $t7, L1	# t6 <= t5 AND t6 <t7
	addi $a0, $s7, 0	# t7 <= t6 <= t5
	addi $t8, $t7, 0	# t7 <= t6 <= t5
	beq $s4, 12, check_level_3
	j redraw_closest

L0:	blt $t5, $t7, L2	# t5 < t7
	addi $a0, $s7, 0	# t6 > t5 >= t7, so t7 smallest
	addi $t8, $t7, 0
	beq $s4, 12, check_level_3
	j redraw_closest

L1:	addi $a0, $s6, 0	# t6 smallest
	addi $t8, $t6, 0
	beq $s4, 12, check_level_3
	j redraw_closest
	
L2:	addi $a0, $s5, 0	# t5 smallest
	addi $t8, $t5, 0
	beq $s4, 12, check_level_3
	j redraw_closest

check_level_3:			# compare the difference in address of the two new asteroids to the smallest of the three original ones
	sub $t1, $t3, $t9
	abs $t1, $t1
	sub $t2, $t4, $t9
	abs $t2, $t2
	
	blt $t1, $t8, L3	# 
	blt $t2, $t8, L5	# 
	j redraw_closest	
	
L3:	blt $t2, $t1, L4	# 
	addi $a0, $t3, 0
	j redraw_closest

L4:	addi $a0, $t4, 0	
	j redraw_closest

L5: 	blt $t2, $t1, L4
	addi $a0, $t3, 0
	j redraw_closest

redraw_closest:
	addi $a1, $0, 1				# PAINT_EXPLOSION param. Set to paint
	jal PAINT_EXPLOSION			# paint explosion at asteroid base address

	# Add small delay to show explosion
	add $t8, $a0, 0
	li $v0, 32
	li $a0, 100				# add 0.1 second delay
	syscall
	add $a0, $t8, 0
		
	addi $a1, $0, 0				# PAINT_ASTEROID param. Set to erase
	addi $a2, $0, 0				# erase current asteroid

	beq $s5, $a0, closest_obs_1
	beq $s6, $a0, closest_obs_2
	beq $s7, $a0, closest_obs_3
	beq $t3, $a0, closest_obs_4
	beq $t4, $a0, closest_obs_5
	#default
	jal PAINT_ASTEROID
	jal generate_asteroid
	addi $s5, $a0, 0
	j exit_loop
		
closest_obs_1:			# remove and regenerate asteroid in address $s5
	jal PAINT_ASTEROID
	jal generate_asteroid
	addi $s5, $a0, 0
	j exit_loop

closest_obs_2:			# remove and regenerate asteroid in address $s6
	jal PAINT_ASTEROID
	jal generate_asteroid
	addi $s6, $a0, 0
	j exit_loop
	
closest_obs_3:			# remove and regenerate asteroid in address $s7
	jal PAINT_ASTEROID
	jal generate_asteroid
	addi $s7, $a0, 0
	j exit_loop	
	
closest_obs_4:			# remove and regenerate asteroid in address $t3
	jal PAINT_ASTEROID
	jal generate_asteroid
	addi $t3, $a0, 0
	j exit_loop
	
closest_obs_5:			# remove and regenerate asteroid in address $t4
	jal PAINT_ASTEROID
	jal generate_asteroid
	addi $t4, $a0, 0
	j exit_loop	

exit_loop: 	pop_reg_from_stack ($ra)
		jr $ra
#___________________________________________________________________________________________________________________________
# REGENERATE PICKUPS
generate_coin:	
	push_reg_to_stack ($ra)
	addi $a3, $0, 1				# RANDOM_OFFSET param. Add random column offset.
	jal RANDOM_OFFSET			# create random address offset
	add $a0, $v0, object_base_address	# store pickup coin address
	add $s2, $a0, $0			# PAINT_PICKUP_COIN param. Load base address
	addi $a1, $0, 1				# PAINT_PICKUP_COIN param. Set to paint
	jal PAINT_PICKUP_COIN
	pop_reg_from_stack ($ra)
	jr $ra

generate_heart:
	push_reg_to_stack ($ra)
	addi $a3, $0, 0				# RANDOM_OFFSET param. Don't add random column offset.
	jal RANDOM_OFFSET			# create random address offset
	add $s3, $v0, object_base_address	# store pickup heart address
	add $s3, $s3, 900			# set obstacle spawn column to 225
	addi $a0, $s3, 0			# PAINT_PICKUP_COIN param. Load base address
	addi $a1, $0, 1				# PAINT_PICKUP_COIN param. Set to paint
	jal PAINT_PICKUP_HEART
	pop_reg_from_stack ($ra)
	jr $ra
#___________________________________________________________________________________________________________________________
# ==USER INPUT==
USER_INPUT:
	check_key_press:	lw $t8, 0xffff0000		# load the value at this address into $t8
				bne $t8, 1, EXIT_KEY_PRESS	# if $t8 != 1, then no key was pressed, exit the function
				lw $t7, 0xffff0004		# load the ascii value of the key that was pressed

	check_border:		la $t0, ($a0)			# load ___ base address to $t0
				calculate_indices ($t0, $t5, $t6)	# calculate column and row index

				beq $t7, 0x61, respond_to_a 	# ASCII code of 'a' is 0x61 or 97 in decimal
				beq $t7, 0x77, respond_to_w	# ASCII code of 'w'
				beq $t7, 0x73, respond_to_s	# ASCII code of 's'
				beq $t7, 0x64, respond_to_d	# ASCII code of 'd'
				beq $t7, 0x70, respond_to_p	# restart game when 'p' is pressed
				beq $t7, 0x71, respond_to_q	# exit game when 'q' is pressed
				beq $t7, 0x67, respond_to_g	# if 'g', branch to END_SCREEN_LOOP
				j EXIT_KEY_PRESS		# invalid key, exit the input checking stage

	respond_to_a:		ble $t5, 11, EXIT_KEY_PRESS	# the avatar is on left of screen, cannot move up
				subu $t0, $t0, column_increment	# set base position 1 pixel left
				ble $t6, 12, draw_new_avatar	# if after movement, avatar is now at border, draw
				subu $t0, $t0, column_increment	# set base position 1 pixel left
				ble $t6, 13, draw_new_avatar	# if after movement, avatar is now at border, draw
				subu $t0, $t0, column_increment	# set base position 1 pixel left
				j draw_new_avatar

	respond_to_w:		ble $t6, 18, EXIT_KEY_PRESS	# the avatar is on top of screen, cannot move up
				subu $t0, $t0, row_increment	# set base position 1 pixel up
				ble $t6, 19, draw_new_avatar	# if after movement, avatar is now at border, draw
				subu $t0, $t0, row_increment	# set base position 1 pixel up
				ble $t6, 20, draw_new_avatar	# if after movement, avatar is now at border, draw
				subu $t0, $t0, row_increment	# set base position 1 pixel up
				j draw_new_avatar

	respond_to_s:		bgt $t6, 206, EXIT_KEY_PRESS
				add $t0, $t0, row_increment	# set base position 1 pixel down
				bge $t6, 207, draw_new_avatar	# if after movement, avatar is now at border, draw
				add $t0, $t0, row_increment	# set base position 1 pixel down
				bge $t6, 208, draw_new_avatar	# if after movement, avatar is now at border, draw
				add $t0, $t0, row_increment	# set base position 1 pixel down
				j draw_new_avatar

	respond_to_d:		bgt $t5, 214, EXIT_KEY_PRESS
				add $t0, $t0, column_increment	# set base position 1 pixel right
				bge $t6, 215, draw_new_avatar	# if after movement, avatar is now at border, draw
				add $t0, $t0, column_increment	# set base position 1 pixel right
				bge $t6, 216, draw_new_avatar	# if after movement, avatar is now at border, draw
				add $t0, $t0, column_increment	# set base position 1 pixel right
				j draw_new_avatar

	draw_new_avatar:	addi $a1, $zero, 0		# set $a1 as 0
				jal PAINT_PLANE			# (erase plane) paint plane black

				la $a0, ($t0)			# load new base address to $a0
				addi $a1, $zero, 1		# set $a1 as 1
				jal PAINT_PLANE			# paint plane at new location
				j EXIT_KEY_PRESS
	# restart game
	respond_to_p:		jal CLEAR_SCREEN
				# Reinitialize registers
				addi $a0, $0, 0
				addi $a1, $0, 0
				addi $a2, $0, 0
				
				j INITIALIZE
	# quit game
	respond_to_q:		jal CLEAR_SCREEN
				j EXIT
	# go to gameover screen
	respond_to_g:		j END_SCREEN_LOOP

	EXIT_KEY_PRESS:
		j OBSTACLE_MOVE			# avatar finished moving, move to next stage
#___________________________________________________________________________________________________________________________
# ==FUNCTIONS==:
# FUNCTION: Create random address offset
	# Inputs
		# $a3: specifies whether to add random column offset or not
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
	# This will make the object spawn on the rightmost column of the screen at a random row
	# Store used registers to stack
	push_reg_to_stack ($a0)
	push_reg_to_stack ($a1)
	push_reg_to_stack ($s0)
	push_reg_to_stack ($s1)
	push_reg_to_stack ($s2)

	# Randomly generate row value
	li $v0, 42 		# Specify random integer
	li $a0, 0 		# from 0
	li $a1, 188 		# to 188
	syscall 		# generate and store random integer in $a0

	addi $s0, $0, row_increment	# store row increment in $s0
	mult $a0, $s0			# multiply row index to row increment
	mflo $s2			# store result in $s2

	beq $a3, 0, END_RANDOM_OFFSET		# if $a3 == 0, don't add random column offset
		li $v0, 42 		# Specify random integer
		li $a0, 0 		# from 0
		li $a1, 210# to 220
		syscall 		# Generate and store random integer in $a0
		addi $a0, $a0, 10
		addi $s0, $0, column_increment	# store column increment in $s0
		mult $a0, $s0			# multiply column index to column increment
		mflo $s1			# store result in s1
		add $s2, $s2, $s1		# add column address offset to base address

	END_RANDOM_OFFSET:
		add $v0, $s2, $0		# store return value (address offset) in $v0

		# Restore used registers from stack
		pop_reg_from_stack ($s2)
		pop_reg_from_stack ($s1)
		pop_reg_from_stack ($s0)
		pop_reg_from_stack ($a1)
		pop_reg_from_stack ($a0)
		jr $ra			# return to previous instruction
#___________________________________________________________________________________________________________________________
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
			check_color ($t1)			# updates color according to func. param. $a1
	                add $t2, $a0, $t3		# update to specific column from base address
	            	addi $t2, $t2, plane_center	# update to specified center axis
	           	sw $t1, ($t2)			# paint at center axis
	           	j UPDATE_COL			# end iteration
		PLANE_COL_1_2:
			addi $t1, $0, 0x255E90		# change current color to dark blue
			check_color ($t1)			# updates color according to func. param. $a1
	    		set_row_incr (6)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_3:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color ($t1)			# updates color according to func. param. $a1
	    		set_row_incr (4)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_4_7:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color ($t1)			# updates color according to func. param. $a1
	    		set_row_incr (2)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_8_13:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color ($t1)			# updates color according to func. param. $a1
	    		set_row_incr (3)		# update row for column
    			j LOOP_PLANE_ROWS		# paint in row
                	j UPDATE_COL			# end iteration
		PLANE_COL_14:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color ($t1)			# updates color according to func. param. $a1
	    		set_row_incr (8)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
        	        j UPDATE_COL			# end iteration
		PLANE_COL_15_18:
			addi $t1, $0, 0x255E90		# change current color to dark blue
			check_color ($t1)			# updates color according to func. param. $a1
	    		set_row_incr (16)		# update row for column
	    		j LOOP_PLANE_ROWS		# paint in row
	                j UPDATE_COL			# end iteration
		PLANE_COL_19_21:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color ($t1)			# updates color according to func. param. $a1
	    		set_row_incr (3)		# update row for column
	            	j LOOP_PLANE_ROWS		# paint in row
	            	j UPDATE_COL			# end iteration
		PLANE_COL_22_24:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color ($t1)			# updates color according to func. param. $a1
			set_row_incr (2)		# update row for column
			j LOOP_PLANE_ROWS		# paint in row
			j UPDATE_COL			# end iteration
		PLANE_COL_25:
			addi $t1, $0, 0x29343D		# change current color to dark gray
			check_color ($t1)			# updates color according to func. param. $a1
			add $t2, $0, $0			# reinitialize temporary address store
			add $t2, $a0, $t3		# update to specific column from base address
			addi $t2, $t2, plane_center	# update to specified center axis
			sw $t1, ($t2)			# paint at center axis
			j UPDATE_COL			# end iteration
		PLANE_COL_26:
			addi $t1, $0, 0x255E90		# change current color to dark blue
			check_color ($t1)			# updates color according to func. param. $a1
			set_row_incr (2)		# update row for column
			j LOOP_PLANE_ROWS		# paint in row
			j UPDATE_COL			# end iteration
		PLANE_COL_27:
			addi $t1, $0, 0x803635		# change current color to dark red
			check_color ($t1)			# updates color according to func. param. $a1
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
# FUNCTION: PAINT LASER
	# Inputs
		# $a0: object base address
		# $a1: If 0, paint in black. Elif 1, paint in color specified otherwise.
		# $a2: random address offset
	# Registers Used
		# $t1: stores current color value
		# $t2: temporary memory address storage for current unit (in bitmap)
		# $t3: column index for 'for loop' LOOP_LASER_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $t4: row index for 'for loop' LOOP_LASER_ROWS
		# $t5: parameter for subfunction LOOP_LASER_ROWS. Will store # rows to paint from the center row outwards
		# $t8-9: used for multiplication/logical operations
PAINT_LASER:
	# Store used registers to stack
	push_reg_to_stack ($t1)
	push_reg_to_stack ($t2)
	push_reg_to_stack ($t3)
	push_reg_to_stack ($t4)
	push_reg_to_stack ($t5)
	push_reg_to_stack ($t8)
	push_reg_to_stack ($t9)
	# Initialize registers
	addi $t1, $0, 0x00cb0d			# change current color to bright freen
	add $t2, $0, $0				# holds temporary memory address
	add $t3, $0, $0				# holds 'column for loop' indexer
	add $t4, $0, $0				# holds 'row for loop' indexer

	check_color ($t1)			# updates color according to func. param. $a1

	# FOR LOOP: (through col)
	LOOP_LASER_COLS: bge $t3, 128, EXIT_PAINT_LASER
		addi $t5, $0, 2048				# $t5 = %y * row_increment		(lower 32 bits)
		j LOOP_LASER_ROWS			# paint in row
	UPDATE_LASER_COL:				# Update column value
		addi $t3, $t3, column_increment	# add 4 bits (1 byte) to refer to memory address for next row
		add $t4, $0, $0			# reinitialize index for LOOP_LASER_ROWS
		j LOOP_LASER_COLS
	EXIT_PAINT_LASER:
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
	LOOP_LASER_ROWS: bge $t4, $t5, UPDATE_LASER_COL	# returns when row index (stored in $t4) >= (number of rows to paint in) /2
		add $t2, $a0, $0			# start from base address
		add $t2, $t2, $t3			# update to specific column
		add $t2, $t2, $t4			# update to specific row
		add $t2, $t2, $a2			# update to random offset

		calculate_indices ($t2, $t8, $t9)	# get address indices. Store in $t8 and $t9
		within_borders ($t8, $t9, $t9)		# check within borders. Store boolean result in $t9
		beq $t9, 0, SKIP_LASER_PAINT		# skip painting pixel if out of border
		sw $t1, ($t2)				# paint pixel
		SKIP_LASER_PAINT:
		# Updates for loop index
		addi $t4, $t4, row_increment		# t4 += row_increment
		j LOOP_LASER_ROWS				# repeats LOOP_LASER_ROWS
#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT_ASTEROID
	# Inputs
		# $a0: object base address
		# $a1: If 0, paint in black. Elif 1, paint in color specified otherwise.
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: row index for 'for loop' LOOP_ASTEROID_ROW
		# $s3: column index for 'for loop' LOOP_ASTEROID_COLUMN
		# $s4: parameter for subfunction LOOP_ASTEROID_COLUMN
		# $s5-6: used in calculating pixel address row/col indices
PAINT_ASTEROID:
	    # Store used registers in the stack
	    push_reg_to_stack ($ra)
	    push_reg_to_stack ($s0)
	    push_reg_to_stack ($s1)
	    push_reg_to_stack ($s2)
	    push_reg_to_stack ($s3)
	    push_reg_to_stack ($s4)
	    push_reg_to_stack ($s5)
	    push_reg_to_stack ($s6)

	    # Initialize registers
	    add $s0, $0, $0				# initialize current color to black
	    add $s1, $0, $0				# holds temporary memory address
	    add $s2, $0, $0
	    add $s3, $0, $0
	    add $s4, $0, $0

		LOOP_ASTEROID_ROW: bge $s2, row_max, EXIT_PAINT_ASTEROID
				# Boolean Expressions: Paint in based on row index
			ASTEROID_COND:
					beq $s2, 0, ASTEROID_ROW_0
					beq $s2, 1024, ASTEROID_ROW_1
					beq $s2, 2048, ASTEROID_ROW_2
					beq $s2, 3072, ASTEROID_ROW_3
					beq $s2, 4096, ASTEROID_ROW_4
					beq $s2, 5120, ASTEROID_ROW_5
					beq $s2, 6144, ASTEROID_ROW_6
					beq $s2, 7168, ASTEROID_ROW_7
					beq $s2, 8192, ASTEROID_ROW_8

					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_0:
					setup_general_paint (0x000000, 0, 8, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x443a33, 8, 12, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x7d6556, 12, 16, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x7c6455, 16, 20, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x564941, 20, 24, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x36312e, 24, 28, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_1:
					setup_general_paint (0x271f1a, 0, 4, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x826858, 4, 8, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x896e5d, 8, 28, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x82695a, 28, 32, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x000000, 32, 36, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_2:
					setup_general_paint (0x7c6454, 0, 4, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x896e5d, 4, 32, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x332923, 32, 36, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_3:
					setup_general_paint (0x896e5d, 0, 32, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x876c5b, 32, 36, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_4:
					setup_general_paint (0x896e5d, 0, 32, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x876d5c, 32, 36, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_5:
					setup_general_paint (0x896e5d, 0, 32, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x615045, 32, 36, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_6:
					setup_general_paint (0x896e5d, 0, 28, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x866b5b, 28, 32, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x000000, 32, 36, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_7:
					setup_general_paint (0x000000, 0, 4, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x876c5b, 4, 8, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x896e5d, 8, 24, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x866c5c, 24, 28, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x8a6e5f, 28, 32, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x000000, 32, 36, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW
			ASTEROID_ROW_8:
					setup_general_paint (0x000000, 0, 4, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x40342c, 4, 8, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x896e5d, 8, 16, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x69564b, 16, 20, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x342f2d, 20, 24, LOOP_ASTEROID_COLUMN)
					setup_general_paint (0x161515, 24, 28, LOOP_ASTEROID_COLUMN)
					j UPDATE_ASTEROID_ROW

    	UPDATE_ASTEROID_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_ASTEROID_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_ASTEROID_COLUMN: bge $s3, $s4, EXIT_LOOP_ASTEROID_COLUMN	# branch to UPDATE_ASTEROID_COL; if column index >= last column index to paint
			add $s1, $a0, $0			# start from given address
			add $s1, $s1, $s3			# update to specific column
			add $s1, $s1, $s2			# update to specific row
			add $s1, $s1, $a2			# update to random offset

			calculate_indices ($s1, $s5, $s6)	# get address indices. Store in $s5-6
			within_borders ($s5, $s6, $s6)		# check within borders. Store boolean result in $s6
			beq $s6, 0, SKIP_ASTEROID_PAINT		# skip painting pixel if out of border
			sw $s0, ($s1)				# paint pixel
			SKIP_ASTEROID_PAINT:
        		# Updates for loop index
        		addi $s3, $s3, column_increment			# t4 += row_increment
        		j LOOP_ASTEROID_COLUMN				# repeats LOOP_ASTEROID_ROW
	    EXIT_LOOP_ASTEROID_COLUMN:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_ASTEROID:
        		# Restore used registers
        		pop_reg_from_stack ($s6)
        		pop_reg_from_stack ($s5)
	    		pop_reg_from_stack ($s4)
	    		pop_reg_from_stack ($s3)
	    		pop_reg_from_stack ($s2)
	    		pop_reg_from_stack ($s1)
	    		pop_reg_from_stack ($s0)
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction
#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT_PICKUP_HEART
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: row index for 'for loop' LOOP_PICKUP_HEART_ROW
		# $s3: column index for 'for loop' LOOP_PICKUP_HEART_COLUMN
		# $s4: parameter for subfunction LOOP_PICKUP_HEART_COLUMN
		# $s5-6: used in calculating pixel address row/col indices
PAINT_PICKUP_HEART:
	    # Store used registers in the stack
	    push_reg_to_stack ($ra)
	    push_reg_to_stack ($s0)
	    push_reg_to_stack ($s1)
	    push_reg_to_stack ($s2)
	    push_reg_to_stack ($s3)
	    push_reg_to_stack ($s4)
	    push_reg_to_stack ($s5)
	    push_reg_to_stack ($s6)

	    # Initialize registers
	    add $s0, $0, $0				# initialize current color to black
	    add $s1, $0, $0				# holds temporary memory address
	    add $s2, $0, $0
	    add $s3, $0, $0
	    add $s4, $0, $0

		LOOP_PICKUP_HEART_ROW: bge $s2, row_max, EXIT_PAINT_PICKUP_HEART
				# Boolean Expressions: Paint in based on row index
			PICKUP_HEART_COND:
					beq $s2, 1024, PICKUP_HEART_ROW_1
					beq $s2, 2048, PICKUP_HEART_ROW_2
					beq $s2, 3072, PICKUP_HEART_ROW_3
					beq $s2, 4096, PICKUP_HEART_ROW_4
					beq $s2, 5120, PICKUP_HEART_ROW_5
					beq $s2, 6144, PICKUP_HEART_ROW_6

					j UPDATE_PICKUP_HEART_ROW
			PICKUP_HEART_ROW_1:
					setup_general_paint (0x000000, 0, 4, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xd63a3a, 4, 8, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xe92828, 8, 12, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x5b0000, 12, 16, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xe30000, 16, 20, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xd90000, 20, 24, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x000000, 24, 28, LOOP_PICKUP_HEART_COLUMN)
					j UPDATE_PICKUP_HEART_ROW
			PICKUP_HEART_ROW_2:
					setup_general_paint (0x5c0000, 0, 4, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xff4141, 4, 8, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xff0000, 8, 20, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xf60000, 20, 24, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x580000, 24, 28, LOOP_PICKUP_HEART_COLUMN)
					j UPDATE_PICKUP_HEART_ROW
			PICKUP_HEART_ROW_3:
					setup_general_paint (0x000000, 0, 4, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xff0000, 4, 20, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xe80000, 20, 24, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x000000, 24, 28, LOOP_PICKUP_HEART_COLUMN)
					j UPDATE_PICKUP_HEART_ROW
			PICKUP_HEART_ROW_4:
					setup_general_paint (0x000000, 0, 4, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x750000, 4, 8, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xff0000, 8, 20, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x710000, 20, 24, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x000000, 24, 28, LOOP_PICKUP_HEART_COLUMN)
					j UPDATE_PICKUP_HEART_ROW
			PICKUP_HEART_ROW_5:
					setup_general_paint (0x000000, 0, 8, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x710000, 8, 12, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0xff0000, 12, 16, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x6b0000, 16, 20, LOOP_PICKUP_HEART_COLUMN)
					j UPDATE_PICKUP_HEART_ROW
			PICKUP_HEART_ROW_6:
					setup_general_paint (0x000000, 0, 12, LOOP_PICKUP_HEART_COLUMN)
					setup_general_paint (0x310000, 12, 16, LOOP_PICKUP_HEART_COLUMN)
					j UPDATE_PICKUP_HEART_ROW

    	UPDATE_PICKUP_HEART_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_PICKUP_HEART_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_PICKUP_HEART_COLUMN: bge $s3, $s4, EXIT_LOOP_PICKUP_HEART_COLUMN	# branch to UPDATE_PICKUP_HEART_COL; if column index >= last column index to paint
        		addi $s1, $a0, 0				# Reinitialize t2; temporary address store
        		add $s1, $s1, $s2				# update to specific row from base address
        		add $s1, $s1, $s3				# update to specific column
        		sw $s0, ($s1)					# paint in value

			calculate_indices ($s1, $s5, $s6)	# get address indices. Store in $s5-6
			within_borders ($s5, $s6, $s6)		# check within borders. Store boolean result in $s6
			beq $s6, 0, SKIP_PICKUP_HEART_PAINT	# skip painting pixel if out of border
			sw $s0, ($s1)				# paint pixel
			SKIP_PICKUP_HEART_PAINT:

        		# Updates for loop index
        		addi $s3, $s3, column_increment			# t4 += row_increment
        		j LOOP_PICKUP_HEART_COLUMN				# repeats LOOP_PICKUP_HEART_ROW
	    EXIT_LOOP_PICKUP_HEART_COLUMN:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_PICKUP_HEART:
        		# Restore used registers
        		pop_reg_from_stack ($s6)
        		pop_reg_from_stack ($s5)
	    		pop_reg_from_stack ($s4)
	    		pop_reg_from_stack ($s3)
	    		pop_reg_from_stack ($s2)
	    		pop_reg_from_stack ($s1)
	    		pop_reg_from_stack ($s0)
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction
#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT_PICKUP_COIN
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: row index for 'for loop' LOOP_PICKUP_COIN_ROW
		# $s3: column index for 'for loop' LOOP_PICKUP_COIN_COLUMN
		# $s4: parameter for subfunction LOOP_PICKUP_COIN_COLUMN
PAINT_PICKUP_COIN:
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

		LOOP_PICKUP_COIN_ROW: bge $s2, row_max, EXIT_PAINT_PICKUP_COIN
				# Boolean Expressions: Paint in based on row index
			PICKUP_COIN_COND:
					beq $s2, 0, PICKUP_COIN_ROW_0
					beq $s2, 1024, PICKUP_COIN_ROW_1
					beq $s2, 2048, PICKUP_COIN_ROW_2
					beq $s2, 3072, PICKUP_COIN_ROW_3
					beq $s2, 4096, PICKUP_COIN_ROW_4
					beq $s2, 5120, PICKUP_COIN_ROW_5
					beq $s2, 6144, PICKUP_COIN_ROW_6
					beq $s2, 7168, PICKUP_COIN_ROW_7
					beq $s2, 8192, PICKUP_COIN_ROW_8

					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_0:
					setup_general_paint (0x000000, 0, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x494900, 8, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 12, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x5c5c37, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x222100, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_1:
					setup_general_paint (0x000000, 0, 4, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x535300, 4, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 8, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x8f8f00, 12, 16, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x5b5b00, 16, 20, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x8d8d00, 20, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xd1d15c, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_2:
					setup_general_paint (0x303016, 0, 4, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 4, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x939300, 8, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x212100, 12, 16, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 16, 20, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x333300, 20, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xa3a200, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xe2e1a6, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x878715, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_3:
					setup_general_paint (0x5f5f00, 0, 4, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 4, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x494900, 8, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 12, 20, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x161600, 20, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x5e5f00, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xa9a853, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_4:
					setup_general_paint (0x5e5f00, 0, 4, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 4, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x2f2f00, 8, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 12, 20, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x161600, 20, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x5e5f00, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xa6a66b, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_5:
					setup_general_paint (0x5e5f00, 0, 4, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 4, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x494900, 8, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 12, 20, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x161600, 20, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x5e5f00, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x8c8c59, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_6:
					setup_general_paint (0x272700, 0, 4, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 4, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x333315, 12, 16, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 16, 20, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x353600, 20, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xa7a700, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x393a00, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_7:
					setup_general_paint (0x000000, 0, 4, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x494900, 4, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 8, 16, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x909000, 16, 20, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x939300, 20, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x777700, 28, 32, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x000000, 32, 36, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW
			PICKUP_COIN_ROW_8:
					setup_general_paint (0x000000, 0, 8, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x252500, 8, 12, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0xbaba00, 12, 24, LOOP_PICKUP_COIN_COLUMN)
					setup_general_paint (0x202100, 24, 28, LOOP_PICKUP_COIN_COLUMN)
					j UPDATE_PICKUP_COIN_ROW

    	UPDATE_PICKUP_COIN_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_PICKUP_COIN_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_PICKUP_COIN_COLUMN: bge $s3, $s4, EXIT_LOOP_PICKUP_COIN_COLUMN	# branch to UPDATE_PICKUP_COIN_COL; if column index >= last column index to paint
        		addi $s1, $a0, 0				# initialize from base address specified in $a0
        		add $s1, $s1, $s2				# update to specific row from base address
        		add $s1, $s1, $s3				# update to specific column
        		sw $s0, ($s1)					# paint in value

        		# Updates for loop index
        		addi $s3, $s3, column_increment			# t4 += row_increment
        		j LOOP_PICKUP_COIN_COLUMN				# repeats LOOP_PICKUP_COIN_ROW
	    EXIT_LOOP_PICKUP_COIN_COLUMN:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_PICKUP_COIN:
        		# Restore used registers
	    		pop_reg_from_stack ($s4)
	    		pop_reg_from_stack ($s3)
	    		pop_reg_from_stack ($s2)
	    		pop_reg_from_stack ($s1)
	    		pop_reg_from_stack ($s0)
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction
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
	push_reg_to_stack ($a0)
	push_reg_to_stack ($a2)
	push_reg_to_stack ($a3)
	push_reg_to_stack ($s0)
	push_reg_to_stack ($t0)
	push_reg_to_stack ($t1)
	push_reg_to_stack ($t2)
	push_reg_to_stack ($t3)

	# Initialize for loop indexer
	add $t0, $0, $0
	# Loop 5 times through all possible hearts. Subtract 1 from number of hearts each time.
	LOOP_HEART: beq $t0, 5, EXIT_UPDATE_HEALTH	# branch if $t0 = 5
		addi $t1, $0, column_increment	# store column increment temporarily
		addi $t2, $0, 12
		mult $t1, $t2
		mflo $t1
		mult $t0, $t1			# address offset = current index * (3 * column_increment)
		mflo $t3
		addi $a0, $t3, display_base_address	# param. address to start painting at

		add $t2, $s0, $0		# store number of hit points
		sub $t2, $t2, $t0		# subtract number of hit points by current indexer
		sge $a3, $t2, 1			# param. for helper function to paint/erase heart. If number of hearts > curr index, paint in heart. Otherwise, erase.
		jal PAINT_BORDER_HEART		# paint/erase heart

		# Update for loop indexer
		addi $t0, $t0, 1		# $t0 = $t0 + 1
		j LOOP_HEART
	# Restore previouos state of used registers
	EXIT_UPDATE_HEALTH:
		pop_reg_from_stack ($t3)
		pop_reg_from_stack ($t2)
		pop_reg_from_stack ($t1)
		pop_reg_from_stack ($t0)
		pop_reg_from_stack ($s0)

		pop_reg_from_stack ($a3)
		pop_reg_from_stack ($a2)
		pop_reg_from_stack ($a0)
		pop_reg_from_stack ($ra)
		jr $ra
#___________________________________________________________________________________________________________________________
# HELPER FUNCTION: PAINT_BORDER_HEART
	# Precondition:
		# $a1 must be equal to 1 to avoid painting black.
	# Inputs:
		# $a0: address to start painting
		# $a3: whether to paint in or erase heart
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: column index for 'for loop' LOOP_BORDER_HEART_COLS
		# $s3: starting row index for 'for loop' LOOP_BORDER_HEART_ROWS
		# $s4: ending row index for 'for loop' LOOP_BORDER_HEART_ROWS
PAINT_BORDER_HEART:
	    # Store used registers in the stack
	    push_reg_to_stack ($ra)
	    push_reg_to_stack ($s0)
	    push_reg_to_stack ($s1)
	    push_reg_to_stack ($s2)
	    push_reg_to_stack ($s3)
	    push_reg_to_stack ($s4)
	    push_reg_to_stack ($a1)

	    # Initialize registers
	    add $s0, $0, $0				# initialize current color to black
	    add $s1, $0, $0				# holds temporary memory address
	    add $s2, $0, $0
	    add $s3, $0, $0
	    add $s4, $0, $0
	    addi $a1, $0, 1				# precondition

		LOOP_BORDER_HEART_ROW: bge $s2, row_max, EXIT_PAINT_BORDER_HEART
				# Boolean Expressions: Paint in based on row index
			BORDER_HEART_COND:
					beq $s2, 0, BORDER_HEART_ROW_0
					beq $s2, 1024, BORDER_HEART_ROW_1
					beq $s2, 2048, BORDER_HEART_ROW_2
					beq $s2, 3072, BORDER_HEART_ROW_3
					beq $s2, 4096, BORDER_HEART_ROW_4
					beq $s2, 5120, BORDER_HEART_ROW_5
					beq $s2, 6144, BORDER_HEART_ROW_6
					beq $s2, 7168, BORDER_HEART_ROW_7
					beq $s2, 8192, BORDER_HEART_ROW_8

					j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_0:
					setup_general_paint (0x7f7f7f, 0, 4, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x797979, 4, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x4c4c4c, 8, 12, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x666666, 12, 16, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x7f7f7f, 16, 20, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x6b6b6b, 20, 24, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x4c4c4c, 24, 28, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x747474, 28, 32, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x7f7f7f, 32, 36, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_1:
					setup_general_paint (0x777777, 0, 4, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x6c2a2a, 4, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xdc3131, 8, 12, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x9f1616, 12, 16, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x545353, 16, 20, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x900000, 20, 24, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xd80000, 24, 28, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x741e1e, 28, 32, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x737373, 32, 36, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_2:
					setup_general_paint (0x553131, 0, 4, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xed4343, 4, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff4d4d, 8, 12, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff0000, 12, 16, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xcc0000, 16, 20, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xfb0000, 20, 24, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff0000, 24, 28, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xdb0000, 28, 32, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x502424, 32, 36, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_3:
					setup_general_paint (0x512424, 0, 4, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff3535, 4, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff0000, 8, 28, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xe50000, 28, 32, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x4f1717, 32, 36, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_4:
					setup_general_paint (0x5f5050, 0, 4, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xc30000, 4, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff0000, 8, 24, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xfa0000, 24, 28, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xb40000, 28, 32, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x564343, 32, 36, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_5:
					setup_general_paint (0x757575, 0, 4, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x701e1e, 4, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xf80000, 8, 12, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff0000, 12, 20, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xfe0000, 20, 24, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xe50000, 24, 28, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x6c1717, 28, 32, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x707070, 32, 36, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_6:
					setup_general_paint (0x7f7f7f, 0, 4, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x787878, 4, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x671c1c, 8, 12, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xff0000, 12, 20, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xe90000, 20, 24, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x651414, 24, 28, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x727272, 28, 32, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x7f7f7f, 32, 36, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_7:
					setup_general_paint (0x7f7f7f, 0, 8, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x7b7b7b, 8, 12, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x621c1c, 12, 16, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0xe60000, 16, 20, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x611616, 20, 24, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x747474, 24, 28, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW
			BORDER_HEART_ROW_8:
					setup_general_paint (0x7f7f7f, 0, 12, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x7a7a7a, 12, 16, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x423333, 16, 20, LOOP_BORDER_HEART_COLUMN)
					setup_general_paint (0x747373, 20, 24, LOOP_BORDER_HEART_COLUMN)
				j UPDATE_BORDER_HEART_ROW

    	UPDATE_BORDER_HEART_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_BORDER_HEART_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_BORDER_HEART_COLUMN: bge $s3, $s4, EXIT_LOOP_BORDER_HEART_COLUMN	# branch to UPDATE_BORDER_HEART_COL; if column index >= last column index to paint
        		addi $s1, $a0, 0		# start from address specified in $a0

        		addi $s1, $s1, 250880				# shift row to bottom outermost border (row index 245)
        		addi $s1, $s1, 52				# shift column to column index 13
        		add $s1, $s1, $a2				# add offset from parameter $a2

        		add $s1, $s1, $s2				# update to specific row from base address
        		add $s1, $s1, $s3				# update to specific column

			beq $a3, 1, PAINT_BORDER_HEART_PIXEL		# check if parameter specifies to erase/paint
        			addi $s0, $0, 0x868686
        		PAINT_BORDER_HEART_PIXEL: sw $s0, ($s1)					# paint in value
        		# Updates for loop index
        		addi $s3, $s3, column_increment			# t4 += row_increment
        		j LOOP_BORDER_HEART_COLUMN
	    EXIT_LOOP_BORDER_HEART_COLUMN:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_BORDER_HEART:
        		# Restore used registers
        		pop_reg_from_stack ($a1)
	    		pop_reg_from_stack ($s4)
	    		pop_reg_from_stack ($s3)
	    		pop_reg_from_stack ($s2)
	    		pop_reg_from_stack ($s1)
	    		pop_reg_from_stack ($s0)
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction
#___________________________________________________________________________________________________________________________
# FUNCTION: UPDATE_SCORE
	# Inputs
		# $s1: score counter
	# Used Registers:
		# $t0-1: used as temporary storages from division
UPDATE_SCORE:
	# Store used registers to stack
	push_reg_to_stack ($ra)
	push_reg_to_stack ($a0)
	push_reg_to_stack ($a1)
	push_reg_to_stack ($a2)
	push_reg_to_stack ($t0)
	push_reg_to_stack ($t1)

	# Find tenths and ones place value to display
	addi $t0, $0, 10
	div $s1, $t0			# divide current score by 10
	mflo $t0			# holds tenths place value of score
	mfhi $t1			# holds ones place value of score

	# Erase old score
	addi $a0, $0, display_base_address
	addi $a0, $a0, 2948
	addi $a1, $0, 0
	add $a2, $0, $t0
	jal PAINT_NUMBER		# erase tenths digit
	addi $a0, $a0, 24
	addi $a1, $0, 0
	add $a2, $0, $t1
	jal PAINT_NUMBER		# erase ones digit

	# Find tenths and ones place value to display
	addi $s1, $s1, 1		# update new score
	addi $t0, $0, 10
	div $s1, $t0			# divide current score by 10
	mflo $t0			# holds tenths place value of score
	mfhi $t1			# holds ones place value of score

	# Paint new score
	addi $a0, $0, display_base_address
	addi $a0, $a0, 2948
	addi $a1, $0, 1
	add $a2, $0, $t0
	jal PAINT_NUMBER
	addi $a0, $a0, 24
	addi $a1, $0, 1
	add $a2, $0, $t1
	jal PAINT_NUMBER

	# EXIT UPDATE_SCORE
	pop_reg_from_stack ($t1)	# Restore used registers
	pop_reg_from_stack ($t0)
	pop_reg_from_stack ($a2)
	pop_reg_from_stack ($a1)
	pop_reg_from_stack ($a0)
	pop_reg_from_stack ($ra)
	jr $ra				# return to previous instruction
#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT_NUMBER
	# Inputs
		# $a0: address to start painting number
		# $a1: whether to paint in or erase
		# $a2: number to paint in
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: column index for 'for loop' LOOP_NUMBER_COLUMN
		# $s3: row index for 'for loop' LOOP_NUMBER_ROW
		# $s4: parameter for subfunction LOOP_NUMBER_ROW
PAINT_NUMBER:
	    # Store used registers in the stack
	    push_reg_to_stack ($ra)
	    push_reg_to_stack ($s0)
	    push_reg_to_stack ($s1)
	    push_reg_to_stack ($s2)
	    push_reg_to_stack ($s3)
	    push_reg_to_stack ($s4)
	    # Initialize registers
	    add $s0, $0, 0xffffff			# initialize current color to white
	    add $s1, $0, $0				# holds temporary memory address
	    add $s2, $0, $0
	    add $s3, $0, $0
	    add $s4, $0, $0
		LOOP_NUMBER_COLUMN: bge $s2, column_max, EXIT_PAINT_NUMBER
			# Boolean Expressions: Paint in based on column index
			NUMBER_COND:
					beq $s2, 0, NUMBER_COLUMN_0
					beq $s2, 4, NUMBER_COLUMN_1
					beq $s2, 8, NUMBER_COLUMN_2
					beq $s2, 12, NUMBER_COLUMN_3
					beq $s2, 16, NUMBER_COLUMN_4

					j UPDATE_NUMBER_COLUMN
			NUMBER_COLUMN_0:
					# number-specific painting conditionals
					beq $a2, 1, SKIP_LOWER_NUMBER_COLUMN_0
					beq $a2, 3, SKIP_LOWER_NUMBER_COLUMN_0
					beq $a2, 7, SKIP_LOWER_NUMBER_COLUMN_0
					beq $a2, 2, SKIP_UPPER_NUMBER_COLUMN_0

					setup_general_paint (0xffffff, 1024, 4096, LOOP_NUMBER_ROW)
					SKIP_UPPER_NUMBER_COLUMN_0:

					beq $a2, 4, SKIP_LOWER_NUMBER_COLUMN_0
					beq $a2, 5, SKIP_LOWER_NUMBER_COLUMN_0
					beq $a2, 9, SKIP_LOWER_NUMBER_COLUMN_0

					setup_general_paint (0xffffff, 5120, 8192, LOOP_NUMBER_ROW)
					SKIP_LOWER_NUMBER_COLUMN_0:
					j UPDATE_NUMBER_COLUMN
			NUMBER_COLUMN_1:
					# number-specific painting conditionals
					beq $a2, 1, SKIP_BOTTOM_NUMBER_COLUMN_1
					beq $a2, 4, SKIP_TOP_NUMBER_COLUMN_1
					beq $a2, 6, SKIP_TOP_NUMBER_COLUMN_1

					setup_general_paint (0xffffff, 0, 1024, LOOP_NUMBER_ROW)
					SKIP_TOP_NUMBER_COLUMN_1:

					beq $a2, 0, SKIP_MIDDLE_NUMBER_COLUMN_1
					beq $a2, 7, SKIP_BOTTOM_NUMBER_COLUMN_1

					setup_general_paint (0xffffff, 4096, 5120, LOOP_NUMBER_ROW)
					SKIP_MIDDLE_NUMBER_COLUMN_1:

					beq $a2, 4, SKIP_BOTTOM_NUMBER_COLUMN_1
					beq $a2, 9, SKIP_BOTTOM_NUMBER_COLUMN_1

					setup_general_paint (0xffffff, 8192, 9216, LOOP_NUMBER_ROW)
					SKIP_BOTTOM_NUMBER_COLUMN_1:
					j UPDATE_NUMBER_COLUMN
			NUMBER_COLUMN_2:
					# number-specific painting conditionals
					beq $a2, 1, SKIP_BOTTOM_NUMBER_COLUMN_2
					beq $a2, 4, SKIP_TOP_NUMBER_COLUMN_2
					beq $a2, 6, SKIP_TOP_NUMBER_COLUMN_2

					setup_general_paint (0xffffff, 0, 1024, LOOP_NUMBER_ROW)
					SKIP_TOP_NUMBER_COLUMN_2:

					beq $a2, 0, SKIP_MIDDLE_NUMBER_COLUMN_2
					beq $a2, 7, SKIP_BOTTOM_NUMBER_COLUMN_2

					setup_general_paint (0xffffff, 4096, 5120, LOOP_NUMBER_ROW)
					SKIP_MIDDLE_NUMBER_COLUMN_2:

					beq $a2, 4, SKIP_BOTTOM_NUMBER_COLUMN_2
					beq $a2, 9, SKIP_BOTTOM_NUMBER_COLUMN_2

					setup_general_paint (0xffffff, 8192, 9216, LOOP_NUMBER_ROW)
					SKIP_BOTTOM_NUMBER_COLUMN_2:
					j UPDATE_NUMBER_COLUMN
			NUMBER_COLUMN_3:
					# number-specific painting conditionals
					beq $a2, 1, SKIP_BOTTOM_NUMBER_COLUMN_3
					beq $a2, 4, SKIP_TOP_NUMBER_COLUMN_3
					beq $a2, 6, SKIP_TOP_NUMBER_COLUMN_3

					setup_general_paint (0xffffff, 0, 1024, LOOP_NUMBER_ROW)
					SKIP_TOP_NUMBER_COLUMN_3:

					beq $a2, 0, SKIP_MIDDLE_NUMBER_COLUMN_3
					beq $a2, 7, SKIP_BOTTOM_NUMBER_COLUMN_3

					setup_general_paint (0xffffff, 4096, 5120, LOOP_NUMBER_ROW)
					SKIP_MIDDLE_NUMBER_COLUMN_3:

					beq $a2, 4, SKIP_BOTTOM_NUMBER_COLUMN_3
					beq $a2, 9, SKIP_BOTTOM_NUMBER_COLUMN_3

					setup_general_paint (0xffffff, 8192, 9216, LOOP_NUMBER_ROW)
					SKIP_BOTTOM_NUMBER_COLUMN_3:
					j UPDATE_NUMBER_COLUMN
			NUMBER_COLUMN_4:
					# number-specific painting conditionals
					beq $a2, 5, SKIP_UPPER_NUMBER_COLUMN_4
					beq $a2, 6, SKIP_UPPER_NUMBER_COLUMN_4

					setup_general_paint (0xffffff, 1024, 4096, LOOP_NUMBER_ROW)
					SKIP_UPPER_NUMBER_COLUMN_4:

					beq $a2, 2, SKIP_LOWER_NUMBER_COLUMN_4

					setup_general_paint (0xffffff, 5120, 8192, LOOP_NUMBER_ROW)
					SKIP_LOWER_NUMBER_COLUMN_4:
					j UPDATE_NUMBER_COLUMN

    	UPDATE_NUMBER_COLUMN:				# Update column value
    	    	addi $s2, $s2, column_increment
	        	j LOOP_NUMBER_COLUMN

    	# FOR LOOP: (through row)
    	# Paints in row from $s3 to $s4 at some column
    	LOOP_NUMBER_ROW: bge $s3, $s4, EXIT_LOOP_NUMBER_ROW			# branch to UPDATE_NUMBER_COL; if row index >= last row index to paint
        		addi $s1, $a0, 0					# start from base address given by $a0
        		add $s1, $s1, $s2					# update to specific column from base address
        		add $s1, $s1, $s3					# update to specific row
	    		beq $a1, 1, PAINT_NUMBER_PIXEL				# if $a1 == 0, set to erase
	    		addi $s0, $0, 0x868686					# update color to border gray
	    		PAINT_NUMBER_PIXEL: sw $s0, ($s1)			# paint in value

        		# Updates for loop index
        		addi $s3, $s3, row_increment				# s3 += column_increment
        		j LOOP_NUMBER_ROW					# repeats LOOP_NUMBER_COLUMN
	    EXIT_LOOP_NUMBER_ROW:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_NUMBER:
        		# Restore used registers
	    		pop_reg_from_stack ($s4)
	    		pop_reg_from_stack ($s3)
	    		pop_reg_from_stack ($s2)
	    		pop_reg_from_stack ($s1)
	    		pop_reg_from_stack ($s0)
        		pop_reg_from_stack ($ra)
        		jr $ra						# return to previous instruction

#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT_BORDER_COIN
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: row index for 'for loop' LOOP_BORDER_COIN_ROW
		# $s3: column index for 'for loop' LOOP_BORDER_COIN_COLUMN
		# $s4: parameter for subfunction LOOP_BORDER_COIN_COLUMN
PAINT_BORDER_COIN:
	    # Store used registers in the stack
	    push_reg_to_stack ($ra)
	    push_reg_to_stack ($a0)
	    push_reg_to_stack ($a1)
	    push_reg_to_stack ($a2)
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
	    addi $a1, $0, 1				# precondition for painting

		LOOP_BORDER_COIN_ROW: bge $s2, row_max, EXIT_PAINT_BORDER_COIN
				# Boolean Expressions: Paint in based on row index
			BORDER_COIN_COND:
					beq $s2, 0, BORDER_COIN_ROW_0
					beq $s2, 1024, BORDER_COIN_ROW_1
					beq $s2, 2048, BORDER_COIN_ROW_2
					beq $s2, 3072, BORDER_COIN_ROW_3
					beq $s2, 4096, BORDER_COIN_ROW_4
					beq $s2, 5120, BORDER_COIN_ROW_5
					beq $s2, 6144, BORDER_COIN_ROW_6
					beq $s2, 7168, BORDER_COIN_ROW_7
					beq $s2, 8192, BORDER_COIN_ROW_8

					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_0:
					setup_general_paint (0x868686, 0, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x494900, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb9b900, 12, 16, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xbaba00, 16, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x5c5c37, 24, 28, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_1:
					setup_general_paint (0x868686, 0, 4, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x535300, 4, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb8b800, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x939300, 12, 16, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x5d5d00, 16, 20, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x8f8f16, 20, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xd8d854, 24, 28, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xd1d15c, 28, 32, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_2:
					setup_general_paint (0x868686, 0, 4, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb9b900, 4, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x979700, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x40403a, 12, 16, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 16, 20, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x4c4c46, 20, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xaaa900, 24, 28, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xe1e0a6, 28, 32, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x717131, 32, 36, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_3:
					setup_general_paint (0x5f5f00, 0, 4, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb9b900, 4, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x494900, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 12, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x5e5e00, 24, 28, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xbaba00, 28, 32, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x787854, 32, 36, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 36, 44, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xffffff, 44, 48, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 48, 52, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xffffff, 52, 56, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_4:
					setup_general_paint (0x5e5f00, 0, 4, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb9b900, 4, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x2f2f00, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 12, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x595b1b, 24, 28, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb8b800, 28, 32, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x74745d, 32, 36, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 36, 48, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xffffff, 48, 52, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 52, 56, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_5:
					setup_general_paint (0x5e5f00, 0, 4, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xbaba00, 4, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x484800, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 12, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x5b5c00, 24, 28, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb8b800, 28, 32, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x6e6e57, 32, 36, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 36, 44, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xffffff, 44, 48, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 48, 52, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xffffff, 52, 56, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_6:
					setup_general_paint (0x868686, 0, 4, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb8b800, 4, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xafaf00, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x343416, 12, 16, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x868686, 16, 20, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x333400, 20, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xa5a500, 24, 28, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb9b900, 28, 32, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x414224, 32, 36, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_7:
					setup_general_paint (0x868686, 0, 4, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x494900, 4, 8, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb2b200, 8, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb5b500, 12, 16, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x909000, 16, 20, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x939300, 20, 24, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb9b900, 24, 28, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0x777700, 28, 32, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW
			BORDER_COIN_ROW_8:
					setup_general_paint (0x868686, 0, 12, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb6b600, 12, 16, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb9b900, 16, 20, LOOP_BORDER_COIN_COLUMN)
					setup_general_paint (0xb3b300, 20, 24, LOOP_BORDER_COIN_COLUMN)
					j UPDATE_BORDER_COIN_ROW

    	UPDATE_BORDER_COIN_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_BORDER_COIN_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_BORDER_COIN_COLUMN: bge $s3, $s4, EXIT_LOOP_BORDER_COIN_COLUMN	# branch to UPDATE_BORDER_COIN_COL; if column index >= last column index to paint
        		addi $s1, $0, display_base_address			# Reinitialize t2; temporary address store
        		add $s1, $s1, $s2				# update to specific row from base address
        		add $s1, $s1, $s3				# update to specific column
        		addi $s1, $s1, 2888				# add specified offset
                	sw $s0, ($s1)					# paint in value

        		# Updates for loop index
        		addi $s3, $s3, column_increment			# t4 += row_increment
        		j LOOP_BORDER_COIN_COLUMN				# repeats LOOP_BORDER_COIN_ROW
	    EXIT_LOOP_BORDER_COIN_COLUMN:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_BORDER_COIN:
       		# Paint 00 as initial score
		addi $a0, $0, display_base_address
		addi $a0, $a0, 2948
		addi $a1, $0, 1
		addi $a2, $0, 0
		jal PAINT_NUMBER
		addi $a0, $a0, 24
		addi $a1, $0, 1
		addi $a2, $0, 0
		jal PAINT_NUMBER

        	# Restore used registers
    		pop_reg_from_stack ($s4)
    		pop_reg_from_stack ($s3)
    		pop_reg_from_stack ($s2)
    		pop_reg_from_stack ($s1)
    		pop_reg_from_stack ($s0)
    		pop_reg_from_stack ($a2)
    		pop_reg_from_stack ($a1)
    		pop_reg_from_stack ($a0)
       		pop_reg_from_stack ($ra)
       		jr $ra						# return to previous instruction
#___________________________________________________________________________________________________________________________
# FUNCTION: CLEAR_SCREEN
	# Registers Used
		# $t1: stores current color value
		# $t2: temporary memory address storage for current unit (in bitmap)
		# $t3: column index for 'for loop' LOOP_CLEAR_COLS					# Stores (delta) column to add to memory address to move columns right in the bitmap
		# $t4: row index for 'for loop' LOOP_CLEAR_ROWS
		# $t5: parameter for subfunction LOOP_CLEAR_ROWS. Will store # rows to paint from the center row outwards
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
# FUNCTION: PAINT_FINAL_SCORE
	# Inputs
		# $s1: score counter
	# Used Registers:
		# $t0-1: used as temporary storages from division
PAINT_FINAL_SCORE:
	push_reg_to_stack ($ra)
	# Find tenths and ones place value to display
	addi $t0, $0, 10
	div $s1, $t0			# divide current score by 10
	mflo $t0			# holds tenths place value of score
	mfhi $t1			# holds ones place value of score

	# Erase old score
	addi $a0, $0, display_base_address
	addi $a0, $a0, 51200		# add offset when painting in game_over
	addi $a0, $a0, 488		# shift to column 122
	addi $a0, $a0, 78848		# shift to row 77
	addi $a1, $0, 1			# set to paint
	add $a2, $0, $t0		
	jal PAINT_NUMBER		# paint tenths digit
	addi $a0, $a0, 24
	addi $a1, $0, 1			# set to paint
	add $a2, $0, $t1
	jal PAINT_NUMBER		# paint ones digit
	pop_reg_from_stack ($ra)
	jr $ra
#___________________________________________________________________________________________________________________________
# FUNCTION: PAINT_EXPLOSION
	# Inputs
		# $a0: base address to paint explosion
	# Registers Used
		# $s0: stores current color value
		# $s1: temporary memory address storage for current unit (in bitmap)
		# $s2: row index for 'for loop' LOOP_EXPLOSION_ROW
		# $s3: column index for 'for loop' LOOP_EXPLOSION_COLUMN
		# $s4: parameter for subfunction LOOP_EXPLOSION_COLUMN
PAINT_EXPLOSION:
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

		LOOP_EXPLOSION_ROW: bge $s2, row_max, EXIT_PAINT_EXPLOSION
				# Boolean Expressions: Paint in based on row index
			EXPLOSION_COND:
					beq $s2, 0, EXPLOSION_ROW_0
					beq $s2, 1024, EXPLOSION_ROW_1
					beq $s2, 2048, EXPLOSION_ROW_2
					beq $s2, 3072, EXPLOSION_ROW_3
					beq $s2, 4096, EXPLOSION_ROW_4
					beq $s2, 5120, EXPLOSION_ROW_5
					beq $s2, 6144, EXPLOSION_ROW_6
					beq $s2, 7168, EXPLOSION_ROW_7
					beq $s2, 8192, EXPLOSION_ROW_8

					j UPDATE_EXPLOSION_ROW
			EXPLOSION_ROW_0:
					setup_general_paint (0x000000, 0, 8, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x8b1600, 8, 12, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x6d0000, 12, 16, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x390000, 16, 20, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x000000, 20, 24, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x290000, 24, 28, LOOP_EXPLOSION_COLUMN)
					j UPDATE_EXPLOSION_ROW
			EXPLOSION_ROW_1:
					setup_general_paint (0x300000, 0, 4, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x872700, 4, 8, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xd7743c, 8, 12, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xf8b423, 12, 16, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xee9b49, 16, 20, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xbd3200, 20, 24, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xdd3f00, 24, 28, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x340000, 28, 32, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x000000, 32, 36, LOOP_EXPLOSION_COLUMN)
					j UPDATE_EXPLOSION_ROW
			EXPLOSION_ROW_2:
					setup_general_paint (0x9f1f00, 0, 4, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfbcb3a, 4, 8, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfffffb, 8, 12, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfcf8ae, 12, 16, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfcf9bb, 16, 20, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xffca00, 20, 24, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfcbb22, 24, 28, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xc55000, 28, 32, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x2c0000, 32, 36, LOOP_EXPLOSION_COLUMN)
					j UPDATE_EXPLOSION_ROW
			EXPLOSION_ROW_3:
					setup_general_paint (0x852600, 0, 4, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xffde1e, 4, 8, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfdf8aa, 8, 12, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfef04c, 12, 16, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xffea00, 16, 20, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfedb1c, 20, 24, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xf9ce1f, 24, 28, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xf1b118, 28, 32, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x7a2100, 32, 36, LOOP_EXPLOSION_COLUMN)
					j UPDATE_EXPLOSION_ROW
			EXPLOSION_ROW_4:
					setup_general_paint (0xba3e00, 0, 4, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xffd822, 4, 8, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfed91d, 8, 12, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfcc820, 12, 16, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xffda1a, 16, 20, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfcf7a9, 20, 24, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfeeb00, 24, 28, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfbc91c, 28, 32, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x9d3f00, 32, 36, LOOP_EXPLOSION_COLUMN)
					j UPDATE_EXPLOSION_ROW
			EXPLOSION_ROW_5:
					setup_general_paint (0xb24d00, 0, 4, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfac838, 4, 8, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xf29926, 8, 12, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xf19726, 12, 16, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfefce0, 16, 20, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xffeb00, 20, 24, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xffdf00, 24, 28, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfde82e, 28, 32, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xe55c00, 32, 36, LOOP_EXPLOSION_COLUMN)
					j UPDATE_EXPLOSION_ROW
			EXPLOSION_ROW_6:
					setup_general_paint (0xb74f00, 0, 4, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfedd2d, 4, 8, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfabf32, 8, 12, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfec41e, 12, 16, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfcf8ae, 16, 20, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfdee38, 20, 24, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfdcb19, 24, 28, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xed7100, 28, 32, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x6c1700, 32, 36, LOOP_EXPLOSION_COLUMN)
					j UPDATE_EXPLOSION_ROW
			EXPLOSION_ROW_7:
					setup_general_paint (0x862000, 0, 4, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xe66900, 4, 8, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xe25f00, 8, 12, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xee7814, 12, 16, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfee770, 16, 20, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xfee130, 20, 24, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xf3821d, 24, 28, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xb01f00, 28, 32, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x1d0000, 32, 36, LOOP_EXPLOSION_COLUMN)
					j UPDATE_EXPLOSION_ROW
			EXPLOSION_ROW_8:
					setup_general_paint (0x4f0000, 0, 4, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x2d0000, 4, 8, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x000000, 8, 12, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x380000, 12, 16, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0xb23100, 16, 20, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x8b2600, 20, 24, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x2e0000, 24, 28, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x380000, 28, 32, LOOP_EXPLOSION_COLUMN)
					setup_general_paint (0x000000, 32, 36, LOOP_EXPLOSION_COLUMN)
					j UPDATE_EXPLOSION_ROW

    	UPDATE_EXPLOSION_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_EXPLOSION_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_EXPLOSION_COLUMN: bge $s3, $s4, EXIT_LOOP_EXPLOSION_COLUMN	# branch to UPDATE_EXPLOSION_COL; if column index >= last column index to paint
        		addi $s1, $a0, 0				# initialize from base address
        		add $s1, $s1, $s2				# update to specific row from base address
        		add $s1, $s1, $s3				# update to specific column
        		sw $s0, ($s1)					# paint in value

        		# Updates for loop index
        		addi $s3, $s3, column_increment			# s3 += row_increment
        		j LOOP_EXPLOSION_COLUMN				# repeats LOOP_EXPLOSION_ROW
	    EXIT_LOOP_EXPLOSION_COLUMN:
		        jr $ra

    	# EXIT FUNCTION
       	EXIT_PAINT_EXPLOSION:
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
					beq $s2, 30720, GAME_OVER_ROW_30
					beq $s2, 31744, GAME_OVER_ROW_31
					beq $s2, 32768, GAME_OVER_ROW_32
					beq $s2, 33792, GAME_OVER_ROW_33
					beq $s2, 34816, GAME_OVER_ROW_34
					beq $s2, 35840, GAME_OVER_ROW_35
					beq $s2, 36864, GAME_OVER_ROW_36
					beq $s2, 37888, GAME_OVER_ROW_37
					beq $s2, 38912, GAME_OVER_ROW_38
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
					beq $s2, 78848, GAME_OVER_ROW_77
					beq $s2, 79872, GAME_OVER_ROW_78
					beq $s2, 80896, GAME_OVER_ROW_79
					beq $s2, 81920, GAME_OVER_ROW_80
					beq $s2, 82944, GAME_OVER_ROW_81
					beq $s2, 83968, GAME_OVER_ROW_82
					beq $s2, 84992, GAME_OVER_ROW_83
					beq $s2, 86016, GAME_OVER_ROW_84
					beq $s2, 87040, GAME_OVER_ROW_85
					beq $s2, 105472, GAME_OVER_ROW_103
					beq $s2, 106496, GAME_OVER_ROW_104
					beq $s2, 107520, GAME_OVER_ROW_105
					beq $s2, 108544, GAME_OVER_ROW_106
					beq $s2, 109568, GAME_OVER_ROW_107
					beq $s2, 110592, GAME_OVER_ROW_108
					beq $s2, 111616, GAME_OVER_ROW_109
					beq $s2, 112640, GAME_OVER_ROW_110
					beq $s2, 113664, GAME_OVER_ROW_111
					beq $s2, 114688, GAME_OVER_ROW_112
					beq $s2, 128000, GAME_OVER_ROW_125
					beq $s2, 129024, GAME_OVER_ROW_126
					beq $s2, 130048, GAME_OVER_ROW_127
					beq $s2, 131072, GAME_OVER_ROW_128
					beq $s2, 132096, GAME_OVER_ROW_129
					beq $s2, 133120, GAME_OVER_ROW_130
					beq $s2, 134144, GAME_OVER_ROW_131
					beq $s2, 135168, GAME_OVER_ROW_132
					beq $s2, 136192, GAME_OVER_ROW_133
					beq $s2, 137216, GAME_OVER_ROW_134
					beq $s2, 138240, GAME_OVER_ROW_135

					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_30:
					setup_general_paint (0x000000, 0, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 108, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001400, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x161900, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 160, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 220, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 368, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001400, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 728, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x161600, 840, 844, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_31:
					setup_general_paint (0x000000, 0, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x454500, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbbbe67, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd3d75e, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe0e25b, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdadb5b, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd5d656, 116, 120, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd6d853, 120, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcfd34b, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdee25a, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdae058, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdadd58, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdcdd5d, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1e165, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe4e267, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdddc5d, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd2d15b, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcdc96e, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb5b172, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2d2800, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 172, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x454716, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc0c571, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2e570, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdade56, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcbcd46, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd0d24b, 220, 224, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd5d750, 224, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdbde59, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdde05b, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcdd26c, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b1c00, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 244, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000017, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 260, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x595525, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc8c671, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdfdf6f, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdde05f, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdce25c, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd2d85a, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd3d778, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x49471e, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 308, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x635f2f, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc9ca6c, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd3d45c, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd4d555, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdfe058, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdbdc50, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdedd69, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc1bd7d, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 372, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbab980, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdbdb77, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdcde61, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe0e15f, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdcdd55, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd2d047, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd6d74d, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdadc55, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd7da57, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdbde5d, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdadf5e, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdbe15b, 424, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdfe15c, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdfdf5b, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2dd5f, 440, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdede5c, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdbdc5a, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2e45f, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdadd58, 460, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd2d757, 464, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdce071, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd4d585, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 476, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a1c00, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc4c979, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd1d868, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdae15f, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd8db56, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdee05b, 564, 568, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdfdf59, 568, 572, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2df5c, 572, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1dc5e, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2dc60, 580, 584, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdfde60, 584, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdadb5b, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdfe25f, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdee15c, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe5e664, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdede6e, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc6c37c, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e1c00, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 616, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc2c375, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd5d565, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd7d657, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdddb54, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdbdc54, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd8da5f, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd3d379, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x272600, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 664, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x404200, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd5d978, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd9de60, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdadf5e, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd6db5b, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdadf69, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc7ca6f, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4e4d21, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 732, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd3d884, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd2d965, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd7de54, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe0e557, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd4d949, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd6dd51, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd8dc53, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdadb53, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdbd853, 772, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd9d955, 780, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdcdc58, 784, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdcde59, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdee05b, 792, 796, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdee059, 796, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdbdd56, 800, 804, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdddf58, 804, 808, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdee059, 808, 812, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdcde59, 812, 816, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd9da58, 816, 820, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdbdb59, 820, 824, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1e061, 824, 828, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe5e37c, 828, 832, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb4af77, 832, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x191500, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d3e00, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd9db76, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd3d85a, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd3da50, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdce058, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdce057, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdde252, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdce04e, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2e556, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe3e659, 876, 880, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdfe056, 880, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xddde56, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdddd59, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdada56, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdddf57, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd9dd54, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdcde56, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdde05b, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd7dc5b, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdee176, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd2d292, 920, 924, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_32:
					setup_general_paint (0x000000, 0, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4c4b00, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f377, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f54c, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f841, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9ea44, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefef4f, 116, 120, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9ea47, 120, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeaed48, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f74f, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeff54d, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0f34e, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f24f, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6f356, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7f457, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f053, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xece95a, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xddd765, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd3cc7c, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x302800, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 172, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x464600, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0f37e, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeeef53, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeef142, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe5e83f, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecef48, 220, 224, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f548, 224, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0f543, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeaef3a, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdde051, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x161500, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 244, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 256, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x63601b, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecec72, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f657, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6fa43, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f738, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeaf038, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdee04f, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b4700, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 316, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x736c1c, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f26b, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe5e73c, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8f840, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0f22f, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebeb27, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f24e, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6f394, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdedb8a, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeeed5f, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefee3e, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5f43a, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9f937, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f32f, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfafa3a, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f541, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebed41, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0f34e, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeff450, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeef54f, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0f64c, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f54c, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f44e, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5f150, 440, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6f451, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f54e, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f64f, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0f550, 460, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebf151, 464, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f86c, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9eb86, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a1800, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 480, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeff480, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebf257, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeaf245, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f54e, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f24e, 564, 568, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f451, 568, 572, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f04e, 572, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9f355, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5ef53, 580, 584, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9f659, 584, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f352, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f64d, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f546, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5f640, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f151, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe4e072, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a1500, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 616, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6e56f, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe5e642, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfaf93f, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7f530, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8fa34, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f645, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f371, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x525100, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 664, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b6c28, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f46f, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0f447, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f43b, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0f239, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfafc53, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedee6f, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x514d00, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 732, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9ec77, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5fb53, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7fa37, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f52f, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6f832, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7fc3d, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f641, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f248, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f14c, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f14e, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f24f, 780, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5f351, 784, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f552, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f450, 792, 796, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f550, 796, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f750, 800, 808, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f651, 808, 816, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5f555, 816, 820, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7f757, 820, 824, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7f759, 824, 828, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f371, 828, 832, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcfcb82, 832, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x181500, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x444300, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0f261, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f544, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcfd3d, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8f838, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7f735, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbfd37, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f431, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6f744, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeeed43, 876, 880, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f64b, 880, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5f74c, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f34d, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f44e, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f44b, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f548, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeff23f, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe8ec37, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f740, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9ed50, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5f38f, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x171500, 924, 928, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_33:
					setup_general_paint (0x000000, 0, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x544b00, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5ef5d, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8f838, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f430, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbf758, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5ef65, 116, 120, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f069, 120, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f56b, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeff160, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeff15f, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f062, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f064, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0ec64, 144, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f16a, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5f378, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2ee8a, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd5d08c, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x272000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 172, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4c4600, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfff975, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e946, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdf64d, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f159, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeff25d, 220, 224, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f657, 224, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7fa4b, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6f835, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2ef4a, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x201800, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 244, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f5c00, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f067, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5f53f, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5f322, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5f217, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9f821, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfaf746, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x514800, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x211800, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 312, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x746900, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3ed4d, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdf936, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfef828, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfffd22, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfef81c, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8f23a, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1ea7f, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 372, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6df87, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbf259, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9f12e, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7f11f, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfaf61b, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4ef17, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8f628, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5f33e, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1ef4c, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f15d, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeef260, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedf35f, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedf35b, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedf258, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeff25b, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2f05f, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2ef60, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeeec59, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f15d, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f462, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecee5d, 460, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeff267, 464, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7eb73, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7e693, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 476, 484, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000014, 484, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000016, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 492, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a1500, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7f773, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f350, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeef045, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f35b, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1ee61, 564, 568, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2ee68, 568, 572, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f06a, 572, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2ec64, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0ea60, 580, 584, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeae95d, 584, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6f664, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecec4e, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedeb3e, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcf835, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfef540, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbef67, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x231600, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 616, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xede75b, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbf736, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfaf31f, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdf614, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8f700, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7f92c, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0ef59, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b4800, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 664, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x686717, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3ee5f, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5ef35, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9f325, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8f021, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9f136, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e85b, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c5100, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9e661, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2ef30, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfefa1d, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfff71c, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8f11c, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcf62e, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefea38, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7f25a, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6f368, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3f065, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6f569, 780, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0ee65, 784, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f268, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeeef63, 792, 796, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeff064, 796, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedf061, 800, 804, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecef60, 804, 808, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebee61, 808, 812, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecef62, 812, 816, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeff068, 816, 820, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f26a, 820, 824, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeded67, 824, 828, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe8e679, 828, 832, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc5c181, 832, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x211e00, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x434300, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebe946, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9f62f, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8f31b, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfaf41c, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcf520, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6f21d, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9f733, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefeb4c, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5f265, 876, 880, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefee60, 880, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeeed5d, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1f062, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebed5e, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7ea5d, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeff25b, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefee44, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8f73b, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f327, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3ef38, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e867, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d1500, 924, 928, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_34:
					setup_general_paint (0x000000, 0, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x211b00, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x564e29, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xafa25e, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb6a845, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc3b532, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbee48, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xece719, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8f431, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f5600, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d4300, 116, 120, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4f4a00, 120, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a4a00, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4c4d00, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x494a00, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x484800, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a4a00, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b4b00, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x484800, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x444500, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x444400, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x424200, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x494716, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 168, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x282900, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7a7a44, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7d7534, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x807519, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa39818, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e34e, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecdc3e, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x736500, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4f4800, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d4c00, 220, 224, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x585b00, 224, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbcbd21, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9f534, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebe22d, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb2a62e, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xafa34d, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb5ae5d, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb4af77, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x282418, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 268, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x585200, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1ec5d, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0eb2d, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2e900, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbf000, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8ef00, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9e019, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb1a619, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9f9533, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x958e48, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3e3a00, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 320, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x161400, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5d5830, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x988d33, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xccbf35, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xece22b, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcf21f, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9ed00, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e400, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcef00, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e62a, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2d764, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xddd278, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4e648, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8e81f, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4e700, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5ec00, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8f000, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0e821, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb7af00, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x665f00, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x504c00, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b4b00, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x484d00, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x464e00, 428, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x474e00, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x494c00, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a4b00, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4f4d00, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b4900, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4c4a00, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b4b00, 460, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x404000, 464, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b4a00, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x464600, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 476, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x403a18, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b612e, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x908241, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x96882f, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7d7300, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0ea56, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8f455, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x676300, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5a5500, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b4500, 564, 568, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x443f00, 568, 572, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x504d00, 572, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4f4b00, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b4900, 580, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x464300, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b6500, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x908600, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7ec2e, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7e928, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9e745, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe8d755, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1d372, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdacd87, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbead81, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x221400, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeae04a, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3ea21, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9eb00, 640, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6f000, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1ee15, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe4e041, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4e4800, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 664, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x636000, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebe352, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0e325, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5e600, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8e900, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7e924, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefe14d, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5a4b00, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 732, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xece758, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4ed23, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5ea00, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7e800, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9e900, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e320, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb9ad00, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4e4800, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d4900, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x494500, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d4a00, 780, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x454500, 784, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b4b00, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x474900, 792, 796, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a4c00, 796, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x484d00, 800, 804, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x474c00, 804, 812, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x484d00, 812, 816, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b4c00, 816, 824, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a4a00, 824, 828, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x474800, 828, 832, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x343200, 832, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a4800, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeeea41, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xede518, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4e800, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6e900, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbef00, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2e900, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeae42e, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x584f00, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a4400, 876, 880, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b4800, 880, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x484800, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x444600, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x474900, 892, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5d6000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x777500, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xece735, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4ec1d, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xded200, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e344, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7db61, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdbd47c, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdad7a0, 932, 936, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_35:
					setup_general_paint (0x000000, 0, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8e7e42, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9d866, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5e14c, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedd630, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xead71b, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6eb17, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe5db2b, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 116, 120, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 120, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x726c2e, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe0dc79, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe3da61, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7db47, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2d527, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0db30, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9df54, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a3300, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 220, 224, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e1f00, 224, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9c9c24, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8ee3e, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedde1f, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdccd2a, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e551, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2db4d, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdcd972, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x151400, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 260, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x534b00, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2da51, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xece22b, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4e400, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5e300, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7e400, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbea18, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebdf2b, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6dc49, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0ea78, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x615d00, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x181400, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x989353, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe8de5b, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0e430, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4e818, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5e700, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdeb00, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4e000, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfce714, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4e031, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe5d566, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd1c16a, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeed940, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8e11f, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6e300, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0e200, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3e417, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefe335, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaa9c21, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x251a00, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 416, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x645b24, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9da85, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebd969, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe8d64e, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeee042, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebdf3f, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1d648, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x423700, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x201600, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 564, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001400, 580, 584, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 584, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x231900, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x857500, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6e138, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9e220, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4dc20, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2de31, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeee147, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeee268, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc5b369, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x251400, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedde4d, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedde21, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8e200, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4de00, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8ea00, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e714, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7de41, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4f4700, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 664, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x625e14, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xece153, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e225, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5e500, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5e200, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4e220, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe8d847, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x534200, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7e253, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeae01c, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4e500, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbe800, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8e200, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3e02c, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb4a621, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 772, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b4400, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6dd40, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2e421, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5e500, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6e400, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6e600, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5ea1e, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xece346, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 876, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001400, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 892, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x555100, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebe14b, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0e21f, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfff01e, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7e426, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeedd38, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6dc56, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe5e085, 932, 936, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_36:
					setup_general_paint (0x000000, 0, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x947a2f, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9d342, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2dc27, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5d91e, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfae220, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe8db00, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe5db3c, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x231400, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 116, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x837423, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeadd5d, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0e244, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5e633, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfeec28, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7e22f, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefd254, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b2200, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 220, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbdba5b, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7db3b, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e020, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0df20, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5e52d, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5ea38, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdad34f, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 256, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x584e00, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6da54, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebda28, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7e018, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6dd00, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbe300, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5e100, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3e419, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe8dd2b, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd9d043, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c5300, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9f9442, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe5d739, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e014, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7e300, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfae300, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8dc00, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffe100, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3d800, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9e139, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecd76c, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd2be67, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7de46, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbe021, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfce400, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9e400, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6e21f, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1df3f, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac9d38, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 416, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b5d16, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecda6a, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefda49, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2dd34, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2dc27, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4df38, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebd858, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f2e00, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 564, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x836f18, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedd63b, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5de1c, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbe41a, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3de15, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecda1e, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e048, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd1be60, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a1700, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6d645, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2df29, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6db00, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcdf00, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7e100, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4e317, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9dc42, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d4300, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 668, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5e5700, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7da4e, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefdd21, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7e200, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4dc00, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9e125, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeed94c, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x524100, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9df59, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4e526, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7e300, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6de00, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8df00, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3dd32, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb4a32f, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 768, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x554900, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeadb44, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1dc1f, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbe300, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7de00, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9e400, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebda18, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9dc50, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 872, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x514a00, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9dc52, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6e428, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeed900, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9e000, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8e123, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeedf3c, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeae06f, 932, 936, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_37:
					setup_general_paint (0x000000, 0, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa57f2e, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7da3e, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6dd1e, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcdd20, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbe226, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeee42b, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeae45a, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b1400, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 116, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x846b00, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2c73c, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1d62d, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7df23, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2de1b, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5e134, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2d963, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d2900, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 216, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb5b05f, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebdf4f, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1e12a, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4e01d, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedda00, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3df20, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfae95b, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x211800, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 260, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c5000, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeede57, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4de30, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfadc1c, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcdc00, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfce200, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9e300, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3e000, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3e223, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbe750, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x604c00, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa69134, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6de36, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfee000, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfedd00, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffdf00, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffdd00, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdd700, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9d900, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4db38, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xead270, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 372, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd9c167, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6db42, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfee121, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffe315, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbdf00, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbde20, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3da40, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xad9a3b, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 416, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e5d00, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4df5f, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6e03c, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7df23, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8da18, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7d82f, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4db64, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d2b00, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 560, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x826d1a, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecdb47, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3e223, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2dd00, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9e300, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6dc15, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8df3c, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd3bc56, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x311a00, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7d543, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1da28, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4d400, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcda00, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfee000, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4dd15, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebda44, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4e4100, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 668, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x635c16, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeddd54, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5e128, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6de00, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbe100, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfee12b, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedd54d, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x544500, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0dc63, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5df29, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7de00, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfae000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8dd00, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0d732, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb5a333, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 768, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x554200, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5db46, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7da1e, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffdf00, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffe100, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5da00, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8e026, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebd752, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 876, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x574700, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecda50, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4e027, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfae100, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcdd00, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4d614, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7e030, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe8da5d, 932, 936, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_38:
					setup_general_paint (0x000000, 0, 72, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 72, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x270000, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a1e00, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9b6f00, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6d532, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8dc23, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffe136, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe4cc2c, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xddd542, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdcdb71, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a1600, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 116, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x866400, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffdc45, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffdf2f, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7d91f, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfde732, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6d23d, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe5d273, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x413100, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 216, 224, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b1500, 224, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaea770, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6db6f, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeada46, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9e32e, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfde21f, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbdc1f, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeacf36, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x352500, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e0000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x635200, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7d34e, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8dd34, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffd922, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffd814, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfad800, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfee100, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfde200, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7dc19, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedd02c, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x725400, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x341600, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b2100, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x987d00, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffe231, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcd600, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffda00, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffd300, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffd200, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffd600, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffdb17, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6d937, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9cf6e, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x220000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd3b964, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2d23f, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcda20, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffde17, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffdb15, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffdb23, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3d541, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab983c, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 416, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e5d00, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2da52, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5db2c, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9db17, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfed800, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcd62b, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7d766, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x422a00, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 564, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x836d21, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebd84d, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3de29, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfae019, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8d900, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfeda14, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcd937, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd8bc58, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedd648, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6dc2f, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcd61b, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcd200, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffdc00, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbdd1d, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedd746, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x524300, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 668, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x655b16, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedd954, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6db28, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6da00, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6d700, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbda29, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6d957, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x564500, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3d968, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbdd2d, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffe000, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffdf00, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbdb17, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3d537, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf9a31, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 768, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x574000, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7d945, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffd920, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffdc00, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffdd17, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfad719, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbdb28, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedd251, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 876, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x544000, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7df57, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3d825, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4d500, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffd900, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffda19, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfada27, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebd656, 932, 936, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_39:
					setup_general_paint (0x000000, 0, 72, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x644f16, 72, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa07e27, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb38900, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcea414, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfad52f, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9c929, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdabb3c, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x836e00, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x777417, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e7031, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 112, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b3c00, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x957a2b, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe9600, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7cc28, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8d020, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedcc1f, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe3cb37, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x827200, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x554c00, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x191400, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 216, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c341d, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x534c16, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x615200, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1c637, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedc81f, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffd622, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5d029, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa18900, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e8e2e, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8a7945, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x584400, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9d051, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefce2b, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6c81b, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffcf18, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbcc00, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfed200, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9d200, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9d300, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffd425, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd1a500, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa98000, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa68100, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa48500, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd9ba24, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4d01a, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbd100, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffd200, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfccd00, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbca00, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffd000, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfed300, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3cf30, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1c863, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e0000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd1b56c, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5cf48, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9d020, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8cd00, 392, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9d01e, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefcf3e, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa9963a, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 416, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6a5800, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xead048, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0d023, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7d000, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xface00, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7cb22, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0ca5b, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x422400, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 564, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x806925, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9cc4c, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3d129, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdd619, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4c800, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffcd16, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9cb37, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd4b259, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x341a00, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7cd45, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeccb24, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6c914, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5c400, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdd200, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4d01a, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2c63e, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x523e00, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 668, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x604e00, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebce50, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5d329, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2cd00, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8d100, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfad129, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebc94b, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x513e00, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xead061, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefce21, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfad300, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9d000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6cc15, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9d340, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb19736, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 768, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x523c00, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeecb3b, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfacd1a, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffcf00, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfccf00, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9cf18, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5cd1d, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9cb49, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 876, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c4100, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedcb4d, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6d226, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbd000, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfece00, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8c700, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8cc21, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeccc51, 932, 936, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 936, 940, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_40:
					setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 68, 72, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x977a2e, 72, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefc652, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9ba24, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5c421, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6c928, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeec43a, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd1af4e, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x301c00, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 104, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 156, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x725916, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6bf56, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1bf2c, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6c016, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5c100, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebc121, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2c44a, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x443300, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 208, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeac955, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefc126, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6c217, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecba00, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7c420, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe4c948, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc6ab66, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1f0000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x604300, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0ce53, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4cc2f, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3be1a, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfec418, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcc100, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfac200, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5c300, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5c200, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfac300, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7be15, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4be1e, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbcb2d, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeac020, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1c820, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8c700, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9c600, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6c100, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbc600, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9c300, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfac400, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9c500, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2c72d, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdec15d, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd0b371, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0c344, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9c420, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbc400, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfeca16, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3c31b, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecc53a, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac9136, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 416, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c5600, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeac948, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4c924, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8c800, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdcb00, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9c823, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedc259, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x482500, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 564, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7e6427, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7c049, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4c628, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5c300, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9c100, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcc216, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5c137, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xceab59, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe4c244, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebc325, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1bf00, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3bd00, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffcb00, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdcd23, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebc441, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x573900, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 668, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6a4f00, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebc349, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1c423, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4c300, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6c500, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5c525, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebc34a, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d3300, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1c057, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3c925, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5c600, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1bf00, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8c416, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeebd34, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb48d30, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 772, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4e3700, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7c138, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9c51a, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdc500, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8c400, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbc719, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2c216, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe4be41, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 876, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x613d00, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6bc43, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2c521, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfac800, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfec700, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfac200, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7c21e, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedc450, 932, 936, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 936, 940, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_41:
					setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 68, 72, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa37a28, 72, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcc449, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffc227, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffbe1a, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8b823, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7c049, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd6ab5d, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x371c00, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 108, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x270000, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x280000, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x250000, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x220000, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x260000, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x240000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x744c00, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4bf3f, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffc426, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffbe00, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdba00, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfac030, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe4bd58, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f2a00, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 208, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9c057, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfac12c, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7b600, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcbd00, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdc91b, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe7b92f, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xddb06d, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c4400, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdeb43e, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5c32c, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdc122, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffbf17, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffbd14, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfebc00, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdbe00, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffc100, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffbf00, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffbf16, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbb800, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffc018, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcc218, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3ba00, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffc100, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffbf00, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfec200, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdc100, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfabd00, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfabc00, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbbe16, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5c032, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1bd5f, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x250000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1f0000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcdac69, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9c24d, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfab722, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9b400, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffc51e, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9bd21, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9c442, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb68b2f, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x320000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x220000, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 420, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1f0000, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x240000, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 436, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 456, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x725500, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedc34b, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9c426, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcc100, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbc100, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5bf21, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe5b551, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x462300, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 564, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7f6125, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6b647, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6bd28, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffc618, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfec100, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefb000, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebb531, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdbb867, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xecc24a, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefbd28, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7c119, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6b900, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcb900, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffbd1e, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2b83a, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f3000, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 668, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 680, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 688, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x260000, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b4400, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3bf47, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4bb24, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcbf17, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1b400, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5b923, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbc757, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x573700, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 732, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1b755, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1be25, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffc915, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffc400, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffc01d, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcbe39, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc58f2f, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x280000, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x250000, 776, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 784, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x270000, 792, 796, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 796, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1f0000, 800, 804, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 804, 812, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 812, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x513700, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe8bc3f, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfec422, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffc200, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcbe00, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdc01a, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffc422, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeabb47, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 876, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x330000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x653600, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4c048, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9c428, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8c100, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffc300, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbbd00, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbbc23, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeebe52, 932, 936, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 936, 940, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_42:
					setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1f0000, 68, 72, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x926200, 72, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefad33, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4a814, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3a400, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5a91f, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9a739, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc79654, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f1e00, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 108, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x613915, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x642e00, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6d3000, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e3300, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6a3800, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x653500, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x633000, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6d3d15, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f3400, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x553216, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1f0000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x824d00, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedaa27, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8ab00, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffb300, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffab00, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9b02d, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd9a752, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x452600, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 208, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdba94a, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4ad21, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4a500, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffb300, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8b600, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe4a91f, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda9f63, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x310000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2d0000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x734100, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdda73b, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5b629, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5ae18, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9ac00, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffb200, 296, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffb100, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfeb000, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfaad00, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6a900, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfaad00, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9ac00, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffb400, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcb100, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8a900, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbae00, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcb600, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8b200, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8ac00, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9ac00, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8ad14, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebaa28, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd7a752, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x220000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbf995b, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebab41, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3a61c, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfaa900, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffb419, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeaa200, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeda92c, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc98a29, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7e4400, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c3700, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x673400, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x663300, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x663400, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x693400, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x673200, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x633200, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c3621, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 452, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x714c00, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe4b042, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1b01e, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf2ad00, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4b200, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeeb21e, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdba94a, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x452100, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 564, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7c581e, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe0a53f, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefaa1f, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7b200, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7b000, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5ac00, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe4a72a, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc7a051, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2c0000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdaa437, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1b129, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfab51c, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfeb200, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffab00, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffab1a, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbb134, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x995700, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x723600, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x632f00, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c321a, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 680, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x533200, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5e3600, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c3b00, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9d6400, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfeb940, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffbc2c, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfaaf15, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7ae14, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3ae22, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6ac41, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5d3800, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x220000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2c0000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1ab51, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xedab1f, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdb600, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbb200, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5aa00, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7a827, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd28923, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7a3d00, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x764000, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c3500, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6d3500, 780, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b3600, 784, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x693400, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b3400, 792, 796, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x673200, 796, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5e3300, 800, 804, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x563816, 804, 808, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 808, 824, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000014, 824, 832, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 832, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x532f00, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1ac3a, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6b31a, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbb000, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7ab00, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4ab00, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0ad18, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdeab42, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 876, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x583519, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6d3e00, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x945800, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeead35, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5b31f, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7b300, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdb400, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9ae14, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6ad23, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebb354, 932, 936, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1f0000, 936, 940, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_43:
					setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 68, 72, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8a5500, 72, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe59c2d, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe68e00, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea8d00, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed9915, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd68f25, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb47e3e, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b1900, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 108, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf9355, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc8d3e, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdf893c, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc8b3c, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd7933e, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd5933f, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd58e3e, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd79149, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc8c4f, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb58054, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a1400, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2e0000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7f3d00, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6951f, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed9300, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf28f00, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf58e00, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe18614, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd2944b, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x482300, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 212, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd49339, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed9400, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf59500, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf39800, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb9e00, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd9951a, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbd7e48, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x330000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e3600, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd79537, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe99a21, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe68f00, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe48800, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe58500, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb8900, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe98a00, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee9200, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf09600, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb9300, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb9600, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee9700, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee9300, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe78900, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf69700, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee9400, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea9800, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee9c00, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf29600, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf59600, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf09700, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe09118, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc8e43, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2d0000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x270000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb2834d, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdb9535, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe48f00, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb9100, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xef9600, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe69300, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed9b1e, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe69329, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd68325, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1913a, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde903b, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc9134, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd9332, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd912f, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd88f33, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd38e43, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc9925c, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x552f1a, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x250000, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 460, 524, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 524, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6f4100, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd99937, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe49a15, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe89b00, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe79a00, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe29e17, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc993e, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3e1d00, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 560, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7c4e1a, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd99437, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe99719, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed9d00, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe99800, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed9800, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde931e, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb18031, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x420000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc98522, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe5921c, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea8f00, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xec8b00, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea8300, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb8400, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xef9616, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe28e1c, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde8d31, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd9934b, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc99460, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x320000, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb78957, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc9e53, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde973b, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb9a2e, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc8400, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe78d00, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda8100, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe79400, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe49715, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc58722, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f3400, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x300000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc8938, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe79819, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe78f00, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb9200, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf79d00, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea8900, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed9122, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde8d32, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda8d3f, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd48536, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda893a, 780, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde8d3c, 784, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe59341, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe38e3e, 792, 796, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd8e43, 796, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd99856, 800, 804, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc19361, 804, 808, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 808, 812, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 812, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x552500, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd9830, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee9b00, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf39a00, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf29800, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xec9600, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe29916, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd19e42, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 876, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbd8e56, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc38530, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1982f, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe49215, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe38d00, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe98f00, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed8c00, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee9000, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe28b17, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd69845, 932, 936, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_44:
					setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x270000, 68, 72, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x965600, 72, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe08626, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf28317, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf28000, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf18918, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe18a2d, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc1824c, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 104, 120, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 120, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x280000, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd6914e, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1953e, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee8931, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe9842a, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea8d2e, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee9132, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf28f32, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe58531, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdb843f, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc17b4a, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x340000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x863900, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea8a26, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf58c19, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfb8800, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfd8514, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf28528, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd8864a, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x521700, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x240000, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 220, 224, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 224, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2c0000, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe68f42, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf88c1f, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfa8700, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf48600, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed8c00, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe39028, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcb8554, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6d2e00, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd38137, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed8c2b, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf08619, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf48300, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf78100, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8e00, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf38b00, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf18e17, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf09015, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xef9000, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf59400, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf58f00, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfd8d00, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfa8c00, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf28e16, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee9014, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf19500, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf69200, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfd8b00, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8900, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfd8c00, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee8d24, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd88c50, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x330000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb67b51, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe18c3b, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xec851c, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf78a00, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf78900, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfa911c, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf28c20, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee8a28, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9973c, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6882e, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe48b2d, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe49129, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe69428, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe69124, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe18f2b, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc8f3d, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd3955c, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x542700, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x240000, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 460, 524, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 524, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x773d00, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdb8c3d, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe78d1f, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf29000, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf08d00, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb9423, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd19245, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x431d00, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 560, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x814b1d, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe08b3b, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf08b23, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8941a, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf99200, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf58b15, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed8f2d, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb87733, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x440000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf8639, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe38e33, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb8f28, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe88415, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf18115, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfa8818, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf08500, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf58d1e, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xef8320, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0903c, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde9455, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x300000, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x220000, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2c0000, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdb955a, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf09743, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf08c2e, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3861d, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf58300, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf18400, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed8a00, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb911f, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe19428, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xca8c37, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5b2e00, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2d0000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc8d4a, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea891e, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf78b00, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfd9000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfb8b00, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf98600, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfa8d24, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe58c2e, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe19037, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe69137, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe68d31, 780, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2892d, 784, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe98e33, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6862f, 792, 796, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe88f3d, 796, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd58f49, 800, 804, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc89663, 804, 808, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 808, 812, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 812, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c2000, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe58f38, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf6921a, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfd9000, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8f00, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf58c16, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xef9024, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd79042, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x240000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 876, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2c0000, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdf9556, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe28a30, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xef9630, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe48a1c, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe98e1b, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf39420, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf28e1e, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee8d26, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe28d30, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd49b58, 932, 936, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_45:
					setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2e0000, 68, 72, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa14f17, 72, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf18034, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7e2d, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7824, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7d2a, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf88944, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd17f59, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 104, 120, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 120, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x220000, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd8e58, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1893f, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf08036, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf97e31, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8737, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfe802c, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfe7a27, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7772c, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf08245, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd27e52, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x862e00, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4853e, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8430, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8027, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7c27, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf57631, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf08358, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5e0000, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x340000, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x330000, 220, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2f0000, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4c0000, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9814d, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7f33, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7d27, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfe791e, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8124, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf88d3f, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc7d56, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d0000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6f2400, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe4804c, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf8813d, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7c31, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7b26, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7e1f, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8628, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee812c, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe48531, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe28631, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe68429, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf68421, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8c25, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7e20, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfb8229, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed8a35, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea8c34, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf58d2a, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8b2a, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff751f, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff731f, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7a1e, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfc8334, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda8254, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xca8063, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf5894b, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfe7d2c, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff761e, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7c22, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7c2a, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf27428, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe3722c, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed8745, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdf8642, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc8c45, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdf9347, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe19645, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe19243, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda8b46, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd8650, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe825e, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x471c00, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 460, 524, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 524, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x793500, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe38047, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf37f32, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8128, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8027, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf37b2d, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd8864e, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x471500, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 564, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x884421, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe97f45, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfd7d32, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7f2a, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8028, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7626, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfe8340, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd17d4e, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc8857, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd79058, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd9904c, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde8a41, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xec8035, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9802f, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff842d, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfc791f, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7726, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7f39, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe97e48, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d0000, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x450000, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf1884e, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf0762b, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8038, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7c30, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7b25, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8329, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf38935, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe18a3a, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdb9146, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc945b, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b2100, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x310000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde8452, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf88334, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8224, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7c20, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7a21, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7722, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf77e2b, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc8538, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd38b41, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd98d42, 776, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd2863b, 784, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd98b43, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc8945, 792, 796, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc8e50, 796, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xce8f5c, 800, 804, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc09372, 804, 808, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 808, 812, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 812, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x621900, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe57c3a, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfc802a, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff8120, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff761b, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7820, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xff7e2d, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf38246, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x460000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 876, 880, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 880, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x310000, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f0000, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a0000, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf98751, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf67d36, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf3893d, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdf8234, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc8939, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdf8d41, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe18b42, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdb8b46, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd49051, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc5996a, 932, 936, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_46:
					setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x340000, 68, 72, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x862300, 72, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb62c00, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc72600, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd32900, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf2900, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbc2d00, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa0331c, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x470000, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 108, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d0000, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c0000, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8f1500, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb21f00, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc52600, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd2700, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd72a00, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd02c00, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb42b00, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9c3417, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7a0000, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xba3100, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc42900, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc92400, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd62f00, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc62300, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc52e00, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa41800, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa82827, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa72c31, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa4272f, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa0252a, 220, 224, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9b2426, 224, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e2828, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa7292d, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaa1c18, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc72600, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc92100, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xce2700, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd12b00, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xce2700, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc02f00, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x96361d, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x420000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x440000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6a0000, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb23716, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbf2b00, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc42200, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcb2000, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd42700, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc72e00, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8d1b00, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5b0000, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5a0000, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x862100, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb12c00, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc13000, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc02e00, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e1d00, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x630000, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x710000, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa02800, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe2c00, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd32700, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd52100, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd22300, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc72f00, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab3f22, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x490000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x973a29, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb22c00, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd2c00, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd12200, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd72800, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd22e00, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbf2c00, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x941d00, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6d0000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a0000, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f0000, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x300000, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 452, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x610000, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb63b1a, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc23100, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd2c00, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd52700, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc62b00, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa8401d, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e0000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 564, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x320000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e1d00, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb43400, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc52900, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd32c00, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd72900, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd32200, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc12700, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e361b, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x450000, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x500000, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x730000, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb12f00, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc22e00, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd2900, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd32300, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc2100, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbc2300, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa61b00, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac2e22, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9d1a00, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc42b00, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc82100, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd02100, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd52200, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd42300, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc12600, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9c2900, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x550000, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4c0000, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x451700, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x250000, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3e0000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa8391b, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc43100, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd52c00, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd72c00, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd73000, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc52800, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e1d00, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x510000, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 780, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 792, 796, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 796, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 800, 804, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e0000, 804, 808, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 808, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x590000, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb93600, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc92f00, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd12800, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf2000, 856, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd62b00, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc62700, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf2314, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa32320, 876, 880, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa02426, 880, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa72b2b, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb13631, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa01800, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc22400, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe2600, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa02600, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f0000, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x440000, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f0000, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x420000, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x310000, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x260000, 932, 936, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_47:
					setup_general_paint (0x000000, 0, 64, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 64, 68, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f0000, 68, 72, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8b0000, 72, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc11f00, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd61c00, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd1500, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd60000, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc70000, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac2217, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5b0000, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 108, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x280000, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d0000, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x990000, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc91900, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda0000, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe50000, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea0000, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda0000, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc2119, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9c1b16, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x560000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a0000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8b0000, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc41900, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd81600, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe20000, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xec1500, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe50000, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdf0000, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe21500, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd91516, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd10000, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd10014, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd40017, 220, 224, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd00016, 224, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf0015, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd6141c, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde1619, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc0000, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe40000, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe51400, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe10000, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe70000, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd10000, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9a1f1a, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x520000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x540000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x790000, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb92114, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xce1900, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe11a00, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe10000, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe51700, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xce1e00, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8c0000, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x470000, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x430000, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x811600, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc72d21, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc41800, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe1d00, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9a0000, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b0000, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x660000, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae2200, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf1c00, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda0000, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe40000, 356, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd21700, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa32100, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x570000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x510000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x94211a, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb1800, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe01c00, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe30000, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe20000, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd71400, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe1b00, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8a1400, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x480000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 424, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 444, 524, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 524, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6a0000, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb62218, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xca1600, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda0000, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe40000, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd61400, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa92516, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x520000, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 564, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x690000, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb31e00, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd41c00, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd0000, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe00000, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe50000, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf1700, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa72b21, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b0000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x610000, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb82a16, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xce1c00, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe01400, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb0000, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe60000, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdf0000, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe00000, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd90000, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde0000, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe20000, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe70000, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe60000, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe70000, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe40000, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xca1600, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa73127, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2e0000, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x460000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaa2016, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda1b00, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe90000, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe30000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd80000, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc1b00, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x981500, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d0000, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 780, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x280000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b0000, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbd1a00, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd91600, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe40000, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea0000, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb0000, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee0000, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe20000, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdb1400, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf0000, 876, 880, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde1d20, 880, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xce0000, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc70000, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdb1900, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc0000, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc90000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9c0000, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x520000, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x300000, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 916, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 928, 932, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_48:
					setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3e0000, 68, 72, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x840000, 72, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb81c1f, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd191c, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc1417, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe60000, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda0000, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe1f1b, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e0000, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x320000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 112, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f0000, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x970000, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd0018, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe80000, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf60000, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf90000, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe80000, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd0171d, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e0019, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x590000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x550000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x900000, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd6181a, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea0000, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf30000, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf60000, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf20000, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf30000, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee0000, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd0000, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda0000, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc0000, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd0015, 220, 224, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdb0016, 224, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc001b, 228, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdb0000, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe70000, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe80000, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb0000, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf30000, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf70000, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe0001b, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa11e23, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4f0000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x570000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7f0000, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc11e19, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd20000, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea0000, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe80000, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xef0000, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf0000, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x840000, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x731620, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb5232e, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb6001b, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf1a1c, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8f1716, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f0000, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb31f1f, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd71617, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe80000, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf30000, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf20000, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe01400, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa81f19, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x560000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4f0000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa02424, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcb1915, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe50000, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe90000, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee0000, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe20000, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc61a18, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x881414, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 420, 524, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 524, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6f0000, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbd1d1f, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd50000, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed0000, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf20000, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe80016, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb31f1b, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5b0000, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 564, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e0000, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f0000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e0000, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xba1700, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd0000, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf10000, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf20000, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee0000, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd50000, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae2422, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b0000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x250000, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x540000, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa41f1a, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc81500, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc0000, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf10000, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf60000, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf30000, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf60000, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf30000, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfa0000, 684, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf40000, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf30000, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb0000, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe6001a, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbd141b, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x972e35, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x320000, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 724, 728, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 728, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x450000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb11f1f, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdb0000, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf00000, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf50000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe50000, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd51b1e, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x920000, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 772, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x270000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x730000, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xca1615, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb0000, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf70000, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf90000, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf60000, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf70000, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf60000, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe00000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdb0000, 876, 880, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde0000, 880, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea0000, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed0000, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee0000, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xec0000, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd80000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0000, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x660000, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x430000, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x280000, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 920, 924, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_49:
					setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x320000, 68, 72, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x71141e, 72, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa1222b, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xad1a22, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbf0018, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde0016, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd60000, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb60000, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x840000, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5b0000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 116, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8d0000, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc30000, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe50000, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf40000, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf10000, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe50000, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc9151e, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9d161d, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4e0000, 168, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x860000, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd00018, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe20000, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee0000, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf70000, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe90000, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe20000, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd21700, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbf1b00, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xba211b, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb71b1c, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb61b1f, 220, 224, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb61c26, 224, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb72029, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb41f21, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc4201f, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd1b19, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe60000, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe10000, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe90000, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf00000, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd50018, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x951d1f, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x420000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b0000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x710000, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xba1c19, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd20000, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe70000, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe50000, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee0000, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xce1618, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7a0000, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x320000, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2c0000, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x58151c, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8f212c, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa22932, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x90272b, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6f1b1b, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x330000, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x520000, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab1c1e, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd0014, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd0000, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed0000, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf00000, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd90000, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa5211c, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x510000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4c0000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9b2426, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc71717, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde0000, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea0000, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb0000, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde0000, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc51917, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x800000, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 416, 524, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 524, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6d0000, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe1d23, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf0000, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe60000, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf10000, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe70014, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb91f1d, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f0000, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 564, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x740000, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc61c1c, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe60000, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe90000, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xef0000, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xec0000, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd30016, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa71917, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x540000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 636, 640, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 640, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x250000, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x520000, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8c2320, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb42119, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd01900, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd0000, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe90000, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf20000, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf80000, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf50000, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf00000, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb0000, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf10000, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xed0000, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda0000, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc92121, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9f2427, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x732c32, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 716, 720, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 720, 724, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 724, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae2924, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd90000, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xec0000, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xee0000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe10000, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd0151c, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x940000, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x340000, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 772, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c0000, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc91717, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe60000, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf80000, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf60000, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf00000, 860, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe00000, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb1c19, 876, 880, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd01820, 880, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde0019, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe20000, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf10000, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xef0000, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc0000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xba0000, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x830000, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x600000, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b0000, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x420000, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 924, 928, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_50:
					setup_general_paint (0x000000, 0, 68, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 68, 72, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 72, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x590000, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x660000, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x840000, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc81417, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd30000, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc91a17, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa90000, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x991419, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x78141c, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x300000, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 116, 120, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 120, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d0000, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x880000, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0014, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde0000, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xeb0000, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe90000, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe10000, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc4171b, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x98151b, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x490000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b0000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8c0000, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xca0016, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc0000, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe70000, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe80000, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda0000, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb90000, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x930000, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b0000, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f0000, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x610000, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x620000, 220, 224, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5e0000, 224, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f0000, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5d0000, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x720000, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb50000, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd0000, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd30000, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe10000, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe20000, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd001a, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8e1b1e, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x430000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x450000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e0000, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf1500, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc70000, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde0000, 288, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe10000, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc30000, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x710000, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x320000, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x260000, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2f0000, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x430000, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x520000, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x310000, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x510000, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa81b21, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc80015, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd60000, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe10000, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xea0000, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd40000, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9d1d1a, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4c0000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a0000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8e1b20, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0000, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd70000, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe30000, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde0000, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd00000, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe1500, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x810000, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f0000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 420, 524, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 524, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x690000, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb61f26, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc20000, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd50000, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe50000, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd70000, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb3191b, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x620000, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x330000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 564, 568, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 568, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x220000, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x770000, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc5141a, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd90000, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe90000, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe60000, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd30000, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc00015, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9f1b19, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a0000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 636, 644, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 644, 648, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 648, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x440000, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x690000, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaa1600, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc20000, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd0000, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe40000, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe30000, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe80000, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe60000, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe10000, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd90000, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd00000, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0000, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x750000, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x560000, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x310000, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 716, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9b1919, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcb0000, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe00000, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe10000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde0000, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc80014, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x910000, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 772, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6a0000, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc01617, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd70000, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xec0000, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe80000, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe30000, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe20000, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc80000, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7a0000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x750000, 876, 880, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x930000, 880, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0000, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd30000, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe10000, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd0000, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd60000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc0000, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb91400, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa51c16, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8b1e17, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e1b17, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x320000, 924, 928, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_51:
					setup_general_paint (0x000000, 0, 72, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 72, 76, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 76, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x560000, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb11f1f, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc11400, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc00000, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb90000, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc10000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab1a1d, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x450000, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x250000, 116, 120, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e0000, 120, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x220000, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x430000, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x810000, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xad0000, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcb0000, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd40000, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd80000, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd0000, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xba1614, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x911515, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b0000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x440000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x810000, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0000, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd60000, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe90000, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc0000, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xce0017, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9d001a, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c0000, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2e0000, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 212, 216, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x220000, 216, 220, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 220, 224, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e0000, 224, 228, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 228, 232, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x220000, 232, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb21a19, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd20000, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda0000, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc0000, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe10018, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc90022, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8a151d, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x420000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6f0000, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae1615, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc20000, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd20000, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde0000, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdc0000, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0000, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6a0000, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2f0000, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 316, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 320, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 332, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x560000, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa51820, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc50016, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd40000, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd80000, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdb0000, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc90000, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9a1e20, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4f0000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a0000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8a191d, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb90017, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd20000, 388, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd50000, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd20000, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc21916, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8d0000, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x500000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 428, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 440, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 448, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 460, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 464, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 468, 524, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 524, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5e0000, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa01f24, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xad1400, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe0000, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd0000, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc50000, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa60019, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x610000, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e0000, 564, 568, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 568, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 580, 584, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 584, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2e0000, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4c0000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7d0000, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc20015, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd20000, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd00000, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf0000, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbc0000, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa6151a, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8b1d20, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d0000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 632, 636, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 636, 652, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e0000, 652, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x881e22, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa30016, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc10016, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd00014, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd30000, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd40000, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd10000, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf0000, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc50000, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb1715, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9c1b16, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x480000, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2c0000, 708, 712, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 712, 716, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 716, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f0000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9c1621, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd0017, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdf0000, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd90000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd60000, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc50000, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x940000, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 780, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 784, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 792, 808, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 808, 812, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e0000, 812, 816, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 816, 828, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 828, 832, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 832, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x270000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x630000, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb31418, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd0000, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd0000, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd70000, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd50000, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd50014, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbc151c, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b0000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4c0000, 876, 880, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x730000, 880, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaa0022, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xca001b, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd10000, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd60000, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xde0000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd80000, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xca0000, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc00000, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb32019, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8c1b17, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x430000, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 928, 932, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_52:
					setup_general_paint (0x000000, 0, 80, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 80, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x310000, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x891e18, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa41700, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa50000, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbd1400, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xce0000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc41818, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x670000, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x450000, 116, 120, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 120, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x460000, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5b0000, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x860000, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0000, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc80000, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd30000, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd90000, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc80000, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb31800, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8b1500, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x500000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x450000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7c0000, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xba0000, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd0000, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda0000, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd30000, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc10016, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x981c27, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x440000, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 212, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa11516, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc0000, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd90000, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd80000, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd10000, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbd001b, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8c1a22, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x450000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x420000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x620000, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa80016, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc90017, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd10000, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd60000, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc0000, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb80000, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b0000, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 312, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x220000, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x570000, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa51922, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe0017, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc70000, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd50000, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd60000, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe0000, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x90181a, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b0000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x470000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8d2026, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb91520, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xce0017, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcb0000, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd40014, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xce0000, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb70000, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x960000, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6f0000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4e0000, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x330000, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x340000, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 456, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 464, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2f0000, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 480, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a0000, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7e1b1e, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x901915, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa31a14, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaa0000, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb7191a, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac171d, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7a0000, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x540000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 564, 568, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 568, 572, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 572, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d0000, 580, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x510000, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6d0000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x920000, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc60015, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf0000, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc60000, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xad0000, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9f181c, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8c2226, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b1a20, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 632, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c232a, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8b1c25, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa31720, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb3001a, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc31419, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbf0000, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc50000, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0000, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa71918, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x991d1f, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7b1f20, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2f0000, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 708, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa21b29, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xca0017, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda0000, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd0000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd10000, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc60000, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x990000, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c0000, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x430000, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 780, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 784, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d0000, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 792, 796, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 796, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 800, 804, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 804, 808, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 808, 812, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 812, 816, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 816, 820, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 820, 824, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x320000, 824, 828, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 828, 832, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 832, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x670000, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae151a, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd0000, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd50000, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc90000, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xca0000, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc60000, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab1517, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x330000, 876, 880, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x620019, 880, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x951f2d, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf1724, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbc0015, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd0014, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda0014, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd70000, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda0000, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd00000, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbd0000, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9a0000, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x650000, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 932, 936, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 936, 940, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_53:
					setup_general_paint (0x000000, 0, 84, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 84, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x490000, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b0000, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x750000, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa30000, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc20000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc10000, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8c0000, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7a0000, 116, 120, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x750015, 120, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x771417, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7a0000, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x820000, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x960000, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae0000, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc40000, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd60000, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd50000, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc00000, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa60000, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x881816, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b0000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x470000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x770000, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb10000, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc50000, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd0000, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc90000, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb90000, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x991520, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4e0000, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 208, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x980000, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc10000, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd10000, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd40000, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc90000, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf0000, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x811a1b, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d0000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f0000, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10018, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc7001c, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc80000, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xca0000, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcb0000, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb6001b, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x600000, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x260000, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 316, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x540000, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e1821, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb60017, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbc0000, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc60000, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc0000, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb60000, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8a1616, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x460000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x430000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x831b24, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaa0018, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe0000, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc50000, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc90000, 396, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc00000, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab0000, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x980000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x860000, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7c0000, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x790000, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x770000, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x780000, 432, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x770000, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7a0015, 452, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x750000, 460, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x780015, 464, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6d0019, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x621920, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 480, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x240000, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x510000, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x630000, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x750000, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9f1918, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa80000, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9a0000, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x840000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x790000, 564, 568, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x730000, 568, 572, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x760000, 572, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x790000, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7c0000, 580, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x830000, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x950000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae0000, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc50000, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc60000, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xad0000, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x830000, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c0000, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 628, 632, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 632, 656, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 656, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400014, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4f0000, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x620000, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x730000, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa50014, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb90000, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb00000, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x730000, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5d0000, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x510000, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b0019, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 704, 708, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 708, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f0000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x99161c, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc60000, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd0000, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd50000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcb0000, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc10000, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa90000, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8d0000, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x810000, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7c0000, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x770000, 780, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x780000, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x790000, 792, 796, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x770000, 796, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x790000, 800, 808, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7a0000, 808, 816, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x780000, 816, 820, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x730015, 820, 824, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6d1416, 824, 828, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x661615, 828, 832, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x570000, 832, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a0000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x690000, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa60000, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc70000, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf0000, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc60000, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc20000, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc40000, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa01415, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x310000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x250000, 876, 880, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f0000, 880, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x63001d, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x750014, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8a0000, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0019, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc60000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd20000, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd40000, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc0000, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc40000, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf0000, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x860000, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x660000, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x51191c, 932, 936, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 936, 940, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_54:
					setup_general_paint (0x000000, 0, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x450000, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x560000, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8d0000, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb10000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc30000, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab0000, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa21b17, 116, 120, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9a1818, 120, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9a1516, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa31514, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa40000, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab0000, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb60000, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc20000, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcb0000, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc80000, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb30000, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9c0000, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7d1500, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x450000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x440000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x730000, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0016, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0000, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc00000, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe0000, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb10000, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x95001f, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4f0000, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 208, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x931518, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0000, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc80000, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd0000, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc20000, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaa0000, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7f1819, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3e0000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f0000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5d0000, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9b0019, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbf141c, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbd0000, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbf0000, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc10000, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae1420, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c0000, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x240000, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 312, 316, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 316, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e0000, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4e0000, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x96141e, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0014, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf0000, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0000, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc00000, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab0000, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x861600, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x460000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x420000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7b171f, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10017, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb60000, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc00000, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc80000, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xce0000, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xca0000, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbc0000, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf0000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa60000, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10000, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9f0014, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e1414, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa00000, 432, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e0000, 440, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9d0000, 448, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9a0000, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x950000, 460, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x960015, 464, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8b001b, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7a1922, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 480, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x250000, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2f0000, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4c0000, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8a1817, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0000, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb30000, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa20000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9d0000, 564, 568, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x980000, 568, 572, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9c0000, 572, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa21400, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa31416, 580, 584, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9f0016, 584, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10000, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf0000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0000, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc20000, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0000, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa00000, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6a0000, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 628, 660, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e0000, 660, 664, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x250000, 664, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x530000, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x931719, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa90000, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10000, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x590000, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 700, 704, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 704, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x981d20, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc00000, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd40000, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcf0000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xca0000, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbf0000, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb30000, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa80000, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa50000, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9f0000, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9c0000, 780, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9f0000, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10000, 792, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa20000, 800, 804, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa20014, 804, 808, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10000, 808, 812, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10016, 812, 816, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e0018, 816, 820, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x981618, 820, 824, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8f1919, 824, 828, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x851d1a, 828, 832, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6f1715, 832, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x580000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6a0000, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa40015, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc60000, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xce0000, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc30000, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbc0000, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0000, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9d1819, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2c0000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 876, 880, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 880, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x300000, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x420000, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5a0000, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa20000, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb90000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc60000, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc90000, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc30000, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc10000, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xba0000, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa40000, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8a1619, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x712323, 932, 936, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x240000, 936, 940, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_55:
					setup_general_paint (0x000000, 0, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2f0000, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a0000, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8a1a18, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc00000, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb30000, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0000, 116, 120, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa80000, 120, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0000, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb40000, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb20000, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb40000, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb70000, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbc0000, 144, 148, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc00000, 148, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbb0000, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa90000, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x931800, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x741700, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x710000, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa60018, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb20000, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb60000, 188, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab0000, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x921523, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d0000, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 208, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x260000, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8b161c, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb00017, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xba0000, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe0000, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb80000, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa70000, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x831717, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x490000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x480000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x610000, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x940014, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf0017, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae0000, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xad0000, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb10000, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9f171b, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x570000, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 312, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1f0000, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d0000, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x91181d, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa80016, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab0000, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb60000, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb90000, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa80000, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x851800, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x450000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d0000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x76171b, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x990000, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xad0000, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb90000, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc40000, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcb0000, 400, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc10000, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb60000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb00000, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xad0000, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf0000, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb00000, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb30000, 432, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb00000, 444, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0000, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab0000, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa70000, 460, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa60000, 464, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9a0016, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x84151c, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 480, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x270000, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x801c1c, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaa0019, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbd0017, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb30000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf0000, 564, 568, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae0000, 568, 572, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf0000, 572, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb00000, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb30000, 580, 584, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xad0000, 584, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb80000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbc0000, 596, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb00000, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9b1917, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5b0000, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x330000, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1f0000, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 628, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d0000, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8a1d20, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa00000, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9c1414, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x500000, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 700, 732, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 732, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2c0000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8e2126, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb20015, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc30000, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc50000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc40000, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb90000, 760, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb50000, 768, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb00000, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae0000, 780, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb00000, 784, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb30000, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb60000, 792, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb50000, 800, 804, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb60000, 804, 812, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb30000, 812, 816, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaf0000, 816, 820, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa90000, 820, 824, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10000, 824, 828, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x931800, 828, 832, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x781400, 832, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f0000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c0000, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa00019, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xba0000, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc20000, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb80000, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb60000, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb10000, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x991f1e, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 876, 884, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 884, 888, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x260000, 888, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x420000, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x960000, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb70000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc20000, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc30000, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbd0000, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbc0000, 916, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae0000, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9b001d, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x832428, 932, 936, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 936, 940, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_56:
					setup_general_paint (0x000000, 0, 88, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 88, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x771d1f, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9a0019, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae0016, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa60000, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa20000, 116, 120, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa50000, 120, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab1600, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa70000, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa80000, 132, 136, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa60000, 136, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa70000, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa90000, 144, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa21400, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x931600, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x851f1b, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x691b17, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d0000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x660000, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x93141b, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9d0015, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10000, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa20014, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x98151b, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x811b28, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x490000, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 208, 212, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 212, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x240000, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7c1c20, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e181f, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa60019, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0019, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa90014, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9b1418, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x761818, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x440000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x580000, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x86151b, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e2021, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x951400, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x940000, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x991415, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x891b1c, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x510000, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 308, 312, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 312, 336, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 336, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x420000, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7d1b1c, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x911618, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x980000, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10000, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa40000, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9b1516, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7b1e19, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f0000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x701e22, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8d191c, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e0015, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaa0015, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb50017, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbc0018, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbc0016, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb10000, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa70000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa30000, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa20014, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa50016, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa80016, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab0017, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xad0015, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab0000, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaa0000, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa50000, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10000, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa31400, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10000, 460, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10016, 464, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x96151a, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x80171c, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x420000, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 480, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x732123, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x99001e, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac001c, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa60014, 560, 568, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa50000, 568, 572, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa60000, 572, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa80000, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0016, 580, 584, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa30015, 584, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa00000, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa90015, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa90000, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa40000, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9b1400, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x851e19, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x480000, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x280000, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 624, 668, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 668, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x752023, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8a1619, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x881817, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1f0000, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 696, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x280000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7a2427, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x960019, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa90000, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xab0000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae0000, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa30000, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa60018, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0014, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0000, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa80000, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa70000, 780, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa90000, 784, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaa0000, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xac0000, 792, 804, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaa0000, 804, 812, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa90000, 812, 816, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa60000, 816, 820, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa20000, 820, 824, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9a1400, 824, 828, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8d1a17, 828, 832, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x771c1b, 832, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x580000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c0000, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8c001c, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa71518, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb21617, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa30000, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e0000, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa01415, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x892122, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 876, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2c0000, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8b1919, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa61417, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa80015, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa30000, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa10000, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa30000, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa80000, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa20016, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8a0016, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x761b22, 932, 936, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 936, 940, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_57:
					setup_general_paint (0x000000, 0, 92, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 92, 96, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x220000, 96, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b0018, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x660000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x760000, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e0000, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b0000, 116, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x670000, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b0000, 128, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6d0000, 144, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x680000, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5e0000, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x580000, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x440000, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x260000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x250000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x420000, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f0000, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x620000, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x630000, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x670000, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f0000, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x520018, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2e0000, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 208, 236, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 236, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x510000, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x650000, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x660000, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6a0000, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x680000, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x640000, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d0000, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2f0000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x530000, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x620000, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c0000, 288, 292, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5b0000, 292, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x620000, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x580000, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x320000, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 308, 340, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x250000, 340, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d0000, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5a0000, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5d0000, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x620000, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x670000, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x650000, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x520000, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x250000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4e1619, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5a0000, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x630000, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b0000, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x730000, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x770000, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x760000, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c0000, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x650000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6a0000, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b0000, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e0000, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x700000, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x710000, 432, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x700000, 440, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c0000, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b0000, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c0000, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e0000, 460, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x700000, 464, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b0000, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5a0000, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2c0000, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 480, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4f1718, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x670014, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x740000, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e0000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c0000, 564, 568, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6a0000, 568, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x700000, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x740000, 580, 584, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c0000, 584, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x690000, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6f0000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e0000, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c0000, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x670000, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x551400, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 620, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b1817, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5b0000, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x570000, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x270000, 688, 692, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 692, 736, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 736, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d1518, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x610000, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x700000, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c0000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x700000, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6a0000, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6d0000, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x710000, 768, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e0000, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6d0000, 780, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e0000, 784, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x700000, 788, 792, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x710000, 792, 796, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x700000, 796, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e0000, 800, 820, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b0000, 820, 824, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x670000, 824, 828, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x600000, 828, 832, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x480000, 832, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 836, 840, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3e0000, 840, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f0014, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6c0000, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6f0000, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x680000, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b0000, 860, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c0000, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 876, 892, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1f0000, 892, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5a0000, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6d0000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6a0000, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x640000, 908, 912, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x660000, 912, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6b0000, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x730000, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x710000, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x640000, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x540018, 932, 936, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e0000, 936, 940, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_58:
					setup_general_paint (0x000000, 0, 100, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 100, 104, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x330000, 104, 108, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3e0000, 108, 112, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 112, 116, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 116, 124, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x340000, 124, 128, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x330000, 128, 132, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x340000, 132, 140, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 140, 144, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 144, 152, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 152, 156, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 156, 160, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2d0000, 160, 164, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x260000, 164, 168, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 168, 172, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 172, 176, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x280000, 176, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x310000, 184, 188, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2e0000, 188, 192, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x330000, 192, 196, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2e0000, 196, 200, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2c0000, 200, 204, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 204, 208, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 208, 240, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2e0000, 240, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 244, 248, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 248, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 252, 256, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 256, 260, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 260, 264, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x280000, 264, 268, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 268, 272, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 272, 276, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1c0000, 276, 280, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2e0000, 280, 284, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 284, 288, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2d0000, 288, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x310000, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x200000, 304, 308, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 308, 344, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x220000, 344, 348, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 348, 352, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x310000, 352, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 356, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x340000, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2e0000, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 372, 376, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 376, 380, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2a0000, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x300000, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x340000, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3e0000, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 400, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 440, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 448, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 460, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3e0000, 464, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d0000, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x330000, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 480, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 544, 548, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2d0000, 548, 552, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 552, 556, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d0000, 556, 560, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 560, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 564, 568, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 568, 572, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 572, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 580, 584, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 584, 588, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x340000, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 592, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x270000, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 612, 672, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 672, 676, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x260000, 676, 680, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2c0000, 680, 684, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 684, 688, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 688, 740, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 740, 744, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x340000, 744, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3d0000, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 752, 756, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 756, 760, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 760, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3b0000, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 768, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 776, 780, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 780, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 788, 796, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 796, 800, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 800, 804, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x320000, 804, 808, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x340000, 808, 816, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 816, 820, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 820, 824, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x360000, 824, 828, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x310000, 828, 832, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 832, 836, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1f0000, 836, 844, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x300000, 844, 848, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c0000, 848, 852, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3e0000, 852, 856, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 856, 860, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x330000, 860, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 872, 876, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 876, 896, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2b0000, 896, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 904, 908, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x370000, 908, 916, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 916, 920, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3f0000, 920, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x410000, 924, 928, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3a0000, 928, 932, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2c0000, 932, 936, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_59:
					setup_general_paint (0x000000, 0, 180, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 180, 184, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 184, 244, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 244, 252, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 252, 296, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 296, 300, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 300, 304, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 304, 356, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 356, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 364, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1a0000, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 416, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 428, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 440, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 456, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 464, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 472, 568, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 568, 572, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 572, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 580, 584, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 584, 596, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 596, 600, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 600, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 604, 748, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 748, 752, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 752, 764, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 764, 768, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 768, 772, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 772, 776, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 776, 784, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 784, 788, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 788, 820, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 820, 824, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 824, 832, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 832, 864, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 864, 868, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 868, 872, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 872, 900, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 900, 904, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 904, 924, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x160000, 924, 928, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_77:
					setup_general_paint (0x000000, 0, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x494900, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb9b900, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbaba00, 440, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5c5c37, 448, 452, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_78:
					setup_general_paint (0x000000, 0, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x535300, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb8b800, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x939300, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5d5d00, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8f8f16, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd8d854, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd1d15c, 452, 456, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_79:
					setup_general_paint (0x000000, 0, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb9b900, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x979700, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x40403a, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4c4c46, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaaa900, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe1e0a6, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x717131, 456, 460, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_80:
					setup_general_paint (0x000000, 0, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5f5f00, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb9b900, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x494900, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 436, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5e5e00, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbaba00, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x787854, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 460, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 476, 480, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_81:
					setup_general_paint (0x000000, 0, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5e5f00, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb9b900, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2f2f00, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 436, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x595b1b, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb8b800, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x74745d, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 460, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 472, 476, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_82:
					setup_general_paint (0x000000, 0, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5e5f00, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbaba00, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x484800, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 436, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x5b5c00, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb8b800, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x6e6e57, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 460, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 476, 480, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_83:
					setup_general_paint (0x000000, 0, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb8b800, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xafaf00, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x343416, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x333400, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa5a500, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb9b900, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x414224, 456, 460, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_84:
					setup_general_paint (0x000000, 0, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x494900, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb2b200, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb5b500, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x909000, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x939300, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb9b900, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x777700, 452, 456, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_85:
					setup_general_paint (0x000000, 0, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb6b600, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb9b900, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb3b300, 444, 448, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_103:
					setup_general_paint (0x000000, 0, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8b898a, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 480, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8a8a8a, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf4f4f4, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 612, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 620, 628, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_104:
					setup_general_paint (0x000000, 0, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfaf8fb, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 480, 604, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfafafa, 604, 608, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbfbfb, 608, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 612, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc6c6c6, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe5e5e5, 624, 628, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_105:
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
					setup_general_paint (0xcbc7c8, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb5b3b4, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc6c6c6, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xafafaf, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcacaca, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb4b4b4, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc6c6c6, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 416, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x235937, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d9668, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b9b66, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x499a62, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x52a066, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x509461, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2e653e, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 460, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8e8d93, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfefbff, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb3b0b7, 480, 484, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8f8d92, 484, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdcdadb, 492, 496, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaeb0af, 496, 500, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd4d8d7, 500, 504, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa7a9a8, 504, 508, LOOP_GAME_OVER_COLUMN)
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
			GAME_OVER_ROW_106:
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
					setup_general_paint (0x7f7b7c, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa6aaab, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x7d7b7e, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa9a9ab, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 416, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001900, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x45a067, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x3c9f5e, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x002600, 444, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x439d5d, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4d9565, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 460, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfffdff, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 480, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdedadb, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa5a4a2, 492, 496, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 496, 504, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfeffff, 504, 508, LOOP_GAME_OVER_COLUMN)
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
			GAME_OVER_ROW_107:
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
					setup_general_paint (0xffffff, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdcdddf, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 392, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa9a7aa, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfffcff, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe2e0e5, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 412, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001800, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x499566, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4c9663, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001e00, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x002100, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x479a62, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x50976b, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001400, 460, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 464, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfffdff, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 480, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfffef9, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 492, 504, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbfbfb, 504, 508, LOOP_GAME_OVER_COLUMN)
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
					setup_general_paint (0xfefefe, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 580, 584, LOOP_GAME_OVER_COLUMN)
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
			GAME_OVER_ROW_108:
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
					setup_general_paint (0xe2e4e3, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcffff, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 396, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe3e2e7, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfeffff, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 416, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001400, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b9266, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x569b6c, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001d00, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x002000, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x479860, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4e9366, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001400, 460, 464, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 464, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfffcfc, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 480, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfffef9, 488, 492, LOOP_GAME_OVER_COLUMN)
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
			GAME_OVER_ROW_109:
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
					setup_general_paint (0xa9a9a7, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 384, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfefffb, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa3a9a7, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 404, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfefdff, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 416, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001500, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4a9868, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x489d66, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x002300, 444, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b9f61, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x549666, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 460, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfffbff, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 480, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdcdedd, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaeb0af, 492, 496, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 496, 504, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfffbff, 504, 508, LOOP_GAME_OVER_COLUMN)
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
			GAME_OVER_ROW_110:
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
					setup_general_paint (0xf0efed, 380, 384, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xccc9c4, 384, 388, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb5b2ad, 388, 392, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdadbd6, 392, 396, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 396, 400, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xebf1ef, 400, 404, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc3c9c9, 404, 408, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb2b3b7, 408, 412, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd8d7dc, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 416, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001900, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x479a64, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x439e61, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x45a162, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b9a60, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4b8e5b, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x33633b, 456, 460, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 460, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xccc7cb, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe4e3e8, 480, 484, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xabafb0, 484, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd6dad9, 492, 496, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb5b6b8, 496, 500, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdadada, 500, 504, LOOP_GAME_OVER_COLUMN)
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
					setup_general_paint (0xffffff, 588, 592, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfefefe, 592, 596, LOOP_GAME_OVER_COLUMN)
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
					setup_general_paint (0xefefef, 692, 696, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdfdfd, 696, 700, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb6b6b6, 700, 704, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_111:
					setup_general_paint (0x000000, 0, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdfdfd, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 328, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001b00, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x43995c, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x419c57, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001e00, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x001600, 448, 452, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_112:
					setup_general_paint (0x000000, 0, 320, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8c8c8c, 320, 324, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 324, 328, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa5a5a5, 328, 332, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 332, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1e522c, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x4e9261, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x569b65, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x2f643a, 444, 448, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_125:
					setup_general_paint (0x000000, 0, 512, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8c8e8b, 512, 516, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 516, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfdfdfd, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8b8b8b, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xededed, 628, 632, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_126:
					setup_general_paint (0x000000, 0, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x140000, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x170000, 480, 484, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 484, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1f0000, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 492, 496, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 496, 512, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf9fbf8, 512, 516, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 516, 612, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc9c9c9, 612, 616, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xe0e0e0, 616, 620, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 620, 624, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xf7f7f7, 624, 628, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 628, 632, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_127:
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
					setup_general_paint (0xb7b7b7, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc6c6c6, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb3b3b3, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc7c7c7, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb2b2b2, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc7c7c5, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 456, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa03638, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa73841, 480, 484, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae323d, 484, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc23339, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xae3b3e, 492, 496, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1d0000, 496, 500, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 500, 508, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x87908f, 508, 512, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfcfefd, 512, 516, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb2b2b2, 516, 520, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8b8b8b, 520, 524, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 524, 528, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd9d9d9, 528, 532, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb1b1b1, 532, 536, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd8d8d8, 536, 540, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa9a9a9, 540, 544, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 544, 564, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfbfbfb, 564, 568, LOOP_GAME_OVER_COLUMN)
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
			GAME_OVER_ROW_128:
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
					setup_general_paint (0xa9abaa, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 456, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x180000, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa12d2e, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbf2d30, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9f2027, 480, 484, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x610000, 484, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xda2328, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc62b2f, 492, 496, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x260000, 496, 500, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 500, 512, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfeffff, 512, 516, LOOP_GAME_OVER_COLUMN)
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
			GAME_OVER_ROW_129:
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
					setup_general_paint (0xe1e2e6, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 452, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x260000, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe2c37, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc72c34, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 480, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc272b, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcd3238, 492, 496, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x260000, 496, 500, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 500, 512, LOOP_GAME_OVER_COLUMN)
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
			GAME_OVER_ROW_130:
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
					setup_general_paint (0xdfe0e2, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 456, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc2303d, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc72c34, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x380000, 480, 484, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x390000, 484, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd22d31, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc4292f, 492, 496, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 496, 500, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 500, 512, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfffeff, 512, 516, LOOP_GAME_OVER_COLUMN)
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
			GAME_OVER_ROW_131:
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
					setup_general_paint (0xffffff, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 456, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x1b0000, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x9e272b, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc53034, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa22028, 480, 484, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x620000, 484, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdd2628, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc2292b, 492, 496, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x240000, 496, 500, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 500, 512, LOOP_GAME_OVER_COLUMN)
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
			GAME_OVER_ROW_132:
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
					setup_general_paint (0xcacaca, 412, 416, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa9a9a9, 416, 420, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xededed, 420, 424, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc8c8c8, 424, 428, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb0b0b0, 428, 432, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd9d9d9, 432, 436, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 436, 440, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xefefef, 440, 444, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc5c7c6, 444, 448, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaeb3af, 448, 452, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd7d9d6, 452, 456, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 456, 468, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x150000, 468, 472, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x350000, 472, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa33939, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xaa353d, 480, 484, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xbe2e37, 484, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xdb2227, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xc92d30, 492, 496, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x290000, 496, 500, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 500, 512, LOOP_GAME_OVER_COLUMN)
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
			GAME_OVER_ROW_133:
					setup_general_paint (0x000000, 0, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 368, 476, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x190000, 476, 480, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x210000, 480, 484, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x400000, 484, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xd42932, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xcc2630, 492, 496, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x340000, 496, 500, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 500, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfefefe, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 580, 584, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_134:
					setup_general_paint (0x000000, 0, 360, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8c8c8c, 360, 364, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 364, 368, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa5a5a5, 368, 372, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 372, 484, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x542024, 484, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb4353e, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xb8363e, 492, 496, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x63282c, 496, 500, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x000000, 500, 572, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x8e8e8e, 572, 576, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xffffff, 576, 580, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xfefefe, 580, 584, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0xa5a5a5, 584, 588, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW
			GAME_OVER_ROW_135:
					setup_general_paint (0x000000, 0, 488, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x240000, 488, 492, LOOP_GAME_OVER_COLUMN)
					setup_general_paint (0x230000, 492, 496, LOOP_GAME_OVER_COLUMN)
					j UPDATE_GAME_OVER_ROW

    	UPDATE_GAME_OVER_ROW:				# Update row value
    	    	addi $s2, $s2, row_increment
	        	j LOOP_GAME_OVER_ROW

    	# FOR LOOP: (through column)
    	# Paints in column from $s3 to $s4 at some row
    	LOOP_GAME_OVER_COLUMN: bge $s3, $s4, EXIT_LOOP_GAME_OVER_COLUMN	# branch to UPDATE_GAME_OVER_COL; if column index >= last column index to paint
        		addi $s1, $0, display_base_address			# Reinitialize t2; temporary address store
        		add $s1, $s1, $s2				# update to specific row from base address
        		add $s1, $s1, $s3				# update to specific column
        		addi $s1, $s1, 51200				# add specified offset
                		sw $s0, ($s1)					# paint in value

        		# Updates for loop index
        		addi $s3, $s3, column_increment			# s3 += row_increment
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



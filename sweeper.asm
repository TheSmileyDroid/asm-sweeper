%include "print.mac"
%include "syscall.mac"

%define MAIN _start


%define MOVE_EVERY_TICK   1
%define SIZE_X            21
%define SIZE_Y            21
%define UPD_DEL_SEC       0
%define UPD_DEL_NANO      50000000
%define HEART_COUNT       30

%assign SIZE_N SIZE_X*SIZE_Y
%assign PLAYER_X_INIT SIZE_X/2
%assign PLAYER_Y_INIT SIZE_Y/2

%define DIR_NONE  0
%define DIR_UP    1
%define DIR_RIGHT 2
%define DIR_DOWN  3
%define DIR_LEFT  4

%define MAP_FREE  0
%define MAP_PLAYER 1
%define MAP_WALL_0 2
%define MAP_WALL_1 3
%define MAP_WALL_2 4
%define MAP_WALL_3 5
%define MAP_WALL_4 6
%define MAP_WALL_5 7
%define MAP_WALL_6 8
%define MAP_WALL_7 9
%define MAP_WALL_8 10
%define MAP_HEART 11
%define MAP_EMPTY_HEART 12

%define FOG_VISIBLE 0
%define FOG_HIDDEN  1

%define STATUS_RUN  0
%define STATUS_EXIT 1
%define STATUS_DIE  2
%define STATUS_WIN  3

%define CELL_TEXT '  '
%strlen CELL_TEXT_LEN CELL_TEXT

%macro DEF_ESC_SEQ 3+
	DEF_STR_DATA %1, 27, '[', %3, %2
%endmacro

%macro DEF_COLOR_SEQ 3
	DEF_ESC_SEQ color_%1_seq, 'm', '1', ';', %2, ';', %3
%endmacro

%macro MAP_BUFFER 1
	%1:
		%rep SIZE_Y ; cells between top and bottom walls
			times SIZE_X db MAP_FREE ; free space
		%endrep
%endmacro

%macro FOG_BUFFER 1
	%1:
		%rep SIZE_Y 
			times SIZE_X db FOG_HIDDEN 
		%endrep
%endmacro

%define ESC_SEQ_MAX_LEN 10

%assign MAX_CELL_PRINT_SIZE ESC_SEQ_MAX_LEN*2+CELL_TEXT_LEN

%macro PRINT_BUFFER 1
	%1 resb SIZE_N*MAX_CELL_PRINT_SIZE
%endmacro

%macro NUMBER_CELL 1
	%define quot "
	%define stringify(x) quot %+ x %+ quot
	%strcat myString stringify(%1), " "
	DEF_STR_DATA cell_%1, myString
%endmacro

section .data

%assign SCREEN_Y SIZE_Y+1
%defstr SCREEN_Y_STR SCREEN_Y

; ANSI escape seqences
DEF_ESC_SEQ cur_reset_seq, 'A', SCREEN_Y_STR
DEF_ESC_SEQ cur_home_seq, 'H', '0', ';', '0'
DEF_ESC_SEQ cur_hide_seq, 'l', '?', '25'
DEF_ESC_SEQ cur_show_seq, 'h', '?', '25'
DEF_ESC_SEQ clear_seq, 'J', '0'
DEF_ESC_SEQ color_reset_seq, 'm', '0'
DEF_COLOR_SEQ bright_red, '91', '101'
DEF_COLOR_SEQ red, '31', '41'
DEF_COLOR_SEQ black, '30', '40'
DEF_COLOR_SEQ blue, '34', '44'
DEF_COLOR_SEQ yellow, '33', '43'
DEF_COLOR_SEQ bright_yellow, '93', '103'
DEF_COLOR_SEQ bright_green, '92', '102'
DEF_COLOR_SEQ gray, '37', '47'
DEF_COLOR_SEQ blue_one, '94', '104'


; Strings
DEF_STR_DATA text_score, "Score: "
DEF_STR_DATA text_score_end, "  "
DEF_STR_DATA text_controls, "Move: wasd  Quit: q", 10
DEF_STR_DATA text_game_over, "GAME OVER!", 10
DEF_STR_DATA text_win, "Você ganhou!", 10
DEF_STR_DATA cell_sym, CELL_TEXT
DEF_STR_DATA text_heart, "♥ "
DEF_STR_DATA text_heart_counter, "Hearts: "
DEF_STR_DATA text_heart_counter_end, " / "
DEF_STR_DATA text_last_cell, "Last cell: "
NUMBER_CELL 1
NUMBER_CELL 2
NUMBER_CELL 3
NUMBER_CELL 4
NUMBER_CELL 5
NUMBER_CELL 6
NUMBER_CELL 7
NUMBER_CELL 8

; Some global vars
status db STATUS_RUN

MAP_BUFFER map
FOG_BUFFER fog

score dq 0
heart_counter dq 0
player_x dq PLAYER_X_INIT
player_y dq PLAYER_Y_INIT

input db 0
frame dq 0

move_dir db 0
last_cell db 0

section .bss

; buf to store free map cells for get_free_cells
map_free_buf resq SIZE_N
map_free_buf_len resq 1

PRINT_BUFFER print_buf
print_buf_len resq 1


section .text

global MAIN

extern memcpy
extern rand
extern set_noncanon
extern set_canon

; rax: x
; rdx: y
; returns: map index
get_map_index:
	imul rdx, SIZE_X
	add rax, rdx
	ret

%macro HANDLE_KEY 2
	cmp byte [input], %2
	je .%1
%endmacro

handle_key:
	HANDLE_KEY quit,  'q'
	HANDLE_KEY right, 'd'
	HANDLE_KEY down,  's'
	HANDLE_KEY left,  'a'
	HANDLE_KEY up,    'w'

    mov byte [move_dir], DIR_NONE

	jmp .exit

	.quit:
		mov byte [status], STATUS_EXIT
		jmp .exit

	.right:
		mov byte [move_dir], DIR_RIGHT
		jmp .exit

	.down:
		mov byte [move_dir], DIR_DOWN
		jmp .exit

	.left:
		mov byte [move_dir], DIR_LEFT
		jmp .exit

	.up:
		mov byte [move_dir], DIR_UP
		jmp .exit

	.exit:
        call move_player
		ret

%macro PRINT_BUF_APPEND 1
	mov rax, print_buf
	add rax, [print_buf_len]
	mov rdx, %1
	mov rcx, %1_len
	add [print_buf_len], rcx
	call memcpy
%endmacro

%macro DRAW_CELL 0
	PRINT_BUF_APPEND cell_sym
%endmacro

%macro DRAW_COLOR_CELL 1
	PRINT_BUF_APPEND color_%1_seq
	DRAW_CELL
	PRINT_BUF_APPEND color_reset_seq
%endmacro

%macro DRAW_COLOR_NUMBER 1
	PRINT_BUF_APPEND color_blue_seq
	PRINT_BUF_APPEND cell_%1
	PRINT_BUF_APPEND color_reset_seq
%endmacro

%macro DRAW_COLOR_CELL_HEART 1
	PRINT_BUF_APPEND color_%1_seq
	PRINT_BUF_APPEND text_heart
	PRINT_BUF_APPEND color_reset_seq
%endmacro

print_term_buf:
	mov rax, print_buf
	mov rdx, [print_buf_len]
	call print
	mov qword [print_buf_len], 0
	ret

; rax: cell
draw_cell:
	cmp rax, MAP_WALL_0
	je .wall

    cmp rax, MAP_WALL_1
    je .wall_1

    cmp rax, MAP_WALL_2
    je .wall_2

    cmp rax, MAP_WALL_3
    je .wall_3

    cmp rax, MAP_WALL_4
    je .wall_4

	cmp rax, MAP_WALL_5
	je .wall_5

	cmp rax, MAP_WALL_6
	je .wall_6

	cmp rax, MAP_WALL_7
	je .wall_7

	cmp rax, MAP_WALL_8
	je .wall_8

	cmp rax, MAP_PLAYER
    je .player

	cmp rax, MAP_HEART
    je .heart

	cmp rax, MAP_EMPTY_HEART
	je .empty_heart

	jmp .free

	.free:
		DRAW_CELL
		jmp .exit

	.wall:
		DRAW_COLOR_CELL blue
		jmp .exit
	
	.wall_1:
		DRAW_COLOR_NUMBER 1
		jmp .exit
	
	.wall_2:
		DRAW_COLOR_NUMBER 2
		jmp .exit

	.wall_3:
		DRAW_COLOR_NUMBER 3
		jmp .exit

	.wall_4:
		DRAW_COLOR_NUMBER 4
		jmp .exit

	.wall_5:
		DRAW_COLOR_NUMBER 5
		jmp .exit
	
	.wall_6:
		DRAW_COLOR_NUMBER 6
		jmp .exit

	.wall_7:
		DRAW_COLOR_NUMBER 7
		jmp .exit

	.wall_8:
		DRAW_COLOR_NUMBER 8
		jmp .exit

	.player:
		DRAW_COLOR_CELL yellow
		jmp .exit

	.heart:
		DRAW_COLOR_CELL_HEART red
		jmp .exit
	
	.empty_heart:
		DRAW_COLOR_CELL_HEART gray
		jmp .exit

	.exit:
		ret

draw_map:
	push rbx
	push r11

	mov bh, 0  ; x counter
	mov bl, 0  ; y counter
	mov r11, 0 ; map cell

	.loop_y:
		.loop_x:
			mov rax, 0
			mov al, [fog+r11]
			cmp al, FOG_VISIBLE
			jne .skip

			mov rax, 0
			mov al, [map+r11]
			call draw_cell

			jmp .continue

			.skip:
				DRAW_COLOR_CELL gray

			.continue:

			inc r11

			inc bh
			cmp bh, SIZE_X
			jne .loop_x

		PRINT_BUF_APPEND newline

		mov bh, 0

		inc bl
		cmp bl, SIZE_Y
		jne .loop_y

	PRINT_BUF_APPEND text_score

	call print_term_buf

	mov rax, [score]
	call print_num

	PRINT_BUF_APPEND text_score_end

	call print_term_buf

	PRINT_BUF_APPEND text_heart_counter

	call print_term_buf

	mov rax, [heart_counter]
	call print_num

	PRINT_BUF_APPEND text_heart_counter_end

	call print_term_buf

	mov rax, HEART_COUNT
	call print_num

	PRINT_BUF_APPEND text_score_end

	call print_term_buf

	PRINT_NEW_LINE

	pop r11
	pop rbx
	ret

clear_screen:
	PRINT_BUF_APPEND cur_reset_seq
	ret

%macro SHOW_CELL 1
	; Check if cell is in bounds
	cmp rax, 0
	jl .exit_%1
	cmp rax, SIZE_N
	jge .exit_%1
	
	; Set cell to visible
	mov byte [fog+rax], FOG_VISIBLE

	.exit_%1:
%endmacro

show_surroundings:
	; Set cells with 1 distance to visible and don't hide the others
	mov rax, [player_x]
	mov rdx, [player_y]
	call get_map_index

	SHOW_CELL 0

	dec rax
	SHOW_CELL 1

	inc rax
	inc rax
	SHOW_CELL 2

	mov rax, [player_x]
	mov rdx, [player_y]
	add rdx, 1
	call get_map_index

	SHOW_CELL 3

	dec rax
	SHOW_CELL 4

	inc rax
	inc rax
	SHOW_CELL 5

	mov rax, [player_x]
	mov rdx, [player_y]
	sub rdx, 1
	call get_map_index

	SHOW_CELL 6

	dec rax
	SHOW_CELL 7

	inc rax
	inc rax
	SHOW_CELL 8

	ret

move_player:
    mov rax, [player_x]
    mov rdx, [player_y]
    call get_map_index
    ; if the last cell was a heart or empty heart, add a empty heart to the map
	mov byte rax, [last_cell]
	cmp rax, MAP_HEART
	je .add_empty_heart

	cmp rax, MAP_EMPTY_HEART
	je .add_empty_heart

	jmp .add_free

	.add_empty_heart:
		mov rax, [player_x]
		mov rdx, [player_y]
		call get_map_index
		mov byte [map+rax], MAP_EMPTY_HEART
		jmp .finish_last_cell

	.add_free:
		mov rax, [player_x]
		mov rdx, [player_y]
		call get_map_index
		mov byte [map+rax], MAP_FREE

	.finish_last_cell:

	; get the direction

	mov al, [move_dir]

	cmp al, DIR_RIGHT
	je .right

	cmp al, DIR_DOWN
	je .down

	cmp al, DIR_LEFT
	je .left

	cmp al, DIR_UP
	je .up

    cmp al, DIR_NONE
    je .exit

	.right:
		inc qword [player_x]
		jmp .exit

	.down:
		inc qword [player_y]
		jmp .exit

	.left:
		dec qword [player_x]
		jmp .exit

	.up:
		dec qword [player_y]
		jmp .exit

	.exit:
		; check if player is out of map
		cmp qword [player_x], SIZE_X
		jge .left

		cmp qword [player_y], SIZE_Y
		jge .up

		cmp qword [player_x], 0
		jl .right

		cmp qword [player_y], 0
		jl .down

		; make surrounding cells visible
		mov rax, [player_x]
		mov rdx, [player_y]
		call show_surroundings

		; check new player position for collisions
        mov rax, [player_x]
		mov rdx, [player_y]
		call get_map_index
		call check_cell

		; save cell type
		mov al, [move_dir]
		cmp al, DIR_NONE
		je .continue

		mov rax, [player_x]
		mov rdx, [player_y]
		call get_map_index

		cmp byte [map+rax], MAP_HEART
		je .heart

		cmp byte [map+rax], MAP_EMPTY_HEART
		je .heart

		mov byte [last_cell], MAP_FREE
		jmp .continue

		.heart:
			mov byte [last_cell], MAP_EMPTY_HEART
		
		.continue:

		; set new player position
		mov rax, [player_x]
		mov rdx, [player_y]
		call get_map_index
		mov byte [map+rax], MAP_PLAYER
		
		ret

check_cell:
	cmp byte [map+rax], MAP_FREE
	je .free

	cmp byte [map+rax], MAP_HEART
	je .heart

	cmp byte [map+rax], MAP_WALL_0
	je .wall

	cmp byte [map+rax], MAP_WALL_1
	je .wall

	cmp byte [map+rax], MAP_WALL_2
	je .wall

	cmp byte [map+rax], MAP_WALL_3
	je .wall

	cmp byte [map+rax], MAP_WALL_4
	je .wall

	cmp byte [map+rax], MAP_WALL_5
	je .wall

	cmp byte [map+rax], MAP_WALL_6
	je .wall

	cmp byte [map+rax], MAP_WALL_7
	je .wall

	cmp byte [map+rax], MAP_WALL_8
	je .wall

	jmp .exit

	.free:
		jmp .exit

	.heart:
		add qword [score], 5
		inc qword [heart_counter]

		; if heart_counter is equal to HEART_COUNT then end the game
		cmp qword [heart_counter], HEART_COUNT
		je .success

		jmp .exit

	.wall:
		; If the score is less than 1, then Game Over
		cmp qword [score], 1
		jl .game_over
		; If not, then decrease the score by 1
		dec qword [score]
		jmp .exit

	.game_over:
		mov byte [status], STATUS_DIE
		jmp .exit

	.success:
		mov byte [status], STATUS_WIN
		jmp .exit

	.exit:
		ret

update:
	call clear_screen
	call draw_map

	inc qword [frame]

	ret

get_free_cells:
	mov rcx, 0 ; counter
	mov [map_free_buf_len], rcx

	.loop:
		cmp byte [map+rcx], MAP_FREE
		jne .loop_inc

		mov rax, [map_free_buf_len]
		mov [map_free_buf+rax*8], rcx
		inc qword [map_free_buf_len]

	.loop_inc:
		inc rcx
		cmp rcx, SIZE_N
		jne .loop

	ret

place_hearts:
	call get_free_cells

	mov rax, [map_free_buf_len]

	cmp rax, 0
	je .exit

	call rand

	mov rdx, [map_free_buf+rax*8]

	mov byte [map+rdx], MAP_HEART

	.exit:
		ret

%macro THERE_IS_HEART 1
	mov rax, r11
	mov rdx, r12
	call get_map_index

	mov rax, [map+rax]

	cmp al, MAP_HEART
	je .there_is_%1
	jmp .there_is_not_%1

	.there_is_%1:
		mov rax, 1
		jmp .continue_%1

	.there_is_not_%1:
		mov rax, 0
		jmp .continue_%1
		
	.continue_%1:
%endmacro

; r11 - x
; r12 - y
; return - rcx: number of hearts around the cell in 1 distance from it
get_hearts_around: 
	mov rcx, 0 ; counter

	; up
	dec r12
	THERE_IS_HEART 1
	add rcx, rax

	; down
	inc r12
	inc r12
	THERE_IS_HEART 2
	add rcx, rax

	; left
	dec r12
	dec r11
	THERE_IS_HEART 3
	add rcx, rax

	; right
	inc r11
	inc r11
	THERE_IS_HEART 4
	add rcx, rax

	; up-right
	dec r12
	THERE_IS_HEART 6
	add rcx, rax

	; up-left
	dec r11
	dec r11
	THERE_IS_HEART 5
	add rcx, rax

	

	; down-left
	inc r12
	inc r12
	THERE_IS_HEART 7
	add rcx, rax

	; down-right
	inc r11
	inc r11
	THERE_IS_HEART 8
	add rcx, rax

	ret

%macro IS_FREE 1
	mov rbx, [map+rax]

	cmp bl, MAP_FREE
	jne .skip_%1
%endmacro

%macro GET_WALL 1
	cmp rcx, %1
	jne .skip_%1
	
	mov rax, r13
	mov rdx, r14
	call get_map_index
	IS_FREE %1

	mov byte [map+rax], MAP_WALL_%1
	jmp .loop_x_inc

	.skip_%1:
%endmacro

place_walls: ; Place wall in every cell with the number of hearts around
	mov r13, 0 ; x
	mov r14, 0 ; y

	mov r15, SIZE_X

	.loop_y:
		mov r13, 0
		.loop_x:
			mov r11, r13
			mov r12, r14
			call get_hearts_around

			GET_WALL 0
			GET_WALL 1
			GET_WALL 2
			GET_WALL 3
			GET_WALL 4
			GET_WALL 5
			GET_WALL 6
			GET_WALL 7
			GET_WALL 8

			.loop_x_inc:
				inc r13
				cmp r13, r15
				jl .loop_x

		.loop_y_inc:
			inc r14
			cmp r14, r15
			jl .loop_y
		
	ret

run:
	push rbx

	; update count
	mov rbx, 0

	.loop:
		mov rax, input
		mov rdx, 1
		call poll

		call handle_key

		cmp byte [status], STATUS_WIN
		je .win

		cmp byte [status], STATUS_EXIT
		je .exit

		cmp byte [status], STATUS_DIE
		je .die

		cmp rbx, MOVE_EVERY_TICK
		je .update

		inc rbx

		mov rax, UPD_DEL_SEC
		mov rdx, UPD_DEL_NANO
		call sleep

		jmp .loop

	.update:
		call update
		mov rbx, 0
		jmp .loop

	.die:
		PRINT_STR_DATA text_game_over

	.exit:
		pop rbx
		ret
	
	.win:
		PRINT_STR_DATA text_win

		pop rbx
		ret

init:
	mov rax, [player_x]
	mov rdx, [player_y]
	call get_map_index ;player pos in rax

	; add player to map
	mov byte [map+rax], MAP_PLAYER


	; init map hearts
	mov rbx, 0
	.heart_loop:
		call place_hearts
		inc rbx
		cmp rbx, HEART_COUNT
		jne .heart_loop


	; place walls on every free cell
	call place_walls

	; set starting score
	mov rax, 10
	mov [score], rax


	; init print buffer
	mov qword [print_buf_len], 0

	call set_noncanon

	PRINT_BUF_APPEND cur_home_seq
	PRINT_BUF_APPEND clear_seq
	PRINT_BUF_APPEND text_controls
	PRINT_BUF_APPEND cur_hide_seq

	ret

shutdown:
	PRINT_STR_DATA cur_show_seq
	call set_canon
	ret

MAIN:
	call init

	call draw_map

	call run

	call shutdown

	mov rax, 0
	call exit

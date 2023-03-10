%include "print_int.mac"
%include "syscall.mac"

section .data

DEF_STR_DATA newline, 10

section .bss

print_num_buf resb 8
print_num_buf_end equ $

section .text

global print
global print_num

global newline
global newline_len 

; rax: pointer to string
; rdx: string length
print:
	mov rcx, STDOUT
	call write
	ret

; rax: number
print_num:
	push rbx
	push rsi

	mov rbx, 10 ; for idiv
	mov rcx, 0 ; counter for digits

	.loop:
		; divide [rdx:rax] by rbx
		; rdx contains remainder - digit
		mov rdx, 0
		idiv rbx

		; add code of 0 to get ASCII char code
		add dl, '0'

		; save digit in the first free cell in
		; buffer from the end
		inc rcx
		mov rsi, print_num_buf_end
		sub rsi, rcx
		mov [rsi], dl ; save

		cmp rax, 0
		jne .loop

	mov rax, print_num_buf_end
	sub rax, rcx
	mov rdx, rcx
	call print

	pop rsi
	pop rbx
	ret
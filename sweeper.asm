; Assembler: NASM
; Target: 32-bit x86
;
; Compilar: nasm -f elf main.asm
;           ld -m elf_i386 -o main main.o -L/usr/local/lib -lSDL2
;           rm main.o

section .data

section .bss
    janela       resd 1
    renderer     resd 1

section .text
    global _start

_start:
    ; Inicializar a SDL2
    invoke SDL_Init, SDL_INIT_VIDEO

    ; Criar a janela
    invoke SDL_CreateWindow, "Minha Janela", SDL_WINDOWPOS_UNDEFINED, \
                             SDL_WINDOWPOS_UNDEFINED, 640, 480, SDL_WINDOW_SHOWN
    mov [janela], eax

    ; Criar o contexto de renderização para a janela
    invoke SDL_CreateRenderer, [janela], -1, 0
    mov [renderer], eax

    ; Limpar a tela
    invoke SDL_SetRenderDrawColor, [renderer], 0, 0, 0, 255
    invoke SDL_RenderClear, [renderer]

    ; Exibir a tela
    invoke SDL_RenderPresent, [renderer]

    ; Aguardar um tempo para fechar a janela
    invoke SDL_Delay, 5000

    ; Destruir a janela e o contexto de renderização
    invoke SDL_DestroyRenderer, [renderer]
    invoke SDL_DestroyWindow, [janela]

    ; Finalizar a SDL2
    invoke SDL_Quit

    ; Fim da execução
    mov eax, 1
    xor ebx, ebx
    int 0x80



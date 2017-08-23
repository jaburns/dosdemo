BITS 16
ORG 0x100

REFRESH_RATE EQU 60
WAIT_SECS EQU 5

sineTable: INCBIN "sine.dat"

Start:
    ; Init video
        mov ax, 0x13   ; set video mode 13h
        int 0x10
        mov ax, 0xA000 ; point ES to video memory
        mov es, ax

    ; Initialize draw color and frame counter
        mov ah, 0x40
        mov bx, REFRESH_RATE * WAIT_SECS

    .mainLoop:

    ; Draw frame
        inc ah
        and ah, 0x4F
        mov al, ah
        xor di, di
        mov cx, 32000
        rep stosw

    ; Wait for next retrace
        mov dx, 0x03DA
    .waitRetrace:
        in al, dx     ; read from status port
        test al, 0x08 ; bit 3 will be on if we're in retrace
        jnz .waitRetrace
    .endRefresh:
        in al, dx
        test al, 0x08
        jz .endRefresh

    ; End of main loop
        dec bx
        jnz .mainLoop

    ; Restore state and exit
        mov ax, 0x03  ; return to text mode 0x03
        int 0x10
        mov ax, 0x4C00  ; exit with code 0
        int 0x21

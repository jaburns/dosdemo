BITS 16
ORG 0x100

REFRESH_RATE EQU 60
WAIT_SECS EQU 5

Start:
    ; Initialize frame counter and draw color
        mov cx, REFRESH_RATE * WAIT_SECS
        mov bl, 0x40

    ; Init video
        mov ax, 0x13   ; set video mode 13h
        int 0x10
        mov ax, 0xA000 ; point ES to video memory
        mov es, ax

    .mainLoop:
        sub bl, 0x40
        inc bl
        and bl, 0x0F
        add bl, 0x40

    ; Draw frame
        push ax
        push cx
        xor di, di
        mov ah, bl
        mov al, bl
        mov cx, 32000
        rep stosw
        pop cx
        pop ax

    ; Wait for next retrace
        push dx
        mov dx, 0x03DA
    .waitRetrace:
        in al, dx     ; read from status port
        test al, 0x08 ; bit 3 will be on if we're in retrace
        jnz .waitRetrace
    .endRefresh:
        in al, dx
        test al, 0x08
        jz .endRefresh
        pop dx

    ; End of main loop
        dec cx
        jnz .mainLoop

    ; Restore state and exit
        mov ax, 0x03  ; return to text mode 0x03
        int 0x10
        mov ah, 0x4C  ; exit
        mov al, 0     ; return code 0
        int 0x21

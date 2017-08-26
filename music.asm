bits 16
org 0x100


Start:
        mov ax, 0x13   ; set video mode 13h
        int 0x10
        mov ax, 0xA000 ; point ES to video memory
        mov es, ax

        mov al, 182
        out 43h, al
        in al, 61h
        or al, 00000011b
        out 61h, al

        mov word [musicPtr], musicData


MainLoop:
        call LoadMusic
    .topOfLoop:
        call WaitForRetrace

        ; render gfx here

        dec bl
        jnz .topOfLoop
        jmp MainLoop

; BL -> frame count
LoadMusic:
        in al, 61h
        or al, 00000011b
        out 61h, al
        mov di, [musicPtr]
        mov bl, [di]
        inc di
        cmp bl, 0
        je Exit
        push bx
        mov bl, [di]
        cmp bl, 37
        jne .notOff
            in al, 61h
            and al, 11111100b
            out 61h, al
    .notOff:
        shl bl, 1
        inc di
        xor bh, bh
        mov ax, [notesTable+bx]
        pop bx
        out 42h, al
        mov al, ah
        out 42h, al
        mov [musicPtr], di
        ret
    .off:
        ret



Exit:
        in al, 61h
        and al, 11111100b
        out 61h, al

        mov ax, 0x03   ; return to text mode 0x03
        int 0x10
        mov ax, 0x4C00 ; exit with code 0
        int 0x21



WaitForRetrace:
        push ax
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
        pop ax
        ret

notesTable:
        dw 9121 ; C   0
        dw 8609 ; C#  1
        dw 8126 ; D   2
        dw 7670 ; D#  3
        dw 7239 ; E   4
        dw 6833 ; F   5
        dw 6449 ; F#  6
        dw 6087 ; G   7
        dw 5746 ; G#  8
        dw 5423 ; A   9
        dw 5119 ; A#  10
        dw 4831 ; B   11
        dw 4560 ; M-C 12
        dw 4304 ; C#  13
        dw 4063 ; D   14
        dw 3834 ; D#  15
        dw 3619 ; E   16
        dw 3416 ; F   17
        dw 3224 ; F#  18
        dw 3043 ; G   19
        dw 2873 ; G#  20
        dw 2711 ; A   21
        dw 2559 ; A#  22
        dw 2415 ; B   23
        dw 2280 ; C   24
        dw 2152 ; C#  25
        dw 2031 ; D   26
        dw 1917 ; D#  27
        dw 1809 ; E   28
        dw 1715 ; F   29
        dw 1612 ; F#  30
        dw 1521 ; G   31
        dw 1436 ; G#  32
        dw 1355 ; A   33
        dw 1292 ; A#  34
        dw 1207 ; B   35
        dw 1140 ; C   36
        dw 0    ;     37

musicPtr:  dw 0

musicData:
        db 10,11
        db 10,14
        db 10,16
        db 10,17
        db 20,18
        db 10,11
        db 10,16
        db 10,18
        db 20,17
        db 20,16
        db 20,14

        db 10,11
        db 10,14
        db 10,16
        db 10,17
        db 20,18
        db 10,11
        db 10,16
        db 10,18
        db 20,17
        db 20,16
        db 20,14
        db 0

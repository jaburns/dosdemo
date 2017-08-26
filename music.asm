bits 16
org 0x100


Start:
        mov ax, 0x13   ; set video mode 13h
        int 0x10
        mov ax, 0xA000 ; point ES to video memory
        mov es, ax

        mov     al, 182
        out     43h, al
        in      al, 61h
        or      al, 00000011b
        out     61h, al

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
        mov di, [musicPtr]
        mov bl, [di]
        cmp bl, 0
        je Exit
        inc di
        mov ax, [di]
        out 42h, al
        mov al, ah
        out 42h, al
        add di, 2
        mov [musicPtr], di
        ret



Exit:
        in      al, 61h
        and     al, 11111100b
        out     61h, al

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


musicPtr:  dw 0
musicData: db 60
           dw 4560
           db 10
           dw 2280
           db 10
           dw 4560
           db 10
           dw 2280
           db 10
           dw 4560
           db 10
           dw 2280
           db 10
           dw 4560
           db 10
           dw 2280
           db 10
           dw 4560
           db 10
           dw 2280
           db 10
           dw 4560
           db 10
           dw 2280
           db 10
           dw 4560
           db 10
           dw 2280
           db 10
           dw 4560
           db 10
           dw 2280
           db 10
           dw 4560
           db 60
           dw 4560
           db 0


; Start:
;         ; prepare the speaker for the note
;         mov     al, 182
;         out     43h, al
;
;         ; load frequency number (in decimal) for middle C to timer
;         mov     ax, 4560
;         out     42h, al
;         mov     al, ah
;         out     42h, al
;
;         ; turn on speaker
;         in      al, 61h
;         or      al, 00000011b
;         out     61h, al
;
;         ; pause for duration of note
;         mov     dx, 4560
;         mov     bx, 100
;     .pause1:
;         mov     cx, 65535
;     .pause2:
;         dec     cx
;         jne     .pause2
;
;         ; update note frequency
;         add     dx, 1000
;         and     dx, 0x1FFF
;         mov     ax, dx
;         out     42h, al
;         mov     al, ah
;         out     42h, al
;
;         dec     bx
;         jne     .pause1
;
;         ; turn off speacker
;         in      al, 61h
;         and     al, 11111100b
;         out     61h, al
;
;         ; exit with code 0
;         mov ax, 0x4C00
;         int 0x21

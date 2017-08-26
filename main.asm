bits 16
org 0x100

Start:
        mov ax, 0x13   ; set video mode 13h
        int 0x10
        mov ax, 0xA000 ; point ES to video memory
        mov es, ax

    .lup:
        call MainLoop
        jmp .lup

        mov ax, 0x03   ; return to text mode 0x03
        int 0x10
        mov ax, 0x4C00 ; exit with code 0
        int 0x21


MainLoop:
        mov word [frameCounter], 60 * 2
        xor ax, ax  ; ax: incremented every frame

    .topOfLoop:
        call WaitForRetrace

        inc ax

        mov bh, 200 ; bh: counting down rows of screen
                    ; bl: counting up true angle on each screen row. computed from cx
        mov cx, ax  ; cx: counting up multiple of angle on each screen row
        shl cx, 7   ;     starting at a multiple of the time counter ax
        xor dx, dx  ; dx: video memory offset of current row
        xor di, di  ; di: video memory offset, but incremented by called routines

        .rowsLoop:
            add cx, ax
            push cx
            shr cx, 6
            mov bl, cl
            pop cx

            add bl, bh

            call DrawStrip

            add dx, 320
            mov di, dx

            dec bh
            jnz .rowsLoop

        dec word [frameCounter]
        jnz .topOfLoop
        ret

; BH <- row count
; BL <- theta
; DI <- vram offset of start of row
; DI -> vram offset after drawing
DrawStrip:
        push ax
        push cx
        push dx
        push bx

        ; get length of first face of column in to bh
        mov al, bl
        call GetSine
        shr al, 2
        mov bh, al

        ; get length of second face of column in to bl
        mov al, bl
        add al, 128
        call GetSine
        shr al, 2
        mov bl, al

        ; get length of left empty region in to dh
        mov dl, bh
        add dl, bl
        shr dl, 1
        mov dh, 120
        sub dh, dl

        ; draw first empty region
        xor cx, cx
        mov cl, dh
        mov al, 0
        rep stosb

        ; draw two faces, order depending on input angle
        pop dx
        cmp dl, 128
        push dx
        ja .drawOrderElse
            mov cl, bh
            mov dl, 0x10
            call DrawColChunk
            mov cl, bl
            mov dl, 0x40
            call DrawColChunk
            jmp .drawOrderEnd

        .drawOrderElse:
            mov cl, bl
            mov dl, 0x40
            call DrawColChunk
            mov cl, bh
            mov dl, 0x10
            call DrawColChunk

        .drawOrderEnd:

        ; draw more empty space to the right
        mov cl, 30
        mov ax, 0
        rep stosw

        pop bx
        pop dx
        pop cx
        pop ax
        ret


; CL <- width of chunk
; DH <- y position of chunk
; DL <- palette offset
DrawColChunk:
        cmp cl, 0
        jne .notZero
        ret
    .notZero:
        push ax
        push cx
        push dx

        shr dh, 2
        mov ch, cl
        inc ch

        .drawLoop:
            xor ah, ah
            mov al, cl
            shl ax, 4
            div ch

            xor al, dh
            and al, 0x0F
            add al, dl

            stosb
            dec cl
            jnz .drawLoop

        pop dx
        pop cx
        pop ax
        ret


; AL <- theta
; AL -> sin(theta)
GetSine:
        push ax
        xor ah, ah
        mov si, ax
        pop ax
        mov al, [sineTable + si]
        ret


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


frameCounter: dw 0

sineTable: incbin "sine.dat"

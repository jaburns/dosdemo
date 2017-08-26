bits 16
org 0x100


Start:
        ; set up video mode 13h and point ES to vram
        mov ax, 0x13
        int 0x10
        mov ax, 0xA000
        mov es, ax

        ; set up the 8253 timer chip, and enable the PC speaker
        mov al, 182
        out 43h, al
        in al, 61h
        or al, 00000011b
        out 61h, al

        call MainLoop

        ; disable PC speaker
        in al, 61h
        and al, 11111100b
        out 61h, al

        ; return to text mode 0x03 and exit with code 0
        mov ax, 0x03
        int 0x10
        mov ax, 0x4C00
        int 0x21

MainLoop:
        mov word [musicPtr], musicData
        mov word [frameCounter], 60 * 5
        xor ax, ax  ; ax: incremented every frame

    .topOfLoop:
        call WaitForRetrace
        call UpdateMusic

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
            mov dh, 160
        ;   pop cx
        ;   mov al, ch
        ;   call GetSineSmooth
        ;   shr al, 2
        ;   add al, 100
        ;   mov dh, al
        ;   push cx
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


; AL <- theta      : 0->255 map to 0->pi
; AL -> sin(theta) : 0->255 map to 0->1
GetSine:
        push ax
        xor ah, ah
        mov si, ax
        pop ax
        mov al, [sineTable + si]
        ret


; AL <- theta      : 0->255 map to  0->2*pi
; AL -> sin(theta) : 0->255 map to -1->1
GetSineSmooth:
        shl al, 1
        jc .afterPi
        call GetSine
        shr al, 1
        or al, 0x80
        jmp .done
    .afterPi:
        call GetSine
        inc al
        neg al
        shr al, 1
      ; mov al, 0
    .done:
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



UpdateMusic:
        push bx
        dec byte [musicCounter]
        jnz .skipLoad
        call LoadMusic
        mov byte [musicCounter], bl
    .skipLoad:
        pop bx
        ret

; BL -> frame count
LoadMusic:
        push di
        push ax

        mov di, [musicPtr]
        mov bl, [di]
        inc di
        cmp bl, 0
        je .reset
        push bx
        mov bl, [di]
        sub bl, 12
        shl bl, 1
        inc di
        xor bh, bh
        mov ax, [notesTable+bx]
;       shl ax, 2
        pop bx
        out 42h, al
        mov al, ah
        out 42h, al
        mov [musicPtr], di

        pop ax
        pop di
        ret
    .reset:
     ;  push ax
     ;  ret
     ;  popa
        ret



sineTable: incbin "sine.dat"

frameCounter: dw 0

musicCounter: db 1

notesTable:
        dw 18242 ; C
        dw 17218
        dw 16252
        dw 15340
        dw 14478
        dw 13666
        dw 12898
        dw 12174
        dw 11492
        dw 10846
        dw 10238
        dw 9662
        dw 9121
        dw 8609
        dw 8126
        dw 7670
        dw 7239
        dw 6833
        dw 6449
        dw 6087
        dw 5746
        dw 5423
        dw 5119
        dw 4831
        dw 4560
        dw 4304
        dw 4063
        dw 3834
        dw 3619
        dw 3416
        dw 3224
        dw 3043
        dw 2873
        dw 2711
        dw 2559
        dw 2415
        dw 2280
        dw 2152
        dw 2031
        dw 1917
        dw 1809
        dw 1715
        dw 1612
        dw 1521
        dw 1436
        dw 1355
        dw 1292
        dw 1207
        dw 1140

musicPtr: dw 0

; DT equ 2
%define DT 5
%define DTA 10

musicData:
        db 60, 12

        db DTA,25,DT,23,DT,20
        db DTA,25,DT,23,DT,20
        db DTA,18,DT,15,DT,14
        db DTA,20,DT,18,DT,15

        db DTA,23,DT,20,DT,18
        db DTA,15,DT,14,DT,13
        db DTA,15,DT,14,DT,13
        db DTA,14,DT,14,DT,14


        db DTA,25,DT,23,DT,20
        db DTA,25,DT,23,DT,20
        db DTA,18,DT,15,DT,14
        db DTA,20,DT,18,DT,15

        db DTA,23,DT,20,DT,18
        db DTA,15,DT,14,DT,13
        db DTA,15,DT,14,DT,13
        db DTA,14,DT,13,DT,15

        db 0xFF,1

        db 0

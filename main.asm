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
        call InitMusic

    .topOfLoop:
        call WaitForRetrace
        call UpdateMusic

        inc word [frameCounter]

        mov ax, word [frameCounter] ; amount to twist cx by on each next row

        mov cx, ax  ; cx: counting up multiple of angle on each screen row
        shl cx, 7   ;     starting at a multiple of the time counter ax

        xor ah, ah
        call GetSineSmooth
        sub ax, 128

        mov bh, 200 ; bh: counting down rows of screen
                    ; bl: counting up true angle on each screen row. computed from cx
        xor dx, dx  ; dx: video memory offset of current row
        xor di, di  ; di: video memory offset, but incremented by called routines

        .rowsLoop:
            add cx, ax
            push cx
            shr cx, 6
            mov bl, cl
            pop cx

            call DrawStrip

            add dx, 320
            mov di, dx

            dec bh
            jnz .rowsLoop

;       dec word [frameCounter]  jnz
        jmp .topOfLoop
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

;; ===========================================================================
;;  State
;; ===========================================================================

frameCounter:    dw 0
musicPtr:        dw 0
musicCounter:    db 1
curFreq:         dw 0
shouldShiftFreq: db 0

;; ===========================================================================
;;  Music related stuff
;; ===========================================================================

InitMusic:
        mov word [musicPtr], intro
        ret

UpdateMusic:
        dec byte [musicCounter]
        jnz .skipLoad
        call LoadMusic
    .skipLoad:
        cmp byte [shouldShiftFreq], 0xFF
        jne .justRet
        cmp byte [musicCounter], 5
        je .freqShift
        cmp byte [musicCounter], 14
        je .freqShift
        ret
    .freqShift
        push ax
        mov ax, word [curFreq]
        shl ax, 1
        out 42h, al
        mov al, ah
        out 42h, al
        pop ax
    .justRet:
        ret

LoadMusic:
        push di
        push ax
        push bx

        mov di, word [musicPtr]
        mov bl, byte [di]
        cmp bl, 0xFF
        jne .notEnd
            mov word [musicPtr], main
            mov di, main
            mov bl, 0xE0 ; this is the value of the first byte in the music data loop
    .notEnd:
        inc word [musicPtr]
        mov bh, bl
        and bh, 0x80
        jz .dontShiftFreq
            mov byte [shouldShiftFreq], 0xFF
    .dontShiftFreq:
        mov bh, bl
        and bl, 0x07
        and bh, 0x10
        jz .shortNote
            mov byte [musicCounter], 18
            jmp .noteDurBranchEnd
    .shortNote:
            mov byte [musicCounter], 9
    .noteDurBranchEnd:
        xor bh, bh
        shl bl, 1
        mov ax, [freqTable+bx]
        shr ax, 1
        mov word [curFreq], ax
        out 42h, al
        mov al, ah
        out 42h, al

        pop bx
        pop ax
        pop di
        ret

; TODO can save a shift on load, these are too big by 2x

freqTable:
        dw 19324
        dw 16252
        dw 14478
        dw 13666
        dw 12898
        dw 10846

; music byte bits: AxxBxCCC
;   A -> When set first play note at half freq before playing main note
;   B -> When set, duration should be twice as long
;   C -> Index of frequency in freqTable
intro:
        db 0x10,0x11,0x14,0x10
        db 0x14,0x13,0x12,0x11
        db 0x10,0x11,0x14,0x10
        db 0x15,0x14,0x12,0x11
main:   db 0xE0,0xE1,0xE2,0xE3,0xF4,0xE0,0xE2
        db 0xE4,0xF3,0xF2,0xF1,0xE2
        db 0xE0,0xE1,0xE2,0xE3,0xF4,0xE0,0xE2
        db 0xE4,0xF2,0xF3,0xF2,0xE4
        db 0xE0,0xE1,0xE2,0xE3,0xF4,0xE0,0xE2
        db 0xE4,0xF3,0xF2,0xF1,0xE2
        db 0xE0,0xE1,0xE2,0xE3,0xF4,0xE0,0xE2
        db 0xE5,0xF4,0xE3,0xF2,0xE1,0xE2
        db 0xFF

;; ===========================================================================
;;  Import sine table
;; ===========================================================================

sineTable: incbin "sine.dat"



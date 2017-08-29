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
        call WaitForRetrace
        call UpdateMusic

        inc word [frameCounter]
        mov ax, word [frameCounter]

        mov cx, ax  ; cx: counting up multiple of angle on each screen row (after intro)
        shl cx, 7   ;     starting at a multiple of the time counter ax

        xor ah, ah

        cmp word [frameCounter], INTRO_LENGTH

        jae .afterIntro
            xor al, al          ; dont twist column during intro
            jmp .endIntroBranch
        .afterIntro:
            test word [frameCounter], 1
            jz .afterBG
            inc byte [bgColor]
            cmp byte [bgColor], 0x9F
            jb .afterBG
            mov byte [bgColor], 0x80
        .afterBG:
            add al, 96          ; offset sine lookup to align properly after intro
            call GetSineSmooth
            sub ax, 128
            sar ax, 1
            push ax
            mov ax, word [frameCounter]
            sub ax, INTRO_LENGTH
            shr ax, 1
            call GetSineSmooth
            shr al, 1
            add al, 160 - 64
            mov byte [leftOffset], al
            pop ax
        .endIntroBranch:

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

        cmp word [frameCounter], DEMO_LENGTH
        jb MainLoop
        ret

; BH <- row count
; BL <- theta
; DI <- vram offset of start of row
; DI -> vram offset after drawing
DrawStrip:
        push ax
        push cx
        push dx
        push di
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
        mov dh, byte [leftOffset]
        sub dh, dl

        ; draw first empty region
        xor cx, cx
        mov cl, dh
        mov al, byte [bgColor]
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

        pop bx
        pop dx

        ; draw more empty space to the right
        mov ax, di
        sub ax, dx
        mov cx, 320
        sub cx, ax
        mov al, byte [bgColor]
        rep stosb

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
        push bx
        push ax
        xor ah, ah
        shr al, 1
        mov si, ax
        mov bl, [sineTable + si]
        jc .doInterpolate
        jmp .ret
    .doInterpolate:
        push cx
        xor bh, bh
        xor ch, ch
        inc si
        and si, 0x7f
        mov cl, byte [sineTable + si]
        add bx, cx
        shr bx, 1
        pop cx
    .ret:
        pop ax
        mov al, bl
        pop bx
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
leftOffset:      db 160
bgColor:         db 0x80

;; ===========================================================================
;;  Music related stuff
;; ===========================================================================

QUARTER_NOTE          equ  9
HALF_NOTE             equ  2 * QUARTER_NOTE
HIGH_OCTAVE_DURATION  equ  4
INTRO_LENGTH          equ 16 * HALF_NOTE
DEMO_LENGTH           equ INTRO_LENGTH + 16 * 4 * 2 * QUARTER_NOTE - QUARTER_NOTE

; Clobbers: AX, BX, CX, DH, SI
UpdateMusic:
        ;
        mov dh, byte [musicCounter]
        mov cx, word [musicPtr]
        dec dh
        jnz .skipLoad
        call LoadMusic
    .skipLoad:
        cmp word [frameCounter], INTRO_LENGTH
        jb .end
        cmp dh, QUARTER_NOTE - HIGH_OCTAVE_DURATION
        je .freqShift
        cmp dh, HALF_NOTE - HIGH_OCTAVE_DURATION
        je .freqShift
        jmp .end
    .freqShift:
        mov ax, word [curFreq]
        shl ax, 1
        call PlayAX
    .end:
        mov word [musicPtr], cx
        mov byte [musicCounter], dh
        ret

; Clobbers: AX, BX, SI
LoadMusic:
        mov si, cx
        shr si, 1
        mov bl, byte [musicData + si]
        jc .readLow
            and bl, 0xF0
            shr bl, 4
            jmp .afterRead
        .readLow:
            and bl, 0x0F
    .afterRead:
        cmp bl, 0x0F
        jne .notEnd
            mov cx, 16
            mov bl, 0x00 ; This is the value of the first nibble in the music data loop
    .notEnd:
        inc cx
        mov bh, bl
        and bl, 0x07
        and bh, 0x08
        jz .shortNote
            mov dh, HALF_NOTE
            jmp .noteDurBranchEnd
    .shortNote:
            mov dh, QUARTER_NOTE
    .noteDurBranchEnd:
        xor bh, bh
        shl bl, 1
        mov ax, [freqTable+bx]
        mov word [curFreq], ax
PlayAX:
        out 42h, al
        mov al, ah
        out 42h, al
        ret


freqTable:
        dw 9662,8126,7239,6833,6449,5423

; Music nibble bits: BCCC
;   B -> When set, duration should be twice as long
;   C -> Index of frequency in freqTable
musicData:
        db 0x89,0xC8,0xCB,0xA9
        db 0x89,0xC8,0xDC,0xA9
        db 0x01,0x23,0xC0,0x24,0xBA,0x92
        db 0x01,0x23,0xC0,0x24,0xAB,0xA4
        db 0x01,0x23,0xC0,0x24,0xBA,0x92
        db 0x01,0x23,0xC0,0x25,0xC3,0xA1,0x2F

;; ===========================================================================
;;  Sine table
;; ===========================================================================

sineTable:
        db 0x00,0x06,0x0D,0x13,0x19,0x1F,0x25,0x2C,0x32,0x38,0x3E,0x44,0x4A,0x50,0x56,0x5C
        db 0x62,0x67,0x6D,0x73,0x78,0x7E,0x83,0x88,0x8E,0x93,0x98,0x9D,0xA2,0xA7,0xAB,0xB0
        db 0xB4,0xB9,0xBD,0xC1,0xC5,0xC9,0xCD,0xD0,0xD4,0xD7,0xDB,0xDE,0xE1,0xE4,0xE7,0xE9
        db 0xEC,0xEE,0xF0,0xF2,0xF4,0xF6,0xF7,0xF9,0xFA,0xFB,0xFC,0xFD,0xFE,0xFE,0xFF,0xFF
        db 0xFF,0xFF,0xFF,0xFE,0xFE,0xFD,0xFC,0xFB,0xFA,0xF9,0xF7,0xF6,0xF4,0xF2,0xF0,0xEE
        db 0xEC,0xE9,0xE7,0xE4,0xE1,0xDE,0xDB,0xD7,0xD4,0xD0,0xCD,0xC9,0xC5,0xC1,0xBD,0xB9
        db 0xB4,0xB0,0xAB,0xA7,0xA2,0x9D,0x98,0x93,0x8E,0x88,0x83,0x7E,0x78,0x73,0x6D,0x67
        db 0x62,0x5C,0x56,0x50,0x4A,0x44,0x3E,0x38,0x32,0x2C,0x25,0x1F,0x19,0x13,0x0D,0x06

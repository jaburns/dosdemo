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
            add al, 96          ; offset sine lookup to align properly after intro
            call GetSineSmooth
            sub ax, 128
            sar ax, 1

            mov bl, al
            mov al, byte [frameCounter]
            add al, 128 + 96
            call GetSineSmooth
            shr al, 1
            add al, 160 - 64
            mov byte [leftOffset], al
            mov al, bl
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
musicPtr:        dw musicIntro
musicCounter:    db 1
curFreq:         dw 0
leftOffset:      db 160

;; ===========================================================================
;;  Music related stuff
;; ===========================================================================

QUARTER_NOTE          equ  9
HALF_NOTE             equ  2 * QUARTER_NOTE
HIGH_OCTAVE_DURATION  equ  4
INTRO_LENGTH          equ 16 * HALF_NOTE
DEMO_LENGTH           equ INTRO_LENGTH + 16 * 4 * 2 * QUARTER_NOTE - QUARTER_NOTE

UpdateMusic:
        dec byte [musicCounter]
        jnz .skipLoad
        call LoadMusic
    .skipLoad:
        cmp word [frameCounter], INTRO_LENGTH
        jb .justRet
        cmp byte [musicCounter], QUARTER_NOTE - HIGH_OCTAVE_DURATION
        je .freqShift
        cmp byte [musicCounter], HALF_NOTE - HIGH_OCTAVE_DURATION
        je .freqShift
        ret
    .freqShift:
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
            mov word [musicPtr], musicLoop
            mov di, musicLoop
            mov bl, 0xE0 ; this is the value of the first byte in the music data loop
    .notEnd:
        inc word [musicPtr]
        mov bh, bl
        and bl, 0x07
        and bh, 0x10
        jz .shortNote
            mov byte [musicCounter], HALF_NOTE
            jmp .noteDurBranchEnd
    .shortNote:
            mov byte [musicCounter], QUARTER_NOTE
    .noteDurBranchEnd:
        xor bh, bh
        shl bl, 1
        mov ax, [freqTable+bx]
        mov word [curFreq], ax
        out 42h, al
        mov al, ah
        out 42h, al

        pop bx
        pop ax
        pop di
        ret

freqTable:
        dw 9662,8126,7239,6833,6449,5423

;  TODO Can pack music data into nibbles to save space
; music byte bits: xxxBxCCC
;   B -> When set, duration should be twice as long
;   C -> Index of frequency in freqTable
musicIntro:
        db 0x10,0x11,0x14,0x10
        db 0x14,0x13,0x12,0x11
        db 0x10,0x11,0x14,0x10
        db 0x15,0x14,0x12,0x11
musicLoop:
        db 0xE0,0xE1,0xE2,0xE3,0xF4,0xE0,0xE2
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

; TODO Can make do with half the sine table resolution and interpolate
sineTable: incbin "sine.dat"



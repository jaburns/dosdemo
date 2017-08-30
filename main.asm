bits 16
org 0x100

;; ===== Initialize video and sound
Init:
        mov ax, 0x13 ; set up video mode 13h and point ES to vram
        int 0x10
        mov ax, 0xA000
        mov es, ax  ; point ES to vram
        mov al, 182
        out 43h, al ; set up the 8253 timer chip
        in al, 61h
        or al, 00000011b
        out 61h, al ; init PC speaker

;; ===== Wait for retrace, top of main loop -- Clobbers: AL, DX
WaitForRetrace:
        mov dx, 0x03DA
    .waitRetrace:
        in al, dx
        test al, 0x08 ; bit 3 will be on if we're in retrace
        jnz .waitRetrace
    .endRefresh:
        in al, dx
        test al, 0x08
        jz .endRefresh

;; ===== Update music -- Clobbers: AX, BX, CX, DH, SI
UpdateMusic:
    ;   assert(bh == 0)
        mov dh, byte [musicCounter]
        mov cx, word [musicPtr]
        dec dh
        jnz .skipLoad
    .loadMusic:
        mov si, cx
        shr si, 1
        mov bl, byte [musicData + si]
        jc .readLow
        shr bl, 4
    .readLow:
        and bl, 0x0F
    .afterRead:
        cmp bl, 0x0F
        jne .notEnd
        mov cx, 16
        mov bl, 0x00 ; This is the value of the first nibble in the music data loop
    .notEnd:
        inc cx
        shr bl, 1
        mov dh, QUARTER_NOTE
        jnc .quarterNote
        add dh, QUARTER_NOTE
    .quarterNote:
        shl bl, 1
        mov ax, [freqTable + bx]
        mov word [curFreq], ax
        call PlayAX
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

;; ===== Set up the frame to start drawing pixel rows
PreLoopInit:
        ; dx: unused
        inc word [frameCounter]  ; TODO have frame counter in register through music update and pre-init
        mov ax, word [frameCounter]
        mov cx, ax  ; cx: counting up multiple of angle on each screen row (after intro)
        shl cx, 7   ;     starting at a multiple of the time counter ax
        cmp ax, INTRO_LENGTH
        jae .afterIntro
        xor ax, ax  ; dont twist column during intro
        jmp .endIntroBranch
    .afterIntro:
        test ax, 1
        jz .afterBG
        inc byte [bgColor]  ; TODO compute bg color from frame counter
        cmp byte [bgColor], 0x9F
        jb .afterBG
        mov byte [bgColor], 0x80
    .afterBG:
        xor ah, ah
        add al, 96  ; offset sine lookup to align properly after intro
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
        mov bh, 200  ; bh: counting down rows of screen
        xor di, di   ; di: video memory offset, incremented in DrawStrip

;; ===== Loop over the screen pixel rows
RowsLoop:
        ; ax <- amount to add to cx each row
        ; cx <- large multiple of theta
        ; bh <- row count
        ; bl <- theta
        add cx, ax
        push cx
        shr cx, 6
        mov bl, cl
        pop cx
    .drawStrip:
        push ax
        push bx
        push cx

        push di
        push bx

        mov al, bl  ; get length of first face of column in to bh
        call GetSine
        shr al, 2
        mov bh, al
        mov al, bl  ; get length of second face of column in to bl
        add al, 128
        call GetSine
        shr al, 2
        mov bl, al
        mov dl, bh ; get length of left empty region in to dh
        add dl, bl
        shr dl, 1
        sub dl, byte [leftOffset]
        neg dl
        xor cx, cx ; draw first empty region
        mov cl, dl
        mov al, byte [bgColor]
        rep stosb

        pop dx ; draw two faces, order depending on input angle
        cmp dl, 128
        ja .drawOrderElse
        call DrawChunkA
        call DrawChunkB
        jmp .drawOrderEnd
    .drawOrderElse:
        call DrawChunkB
        call DrawChunkA
    .drawOrderEnd:

        pop dx
        mov ax, di ; draw more empty space to the right
        sub ax, dx
        mov cx, 320
        sub cx, ax
        mov al, byte [bgColor]
        rep stosb

        pop cx
        pop bx
        pop ax
    .drawStripEnd:
        dec bh
        jnz RowsLoop
        cmp word [frameCounter], DEMO_LENGTH
        jb WaitForRetrace

;; ===== Restore video + sound settings and exit
        in al, 61h
        and al, 11111100b
        out 61h, al    ; disable PC speaker
        mov ax, 0x03   ; return to text mode 0x03
        int 0x10
        mov ax, 0x4C00 ; exit with code 0
        int 0x21

;; ===========================================================================
;;  Subroutines
;; ===========================================================================

PlayAX:
        out 42h, al
        mov al, ah
        out 42h, al
        ret

DrawChunkA:
        mov cl, bh
        mov dl, 0x10
        jmp DrawColChunk

DrawChunkB:
        mov cl, bl
        mov dl, 0x40

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
        call .lookupTable
        jc .doInterpolate
        jmp .ret
    .doInterpolate:
        push cx
        xor bh, bh
        xor ch, ch
        inc si
        and si, 0x7f
        mov cl, bl
        call .lookupTable
        add bx, cx
        shr bx, 1
        pop cx
    .ret:
        pop ax
        mov al, bl
        pop bx
        ret
    .lookupTable:
        push si
        cmp si, 64
        jb .below64
        sub si, 127
        neg si
    .below64:
        mov bl, byte [sineTable + si]
        pop si
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
    .done:
        ret

;; ===========================================================================
;;  Assembler constants, constant data, and dynamic state
;; ===========================================================================

QUARTER_NOTE         equ  9
HALF_NOTE            equ  2 * QUARTER_NOTE
HIGH_OCTAVE_DURATION equ  4
INTRO_LENGTH         equ 16 * HALF_NOTE
DEMO_LENGTH          equ INTRO_LENGTH + 16 * 4 * 2 * QUARTER_NOTE - QUARTER_NOTE

freqTable:
        dw 9662,8126,7239,6833,6449,5423

; Music nibble bits: BCCC
;   B -> When set, duration should be twice as long
;   C -> Index of frequency in freqTable
musicData:
        db 0x13,0x91,0x97,0x53
        db 0x13,0x91,0xB9,0x53
        db 0x02,0x46,0x90,0x48,0x75,0x34
        db 0x02,0x46,0x90,0x48,0x57,0x58
        db 0x02,0x46,0x90,0x48,0x75,0x34
        db 0x02,0x46,0x90,0x4A,0x96,0x52,0x4F

musicPtr: db 0 ; used as a word, but never uses MSB, so using first value in sine table for MSB of 0.

sineTable:
        db 0x00,0x06,0x0D,0x13,0x19,0x1F,0x25,0x2C,0x32,0x38,0x3E,0x44,0x4A,0x50,0x56,0x5C
        db 0x62,0x67,0x6D,0x73,0x78,0x7E,0x83,0x88,0x8E,0x93,0x98,0x9D,0xA2,0xA7,0xAB,0xB0
        db 0xB4,0xB9,0xBD,0xC1,0xC5,0xC9,0xCD,0xD0,0xD4,0xD7,0xDB,0xDE,0xE1,0xE4,0xE7,0xE9
        db 0xEC,0xEE,0xF0,0xF2,0xF4,0xF6,0xF7,0xF9,0xFA,0xFB,0xFC,0xFD,0xFE,0xFE,0xFF,0xFF

frameCounter: dw 0
musicCounter: db 1
leftOffset:   db 160
bgColor:      db 0x80
;curFreq:     dw 0
curFreq       equ 0x9102 ; Point to some memory past the end of the loaded binary

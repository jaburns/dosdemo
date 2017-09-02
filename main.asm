bits 16
org 0x100

;; ===== Initialize video and sound
Init:
        mov ax, 0x13 ; set up video mode 13h
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
        .varMusicCounter: mov dh, 1  ; labels preceded by 'var' indicate instructions that double as mutable state.
        .varMusicPtr:     mov cx, 0
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
        jnz .notEnd
        mov cx, 16
        mov bl, 2 ; this is the value of the first nibble in the music data loop
    .notEnd:
        inc cx
        shr bl, 1
        mov dh, QUARTER_NOTE
        jnc .quarterNote
        add dh, QUARTER_NOTE
    .quarterNote:
        shl bl, 1
        mov ax, [freqTable + bx]
        mov word [UpdateMusic.varCurFreq + 1], ax
        call PlayAX
    .skipLoad:
        cmp word [PreLoopInit.varFrameCounter + 1], INTRO_LENGTH
        jb .end
        cmp dh, QUARTER_NOTE - HIGH_OCTAVE_DURATION
        je .freqShift
        cmp dh, HALF_NOTE - HIGH_OCTAVE_DURATION
        je .freqShift
        jmp .end
    .freqShift:
        .varCurFreq: mov ax, 0
        shl ax, 1
        call PlayAX
    .end:
        mov word [UpdateMusic.varMusicPtr + 1], cx
        mov byte [UpdateMusic.varMusicCounter + 1], dh

;; ===== Set up the frame to start drawing pixel rows
PreLoopInit:
        ; dx: unused
        inc word [PreLoopInit.varFrameCounter + 1]
        .varFrameCounter: mov ax, 0
        mov cx, ax  ; cx: counting up multiple of angle on each screen row (after intro)
        shl cx, 7   ;     starting at a multiple of the time counter ax
        cmp ax, INTRO_LENGTH
        jae .afterIntro
        xor ax, ax  ; dont twist column during intro
        jmp .endIntroBranch
    .afterIntro:
        test ax, 1
        jz .afterBG
        inc byte [DrawEmpty + 1] ; update the bg color directly at the mov instruction
    .afterBG:
        xor ah, ah
        add al, 96  ; offset sine lookup to align properly after intro
        call GetSineSmooth
        sub ax, 128
        sar ax, 1
        push ax
        mov ax, word [PreLoopInit.varFrameCounter + 1]
        sub ax, INTRO_LENGTH
        shr ax, 1
        call GetSineSmooth
        shr al, 1
        add al, 160 - 64
        mov byte [RowsLoop.varLeftOffset + 2], al
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
        .varLeftOffset: sub dl, 160
        neg dl
        xor ch, ch ; draw first empty region
        mov cl, dl
        call DrawEmpty

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
        mov cx, 320
        sub cx, di
        add cx, dx
        call DrawEmpty

        pop cx
        pop bx
        pop ax
    .drawStripEnd:
        dec bh
        jnz RowsLoop
        cmp word [PreLoopInit.varFrameCounter + 1], DEMO_LENGTH
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

DrawEmpty:
        mov al, 0x00
        and al, 0x1F
        or al, 0x80
        rep stosb
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
        or cl, cl
        jnz .notZero
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
        pushf
        call GetSine
        popf
        jc .afterPi
        shr al, 1
        or al, 0x80
        ret
    .afterPi:
        inc al
        neg al
        shr al, 1
        ret

;; ===========================================================================
;;  Assembler constants, constant data, and dynamic state
;; ===========================================================================

QUARTER_NOTE         equ  9
HALF_NOTE            equ  2 * QUARTER_NOTE
HIGH_OCTAVE_DURATION equ  4
INTRO_LENGTH         equ 16 * HALF_NOTE
DEMO_LENGTH          equ INTRO_LENGTH + 16 * 4 * 2 * QUARTER_NOTE - QUARTER_NOTE

; Music nibble bits: BCCC
;   B -> When set, duration should be twice as long
;   C -> Index of frequency in freqTable
musicData:
        db 0x35,0xB3,0xB9,0x75
        db 0x35,0xB3,0xDB,0x75
        db 0x24,0x68,0xB2,0x6A,0x97,0x56
        db 0x24,0x68,0xB2,0x6A,0x79,0x7A
        db 0x24,0x68,0xB2,0x6A,0x97,0x56
        db 0x24,0x68,0xB2,0x6C,0xB8,0x74,0x60

sineTable:
        db 0x00,0x06,0x0D,0x13,0x19,0x1F,0x25,0x2C,0x32,0x38,0x3E,0x44,0x4A,0x50,0x56,0x5C
        db 0x62,0x67,0x6D,0x73,0x78,0x7E,0x83,0x88,0x8E,0x93,0x98,0x9D,0xA2,0xA7,0xAB,0xB0
        db 0xB4,0xB9,0xBD,0xC1,0xC5,0xC9,0xCD,0xD0,0xD4,0xD7,0xDB,0xDE,0xE1,0xE4,0xE7,0xE9
        db 0xEC,0xEE,0xF0,0xF2,0xF4,0xF6,0xF7,0xF9,0xFA,0xFB,0xFC,0xFD,0xFE,0xFE
freqTable: db 0xFF,0xFF
        dw 9662,8126,7239,6833,6449,5423 ; freqTable label is placed 1 word before the first used
                                         ; frequency, since zero is used as sentinel

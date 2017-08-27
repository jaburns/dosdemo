InitMusic:
        mov word [musicPtr], intro
        ret

UpdateMusic:
        dec byte [musicCounter]
        jnz .skipLoad
        call LoadMusic
    .skipLoad:
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
        and bl, 0x07

        and bh, 0x10
        jz .shortNote
            mov byte [musicCounter], 16
            jmp .noteDurBranchEnd
    .shortNote:
            mov byte [musicCounter], 8
    .noteDurBranchEnd:

        xor bh, bh
        shl bl, 1
        mov ax, [freqTable+bx]
        shr ax, 1
        out 42h, al
        mov al, ah
        out 42h, al

        pop bx
        pop ax
        pop di
        ret

musicPtr: dw 0
musicCounter: db 1

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

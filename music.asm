
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
        shl bl, 1
        inc di
        xor bh, bh
        mov ax, [notesTable+bx]
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



musicPtr: dw 0
musicCounter: db 1

notesTable:
        dw 36484
        dw 34436
        dw 32504
        dw 30680
        dw 28956
        dw 27332
        dw 25796
        dw 24348
        dw 22984
        dw 21692
        dw 20476
        dw 19324
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

%define Q 4
%define H 12
%define X 4

%define Q_11 db X,12+11,Q,11
%define Q_14 db X,12+14,Q,14
%define Q_16 db X,12+16,Q,16
%define Q_17 db X,12+17,Q,17
%define Q_18 db X,12+18,Q,18
%define Q_21 db X,12+21,Q,21
%define H_11 db X,12+11,H,11
%define H_14 db X,12+14,H,14
%define H_16 db X,12+16,H,16
%define H_17 db X,12+17,H,17
%define H_18 db X,12+18,H,18
%define H_21 db X,12+21,H,21

%define SQ_11 db X+Q,12+11
%define SQ_14 db X+Q,12+14
%define SQ_16 db X+Q,12+16
%define SQ_17 db X+Q,12+17
%define SQ_18 db X+Q,12+18
%define SQ_21 db X+Q,12+21
%define SH_11 db X+H,12+11
%define SH_14 db X+H,12+14
%define SH_16 db X+H,12+16
%define SH_17 db X+H,12+17
%define SH_18 db X+H,12+18
%define SH_21 db X+H,12+21


musicData:

        SH_11
        SH_14
        SH_18
        SH_11
        SH_18
        SH_17
        SH_16
        SH_14

        SH_11
        SH_14
        SH_18
        SH_11
        SH_21
        SH_18
        SH_16
        SH_14

        Q_11
        Q_14
        Q_16
        Q_17
        H_18
        Q_11
        Q_16
        Q_18
        H_17
        H_16
        H_14
        Q_16

        Q_11
        Q_14
        Q_16
        Q_17
        H_18
        Q_11
        Q_16
        Q_18
        H_16
        H_17
        H_16
        Q_18

        Q_11
        Q_14
        Q_16
        Q_17
        H_18
        Q_11
        Q_16
        Q_18
        H_17
        H_16
        H_14
        Q_16

        Q_11
        Q_14
        Q_16
        Q_17
        H_18
        Q_11
        Q_16
        Q_21
        H_18
        Q_17
        H_16
        Q_14
        Q_16

        db 0


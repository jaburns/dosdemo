bits 16
org 0x100

; http://faydoc.tripod.com/cpu/

Start:
        call Setup
        xor bl, bl   ; cx -> Sine table lookup index
    .mainLoop:
        call WaitForRetrace

        inc bl
        mov al, bl
        call GetCosine
        shr al, 4
        add al, 0x40
        mov ah, al
        xor di, di
        mov cx, 32000
        rep stosw

        dec word [frameCounter]
        jnz .mainLoop
        jmp Exit



GetSine: ; input al -> output al; clobbers ah
        mov ah, 0
        mov si, ax
        mov al, [sineTable + si]
        ret

GetCosine: ; same properties as GetSine
        mov ah, 0
        add al, 128
        mov si, ax
        mov al, [sineTable + si]
        ret



WaitForRetrace:       ; clobbers al, dx
        mov dx, 0x03DA
    .waitRetrace:
        in al, dx     ; read from status port
        test al, 0x08 ; bit 3 will be on if we're in retrace
        jnz .waitRetrace
    .endRefresh:
        in al, dx
        test al, 0x08
        jz .endRefresh
        ret



Setup:
        mov ax, 0x13   ; set video mode 13h
        int 0x10
        mov ax, 0xA000 ; point ES to video memory
        mov es, ax
        ret

Exit:
        mov ax, 0x03   ; return to text mode 0x03
        int 0x10
        mov ax, 0x4C00 ; exit with code 0
        int 0x21



frameCounter: dw 60 * 5

sineTable: incbin "sine.dat"

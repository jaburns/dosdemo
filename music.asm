bits 16
org 0x100

Start:
        ; prepare the speaker for the note
        mov     al, 182
        out     43h, al

        ; load frequency number (in decimal) for middle C to timer
        mov     ax, 4560
        out     42h, al
        mov     al, ah
        out     42h, al

        ; turn on note
        in      al, 61h
        or      al, 00000011b
        out     61h, al

        ; pause for duration of note
        mov     dx, 4560
        mov     bx, 100
    .pause1:
        mov     cx, 65535
    .pause2:
        dec     cx
        jne     .pause2

        ; update note frequency
        add     dx, 1000
        and     dx, 0x1FFF
        mov     ax, dx
        out     42h, al
        mov     al, ah
        out     42h, al

        dec     bx
        jne     .pause1

        ; turn off note
        in      al, 61h
        and     al, 11111100b
        out     61h, al

        ; exit with code 0
        mov ax, 0x4C00
        int 0x21

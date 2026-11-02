; ============================================================================
; GALAXIAN '79 — BEGINNER'S FULLY ANNOTATED SOURCE (based on working V31)
; ============================================================================
; WHAT THIS IS
;   A Commodore 64 game written in 6502-family assembly for the 6510 CPU.
;   The game uses the VIC-II video chip, SID sound chip and CIA joystick input.
;   The executable instructions and game data are preserved from V31.
;
; HOW TO BUILD (ACME assembler)
;   acme galaxian79_arcade_v31_commented.asm
;   The !to directive below writes galaxian79_arcade_v31_commented.prg.
;   Load the PRG in VICE or a C64 and type RUN (or use emulator autostart).
;
; READING AN ASSEMBLY LINE
;   label:         A named address. Other instructions can jump to it.
;   lda #3         Put the literal number 3 into register A (# = immediate).
;   lda lives      Read the byte stored at the address named lives.
;   sta lives      Write A to the byte stored at lives.
;   lda $d012      Read hexadecimal address $D012 (the raster register).
;   jsr motion     Call motion; motion finishes with rts.
;   beq label      Branch to label if the previous result was zero.
;   ; comment      An explanation for humans; ACME ignores it.
;
; IMPORTANT SYMBOLS
;   $ means hexadecimal (base 16): $10 = 16 decimal, $FF = 255.
;   % means binary (base 2) in ACME: %00000001 = 1.
;   # means use the value itself rather than the byte stored at an address.
;   A, X and Y are the CPU's three 8-bit working registers.
;   A flag is a 1-bit CPU status value (zero, carry, negative, etc.).
;   The carry flag is used in arithmetic and comparisons.
;   !byte puts literal bytes into the output; !word puts 16-bit values.
;   !fill reserves/initialises repeated bytes; !for repeats source at build time.
;   *=$3000 means place following bytes at C64 address $3000.
;
; HOW A FRAME WORKS
;   Wait for raster timing -> read joystick -> move objects -> check hits
;   -> redraw formation/HUD -> update SID and explosion timers -> repeat.
;   PAL is roughly 50 frames/second. Timing here is frame-count based.
;
; C64 VIDEO MEMORY
;   $0400 and $3800 : two 1000-character screens for flicker reduction.
;   $D800             : colour RAM, separate from screen character codes.
;   $2000 onwards    : custom character graphics in RAM.
;   $3000 onwards    : hardware sprite bitmap graphics (64 bytes each).
;   $D000-$D02E      : VIC-II sprite registers and colours.
;   A sprite is 24x21 pixels; a character tile is 8x8 pixels.
;   Multicolour pixels are twice the width of hires pixels.
;   The VIC uses an extra bit in $D010 for X positions above 255.
;
; GAME STATE
;   `alive` contains 46 entries, one per formation alien.
;   `diveindex` selects an alien; `diveon` marks a live dive.
;   `alienboom` and `playerboom` count remaining explosion frames.
;   `scorelo`/`scorehi` and `highlo`/`highhi` are 16-bit values.
;   The high score lasts across restarts, not power cycles.
;
; BEGINNER TIP
;   Read start -> main -> joystick -> motion -> checkhits -> paint -> sprites.
;   Data tables and bitmaps at the end are pictures, not CPU instructions.
; ============================================================================

; GALAXIAN '79 C64 - original arcade-inspired, single-file PAL game
; ACME: acme galaxian79_c64.asm  (produces galaxian79.prg)
; Joystick port 2: left/right/fire. BASIC: RUN
; Screen-code formation: 46 enemies, 10+10+10+10+6.
!to "galaxian79_arcade_v31_commented.prg",cbm ; ACME output file
; Book line 66: Select the output filename and format "galaxian79_arcade_v31_commented.prg",cbm. This
; is an assembler setting and emits no game instruction.
; Declare zero-page pointers before use so ACME selects indirect ZP addressing.
ptr = $fb
; Book line 68: Define ptr as $fb at assembly time; this names a value or address and emits no
; storage.
cptr = $fd
; Book line 69: Define cptr as $fd at assembly time; this names a value or address and emits no
; storage.
*=$0801
; Book line 70: Place subsequent output at C64 address $0801; the origin directive is processed by
; ACME, not executed by the CPU.
!byte $0b,$08,$0a,$00,$9e
; Book line 71: Emit 5 bytes in the shown order for program. These are data or encoded loader bytes,
; not instructions to execute.
!text "2064"
; Book line 72: Emit the quoted text as literal text bytes, used here as loader or message data; these
; are not automatically screen codes.
!byte 0,0,0
; Book line 73: Emit 3 bytes in the shown order for program. These are data or encoded loader bytes,
; not instructions to execute.
*=$0810
; Book line 74: Place subsequent output at C64 address $0810; the origin directive is processed by
; ACME, not executed by the CPU.

; ---------------------------------------------------------------------------
; START: Initialise the CPU, VIC-II display, SID sound chip, persistent high score, character set and title screen. SEI prevents interrupts during setup.
; ---------------------------------------------------------------------------
start:
; Book line 79: start names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 sei                          ; Disable maskable interrupts temporarily
; Book line 80: Set the interrupt-disable flag to mask ordinary IRQ handling. NMI is not masked, and
; peripheral interrupt sources are not automatically cleared.
 lda #$37                     ; Load a value into A
; Book line 81: Load A with literal $37 (decimal 55). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $01                      ; Store A into memory
; Book line 82: Store A into the byte at $01 (6510 ROM and I/O banking port). The register and CPU
; flags are unchanged.
 lda #0                       ; Load a value into A
; Book line 83: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d020                    ; Store A into memory; screen border colour
; Book line 84: Store A into the byte at $d020 (VIC border colour). The register and CPU flags are
; unchanged.
 sta $d021                    ; Store A into memory; background colour
; Book line 85: Store A into the byte at $d021 (VIC background colour). The register and CPU flags are
; unchanged.
 sta $d015                    ; Store A into memory; sprite enable bitmask
; Book line 86: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 sta $d01c                    ; Store A into memory; sprite multicolour mask
; Book line 87: Store A into the byte at $d01c (VIC sprite multicolour bits). The register and CPU
; flags are unchanged.
 sta $d017                    ; Store A into memory; sprite vertical expansion mask
; Book line 88: Store A into the byte at $d017 (VIC sprite height expansion). The register and CPU
; flags are unchanged.
 sta $d01d                    ; Store A into memory; sprite horizontal expansion mask
; Book line 89: Store A into the byte at $d01d (VIC sprite width expansion). The register and CPU
; flags are unchanged.
 sta $d010                    ; Store A into memory; ninth X-position bits for sprites 0–7
; Book line 90: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
 lda #$1b                     ; Load a value into A
; Book line 91: Load A with literal $1b (decimal 27). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d011                    ; Store A into memory; VIC display/raster control
; Book line 92: Store A into the byte at $d011 (VIC vertical control and raster high bit). The
; register and CPU flags are unchanged.
 lda #$03                     ; Load a value into A
; Book line 93: Load A with literal $03 (decimal 3). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $dd00                    ; Store A into memory; VIC memory-bank selector
; Book line 94: Store A into the byte at $dd00 (CIA2 port A and VIC bank select). The register and CPU
; flags are unchanged.
 lda #$18                     ; Load a value into A
; Book line 95: Load A with literal $18 (decimal 24). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d016                    ; Store A into memory; VIC horizontal/multicolour mode
; Book line 96: Store A into the byte at $d016 (VIC horizontal control and fine scroll). The register
; and CPU flags are unchanged.
 lda #$18                     ; Load a value into A
; Book line 97: Load A with literal $18 (decimal 24). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d018                    ; Store A into memory; screen and character-set base selector
; Book line 98: Store A into the byte at $d018 (VIC screen and font selection). The register and CPU
; flags are unchanged.
 lda #15                      ; Load a value into A
; Book line 99: Load A with literal 15. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d418                    ; Store A into memory; SID master volume
; Book line 100: Store A into the byte at $d418 (SID volume and filter mode). The register and CPU
; flags are unchanged.
 lda #0                       ; Load a value into A
; Book line 101: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d404                    ; Store A into memory
; Book line 102: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
 sta $d40b                    ; Store A into memory
; Book line 103: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
 sta $d412                    ; Store A into memory
; Book line 104: Store A into the byte at $d412 (SID voice 3 waveform and gate). The register and CPU
; flags are unchanged.
 lda #0                       ; Load a value into A
; Book line 105: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta highlo                   ; Store A into memory; low byte of session high score
; Book line 106: Store A into the byte at highlo (record low byte). The register and CPU flags are
; unchanged.
 sta highhi                   ; Store A into memory; high byte of session high score
; Book line 107: Store A into the byte at highhi (record high byte). The register and CPU flags are
; unchanged.
 jsr charset_init             ; Call a subroutine (return address saved on stack)
; Book line 108: Call charset_init, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr clear                    ; Call a subroutine (return address saved on stack)
; Book line 109: Call clear, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda #0                       ; Load a value into A
; Book line 110: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta screenbank               ; Store A into memory; which screen is currently visible (double buffering)
; Book line 111: Store A into the byte at screenbank. The register and CPU flags are unchanged.
 jsr title_screen             ; Call a subroutine (return address saved on stack)
; Book line 112: Call title_screen, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 cli                          ; Enable maskable interrupts
; Book line 113: Clear the interrupt-disable flag to permit ordinary IRQ handling once the CPU
; recognises an eligible request. The handler and vectors must already be ready.

; ---------------------------------------------------------------------------
; ATTRACT: Title-screen loop. Poll the keyboard until P is pressed, then initialise a new game.
; ---------------------------------------------------------------------------
attract:
; Book line 118: attract names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr read_p                   ; Call a subroutine (return address saved on stack)
; Book line 119: Call read_p, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 bcc attract                  ; Branch when carry is clear
; Book line 120: Branch to attract if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 sei                          ; Disable maskable interrupts temporarily
; Book line 121: Set the interrupt-disable flag to mask ordinary IRQ handling. NMI is not masked, and
; peripheral interrupt sources are not automatically cleared.
 jsr begin_play               ; Call a subroutine (return address saved on stack)
; Book line 122: Call begin_play, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 cli                          ; Enable maskable interrupts
; Book line 123: Clear the interrupt-disable flag to permit ordinary IRQ handling once the CPU
; recognises an eligible request. The handler and vectors must already be ready.

; ---------------------------------------------------------------------------
; MAIN: Main game loop. Synchronise to raster line 250, process input, move objects, check collisions, redraw and update effects.
; ---------------------------------------------------------------------------
main:
; Book line 128: main names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda $d012                    ; Load a value into A; current raster line
; Book line 129: Load A with the byte at $d012 (VIC raster counter or IRQ compare). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cmp #250                     ; Compare A against operand
; Book line 130: Compare A with literal 250 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne main                     ; Branch when zero flag is clear
; Book line 131: Branch to main if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.

; ---------------------------------------------------------------------------
; WAITFRAME: Wait for raster line 250 to pass so the loop executes once per video frame rather than repeatedly on one scanline.
; ---------------------------------------------------------------------------
waitframe:
; Book line 136: waitframe names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda $d012                    ; Load a value into A; current raster line
; Book line 137: Load A with the byte at $d012 (VIC raster counter or IRQ compare). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cmp #250                     ; Compare A against operand
; Book line 138: Compare A with literal 250 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq waitframe                ; Branch when zero flag is set
; Book line 139: Branch to waitframe if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inc tick                     ; Increase memory byte by 1; frame counter used for timing
; Book line 140: Increase the byte at tick (frame clock) by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
 jsr joystick                 ; Call a subroutine (return address saved on stack)
; Book line 141: Call joystick, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr motion                   ; Call a subroutine (return address saved on stack)
; Book line 142: Call motion, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr checkhits                ; Call a subroutine (return address saved on stack)
; Book line 143: Call checkhits, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr paint                    ; Call a subroutine (return address saved on stack)
; Book line 144: Call paint, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 jsr soundtick                ; Call a subroutine (return address saved on stack)
; Book line 145: Call soundtick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr explosion_tick           ; Call a subroutine (return address saved on stack)
; Book line 146: Call explosion_tick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda gamestate                ; Load a value into A; 1 during play, 0 after game over
; Book line 147: Load A with the byte at gamestate (game state selector). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 beq game_over                ; Branch when zero flag is set
; Book line 148: Branch to game_over if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp main                     ; Jump unconditionally
; Book line 149: Continue execution at main without saving a return address. Registers and flags are
; unchanged by the jump itself.

; ---------------------------------------------------------------------------
; GAME_OVER: Turn off sprites and draw the GAME OVER message using screen codes.
; ---------------------------------------------------------------------------
game_over:
; Book line 154: game_over names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #0                       ; Load a value into A
; Book line 155: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d015                    ; Store A into memory; sprite enable bitmask
; Book line 156: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 jsr menu_setup               ; Call a subroutine (return address saved on stack)
; Book line 157: Call menu_setup, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 ldx #0                       ; Load a value into X
; Book line 158: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
over_line:
; Book line 159: over_line names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda gameover_text,x          ; Load a value into A
; Book line 160: Load A with the byte at gameover_text plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 beq over_end                 ; Branch when zero flag is set
; Book line 161: Branch to over_end if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta $059f,x                  ; row 10 column 15 (centred 9 chars) | Store A into memory
; Book line 162: Store A into the byte at $059f (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 inx                          ; Increase X by 1
; Book line 163: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne over_line                ; Branch when zero flag is clear
; Book line 164: Branch to over_line if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
over_end:
; Book line 165: over_end names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 cli                          ; Enable maskable interrupts
; Book line 166: Clear the interrupt-disable flag to permit ordinary IRQ handling once the CPU
; recognises an eligible request. The handler and vectors must already be ready.

; ---------------------------------------------------------------------------
; WAIT_RESTART: Keep checking for P before starting another game. High score is intentionally not cleared.
; ---------------------------------------------------------------------------
wait_restart:
; Book line 171: wait_restart names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 jsr read_p                   ; Call a subroutine (return address saved on stack)
; Book line 172: Call read_p, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 bcc wait_restart             ; Branch when carry is clear
; Book line 173: Branch to wait_restart if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 sei                          ; Disable maskable interrupts temporarily
; Book line 174: Set the interrupt-disable flag to mask ordinary IRQ handling. NMI is not masked, and
; peripheral interrupt sources are not automatically cleared.
 jsr begin_play               ; Call a subroutine (return address saved on stack)
; Book line 175: Call begin_play, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 cli                          ; Enable maskable interrupts
; Book line 176: Clear the interrupt-disable flag to permit ordinary IRQ handling once the CPU
; recognises an eligible request. The handler and vectors must already be ready.
 jmp main                     ; Jump unconditionally
; Book line 177: Continue execution at main without saving a return address. Registers and flags are
; unchanged by the jump itself.

; Read P from KERNAL keyboard buffer (SCNKEY and GETIN).
; Carry set when P is pressed. Wait for key release to avoid repeats.

; ---------------------------------------------------------------------------
; READ_P: Call KERNAL keyboard scanning/GETIN. Carry set signals P; carry clear means no P detected.
; ---------------------------------------------------------------------------
read_p:
; Book line 185: read_p names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr $ff9f                    ; Call a subroutine (return address saved on stack)
; Book line 186: Call $ff9f, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 jsr $ffe4                    ; Call a subroutine (return address saved on stack)
; Book line 187: Call $ffe4, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 cmp #$50                     ; Compare A against operand
; Book line 188: Compare A with literal $50 (decimal 80) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 beq p_pressed                ; Branch when zero flag is set
; Book line 189: Branch to p_pressed if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #$70                     ; Compare A against operand
; Book line 190: Compare A with literal $70 (decimal 112) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 beq p_pressed                ; Branch when zero flag is set
; Book line 191: Branch to p_pressed if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 192: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 rts                          ; Return from subroutine
; Book line 193: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
p_pressed:
; Book line 194: p_pressed names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sec                          ; Set carry before subtraction
; Book line 195: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 rts                          ; Return from subroutine
; Book line 196: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ---------------------------------------------------------------------------
; BEGIN_PLAY: Restore the gameplay VIC settings (multicolour characters, custom RAM font), clear the display and initialise a new round.
; ---------------------------------------------------------------------------
begin_play:
; Book line 202: begin_play names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #$03                     ; Load a value into A
; Book line 203: Load A with literal $03 (decimal 3). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $dd00                    ; Store A into memory; VIC memory-bank selector
; Book line 204: Store A into the byte at $dd00 (CIA2 port A and VIC bank select). The register and
; CPU flags are unchanged.
 lda #$18                     ; 40-column VIC multicolour characters | Load a value into A
; Book line 205: Load A with literal $18 (decimal 24). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d016                    ; Store A into memory; VIC horizontal/multicolour mode
; Book line 206: Store A into the byte at $d016 (VIC horizontal control and fine scroll). The register
; and CPU flags are unchanged.
 lda #$00                     ; Load a value into A
; Book line 207: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d021                    ; VIC colour 0 is black; 1 is white | Store A into memory; background colour
; Book line 208: Store A into the byte at $d021 (VIC background colour). The register and CPU flags
; are unchanged.
 lda #$06                     ; Load a value into A
; Book line 209: Load A with literal $06 (decimal 6). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d022                    ; shared blue outline | Store A into memory; shared character multicolour 1
; Book line 210: Store A into the byte at $d022. The register and CPU flags are unchanged.
 lda #$01                     ; Load a value into A
; Book line 211: Load A with literal $01 (decimal 1). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d023                    ; shared white highlights | Store A into memory; shared character multicolour 2
; Book line 212: Store A into the byte at $d023. The register and CPU flags are unchanged.
 jsr clear                    ; Call a subroutine (return address saved on stack)
; Book line 213: Call clear, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda #$18                     ; screen $0400, custom RAM character set $2000 | Load a value into A
; Book line 214: Load A with literal $18 (decimal 24). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d018                    ; Store A into memory; screen and character-set base selector
; Book line 215: Store A into the byte at $d018 (VIC screen and font selection). The register and CPU
; flags are unchanged.
 lda #0                       ; Load a value into A
; Book line 216: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta screenbank               ; Store A into memory; which screen is currently visible (double buffering)
; Book line 217: Store A into the byte at screenbank. The register and CPU flags are unchanged.
 lda #1                       ; Load a value into A
; Book line 218: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta gamestate                ; Store A into memory; 1 during play, 0 after game over
; Book line 219: Store A into the byte at gamestate (game state selector). The register and CPU flags
; are unchanged.
 jsr initgame                 ; Call a subroutine (return address saved on stack)
; Book line 220: Call initgame, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr paint_force              ; Call a subroutine (return address saved on stack)
; Book line 221: Call paint_force, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 rts                          ; Return from subroutine
; Book line 222: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ---------------------------------------------------------------------------
; TITLE_SCREEN: Draw the title text. The values are screen codes, not ASCII bytes.
; ---------------------------------------------------------------------------
title_screen:
; Book line 228: title_screen names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 jsr menu_setup               ; Call a subroutine (return address saved on stack)
; Book line 229: Call menu_setup, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 ldx #0                       ; Load a value into X
; Book line 230: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
title_line:
; Book line 231: title_line names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda title_text,x             ; Load a value into A
; Book line 232: Load A with the byte at title_text plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 beq title_prompt             ; Branch when zero flag is set
; Book line 233: Branch to title_prompt if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta $059e,x                  ; row 10, column 14 (11 characters) | Store A into memory
; Book line 234: Store A into the byte at $059e (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 inx                          ; Increase X by 1
; Book line 235: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne title_line               ; Branch when zero flag is clear
; Book line 236: Branch to title_line if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
title_prompt:
; Book line 237: title_prompt names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 jmp menu_prompt              ; Jump unconditionally
; Book line 238: Continue execution at menu_prompt without saving a return address. Registers and
; flags are unchanged by the jump itself.


; ---------------------------------------------------------------------------
; MENU_SETUP: Switch to the ROM font and standard character mode so menu letters are legible; clear both screen buffers.
; ---------------------------------------------------------------------------
menu_setup:
; Book line 244: menu_setup names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #$03                     ; Load a value into A
; Book line 245: Load A with literal $03 (decimal 3). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $dd00                    ; Store A into memory; VIC memory-bank selector
; Book line 246: Store A into the byte at $dd00 (CIA2 port A and VIC bank select). The register and
; CPU flags are unchanged.
 lda #0                       ; Load a value into A
; Book line 247: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d015                    ; Store A into memory; sprite enable bitmask
; Book line 248: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 sta $d01c                    ; Store A into memory; sprite multicolour mask
; Book line 249: Store A into the byte at $d01c (VIC sprite multicolour bits). The register and CPU
; flags are unchanged.
 sta $d010                    ; Store A into memory; ninth X-position bits for sprites 0–7
; Book line 250: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
 lda #$03                     ; Load a value into A
; Book line 251: Load A with literal $03 (decimal 3). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $dd00                    ; VIC bank 0: ROM charset at $1000 | Store A into memory; VIC memory-bank selector
; Book line 252: Store A into the byte at $dd00 (CIA2 port A and VIC bank select). The register and
; CPU flags are unchanged.
 lda #0                       ; Load a value into A
; Book line 253: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d015                    ; Store A into memory; sprite enable bitmask
; Book line 254: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 jsr clear                    ; Call a subroutine (return address saved on stack)
; Book line 255: Call clear, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda #$14                     ; screen $0400, VIC built-in uppercase character ROM at $1000 | Load a value into A
; Book line 256: Load A with literal $14 (decimal 20). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d018                    ; Store A into memory; screen and character-set base selector
; Book line 257: Store A into the byte at $d018 (VIC screen and font selection). The register and CPU
; flags are unchanged.
 lda #$08                     ; normal 40-column hires text | Load a value into A
; Book line 258: Load A with literal $08 (decimal 8). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d016                    ; Store A into memory; VIC horizontal/multicolour mode
; Book line 259: Store A into the byte at $d016 (VIC horizontal control and fine scroll). The register
; and CPU flags are unchanged.
 lda #0                       ; Load a value into A
; Book line 260: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d017                    ; Store A into memory; sprite vertical expansion mask
; Book line 261: Store A into the byte at $d017 (VIC sprite height expansion). The register and CPU
; flags are unchanged.
 sta $d01d                    ; Store A into memory; sprite horizontal expansion mask
; Book line 262: Store A into the byte at $d01d (VIC sprite width expansion). The register and CPU
; flags are unchanged.
 sta $d01b                    ; Store A into memory; sprite priority mask
; Book line 263: Store A into the byte at $d01b (VIC sprite background priority). The register and CPU
; flags are unchanged.
 lda #0                       ; Load a value into A
; Book line 264: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d015                    ; Store A into memory; sprite enable bitmask
; Book line 265: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.

; ---------------------------------------------------------------------------
; MENU_PROMPT: Write PRESS P TO PLAY to row 13, column 12 of the 40-column screen.
; ---------------------------------------------------------------------------
menu_prompt:
; Book line 270: menu_prompt names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ldx #0                       ; Load a value into X
; Book line 271: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
menu_prompt_loop:
; Book line 272: menu_prompt_loop names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda prompt_text,x            ; Load a value into A
; Book line 273: Load A with the byte at prompt_text plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 beq title_end                ; Branch when zero flag is set
; Book line 274: Branch to title_end if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta $0614,x                  ; row 13 col 12 (15 characters) | Store A into memory
; Book line 275: Store A into the byte at $0614 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 inx                          ; Increase X by 1
; Book line 276: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne menu_prompt_loop         ; Branch when zero flag is clear
; Book line 277: Branch to menu_prompt_loop if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
title_end:
; Book line 278: title_end names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 rts                          ; Return from subroutine
; Book line 279: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.



; ---------------------------------------------------------------------------
; CLEAR: Fill both screen buffers with spaces and the colour RAM with white. Uses X wrapping from 255 to 0 as the loop end.
; ---------------------------------------------------------------------------
clear:
; Book line 286: clear names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #$20                     ; Load a value into A
; Book line 287: Load A with literal $20 (decimal 32). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 ldx #0                       ; Load a value into X
; Book line 288: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
cl:
; Book line 289: cl names this assembled address; it emits no bytes and provides a jump, call or data
; reference target.
 sta $0400,x                  ; Store A into memory
; Book line 290: Store A into the byte at $0400 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 sta $0500,x                  ; Store A into memory
; Book line 291: Store A into the byte at $0500 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 sta $0600,x                  ; Store A into memory
; Book line 292: Store A into the byte at $0600 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 sta $06e8,x                  ; Store A into memory
; Book line 293: Store A into the byte at $06e8 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 sta $3800,x                  ; Store A into memory
; Book line 294: Store A into the byte at $3800 plus index X. The register and CPU flags are
; unchanged.
 sta $3900,x                  ; Store A into memory
; Book line 295: Store A into the byte at $3900 plus index X. The register and CPU flags are
; unchanged.
 sta $3a00,x                  ; Store A into memory
; Book line 296: Store A into the byte at $3a00 plus index X. The register and CPU flags are
; unchanged.
 sta $3ae8,x                  ; Store A into memory
; Book line 297: Store A into the byte at $3ae8 plus index X. The register and CPU flags are
; unchanged.
 inx                          ; Increase X by 1
; Book line 298: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne cl                       ; Branch when zero flag is clear
; Book line 299: Branch to cl if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #1                       ; Load a value into A
; Book line 300: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 ldx #0                       ; Load a value into X
; Book line 301: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
cc:
; Book line 302: cc names this assembled address; it emits no bytes and provides a jump, call or data
; reference target.
 sta $d800,x                  ; Store A into memory
; Book line 303: Store A into the byte at $d800 (colour RAM) plus index X. The register and CPU flags
; are unchanged.
 sta $d900,x                  ; Store A into memory
; Book line 304: Store A into the byte at $d900 (colour RAM) plus index X. The register and CPU flags
; are unchanged.
 sta $da00,x                  ; Store A into memory
; Book line 305: Store A into the byte at $da00 (colour RAM) plus index X. The register and CPU flags
; are unchanged.
 sta $dae8,x                  ; Store A into memory
; Book line 306: Store A into the byte at $dae8 (colour RAM) plus index X. The register and CPU flags
; are unchanged.
 inx                          ; Increase X by 1
; Book line 307: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne cc                       ; Branch when zero flag is clear
; Book line 308: Branch to cc if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts                          ; Return from subroutine
; Book line 309: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ---------------------------------------------------------------------------
; INITGAME: Reset lives, score, wave and ship position for a new game; leave the persistent high-score bytes alone.
; ---------------------------------------------------------------------------
initgame:
; Book line 315: initgame names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #3                       ; Load a value into A
; Book line 316: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta lives                    ; Store A into memory; player lives remaining
; Book line 317: Store A into the byte at lives (remaining lives). The register and CPU flags are
; unchanged.
 lda #0                       ; Load a value into A
; Book line 318: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta scorelo                  ; Store A into memory; low byte of current 16-bit score
; Book line 319: Store A into the byte at scorelo (score low byte). The register and CPU flags are
; unchanged.
 sta scorehi                  ; Store A into memory; high byte of current 16-bit score
; Book line 320: Store A into the byte at scorehi (score high byte). The register and CPU flags are
; unchanged.
 sta wave                     ; Store A into memory; current wave number
; Book line 321: Store A into the byte at wave. The register and CPU flags are unchanged.
 lda #160                     ; Load a value into A
; Book line 322: Load A with literal 160. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipx                    ; Store A into memory; player X position, low 8 bits
; Book line 323: Store A into the byte at shipx (ship X low byte). The register and CPU flags are
; unchanged.
 lda #0                       ; Load a value into A
; Book line 324: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipxhi                  ; Store A into memory; player X position, ninth bit
; Book line 325: Store A into the byte at shipxhi. The register and CPU flags are unchanged.
 jsr newwave                  ; Call a subroutine (return address saved on stack)
; Book line 326: Call newwave, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 rts                          ; Return from subroutine
; Book line 327: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ---------------------------------------------------------------------------
; NEWWAVE: Prepare a new 46-alien formation and reset bullets, diving state and movement.
; ---------------------------------------------------------------------------
newwave:
; Book line 332: newwave names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 inc wave                     ; Increase memory byte by 1; current wave number
; Book line 333: Increase the byte at wave by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 lda #0                       ; Load a value into A
; Book line 334: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shoton                   ; Store A into memory; nonzero while player laser is active
; Book line 335: Store A into the byte at shoton. The register and CPU flags are unchanged.
 sta enemyshoton              ; Store A into memory; nonzero while enemy bullet is active
; Book line 336: Store A into the byte at enemyshoton. The register and CPU flags are unchanged.
 sta diveon                   ; Store A into memory; nonzero while a dive is active
; Book line 337: Store A into the byte at diveon. The register and CPU flags are unchanged.
 sta formationstep            ; Store A into memory
; Book line 338: Store A into the byte at formationstep. The register and CPU flags are unchanged.
 sta drift                    ; Store A into memory; horizontal formation offset
; Book line 339: Store A into the byte at drift. The register and CPU flags are unchanged.
 sta divephase                ; Store A into memory; current position in the 64-step dive curve
; Book line 340: Store A into the byte at divephase. The register and CPU flags are unchanged.
 sta divepick                 ; Store A into memory; next candidate index for diving
; Book line 341: Store A into the byte at divepick. The register and CPU flags are unchanged.
 lda #1                       ; Load a value into A
; Book line 342: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta dir                      ; Store A into memory; formation travel direction
; Book line 343: Store A into the byte at dir. The register and CPU flags are unchanged.
 ldx #45                      ; Load a value into X
; Book line 344: Load X with literal 45. Z records a zero value; N copies bit 7. Carry is unchanged.
nw:
; Book line 345: nw names this assembled address; it emits no bytes and provides a jump, call or data
; reference target.
 lda #1                       ; Load a value into A
; Book line 346: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta alive,x                  ; Store A into memory
; Book line 347: Store A into the byte at alive (formation membership table) plus index X. The
; register and CPU flags are unchanged.
 dex                          ; Decrease X by 1
; Book line 348: Decrease X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bpl nw                       ; Branch when result is nonnegative
; Book line 349: Branch to nw if N is 0 (bit 7 clear); otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 lda #46                      ; Load a value into A
; Book line 350: Load A with literal 46. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta remaining                ; Store A into memory; number of aliens left in this wave
; Book line 351: Store A into the byte at remaining (remaining asteroid count). The register and CPU
; flags are unchanged.
 jsr hud                      ; Call a subroutine (return address saved on stack)
; Book line 352: Call hud, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 rts                          ; Return from subroutine
; Book line 353: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ---------------------------------------------------------------------------
; JOYSTICK: Read CIA #1 port A ($DC00), joystick port 2. Joystick switches are active LOW: a cleared bit means pressed.
; ---------------------------------------------------------------------------
joystick:
; Book line 359: joystick names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda $dc00                    ; Load a value into A; CIA joystick port 2 inputs
; Book line 360: Load A with the byte at $dc00 (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #4                       ; Mask A to keep selected bits
; Book line 361: Keep only bits set in both A and literal 4. Save the result in A and update Z and N;
; carry is unchanged.
 bne joyright                 ; Branch when zero flag is clear
; Book line 362: Branch to joyright if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ; Left edge of visible 320px screen is sprite X=24.
 lda shipxhi                  ; Load a value into A; player X position, ninth bit
; Book line 364: Load A with the byte at shipxhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bne moveleft                 ; Branch when zero flag is clear
; Book line 365: Branch to moveleft if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda shipx                    ; Load a value into A; player X position, low 8 bits
; Book line 366: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 cmp #27                      ; Compare A against operand
; Book line 367: Compare A with literal 27 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc joyright                 ; Branch when carry is clear
; Book line 368: Branch to joyright if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.

; ---------------------------------------------------------------------------
; MOVELEFT: Move ship 3 pixels left, using SBC carry/borrow to update the ninth X bit.
; ---------------------------------------------------------------------------
moveleft:
; Book line 373: moveleft names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 sec                          ; Set carry before subtraction
; Book line 374: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda shipx                    ; Load a value into A; player X position, low 8 bits
; Book line 375: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sbc #3                       ; Subtract operand and borrow from A
; Book line 376: Subtract literal 3 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta shipx                    ; Store A into memory; player X position, low 8 bits
; Book line 377: Store A into the byte at shipx (ship X low byte). The register and CPU flags are
; unchanged.
 lda shipxhi                  ; Load a value into A; player X position, ninth bit
; Book line 378: Load A with the byte at shipxhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc #0                       ; Subtract operand and borrow from A
; Book line 379: Subtract literal 0 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta shipxhi                  ; Store A into memory; player X position, ninth bit
; Book line 380: Store A into the byte at shipxhi. The register and CPU flags are unchanged.

; ---------------------------------------------------------------------------
; JOYRIGHT: Test the right-direction joystick bit, then clamp the ship near the right screen edge.
; ---------------------------------------------------------------------------
joyright:
; Book line 385: joyright names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda $dc00                    ; Load a value into A; CIA joystick port 2 inputs
; Book line 386: Load A with the byte at $dc00 (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #8                       ; Mask A to keep selected bits
; Book line 387: Keep only bits set in both A and literal 8. Save the result in A and update Z and N;
; carry is unchanged.
 bne joyfire                  ; Branch when zero flag is clear
; Book line 388: Branch to joyfire if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ; Right edge is X=320 (sprite width 24, visible area ends 344).
 lda shipxhi                  ; Load a value into A; player X position, ninth bit
; Book line 390: Load A with the byte at shipxhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq moveright                ; Branch when zero flag is set
; Book line 391: Branch to moveright if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda shipx                    ; Load a value into A; player X position, low 8 bits
; Book line 392: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 cmp #62                      ; Compare A against operand
; Book line 393: Compare A with literal 62 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcs joyfire                  ; Branch when carry is set
; Book line 394: Branch to joyfire if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.

; ---------------------------------------------------------------------------
; MOVERIGHT: Move ship 3 pixels right. ADC carry propagates into the high X-position byte.
; ---------------------------------------------------------------------------
moveright:
; Book line 399: moveright names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 400: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 lda shipx                    ; Load a value into A; player X position, low 8 bits
; Book line 401: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 adc #3                       ; Add operand and carry to A
; Book line 402: Add literal 3 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta shipx                    ; Store A into memory; player X position, low 8 bits
; Book line 403: Store A into the byte at shipx (ship X low byte). The register and CPU flags are
; unchanged.
 lda shipxhi                  ; Load a value into A; player X position, ninth bit
; Book line 404: Load A with the byte at shipxhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 adc #0                       ; Add operand and carry to A
; Book line 405: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta shipxhi                  ; Store A into memory; player X position, ninth bit
; Book line 406: Store A into the byte at shipxhi. The register and CPU flags are unchanged.

; ---------------------------------------------------------------------------
; JOYFIRE: Start a player laser if fire is pressed and no laser is already active. Also trigger a short SID note.
; ---------------------------------------------------------------------------
joyfire:
; Book line 411: joyfire names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda $dc00                    ; Load a value into A; CIA joystick port 2 inputs
; Book line 412: Load A with the byte at $dc00 (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #16                      ; Mask A to keep selected bits
; Book line 413: Keep only bits set in both A and literal 16. Save the result in A and update Z and N;
; carry is unchanged.
 bne joyend                   ; Branch when zero flag is clear
; Book line 414: Branch to joyend if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda shoton                   ; Load a value into A; nonzero while player laser is active
; Book line 415: Load A with the byte at shoton. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bne joyend                   ; Branch when zero flag is clear
; Book line 416: Branch to joyend if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #1                       ; Load a value into A
; Book line 417: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shoton                   ; Store A into memory; nonzero while player laser is active
; Book line 418: Store A into the byte at shoton. The register and CPU flags are unchanged.
 lda shipx                    ; Load a value into A; player X position, low 8 bits
; Book line 419: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 420: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #1                       ; Add operand and carry to A
; Book line 421: Add literal 1 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta shotx                    ; Store A into memory; player laser X low byte
; Book line 422: Store A into the byte at shotx. The register and CPU flags are unchanged.
 lda shipxhi                  ; Load a value into A; player X position, ninth bit
; Book line 423: Load A with the byte at shipxhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 adc #0                       ; Add operand and carry to A
; Book line 424: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta shotxhi                  ; Store A into memory; player laser X high bit
; Book line 425: Store A into the byte at shotxhi. The register and CPU flags are unchanged.
 lda #203                     ; Load a value into A
; Book line 426: Load A with literal 203. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shoty                    ; Store A into memory; player laser Y position
; Book line 427: Store A into the byte at shoty. The register and CPU flags are unchanged.
 lda #8                       ; Load a value into A
; Book line 428: Load A with literal 8. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta laserlife                ; Store A into memory; laser sound effect countdown
; Book line 429: Store A into the byte at laserlife. The register and CPU flags are unchanged.
 lda #0                       ; Load a value into A
; Book line 430: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d404                    ; Store A into memory
; Book line 431: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
 lda #$70                     ; Load a value into A
; Book line 432: Load A with literal $70 (decimal 112). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d400                    ; Store A into memory
; Book line 433: Store A into the byte at $d400 (SID voice 1 frequency low). The register and CPU
; flags are unchanged.
 lda #$27                     ; Load a value into A
; Book line 434: Load A with literal $27 (decimal 39). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d401                    ; Store A into memory
; Book line 435: Store A into the byte at $d401 (SID voice 1 frequency high). The register and CPU
; flags are unchanged.
 lda #$09                     ; Load a value into A
; Book line 436: Load A with literal $09 (decimal 9). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d405                    ; Store A into memory
; Book line 437: Store A into the byte at $d405 (SID voice 1 attack and decay). The register and CPU
; flags are unchanged.
 lda #$30                     ; Load a value into A
; Book line 438: Load A with literal $30 (decimal 48). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d406                    ; Store A into memory
; Book line 439: Store A into the byte at $d406 (SID voice 1 sustain and release). The register and
; CPU flags are unchanged.
 lda #$81                     ; Load a value into A
; Book line 440: Load A with literal $81 (decimal 129). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d404                    ; Store A into memory
; Book line 441: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
joyend: rts                   ; Return from subroutine
; Book line 442: joyend names the data or instruction address. Pull the saved subroutine return
; address from the stack and resume after its JSR. Do not use this as an interrupt return.


; ---------------------------------------------------------------------------
; MOTION: Update the player laser, enemy laser, formation drift, diving alien and enemy firing.
; ---------------------------------------------------------------------------
motion:
; Book line 448: motion names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda shoton                   ; Load a value into A; nonzero while player laser is active
; Book line 449: Load A with the byte at shoton. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq noshotmove               ; Branch when zero flag is set
; Book line 450: Branch to noshotmove if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda shoty                    ; Load a value into A; player laser Y position
; Book line 451: Load A with the byte at shoty. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #45                      ; Compare A against operand
; Book line 452: Compare A with literal 45 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc endshot                  ; Branch when carry is clear
; Book line 453: Branch to endshot if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 sec                          ; Set carry before subtraction
; Book line 454: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc #5                       ; Subtract operand and borrow from A
; Book line 455: Subtract literal 5 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta shoty                    ; Store A into memory; player laser Y position
; Book line 456: Store A into the byte at shoty. The register and CPU flags are unchanged.
 jmp noshotmove               ; Jump unconditionally
; Book line 457: Continue execution at noshotmove without saving a return address. Registers and flags
; are unchanged by the jump itself.

; ---------------------------------------------------------------------------
; ENDSHOT: Deactivate the laser once it leaves the playable area.
; ---------------------------------------------------------------------------
endshot:
; Book line 462: endshot names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #0                       ; Load a value into A
; Book line 463: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shoton                   ; Store A into memory; nonzero while player laser is active
; Book line 464: Store A into the byte at shoton. The register and CPU flags are unchanged.

; ---------------------------------------------------------------------------
; NOSHOTMOVE: Move an active enemy shot downward and turn it off below the screen.
; ---------------------------------------------------------------------------
noshotmove:
; Book line 469: noshotmove names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda enemyshoton              ; Load a value into A; nonzero while enemy bullet is active
; Book line 470: Load A with the byte at enemyshoton. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq noshotenemy              ; Branch when zero flag is set
; Book line 471: Branch to noshotenemy if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda enemyshoty               ; Load a value into A; enemy bullet Y position
; Book line 472: Load A with the byte at enemyshoty. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 473: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #3                       ; Add operand and carry to A
; Book line 474: Add literal 3 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta enemyshoty               ; Store A into memory; enemy bullet Y position
; Book line 475: Store A into the byte at enemyshoty. The register and CPU flags are unchanged.
 cmp #240                     ; Compare A against operand
; Book line 476: Compare A with literal 240 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc noshotenemy              ; Branch when carry is clear
; Book line 477: Branch to noshotenemy if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #0                       ; Load a value into A
; Book line 478: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta enemyshoton              ; Store A into memory; nonzero while enemy bullet is active
; Book line 479: Store A into the byte at enemyshoton. The register and CPU flags are unchanged.

; ---------------------------------------------------------------------------
; NOSHOTENEMY: Every eighth frame, adjust the formation drift and reverse direction at its limits.
; ---------------------------------------------------------------------------
noshotenemy:
; Book line 484: noshotenemy names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda tick                     ; Load a value into A; frame counter used for timing
; Book line 485: Load A with the byte at tick (frame clock). Z records a zero value; N copies bit 7.
; Carry is unchanged.
 and #7                       ; Mask A to keep selected bits
; Book line 486: Keep only bits set in both A and literal 7. Save the result in A and update Z and N;
; carry is unchanged.
 bne nomarch                  ; Branch when zero flag is clear
; Book line 487: Branch to nomarch if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ; Keep 2-character-wide aliens inside columns 0..39.
 ; Rightmost regular alien starts at column 35, so drift <= 3.
 lda dir                      ; Load a value into A; formation travel direction
; Book line 490: Load A with the byte at dir. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq marchleft                ; Branch when zero flag is set
; Book line 491: Branch to marchleft if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inc drift                    ; Increase memory byte by 1; horizontal formation offset
; Book line 492: Increase the byte at drift by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 lda drift                    ; Load a value into A; horizontal formation offset
; Book line 493: Load A with the byte at drift. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #3                       ; Compare A against operand
; Book line 494: Compare A with literal 3 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc nomarch                  ; Branch when carry is clear
; Book line 495: Branch to nomarch if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #0                       ; Load a value into A
; Book line 496: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta dir                      ; Store A into memory; formation travel direction
; Book line 497: Store A into the byte at dir. The register and CPU flags are unchanged.
 jmp nomarch                  ; Jump unconditionally
; Book line 498: Continue execution at nomarch without saving a return address. Registers and flags
; are unchanged by the jump itself.
marchleft:
; Book line 499: marchleft names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda drift                    ; Load a value into A; horizontal formation offset
; Book line 500: Load A with the byte at drift. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq turnright                ; Branch when zero flag is set
; Book line 501: Branch to turnright if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec drift                    ; Decrease memory byte by 1; horizontal formation offset
; Book line 502: Decrease the byte at drift by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 jmp nomarch                  ; Jump unconditionally
; Book line 503: Continue execution at nomarch without saving a return address. Registers and flags
; are unchanged by the jump itself.
turnright:
; Book line 504: turnright names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #1                       ; Load a value into A
; Book line 505: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta dir                      ; Store A into memory; formation travel direction
; Book line 506: Store A into the byte at dir. The register and CPU flags are unchanged.

; ---------------------------------------------------------------------------
; NOMARCH: If a dive is active, advance it along a precomputed curve and downward through the playfield.
; ---------------------------------------------------------------------------
nomarch:
; Book line 511: nomarch names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda diveon                   ; Load a value into A; nonzero while a dive is active
; Book line 512: Load A with the byte at diveon. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq launch                   ; Branch when zero flag is set
; Book line 513: Branch to launch if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda divey                    ; Load a value into A; diving alien Y
; Book line 514: Load A with the byte at divey. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 515: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #3                       ; Add operand and carry to A
; Book line 516: Add literal 3 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta divey                    ; Store A into memory; diving alien Y
; Book line 517: Store A into the byte at divey. The register and CPU flags are unchanged.
 ; smooth curved dive: left/right motion changes with dive phase
 inc divephase                ; Increase memory byte by 1; current position in the 64-step dive curve
; Book line 519: Increase the byte at divephase by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 lda divephase                ; Load a value into A; current position in the 64-step dive curve
; Book line 520: Load A with the byte at divephase. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #$3f                     ; Mask A to keep selected bits
; Book line 521: Keep only bits set in both A and literal $3f (decimal 63). Save the result in A and
; update Z and N; carry is unchanged.
 tax                          ; Copy A into X
; Book line 522: Copy A to X; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda divecurve,x              ; Load a value into A
; Book line 523: Load A with the byte at divecurve plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta diveoffset               ; Store A into memory; signed horizontal offset from the dive curve
; Book line 524: Store A into the byte at diveoffset. The register and CPU flags are unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 525: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc diveorigin               ; Add operand and carry to A; diving alien starting X low byte
; Book line 526: Add the byte at diveorigin and incoming carry to A. Update C, Z, N and V according to
; CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta divex                    ; Store A into memory; diving alien X low byte
; Book line 527: Store A into the byte at divex. The register and CPU flags are unchanged.
 lda diveoffset               ; Load a value into A; signed horizontal offset from the dive curve
; Book line 528: Load A with the byte at diveoffset. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bmi dive_negative            ; Branch when result is negative
; Book line 529: Branch to dive_negative if N is 1 (bit 7 set); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda diveoriginhi             ; Load a value into A; diving alien starting X high byte
; Book line 530: Load A with the byte at diveoriginhi. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 adc #0                       ; Add operand and carry to A
; Book line 531: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta divexhi                  ; Store A into memory; diving alien ninth X bit
; Book line 532: Store A into the byte at divexhi. The register and CPU flags are unchanged.
 jmp divebottom               ; Jump unconditionally
; Book line 533: Continue execution at divebottom without saving a return address. Registers and flags
; are unchanged by the jump itself.

; ---------------------------------------------------------------------------
; DIVE_NEGATIVE: The dive curve offset is negative; sign-extend it to the high X byte.
; ---------------------------------------------------------------------------
dive_negative:
; Book line 538: dive_negative names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda diveoriginhi             ; Load a value into A; diving alien starting X high byte
; Book line 539: Load A with the byte at diveoriginhi. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 adc #$ff                     ; Add operand and carry to A
; Book line 540: Add literal $ff (decimal 255) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta divexhi                  ; Store A into memory; diving alien ninth X bit
; Book line 541: Store A into the byte at divexhi. The register and CPU flags are unchanged.

; ---------------------------------------------------------------------------
; DIVEBOTTOM: Deactivate a dive when it reaches the bottom edge.
; ---------------------------------------------------------------------------
divebottom:
; Book line 546: divebottom names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda divey                    ; Load a value into A; diving alien Y
; Book line 547: Load A with the byte at divey. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #237                     ; Compare A against operand
; Book line 548: Compare A with literal 237 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc launch                   ; Branch when carry is clear
; Book line 549: Branch to launch if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #0                       ; Load a value into A
; Book line 550: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta diveon                   ; Store A into memory; nonzero while a dive is active
; Book line 551: Store A into the byte at diveon. The register and CPU flags are unchanged.
 jmp launch                   ; Jump unconditionally
; Book line 552: Continue execution at launch without saving a return address. Registers and flags are
; unchanged by the jump itself.

; ---------------------------------------------------------------------------
; LAUNCH: Periodically choose a living alien to begin a dive; do not give up merely because one candidate was destroyed.
; ---------------------------------------------------------------------------
launch:
; Book line 557: launch names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda diveon                   ; Load a value into A; nonzero while a dive is active
; Book line 558: Load A with the byte at diveon. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bne enemyfire                ; Branch when zero flag is clear
; Book line 559: Branch to enemyfire if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda tick                     ; Load a value into A; frame counter used for timing
; Book line 560: Load A with the byte at tick (frame clock). Z records a zero value; N copies bit 7.
; Carry is unchanged.
 and #63                      ; Mask A to keep selected bits
; Book line 561: Keep only bits set in both A and literal 63. Save the result in A and update Z and N;
; carry is unchanged.
 bne enemyfire                ; Branch when zero flag is clear
; Book line 562: Branch to enemyfire if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ; Search for a surviving alien, rather than giving up when
 ; the next chosen slot has already been destroyed.
 lda divepick                 ; Load a value into A; next candidate index for diving
; Book line 565: Load A with the byte at divepick. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 566: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #7                       ; Add operand and carry to A
; Book line 567: Add literal 7 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp #46                      ; Compare A against operand
; Book line 568: Compare A with literal 46 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc divepickok               ; Branch when carry is clear
; Book line 569: Branch to divepickok if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 sbc #46                      ; Subtract operand and borrow from A
; Book line 570: Subtract literal 46 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
divepickok:
; Book line 571: divepickok names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sta divepick                 ; Store A into memory; next candidate index for diving
; Book line 572: Store A into the byte at divepick. The register and CPU flags are unchanged.
 tax                          ; Copy A into X
; Book line 573: Copy A to X; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 ldy #46                      ; Load a value into Y
; Book line 574: Load Y with literal 46. Z records a zero value; N copies bit 7. Carry is unchanged.

; ---------------------------------------------------------------------------
; DIVE_SEARCH: Scan up to all 46 alien slots, wrapping at the end, until a surviving alien is found.
; ---------------------------------------------------------------------------
dive_search:
; Book line 579: dive_search names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda alive,x                  ; Load a value into A
; Book line 580: Load A with the byte at alive (formation membership table) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 bne dive_found               ; Branch when zero flag is clear
; Book line 581: Branch to dive_found if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inx                          ; Increase X by 1
; Book line 582: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #46                      ; Compare X against operand
; Book line 583: Compare X with literal 46 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc dive_search_next         ; Branch when carry is clear
; Book line 584: Branch to dive_search_next if C is 0; otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 ldx #0                       ; Load a value into X
; Book line 585: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
dive_search_next:
; Book line 586: dive_search_next names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 dey                          ; Decrease Y by 1
; Book line 587: Decrease Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne dive_search              ; Branch when zero flag is clear
; Book line 588: Branch to dive_search if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp enemyfire                ; Jump unconditionally
; Book line 589: Continue execution at enemyfire without saving a return address. Registers and flags
; are unchanged by the jump itself.

; ---------------------------------------------------------------------------
; DIVE_FOUND: Remember the selected alien, find its current formation position and initialise its dive.
; ---------------------------------------------------------------------------
dive_found:
; Book line 594: dive_found names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 stx divepick                 ; Store X into memory; next candidate index for diving
; Book line 595: Store X into the byte at divepick. The register and CPU flags are unchanged.
 stx diveindex                ; Store X into memory; index of the alien selected for a dive
; Book line 596: Store X into the byte at diveindex. The register and CPU flags are unchanged.
 lda #1                       ; Load a value into A
; Book line 597: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta diveon                   ; Store A into memory; nonzero while a dive is active
; Book line 598: Store A into the byte at diveon. The register and CPU flags are unchanged.
 jsr enemycoords              ; Call a subroutine (return address saved on stack)
; Book line 599: Call enemycoords, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda ex                       ; Load a value into A; calculated alien pixel X low byte
; Book line 600: Load A with the byte at ex. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta diveorigin               ; Store A into memory; diving alien starting X low byte
; Book line 601: Store A into the byte at diveorigin. The register and CPU flags are unchanged.
 sta divex                    ; Store A into memory; diving alien X low byte
; Book line 602: Store A into the byte at divex. The register and CPU flags are unchanged.
 lda exhi                     ; Load a value into A; calculated alien pixel X high bit
; Book line 603: Load A with the byte at exhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta diveoriginhi             ; Store A into memory; diving alien starting X high byte
; Book line 604: Store A into the byte at diveoriginhi. The register and CPU flags are unchanged.
 sta divexhi                  ; Store A into memory; diving alien ninth X bit
; Book line 605: Store A into the byte at divexhi. The register and CPU flags are unchanged.
 lda ey                       ; Load a value into A; calculated alien pixel Y
; Book line 606: Load A with the byte at ey. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta divey                    ; Store A into memory; diving alien Y
; Book line 607: Store A into the byte at divey. The register and CPU flags are unchanged.
 lda #0                       ; Load a value into A
; Book line 608: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta divephase                ; Store A into memory; current position in the 64-step dive curve
; Book line 609: Store A into the byte at divephase. The register and CPU flags are unchanged.

; ---------------------------------------------------------------------------
; ENEMYFIRE: Launch a new enemy bullet periodically, using the diving alien position when available.
; ---------------------------------------------------------------------------
enemyfire:
; Book line 614: enemyfire names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda enemyshoton              ; Load a value into A; nonzero while enemy bullet is active
; Book line 615: Load A with the byte at enemyshoton. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bne motionend                ; Branch when zero flag is clear
; Book line 616: Branch to motionend if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda tick                     ; Load a value into A; frame counter used for timing
; Book line 617: Load A with the byte at tick (frame clock). Z records a zero value; N copies bit 7.
; Carry is unchanged.
 and #127                     ; Mask A to keep selected bits
; Book line 618: Keep only bits set in both A and literal 127. Save the result in A and update Z and
; N; carry is unchanged.
 bne motionend                ; Branch when zero flag is clear
; Book line 619: Branch to motionend if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #1                       ; Load a value into A
; Book line 620: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta enemyshoton              ; Store A into memory; nonzero while enemy bullet is active
; Book line 621: Store A into the byte at enemyshoton. The register and CPU flags are unchanged.
 lda diveon                   ; Load a value into A; nonzero while a dive is active
; Book line 622: Load A with the byte at diveon. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq fireformation            ; Branch when zero flag is set
; Book line 623: Branch to fireformation if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda divex                    ; Load a value into A; diving alien X low byte
; Book line 624: Load A with the byte at divex. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta enemyshotx               ; Store A into memory; enemy bullet X low byte
; Book line 625: Store A into the byte at enemyshotx. The register and CPU flags are unchanged.
 lda divexhi                  ; Load a value into A; diving alien ninth X bit
; Book line 626: Load A with the byte at divexhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta enemyshotxhi             ; Store A into memory; enemy bullet ninth X bit
; Book line 627: Store A into the byte at enemyshotxhi. The register and CPU flags are unchanged.
 lda divey                    ; Load a value into A; diving alien Y
; Book line 628: Load A with the byte at divey. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta enemyshoty               ; Store A into memory; enemy bullet Y position
; Book line 629: Store A into the byte at enemyshoty. The register and CPU flags are unchanged.
 rts                          ; Return from subroutine
; Book line 630: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ---------------------------------------------------------------------------
; FIREFORMATION: When nothing is diving, launch a bullet from a fixed position near the formation.
; ---------------------------------------------------------------------------
fireformation:
; Book line 635: fireformation names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #160                     ; Load a value into A
; Book line 636: Load A with literal 160. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta enemyshotx               ; Store A into memory; enemy bullet X low byte
; Book line 637: Store A into the byte at enemyshotx. The register and CPU flags are unchanged.
 lda #0                       ; Load a value into A
; Book line 638: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta enemyshotxhi             ; Store A into memory; enemy bullet ninth X bit
; Book line 639: Store A into the byte at enemyshotxhi. The register and CPU flags are unchanged.
 lda #115                     ; Load a value into A
; Book line 640: Load A with literal 115. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta enemyshoty               ; Store A into memory; enemy bullet Y position
; Book line 641: Store A into the byte at enemyshoty. The register and CPU flags are unchanged.
motionend: rts                ; Return from subroutine
; Book line 642: motionend names the data or instruction address. Pull the saved subroutine return
; address from the stack and resume after its JSR. Do not use this as an interrupt return.

; index X -> pixel coordinate of formation character (8-pixel cells)
; 0..9 cyan, 10..19 purple, 20..29 purple, 30..39 red, 40..45 flagship
; formation is drawn at screen columns 5..34; rows 5,7,9,11,13
; each row uses spacing of 3 columns, flagship row starts at column 11
; drift is applied in screen columns via +/- one cell at boundaries

; ---------------------------------------------------------------------------
; COORDS: Convert an alien index (0–45) into its formation row, column and on-screen position.
; ---------------------------------------------------------------------------
coords:
; Book line 653: coords names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #0                       ; Load a value into A
; Book line 654: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta rownum                   ; Store A into memory; formation row for the current alien
; Book line 655: Store A into the byte at rownum. The register and CPU flags are unchanged.
 txa                          ; Copy X into A
; Book line 656: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
co10:
; Book line 657: co10 names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 cmp #10                      ; Compare A against operand
; Book line 658: Compare A with literal 10 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc cofound                  ; Branch when carry is clear
; Book line 659: Branch to cofound if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 sec                          ; Set carry before subtraction
; Book line 660: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc #10                      ; Subtract operand and borrow from A
; Book line 661: Subtract literal 10 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 inc rownum                   ; Increase memory byte by 1; formation row for the current alien
; Book line 662: Increase the byte at rownum by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 cmp #10                      ; Compare A against operand
; Book line 663: Compare A with literal 10 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcs co10                     ; Branch when carry is set
; Book line 664: Branch to co10 if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
cofound:
; Book line 665: cofound names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 sta colnum                   ; Store A into memory; formation column for the current alien
; Book line 666: Store A into the byte at colnum. The register and CPU flags are unchanged.
 lda rownum                   ; Load a value into A; formation row for the current alien
; Book line 667: Load A with the byte at rownum. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #4                       ; Compare A against operand
; Book line 668: Compare A with literal 4 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne coreg                    ; Branch when zero flag is clear
; Book line 669: Branch to coreg if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda colnum                   ; Load a value into A; formation column for the current alien
; Book line 670: Load A with the byte at colnum. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #6                       ; Compare A against operand
; Book line 671: Compare A with literal 6 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc coflag                   ; Branch when carry is clear
; Book line 672: Branch to coflag if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
coflag:
; Book line 673: coflag names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda colnum                   ; Load a value into A; formation column for the current alien
; Book line 674: Load A with the byte at colnum. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 asl                          ; Shift left one bit
; Book line 675: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 676: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc colnum                   ; Add operand and carry to A; formation column for the current alien
; Book line 677: Add the byte at colnum and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 adc #12                      ; Add operand and carry to A
; Book line 678: Add literal 12 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 jmp cocol                    ; Jump unconditionally
; Book line 679: Continue execution at cocol without saving a return address. Registers and flags are
; unchanged by the jump itself.
coreg:
; Book line 680: coreg names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda colnum                   ; Load a value into A; formation column for the current alien
; Book line 681: Load A with the byte at colnum. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 asl                          ; Shift left one bit
; Book line 682: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 683: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #8                       ; Add operand and carry to A
; Book line 684: Add literal 8 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 685: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc colnum                   ; Add operand and carry to A; formation column for the current alien
; Book line 686: Add the byte at colnum and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
cocol:
; Book line 687: cocol names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 688: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc drift                    ; Add operand and carry to A; horizontal formation offset
; Book line 689: Add the byte at drift and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta screenx                  ; Store A into memory; alien position in text columns
; Book line 690: Store A into the byte at screenx. The register and CPU flags are unchanged.
 lda rownum                   ; Load a value into A; formation row for the current alien
; Book line 691: Load A with the byte at rownum. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 asl                          ; Shift left one bit
; Book line 692: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 693: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc rownum                   ; Add operand and carry to A; formation row for the current alien
; Book line 694: Add the byte at rownum and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 ; row offsets 5,7,9,11,13 (not 3)
 lda rownum                   ; Load a value into A; formation row for the current alien
; Book line 696: Load A with the byte at rownum. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 asl                          ; Shift left one bit
; Book line 697: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 698: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #5                       ; Add operand and carry to A
; Book line 699: Add literal 5 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta screeny                  ; Store A into memory; alien position in text rows
; Book line 700: Store A into the byte at screeny. The register and CPU flags are unchanged.
 rts                          ; Return from subroutine
; Book line 701: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Screen position pointer for x index; uses multiplication by 40 table

; ---------------------------------------------------------------------------
; SCREENPTR: Compute screen and colour-RAM pointers for an alien tile, including which of the two screen buffers is being drawn.
; ---------------------------------------------------------------------------
screenptr:
; Book line 708: screenptr names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr coords                   ; Call a subroutine (return address saved on stack)
; Book line 709: Call coords, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 ldy screeny                  ; Load a value into Y; alien position in text rows
; Book line 710: Load Y with the byte at screeny. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda rowlow,y                 ; Load a value into A
; Book line 711: Load A with the byte at rowlow plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 712: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc screenx                  ; Add operand and carry to A; alien position in text columns
; Book line 713: Add the byte at screenx and incoming carry to A. Update C, Z, N and V according to
; CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ptr                      ; Store A into memory
; Book line 714: Store A into the byte at ptr (pointer storage). The register and CPU flags are
; unchanged.
 lda rowhigh,y                ; Load a value into A
; Book line 715: Load A with the byte at rowhigh plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 adc #0                       ; Add operand and carry to A
; Book line 716: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ptr+1                    ; Store A into memory
; Book line 717: Store A into the byte at ptr+1. The register and CPU flags are unchanged.
 lda drawbank                 ; Load a value into A; which screen is currently being drawn
; Book line 718: Load A with the byte at drawbank. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq screenptr_base_done      ; Branch when zero flag is set
; Book line 719: Branch to screenptr_base_done if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 720: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 lda ptr+1                    ; Load a value into A
; Book line 721: Load A with the byte at ptr+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 adc #$34                     ; Add operand and carry to A
; Book line 722: Add literal $34 (decimal 52) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ptr+1                    ; Store A into memory
; Book line 723: Store A into the byte at ptr+1. The register and CPU flags are unchanged.
screenptr_base_done:
; Book line 724: screenptr_base_done names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 rts                          ; Return from subroutine
; Book line 725: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Get pixel coordinate from screen coordinates
 enemycoords:
; Book line 728: enemycoords names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr coords                   ; Call a subroutine (return address saved on stack)
; Book line 729: Call coords, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda #0                       ; Load a value into A
; Book line 730: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta exhi                     ; Store A into memory; calculated alien pixel X high bit
; Book line 731: Store A into the byte at exhi. The register and CPU flags are unchanged.
 lda screenx                  ; Load a value into A; alien position in text columns
; Book line 732: Load A with the byte at screenx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 asl                          ; Shift left one bit
; Book line 733: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 rol exhi                     ; Rotate left through carry; calculated alien pixel X high bit
; Book line 734: Rotate the byte at exhi left through carry: old C enters bit 0 and old bit 7 becomes
; C. Update Z and N from the result.
 asl                          ; Shift left one bit
; Book line 735: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 rol exhi                     ; Rotate left through carry; calculated alien pixel X high bit
; Book line 736: Rotate the byte at exhi left through carry: old C enters bit 0 and old bit 7 becomes
; C. Update Z and N from the result.
 asl                          ; Shift left one bit
; Book line 737: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 rol exhi                     ; Rotate left through carry; calculated alien pixel X high bit
; Book line 738: Rotate the byte at exhi left through carry: old C enters bit 0 and old bit 7 becomes
; C. Update Z and N from the result.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 739: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #24                      ; Add operand and carry to A
; Book line 740: Add literal 24 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ex                       ; Store A into memory; calculated alien pixel X low byte
; Book line 741: Store A into the byte at ex. The register and CPU flags are unchanged.
 lda exhi                     ; Load a value into A; calculated alien pixel X high bit
; Book line 742: Load A with the byte at exhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 adc #0                       ; Add operand and carry to A
; Book line 743: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta exhi                     ; Store A into memory; calculated alien pixel X high bit
; Book line 744: Store A into the byte at exhi. The register and CPU flags are unchanged.
 lda screeny                  ; Load a value into A; alien position in text rows
; Book line 745: Load A with the byte at screeny. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 asl                          ; Shift left one bit
; Book line 746: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 asl                          ; Shift left one bit
; Book line 747: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 asl                          ; Shift left one bit
; Book line 748: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 749: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #50                      ; Add operand and carry to A
; Book line 750: Add literal 50 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ey                       ; Store A into memory; calculated alien pixel Y
; Book line 751: Store A into the byte at ey. The register and CPU flags are unchanged.
 rts                          ; Return from subroutine
; Book line 752: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; redraw whole playfield formation, avoiding the HUD and ship zone

; ---------------------------------------------------------------------------
; PAINT: Choose whether this frame should redraw the hidden buffer.
; ---------------------------------------------------------------------------
paint:
; Book line 759: paint names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda tick                     ; Load a value into A; frame counter used for timing
; Book line 760: Load A with the byte at tick (frame clock). Z records a zero value; N copies bit 7.
; Carry is unchanged.
 and #1                       ; Mask A to keep selected bits
; Book line 761: Keep only bits set in both A and literal 1. Save the result in A and update Z and N;
; carry is unchanged.
 beq paint_force              ; Branch when zero flag is set
; Book line 762: Branch to paint_force if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jsr sprites                  ; Call a subroutine (return address saved on stack)
; Book line 763: Call sprites, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 rts                          ; Return from subroutine
; Book line 764: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ---------------------------------------------------------------------------
; PAINT_FORCE: Render the hidden screen: clear, paint aliens, HUD, set sprite pointers, then switch visible screen bank.
; ---------------------------------------------------------------------------
paint_force:
; Book line 769: paint_force names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ; Render complete formation into the hidden screen, then flip.
 lda screenbank               ; Load a value into A; which screen is currently visible (double buffering)
; Book line 771: Load A with the byte at screenbank. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 eor #1                       ; Toggle selected bits in A
; Book line 772: Toggle A bits selected by literal 1. Save the result in A and update Z and N; carry
; is unchanged.
 sta drawbank                 ; Store A into memory; which screen is currently being drawn
; Book line 773: Store A into the byte at drawbank. The register and CPU flags are unchanged.
 ; Set base screen high byte: $04 or $0c
 lda drawbank                 ; Load a value into A; which screen is currently being drawn
; Book line 775: Load A with the byte at drawbank. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq clear_screen_a           ; Branch when zero flag is set
; Book line 776: Branch to clear_screen_a if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #$38                     ; Load a value into A
; Book line 777: Load A with literal $38 (decimal 56). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne clear_screen_set         ; Branch when zero flag is clear
; Book line 778: Branch to clear_screen_set if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.

; ---------------------------------------------------------------------------
; CLEAR_SCREEN_A: Set up the correct screen-buffer base address for clearing.
; ---------------------------------------------------------------------------
clear_screen_a:
; Book line 783: clear_screen_a names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #$04                     ; Load a value into A
; Book line 784: Load A with literal $04 (decimal 4). Z records a zero value; N copies bit 7. Carry is
; unchanged.
clear_screen_set:
; Book line 785: clear_screen_set names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 sta ptr+1                    ; Store A into memory
; Book line 786: Store A into the byte at ptr+1. The register and CPU flags are unchanged.
 lda #0                       ; Load a value into A
; Book line 787: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ptr                      ; Store A into memory
; Book line 788: Store A into the byte at ptr (pointer storage). The register and CPU flags are
; unchanged.
 ldx #4                       ; Load a value into X
; Book line 789: Load X with literal 4. Z records a zero value; N copies bit 7. Carry is unchanged.

; ---------------------------------------------------------------------------
; CLEAR_SCREEN_PAGES: Clear screen RAM in chunks of 256 bytes, writing blank screen codes.
; ---------------------------------------------------------------------------
clear_screen_pages:
; Book line 794: clear_screen_pages names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 ldy #0                       ; Load a value into Y
; Book line 795: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 lda #$20                     ; Load a value into A
; Book line 796: Load A with literal $20 (decimal 32). Z records a zero value; N copies bit 7. Carry
; is unchanged.
clear_screen_bytes:
; Book line 797: clear_screen_bytes names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 sta (ptr),y                  ; Store A into memory
; Book line 798: Store A into the byte at the address in zero-page pair ptr and its next byte, plus Y.
; The register and CPU flags are unchanged.
 iny                          ; Increase Y by 1
; Book line 799: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne clear_screen_bytes       ; Branch when zero flag is clear
; Book line 800: Branch to clear_screen_bytes if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 inc ptr+1                    ; Increase memory byte by 1
; Book line 801: Increase the byte at ptr+1 by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 dex                          ; Decrease X by 1
; Book line 802: Decrease X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne clear_screen_pages       ; Branch when zero flag is clear
; Book line 803: Branch to clear_screen_pages if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 ; Regenerate HUD in BOTH buffers after clearing the hidden screen.
 ; Copying from $0400 fails whenever $0400 itself was just cleared.
 jsr hud                      ; Call a subroutine (return address saved on stack)
; Book line 806: Call hud, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 ldx #0                       ; Load a value into X
; Book line 807: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.


; ---------------------------------------------------------------------------
; PAINTALIENS: Loop over all 46 aliens, skipping destroyed ones and the currently diving alien.
; ---------------------------------------------------------------------------
paintaliens:
; Book line 813: paintaliens names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda alive,x                  ; Load a value into A
; Book line 814: Load A with the byte at alive (formation membership table) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 bne +                        ; Branch when zero flag is clear
; Book line 815: Branch to + if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp paintnext                ; Jump unconditionally
; Book line 816: Continue execution at paintnext without saving a return address. Registers and flags
; are unchanged by the jump itself.
+ lda diveon
; Book line 817: The + is an anonymous forward label. Load A with the byte at diveon. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 beq paintdraw                ; Branch when zero flag is set
; Book line 818: Branch to paintdraw if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cpx diveindex                ; Compare X against operand; index of the alien selected for a dive
; Book line 819: Compare X with the byte at diveindex without changing X. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 bne paintdraw                ; Branch when zero flag is clear
; Book line 820: Branch to paintdraw if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp paintnext                ; Jump unconditionally
; Book line 821: Continue execution at paintnext without saving a return address. Registers and flags
; are unchanged by the jump itself.

; ---------------------------------------------------------------------------
; PAINTDRAW: Select the correct custom character tiles and colour for this alien row and animation frame.
; ---------------------------------------------------------------------------
paintdraw:
; Book line 826: paintdraw names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr coords                   ; Call a subroutine (return address saved on stack)
; Book line 827: Call coords, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda screenx                  ; Load a value into A; alien position in text columns
; Book line 828: Load A with the byte at screenx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #39                      ; Compare A against operand
; Book line 829: Compare A with literal 39 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc +                        ; Branch when carry is clear
; Book line 830: Branch to + if C is 0; otherwise continue at the next instruction. Test the current
; flag, and leave all flags unchanged.
 jmp paintnext                ; Jump unconditionally
; Book line 831: Continue execution at paintnext without saving a return address. Registers and flags
; are unchanged by the jump itself.
+ jsr screenptr
; Book line 832: The + is an anonymous forward label. Call screenptr, saving a return address on the
; stack. Its RTS resumes after this call. A, X, Y and flags are not automatically preserved by a call.
 ldy #0                       ; Load a value into Y
; Book line 833: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 lda rownum                   ; Load a value into A; formation row for the current alien
; Book line 834: Load A with the byte at rownum. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #4                       ; Compare A against operand
; Book line 835: Compare A with literal 4 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq flagchar                 ; Branch when zero flag is set
; Book line 836: Branch to flagchar if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #3                       ; Compare A against operand
; Book line 837: Compare A with literal 3 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq redchar                  ; Branch when zero flag is set
; Book line 838: Branch to redchar if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #0                       ; Compare A against operand
; Book line 839: Compare A with literal 0 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq cyanchar                 ; Branch when zero flag is set
; Book line 840: Branch to cyanchar if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #$b0                     ; Load a value into A
; Book line 841: Load A with literal $b0 (decimal 176). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne putchar                  ; Branch when zero flag is clear
; Book line 842: Branch to putchar if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
cyanchar:
; Book line 843: cyanchar names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #$a0                     ; Load a value into A
; Book line 844: Load A with literal $a0 (decimal 160). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne putchar                  ; Branch when zero flag is clear
; Book line 845: Branch to putchar if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
redchar:
; Book line 846: redchar names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #$b8                     ; Load a value into A
; Book line 847: Load A with literal $b8 (decimal 184). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne putchar                  ; Branch when zero flag is clear
; Book line 848: Branch to putchar if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
flagchar:
; Book line 849: flagchar names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #$c0                     ; Load a value into A
; Book line 850: Load A with literal $c0 (decimal 192). Z records a zero value; N copies bit 7. Carry
; is unchanged.

; ---------------------------------------------------------------------------
; PUTCHAR: Write an alien tile into screen RAM and its matching colour into colour RAM.
; ---------------------------------------------------------------------------
putchar:
; Book line 855: putchar names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ; 2x2 character alien, two frames per colour
 pha
; Book line 857: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 lda tick                     ; Load a value into A; frame counter used for timing
; Book line 858: Load A with the byte at tick (frame clock). Z records a zero value; N copies bit 7.
; Carry is unchanged.
 and #8                       ; Mask A to keep selected bits
; Book line 859: Keep only bits set in both A and literal 8. Save the result in A and update Z and N;
; carry is unchanged.
 beq wingstill                ; Branch when zero flag is set
; Book line 860: Branch to wingstill if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 pla
; Book line 861: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 862: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$04                     ; Add operand and carry to A
; Book line 863: Add literal $04 (decimal 4) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 jmp wingput                  ; Jump unconditionally
; Book line 864: Continue execution at wingput without saving a return address. Registers and flags
; are unchanged by the jump itself.

; ---------------------------------------------------------------------------
; WINGSTILL: Choose the alternative wing animation frame.
; ---------------------------------------------------------------------------
wingstill:
; Book line 869: wingstill names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 pla
; Book line 870: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.

; ---------------------------------------------------------------------------
; WINGPUT: Place the 2×2-character (16×16-pixel) alien tiles.
; ---------------------------------------------------------------------------
wingput:
; Book line 875: wingput names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 sta tilebase                 ; Store A into memory; first custom character code for current alien artwork
; Book line 876: Store A into the byte at tilebase. The register and CPU flags are unchanged.
 ldy #0                       ; Load a value into Y
; Book line 877: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta (ptr),y                  ; Store A into memory
; Book line 878: Store A into the byte at the address in zero-page pair ptr and its next byte, plus Y.
; The register and CPU flags are unchanged.
 iny                          ; Increase Y by 1
; Book line 879: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 880: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #1                       ; Add operand and carry to A
; Book line 881: Add literal 1 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta (ptr),y                  ; Store A into memory
; Book line 882: Store A into the byte at the address in zero-page pair ptr and its next byte, plus Y.
; The register and CPU flags are unchanged.
 ; second tile row, pointer += 40
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 884: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 lda ptr                      ; Load a value into A
; Book line 885: Load A with the byte at ptr (pointer storage). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 adc #40                      ; Add operand and carry to A
; Book line 886: Add literal 40 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ptr                      ; Store A into memory
; Book line 887: Store A into the byte at ptr (pointer storage). The register and CPU flags are
; unchanged.
 lda ptr+1                    ; Load a value into A
; Book line 888: Load A with the byte at ptr+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 adc #0                       ; Add operand and carry to A
; Book line 889: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ptr+1                    ; Store A into memory
; Book line 890: Store A into the byte at ptr+1. The register and CPU flags are unchanged.
 lda tilebase                 ; Load a value into A; first custom character code for current alien artwork
; Book line 891: Load A with the byte at tilebase. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 892: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #2                       ; Add operand and carry to A
; Book line 893: Add literal 2 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 ldy #0                       ; Load a value into Y
; Book line 894: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta (ptr),y                  ; Store A into memory
; Book line 895: Store A into the byte at the address in zero-page pair ptr and its next byte, plus Y.
; The register and CPU flags are unchanged.
 iny                          ; Increase Y by 1
; Book line 896: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 897: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #1                       ; Add operand and carry to A
; Book line 898: Add literal 1 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta (ptr),y                  ; Store A into memory
; Book line 899: Store A into the byte at the address in zero-page pair ptr and its next byte, plus Y.
; The register and CPU flags are unchanged.
 ldy screeny                  ; Load a value into Y; alien position in text rows
; Book line 900: Load Y with the byte at screeny. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda colorlow,y               ; Load a value into A
; Book line 901: Load A with the byte at colorlow plus index Y. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta cptr                     ; Store A into memory
; Book line 902: Store A into the byte at cptr (colour pointer storage). The register and CPU flags
; are unchanged.
 lda colorhigh,y              ; Load a value into A
; Book line 903: Load A with the byte at colorhigh plus index Y. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta cptr+1                   ; Store A into memory
; Book line 904: Store A into the byte at cptr+1. The register and CPU flags are unchanged.
 ldy screenx                  ; Load a value into Y; alien position in text columns
; Book line 905: Load Y with the byte at screenx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 txa                          ; Copy X into A
; Book line 906: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
 pha
; Book line 907: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 ldx rownum                   ; Load a value into X; formation row for the current alien
; Book line 908: Load X with the byte at rownum. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda colors,x                 ; Load a value into A
; Book line 909: Load A with the byte at colors plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta tilecolor                ; Store A into memory; colour RAM value for current alien
; Book line 910: Store A into the byte at tilecolor. The register and CPU flags are unchanged.
 ldy screenx                  ; Load a value into Y; alien position in text columns
; Book line 911: Load Y with the byte at screenx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta (cptr),y                 ; Store A into memory
; Book line 912: Store A into the byte at the address in zero-page pair cptr and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny                          ; Increase Y by 1
; Book line 913: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 sta (cptr),y                 ; Store A into memory
; Book line 914: Store A into the byte at the address in zero-page pair cptr and its next byte, plus
; Y. The register and CPU flags are unchanged.
 ; color second tile row
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 916: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 lda cptr                     ; Load a value into A
; Book line 917: Load A with the byte at cptr (colour pointer storage). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 adc #40                      ; Add operand and carry to A
; Book line 918: Add literal 40 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta cptr                     ; Store A into memory
; Book line 919: Store A into the byte at cptr (colour pointer storage). The register and CPU flags
; are unchanged.
 lda cptr+1                   ; Load a value into A
; Book line 920: Load A with the byte at cptr+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 adc #0                       ; Add operand and carry to A
; Book line 921: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta cptr+1                   ; Store A into memory
; Book line 922: Store A into the byte at cptr+1. The register and CPU flags are unchanged.
 ldy screenx                  ; Load a value into Y; alien position in text columns
; Book line 923: Load Y with the byte at screenx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda tilecolor                ; Load a value into A; colour RAM value for current alien
; Book line 924: Load A with the byte at tilecolor. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta (cptr),y                 ; Store A into memory
; Book line 925: Store A into the byte at the address in zero-page pair cptr and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny                          ; Increase Y by 1
; Book line 926: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 sta (cptr),y                 ; Store A into memory
; Book line 927: Store A into the byte at the address in zero-page pair cptr and its next byte, plus
; Y. The register and CPU flags are unchanged.
 pla
; Book line 928: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 tax                          ; Copy A into X
; Book line 929: Copy A to X; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
paintnext:
; Book line 930: paintnext names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 inx                          ; Increase X by 1
; Book line 931: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #46                      ; Compare X against operand
; Book line 932: Compare X with literal 46 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq paintdone                ; Branch when zero flag is set
; Book line 933: Branch to paintdone if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp paintaliens              ; Jump unconditionally
; Book line 934: Continue execution at paintaliens without saving a return address. Registers and
; flags are unchanged by the jump itself.

; ---------------------------------------------------------------------------
; PAINTDONE: Finish drawing and swap the screen displayed by the VIC-II.
; ---------------------------------------------------------------------------
paintdone:
; Book line 939: paintdone names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda drawbank                 ; Load a value into A; which screen is currently being drawn
; Book line 940: Load A with the byte at drawbank. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta screenbank               ; Store A into memory; which screen is currently visible (double buffering)
; Book line 941: Store A into the byte at screenbank. The register and CPU flags are unchanged.
 beq show_a                   ; Branch when zero flag is set
; Book line 942: Branch to show_a if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #$e8                     ; Load a value into A
; Book line 943: Load A with literal $e8 (decimal 232). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne show_set                 ; Branch when zero flag is clear
; Book line 944: Branch to show_set if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
show_a:
; Book line 945: show_a names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #$18                     ; Load a value into A
; Book line 946: Load A with literal $18 (decimal 24). Z records a zero value; N copies bit 7. Carry
; is unchanged.
show_set:
; Book line 947: show_set names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 pha
; Book line 948: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 ; The hidden screen's $3bf8 sprite pointers were erased by clearing it.
 ; Install pointers BEFORE exposing the buffer to the VIC-II.
 jsr sprites                  ; Call a subroutine (return address saved on stack)
; Book line 951: Call sprites, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 pla
; Book line 952: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 sta $d018                    ; Store A into memory; screen and character-set base selector
; Book line 953: Store A into the byte at $d018 (VIC screen and font selection). The register and CPU
; flags are unchanged.
 rts                          ; Return from subroutine
; Book line 954: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ---------------------------------------------------------------------------
; HUD_HIDDEN: Draw HUD text and digits into the hidden screen so the display swap does not flicker.
; ---------------------------------------------------------------------------
hud_hidden:
; Book line 960: hud_hidden names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ldx #0                       ; Load a value into X
; Book line 961: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
hud_hidden_loop:
; Book line 962: hud_hidden_loop names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda $0400,x                  ; Load a value into A
; Book line 963: Load A with the byte at $0400 (screen RAM in the $0400 screen) plus index X. Z
; records a zero value; N copies bit 7. Carry is unchanged.
 ldy drawbank                 ; Load a value into Y; which screen is currently being drawn
; Book line 964: Load Y with the byte at drawbank. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq hud_hidden_a             ; Branch when zero flag is set
; Book line 965: Branch to hud_hidden_a if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta $3800,x                  ; Store A into memory
; Book line 966: Store A into the byte at $3800 plus index X. The register and CPU flags are
; unchanged.
 jmp hud_hidden_next          ; Jump unconditionally
; Book line 967: Continue execution at hud_hidden_next without saving a return address. Registers and
; flags are unchanged by the jump itself.
hud_hidden_a:
; Book line 968: hud_hidden_a names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 sta $0400,x                  ; Store A into memory
; Book line 969: Store A into the byte at $0400 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
hud_hidden_next:
; Book line 970: hud_hidden_next names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #1                       ; Load a value into A
; Book line 971: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d800,x                  ; Store A into memory
; Book line 972: Store A into the byte at $d800 (colour RAM) plus index X. The register and CPU flags
; are unchanged.
 inx                          ; Increase X by 1
; Book line 973: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #40                      ; Compare X against operand
; Book line 974: Compare X with literal 40 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne hud_hidden_loop          ; Branch when zero flag is clear
; Book line 975: Branch to hud_hidden_loop if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 rts                          ; Return from subroutine
; Book line 976: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ---------------------------------------------------------------------------
; SPRITES: Configure VIC-II hardware sprites: X/Y positions, sprite data pointers, multicolour flags, colours and enable mask.
; ---------------------------------------------------------------------------
sprites:
; Book line 982: sprites names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda shipx                    ; Load a value into A; player X position, low 8 bits
; Book line 983: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta $d000                    ; Store A into memory; sprite 0 X (player)
; Book line 984: Store A into the byte at $d000 (sprite 0 X low byte). The register and CPU flags are
; unchanged.
 lda #0                       ; Load a value into A
; Book line 985: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d010                    ; Store A into memory; ninth X-position bits for sprites 0–7
; Book line 986: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
 lda shipxhi                  ; Load a value into A; player X position, ninth bit
; Book line 987: Load A with the byte at shipxhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq sprite_x_done            ; Branch when zero flag is set
; Book line 988: Branch to sprite_x_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #1                       ; Load a value into A
; Book line 989: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d010                    ; Store A into memory; ninth X-position bits for sprites 0–7
; Book line 990: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
sprite_x_done:
; Book line 991: sprite_x_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda shotxhi                  ; Load a value into A; player laser X high bit
; Book line 992: Load A with the byte at shotxhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq shot_x_done              ; Branch when zero flag is set
; Book line 993: Branch to shot_x_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda $d010                    ; Load a value into A; ninth X-position bits for sprites 0–7
; Book line 994: Load A with the byte at $d010 (VIC sprite X high bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ora #4                       ; Set selected bits in A
; Book line 995: Set A bits present in either A or literal 4. Save the result in A and update Z and N;
; carry is unchanged.
 sta $d010                    ; Store A into memory; ninth X-position bits for sprites 0–7
; Book line 996: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
shot_x_done:
; Book line 997: shot_x_done names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda divexhi                  ; Load a value into A; diving alien ninth X bit
; Book line 998: Load A with the byte at divexhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq dive_x_done              ; Branch when zero flag is set
; Book line 999: Branch to dive_x_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda $d010                    ; Load a value into A; ninth X-position bits for sprites 0–7
; Book line 1000: Load A with the byte at $d010 (VIC sprite X high bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ora #2                       ; Set selected bits in A
; Book line 1001: Set A bits present in either A or literal 2. Save the result in A and update Z and
; N; carry is unchanged.
 sta $d010                    ; Store A into memory; ninth X-position bits for sprites 0–7
; Book line 1002: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
dive_x_done:
; Book line 1003: dive_x_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda enemyshotxhi             ; Load a value into A; enemy bullet ninth X bit
; Book line 1004: Load A with the byte at enemyshotxhi. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 beq enemy_x_done             ; Branch when zero flag is set
; Book line 1005: Branch to enemy_x_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda $d010                    ; Load a value into A; ninth X-position bits for sprites 0–7
; Book line 1006: Load A with the byte at $d010 (VIC sprite X high bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ora #8                       ; Set selected bits in A
; Book line 1007: Set A bits present in either A or literal 8. Save the result in A and update Z and
; N; carry is unchanged.
 sta $d010                    ; Store A into memory; ninth X-position bits for sprites 0–7
; Book line 1008: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
enemy_x_done:
; Book line 1009: enemy_x_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #219                     ; Load a value into A
; Book line 1010: Load A with literal 219. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d001                    ; Store A into memory; sprite 0 Y (player)
; Book line 1011: Store A into the byte at $d001 (sprite 0 Y coordinate). The register and CPU flags
; are unchanged.
 lda divex                    ; Load a value into A; diving alien X low byte
; Book line 1012: Load A with the byte at divex. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d002                    ; Store A into memory; sprite 1 X (diver)
; Book line 1013: Store A into the byte at $d002 (sprite 1 X low byte). The register and CPU flags are
; unchanged.
 lda divey                    ; Load a value into A; diving alien Y
; Book line 1014: Load A with the byte at divey. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d003                    ; Store A into memory; sprite 1 Y (diver)
; Book line 1015: Store A into the byte at $d003 (sprite 1 Y coordinate). The register and CPU flags
; are unchanged.
 lda shotx                    ; Load a value into A; player laser X low byte
; Book line 1016: Load A with the byte at shotx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d004                    ; Store A into memory; sprite 2 X (player laser)
; Book line 1017: Store A into the byte at $d004 (sprite 2 X low byte). The register and CPU flags are
; unchanged.
 lda shoty                    ; Load a value into A; player laser Y position
; Book line 1018: Load A with the byte at shoty. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d005                    ; Store A into memory; sprite 2 Y (player laser)
; Book line 1019: Store A into the byte at $d005 (sprite 2 Y coordinate). The register and CPU flags
; are unchanged.
 lda enemyshotx               ; Load a value into A; enemy bullet X low byte
; Book line 1020: Load A with the byte at enemyshotx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d006                    ; Store A into memory; sprite 3 X (enemy bullet)
; Book line 1021: Store A into the byte at $d006 (sprite 3 X low byte). The register and CPU flags are
; unchanged.
 lda enemyshoty               ; Load a value into A; enemy bullet Y position
; Book line 1022: Load A with the byte at enemyshoty. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d007                    ; Store A into memory; sprite 3 Y (enemy bullet)
; Book line 1023: Store A into the byte at $d007 (sprite 3 Y coordinate). The register and CPU flags
; are unchanged.
 lda #0                       ; Load a value into A
; Book line 1024: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d017                    ; no sprite Y expansion | Store A into memory; sprite vertical expansion mask
; Book line 1025: Store A into the byte at $d017 (VIC sprite height expansion). The register and CPU
; flags are unchanged.
 sta $d01d                    ; no sprite X expansion | Store A into memory; sprite horizontal expansion mask
; Book line 1026: Store A into the byte at $d01d (VIC sprite width expansion). The register and CPU
; flags are unchanged.
 sta $d01b                    ; sprites in front of characters | Store A into memory; sprite priority mask
; Book line 1027: Store A into the byte at $d01b (VIC sprite background priority). The register and
; CPU flags are unchanged.
 lda #$02                     ; Load a value into A
; Book line 1028: Load A with literal $02 (decimal 2). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d01c                    ; diving sprite uses 2-bit multicolour, others stay hires | Store A into memory; sprite multicolour mask
; Book line 1029: Store A into the byte at $d01c (VIC sprite multicolour bits). The register and CPU
; flags are unchanged.
 lda #$01                     ; Load a value into A
; Book line 1030: Load A with literal $01 (decimal 1). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d025                    ; shared white accent (01) | Store A into memory; shared sprite multicolour 1
; Book line 1031: Store A into the byte at $d025 (shared sprite multicolour 1). The register and CPU
; flags are unchanged.
 lda #$06                     ; Load a value into A
; Book line 1032: Load A with literal $06 (decimal 6). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d026                    ; shared blue outline (10) | Store A into memory; shared sprite multicolour 2
; Book line 1033: Store A into the byte at $d026 (shared sprite multicolour 2). The register and CPU
; flags are unchanged.
 lda #$c0                     ; Load a value into A
; Book line 1034: Load A with literal $c0 (decimal 192). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $3bf8                    ; Store A into memory
; Book line 1035: Store A into the byte at $3bf8. The register and CPU flags are unchanged.
 sta $07f8                    ; Store A into memory
; Book line 1036: Store A into the byte at $07f8 (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
 ; diving sprite selected by original alien row; clamp inactive index
 ldx diveindex                ; Load a value into X; index of the alien selected for a dive
; Book line 1038: Load X with the byte at diveindex. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cpx #46                      ; Compare X against operand
; Book line 1039: Compare X with literal 46 without changing X. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc dive_index_valid         ; Branch when carry is clear
; Book line 1040: Branch to dive_index_valid if C is 0; otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 ldx #0                       ; Load a value into X
; Book line 1041: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.

; ---------------------------------------------------------------------------
; DIVE_INDEX_VALID: Look up which sprite artwork matches the selected alien row.
; ---------------------------------------------------------------------------
dive_index_valid:
; Book line 1046: dive_index_valid names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 jsr coords                   ; Call a subroutine (return address saved on stack)
; Book line 1047: Call coords, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda rownum                   ; Load a value into A; formation row for the current alien
; Book line 1048: Load A with the byte at rownum. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 tax                          ; Copy A into X
; Book line 1049: Copy A to X; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda diveptrs,x               ; Load a value into A
; Book line 1050: Load A with the byte at diveptrs plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta $3bf9                    ; Store A into memory
; Book line 1051: Store A into the byte at $3bf9. The register and CPU flags are unchanged.
 sta $07f9                    ; Store A into memory
; Book line 1052: Store A into the byte at $07f9 (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
 lda #$c7                     ; sprite 2 laser at $31c0 | Load a value into A
; Book line 1053: Load A with literal $c7 (decimal 199). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $3bfa                    ; Store A into memory
; Book line 1054: Store A into the byte at $3bfa. The register and CPU flags are unchanged.
 sta $07fa                    ; Store A into memory
; Book line 1055: Store A into the byte at $07fa (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
 lda #$c6                     ; Load a value into A
; Book line 1056: Load A with literal $c6 (decimal 198). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $3bfb                    ; Store A into memory
; Book line 1057: Store A into the byte at $3bfb. The register and CPU flags are unchanged.
 sta $07fb                    ; Store A into memory
; Book line 1058: Store A into the byte at $07fb (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
 ; Dedicated explosion sprites, with pointers in BOTH screen buffers.
 ; Three-frame explosion animations: $c8-$ca alien, $cb-$cd ship.
 lda alienboom                ; Load a value into A; remaining frames in alien explosion animation
; Book line 1061: Load A with the byte at alienboom. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq alien_frame_end          ; Branch when zero flag is set
; Book line 1062: Branch to alien_frame_end if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #10                      ; Compare A against operand
; Book line 1063: Compare A with literal 10 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs alien_frame_early        ; Branch when carry is set
; Book line 1064: Branch to alien_frame_early if C is 1; otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 cmp #5                       ; Compare A against operand
; Book line 1065: Compare A with literal 5 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcs alien_frame_middle       ; Branch when carry is set
; Book line 1066: Branch to alien_frame_middle if C is 1; otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 lda #$ca                     ; Load a value into A
; Book line 1067: Load A with literal $ca (decimal 202). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne alien_frame_store        ; Branch when zero flag is clear
; Book line 1068: Branch to alien_frame_store if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.

; ---------------------------------------------------------------------------
; ALIEN_FRAME_EARLY: Choose first frame of the alien explosion.
; ---------------------------------------------------------------------------
alien_frame_early:
; Book line 1073: alien_frame_early names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #$c8                     ; Load a value into A
; Book line 1074: Load A with literal $c8 (decimal 200). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne alien_frame_store        ; Branch when zero flag is clear
; Book line 1075: Branch to alien_frame_store if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.

; ---------------------------------------------------------------------------
; ALIEN_FRAME_MIDDLE: Choose middle frame of the alien explosion.
; ---------------------------------------------------------------------------
alien_frame_middle:
; Book line 1080: alien_frame_middle names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #$c9                     ; Load a value into A
; Book line 1081: Load A with literal $c9 (decimal 201). Z records a zero value; N copies bit 7. Carry
; is unchanged.

; ---------------------------------------------------------------------------
; ALIEN_FRAME_STORE: Write the alien explosion sprite pointer into both screen buffers.
; ---------------------------------------------------------------------------
alien_frame_store:
; Book line 1086: alien_frame_store names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 sta $3bfc                    ; Store A into memory
; Book line 1087: Store A into the byte at $3bfc. The register and CPU flags are unchanged.
 sta $07fc                    ; Store A into memory
; Book line 1088: Store A into the byte at $07fc (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
alien_frame_end:
; Book line 1089: alien_frame_end names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda playerboom               ; Load a value into A; remaining frames in player explosion animation
; Book line 1090: Load A with the byte at playerboom. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq player_frame_end         ; Branch when zero flag is set
; Book line 1091: Branch to player_frame_end if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #15                      ; Compare A against operand
; Book line 1092: Compare A with literal 15 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs player_frame_early       ; Branch when carry is set
; Book line 1093: Branch to player_frame_early if C is 1; otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 cmp #8                       ; Compare A against operand
; Book line 1094: Compare A with literal 8 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcs player_frame_middle      ; Branch when carry is set
; Book line 1095: Branch to player_frame_middle if C is 1; otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 lda #$cd                     ; Load a value into A
; Book line 1096: Load A with literal $cd (decimal 205). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne player_frame_store       ; Branch when zero flag is clear
; Book line 1097: Branch to player_frame_store if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.

; ---------------------------------------------------------------------------
; PLAYER_FRAME_EARLY: Choose first frame of the player explosion.
; ---------------------------------------------------------------------------
player_frame_early:
; Book line 1102: player_frame_early names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #$cb                     ; Load a value into A
; Book line 1103: Load A with literal $cb (decimal 203). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne player_frame_store       ; Branch when zero flag is clear
; Book line 1104: Branch to player_frame_store if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.

; ---------------------------------------------------------------------------
; PLAYER_FRAME_MIDDLE: Choose middle frame of the player explosion.
; ---------------------------------------------------------------------------
player_frame_middle:
; Book line 1109: player_frame_middle names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #$cc                     ; Load a value into A
; Book line 1110: Load A with literal $cc (decimal 204). Z records a zero value; N copies bit 7. Carry
; is unchanged.

; ---------------------------------------------------------------------------
; PLAYER_FRAME_STORE: Write the player explosion sprite pointer into both screen buffers.
; ---------------------------------------------------------------------------
player_frame_store:
; Book line 1115: player_frame_store names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 sta $3bfd                    ; Store A into memory
; Book line 1116: Store A into the byte at $3bfd. The register and CPU flags are unchanged.
 sta $07fd                    ; Store A into memory
; Book line 1117: Store A into the byte at $07fd (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
player_frame_end:
; Book line 1118: player_frame_end names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda boomx                    ; Load a value into A; alien explosion X low byte
; Book line 1119: Load A with the byte at boomx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d008                    ; Store A into memory; sprite 4 X (alien explosion)
; Book line 1120: Store A into the byte at $d008 (sprite 4 X low byte). The register and CPU flags are
; unchanged.
 lda boomy                    ; Load a value into A; alien explosion Y
; Book line 1121: Load A with the byte at boomy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d009                    ; Store A into memory; sprite 4 Y (alien explosion)
; Book line 1122: Store A into the byte at $d009 (sprite 4 Y coordinate). The register and CPU flags
; are unchanged.
 ; V31: player explosion a further 2 pixels left and 2 pixels down.
 sec                          ; Set carry before subtraction
; Book line 1124: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda shipx                    ; Load a value into A; player X position, low 8 bits
; Book line 1125: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sbc #4                       ; Subtract operand and borrow from A
; Book line 1126: Subtract literal 4 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $d00a                    ; Store A into memory; sprite 5 X (player explosion)
; Book line 1127: Store A into the byte at $d00a (sprite 5 X low byte). The register and CPU flags are
; unchanged.
 lda shipxhi                  ; Load a value into A; player X position, ninth bit
; Book line 1128: Load A with the byte at shipxhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc #0                       ; Subtract operand and borrow from A
; Book line 1129: Subtract literal 0 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta playerboomxhi            ; Store A into memory; player explosion X high bit
; Book line 1130: Store A into the byte at playerboomxhi. The register and CPU flags are unchanged.
 lda #221                     ; Load a value into A
; Book line 1131: Load A with literal 221. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d00b                    ; Store A into memory; sprite 5 Y (player explosion)
; Book line 1132: Store A into the byte at $d00b (sprite 5 Y coordinate). The register and CPU flags
; are unchanged.
 ; Alien sparks alternate yellow/orange; ship flash white/red/yellow.
 lda alienboom                ; Load a value into A; remaining frames in alien explosion animation
; Book line 1134: Load A with the byte at alienboom. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #$04                     ; Mask A to keep selected bits
; Book line 1135: Keep only bits set in both A and literal $04 (decimal 4). Save the result in A and
; update Z and N; carry is unchanged.
 beq alien_spark_yellow       ; Branch when zero flag is set
; Book line 1136: Branch to alien_spark_yellow if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 lda #8                       ; Load a value into A
; Book line 1137: Load A with literal 8. Z records a zero value; N copies bit 7. Carry is unchanged.
 bne alien_spark_color        ; Branch when zero flag is clear
; Book line 1138: Branch to alien_spark_color if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
alien_spark_yellow:
; Book line 1139: alien_spark_yellow names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #7                       ; Load a value into A
; Book line 1140: Load A with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.

; ---------------------------------------------------------------------------
; ALIEN_SPARK_COLOR: Set the colour of the current alien explosion frame.
; ---------------------------------------------------------------------------
alien_spark_color:
; Book line 1145: alien_spark_color names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 sta $d02b                    ; Store A into memory
; Book line 1146: Store A into the byte at $d02b (sprite 4 colour). The register and CPU flags are
; unchanged.
 lda playerboom               ; Load a value into A; remaining frames in player explosion animation
; Book line 1147: Load A with the byte at playerboom. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #$04                     ; Mask A to keep selected bits
; Book line 1148: Keep only bits set in both A and literal $04 (decimal 4). Save the result in A and
; update Z and N; carry is unchanged.
 beq player_spark_white       ; Branch when zero flag is set
; Book line 1149: Branch to player_spark_white if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 lda #2                       ; Load a value into A
; Book line 1150: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
 bne player_spark_color       ; Branch when zero flag is clear
; Book line 1151: Branch to player_spark_color if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
player_spark_white:
; Book line 1152: player_spark_white names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #1                       ; Load a value into A
; Book line 1153: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.

; ---------------------------------------------------------------------------
; PLAYER_SPARK_COLOR: Set the colour of the current player explosion frame.
; ---------------------------------------------------------------------------
player_spark_color:
; Book line 1158: player_spark_color names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 sta $d02c                    ; Store A into memory
; Book line 1159: Store A into the byte at $d02c (sprite 5 colour). The register and CPU flags are
; unchanged.
 ; Sprite 4 and 5 ninth X bits.
 lda boomxhi                  ; Load a value into A; alien explosion X high bit
; Book line 1161: Load A with the byte at boomxhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq boom_low_x               ; Branch when zero flag is set
; Book line 1162: Branch to boom_low_x if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda $d010                    ; Load a value into A; ninth X-position bits for sprites 0–7
; Book line 1163: Load A with the byte at $d010 (VIC sprite X high bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ora #$10                     ; Set selected bits in A
; Book line 1164: Set A bits present in either A or literal $10 (decimal 16). Save the result in A and
; update Z and N; carry is unchanged.
 sta $d010                    ; Store A into memory; ninth X-position bits for sprites 0–7
; Book line 1165: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.

; ---------------------------------------------------------------------------
; BOOM_LOW_X: Set bit 4 of the sprite-X MSB register when the alien explosion crosses pixel 255.
; ---------------------------------------------------------------------------
boom_low_x:
; Book line 1170: boom_low_x names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda playerboomxhi            ; Load a value into A; player explosion X high bit
; Book line 1171: Load A with the byte at playerboomxhi. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 beq player_low_x             ; Branch when zero flag is set
; Book line 1172: Branch to player_low_x if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda $d010                    ; Load a value into A; ninth X-position bits for sprites 0–7
; Book line 1173: Load A with the byte at $d010 (VIC sprite X high bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ora #$20                     ; Set selected bits in A
; Book line 1174: Set A bits present in either A or literal $20 (decimal 32). Save the result in A and
; update Z and N; carry is unchanged.
 sta $d010                    ; Store A into memory; ninth X-position bits for sprites 0–7
; Book line 1175: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.

; ---------------------------------------------------------------------------
; PLAYER_LOW_X: Set bit 5 of the sprite-X MSB register when the player explosion crosses pixel 255.
; ---------------------------------------------------------------------------
player_low_x:
; Book line 1180: player_low_x names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #7                       ; Load a value into A
; Book line 1181: Load A with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d027                    ; Store A into memory
; Book line 1182: Store A into the byte at $d027 (sprite 0 colour). The register and CPU flags are
; unchanged.
 ldx rownum                   ; Load a value into X; formation row for the current alien
; Book line 1183: Load X with the byte at rownum. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda divecolors,x             ; Load a value into A
; Book line 1184: Load A with the byte at divecolors plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $d028                    ; Store A into memory
; Book line 1185: Store A into the byte at $d028 (sprite 1 colour). The register and CPU flags are
; unchanged.
 lda #1                       ; Load a value into A
; Book line 1186: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d029                    ; Store A into memory
; Book line 1187: Store A into the byte at $d029 (sprite 2 colour). The register and CPU flags are
; unchanged.
 lda #10                      ; Load a value into A
; Book line 1188: Load A with literal 10. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d02a                    ; Store A into memory
; Book line 1189: Store A into the byte at $d02a (sprite 3 colour). The register and CPU flags are
; unchanged.
 lda #1                       ; Load a value into A
; Book line 1190: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta spritemask               ; Store A into memory; bitmask of enabled hardware sprites
; Book line 1191: Store A into the byte at spritemask. The register and CPU flags are unchanged.
 lda diveon                   ; Load a value into A; nonzero while a dive is active
; Book line 1192: Load A with the byte at diveon. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq spn1                     ; Branch when zero flag is set
; Book line 1193: Branch to spn1 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda spritemask               ; Load a value into A; bitmask of enabled hardware sprites
; Book line 1194: Load A with the byte at spritemask. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ora #2                       ; Set selected bits in A
; Book line 1195: Set A bits present in either A or literal 2. Save the result in A and update Z and
; N; carry is unchanged.
 sta spritemask               ; Store A into memory; bitmask of enabled hardware sprites
; Book line 1196: Store A into the byte at spritemask. The register and CPU flags are unchanged.
spn1:
; Book line 1197: spn1 names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ldx shoton                   ; Load a value into X; nonzero while player laser is active
; Book line 1198: Load X with the byte at shoton. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq spn2                     ; Branch when zero flag is set
; Book line 1199: Branch to spn2 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda spritemask               ; Load a value into A; bitmask of enabled hardware sprites
; Book line 1200: Load A with the byte at spritemask. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ora #4                       ; Set selected bits in A
; Book line 1201: Set A bits present in either A or literal 4. Save the result in A and update Z and
; N; carry is unchanged.
 sta spritemask               ; Store A into memory; bitmask of enabled hardware sprites
; Book line 1202: Store A into the byte at spritemask. The register and CPU flags are unchanged.
spn2:
; Book line 1203: spn2 names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ldx enemyshoton              ; Load a value into X; nonzero while enemy bullet is active
; Book line 1204: Load X with the byte at enemyshoton. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 beq spn3                     ; Branch when zero flag is set
; Book line 1205: Branch to spn3 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda spritemask               ; Load a value into A; bitmask of enabled hardware sprites
; Book line 1206: Load A with the byte at spritemask. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ora #8                       ; Set selected bits in A
; Book line 1207: Set A bits present in either A or literal 8. Save the result in A and update Z and
; N; carry is unchanged.
 sta spritemask               ; Store A into memory; bitmask of enabled hardware sprites
; Book line 1208: Store A into the byte at spritemask. The register and CPU flags are unchanged.
spn3:
; Book line 1209: spn3 names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda alienboom                ; Load a value into A; remaining frames in alien explosion animation
; Book line 1210: Load A with the byte at alienboom. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq no_alien_boom            ; Branch when zero flag is set
; Book line 1211: Branch to no_alien_boom if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda spritemask               ; Load a value into A; bitmask of enabled hardware sprites
; Book line 1212: Load A with the byte at spritemask. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ora #$10                     ; Set selected bits in A
; Book line 1213: Set A bits present in either A or literal $10 (decimal 16). Save the result in A and
; update Z and N; carry is unchanged.
 sta spritemask               ; Store A into memory; bitmask of enabled hardware sprites
; Book line 1214: Store A into the byte at spritemask. The register and CPU flags are unchanged.

; ---------------------------------------------------------------------------
; NO_ALIEN_BOOM: Include the alien explosion sprite in the enable mask only while its timer is nonzero.
; ---------------------------------------------------------------------------
no_alien_boom:
; Book line 1219: no_alien_boom names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda playerboom               ; Load a value into A; remaining frames in player explosion animation
; Book line 1220: Load A with the byte at playerboom. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq no_player_boom           ; Branch when zero flag is set
; Book line 1221: Branch to no_player_boom if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda spritemask               ; Load a value into A; bitmask of enabled hardware sprites
; Book line 1222: Load A with the byte at spritemask. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ora #$20                     ; Set selected bits in A
; Book line 1223: Set A bits present in either A or literal $20 (decimal 32). Save the result in A and
; update Z and N; carry is unchanged.
 sta spritemask               ; Store A into memory; bitmask of enabled hardware sprites
; Book line 1224: Store A into the byte at spritemask. The register and CPU flags are unchanged.

; ---------------------------------------------------------------------------
; NO_PLAYER_BOOM: Include the player explosion sprite in the enable mask only while its timer is nonzero.
; ---------------------------------------------------------------------------
no_player_boom:
; Book line 1229: no_player_boom names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda spritemask               ; Load a value into A; bitmask of enabled hardware sprites
; Book line 1230: Load A with the byte at spritemask. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d015                    ; Store A into memory; sprite enable bitmask
; Book line 1231: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 rts                          ; Return from subroutine
; Book line 1232: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ---------------------------------------------------------------------------
; CHECKHITS: Test player laser against diving aliens and formation aliens, then enemy projectiles and ship collisions.
; ---------------------------------------------------------------------------
checkhits:
; Book line 1238: checkhits names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda shoton                   ; Load a value into A; nonzero while player laser is active
; Book line 1239: Load A with the byte at shoton. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bne checkdiveshot            ; Branch when zero flag is clear
; Book line 1240: Branch to checkdiveshot if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 jmp enemyhitplayer           ; Jump unconditionally
; Book line 1241: Continue execution at enemyhitplayer without saving a return address. Registers and
; flags are unchanged by the jump itself.

; ---------------------------------------------------------------------------
; CHECKDIVESHOT: Check whether the player laser overlaps the currently diving alien.
; ---------------------------------------------------------------------------
checkdiveshot:
; Book line 1246: checkdiveshot names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda diveon                   ; Load a value into A; nonzero while a dive is active
; Book line 1247: Load A with the byte at diveon. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq hitformation             ; Branch when zero flag is set
; Book line 1248: Branch to hitformation if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ; Bullet graphic is at shotx+11, dive sprite visible from divex+4 to +19.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1250: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 lda shotx                    ; Load a value into A; player laser X low byte
; Book line 1251: Load A with the byte at shotx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 adc #11                      ; Add operand and carry to A
; Book line 1252: Add literal 11 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta tmpx                     ; Store A into memory
; Book line 1253: Store A into the byte at tmpx. The register and CPU flags are unchanged.
 lda shotxhi                  ; Load a value into A; player laser X high bit
; Book line 1254: Load A with the byte at shotxhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 adc #0                       ; Add operand and carry to A
; Book line 1255: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta tmpx+1                   ; Store A into memory
; Book line 1256: Store A into the byte at tmpx+1. The register and CPU flags are unchanged.
 sec                          ; Set carry before subtraction
; Book line 1257: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda tmpx                     ; Load a value into A
; Book line 1258: Load A with the byte at tmpx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc divex                    ; Subtract operand and borrow from A; diving alien X low byte
; Book line 1259: Subtract the byte at divex and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta hitdx                    ; Store A into memory
; Book line 1260: Store A into the byte at hitdx. The register and CPU flags are unchanged.
 lda tmpx+1                   ; Load a value into A
; Book line 1261: Load A with the byte at tmpx+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc divexhi                  ; Subtract operand and borrow from A; diving alien ninth X bit
; Book line 1262: Subtract the byte at divexhi and (1 minus incoming carry) from A. Update C, Z, N and
; V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 bne hitformation             ; Branch when zero flag is clear
; Book line 1263: Branch to hitformation if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 lda hitdx                    ; Load a value into A
; Book line 1264: Load A with the byte at hitdx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #4                       ; Compare A against operand
; Book line 1265: Compare A with literal 4 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc hitformation             ; Branch when carry is clear
; Book line 1266: Branch to hitformation if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 cmp #20                      ; Compare A against operand
; Book line 1267: Compare A with literal 20 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs hitformation             ; Branch when carry is set
; Book line 1268: Branch to hitformation if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 ; Bullet spans shoty+6 through shoty+18; dive body divey+3..+17.
 lda shoty                    ; Load a value into A; player laser Y position
; Book line 1270: Load A with the byte at shoty. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1271: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #18                      ; Add operand and carry to A
; Book line 1272: Add literal 18 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp divey                    ; Compare A against operand; diving alien Y
; Book line 1273: Compare A with the byte at divey without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc hitformation             ; Branch when carry is clear
; Book line 1274: Branch to hitformation if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 lda divey                    ; Load a value into A; diving alien Y
; Book line 1275: Load A with the byte at divey. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1276: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #17                      ; Add operand and carry to A
; Book line 1277: Add literal 17 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp shoty                    ; Compare A against operand; player laser Y position
; Book line 1278: Compare A with the byte at shoty without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc hitformation             ; Branch when carry is clear
; Book line 1279: Branch to hitformation if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 ldx diveindex                ; Load a value into X; index of the alien selected for a dive
; Book line 1280: Load X with the byte at diveindex. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 jsr coords                   ; Call a subroutine (return address saved on stack)
; Book line 1281: Call coords, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr destroy                  ; Call a subroutine (return address saved on stack)
; Book line 1282: Call destroy, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda #0                       ; Load a value into A
; Book line 1283: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta diveon                   ; Store A into memory; nonzero while a dive is active
; Book line 1284: Store A into the byte at diveon. The register and CPU flags are unchanged.
 jmp enemyhitplayer           ; Jump unconditionally
; Book line 1285: Continue execution at enemyhitplayer without saving a return address. Registers and
; flags are unchanged by the jump itself.

; ---------------------------------------------------------------------------
; HITFORMATION: Search the remaining formation aliens for a laser hit.
; ---------------------------------------------------------------------------
hitformation:
; Book line 1290: hitformation names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ldx #0                       ; Load a value into X
; Book line 1291: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.

; ---------------------------------------------------------------------------
; HITLOOP: Iterate through formation slots; skip inactive aliens.
; ---------------------------------------------------------------------------
hitloop:
; Book line 1296: hitloop names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda alive,x                  ; Load a value into A
; Book line 1297: Load A with the byte at alive (formation membership table) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 beq hitnext                  ; Branch when zero flag is set
; Book line 1298: Branch to hitnext if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda diveon                   ; Load a value into A; nonzero while a dive is active
; Book line 1299: Load A with the byte at diveon. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq hittry                   ; Branch when zero flag is set
; Book line 1300: Branch to hittry if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cpx diveindex                ; Compare X against operand; index of the alien selected for a dive
; Book line 1301: Compare X with the byte at diveindex without changing X. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 beq hitnext                  ; Branch when zero flag is set
; Book line 1302: Branch to hitnext if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.

; ---------------------------------------------------------------------------
; HITTRY: Compare the laser position against the current alien hit box.
; ---------------------------------------------------------------------------
hittry:
; Book line 1307: hittry names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr enemycoords              ; Call a subroutine (return address saved on stack)
; Book line 1308: Call enemycoords, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 ; Actual projectile centre X is shotx+11 (sprite graphic at bit 11).
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1310: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 lda shotx                    ; Load a value into A; player laser X low byte
; Book line 1311: Load A with the byte at shotx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 adc #11                      ; Add operand and carry to A
; Book line 1312: Add literal 11 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta tmpx                     ; Store A into memory
; Book line 1313: Store A into the byte at tmpx. The register and CPU flags are unchanged.
 lda shotxhi                  ; Load a value into A; player laser X high bit
; Book line 1314: Load A with the byte at shotxhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 adc #0                       ; Add operand and carry to A
; Book line 1315: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta tmpx+1                   ; Store A into memory
; Book line 1316: Store A into the byte at tmpx+1. The register and CPU flags are unchanged.
 sec                          ; Set carry before subtraction
; Book line 1317: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda tmpx                     ; Load a value into A
; Book line 1318: Load A with the byte at tmpx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc ex                       ; Subtract operand and borrow from A; calculated alien pixel X low byte
; Book line 1319: Subtract the byte at ex and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta hitdx                    ; Store A into memory
; Book line 1320: Store A into the byte at hitdx. The register and CPU flags are unchanged.
 lda tmpx+1                   ; Load a value into A
; Book line 1321: Load A with the byte at tmpx+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc exhi                     ; Subtract operand and borrow from A; calculated alien pixel X high bit
; Book line 1322: Subtract the byte at exhi and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 bne hitnext                  ; Branch when zero flag is clear
; Book line 1323: Branch to hitnext if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda hitdx                    ; Load a value into A
; Book line 1324: Load A with the byte at hitdx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #16                      ; Compare A against operand
; Book line 1325: Compare A with literal 16 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs hitnext                  ; Branch when carry is set
; Book line 1326: Branch to hitnext if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 ; Formation enemy is 16 pixels high; bullet's painted pixels y+0..17.
 ; Overlap iff bullet top <= enemy bottom and bullet bottom >= enemy top.
 lda shoty                    ; Load a value into A; player laser Y position
; Book line 1329: Load A with the byte at shoty. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp ey                       ; Compare A against operand; calculated alien pixel Y
; Book line 1330: Compare A with the byte at ey without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc bulletabove              ; Branch when carry is clear
; Book line 1331: Branch to bulletabove if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 sec                          ; Set carry before subtraction
; Book line 1332: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc ey                       ; Subtract operand and borrow from A; calculated alien pixel Y
; Book line 1333: Subtract the byte at ey and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp #16                      ; Compare A against operand
; Book line 1334: Compare A with literal 16 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs hitnext                  ; Branch when carry is set
; Book line 1335: Branch to hitnext if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 jmp formhit                  ; Jump unconditionally
; Book line 1336: Continue execution at formhit without saving a return address. Registers and flags
; are unchanged by the jump itself.
bulletabove:
; Book line 1337: bulletabove names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1338: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #18                      ; Add operand and carry to A
; Book line 1339: Add literal 18 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp ey                       ; Compare A against operand; calculated alien pixel Y
; Book line 1340: Compare A with the byte at ey without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc hitnext                  ; Branch when carry is clear
; Book line 1341: Branch to hitnext if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.

; ---------------------------------------------------------------------------
; FORMHIT: Apply a successful hit to a formation alien.
; ---------------------------------------------------------------------------
formhit:
; Book line 1346: formhit names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr coords                   ; Call a subroutine (return address saved on stack)
; Book line 1347: Call coords, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr destroy                  ; Call a subroutine (return address saved on stack)
; Book line 1348: Call destroy, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jmp enemyhitplayer           ; Jump unconditionally
; Book line 1349: Continue execution at enemyhitplayer without saving a return address. Registers and
; flags are unchanged by the jump itself.
hitnext:
; Book line 1350: hitnext names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 inx                          ; Increase X by 1
; Book line 1351: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #46                      ; Compare X against operand
; Book line 1352: Compare X with literal 46 without changing X. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne hitloop                  ; Branch when zero flag is clear
; Book line 1353: Branch to hitloop if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.


; ---------------------------------------------------------------------------
; ENEMYHITPLAYER: Check whether an enemy bullet hits the player ship.
; ---------------------------------------------------------------------------
enemyhitplayer:
; Book line 1359: enemyhitplayer names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda enemyshoton              ; Load a value into A; nonzero while enemy bullet is active
; Book line 1360: Load A with the byte at enemyshoton. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 beq divehitplayer            ; Branch when zero flag is set
; Book line 1361: Branch to divehitplayer if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda enemyshoty               ; Load a value into A; enemy bullet Y position
; Book line 1362: Load A with the byte at enemyshoty. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #205                     ; Compare A against operand
; Book line 1363: Compare A with literal 205 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc divehitplayer            ; Branch when carry is clear
; Book line 1364: Branch to divehitplayer if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 cmp #238                     ; Compare A against operand
; Book line 1365: Compare A with literal 238 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs divehitplayer            ; Branch when carry is set
; Book line 1366: Branch to divehitplayer if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 ; Enemy shot against full 9-bit player X.
 sec                          ; Set carry before subtraction
; Book line 1368: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda enemyshotx               ; Load a value into A; enemy bullet X low byte
; Book line 1369: Load A with the byte at enemyshotx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc shipx                    ; Subtract operand and borrow from A; player X position, low 8 bits
; Book line 1370: Subtract the byte at shipx (ship X low byte) and (1 minus incoming carry) from A.
; Update C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta hitdx                    ; Store A into memory
; Book line 1371: Store A into the byte at hitdx. The register and CPU flags are unchanged.
 lda enemyshotxhi             ; Load a value into A; enemy bullet ninth X bit
; Book line 1372: Load A with the byte at enemyshotxhi. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sbc shipxhi                  ; Subtract operand and borrow from A; player X position, ninth bit
; Book line 1373: Subtract the byte at shipxhi and (1 minus incoming carry) from A. Update C, Z, N and
; V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 bne divehitplayer            ; Branch when zero flag is clear
; Book line 1374: Branch to divehitplayer if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 lda hitdx                    ; Load a value into A
; Book line 1375: Load A with the byte at hitdx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #24                      ; Compare A against operand
; Book line 1376: Compare A with literal 24 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs divehitplayer            ; Branch when carry is set
; Book line 1377: Branch to divehitplayer if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 lda #0                       ; Load a value into A
; Book line 1378: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta enemyshoton              ; Store A into memory; nonzero while enemy bullet is active
; Book line 1379: Store A into the byte at enemyshoton. The register and CPU flags are unchanged.
 jsr loselife                 ; Call a subroutine (return address saved on stack)
; Book line 1380: Call loselife, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.

; ---------------------------------------------------------------------------
; DIVEHITPLAYER: Check whether the diving alien collides with the player.
; ---------------------------------------------------------------------------
divehitplayer:
; Book line 1385: divehitplayer names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda diveon                   ; Load a value into A; nonzero while a dive is active
; Book line 1386: Load A with the byte at diveon. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq hitsdone                 ; Branch when zero flag is set
; Book line 1387: Branch to hitsdone if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda divey                    ; Load a value into A; diving alien Y
; Book line 1388: Load A with the byte at divey. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #199                     ; Compare A against operand
; Book line 1389: Compare A with literal 199 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc hitsdone                 ; Branch when carry is clear
; Book line 1390: Branch to hitsdone if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 cmp #240                     ; Compare A against operand
; Book line 1391: Compare A with literal 240 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs hitsdone                 ; Branch when carry is set
; Book line 1392: Branch to hitsdone if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 sec                          ; Set carry before subtraction
; Book line 1393: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda divex                    ; Load a value into A; diving alien X low byte
; Book line 1394: Load A with the byte at divex. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc shipx                    ; Subtract operand and borrow from A; player X position, low 8 bits
; Book line 1395: Subtract the byte at shipx (ship X low byte) and (1 minus incoming carry) from A.
; Update C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta hitdx                    ; Store A into memory
; Book line 1396: Store A into the byte at hitdx. The register and CPU flags are unchanged.
 lda divexhi                  ; Load a value into A; diving alien ninth X bit
; Book line 1397: Load A with the byte at divexhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc shipxhi                  ; Subtract operand and borrow from A; player X position, ninth bit
; Book line 1398: Subtract the byte at shipxhi and (1 minus incoming carry) from A. Update C, Z, N and
; V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 bne hitsdone                 ; Branch when zero flag is clear
; Book line 1399: Branch to hitsdone if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda hitdx                    ; Load a value into A
; Book line 1400: Load A with the byte at hitdx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #24                      ; Compare A against operand
; Book line 1401: Compare A with literal 24 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs hitsdone                 ; Branch when carry is set
; Book line 1402: Branch to hitsdone if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #0                       ; Load a value into A
; Book line 1403: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta diveon                   ; Store A into memory; nonzero while a dive is active
; Book line 1404: Store A into the byte at diveon. The register and CPU flags are unchanged.
 jsr loselife                 ; Call a subroutine (return address saved on stack)
; Book line 1405: Call loselife, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
hitsdone: rts                 ; Return from subroutine
; Book line 1406: hitsdone names the data or instruction address. Pull the saved subroutine return
; address from the stack and resume after its JSR. Do not use this as an interrupt return.


; ---------------------------------------------------------------------------
; DESTROY: Remove the hit alien, start its explosion, award points and check wave completion.
; ---------------------------------------------------------------------------
destroy:
; Book line 1412: destroy names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ; Save the precise visible location of the alien being hit.
 ; Dive sprite uses divex/divey; formation uses enemycoords.
 lda diveon                   ; Load a value into A; nonzero while a dive is active
; Book line 1415: Load A with the byte at diveon. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq boom_formation           ; Branch when zero flag is set
; Book line 1416: Branch to boom_formation if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cpx diveindex                ; Compare X against operand; index of the alien selected for a dive
; Book line 1417: Compare X with the byte at diveindex without changing X. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 bne boom_formation           ; Branch when zero flag is clear
; Book line 1418: Branch to boom_formation if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 lda divex                    ; Load a value into A; diving alien X low byte
; Book line 1419: Load A with the byte at divex. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta boomx                    ; Store A into memory; alien explosion X low byte
; Book line 1420: Store A into the byte at boomx. The register and CPU flags are unchanged.
 lda divexhi                  ; Load a value into A; diving alien ninth X bit
; Book line 1421: Load A with the byte at divexhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta boomxhi                  ; Store A into memory; alien explosion X high bit
; Book line 1422: Store A into the byte at boomxhi. The register and CPU flags are unchanged.
 lda divey                    ; Load a value into A; diving alien Y
; Book line 1423: Load A with the byte at divey. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta boomy                    ; Store A into memory; alien explosion Y
; Book line 1424: Store A into the byte at boomy. The register and CPU flags are unchanged.
 jmp boom_dive_ready          ; Jump unconditionally
; Book line 1425: Continue execution at boom_dive_ready without saving a return address. Registers and
; flags are unchanged by the jump itself.

; ---------------------------------------------------------------------------
; BOOM_FORMATION: Determine explosion coordinates from the stationary alien’s tile position.
; ---------------------------------------------------------------------------
boom_formation:
; Book line 1430: boom_formation names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 jsr enemycoords              ; Call a subroutine (return address saved on stack)
; Book line 1431: Call enemycoords, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda ex                       ; Load a value into A; calculated alien pixel X low byte
; Book line 1432: Load A with the byte at ex. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta boomx                    ; Store A into memory; alien explosion X low byte
; Book line 1433: Store A into the byte at boomx. The register and CPU flags are unchanged.
 lda exhi                     ; Load a value into A; calculated alien pixel X high bit
; Book line 1434: Load A with the byte at exhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta boomxhi                  ; Store A into memory; alien explosion X high bit
; Book line 1435: Store A into the byte at boomxhi. The register and CPU flags are unchanged.
 lda ey                       ; Load a value into A; calculated alien pixel Y
; Book line 1436: Load A with the byte at ey. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta boomy                    ; Store A into memory; alien explosion Y
; Book line 1437: Store A into the byte at boomy. The register and CPU flags are unchanged.

; ---------------------------------------------------------------------------
; BOOM_READY: Apply the alien-explosion position and timer.
; ---------------------------------------------------------------------------
boom_ready:
; Book line 1442: boom_ready names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ; V29: formation explosion retains its existing 12px offset.
 sec                          ; Set carry before subtraction
; Book line 1444: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda boomx                    ; Load a value into A; alien explosion X low byte
; Book line 1445: Load A with the byte at boomx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc #12                      ; Subtract operand and borrow from A
; Book line 1446: Subtract literal 12 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta boomx                    ; Store A into memory; alien explosion X low byte
; Book line 1447: Store A into the byte at boomx. The register and CPU flags are unchanged.
 lda boomxhi                  ; Load a value into A; alien explosion X high bit
; Book line 1448: Load A with the byte at boomxhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc #0                       ; Subtract operand and borrow from A
; Book line 1449: Subtract literal 0 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta boomxhi                  ; Store A into memory; alien explosion X high bit
; Book line 1450: Store A into the byte at boomxhi. The register and CPU flags are unchanged.

; ---------------------------------------------------------------------------
; BOOM_DIVE_READY: Handle the different coordinate origin of a diving sprite explosion.
; ---------------------------------------------------------------------------
boom_dive_ready:
; Book line 1455: boom_dive_ready names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ; V30: restore V28 alien explosion alignment (formation and diving).
 ; Move up two scanlines to align the explosion's visible centre.
 sec                          ; Set carry before subtraction
; Book line 1458: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda boomy                    ; Load a value into A; alien explosion Y
; Book line 1459: Load A with the byte at boomy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc #2                       ; Subtract operand and borrow from A
; Book line 1460: Subtract literal 2 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta boomy                    ; Store A into memory; alien explosion Y
; Book line 1461: Store A into the byte at boomy. The register and CPU flags are unchanged.
 lda #15                      ; Load a value into A
; Book line 1462: Load A with literal 15. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta alienboom                ; Store A into memory; remaining frames in alien explosion animation
; Book line 1463: Store A into the byte at alienboom. The register and CPU flags are unchanged.
 lda #0                       ; Load a value into A
; Book line 1464: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta alive,x                  ; Store A into memory
; Book line 1465: Store A into the byte at alive (formation membership table) plus index X. The
; register and CPU flags are unchanged.
 sta shoton                   ; Store A into memory; nonzero while player laser is active
; Book line 1466: Store A into the byte at shoton. The register and CPU flags are unchanged.
 dec remaining                ; Decrease memory byte by 1; number of aliens left in this wave
; Book line 1467: Decrease the byte at remaining (remaining asteroid count) by one with 8-bit
; wraparound. Update Z and N; carry is unchanged.
 lda rownum                   ; Load a value into A; formation row for the current alien
; Book line 1468: Load A with the byte at rownum. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #4                       ; Compare A against operand
; Book line 1469: Compare A with literal 4 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq points60                 ; Branch when zero flag is set
; Book line 1470: Branch to points60 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #3                       ; Compare A against operand
; Book line 1471: Compare A with literal 3 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq points50                 ; Branch when zero flag is set
; Book line 1472: Branch to points50 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #0                       ; Compare A against operand
; Book line 1473: Compare A with literal 0 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq points30                 ; Branch when zero flag is set
; Book line 1474: Branch to points30 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #40                      ; Load a value into A
; Book line 1475: Load A with literal 40. Z records a zero value; N copies bit 7. Carry is unchanged.
 bne addscore                 ; Branch when zero flag is clear
; Book line 1476: Branch to addscore if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
points60: lda #60             ; Load a value into A
; Book line 1477: points60 names the data or instruction address. Load A with literal 60. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 bne addscore                 ; Branch when zero flag is clear
; Book line 1478: Branch to addscore if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
points50: lda #50             ; Load a value into A
; Book line 1479: points50 names the data or instruction address. Load A with literal 50. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 bne addscore                 ; Branch when zero flag is clear
; Book line 1480: Branch to addscore if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
points30: lda #30             ; Load a value into A
; Book line 1481: points30 names the data or instruction address. Load A with literal 30. Z records a
; zero value; N copies bit 7. Carry is unchanged.

; ---------------------------------------------------------------------------
; ADDSCORE: Add awarded points to the 16-bit score and compare with the stored high score.
; ---------------------------------------------------------------------------
addscore:
; Book line 1486: addscore names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1487: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc scorelo                  ; Add operand and carry to A; low byte of current 16-bit score
; Book line 1488: Add the byte at scorelo (score low byte) and incoming carry to A. Update C, Z, N and
; V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta scorelo                  ; Store A into memory; low byte of current 16-bit score
; Book line 1489: Store A into the byte at scorelo (score low byte). The register and CPU flags are
; unchanged.
 lda scorehi                  ; Load a value into A; high byte of current 16-bit score
; Book line 1490: Load A with the byte at scorehi (score high byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 adc #0                       ; Add operand and carry to A
; Book line 1491: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta scorehi                  ; Store A into memory; high byte of current 16-bit score
; Book line 1492: Store A into the byte at scorehi (score high byte). The register and CPU flags are
; unchanged.
 lda #0                       ; Load a value into A
; Book line 1493: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d40b                    ; Store A into memory
; Book line 1494: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
 lda #$ff                     ; Load a value into A
; Book line 1495: Load A with literal $ff (decimal 255). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d407                    ; Store A into memory
; Book line 1496: Store A into the byte at $d407 (SID voice 2 frequency low). The register and CPU
; flags are unchanged.
 lda #$1a                     ; Load a value into A
; Book line 1497: Load A with literal $1a (decimal 26). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d408                    ; Store A into memory
; Book line 1498: Store A into the byte at $d408 (SID voice 2 frequency high). The register and CPU
; flags are unchanged.
 lda #$08                     ; Load a value into A
; Book line 1499: Load A with literal $08 (decimal 8). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d40c                    ; Store A into memory
; Book line 1500: Store A into the byte at $d40c (SID voice 2 attack and decay). The register and CPU
; flags are unchanged.
 lda #$a0                     ; Load a value into A
; Book line 1501: Load A with literal $a0 (decimal 160). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d40d                    ; Store A into memory
; Book line 1502: Store A into the byte at $d40d (SID voice 2 sustain and release). The register and
; CPU flags are unchanged.
 lda #$81                     ; Load a value into A
; Book line 1503: Load A with literal $81 (decimal 129). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d40b                    ; Store A into memory
; Book line 1504: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
 lda #12                      ; Load a value into A
; Book line 1505: Load A with literal 12. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta boomlife                 ; Store A into memory; explosion sound countdown
; Book line 1506: Store A into the byte at boomlife. The register and CPU flags are unchanged.
 ; Preserve the best score between games.
 lda scorehi                  ; Load a value into A; high byte of current 16-bit score
; Book line 1508: Load A with the byte at scorehi (score high byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 cmp highhi                   ; Compare A against operand; high byte of session high score
; Book line 1509: Compare A with the byte at highhi (record high byte) without changing A. Z means
; equal, C means unsigned greater or equal, and N is the subtraction result bit 7.
 bcc score_not_record         ; Branch when carry is clear
; Book line 1510: Branch to score_not_record if C is 0; otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 bne score_new_record         ; Branch when zero flag is clear
; Book line 1511: Branch to score_new_record if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 lda scorelo                  ; Load a value into A; low byte of current 16-bit score
; Book line 1512: Load A with the byte at scorelo (score low byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 cmp highlo                   ; Compare A against operand; low byte of session high score
; Book line 1513: Compare A with the byte at highlo (record low byte) without changing A. Z means
; equal, C means unsigned greater or equal, and N is the subtraction result bit 7.
 bcc score_not_record         ; Branch when carry is clear
; Book line 1514: Branch to score_not_record if C is 0; otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.

; ---------------------------------------------------------------------------
; SCORE_NEW_RECORD: Copy the new score into the high-score bytes when the current score exceeds the record.
; ---------------------------------------------------------------------------
score_new_record:
; Book line 1519: score_new_record names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda scorelo                  ; Load a value into A; low byte of current 16-bit score
; Book line 1520: Load A with the byte at scorelo (score low byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta highlo                   ; Store A into memory; low byte of session high score
; Book line 1521: Store A into the byte at highlo (record low byte). The register and CPU flags are
; unchanged.
 lda scorehi                  ; Load a value into A; high byte of current 16-bit score
; Book line 1522: Load A with the byte at scorehi (score high byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta highhi                   ; Store A into memory; high byte of session high score
; Book line 1523: Store A into the byte at highhi (record high byte). The register and CPU flags are
; unchanged.
score_not_record:
; Book line 1524: score_not_record names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 jsr hud                      ; Call a subroutine (return address saved on stack)
; Book line 1525: Call hud, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda remaining                ; Load a value into A; number of aliens left in this wave
; Book line 1526: Load A with the byte at remaining (remaining asteroid count). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 bne destroyend               ; Branch when zero flag is clear
; Book line 1527: Branch to destroyend if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jsr newwave                  ; Call a subroutine (return address saved on stack)
; Book line 1528: Call newwave, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
destroyend: rts               ; Return from subroutine
; Book line 1529: destroyend names the data or instruction address. Pull the saved subroutine return
; address from the stack and resume after its JSR. Do not use this as an interrupt return.

; ---------------------------------------------------------------------------
; LOSELIFE: Start player explosion, reduce lives and set game-over state when no lives remain.
; ---------------------------------------------------------------------------
loselife:
; Book line 1534: loselife names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #23                      ; Load a value into A
; Book line 1535: Load A with literal 23. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta playerboom               ; Store A into memory; remaining frames in player explosion animation
; Book line 1536: Store A into the byte at playerboom. The register and CPU flags are unchanged.
 dec lives                    ; Decrease memory byte by 1; player lives remaining
; Book line 1537: Decrease the byte at lives (remaining lives) by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
 bne lifeok                   ; Branch when zero flag is clear
; Book line 1538: Branch to lifeok if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #0                       ; Load a value into A
; Book line 1539: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta gamestate                ; Store A into memory; 1 during play, 0 after game over
; Book line 1540: Store A into the byte at gamestate (game state selector). The register and CPU flags
; are unchanged.
 rts                          ; Return from subroutine
; Book line 1541: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
lifeok:
; Book line 1542: lifeok names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #0                       ; Load a value into A
; Book line 1543: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shoton                   ; Store A into memory; nonzero while player laser is active
; Book line 1544: Store A into the byte at shoton. The register and CPU flags are unchanged.
 sta enemyshoton              ; Store A into memory; nonzero while enemy bullet is active
; Book line 1545: Store A into the byte at enemyshoton. The register and CPU flags are unchanged.
 sta diveon                   ; Store A into memory; nonzero while a dive is active
; Book line 1546: Store A into the byte at diveon. The register and CPU flags are unchanged.
 jsr hud                      ; Call a subroutine (return address saved on stack)
; Book line 1547: Call hud, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 rts                          ; Return from subroutine
; Book line 1548: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ---------------------------------------------------------------------------
; HUD: Prepare the score/lives HUD for display.
; ---------------------------------------------------------------------------
hud:
; Book line 1554: hud names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ldx #0                       ; Load a value into X
; Book line 1555: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
hudloop:
; Book line 1556: hudloop names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda hudtext,x                ; Load a value into A
; Book line 1557: Load A with the byte at hudtext plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 beq hudnumbers               ; Branch when zero flag is set
; Book line 1558: Branch to hudnumbers if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta $0400,x                  ; Store A into memory
; Book line 1559: Store A into the byte at $0400 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 sta $3800,x                  ; Store A into memory
; Book line 1560: Store A into the byte at $3800 plus index X. The register and CPU flags are
; unchanged.
 inx                          ; Increase X by 1
; Book line 1561: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne hudloop                  ; Branch when zero flag is clear
; Book line 1562: Branch to hudloop if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.

; ---------------------------------------------------------------------------
; HUDNUMBERS: Convert the score and high score to printable decimal digits.
; ---------------------------------------------------------------------------
hudnumbers:
; Book line 1567: hudnumbers names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda scorelo                  ; Load a value into A; low byte of current 16-bit score
; Book line 1568: Load A with the byte at scorelo (score low byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta tmp                      ; Store A into memory
; Book line 1569: Store A into the byte at tmp. The register and CPU flags are unchanged.
 lda scorehi                  ; Load a value into A; high byte of current 16-bit score
; Book line 1570: Load A with the byte at scorehi (score high byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta tmp+1                    ; Store A into memory
; Book line 1571: Store A into the byte at tmp+1. The register and CPU flags are unchanged.
 jsr convert_digits           ; Call a subroutine (return address saved on stack)
; Book line 1572: Call convert_digits, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
 jsr print_score_digits       ; Call a subroutine (return address saved on stack)
; Book line 1573: Call print_score_digits, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
 lda highlo                   ; Load a value into A; low byte of session high score
; Book line 1574: Load A with the byte at highlo (record low byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta tmp                      ; Store A into memory
; Book line 1575: Store A into the byte at tmp. The register and CPU flags are unchanged.
 lda highhi                   ; Load a value into A; high byte of session high score
; Book line 1576: Load A with the byte at highhi (record high byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta tmp+1                    ; Store A into memory
; Book line 1577: Store A into the byte at tmp+1. The register and CPU flags are unchanged.
 jsr convert_digits           ; Call a subroutine (return address saved on stack)
; Book line 1578: Call convert_digits, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
 jsr print_high_digits        ; Call a subroutine (return address saved on stack)
; Book line 1579: Call print_high_digits, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
 lda lives                    ; Load a value into A; player lives remaining
; Book line 1580: Load A with the byte at lives (remaining lives). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1581: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$30                     ; Add operand and carry to A
; Book line 1582: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $0427                    ; Store A into memory
; Book line 1583: Store A into the byte at $0427 (screen RAM in the $0400 screen). The register and
; CPU flags are unchanged.
 sta $3827                    ; Store A into memory
; Book line 1584: Store A into the byte at $3827. The register and CPU flags are unchanged.
 rts                          ; Return from subroutine
; Book line 1585: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Input: tmp 16-bit binary. Output: digit0..digit4.

; ---------------------------------------------------------------------------
; CONVERT_DIGITS: Convert a 16-bit unsigned number to decimal using repeated subtraction rather than division.
; ---------------------------------------------------------------------------
convert_digits:
; Book line 1592: convert_digits names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #0                       ; Load a value into A
; Book line 1593: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta digit0                   ; Store A into memory; first decimal digit in score conversion
; Book line 1594: Store A into the byte at digit0. The register and CPU flags are unchanged.
 sta digit1                   ; Store A into memory; second decimal digit in score conversion
; Book line 1595: Store A into the byte at digit1. The register and CPU flags are unchanged.
 sta digit2                   ; Store A into memory; third decimal digit in score conversion
; Book line 1596: Store A into the byte at digit2. The register and CPU flags are unchanged.
 sta digit3                   ; Store A into memory; fourth decimal digit in score conversion
; Book line 1597: Store A into the byte at digit3. The register and CPU flags are unchanged.
 sta digit4                   ; Store A into memory; fifth decimal digit in score conversion
; Book line 1598: Store A into the byte at digit4. The register and CPU flags are unchanged.
hundred00:
; Book line 1599: hundred00 names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda tmp+1                    ; Load a value into A
; Book line 1600: Load A with the byte at tmp+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #$27                     ; Compare A against operand
; Book line 1601: Compare A with literal $27 (decimal 39) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 bcc thouscheck               ; Branch when carry is clear
; Book line 1602: Branch to thouscheck if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 bne dosub10000               ; Branch when zero flag is clear
; Book line 1603: Branch to dosub10000 if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda tmp                      ; Load a value into A
; Book line 1604: Load A with the byte at tmp. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #$10                     ; Compare A against operand
; Book line 1605: Compare A with literal $10 (decimal 16) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 bcc thouscheck               ; Branch when carry is clear
; Book line 1606: Branch to thouscheck if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
dosub10000:
; Book line 1607: dosub10000 names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sec                          ; Set carry before subtraction
; Book line 1608: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda tmp                      ; Load a value into A
; Book line 1609: Load A with the byte at tmp. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc #$10                     ; Subtract operand and borrow from A
; Book line 1610: Subtract literal $10 (decimal 16) and (1 minus incoming carry) from A. Update C, Z,
; N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta tmp                      ; Store A into memory
; Book line 1611: Store A into the byte at tmp. The register and CPU flags are unchanged.
 lda tmp+1                    ; Load a value into A
; Book line 1612: Load A with the byte at tmp+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc #$27                     ; Subtract operand and borrow from A
; Book line 1613: Subtract literal $27 (decimal 39) and (1 minus incoming carry) from A. Update C, Z,
; N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta tmp+1                    ; Store A into memory
; Book line 1614: Store A into the byte at tmp+1. The register and CPU flags are unchanged.
 inc digit0                   ; Increase memory byte by 1; first decimal digit in score conversion
; Book line 1615: Increase the byte at digit0 by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 jmp hundred00                ; Jump unconditionally
; Book line 1616: Continue execution at hundred00 without saving a return address. Registers and flags
; are unchanged by the jump itself.
thouscheck:
; Book line 1617: thouscheck names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda tmp+1                    ; Load a value into A
; Book line 1618: Load A with the byte at tmp+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #$03                     ; Compare A against operand
; Book line 1619: Compare A with literal $03 (decimal 3) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 bcc hundredscheck            ; Branch when carry is clear
; Book line 1620: Branch to hundredscheck if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 bne dosub1000                ; Branch when zero flag is clear
; Book line 1621: Branch to dosub1000 if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda tmp                      ; Load a value into A
; Book line 1622: Load A with the byte at tmp. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #$e8                     ; Compare A against operand
; Book line 1623: Compare A with literal $e8 (decimal 232) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 bcc hundredscheck            ; Branch when carry is clear
; Book line 1624: Branch to hundredscheck if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
dosub1000:
; Book line 1625: dosub1000 names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sec                          ; Set carry before subtraction
; Book line 1626: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda tmp                      ; Load a value into A
; Book line 1627: Load A with the byte at tmp. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc #$e8                     ; Subtract operand and borrow from A
; Book line 1628: Subtract literal $e8 (decimal 232) and (1 minus incoming carry) from A. Update C, Z,
; N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta tmp                      ; Store A into memory
; Book line 1629: Store A into the byte at tmp. The register and CPU flags are unchanged.
 lda tmp+1                    ; Load a value into A
; Book line 1630: Load A with the byte at tmp+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc #$03                     ; Subtract operand and borrow from A
; Book line 1631: Subtract literal $03 (decimal 3) and (1 minus incoming carry) from A. Update C, Z, N
; and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta tmp+1                    ; Store A into memory
; Book line 1632: Store A into the byte at tmp+1. The register and CPU flags are unchanged.
 inc digit1                   ; Increase memory byte by 1; second decimal digit in score conversion
; Book line 1633: Increase the byte at digit1 by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 jmp thouscheck               ; Jump unconditionally
; Book line 1634: Continue execution at thouscheck without saving a return address. Registers and
; flags are unchanged by the jump itself.
hundredscheck:
; Book line 1635: hundredscheck names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda tmp+1                    ; Load a value into A
; Book line 1636: Load A with the byte at tmp+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bne dosub100                 ; Branch when zero flag is clear
; Book line 1637: Branch to dosub100 if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda tmp                      ; Load a value into A
; Book line 1638: Load A with the byte at tmp. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #100                     ; Compare A against operand
; Book line 1639: Compare A with literal 100 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc tenscheck                ; Branch when carry is clear
; Book line 1640: Branch to tenscheck if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
dosub100:
; Book line 1641: dosub100 names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sec                          ; Set carry before subtraction
; Book line 1642: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda tmp                      ; Load a value into A
; Book line 1643: Load A with the byte at tmp. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc #100                     ; Subtract operand and borrow from A
; Book line 1644: Subtract literal 100 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta tmp                      ; Store A into memory
; Book line 1645: Store A into the byte at tmp. The register and CPU flags are unchanged.
 lda tmp+1                    ; Load a value into A
; Book line 1646: Load A with the byte at tmp+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc #0                       ; Subtract operand and borrow from A
; Book line 1647: Subtract literal 0 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta tmp+1                    ; Store A into memory
; Book line 1648: Store A into the byte at tmp+1. The register and CPU flags are unchanged.
 inc digit2                   ; Increase memory byte by 1; third decimal digit in score conversion
; Book line 1649: Increase the byte at digit2 by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 jmp hundredscheck            ; Jump unconditionally
; Book line 1650: Continue execution at hundredscheck without saving a return address. Registers and
; flags are unchanged by the jump itself.
tenscheck:
; Book line 1651: tenscheck names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda tmp                      ; Load a value into A
; Book line 1652: Load A with the byte at tmp. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #10                      ; Compare A against operand
; Book line 1653: Compare A with literal 10 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc unitscheck               ; Branch when carry is clear
; Book line 1654: Branch to unitscheck if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 sec                          ; Set carry before subtraction
; Book line 1655: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc #10                      ; Subtract operand and borrow from A
; Book line 1656: Subtract literal 10 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta tmp                      ; Store A into memory
; Book line 1657: Store A into the byte at tmp. The register and CPU flags are unchanged.
 inc digit3                   ; Increase memory byte by 1; fourth decimal digit in score conversion
; Book line 1658: Increase the byte at digit3 by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 jmp tenscheck                ; Jump unconditionally
; Book line 1659: Continue execution at tenscheck without saving a return address. Registers and flags
; are unchanged by the jump itself.
unitscheck:
; Book line 1660: unitscheck names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda tmp                      ; Load a value into A
; Book line 1661: Load A with the byte at tmp. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta digit4                   ; Store A into memory; fifth decimal digit in score conversion
; Book line 1662: Store A into the byte at digit4. The register and CPU flags are unchanged.
 rts                          ; Return from subroutine
; Book line 1663: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ---------------------------------------------------------------------------
; PRINT_SCORE_DIGITS: Write the five score digits to the appropriate screen addresses.
; ---------------------------------------------------------------------------
print_score_digits:
; Book line 1669: print_score_digits names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda digit0                   ; Load a value into A; first decimal digit in score conversion
; Book line 1670: Load A with the byte at digit0. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1671: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$30                     ; Add operand and carry to A
; Book line 1672: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $0406                    ; Store A into memory
; Book line 1673: Store A into the byte at $0406 (screen RAM in the $0400 screen). The register and
; CPU flags are unchanged.
 sta $3806                    ; Store A into memory
; Book line 1674: Store A into the byte at $3806. The register and CPU flags are unchanged.
 lda digit1                   ; Load a value into A; second decimal digit in score conversion
; Book line 1675: Load A with the byte at digit1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1676: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$30                     ; Add operand and carry to A
; Book line 1677: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $0407                    ; Store A into memory
; Book line 1678: Store A into the byte at $0407 (screen RAM in the $0400 screen). The register and
; CPU flags are unchanged.
 sta $3807                    ; Store A into memory
; Book line 1679: Store A into the byte at $3807. The register and CPU flags are unchanged.
 lda digit2                   ; Load a value into A; third decimal digit in score conversion
; Book line 1680: Load A with the byte at digit2. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1681: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$30                     ; Add operand and carry to A
; Book line 1682: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $0408                    ; Store A into memory
; Book line 1683: Store A into the byte at $0408 (screen RAM in the $0400 screen). The register and
; CPU flags are unchanged.
 sta $3808                    ; Store A into memory
; Book line 1684: Store A into the byte at $3808. The register and CPU flags are unchanged.
 lda digit3                   ; Load a value into A; fourth decimal digit in score conversion
; Book line 1685: Load A with the byte at digit3. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1686: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$30                     ; Add operand and carry to A
; Book line 1687: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $0409                    ; Store A into memory
; Book line 1688: Store A into the byte at $0409 (screen RAM in the $0400 screen). The register and
; CPU flags are unchanged.
 sta $3809                    ; Store A into memory
; Book line 1689: Store A into the byte at $3809. The register and CPU flags are unchanged.
 lda digit4                   ; Load a value into A; fifth decimal digit in score conversion
; Book line 1690: Load A with the byte at digit4. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1691: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$30                     ; Add operand and carry to A
; Book line 1692: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $040a                    ; Store A into memory
; Book line 1693: Store A into the byte at $040a (screen RAM in the $0400 screen). The register and
; CPU flags are unchanged.
 sta $380a                    ; Store A into memory
; Book line 1694: Store A into the byte at $380a. The register and CPU flags are unchanged.
 rts                          ; Return from subroutine
; Book line 1695: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ---------------------------------------------------------------------------
; PRINT_HIGH_DIGITS: Write the five high-score digits to the appropriate screen addresses.
; ---------------------------------------------------------------------------
print_high_digits:
; Book line 1701: print_high_digits names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda digit0                   ; Load a value into A; first decimal digit in score conversion
; Book line 1702: Load A with the byte at digit0. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1703: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$30                     ; Add operand and carry to A
; Book line 1704: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $041a                    ; Store A into memory
; Book line 1705: Store A into the byte at $041a (screen RAM in the $0400 screen). The register and
; CPU flags are unchanged.
 sta $381a                    ; Store A into memory
; Book line 1706: Store A into the byte at $381a. The register and CPU flags are unchanged.
 lda digit1                   ; Load a value into A; second decimal digit in score conversion
; Book line 1707: Load A with the byte at digit1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1708: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$30                     ; Add operand and carry to A
; Book line 1709: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $041b                    ; Store A into memory
; Book line 1710: Store A into the byte at $041b (screen RAM in the $0400 screen). The register and
; CPU flags are unchanged.
 sta $381b                    ; Store A into memory
; Book line 1711: Store A into the byte at $381b. The register and CPU flags are unchanged.
 lda digit2                   ; Load a value into A; third decimal digit in score conversion
; Book line 1712: Load A with the byte at digit2. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1713: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$30                     ; Add operand and carry to A
; Book line 1714: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $041c                    ; Store A into memory
; Book line 1715: Store A into the byte at $041c (screen RAM in the $0400 screen). The register and
; CPU flags are unchanged.
 sta $381c                    ; Store A into memory
; Book line 1716: Store A into the byte at $381c. The register and CPU flags are unchanged.
 lda digit3                   ; Load a value into A; fourth decimal digit in score conversion
; Book line 1717: Load A with the byte at digit3. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1718: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$30                     ; Add operand and carry to A
; Book line 1719: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $041d                    ; Store A into memory
; Book line 1720: Store A into the byte at $041d (screen RAM in the $0400 screen). The register and
; CPU flags are unchanged.
 sta $381d                    ; Store A into memory
; Book line 1721: Store A into the byte at $381d. The register and CPU flags are unchanged.
 lda digit4                   ; Load a value into A; fifth decimal digit in score conversion
; Book line 1722: Load A with the byte at digit4. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                          ; Clear carry before addition / unsigned comparison
; Book line 1723: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$30                     ; Add operand and carry to A
; Book line 1724: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $041e                    ; Store A into memory
; Book line 1725: Store A into the byte at $041e (screen RAM in the $0400 screen). The register and
; CPU flags are unchanged.
 sta $381e                    ; Store A into memory
; Book line 1726: Store A into the byte at $381e. The register and CPU flags are unchanged.
 rts                          ; Return from subroutine
; Book line 1727: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ---------------------------------------------------------------------------
; EXPLOSION_TICK: Reduce alien and player explosion timers once per frame.
; ---------------------------------------------------------------------------
explosion_tick:
; Book line 1733: explosion_tick names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda alienboom                ; Load a value into A; remaining frames in alien explosion animation
; Book line 1734: Load A with the byte at alienboom. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq explosion_player         ; Branch when zero flag is set
; Book line 1735: Branch to explosion_player if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec alienboom                ; Decrease memory byte by 1; remaining frames in alien explosion animation
; Book line 1736: Decrease the byte at alienboom by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
explosion_player:
; Book line 1737: explosion_player names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda playerboom               ; Load a value into A; remaining frames in player explosion animation
; Book line 1738: Load A with the byte at playerboom. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq explosion_done           ; Branch when zero flag is set
; Book line 1739: Branch to explosion_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec playerboom               ; Decrease memory byte by 1; remaining frames in player explosion animation
; Book line 1740: Decrease the byte at playerboom by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
explosion_done:
; Book line 1741: explosion_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 rts                          ; Return from subroutine
; Book line 1742: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ---------------------------------------------------------------------------
; SOUNDTICK: Update SID sound effects and stop voices when their timers expire.
; ---------------------------------------------------------------------------
soundtick:
; Book line 1748: soundtick names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda laserlife                ; Load a value into A; laser sound effect countdown
; Book line 1749: Load A with the byte at laserlife. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq boomtick                 ; Branch when zero flag is set
; Book line 1750: Branch to boomtick if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec laserlife                ; Decrease memory byte by 1; laser sound effect countdown
; Book line 1751: Decrease the byte at laserlife by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
 bne boomtick                 ; Branch when zero flag is clear
; Book line 1752: Branch to boomtick if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #0                       ; Load a value into A
; Book line 1753: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d404                    ; Store A into memory
; Book line 1754: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
boomtick:
; Book line 1755: boomtick names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda boomlife                 ; Load a value into A; explosion sound countdown
; Book line 1756: Load A with the byte at boomlife. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq sounddone                ; Branch when zero flag is set
; Book line 1757: Branch to sounddone if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec boomlife                 ; Decrease memory byte by 1; explosion sound countdown
; Book line 1758: Decrease the byte at boomlife by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 bne sounddone                ; Branch when zero flag is clear
; Book line 1759: Branch to sounddone if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #0                       ; Load a value into A
; Book line 1760: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d40b                    ; Store A into memory
; Book line 1761: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
sounddone: rts                ; Return from subroutine
; Book line 1762: sounddone names the data or instruction address. Pull the saved subroutine return
; address from the stack and resume after its JSR. Do not use this as an interrupt return.

gameover_text: !byte 7,1,13,5,32,15,22,5,18
; Book line 1764: gameover_text names the data or instruction address. Emit 9 bytes in the shown order
; for gameover_text. These are data or encoded loader bytes, not instructions to execute.
!byte 0
; Book line 1765: Emit 1 byte in the shown order for gameover_text. These are data or encoded loader
; bytes, not instructions to execute.
title_text: !byte 7,1,12,1,24,9,1,14,32,55,57
; Book line 1766: title_text names the data or instruction address. Emit 11 bytes in the shown order
; for title_text. These are data or encoded loader bytes, not instructions to execute.
!byte 0
; Book line 1767: Emit 1 byte in the shown order for title_text. These are data or encoded loader
; bytes, not instructions to execute.
prompt_text: !byte 16,18,5,19,19,32,16,32,20,15,32,16,12,1,25
; Book line 1768: prompt_text names the data or instruction address. Emit 15 bytes in the shown order
; for prompt_text. These are data or encoded loader bytes, not instructions to execute.
!byte 0
; Book line 1769: Emit 1 byte in the shown order for prompt_text. These are data or encoded loader
; bytes, not instructions to execute.
hudtext: !scr "1up   00000   high score  00000  lives  "
; Book line 1770: hudtext names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
!byte 0
; Book line 1771: Emit 1 byte in the shown order for hudtext. These are data or encoded loader bytes,
; not instructions to execute.
colors: !byte 11,12,12,10,15 ; VIC multicolor character flag plus row colour
; Book line 1772: colors names the data or instruction address. Emit 5 bytes in the shown order for
; colors. These are data or encoded loader bytes, not instructions to execute.
divecolors: !byte 3,4,4,2,7 ; cyan, purple, purple, red, yellow
; Book line 1773: divecolors names the data or instruction address. Emit 5 bytes in the shown order
; for divecolors. These are data or encoded loader bytes, not instructions to execute.
rowlow:
; Book line 1774: rowlow names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
!for .i,0,24 { !byte <($0400+.i*40) }
; Book line 1775: Repeat the enclosed assembly-time body for the specified loop range. Each !byte
; emits the shown low or high address expression; this is not a runtime CPU loop.
rowhigh:
; Book line 1776: rowhigh names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
!for .i,0,24 { !byte >($0400+.i*40) }
; Book line 1777: Repeat the enclosed assembly-time body for the specified loop range. Each !byte
; emits the shown low or high address expression; this is not a runtime CPU loop.
colorlow:
; Book line 1778: colorlow names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
!for .i,0,24 { !byte <($d800+.i*40) }
; Book line 1779: Repeat the enclosed assembly-time body for the specified loop range. Each !byte
; emits the shown low or high address expression; this is not a runtime CPU loop.
colorhigh:
; Book line 1780: colorhigh names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
!for .i,0,24 { !byte >($d800+.i*40) }
; Book line 1781: Repeat the enclosed assembly-time body for the specified loop range. Each !byte
; emits the shown low or high address expression; this is not a runtime CPU loop.
; VARIABLE screenbank: which screen is currently visible (double buffering).
screenbank: !byte 0
; Book line 1783: screenbank names the data or instruction address. Emit 1 byte in the shown order for
; screenbank. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE drawbank: which screen is currently being drawn.
drawbank: !byte 0
; Book line 1785: drawbank names the data or instruction address. Emit 1 byte in the shown order for
; drawbank. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE gamestate: 1 during play, 0 after game over.
gamestate: !byte 0
; Book line 1787: gamestate names the data or instruction address. Emit 1 byte in the shown order for
; gamestate. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE shipx: player X position, low 8 bits.
shipx: !byte 0
; Book line 1789: shipx names the data or instruction address. Emit 1 byte in the shown order for
; shipx. These are data or encoded loader bytes, not instructions to execute. The surrounding image
; definition determines how these bits become pixels.
; VARIABLE shipxhi: player X position, ninth bit.
shipxhi: !byte 0
; Book line 1791: shipxhi names the data or instruction address. Emit 1 byte in the shown order for
; shipxhi. These are data or encoded loader bytes, not instructions to execute. The surrounding image
; definition determines how these bits become pixels.
; VARIABLE shotxhi: player laser X high bit.
shotxhi: !byte 0
; Book line 1793: shotxhi names the data or instruction address. Emit 1 byte in the shown order for
; shotxhi. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE exhi: calculated alien pixel X high bit.
exhi: !byte 0
; Book line 1795: exhi names the data or instruction address. Emit 1 byte in the shown order for exhi.
; These are data or encoded loader bytes, not instructions to execute.
hitdx: !byte 0
; Book line 1796: hitdx names the data or instruction address. Emit 1 byte in the shown order for
; hitdx. These are data or encoded loader bytes, not instructions to execute.
tmpx: !word 0
; Book line 1797: tmpx names the data or instruction address. Emit the listed 16-bit value or values
; for tmpx, storing each low byte before its high byte.
; VARIABLE divexhi: diving alien ninth X bit.
divexhi: !byte 0
; Book line 1799: divexhi names the data or instruction address. Emit 1 byte in the shown order for
; divexhi. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE enemyshotxhi: enemy bullet ninth X bit.
enemyshotxhi: !byte 0
; Book line 1801: enemyshotxhi names the data or instruction address. Emit 1 byte in the shown order
; for enemyshotxhi. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE shotx: player laser X low byte.
shotx: !byte 0
; Book line 1803: shotx names the data or instruction address. Emit 1 byte in the shown order for
; shotx. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE shoty: player laser Y position.
shoty: !byte 0
; Book line 1805: shoty names the data or instruction address. Emit 1 byte in the shown order for
; shoty. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE shoton: nonzero while player laser is active.
shoton: !byte 0
; Book line 1807: shoton names the data or instruction address. Emit 1 byte in the shown order for
; shoton. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE enemyshotx: enemy bullet X low byte.
enemyshotx: !byte 0
; Book line 1809: enemyshotx names the data or instruction address. Emit 1 byte in the shown order for
; enemyshotx. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE enemyshoty: enemy bullet Y position.
enemyshoty: !byte 0
; Book line 1811: enemyshoty names the data or instruction address. Emit 1 byte in the shown order for
; enemyshoty. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE enemyshoton: nonzero while enemy bullet is active.
enemyshoton: !byte 0
; Book line 1813: enemyshoton names the data or instruction address. Emit 1 byte in the shown order
; for enemyshoton. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE divex: diving alien X low byte.
divex: !byte 0
; Book line 1815: divex names the data or instruction address. Emit 1 byte in the shown order for
; divex. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE divey: diving alien Y.
divey: !byte 0
; Book line 1817: divey names the data or instruction address. Emit 1 byte in the shown order for
; divey. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE diveon: nonzero while a dive is active.
diveon: !byte 0
; Book line 1819: diveon names the data or instruction address. Emit 1 byte in the shown order for
; diveon. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE diveindex: index of the alien selected for a dive.
diveindex: !byte 0
; Book line 1821: diveindex names the data or instruction address. Emit 1 byte in the shown order for
; diveindex. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE ex: calculated alien pixel X low byte.
ex: !byte 0
; Book line 1823: ex names the data or instruction address. Emit 1 byte in the shown order for ex.
; These are data or encoded loader bytes, not instructions to execute.
; VARIABLE ey: calculated alien pixel Y.
ey: !byte 0
; Book line 1825: ey names the data or instruction address. Emit 1 byte in the shown order for ey.
; These are data or encoded loader bytes, not instructions to execute.
; VARIABLE screenx: alien position in text columns.
screenx: !byte 0
; Book line 1827: screenx names the data or instruction address. Emit 1 byte in the shown order for
; screenx. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE screeny: alien position in text rows.
screeny: !byte 0
; Book line 1829: screeny names the data or instruction address. Emit 1 byte in the shown order for
; screeny. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE rownum: formation row for the current alien.
rownum: !byte 0
; Book line 1831: rownum names the data or instruction address. Emit 1 byte in the shown order for
; rownum. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE colnum: formation column for the current alien.
colnum: !byte 0
; Book line 1833: colnum names the data or instruction address. Emit 1 byte in the shown order for
; colnum. These are data or encoded loader bytes, not instructions to execute.
tmp: !word 0
; Book line 1834: tmp names the data or instruction address. Emit the listed 16-bit value or values
; for tmp, storing each low byte before its high byte.
; VARIABLE alive: 46 flags; nonzero means the corresponding alien is alive.
alive: !fill 46,0
; Book line 1836: alive names the data or instruction address. Emit repeated initial data for alive:
; 46,0. The first expression is the byte count and the second is the fill value.
; VARIABLE remaining: number of aliens left in this wave.
remaining: !byte 0
; Book line 1838: remaining names the data or instruction address. Emit 1 byte in the shown order for
; remaining. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE lives: player lives remaining.
lives: !byte 0
; Book line 1840: lives names the data or instruction address. Emit 1 byte in the shown order for
; lives. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE scorelo: low byte of current 16-bit score.
scorelo: !byte 0
; Book line 1842: scorelo names the data or instruction address. Emit 1 byte in the shown order for
; scorelo. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE scorehi: high byte of current 16-bit score.
scorehi: !byte 0
; Book line 1844: scorehi names the data or instruction address. Emit 1 byte in the shown order for
; scorehi. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE highlo: low byte of session high score.
highlo: !byte 0
; Book line 1846: highlo names the data or instruction address. Emit 1 byte in the shown order for
; highlo. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE highhi: high byte of session high score.
highhi: !byte 0
; Book line 1848: highhi names the data or instruction address. Emit 1 byte in the shown order for
; highhi. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE wave: current wave number.
wave: !byte 0
; Book line 1850: wave names the data or instruction address. Emit 1 byte in the shown order for wave.
; These are data or encoded loader bytes, not instructions to execute.
; VARIABLE tick: frame counter used for timing.
tick: !byte 0
; Book line 1852: tick names the data or instruction address. Emit 1 byte in the shown order for tick.
; These are data or encoded loader bytes, not instructions to execute.
; VARIABLE drift: horizontal formation offset.
drift: !byte 0
; Book line 1854: drift names the data or instruction address. Emit 1 byte in the shown order for
; drift. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE dir: formation travel direction.
dir: !byte 0
; Book line 1856: dir names the data or instruction address. Emit 1 byte in the shown order for dir.
; These are data or encoded loader bytes, not instructions to execute.
formationstep: !byte 0
; Book line 1857: formationstep names the data or instruction address. Emit 1 byte in the shown order
; for formationstep. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE divephase: current position in the 64-step dive curve.
divephase: !byte 0
; Book line 1859: divephase names the data or instruction address. Emit 1 byte in the shown order for
; divephase. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE diveorigin: diving alien starting X low byte.
diveorigin: !byte 0
; Book line 1861: diveorigin names the data or instruction address. Emit 1 byte in the shown order for
; diveorigin. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE diveoriginhi: diving alien starting X high byte.
diveoriginhi: !byte 0
; Book line 1863: diveoriginhi names the data or instruction address. Emit 1 byte in the shown order
; for diveoriginhi. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE diveoffset: signed horizontal offset from the dive curve.
diveoffset: !byte 0
; Book line 1865: diveoffset names the data or instruction address. Emit 1 byte in the shown order for
; diveoffset. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE divepick: next candidate index for diving.
divepick: !byte 0
; Book line 1867: divepick names the data or instruction address. Emit 1 byte in the shown order for
; divepick. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE digit0: first decimal digit in score conversion.
digit0: !byte 0
; Book line 1869: digit0 names the data or instruction address. Emit 1 byte in the shown order for
; digit0. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE digit1: second decimal digit in score conversion.
digit1: !byte 0
; Book line 1871: digit1 names the data or instruction address. Emit 1 byte in the shown order for
; digit1. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE digit2: third decimal digit in score conversion.
digit2: !byte 0
; Book line 1873: digit2 names the data or instruction address. Emit 1 byte in the shown order for
; digit2. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE digit3: fourth decimal digit in score conversion.
digit3: !byte 0
; Book line 1875: digit3 names the data or instruction address. Emit 1 byte in the shown order for
; digit3. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE digit4: fifth decimal digit in score conversion.
digit4: !byte 0
; Book line 1877: digit4 names the data or instruction address. Emit 1 byte in the shown order for
; digit4. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE laserlife: laser sound effect countdown.
laserlife: !byte 0
; Book line 1879: laserlife names the data or instruction address. Emit 1 byte in the shown order for
; laserlife. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE boomlife: explosion sound countdown.
boomlife: !byte 0
; Book line 1881: boomlife names the data or instruction address. Emit 1 byte in the shown order for
; boomlife. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE spritemask: bitmask of enabled hardware sprites.
spritemask: !byte 0
; Book line 1883: spritemask names the data or instruction address. Emit 1 byte in the shown order for
; spritemask. These are data or encoded loader bytes, not instructions to execute. The surrounding
; image definition determines how these bits become pixels.
; VARIABLE alienboom: remaining frames in alien explosion animation.
alienboom: !byte 0
; Book line 1885: alienboom names the data or instruction address. Emit 1 byte in the shown order for
; alienboom. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE playerboom: remaining frames in player explosion animation.
playerboom: !byte 0
; Book line 1887: playerboom names the data or instruction address. Emit 1 byte in the shown order for
; playerboom. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE playerboomxhi: player explosion X high bit.
playerboomxhi: !byte 0
; Book line 1889: playerboomxhi names the data or instruction address. Emit 1 byte in the shown order
; for playerboomxhi. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE boomx: alien explosion X low byte.
boomx: !byte 0
; Book line 1891: boomx names the data or instruction address. Emit 1 byte in the shown order for
; boomx. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE boomxhi: alien explosion X high bit.
boomxhi: !byte 0
; Book line 1893: boomxhi names the data or instruction address. Emit 1 byte in the shown order for
; boomxhi. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE boomy: alien explosion Y.
boomy: !byte 0
; Book line 1895: boomy names the data or instruction address. Emit 1 byte in the shown order for
; boomy. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE tilebase: first custom character code for current alien artwork.
tilebase: !byte 0
; Book line 1897: tilebase names the data or instruction address. Emit 1 byte in the shown order for
; tilebase. These are data or encoded loader bytes, not instructions to execute.
; VARIABLE tilecolor: colour RAM value for current alien.
tilecolor: !byte 0
; Book line 1899: tilecolor names the data or instruction address. Emit 1 byte in the shown order for
; tilecolor. These are data or encoded loader bytes, not instructions to execute.


; Copy C64 character ROM into RAM charset $2000, then replace alien glyphs.
; CPU sees ROM at $d000 while VIC sees RAM at $2000.

; ---------------------------------------------------------------------------
; CHARSET_INIT: Temporarily map the character ROM into CPU memory, copy glyphs to RAM, then copy custom alien characters.
; ---------------------------------------------------------------------------
charset_init:
; Book line 1908: charset_init names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #$33                     ; Load a value into A
; Book line 1909: Load A with literal $33 (decimal 51). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $01                      ; Store A into memory
; Book line 1910: Store A into the byte at $01 (6510 ROM and I/O banking port). The register and CPU
; flags are unchanged.
 ldx #0                       ; Load a value into X
; Book line 1911: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.

; ---------------------------------------------------------------------------
; CHARSET_COPY: Copy eight 256-byte pages of the character ROM to RAM. The !for directive expands this at assembly time.
; ---------------------------------------------------------------------------
charset_copy:
; Book line 1916: charset_copy names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
!for .i,0,7 {
; Book line 1917: Repeat the enclosed assembly-time body for the specified loop range. Each !byte
; emits the shown low or high address expression; this is not a runtime CPU loop.
 lda $d000+(.i*256),x         ; Load a value into A; sprite 0 X (player)
; Book line 1918: Load A with the byte at $d000+(.i*256) plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2000+(.i*256),x         ; Store A into memory
; Book line 1919: Store A into the byte at $2000+(.i*256) plus index X. The register and CPU flags are
; unchanged.
 sta $2800+(.i*256),x         ; Store A into memory
; Book line 1920: Store A into the byte at $2800+(.i*256) plus index X. The register and CPU flags are
; unchanged.
}
; Book line 1921: Close the assembly-time block; this is not a CPU instruction.
 inx                          ; Increase X by 1
; Book line 1922: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne charset_copy             ; Branch when zero flag is clear
; Book line 1923: Branch to charset_copy if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 lda #$37                     ; Load a value into A
; Book line 1924: Load A with literal $37 (decimal 55). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $01                      ; Store A into memory
; Book line 1925: Store A into the byte at $01 (6510 ROM and I/O banking port). The register and CPU
; flags are unchanged.
 ldx #0                       ; Load a value into X
; Book line 1926: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.

; ---------------------------------------------------------------------------
; CUSTOM_COPY: Copy the custom alien glyph bitmap bytes into the selected RAM character set.
; ---------------------------------------------------------------------------
custom_copy:
; Book line 1931: custom_copy names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda alienfont,x              ; Load a value into A
; Book line 1932: Load A with the byte at alienfont plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta $2500,x                  ; Store A into memory
; Book line 1933: Store A into the byte at $2500 plus index X. The register and CPU flags are
; unchanged.
 lda alienfont+$100,x         ; Load a value into A
; Book line 1934: Load A with the byte at alienfont+$100 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2600,x                  ; Store A into memory
; Book line 1935: Store A into the byte at $2600 plus index X. The register and CPU flags are
; unchanged.
 inx                          ; Increase X by 1
; Book line 1936: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne custom_copy              ; Branch when zero flag is clear
; Book line 1937: Branch to custom_copy if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts                          ; Return from subroutine
; Book line 1938: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Signed-offset table for a looping curved dive, 64 frames.

; ---------------------------------------------------------------------------
; DIVECURVE: A 64-entry table of signed horizontal offsets for a diving alien; $FE means -2, $FC means -4.
; ---------------------------------------------------------------------------
divecurve:
; Book line 1945: divecurve names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
!byte $00,$02,$04,$06,$08,$09,$0b,$0d,$0e,$0f,$11,$12,$12,$13,$14,$14,$14,$14,$14,$13,$12,$12,$11,$0f,$0e,$0d,$0b,$09,$08,$06,$04,$02,$00,$fe,$fc,$fa,$f8,$f7,$f5,$f3,$f2,$f1,$ef,$ee,$ee,$ed,$ec,$ec,$ec,$ec,$ec,$ed,$ee,$ee,$ef,$f1,$f2,$f3,$f5,$f7,$f8,$fa,$fc,$fe
; Book line 1946: Emit 64 bytes in the shown order for divecurve. These are data or encoded loader
; bytes, not instructions to execute.

; ---------------------------------------------------------------------------
; ALIENFONT: Raw bitmap data for the custom alien characters. Each character uses 8 bytes (one per pixel row).
; ---------------------------------------------------------------------------
alienfont:
; Book line 1951: alienfont names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
; 40 multicolour character tiles: 5 alien types x 2 wing frames x 4 tiles.
!byte $00,$03,$0b,$2b,$bb,$3d,$2d,$0d,$00,$00,$80,$a0,$b8,$50,$50,$40
; Book line 1953: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $2d,$39,$89,$08,$08,$00,$00,$00,$50,$50,$48,$40,$80,$00,$00,$00
; Book line 1954: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$03,$0b,$0f,$8f,$ed,$3d,$0d,$00,$00,$80,$c0,$c8,$5b,$50,$40
; Book line 1955: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $2d,$39,$89,$08,$08,$00,$00,$00,$50,$50,$48,$40,$80,$00,$00,$00
; Book line 1956: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$02,$03,$0b,$2b,$b9,$3d,$2d,$00,$80,$c0,$e0,$e8,$5e,$5c,$58
; Book line 1957: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0d,$2d,$31,$01,$08,$00,$00,$00,$50,$58,$4c,$40,$20,$00,$00,$00
; Book line 1958: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$02,$03,$2b,$bb,$3d,$2d,$0d,$00,$80,$c0,$e8,$ee,$5c,$58,$50
; Book line 1959: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $2d,$31,$81,$01,$08,$00,$00,$00,$58,$4c,$42,$40,$20,$00,$00,$00
; Book line 1960: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$02,$03,$0b,$0f,$3d,$bd,$2d,$00,$80,$c0,$e0,$f0,$5c,$5e,$58
; Book line 1961: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0d,$29,$21,$01,$08,$00,$00,$00,$50,$58,$48,$40,$20,$00,$00,$00
; Book line 1962: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$03,$0b,$2b,$bb,$bd,$2d,$0d,$00,$00,$80,$a0,$b8,$52,$50,$40
; Book line 1963: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $2d,$39,$89,$08,$08,$00,$00,$00,$50,$50,$48,$40,$80,$00,$00,$00
; Book line 1964: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$03,$0b,$0f,$0f,$ad,$3d,$0d,$00,$00,$80,$c0,$c8,$5a,$50,$40
; Book line 1965: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $2d,$39,$89,$08,$08,$00,$00,$00,$50,$50,$48,$40,$80,$00,$00,$00
; Book line 1966: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$02,$03,$0b,$2b,$f9,$3d,$2d,$00,$80,$c0,$e0,$e8,$5f,$5c,$58
; Book line 1967: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0d,$2d,$31,$01,$08,$00,$00,$00,$50,$58,$4c,$40,$20,$00,$00,$00
; Book line 1968: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$02,$03,$2b,$3b,$3d,$2d,$0d,$00,$80,$c0,$e8,$ec,$5c,$58,$50
; Book line 1969: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $2d,$31,$81,$01,$08,$00,$00,$00,$58,$4c,$42,$40,$20,$00,$00,$00
; Book line 1970: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$02,$03,$0b,$0f,$bd,$bd,$2d,$00,$80,$c0,$e0,$f0,$5e,$5e,$58
; Book line 1971: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0d,$29,$21,$01,$08,$00,$00,$00,$50,$58,$48,$40,$20,$00,$00,$00
; Book line 1972: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1973: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1974: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1975: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1976: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1977: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1978: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1979: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1980: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1981: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1982: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1983: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1984: Emit 16 bytes in the shown order for alienfont. These are data or encoded loader
; bytes, not instructions to execute.

; ---------------------------------------------------------------------------
; DIVEPTRS: Sprite pointer values for the five alien rows, indexed by row number.
; ---------------------------------------------------------------------------
diveptrs: !byte $c1,$c2,$c3,$c4,$c5
; Book line 1989: diveptrs names the data or instruction address. Emit 5 bytes in the shown order for
; diveptrs. These are data or encoded loader bytes, not instructions to execute.

*=$3000
; Book line 1991: Place subsequent output at C64 address $3000; the origin directive is processed by
; ACME, not executed by the CPU.
; Eight 64-byte-aligned VIC-II sprites, 21 rows x 3 bytes + pad.
; Sprite 0, pointer $c0
 !byte $00,$00,$00
; Book line 1994: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 1995: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 1996: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 1997: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 1998: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 1999: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $01,$80,$00
; Book line 2000: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $03,$c0,$00
; Book line 2001: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $07,$e0,$00
; Book line 2002: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $0f,$f0,$00
; Book line 2003: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $1f,$f8,$00
; Book line 2004: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $3f,$fc,$00
; Book line 2005: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $7f,$fe,$00
; Book line 2006: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $ff,$ff,$00
; Book line 2007: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $7f,$fe,$00
; Book line 2008: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $3f,$fc,$00
; Book line 2009: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $19,$98,$00
; Book line 2010: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $31,$8c,$00
; Book line 2011: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $60,$06,$00
; Book line 2012: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2013: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2014: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 0
; Book line 2015: Emit 1 byte in the shown order for diveptrs. These are data or encoded loader bytes,
; not instructions to execute.
; Sprite 1, pointer $c1
; V27 matching multicolour formation silhouette
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$30,$00,$00
; Book line 2018: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $b8,$00,$02,$ba,$00,$0b,$bb,$80,$03,$d5,$00,$02,$d5,$00,$00,$d4
; Book line 2019: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$02,$d5,$00,$03,$95,$00,$08,$94,$80,$00,$84,$00,$00,$88,$00
; Book line 2020: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 2021: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
; Sprite 2, pointer $c2
; V27 matching multicolour formation silhouette
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$28,$00,$00
; Book line 2024: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3c,$00,$00,$be,$00,$02,$be,$80,$0b,$95,$e0,$03,$d5,$c0,$02,$d5
; Book line 2025: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $80,$00,$d5,$00,$02,$d5,$80,$03,$14,$c0,$00,$14,$00,$00,$82,$00
; Book line 2026: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 2027: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
; Sprite 3, pointer $c3
; V27 matching multicolour formation silhouette
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$28,$00,$00
; Book line 2030: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3c,$00,$00,$be,$00,$00,$ff,$00,$03,$d5,$c0,$0b,$d5,$e0,$02,$d5
; Book line 2031: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $80,$00,$d5,$00,$02,$95,$80,$02,$14,$80,$00,$14,$00,$00,$82,$00
; Book line 2032: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 2033: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
; Sprite 4, pointer $c4
; V27 matching multicolour formation silhouette
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$30,$00,$00
; Book line 2036: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $b8,$00,$00,$fc,$00,$00,$fc,$80,$0a,$d5,$a0,$03,$d5,$00,$00,$d4
; Book line 2037: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$02,$d5,$00,$03,$95,$00,$08,$94,$80,$00,$84,$00,$00,$88,$00
; Book line 2038: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 2039: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
; Sprite 5, pointer $c5
; V27 matching multicolour formation silhouette
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$28,$00,$00
; Book line 2042: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3c,$00,$02,$be,$80,$03,$be,$c0,$03,$d5,$c0,$02,$d5,$80,$00,$d5
; Book line 2043: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$02,$d5,$80,$03,$14,$c0,$08,$14,$20,$00,$14,$00,$00,$82,$00
; Book line 2044: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 2045: Emit 16 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
; Sprite 6, pointer $c6
 !byte $00,$00,$00
; Book line 2047: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2048: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2049: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2050: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2051: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2052: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $01,$80,$00
; Book line 2053: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $01,$80,$00
; Book line 2054: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $03,$c0,$00
; Book line 2055: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $01,$80,$00
; Book line 2056: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $01,$80,$00
; Book line 2057: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2058: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2059: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2060: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2061: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2062: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2063: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2064: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2065: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2066: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2067: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 0
; Book line 2068: Emit 1 byte in the shown order for diveptrs. These are data or encoded loader bytes,
; not instructions to execute.
; Sprite 7, pointer $c7
 !byte $00,$00,$00
; Book line 2070: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2071: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2072: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$10,$00
; Book line 2073: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$10,$00
; Book line 2074: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$10,$00
; Book line 2075: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$10,$00
; Book line 2076: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$10,$00
; Book line 2077: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$10,$00
; Book line 2078: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$10,$00
; Book line 2079: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$10,$00
; Book line 2080: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$10,$00
; Book line 2081: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$10,$00
; Book line 2082: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$10,$00
; Book line 2083: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$10,$00
; Book line 2084: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$10,$00
; Book line 2085: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2086: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2087: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2088: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2089: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00
; Book line 2090: Emit 3 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 0
; Book line 2091: Emit 1 byte in the shown order for diveptrs. These are data or encoded loader bytes,
; not instructions to execute.

; V23: six independently aligned 64-byte explosion animation frames.
; Alien: $c8,$c9,$ca. Player: $cb,$cc,$cd.
*=$3200
; Book line 2095: Place subsequent output at C64 address $3200; the origin directive is processed by
; ACME, not executed by the CPU.
; alien explosion frame 1 (64 bytes)
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2097: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2098: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$08,$00,$00,$2c,$00
; Book line 2099: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$ff,$00,$00,$7e,$00,$00,$ff
; Book line 2100: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$7e,$00,$00,$ff,$00,$00
; Book line 2101: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $2c,$00,$00,$08,$00,$00,$00,$00
; Book line 2102: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2103: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2104: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
; alien explosion frame 2 (64 bytes)
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2106: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$91,$00,$00
; Book line 2107: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $52,$00,$00,$4a,$00,$03,$00,$c0
; Book line 2108: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$81,$00,$00,$00,$00,$07,$00
; Book line 2109: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $e0,$00,$00,$00,$00,$81,$00,$03
; Book line 2110: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$c0,$00,$4a,$00,$00,$4a,$00
; Book line 2111: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$89,$00,$00,$00,$00,$00,$00
; Book line 2112: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2113: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
; alien explosion frame 3 (64 bytes)
!byte $00,$10,$00,$02,$10,$80,$01,$10
; Book line 2115: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $80,$01,$00,$80,$00,$00,$00,$18
; Book line 2116: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$18,$04,$00,$20,$00,$00,$00
; Book line 2117: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$28,$00
; Book line 2118: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0a,$00,$00,$00,$00,$00,$00,$00
; Book line 2119: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$0c,$00,$30,$10,$00,$08
; Book line 2120: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$80,$80,$01,$08
; Book line 2121: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $80,$01,$08,$80,$00,$08,$00,$00
; Book line 2122: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
; player explosion frame 1 (64 bytes)
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2124: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2125: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$3c,$00
; Book line 2126: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$7e,$00,$00,$ff,$00,$00,$ff
; Book line 2127: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$ff,$00,$00,$7e,$00,$00
; Book line 2128: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3c,$00,$00,$00,$00,$00,$00,$00
; Book line 2129: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2130: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2131: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
; player explosion frame 2 (64 bytes)
!byte $00,$00,$00,$00,$06,$00,$01,$ce
; Book line 2133: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$01,$ff,$00,$01,$bb,$78,$01
; Book line 2134: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $93,$f8,$3f,$83,$30,$38,$00,$30
; Book line 2135: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $18,$00,$60,$0e,$00,$78,$0e,$00
; Book line 2136: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0e,$18,$00,$1e,$38,$00,$f8,$3f
; Book line 2137: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$60,$1f,$00,$60,$03,$23,$70
; Book line 2138: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $03,$77,$f0,$03,$de,$70,$03,$1c
; Book line 2139: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$0c,$00,$00,$00,$00,$00
; Book line 2140: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
; player explosion frame 3 (64 bytes)
!byte $0f,$bf,$00,$0f,$f3,$fc,$0c,$61
; Book line 2142: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $fc,$0c,$01,$8c,$1c,$00,$0c,$fc
; Book line 2143: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$0c,$c0,$00,$1c,$80,$00,$1f
; Book line 2144: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $c0,$00,$03,$e0,$00,$01,$70,$00
; Book line 2145: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $01,$70,$00,$03,$e0,$00,$0f,$c0
; Book line 2146: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$0e,$c0,$00,$0c,$fc,$00,$06
; Book line 2147: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $fe,$00,$06,$0e,$00,$fe,$06,$31
; Book line 2148: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.
!byte $fe,$06,$f9,$80,$07,$df,$80,$00
; Book line 2149: Emit 8 bytes in the shown order for diveptrs. These are data or encoded loader
; bytes, not instructions to execute.

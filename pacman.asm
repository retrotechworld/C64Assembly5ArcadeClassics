; ============================================================================
; PAC 64 V11 BEGINNER COMMENTED EDITION
; ============================================================================
; This is the same game as pac64_ARCADE_V11.asm. Only comments have changed.
; Reassembling this file must produce an identical PRG, byte for byte.
;
; BUILD (from a terminal opened in the extracted folder):
;   acme -f cbm -o pac64_ARCADE_V11_COMMENTED.prg pac64_ARCADE_V11_COMMENTED.asm
; Then autostart the PRG in VICE; use joystick port 2 and fire to begin.
;
; HOW TO READ A LINE
;   label:          A name for the current address; emits no bytes by itself.
;   lda #7          Put the literal number 7 into CPU register A.
;   lda lives       Read a byte from the address named lives into A.
;   sta lives       Write A into that byte of memory.
;   jsr name        Call a subroutine; RTS returns to the next instruction.
;   !byte / !text   Ask ACME to store data; these are not CPU instructions.
;   ; comment       Text for humans; ignored by the assembler.
;
; NUMBER AND ADDRESS BASICS
;   $ = hexadecimal (base 16); $10 = decimal 16; $ff = decimal 255.
;   # = literal/immediate value. Without #, an operand normally names memory.
;   A, X, Y are 8-bit CPU registers (0..255). Arithmetic wraps at 256.
;   C = carry flag; Z = zero flag; N = negative flag (bit 7 of a result).
;   CMP sets flags without changing A. Bxx branches test those flags.
;   16-bit addresses use LOW byte first, then HIGH byte (little endian).
;   ,x or ,y adds an index. (ZP),y follows a 16-bit zero-page pointer plus Y.
;
; READING ROUTE (see the illustrated tutorial for worked examples)
;   start -> game_loop -> step_player -> can_step -> advance_pixels
;   then eat_tile -> check_collision -> step_ghosts -> draw_sprites
;   finally paint_tile, install_font, next_level, and the SID sound routines.
;
; IMPORTANT DISTINCTIONS
;   Logical tile destination != visible pixel position during interpolation.
;   Map symbols != screen character codes != sprite-picture pointers.
;   Comments document current behavior, including its limitations; they do
;   not silently redesign the score, ghost AI, PAL/NTSC pacing, or artwork.
; ============================================================================


*=$0801 ; Place a BASIC loader at the standard C64 BASIC program start.
; Book line 42: Place subsequent output at C64 address $0801; the origin directive is processed by
; ACME, not executed by the CPU.
!byte $0b,$08,$0a,$00,$9e ; BASIC next-line pointer $080b, line number 10, and token $9e (SYS), in little-endian order.
; Book line 43: Emit 5 bytes in the shown order for program. These are data or encoded loader bytes,
; not instructions to execute.
!text "2064" ; ASCII digits for BASIC SYS 2064; these bytes are read by BASIC, not printed to screen RAM.
; Book line 44: Emit the quoted text as literal text bytes, used here as loader or message data; these
; are not automatically screen codes.
!byte 0,0,0 ; End the BASIC line, then a zero next-line pointer ends the BASIC program.
; Book line 45: Emit 3 bytes in the shown order for program. These are data or encoded loader bytes,
; not instructions to execute.
*=$0810 ; Place the machine-code entry at decimal 2064, matching the SYS text.
; Book line 46: Place subsequent output at C64 address $0810; the origin directive is processed by
; ACME, not executed by the CPU.

SCREEN=$0400 ; character screen RAM base $0400
; Book line 48: Define SCREEN as $0400 (screen RAM in the $0400 screen) at assembly time; this names a
; value or address and emits no storage.
COLOR=$d800 ; Color RAM base $d800
; Book line 49: Define COLOR as $d800 (colour RAM) at assembly time; this names a value or address and
; emits no storage.
JOY=$dc00 ; joystick port 2 input at CIA1 $dc00
; Book line 50: Define JOY as $dc00 (CIA1 port A and joystick 2) at assembly time; this names a value
; or address and emits no storage.
PTR=$07f8 ; sprite-pointer base $07f8; pointer byte times 64 selects a sprite frame in the current VIC bank
; Book line 51: Define PTR as $07f8 (sprite pointer table in the $0400 screen) at assembly time; this
; names a value or address and emits no storage.
ZP=$f8 ; zero-page scratch base $f8: map pointer +0/+1, screen/color pointer +2/+3, neighbor pointer +4/+5
; Book line 52: Define ZP as $f8 at assembly time; this names a value or address and emits no storage.


; ============================================================================
; start - TAKE CONTROL OF THE C64 HARDWARE
; This is the machine-code entry point reached by BASIC SYS 2064. Disable maskable CPU
; interrupts, select RAM under the BASIC/KERNAL ROMs while keeping I/O visible, select the
; screen/font bank, and initialize graphics and sound. The normal BASIC/KERNAL environment
; is not restored on exit.
; ============================================================================
start:
; Book line 62: start names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 sei                        ; Disable maskable CPU interrupts; this game polls the hardware instead of using IRQ handlers.
; Book line 63: Set the interrupt-disable flag to mask ordinary IRQ handling. NMI is not masked, and
; peripheral interrupt sources are not automatically cleared.
 lda #$35                   ; Load A with literal $35 (53 decimal); this also sets Z and N.
; Book line 64: Load A with literal $35 (decimal 53). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ; Write A to CPU memory-banking register: $35 exposes RAM under BASIC/KERNAL while retaining I/O; $33
 ; exposes character ROM for the font copy.
 sta $01
; Book line 67: Store A into the byte at $01 (6510 ROM and I/O banking port). The register and CPU
; flags are unchanged.
 lda #$00                   ; Load A with literal $00; this also sets Z and N.
; Book line 68: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d020                  ; Write A to VIC-II border color.
; Book line 69: Store A into the byte at $d020 (VIC border colour). The register and CPU flags are
; unchanged.
 sta $d021                  ; Write A to VIC-II background color.
; Book line 70: Store A into the byte at $d021 (VIC background colour). The register and CPU flags are
; unchanged.
 lda #$08                   ; Load A with literal $08; this also sets Z and N.
; Book line 71: Load A with literal $08 (decimal 8). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d016                  ; Write A to VIC-II horizontal/multicolor character control; $08 is the normal 40-column character setup here.
; Book line 72: Store A into the byte at $d016 (VIC horizontal control and fine scroll). The register
; and CPU flags are unchanged.
 lda #$1a                   ; Load A with literal $1a (26 decimal); this also sets Z and N.
; Book line 73: Load A with literal $1a (decimal 26). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d018                  ; Write A to VIC-II screen/font pointers; $1a selects screen $0400 and RAM font $2800 within bank 0.
; Book line 74: Store A into the byte at $d018 (VIC screen and font selection). The register and CPU
; flags are unchanged.
 lda #$03                   ; Load A with literal $03; this also sets Z and N.
; Book line 75: Load A with literal $03 (decimal 3). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $dd00                  ; Write A to CIA2 VIC bank selector; low bits 3 choose bank 0 ($0000-$3fff).
; Book line 76: Store A into the byte at $dd00 (CIA2 port A and VIC bank select). The register and CPU
; flags are unchanged.
 jsr install_font           ; Call install_font: Copy ROM characters to a writable RAM font. RTS will return here.
; Book line 77: Call install_font, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr sound_init             ; Call sound_init: Silence and reset all three SID voices. RTS will return here.
; Book line 78: Call sound_init, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr title                  ; Call title: Show readable intro text and wait for fire. RTS will return here.
; Book line 79: Call title, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.

; ============================================================================
; restart - BEGIN A COMPLETELY NEW GAME
; Called after the title or a fresh fire press on GAME OVER. new_game resets score, lives,
; level and pellets; it then returns here to the main loop.
; ============================================================================
restart:
; Book line 86: restart names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr new_game               ; Call new_game: Reset score and lives only for a new game. RTS will return here.
; Book line 87: Call new_game, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.

; ============================================================================
; game_loop - RUN ONE VIDEO FRAME OF THE GAME
; Wait for a raster position, read input, update timers, choose tile targets every 16
; frames, move visible sprites one pixel, test contact every frame, handle level
; completion, draw, and update SID effects. A tile target can change before the visible
; sprite reaches it.
; ============================================================================
game_loop:
; Book line 96: game_loop names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr wait_frame             ; Call wait_frame: Wait for the next raster timing point. RTS will return here.
; Book line 97: Call wait_frame, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr read_joystick          ; Call read_joystick: Buffer a requested direction from joystick port 2. RTS will return here.
; Book line 98: Call read_joystick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 ; Increase 8-bit frame counter; wraps 255 to 0 and drives mouth animation and ghost target phase by 1,
 ; wrapping within 0..255; update Z/N.
 inc tick
; Book line 101: Increase the byte at tick (frame clock) by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
 jsr power_tick             ; Call power_tick: Update short invulnerability and power timers. RTS will return here.
; Book line 102: Call power_tick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda move_phase             ; Read 0..15: choose tile targets at 0 and finish a tile on frame 15 into A; Z/N reflect that byte.
; Book line 103: Load A with the byte at move_phase (tile movement phase 0 to 15). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 bne movement_interpolate   ; If Z=0 (last result nonzero, or comparison unequal), branch to movement_interpolate.
; Book line 104: Branch to movement_interpolate if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 jsr step_player            ; Call step_player: Choose a legal tile target for Pac-Man. RTS will return here.
; Book line 105: Call step_player, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr step_ghosts            ; Call step_ghosts: Choose ghost tile targets from distance fields. RTS will return here.
; Book line 106: Call step_ghosts, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
; Move the visible actors every frame, even when no new tile target was chosen.
movement_interpolate:
; Book line 108: movement_interpolate names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 jsr advance_pixels         ; Call advance_pixels: Move visible actors one pixel toward their targets. RTS will return here.
; Book line 109: Call advance_pixels, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr check_collision        ; Call check_collision: Compare visible positions on every frame. RTS will return here.
; Book line 110: Call check_collision, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
 ; Finish the last pixel of the final tile before changing levels.
 lda move_phase             ; Read 0..15: choose tile targets at 0 and finish a tile on frame 15 into A; Z/N reflect that byte.
; Book line 112: Load A with the byte at move_phase (tile movement phase 0 to 15). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cmp #15                    ; Compare A with #15; leave A unchanged, set Z for equal and C for >=.
; Book line 113: Compare A with literal 15 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne movement_no_collision  ; If Z=0 (last result nonzero, or comparison unequal), branch to movement_no_collision.
; Book line 114: Branch to movement_no_collision if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 ; Read number of remaining dots plus power pellets; reaches zero only once each is consumed into A;
 ; Z/N reflect that byte.
 lda pellets_left
; Book line 117: Load A with the byte at pellets_left (remaining maze pellets). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 bne movement_no_collision  ; If Z=0 (last result nonzero, or comparison unequal), branch to movement_no_collision.
; Book line 118: Branch to movement_no_collision if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 lda lives                  ; Read remaining lives; new_game sets 3 into A; Z/N reflect that byte.
; Book line 119: Load A with the byte at lives (remaining lives). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 beq movement_no_collision  ; If Z=1 (last result zero, or comparison equal), branch to movement_no_collision.
; Book line 120: Branch to movement_no_collision if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 jsr next_level             ; Call next_level: Advance the displayed level while preserving score and lives. RTS will return here.
; Book line 121: Call next_level, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jmp game_draw              ; Continue at game_draw without saving a return address.
; Book line 122: Continue execution at game_draw without saving a return address. Registers and flags
; are unchanged by the jump itself.
; Continue the ordinary frame; the historical name now also covers the no-level-transition
; path.
movement_no_collision:
; Book line 125: movement_no_collision names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 inc move_phase             ; Increase 0..15: choose tile targets at 0 and finish a tile on frame 15 by 1, wrapping within 0..255; update Z/N.
; Book line 126: Increase the byte at move_phase (tile movement phase 0 to 15) by one with 8-bit
; wraparound. Update Z and N; carry is unchanged.
 lda move_phase             ; Read 0..15: choose tile targets at 0 and finish a tile on frame 15 into A; Z/N reflect that byte.
; Book line 127: Load A with the byte at move_phase (tile movement phase 0 to 15). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 and #15                    ; Keep only the A bits selected by #15; zero/nonzero now tests those bits.
; Book line 128: Keep only bits set in both A and literal 15. Save the result in A and update Z and N;
; carry is unchanged.
 sta move_phase             ; Write A to 0..15: choose tile targets at 0 and finish a tile on frame 15.
; Book line 129: Store A into the byte at move_phase (tile movement phase 0 to 15). The register and
; CPU flags are unchanged.
; Write sprite/HUD state and advance non-blocking sound effects.
game_draw:
; Book line 131: game_draw names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr draw_sprites           ; Call draw_sprites: Translate game state into VIC-II sprite settings. RTS will return here.
; Book line 132: Call draw_sprites, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr draw_hud               ; Call draw_hud: Print score lives and level above the maze. RTS will return here.
; Book line 133: Call draw_hud, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr sound_tick             ; Call sound_tick: Advance each sound once without pausing the game. RTS will return here.
; Book line 134: Call sound_tick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda lives                  ; Read remaining lives; new_game sets 3 into A; Z/N reflect that byte.
; Book line 135: Load A with the byte at lives (remaining lives). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 bne game_loop              ; If Z=0 (last result nonzero, or comparison unequal), branch to game_loop.
; Book line 136: Branch to game_loop if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp game_over              ; Continue at game_over without saving a return address.
; Book line 137: Continue execution at game_over without saving a return address. Registers and flags
; are unchanged by the jump itself.


; ============================================================================
; wait_frame - WAIT FOR THE NEXT RASTER TIMING POINT
; Poll the low eight bits of the VIC-II raster counter until it equals $f8, then wait
; until it leaves $f8. This paces the loop at approximately 50 frames/second on PAL or 60
; on NTSC when the frame work finishes in time. $d011 contains the separate ninth raster
; bit; this routine does not read it.
; ============================================================================
wait_frame:
; Book line 147: wait_frame names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
; Wait until the low raster byte reaches $f8.
wait_high:
; Book line 149: wait_high names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda $d012                  ; Read low byte of the VIC-II raster-line counter into A; Z/N reflect that byte.
; Book line 150: Load A with the byte at $d012 (VIC raster counter or IRQ compare). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cmp #$f8                   ; Compare A with #$f8; leave A unchanged, set Z for equal and C for >=.
; Book line 151: Compare A with literal $f8 (decimal 248) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 bne wait_high              ; If Z=0 (last result nonzero, or comparison unequal), branch to wait_high.
; Book line 152: Branch to wait_high if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
; Wait until the raster leaves $f8, preventing two immediate updates at the same timing
; point.
wait_low:
; Book line 155: wait_low names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda $d012                  ; Read low byte of the VIC-II raster-line counter into A; Z/N reflect that byte.
; Book line 156: Load A with the byte at $d012 (VIC raster counter or IRQ compare). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cmp #$f8                   ; Compare A with #$f8; leave A unchanged, set Z for equal and C for >=.
; Book line 157: Compare A with literal $f8 (decimal 248) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 beq wait_low               ; If Z=1 (last result zero, or comparison equal), branch to wait_low.
; Book line 158: Branch to wait_low if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 159: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; clear_screen - BLANK CHARACTER RAM AND SET A DEFAULT INK
; Four 256-byte writes clear 1024 bytes, slightly more than the visible 1000 cells. That
; also touches sprite-pointer storage, so start_level must reinstall pointers after
; clearing. Color RAM is cleared in the same four-page pattern.
; ============================================================================
clear_screen:
; Book line 168: clear_screen names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 169: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 170: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Clear four character-memory pages using one wrapping X index.
clear_loop:
; Book line 172: clear_loop names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sta SCREEN,x               ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 173: Store A into the byte at SCREEN (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 sta SCREEN+256,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 174: Store A into the byte at SCREEN+256 plus index X. The register and CPU flags are
; unchanged.
 sta SCREEN+512,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 175: Store A into the byte at SCREEN+512 plus index X. The register and CPU flags are
; unchanged.
 sta SCREEN+768,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 176: Store A into the byte at SCREEN+768 plus index X. The register and CPU flags are
; unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 177: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne clear_loop             ; If Z=0 (last result nonzero, or comparison unequal), branch to clear_loop.
; Book line 178: Branch to clear_loop if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 179: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 180: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Set four Color RAM pages to white.
color_loop:
; Book line 182: color_loop names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sta COLOR,x                ; Write A to the indicated character ink cell in Color RAM.
; Book line 183: Store A into the byte at COLOR (colour RAM) plus index X. The register and CPU flags
; are unchanged.
 sta COLOR+256,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 184: Store A into the byte at COLOR+256 plus index X. The register and CPU flags are
; unchanged.
 sta COLOR+512,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 185: Store A into the byte at COLOR+512 plus index X. The register and CPU flags are
; unchanged.
 sta COLOR+768,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 186: Store A into the byte at COLOR+768 plus index X. The register and CPU flags are
; unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 187: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne color_loop             ; If Z=0 (last result nonzero, or comparison unequal), branch to color_loop.
; Book line 188: Branch to color_loop if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 189: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Screen codes are C64 screen codes, not PETSCII bytes.

; ============================================================================
; title - SHOW READABLE INTRO TEXT AND WAIT FOR FIRE
; Sprites are hidden. Text bytes are screen codes for the installed font, not PETSCII
; printer commands. First wait for fire to be released, then for a new press, so a button
; held from an earlier screen cannot skip this one.
; ============================================================================
title:
; Book line 199: title names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 200: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d015                  ; Write A to VIC-II sprite enable bits; $1f enables sprites 0..4.
; Book line 201: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 jsr clear_screen           ; Call clear_screen: Blank character RAM and set a default ink. RTS will return here.
; Book line 202: Call clear_screen, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 203: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Print yellow title letters until the zero terminator.
title_letters:
; Book line 205: title_letters names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda title_line,x           ; Read an entry from title_line (see the table description) into A; Z/N reflect that byte.
; Book line 206: Load A with the byte at title_line plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 beq title_prompt           ; If Z=1 (last result zero, or comparison equal), branch to title_prompt.
; Book line 207: Branch to title_prompt if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN+294,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 208: Store A into the byte at SCREEN+294 plus index X. The register and CPU flags are
; unchanged.
 lda #7                     ; Load A with literal 7; this also sets Z and N.
; Book line 209: Load A with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+294,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 210: Store A into the byte at COLOR+294 plus index X. The register and CPU flags are
; unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 211: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne title_letters          ; If Z=0 (last result nonzero, or comparison unequal), branch to title_letters.
; Book line 212: Branch to title_letters if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
; Prepare the white start prompt.
title_prompt:
; Book line 214: title_prompt names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 215: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Print one start-prompt character at a time.
title_prompt_loop:
; Book line 217: title_prompt_loop names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda start_line,x           ; Read an entry from start_line (see the table description) into A; Z/N reflect that byte.
; Book line 218: Load A with the byte at start_line plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 beq title_wait_release     ; If Z=1 (last result zero, or comparison equal), branch to title_wait_release.
; Book line 219: Branch to title_wait_release if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN+610,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 220: Store A into the byte at SCREEN+610 plus index X. The register and CPU flags are
; unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 221: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+610,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 222: Store A into the byte at COLOR+610 plus index X. The register and CPU flags are
; unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 223: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne title_prompt_loop      ; If Z=0 (last result nonzero, or comparison unequal), branch to title_prompt_loop.
; Book line 224: Branch to title_prompt_loop if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
; Wait until fire is not held.
title_wait_release:
; Book line 226: title_wait_release names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda JOY                    ; Read joystick port 2 input at CIA1 $dc00 into A; Z/N reflect that byte.
; Book line 227: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$10                   ; Keep only the A bits selected by #$10; zero/nonzero now tests those bits.
; Book line 228: Keep only bits set in both A and literal $10 (decimal 16). Save the result in A and
; update Z and N; carry is unchanged.
 beq title_wait_release     ; If Z=1 (last result zero, or comparison equal), branch to title_wait_release.
; Book line 229: Branch to title_wait_release if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
; Wait for a fresh fire press, paced by wait_frame.
title_wait_press:
; Book line 231: title_wait_press names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 jsr wait_frame             ; Call wait_frame: Wait for the next raster timing point. RTS will return here.
; Book line 232: Call wait_frame, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda JOY                    ; Read joystick port 2 input at CIA1 $dc00 into A; Z/N reflect that byte.
; Book line 233: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$10                   ; Keep only the A bits selected by #$10; zero/nonzero now tests those bits.
; Book line 234: Keep only bits set in both A and literal $10 (decimal 16). Save the result in A and
; update Z and N; carry is unchanged.
 bne title_wait_press       ; If Z=0 (last result nonzero, or comparison unequal), branch to title_wait_press.
; Book line 235: Branch to title_wait_press if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 236: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; new_game - RESET SCORE AND LIVES ONLY FOR A NEW GAME
; Set three lives, zero score, and level 1. Execution then falls directly into
; start_level; no JMP or JSR is required to reach the next label.
; ============================================================================
new_game:
; Book line 244: new_game names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #3                     ; Load A with literal 3; this also sets Z and N.
; Book line 245: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta lives                  ; Write A to remaining lives; new_game sets 3.
; Book line 246: Store A into the byte at lives (remaining lives). The register and CPU flags are
; unchanged.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 247: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta score                  ; Write A to two bytes reserved, but only score (low byte) is used; displayed score wraps at 256.
; Book line 248: Store A into the byte at score. The register and CPU flags are unchanged.
 sta score+1                ; Write A to two bytes reserved, but only score (low byte) is used; displayed score wraps at 256.
; Book line 249: Store A into the byte at score+1. The register and CPU flags are unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 250: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta level                  ; Write A to displayed level 1..99; later completions still refill level 99.
; Book line 251: Store A into the byte at level. The register and CPU flags are unchanged.

; ============================================================================
; start_level - RESTORE A FRESH MAZE AND RESET THE ACTORS
; Sound, display, pellets, timers, positions and ghost states are reset. Score, remaining
; lives and level are deliberately left alone here, so next_level can reuse this code.
; Rebuild the hardware sprite configuration after clear_screen.
; ============================================================================
start_level:
; Book line 259: start_level names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr sound_init             ; Call sound_init: Silence and reset all three SID voices. RTS will return here.
; Book line 260: Call sound_init, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr clear_screen           ; Call clear_screen: Blank character RAM and set a default ink. RTS will return here.
; Book line 261: Call clear_screen, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr restore_maze           ; Call restore_maze: Copy the immutable map back into the live map. RTS will return here.
; Book line 262: Call restore_maze, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 263: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta tick                   ; Write A to 8-bit frame counter; wraps 255 to 0 and drives mouth animation and ghost target phase.
; Book line 264: Store A into the byte at tick (frame clock). The register and CPU flags are
; unchanged.
 sta power_timer            ; Write A to little-endian 16-bit vulnerability countdown: low byte then high byte.
; Book line 265: Store A into the byte at power_timer. The register and CPU flags are unchanged.
 sta power_timer+1          ; Write A to little-endian 16-bit vulnerability countdown: low byte then high byte.
; Book line 266: Store A into the byte at power_timer+1. The register and CPU flags are unchanged.
 sta hit_cooldown           ; Write A to frames of contact immunity after losing a life; it skips all contact processing.
; Book line 267: Store A into the byte at hit_cooldown. The register and CPU flags are unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 268: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta px                     ; Write A to Pac-Man logical tile column, 0..18; a destination, not his current visible pixel X.
; Book line 269: Store A into the byte at px (logical player column). The register and CPU flags are
; unchanged.
 sta py                     ; Write A to Pac-Man logical tile row, 0..10.
; Book line 270: Store A into the byte at py (logical player row). The register and CPU flags are
; unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 271: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta direction              ; Write A to accepted travel direction: 0 up, 1 right, 2 down, 3 left.
; Book line 272: Store A into the byte at direction. The register and CPU flags are unchanged.
 sta requested              ; Write A to buffered joystick direction; can differ from direction until a turn is legal.
; Book line 273: Store A into the byte at requested. The register and CPU flags are unchanged.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 274: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Initialize one ghost entry at a time.
ghost_init:
; Book line 276: ghost_init names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda ghost_start_x,x        ; Read four spawn columns into A; Z/N reflect that byte.
; Book line 277: Load A with the byte at ghost_start_x plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta gx,x                   ; Write A to four ghost logical tile columns.
; Book line 278: Store A into the byte at gx (ghost tile-column table) plus index X. The register and
; CPU flags are unchanged.
 lda ghost_start_y,x        ; Read four spawn rows into A; Z/N reflect that byte.
; Book line 279: Load A with the byte at ghost_start_y plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta gy,x                   ; Write A to four ghost logical tile rows.
; Book line 280: Store A into the byte at gy (ghost tile-row table) plus index X. The register and CPU
; flags are unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 281: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta gd,x                   ; Write A to four last-selected ghost directions; stored by routing, not used for current sprite selection.
; Book line 282: Store A into the byte at gd plus index X. The register and CPU flags are unchanged.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 283: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ghost_state,x          ; Write A to four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating.
; Book line 284: Store A into the byte at ghost_state (ghost state table) plus index X. The register
; and CPU flags are unchanged.
 sta ghost_regen,x          ; Write A to four regeneration countdowns; decremented at tile decisions, not every frame.
; Book line 285: Store A into the byte at ghost_regen (ghost regeneration countdown table) plus index
; X. The register and CPU flags are unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 286: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #4                     ; Compare X with #4; leave X unchanged, set Z for equal and C for >=.
; Book line 287: Compare X with literal 4 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne ghost_init             ; If Z=0 (last result nonzero, or comparison unequal), branch to ghost_init.
; Book line 288: Branch to ghost_init if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 289: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta move_phase             ; Write A to 0..15: choose tile targets at 0 and finish a tile on frame 15.
; Book line 290: Store A into the byte at move_phase (tile movement phase 0 to 15). The register and
; CPU flags are unchanged.
 jsr sync_pixels            ; Call sync_pixels: Snap all five visible actors to their tile centres. RTS will return here.
; Book line 291: Call sync_pixels, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr draw_maze              ; Call draw_maze: Turn the logical map into screen characters. RTS will return here.
; Book line 292: Call draw_maze, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr draw_hud               ; Call draw_hud: Print score lives and level above the maze. RTS will return here.
; Book line 293: Call draw_hud, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda #$1f                   ; Load A with literal $1f (31 decimal); this also sets Z and N.
; Book line 294: Load A with literal $1f (decimal 31). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d015                  ; Write A to VIC-II sprite enable bits; $1f enables sprites 0..4.
; Book line 295: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 296: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d017                  ; Write A to sprite vertical expansion bits; zero keeps normal height.
; Book line 297: Store A into the byte at $d017 (VIC sprite height expansion). The register and CPU
; flags are unchanged.
 sta $d01d                  ; Write A to sprite horizontal expansion bits; zero keeps normal width.
; Book line 298: Store A into the byte at $d01d (VIC sprite width expansion). The register and CPU
; flags are unchanged.
 lda #$1e                   ; Load A with literal $1e (30 decimal); this also sets Z and N.
; Book line 299: Load A with literal $1e (decimal 30). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d01c                  ; Write A to sprite multicolor bits; $1e makes ghosts 1..4 multicolor and leaves Pac-Man 0 high-resolution.
; Book line 300: Store A into the byte at $d01c (VIC sprite multicolour bits). The register and CPU
; flags are unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 301: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d025                  ; Write A to shared multicolor sprite ink 1, white.
; Book line 302: Store A into the byte at $d025 (shared sprite multicolour 1). The register and CPU
; flags are unchanged.
 lda #6                     ; Load A with literal 6; this also sets Z and N.
; Book line 303: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d026                  ; Write A to shared multicolor sprite ink 3, blue.
; Book line 304: Store A into the byte at $d026 (shared sprite multicolour 2). The register and CPU
; flags are unchanged.
 lda #7                     ; Load A with literal 7; this also sets Z and N.
; Book line 305: Load A with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d027                  ; Write A to Pac-Man sprite color, yellow 7.
; Book line 306: Store A into the byte at $d027 (sprite 0 colour). The register and CPU flags are
; unchanged.
 lda #2                     ; Load A with literal 2; this also sets Z and N.
; Book line 307: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d028                  ; Write A to first ghost body color (indexed addresses reach the other ghosts).
; Book line 308: Store A into the byte at $d028 (sprite 1 colour). The register and CPU flags are
; unchanged.
 lda #10                    ; Load A with literal 10; this also sets Z and N.
; Book line 309: Load A with literal 10. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d029                  ; Write A to second ghost body color.
; Book line 310: Store A into the byte at $d029 (sprite 2 colour). The register and CPU flags are
; unchanged.
 lda #3                     ; Load A with literal 3; this also sets Z and N.
; Book line 311: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d02a                  ; Write A to third ghost body color.
; Book line 312: Store A into the byte at $d02a (sprite 3 colour). The register and CPU flags are
; unchanged.
 lda #8                     ; Load A with literal 8; this also sets Z and N.
; Book line 313: Load A with literal 8. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d02b                  ; Write A to fourth ghost body color.
; Book line 314: Store A into the byte at $d02b (sprite 4 colour). The register and CPU flags are
; unchanged.
 lda #$80                   ; Load A with literal $80 (128 decimal); this also sets Z and N.
; Book line 315: Load A with literal $80 (decimal 128). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta PTR                    ; Write A to sprite-pointer base $07f8; pointer byte times 64 selects a sprite frame in the current VIC bank.
; Book line 316: Store A into the byte at PTR (sprite pointer table in the $0400 screen). The register
; and CPU flags are unchanged.
 lda #$81                   ; Load A with literal $81 (129 decimal); this also sets Z and N.
; Book line 317: Load A with literal $81 (decimal 129). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta PTR+1                  ; Write A to the indicated hardware sprite picture pointer.
; Book line 318: Store A into the byte at PTR+1. The register and CPU flags are unchanged.
 lda #$82                   ; Load A with literal $82 (130 decimal); this also sets Z and N.
; Book line 319: Load A with literal $82 (decimal 130). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta PTR+2                  ; Write A to the indicated hardware sprite picture pointer.
; Book line 320: Store A into the byte at PTR+2. The register and CPU flags are unchanged.
 lda #$83                   ; Load A with literal $83 (131 decimal); this also sets Z and N.
; Book line 321: Load A with literal $83 (decimal 131). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta PTR+3                  ; Write A to the indicated hardware sprite picture pointer.
; Book line 322: Store A into the byte at PTR+3. The register and CPU flags are unchanged.
 lda #$84                   ; Load A with literal $84 (132 decimal); this also sets Z and N.
; Book line 323: Load A with literal $84 (decimal 132). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta PTR+4                  ; Write A to the indicated hardware sprite picture pointer.
; Book line 324: Store A into the byte at PTR+4. The register and CPU flags are unchanged.
 jsr draw_sprites           ; Call draw_sprites: Translate game state into VIC-II sprite settings. RTS will return here.
; Book line 325: Call draw_sprites, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 326: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Each logical maze tile is 2x2 screen characters = 16x16 pixels.
; Wall is a HOLLOW 16x16 outline, not a solid PETSCII block.

; ============================================================================
; draw_maze - TURN THE LOGICAL MAP INTO SCREEN CHARACTERS
; Read 19 columns in each of 11 rows. Map symbols decide the tile type; each tile occupies
; four 8x8 character cells. After the general renderer finishes, redraw the central wall
; region using its precomputed artwork.
; ============================================================================
draw_maze:
; Book line 337: draw_maze names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 338: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Select the live row pointer for the next logical maze row.
maze_row:
; Book line 340: maze_row names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 stx row_index              ; Write X to logical row being painted.
; Book line 341: Store X into the byte at row_index. The register and CPU flags are unchanged.
 lda row_lo,x               ; Read an entry from row_lo (see the table description) into A; Z/N reflect that byte.
; Book line 342: Load A with the byte at row_lo plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta ZP                     ; Write A to zero-page scratch base $f8: map pointer +0/+1, screen/color pointer +2/+3, neighbor pointer +4/+5.
; Book line 343: Store A into the byte at ZP (zero-page scratch base). The register and CPU flags are
; unchanged.
 lda row_hi,x               ; Read an entry from row_hi (see the table description) into A; Z/N reflect that byte.
; Book line 344: Load A with the byte at row_hi plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta ZP+1                   ; Write A to a byte of the zero-page scratch pointers (low byte first).
; Book line 345: Store A into the byte at ZP+1. The register and CPU flags are unchanged.
 ldy #0                     ; Load Y with literal 0; this also sets Z and N.
; Book line 346: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Read and classify one map symbol.
maze_column:
; Book line 348: maze_column names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sty col_index              ; Write Y to logical column being painted.
; Book line 349: Store Y into the byte at col_index. The register and CPU flags are unchanged.
 lda (ZP),y                 ; Read the byte at the 16-bit pointer in $f8/$f9, plus Y into A; Z/N reflect that byte.
; Book line 350: Load A with the byte at the address in zero-page pair ZP and its next byte, plus Y. Z
; records a zero value; N copies bit 7. Carry is unchanged.
 cmp #35                    ; Compare A with #35; leave A unchanged, set Z for equal and C for >=.
; Book line 351: Compare A with literal 35 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq maze_wall              ; If Z=1 (last result zero, or comparison equal), branch to maze_wall.
; Book line 352: Branch to maze_wall if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #111                   ; Compare A with #111; leave A unchanged, set Z for equal and C for >=.
; Book line 353: Compare A with literal 111 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq maze_power             ; If Z=1 (last result zero, or comparison equal), branch to maze_power.
; Book line 354: Branch to maze_power if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #46                    ; Compare A with #46; leave A unchanged, set Z for equal and C for >=.
; Book line 355: Compare A with literal 46 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq maze_pellet            ; If Z=1 (last result zero, or comparison equal), branch to maze_pellet.
; Book line 356: Branch to maze_pellet if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #69                    ; Compare A with #69; leave A unchanged, set Z for equal and C for >=.
; Book line 357: Compare A with literal 69 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq maze_gate              ; If Z=1 (last result zero, or comparison equal), branch to maze_gate.
; Book line 358: Branch to maze_gate if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #72                    ; Compare A with #72; leave A unchanged, set Z for equal and C for >=.
; Book line 359: Compare A with literal 72 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq maze_house             ; If Z=1 (last result zero, or comparison equal), branch to maze_house.
; Book line 360: Branch to maze_house if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #66                    ; Compare A with #66; leave A unchanged, set Z for equal and C for >=.
; Book line 361: Compare A with literal 66 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq maze_house_border      ; If Z=1 (last result zero, or comparison equal), branch to maze_house_border.
; Book line 362: Branch to maze_house_border if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 363: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 bne maze_plot              ; If Z=0 (last result nonzero, or comparison unequal), branch to maze_plot.
; Book line 364: Branch to maze_plot if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
; Treat H as blank interior graphics; movement rules are handled separately.
maze_house:
; Book line 366: maze_house names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 367: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 bne maze_plot              ; If Z=0 (last result nonzero, or comparison unequal), branch to maze_plot.
; Book line 368: Branch to maze_plot if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
; Retained B-marker rendering path; the current maze does not contain B.
maze_house_border:
; Book line 370: maze_house_border names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #112                   ; Load A with literal 112; this also sets Z and N.
; Book line 371: Load A with literal 112. Z records a zero value; N copies bit 7. Carry is unchanged.
 bne maze_plot              ; If Z=0 (last result nonzero, or comparison unequal), branch to maze_plot.
; Book line 372: Branch to maze_plot if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
; Select the gate renderer.
maze_gate:
; Book line 374: maze_gate names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #106                   ; Load A with literal 106; this also sets Z and N.
; Book line 375: Load A with literal 106. Z records a zero value; N copies bit 7. Carry is unchanged.
 bne maze_plot              ; If Z=0 (last result nonzero, or comparison unequal), branch to maze_plot.
; Book line 376: Branch to maze_plot if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
; Compute a neighbor mask and encode its wall tile kind.
maze_wall:
; Book line 378: maze_wall names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr wall_mask              ; Call wall_mask: Inspect four orthogonal wall neighbors. RTS will return here.
; Book line 379: Call wall_mask, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 380: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #128                   ; Add #128 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 381: Add literal 128 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 bne maze_plot              ; If Z=0 (last result nonzero, or comparison unequal), branch to maze_plot.
; Book line 382: Branch to maze_plot if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
; Select the power-pellet renderer.
maze_power:
; Book line 384: maze_power names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #105                   ; Load A with literal 105; this also sets Z and N.
; Book line 385: Load A with literal 105. Z records a zero value; N copies bit 7. Carry is unchanged.
 bne maze_plot              ; If Z=0 (last result nonzero, or comparison unequal), branch to maze_plot.
; Book line 386: Branch to maze_plot if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
; Select the dot renderer.
maze_pellet:
; Book line 388: maze_pellet names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #104                   ; Load A with literal 104; this also sets Z and N.
; Book line 389: Load A with literal 104. Z records a zero value; N copies bit 7. Carry is unchanged.
; Paint the selected tile, then advance across the grid.
maze_plot:
; Book line 391: maze_plot names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sta tile_kind              ; Write A to renderer tile identifier; this is not necessarily the live map character.
; Book line 392: Store A into the byte at tile_kind. The register and CPU flags are unchanged.
 jsr paint_tile             ; Call paint_tile: Paint one 16 by 16 pixel logical tile. RTS will return here.
; Book line 393: Call paint_tile, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 ldy col_index              ; Read logical column being painted into Y; Z/N reflect that byte.
; Book line 394: Load Y with the byte at col_index. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 395: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpy #19                    ; Compare Y with #19; leave Y unchanged, set Z for equal and C for >=.
; Book line 396: Compare Y with literal 19 without changing Y. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne maze_column            ; If Z=0 (last result nonzero, or comparison unequal), branch to maze_column.
; Book line 397: Branch to maze_column if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ldx row_index              ; Read logical row being painted into X; Z/N reflect that byte.
; Book line 398: Load X with the byte at row_index. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 399: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #11                    ; Compare X with #11; leave X unchanged, set Z for equal and C for >=.
; Book line 400: Compare X with literal 11 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne maze_row               ; If Z=0 (last result nonzero, or comparison unequal), branch to maze_row.
; Book line 401: Branch to maze_row if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jsr draw_house_outline     ; Call draw_house_outline: Redraw the central maze with connected house joints. RTS will return here.
; Book line 402: Call draw_house_outline, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 403: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Paint four glyphs at a tile's screen coordinates.

; ============================================================================
; paint_tile - PAINT ONE 16 BY 16 PIXEL LOGICAL TILE
; Inputs are row_index, col_index and tile_kind. ZP+2/+3 first points at character RAM,
; then at Color RAM. Character columns start at 1; tile rows start at screen row 3. The
; renderer can change A, X, Y and flags.
; ============================================================================
paint_tile:
; Book line 413: paint_tile names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ldx row_index              ; Read logical row being painted into X; Z/N reflect that byte.
; Book line 414: Load X with the byte at row_index. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda screen_row_lo,x        ; Read an entry from screen_row_lo (see the table description) into A; Z/N reflect that byte.
; Book line 415: Load A with the byte at screen_row_lo plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta ZP+2                   ; Write A to a byte of the zero-page scratch pointers (low byte first).
; Book line 416: Store A into the byte at ZP+2. The register and CPU flags are unchanged.
 lda screen_row_hi,x        ; Read an entry from screen_row_hi (see the table description) into A; Z/N reflect that byte.
; Book line 417: Load A with the byte at screen_row_hi plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta ZP+3                   ; Write A to a byte of the zero-page scratch pointers (low byte first).
; Book line 418: Store A into the byte at ZP+3. The register and CPU flags are unchanged.
 lda col_index              ; Read logical column being painted into A; Z/N reflect that byte.
; Book line 419: Load A with the byte at col_index. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 asl                        ; Shift A left by one bit (multiply by 2 modulo 256); old bit 7 goes to carry.
; Book line 420: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 421: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #1                     ; Add #1 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 422: Add literal 1 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 tay                        ; Copy A into Y; A is unchanged, Z/N follow the copied byte.
; Book line 423: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda tile_kind              ; Read renderer tile identifier; this is not necessarily the live map character into A; Z/N reflect that byte.
; Book line 424: Load A with the byte at tile_kind. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #128                   ; Compare A with #128; leave A unchanged, set Z for equal and C for >=.
; Book line 425: Compare A with literal 128 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc plot_not_wall          ; If C=0 (after CMP: unsigned value < operand), branch to plot_not_wall.
; Book line 426: Branch to plot_not_wall if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 cmp #144                   ; Compare A with #144; leave A unchanged, set Z for equal and C for >=.
; Book line 427: Compare A with literal 144 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc plot_wall              ; If C=0 (after CMP: unsigned value < operand), branch to plot_wall.
; Book line 428: Branch to plot_wall if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
; Dispatch non-wall tile identifiers to their drawing paths.
plot_not_wall:
; Book line 430: plot_not_wall names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 cmp #104                   ; Compare A with #104; leave A unchanged, set Z for equal and C for >=.
; Book line 431: Compare A with literal 104 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne skip_plot_dot          ; If Z=0 (last result nonzero, or comparison unequal), branch to skip_plot_dot.
; Book line 432: Branch to skip_plot_dot if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 jmp plot_dot               ; Continue at plot_dot without saving a return address.
; Book line 433: Continue execution at plot_dot without saving a return address. Registers and flags
; are unchanged by the jump itself.
; Continue dispatching the non-wall tile type after the preceding comparison.
skip_plot_dot:
; Book line 435: skip_plot_dot names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 cmp #105                   ; Compare A with #105; leave A unchanged, set Z for equal and C for >=.
; Book line 436: Compare A with literal 105 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne skip_plot_power        ; If Z=0 (last result nonzero, or comparison unequal), branch to skip_plot_power.
; Book line 437: Branch to skip_plot_power if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 jmp plot_power             ; Continue at plot_power without saving a return address.
; Book line 438: Continue execution at plot_power without saving a return address. Registers and flags
; are unchanged by the jump itself.
; Continue dispatching the non-wall tile type after the preceding comparison.
skip_plot_power:
; Book line 440: skip_plot_power names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 cmp #106                   ; Compare A with #106; leave A unchanged, set Z for equal and C for >=.
; Book line 441: Compare A with literal 106 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne skip_plot_gate         ; If Z=0 (last result nonzero, or comparison unequal), branch to skip_plot_gate.
; Book line 442: Branch to skip_plot_gate if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 jmp plot_gate              ; Continue at plot_gate without saving a return address.
; Book line 443: Continue execution at plot_gate without saving a return address. Registers and flags
; are unchanged by the jump itself.
; Continue dispatching the non-wall tile type after the preceding comparison.
skip_plot_gate:
; Book line 445: skip_plot_gate names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 cmp #107                   ; Compare A with #107; leave A unchanged, set Z for equal and C for >=.
; Book line 446: Compare A with literal 107 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne skip_plot_house_top    ; If Z=0 (last result nonzero, or comparison unequal), branch to skip_plot_house_top.
; Book line 447: Branch to skip_plot_house_top if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 jmp plot_house             ; Continue at plot_house without saving a return address.
; Book line 448: Continue execution at plot_house without saving a return address. Registers and flags
; are unchanged by the jump itself.
; Continue dispatching the non-wall tile type after the preceding comparison.
skip_plot_house_top:
; Book line 450: skip_plot_house_top names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 cmp #112                   ; Compare A with #112; leave A unchanged, set Z for equal and C for >=.
; Book line 451: Compare A with literal 112 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne skip_plot_house_side   ; If Z=0 (last result nonzero, or comparison unequal), branch to skip_plot_house_side.
; Book line 452: Branch to skip_plot_house_side if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 jmp plot_house             ; Continue at plot_house without saving a return address.
; Book line 453: Continue execution at plot_house without saving a return address. Registers and flags
; are unchanged by the jump itself.
; Continue dispatching the non-wall tile type after the preceding comparison.
skip_plot_house_side:
; Book line 455: skip_plot_house_side names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 cmp #113                   ; Compare A with #113; leave A unchanged, set Z for equal and C for >=.
; Book line 456: Compare A with literal 113 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne skip_plot_house_bottom ; If Z=0 (last result nonzero, or comparison unequal), branch to skip_plot_house_bottom.
; Book line 457: Branch to skip_plot_house_bottom if Z is 0 (nonzero or unequal); otherwise continue
; at the next instruction. Test the current flag, and leave all flags unchanged.
 jmp plot_house             ; Continue at plot_house without saving a return address.
; Book line 458: Continue execution at plot_house without saving a return address. Registers and flags
; are unchanged by the jump itself.
; Continue dispatching the non-wall tile type after the preceding comparison.
skip_plot_house_bottom:
; Book line 460: skip_plot_house_bottom names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 461: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 462: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 463: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 464: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 tya                        ; Copy Y into A; Y is unchanged, Z/N follow the copied byte.
; Book line 465: Copy Y to A; leave Y unchanged. Update Z and N from the copied value; carry is
; unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 466: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #39                    ; Add #39 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 467: Add literal 39 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 tay                        ; Copy A into Y; A is unchanged, Z/N follow the copied byte.
; Book line 468: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 469: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 470: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 471: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 472: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 jmp paint_colour           ; Continue at paint_colour without saving a return address.
; Book line 473: Continue execution at paint_colour without saving a return address. Registers and
; flags are unchanged by the jump itself.

; ============================================================================
; plot_wall - SELECT FOUR GLYPHS FOR ONE WALL TOPOLOGY
; There are sixteen left/right/up/down neighbor masks. Each has four consecutive character
; codes beginning at 128 + mask*4. A diagonal check can replace an otherwise empty joined
; quadrant with a concave corner.
; ============================================================================
plot_wall:
; Book line 481: plot_wall names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sec                        ; Set carry before subtraction (no incoming borrow), or signal a blocked probe.
; Book line 482: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc #128                   ; Subtract #128 and (1-C) from A; carry clear afterward means a borrow.
; Book line 483: Subtract literal 128 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 asl                        ; Shift A left by one bit (multiply by 2 modulo 256); old bit 7 goes to carry.
; Book line 484: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 asl                        ; Shift A left by one bit (multiply by 2 modulo 256); old bit 7 goes to carry.
; Book line 485: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 486: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #128                   ; Add #128 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 487: Add literal 128 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta glyph_code             ; Write A to current screen character for a wall quadrant.
; Book line 488: Store A into the byte at glyph_code. The register and CPU flags are unchanged.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 489: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta wall_quadrant          ; Write A to 0 TL, 1 TR, 2 BL, 3 BR within a wall tile.
; Book line 490: Store A into the byte at wall_quadrant. The register and CPU flags are unchanged.
; Draw one of four wall characters, possibly replacing its inside corner.
plot_wall_quadrant:
; Book line 492: plot_wall_quadrant names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 jsr select_wall_corner     ; Call select_wall_corner: Fill an inside corner only when needed. RTS will return here.
; Book line 493: Call select_wall_corner, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 494: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 inc glyph_code             ; Increase current screen character for a wall quadrant by 1, wrapping within 0..255; update Z/N.
; Book line 495: Increase the byte at glyph_code by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
 inc wall_quadrant          ; Increase 0 TL, 1 TR, 2 BL, 3 BR within a wall tile by 1, wrapping within 0..255; update Z/N.
; Book line 496: Increase the byte at wall_quadrant by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
 lda wall_quadrant          ; Read 0 TL, 1 TR, 2 BL, 3 BR within a wall tile into A; Z/N reflect that byte.
; Book line 497: Load A with the byte at wall_quadrant. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 cmp #4                     ; Compare A with #4; leave A unchanged, set Z for equal and C for >=.
; Book line 498: Compare A with literal 4 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq plot_wall_done         ; If Z=1 (last result zero, or comparison equal), branch to plot_wall_done.
; Book line 499: Branch to plot_wall_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #2                     ; Compare A with #2; leave A unchanged, set Z for equal and C for >=.
; Book line 500: Compare A with literal 2 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne plot_wall_next         ; If Z=0 (last result nonzero, or comparison unequal), branch to plot_wall_next.
; Book line 501: Branch to plot_wall_next if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 tya                        ; Copy Y into A; Y is unchanged, Z/N follow the copied byte.
; Book line 502: Copy Y to A; leave Y unchanged. Update Z and N from the copied value; carry is
; unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 503: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #39                    ; Add #39 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 504: Add literal 39 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 tay                        ; Copy A into Y; A is unchanged, Z/N follow the copied byte.
; Book line 505: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 jmp plot_wall_quadrant     ; Continue at plot_wall_quadrant without saving a return address.
; Book line 506: Continue execution at plot_wall_quadrant without saving a return address. Registers
; and flags are unchanged by the jump itself.
; Move one screen column right within the current tile row.
plot_wall_next:
; Book line 508: plot_wall_next names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 509: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 jmp plot_wall_quadrant     ; Continue at plot_wall_quadrant without saving a return address.
; Book line 510: Continue execution at plot_wall_quadrant without saving a return address. Registers
; and flags are unchanged by the jump itself.
; Finish wall glyphs and set their ink.
plot_wall_done:
; Book line 512: plot_wall_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 jmp paint_colour           ; Continue at paint_colour without saving a return address.
; Book line 513: Continue execution at paint_colour without saving a return address. Registers and
; flags are unchanged by the jump itself.

; Replace a blank joined quadrant only when its diagonal is open.
; Solid 2x2 wall blocks retain their blank interior quadrants.

; ============================================================================
; select_wall_corner - FILL AN INSIDE CORNER ONLY WHEN NEEDED
; The quadrant must join both relevant sides and face a non-wall diagonal. If the diagonal
; is also wall, keep the blank interior rather than drawing a seam through a solid block.
; Y is saved on the CPU stack because the caller needs its screen offset.
; ============================================================================
select_wall_corner:
; Book line 524: select_wall_corner names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 tya                        ; Copy Y into A; Y is unchanged, Z/N follow the copied byte.
; Book line 525: Copy Y to A; leave Y unchanged. Update Z and N from the copied value; carry is
; unchanged.
 pha                        ; Push A on the hardware stack; here it saves the caller's Y after TYA.
; Book line 526: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 ldx wall_quadrant          ; Read 0 TL, 1 TR, 2 BL, 3 BR within a wall tile into X; Z/N reflect that byte.
; Book line 527: Load X with the byte at wall_quadrant. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 lda wall_flags             ; Read four neighbor bits used to choose the wall shape into A; Z/N reflect that byte.
; Book line 528: Load A with the byte at wall_flags. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and corner_required,x      ; Keep only the A bits selected by corner_required,x; zero/nonzero now tests those bits.
; Book line 529: Keep only bits set in both A and the byte at corner_required plus index X. Save the
; result in A and update Z and N; carry is unchanged.
 cmp corner_required,x      ; Compare A with corner_required,x; leave A unchanged, set Z for equal and C for >=.
; Book line 530: Compare A with the byte at corner_required plus index X without changing A. Z means
; equal, C means unsigned greater or equal, and N is the subtraction result bit 7.
 bne corner_original        ; If Z=0 (last result nonzero, or comparison unequal), branch to corner_original.
; Book line 531: Branch to corner_original if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 lda row_index              ; Read logical row being painted into A; Z/N reflect that byte.
; Book line 532: Load A with the byte at row_index. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 533: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc corner_dy,x            ; Add corner_dy,x plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 534: Add the byte at corner_dy plus index X and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp #11                    ; Compare A with #11; leave A unchanged, set Z for equal and C for >=.
; Book line 535: Compare A with literal 11 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcs corner_original        ; If C=1 (after CMP: unsigned value >= operand), branch to corner_original.
; Book line 536: Branch to corner_original if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 tax                        ; Copy A into X; A is unchanged, Z/N follow the copied byte.
; Book line 537: Copy A to X; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda row_lo,x               ; Read an entry from row_lo (see the table description) into A; Z/N reflect that byte.
; Book line 538: Load A with the byte at row_lo plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta ZP+4                   ; Write A to a byte of the zero-page scratch pointers (low byte first).
; Book line 539: Store A into the byte at ZP+4. The register and CPU flags are unchanged.
 lda row_hi,x               ; Read an entry from row_hi (see the table description) into A; Z/N reflect that byte.
; Book line 540: Load A with the byte at row_hi plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta ZP+5                   ; Write A to a byte of the zero-page scratch pointers (low byte first).
; Book line 541: Store A into the byte at ZP+5. The register and CPU flags are unchanged.
 ldx wall_quadrant          ; Read 0 TL, 1 TR, 2 BL, 3 BR within a wall tile into X; Z/N reflect that byte.
; Book line 542: Load X with the byte at wall_quadrant. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 lda col_index              ; Read logical column being painted into A; Z/N reflect that byte.
; Book line 543: Load A with the byte at col_index. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 544: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc corner_dx,x            ; Add corner_dx,x plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 545: Add the byte at corner_dx plus index X and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp #19                    ; Compare A with #19; leave A unchanged, set Z for equal and C for >=.
; Book line 546: Compare A with literal 19 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcs corner_original        ; If C=1 (after CMP: unsigned value >= operand), branch to corner_original.
; Book line 547: Branch to corner_original if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 tay                        ; Copy A into Y; A is unchanged, Z/N follow the copied byte.
; Book line 548: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda (ZP+4),y               ; Read the neighbor-map byte at the pointer in $fc/$fd, plus Y into A; Z/N reflect that byte.
; Book line 549: Load A with the byte at the address in zero-page pair ZP+4 and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
 cmp #35                    ; Compare A with #35; leave A unchanged, set Z for equal and C for >=.
; Book line 550: Compare A with literal 35 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq corner_original        ; If Z=1 (last result zero, or comparison equal), branch to corner_original.
; Book line 551: Branch to corner_original if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 pla                        ; Pop the saved byte into A; TAY then restores the caller's screen offset.
; Book line 552: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 tay                        ; Copy A into Y; A is unchanged, Z/N follow the copied byte.
; Book line 553: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda wall_quadrant          ; Read 0 TL, 1 TR, 2 BL, 3 BR within a wall tile into A; Z/N reflect that byte.
; Book line 554: Load A with the byte at wall_quadrant. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 555: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #192                   ; Add #192 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 556: Add literal 192 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 557: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
; Restore Y and return the normal quadrant glyph.
corner_original:
; Book line 559: corner_original names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 pla                        ; Pop the saved byte into A; TAY then restores the caller's screen offset.
; Book line 560: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 tay                        ; Copy A into Y; A is unchanged, Z/N follow the copied byte.
; Book line 561: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda glyph_code             ; Read current screen character for a wall quadrant into A; Z/N reflect that byte.
; Book line 562: Load A with the byte at glyph_code. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 563: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Required orthogonal neighbor bits for TL/TR/BL/BR concave corners: 5,6,9,10.
corner_required: !byte 5,6,9,10 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 566: corner_required names the data or instruction address. Emit 4 bytes in the shown
; order for corner_required. These are data or encoded loader bytes, not instructions to execute.

; Diagonal column offsets per quadrant; 255 is -1 when used in 8-bit addition.
corner_dx: !byte 255,1,255,1 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 569: corner_dx names the data or instruction address. Emit 4 bytes in the shown order for
; corner_dx. These are data or encoded loader bytes, not instructions to execute.

; Diagonal row offsets per quadrant; 255 is -1 in the same way.
corner_dy: !byte 255,255,1,1 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 572: corner_dy names the data or instruction address. Emit 4 bytes in the shown order for
; corner_dy. These are data or encoded loader bytes, not instructions to execute.
; 0 TL, 1 TR, 2 BL, 3 BR within a wall tile.
wall_quadrant: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 574: wall_quadrant names the data or instruction address. Emit 1 byte in the shown order
; for wall_quadrant. These are data or encoded loader bytes, not instructions to execute.

; Retained legacy house tile drawing path; central artwork is applied after the general
; maze.
plot_house:
; Book line 578: plot_house names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda tile_kind              ; Read renderer tile identifier; this is not necessarily the live map character into A; Z/N reflect that byte.
; Book line 579: Load A with the byte at tile_kind. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 580: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 581: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 582: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 tya                        ; Copy Y into A; Y is unchanged, Z/N follow the copied byte.
; Book line 583: Copy Y to A; leave Y unchanged. Update Z and N from the copied value; carry is
; unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 584: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #39                    ; Add #39 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 585: Add literal 39 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 tay                        ; Copy A into Y; A is unchanged, Z/N follow the copied byte.
; Book line 586: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda tile_kind              ; Read renderer tile identifier; this is not necessarily the live map character into A; Z/N reflect that byte.
; Book line 587: Load A with the byte at tile_kind. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 588: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 589: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 590: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 jmp paint_colour           ; Continue at paint_colour without saving a return address.
; Book line 591: Continue execution at paint_colour without saving a return address. Registers and
; flags are unchanged by the jump itself.
; Leave the upper character row blank and draw the stripe in the lower row.
plot_gate:
; Book line 593: plot_gate names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 594: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 595: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 596: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 597: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 tya                        ; Copy Y into A; Y is unchanged, Z/N follow the copied byte.
; Book line 598: Copy Y to A; leave Y unchanged. Update Z and N from the copied value; carry is
; unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 599: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #39                    ; Add #39 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 600: Add literal 39 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 tay                        ; Copy A into Y; A is unchanged, Z/N follow the copied byte.
; Book line 601: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda #106                   ; Load A with literal 106; this also sets Z and N.
; Book line 602: Load A with literal 106. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 603: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 604: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 lda #106                   ; Load A with literal 106; this also sets Z and N.
; Book line 605: Load A with literal 106. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 606: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 jmp paint_colour           ; Continue at paint_colour without saving a return address.
; Book line 607: Continue execution at paint_colour without saving a return address. Registers and
; flags are unchanged by the jump itself.
; Use a dot only in the lower-left character of this logical tile.
plot_dot:
; Book line 609: plot_dot names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 610: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 611: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 612: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 613: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 tya                        ; Copy Y into A; Y is unchanged, Z/N follow the copied byte.
; Book line 614: Copy Y to A; leave Y unchanged. Update Z and N from the copied value; carry is
; unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 615: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #39                    ; Add #39 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 616: Add literal 39 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 tay                        ; Copy A into Y; A is unchanged, Z/N follow the copied byte.
; Book line 617: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda #104                   ; Load A with literal 104; this also sets Z and N.
; Book line 618: Load A with literal 104. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 619: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 620: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 621: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 622: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 jmp paint_colour           ; Continue at paint_colour without saving a return address.
; Book line 623: Continue execution at paint_colour without saving a return address. Registers and
; flags are unchanged by the jump itself.
; Use the larger pellet in the same lower-left position.
plot_power:
; Book line 625: plot_power names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 626: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 627: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 628: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 629: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 tya                        ; Copy Y into A; Y is unchanged, Z/N follow the copied byte.
; Book line 630: Copy Y to A; leave Y unchanged. Update Z and N from the copied value; carry is
; unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 631: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #39                    ; Add #39 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 632: Add literal 39 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 tay                        ; Copy A into Y; A is unchanged, Z/N follow the copied byte.
; Book line 633: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda #105                   ; Load A with literal 105; this also sets Z and N.
; Book line 634: Load A with literal 105. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 635: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 636: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 637: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 638: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.

; ============================================================================
; paint_colour - GIVE ALL FOUR CHARACTER CELLS THEIR INK
; Regular walls use blue 6; the gate uses light red 10; ordinary floor/pellet tiles use
; white 1. Ghost sprite colors are separate VIC-II registers and are not affected by Color
; RAM.
; ============================================================================
paint_colour:
; Book line 646: paint_colour names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ; Both tile rows share the same color.
 ldx row_index              ; Read logical row being painted into X; Z/N reflect that byte.
; Book line 648: Load X with the byte at row_index. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda color_row_lo,x         ; Read an entry from color_row_lo (see the table description) into A; Z/N reflect that byte.
; Book line 649: Load A with the byte at color_row_lo plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta ZP+2                   ; Write A to a byte of the zero-page scratch pointers (low byte first).
; Book line 650: Store A into the byte at ZP+2. The register and CPU flags are unchanged.
 lda color_row_hi,x         ; Read an entry from color_row_hi (see the table description) into A; Z/N reflect that byte.
; Book line 651: Load A with the byte at color_row_hi plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta ZP+3                   ; Write A to a byte of the zero-page scratch pointers (low byte first).
; Book line 652: Store A into the byte at ZP+3. The register and CPU flags are unchanged.
 lda col_index              ; Read logical column being painted into A; Z/N reflect that byte.
; Book line 653: Load A with the byte at col_index. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 asl                        ; Shift A left by one bit (multiply by 2 modulo 256); old bit 7 goes to carry.
; Book line 654: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 655: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #1                     ; Add #1 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 656: Add literal 1 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 tay                        ; Copy A into Y; A is unchanged, Z/N follow the copied byte.
; Book line 657: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda tile_kind              ; Read renderer tile identifier; this is not necessarily the live map character into A; Z/N reflect that byte.
; Book line 658: Load A with the byte at tile_kind. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #128                   ; Compare A with #128; leave A unchanged, set Z for equal and C for >=.
; Book line 659: Compare A with literal 128 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc color_open             ; If C=0 (after CMP: unsigned value < operand), branch to color_open.
; Book line 660: Branch to color_open if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 cmp #144                   ; Compare A with #144; leave A unchanged, set Z for equal and C for >=.
; Book line 661: Compare A with literal 144 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc blue_wall              ; If C=0 (after CMP: unsigned value < operand), branch to blue_wall.
; Book line 662: Branch to blue_wall if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
; Choose colors for non-wall tiles.
color_open:
; Book line 664: color_open names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda tile_kind              ; Read renderer tile identifier; this is not necessarily the live map character into A; Z/N reflect that byte.
; Book line 665: Load A with the byte at tile_kind. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #106                   ; Compare A with #106; leave A unchanged, set Z for equal and C for >=.
; Book line 666: Compare A with literal 106 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne regular_open_color     ; If Z=0 (last result nonzero, or comparison unequal), branch to regular_open_color.
; Book line 667: Branch to regular_open_color if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 lda #10                    ; Load A with literal 10; this also sets Z and N.
; Book line 668: Load A with literal 10. Z records a zero value; N copies bit 7. Carry is unchanged.
 bne color_set              ; If Z=0 (last result nonzero, or comparison unequal), branch to color_set.
; Book line 669: Branch to color_set if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
; Ordinary floor/pellet ink is white.
regular_open_color:
; Book line 671: regular_open_color names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 672: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 bne color_set              ; If Z=0 (last result nonzero, or comparison unequal), branch to color_set.
; Book line 673: Branch to color_set if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
; Wall ink is blue.
blue_wall:
; Book line 675: blue_wall names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #6                     ; Load A with literal 6; this also sets Z and N.
; Book line 676: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
; Write the selected ink into all four character cells.
color_set:
; Book line 678: color_set names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sta paint_ink              ; Write A to temporary ink color for all four cells of one tile.
; Book line 679: Store A into the byte at paint_ink. The register and CPU flags are unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 680: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 681: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 682: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 tya                        ; Copy Y into A; Y is unchanged, Z/N follow the copied byte.
; Book line 683: Copy Y to A; leave Y unchanged. Update Z and N from the copied value; carry is
; unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 684: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #39                    ; Add #39 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 685: Add literal 39 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 tay                        ; Copy A into Y; A is unchanged, Z/N follow the copied byte.
; Book line 686: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda paint_ink              ; Read temporary ink color for all four cells of one tile into A; Z/N reflect that byte.
; Book line 687: Load A with the byte at paint_ink. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 688: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 689: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 sta (ZP+2),y               ; Write A to the screen/color byte at the pointer in $fa/$fb, plus Y.
; Book line 690: Store A into the byte at the address in zero-page pair ZP+2 and its next byte, plus
; Y. The register and CPU flags are unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 691: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Connected wall topology (left/right/up/down).
; Each combination maps to a 16x16 four-glyph outline.

; ============================================================================
; wall_mask - INSPECT FOUR ORTHOGONAL WALL NEIGHBORS
; Return a bit mask in A and wall_flags: left=1, right=2, up=4, down=8. Only # counts as a
; wall for this topology. Bounds tests prevent reads outside the 19 by 11 grid.
; ============================================================================
wall_mask:
; Book line 701: wall_mask names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 702: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta wall_flags             ; Write A to four neighbor bits used to choose the wall shape.
; Book line 703: Store A into the byte at wall_flags. The register and CPU flags are unchanged.
 ldy col_index              ; Read logical column being painted into Y; Z/N reflect that byte.
; Book line 704: Load Y with the byte at col_index. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq wall_no_left           ; If Z=1 (last result zero, or comparison equal), branch to wall_no_left.
; Book line 705: Branch to wall_no_left if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dey                        ; Decrease Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 706: Decrease Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 lda (ZP),y                 ; Read the byte at the 16-bit pointer in $f8/$f9, plus Y into A; Z/N reflect that byte.
; Book line 707: Load A with the byte at the address in zero-page pair ZP and its next byte, plus Y. Z
; records a zero value; N copies bit 7. Carry is unchanged.
 cmp #35                    ; Compare A with #35; leave A unchanged, set Z for equal and C for >=.
; Book line 708: Compare A with literal 35 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne wall_no_left           ; If Z=0 (last result nonzero, or comparison unequal), branch to wall_no_left.
; Book line 709: Branch to wall_no_left if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda wall_flags             ; Read four neighbor bits used to choose the wall shape into A; Z/N reflect that byte.
; Book line 710: Load A with the byte at wall_flags. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ora #1                     ; Set in A any bits present in #1; combine masks without clearing other bits.
; Book line 711: Set A bits present in either A or literal 1. Save the result in A and update Z and N;
; carry is unchanged.
 sta wall_flags             ; Write A to four neighbor bits used to choose the wall shape.
; Book line 712: Store A into the byte at wall_flags. The register and CPU flags are unchanged.
; Continue with the right neighbor after the left-side test.
wall_no_left:
; Book line 714: wall_no_left names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ldy col_index              ; Read logical column being painted into Y; Z/N reflect that byte.
; Book line 715: Load Y with the byte at col_index. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cpy #18                    ; Compare Y with #18; leave Y unchanged, set Z for equal and C for >=.
; Book line 716: Compare Y with literal 18 without changing Y. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq wall_no_right          ; If Z=1 (last result zero, or comparison equal), branch to wall_no_right.
; Book line 717: Branch to wall_no_right if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 iny                        ; Increase Y by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 718: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 lda (ZP),y                 ; Read the byte at the 16-bit pointer in $f8/$f9, plus Y into A; Z/N reflect that byte.
; Book line 719: Load A with the byte at the address in zero-page pair ZP and its next byte, plus Y. Z
; records a zero value; N copies bit 7. Carry is unchanged.
 cmp #35                    ; Compare A with #35; leave A unchanged, set Z for equal and C for >=.
; Book line 720: Compare A with literal 35 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne wall_no_right          ; If Z=0 (last result nonzero, or comparison unequal), branch to wall_no_right.
; Book line 721: Branch to wall_no_right if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 lda wall_flags             ; Read four neighbor bits used to choose the wall shape into A; Z/N reflect that byte.
; Book line 722: Load A with the byte at wall_flags. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ora #2                     ; Set in A any bits present in #2; combine masks without clearing other bits.
; Book line 723: Set A bits present in either A or literal 2. Save the result in A and update Z and N;
; carry is unchanged.
 sta wall_flags             ; Write A to four neighbor bits used to choose the wall shape.
; Book line 724: Store A into the byte at wall_flags. The register and CPU flags are unchanged.
; Continue with the upper neighbor.
wall_no_right:
; Book line 726: wall_no_right names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ldx row_index              ; Read logical row being painted into X; Z/N reflect that byte.
; Book line 727: Load X with the byte at row_index. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq wall_no_up             ; If Z=1 (last result zero, or comparison equal), branch to wall_no_up.
; Book line 728: Branch to wall_no_up if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dex                        ; Decrease X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 729: Decrease X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 lda row_lo,x               ; Read an entry from row_lo (see the table description) into A; Z/N reflect that byte.
; Book line 730: Load A with the byte at row_lo plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta ZP+4                   ; Write A to a byte of the zero-page scratch pointers (low byte first).
; Book line 731: Store A into the byte at ZP+4. The register and CPU flags are unchanged.
 lda row_hi,x               ; Read an entry from row_hi (see the table description) into A; Z/N reflect that byte.
; Book line 732: Load A with the byte at row_hi plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta ZP+5                   ; Write A to a byte of the zero-page scratch pointers (low byte first).
; Book line 733: Store A into the byte at ZP+5. The register and CPU flags are unchanged.
 ldy col_index              ; Read logical column being painted into Y; Z/N reflect that byte.
; Book line 734: Load Y with the byte at col_index. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda (ZP+4),y               ; Read the neighbor-map byte at the pointer in $fc/$fd, plus Y into A; Z/N reflect that byte.
; Book line 735: Load A with the byte at the address in zero-page pair ZP+4 and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
 cmp #35                    ; Compare A with #35; leave A unchanged, set Z for equal and C for >=.
; Book line 736: Compare A with literal 35 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne wall_no_up             ; If Z=0 (last result nonzero, or comparison unequal), branch to wall_no_up.
; Book line 737: Branch to wall_no_up if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda wall_flags             ; Read four neighbor bits used to choose the wall shape into A; Z/N reflect that byte.
; Book line 738: Load A with the byte at wall_flags. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ora #4                     ; Set in A any bits present in #4; combine masks without clearing other bits.
; Book line 739: Set A bits present in either A or literal 4. Save the result in A and update Z and N;
; carry is unchanged.
 sta wall_flags             ; Write A to four neighbor bits used to choose the wall shape.
; Book line 740: Store A into the byte at wall_flags. The register and CPU flags are unchanged.
; Continue with the lower neighbor.
wall_no_up:
; Book line 742: wall_no_up names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ldx row_index              ; Read logical row being painted into X; Z/N reflect that byte.
; Book line 743: Load X with the byte at row_index. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cpx #10                    ; Compare X with #10; leave X unchanged, set Z for equal and C for >=.
; Book line 744: Compare X with literal 10 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq wall_no_down           ; If Z=1 (last result zero, or comparison equal), branch to wall_no_down.
; Book line 745: Branch to wall_no_down if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 746: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 lda row_lo,x               ; Read an entry from row_lo (see the table description) into A; Z/N reflect that byte.
; Book line 747: Load A with the byte at row_lo plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta ZP+4                   ; Write A to a byte of the zero-page scratch pointers (low byte first).
; Book line 748: Store A into the byte at ZP+4. The register and CPU flags are unchanged.
 lda row_hi,x               ; Read an entry from row_hi (see the table description) into A; Z/N reflect that byte.
; Book line 749: Load A with the byte at row_hi plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta ZP+5                   ; Write A to a byte of the zero-page scratch pointers (low byte first).
; Book line 750: Store A into the byte at ZP+5. The register and CPU flags are unchanged.
 ldy col_index              ; Read logical column being painted into Y; Z/N reflect that byte.
; Book line 751: Load Y with the byte at col_index. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda (ZP+4),y               ; Read the neighbor-map byte at the pointer in $fc/$fd, plus Y into A; Z/N reflect that byte.
; Book line 752: Load A with the byte at the address in zero-page pair ZP+4 and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
 cmp #35                    ; Compare A with #35; leave A unchanged, set Z for equal and C for >=.
; Book line 753: Compare A with literal 35 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne wall_no_down           ; If Z=0 (last result nonzero, or comparison unequal), branch to wall_no_down.
; Book line 754: Branch to wall_no_down if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda wall_flags             ; Read four neighbor bits used to choose the wall shape into A; Z/N reflect that byte.
; Book line 755: Load A with the byte at wall_flags. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ora #8                     ; Set in A any bits present in #8; combine masks without clearing other bits.
; Book line 756: Set A bits present in either A or literal 8. Save the result in A and update Z and N;
; carry is unchanged.
 sta wall_flags             ; Write A to four neighbor bits used to choose the wall shape.
; Book line 757: Store A into the byte at wall_flags. The register and CPU flags are unchanged.
; Return the completed neighbor mask.
wall_no_down:
; Book line 759: wall_no_down names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda wall_flags             ; Read four neighbor bits used to choose the wall shape into A; Z/N reflect that byte.
; Book line 760: Load A with the byte at wall_flags. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 761: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; HUD is outside the 38x22 character maze.

; ============================================================================
; draw_hud - PRINT SCORE LIVES AND LEVEL ABOVE THE MAZE
; The HUD uses character screen codes. Score conversion works on the low byte only: this
; version has an 8-bit score that wraps after 255. The second reserved score byte is not
; used by the scoring/display routines. Level display is limited to 99.
; ============================================================================
draw_hud:
; Book line 771: draw_hud names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ; Row 0: SCORE 000       LIVES 3       LEVEL 1
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 773: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Copy HUD letters until their zero terminator.
hud_labels:
; Book line 775: hud_labels names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda hud_text,x             ; Read an entry from hud_text (see the table description) into A; Z/N reflect that byte.
; Book line 776: Load A with the byte at hud_text plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 beq hud_values             ; If Z=1 (last result zero, or comparison equal), branch to hud_values.
; Book line 777: Branch to hud_values if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN,x               ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 778: Store A into the byte at SCREEN (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 779: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR,x                ; Write A to the indicated character ink cell in Color RAM.
; Book line 780: Store A into the byte at COLOR (colour RAM) plus index X. The register and CPU flags
; are unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 781: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne hud_labels             ; If Z=0 (last result nonzero, or comparison unequal), branch to hud_labels.
; Book line 782: Branch to hud_labels if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
; Write current lives, level and score digits.
hud_values:
; Book line 784: hud_values names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda lives                  ; Read remaining lives; new_game sets 3 into A; Z/N reflect that byte.
; Book line 785: Load A with the byte at lives (remaining lives). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 786: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #48                    ; Add #48 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 787: Add literal 48 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta SCREEN+24              ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 788: Store A into the byte at SCREEN+24. The register and CPU flags are unchanged.
 lda level                  ; Read displayed level 1..99; later completions still refill level 99 into A; Z/N reflect that byte.
; Book line 789: Load A with the byte at level. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 790: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Repeatedly subtract 10 to obtain the level tens digit.
hud_level_tens:
; Book line 792: hud_level_tens names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 cmp #10                    ; Compare A with #10; leave A unchanged, set Z for equal and C for >=.
; Book line 793: Compare A with literal 10 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc hud_level_digits       ; If C=0 (after CMP: unsigned value < operand), branch to hud_level_digits.
; Book line 794: Branch to hud_level_digits if C is 0; otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 sec                        ; Set carry before subtraction (no incoming borrow), or signal a blocked probe.
; Book line 795: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc #10                    ; Subtract #10 and (1-C) from A; carry clear afterward means a borrow.
; Book line 796: Subtract literal 10 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 797: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne hud_level_tens         ; If Z=0 (last result nonzero, or comparison unequal), branch to hud_level_tens.
; Book line 798: Branch to hud_level_tens if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
; Write level ones; then format the tens column.
hud_level_digits:
; Book line 800: hud_level_digits names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 801: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #48                    ; Add #48 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 802: Add literal 48 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta SCREEN+38              ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 803: Store A into the byte at SCREEN+38. The register and CPU flags are unchanged.
 txa                        ; Copy X into A; X is unchanged, Z/N follow the copied byte.
; Book line 804: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
 beq hud_level_blank        ; If Z=1 (last result zero, or comparison equal), branch to hud_level_blank.
; Book line 805: Branch to hud_level_blank if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 806: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #48                    ; Add #48 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 807: Add literal 48 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 bne hud_level_store        ; If Z=0 (last result nonzero, or comparison unequal), branch to hud_level_store.
; Book line 808: Branch to hud_level_store if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
; Use a blank rather than a leading zero for levels 1..9.
hud_level_blank:
; Book line 810: hud_level_blank names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 811: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
; Store level tens/blank and begin score conversion.
hud_level_store:
; Book line 813: hud_level_store names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 sta SCREEN+37              ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 814: Store A into the byte at SCREEN+37. The register and CPU flags are unchanged.
 ; Read two bytes reserved, but only score (low byte) is used; displayed score wraps at 256 into A; Z/N
 ; reflect that byte.
 lda score
; Book line 817: Load A with the byte at score. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta score_work             ; Write A to temporary score remainder during decimal digit conversion.
; Book line 818: Store A into the byte at score_work. The register and CPU flags are unchanged.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 819: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta score_hundreds         ; Write A to temporary hundreds digit.
; Book line 820: Store A into the byte at score_hundreds. The register and CPU flags are unchanged.
 sta score_tens             ; Write A to temporary tens digit.
; Book line 821: Store A into the byte at score_tens. The register and CPU flags are unchanged.
; Remove groups of 100 from the low-byte score.
hud_hundreds:
; Book line 823: hud_hundreds names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda score_work             ; Read temporary score remainder during decimal digit conversion into A; Z/N reflect that byte.
; Book line 824: Load A with the byte at score_work. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #100                   ; Compare A with #100; leave A unchanged, set Z for equal and C for >=.
; Book line 825: Compare A with literal 100 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc hud_tens               ; If C=0 (after CMP: unsigned value < operand), branch to hud_tens.
; Book line 826: Branch to hud_tens if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 sec                        ; Set carry before subtraction (no incoming borrow), or signal a blocked probe.
; Book line 827: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc #100                   ; Subtract #100 and (1-C) from A; carry clear afterward means a borrow.
; Book line 828: Subtract literal 100 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta score_work             ; Write A to temporary score remainder during decimal digit conversion.
; Book line 829: Store A into the byte at score_work. The register and CPU flags are unchanged.
 inc score_hundreds         ; Increase temporary hundreds digit by 1, wrapping within 0..255; update Z/N.
; Book line 830: Increase the byte at score_hundreds by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
 jmp hud_hundreds           ; Continue at hud_hundreds without saving a return address.
; Book line 831: Continue execution at hud_hundreds without saving a return address. Registers and
; flags are unchanged by the jump itself.
; Remove groups of 10 from the score remainder.
hud_tens:
; Book line 833: hud_tens names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda score_work             ; Read temporary score remainder during decimal digit conversion into A; Z/N reflect that byte.
; Book line 834: Load A with the byte at score_work. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #10                    ; Compare A with #10; leave A unchanged, set Z for equal and C for >=.
; Book line 835: Compare A with literal 10 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc hud_digits             ; If C=0 (after CMP: unsigned value < operand), branch to hud_digits.
; Book line 836: Branch to hud_digits if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 sec                        ; Set carry before subtraction (no incoming borrow), or signal a blocked probe.
; Book line 837: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc #10                    ; Subtract #10 and (1-C) from A; carry clear afterward means a borrow.
; Book line 838: Subtract literal 10 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta score_work             ; Write A to temporary score remainder during decimal digit conversion.
; Book line 839: Store A into the byte at score_work. The register and CPU flags are unchanged.
 inc score_tens             ; Increase temporary tens digit by 1, wrapping within 0..255; update Z/N.
; Book line 840: Increase the byte at score_tens by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
 jmp hud_tens               ; Continue at hud_tens without saving a return address.
; Book line 841: Continue execution at hud_tens without saving a return address. Registers and flags
; are unchanged by the jump itself.
; Turn the resulting digits 0..9 into screen codes 48..57.
hud_digits:
; Book line 843: hud_digits names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda score_hundreds         ; Read temporary hundreds digit into A; Z/N reflect that byte.
; Book line 844: Load A with the byte at score_hundreds. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 845: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #48                    ; Add #48 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 846: Add literal 48 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta SCREEN+7               ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 847: Store A into the byte at SCREEN+7. The register and CPU flags are unchanged.
 lda score_tens             ; Read temporary tens digit into A; Z/N reflect that byte.
; Book line 848: Load A with the byte at score_tens. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 849: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #48                    ; Add #48 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 850: Add literal 48 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta SCREEN+8               ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 851: Store A into the byte at SCREEN+8. The register and CPU flags are unchanged.
 lda score_work             ; Read temporary score remainder during decimal digit conversion into A; Z/N reflect that byte.
; Book line 852: Load A with the byte at score_work. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 853: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #48                    ; Add #48 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 854: Add literal 48 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta SCREEN+9               ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 855: Store A into the byte at SCREEN+9. The register and CPU flags are unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 856: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Graphics-only redraw derived from the original collision grid.
; No independent rectangle is overlaid on the maze walls.

; ============================================================================
; draw_house_outline - REDRAW THE CENTRAL MAZE WITH CONNECTED HOUSE JOINTS
; central_screen supplies 14 character columns across ten screen rows. A zero entry means
; leave the existing corridor/pellet cell alone. Nonzero entries select custom glyphs. The
; artwork is paired with this exact map; changing walls requires rebuilding it, not only
; editing row strings.
; ============================================================================
draw_house_outline:
; Book line 868: draw_house_outline names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 869: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Process the same X column in all ten central screen rows.
central_outline_loop:
; Book line 871: central_outline_loop names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda central_screen+0,x     ; Read an entry from central_screen (see the table description) into A; Z/N reflect that byte.
; Book line 872: Load A with the byte at central_screen+0 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 beq central_skip_0         ; If Z=1 (last result zero, or comparison equal), branch to central_skip_0.
; Book line 873: Branch to central_skip_0 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN+453,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 874: Store A into the byte at SCREEN+453 plus index X. The register and CPU flags are
; unchanged.
 lda #6                     ; Load A with literal 6; this also sets Z and N.
; Book line 875: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+453,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 876: Store A into the byte at COLOR+453 plus index X. The register and CPU flags are
; unchanged.
; Continue after central screen row 0; zero entries deliberately preserved the original
; cell.
central_skip_0:
; Book line 879: central_skip_0 names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda central_screen+14,x    ; Read an entry from central_screen (see the table description) into A; Z/N reflect that byte.
; Book line 880: Load A with the byte at central_screen+14 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 beq central_skip_1         ; If Z=1 (last result zero, or comparison equal), branch to central_skip_1.
; Book line 881: Branch to central_skip_1 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN+493,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 882: Store A into the byte at SCREEN+493 plus index X. The register and CPU flags are
; unchanged.
 lda #6                     ; Load A with literal 6; this also sets Z and N.
; Book line 883: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+493,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 884: Store A into the byte at COLOR+493 plus index X. The register and CPU flags are
; unchanged.
; Continue after central screen row 1; zero entries deliberately preserved the original
; cell.
central_skip_1:
; Book line 887: central_skip_1 names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda central_screen+28,x    ; Read an entry from central_screen (see the table description) into A; Z/N reflect that byte.
; Book line 888: Load A with the byte at central_screen+28 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 beq central_skip_2         ; If Z=1 (last result zero, or comparison equal), branch to central_skip_2.
; Book line 889: Branch to central_skip_2 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN+533,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 890: Store A into the byte at SCREEN+533 plus index X. The register and CPU flags are
; unchanged.
 lda #6                     ; Load A with literal 6; this also sets Z and N.
; Book line 891: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+533,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 892: Store A into the byte at COLOR+533 plus index X. The register and CPU flags are
; unchanged.
; Continue after central screen row 2; zero entries deliberately preserved the original
; cell.
central_skip_2:
; Book line 895: central_skip_2 names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda central_screen+42,x    ; Read an entry from central_screen (see the table description) into A; Z/N reflect that byte.
; Book line 896: Load A with the byte at central_screen+42 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 beq central_skip_3         ; If Z=1 (last result zero, or comparison equal), branch to central_skip_3.
; Book line 897: Branch to central_skip_3 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN+573,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 898: Store A into the byte at SCREEN+573 plus index X. The register and CPU flags are
; unchanged.
 lda #6                     ; Load A with literal 6; this also sets Z and N.
; Book line 899: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+573,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 900: Store A into the byte at COLOR+573 plus index X. The register and CPU flags are
; unchanged.
; Continue after central screen row 3; zero entries deliberately preserved the original
; cell.
central_skip_3:
; Book line 903: central_skip_3 names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda central_screen+56,x    ; Read an entry from central_screen (see the table description) into A; Z/N reflect that byte.
; Book line 904: Load A with the byte at central_screen+56 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 beq central_skip_4         ; If Z=1 (last result zero, or comparison equal), branch to central_skip_4.
; Book line 905: Branch to central_skip_4 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN+613,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 906: Store A into the byte at SCREEN+613 plus index X. The register and CPU flags are
; unchanged.
 lda #6                     ; Load A with literal 6; this also sets Z and N.
; Book line 907: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+613,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 908: Store A into the byte at COLOR+613 plus index X. The register and CPU flags are
; unchanged.
; Continue after central screen row 4; zero entries deliberately preserved the original
; cell.
central_skip_4:
; Book line 911: central_skip_4 names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda central_screen+70,x    ; Read an entry from central_screen (see the table description) into A; Z/N reflect that byte.
; Book line 912: Load A with the byte at central_screen+70 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 beq central_skip_5         ; If Z=1 (last result zero, or comparison equal), branch to central_skip_5.
; Book line 913: Branch to central_skip_5 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN+653,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 914: Store A into the byte at SCREEN+653 plus index X. The register and CPU flags are
; unchanged.
 lda #6                     ; Load A with literal 6; this also sets Z and N.
; Book line 915: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+653,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 916: Store A into the byte at COLOR+653 plus index X. The register and CPU flags are
; unchanged.
; Continue after central screen row 5; zero entries deliberately preserved the original
; cell.
central_skip_5:
; Book line 919: central_skip_5 names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda central_screen+84,x    ; Read an entry from central_screen (see the table description) into A; Z/N reflect that byte.
; Book line 920: Load A with the byte at central_screen+84 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 beq central_skip_6         ; If Z=1 (last result zero, or comparison equal), branch to central_skip_6.
; Book line 921: Branch to central_skip_6 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN+693,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 922: Store A into the byte at SCREEN+693 plus index X. The register and CPU flags are
; unchanged.
 lda #6                     ; Load A with literal 6; this also sets Z and N.
; Book line 923: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+693,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 924: Store A into the byte at COLOR+693 plus index X. The register and CPU flags are
; unchanged.
; Continue after central screen row 6; zero entries deliberately preserved the original
; cell.
central_skip_6:
; Book line 927: central_skip_6 names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda central_screen+98,x    ; Read an entry from central_screen (see the table description) into A; Z/N reflect that byte.
; Book line 928: Load A with the byte at central_screen+98 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 beq central_skip_7         ; If Z=1 (last result zero, or comparison equal), branch to central_skip_7.
; Book line 929: Branch to central_skip_7 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN+733,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 930: Store A into the byte at SCREEN+733 plus index X. The register and CPU flags are
; unchanged.
 lda #6                     ; Load A with literal 6; this also sets Z and N.
; Book line 931: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+733,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 932: Store A into the byte at COLOR+733 plus index X. The register and CPU flags are
; unchanged.
; Continue after central screen row 7; zero entries deliberately preserved the original
; cell.
central_skip_7:
; Book line 935: central_skip_7 names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda central_screen+112,x   ; Read an entry from central_screen (see the table description) into A; Z/N reflect that byte.
; Book line 936: Load A with the byte at central_screen+112 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 beq central_skip_8         ; If Z=1 (last result zero, or comparison equal), branch to central_skip_8.
; Book line 937: Branch to central_skip_8 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN+773,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 938: Store A into the byte at SCREEN+773 plus index X. The register and CPU flags are
; unchanged.
 lda #6                     ; Load A with literal 6; this also sets Z and N.
; Book line 939: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+773,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 940: Store A into the byte at COLOR+773 plus index X. The register and CPU flags are
; unchanged.
; Continue after central screen row 8; zero entries deliberately preserved the original
; cell.
central_skip_8:
; Book line 943: central_skip_8 names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda central_screen+126,x   ; Read an entry from central_screen (see the table description) into A; Z/N reflect that byte.
; Book line 944: Load A with the byte at central_screen+126 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 beq central_skip_9         ; If Z=1 (last result zero, or comparison equal), branch to central_skip_9.
; Book line 945: Branch to central_skip_9 if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN+813,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 946: Store A into the byte at SCREEN+813 plus index X. The register and CPU flags are
; unchanged.
 lda #6                     ; Load A with literal 6; this also sets Z and N.
; Book line 947: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+813,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 948: Store A into the byte at COLOR+813 plus index X. The register and CPU flags are
; unchanged.
; Continue after central screen row 9; zero entries deliberately preserved the original
; cell.
central_skip_9:
; Book line 951: central_skip_9 names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 952: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #14                    ; Compare X with #14; leave X unchanged, set Z for equal and C for >=.
; Book line 953: Compare X with literal 14 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq central_outline_done   ; If Z=1 (last result zero, or comparison equal), branch to central_outline_done.
; Book line 954: Branch to central_outline_done if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 jmp central_outline_loop   ; Continue at central_outline_loop without saving a return address.
; Book line 955: Continue execution at central_outline_loop without saving a return address. Registers
; and flags are unchanged by the jump itself.
; Recolor the two door characters light red.
central_outline_done:
; Book line 957: central_outline_done names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 ; Pink door joins the top chamber contour in the original E tile.
 lda #10                    ; Load A with literal 10; this also sets Z and N.
; Book line 959: Load A with literal 10. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+539              ; Write A to the indicated character ink cell in Color RAM.
; Book line 960: Store A into the byte at COLOR+539. The register and CPU flags are unchanged.
 sta COLOR+540              ; Write A to the indicated character ink cell in Color RAM.
; Book line 961: Store A into the byte at COLOR+540. The register and CPU flags are unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 962: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; 140 screen-code entries, 14 columns by 10 screen rows. Zero means preserve the existing
; floor/pellet cell. Codes 196 onward select central_glyphs.
central_screen:
; Book line 966: central_screen names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 !byte 196,197,197,198,0,0,0,0,0,0,196,197,197,198 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 967: Emit 14 bytes in the shown order for central_screen. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 200,201,202,203,0,0,0,0,0,0,204,205,201,206 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 968: Emit 14 bytes in the shown order for central_screen. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 0,0,204,207,201,201,201,201,201,201,208,203,0,0 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 969: Emit 14 bytes in the shown order for central_screen. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 0,0,204,203,199,199,199,199,199,199,204,203,0,0 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 970: Emit 14 bytes in the shown order for central_screen. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 196,197,209,203,199,199,199,199,199,199,204,210,197,198 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 971: Emit 14 bytes in the shown order for central_screen. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 200,201,202,203,199,199,199,199,199,199,204,205,201,206 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 972: Emit 14 bytes in the shown order for central_screen. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 0,0,204,210,197,197,197,197,197,197,209,203,0,0 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 973: Emit 14 bytes in the shown order for central_screen. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 0,0,200,201,201,201,201,201,201,201,201,206,0,0 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 974: Emit 14 bytes in the shown order for central_screen. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 975: Emit 14 bytes in the shown order for central_screen. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 976: Emit 14 bytes in the shown order for central_screen. These are data or encoded loader
; bytes, not instructions to execute.

; Custom 8x8 glyph bytes for the central maze and house joints. Glyphs are copied to
; $2e20, which is font code 196.
central_glyphs:
; Book line 980: central_glyphs names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 !byte $00,$00,$3f,$20,$2f,$28,$28,$28,$00,$00,$ff,$00,$ff,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 981: Emit 16 bytes in the shown order for central_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$fc,$04,$f4,$14,$14,$14,$00,$00,$00,$00,$00,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 982: Emit 16 bytes in the shown order for central_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$2f,$20,$3f,$00,$00,$00,$00,$00,$ff,$00,$ff,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 983: Emit 16 bytes in the shown order for central_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$f8,$08,$e8,$28,$28,$14,$14,$14,$14,$14,$14,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 984: Emit 16 bytes in the shown order for central_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$28,$28,$28,$28,$28,$00,$00,$00,$1f,$10,$17,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 985: Emit 16 bytes in the shown order for central_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $14,$14,$14,$f4,$04,$fc,$00,$00,$14,$14,$14,$1f,$14,$17,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 986: Emit 16 bytes in the shown order for central_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$f8,$28,$e8,$28,$28,$28,$28,$e8,$08,$f8,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 987: Emit 16 bytes in the shown order for central_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $14,$14,$17,$10,$1f,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 988: Emit 8 bytes in the shown order for central_glyphs. These are data or encoded loader
; bytes, not instructions to execute.


; ============================================================================
; read_joystick - BUFFER A REQUESTED DIRECTION FROM JOYSTICK PORT 2
; CIA port A at $dc00 has active-low joystick bits: a pressed direction reads zero. Up,
; down, left, right are tested in that priority order. If no direction is pressed,
; requested retains its old value. Actual turning still waits for can_step at a tile
; decision.
; ============================================================================
read_joystick:
; Book line 998: read_joystick names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda JOY                    ; Read joystick port 2 input at CIA1 $dc00 into A; Z/N reflect that byte.
; Book line 999: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #1                     ; Keep only the A bits selected by #1; zero/nonzero now tests those bits.
; Book line 1000: Keep only bits set in both A and literal 1. Save the result in A and update Z and N;
; carry is unchanged.
 bne input_down             ; If Z=0 (last result nonzero, or comparison unequal), branch to input_down.
; Book line 1001: Branch to input_down if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 1002: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta requested              ; Write A to buffered joystick direction; can differ from direction until a turn is legal.
; Book line 1003: Store A into the byte at requested. The register and CPU flags are unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1004: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
; If up was not pressed, test down.
input_down:
; Book line 1006: input_down names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda JOY                    ; Read joystick port 2 input at CIA1 $dc00 into A; Z/N reflect that byte.
; Book line 1007: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #2                     ; Keep only the A bits selected by #2; zero/nonzero now tests those bits.
; Book line 1008: Keep only bits set in both A and literal 2. Save the result in A and update Z and N;
; carry is unchanged.
 bne input_left             ; If Z=0 (last result nonzero, or comparison unequal), branch to input_left.
; Book line 1009: Branch to input_left if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #2                     ; Load A with literal 2; this also sets Z and N.
; Book line 1010: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta requested              ; Write A to buffered joystick direction; can differ from direction until a turn is legal.
; Book line 1011: Store A into the byte at requested. The register and CPU flags are unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1012: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
; If down was not pressed, test left.
input_left:
; Book line 1014: input_left names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda JOY                    ; Read joystick port 2 input at CIA1 $dc00 into A; Z/N reflect that byte.
; Book line 1015: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #4                     ; Keep only the A bits selected by #4; zero/nonzero now tests those bits.
; Book line 1016: Keep only bits set in both A and literal 4. Save the result in A and update Z and N;
; carry is unchanged.
 bne input_right            ; If Z=0 (last result nonzero, or comparison unequal), branch to input_right.
; Book line 1017: Branch to input_right if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #3                     ; Load A with literal 3; this also sets Z and N.
; Book line 1018: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta requested              ; Write A to buffered joystick direction; can differ from direction until a turn is legal.
; Book line 1019: Store A into the byte at requested. The register and CPU flags are unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1020: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
; If left was not pressed, test right.
input_right:
; Book line 1022: input_right names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda JOY                    ; Read joystick port 2 input at CIA1 $dc00 into A; Z/N reflect that byte.
; Book line 1023: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #8                     ; Keep only the A bits selected by #8; zero/nonzero now tests those bits.
; Book line 1024: Keep only bits set in both A and literal 8. Save the result in A and update Z and N;
; carry is unchanged.
 bne input_done             ; If Z=0 (last result nonzero, or comparison unequal), branch to input_done.
; Book line 1025: Branch to input_done if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 1026: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta requested              ; Write A to buffered joystick direction; can differ from direction until a turn is legal.
; Book line 1027: Store A into the byte at requested. The register and CPU flags are unchanged.
; Return; if nothing was pressed, keep the previous requested direction.
input_done:
; Book line 1029: input_done names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1030: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Return C clear if adjacent tile is open.
; Input: A direction, X current X, Y current Y.

; ============================================================================
; can_step - TEST ONE NEIGHBORING TILE WITHOUT MOVING THE ACTOR
; Inputs: A=direction (0 up, 1 right, 2 down, 3 left), X=current tile column, Y=current
; tile row. Output: C=0 if allowed, C=1 if blocked; probe_x/probe_y hold the candidate.
; actor_is_ghost allows H and E only for ghosts. This routine uses scratch registers and
; zero-page pointers.
; ============================================================================
can_step:
; Book line 1042: can_step names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sta probe_direction        ; Write A to saved direction while probing a candidate.
; Book line 1043: Store A into the byte at probe_direction. The register and CPU flags are unchanged.
 stx probe_x                ; Write X to candidate tile column produced by can_step.
; Book line 1044: Store X into the byte at probe_x. The register and CPU flags are unchanged.
 sty probe_y                ; Write Y to candidate tile row produced by can_step.
; Book line 1045: Store Y into the byte at probe_y. The register and CPU flags are unchanged.
 lda probe_direction        ; Read saved direction while probing a candidate into A; Z/N reflect that byte.
; Book line 1046: Load A with the byte at probe_direction. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 bne probe_right            ; If Z=0 (last result nonzero, or comparison unequal), branch to probe_right.
; Book line 1047: Branch to probe_right if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec probe_y                ; Decrease candidate tile row produced by can_step by 1, wrapping within 0..255; update Z/N.
; Book line 1048: Decrease the byte at probe_y by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 jmp probe_bounds           ; Continue at probe_bounds without saving a return address.
; Book line 1049: Continue execution at probe_bounds without saving a return address. Registers and
; flags are unchanged by the jump itself.
; Check whether the requested probe direction is right.
probe_right:
; Book line 1051: probe_right names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 cmp #1                     ; Compare A with #1; leave A unchanged, set Z for equal and C for >=.
; Book line 1052: Compare A with literal 1 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne probe_down             ; If Z=0 (last result nonzero, or comparison unequal), branch to probe_down.
; Book line 1053: Branch to probe_down if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inc probe_x                ; Increase candidate tile column produced by can_step by 1, wrapping within 0..255; update Z/N.
; Book line 1054: Increase the byte at probe_x by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 jmp probe_bounds           ; Continue at probe_bounds without saving a return address.
; Book line 1055: Continue execution at probe_bounds without saving a return address. Registers and
; flags are unchanged by the jump itself.
; Check whether it is down.
probe_down:
; Book line 1057: probe_down names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 cmp #2                     ; Compare A with #2; leave A unchanged, set Z for equal and C for >=.
; Book line 1058: Compare A with literal 2 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne probe_left             ; If Z=0 (last result nonzero, or comparison unequal), branch to probe_left.
; Book line 1059: Branch to probe_left if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inc probe_y                ; Increase candidate tile row produced by can_step by 1, wrapping within 0..255; update Z/N.
; Book line 1060: Increase the byte at probe_y by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 jmp probe_bounds           ; Continue at probe_bounds without saving a return address.
; Book line 1061: Continue execution at probe_bounds without saving a return address. Registers and
; flags are unchanged by the jump itself.
; The remaining direction is left.
probe_left:
; Book line 1063: probe_left names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 dec probe_x                ; Decrease candidate tile column produced by can_step by 1, wrapping within 0..255; update Z/N.
; Book line 1064: Decrease the byte at probe_x by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
; Apply the special wrap rule only on logical row 5.
probe_bounds:
; Book line 1066: probe_bounds names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda probe_y                ; Read candidate tile row produced by can_step into A; Z/N reflect that byte.
; Book line 1067: Load A with the byte at probe_y. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #5                     ; Compare A with #5; leave A unchanged, set Z for equal and C for >=.
; Book line 1068: Compare A with literal 5 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne probe_bounds_normal    ; If Z=0 (last result nonzero, or comparison unequal), branch to probe_bounds_normal.
; Book line 1069: Branch to probe_bounds_normal if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 lda probe_x                ; Read candidate tile column produced by can_step into A; Z/N reflect that byte.
; Book line 1070: Load A with the byte at probe_x. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #255                   ; Compare A with #255; leave A unchanged, set Z for equal and C for >=.
; Book line 1071: Compare A with literal 255 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne tunnel_check_right     ; If Z=0 (last result nonzero, or comparison unequal), branch to tunnel_check_right.
; Book line 1072: Branch to tunnel_check_right if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 lda #18                    ; Load A with literal 18; this also sets Z and N.
; Book line 1073: Load A with literal 18. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta probe_x                ; Write A to candidate tile column produced by can_step.
; Book line 1074: Store A into the byte at probe_x. The register and CPU flags are unchanged.
 jmp probe_bounds_normal    ; Continue at probe_bounds_normal without saving a return address.
; Book line 1075: Continue execution at probe_bounds_normal without saving a return address. Registers
; and flags are unchanged by the jump itself.
; Test the opposite tunnel edge.
tunnel_check_right:
; Book line 1077: tunnel_check_right names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 cmp #19                    ; Compare A with #19; leave A unchanged, set Z for equal and C for >=.
; Book line 1078: Compare A with literal 19 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne probe_bounds_normal    ; If Z=0 (last result nonzero, or comparison unequal), branch to probe_bounds_normal.
; Book line 1079: Branch to probe_bounds_normal if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 1080: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta probe_x                ; Write A to candidate tile column produced by can_step.
; Book line 1081: Store A into the byte at probe_x. The register and CPU flags are unchanged.
; Reject out-of-range coordinates, then read the destination map symbol.
probe_bounds_normal:
; Book line 1083: probe_bounds_normal names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda probe_x                ; Read candidate tile column produced by can_step into A; Z/N reflect that byte.
; Book line 1084: Load A with the byte at probe_x. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #19                    ; Compare A with #19; leave A unchanged, set Z for equal and C for >=.
; Book line 1085: Compare A with literal 19 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs probe_blocked          ; If C=1 (after CMP: unsigned value >= operand), branch to probe_blocked.
; Book line 1086: Branch to probe_blocked if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 lda probe_y                ; Read candidate tile row produced by can_step into A; Z/N reflect that byte.
; Book line 1087: Load A with the byte at probe_y. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #11                    ; Compare A with #11; leave A unchanged, set Z for equal and C for >=.
; Book line 1088: Compare A with literal 11 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs probe_blocked          ; If C=1 (after CMP: unsigned value >= operand), branch to probe_blocked.
; Book line 1089: Branch to probe_blocked if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 ldx probe_y                ; Read candidate tile row produced by can_step into X; Z/N reflect that byte.
; Book line 1090: Load X with the byte at probe_y. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda row_lo,x               ; Read an entry from row_lo (see the table description) into A; Z/N reflect that byte.
; Book line 1091: Load A with the byte at row_lo plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta ZP                     ; Write A to zero-page scratch base $f8: map pointer +0/+1, screen/color pointer +2/+3, neighbor pointer +4/+5.
; Book line 1092: Store A into the byte at ZP (zero-page scratch base). The register and CPU flags are
; unchanged.
 lda row_hi,x               ; Read an entry from row_hi (see the table description) into A; Z/N reflect that byte.
; Book line 1093: Load A with the byte at row_hi plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta ZP+1                   ; Write A to a byte of the zero-page scratch pointers (low byte first).
; Book line 1094: Store A into the byte at ZP+1. The register and CPU flags are unchanged.
 ldy probe_x                ; Read candidate tile column produced by can_step into Y; Z/N reflect that byte.
; Book line 1095: Load Y with the byte at probe_x. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda (ZP),y                 ; Read the byte at the 16-bit pointer in $f8/$f9, plus Y into A; Z/N reflect that byte.
; Book line 1096: Load A with the byte at the address in zero-page pair ZP and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
 cmp #35                    ; Compare A with #35; leave A unchanged, set Z for equal and C for >=.
; Book line 1097: Compare A with literal 35 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq probe_blocked          ; If Z=1 (last result zero, or comparison equal), branch to probe_blocked.
; Book line 1098: Branch to probe_blocked if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #66                    ; Compare A with #66; leave A unchanged, set Z for equal and C for >=.
; Book line 1099: Compare A with literal 66 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq probe_blocked          ; If Z=1 (last result zero, or comparison equal), branch to probe_blocked.
; Book line 1100: Branch to probe_blocked if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #72                    ; Compare A with #72; leave A unchanged, set Z for equal and C for >=.
; Book line 1101: Compare A with literal 72 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq probe_house_check      ; If Z=1 (last result zero, or comparison equal), branch to probe_house_check.
; Book line 1102: Branch to probe_house_check if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 cmp #69                    ; Compare A with #69; leave A unchanged, set Z for equal and C for >=.
; Book line 1103: Compare A with literal 69 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq probe_house_check      ; If Z=1 (last result zero, or comparison equal), branch to probe_house_check.
; Book line 1104: Branch to probe_house_check if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 jmp probe_passable         ; Continue at probe_passable without saving a return address.
; Book line 1105: Continue execution at probe_passable without saving a return address. Registers and
; flags are unchanged by the jump itself.
; H/E access depends on whether the actor is a ghost.
probe_house_check:
; Book line 1107: probe_house_check names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda actor_is_ghost         ; Read 0 for player probes, 1 for ghost probes; controls house access into A; Z/N reflect that byte.
; Book line 1108: Load A with the byte at actor_is_ghost (movement probe actor type). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 bne probe_passable         ; If Z=0 (last result nonzero, or comparison unequal), branch to probe_passable.
; Book line 1109: Branch to probe_passable if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 jmp probe_blocked          ; Continue at probe_blocked without saving a return address.
; Book line 1110: Continue execution at probe_blocked without saving a return address. Registers and
; flags are unchanged by the jump itself.
; Return carry clear to mean a legal destination.
probe_passable:
; Book line 1112: probe_passable names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 clc                        ; Clear carry before addition, or return C=0 to signal a passable tile.
; Book line 1113: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1114: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
; Return carry set to mean a blocked destination.
probe_blocked:
; Book line 1116: probe_blocked names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 sec                        ; Set carry before subtraction (no incoming borrow), or signal a blocked probe.
; Book line 1117: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1118: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; step_player - CHOOSE A LEGAL TILE TARGET FOR PAC-MAN
; First try the buffered requested turn; otherwise keep the current direction. A second
; can_step checks that continuing is legal. On success, copy the candidate into logical
; px/py and consume its pellet. Visible motion follows later in advance_pixels.
; ============================================================================
step_player:
; Book line 1127: step_player names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 1128: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta actor_is_ghost         ; Write A to 0 for player probes, 1 for ghost probes; controls house access.
; Book line 1129: Store A into the byte at actor_is_ghost (movement probe actor type). The register
; and CPU flags are unchanged.
 ; Read Pac-Man logical tile column, 0..18; a destination, not his current visible pixel X into X; Z/N
 ; reflect that byte.
 ldx px
; Book line 1132: Load X with the byte at px (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 ldy py                     ; Read Pac-Man logical tile row, 0..10 into Y; Z/N reflect that byte.
; Book line 1133: Load Y with the byte at py (logical player row). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 lda requested              ; Read buffered joystick direction; can differ from direction until a turn is legal into A; Z/N reflect that byte.
; Book line 1134: Load A with the byte at requested. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 jsr can_step               ; Call can_step: Test one neighboring tile without moving the actor. RTS will return here.
; Book line 1135: Call can_step, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 bcs player_keep            ; If C=1 (after CMP: unsigned value >= operand), branch to player_keep.
; Book line 1136: Branch to player_keep if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 lda requested              ; Read buffered joystick direction; can differ from direction until a turn is legal into A; Z/N reflect that byte.
; Book line 1137: Load A with the byte at requested. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta direction              ; Write A to accepted travel direction: 0 up, 1 right, 2 down, 3 left.
; Book line 1138: Store A into the byte at direction. The register and CPU flags are unchanged.
; Try continuing in the accepted direction after considering the buffered turn.
player_keep:
; Book line 1140: player_keep names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ; Read Pac-Man logical tile column, 0..18; a destination, not his current visible pixel X into X; Z/N
 ; reflect that byte.
 ldx px
; Book line 1143: Load X with the byte at px (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 ldy py                     ; Read Pac-Man logical tile row, 0..10 into Y; Z/N reflect that byte.
; Book line 1144: Load Y with the byte at py (logical player row). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 lda direction              ; Read accepted travel direction: 0 up, 1 right, 2 down, 3 left into A; Z/N reflect that byte.
; Book line 1145: Load A with the byte at direction. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 jsr can_step               ; Call can_step: Test one neighboring tile without moving the actor. RTS will return here.
; Book line 1146: Call can_step, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 bcs player_still           ; If C=1 (after CMP: unsigned value >= operand), branch to player_still.
; Book line 1147: Branch to player_still if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 lda probe_x                ; Read candidate tile column produced by can_step into A; Z/N reflect that byte.
; Book line 1148: Load A with the byte at probe_x. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta px                     ; Write A to Pac-Man logical tile column, 0..18; a destination, not his current visible pixel X.
; Book line 1149: Store A into the byte at px (logical player column). The register and CPU flags are
; unchanged.
 lda probe_y                ; Read candidate tile row produced by can_step into A; Z/N reflect that byte.
; Book line 1150: Load A with the byte at probe_y. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta py                     ; Write A to Pac-Man logical tile row, 0..10.
; Book line 1151: Store A into the byte at py (logical player row). The register and CPU flags are
; unchanged.
 jsr eat_tile               ; Call eat_tile: Consume a dot or power pellet at the logical target. RTS will return here.
; Book line 1152: Call eat_tile, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
; Return without moving if neither move is legal.
player_still:
; Book line 1154: player_still names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1155: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; eat_tile - CONSUME A DOT OR POWER PELLET AT THE LOGICAL TARGET
; A normal dot and a power pellet each add one score unit and remove one from
; pellets_left. A power pellet also starts a 300-frame timer and frightens
; normal/frightened ghosts, but not returning eyes or regenerating ghosts. Clearing the
; map cell prevents repeated scoring.
; ============================================================================
eat_tile:
; Book line 1165: eat_tile names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ldx py                     ; Read Pac-Man logical tile row, 0..10 into X; Z/N reflect that byte.
; Book line 1166: Load X with the byte at py (logical player row). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 lda row_lo,x               ; Read an entry from row_lo (see the table description) into A; Z/N reflect that byte.
; Book line 1167: Load A with the byte at row_lo plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta ZP                     ; Write A to zero-page scratch base $f8: map pointer +0/+1, screen/color pointer +2/+3, neighbor pointer +4/+5.
; Book line 1168: Store A into the byte at ZP (zero-page scratch base). The register and CPU flags are
; unchanged.
 lda row_hi,x               ; Read an entry from row_hi (see the table description) into A; Z/N reflect that byte.
; Book line 1169: Load A with the byte at row_hi plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta ZP+1                   ; Write A to a byte of the zero-page scratch pointers (low byte first).
; Book line 1170: Store A into the byte at ZP+1. The register and CPU flags are unchanged.
 ; Read Pac-Man logical tile column, 0..18; a destination, not his current visible pixel X into Y; Z/N
 ; reflect that byte.
 ldy px
; Book line 1173: Load Y with the byte at px (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 lda (ZP),y                 ; Read the byte at the 16-bit pointer in $f8/$f9, plus Y into A; Z/N reflect that byte.
; Book line 1174: Load A with the byte at the address in zero-page pair ZP and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
 cmp #46                    ; Compare A with #46; leave A unchanged, set Z for equal and C for >=.
; Book line 1175: Compare A with literal 46 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq eat_found              ; If Z=1 (last result zero, or comparison equal), branch to eat_found.
; Book line 1176: Branch to eat_found if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #111                   ; Compare A with #111; leave A unchanged, set Z for equal and C for >=.
; Book line 1177: Compare A with literal 111 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne eat_end                ; If Z=0 (last result nonzero, or comparison unequal), branch to eat_end.
; Book line 1178: Branch to eat_end if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #$2c                   ; Load A with literal $2c (44 decimal); this also sets Z and N.
; Book line 1179: Load A with literal $2c (decimal 44). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta power_timer            ; Write A to little-endian 16-bit vulnerability countdown: low byte then high byte.
; Book line 1180: Store A into the byte at power_timer. The register and CPU flags are unchanged.
 lda #$01                   ; Load A with literal $01; this also sets Z and N.
; Book line 1181: Load A with literal $01 (decimal 1). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta power_timer+1          ; Write A to little-endian 16-bit vulnerability countdown: low byte then high byte.
; Book line 1182: Store A into the byte at power_timer+1. The register and CPU flags are unchanged.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1183: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Change only eligible ghosts to state 1.
power_make_frightened:
; Book line 1185: power_make_frightened names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda ghost_state,x          ; Read four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating into A; Z/N reflect that byte.
; Book line 1186: Load A with the byte at ghost_state (ghost state table) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 cmp #2                     ; Compare A with #2; leave A unchanged, set Z for equal and C for >=.
; Book line 1187: Compare A with literal 2 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq power_next_ghost       ; If Z=1 (last result zero, or comparison equal), branch to power_next_ghost.
; Book line 1188: Branch to power_next_ghost if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #3                     ; Compare A with #3; leave A unchanged, set Z for equal and C for >=.
; Book line 1189: Compare A with literal 3 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq power_next_ghost       ; If Z=1 (last result zero, or comparison equal), branch to power_next_ghost.
; Book line 1190: Branch to power_next_ghost if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 1191: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ghost_state,x          ; Write A to four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating.
; Book line 1192: Store A into the byte at ghost_state (ghost state table) plus index X. The register
; and CPU flags are unchanged.
; Move to the next ghost in the four-entry state array.
power_next_ghost:
; Book line 1194: power_next_ghost names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1195: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #4                     ; Compare X with #4; leave X unchanged, set Z for equal and C for >=.
; Book line 1196: Compare X with literal 4 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne power_make_frightened  ; If Z=0 (last result nonzero, or comparison unequal), branch to power_make_frightened.
; Book line 1197: Branch to power_make_frightened if Z is 0 (nonzero or unequal); otherwise continue
; at the next instruction. Test the current flag, and leave all flags unchanged.
; Clear one pellet, award one point and erase its tile graphic.
eat_found:
; Book line 1199: eat_found names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 1200: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta (ZP),y                 ; Write A to the byte at the 16-bit pointer in $f8/$f9, plus Y.
; Book line 1201: Store A into the byte at the address in zero-page pair ZP and its next byte, plus Y.
; The register and CPU flags are unchanged.
 ; Increase two bytes reserved, but only score (low byte) is used; displayed score wraps at 256 by 1,
 ; wrapping within 0..255; update Z/N.
 inc score
; Book line 1204: Increase the byte at score by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 ; Decrease number of remaining dots plus power pellets; reaches zero only once each is consumed by 1,
 ; wrapping within 0..255; update Z/N.
 dec pellets_left
; Book line 1207: Decrease the byte at pellets_left (remaining maze pellets) by one with 8-bit
; wraparound. Update Z and N; carry is unchanged.
 lda py                     ; Read Pac-Man logical tile row, 0..10 into A; Z/N reflect that byte.
; Book line 1208: Load A with the byte at py (logical player row). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta row_index              ; Write A to logical row being painted.
; Book line 1209: Store A into the byte at row_index. The register and CPU flags are unchanged.
 ; Read Pac-Man logical tile column, 0..18; a destination, not his current visible pixel X into A; Z/N
 ; reflect that byte.
 lda px
; Book line 1212: Load A with the byte at px (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta col_index              ; Write A to logical column being painted.
; Book line 1213: Store A into the byte at col_index. The register and CPU flags are unchanged.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 1214: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta tile_kind              ; Write A to renderer tile identifier; this is not necessarily the live map character.
; Book line 1215: Store A into the byte at tile_kind. The register and CPU flags are unchanged.
 jsr paint_tile             ; Call paint_tile: Paint one 16 by 16 pixel logical tile. RTS will return here.
; Book line 1216: Call paint_tile, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr sound_waka             ; Call sound_waka: Start an alternating pellet chomp on SID voice 1. RTS will return here.
; Book line 1217: Call sound_waka, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
; Return; empty tiles do not score or trigger a chomp.
eat_end:
; Book line 1219: eat_end names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1220: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Ghost movement uses the SAME collision grid as Pac-Man.
; Test all four directions and choose the smallest distance; ties keep
; the earlier direction in up/right/down/left order. Eyes target home (9,6).

; ============================================================================
; step_ghosts - CHOOSE GHOST TILE TARGETS FROM DISTANCE FIELDS
; Each ghost tests up/right/down/left and selects the first candidate with the smallest
; distance. Strictly smaller wins; ties keep the earlier direction. Normal and frightened
; ghosts use corner fields; eyes use the home field. This is simple patrol routing, not
; the original arcade personalities or Pac-Man chasing.
; ============================================================================
step_ghosts:
; Book line 1233: step_ghosts names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 1234: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta actor_is_ghost         ; Write A to 0 for player probes, 1 for ghost probes; controls house access.
; Book line 1235: Store A into the byte at actor_is_ghost (movement probe actor type). The register
; and CPU flags are unchanged.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1236: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Process one ghost using its saved index.
ghost_loop:
; Book line 1238: ghost_loop names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 stx ghost_index            ; Write X to which ghost (0..3) the current loop is processing.
; Book line 1239: Store X into the byte at ghost_index. The register and CPU flags are unchanged.
 lda ghost_state,x          ; Read four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating into A; Z/N reflect that byte.
; Book line 1240: Load A with the byte at ghost_state (ghost state table) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 cmp #3                     ; Compare A with #3; leave A unchanged, set Z for equal and C for >=.
; Book line 1241: Compare A with literal 3 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne ghost_select_target    ; If Z=0 (last result nonzero, or comparison unequal), branch to ghost_select_target.
; Book line 1242: Branch to ghost_select_target if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 lda ghost_regen,x          ; Read four regeneration countdowns; decremented at tile decisions, not every frame into A; Z/N reflect that byte.
; Book line 1243: Load A with the byte at ghost_regen (ghost regeneration countdown table) plus index
; X. Z records a zero value; N copies bit 7. Carry is unchanged.
 beq ghost_regen_complete   ; If Z=1 (last result zero, or comparison equal), branch to ghost_regen_complete.
; Book line 1244: Branch to ghost_regen_complete if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 ; Decrease four regeneration countdowns; decremented at tile decisions, not every frame by 1, wrapping
 ; within 0..255; update Z/N.
 dec ghost_regen,x
; Book line 1247: Decrease the byte at ghost_regen (ghost regeneration countdown table) plus index X
; by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 jmp ghost_next             ; Continue at ghost_next without saving a return address.
; Book line 1248: Continue execution at ghost_next without saving a return address. Registers and
; flags are unchanged by the jump itself.
; Regeneration finished: make the ghost normal again.
ghost_regen_complete:
; Book line 1250: ghost_regen_complete names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 1251: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ghost_state,x          ; Write A to four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating.
; Book line 1252: Store A into the byte at ghost_state (ghost state table) plus index X. The register
; and CPU flags are unchanged.
 jmp ghost_next             ; Continue at ghost_next without saving a return address.
; Book line 1253: Continue execution at ghost_next without saving a return address. Registers and
; flags are unchanged by the jump itself.

; Handle eyes reaching home, or select a target field.
ghost_select_target:
; Book line 1256: ghost_select_target names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 ; Eaten ghosts follow a shortest path home.
 cmp #2                     ; Compare A with #2; leave A unchanged, set Z for equal and C for >=.
; Book line 1258: Compare A with literal 2 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne ghost_scatter          ; If Z=0 (last result nonzero, or comparison unequal), branch to ghost_scatter.
; Book line 1259: Branch to ghost_scatter if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 lda gx,x                   ; Read four ghost logical tile columns into A; Z/N reflect that byte.
; Book line 1260: Load A with the byte at gx (ghost tile-column table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cmp #9                     ; Compare A with #9; leave A unchanged, set Z for equal and C for >=.
; Book line 1261: Compare A with literal 9 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne ghost_eyes_target      ; If Z=0 (last result nonzero, or comparison unequal), branch to ghost_eyes_target.
; Book line 1262: Branch to ghost_eyes_target if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 lda gy,x                   ; Read four ghost logical tile rows into A; Z/N reflect that byte.
; Book line 1263: Load A with the byte at gy (ghost tile-row table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cmp #6                     ; Compare A with #6; leave A unchanged, set Z for equal and C for >=.
; Book line 1264: Compare A with literal 6 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne ghost_eyes_target      ; If Z=0 (last result nonzero, or comparison unequal), branch to ghost_eyes_target.
; Book line 1265: Branch to ghost_eyes_target if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 lda #3                     ; Load A with literal 3; this also sets Z and N.
; Book line 1266: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ghost_state,x          ; Write A to four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating.
; Book line 1267: Store A into the byte at ghost_state (ghost state table) plus index X. The register
; and CPU flags are unchanged.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 1268: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ghost_regen,x          ; Write A to four regeneration countdowns; decremented at tile decisions, not every frame.
; Book line 1269: Store A into the byte at ghost_regen (ghost regeneration countdown table) plus index
; X. The register and CPU flags are unchanged.
 jmp ghost_next             ; Continue at ghost_next without saving a return address.
; Book line 1270: Continue execution at ghost_next without saving a return address. Registers and
; flags are unchanged by the jump itself.
; Select field 4, the home distance field.
ghost_eyes_target:
; Book line 1272: ghost_eyes_target names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #4                     ; Load A with literal 4; this also sets Z and N.
; Book line 1273: Load A with literal 4. Z records a zero value; N copies bit 7. Carry is unchanged.
 jmp ghost_set_target       ; Continue at ghost_set_target without saving a return address.
; Book line 1274: Continue execution at ghost_set_target without saving a return address. Registers
; and flags are unchanged by the jump itself.

; Choose one of the corner fields; frightened ghosts currently use the same routing.
ghost_scatter:
; Book line 1277: ghost_scatter names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ; Four separate corner targets, rotated every 128 frames.
 ; This prevents all four ghosts converging on one point.
 ; Read 8-bit frame counter; wraps 255 to 0 and drives mouth animation and ghost target phase into A;
 ; Z/N reflect that byte.
 lda tick
; Book line 1282: Load A with the byte at tick (frame clock). Z records a zero value; N copies bit 7.
; Carry is unchanged.
 and #$80                   ; Keep only the A bits selected by #$80; zero/nonzero now tests those bits.
; Book line 1283: Keep only bits set in both A and literal $80 (decimal 128). Save the result in A and
; update Z and N; carry is unchanged.
 beq ghost_phase_zero       ; If Z=1 (last result zero, or comparison equal), branch to ghost_phase_zero.
; Book line 1284: Branch to ghost_phase_zero if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 1285: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 bne ghost_phase_ready      ; If Z=0 (last result nonzero, or comparison unequal), branch to ghost_phase_ready.
; Book line 1286: Branch to ghost_phase_ready if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
; Use zero target rotation during the lower half of the tick cycle.
ghost_phase_zero:
; Book line 1288: ghost_phase_zero names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 1289: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Add the ghost number and wrap the target index into 0..3.
ghost_phase_ready:
; Book line 1291: ghost_phase_ready names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 1292: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc ghost_index            ; Add ghost_index plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 1293: Add the byte at ghost_index and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 and #3                     ; Keep only the A bits selected by #3; zero/nonzero now tests those bits.
; Book line 1294: Keep only bits set in both A and literal 3. Save the result in A and update Z and N;
; carry is unchanged.
; Reset the best-distance search before testing four directions.
ghost_set_target:
; Book line 1296: ghost_set_target names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 sta ghost_target           ; Write A to distance-field number: 0 NW, 1 NE, 2 SW, 3 SE, 4 home.
; Book line 1297: Store A into the byte at ghost_target. The register and CPU flags are unchanged.
 lda #255                   ; Load A with literal 255; this also sets Z and N.
; Book line 1298: Load A with literal 255. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ghost_best             ; Write A to smallest distance seen so far; 255 means no route found.
; Book line 1299: Store A into the byte at ghost_best. The register and CPU flags are unchanged.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 1300: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ghost_try_dir          ; Write A to candidate direction 0..3.
; Book line 1301: Store A into the byte at ghost_try_dir. The register and CPU flags are unchanged.

; Probe one candidate and look up its distance.
ghost_candidate:
; Book line 1304: ghost_candidate names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ldx ghost_index            ; Read which ghost (0..3) the current loop is processing into X; Z/N reflect that byte.
; Book line 1305: Load X with the byte at ghost_index. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 ldy gy,x                   ; Read four ghost logical tile rows into Y; Z/N reflect that byte.
; Book line 1306: Load Y with the byte at gy (ghost tile-row table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 lda gx,x                   ; Read four ghost logical tile columns into A; Z/N reflect that byte.
; Book line 1307: Load A with the byte at gx (ghost tile-column table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 tax                        ; Copy A into X; A is unchanged, Z/N follow the copied byte.
; Book line 1308: Copy A to X; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda ghost_try_dir          ; Read candidate direction 0..3 into A; Z/N reflect that byte.
; Book line 1309: Load A with the byte at ghost_try_dir. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 jsr can_step               ; Call can_step: Test one neighboring tile without moving the actor. RTS will return here.
; Book line 1310: Call can_step, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 bcs ghost_candidate_next   ; If C=1 (after CMP: unsigned value >= operand), branch to ghost_candidate_next.
; Book line 1311: Branch to ghost_candidate_next if C is 1; otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ; Compute offset into 19x11 distance field.
 ldx probe_y                ; Read candidate tile row produced by can_step into X; Z/N reflect that byte.
; Book line 1313: Load X with the byte at probe_y. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda map_row_offset,x       ; Read an entry from map_row_offset (see the table description) into A; Z/N reflect that byte.
; Book line 1314: Load A with the byte at map_row_offset plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 1315: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc probe_x                ; Add probe_x plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 1316: Add the byte at probe_x and incoming carry to A. Update C, Z, N and V according to
; CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ghost_map_index        ; Write A to candidate flat map index: row*19+column.
; Book line 1317: Store A into the byte at ghost_map_index. The register and CPU flags are unchanged.
 ldx ghost_target           ; Read distance-field number: 0 NW, 1 NE, 2 SW, 3 SE, 4 home into X; Z/N reflect that byte.
; Book line 1318: Load X with the byte at ghost_target. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 lda distance_lo,x          ; Read an entry from distance_lo (see the table description) into A; Z/N reflect that byte.
; Book line 1319: Load A with the byte at distance_lo plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 1320: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc ghost_map_index        ; Add ghost_map_index plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 1321: Add the byte at ghost_map_index and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ZP                     ; Write A to zero-page scratch base $f8: map pointer +0/+1, screen/color pointer +2/+3, neighbor pointer +4/+5.
; Book line 1322: Store A into the byte at ZP (zero-page scratch base). The register and CPU flags are
; unchanged.
 lda distance_hi,x          ; Read an entry from distance_hi (see the table description) into A; Z/N reflect that byte.
; Book line 1323: Load A with the byte at distance_hi plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 adc #0                     ; Add #0 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 1324: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ZP+1                   ; Write A to a byte of the zero-page scratch pointers (low byte first).
; Book line 1325: Store A into the byte at ZP+1. The register and CPU flags are unchanged.
 ldy #0                     ; Load Y with literal 0; this also sets Z and N.
; Book line 1326: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 lda (ZP),y                 ; Read the byte at the 16-bit pointer in $f8/$f9, plus Y into A; Z/N reflect that byte.
; Book line 1327: Load A with the byte at the address in zero-page pair ZP and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
 cmp ghost_best             ; Compare A with ghost_best; leave A unchanged, set Z for equal and C for >=.
; Book line 1328: Compare A with the byte at ghost_best without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 bcs ghost_candidate_next   ; If C=1 (after CMP: unsigned value >= operand), branch to ghost_candidate_next.
; Book line 1329: Branch to ghost_candidate_next if C is 1; otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta ghost_best             ; Write A to smallest distance seen so far; 255 means no route found.
; Book line 1330: Store A into the byte at ghost_best. The register and CPU flags are unchanged.
 lda ghost_try_dir          ; Read candidate direction 0..3 into A; Z/N reflect that byte.
; Book line 1331: Load A with the byte at ghost_try_dir. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta ghost_best_dir         ; Write A to direction of the best candidate.
; Book line 1332: Store A into the byte at ghost_best_dir. The register and CPU flags are unchanged.
 lda probe_x                ; Read candidate tile column produced by can_step into A; Z/N reflect that byte.
; Book line 1333: Load A with the byte at probe_x. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta ghost_best_x           ; Write A to column of the best candidate.
; Book line 1334: Store A into the byte at ghost_best_x. The register and CPU flags are unchanged.
 lda probe_y                ; Read candidate tile row produced by can_step into A; Z/N reflect that byte.
; Book line 1335: Load A with the byte at probe_y. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta ghost_best_y           ; Write A to row of the best candidate.
; Book line 1336: Store A into the byte at ghost_best_y. The register and CPU flags are unchanged.
; Try the next direction, up to four directions total.
ghost_candidate_next:
; Book line 1338: ghost_candidate_next names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 inc ghost_try_dir          ; Increase candidate direction 0..3 by 1, wrapping within 0..255; update Z/N.
; Book line 1339: Increase the byte at ghost_try_dir by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
 lda ghost_try_dir          ; Read candidate direction 0..3 into A; Z/N reflect that byte.
; Book line 1340: Load A with the byte at ghost_try_dir. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 cmp #4                     ; Compare A with #4; leave A unchanged, set Z for equal and C for >=.
; Book line 1341: Compare A with literal 4 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcs ghost_candidates_done  ; If C=1 (after CMP: unsigned value >= operand), branch to ghost_candidates_done.
; Book line 1342: Branch to ghost_candidates_done if C is 1; otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp ghost_candidate        ; Continue at ghost_candidate without saving a return address.
; Book line 1343: Continue execution at ghost_candidate without saving a return address. Registers and
; flags are unchanged by the jump itself.

; Commit the best candidate if one was reachable.
ghost_candidates_done:
; Book line 1346: ghost_candidates_done names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda ghost_best             ; Read smallest distance seen so far; 255 means no route found into A; Z/N reflect that byte.
; Book line 1347: Load A with the byte at ghost_best. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #255                   ; Compare A with #255; leave A unchanged, set Z for equal and C for >=.
; Book line 1348: Compare A with literal 255 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq ghost_next             ; If Z=1 (last result zero, or comparison equal), branch to ghost_next.
; Book line 1349: Branch to ghost_next if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ldx ghost_index            ; Read which ghost (0..3) the current loop is processing into X; Z/N reflect that byte.
; Book line 1350: Load X with the byte at ghost_index. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 lda ghost_best_x           ; Read column of the best candidate into A; Z/N reflect that byte.
; Book line 1351: Load A with the byte at ghost_best_x. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta gx,x                   ; Write A to four ghost logical tile columns.
; Book line 1352: Store A into the byte at gx (ghost tile-column table) plus index X. The register and
; CPU flags are unchanged.
 lda ghost_best_y           ; Read row of the best candidate into A; Z/N reflect that byte.
; Book line 1353: Load A with the byte at ghost_best_y. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta gy,x                   ; Write A to four ghost logical tile rows.
; Book line 1354: Store A into the byte at gy (ghost tile-row table) plus index X. The register and
; CPU flags are unchanged.
 lda ghost_best_dir         ; Read direction of the best candidate into A; Z/N reflect that byte.
; Book line 1355: Load A with the byte at ghost_best_dir. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta gd,x                   ; Write A to four last-selected ghost directions; stored by routing, not used for current sprite selection.
; Book line 1356: Store A into the byte at gd plus index X. The register and CPU flags are unchanged.
; Advance the outer ghost loop.
ghost_next:
; Book line 1358: ghost_next names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ldx ghost_index            ; Read which ghost (0..3) the current loop is processing into X; Z/N reflect that byte.
; Book line 1359: Load X with the byte at ghost_index. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1360: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #4                     ; Compare X with #4; leave X unchanged, set Z for equal and C for >=.
; Book line 1361: Compare X with literal 4 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq ghost_loop_done        ; If Z=1 (last result zero, or comparison equal), branch to ghost_loop_done.
; Book line 1362: Branch to ghost_loop_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp ghost_loop             ; Continue at ghost_loop without saving a return address.
; Book line 1363: Continue execution at ghost_loop without saving a return address. Registers and
; flags are unchanged by the jump itself.
; Return after all four ghosts have been processed.
ghost_loop_done:
; Book line 1365: ghost_loop_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1366: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Compare visible sprite centres every frame, including halfway tile crossings.
; Horizontal differences are signed 16-bit values (the maze crosses X=255).

; ============================================================================
; check_collision - COMPARE VISIBLE POSITIONS ON EVERY FRAME
; Ignore contacts during hit_cooldown. Skip eyes and regenerating ghosts. For each other
; ghost, require a horizontal AND vertical difference between -9 and +9 pixels. X
; subtraction is 16-bit because visible X crosses 255. This catches head-on crossings
; between tile centres.
; ============================================================================
check_collision:
; Book line 1378: check_collision names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ; Read frames of contact immunity after losing a life; it skips all contact processing into A; Z/N
 ; reflect that byte.
 lda hit_cooldown
; Book line 1381: Load A with the byte at hit_cooldown. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne collision_done         ; If Z=0 (last result nonzero, or comparison unequal), branch to collision_done.
; Book line 1382: Branch to collision_done if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1383: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Ignore non-contact ghost states, then compare this ghost with Pac-Man.
collision_loop:
; Book line 1385: collision_loop names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda ghost_state,x          ; Read four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating into A; Z/N reflect that byte.
; Book line 1386: Load A with the byte at ghost_state (ghost state table) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 cmp #2                     ; Compare A with #2; leave A unchanged, set Z for equal and C for >=.
; Book line 1387: Compare A with literal 2 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq collision_next         ; If Z=1 (last result zero, or comparison equal), branch to collision_next.
; Book line 1388: Branch to collision_next if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #3                     ; Compare A with #3; leave A unchanged, set Z for equal and C for >=.
; Book line 1389: Compare A with literal 3 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq collision_next         ; If Z=1 (last result zero, or comparison equal), branch to collision_next.
; Book line 1390: Branch to collision_next if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1391: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 sec                        ; Set carry before subtraction (no incoming borrow), or signal a blocked probe.
; Book line 1392: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda pixel_xlo              ; Read five low bytes of visible hardware X, Pac-Man first into A; Z/N reflect that byte.
; Book line 1393: Load A with the byte at pixel_xlo. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc pixel_xlo,x            ; Subtract pixel_xlo,x and (1-C) from A; carry clear afterward means a borrow.
; Book line 1394: Subtract the byte at pixel_xlo plus index X and (1 minus incoming carry) from A.
; Update C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta collision_dx           ; Write A to scratch low byte of the signed 16-bit player-minus-ghost X difference.
; Book line 1395: Store A into the byte at collision_dx. The register and CPU flags are unchanged.
 lda pixel_xhi              ; Read five high bytes of visible hardware X into A; Z/N reflect that byte.
; Book line 1396: Load A with the byte at pixel_xhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc pixel_xhi,x            ; Subtract pixel_xhi,x and (1-C) from A; carry clear afterward means a borrow.
; Book line 1397: Subtract the byte at pixel_xhi plus index X and (1 minus incoming carry) from A.
; Update C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 beq collision_x_positive   ; If Z=1 (last result zero, or comparison equal), branch to collision_x_positive.
; Book line 1398: Branch to collision_x_positive if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 cmp #255                   ; Compare A with #255; leave A unchanged, set Z for equal and C for >=.
; Book line 1399: Compare A with literal 255 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne collision_skip_pixel   ; If Z=0 (last result nonzero, or comparison unequal), branch to collision_skip_pixel.
; Book line 1400: Branch to collision_skip_pixel if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 lda collision_dx           ; Read scratch low byte of the signed 16-bit player-minus-ghost X difference into A; Z/N reflect that byte.
; Book line 1401: Load A with the byte at collision_dx. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 cmp #247                   ; Compare A with #247; leave A unchanged, set Z for equal and C for >=.
; Book line 1402: Compare A with literal 247 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc collision_skip_pixel   ; If C=0 (after CMP: unsigned value < operand), branch to collision_skip_pixel.
; Book line 1403: Branch to collision_skip_pixel if C is 0; otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp collision_test_y       ; Continue at collision_test_y without saving a return address.
; Book line 1404: Continue execution at collision_test_y without saving a return address. Registers
; and flags are unchanged by the jump itself.
; Accept only nonnegative horizontal differences smaller than 10.
collision_x_positive:
; Book line 1406: collision_x_positive names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda collision_dx           ; Read scratch low byte of the signed 16-bit player-minus-ghost X difference into A; Z/N reflect that byte.
; Book line 1407: Load A with the byte at collision_dx. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 cmp #10                    ; Compare A with #10; leave A unchanged, set Z for equal and C for >=.
; Book line 1408: Compare A with literal 10 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs collision_skip_pixel   ; If C=1 (after CMP: unsigned value >= operand), branch to collision_skip_pixel.
; Book line 1409: Branch to collision_skip_pixel if C is 1; otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
; Horizontal overlap passed; now test vertical separation.
collision_test_y:
; Book line 1411: collision_test_y names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 sec                        ; Set carry before subtraction (no incoming borrow), or signal a blocked probe.
; Book line 1412: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda pixel_y                ; Read five visible hardware Y coordinates into A; Z/N reflect that byte.
; Book line 1413: Load A with the byte at pixel_y. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc pixel_y,x              ; Subtract pixel_y,x and (1-C) from A; carry clear afterward means a borrow.
; Book line 1414: Subtract the byte at pixel_y plus index X and (1 minus incoming carry) from A.
; Update C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 bcs collision_y_positive   ; If C=1 (after CMP: unsigned value >= operand), branch to collision_y_positive.
; Book line 1415: Branch to collision_y_positive if C is 1; otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #247                   ; Compare A with #247; leave A unchanged, set Z for equal and C for >=.
; Book line 1416: Compare A with literal 247 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc collision_skip_pixel   ; If C=0 (after CMP: unsigned value < operand), branch to collision_skip_pixel.
; Book line 1417: Branch to collision_skip_pixel if C is 0; otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp collision_hit          ; Continue at collision_hit without saving a return address.
; Book line 1418: Continue execution at collision_hit without saving a return address. Registers and
; flags are unchanged by the jump itself.
; Accept only nonnegative vertical differences smaller than 10.
collision_y_positive:
; Book line 1420: collision_y_positive names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 cmp #10                    ; Compare A with #10; leave A unchanged, set Z for equal and C for >=.
; Book line 1421: Compare A with literal 10 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs collision_skip_pixel   ; If C=1 (after CMP: unsigned value >= operand), branch to collision_skip_pixel.
; Book line 1422: Branch to collision_skip_pixel if C is 1; otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
; Convert the visible-actor index back into a ghost-array index and resolve contact.
collision_hit:
; Book line 1424: collision_hit names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 dex                        ; Decrease X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1425: Decrease X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 lda ghost_state,x          ; Read four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating into A; Z/N reflect that byte.
; Book line 1426: Load A with the byte at ghost_state (ghost state table) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 cmp #1                     ; Compare A with #1; leave A unchanged, set Z for equal and C for >=.
; Book line 1427: Compare A with literal 1 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq collision_eat          ; If Z=1 (last result zero, or comparison equal), branch to collision_eat.
; Book line 1428: Branch to collision_eat if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec lives                  ; Decrease remaining lives; new_game sets 3 by 1, wrapping within 0..255; update Z/N.
; Book line 1429: Decrease the byte at lives (remaining lives) by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
 lda #60                    ; Load A with literal 60; this also sets Z and N.
; Book line 1430: Load A with literal 60. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta hit_cooldown           ; Write A to frames of contact immunity after losing a life; it skips all contact processing.
; Book line 1431: Store A into the byte at hit_cooldown. The register and CPU flags are unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 1432: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta px                     ; Write A to Pac-Man logical tile column, 0..18; a destination, not his current visible pixel X.
; Book line 1433: Store A into the byte at px (logical player column). The register and CPU flags are
; unchanged.
 sta py                     ; Write A to Pac-Man logical tile row, 0..10.
; Book line 1434: Store A into the byte at py (logical player row). The register and CPU flags are
; unchanged.
 sta direction              ; Write A to accepted travel direction: 0 up, 1 right, 2 down, 3 left.
; Book line 1435: Store A into the byte at direction. The register and CPU flags are unchanged.
 sta requested              ; Write A to buffered joystick direction; can differ from direction until a turn is legal.
; Book line 1436: Store A into the byte at requested. The register and CPU flags are unchanged.
 jsr reset_ghosts           ; Call reset_ghosts: Put ghosts back at their starting tiles. RTS will return here.
; Book line 1437: Call reset_ghosts, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr sound_death            ; Call sound_death: Start the descending life-loss effect on SID voice 3. RTS will return here.
; Book line 1438: Call sound_death, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1439: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
; Undo the temporary +1 index before advancing to the next ghost.
collision_skip_pixel:
; Book line 1441: collision_skip_pixel names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 dex                        ; Decrease X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1442: Decrease X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
; Continue to the next ghost.
collision_next:
; Book line 1444: collision_next names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1445: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #4                     ; Compare X with #4; leave X unchanged, set Z for equal and C for >=.
; Book line 1446: Compare X with literal 4 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne collision_loop         ; If Z=0 (last result nonzero, or comparison unequal), branch to collision_loop.
; Book line 1447: Branch to collision_loop if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
; Return after immunity or after all ghosts were checked.
collision_done:
; Book line 1449: collision_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1450: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ============================================================================
; collision_eat - TURN A FRIGHTENED GHOST INTO RETURNING EYES
; Set state 2, add two score units, and trigger the separate SID ghost effect. Position
; stays where it is logically; subsequent tile decisions use the home distance field.
; Continue the loop so multiple contacting frightened ghosts can be processed.
; ============================================================================
collision_eat:
; Book line 1458: collision_eat names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #2                     ; Load A with literal 2; this also sets Z and N.
; Book line 1459: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ghost_state,x          ; Write A to four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating.
; Book line 1460: Store A into the byte at ghost_state (ghost state table) plus index X. The register
; and CPU flags are unchanged.
 ; Increase two bytes reserved, but only score (low byte) is used; displayed score wraps at 256 by 1,
 ; wrapping within 0..255; update Z/N.
 inc score
; Book line 1463: Increase the byte at score by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 ; Increase two bytes reserved, but only score (low byte) is used; displayed score wraps at 256 by 1,
 ; wrapping within 0..255; update Z/N.
 inc score
; Book line 1466: Increase the byte at score by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 jsr sound_ghost            ; Call sound_ghost: Start a rising eaten-ghost effect on SID voice 2. RTS will return here.
; Book line 1467: Call sound_ghost, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jmp collision_next         ; Continue at collision_next without saving a return address.
; Book line 1468: Continue execution at collision_next without saving a return address. Registers and
; flags are unchanged by the jump itself.
; scratch low byte of the signed 16-bit player-minus-ghost X difference.
collision_dx: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 1470: collision_dx names the data or instruction address. Emit 1 byte in the shown order
; for collision_dx. These are data or encoded loader bytes, not instructions to execute.


; ============================================================================
; reset_ghosts - PUT GHOSTS BACK AT THEIR STARTING TILES
; Restore all four ghost positions, directions and states after a life is lost, then
; synchronize all visible pixel positions immediately. Player px/py were already reset by
; the collision code.
; ============================================================================
reset_ghosts:
; Book line 1479: reset_ghosts names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1480: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Restore one ghost and clear its state/regen counter.
reset_ghost_loop:
; Book line 1482: reset_ghost_loop names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda ghost_start_x,x        ; Read four spawn columns into A; Z/N reflect that byte.
; Book line 1483: Load A with the byte at ghost_start_x plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta gx,x                   ; Write A to four ghost logical tile columns.
; Book line 1484: Store A into the byte at gx (ghost tile-column table) plus index X. The register and
; CPU flags are unchanged.
 lda ghost_start_y,x        ; Read four spawn rows into A; Z/N reflect that byte.
; Book line 1485: Load A with the byte at ghost_start_y plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta gy,x                   ; Write A to four ghost logical tile rows.
; Book line 1486: Store A into the byte at gy (ghost tile-row table) plus index X. The register and
; CPU flags are unchanged.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 1487: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ghost_state,x          ; Write A to four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating.
; Book line 1488: Store A into the byte at ghost_state (ghost state table) plus index X. The register
; and CPU flags are unchanged.
 sta ghost_regen,x          ; Write A to four regeneration countdowns; decremented at tile decisions, not every frame.
; Book line 1489: Store A into the byte at ghost_regen (ghost regeneration countdown table) plus index
; X. The register and CPU flags are unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 1490: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta gd,x                   ; Write A to four last-selected ghost directions; stored by routing, not used for current sprite selection.
; Book line 1491: Store A into the byte at gd plus index X. The register and CPU flags are unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1492: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #4                     ; Compare X with #4; leave X unchanged, set Z for equal and C for >=.
; Book line 1493: Compare X with literal 4 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne reset_ghost_loop       ; If Z=0 (last result nonzero, or comparison unequal), branch to reset_ghost_loop.
; Book line 1494: Branch to reset_ghost_loop if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 jsr sync_pixels            ; Call sync_pixels: Snap all five visible actors to their tile centres. RTS will return here.
; Book line 1495: Call sync_pixels, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1496: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; power_tick - UPDATE SHORT INVULNERABILITY AND POWER TIMERS
; hit_cooldown is measured in video frames. power_timer is a 16-bit little-endian
; countdown. Only state 1 ghosts return to normal at expiry; state 2 eyes and state 3
; regeneration are deliberately untouched.
; ============================================================================
power_tick:
; Book line 1505: power_tick names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ; Read frames of contact immunity after losing a life; it skips all contact processing into A; Z/N
 ; reflect that byte.
 lda hit_cooldown
; Book line 1508: Load A with the byte at hit_cooldown. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 beq power_tick_timer       ; If Z=1 (last result zero, or comparison equal), branch to power_tick_timer.
; Book line 1509: Branch to power_tick_timer if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ; Decrease frames of contact immunity after losing a life; it skips all contact processing by 1,
 ; wrapping within 0..255; update Z/N.
 dec hit_cooldown
; Book line 1512: Decrease the byte at hit_cooldown by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
; Update the 16-bit power countdown after contact immunity.
power_tick_timer:
; Book line 1514: power_tick_timer names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda power_timer            ; Read little-endian 16-bit vulnerability countdown: low byte then high byte into A; Z/N reflect that byte.
; Book line 1515: Load A with the byte at power_timer. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 ora power_timer+1          ; Set in A any bits present in power_timer+1; combine masks without clearing other bits.
; Book line 1516: Set A bits present in either A or the byte at power_timer+1. Save the result in A
; and update Z and N; carry is unchanged.
 beq power_restore          ; If Z=1 (last result zero, or comparison equal), branch to power_restore.
; Book line 1517: Branch to power_restore if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda power_timer            ; Read little-endian 16-bit vulnerability countdown: low byte then high byte into A; Z/N reflect that byte.
; Book line 1518: Load A with the byte at power_timer. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne power_tick_low         ; If Z=0 (last result nonzero, or comparison unequal), branch to power_tick_low.
; Book line 1519: Branch to power_tick_low if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 ; Decrease little-endian 16-bit vulnerability countdown: low byte then high byte by 1, wrapping within
 ; 0..255; update Z/N.
 dec power_timer+1
; Book line 1522: Decrease the byte at power_timer+1 by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
; Decrement the low byte; borrow was handled first if it was zero.
power_tick_low:
; Book line 1524: power_tick_low names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ; Decrease little-endian 16-bit vulnerability countdown: low byte then high byte by 1, wrapping within
 ; 0..255; update Z/N.
 dec power_timer
; Book line 1527: Decrease the byte at power_timer by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
 lda power_timer            ; Read little-endian 16-bit vulnerability countdown: low byte then high byte into A; Z/N reflect that byte.
; Book line 1528: Load A with the byte at power_timer. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 ora power_timer+1          ; Set in A any bits present in power_timer+1; combine masks without clearing other bits.
; Book line 1529: Set A bits present in either A or the byte at power_timer+1. Save the result in A
; and update Z and N; carry is unchanged.
 bne power_tick_done        ; If Z=0 (last result nonzero, or comparison unequal), branch to power_tick_done.
; Book line 1530: Branch to power_tick_done if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
; Power has expired; restore only frightened ghosts.
power_restore:
; Book line 1532: power_restore names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1533: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Inspect one ghost state.
power_restore_loop:
; Book line 1535: power_restore_loop names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda ghost_state,x          ; Read four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating into A; Z/N reflect that byte.
; Book line 1536: Load A with the byte at ghost_state (ghost state table) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 cmp #1                     ; Compare A with #1; leave A unchanged, set Z for equal and C for >=.
; Book line 1537: Compare A with literal 1 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne power_restore_next     ; If Z=0 (last result nonzero, or comparison unequal), branch to power_restore_next.
; Book line 1538: Branch to power_restore_next if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 1539: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ghost_state,x          ; Write A to four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating.
; Book line 1540: Store A into the byte at ghost_state (ghost state table) plus index X. The register
; and CPU flags are unchanged.
; Continue the restoration loop.
power_restore_next:
; Book line 1542: power_restore_next names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1543: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #4                     ; Compare X with #4; leave X unchanged, set Z for equal and C for >=.
; Book line 1544: Compare X with literal 4 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne power_restore_loop     ; If Z=0 (last result nonzero, or comparison unequal), branch to power_restore_loop.
; Book line 1545: Branch to power_restore_loop if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
; Return after timer work.
power_tick_done:
; Book line 1547: power_tick_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1548: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; 16x16 visible sprites centered over each 16x16 logical tile.
; Hardware sprite 24x21; transparent padding is intentional.

; ============================================================================
; draw_sprites - TRANSLATE GAME STATE INTO VIC-II SPRITE SETTINGS
; Set ghost body colors and picture pointers, copy the five visible pixel positions to
; sprite registers, combine their ninth X bits into $d010, and choose Pac-Man artwork from
; direction and mouth phase. Changing a picture does not change motion or collision.
; ============================================================================
draw_sprites:
; Book line 1559: draw_sprites names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1560: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Select a body color and artwork for each ghost state.
ghost_set_colours:
; Book line 1562: ghost_set_colours names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda ghost_state,x          ; Read four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating into A; Z/N reflect that byte.
; Book line 1563: Load A with the byte at ghost_state (ghost state table) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 cmp #1                     ; Compare A with #1; leave A unchanged, set Z for equal and C for >=.
; Book line 1564: Compare A with literal 1 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq ghost_colour_blue      ; If Z=1 (last result zero, or comparison equal), branch to ghost_colour_blue.
; Book line 1565: Branch to ghost_colour_blue if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 cmp #2                     ; Compare A with #2; leave A unchanged, set Z for equal and C for >=.
; Book line 1566: Compare A with literal 2 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq ghost_colour_eyes      ; If Z=1 (last result zero, or comparison equal), branch to ghost_colour_eyes.
; Book line 1567: Branch to ghost_colour_eyes if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 cmp #3                     ; Compare A with #3; leave A unchanged, set Z for equal and C for >=.
; Book line 1568: Compare A with literal 3 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq ghost_colour_regen     ; If Z=1 (last result zero, or comparison equal), branch to ghost_colour_regen.
; Book line 1569: Branch to ghost_colour_regen if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 lda ghost_base_colours,x   ; Read body color per ghost: red 2, light red 10, cyan 3, orange 8 into A; Z/N reflect that byte.
; Book line 1570: Load A with the byte at ghost_base_colours plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 jmp ghost_colour_store     ; Continue at ghost_colour_store without saving a return address.
; Book line 1571: Continue execution at ghost_colour_store without saving a return address. Registers
; and flags are unchanged by the jump itself.
; During the last 64 power frames, alternate white and blue as a warning.
ghost_colour_blue:
; Book line 1573: ghost_colour_blue names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda power_timer+1          ; Read little-endian 16-bit vulnerability countdown: low byte then high byte into A; Z/N reflect that byte.
; Book line 1574: Load A with the byte at power_timer+1. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne ghost_frightened_blue  ; If Z=0 (last result nonzero, or comparison unequal), branch to ghost_frightened_blue.
; Book line 1575: Branch to ghost_frightened_blue if Z is 0 (nonzero or unequal); otherwise continue
; at the next instruction. Test the current flag, and leave all flags unchanged.
 lda power_timer            ; Read little-endian 16-bit vulnerability countdown: low byte then high byte into A; Z/N reflect that byte.
; Book line 1576: Load A with the byte at power_timer. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 cmp #64                    ; Compare A with #64; leave A unchanged, set Z for equal and C for >=.
; Book line 1577: Compare A with literal 64 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs ghost_frightened_blue  ; If C=1 (after CMP: unsigned value >= operand), branch to ghost_frightened_blue.
; Book line 1578: Branch to ghost_frightened_blue if C is 1; otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ; Read 8-bit frame counter; wraps 255 to 0 and drives mouth animation and ghost target phase into A;
 ; Z/N reflect that byte.
 lda tick
; Book line 1581: Load A with the byte at tick (frame clock). Z records a zero value; N copies bit 7.
; Carry is unchanged.
 and #8                     ; Keep only the A bits selected by #8; zero/nonzero now tests those bits.
; Book line 1582: Keep only bits set in both A and literal 8. Save the result in A and update Z and N;
; carry is unchanged.
 beq ghost_frightened_blue  ; If Z=1 (last result zero, or comparison equal), branch to ghost_frightened_blue.
; Book line 1583: Branch to ghost_frightened_blue if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 1584: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 bne ghost_colour_store     ; If Z=0 (last result nonzero, or comparison unequal), branch to ghost_colour_store.
; Book line 1585: Branch to ghost_colour_store if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
; Use light blue for a frightened body.
ghost_frightened_blue:
; Book line 1587: ghost_frightened_blue names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #14                    ; Load A with literal 14; this also sets Z and N.
; Book line 1588: Load A with literal 14. Z records a zero value; N copies bit 7. Carry is unchanged.
 jmp ghost_colour_store     ; Continue at ghost_colour_store without saving a return address.
; Book line 1589: Continue execution at ghost_colour_store without saving a return address. Registers
; and flags are unchanged by the jump itself.
; Use white body ink for the eyes-only frame.
ghost_colour_eyes:
; Book line 1591: ghost_colour_eyes names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 1592: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 jmp ghost_colour_store     ; Continue at ghost_colour_store without saving a return address.
; Book line 1593: Continue execution at ghost_colour_store without saving a return address. Registers
; and flags are unchanged by the jump itself.
; Use yellow during regeneration.
ghost_colour_regen:
; Book line 1595: ghost_colour_regen names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #7                     ; Load A with literal 7; this also sets Z and N.
; Book line 1596: Load A with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
; Write the per-sprite body ink and select its picture.
ghost_colour_store:
; Book line 1598: ghost_colour_store names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 sta $d028,x                ; Write A to first ghost body color (indexed addresses reach the other ghosts) plus the shown index/offset.
; Book line 1599: Store A into the byte at $d028 (sprite 1 colour) plus index X. The register and CPU
; flags are unchanged.
 lda ghost_state,x          ; Read four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating into A; Z/N reflect that byte.
; Book line 1600: Load A with the byte at ghost_state (ghost state table) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 cmp #2                     ; Compare A with #2; leave A unchanged, set Z for equal and C for >=.
; Book line 1601: Compare A with literal 2 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq ghost_picture_eyes     ; If Z=1 (last result zero, or comparison equal), branch to ghost_picture_eyes.
; Book line 1602: Branch to ghost_picture_eyes if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 cmp #1                     ; Compare A with #1; leave A unchanged, set Z for equal and C for >=.
; Book line 1603: Compare A with literal 1 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq ghost_picture_frightened ; If Z=1 (last result zero, or comparison equal), branch to ghost_picture_frightened.
; Book line 1604: Branch to ghost_picture_frightened if Z is 1 (zero or equal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 lda #$81                   ; Load A with literal $81 (129 decimal); this also sets Z and N.
; Book line 1605: Load A with literal $81 (decimal 129). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne ghost_picture_store    ; If Z=0 (last result nonzero, or comparison unequal), branch to ghost_picture_store.
; Book line 1606: Branch to ghost_picture_store if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
; Use sprite frame 9, containing only white eyes and blue pupils.
ghost_picture_eyes:
; Book line 1608: ghost_picture_eyes names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #$89                   ; Load A with literal $89 (137 decimal); this also sets Z and N.
; Book line 1609: Load A with literal $89 (decimal 137). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne ghost_picture_store    ; If Z=0 (last result nonzero, or comparison unequal), branch to ghost_picture_store.
; Book line 1610: Branch to ghost_picture_store if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
; Use sprite frame 8 with a frightened face.
ghost_picture_frightened:
; Book line 1612: ghost_picture_frightened names this assembled address; it emits no bytes and
; provides a jump, call or data reference target.
 lda #$88                   ; Load A with literal $88 (136 decimal); this also sets Z and N.
; Book line 1613: Load A with literal $88 (decimal 136). Z records a zero value; N copies bit 7. Carry
; is unchanged.
; Write the ghost pointer without moving the sprite.
ghost_picture_store:
; Book line 1615: ghost_picture_store names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 sta PTR+1,x                ; Write A to the indicated hardware sprite picture pointer.
; Book line 1616: Store A into the byte at PTR+1 plus index X. The register and CPU flags are
; unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1617: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #4                     ; Compare X with #4; leave X unchanged, set Z for equal and C for >=.
; Book line 1618: Compare X with literal 4 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne ghost_set_colours      ; If Z=0 (last result nonzero, or comparison unequal), branch to ghost_set_colours.
; Book line 1619: Branch to ghost_set_colours if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
; Begin copying visible positions to VIC-II registers.
ghost_colours_done:
; Book line 1621: ghost_colours_done names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda pixel_xlo              ; Read five low bytes of visible hardware X, Pac-Man first into A; Z/N reflect that byte.
; Book line 1622: Load A with the byte at pixel_xlo. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d000                  ; Write A to hardware sprite 0 X-low (indexed Y reaches ghost coordinate registers).
; Book line 1623: Store A into the byte at $d000 (sprite 0 X low byte). The register and CPU flags are
; unchanged.
 lda pixel_xhi              ; Read five high bytes of visible hardware X into A; Z/N reflect that byte.
; Book line 1624: Load A with the byte at pixel_xhi. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta high_bits              ; Write A to combined ninth-X-bit mask for the visible hardware sprites.
; Book line 1625: Store A into the byte at high_bits. The register and CPU flags are unchanged.
 lda pixel_y                ; Read five visible hardware Y coordinates into A; Z/N reflect that byte.
; Book line 1626: Load A with the byte at pixel_y. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d001                  ; Write A to hardware sprite 0 Y (indexed Y reaches ghost Y registers).
; Book line 1627: Store A into the byte at $d001 (sprite 0 Y coordinate). The register and CPU flags
; are unchanged.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1628: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Copy one ghost position; hardware sprite register offsets are two bytes apart.
draw_ghost_loop:
; Book line 1630: draw_ghost_loop names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 stx ghost_index            ; Write X to which ghost (0..3) the current loop is processing.
; Book line 1631: Store X into the byte at ghost_index. The register and CPU flags are unchanged.
 txa                        ; Copy X into A; X is unchanged, Z/N follow the copied byte.
; Book line 1632: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
 asl                        ; Shift A left by one bit (multiply by 2 modulo 256); old bit 7 goes to carry.
; Book line 1633: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 1634: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #2                     ; Add #2 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 1635: Add literal 2 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 tay                        ; Copy A into Y; A is unchanged, Z/N follow the copied byte.
; Book line 1636: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1637: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 lda pixel_xlo,x            ; Read five low bytes of visible hardware X, Pac-Man first into A; Z/N reflect that byte.
; Book line 1638: Load A with the byte at pixel_xlo plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta $d000,y                ; Write A to hardware sprite 0 X-low (indexed Y reaches ghost coordinate registers) plus the shown index/offset.
; Book line 1639: Store A into the byte at $d000 (sprite 0 X low byte) plus index Y. The register and
; CPU flags are unchanged.
 lda pixel_xhi,x            ; Read five high bytes of visible hardware X into A; Z/N reflect that byte.
; Book line 1640: Load A with the byte at pixel_xhi plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 beq ghost_no_high          ; If Z=1 (last result zero, or comparison equal), branch to ghost_no_high.
; Book line 1641: Branch to ghost_no_high if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ; Read hardware sprite X-bit lookup; Y is 2,4,6,8 for ghosts, yielding bits 2,4,8,16 into A; Z/N
 ; reflect that byte.
 lda bit_masks,y
; Book line 1644: Load A with the byte at bit_masks plus index Y. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 ora high_bits              ; Set in A any bits present in high_bits; combine masks without clearing other bits.
; Book line 1645: Set A bits present in either A or the byte at high_bits. Save the result in A and
; update Z and N; carry is unchanged.
 sta high_bits              ; Write A to combined ninth-X-bit mask for the visible hardware sprites.
; Book line 1646: Store A into the byte at high_bits. The register and CPU flags are unchanged.
; Copy Y after handling any ninth-X-bit contribution.
ghost_no_high:
; Book line 1648: ghost_no_high names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda pixel_y,x              ; Read five visible hardware Y coordinates into A; Z/N reflect that byte.
; Book line 1649: Load A with the byte at pixel_y plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta $d001,y                ; Write A to hardware sprite 0 Y (indexed Y reaches ghost Y registers) plus the shown index/offset.
; Book line 1650: Store A into the byte at $d001 (sprite 0 Y coordinate) plus index Y. The register
; and CPU flags are unchanged.
 ldx ghost_index            ; Read which ghost (0..3) the current loop is processing into X; Z/N reflect that byte.
; Book line 1651: Load X with the byte at ghost_index. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1652: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #4                     ; Compare X with #4; leave X unchanged, set Z for equal and C for >=.
; Book line 1653: Compare X with literal 4 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne draw_ghost_loop        ; If Z=0 (last result nonzero, or comparison unequal), branch to draw_ghost_loop.
; Book line 1654: Branch to draw_ghost_loop if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
; Write the combined X-high mask and select Pac-Man animation.
draw_ghosts_done:
; Book line 1656: draw_ghosts_done names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda high_bits              ; Read combined ninth-X-bit mask for the visible hardware sprites into A; Z/N reflect that byte.
; Book line 1657: Load A with the byte at high_bits. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d010                  ; Write A to combined ninth X-coordinate bits for all hardware sprites.
; Book line 1658: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
 ; Direction is the accepted movement direction: up/right/down/left.
 lda direction              ; Read accepted travel direction: 0 up, 1 right, 2 down, 3 left into A; Z/N reflect that byte.
; Book line 1660: Load A with the byte at direction. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 asl                        ; Shift A left by one bit (multiply by 2 modulo 256); old bit 7 goes to carry.
; Book line 1661: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 tax                        ; Copy A into X; A is unchanged, Z/N follow the copied byte.
; Book line 1662: Copy A to X; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 ; Read 8-bit frame counter; wraps 255 to 0 and drives mouth animation and ghost target phase into A;
 ; Z/N reflect that byte.
 lda tick
; Book line 1665: Load A with the byte at tick (frame clock). Z records a zero value; N copies bit 7.
; Carry is unchanged.
 and #$10                   ; Keep only the A bits selected by #$10; zero/nonzero now tests those bits.
; Book line 1666: Keep only bits set in both A and literal $10 (decimal 16). Save the result in A and
; update Z and N; carry is unchanged.
 beq pac_store_frame        ; If Z=1 (last result zero, or comparison equal), branch to pac_store_frame.
; Book line 1667: Branch to pac_store_frame if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1668: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
; Use direction*2 plus mouth phase to choose one of eight pointers.
pac_store_frame:
; Book line 1670: pac_store_frame names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda pac_frames,x           ; Read an entry from pac_frames (see the table description) into A; Z/N reflect that byte.
; Book line 1671: Load A with the byte at pac_frames plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta PTR                    ; Write A to sprite-pointer base $07f8; pointer byte times 64 selects a sprite frame in the current VIC bank.
; Book line 1672: Store A into the byte at PTR (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1673: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Two pointers per accepted direction: up $8a/$8b, right $80/$85, down $8c/$8d, left
; $86/$87. Pointer*64 gives the sprite address in VIC bank 0.
pac_frames: !byte $8a,$8b,$80,$85,$8c,$8d,$86,$87 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 1677: pac_frames names the data or instruction address. Emit 8 bytes in the shown order
; for pac_frames. These are data or encoded loader bytes, not instructions to execute.

; One pixel per video frame, one tile per 16 frames.
; Decisions remain on tile centres; visible contact is checked EVERY frame.
; Large X changes are tunnel wraps and snap to the opposite endpoint.

; ============================================================================
; sync_pixels - SNAP ALL FIVE VISIBLE ACTORS TO THEIR TILE CENTRES
; Temporarily enable pixel_snap, call the normal pixel updater, then disable snapping.
; This is for spawn/reset/level entry rather than normal movement.
; ============================================================================
sync_pixels:
; Book line 1688: sync_pixels names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 1689: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta pixel_snap             ; Write A to nonzero means snap targets immediately instead of moving one pixel.
; Book line 1690: Store A into the byte at pixel_snap. The register and CPU flags are unchanged.
 jsr advance_pixels         ; Call advance_pixels: Move visible actors one pixel toward their targets. RTS will return here.
; Book line 1691: Call advance_pixels, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 1692: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta pixel_snap             ; Write A to nonzero means snap targets immediately instead of moving one pixel.
; Book line 1693: Store A into the byte at pixel_snap. The register and CPU flags are unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1694: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ============================================================================
; advance_pixels - MOVE VISIBLE ACTORS ONE PIXEL TOWARD THEIR TARGETS
; Actor index 0 is Pac-Man; 1 through 4 are the four ghosts. Convert tile coordinates
; using sprite_xlo/sprite_xhi/sprite_y. For an ordinary cardinal move, adjust one axis by
; one pixel. A large X difference is treated as a tunnel wrap and snaps to the opposite
; endpoint.
; ============================================================================
advance_pixels:
; Book line 1703: advance_pixels names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1704: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Select the target for visible actor 0..4.
pixel_actor_loop:
; Book line 1706: pixel_actor_loop names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 stx pixel_actor            ; Write X to saved visible actor index 0..4.
; Book line 1707: Store X into the byte at pixel_actor. The register and CPU flags are unchanged.
 cpx #0                     ; Compare X with #0; leave X unchanged, set Z for equal and C for >=.
; Book line 1708: Compare X with literal 0 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne pixel_ghost_target     ; If Z=0 (last result nonzero, or comparison unequal), branch to pixel_ghost_target.
; Book line 1709: Branch to pixel_ghost_target if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 ; Read Pac-Man logical tile column, 0..18; a destination, not his current visible pixel X into Y; Z/N
 ; reflect that byte.
 ldy px
; Book line 1712: Load Y with the byte at px (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 lda py                     ; Read Pac-Man logical tile row, 0..10 into A; Z/N reflect that byte.
; Book line 1713: Load A with the byte at py (logical player row). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 jmp pixel_target_ready     ; Continue at pixel_target_ready without saving a return address.
; Book line 1714: Continue execution at pixel_target_ready without saving a return address. Registers
; and flags are unchanged by the jump itself.
; Translate actor index 1..4 into ghost index 0..3.
pixel_ghost_target:
; Book line 1716: pixel_ghost_target names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 dex                        ; Decrease X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1717: Decrease X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 ldy gx,x                   ; Read four ghost logical tile columns into Y; Z/N reflect that byte.
; Book line 1718: Load Y with the byte at gx (ghost tile-column table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 lda gy,x                   ; Read four ghost logical tile rows into A; Z/N reflect that byte.
; Book line 1719: Load A with the byte at gy (ghost tile-row table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
; Read the target coordinate lookup tables.
pixel_target_ready:
; Book line 1721: pixel_target_ready names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 tax                        ; Copy A into X; A is unchanged, Z/N follow the copied byte.
; Book line 1722: Copy A to X; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda sprite_y,x             ; Read an entry from sprite_y (see the table description) into A; Z/N reflect that byte.
; Book line 1723: Load A with the byte at sprite_y plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta pixel_target_y         ; Write A to target hardware Y.
; Book line 1724: Store A into the byte at pixel_target_y. The register and CPU flags are unchanged.
 lda sprite_xlo,y           ; Read an entry from sprite_xlo (see the table description) into A; Z/N reflect that byte.
; Book line 1725: Load A with the byte at sprite_xlo plus index Y. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta pixel_target_lo        ; Write A to low byte of target hardware X.
; Book line 1726: Store A into the byte at pixel_target_lo. The register and CPU flags are unchanged.
 lda sprite_xhi,y           ; Read an entry from sprite_xhi (see the table description) into A; Z/N reflect that byte.
; Book line 1727: Load A with the byte at sprite_xhi plus index Y. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta pixel_target_hi        ; Write A to high byte of target hardware X.
; Book line 1728: Store A into the byte at pixel_target_hi. The register and CPU flags are unchanged.
 ldx pixel_actor            ; Read saved visible actor index 0..4 into X; Z/N reflect that byte.
; Book line 1729: Load X with the byte at pixel_actor. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 lda pixel_snap             ; Read nonzero means snap targets immediately instead of moving one pixel into A; Z/N reflect that byte.
; Book line 1730: Load A with the byte at pixel_snap. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bne pixel_snap_actor       ; If Z=0 (last result nonzero, or comparison unequal), branch to pixel_snap_actor.
; Book line 1731: Branch to pixel_snap_actor if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 ; Signed 16-bit target minus actual. A normal step is at most 16.
 sec                        ; Set carry before subtraction (no incoming borrow), or signal a blocked probe.
; Book line 1733: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda pixel_target_lo        ; Read low byte of target hardware X into A; Z/N reflect that byte.
; Book line 1734: Load A with the byte at pixel_target_lo. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sbc pixel_xlo,x            ; Subtract pixel_xlo,x and (1-C) from A; carry clear afterward means a borrow.
; Book line 1735: Subtract the byte at pixel_xlo plus index X and (1 minus incoming carry) from A.
; Update C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta pixel_delta            ; Write A to low byte of target-X minus visible-X; high subtraction controls its sign.
; Book line 1736: Store A into the byte at pixel_delta. The register and CPU flags are unchanged.
 lda pixel_target_hi        ; Read high byte of target hardware X into A; Z/N reflect that byte.
; Book line 1737: Load A with the byte at pixel_target_hi. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sbc pixel_xhi,x            ; Subtract pixel_xhi,x and (1-C) from A; carry clear afterward means a borrow.
; Book line 1738: Subtract the byte at pixel_xhi plus index X and (1 minus incoming carry) from A.
; Update C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 beq pixel_positive_x       ; If Z=1 (last result zero, or comparison equal), branch to pixel_positive_x.
; Book line 1739: Branch to pixel_positive_x if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #255                   ; Compare A with #255; leave A unchanged, set Z for equal and C for >=.
; Book line 1740: Compare A with literal 255 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne pixel_snap_actor       ; If Z=0 (last result nonzero, or comparison unequal), branch to pixel_snap_actor.
; Book line 1741: Branch to pixel_snap_actor if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 lda pixel_delta            ; Read low byte of target-X minus visible-X; high subtraction controls its sign into A; Z/N reflect that byte.
; Book line 1742: Load A with the byte at pixel_delta. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 cmp #240                   ; Compare A with #240; leave A unchanged, set Z for equal and C for >=.
; Book line 1743: Compare A with literal 240 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc pixel_snap_actor       ; If C=0 (after CMP: unsigned value < operand), branch to pixel_snap_actor.
; Book line 1744: Branch to pixel_snap_actor if C is 0; otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 ; Negative delta -16..-1.
 lda pixel_xlo,x            ; Read five low bytes of visible hardware X, Pac-Man first into A; Z/N reflect that byte.
; Book line 1746: Load A with the byte at pixel_xlo plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 bne pixel_decrement_x      ; If Z=0 (last result nonzero, or comparison unequal), branch to pixel_decrement_x.
; Book line 1747: Branch to pixel_decrement_x if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 dec pixel_xhi,x            ; Decrease five high bytes of visible hardware X by 1, wrapping within 0..255; update Z/N.
; Book line 1748: Decrease the byte at pixel_xhi plus index X by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
; Move left one pixel; the high-byte borrow was handled if necessary.
pixel_decrement_x:
; Book line 1750: pixel_decrement_x names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 dec pixel_xlo,x            ; Decrease five low bytes of visible hardware X, Pac-Man first by 1, wrapping within 0..255; update Z/N.
; Book line 1751: Decrease the byte at pixel_xlo plus index X by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
 jmp pixel_move_y           ; Continue at pixel_move_y without saving a return address.
; Book line 1752: Continue execution at pixel_move_y without saving a return address. Registers and
; flags are unchanged by the jump itself.
; Handle zero/rightward X differences or a large tunnel wrap.
pixel_positive_x:
; Book line 1754: pixel_positive_x names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda pixel_delta            ; Read low byte of target-X minus visible-X; high subtraction controls its sign into A; Z/N reflect that byte.
; Book line 1755: Load A with the byte at pixel_delta. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 beq pixel_move_y           ; If Z=1 (last result zero, or comparison equal), branch to pixel_move_y.
; Book line 1756: Branch to pixel_move_y if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #17                    ; Compare A with #17; leave A unchanged, set Z for equal and C for >=.
; Book line 1757: Compare A with literal 17 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs pixel_snap_actor       ; If C=1 (after CMP: unsigned value >= operand), branch to pixel_snap_actor.
; Book line 1758: Branch to pixel_snap_actor if C is 1; otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 inc pixel_xlo,x            ; Increase five low bytes of visible hardware X, Pac-Man first by 1, wrapping within 0..255; update Z/N.
; Book line 1759: Increase the byte at pixel_xlo plus index X by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
 bne pixel_move_y           ; If Z=0 (last result nonzero, or comparison unequal), branch to pixel_move_y.
; Book line 1760: Branch to pixel_move_y if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 inc pixel_xhi,x            ; Increase five high bytes of visible hardware X by 1, wrapping within 0..255; update Z/N.
; Book line 1761: Increase the byte at pixel_xhi plus index X by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
; Move up/down one pixel if Y differs.
pixel_move_y:
; Book line 1763: pixel_move_y names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda pixel_y,x              ; Read five visible hardware Y coordinates into A; Z/N reflect that byte.
; Book line 1764: Load A with the byte at pixel_y plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 cmp pixel_target_y         ; Compare A with pixel_target_y; leave A unchanged, set Z for equal and C for >=.
; Book line 1765: Compare A with the byte at pixel_target_y without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 beq pixel_actor_done       ; If Z=1 (last result zero, or comparison equal), branch to pixel_actor_done.
; Book line 1766: Branch to pixel_actor_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 bcc pixel_increment_y      ; If C=0 (after CMP: unsigned value < operand), branch to pixel_increment_y.
; Book line 1767: Branch to pixel_increment_y if C is 0; otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 dec pixel_y,x              ; Decrease five visible hardware Y coordinates by 1, wrapping within 0..255; update Z/N.
; Book line 1768: Decrease the byte at pixel_y plus index X by one with 8-bit wraparound. Update Z and
; N; carry is unchanged.
 jmp pixel_actor_done       ; Continue at pixel_actor_done without saving a return address.
; Book line 1769: Continue execution at pixel_actor_done without saving a return address. Registers
; and flags are unchanged by the jump itself.
; Move down one pixel.
pixel_increment_y:
; Book line 1771: pixel_increment_y names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 inc pixel_y,x              ; Increase five visible hardware Y coordinates by 1, wrapping within 0..255; update Z/N.
; Book line 1772: Increase the byte at pixel_y plus index X by one with 8-bit wraparound. Update Z and
; N; carry is unchanged.
 jmp pixel_actor_done       ; Continue at pixel_actor_done without saving a return address.
; Book line 1773: Continue execution at pixel_actor_done without saving a return address. Registers
; and flags are unchanged by the jump itself.
; Copy the target immediately for initialization or tunnel wrapping.
pixel_snap_actor:
; Book line 1775: pixel_snap_actor names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda pixel_target_lo        ; Read low byte of target hardware X into A; Z/N reflect that byte.
; Book line 1776: Load A with the byte at pixel_target_lo. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta pixel_xlo,x            ; Write A to five low bytes of visible hardware X, Pac-Man first.
; Book line 1777: Store A into the byte at pixel_xlo plus index X. The register and CPU flags are
; unchanged.
 lda pixel_target_hi        ; Read high byte of target hardware X into A; Z/N reflect that byte.
; Book line 1778: Load A with the byte at pixel_target_hi. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta pixel_xhi,x            ; Write A to five high bytes of visible hardware X.
; Book line 1779: Store A into the byte at pixel_xhi plus index X. The register and CPU flags are
; unchanged.
 lda pixel_target_y         ; Read target hardware Y into A; Z/N reflect that byte.
; Book line 1780: Load A with the byte at pixel_target_y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta pixel_y,x              ; Write A to five visible hardware Y coordinates.
; Book line 1781: Store A into the byte at pixel_y plus index X. The register and CPU flags are
; unchanged.
; Restore the saved actor index and continue.
pixel_actor_done:
; Book line 1783: pixel_actor_done names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 ldx pixel_actor            ; Read saved visible actor index 0..4 into X; Z/N reflect that byte.
; Book line 1784: Load X with the byte at pixel_actor. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1785: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #5                     ; Compare X with #5; leave X unchanged, set Z for equal and C for >=.
; Book line 1786: Compare X with literal 5 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq pixel_all_done         ; If Z=1 (last result zero, or comparison equal), branch to pixel_all_done.
; Book line 1787: Branch to pixel_all_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp pixel_actor_loop       ; Continue at pixel_actor_loop without saving a return address.
; Book line 1788: Continue execution at pixel_actor_loop without saving a return address. Registers
; and flags are unchanged by the jump itself.
; All five visible actors have been updated.
pixel_all_done:
; Book line 1790: pixel_all_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1791: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
; 0..15: choose tile targets at 0 and finish a tile on frame 15.
move_phase: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 1793: move_phase names the data or instruction address. Emit 1 byte in the shown order for
; move_phase. These are data or encoded loader bytes, not instructions to execute.
; nonzero means snap targets immediately instead of moving one pixel.
pixel_snap: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 1795: pixel_snap names the data or instruction address. Emit 1 byte in the shown order for
; pixel_snap. These are data or encoded loader bytes, not instructions to execute.
; saved visible actor index 0..4.
pixel_actor: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 1797: pixel_actor names the data or instruction address. Emit 1 byte in the shown order
; for pixel_actor. These are data or encoded loader bytes, not instructions to execute.
; low byte of target hardware X.
pixel_target_lo: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 1799: pixel_target_lo names the data or instruction address. Emit 1 byte in the shown
; order for pixel_target_lo. These are data or encoded loader bytes, not instructions to execute.
; high byte of target hardware X.
pixel_target_hi: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 1801: pixel_target_hi names the data or instruction address. Emit 1 byte in the shown
; order for pixel_target_hi. These are data or encoded loader bytes, not instructions to execute.
; target hardware Y.
pixel_target_y: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 1803: pixel_target_y names the data or instruction address. Emit 1 byte in the shown order
; for pixel_target_y. These are data or encoded loader bytes, not instructions to execute.
; low byte of target-X minus visible-X; high subtraction controls its sign.
pixel_delta: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 1805: pixel_delta names the data or instruction address. Emit 1 byte in the shown order
; for pixel_delta. These are data or encoded loader bytes, not instructions to execute.
; five low bytes of visible hardware X, Pac-Man first.
pixel_xlo: !fill 5,0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 1807: pixel_xlo names the data or instruction address. Emit repeated initial data for
; pixel_xlo: 5,0. The first expression is the byte count and the second is the fill value.
; five high bytes of visible hardware X.
pixel_xhi: !fill 5,0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 1809: pixel_xhi names the data or instruction address. Emit repeated initial data for
; pixel_xhi: 5,0. The first expression is the byte count and the second is the fill value.
; five visible hardware Y coordinates.
pixel_y: !fill 5,0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 1811: pixel_y names the data or instruction address. Emit repeated initial data for
; pixel_y: 5,0. The first expression is the byte count and the second is the fill value.


; ============================================================================
; game_over - DISPLAY GAME OVER AND RESTART ON A NEW FIRE PRESS
; Hide sprites, print GAME OVER and PRESS FIRE TO PLAY, then wait for release followed by
; press. Continue calling sound_tick during these waits so the last-life sound can finish.
; There is no jump back to BASIC.
; ============================================================================
game_over:
; Book line 1820: game_over names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 1821: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d015                  ; Write A to VIC-II sprite enable bits; $1f enables sprites 0..4.
; Book line 1822: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 jsr clear_screen           ; Call clear_screen: Blank character RAM and set a default ink. RTS will return here.
; Book line 1823: Call clear_screen, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1824: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Print GAME OVER in red.
over_print:
; Book line 1826: over_print names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda over_line,x            ; Read an entry from over_line (see the table description) into A; Z/N reflect that byte.
; Book line 1827: Load A with the byte at over_line plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 beq over_prompt            ; If Z=1 (last result zero, or comparison equal), branch to over_prompt.
; Book line 1828: Branch to over_prompt if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN+495,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 1829: Store A into the byte at SCREEN+495 plus index X. The register and CPU flags are
; unchanged.
 lda #2                     ; Load A with literal 2; this also sets Z and N.
; Book line 1830: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+495,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 1831: Store A into the byte at COLOR+495 plus index X. The register and CPU flags are
; unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1832: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne over_print             ; If Z=0 (last result nonzero, or comparison unequal), branch to over_print.
; Book line 1833: Branch to over_print if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
; Prepare the replay prompt.
over_prompt:
; Book line 1835: over_prompt names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1836: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Print PRESS FIRE TO PLAY in white.
over_prompt_loop:
; Book line 1838: over_prompt_loop names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda replay_line,x          ; Read an entry from replay_line (see the table description) into A; Z/N reflect that byte.
; Book line 1839: Load A with the byte at replay_line plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 beq over_release           ; If Z=1 (last result zero, or comparison equal), branch to over_release.
; Book line 1840: Branch to over_release if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta SCREEN+611,x           ; Write A to the indicated character screen cell, using the shown offset/index.
; Book line 1841: Store A into the byte at SCREEN+611 plus index X. The register and CPU flags are
; unchanged.
 lda #1                     ; Load A with literal 1; this also sets Z and N.
; Book line 1842: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta COLOR+611,x            ; Write A to the indicated character ink cell in Color RAM.
; Book line 1843: Store A into the byte at COLOR+611 plus index X. The register and CPU flags are
; unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1844: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne over_prompt_loop       ; If Z=0 (last result nonzero, or comparison unequal), branch to over_prompt_loop.
; Book line 1845: Branch to over_prompt_loop if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
; Wait for fire release while allowing SID effects to finish.
over_release:
; Book line 1847: over_release names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 jsr wait_frame             ; Call wait_frame: Wait for the next raster timing point. RTS will return here.
; Book line 1848: Call wait_frame, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr sound_tick             ; Call sound_tick: Advance each sound once without pausing the game. RTS will return here.
; Book line 1849: Call sound_tick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda JOY                    ; Read joystick port 2 input at CIA1 $dc00 into A; Z/N reflect that byte.
; Book line 1850: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$10                   ; Keep only the A bits selected by #$10; zero/nonzero now tests those bits.
; Book line 1851: Keep only bits set in both A and literal $10 (decimal 16). Save the result in A and
; update Z and N; carry is unchanged.
 beq over_release           ; If Z=1 (last result zero, or comparison equal), branch to over_release.
; Book line 1852: Branch to over_release if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
; Wait for the next fire press; then jump to restart.
over_wait:
; Book line 1854: over_wait names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr wait_frame             ; Call wait_frame: Wait for the next raster timing point. RTS will return here.
; Book line 1855: Call wait_frame, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr sound_tick             ; Call sound_tick: Advance each sound once without pausing the game. RTS will return here.
; Book line 1856: Call sound_tick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda JOY                    ; Read joystick port 2 input at CIA1 $dc00 into A; Z/N reflect that byte.
; Book line 1857: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$10                   ; Keep only the A bits selected by #$10; zero/nonzero now tests those bits.
; Book line 1858: Keep only bits set in both A and literal $10 (decimal 16). Save the result in A and
; update Z and N; carry is unchanged.
 bne over_wait              ; If Z=0 (last result nonzero, or comparison unequal), branch to over_wait.
; Book line 1859: Branch to over_wait if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp restart                ; Continue at restart without saving a return address.
; Book line 1860: Continue execution at restart without saving a return address. Registers and flags
; are unchanged by the jump itself.


; ============================================================================
; install_font - COPY ROM CHARACTERS TO A WRITABLE RAM FONT
; CPU banking temporarily exposes character ROM at $d000. Copy 2048 bytes to $2800-$2fff,
; then restore I/O visibility and replace letters, pellet/gate/house shapes, wall sets and
; central maze glyphs. The VIC-II uses this RAM font through $d018.
; ============================================================================
install_font:
; Book line 1869: install_font names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ; Copy 2 KB of ROM character glyphs to RAM $2800.
 lda #$33                   ; Load A with literal $33 (51 decimal); this also sets Z and N.
; Book line 1871: Load A with literal $33 (decimal 51). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 ; Write A to CPU memory-banking register: $35 exposes RAM under BASIC/KERNAL while retaining I/O; $33
 ; exposes character ROM for the font copy.
 sta $01
; Book line 1874: Store A into the byte at $01 (6510 ROM and I/O banking port). The register and CPU
; flags are unchanged.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1875: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Copy eight 256-byte pages of character ROM.
font_copy:
; Book line 1877: font_copy names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ; Read hardware sprite 0 X-low (indexed Y reaches ghost coordinate registers) plus the shown
 ; index/offset into A; Z/N reflect that byte.
 lda $d000,x
; Book line 1880: Load A with the byte at $d000 (sprite 0 X low byte) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $2800,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1881: Store A into the byte at $2800 plus index X. The register and CPU flags are
; unchanged.
 lda $d100,x                ; Read $d100,x into A; Z/N reflect that byte.
; Book line 1882: Load A with the byte at $d100 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $2900,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1883: Store A into the byte at $2900 plus index X. The register and CPU flags are
; unchanged.
 lda $d200,x                ; Read $d200,x into A; Z/N reflect that byte.
; Book line 1884: Load A with the byte at $d200 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $2a00,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1885: Store A into the byte at $2a00 plus index X. The register and CPU flags are
; unchanged.
 lda $d300,x                ; Read $d300,x into A; Z/N reflect that byte.
; Book line 1886: Load A with the byte at $d300 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $2b00,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1887: Store A into the byte at $2b00 plus index X. The register and CPU flags are
; unchanged.
 ; Read SID voice-1 frequency low; indexed clearing also reaches other SID registers plus the shown
 ; index/offset into A; Z/N reflect that byte.
 lda $d400,x
; Book line 1890: Load A with the byte at $d400 (SID voice 1 frequency low) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 sta $2c00,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1891: Store A into the byte at $2c00 plus index X. The register and CPU flags are
; unchanged.
 lda $d500,x                ; Read $d500,x into A; Z/N reflect that byte.
; Book line 1892: Load A with the byte at $d500 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $2d00,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1893: Store A into the byte at $2d00 plus index X. The register and CPU flags are
; unchanged.
 lda $d600,x                ; Read $d600,x into A; Z/N reflect that byte.
; Book line 1894: Load A with the byte at $d600 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $2e00,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1895: Store A into the byte at $2e00 plus index X. The register and CPU flags are
; unchanged.
 lda $d700,x                ; Read $d700,x into A; Z/N reflect that byte.
; Book line 1896: Load A with the byte at $d700 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $2f00,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1897: Store A into the byte at $2f00 plus index X. The register and CPU flags are
; unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1898: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne font_copy              ; If Z=0 (last result nonzero, or comparison unequal), branch to font_copy.
; Book line 1899: Branch to font_copy if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #$35                   ; Load A with literal $35 (53 decimal); this also sets Z and N.
; Book line 1900: Load A with literal $35 (decimal 53). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 ; Write A to CPU memory-banking register: $35 exposes RAM under BASIC/KERNAL while retaining I/O; $33
 ; exposes character ROM for the font copy.
 sta $01
; Book line 1903: Store A into the byte at $01 (6510 ROM and I/O banking port). The register and CPU
; flags are unchanged.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1904: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Replace the 26 uppercase letter glyphs in RAM.
font_letters:
; Book line 1906: font_letters names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda arcade_font,x          ; Read an entry from arcade_font (see the table description) into A; Z/N reflect that byte.
; Book line 1907: Load A with the byte at arcade_font plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $2808,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1908: Store A into the byte at $2808 plus index X. The register and CPU flags are
; unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1909: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #208                   ; Compare X with #208; leave X unchanged, set Z for equal and C for >=.
; Book line 1910: Compare X with literal 208 without changing X. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne font_letters           ; If Z=0 (last result nonzero, or comparison unequal), branch to font_letters.
; Book line 1911: Branch to font_letters if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1912: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Copy eight rows for each small custom glyph set.
font_custom:
; Book line 1914: font_custom names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda pellet_glyph,x         ; Read an entry from pellet_glyph (see the table description) into A; Z/N reflect that byte.
; Book line 1915: Load A with the byte at pellet_glyph plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $2b40,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1916: Store A into the byte at $2b40 plus index X. The register and CPU flags are
; unchanged.
 lda power_glyph,x          ; Read an entry from power_glyph (see the table description) into A; Z/N reflect that byte.
; Book line 1917: Load A with the byte at power_glyph plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $2b48,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1918: Store A into the byte at $2b48 plus index X. The register and CPU flags are
; unchanged.
 lda gate_glyph,x           ; Read an entry from gate_glyph (see the table description) into A; Z/N reflect that byte.
; Book line 1919: Load A with the byte at gate_glyph plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $2b50,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1920: Store A into the byte at $2b50 plus index X. The register and CPU flags are
; unchanged.
 lda house_top_glyph,x      ; Read an entry from house_top_glyph (see the table description) into A; Z/N reflect that byte.
; Book line 1921: Load A with the byte at house_top_glyph plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2b58,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1922: Store A into the byte at $2b58 plus index X. The register and CPU flags are
; unchanged.
 lda house_side_glyph,x     ; Read an entry from house_side_glyph (see the table description) into A; Z/N reflect that byte.
; Book line 1923: Load A with the byte at house_side_glyph plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2b60,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1924: Store A into the byte at $2b60 plus index X. The register and CPU flags are
; unchanged.
 lda house_bottom_glyph,x   ; Read an entry from house_bottom_glyph (see the table description) into A; Z/N reflect that byte.
; Book line 1925: Load A with the byte at house_bottom_glyph plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2b68,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1926: Store A into the byte at $2b68 plus index X. The register and CPU flags are
; unchanged.
 lda house_tl_glyph,x       ; Read an entry from house_tl_glyph (see the table description) into A; Z/N reflect that byte.
; Book line 1927: Load A with the byte at house_tl_glyph plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2b70,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1928: Store A into the byte at $2b70 plus index X. The register and CPU flags are
; unchanged.
 lda house_tr_glyph,x       ; Read an entry from house_tr_glyph (see the table description) into A; Z/N reflect that byte.
; Book line 1929: Load A with the byte at house_tr_glyph plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2b78,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1930: Store A into the byte at $2b78 plus index X. The register and CPU flags are
; unchanged.
 lda house_bl_glyph,x       ; Read an entry from house_bl_glyph (see the table description) into A; Z/N reflect that byte.
; Book line 1931: Load A with the byte at house_bl_glyph plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2b80,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1932: Store A into the byte at $2b80 plus index X. The register and CPU flags are
; unchanged.
 lda house_br_glyph,x       ; Read an entry from house_br_glyph (see the table description) into A; Z/N reflect that byte.
; Book line 1933: Load A with the byte at house_br_glyph plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2b88,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1934: Store A into the byte at $2b88 plus index X. The register and CPU flags are
; unchanged.
 lda concave_glyphs,x       ; Read an entry from concave_glyphs (see the table description) into A; Z/N reflect that byte.
; Book line 1935: Load A with the byte at concave_glyphs plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2e00,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1936: Store A into the byte at $2e00 plus index X. The register and CPU flags are
; unchanged.
 lda concave_glyphs+8,x     ; Read an entry from concave_glyphs (see the table description) into A; Z/N reflect that byte.
; Book line 1937: Load A with the byte at concave_glyphs+8 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2e08,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1938: Store A into the byte at $2e08 plus index X. The register and CPU flags are
; unchanged.
 lda concave_glyphs+16,x    ; Read an entry from concave_glyphs (see the table description) into A; Z/N reflect that byte.
; Book line 1939: Load A with the byte at concave_glyphs+16 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2e10,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1940: Store A into the byte at $2e10 plus index X. The register and CPU flags are
; unchanged.
 lda concave_glyphs+24,x    ; Read an entry from concave_glyphs (see the table description) into A; Z/N reflect that byte.
; Book line 1941: Load A with the byte at concave_glyphs+24 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2e18,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1942: Store A into the byte at $2e18 plus index X. The register and CPU flags are
; unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1943: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #8                     ; Compare X with #8; leave X unchanged, set Z for equal and C for >=.
; Book line 1944: Compare X with literal 8 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne font_custom            ; If Z=0 (last result nonzero, or comparison unequal), branch to font_custom.
; Book line 1945: Branch to font_custom if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1946: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Copy both halves of the 512-byte wall-glyph set.
copy_walls:
; Book line 1948: copy_walls names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda wall_glyphs,x          ; Read an entry from wall_glyphs (see the table description) into A; Z/N reflect that byte.
; Book line 1949: Load A with the byte at wall_glyphs plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $2c00,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1950: Store A into the byte at $2c00 plus index X. The register and CPU flags are
; unchanged.
 lda wall_glyphs+256,x      ; Read an entry from wall_glyphs (see the table description) into A; Z/N reflect that byte.
; Book line 1951: Load A with the byte at wall_glyphs+256 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2d00,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1952: Store A into the byte at $2d00 plus index X. The register and CPU flags are
; unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1953: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne copy_walls             ; If Z=0 (last result nonzero, or comparison unequal), branch to copy_walls.
; Book line 1954: Branch to copy_walls if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 1955: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Copy the exact central-glyph byte count into codes starting at 196.
central_font_copy:
; Book line 1957: central_font_copy names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda central_glyphs,x       ; Read an entry from central_glyphs (see the table description) into A; Z/N reflect that byte.
; Book line 1958: Load A with the byte at central_glyphs plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $2e20,x                ; Write A to the selected byte of the writable RAM font.
; Book line 1959: Store A into the byte at $2e20 plus index X. The register and CPU flags are
; unchanged.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 1960: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #120                   ; Compare X with #120; leave X unchanged, set Z for equal and C for >=.
; Book line 1961: Compare X with literal 120 without changing X. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne central_font_copy      ; If Z=0 (last result nonzero, or comparison unequal), branch to central_font_copy.
; Book line 1962: Branch to central_font_copy if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 1963: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Top-left, top-right, bottom-left, bottom-right of hollow 16px wall.

; Eight bitmap rows for screen code 104, an ordinary dot. Bit 7 is the leftmost pixel.
pellet_glyph: !byte $00,$00,$00,$18,$18,$00,$00,$00 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 1968: pellet_glyph names the data or instruction address. Emit 8 bytes in the shown order
; for pellet_glyph. These are data or encoded loader bytes, not instructions to execute.

; Eight bitmap rows for code 105, the larger power pellet.
power_glyph:  !byte $00,$18,$3c,$7e,$7e,$3c,$18,$00 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 1971: power_glyph names the data or instruction address. Emit 8 bytes in the shown order
; for power_glyph. These are data or encoded loader bytes, not instructions to execute.

; Eight bitmap rows for code 106, the gate stripe.
gate_glyph:   !byte $00,$00,$00,$ff,$ff,$00,$00,$00 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 1974: gate_glyph names the data or instruction address. Emit 8 bytes in the shown order
; for gate_glyph. These are data or encoded loader bytes, not instructions to execute.

; Retained blank glyph data; this legacy label is not copied by the current font
; installer.
house_glyph:  !byte $00,$00,$00,$00,$00,$00,$00,$00 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 1978: house_glyph names the data or instruction address. Emit 8 bytes in the shown order
; for house_glyph. These are data or encoded loader bytes, not instructions to execute.

; Legacy horizontal house glyph, code 107.
house_top_glyph: !byte $00,$00,$00,$ff,$ff,$00,$00,$00 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 1981: house_top_glyph names the data or instruction address. Emit 8 bytes in the shown
; order for house_top_glyph. These are data or encoded loader bytes, not instructions to execute.

; Legacy vertical house glyph, code 108.
house_side_glyph: !byte $18,$18,$18,$18,$18,$18,$18,$18 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 1984: house_side_glyph names the data or instruction address. Emit 8 bytes in the shown
; order for house_side_glyph. These are data or encoded loader bytes, not instructions to execute.

; Legacy lower edge glyph, code 109.
house_bottom_glyph: !byte $00,$00,$00,$ff,$ff,$00,$00,$00 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 1987: house_bottom_glyph names the data or instruction address. Emit 8 bytes in the shown
; order for house_bottom_glyph. These are data or encoded loader bytes, not instructions to execute.

; Legacy top-left house corner, code 110.
house_tl_glyph: !byte $00,$00,$00,$1f,$1f,$18,$18,$18 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 1990: house_tl_glyph names the data or instruction address. Emit 8 bytes in the shown
; order for house_tl_glyph. These are data or encoded loader bytes, not instructions to execute.

; Legacy top-right house corner, code 111.
house_tr_glyph: !byte $00,$00,$00,$f8,$f8,$18,$18,$18 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 1993: house_tr_glyph names the data or instruction address. Emit 8 bytes in the shown
; order for house_tr_glyph. These are data or encoded loader bytes, not instructions to execute.

; Legacy bottom-left house corner, code 112.
house_bl_glyph: !byte $18,$18,$18,$1f,$1f,$00,$00,$00 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 1996: house_bl_glyph names the data or instruction address. Emit 8 bytes in the shown
; order for house_bl_glyph. These are data or encoded loader bytes, not instructions to execute.

; Legacy bottom-right house corner, code 113.
house_br_glyph: !byte $18,$18,$18,$f8,$f8,$00,$00,$00 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 1999: house_br_glyph names the data or instruction address. Emit 8 bytes in the shown
; order for house_br_glyph. These are data or encoded loader bytes, not instructions to execute.
; Concave TL, TR, BL, BR quadrants; codes 192-195.

; Four 8x8 inside-corner glyphs at codes 192..195, ordered TL/TR/BL/BR.
concave_glyphs:
; Book line 2003: concave_glyphs names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 !byte $28,$28,$e8,$08,$f8,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2004: Emit 8 bytes in the shown order for concave_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $14,$14,$17,$10,$1f,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2005: Emit 8 bytes in the shown order for concave_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$f8,$08,$e8,$28,$28 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2006: Emit 8 bytes in the shown order for concave_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$1f,$10,$17,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2007: Emit 8 bytes in the shown order for concave_glyphs. These are data or encoded loader
; bytes, not instructions to execute.


; 26 letters A..Z, eight bitmap bytes each. Copied to font code 1 onward, not to ASCII
; code 65.
arcade_font:
; Book line 2012: arcade_font names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 !byte $60,$60,$60,$90,$90,$f0,$90,$00,$f0,$90,$90,$e0,$90,$90,$f0,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2013: Emit 16 bytes in the shown order for arcade_font. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $70,$80,$80,$80,$80,$80,$70,$00,$e0,$90,$90,$90,$90,$90,$e0,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2014: Emit 16 bytes in the shown order for arcade_font. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $f0,$80,$80,$f0,$80,$80,$f0,$00,$f0,$80,$80,$f0,$80,$80,$80,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2015: Emit 16 bytes in the shown order for arcade_font. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $70,$80,$80,$b0,$90,$90,$70,$00,$90,$90,$90,$f0,$90,$90,$90,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2016: Emit 16 bytes in the shown order for arcade_font. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $e0,$40,$40,$40,$40,$40,$e0,$00,$70,$10,$10,$10,$10,$90,$60,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2017: Emit 16 bytes in the shown order for arcade_font. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $90,$a0,$e0,$e0,$a0,$b0,$90,$00,$80,$80,$80,$80,$80,$80,$f0,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2018: Emit 16 bytes in the shown order for arcade_font. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $90,$f0,$f0,$f0,$90,$90,$90,$00,$90,$d0,$d0,$b0,$b0,$b0,$90,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2019: Emit 16 bytes in the shown order for arcade_font. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $60,$90,$90,$90,$90,$90,$60,$00,$e0,$90,$90,$e0,$80,$80,$80,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2020: Emit 16 bytes in the shown order for arcade_font. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $60,$90,$90,$90,$90,$90,$60,$10,$f0,$90,$90,$e0,$b0,$90,$98,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2021: Emit 16 bytes in the shown order for arcade_font. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $60,$90,$80,$70,$10,$90,$60,$00,$f0,$40,$40,$40,$40,$40,$40,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2022: Emit 16 bytes in the shown order for arcade_font. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $90,$90,$90,$90,$90,$90,$60,$00,$90,$90,$90,$90,$60,$60,$60,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2023: Emit 16 bytes in the shown order for arcade_font. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $10,$10,$50,$b0,$b0,$a0,$a0,$00,$90,$90,$60,$60,$60,$90,$90,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2024: Emit 16 bytes in the shown order for arcade_font. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $b0,$a0,$a0,$40,$40,$40,$40,$00,$f0,$30,$20,$60,$40,$c0,$f0,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2025: Emit 16 bytes in the shown order for arcade_font. These are data or encoded loader
; bytes, not instructions to execute.

; 512 bytes: 16 neighbor masks * 4 character quadrants * 8 bitmap rows. Code base 128;
; TL,TR,BL,BR order for each mask.
wall_glyphs:
; Book line 2029: wall_glyphs names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 !byte $00,$00,$0f,$10,$2f,$28,$28,$28,$00,$00,$f0,$08,$f4,$14,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2030: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$2f,$10,$0f,$00,$00,$14,$14,$14,$f4,$08,$f0,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2031: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$ff,$00,$ff,$00,$00,$00,$00,$00,$f0,$08,$f4,$14,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2032: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$ff,$00,$ff,$00,$00,$14,$14,$14,$f4,$08,$f0,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2033: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$0f,$10,$2f,$28,$28,$28,$00,$00,$ff,$00,$ff,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2034: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$2f,$10,$0f,$00,$00,$00,$00,$00,$ff,$00,$ff,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2035: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$ff,$00,$ff,$00,$00,$00,$00,$00,$ff,$00,$ff,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2036: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$ff,$00,$ff,$00,$00,$00,$00,$00,$ff,$00,$ff,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2037: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$28,$28,$28,$28,$28,$14,$14,$14,$14,$14,$14,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2038: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$2f,$10,$0f,$00,$00,$14,$14,$14,$f4,$08,$f0,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2039: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$14,$14,$14,$14,$14,$14,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2040: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$ff,$00,$ff,$00,$00,$14,$14,$14,$f4,$08,$f0,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2041: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$28,$28,$28,$28,$28,$00,$00,$00,$00,$00,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2042: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$2f,$10,$0f,$00,$00,$00,$00,$00,$ff,$00,$ff,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2043: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2044: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$ff,$00,$ff,$00,$00,$00,$00,$00,$ff,$00,$ff,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2045: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$0f,$10,$2f,$28,$28,$28,$00,$00,$f0,$08,$f4,$14,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2046: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$28,$28,$28,$28,$28,$14,$14,$14,$14,$14,$14,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2047: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$ff,$00,$ff,$00,$00,$00,$00,$00,$f0,$08,$f4,$14,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2048: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$14,$14,$14,$14,$14,$14,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2049: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$0f,$10,$2f,$28,$28,$28,$00,$00,$ff,$00,$ff,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2050: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$28,$28,$28,$28,$28,$00,$00,$00,$00,$00,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2051: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$ff,$00,$ff,$00,$00,$00,$00,$00,$ff,$00,$ff,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2052: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2053: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$28,$28,$28,$28,$28,$14,$14,$14,$14,$14,$14,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2054: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$28,$28,$28,$28,$28,$14,$14,$14,$14,$14,$14,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2055: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$14,$14,$14,$14,$14,$14,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2056: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$14,$14,$14,$14,$14,$14,$14,$14 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2057: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$28,$28,$28,$28,$28,$00,$00,$00,$00,$00,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2058: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $28,$28,$28,$28,$28,$28,$28,$28,$00,$00,$00,$00,$00,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2059: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2060: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Bitmap rows: each byte encodes eight left-to-right pixels, bit 7 first.
; Book line 2061: Emit 16 bytes in the shown order for wall_glyphs. These are data or encoded loader
; bytes, not instructions to execute.

; Print "P A C - 6 4" using explicit screen codes (A=1 ... Z=26), spaces=32 and
; digits=48..57; zero ends the string.
title_line: !byte 16,32,1,32,3,32,45,32,54,32,52,0 ; Screen-code text with a final zero terminator; do not replace with raw uppercase ASCII.
; Book line 2065: title_line names the data or instruction address. Emit 12 bytes in the shown order
; for title_line. These are data or encoded loader bytes, not instructions to execute.

; Print "PRESS FIRE TO START" using explicit screen codes (A=1 ... Z=26), spaces=32 and
; digits=48..57; zero ends the string.
start_line: !byte 16,18,5,19,19,32,6,9,18,5,32,20,15,32,19,20,1,18,20,0 ; Screen-code text with a final zero terminator; do not replace with raw uppercase ASCII.
; Book line 2069: start_line names the data or instruction address. Emit 20 bytes in the shown order
; for start_line. These are data or encoded loader bytes, not instructions to execute.

; Print "GAME OVER" using explicit screen codes (A=1 ... Z=26), spaces=32 and
; digits=48..57; zero ends the string.
over_line: !byte 7,1,13,5,32,15,22,5,18,0 ; Screen-code text with a final zero terminator; do not replace with raw uppercase ASCII.
; Book line 2073: over_line names the data or instruction address. Emit 10 bytes in the shown order
; for over_line. These are data or encoded loader bytes, not instructions to execute.

; Print "PRESS FIRE TO PLAY" using explicit screen codes (A=1 ... Z=26), spaces=32 and
; digits=48..57; zero ends the string.
replay_line: !byte 16,18,5,19,19,32,6,9,18,5,32,20,15,32,16,12,1,25,0 ; Screen-code text with a final zero terminator; do not replace with raw uppercase ASCII.
; Book line 2077: replay_line names the data or instruction address. Emit 19 bytes in the shown order
; for replay_line. These are data or encoded loader bytes, not instructions to execute.

; Pac-Man logical tile column, 0..18; a destination, not his current visible pixel X.
px: !byte 1 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2080: px names the data or instruction address. Emit 1 byte in the shown order for px.
; These are data or encoded loader bytes, not instructions to execute.
; Pac-Man logical tile row, 0..10.
py: !byte 1 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2082: py names the data or instruction address. Emit 1 byte in the shown order for py.
; These are data or encoded loader bytes, not instructions to execute.
; accepted travel direction: 0 up, 1 right, 2 down, 3 left.
direction: !byte 1 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2084: direction names the data or instruction address. Emit 1 byte in the shown order for
; direction. These are data or encoded loader bytes, not instructions to execute.
; buffered joystick direction; can differ from direction until a turn is legal.
requested: !byte 1 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2086: requested names the data or instruction address. Emit 1 byte in the shown order for
; requested. These are data or encoded loader bytes, not instructions to execute.
; remaining lives; new_game sets 3.
lives: !byte 3 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2088: lives names the data or instruction address. Emit 1 byte in the shown order for
; lives. These are data or encoded loader bytes, not instructions to execute.
; two bytes reserved, but only score (low byte) is used; displayed score wraps at 256.
score: !byte 0,0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2090: score names the data or instruction address. Emit 2 bytes in the shown order for
; score. These are data or encoded loader bytes, not instructions to execute.
; 8-bit frame counter; wraps 255 to 0 and drives mouth animation and ghost target phase.
tick: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2092: tick names the data or instruction address. Emit 1 byte in the shown order for tick.
; These are data or encoded loader bytes, not instructions to execute.
; logical row being painted.
row_index: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2094: row_index names the data or instruction address. Emit 1 byte in the shown order for
; row_index. These are data or encoded loader bytes, not instructions to execute.
; logical column being painted.
col_index: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2096: col_index names the data or instruction address. Emit 1 byte in the shown order for
; col_index. These are data or encoded loader bytes, not instructions to execute.
; renderer tile identifier; this is not necessarily the live map character.
tile_kind: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2098: tile_kind names the data or instruction address. Emit 1 byte in the shown order for
; tile_kind. These are data or encoded loader bytes, not instructions to execute.
; temporary ink color for all four cells of one tile.
paint_ink: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2100: paint_ink names the data or instruction address. Emit 1 byte in the shown order for
; paint_ink. These are data or encoded loader bytes, not instructions to execute.
; temporary score remainder during decimal digit conversion.
score_work: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2102: score_work names the data or instruction address. Emit 1 byte in the shown order for
; score_work. These are data or encoded loader bytes, not instructions to execute.
; temporary tens digit.
score_tens: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2104: score_tens names the data or instruction address. Emit 1 byte in the shown order for
; score_tens. These are data or encoded loader bytes, not instructions to execute.
; temporary hundreds digit.
score_hundreds: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2106: score_hundreds names the data or instruction address. Emit 1 byte in the shown order
; for score_hundreds. These are data or encoded loader bytes, not instructions to execute.
; 0 for player probes, 1 for ghost probes; controls house access.
actor_is_ghost: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2108: actor_is_ghost names the data or instruction address. Emit 1 byte in the shown order
; for actor_is_ghost. These are data or encoded loader bytes, not instructions to execute.
; little-endian 16-bit vulnerability countdown: low byte then high byte.
power_timer: !byte 0,0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2110: power_timer names the data or instruction address. Emit 2 bytes in the shown order
; for power_timer. These are data or encoded loader bytes, not instructions to execute.
; current screen character for a wall quadrant.
glyph_code: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2112: glyph_code names the data or instruction address. Emit 1 byte in the shown order for
; glyph_code. These are data or encoded loader bytes, not instructions to execute.
; four neighbor bits used to choose the wall shape.
wall_flags: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2114: wall_flags names the data or instruction address. Emit 1 byte in the shown order for
; wall_flags. These are data or encoded loader bytes, not instructions to execute.
; candidate tile column produced by can_step.
probe_x: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2116: probe_x names the data or instruction address. Emit 1 byte in the shown order for
; probe_x. These are data or encoded loader bytes, not instructions to execute.
; candidate tile row produced by can_step.
probe_y: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2118: probe_y names the data or instruction address. Emit 1 byte in the shown order for
; probe_y. These are data or encoded loader bytes, not instructions to execute.
; saved direction while probing a candidate.
probe_direction: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2120: probe_direction names the data or instruction address. Emit 1 byte in the shown
; order for probe_direction. These are data or encoded loader bytes, not instructions to execute.
; legacy reserved data; not read by the current game logic (kept to preserve the binary).
trial_direction: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2122: trial_direction names the data or instruction address. Emit 1 byte in the shown
; order for trial_direction. These are data or encoded loader bytes, not instructions to execute.
; which ghost (0..3) the current loop is processing.
ghost_index: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2124: ghost_index names the data or instruction address. Emit 1 byte in the shown order
; for ghost_index. These are data or encoded loader bytes, not instructions to execute.
; legacy reserved data; not read by the current game logic (kept to preserve the binary).
ghost_attempt: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2126: ghost_attempt names the data or instruction address. Emit 1 byte in the shown order
; for ghost_attempt. These are data or encoded loader bytes, not instructions to execute.
; legacy reserved data; not read by the current game logic (kept to preserve the binary).
ghost_bias: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2128: ghost_bias names the data or instruction address. Emit 1 byte in the shown order for
; ghost_bias. These are data or encoded loader bytes, not instructions to execute.
; distance-field number: 0 NW, 1 NE, 2 SW, 3 SE, 4 home.
ghost_target: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2130: ghost_target names the data or instruction address. Emit 1 byte in the shown order
; for ghost_target. These are data or encoded loader bytes, not instructions to execute.
; candidate direction 0..3.
ghost_try_dir: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2132: ghost_try_dir names the data or instruction address. Emit 1 byte in the shown order
; for ghost_try_dir. These are data or encoded loader bytes, not instructions to execute.
; smallest distance seen so far; 255 means no route found.
ghost_best: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2134: ghost_best names the data or instruction address. Emit 1 byte in the shown order for
; ghost_best. These are data or encoded loader bytes, not instructions to execute.
; direction of the best candidate.
ghost_best_dir: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2136: ghost_best_dir names the data or instruction address. Emit 1 byte in the shown order
; for ghost_best_dir. These are data or encoded loader bytes, not instructions to execute.
; column of the best candidate.
ghost_best_x: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2138: ghost_best_x names the data or instruction address. Emit 1 byte in the shown order
; for ghost_best_x. These are data or encoded loader bytes, not instructions to execute.
; row of the best candidate.
ghost_best_y: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2140: ghost_best_y names the data or instruction address. Emit 1 byte in the shown order
; for ghost_best_y. These are data or encoded loader bytes, not instructions to execute.
; candidate flat map index: row*19+column.
ghost_map_index: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2142: ghost_map_index names the data or instruction address. Emit 1 byte in the shown
; order for ghost_map_index. These are data or encoded loader bytes, not instructions to execute.
; legacy reserved data; not read by the current game logic (kept to preserve the binary).
ghost_turn_offsets: !byte 0,3,1,2 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2144: ghost_turn_offsets names the data or instruction address. Emit 4 bytes in the shown
; order for ghost_turn_offsets. These are data or encoded loader bytes, not instructions to execute.
; frames of contact immunity after losing a life; it skips all contact processing.
hit_cooldown: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2146: hit_cooldown names the data or instruction address. Emit 1 byte in the shown order
; for hit_cooldown. These are data or encoded loader bytes, not instructions to execute.
; four entries: 0 normal, 1 frightened, 2 returning eyes, 3 regenerating.
ghost_state: !fill 4,0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2148: ghost_state names the data or instruction address. Emit repeated initial data for
; ghost_state: 4,0. The first expression is the byte count and the second is the fill value.
; four regeneration countdowns; decremented at tile decisions, not every frame.
ghost_regen: !fill 4,0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2150: ghost_regen names the data or instruction address. Emit repeated initial data for
; ghost_regen: 4,0. The first expression is the byte count and the second is the fill value.
; body color per ghost: red 2, light red 10, cyan 3, orange 8.
ghost_base_colours: !byte 2,10,3,8 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2152: ghost_base_colours names the data or instruction address. Emit 4 bytes in the shown
; order for ghost_base_colours. These are data or encoded loader bytes, not instructions to execute.
; combined ninth-X-bit mask for the visible hardware sprites.
high_bits: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2154: high_bits names the data or instruction address. Emit 1 byte in the shown order for
; high_bits. These are data or encoded loader bytes, not instructions to execute.
; four ghost logical tile columns.
gx: !fill 4,0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2156: gx names the data or instruction address. Emit repeated initial data for gx: 4,0.
; The first expression is the byte count and the second is the fill value.
; four ghost logical tile rows.
gy: !fill 4,0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2158: gy names the data or instruction address. Emit repeated initial data for gy: 4,0.
; The first expression is the byte count and the second is the fill value.
; four last-selected ghost directions; stored by routing, not used for current sprite
; selection.
gd: !fill 4,0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2161: gd names the data or instruction address. Emit repeated initial data for gd: 4,0.
; The first expression is the byte count and the second is the fill value.
; four spawn columns.
ghost_start_x: !byte 8,9,10,9 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2163: ghost_start_x names the data or instruction address. Emit 4 bytes in the shown order
; for ghost_start_x. These are data or encoded loader bytes, not instructions to execute.
; four spawn rows.
ghost_start_y: !byte 6,6,6,5 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2165: ghost_start_y names the data or instruction address. Emit 4 bytes in the shown order
; for ghost_start_y. These are data or encoded loader bytes, not instructions to execute.
; hardware sprite X-bit lookup; Y is 2,4,6,8 for ghosts, yielding bits 2,4,8,16.
bit_masks: !byte 0,0,2,0,4,0,8,0,16,0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2167: bit_masks names the data or instruction address. Emit 10 bytes in the shown order
; for bit_masks. These are data or encoded loader bytes, not instructions to execute.

; Logical maze, 19 columns x 11 rows

; Screen codes for the fixed SCORE, LIVES and LEVEL labels; zero terminates the print
; loop.
hud_text: !byte 32,19,3,15,18,5,32,32,32,32,32,32,32,32,32,32,32,32,12,9,22,5,19,32,32,32,32,32,32,32,32,32,12,5,22,5,12,32,32,32,0 ; Screen-code text with a final zero terminator; do not replace with raw uppercase ASCII.
; Book line 2173: hud_text names the data or instruction address. Emit 41 bytes in the shown order for
; hud_text. These are data or encoded loader bytes, not instructions to execute.
; Live maze row 0, columns 0..18. #=wall, .=dot, o=power, H=house, E=door, T=tunnel.
row0: !text "###################" ; Map data, not instructions; consumed pellets will be replaced with space (32).
; Book line 2175: row0 names the data or instruction address. Emit the quoted text as literal text
; bytes, used here as loader or message data; these are not automatically screen codes.
; Live maze row 1, columns 0..18. #=wall, .=dot, o=power, H=house, E=door, T=tunnel.
row1: !text "#o.......#.......o#" ; Map data, not instructions; consumed pellets will be replaced with space (32).
; Book line 2177: row1 names the data or instruction address. Emit the quoted text as literal text
; bytes, used here as loader or message data; these are not automatically screen codes.
; Live maze row 2, columns 0..18. #=wall, .=dot, o=power, H=house, E=door, T=tunnel.
row2: !text "#.###.##.#.##.###.#" ; Map data, not instructions; consumed pellets will be replaced with space (32).
; Book line 2179: row2 names the data or instruction address. Emit the quoted text as literal text
; bytes, used here as loader or message data; these are not automatically screen codes.
; Live maze row 3, columns 0..18. #=wall, .=dot, o=power, H=house, E=door, T=tunnel.
row3: !text "#...#.........#...#" ; Map data, not instructions; consumed pellets will be replaced with space (32).
; Book line 2181: row3 names the data or instruction address. Emit the quoted text as literal text
; bytes, used here as loader or message data; these are not automatically screen codes.
; Live maze row 4, columns 0..18. #=wall, .=dot, o=power, H=house, E=door, T=tunnel.
row4: !text "###.#.##...##.#.###" ; Map data, not instructions; consumed pellets will be replaced with space (32).
; Book line 2183: row4 names the data or instruction address. Emit the quoted text as literal text
; bytes, used here as loader or message data; these are not automatically screen codes.
; Live maze row 5, columns 0..18. #=wall, .=dot, o=power, H=house, E=door, T=tunnel.
row5: !text "T......##E##......T" ; Map data, not instructions; consumed pellets will be replaced with space (32).
; Book line 2185: row5 names the data or instruction address. Emit the quoted text as literal text
; bytes, used here as loader or message data; these are not automatically screen codes.
; Live maze row 6, columns 0..18. #=wall, .=dot, o=power, H=house, E=door, T=tunnel.
row6: !text "#.###.##HHH##.###.#" ; Map data, not instructions; consumed pellets will be replaced with space (32).
; Book line 2187: row6 names the data or instruction address. Emit the quoted text as literal text
; bytes, used here as loader or message data; these are not automatically screen codes.
; Live maze row 7, columns 0..18. #=wall, .=dot, o=power, H=house, E=door, T=tunnel.
row7: !text "#......#####......#" ; Map data, not instructions; consumed pellets will be replaced with space (32).
; Book line 2189: row7 names the data or instruction address. Emit the quoted text as literal text
; bytes, used here as loader or message data; these are not automatically screen codes.
; Live maze row 8, columns 0..18. #=wall, .=dot, o=power, H=house, E=door, T=tunnel.
row8: !text "#.###.........###.#" ; Map data, not instructions; consumed pellets will be replaced with space (32).
; Book line 2191: row8 names the data or instruction address. Emit the quoted text as literal text
; bytes, used here as loader or message data; these are not automatically screen codes.
; Live maze row 9, columns 0..18. #=wall, .=dot, o=power, H=house, E=door, T=tunnel.
row9: !text "#o...............o#" ; Map data, not instructions; consumed pellets will be replaced with space (32).
; Book line 2193: row9 names the data or instruction address. Emit the quoted text as literal text
; bytes, used here as loader or message data; these are not automatically screen codes.
; Live maze row 10, columns 0..18. #=wall, .=dot, o=power, H=house, E=door, T=tunnel.
row10: !text "###################" ; Map data, not instructions; consumed pellets will be replaced with space (32).
; Book line 2195: row10 names the data or instruction address. Emit the quoted text as literal text
; bytes, used here as loader or message data; these are not automatically screen codes.
; Regenerated for the V7 corridor: shortest path fields for patrol
; corners plus the house. 255 marks blocked or unreachable tiles.

; Precomputed row*19 offsets, so a map/field lookup needs addition rather than
; multiplication.
map_row_offset: !byte 0,19,38,57,76,95,114,133,152,171,190 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 2201: map_row_offset names the data or instruction address. Emit 11 bytes in the shown
; order for map_row_offset. These are data or encoded loader bytes, not instructions to execute.

; Low bytes of the five distance-field addresses, in NW/NE/SW/SE/home order.
distance_lo: !byte <dist_nw,<dist_ne,<dist_sw,<dist_se,<dist_home ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 2204: distance_lo names the data or instruction address. Emit 5 bytes in the shown order
; for distance_lo. These are data or encoded loader bytes, not instructions to execute.

; Matching high bytes; together the two tables form five 16-bit addresses.
distance_hi: !byte >dist_nw,>dist_ne,>dist_sw,>dist_se,>dist_home ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 2207: distance_hi names the data or instruction address. Emit 5 bytes in the shown order
; for distance_hi. These are data or encoded loader bytes, not instructions to execute.

; 209 shortest-path distances to north-west patrol corner (1,1). Each line is one
; 19-column map row. 255 marks walls/unreachable cells; 0 marks the target. These values
; must match maze_template, including the row-5 tunnel.
dist_nw:
; Book line 2212: dist_nw names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255 ; Distance field row 0, 19 columns; values are steps, not pixel coordinates.
; Book line 2213: Emit 19 bytes in the shown order for dist_nw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,0,1,2,3,4,5,6,7,255,13,14,15,16,17,18,19,19,255 ; Distance field row 1, 19 columns; values are steps, not pixel coordinates.
; Book line 2214: Emit 19 bytes in the shown order for dist_nw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,1,255,255,255,5,255,255,8,255,12,255,255,15,255,255,255,18,255 ; Distance field row 2, 19 columns; values are steps, not pixel coordinates.
; Book line 2215: Emit 19 bytes in the shown order for dist_nw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,2,3,4,255,6,7,8,9,10,11,12,13,14,255,15,16,17,255 ; Distance field row 3, 19 columns; values are steps, not pixel coordinates.
; Book line 2216: Emit 19 bytes in the shown order for dist_nw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,255,255,5,255,7,255,255,10,11,12,255,255,15,255,14,255,255,255 ; Distance field row 4, 19 columns; values are steps, not pixel coordinates.
; Book line 2217: Emit 19 bytes in the shown order for dist_nw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 9,8,7,6,7,8,9,255,255,12,255,255,16,15,14,13,12,11,10 ; Distance field row 5, 19 columns; values are steps, not pixel coordinates.
; Book line 2218: Emit 19 bytes in the shown order for dist_nw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,9,255,255,255,9,255,255,14,13,14,255,255,16,255,255,255,12,255 ; Distance field row 6, 19 columns; values are steps, not pixel coordinates.
; Book line 2219: Emit 19 bytes in the shown order for dist_nw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,10,11,12,11,10,11,255,255,255,255,255,18,17,16,15,14,13,255 ; Distance field row 7, 19 columns; values are steps, not pixel coordinates.
; Book line 2220: Emit 19 bytes in the shown order for dist_nw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,11,255,255,255,11,12,13,14,15,16,17,18,18,255,255,255,14,255 ; Distance field row 8, 19 columns; values are steps, not pixel coordinates.
; Book line 2221: Emit 19 bytes in the shown order for dist_nw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,12,13,14,13,12,13,14,15,16,17,18,19,19,18,17,16,15,255 ; Distance field row 9, 19 columns; values are steps, not pixel coordinates.
; Book line 2222: Emit 19 bytes in the shown order for dist_nw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255 ; Distance field row 10, 19 columns; values are steps, not pixel coordinates.
; Book line 2223: Emit 19 bytes in the shown order for dist_nw. These are data or encoded loader
; bytes, not instructions to execute.

; 209 shortest-path distances to north-east patrol corner (17,1). Each line is one
; 19-column map row. 255 marks walls/unreachable cells; 0 marks the target. These values
; must match maze_template, including the row-5 tunnel.
dist_ne:
; Book line 2228: dist_ne names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255 ; Distance field row 0, 19 columns; values are steps, not pixel coordinates.
; Book line 2229: Emit 19 bytes in the shown order for dist_ne. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,19,19,18,17,16,15,14,13,255,7,6,5,4,3,2,1,0,255 ; Distance field row 1, 19 columns; values are steps, not pixel coordinates.
; Book line 2230: Emit 19 bytes in the shown order for dist_ne. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,18,255,255,255,15,255,255,12,255,8,255,255,5,255,255,255,1,255 ; Distance field row 2, 19 columns; values are steps, not pixel coordinates.
; Book line 2231: Emit 19 bytes in the shown order for dist_ne. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,17,16,15,255,14,13,12,11,10,9,8,7,6,255,4,3,2,255 ; Distance field row 3, 19 columns; values are steps, not pixel coordinates.
; Book line 2232: Emit 19 bytes in the shown order for dist_ne. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,255,255,14,255,15,255,255,12,11,10,255,255,7,255,5,255,255,255 ; Distance field row 4, 19 columns; values are steps, not pixel coordinates.
; Book line 2233: Emit 19 bytes in the shown order for dist_ne. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 10,11,12,13,14,15,16,255,255,12,255,255,9,8,7,6,7,8,9 ; Distance field row 5, 19 columns; values are steps, not pixel coordinates.
; Book line 2234: Emit 19 bytes in the shown order for dist_ne. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,12,255,255,255,16,255,255,14,13,14,255,255,9,255,255,255,9,255 ; Distance field row 6, 19 columns; values are steps, not pixel coordinates.
; Book line 2235: Emit 19 bytes in the shown order for dist_ne. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,13,14,15,16,17,18,255,255,255,255,255,11,10,11,12,11,10,255 ; Distance field row 7, 19 columns; values are steps, not pixel coordinates.
; Book line 2236: Emit 19 bytes in the shown order for dist_ne. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,14,255,255,255,18,18,17,16,15,14,13,12,11,255,255,255,11,255 ; Distance field row 8, 19 columns; values are steps, not pixel coordinates.
; Book line 2237: Emit 19 bytes in the shown order for dist_ne. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,15,16,17,18,19,19,18,17,16,15,14,13,12,13,14,13,12,255 ; Distance field row 9, 19 columns; values are steps, not pixel coordinates.
; Book line 2238: Emit 19 bytes in the shown order for dist_ne. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255 ; Distance field row 10, 19 columns; values are steps, not pixel coordinates.
; Book line 2239: Emit 19 bytes in the shown order for dist_ne. These are data or encoded loader
; bytes, not instructions to execute.

; 209 shortest-path distances to south-west patrol corner (1,9). Each line is one
; 19-column map row. 255 marks walls/unreachable cells; 0 marks the target. These values
; must match maze_template, including the row-5 tunnel.
dist_sw:
; Book line 2244: dist_sw names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255 ; Distance field row 0, 19 columns; values are steps, not pixel coordinates.
; Book line 2245: Emit 19 bytes in the shown order for dist_sw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,12,13,14,13,12,13,14,15,255,17,17,16,15,16,17,16,15,255 ; Distance field row 1, 19 columns; values are steps, not pixel coordinates.
; Book line 2246: Emit 19 bytes in the shown order for dist_sw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,11,255,255,255,11,255,255,14,255,16,255,255,14,255,255,255,14,255 ; Distance field row 2, 19 columns; values are steps, not pixel coordinates.
; Book line 2247: Emit 19 bytes in the shown order for dist_sw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,10,9,8,255,10,11,12,13,14,15,15,14,13,255,11,12,13,255 ; Distance field row 3, 19 columns; values are steps, not pixel coordinates.
; Book line 2248: Emit 19 bytes in the shown order for dist_sw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,255,255,7,255,9,255,255,14,15,16,255,255,12,255,10,255,255,255 ; Distance field row 4, 19 columns; values are steps, not pixel coordinates.
; Book line 2249: Emit 19 bytes in the shown order for dist_sw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 5,4,5,6,7,8,9,255,255,16,255,255,12,11,10,9,8,7,6 ; Distance field row 5, 19 columns; values are steps, not pixel coordinates.
; Book line 2250: Emit 19 bytes in the shown order for dist_sw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,3,255,255,255,7,255,255,18,17,18,255,255,12,255,255,255,8,255 ; Distance field row 6, 19 columns; values are steps, not pixel coordinates.
; Book line 2251: Emit 19 bytes in the shown order for dist_sw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,2,3,4,5,6,7,255,255,255,255,255,13,13,12,11,10,9,255 ; Distance field row 7, 19 columns; values are steps, not pixel coordinates.
; Book line 2252: Emit 19 bytes in the shown order for dist_sw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,1,255,255,255,5,6,7,8,9,10,11,12,13,255,255,255,10,255 ; Distance field row 8, 19 columns; values are steps, not pixel coordinates.
; Book line 2253: Emit 19 bytes in the shown order for dist_sw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,0,1,2,3,4,5,6,7,8,9,10,11,12,13,13,12,11,255 ; Distance field row 9, 19 columns; values are steps, not pixel coordinates.
; Book line 2254: Emit 19 bytes in the shown order for dist_sw. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255 ; Distance field row 10, 19 columns; values are steps, not pixel coordinates.
; Book line 2255: Emit 19 bytes in the shown order for dist_sw. These are data or encoded loader
; bytes, not instructions to execute.

; 209 shortest-path distances to south-east patrol corner (17,9). Each line is one
; 19-column map row. 255 marks walls/unreachable cells; 0 marks the target. These values
; must match maze_template, including the row-5 tunnel.
dist_se:
; Book line 2260: dist_se names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255 ; Distance field row 0, 19 columns; values are steps, not pixel coordinates.
; Book line 2261: Emit 19 bytes in the shown order for dist_se. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,15,16,17,16,15,16,17,17,255,15,14,13,12,13,14,13,12,255 ; Distance field row 1, 19 columns; values are steps, not pixel coordinates.
; Book line 2262: Emit 19 bytes in the shown order for dist_se. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,14,255,255,255,14,255,255,16,255,14,255,255,11,255,255,255,11,255 ; Distance field row 2, 19 columns; values are steps, not pixel coordinates.
; Book line 2263: Emit 19 bytes in the shown order for dist_se. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,13,12,11,255,13,14,15,15,14,13,12,11,10,255,8,9,10,255 ; Distance field row 3, 19 columns; values are steps, not pixel coordinates.
; Book line 2264: Emit 19 bytes in the shown order for dist_se. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,255,255,10,255,12,255,255,16,15,14,255,255,9,255,7,255,255,255 ; Distance field row 4, 19 columns; values are steps, not pixel coordinates.
; Book line 2265: Emit 19 bytes in the shown order for dist_se. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 6,7,8,9,10,11,12,255,255,16,255,255,9,8,7,6,5,4,5 ; Distance field row 5, 19 columns; values are steps, not pixel coordinates.
; Book line 2266: Emit 19 bytes in the shown order for dist_se. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,8,255,255,255,12,255,255,18,17,18,255,255,7,255,255,255,3,255 ; Distance field row 6, 19 columns; values are steps, not pixel coordinates.
; Book line 2267: Emit 19 bytes in the shown order for dist_se. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,9,10,11,12,13,13,255,255,255,255,255,7,6,5,4,3,2,255 ; Distance field row 7, 19 columns; values are steps, not pixel coordinates.
; Book line 2268: Emit 19 bytes in the shown order for dist_se. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,10,255,255,255,13,12,11,10,9,8,7,6,5,255,255,255,1,255 ; Distance field row 8, 19 columns; values are steps, not pixel coordinates.
; Book line 2269: Emit 19 bytes in the shown order for dist_se. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,11,12,13,13,12,11,10,9,8,7,6,5,4,3,2,1,0,255 ; Distance field row 9, 19 columns; values are steps, not pixel coordinates.
; Book line 2270: Emit 19 bytes in the shown order for dist_se. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255 ; Distance field row 10, 19 columns; values are steps, not pixel coordinates.
; Book line 2271: Emit 19 bytes in the shown order for dist_se. These are data or encoded loader
; bytes, not instructions to execute.

; 209 shortest-path distances to ghost home (9,6). Each line is one 19-column map row. 255
; marks walls/unreachable cells; 0 marks the target. These values must match
; maze_template, including the row-5 tunnel.
dist_home:
; Book line 2276: dist_home names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255 ; Distance field row 0, 19 columns; values are steps, not pixel coordinates.
; Book line 2277: Emit 19 bytes in the shown order for dist_home. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,13,12,11,10,9,8,7,6,255,6,7,8,9,10,11,12,13,255 ; Distance field row 1, 19 columns; values are steps, not pixel coordinates.
; Book line 2278: Emit 19 bytes in the shown order for dist_home. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,14,255,255,255,8,255,255,5,255,5,255,255,8,255,255,255,14,255 ; Distance field row 2, 19 columns; values are steps, not pixel coordinates.
; Book line 2279: Emit 19 bytes in the shown order for dist_home. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,15,14,13,255,7,6,5,4,3,4,5,6,7,255,13,14,15,255 ; Distance field row 3, 19 columns; values are steps, not pixel coordinates.
; Book line 2280: Emit 19 bytes in the shown order for dist_home. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,255,255,12,255,8,255,255,3,2,3,255,255,8,255,12,255,255,255 ; Distance field row 4, 19 columns; values are steps, not pixel coordinates.
; Book line 2281: Emit 19 bytes in the shown order for dist_home. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 14,13,12,11,10,9,10,255,255,1,255,255,10,9,10,11,12,13,14 ; Distance field row 5, 19 columns; values are steps, not pixel coordinates.
; Book line 2282: Emit 19 bytes in the shown order for dist_home. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,14,255,255,255,10,255,255,1,0,1,255,255,10,255,255,255,14,255 ; Distance field row 6, 19 columns; values are steps, not pixel coordinates.
; Book line 2283: Emit 19 bytes in the shown order for dist_home. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,15,14,13,12,11,12,255,255,255,255,255,12,11,12,13,14,15,255 ; Distance field row 7, 19 columns; values are steps, not pixel coordinates.
; Book line 2284: Emit 19 bytes in the shown order for dist_home. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,16,255,255,255,12,13,14,15,16,15,14,13,12,255,255,255,16,255 ; Distance field row 8, 19 columns; values are steps, not pixel coordinates.
; Book line 2285: Emit 19 bytes in the shown order for dist_home. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,17,16,15,14,13,14,15,16,17,16,15,14,13,14,15,16,17,255 ; Distance field row 9, 19 columns; values are steps, not pixel coordinates.
; Book line 2286: Emit 19 bytes in the shown order for dist_home. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255 ; Distance field row 10, 19 columns; values are steps, not pixel coordinates.
; Book line 2287: Emit 19 bytes in the shown order for dist_home. These are data or encoded loader
; bytes, not instructions to execute.

; Low bytes of the eleven live row addresses. Separate tables make indirect addressing
; convenient.
row_lo: !byte <row0,<row1,<row2,<row3,<row4,<row5,<row6,<row7,<row8,<row9,<row10 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 2291: row_lo names the data or instruction address. Emit 11 bytes in the shown order for
; row_lo. These are data or encoded loader bytes, not instructions to execute.

; High bytes of those same eleven addresses.
row_hi: !byte >row0,>row1,>row2,>row3,>row4,>row5,>row6,>row7,>row8,>row9,>row10 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 2294: row_hi names the data or instruction address. Emit 11 bytes in the shown order for
; row_hi. These are data or encoded loader bytes, not instructions to execute.

; Low bytes of each tile row screen base. The top-left logical tile starts at screen row
; 3, column 1.
screen_row_lo: !byte <($0478),<($04c8),<($0518),<($0568),<($05b8),<($0608),<($0658),<($06a8),<($06f8),<($0748),<($0798) ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 2298: screen_row_lo names the data or instruction address. Emit 11 bytes in the shown
; order for screen_row_lo. These are data or encoded loader bytes, not instructions to execute.

; Matching screen-base high bytes.
screen_row_hi: !byte >($0478),>($04c8),>($0518),>($0568),>($05b8),>($0608),>($0658),>($06a8),>($06f8),>($0748),>($0798) ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 2301: screen_row_hi names the data or instruction address. Emit 11 bytes in the shown
; order for screen_row_hi. These are data or encoded loader bytes, not instructions to execute.

; Low bytes of the equivalent Color RAM row bases.
color_row_lo: !byte <($d878),<($d8c8),<($d918),<($d968),<($d9b8),<($da08),<($da58),<($daa8),<($daf8),<($db48),<($db98) ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 2304: color_row_lo names the data or instruction address. Emit 11 bytes in the shown order
; for color_row_lo. These are data or encoded loader bytes, not instructions to execute.

; Matching Color RAM high bytes.
color_row_hi: !byte >($d878),>($d8c8),>($d918),>($d968),>($d9b8),>($da08),>($da58),>($daa8),>($daf8),>($db48),>($db98) ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 2307: color_row_hi names the data or instruction address. Emit 11 bytes in the shown order
; for color_row_hi. These are data or encoded loader bytes, not instructions to execute.

; Low byte of hardware X for each logical column. Values wrap after 252, so use sprite_xhi
; too.
sprite_xlo: !byte 28,44,60,76,92,108,124,140,156,172,188,204,220,236,252,12,28,44,60 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 2311: sprite_xlo names the data or instruction address. Emit 19 bytes in the shown order
; for sprite_xlo. These are data or encoded loader bytes, not instructions to execute. The surrounding
; image definition determines how these bits become pixels.

; Ninth-X-bit values for columns at X >= 256.
sprite_xhi: !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 2314: sprite_xhi names the data or instruction address. Emit 19 bytes in the shown order
; for sprite_xhi. These are data or encoded loader bytes, not instructions to execute. The surrounding
; image definition determines how these bits become pixels.

; Hardware Y for each logical row, increasing by 16 pixels per tile.
sprite_y: !byte 72,88,104,120,136,152,168,184,200,216,232 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 2317: sprite_y names the data or instruction address. Emit 11 bytes in the shown order for
; sprite_y. These are data or encoded loader bytes, not instructions to execute. The surrounding image
; definition determines how these bits become pixels.

; Start a fresh maze, keeping the player's score and remaining lives.

; ============================================================================
; next_level - ADVANCE THE DISPLAYED LEVEL WHILE PRESERVING SCORE AND LIVES
; Increase level until 99, then keep it at 99. JMP into start_level lets its final RTS
; return to the original JSR next_level caller. The same maze is refilled; no speed
; increase or new layout is introduced.
; ============================================================================
next_level:
; Book line 2327: next_level names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda level                  ; Read displayed level 1..99; later completions still refill level 99 into A; Z/N reflect that byte.
; Book line 2328: Load A with the byte at level. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #99                    ; Compare A with #99; leave A unchanged, set Z for equal and C for >=.
; Book line 2329: Compare A with literal 99 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs next_level_ready       ; If C=1 (after CMP: unsigned value >= operand), branch to next_level_ready.
; Book line 2330: Branch to next_level_ready if C is 1; otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 ; Increase displayed level 1..99; later completions still refill level 99 by 1, wrapping within
 ; 0..255; update Z/N.
 inc level
; Book line 2333: Increase the byte at level by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
; Enter the shared level initialization without resetting score/lives.
next_level_ready:
; Book line 2335: next_level_ready names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 jmp start_level            ; Continue at start_level without saving a return address.
; Book line 2336: Continue execution at start_level without saving a return address. Registers and
; flags are unchanged by the jump itself.

; ============================================================================
; restore_maze - COPY THE IMMUTABLE MAP BACK INTO THE LIVE MAP
; The 11 rows are contiguous: 19*11=209 bytes. Copy each byte from maze_template to row0
; and count both dot and power-pellet markers. There are 100 pellets in this layout. Wall
; symbols and distance fields stay consistent.
; ============================================================================
restore_maze:
; Book line 2344: restore_maze names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 2345: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta pellets_left           ; Write A to number of remaining dots plus power pellets; reaches zero only once each is consumed.
; Book line 2346: Store A into the byte at pellets_left (remaining maze pellets). The register and CPU
; flags are unchanged.
 ldx #0                     ; Load X with literal 0; this also sets Z and N.
; Book line 2347: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
; Restore and classify one template byte.
restore_maze_loop:
; Book line 2349: restore_maze_loop names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda maze_template,x        ; Read an entry from maze_template (see the table description) into A; Z/N reflect that byte.
; Book line 2350: Load A with the byte at maze_template plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta row0,x                 ; Write A to row0,x.
; Book line 2351: Store A into the byte at row0 plus index X. The register and CPU flags are
; unchanged.
 cmp #46                    ; Compare A with #46; leave A unchanged, set Z for equal and C for >=.
; Book line 2352: Compare A with literal 46 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq restore_count_pellet   ; If Z=1 (last result zero, or comparison equal), branch to restore_count_pellet.
; Book line 2353: Branch to restore_count_pellet if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 cmp #111                   ; Compare A with #111; leave A unchanged, set Z for equal and C for >=.
; Book line 2354: Compare A with literal 111 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne restore_maze_next      ; If Z=0 (last result nonzero, or comparison unequal), branch to restore_maze_next.
; Book line 2355: Branch to restore_maze_next if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
; Count a dot or power pellet in the restored map.
restore_count_pellet:
; Book line 2357: restore_count_pellet names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 ; Increase number of remaining dots plus power pellets; reaches zero only once each is consumed by 1,
 ; wrapping within 0..255; update Z/N.
 inc pellets_left
; Book line 2360: Increase the byte at pellets_left (remaining maze pellets) by one with 8-bit
; wraparound. Update Z and N; carry is unchanged.
; Continue until all 209 bytes are copied.
restore_maze_next:
; Book line 2362: restore_maze_next names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 inx                        ; Increase X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 2363: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #209                   ; Compare X with #209; leave X unchanged, set Z for equal and C for >=.
; Book line 2364: Compare X with literal 209 without changing X. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne restore_maze_loop      ; If Z=0 (last result nonzero, or comparison unequal), branch to restore_maze_loop.
; Book line 2365: Branch to restore_maze_loop if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 2366: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
; displayed level 1..99; later completions still refill level 99.
level: !byte 1 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2368: level names the data or instruction address. Emit 1 byte in the shown order for
; level. These are data or encoded loader bytes, not instructions to execute.
; number of remaining dots plus power pellets; reaches zero only once each is consumed.
pellets_left: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2370: pellets_left names the data or instruction address. Emit 1 byte in the shown order
; for pellets_left. These are data or encoded loader bytes, not instructions to execute.

; Immutable 209-byte starting maze. restore_maze copies it into the mutable row0..row10
; region and counts 100 pellets.
maze_template:
; Book line 2374: maze_template names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 !text "###################" ; Template row 0; kept unchanged while the live map pellets are erased.
; Book line 2375: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "#o.......#.......o#" ; Template row 1; kept unchanged while the live map pellets are erased.
; Book line 2376: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "#.###.##.#.##.###.#" ; Template row 2; kept unchanged while the live map pellets are erased.
; Book line 2377: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "#...#.........#...#" ; Template row 3; kept unchanged while the live map pellets are erased.
; Book line 2378: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "###.#.##...##.#.###" ; Template row 4; kept unchanged while the live map pellets are erased.
; Book line 2379: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "T......##E##......T" ; Template row 5; kept unchanged while the live map pellets are erased.
; Book line 2380: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "#.###.##HHH##.###.#" ; Template row 6; kept unchanged while the live map pellets are erased.
; Book line 2381: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "#......#####......#" ; Template row 7; kept unchanged while the live map pellets are erased.
; Book line 2382: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "#.###.........###.#" ; Template row 8; kept unchanged while the live map pellets are erased.
; Book line 2383: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "#o...............o#" ; Template row 9; kept unchanged while the live map pellets are erased.
; Book line 2384: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "###################" ; Template row 10; kept unchanged while the live map pellets are erased.
; Book line 2385: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.

; Non-blocking SID: voice 1 chomps, voice 2 ghost swoop, voice 3 life loss.
; Updated once per frame; no delays and no changes to movement timing.

; ============================================================================
; sound_init - SILENCE AND RESET ALL THREE SID VOICES
; Clear SID registers and software timers, set sustain/release bytes, and set master
; volume 15. The game changes pitch and gate state only; it does not use samples or a
; music player.
; ============================================================================
sound_init:
; Book line 2396: sound_init names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 2397: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 ldx #24                    ; Load X with literal 24; this also sets Z and N.
; Book line 2398: Load X with literal 24. Z records a zero value; N copies bit 7. Carry is unchanged.
; Clear SID offsets 24 down through 0, inclusive.
sound_clear:
; Book line 2400: sound_clear names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ; Write A to SID voice-1 frequency low; indexed clearing also reaches other SID registers plus the
 ; shown index/offset.
 sta $d400,x
; Book line 2403: Store A into the byte at $d400 (SID voice 1 frequency low) plus index X. The
; register and CPU flags are unchanged.
 dex                        ; Decrease X by 1 with 8-bit wrap; set Z/N for loop tests.
; Book line 2404: Decrease X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bpl sound_clear            ; If N=0 (last result has bit 7 clear), branch to sound_clear.
; Book line 2405: Branch to sound_clear if N is 0 (bit 7 clear); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta waka_timer             ; Write A to voice-1 chomp countdown in frames.
; Book line 2406: Store A into the byte at waka_timer. The register and CPU flags are unchanged.
 sta waka_phase             ; Write A to 0/1 toggle selecting rising versus falling chomp.
; Book line 2407: Store A into the byte at waka_phase. The register and CPU flags are unchanged.
 sta ghost_sound_timer      ; Write A to voice-2 eaten-ghost sound countdown in frames.
; Book line 2408: Store A into the byte at ghost_sound_timer. The register and CPU flags are
; unchanged.
 sta death_timer            ; Write A to voice-3 life-loss sound countdown in frames.
; Book line 2409: Store A into the byte at death_timer. The register and CPU flags are unchanged.
 lda #$a4                   ; Load A with literal $a4 (164 decimal); this also sets Z and N.
; Book line 2410: Load A with literal $a4 (decimal 164). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d406                  ; Write A to SID voice-1 sustain/release envelope byte.
; Book line 2411: Store A into the byte at $d406 (SID voice 1 sustain and release). The register and
; CPU flags are unchanged.
 sta $d40d                  ; Write A to SID voice-2 sustain/release envelope byte.
; Book line 2412: Store A into the byte at $d40d (SID voice 2 sustain and release). The register and
; CPU flags are unchanged.
 sta $d414                  ; Write A to SID voice-3 sustain/release envelope byte.
; Book line 2413: Store A into the byte at $d414 (SID voice 3 sustain and release). The register and
; CPU flags are unchanged.
 lda #15                    ; Load A with literal 15; this also sets Z and N.
; Book line 2414: Load A with literal 15. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d418                  ; Write A to SID master volume/filter-mode register; 15 is full master volume with filter modes off.
; Book line 2415: Store A into the byte at $d418 (SID volume and filter mode). The register and CPU
; flags are unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 2416: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
; Trigger routines preserve X and Y, including the collision-loop index.

; ============================================================================
; sound_waka - START AN ALTERNATING PELLET CHOMP ON SID VOICE 1
; Toggle waka_phase, restart a 12-frame software timer, and gate on a triangle waveform.
; sound_tick moves its pitch up or down from the table. X and Y are preserved.
; ============================================================================
sound_waka:
; Book line 2424: sound_waka names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda waka_phase             ; Read 0/1 toggle selecting rising versus falling chomp into A; Z/N reflect that byte.
; Book line 2425: Load A with the byte at waka_phase. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 eor #1                     ; Toggle the A bits selected by #1 (XOR); here this alternates the chomp phase.
; Book line 2426: Toggle A bits selected by literal 1. Save the result in A and update Z and N; carry
; is unchanged.
 sta waka_phase             ; Write A to 0/1 toggle selecting rising versus falling chomp.
; Book line 2427: Store A into the byte at waka_phase. The register and CPU flags are unchanged.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 2428: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d404                  ; Write A to SID voice-1 control: $11 triangle+gate on, zero gate off.
; Book line 2429: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
 lda #12                    ; Load A with literal 12; this also sets Z and N.
; Book line 2430: Load A with literal 12. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta waka_timer             ; Write A to voice-1 chomp countdown in frames.
; Book line 2431: Store A into the byte at waka_timer. The register and CPU flags are unchanged.
 lda #$11                   ; Load A with literal $11 (17 decimal); this also sets Z and N.
; Book line 2432: Load A with literal $11 (decimal 17). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d404                  ; Write A to SID voice-1 control: $11 triangle+gate on, zero gate off.
; Book line 2433: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 2434: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ============================================================================
; sound_ghost - START A RISING EATEN-GHOST EFFECT ON SID VOICE 2
; Restart a 24-frame timer and turn on a sawtooth waveform. Voice 1 can continue
; independently, so a pellet chomp and ghost sound can overlap. X and Y are preserved.
; ============================================================================
sound_ghost:
; Book line 2441: sound_ghost names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 2442: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d40b                  ; Write A to SID voice-2 control: $21 sawtooth+gate on, zero gate off.
; Book line 2443: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
 lda #8                     ; Load A with literal 8; this also sets Z and N.
; Book line 2444: Load A with literal 8. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d408                  ; Write A to SID voice-2 frequency high: ghost-swoop pitch.
; Book line 2445: Store A into the byte at $d408 (SID voice 2 frequency high). The register and CPU
; flags are unchanged.
 lda #24                    ; Load A with literal 24; this also sets Z and N.
; Book line 2446: Load A with literal 24. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ghost_sound_timer      ; Write A to voice-2 eaten-ghost sound countdown in frames.
; Book line 2447: Store A into the byte at ghost_sound_timer. The register and CPU flags are
; unchanged.
 lda #$21                   ; Load A with literal $21 (33 decimal); this also sets Z and N.
; Book line 2448: Load A with literal $21 (decimal 33). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d40b                  ; Write A to SID voice-2 control: $21 sawtooth+gate on, zero gate off.
; Book line 2449: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 2450: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ============================================================================
; sound_tick - ADVANCE EACH SOUND ONCE WITHOUT PAUSING THE GAME
; Countdowns control gate-off and pitch changes. Voice 1 alternates table direction, voice
; 2 rises, and voice 3 falls. No delay loop is used here. Gate-off begins the SID envelope
; release rather than instantly forcing the waveform to silence.
; ============================================================================
sound_tick:
; Book line 2458: sound_tick names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda waka_timer             ; Read voice-1 chomp countdown in frames into A; Z/N reflect that byte.
; Book line 2459: Load A with the byte at waka_timer. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq sound_tick_ghost       ; If Z=1 (last result zero, or comparison equal), branch to sound_tick_ghost.
; Book line 2460: Branch to sound_tick_ghost if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec waka_timer             ; Decrease voice-1 chomp countdown in frames by 1, wrapping within 0..255; update Z/N.
; Book line 2461: Decrease the byte at waka_timer by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
 beq sound_waka_off         ; If Z=1 (last result zero, or comparison equal), branch to sound_waka_off.
; Book line 2462: Branch to sound_waka_off if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ldx waka_timer             ; Read voice-1 chomp countdown in frames into X; Z/N reflect that byte.
; Book line 2463: Load X with the byte at waka_timer. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda waka_phase             ; Read 0/1 toggle selecting rising versus falling chomp into A; Z/N reflect that byte.
; Book line 2464: Load A with the byte at waka_phase. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq sound_waka_pitch       ; If Z=1 (last result zero, or comparison equal), branch to sound_waka_pitch.
; Book line 2465: Branch to sound_waka_pitch if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #11                    ; Load A with literal 11; this also sets Z and N.
; Book line 2466: Load A with literal 11. Z records a zero value; N copies bit 7. Carry is unchanged.
 sec                        ; Set carry before subtraction (no incoming borrow), or signal a blocked probe.
; Book line 2467: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc waka_timer             ; Subtract waka_timer and (1-C) from A; carry clear afterward means a borrow.
; Book line 2468: Subtract the byte at waka_timer and (1 minus incoming carry) from A. Update C, Z, N
; and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 tax                        ; Copy A into X; A is unchanged, Z/N follow the copied byte.
; Book line 2469: Copy A to X; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
; Write one high-frequency byte for the chomp.
sound_waka_pitch:
; Book line 2471: sound_waka_pitch names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda waka_pitch,x           ; Read an entry from waka_pitch (see the table description) into A; Z/N reflect that byte.
; Book line 2472: Load A with the byte at waka_pitch plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $d401                  ; Write A to SID voice-1 frequency high: chomp pitch.
; Book line 2473: Store A into the byte at $d401 (SID voice 1 frequency high). The register and CPU
; flags are unchanged.
 jmp sound_tick_ghost       ; Continue at sound_tick_ghost without saving a return address.
; Book line 2474: Continue execution at sound_tick_ghost without saving a return address. Registers
; and flags are unchanged by the jump itself.
; Clear the voice-1 gate so its envelope releases.
sound_waka_off:
; Book line 2476: sound_waka_off names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 2477: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d404                  ; Write A to SID voice-1 control: $11 triangle+gate on, zero gate off.
; Book line 2478: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
; Update voice 2 if the eaten-ghost timer is active.
sound_tick_ghost:
; Book line 2480: sound_tick_ghost names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda ghost_sound_timer      ; Read voice-2 eaten-ghost sound countdown in frames into A; Z/N reflect that byte.
; Book line 2481: Load A with the byte at ghost_sound_timer. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 beq sound_tick_death       ; If Z=1 (last result zero, or comparison equal), branch to sound_tick_death.
; Book line 2482: Branch to sound_tick_death if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec ghost_sound_timer      ; Decrease voice-2 eaten-ghost sound countdown in frames by 1, wrapping within 0..255; update Z/N.
; Book line 2483: Decrease the byte at ghost_sound_timer by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
 beq sound_ghost_off        ; If Z=1 (last result zero, or comparison equal), branch to sound_ghost_off.
; Book line 2484: Branch to sound_ghost_off if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #24                    ; Load A with literal 24; this also sets Z and N.
; Book line 2485: Load A with literal 24. Z records a zero value; N copies bit 7. Carry is unchanged.
 sec                        ; Set carry before subtraction (no incoming borrow), or signal a blocked probe.
; Book line 2486: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc ghost_sound_timer      ; Subtract ghost_sound_timer and (1-C) from A; carry clear afterward means a borrow.
; Book line 2487: Subtract the byte at ghost_sound_timer and (1 minus incoming carry) from A. Update
; C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 asl                        ; Shift A left by one bit (multiply by 2 modulo 256); old bit 7 goes to carry.
; Book line 2488: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 2489: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #8                     ; Add #8 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 2490: Add literal 8 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $d408                  ; Write A to SID voice-2 frequency high: ghost-swoop pitch.
; Book line 2491: Store A into the byte at $d408 (SID voice 2 frequency high). The register and CPU
; flags are unchanged.
 jmp sound_tick_death       ; Continue at sound_tick_death without saving a return address.
; Book line 2492: Continue execution at sound_tick_death without saving a return address. Registers
; and flags are unchanged by the jump itself.
; Clear the voice-2 gate.
sound_ghost_off:
; Book line 2494: sound_ghost_off names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 2495: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d40b                  ; Write A to SID voice-2 control: $21 sawtooth+gate on, zero gate off.
; Book line 2496: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
; Update voice 3 if the life-loss timer is active.
sound_tick_death:
; Book line 2498: sound_tick_death names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda death_timer            ; Read voice-3 life-loss sound countdown in frames into A; Z/N reflect that byte.
; Book line 2499: Load A with the byte at death_timer. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 beq sound_tick_done        ; If Z=1 (last result zero, or comparison equal), branch to sound_tick_done.
; Book line 2500: Branch to sound_tick_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec death_timer            ; Decrease voice-3 life-loss sound countdown in frames by 1, wrapping within 0..255; update Z/N.
; Book line 2501: Decrease the byte at death_timer by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
 beq sound_death_off        ; If Z=1 (last result zero, or comparison equal), branch to sound_death_off.
; Book line 2502: Branch to sound_death_off if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda death_timer            ; Read voice-3 life-loss sound countdown in frames into A; Z/N reflect that byte.
; Book line 2503: Load A with the byte at death_timer. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 asl                        ; Shift A left by one bit (multiply by 2 modulo 256); old bit 7 goes to carry.
; Book line 2504: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc                        ; Clear carry so the next ADC starts with no extra +1.
; Book line 2505: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #6                     ; Add #6 plus carry to A; outgoing carry carries overflow into a high byte.
; Book line 2506: Add literal 6 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $d40f                  ; Write A to SID voice-3 frequency high: descending life-loss pitch.
; Book line 2507: Store A into the byte at $d40f (SID voice 3 frequency high). The register and CPU
; flags are unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 2508: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
; Clear the voice-3 gate.
sound_death_off:
; Book line 2510: sound_death_off names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 2511: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d412                  ; Write A to SID voice-3 control: $11 triangle+gate on, zero gate off.
; Book line 2512: Store A into the byte at $d412 (SID voice 3 waveform and gate). The register and CPU
; flags are unchanged.
; Return after all active effects have had one frame of work.
sound_tick_done:
; Book line 2514: sound_tick_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 2515: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Voice-1 high-frequency-byte table. sound_tick traverses it in alternate directions; low
; frequency byte remains zero.
waka_pitch: !byte $08,$0a,$0c,$10,$14,$18,$1c,$20,$24,$28,$2c,$30 ; Data for the table/glyph described above; the CPU reads these bytes when needed.
; Book line 2519: waka_pitch names the data or instruction address. Emit 12 bytes in the shown order
; for waka_pitch. These are data or encoded loader bytes, not instructions to execute.
; voice-1 chomp countdown in frames.
waka_timer: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2521: waka_timer names the data or instruction address. Emit 1 byte in the shown order for
; waka_timer. These are data or encoded loader bytes, not instructions to execute.
; 0/1 toggle selecting rising versus falling chomp.
waka_phase: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2523: waka_phase names the data or instruction address. Emit 1 byte in the shown order for
; waka_phase. These are data or encoded loader bytes, not instructions to execute.
; voice-2 eaten-ghost sound countdown in frames.
ghost_sound_timer: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2525: ghost_sound_timer names the data or instruction address. Emit 1 byte in the shown
; order for ghost_sound_timer. These are data or encoded loader bytes, not instructions to execute.
; Voice 3: a descending life-loss slide; X/Y remain untouched.

; ============================================================================
; sound_death - START THE DESCENDING LIFE-LOSS EFFECT ON SID VOICE 3
; Stop pellet/ghost gates and their timers so the death sound has priority. Start a
; 32-frame triangle-wave pitch slide. X and Y are preserved, so adding this trigger does
; not disturb the collision loop.
; ============================================================================
sound_death:
; Book line 2534: sound_death names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #0                     ; Load A with literal 0; this also sets Z and N.
; Book line 2535: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d404                  ; Write A to SID voice-1 control: $11 triangle+gate on, zero gate off.
; Book line 2536: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
 sta $d40b                  ; Write A to SID voice-2 control: $21 sawtooth+gate on, zero gate off.
; Book line 2537: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
 sta $d412                  ; Write A to SID voice-3 control: $11 triangle+gate on, zero gate off.
; Book line 2538: Store A into the byte at $d412 (SID voice 3 waveform and gate). The register and CPU
; flags are unchanged.
 sta waka_timer             ; Write A to voice-1 chomp countdown in frames.
; Book line 2539: Store A into the byte at waka_timer. The register and CPU flags are unchanged.
 sta ghost_sound_timer      ; Write A to voice-2 eaten-ghost sound countdown in frames.
; Book line 2540: Store A into the byte at ghost_sound_timer. The register and CPU flags are
; unchanged.
 lda #32                    ; Load A with literal 32; this also sets Z and N.
; Book line 2541: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta death_timer            ; Write A to voice-3 life-loss sound countdown in frames.
; Book line 2542: Store A into the byte at death_timer. The register and CPU flags are unchanged.
 lda #$11                   ; Load A with literal $11 (17 decimal); this also sets Z and N.
; Book line 2543: Load A with literal $11 (decimal 17). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d412                  ; Write A to SID voice-3 control: $11 triangle+gate on, zero gate off.
; Book line 2544: Store A into the byte at $d412 (SID voice 3 waveform and gate). The register and CPU
; flags are unchanged.
 rts                        ; Return to the instruction after the caller's JSR (A/X/Y are not automatically restored).
; Book line 2545: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
; voice-3 life-loss sound countdown in frames.
death_timer: !byte 0 ; Initial storage value(s); labels name these mutable RAM bytes.
; Book line 2547: death_timer names the data or instruction address. Emit 1 byte in the shown order
; for death_timer. These are data or encoded loader bytes, not instructions to execute.
; End marker for code/data before sprite memory; this label emits no bytes.
sound_data_end:
; Book line 2549: sound_data_end names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.

*=$2000 ; Place sprite frame 0 on a required 64-byte boundary; font starts at $2800.
; Book line 2551: Place subsequent output at C64 address $2000; the origin directive is processed by
; ACME, not executed by the CPU.

; SPRITE FRAME 0 - RIGHT CLOSED
; Address $2000; pointer $80. 63 bitmap bytes plus one pad byte.
; Each row is 3 bytes. Ghosts interpret bit pairs; Pac-Man uses individual bits.
; sprite 0
!byte $00,$00,$00,$00,$00,$00,$00,$7e,$00,$01,$ff,$80,$03,$f3,$c0,$07 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2557: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $f3,$e0,$07,$ff,$e0,$0f,$ff,$f0,$0f,$ff,$f0,$0f,$ff,$f0,$0f,$ff ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2558: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $f0,$0f,$ff,$f0,$0f,$ff,$f0,$07,$ff,$e0,$07,$ff,$e0,$03,$ff,$c0 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2559: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $01,$ff,$80,$00,$7e,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2560: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.

; SPRITE FRAME 1 - NORMAL GHOST
; Address $2040; pointer $81. 63 bitmap bytes plus one pad byte.
; Each row is 3 bytes. Ghosts interpret bit pairs; Pac-Man uses individual bits.
; sprite 1
!byte $00,$00,$00,$00,$00,$00,$00,$28,$00,$00,$aa,$00,$02,$aa,$80,$0a ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2566: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $aa,$a0,$09,$69,$60,$09,$e9,$e0,$09,$e9,$e0,$0a,$aa,$a0,$0a,$aa ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2567: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa,$a0 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2568: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $0a,$22,$a0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2569: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.

; SPRITE FRAME 2 - NORMAL GHOST DUPLICATE
; Address $2080; pointer $82. 63 bitmap bytes plus one pad byte.
; Each row is 3 bytes. Ghosts interpret bit pairs; Pac-Man uses individual bits.
; sprite 2
!byte $00,$00,$00,$00,$00,$00,$00,$28,$00,$00,$aa,$00,$02,$aa,$80,$0a ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2575: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $aa,$a0,$09,$69,$60,$09,$e9,$e0,$09,$e9,$e0,$0a,$aa,$a0,$0a,$aa ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2576: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa,$a0 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2577: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $0a,$22,$a0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2578: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.

; SPRITE FRAME 3 - NORMAL GHOST DUPLICATE
; Address $20c0; pointer $83. 63 bitmap bytes plus one pad byte.
; Each row is 3 bytes. Ghosts interpret bit pairs; Pac-Man uses individual bits.
; sprite 3
!byte $00,$00,$00,$00,$00,$00,$00,$28,$00,$00,$aa,$00,$02,$aa,$80,$0a ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2584: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $aa,$a0,$09,$69,$60,$09,$e9,$e0,$09,$e9,$e0,$0a,$aa,$a0,$0a,$aa ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2585: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa,$a0 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2586: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $0a,$22,$a0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2587: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.

; SPRITE FRAME 4 - NORMAL GHOST DUPLICATE
; Address $2100; pointer $84. 63 bitmap bytes plus one pad byte.
; Each row is 3 bytes. Ghosts interpret bit pairs; Pac-Man uses individual bits.
; sprite 4
!byte $00,$00,$00,$00,$00,$00,$00,$28,$00,$00,$aa,$00,$02,$aa,$80,$0a ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2593: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $aa,$a0,$09,$69,$60,$09,$e9,$e0,$09,$e9,$e0,$0a,$aa,$a0,$0a,$aa ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2594: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa,$a0 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2595: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $0a,$22,$a0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2596: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.

; SPRITE FRAME 5 - RIGHT OPEN
; Address $2140; pointer $85. 63 bitmap bytes plus one pad byte.
; Each row is 3 bytes. Ghosts interpret bit pairs; Pac-Man uses individual bits.
; sprite 5
!byte $00,$00,$00,$00,$00,$00,$00,$7e,$00,$01,$ff,$80,$03,$f3,$c0,$07 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2602: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $f3,$c0,$07,$ff,$00,$0f,$fe,$00,$0f,$fc,$00,$0f,$f8,$00,$0f,$f8 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2603: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $00,$0f,$fc,$00,$0f,$fe,$00,$07,$ff,$00,$07,$ff,$c0,$03,$ff,$c0 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2604: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $01,$ff,$80,$00,$7e,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2605: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.

; SPRITE FRAME 6 - LEFT CLOSED
; Address $2180; pointer $86. 63 bitmap bytes plus one pad byte.
; Each row is 3 bytes. Ghosts interpret bit pairs; Pac-Man uses individual bits.
; sprite 6
!byte $00,$00,$00,$00,$00,$00,$00,$7e,$00,$01,$ff,$80,$03,$cf,$c0,$07 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2611: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $cf,$e0,$07,$ff,$e0,$0f,$ff,$f0,$0f,$ff,$f0,$0f,$ff,$f0,$0f,$ff ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2612: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $f0,$0f,$ff,$f0,$0f,$ff,$f0,$07,$ff,$e0,$07,$ff,$e0,$03,$ff,$c0 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2613: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $01,$ff,$80,$00,$7e,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2614: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.

; SPRITE FRAME 7 - LEFT OPEN
; Address $21c0; pointer $87. 63 bitmap bytes plus one pad byte.
; Each row is 3 bytes. Ghosts interpret bit pairs; Pac-Man uses individual bits.
; sprite 7
!byte $00,$00,$00,$00,$00,$00,$00,$7e,$00,$01,$ff,$80,$03,$cf,$c0,$03 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2620: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $cf,$e0,$00,$ff,$e0,$00,$7f,$f0,$00,$3f,$f0,$00,$1f,$f0,$00,$1f ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2621: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $f0,$00,$3f,$f0,$00,$7f,$f0,$00,$ff,$e0,$03,$ff,$e0,$03,$ff,$c0 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2622: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $01,$ff,$80,$00,$7e,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2623: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.

; SPRITE FRAME 8 - FRIGHTENED GHOST
; Address $2200; pointer $88. 63 bitmap bytes plus one pad byte.
; Each row is 3 bytes. Ghosts interpret bit pairs; Pac-Man uses individual bits.
; sprite 8
!byte $00,$00,$00,$00,$00,$00,$00,$28,$00,$00,$aa,$00,$02,$aa,$80,$0a ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2629: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $aa,$a0,$0a,$66,$a0,$0a,$66,$a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2630: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $a0,$09,$99,$a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa,$a0,$0a,$aa,$a0 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2631: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $0a,$22,$a0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2632: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.

; SPRITE FRAME 9 - RETURNING EYES
; Address $2240; pointer $89. 63 bitmap bytes plus one pad byte.
; Each row is 3 bytes. Ghosts interpret bit pairs; Pac-Man uses individual bits.
; sprite 9
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2638: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $00,$00,$01,$41,$40,$01,$c1,$c0,$01,$c1,$c0,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2639: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2640: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2641: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.

; SPRITE FRAME 10 - UP CLOSED
; Address $2280; pointer $8a. 63 bitmap bytes plus one pad byte.
; Each row is 3 bytes. Ghosts interpret bit pairs; Pac-Man uses individual bits.
; sprite 10: up
!byte $00,$00,$00,$00,$00,$00,$00,$7e,$00,$01,$ff,$80,$03,$ff,$c0,$07 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2647: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $ff,$e0,$07,$ff,$e0,$0f,$ff,$f0,$0c,$ff,$f0,$0c,$ff,$f0,$0f,$ff ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2648: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $f0,$0f,$ff,$f0,$0f,$ff,$f0,$07,$ff,$e0,$07,$ff,$e0,$03,$ff,$c0 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2649: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $01,$ff,$80,$00,$7e,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2650: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.

; SPRITE FRAME 11 - UP OPEN
; Address $22c0; pointer $8b. 63 bitmap bytes plus one pad byte.
; Each row is 3 bytes. Ghosts interpret bit pairs; Pac-Man uses individual bits.
; sprite 11: up
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$00,$c0,$07 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2656: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $00,$e0,$07,$81,$e0,$0f,$c3,$f0,$0c,$e7,$f0,$0c,$ff,$f0,$0f,$ff ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2657: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $f0,$0f,$ff,$f0,$0f,$ff,$f0,$07,$ff,$e0,$07,$ff,$e0,$03,$ff,$c0 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2658: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $01,$ff,$80,$00,$7e,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2659: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.

; SPRITE FRAME 12 - DOWN CLOSED
; Address $2300; pointer $8c. 63 bitmap bytes plus one pad byte.
; Each row is 3 bytes. Ghosts interpret bit pairs; Pac-Man uses individual bits.
; sprite 12: down
!byte $00,$00,$00,$00,$00,$00,$00,$7e,$00,$01,$ff,$80,$03,$ff,$c0,$07 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2665: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $ff,$e0,$07,$ff,$e0,$0f,$ff,$f0,$0f,$ff,$f0,$0f,$ff,$f0,$0f,$ff ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2666: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $30,$0f,$ff,$30,$0f,$ff,$f0,$07,$ff,$e0,$07,$ff,$e0,$03,$ff,$c0 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2667: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $01,$ff,$80,$00,$7e,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2668: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.

; SPRITE FRAME 13 - DOWN OPEN
; Address $2340; pointer $8d. 63 bitmap bytes plus one pad byte.
; Each row is 3 bytes. Ghosts interpret bit pairs; Pac-Man uses individual bits.
; sprite 13: down
!byte $00,$00,$00,$00,$00,$00,$00,$7e,$00,$01,$ff,$80,$03,$ff,$c0,$07 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2674: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $ff,$e0,$07,$ff,$e0,$0f,$ff,$f0,$0f,$ff,$f0,$0f,$ff,$f0,$0f,$ff ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2675: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $30,$0f,$e7,$30,$0f,$c3,$f0,$07,$81,$e0,$07,$00,$e0,$03,$00,$c0 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2676: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Sprite bitmap bytes in top-to-bottom row order; final byte of each 64-byte block is padding.
; Book line 2677: Emit 16 bytes in the shown order for sound_data_end. These are data or encoded
; loader bytes, not instructions to execute.
; End marker for all fourteen sprite frames; font memory begins later at $2800.
sprite_data_end:
; Book line 2679: sprite_data_end names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.

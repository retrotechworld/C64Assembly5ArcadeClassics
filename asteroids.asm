; ============================================================================
; ASTEROID ATTACK - BEGINNER'S COMMENTED EDITION (ACME / C64)
; ============================================================================
; WHAT: A rotating-ship, inertia-based asteroid game with SID music and effects.
; WHY: Learn how a complete 6510 game joins input, physics, graphics and sound.
; HOW TO BUILD (macOS Terminal, with ACME and VICE installed):
;   acme -f cbm -o asteroids.prg asteroids_beginner_annotated.asm
;   x64sc asteroids.prg
;
; RECOMMENDED READING ORDER:
;   Read this beginner header, then start, mainloop, input, driftship,
;   nextwave, moveasteroids (sprite selection), and sound_tick.
;   These correspond to start, main_loop, controls, physics, make_level,
;   sprite_frame, and music_tick in the requested learning approach.
;
; QUICK 6502 REFERENCE:
;   LDA load accumulator; STA store; LDX/LDY load index registers;
;   JSR call subroutine; RTS return; JMP jump; CMP compare; BEQ/BNE branch;
;   ADC add with carry; SBC subtract with borrow; AND mask bits.
;   A, X and Y are 8-bit registers. #$10 means immediate hexadecimal 16;
;   $D012 means the memory-mapped raster register. ; starts a comment.
;   Carry is significant: CLC before ADC and SEC before SBC.
;
; C64 MEMORY MAP USED HERE:
;   $0801 BASIC loader; $080D program; $0400 text screen; $D800 colours;
;   $D000+ VIC-II sprite registers; $D400+ SID audio; $DC00 joystick;
;   $D012 raster; $D010 ninth sprite X bits; $07F8 sprite pointers.
;
; NOTE: Comments explain the current implementation, not a guarantee that
; every gameplay edge case is perfect. This edition preserves game logic.
; ============================================================================
; Asteroid Attack - corrected C64 HUD digit screen codes and medium asteroid
; ACME: acme -f cbm -o asteroids.prg asteroids_decimal_centered.asm
*=$0801
; Book line 34: Place subsequent output at C64 address $0801; the origin directive is processed by
; ACME, not executed by the CPU.
!byte $0b,$08,$0a,$00,$9e
; Book line 35: Emit 5 bytes in the shown order for program. These are data or encoded loader bytes,
; not instructions to execute.
!text "2061"
; Book line 36: Emit the quoted text as literal text bytes, used here as loader or message data; these
; are not automatically screen codes.
!byte 0,0,0
; Book line 37: Emit 3 bytes in the shown order for program. These are data or encoded loader bytes,
; not instructions to execute.
*=$080d
; Book line 38: Place subsequent output at C64 address $080d; the origin directive is processed by
; ACME, not executed by the CPU.

SCREEN=$0400
; Book line 40: Define SCREEN as $0400 (screen RAM in the $0400 screen) at assembly time; this names a
; value or address and emits no storage.
COLOR=$d800
; Book line 41: Define COLOR as $d800 (colour RAM) at assembly time; this names a value or address and
; emits no storage.
SPR=$d000
; Book line 42: Define SPR as $d000 (sprite 0 X low byte) at assembly time; this names a value or
; address and emits no storage.
JOY=$dc00
; Book line 43: Define JOY as $dc00 (CIA1 port A and joystick 2) at assembly time; this names a value
; or address and emits no storage.
ptr=$fb   ; zero-page pointer required by LDA (ptr),Y
; Book line 44: Define ptr as $fb at assembly time; this names a value or address and emits no
; storage.


; ------------------------------------------------------------------
; STARTUP - WHAT / WHY / HOW
; Configures VIC-II display, sprite registers, SID, then draws the title. Why: the machine must be placed in a predictable state before gameplay.
; ------------------------------------------------------------------
start:
; Book line 51: start names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 sei
; Book line 52: Set the interrupt-disable flag to mask ordinary IRQ handling. NMI is not masked, and
; peripheral interrupt sources are not automatically cleared.
 lda #$37
; Book line 53: Load A with literal $37 (decimal 55). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $01
; Book line 54: Store A into the byte at $01 (6510 ROM and I/O banking port). The register and CPU
; flags are unchanged.
 lda #$1b
; Book line 55: Load A with literal $1b (decimal 27). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d011
; Book line 56: Store A into the byte at $d011 (VIC vertical control and raster high bit). The
; register and CPU flags are unchanged.
 lda #$00
; Book line 57: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d020
; Book line 58: Store A into the byte at $d020 (VIC border colour). The register and CPU flags are
; unchanged.
 sta $d021
; Book line 59: Store A into the byte at $d021 (VIC background colour). The register and CPU flags are
; unchanged.
 lda #$00
; Book line 60: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d015
; Book line 61: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 lda #$00
; Book line 62: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d01c
; Book line 63: Store A into the byte at $d01c (VIC sprite multicolour bits). The register and CPU
; flags are unchanged.
 sta $d017
; Book line 64: Store A into the byte at $d017 (VIC sprite height expansion). The register and CPU
; flags are unchanged.
 sta $d01d
; Book line 65: Store A into the byte at $d01d (VIC sprite width expansion). The register and CPU
; flags are unchanged.
 lda #$0f
; Book line 66: Load A with literal $0f (decimal 15). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d418
; Book line 67: Store A into the byte at $d418 (SID volume and filter mode). The register and CPU
; flags are unchanged.
 lda #$c0
; Book line 68: Load A with literal $c0 (decimal 192). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $07f8
; Book line 69: Store A into the byte at $07f8 (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
 lda #$01
; Book line 70: Load A with literal $01 (decimal 1). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d027
; Book line 71: Store A into the byte at $d027 (sprite 0 colour). The register and CPU flags are
; unchanged.
 jsr sound_init
; Book line 72: Call sound_init, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr clear
; Book line 73: Call clear, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 jsr title
; Book line 74: Call title, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.

; ------------------------------------------------------------------
; TITLE WAIT - WHAT / WHY / HOW
; Waits for joystick port 2 FIRE. The joystick bits are active-low, so a zero means pressed.
; ------------------------------------------------------------------
mainwait:
; Book line 80: mainwait names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr waitframe
; Book line 81: Call waitframe, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr sound_tick
; Book line 82: Call sound_tick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda JOY
; Book line 83: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$10
; Book line 84: Keep only bits set in both A and literal $10 (decimal 16). Save the result in A and
; update Z and N; carry is unchanged.
 bne mainwait
; Book line 85: Branch to mainwait if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jsr newgame
; Book line 86: Call newgame, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.

; ------------------------------------------------------------------
; MAIN LOOP - WHAT / WHY / HOW
; One frame at a time: synchronize, play audio, read input, update motion, move bullets/rocks, test collisions, refresh HUD, and decide whether to continue.
; ------------------------------------------------------------------
mainloop:
; Book line 92: mainloop names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr waitframe
; Book line 93: Call waitframe, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr sound_tick
; Book line 94: Call sound_tick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr input
; Book line 95: Call input, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 jsr driftship
; Book line 96: Call driftship, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda invuln
; Book line 97: Load A with the byte at invuln (invulnerability countdown). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 beq no_inv_tick
; Book line 98: Branch to no_inv_tick if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec invuln
; Book line 99: Decrease the byte at invuln (invulnerability countdown) by one with 8-bit wraparound.
; Update Z and N; carry is unchanged.
no_inv_tick:
; Book line 100: no_inv_tick names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr movebullet
; Book line 101: Call movebullet, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr moveasteroids
; Book line 102: Call moveasteroids, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr collide
; Book line 103: Call collide, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr drawhud
; Book line 104: Call drawhud, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda lives
; Book line 105: Load A with the byte at lives (remaining lives). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 beq endgame
; Book line 106: Branch to endgame if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda remaining
; Book line 107: Load A with the byte at remaining (remaining asteroid count). Z records a zero value;
; N copies bit 7. Carry is unchanged.
 bne mainloop
; Book line 108: Branch to mainloop if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jsr nextwave
; Book line 109: Call nextwave, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jmp mainloop
; Book line 110: Continue execution at mainloop without saving a return address. Registers and flags
; are unchanged by the jump itself.
endgame:
; Book line 111: endgame names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #$00
; Book line 112: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d015
; Book line 113: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 lda #$93
; Book line 114: Load A with literal $93 (decimal 147). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 jsr $ffd2
; Book line 115: Call $ffd2, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 ldx #<overtext
; Book line 116: Load X with the low address byte of overtext as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 ldy #>overtext
; Book line 117: Load Y with the high address byte of overtext as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 jsr print
; Book line 118: Call print, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 jsr drawhud
; Book line 119: Call drawhud, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
release:
; Book line 120: release names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr waitframe
; Book line 121: Call waitframe, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr sound_tick
; Book line 122: Call sound_tick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda JOY
; Book line 123: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$10
; Book line 124: Keep only bits set in both A and literal $10 (decimal 16). Save the result in A and
; update Z and N; carry is unchanged.
 beq release
; Book line 125: Branch to release if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
waitrestart:
; Book line 126: waitrestart names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr waitframe
; Book line 127: Call waitframe, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr sound_tick
; Book line 128: Call sound_tick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda JOY
; Book line 129: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$10
; Book line 130: Keep only bits set in both A and literal $10 (decimal 16). Save the result in A and
; update Z and N; carry is unchanged.
 bne waitrestart
; Book line 131: Branch to waitrestart if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp start
; Book line 132: Continue execution at start without saving a return address. Registers and flags are
; unchanged by the jump itself.


; ------------------------------------------------------------------
; FRAME PACING - WHAT / WHY / HOW
; Uses the VIC-II raster counter $D012 to synchronize updates. This version is designed around PAL timing.
; ------------------------------------------------------------------
waitframe:
; Book line 139: waitframe names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda $d012
; Book line 140: Load A with the byte at $d012 (VIC raster counter or IRQ compare). Z records a zero
; value; N copies bit 7. Carry is unchanged.
wf1: cmp $d012
; Book line 141: wf1 names the data or instruction address. Compare A with the byte at $d012 (VIC
; raster counter or IRQ compare) without changing A. Z means equal, C means unsigned greater or equal,
; and N is the subtraction result bit 7.
 beq wf1
; Book line 142: Branch to wf1 if Z is 1 (zero or equal); otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
wf2: lda $d012
; Book line 143: wf2 names the data or instruction address. Load A with the byte at $d012 (VIC raster
; counter or IRQ compare). Z records a zero value; N copies bit 7. Carry is unchanged.
 cmp #$fa
; Book line 144: Compare A with literal $fa (decimal 250) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 bne wf2
; Book line 145: Branch to wf2 if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts
; Book line 146: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ------------------------------------------------------------------
; CLEAR SCREEN - WHAT / WHY / HOW
; Writes spaces into the C64 screen memory at $0400 and sets colours.
; ------------------------------------------------------------------
clear:
; Book line 153: clear names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #$20
; Book line 154: Load A with literal $20 (decimal 32). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 ldx #$00
; Book line 155: Load X with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry is
; unchanged.
cl1: sta SCREEN,x
; Book line 156: cl1 names the data or instruction address. Store A into the byte at SCREEN (screen
; RAM in the $0400 screen) plus index X. The register and CPU flags are unchanged.
 sta SCREEN+$100,x
; Book line 157: Store A into the byte at SCREEN+$100 plus index X. The register and CPU flags are
; unchanged.
 sta SCREEN+$200,x
; Book line 158: Store A into the byte at SCREEN+$200 plus index X. The register and CPU flags are
; unchanged.
 sta SCREEN+$300,x
; Book line 159: Store A into the byte at SCREEN+$300 plus index X. The register and CPU flags are
; unchanged.
 inx
; Book line 160: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne cl1
; Book line 161: Branch to cl1 if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts
; Book line 162: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ------------------------------------------------------------------
; TEXT PRINTING - WHAT / WHY / HOW
; Uses a zero-page pointer and indexed-indirect addressing to copy a zero-terminated message to screen memory.
; ------------------------------------------------------------------
print:
; Book line 169: print names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 stx ptr
; Book line 170: Store X into the byte at ptr (pointer storage). The register and CPU flags are
; unchanged.
 sty ptr+1
; Book line 171: Store Y into the byte at ptr+1. The register and CPU flags are unchanged.
 ldy #0
; Book line 172: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
pr1: lda (ptr),y
; Book line 173: pr1 names the data or instruction address. Load A with the byte at the address in
; zero-page pair ptr and its next byte, plus Y. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq prdone
; Book line 174: Branch to prdone if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jsr $ffd2
; Book line 175: Call $ffd2, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 iny
; Book line 176: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne pr1
; Book line 177: Branch to pr1 if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
prdone: rts
; Book line 178: prdone names the data or instruction address. Pull the saved subroutine return
; address from the stack and resume after its JSR. Do not use this as an interrupt return.

title:
; Book line 180: title names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #$93
; Book line 181: Load A with literal $93 (decimal 147). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 jsr $ffd2
; Book line 182: Call $ffd2, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 ldx #<titletext
; Book line 183: Load X with the low address byte of titletext as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 ldy #>titletext
; Book line 184: Load Y with the high address byte of titletext as an immediate value. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 jsr print
; Book line 185: Call print, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 rts
; Book line 186: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ------------------------------------------------------------------
; RESET GAME - WHAT / WHY / HOW
; Initializes lives, ship state, scores and asteroid wave; high score is kept in RAM.
; ------------------------------------------------------------------
newgame:
; Book line 193: newgame names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #0
; Book line 194: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta score
; Book line 195: Store A into the byte at score. The register and CPU flags are unchanged.
 sta score+1
; Book line 196: Store A into the byte at score+1. The register and CPU flags are unchanged.
 sta wave
; Book line 197: Store A into the byte at wave. The register and CPU flags are unchanged.
 lda #3
; Book line 198: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta lives
; Book line 199: Store A into the byte at lives (remaining lives). The register and CPU flags are
; unchanged.
 lda #160
; Book line 200: Load A with literal 160. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipx
; Book line 201: Store A into the byte at shipx (ship X low byte). The register and CPU flags are
; unchanged.
 lda #0
; Book line 202: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipxh
; Book line 203: Store A into the byte at shipxh (ship X high byte). The register and CPU flags are
; unchanged.
 sta angle
; Book line 204: Store A into the byte at angle (ship orientation index). The register and CPU flags
; are unchanged.
 sta thrusttick
; Book line 205: Store A into the byte at thrusttick. The register and CPU flags are unchanged.
 sta rotclock
; Book line 206: Store A into the byte at rotclock. The register and CPU flags are unchanged.
 sta velx
; Book line 207: Store A into the byte at velx (horizontal velocity). The register and CPU flags are
; unchanged.
 sta vely
; Book line 208: Store A into the byte at vely (vertical velocity). The register and CPU flags are
; unchanged.
 sta fracx
; Book line 209: Store A into the byte at fracx (horizontal fractional position). The register and CPU
; flags are unchanged.
 sta fracy
; Book line 210: Store A into the byte at fracy (vertical fractional position). The register and CPU
; flags are unchanged.
 sta dragtick
; Book line 211: Store A into the byte at dragtick. The register and CPU flags are unchanged.
 lda #90
; Book line 212: Load A with literal 90. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta invuln
; Book line 213: Store A into the byte at invuln (invulnerability countdown). The register and CPU
; flags are unchanged.
 lda #120
; Book line 214: Load A with literal 120. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipy
; Book line 215: Store A into the byte at shipy (ship Y). The register and CPU flags are unchanged.
 lda #0
; Book line 216: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta bulletactive
; Book line 217: Store A into the byte at bulletactive. The register and CPU flags are unchanged.
 sta cooldown
; Book line 218: Store A into the byte at cooldown. The register and CPU flags are unchanged.
 jsr clear
; Book line 219: Call clear, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 jsr nextwave
; Book line 220: Call nextwave, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 rts
; Book line 221: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ------------------------------------------------------------------
; MAKE LEVEL / NEXT WAVE - WHAT / WHY / HOW
; Creates a new group of asteroids. Read this as the equivalent of make_level in the suggested learning path.
; ------------------------------------------------------------------
nextwave:
; Book line 228: nextwave names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 inc wave
; Book line 229: Increase the byte at wave by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 lda #4
; Book line 230: Load A with literal 4. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta remaining
; Book line 231: Store A into the byte at remaining (remaining asteroid count). The register and CPU
; flags are unchanged.
 ldx #0
; Book line 232: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
nw1:
; Book line 233: nw1 names this assembled address; it emits no bytes and provides a jump, call or data
; reference target.
 lda #1
; Book line 234: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta active,x
; Book line 235: Store A into the byte at active (object activity table) plus index X. The register
; and CPU flags are unchanged.
 lda #2
; Book line 236: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta sizes,x
; Book line 237: Store A into the byte at sizes (asteroid size table) plus index X. The register and
; CPU flags are unchanged.
 lda initx,x
; Book line 238: Load A with the byte at initx plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta ax,x
; Book line 239: Store A into the byte at ax plus index X. The register and CPU flags are unchanged.
 lda #0
; Book line 240: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta axh,x
; Book line 241: Store A into the byte at axh plus index X. The register and CPU flags are unchanged.
 lda inity,x
; Book line 242: Load A with the byte at inity plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta ay,x
; Book line 243: Store A into the byte at ay plus index X. The register and CPU flags are unchanged.
 lda initdx,x
; Book line 244: Load A with the byte at initdx plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta dx,x
; Book line 245: Store A into the byte at dx plus index X. The register and CPU flags are unchanged.
 lda initdy,x
; Book line 246: Load A with the byte at initdy plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta dy,x
; Book line 247: Store A into the byte at dy plus index X. The register and CPU flags are unchanged.
 inx
; Book line 248: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #4
; Book line 249: Compare X with literal 4 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne nw1
; Book line 250: Branch to nw1 if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #$3d
; Book line 251: Load A with literal $3d (decimal 61). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d015
; Book line 252: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 ldx #4
; Book line 253: Load X with literal 4. Z records a zero value; N copies bit 7. Carry is unchanged.
nwclear:
; Book line 254: nwclear names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #0
; Book line 255: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta active,x
; Book line 256: Store A into the byte at active (object activity table) plus index X. The register
; and CPU flags are unchanged.
 inx
; Book line 257: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #6
; Book line 258: Compare X with literal 6 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne nwclear
; Book line 259: Branch to nwclear if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #$00
; Book line 260: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d017
; Book line 261: Store A into the byte at $d017 (VIC sprite height expansion). The register and CPU
; flags are unchanged.
 lda #$1c
; Book line 262: Load A with literal $1c (decimal 28). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d01d
; Book line 263: Store A into the byte at $d01d (VIC sprite width expansion). The register and CPU
; flags are unchanged.
 lda #$c0
; Book line 264: Load A with literal $c0 (decimal 192). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $07f8
; Book line 265: Store A into the byte at $07f8 (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
 lda #$c8
; Book line 266: Load A with literal $c8 (decimal 200). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $07f9
; Book line 267: Store A into the byte at $07f9 (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
 ldx #0
; Book line 268: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
np:
; Book line 269: np names this assembled address; it emits no bytes and provides a jump, call or data
; reference target.
 lda #$c9
; Book line 270: Load A with literal $c9 (decimal 201). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $07fa,x
; Book line 271: Store A into the byte at $07fa (sprite pointer table in the $0400 screen) plus index
; X. The register and CPU flags are unchanged.
 lda #$0e
; Book line 272: Load A with literal $0e (decimal 14). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d029,x
; Book line 273: Store A into the byte at $d029 (sprite 2 colour) plus index X. The register and CPU
; flags are unchanged.
 inx
; Book line 274: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #6
; Book line 275: Compare X with literal 6 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne np
; Book line 276: Branch to np if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #$07
; Book line 277: Load A with literal $07 (decimal 7). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d028
; Book line 278: Store A into the byte at $d028 (sprite 1 colour). The register and CPU flags are
; unchanged.
 rts
; Book line 279: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ------------------------------------------------------------------
; CONTROLS AND THRUST - WHAT / WHY / HOW
; Reads joystick port 2 via $DC00. Left/right adjust angle, up adds thrust, fire starts a shot.
; ------------------------------------------------------------------
input:
; Book line 286: input names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ; Rotate one step every 6 frames while left/right is held.
 lda rotclock
; Book line 288: Load A with the byte at rotclock. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq rotation_ready
; Book line 289: Branch to rotation_ready if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec rotclock
; Book line 290: Decrease the byte at rotclock by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 jmp ithrust
; Book line 291: Continue execution at ithrust without saving a return address. Registers and flags
; are unchanged by the jump itself.
rotation_ready:
; Book line 292: rotation_ready names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda JOY
; Book line 293: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$04
; Book line 294: Keep only bits set in both A and literal $04 (decimal 4). Save the result in A and
; update Z and N; carry is unchanged.
 bne check_right
; Book line 295: Branch to check_right if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec angle
; Book line 296: Decrease the byte at angle (ship orientation index) by one with 8-bit wraparound.
; Update Z and N; carry is unchanged.
 lda angle
; Book line 297: Load A with the byte at angle (ship orientation index). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #7
; Book line 298: Keep only bits set in both A and literal 7. Save the result in A and update Z and N;
; carry is unchanged.
 sta angle
; Book line 299: Store A into the byte at angle (ship orientation index). The register and CPU flags
; are unchanged.
 lda #5
; Book line 300: Load A with literal 5. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta rotclock
; Book line 301: Store A into the byte at rotclock. The register and CPU flags are unchanged.
 jmp ithrust
; Book line 302: Continue execution at ithrust without saving a return address. Registers and flags
; are unchanged by the jump itself.
check_right:
; Book line 303: check_right names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda JOY
; Book line 304: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$08
; Book line 305: Keep only bits set in both A and literal $08 (decimal 8). Save the result in A and
; update Z and N; carry is unchanged.
 bne ithrust
; Book line 306: Branch to ithrust if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inc angle
; Book line 307: Increase the byte at angle (ship orientation index) by one with 8-bit wraparound.
; Update Z and N; carry is unchanged.
 lda angle
; Book line 308: Load A with the byte at angle (ship orientation index). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #7
; Book line 309: Keep only bits set in both A and literal 7. Save the result in A and update Z and N;
; carry is unchanged.
 sta angle
; Book line 310: Store A into the byte at angle (ship orientation index). The register and CPU flags
; are unchanged.
 lda #5
; Book line 311: Load A with literal 5. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta rotclock
; Book line 312: Store A into the byte at rotclock. The register and CPU flags are unchanged.
ithrust:
; Book line 313: ithrust names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda JOY
; Book line 314: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$01
; Book line 315: Keep only bits set in both A and literal $01 (decimal 1). Save the result in A and
; update Z and N; carry is unchanged.
 bne thrust_done
; Book line 316: Branch to thrust_done if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inc thrusttick
; Book line 317: Increase the byte at thrusttick by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
 lda thrusttick
; Book line 318: Load A with the byte at thrusttick. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #3
; Book line 319: Keep only bits set in both A and literal 3. Save the result in A and update Z and N;
; carry is unchanged.
 bne thrust_done
; Book line 320: Branch to thrust_done if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ldy angle
; Book line 321: Load Y with the byte at angle (ship orientation index). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 lda velx
; Book line 322: Load A with the byte at velx (horizontal velocity). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 clc
; Book line 323: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc accelx,y
; Book line 324: Add the byte at accelx plus index Y and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 jsr clampvelocity
; Book line 325: Call clampvelocity, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 sta velx
; Book line 326: Store A into the byte at velx (horizontal velocity). The register and CPU flags are
; unchanged.
 lda vely
; Book line 327: Load A with the byte at vely (vertical velocity). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 clc
; Book line 328: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc accely,y
; Book line 329: Add the byte at accely plus index Y and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 jsr clampvelocity
; Book line 330: Call clampvelocity, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 sta vely
; Book line 331: Store A into the byte at vely (vertical velocity). The register and CPU flags are
; unchanged.
thrust_done:
; Book line 332: thrust_done names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
iposition:
; Book line 333: iposition names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jmp ifire
; Book line 334: Continue execution at ifire without saving a return address. Registers and flags are
; unchanged by the jump itself.

; Apply velocity in quarter-pixels, including fractional movement.
; Signed velocities are limited to +/- 20 (5 pixels/frame).

; ------------------------------------------------------------------
; PHYSICS: INERTIA - WHAT / WHY / HOW
; Uses stored velocity to move the ship after thrust stops; applies gradual drag and wraps the playfield.
; ------------------------------------------------------------------
driftship:
; Book line 343: driftship names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 inc dragtick
; Book line 344: Increase the byte at dragtick by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 lda dragtick
; Book line 345: Load A with the byte at dragtick. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #7
; Book line 346: Keep only bits set in both A and literal 7. Save the result in A and update Z and N;
; carry is unchanged.
 bne drift_move
; Book line 347: Branch to drift_move if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda velx
; Book line 348: Load A with the byte at velx (horizontal velocity). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 beq drag_y
; Book line 349: Branch to drag_y if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 bmi drag_x_negative
; Book line 350: Branch to drag_x_negative if N is 1 (bit 7 set); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec velx
; Book line 351: Decrease the byte at velx (horizontal velocity) by one with 8-bit wraparound. Update
; Z and N; carry is unchanged.
 jmp drag_y
; Book line 352: Continue execution at drag_y without saving a return address. Registers and flags are
; unchanged by the jump itself.
drag_x_negative:
; Book line 353: drag_x_negative names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 inc velx
; Book line 354: Increase the byte at velx (horizontal velocity) by one with 8-bit wraparound. Update
; Z and N; carry is unchanged.
drag_y:
; Book line 355: drag_y names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda vely
; Book line 356: Load A with the byte at vely (vertical velocity). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 beq drift_move
; Book line 357: Branch to drift_move if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 bmi drag_y_negative
; Book line 358: Branch to drag_y_negative if N is 1 (bit 7 set); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec vely
; Book line 359: Decrease the byte at vely (vertical velocity) by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
 jmp drift_move
; Book line 360: Continue execution at drift_move without saving a return address. Registers and flags
; are unchanged by the jump itself.
drag_y_negative:
; Book line 361: drag_y_negative names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 inc vely
; Book line 362: Increase the byte at vely (vertical velocity) by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
drift_move:
; Book line 363: drift_move names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda velx
; Book line 364: Load A with the byte at velx (horizontal velocity). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 clc
; Book line 365: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc fracx
; Book line 366: Add the byte at fracx (horizontal fractional position) and incoming carry to A.
; Update C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 pha
; Book line 367: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 and #3
; Book line 368: Keep only bits set in both A and literal 3. Save the result in A and update Z and N;
; carry is unchanged.
 sta fracx
; Book line 369: Store A into the byte at fracx (horizontal fractional position). The register and CPU
; flags are unchanged.
 pla
; Book line 370: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 jsr quartershift
; Book line 371: Call quartershift, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 pha
; Book line 372: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 clc
; Book line 373: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc shipx
; Book line 374: Add the byte at shipx (ship X low byte) and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta shipx
; Book line 375: Store A into the byte at shipx (ship X low byte). The register and CPU flags are
; unchanged.
 pla
; Book line 376: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 bmi drift_x_negative
; Book line 377: Branch to drift_x_negative if N is 1 (bit 7 set); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda shipxh
; Book line 378: Load A with the byte at shipxh (ship X high byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 adc #0
; Book line 379: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta shipxh
; Book line 380: Store A into the byte at shipxh (ship X high byte). The register and CPU flags are
; unchanged.
 jmp drift_y
; Book line 381: Continue execution at drift_y without saving a return address. Registers and flags
; are unchanged by the jump itself.
drift_x_negative:
; Book line 382: drift_x_negative names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda shipxh
; Book line 383: Load A with the byte at shipxh (ship X high byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 adc #$ff
; Book line 384: Add literal $ff (decimal 255) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta shipxh
; Book line 385: Store A into the byte at shipxh (ship X high byte). The register and CPU flags are
; unchanged.
drift_y:
; Book line 386: drift_y names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda vely
; Book line 387: Load A with the byte at vely (vertical velocity). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 clc
; Book line 388: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc fracy
; Book line 389: Add the byte at fracy (vertical fractional position) and incoming carry to A. Update
; C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 pha
; Book line 390: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 and #3
; Book line 391: Keep only bits set in both A and literal 3. Save the result in A and update Z and N;
; carry is unchanged.
 sta fracy
; Book line 392: Store A into the byte at fracy (vertical fractional position). The register and CPU
; flags are unchanged.
 pla
; Book line 393: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 jsr quartershift
; Book line 394: Call quartershift, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 clc
; Book line 395: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc shipy
; Book line 396: Add the byte at shipy (ship Y) and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta shipy
; Book line 397: Store A into the byte at shipy (ship Y). The register and CPU flags are unchanged.
 ; Wrap at the left edge and at X=344.
 lda shipxh
; Book line 399: Load A with the byte at shipxh (ship X high byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 bmi ship_wrap_left
; Book line 400: Branch to ship_wrap_left if N is 1 (bit 7 set); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 beq ship_low_page
; Book line 401: Branch to ship_low_page if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda shipx
; Book line 402: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 cmp #88
; Book line 403: Compare A with literal 88 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc iycheck
; Book line 404: Branch to iycheck if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #24
; Book line 405: Load A with literal 24. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipx
; Book line 406: Store A into the byte at shipx (ship X low byte). The register and CPU flags are
; unchanged.
 lda #0
; Book line 407: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipxh
; Book line 408: Store A into the byte at shipxh (ship X high byte). The register and CPU flags are
; unchanged.
 jmp iycheck
; Book line 409: Continue execution at iycheck without saving a return address. Registers and flags
; are unchanged by the jump itself.
ship_low_page:
; Book line 410: ship_low_page names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda shipx
; Book line 411: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 cmp #24
; Book line 412: Compare A with literal 24 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcs iycheck
; Book line 413: Branch to iycheck if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
ship_wrap_left:
; Book line 414: ship_wrap_left names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #87
; Book line 415: Load A with literal 87. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipx
; Book line 416: Store A into the byte at shipx (ship X low byte). The register and CPU flags are
; unchanged.
 lda #1
; Book line 417: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipxh
; Book line 418: Store A into the byte at shipxh (ship X high byte). The register and CPU flags are
; unchanged.
iycheck:
; Book line 419: iycheck names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda shipy
; Book line 420: Load A with the byte at shipy (ship Y). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 cmp #55
; Book line 421: Compare A with literal 55 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcs iyhigh
; Book line 422: Branch to iyhigh if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #225
; Book line 423: Load A with literal 225. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipy
; Book line 424: Store A into the byte at shipy (ship Y). The register and CPU flags are unchanged.
iyhigh:
; Book line 425: iyhigh names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 cmp #230
; Book line 426: Compare A with literal 230 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc idraw
; Book line 427: Branch to idraw if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #56
; Book line 428: Load A with literal 56. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipy
; Book line 429: Store A into the byte at shipy (ship Y). The register and CPU flags are unchanged.
idraw:
; Book line 430: idraw names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda shipx
; Book line 431: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta $d000
; Book line 432: Store A into the byte at $d000 (sprite 0 X low byte). The register and CPU flags are
; unchanged.
 lda $d010
; Book line 433: Load A with the byte at $d010 (VIC sprite X high bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$fe
; Book line 434: Keep only bits set in both A and literal $fe (decimal 254). Save the result in A and
; update Z and N; carry is unchanged.
 ora shipxh
; Book line 435: Set A bits present in either A or the byte at shipxh (ship X high byte). Save the
; result in A and update Z and N; carry is unchanged.
 sta $d010
; Book line 436: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
 lda shipy
; Book line 437: Load A with the byte at shipy (ship Y). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d001
; Book line 438: Store A into the byte at $d001 (sprite 0 Y coordinate). The register and CPU flags
; are unchanged.
 lda angle
; Book line 439: Load A with the byte at angle (ship orientation index). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 clc
; Book line 440: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$c0
; Book line 441: Add literal $c0 (decimal 192) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $07f8
; Book line 442: Store A into the byte at $07f8 (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
 rts
; Book line 443: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

ifire:
; Book line 445: ifire names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda cooldown
; Book line 446: Load A with the byte at cooldown. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq fire_ready
; Book line 447: Branch to fire_ready if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec cooldown
; Book line 448: Decrease the byte at cooldown by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
fire_ready:
; Book line 449: fire_ready names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda JOY
; Book line 450: Load A with the byte at JOY (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$10
; Book line 451: Keep only bits set in both A and literal $10 (decimal 16). Save the result in A and
; update Z and N; carry is unchanged.
 bne inputdone
; Book line 452: Branch to inputdone if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda bulletactive
; Book line 453: Load A with the byte at bulletactive. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne inputdone
; Book line 454: Branch to inputdone if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda cooldown
; Book line 455: Load A with the byte at cooldown. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bne inputdone
; Book line 456: Branch to inputdone if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #1
; Book line 457: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta bulletactive
; Book line 458: Store A into the byte at bulletactive. The register and CPU flags are unchanged.
 jsr sound_fire
; Book line 459: Call sound_fire, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda #10
; Book line 460: Load A with literal 10. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta cooldown
; Book line 461: Store A into the byte at cooldown. The register and CPU flags are unchanged.
 ldy angle
; Book line 462: Load Y with the byte at angle (ship orientation index). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ; Bullet velocity follows the ship orientation and inherits drift.
 lda velx
; Book line 464: Load A with the byte at velx (horizontal velocity). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 jsr quartershift
; Book line 465: Call quartershift, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 clc
; Book line 466: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc shotx,y
; Book line 467: Add the byte at shotx plus index Y and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta bulletdx
; Book line 468: Store A into the byte at bulletdx. The register and CPU flags are unchanged.
 lda vely
; Book line 469: Load A with the byte at vely (vertical velocity). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 jsr quartershift
; Book line 470: Call quartershift, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 clc
; Book line 471: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc shoty,y
; Book line 472: Add the byte at shoty plus index Y and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta bulletdy
; Book line 473: Store A into the byte at bulletdy. The register and CPU flags are unchanged.
 ; Position the shot near the ship nose, not its centre.
 ; Bullet sprite artwork is centred at (12,10), like the ship.
 ; Store sprite origin so its visible pixels emerge from the nose.
 lda shipx
; Book line 477: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta bulletx
; Book line 478: Store A into the byte at bulletx. The register and CPU flags are unchanged.
 lda shipxh
; Book line 479: Load A with the byte at shipxh (ship X high byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 adc #0
; Book line 480: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta bulletxh
; Book line 481: Store A into the byte at bulletxh. The register and CPU flags are unchanged.
 lda bulletx
; Book line 482: Load A with the byte at bulletx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc
; Book line 483: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc nosex,y
; Book line 484: Add the byte at nosex plus index Y and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta bulletx
; Book line 485: Store A into the byte at bulletx. The register and CPU flags are unchanged.
 lda nosex,y
; Book line 486: Load A with the byte at nosex plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 bmi nose_negative
; Book line 487: Branch to nose_negative if N is 1 (bit 7 set); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda bulletxh
; Book line 488: Load A with the byte at bulletxh. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 adc #0
; Book line 489: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta bulletxh
; Book line 490: Store A into the byte at bulletxh. The register and CPU flags are unchanged.
 jmp nose_y
; Book line 491: Continue execution at nose_y without saving a return address. Registers and flags are
; unchanged by the jump itself.
nose_negative:
; Book line 492: nose_negative names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda bulletxh
; Book line 493: Load A with the byte at bulletxh. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 adc #$ff
; Book line 494: Add literal $ff (decimal 255) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta bulletxh
; Book line 495: Store A into the byte at bulletxh. The register and CPU flags are unchanged.
nose_y:
; Book line 496: nose_y names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda shipy
; Book line 497: Load A with the byte at shipy (ship Y). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 clc
; Book line 498: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc nosey,y
; Book line 499: Add the byte at nosey plus index Y and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta bullety
; Book line 500: Store A into the byte at bullety. The register and CPU flags are unchanged.
inputdone:
; Book line 501: inputdone names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 rts
; Book line 502: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ------------------------------------------------------------------
; PHYSICS: SPEED LIMIT - WHAT / WHY / HOW
; Caps signed velocity to avoid uncontrollable motion.
; ------------------------------------------------------------------
clampvelocity:
; Book line 509: clampvelocity names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ; Signed range -8..8 quarter-pixels per frame.
 cmp #9
; Book line 511: Compare A with literal 9 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc cv_done
; Book line 512: Branch to cv_done if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 cmp #$f8
; Book line 513: Compare A with literal $f8 (decimal 248) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 bcs cv_done
; Book line 514: Branch to cv_done if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 cmp #$80
; Book line 515: Compare A with literal $80 (decimal 128) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 bcc cv_positive
; Book line 516: Branch to cv_positive if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #$f8
; Book line 517: Load A with literal $f8 (decimal 248). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 rts
; Book line 518: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
cv_positive:
; Book line 519: cv_positive names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #8
; Book line 520: Load A with literal 8. Z records a zero value; N copies bit 7. Carry is unchanged.
cv_done:
; Book line 521: cv_done names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 rts
; Book line 522: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ------------------------------------------------------------------
; FIXED-POINT ARITHMETIC - WHAT / WHY / HOW
; Converts quarter-pixel velocity units into screen-coordinate steps.
; ------------------------------------------------------------------
quartershift:
; Book line 529: quartershift names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ; Arithmetic signed divide by four (floor), A preserved as signed.
 cmp #$80
; Book line 531: Compare A with literal $80 (decimal 128) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 ror
; Book line 532: Rotate A right through carry: old C enters bit 7 and old bit 0 becomes C. Update Z
; and N from the result.
 cmp #$80
; Book line 533: Compare A with literal $80 (decimal 128) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 ror
; Book line 534: Rotate A right through carry: old C enters bit 7 and old bit 0 becomes C. Update Z
; and N from the result.
 rts
; Book line 535: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ------------------------------------------------------------------
; BULLETS - WHAT / WHY / HOW
; Updates bullet coordinates and sprite placement; handles screen boundaries.
; ------------------------------------------------------------------
movebullet:
; Book line 542: movebullet names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda bulletactive
; Book line 543: Load A with the byte at bulletactive. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 beq bullet_off
; Book line 544: Branch to bullet_off if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda bulletx
; Book line 545: Load A with the byte at bulletx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc
; Book line 546: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc bulletdx
; Book line 547: Add the byte at bulletdx and incoming carry to A. Update C, Z, N and V according to
; CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta bulletx
; Book line 548: Store A into the byte at bulletx. The register and CPU flags are unchanged.
 lda bulletdx
; Book line 549: Load A with the byte at bulletdx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bmi bullet_negative
; Book line 550: Branch to bullet_negative if N is 1 (bit 7 set); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda bulletxh
; Book line 551: Load A with the byte at bulletxh. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 adc #0
; Book line 552: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta bulletxh
; Book line 553: Store A into the byte at bulletxh. The register and CPU flags are unchanged.
 jmp bullet_bounds
; Book line 554: Continue execution at bullet_bounds without saving a return address. Registers and
; flags are unchanged by the jump itself.
bullet_negative:
; Book line 555: bullet_negative names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda bulletxh
; Book line 556: Load A with the byte at bulletxh. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 adc #$ff
; Book line 557: Add literal $ff (decimal 255) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta bulletxh
; Book line 558: Store A into the byte at bulletxh. The register and CPU flags are unchanged.
bullet_bounds:
; Book line 559: bullet_bounds names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda bulletxh
; Book line 560: Load A with the byte at bulletxh. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bmi bullet_kill
; Book line 561: Branch to bullet_kill if N is 1 (bit 7 set); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 beq bullet_low
; Book line 562: Branch to bullet_low if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda bulletx
; Book line 563: Load A with the byte at bulletx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #88
; Book line 564: Compare A with literal 88 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcs bullet_kill
; Book line 565: Branch to bullet_kill if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 jmp bullet_y
; Book line 566: Continue execution at bullet_y without saving a return address. Registers and flags
; are unchanged by the jump itself.
bullet_low:
; Book line 567: bullet_low names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda bulletx
; Book line 568: Load A with the byte at bulletx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #24
; Book line 569: Compare A with literal 24 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc bullet_kill
; Book line 570: Branch to bullet_kill if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
bullet_y:
; Book line 571: bullet_y names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda bullety
; Book line 572: Load A with the byte at bullety. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc
; Book line 573: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc bulletdy
; Book line 574: Add the byte at bulletdy and incoming carry to A. Update C, Z, N and V according to
; CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta bullety
; Book line 575: Store A into the byte at bullety. The register and CPU flags are unchanged.
 cmp #52
; Book line 576: Compare A with literal 52 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc bullet_kill
; Book line 577: Branch to bullet_kill if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 cmp #230
; Book line 578: Compare A with literal 230 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc bullet_on
; Book line 579: Branch to bullet_on if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
bullet_kill:
; Book line 580: bullet_kill names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #0
; Book line 581: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta bulletactive
; Book line 582: Store A into the byte at bulletactive. The register and CPU flags are unchanged.
bullet_off:
; Book line 583: bullet_off names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda $d015
; Book line 584: Load A with the byte at $d015 (VIC sprite enable bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$fd
; Book line 585: Keep only bits set in both A and literal $fd (decimal 253). Save the result in A and
; update Z and N; carry is unchanged.
 sta $d015
; Book line 586: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 rts
; Book line 587: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
bullet_on:
; Book line 588: bullet_on names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda bulletx
; Book line 589: Load A with the byte at bulletx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d002
; Book line 590: Store A into the byte at $d002 (sprite 1 X low byte). The register and CPU flags are
; unchanged.
 lda $d010
; Book line 591: Load A with the byte at $d010 (VIC sprite X high bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$fd
; Book line 592: Keep only bits set in both A and literal $fd (decimal 253). Save the result in A and
; update Z and N; carry is unchanged.
 ldx bulletxh
; Book line 593: Load X with the byte at bulletxh. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq bullet_msb_done
; Book line 594: Branch to bullet_msb_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ora #2
; Book line 595: Set A bits present in either A or literal 2. Save the result in A and update Z and N;
; carry is unchanged.
bullet_msb_done:
; Book line 596: bullet_msb_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 sta $d010
; Book line 597: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
 lda bullety
; Book line 598: Load A with the byte at bullety. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d003
; Book line 599: Store A into the byte at $d003 (sprite 1 Y coordinate). The register and CPU flags
; are unchanged.
 lda $d015
; Book line 600: Load A with the byte at $d015 (VIC sprite enable bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ora #2
; Book line 601: Set A bits present in either A or literal 2. Save the result in A and update Z and N;
; carry is unchanged.
 sta $d015
; Book line 602: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 rts
; Book line 603: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ------------------------------------------------------------------
; ASTEROID MOVEMENT AND SPRITES - WHAT / WHY / HOW
; Moves active rocks, chooses sprite pointers and expansion based on size, and updates VIC-II sprite positions.
; ------------------------------------------------------------------
moveasteroids:
; Book line 610: moveasteroids names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ldx #0
; Book line 611: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
ma_loop:
; Book line 612: ma_loop names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda active,x
; Book line 613: Load A with the byte at active (object activity table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 bne ma_visible
; Book line 614: Branch to ma_visible if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp ma_hidden
; Book line 615: Continue execution at ma_hidden without saving a return address. Registers and flags
; are unchanged by the jump itself.
ma_visible:
; Book line 616: ma_visible names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda ax,x
; Book line 617: Load A with the byte at ax plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 clc
; Book line 618: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc dx,x
; Book line 619: Add the byte at dx plus index X and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ax,x
; Book line 620: Store A into the byte at ax plus index X. The register and CPU flags are unchanged.
 lda dx,x
; Book line 621: Load A with the byte at dx plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 bmi rock_negative
; Book line 622: Branch to rock_negative if N is 1 (bit 7 set); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda axh,x
; Book line 623: Load A with the byte at axh plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 adc #0
; Book line 624: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta axh,x
; Book line 625: Store A into the byte at axh plus index X. The register and CPU flags are unchanged.
 jmp rock_bounds
; Book line 626: Continue execution at rock_bounds without saving a return address. Registers and
; flags are unchanged by the jump itself.
rock_negative:
; Book line 627: rock_negative names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda axh,x
; Book line 628: Load A with the byte at axh plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 adc #$ff
; Book line 629: Add literal $ff (decimal 255) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta axh,x
; Book line 630: Store A into the byte at axh plus index X. The register and CPU flags are unchanged.
rock_bounds:
; Book line 631: rock_bounds names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda axh,x
; Book line 632: Load A with the byte at axh plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 bmi rock_wrap_left
; Book line 633: Branch to rock_wrap_left if N is 1 (bit 7 set); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 beq rock_low
; Book line 634: Branch to rock_low if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda ax,x
; Book line 635: Load A with the byte at ax plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 cmp #88
; Book line 636: Compare A with literal 88 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc ma_y
; Book line 637: Branch to ma_y if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #24
; Book line 638: Load A with literal 24. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ax,x
; Book line 639: Store A into the byte at ax plus index X. The register and CPU flags are unchanged.
 lda #0
; Book line 640: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta axh,x
; Book line 641: Store A into the byte at axh plus index X. The register and CPU flags are unchanged.
 jmp ma_y
; Book line 642: Continue execution at ma_y without saving a return address. Registers and flags are
; unchanged by the jump itself.
rock_low:
; Book line 643: rock_low names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda ax,x
; Book line 644: Load A with the byte at ax plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 cmp #24
; Book line 645: Compare A with literal 24 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcs ma_y
; Book line 646: Branch to ma_y if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
rock_wrap_left:
; Book line 647: rock_wrap_left names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #87
; Book line 648: Load A with literal 87. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ax,x
; Book line 649: Store A into the byte at ax plus index X. The register and CPU flags are unchanged.
 lda #1
; Book line 650: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta axh,x
; Book line 651: Store A into the byte at axh plus index X. The register and CPU flags are unchanged.
ma_y:
; Book line 652: ma_y names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda ay,x
; Book line 653: Load A with the byte at ay plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 clc
; Book line 654: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc dy,x
; Book line 655: Add the byte at dy plus index X and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ay,x
; Book line 656: Store A into the byte at ay plus index X. The register and CPU flags are unchanged.
 cmp #235
; Book line 657: Compare A with literal 235 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc ma_ylow
; Book line 658: Branch to ma_ylow if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #55
; Book line 659: Load A with literal 55. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ay,x
; Book line 660: Store A into the byte at ay plus index X. The register and CPU flags are unchanged.
ma_ylow:
; Book line 661: ma_ylow names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 cmp #50
; Book line 662: Compare A with literal 50 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcs ma_display
; Book line 663: Branch to ma_display if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #230
; Book line 664: Load A with literal 230. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ay,x
; Book line 665: Store A into the byte at ay plus index X. The register and CPU flags are unchanged.
ma_display:
; Book line 666: ma_display names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 txa
; Book line 667: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
 asl
; Book line 668: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc
; Book line 669: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #4
; Book line 670: Add literal 4 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 tay
; Book line 671: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda ax,x
; Book line 672: Load A with the byte at ax plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta SPR,y
; Book line 673: Store A into the byte at SPR (sprite 0 X low byte) plus index Y. The register and CPU
; flags are unchanged.
 ; Sprite 2..7 X high bits are bits 2..7 of $d010.
 lda axh,x
; Book line 675: Load A with the byte at axh plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 beq rock_msb_clear
; Book line 676: Branch to rock_msb_clear if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda $d010
; Book line 677: Load A with the byte at $d010 (VIC sprite X high bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ora rockmask,x
; Book line 678: Set A bits present in either A or the byte at rockmask plus index X. Save the result
; in A and update Z and N; carry is unchanged.
 sta $d010
; Book line 679: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
 jmp rock_msb_done
; Book line 680: Continue execution at rock_msb_done without saving a return address. Registers and
; flags are unchanged by the jump itself.
rock_msb_clear:
; Book line 681: rock_msb_clear names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda $d010
; Book line 682: Load A with the byte at $d010 (VIC sprite X high bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and rockinv,x
; Book line 683: Keep only bits set in both A and the byte at rockinv plus index X. Save the result in
; A and update Z and N; carry is unchanged.
 sta $d010
; Book line 684: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
rock_msb_done:
; Book line 685: rock_msb_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 iny
; Book line 686: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 lda ay,x
; Book line 687: Load A with the byte at ay plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta SPR,y
; Book line 688: Store A into the byte at SPR (sprite 0 X low byte) plus index Y. The register and CPU
; flags are unchanged.
 lda sizes,x
; Book line 689: Load A with the byte at sizes (asteroid size table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cmp #2
; Book line 690: Compare A with literal 2 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne ma_notlarge
; Book line 691: Branch to ma_notlarge if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #$c9
; Book line 692: Load A with literal $c9 (decimal 201). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne ma_pointer
; Book line 693: Branch to ma_pointer if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
ma_notlarge:
; Book line 694: ma_notlarge names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 cmp #1
; Book line 695: Compare A with literal 1 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne ma_small
; Book line 696: Branch to ma_small if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #$ca
; Book line 697: Load A with literal $ca (decimal 202). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne ma_pointer
; Book line 698: Branch to ma_pointer if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
ma_small:
; Book line 699: ma_small names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #$cb
; Book line 700: Load A with literal $cb (decimal 203). Z records a zero value; N copies bit 7. Carry
; is unchanged.
ma_pointer:
; Book line 701: ma_pointer names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sta $07fa,x
; Book line 702: Store A into the byte at $07fa (sprite pointer table in the $0400 screen) plus index
; X. The register and CPU flags are unchanged.
 lda sizes,x
; Book line 703: Load A with the byte at sizes (asteroid size table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cmp #2
; Book line 704: Compare A with literal 2 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne ma_noexpand
; Book line 705: Branch to ma_noexpand if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda $d01d
; Book line 706: Load A with the byte at $d01d (VIC sprite width expansion). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ora rockmask,x
; Book line 707: Set A bits present in either A or the byte at rockmask plus index X. Save the result
; in A and update Z and N; carry is unchanged.
 sta $d01d
; Book line 708: Store A into the byte at $d01d (VIC sprite width expansion). The register and CPU
; flags are unchanged.
 lda $d017
; Book line 709: Load A with the byte at $d017 (VIC sprite height expansion). Z records a zero value;
; N copies bit 7. Carry is unchanged.
 ora rockmask,x
; Book line 710: Set A bits present in either A or the byte at rockmask plus index X. Save the result
; in A and update Z and N; carry is unchanged.
 sta $d017
; Book line 711: Store A into the byte at $d017 (VIC sprite height expansion). The register and CPU
; flags are unchanged.
 jmp ma_enable
; Book line 712: Continue execution at ma_enable without saving a return address. Registers and flags
; are unchanged by the jump itself.
ma_noexpand:
; Book line 713: ma_noexpand names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda $d01d
; Book line 714: Load A with the byte at $d01d (VIC sprite width expansion). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and rockinv,x
; Book line 715: Keep only bits set in both A and the byte at rockinv plus index X. Save the result in
; A and update Z and N; carry is unchanged.
 sta $d01d
; Book line 716: Store A into the byte at $d01d (VIC sprite width expansion). The register and CPU
; flags are unchanged.
 lda $d017
; Book line 717: Load A with the byte at $d017 (VIC sprite height expansion). Z records a zero value;
; N copies bit 7. Carry is unchanged.
 and rockinv,x
; Book line 718: Keep only bits set in both A and the byte at rockinv plus index X. Save the result in
; A and update Z and N; carry is unchanged.
 sta $d017
; Book line 719: Store A into the byte at $d017 (VIC sprite height expansion). The register and CPU
; flags are unchanged.
ma_enable:
; Book line 720: ma_enable names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda $d015
; Book line 721: Load A with the byte at $d015 (VIC sprite enable bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ora rockmask,x
; Book line 722: Set A bits present in either A or the byte at rockmask plus index X. Save the result
; in A and update Z and N; carry is unchanged.
 sta $d015
; Book line 723: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 jmp ma_next
; Book line 724: Continue execution at ma_next without saving a return address. Registers and flags
; are unchanged by the jump itself.
ma_hidden:
; Book line 725: ma_hidden names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda $d015
; Book line 726: Load A with the byte at $d015 (VIC sprite enable bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and rockinv,x
; Book line 727: Keep only bits set in both A and the byte at rockinv plus index X. Save the result in
; A and update Z and N; carry is unchanged.
 sta $d015
; Book line 728: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
ma_next:
; Book line 729: ma_next names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 inx
; Book line 730: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #6
; Book line 731: Compare X with literal 6 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq ma_finished
; Book line 732: Branch to ma_finished if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp ma_loop
; Book line 733: Continue execution at ma_loop without saving a return address. Registers and flags
; are unchanged by the jump itself.
ma_finished:
; Book line 734: ma_finished names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 rts
; Book line 735: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ------------------------------------------------------------------
; COLLISION CHECKS - WHAT / WHY / HOW
; Tests ship/asteroid and bullet/asteroid proximity. The visual sprite outline and the numeric hitbox are different things.
; ------------------------------------------------------------------
collide:
; Book line 742: collide names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ldx #0
; Book line 743: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
co_loop:
; Book line 744: co_loop names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda active,x
; Book line 745: Load A with the byte at active (object activity table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 bne co_active
; Book line 746: Branch to co_active if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp co_next
; Book line 747: Continue execution at co_next without saving a return address. Registers and flags
; are unchanged by the jump itself.
co_active:
; Book line 748: co_active names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ; Collision distances use asteroid centres and size-dependent radii.
 ; A ship has a roughly 10px radius; bullet is about 3px.
 lda sizes,x
; Book line 751: Load A with the byte at sizes (asteroid size table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 tay
; Book line 752: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda rockradius,y
; Book line 753: Load A with the byte at rockradius plus index Y. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta radius
; Book line 754: Store A into the byte at radius. The register and CPU flags are unchanged.
 lda invuln
; Book line 755: Load A with the byte at invuln (invulnerability countdown). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 bne co_bullet
; Book line 756: Branch to co_bullet if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda axh,x
; Book line 757: Load A with the byte at axh plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 cmp shipxh
; Book line 758: Compare A with the byte at shipxh (ship X high byte) without changing A. Z means
; equal, C means unsigned greater or equal, and N is the subtraction result bit 7.
 bne co_bullet
; Book line 759: Branch to co_bullet if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda ax,x
; Book line 760: Load A with the byte at ax plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 clc
; Book line 761: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #12
; Book line 762: Add literal 12 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 ldy sizes,x
; Book line 763: Load Y with the byte at sizes (asteroid size table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cpy #2
; Book line 764: Compare Y with literal 2 without changing Y. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne ship_center_ready
; Book line 765: Branch to ship_center_ready if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
 clc
; Book line 766: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #12
; Book line 767: Add literal 12 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
ship_center_ready:
; Book line 768: ship_center_ready names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 sec
; Book line 769: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc shipx
; Book line 770: Subtract the byte at shipx (ship X low byte) and (1 minus incoming carry) from A.
; Update C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 jsr absacc
; Book line 771: Call absacc, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr subtract_radius
; Book line 772: Call subtract_radius, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
 cmp #10
; Book line 773: Compare A with literal 10 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc ship_x_ok
; Book line 774: Branch to ship_x_ok if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 jmp co_bullet
; Book line 775: Continue execution at co_bullet without saving a return address. Registers and flags
; are unchanged by the jump itself.
ship_x_ok:
; Book line 776: ship_x_ok names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda ay,x
; Book line 777: Load A with the byte at ay plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 clc
; Book line 778: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #10
; Book line 779: Add literal 10 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 ldy sizes,x
; Book line 780: Load Y with the byte at sizes (asteroid size table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cpy #2
; Book line 781: Compare Y with literal 2 without changing Y. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne ship_y_center_ready
; Book line 782: Branch to ship_y_center_ready if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 clc
; Book line 783: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #10
; Book line 784: Add literal 10 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
ship_y_center_ready:
; Book line 785: ship_y_center_ready names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 sec
; Book line 786: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc shipy
; Book line 787: Subtract the byte at shipy (ship Y) and (1 minus incoming carry) from A. Update C, Z,
; N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 jsr absacc
; Book line 788: Call absacc, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr subtract_radius
; Book line 789: Call subtract_radius, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
 cmp #10
; Book line 790: Compare A with literal 10 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc ship_y_ok
; Book line 791: Branch to ship_y_ok if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 jmp co_bullet
; Book line 792: Continue execution at co_bullet without saving a return address. Registers and flags
; are unchanged by the jump itself.
ship_y_ok:
; Book line 793: ship_y_ok names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr sound_explode
; Book line 794: Call sound_explode, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 dec lives
; Book line 795: Decrease the byte at lives (remaining lives) by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
 lda #160
; Book line 796: Load A with literal 160. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipx
; Book line 797: Store A into the byte at shipx (ship X low byte). The register and CPU flags are
; unchanged.
 lda #0
; Book line 798: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipxh
; Book line 799: Store A into the byte at shipxh (ship X high byte). The register and CPU flags are
; unchanged.
 sta velx
; Book line 800: Store A into the byte at velx (horizontal velocity). The register and CPU flags are
; unchanged.
 sta vely
; Book line 801: Store A into the byte at vely (vertical velocity). The register and CPU flags are
; unchanged.
 sta fracx
; Book line 802: Store A into the byte at fracx (horizontal fractional position). The register and CPU
; flags are unchanged.
 sta fracy
; Book line 803: Store A into the byte at fracy (vertical fractional position). The register and CPU
; flags are unchanged.
 lda #120
; Book line 804: Load A with literal 120. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipy
; Book line 805: Store A into the byte at shipy (ship Y). The register and CPU flags are unchanged.
 lda #90
; Book line 806: Load A with literal 90. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta invuln
; Book line 807: Store A into the byte at invuln (invulnerability countdown). The register and CPU
; flags are unchanged.
 ; Don't destroy the asteroid when the ship hits it.
 jmp co_next
; Book line 809: Continue execution at co_next without saving a return address. Registers and flags
; are unchanged by the jump itself.
co_bullet:
; Book line 810: co_bullet names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda bulletactive
; Book line 811: Load A with the byte at bulletactive. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne bullet_test
; Book line 812: Branch to bullet_test if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp co_next
; Book line 813: Continue execution at co_next without saving a return address. Registers and flags
; are unchanged by the jump itself.
bullet_test:
; Book line 814: bullet_test names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda axh,x
; Book line 815: Load A with the byte at axh plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 cmp bulletxh
; Book line 816: Compare A with the byte at bulletxh without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 bne co_next
; Book line 817: Branch to co_next if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda ax,x
; Book line 818: Load A with the byte at ax plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 clc
; Book line 819: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #12
; Book line 820: Add literal 12 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 ldy sizes,x
; Book line 821: Load Y with the byte at sizes (asteroid size table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cpy #2
; Book line 822: Compare Y with literal 2 without changing Y. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne bullet_center_ready
; Book line 823: Branch to bullet_center_ready if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 clc
; Book line 824: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #12
; Book line 825: Add literal 12 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
bullet_center_ready:
; Book line 826: bullet_center_ready names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 sec
; Book line 827: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc bulletx
; Book line 828: Subtract the byte at bulletx and (1 minus incoming carry) from A. Update C, Z, N and
; V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sec
; Book line 829: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc #12
; Book line 830: Subtract literal 12 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 jsr absacc
; Book line 831: Call absacc, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr subtract_radius
; Book line 832: Call subtract_radius, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
 cmp #3
; Book line 833: Compare A with literal 3 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc bullet_x_ok
; Book line 834: Branch to bullet_x_ok if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 jmp co_next
; Book line 835: Continue execution at co_next without saving a return address. Registers and flags
; are unchanged by the jump itself.
bullet_x_ok:
; Book line 836: bullet_x_ok names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda ay,x
; Book line 837: Load A with the byte at ay plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 clc
; Book line 838: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #10
; Book line 839: Add literal 10 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 ldy sizes,x
; Book line 840: Load Y with the byte at sizes (asteroid size table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cpy #2
; Book line 841: Compare Y with literal 2 without changing Y. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne bullet_y_center_ready
; Book line 842: Branch to bullet_y_center_ready if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
 clc
; Book line 843: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #10
; Book line 844: Add literal 10 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
bullet_y_center_ready:
; Book line 845: bullet_y_center_ready names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 sec
; Book line 846: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc bullety
; Book line 847: Subtract the byte at bullety and (1 minus incoming carry) from A. Update C, Z, N and
; V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sec
; Book line 848: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc #10
; Book line 849: Subtract literal 10 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 jsr absacc
; Book line 850: Call absacc, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr subtract_radius
; Book line 851: Call subtract_radius, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
 cmp #3
; Book line 852: Compare A with literal 3 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc bullet_y_ok
; Book line 853: Branch to bullet_y_ok if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 jmp co_next
; Book line 854: Continue execution at co_next without saving a return address. Registers and flags
; are unchanged by the jump itself.
bullet_y_ok:
; Book line 855: bullet_y_ok names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr sound_explode
; Book line 856: Call sound_explode, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda #0
; Book line 857: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta bulletactive
; Book line 858: Store A into the byte at bulletactive. The register and CPU flags are unchanged.
 lda sizes,x
; Book line 859: Load A with the byte at sizes (asteroid size table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 beq smallhit
; Book line 860: Branch to smallhit if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec sizes,x
; Book line 861: Decrease the byte at sizes (asteroid size table) plus index X by one with 8-bit
; wraparound. Update Z and N; carry is unchanged.
 lda #10
; Book line 862: Load A with literal 10. Z records a zero value; N copies bit 7. Carry is unchanged.
 jsr addscore
; Book line 863: Call addscore, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr spawn
; Book line 864: Call spawn, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 jmp co_next
; Book line 865: Continue execution at co_next without saving a return address. Registers and flags
; are unchanged by the jump itself.
smallhit:
; Book line 866: smallhit names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #25
; Book line 867: Load A with literal 25. Z records a zero value; N copies bit 7. Carry is unchanged.
 jsr addscore
; Book line 868: Call addscore, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda #0
; Book line 869: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta active,x
; Book line 870: Store A into the byte at active (object activity table) plus index X. The register
; and CPU flags are unchanged.
 dec remaining
; Book line 871: Decrease the byte at remaining (remaining asteroid count) by one with 8-bit
; wraparound. Update Z and N; carry is unchanged.
co_next:
; Book line 872: co_next names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 inx
; Book line 873: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #6
; Book line 874: Compare X with literal 6 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq co_done
; Book line 875: Branch to co_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp co_loop
; Book line 876: Continue execution at co_loop without saving a return address. Registers and flags
; are unchanged by the jump itself.
co_done:
; Book line 877: co_done names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 rts
; Book line 878: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; |A| of signed 8-bit difference.
absacc:
; Book line 881: absacc names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 bpl absdone
; Book line 882: Branch to absdone if N is 0 (bit 7 clear); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 eor #$ff
; Book line 883: Toggle A bits selected by literal $ff (decimal 255). Save the result in A and update
; Z and N; carry is unchanged.
 clc
; Book line 884: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #1
; Book line 885: Add literal 1 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
absdone: rts
; Book line 886: absdone names the data or instruction address. Pull the saved subroutine return
; address from the stack and resume after its JSR. Do not use this as an interrupt return.

subtract_radius:
; Book line 888: subtract_radius names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 cmp radius
; Book line 889: Compare A with the byte at radius without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs sr_sub
; Book line 890: Branch to sr_sub if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #0
; Book line 891: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 rts
; Book line 892: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
sr_sub:
; Book line 893: sr_sub names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 sec
; Book line 894: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc radius
; Book line 895: Subtract the byte at radius and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 rts
; Book line 896: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Split into a spare asteroid slot, if available.

; ------------------------------------------------------------------
; ASTEROID SPLITTING - WHAT / WHY / HOW
; Searches for a free asteroid slot and spawns a smaller fragment. A limited slot count can prevent every split.
; ------------------------------------------------------------------
spawn:
; Book line 904: spawn names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 stx savedx
; Book line 905: Store X into the byte at savedx. The register and CPU flags are unchanged.
 ldy #0
; Book line 906: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
spfind:
; Book line 907: spfind names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda active,y
; Book line 908: Load A with the byte at active (object activity table) plus index Y. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 beq spfound
; Book line 909: Branch to spfound if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 iny
; Book line 910: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpy #6
; Book line 911: Compare Y with literal 6 without changing Y. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne spfind
; Book line 912: Branch to spfind if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ldx savedx
; Book line 913: Load X with the byte at savedx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 rts
; Book line 914: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
spfound:
; Book line 915: spfound names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #1
; Book line 916: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta active,y
; Book line 917: Store A into the byte at active (object activity table) plus index Y. The register
; and CPU flags are unchanged.
 lda sizes,x
; Book line 918: Load A with the byte at sizes (asteroid size table) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta sizes,y
; Book line 919: Store A into the byte at sizes (asteroid size table) plus index Y. The register and
; CPU flags are unchanged.
 lda ax,x
; Book line 920: Load A with the byte at ax plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 clc
; Book line 921: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #10
; Book line 922: Add literal 10 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ax,y
; Book line 923: Store A into the byte at ax plus index Y. The register and CPU flags are unchanged.
 lda axh,x
; Book line 924: Load A with the byte at axh plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 adc #0
; Book line 925: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta axh,y
; Book line 926: Store A into the byte at axh plus index Y. The register and CPU flags are unchanged.
 lda ay,x
; Book line 927: Load A with the byte at ay plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 clc
; Book line 928: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #8
; Book line 929: Add literal 8 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ay,y
; Book line 930: Store A into the byte at ay plus index Y. The register and CPU flags are unchanged.
 lda dx,x
; Book line 931: Load A with the byte at dx plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 eor #$ff
; Book line 932: Toggle A bits selected by literal $ff (decimal 255). Save the result in A and update
; Z and N; carry is unchanged.
 clc
; Book line 933: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #1
; Book line 934: Add literal 1 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta dx,y
; Book line 935: Store A into the byte at dx plus index Y. The register and CPU flags are unchanged.
 lda dy,x
; Book line 936: Load A with the byte at dy plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 eor #$ff
; Book line 937: Toggle A bits selected by literal $ff (decimal 255). Save the result in A and update
; Z and N; carry is unchanged.
 clc
; Book line 938: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #1
; Book line 939: Add literal 1 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta dy,y
; Book line 940: Store A into the byte at dy plus index Y. The register and CPU flags are unchanged.
 inc remaining
; Book line 941: Increase the byte at remaining (remaining asteroid count) by one with 8-bit
; wraparound. Update Z and N; carry is unchanged.
 lda $d015
; Book line 942: Load A with the byte at $d015 (VIC sprite enable bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ora rockmask,y
; Book line 943: Set A bits present in either A or the byte at rockmask plus index Y. Save the result
; in A and update Z and N; carry is unchanged.
 sta $d015
; Book line 944: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 ldx savedx
; Book line 945: Load X with the byte at savedx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 rts
; Book line 946: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ------------------------------------------------------------------
; SCORE KEEPING - WHAT / WHY / HOW
; Adds points to the current score and compares it with the high score.
; ------------------------------------------------------------------
addscore:
; Book line 953: addscore names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 clc
; Book line 954: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc score
; Book line 955: Add the byte at score and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta score
; Book line 956: Store A into the byte at score. The register and CPU flags are unchanged.
 bcc asdone
; Book line 957: Branch to asdone if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 inc score+1
; Book line 958: Increase the byte at score+1 by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
asdone:
; Book line 959: asdone names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda score+1
; Book line 960: Load A with the byte at score+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp high+1
; Book line 961: Compare A with the byte at high+1 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc asend
; Book line 962: Branch to asend if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 bne ashigh
; Book line 963: Branch to ashigh if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda score
; Book line 964: Load A with the byte at score. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp high
; Book line 965: Compare A with the byte at high without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc asend
; Book line 966: Branch to asend if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
ashigh:
; Book line 967: ashigh names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda score
; Book line 968: Load A with the byte at score. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta high
; Book line 969: Store A into the byte at high. The register and CPU flags are unchanged.
 lda score+1
; Book line 970: Load A with the byte at score+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta high+1
; Book line 971: Store A into the byte at high+1. The register and CPU flags are unchanged.
asend: rts
; Book line 972: asend names the data or instruction address. Pull the saved subroutine return address
; from the stack and resume after its JSR. Do not use this as an interrupt return.


; ------------------------------------------------------------------
; CENTRED HUD - WHAT / WHY / HOW
; Writes the 40-column HUD, decimal score and lives; distinguishes screen codes from PETSCII.
; ------------------------------------------------------------------
drawhud:
; Book line 979: drawhud names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ; Centered 32-column HUD at column 4 on the 40-column display.
 ; SCORE:00000  LIVES:3  HI:00000
 ldx #0
; Book line 982: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
hudlabel:
; Book line 983: hudlabel names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda hudchars,x
; Book line 984: Load A with the byte at hudchars plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta SCREEN+4,x
; Book line 985: Store A into the byte at SCREEN+4 plus index X. The register and CPU flags are
; unchanged.
 inx
; Book line 986: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #32
; Book line 987: Compare X with literal 32 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne hudlabel
; Book line 988: Branch to hudlabel if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda score
; Book line 989: Load A with the byte at score. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ldy score+1
; Book line 990: Load Y with the byte at score+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ldx #10
; Book line 991: Load X with literal 10. Z records a zero value; N copies bit 7. Carry is unchanged.
 jsr decimalout
; Book line 992: Call decimalout, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda lives
; Book line 993: Load A with the byte at lives (remaining lives). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 clc
; Book line 994: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$30
; Book line 995: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta SCREEN+23
; Book line 996: Store A into the byte at SCREEN+23. The register and CPU flags are unchanged.
 lda high
; Book line 997: Load A with the byte at high. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ldy high+1
; Book line 998: Load Y with the byte at high+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ldx #29
; Book line 999: Load X with literal 29. Z records a zero value; N copies bit 7. Carry is unchanged.
 jsr decimalout
; Book line 1000: Call decimalout, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 rts
; Book line 1001: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Input: A=low byte, Y=high byte, X=first screen column.
; Outputs five decimal digits for a 16-bit unsigned value.

; ------------------------------------------------------------------
; DECIMAL CONVERSION - WHAT / WHY / HOW
; Repeatedly subtracts 10000, 1000, 100, 10 and 1 to display a 16-bit number in base ten.
; ------------------------------------------------------------------
decimalout:
; Book line 1010: decimalout names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sta decvalue
; Book line 1011: Store A into the byte at decvalue. The register and CPU flags are unchanged.
 sty decvalue+1
; Book line 1012: Store Y into the byte at decvalue+1. The register and CPU flags are unchanged.
 stx decpos
; Book line 1013: Store X into the byte at decpos. The register and CPU flags are unchanged.
 lda #0
; Book line 1014: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta decindex
; Book line 1015: Store A into the byte at decindex. The register and CPU flags are unchanged.
decnext:
; Book line 1016: decnext names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #0
; Book line 1017: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta decdigit
; Book line 1018: Store A into the byte at decdigit. The register and CPU flags are unchanged.
dectry:
; Book line 1019: dectry names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ldy decindex
; Book line 1020: Load Y with the byte at decindex. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda decvalue+1
; Book line 1021: Load A with the byte at decvalue+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp dechi,y
; Book line 1022: Compare A with the byte at dechi plus index Y without changing A. Z means equal, C
; means unsigned greater or equal, and N is the subtraction result bit 7.
 bcc decprint
; Book line 1023: Branch to decprint if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 bne decsubtract
; Book line 1024: Branch to decsubtract if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda decvalue
; Book line 1025: Load A with the byte at decvalue. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp declo,y
; Book line 1026: Compare A with the byte at declo plus index Y without changing A. Z means equal, C
; means unsigned greater or equal, and N is the subtraction result bit 7.
 bcc decprint
; Book line 1027: Branch to decprint if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
decsubtract:
; Book line 1028: decsubtract names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 sec
; Book line 1029: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 lda decvalue
; Book line 1030: Load A with the byte at decvalue. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc declo,y
; Book line 1031: Subtract the byte at declo plus index Y and (1 minus incoming carry) from A. Update
; C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta decvalue
; Book line 1032: Store A into the byte at decvalue. The register and CPU flags are unchanged.
 lda decvalue+1
; Book line 1033: Load A with the byte at decvalue+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sbc dechi,y
; Book line 1034: Subtract the byte at dechi plus index Y and (1 minus incoming carry) from A. Update
; C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta decvalue+1
; Book line 1035: Store A into the byte at decvalue+1. The register and CPU flags are unchanged.
 inc decdigit
; Book line 1036: Increase the byte at decdigit by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 jmp dectry
; Book line 1037: Continue execution at dectry without saving a return address. Registers and flags
; are unchanged by the jump itself.
decprint:
; Book line 1038: decprint names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda decdigit
; Book line 1039: Load A with the byte at decdigit. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc
; Book line 1040: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$30
; Book line 1041: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 ldx decpos
; Book line 1042: Load X with the byte at decpos. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta SCREEN,x
; Book line 1043: Store A into the byte at SCREEN (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 inc decpos
; Book line 1044: Increase the byte at decpos by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 inc decindex
; Book line 1045: Increase the byte at decindex by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 lda decindex
; Book line 1046: Load A with the byte at decindex. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #5
; Book line 1047: Compare A with literal 5 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne decnext
; Book line 1048: Branch to decnext if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts
; Book line 1049: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Divisors 10000, 1000, 100, 10, 1.
declo: !byte $10,$e8,$64,$0a,$01
; Book line 1052: declo names the data or instruction address. Emit 5 bytes in the shown order for
; declo. These are data or encoded loader bytes, not instructions to execute.
dechi: !byte $27,$03,$00,$00,$00
; Book line 1053: dechi names the data or instruction address. Emit 5 bytes in the shown order for
; dechi. These are data or encoded loader bytes, not instructions to execute.
; C64 screen codes, not PETSCII.
hudchars:
; Book line 1055: hudchars names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 !byte 19,3,15,18,5,58,48,48,48,48,48,32,32
; Book line 1056: Emit 13 bytes in the shown order for hudchars. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 12,9,22,5,19,58,48,32,32
; Book line 1057: Emit 9 bytes in the shown order for hudchars. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 8,9,58,48,48,48,48,48,32,32
; Book line 1058: Emit 10 bytes in the shown order for hudchars. These are data or encoded loader
; bytes, not instructions to execute.
; 32 bytes total. The score starts at column 10, lives at 24, high at 29.
decvalue: !word 0
; Book line 1060: decvalue names the data or instruction address. Emit the listed 16-bit value or
; values for decvalue, storing each low byte before its high byte.
decpos: !byte 0
; Book line 1061: decpos names the data or instruction address. Emit 1 byte in the shown order for
; decpos. These are data or encoded loader bytes, not instructions to execute.
decindex: !byte 0
; Book line 1062: decindex names the data or instruction address. Emit 1 byte in the shown order for
; decindex. These are data or encoded loader bytes, not instructions to execute.
decdigit: !byte 0
; Book line 1063: decdigit names the data or instruction address. Emit 1 byte in the shown order for
; decdigit. These are data or encoded loader bytes, not instructions to execute.

score: !word 0
; Book line 1065: score names the data or instruction address. Emit the listed 16-bit value or values
; for score, storing each low byte before its high byte.
high: !word 0
; Book line 1066: high names the data or instruction address. Emit the listed 16-bit value or values
; for high, storing each low byte before its high byte.
shipx: !byte 160
; Book line 1067: shipx names the data or instruction address. Emit 1 byte in the shown order for
; shipx. These are data or encoded loader bytes, not instructions to execute. The surrounding image
; definition determines how these bits become pixels.
shipxh: !byte 0
; Book line 1068: shipxh names the data or instruction address. Emit 1 byte in the shown order for
; shipxh. These are data or encoded loader bytes, not instructions to execute. The surrounding image
; definition determines how these bits become pixels.
shipy: !byte 120
; Book line 1069: shipy names the data or instruction address. Emit 1 byte in the shown order for
; shipy. These are data or encoded loader bytes, not instructions to execute. The surrounding image
; definition determines how these bits become pixels.
bulletx: !byte 0
; Book line 1070: bulletx names the data or instruction address. Emit 1 byte in the shown order for
; bulletx. These are data or encoded loader bytes, not instructions to execute.
bulletxh: !byte 0
; Book line 1071: bulletxh names the data or instruction address. Emit 1 byte in the shown order for
; bulletxh. These are data or encoded loader bytes, not instructions to execute.
bullety: !byte 0
; Book line 1072: bullety names the data or instruction address. Emit 1 byte in the shown order for
; bullety. These are data or encoded loader bytes, not instructions to execute.
bulletactive: !byte 0
; Book line 1073: bulletactive names the data or instruction address. Emit 1 byte in the shown order
; for bulletactive. These are data or encoded loader bytes, not instructions to execute.
cooldown: !byte 0
; Book line 1074: cooldown names the data or instruction address. Emit 1 byte in the shown order for
; cooldown. These are data or encoded loader bytes, not instructions to execute.
lives: !byte 3
; Book line 1075: lives names the data or instruction address. Emit 1 byte in the shown order for
; lives. These are data or encoded loader bytes, not instructions to execute.
wave: !byte 0
; Book line 1076: wave names the data or instruction address. Emit 1 byte in the shown order for wave.
; These are data or encoded loader bytes, not instructions to execute.
remaining: !byte 0
; Book line 1077: remaining names the data or instruction address. Emit 1 byte in the shown order for
; remaining. These are data or encoded loader bytes, not instructions to execute.
savedx: !byte 0
; Book line 1078: savedx names the data or instruction address. Emit 1 byte in the shown order for
; savedx. These are data or encoded loader bytes, not instructions to execute.
angle: !byte 0
; Book line 1079: angle names the data or instruction address. Emit 1 byte in the shown order for
; angle. These are data or encoded loader bytes, not instructions to execute.
thrusttick: !byte 0
; Book line 1080: thrusttick names the data or instruction address. Emit 1 byte in the shown order for
; thrusttick. These are data or encoded loader bytes, not instructions to execute.
rotclock: !byte 0
; Book line 1081: rotclock names the data or instruction address. Emit 1 byte in the shown order for
; rotclock. These are data or encoded loader bytes, not instructions to execute.
invuln: !byte 0
; Book line 1082: invuln names the data or instruction address. Emit 1 byte in the shown order for
; invuln. These are data or encoded loader bytes, not instructions to execute.
radius: !byte 0
; Book line 1083: radius names the data or instruction address. Emit 1 byte in the shown order for
; radius. These are data or encoded loader bytes, not instructions to execute.
rockradius: !byte 5,11,17
; Book line 1084: rockradius names the data or instruction address. Emit 3 bytes in the shown order
; for rockradius. These are data or encoded loader bytes, not instructions to execute.
bulletdx: !byte 0
; Book line 1085: bulletdx names the data or instruction address. Emit 1 byte in the shown order for
; bulletdx. These are data or encoded loader bytes, not instructions to execute.
bulletdy: !byte 0
; Book line 1086: bulletdy names the data or instruction address. Emit 1 byte in the shown order for
; bulletdy. These are data or encoded loader bytes, not instructions to execute.
; Clockwise from north, signed velocity steps.
; Quarter-pixel acceleration, clockwise from north.
accelx: !byte 0,1,1,1,0,$ff,$ff,$ff
; Book line 1089: accelx names the data or instruction address. Emit 8 bytes in the shown order for
; accelx. These are data or encoded loader bytes, not instructions to execute.
accely: !byte $ff,$ff,0,1,1,1,0,$ff
; Book line 1090: accely names the data or instruction address. Emit 8 bytes in the shown order for
; accely. These are data or encoded loader bytes, not instructions to execute.
; Shot vectors, nose offsets, clockwise from north.
shotx: !byte 0,4,6,4,0,$fc,$fa,$fc
; Book line 1092: shotx names the data or instruction address. Emit 8 bytes in the shown order for
; shotx. These are data or encoded loader bytes, not instructions to execute.
shoty: !byte $fa,$fc,0,4,6,4,0,$fc
; Book line 1093: shoty names the data or instruction address. Emit 8 bytes in the shown order for
; shoty. These are data or encoded loader bytes, not instructions to execute.
nosex: !byte 0,8,11,8,0,$f8,$f5,$f8
; Book line 1094: nosex names the data or instruction address. Emit 8 bytes in the shown order for
; nosex. These are data or encoded loader bytes, not instructions to execute.
nosey: !byte $f5,$f8,0,8,11,8,0,$f8
; Book line 1095: nosey names the data or instruction address. Emit 8 bytes in the shown order for
; nosey. These are data or encoded loader bytes, not instructions to execute.
velx: !byte 0
; Book line 1096: velx names the data or instruction address. Emit 1 byte in the shown order for velx.
; These are data or encoded loader bytes, not instructions to execute.
vely: !byte 0
; Book line 1097: vely names the data or instruction address. Emit 1 byte in the shown order for vely.
; These are data or encoded loader bytes, not instructions to execute.
fracx: !byte 0
; Book line 1098: fracx names the data or instruction address. Emit 1 byte in the shown order for
; fracx. These are data or encoded loader bytes, not instructions to execute.
fracy: !byte 0
; Book line 1099: fracy names the data or instruction address. Emit 1 byte in the shown order for
; fracy. These are data or encoded loader bytes, not instructions to execute.
dragtick: !byte 0
; Book line 1100: dragtick names the data or instruction address. Emit 1 byte in the shown order for
; dragtick. These are data or encoded loader bytes, not instructions to execute.
active: !fill 6,0
; Book line 1101: active names the data or instruction address. Emit repeated initial data for active:
; 6,0. The first expression is the byte count and the second is the fill value.
sizes: !fill 6,0
; Book line 1102: sizes names the data or instruction address. Emit repeated initial data for sizes:
; 6,0. The first expression is the byte count and the second is the fill value.
ax: !fill 6,0
; Book line 1103: ax names the data or instruction address. Emit repeated initial data for ax: 6,0.
; The first expression is the byte count and the second is the fill value.
axh: !fill 6,0
; Book line 1104: axh names the data or instruction address. Emit repeated initial data for axh: 6,0.
; The first expression is the byte count and the second is the fill value.
ay: !fill 6,0
; Book line 1105: ay names the data or instruction address. Emit repeated initial data for ay: 6,0.
; The first expression is the byte count and the second is the fill value.
dx: !fill 6,0
; Book line 1106: dx names the data or instruction address. Emit repeated initial data for dx: 6,0.
; The first expression is the byte count and the second is the fill value.
dy: !fill 6,0
; Book line 1107: dy names the data or instruction address. Emit repeated initial data for dy: 6,0.
; The first expression is the byte count and the second is the fill value.
rockmask: !byte 4,8,16,32,64,128
; Book line 1108: rockmask names the data or instruction address. Emit 6 bytes in the shown order for
; rockmask. These are data or encoded loader bytes, not instructions to execute.
rockinv: !byte $fb,$f7,$ef,$df,$bf,$7f
; Book line 1109: rockinv names the data or instruction address. Emit 6 bytes in the shown order for
; rockinv. These are data or encoded loader bytes, not instructions to execute.
initx: !byte 35,70,115,155,205,235
; Book line 1110: initx names the data or instruction address. Emit 6 bytes in the shown order for
; initx. These are data or encoded loader bytes, not instructions to execute.
inity: !byte 65,180,100,210,85,160
; Book line 1111: inity names the data or instruction address. Emit 6 bytes in the shown order for
; inity. These are data or encoded loader bytes, not instructions to execute.
initdx: !byte 1,255,1,255,1,255
; Book line 1112: initdx names the data or instruction address. Emit 6 bytes in the shown order for
; initdx. These are data or encoded loader bytes, not instructions to execute.
initdy: !byte 1,1,255,255,1,255
; Book line 1113: initdy names the data or instruction address. Emit 6 bytes in the shown order for
; initdy. These are data or encoded loader bytes, not instructions to execute.

titletext:
; Book line 1115: titletext names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 !text 13,13
; Book line 1116: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "            ASTEROID ATTACK",13,13
; Book line 1117: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "          CUSTOM SPRITE ARCADE",13,13
; Book line 1118: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "         LEFT / RIGHT TO ROTATE",13
; Book line 1119: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "              UP TO THRUST",13
; Book line 1120: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "             FIRE TO SHOOT",13,13
; Book line 1121: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "         LARGE SPLITS TO MEDIUM",13
; Book line 1122: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "         MEDIUM SPLITS TO SMALL",13,13
; Book line 1123: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "               PRESS FIRE",13
; Book line 1124: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !byte 0
; Book line 1125: Emit 1 byte in the shown order for titletext. These are data or encoded loader
; bytes, not instructions to execute.
overtext:
; Book line 1126: overtext names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 !text 13,13,13,13
; Book line 1127: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "               GAME OVER",13,13
; Book line 1128: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !text "            PRESS FIRE AGAIN",13,13
; Book line 1129: Emit the quoted text as literal text bytes, used here as loader or message data;
; these are not automatically screen codes.
 !byte 0
; Book line 1130: Emit 1 byte in the shown order for overtext. These are data or encoded loader bytes,
; not instructions to execute.


; Original SID arcade-style accompaniment, not the Pleiades soundtrack.
; Voice 1: music; voice 2: laser; voice 3: asteroid explosion.
; Called once per video frame; does not alter X or Y.

; ------------------------------------------------------------------
; SID SETUP - WHAT / WHY / HOW
; Initializes the three SID voices and envelope parameters.
; ------------------------------------------------------------------
sound_init:
; Book line 1141: sound_init names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ldx #$18
; Book line 1142: Load X with literal $18 (decimal 24). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 lda #0
; Book line 1143: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
si_clear:
; Book line 1144: si_clear names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sta $d400,x
; Book line 1145: Store A into the byte at $d400 (SID voice 1 frequency low) plus index X. The
; register and CPU flags are unchanged.
 dex
; Book line 1146: Decrease X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bpl si_clear
; Book line 1147: Branch to si_clear if N is 0 (bit 7 clear); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #$0f
; Book line 1148: Load A with literal $0f (decimal 15). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d418
; Book line 1149: Store A into the byte at $d418 (SID volume and filter mode). The register and CPU
; flags are unchanged.
 lda #$09
; Book line 1150: Load A with literal $09 (decimal 9). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d405
; Book line 1151: Store A into the byte at $d405 (SID voice 1 attack and decay). The register and CPU
; flags are unchanged.
 lda #$a8
; Book line 1152: Load A with literal $a8 (decimal 168). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d406
; Book line 1153: Store A into the byte at $d406 (SID voice 1 sustain and release). The register and
; CPU flags are unchanged.
 lda #$08
; Book line 1154: Load A with literal $08 (decimal 8). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d40c
; Book line 1155: Store A into the byte at $d40c (SID voice 2 attack and decay). The register and CPU
; flags are unchanged.
 lda #$68
; Book line 1156: Load A with literal $68 (decimal 104). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d40d
; Book line 1157: Store A into the byte at $d40d (SID voice 2 sustain and release). The register and
; CPU flags are unchanged.
 lda #$02
; Book line 1158: Load A with literal $02 (decimal 2). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d413
; Book line 1159: Store A into the byte at $d413 (SID voice 3 attack and decay). The register and CPU
; flags are unchanged.
 lda #$a8
; Book line 1160: Load A with literal $a8 (decimal 168). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d414
; Book line 1161: Store A into the byte at $d414 (SID voice 3 sustain and release). The register and
; CPU flags are unchanged.
 lda #0
; Book line 1162: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta music_pos
; Book line 1163: Store A into the byte at music_pos (music sequence index). The register and CPU
; flags are unchanged.
 sta music_timer
; Book line 1164: Store A into the byte at music_timer (music duration countdown). The register and
; CPU flags are unchanged.
 sta fire_timer
; Book line 1165: Store A into the byte at fire_timer. The register and CPU flags are unchanged.
 sta explode_timer
; Book line 1166: Store A into the byte at explode_timer. The register and CPU flags are unchanged.
 rts
; Book line 1167: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ------------------------------------------------------------------
; FIRE SOUND - WHAT / WHY / HOW
; Starts a short noise effect on SID voice 2.
; ------------------------------------------------------------------
sound_fire:
; Book line 1174: sound_fire names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #7
; Book line 1175: Load A with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta fire_timer
; Book line 1176: Store A into the byte at fire_timer. The register and CPU flags are unchanged.
 lda #$00
; Book line 1177: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d407
; Book line 1178: Store A into the byte at $d407 (SID voice 2 frequency low). The register and CPU
; flags are unchanged.
 lda #$34
; Book line 1179: Load A with literal $34 (decimal 52). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d408
; Book line 1180: Store A into the byte at $d408 (SID voice 2 frequency high). The register and CPU
; flags are unchanged.
 lda #$81       ; noise + gate
; Book line 1181: Load A with literal $81 (decimal 129). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d40b
; Book line 1182: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
 rts
; Book line 1183: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ------------------------------------------------------------------
; EXPLOSION SOUND - WHAT / WHY / HOW
; Starts a descending noise effect on SID voice 3.
; ------------------------------------------------------------------
sound_explode:
; Book line 1190: sound_explode names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #18
; Book line 1191: Load A with literal 18. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta explode_timer
; Book line 1192: Store A into the byte at explode_timer. The register and CPU flags are unchanged.
 lda #$00
; Book line 1193: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d40e
; Book line 1194: Store A into the byte at $d40e (SID voice 3 frequency low). The register and CPU
; flags are unchanged.
 lda #$16
; Book line 1195: Load A with literal $16 (decimal 22). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d40f
; Book line 1196: Store A into the byte at $d40f (SID voice 3 frequency high). The register and CPU
; flags are unchanged.
 lda #$81
; Book line 1197: Load A with literal $81 (decimal 129). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d412
; Book line 1198: Store A into the byte at $d412 (SID voice 3 waveform and gate). The register and CPU
; flags are unchanged.
 rts
; Book line 1199: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ------------------------------------------------------------------
; MUSIC TICK - WHAT / WHY / HOW
; Called once per frame: advances effects and the original repeating note pattern on SID voice 1. This is the counterpart to music_tick in the learning path.
; ------------------------------------------------------------------
sound_tick:
; Book line 1206: sound_tick names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ; Keep the two effects independent of the music voice.
 lda fire_timer
; Book line 1208: Load A with the byte at fire_timer. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq st_explosion
; Book line 1209: Branch to st_explosion if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec fire_timer
; Book line 1210: Decrease the byte at fire_timer by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
 beq st_fire_off
; Book line 1211: Branch to st_fire_off if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 asl
; Book line 1212: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 asl
; Book line 1213: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 asl
; Book line 1214: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc
; Book line 1215: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$14
; Book line 1216: Add literal $14 (decimal 20) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $d408
; Book line 1217: Store A into the byte at $d408 (SID voice 2 frequency high). The register and CPU
; flags are unchanged.
 jmp st_explosion
; Book line 1218: Continue execution at st_explosion without saving a return address. Registers and
; flags are unchanged by the jump itself.
st_fire_off:
; Book line 1219: st_fire_off names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #$80
; Book line 1220: Load A with literal $80 (decimal 128). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d40b
; Book line 1221: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
st_explosion:
; Book line 1222: st_explosion names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda explode_timer
; Book line 1223: Load A with the byte at explode_timer. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 beq st_music
; Book line 1224: Branch to st_music if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec explode_timer
; Book line 1225: Decrease the byte at explode_timer by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
 beq st_explosion_off
; Book line 1226: Branch to st_explosion_off if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda explode_timer
; Book line 1227: Load A with the byte at explode_timer. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 asl
; Book line 1228: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc
; Book line 1229: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #$08
; Book line 1230: Add literal $08 (decimal 8) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $d40f
; Book line 1231: Store A into the byte at $d40f (SID voice 3 frequency high). The register and CPU
; flags are unchanged.
 jmp st_music
; Book line 1232: Continue execution at st_music without saving a return address. Registers and flags
; are unchanged by the jump itself.
st_explosion_off:
; Book line 1233: st_explosion_off names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
 lda #$80
; Book line 1234: Load A with literal $80 (decimal 128). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d412
; Book line 1235: Store A into the byte at $d412 (SID voice 3 waveform and gate). The register and CPU
; flags are unchanged.
st_music:
; Book line 1236: st_music names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda music_timer
; Book line 1237: Load A with the byte at music_timer (music duration countdown). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 beq st_newnote
; Book line 1238: Branch to st_newnote if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec music_timer
; Book line 1239: Decrease the byte at music_timer (music duration countdown) by one with 8-bit
; wraparound. Update Z and N; carry is unchanged.
 rts
; Book line 1240: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
st_newnote:
; Book line 1241: st_newnote names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #11       ; 12 PAL frames per step
; Book line 1242: Load A with literal 11. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta music_timer
; Book line 1243: Store A into the byte at music_timer (music duration countdown). The register and
; CPU flags are unchanged.
 ldx music_pos
; Book line 1244: Load X with the byte at music_pos (music sequence index). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 lda #$10
; Book line 1245: Load A with literal $10 (decimal 16). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d404    ; gate off before new note
; Book line 1246: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
 lda tune_lo,x
; Book line 1247: Load A with the byte at tune_lo plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta $d400
; Book line 1248: Store A into the byte at $d400 (SID voice 1 frequency low). The register and CPU
; flags are unchanged.
 lda tune_hi,x
; Book line 1249: Load A with the byte at tune_hi plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta $d401
; Book line 1250: Store A into the byte at $d401 (SID voice 1 frequency high). The register and CPU
; flags are unchanged.
 lda #$11     ; triangle + gate
; Book line 1251: Load A with literal $11 (decimal 17). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d404
; Book line 1252: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
 inx
; Book line 1253: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #32
; Book line 1254: Compare X with literal 32 without changing X. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne st_savepos
; Book line 1255: Branch to st_savepos if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ldx #0
; Book line 1256: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
st_savepos:
; Book line 1257: st_savepos names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 stx music_pos
; Book line 1258: Store X into the byte at music_pos (music sequence index). The register and CPU
; flags are unchanged.
 rts
; Book line 1259: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

music_pos: !byte 0
; Book line 1261: music_pos names the data or instruction address. Emit 1 byte in the shown order for
; music_pos. These are data or encoded loader bytes, not instructions to execute.
music_timer: !byte 0
; Book line 1262: music_timer names the data or instruction address. Emit 1 byte in the shown order
; for music_timer. These are data or encoded loader bytes, not instructions to execute.
fire_timer: !byte 0
; Book line 1263: fire_timer names the data or instruction address. Emit 1 byte in the shown order for
; fire_timer. These are data or encoded loader bytes, not instructions to execute.
explode_timer: !byte 0
; Book line 1264: explode_timer names the data or instruction address. Emit 1 byte in the shown order
; for explode_timer. These are data or encoded loader bytes, not instructions to execute.

; An original 32-step minor-key space-arcade pattern.
; SID PAL note frequencies, low/high bytes.
tune_lo:
; Book line 1268: tune_lo names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 !byte $68,$68,$17,$68,$d0,$17,$68,$17
; Book line 1269: Emit 8 bytes in the shown order for tune_lo. These are data or encoded loader bytes,
; not instructions to execute.
 !byte $68,$68,$d0,$68,$17,$d0,$68,$17
; Book line 1270: Emit 8 bytes in the shown order for tune_lo. These are data or encoded loader bytes,
; not instructions to execute.
 !byte $45,$45,$68,$45,$17,$68,$45,$68
; Book line 1271: Emit 8 bytes in the shown order for tune_lo. These are data or encoded loader bytes,
; not instructions to execute.
 !byte $45,$17,$68,$45,$d0,$17,$68,$45
; Book line 1272: Emit 8 bytes in the shown order for tune_lo. These are data or encoded loader bytes,
; not instructions to execute.
tune_hi:
; Book line 1273: tune_hi names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 !byte $11,$11,$15,$11,$0d,$15,$11,$15
; Book line 1274: Emit 8 bytes in the shown order for tune_hi. These are data or encoded loader bytes,
; not instructions to execute.
 !byte $11,$11,$0d,$11,$15,$0d,$11,$15
; Book line 1275: Emit 8 bytes in the shown order for tune_hi. These are data or encoded loader bytes,
; not instructions to execute.
 !byte $0f,$0f,$11,$0f,$15,$11,$0f,$11
; Book line 1276: Emit 8 bytes in the shown order for tune_hi. These are data or encoded loader bytes,
; not instructions to execute.
 !byte $0f,$15,$11,$0f,$0d,$15,$11,$0f
; Book line 1277: Emit 8 bytes in the shown order for tune_hi. These are data or encoded loader bytes,
; not instructions to execute.

; Custom sprite artwork. Eight 24x21 ship rotations, followed by bullet and 3 rock sizes.
*=$3000
; Book line 1280: Place subsequent output at C64 address $3000; the origin directive is processed by
; ACME, not executed by the CPU.
ship0:
; Book line 1281: ship0 names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 !byte $00,$00,$00,$00,$18,$00,$00,$3c,$00,$00,$3c,$00
; Book line 1282: Emit 12 bytes in the shown order for ship0. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$3c,$00,$00,$7e,$00,$00,$66,$00,$00,$e7,$00
; Book line 1283: Emit 12 bytes in the shown order for ship0. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$c3,$00,$01,$c3,$80,$01,$c3,$80,$01,$81,$80
; Book line 1284: Emit 12 bytes in the shown order for ship0. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $03,$81,$c0,$03,$00,$c0,$07,$3c,$e0,$06,$ff,$60
; Book line 1285: Emit 12 bytes in the shown order for ship0. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $07,$e7,$e0,$0f,$81,$f0,$0e,$00,$70,$00,$00,$00
; Book line 1286: Emit 12 bytes in the shown order for ship0. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$00,$00,$00
; Book line 1287: Emit 4 bytes in the shown order for ship0. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
ship1:
; Book line 1288: ship1 names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$60
; Book line 1289: Emit 12 bytes in the shown order for ship1. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$01,$e0,$00,$0f,$e0,$00,$3f,$e0,$01,$f8,$c0
; Book line 1290: Emit 12 bytes in the shown order for ship1. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $07,$e1,$c0,$1f,$01,$80,$7c,$01,$80,$fe,$03,$80
; Book line 1291: Emit 12 bytes in the shown order for ship1. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $3f,$c3,$00,$03,$c7,$00,$00,$e6,$00,$00,$6e,$00
; Book line 1292: Emit 12 bytes in the shown order for ship1. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$6c,$00,$00,$6c,$00,$00,$7c,$00,$00,$38,$00
; Book line 1293: Emit 12 bytes in the shown order for ship1. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$38,$00,$00
; Book line 1294: Emit 4 bytes in the shown order for ship1. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
ship2:
; Book line 1295: ship2 names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 !byte $00,$00,$00,$00,$00,$00,$08,$00,$00,$1e,$00,$00
; Book line 1296: Emit 12 bytes in the shown order for ship2. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $1f,$80,$00,$0f,$f0,$00,$0e,$fc,$00,$07,$1f,$80
; Book line 1297: Emit 12 bytes in the shown order for ship2. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $03,$07,$e0,$03,$80,$f8,$01,$80,$3c,$03,$80,$f8
; Book line 1298: Emit 12 bytes in the shown order for ship2. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $03,$07,$e0,$07,$1f,$80,$0e,$fc,$00,$0f,$f0,$00
; Book line 1299: Emit 12 bytes in the shown order for ship2. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $1f,$80,$00,$1e,$00,$00,$08,$00,$00,$00,$00,$00
; Book line 1300: Emit 12 bytes in the shown order for ship2. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$00,$00,$00
; Book line 1301: Emit 4 bytes in the shown order for ship2. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
ship3:
; Book line 1302: ship3 names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 !byte $00,$38,$00,$00,$38,$00,$00,$7c,$00,$00,$6c,$00
; Book line 1303: Emit 12 bytes in the shown order for ship3. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$6c,$00,$00,$6e,$00,$00,$e6,$00,$03,$c7,$00
; Book line 1304: Emit 12 bytes in the shown order for ship3. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $3f,$c3,$00,$fe,$03,$80,$7c,$01,$80,$1f,$01,$80
; Book line 1305: Emit 12 bytes in the shown order for ship3. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $07,$e1,$c0,$01,$f8,$c0,$00,$3f,$e0,$00,$0f,$e0
; Book line 1306: Emit 12 bytes in the shown order for ship3. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$01,$e0,$00,$00,$60,$00,$00,$00,$00,$00,$00
; Book line 1307: Emit 12 bytes in the shown order for ship3. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$00,$00,$00
; Book line 1308: Emit 4 bytes in the shown order for ship3. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
ship4:
; Book line 1309: ship4 names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 !byte $00,$00,$00,$08,$00,$00,$0e,$00,$70,$0f,$81,$f0
; Book line 1310: Emit 12 bytes in the shown order for ship4. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $07,$e7,$e0,$06,$ff,$60,$07,$3c,$e0,$03,$00,$c0
; Book line 1311: Emit 12 bytes in the shown order for ship4. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $03,$81,$c0,$01,$81,$80,$01,$c3,$80,$01,$c3,$80
; Book line 1312: Emit 12 bytes in the shown order for ship4. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$c3,$00,$00,$e7,$00,$00,$66,$00,$00,$7e,$00
; Book line 1313: Emit 12 bytes in the shown order for ship4. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$3c,$00,$00,$3c,$00,$00,$3c,$00,$00,$18,$00
; Book line 1314: Emit 12 bytes in the shown order for ship4. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$08,$00,$00
; Book line 1315: Emit 4 bytes in the shown order for ship4. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
ship5:
; Book line 1316: ship5 names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 !byte $00,$1c,$00,$00,$1c,$00,$00,$3e,$00,$00,$36,$00
; Book line 1317: Emit 12 bytes in the shown order for ship5. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$36,$00,$00,$76,$00,$00,$67,$00,$00,$e3,$c0
; Book line 1318: Emit 12 bytes in the shown order for ship5. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$c3,$fc,$01,$c0,$7f,$01,$80,$3e,$01,$80,$f8
; Book line 1319: Emit 12 bytes in the shown order for ship5. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $03,$87,$e0,$03,$1f,$80,$07,$fc,$00,$07,$f0,$00
; Book line 1320: Emit 12 bytes in the shown order for ship5. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $07,$80,$00,$06,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1321: Emit 12 bytes in the shown order for ship5. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$00,$00,$00
; Book line 1322: Emit 4 bytes in the shown order for ship5. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
ship6:
; Book line 1323: ship6 names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$18,$00,$00,$78
; Book line 1324: Emit 12 bytes in the shown order for ship6. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$01,$f8,$00,$0f,$f0,$00,$3f,$70,$01,$f8,$e0
; Book line 1325: Emit 12 bytes in the shown order for ship6. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $07,$e0,$c0,$1f,$01,$c0,$3c,$01,$80,$3f,$01,$c0
; Book line 1326: Emit 12 bytes in the shown order for ship6. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $07,$e0,$c0,$01,$f8,$e0,$00,$3f,$70,$00,$0f,$f0
; Book line 1327: Emit 12 bytes in the shown order for ship6. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$01,$f8,$00,$00,$78,$00,$00,$10,$00,$00,$00
; Book line 1328: Emit 12 bytes in the shown order for ship6. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$00,$00,$00
; Book line 1329: Emit 4 bytes in the shown order for ship6. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
ship7:
; Book line 1330: ship7 names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$00,$00
; Book line 1331: Emit 12 bytes in the shown order for ship7. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $07,$80,$00,$07,$f0,$00,$07,$fc,$00,$03,$1f,$80
; Book line 1332: Emit 12 bytes in the shown order for ship7. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $03,$87,$e0,$01,$80,$f8,$01,$80,$3e,$01,$c0,$7f
; Book line 1333: Emit 12 bytes in the shown order for ship7. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$c3,$fc,$00,$e3,$c0,$00,$67,$00,$00,$76,$00
; Book line 1334: Emit 12 bytes in the shown order for ship7. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$36,$00,$00,$36,$00,$00,$3e,$00,$00,$1c,$00
; Book line 1335: Emit 12 bytes in the shown order for ship7. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
 !byte $00,$1c,$00,$00
; Book line 1336: Emit 4 bytes in the shown order for ship7. These are data or encoded loader bytes,
; not instructions to execute. The surrounding image definition determines how these bits become
; pixels.
bulletgfx:
; Book line 1337: bulletgfx names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1338: Emit 12 bytes in the shown order for bulletgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1339: Emit 12 bytes in the shown order for bulletgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $00,$00,$00,$00,$18,$00,$00,$18,$00,$00,$18,$00
; Book line 1340: Emit 12 bytes in the shown order for bulletgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1341: Emit 12 bytes in the shown order for bulletgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1342: Emit 12 bytes in the shown order for bulletgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $00,$00,$00,$00
; Book line 1343: Emit 4 bytes in the shown order for bulletgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
largegfx:
; Book line 1344: largegfx names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 !byte $00,$00,$00,$00,$ff,$00,$01,$ff,$80,$01,$81,$80
; Book line 1345: Emit 12 bytes in the shown order for largegfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $03,$81,$c0,$07,$00,$e0,$0e,$00,$70,$0c,$00,$30
; Book line 1346: Emit 12 bytes in the shown order for largegfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $1c,$00,$38,$38,$00,$1c,$30,$00,$3c,$38,$00,$38
; Book line 1347: Emit 12 bytes in the shown order for largegfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $38,$00,$38,$18,$00,$38,$18,$00,$30,$1e,$00,$30
; Book line 1348: Emit 12 bytes in the shown order for largegfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $0f,$c0,$f0,$03,$f9,$e0,$00,$7f,$80,$00,$0f,$00
; Book line 1349: Emit 12 bytes in the shown order for largegfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $00,$00,$00,$00
; Book line 1350: Emit 4 bytes in the shown order for largegfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
mediumgfx:
; Book line 1351: mediumgfx names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 !byte $00,$00,$00,$01,$fe,$00,$07,$03,$80,$0c,$00,$c0
; Book line 1352: Emit 12 bytes in the shown order for mediumgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $18,$00,$60,$30,$00,$30,$20,$00,$10,$20,$00,$18
; Book line 1353: Emit 12 bytes in the shown order for mediumgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $20,$00,$08,$30,$00,$08,$10,$00,$08,$10,$00,$08
; Book line 1354: Emit 12 bytes in the shown order for mediumgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $10,$00,$18,$18,$00,$10,$08,$00,$30,$0c,$00,$20
; Book line 1355: Emit 12 bytes in the shown order for mediumgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $06,$00,$e0,$03,$c3,$c0,$00,$7e,$00,$00,$00,$00
; Book line 1356: Emit 12 bytes in the shown order for mediumgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $00,$00,$00,$00
; Book line 1357: Emit 4 bytes in the shown order for mediumgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
smallgfx:
; Book line 1358: smallgfx names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1359: Emit 12 bytes in the shown order for smallgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $00,$00,$00,$00,$00,$00,$00,$7e,$00,$00,$7e,$00
; Book line 1360: Emit 12 bytes in the shown order for smallgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $00,$e7,$00,$01,$c3,$80,$01,$83,$80,$01,$c3,$00
; Book line 1361: Emit 12 bytes in the shown order for smallgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $01,$e3,$00,$00,$ff,$00,$00,$3e,$00,$00,$00,$00
; Book line 1362: Emit 12 bytes in the shown order for smallgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 1363: Emit 12 bytes in the shown order for smallgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
 !byte $00,$00,$00,$00
; Book line 1364: Emit 4 bytes in the shown order for smallgfx. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.

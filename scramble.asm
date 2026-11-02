; CODING ARCADE GAMES ON THE COMMODORE 64
; Scramble project -- beginner learning edition
; Companion: tutorial/SCRAMBLE-TUTORIAL.md and the supplied Word tutorial.
; Build with ./build.sh. Comments do not change the original game bytes.
;
; READING ASSEMBLY
; A semicolon begins a comment: ACME ignores the rest of that line.
; A label names an address. JSR calls a routine; RTS returns to the caller.
; A, X and Y are 8-bit registers. Each can hold a number from 0 through 255.
; # means a literal; $ means hexadecimal. LDA #$10 loads 16 into A.
; LDA $10 instead reads the value stored at memory address $0010.
; C is carry; Z is zero. CMP changes flags without changing A.
; BEQ/BNE test Z; BCC/BCS test C. CLC prepares ADC; SEC prepares SBC.
; <label and >label take the low/high address bytes (little-endian order).
; ($fb),y follows the pointer in $fb/$fc and then adds Y to that address.
;
; MEMORY PLAN (hexadecimal)
; $0400-$07ff screen A; sprite pointers at $07f8-$07ff.
; $0801 BASIC loader, 10 SYS 4096. $0c00-$0fff screen B; pointers $0ff8.
; $1000 machine-code entry. Code and state must remain below $2800.
; $2800-$297f six sprite images, each occupying a 64-byte-aligned slot.
; $3000-$37ff writable font; $3800-$3cff source of custom terrain glyphs.
; $d800-$dbff colour RAM, shared by both screen buffers.
; $fb/$fc scratch or source pointer; $fd/$fe scratch or destination pointer.
; RAM $fffa/$fffb NMI vector; $fffe/$ffff IRQ vector with KERNAL banked out.
;
; EXECUTION PLAN
; start -> title -> newgame -> main, one update per PAL frame.
; A separate raster IRQ selects stationary HUD and scrolling playfield.
; lose_life returns to main twice; the third death enters gameover.
; Reset the machine to leave this game. It does not restore BASIC/KERNAL.
; Existing validation is CPU-level; PAL VIC timing still needs VICE/hardware QA.
;

; Select the C64 instruction set; no bytes are emitted.
!cpu 6510
; Book line 36: Select the 6510 CPU instruction set for ACME validation. This directive does not run
; on the C64.
; BASIC program-start address. Loader below encodes 10 SYS 4096.
*=$0801
; Book line 38: Place subsequent output at C64 address $0801; the origin directive is processed by
; ACME, not executed by the CPU.
; Next BASIC line $080b; line number 10; $9e is the SYS token.
!byte $0b,$08,$0a,$00,$9e
; Book line 40: Emit 5 bytes in the shown order for program. These are data or encoded loader bytes,
; not instructions to execute.
; BASIC stores the decimal entry address as text: 4096 = $1000.
!text "4096"
; Book line 42: Emit the quoted text as literal text bytes, used here as loader or message data; these
; are not automatically screen codes.
; End line text, followed by two zero bytes ending the BASIC program.
!byte 0,0,0
; Book line 44: Emit 3 bytes in the shown order for program. These are data or encoded loader bytes,
; not instructions to execute.
; Machine-code entry, leaving screen buffers outside executable code.
*=$1000
; Book line 46: Place subsequent output at C64 address $1000; the origin directive is processed by
; ACME, not executed by the CPU.

; ============================================================================
; WHAT: Take over the hardware
; WHY: BASIC interrupts would disturb game timing
; HOW: SEI, disable CIA IRQs, initialise VIC/SID, select bank 0 and prepare ROM/RAM mapping.
; ============================================================================
start:
; Book line 53: start names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 sei ; Mask ordinary CPU IRQs.
; Book line 54: Set the interrupt-disable flag to mask ordinary IRQ handling. NMI is not masked, and
; peripheral interrupt sources are not automatically cleared.
 lda #$7f ; Load literal value into A.
; Book line 55: Load A with literal $7f (decimal 127). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $dc0d ; Write A to CIA1 interrupt control.
; Book line 56: Store A into the byte at $dc0d (CIA1 interrupt control). The register and CPU flags
; are unchanged.
 sta $dd0d ; Write A to CIA2 interrupt control.
; Book line 57: Store A into the byte at $dd0d (CIA2 interrupt control). The register and CPU flags
; are unchanged.
 lda $dc0d ; Read CIA1 interrupt control.
; Book line 58: Load A with the byte at $dc0d (CIA1 interrupt control). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 lda $dd0d ; Read CIA2 interrupt control.
; Book line 59: Load A with the byte at $dd0d (CIA2 interrupt control). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 lda #0 ; Load literal value into A.
; Book line 60: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d01a ; Write A to VIC interrupt enable.
; Book line 61: Store A into the byte at $d01a (VIC interrupt enables). The register and CPU flags are
; unchanged.
 sta $d020 ; Write A to border colour.
; Book line 62: Store A into the byte at $d020 (VIC border colour). The register and CPU flags are
; unchanged.
 sta $d021 ; Write A to background colour.
; Book line 63: Store A into the byte at $d021 (VIC background colour). The register and CPU flags are
; unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 64: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 sta $d010
; Book line 65: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
 sta $d017
; Book line 66: Store A into the byte at $d017 (VIC sprite height expansion). The register and CPU
; flags are unchanged.
 sta $d01b
; Book line 67: Store A into the byte at $d01b (VIC sprite background priority). The register and CPU
; flags are unchanged.
 sta $d01c ; Write A to sprite multicolour bits.
; Book line 68: Store A into the byte at $d01c (VIC sprite multicolour bits). The register and CPU
; flags are unchanged.
 sta $d01d
; Book line 69: Store A into the byte at $d01d (VIC sprite width expansion). The register and CPU
; flags are unchanged.
 lda #3 ; Load literal value into A.
; Book line 70: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $dd00 ; Write A to CIA2 port A / inverted VIC bank selection.
; Book line 71: Store A into the byte at $dd00 (CIA2 port A and VIC bank select). The register and CPU
; flags are unchanged.
 lda #$33 ; Load literal value into A.
; Book line 72: Load A with literal $33 (decimal 51). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $01 ; Write A to 6510 ROM/RAM banking port.
; Book line 73: Store A into the byte at $01 (6510 ROM and I/O banking port). The register and CPU
; flags are unchanged.
 ldx #0 ; Load literal value into X.
; Book line 74: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.

; ============================================================================
; WHAT: Copy the 2048-byte character ROM to RAM
; WHY: Letters remain usable while terrain glyphs become editable
; HOW: X visits 0..255; eight load/store pairs copy eight pages while $01=$33 exposes character
; ROM.
; ============================================================================
copyfont:
; Book line 82: copyfont names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda $d000,x ; Read indexed table or screen entry.
; Book line 83: Load A with the byte at $d000 (sprite 0 X low byte) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $3000,x
; Book line 84: Store A into the byte at $3000 plus index X. The register and CPU flags are unchanged.
 lda $d100,x ; Read indexed table or screen entry.
; Book line 85: Load A with the byte at $d100 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $3100,x
; Book line 86: Store A into the byte at $3100 plus index X. The register and CPU flags are unchanged.
 lda $d200,x ; Read indexed table or screen entry.
; Book line 87: Load A with the byte at $d200 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $3200,x
; Book line 88: Store A into the byte at $3200 plus index X. The register and CPU flags are unchanged.
 lda $d300,x ; Read indexed table or screen entry.
; Book line 89: Load A with the byte at $d300 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $3300,x
; Book line 90: Store A into the byte at $3300 plus index X. The register and CPU flags are unchanged.
 lda $d400,x ; Read indexed table or screen entry.
; Book line 91: Load A with the byte at $d400 (SID voice 1 frequency low) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 sta $3400,x
; Book line 92: Store A into the byte at $3400 plus index X. The register and CPU flags are unchanged.
 lda $d500,x ; Read indexed table or screen entry.
; Book line 93: Load A with the byte at $d500 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $3500,x
; Book line 94: Store A into the byte at $3500 plus index X. The register and CPU flags are unchanged.
 lda $d600,x ; Read indexed table or screen entry.
; Book line 95: Load A with the byte at $d600 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $3600,x
; Book line 96: Store A into the byte at $3600 plus index X. The register and CPU flags are unchanged.
 lda $d700,x ; Read indexed table or screen entry.
; Book line 97: Load A with the byte at $d700 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $3700,x
; Book line 98: Store A into the byte at $3700 plus index X. The register and CPU flags are unchanged.
 inx ; Next X index; 255 wraps to zero.
; Book line 99: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne copyfont ; Branch if not zero/equal (Z=0).
; Book line 100: Branch to copyfont if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #$37 ; Load literal value into A.
; Book line 101: Load A with literal $37 (decimal 55). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $01 ; Write A to 6510 ROM/RAM banking port.
; Book line 102: Store A into the byte at $01 (6510 ROM and I/O banking port). The register and CPU
; flags are unchanged.
 ldx #0 ; Load literal value into X.
; Book line 103: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.

; ============================================================================
; WHAT: Install terrain characters 96..255
; WHY: Smooth edge graphics need custom bitmaps
; HOW: Copy five pages from terrain_chars to font address $3300, preserving earlier letter
; glyphs.
; ============================================================================
cg:
; Book line 111: cg names this assembled address; it emits no bytes and provides a jump, call or data
; reference target.
 lda terrain_chars,x ; Read indexed table or screen entry.
; Book line 112: Load A with the byte at terrain_chars plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $3300,x
; Book line 113: Store A into the byte at $3300 plus index X. The register and CPU flags are
; unchanged.
 lda terrain_chars+$100,x ; Read indexed table or screen entry.
; Book line 114: Load A with the byte at terrain_chars+$100 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $3400,x
; Book line 115: Store A into the byte at $3400 plus index X. The register and CPU flags are
; unchanged.
 lda terrain_chars+$200,x ; Read indexed table or screen entry.
; Book line 116: Load A with the byte at terrain_chars+$200 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $3500,x
; Book line 117: Store A into the byte at $3500 plus index X. The register and CPU flags are
; unchanged.
 lda terrain_chars+$300,x ; Read indexed table or screen entry.
; Book line 118: Load A with the byte at terrain_chars+$300 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $3600,x
; Book line 119: Store A into the byte at $3600 plus index X. The register and CPU flags are
; unchanged.
 lda terrain_chars+$400,x ; Read indexed table or screen entry.
; Book line 120: Load A with the byte at terrain_chars+$400 plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta $3700,x
; Book line 121: Store A into the byte at $3700 plus index X. The register and CPU flags are
; unchanged.
 inx ; Next X index; 255 wraps to zero.
; Book line 122: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne cg ; Branch if not zero/equal (Z=0).
; Book line 123: Branch to cg if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ldx #7 ; Load literal value into X.
; Book line 124: Load X with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.

; ============================================================================
; WHAT: Install star glyph 94 and final hardware settings
; WHY: Stars must be air to collision code
; HOW: Copy eight rows below solid threshold 96; set $01=$35 and RAM IRQ/NMI vectors.
; ============================================================================
starcopy:
; Book line 131: starcopy names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda star_tile,x ; Read indexed table or screen entry.
; Book line 132: Load A with the byte at star_tile plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta $32f0,x
; Book line 133: Store A into the byte at $32f0 plus index X. The register and CPU flags are
; unchanged.
 dex ; Previous X index.
; Book line 134: Decrease X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bpl starcopy ; Branch while bit 7 of last result is clear.
; Book line 135: Branch to starcopy if N is 0 (bit 7 clear); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #$35 ; Load literal value into A.
; Book line 136: Load A with literal $35 (decimal 53). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $01 ; Write A to 6510 ROM/RAM banking port.
; Book line 137: Store A into the byte at $01 (6510 ROM and I/O banking port). The register and CPU
; flags are unchanged.
 lda #<raster_irq ; Take low address byte.
; Book line 138: Load A with the low address byte of raster_irq as an immediate value. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 sta $fffe ; Write A to IRQ vector low byte.
; Book line 139: Store A into the byte at $fffe (RAM IRQ vector low byte). The register and CPU flags
; are unchanged.
 lda #>raster_irq ; Take high address byte.
; Book line 140: Load A with the high address byte of raster_irq as an immediate value. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 sta $ffff ; Write A to IRQ vector high byte.
; Book line 141: Store A into the byte at $ffff (RAM IRQ vector high byte). The register and CPU flags
; are unchanged.
 lda #<nmi_return ; Take low address byte.
; Book line 142: Load A with the low address byte of nmi_return as an immediate value. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 sta $fffa ; Write A to NMI vector low byte.
; Book line 143: Store A into the byte at $fffa (RAM NMI vector low byte). The register and CPU flags
; are unchanged.
 lda #>nmi_return ; Take high address byte.
; Book line 144: Load A with the high address byte of nmi_return as an immediate value. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 sta $fffb ; Write A to NMI vector high byte.
; Book line 145: Store A into the byte at $fffb (RAM NMI vector high byte). The register and CPU flags
; are unchanged.
 lda #2 ; deep red rock shadows
; Book line 146: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d022 ; Write A to terrain pair 01 colour.
; Book line 147: Store A into the byte at $d022. The register and CPU flags are unchanged.
 lda #10 ; rose/light-red rock faces
; Book line 148: Load A with literal 10. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d023 ; Write A to terrain pair 10 colour.
; Book line 149: Store A into the byte at $d023. The register and CPU flags are unchanged.
 lda #1 ; Load literal value into A.
; Book line 150: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d025 ; Write A to sprite pair 01 shared colour.
; Book line 151: Store A into the byte at $d025 (shared sprite multicolour 1). The register and CPU
; flags are unchanged.
 lda #2 ; Load literal value into A.
; Book line 152: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d026 ; Write A to sprite pair 11 shared colour.
; Book line 153: Store A into the byte at $d026 (shared sprite multicolour 2). The register and CPU
; flags are unchanged.
 lda #$f9 ; Load literal value into A.
; Book line 154: Load A with literal $f9 (decimal 249). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d01c ; Write A to sprite multicolour bits.
; Book line 155: Store A into the byte at $d01c (VIC sprite multicolour bits). The register and CPU
; flags are unchanged.
 lda #$1c ; Load literal value into A.
; Book line 156: Load A with literal $1c (decimal 28). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d018 ; Write A to screen/font address selection.
; Book line 157: Store A into the byte at $d018 (VIC screen and font selection). The register and CPU
; flags are unchanged.
 lda #$1b ; Load literal value into A.
; Book line 158: Load A with literal $1b (decimal 27). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d011 ; Write A to display enable and vertical control.
; Book line 159: Store A into the byte at $d011 (VIC vertical control and raster high bit). The
; register and CPU flags are unchanged.
 lda #8 ; Load literal value into A.
; Book line 160: Load A with literal 8. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d016 ; Write A to horizontal mode and fine-scroll bits.
; Book line 161: Store A into the byte at $d016 (VIC horizontal control and fine scroll). The register
; and CPU flags are unchanged.
 lda #15 ; Load literal value into A.
; Book line 162: Load A with literal 15. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d418 ; Write A to SID master volume.
; Book line 163: Store A into the byte at $d418 (SID volume and filter mode). The register and CPU
; flags are unchanged.
 lda #$08 ; Load literal value into A.
; Book line 164: Load A with literal $08 (decimal 8). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d405
; Book line 165: Store A into the byte at $d405 (SID voice 1 attack and decay). The register and CPU
; flags are unchanged.
 lda #$88 ; Load literal value into A.
; Book line 166: Load A with literal $88 (decimal 136). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d406
; Book line 167: Store A into the byte at $d406 (SID voice 1 sustain and release). The register and
; CPU flags are unchanged.
 lda #$08 ; Load literal value into A.
; Book line 168: Load A with literal $08 (decimal 8). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d40c
; Book line 169: Store A into the byte at $d40c (SID voice 2 attack and decay). The register and CPU
; flags are unchanged.
 lda #$88 ; Load literal value into A.
; Book line 170: Load A with literal $88 (decimal 136). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d40d
; Book line 171: Store A into the byte at $d40d (SID voice 2 sustain and release). The register and
; CPU flags are unchanged.
 lda #$ff ; Load literal value into A.
; Book line 172: Load A with literal $ff (decimal 255). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $dc02 ; Write A to CIA1 port A direction.
; Book line 173: Store A into the byte at $dc02 (CIA1 port A direction). The register and CPU flags
; are unchanged.
 lda #0 ; Load literal value into A.
; Book line 174: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $dc03 ; Write A to CIA1 port B direction.
; Book line 175: Store A into the byte at $dc03 (CIA1 port B direction). The register and CPU flags
; are unchanged.
 jmp title ; Continue at title without a return address.
; Book line 176: Continue execution at title without saving a return address. Registers and flags are
; unchanged by the jump itself.


; ============================================================================
; WHAT: Wait for the NEXT raster line 250
; WHY: Speed must depend on display frames, not CPU-loop speed
; HOW: Leave line 250 if already there, then wait for its next occurrence. Clobbers A and flags.
; ============================================================================
frame:
; Book line 184: frame names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda $d012 ; Read raster line read / IRQ compare write.
; Book line 185: Load A with the byte at $d012 (VIC raster counter or IRQ compare). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cmp #250 ; Compare; change flags, preserve register.
; Book line 186: Compare A with literal 250 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq frame ; Branch if zero/equal (Z=1).
; Book line 187: Branch to frame if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
fwait:
; Book line 188: fwait names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda $d012 ; Read raster line read / IRQ compare write.
; Book line 189: Load A with the byte at $d012 (VIC raster counter or IRQ compare). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 cmp #250 ; Compare; change flags, preserve register.
; Book line 190: Compare A with literal 250 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne fwait ; Branch if not zero/equal (Z=0).
; Book line 191: Branch to fwait if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts ; Return to caller.
; Book line 192: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; WHAT: Clear both screens and colour RAM
; WHY: Buffer swaps must never show old characters
; HOW: Fill screen pages with space 32 and colour RAM with 7; gameplay applies final colours
; before reveal. Reinstall sprite pointers afterwards.
; ============================================================================
clear:
; Book line 201: clear names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #32 ; Load literal value into A.
; Book line 202: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 ldx #0 ; Load literal value into X.
; Book line 203: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
cl:
; Book line 204: cl names this assembled address; it emits no bytes and provides a jump, call or data
; reference target.
 sta $0400,x
; Book line 205: Store A into the byte at $0400 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 sta $0500,x
; Book line 206: Store A into the byte at $0500 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 sta $0600,x
; Book line 207: Store A into the byte at $0600 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 sta $0700,x
; Book line 208: Store A into the byte at $0700 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 sta $0c00,x
; Book line 209: Store A into the byte at $0c00 plus index X. The register and CPU flags are
; unchanged.
 sta $0d00,x
; Book line 210: Store A into the byte at $0d00 plus index X. The register and CPU flags are
; unchanged.
 sta $0e00,x
; Book line 211: Store A into the byte at $0e00 plus index X. The register and CPU flags are
; unchanged.
 sta $0f00,x
; Book line 212: Store A into the byte at $0f00 plus index X. The register and CPU flags are
; unchanged.
 lda #7 ; Load literal value into A.
; Book line 213: Load A with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d800,x
; Book line 214: Store A into the byte at $d800 (colour RAM) plus index X. The register and CPU flags
; are unchanged.
 sta $d900,x
; Book line 215: Store A into the byte at $d900 (colour RAM) plus index X. The register and CPU flags
; are unchanged.
 sta $da00,x
; Book line 216: Store A into the byte at $da00 (colour RAM) plus index X. The register and CPU flags
; are unchanged.
 sta $db00,x
; Book line 217: Store A into the byte at $db00 (colour RAM) plus index X. The register and CPU flags
; are unchanged.
 lda #32 ; Load literal value into A.
; Book line 218: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 inx ; Next X index; 255 wraps to zero.
; Book line 219: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne cl ; Branch if not zero/equal (Z=0).
; Book line 220: Branch to cl if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts ; Return to caller.
; Book line 221: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Zero-terminated screen-code string at $fb, destination $fd

; ============================================================================
; WHAT: Print a zero-terminated screen-code string
; WHY: Reuse one printer for title HUD and game over
; HOW: Source pointer $fb/$fc and destination $fd/$fe; read/write with Y until zero. Clobbers
; A/Y/flags; strings must not exceed the indexed range.
; ============================================================================
print:
; Book line 231: print names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ldy #0 ; Load literal value into Y.
; Book line 232: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
ploop:
; Book line 233: ploop names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda ($fb),y ; Read through pointer plus Y.
; Book line 234: Load A with the byte at the address in zero-page pair $fb and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
 beq pdone ; Branch if zero/equal (Z=1).
; Book line 235: Branch to pdone if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 sta ($fd),y ; Write through pointer plus Y.
; Book line 236: Store A into the byte at the address in zero-page pair $fd and its next byte, plus Y.
; The register and CPU flags are unchanged.
 iny ; Next Y index; 255 wraps to zero.
; Book line 237: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne ploop ; Branch if not zero/equal (Z=0).
; Book line 238: Branch to ploop if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
pdone: rts ; Return to caller.
; Book line 239: pdone names the data or instruction address. Pull the saved subroutine return address
; from the stack and resume after its JSR. Do not use this as an interrupt return.


; ============================================================================
; WHAT: Read held controls without KERNAL
; WHY: The game owns the keyboard scanning
; HOW: CIA port A reads joystick 2 and selects keyboard columns; port B reads rows. Space clears
; the same active-low fire bit as the joystick.
; ============================================================================
readkeys:
; Book line 248: readkeys names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #$ff ; Load literal value into A.
; Book line 249: Load A with literal $ff (decimal 255). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $dc00 ; Write A to CIA1 port A / joystick 2 / keyboard column selection.
; Book line 250: Store A into the byte at $dc00 (CIA1 port A and joystick 2). The register and CPU
; flags are unchanged.
 lda $dc00 ; Read CIA1 port A / joystick 2 / keyboard column selection.
; Book line 251: Load A with the byte at $dc00 (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 sta joy ; Store joy.
; Book line 252: Store A into the byte at joy. The register and CPU flags are unchanged.
 lda #$fd ; Load literal value into A.
; Book line 253: Load A with literal $fd (decimal 253). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $dc00 ; Write A to CIA1 port A / joystick 2 / keyboard column selection.
; Book line 254: Store A into the byte at $dc00 (CIA1 port A and joystick 2). The register and CPU
; flags are unchanged.
 lda $dc01 ; Read CIA1 port B / keyboard rows.
; Book line 255: Load A with the byte at $dc01 (CIA1 port B and keyboard rows). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta keys1 ; Store keys1.
; Book line 256: Store A into the byte at keys1. The register and CPU flags are unchanged.
 lda #$fb ; Load literal value into A.
; Book line 257: Load A with literal $fb (decimal 251). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $dc00 ; Write A to CIA1 port A / joystick 2 / keyboard column selection.
; Book line 258: Store A into the byte at $dc00 (CIA1 port A and joystick 2). The register and CPU
; flags are unchanged.
 lda $dc01 ; Read CIA1 port B / keyboard rows.
; Book line 259: Load A with the byte at $dc01 (CIA1 port B and keyboard rows). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta keys2 ; Store keys2.
; Book line 260: Store A into the byte at keys2. The register and CPU flags are unchanged.
 lda #$7f ; Load literal value into A.
; Book line 261: Load A with literal $7f (decimal 127). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $dc00 ; Write A to CIA1 port A / joystick 2 / keyboard column selection.
; Book line 262: Store A into the byte at $dc00 (CIA1 port A and joystick 2). The register and CPU
; flags are unchanged.
 lda $dc01 ; Read CIA1 port B / keyboard rows.
; Book line 263: Load A with the byte at $dc01 (CIA1 port B and keyboard rows). Z records a zero
; value; N copies bit 7. Carry is unchanged.
 and #$10 ; Keep only masked bits.
; Book line 264: Keep only bits set in both A and literal $10 (decimal 16). Save the result in A and
; update Z and N; carry is unchanged.
 bne nospace ; Branch if not zero/equal (Z=0).
; Book line 265: Branch to nospace if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda joy ; Read joy.
; Book line 266: Load A with the byte at joy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #$ef ; Keep only masked bits.
; Book line 267: Keep only bits set in both A and literal $ef (decimal 239). Save the result in A and
; update Z and N; carry is unchanged.
 sta joy ; Store joy.
; Book line 268: Store A into the byte at joy. The register and CPU flags are unchanged.
nospace:
; Book line 269: nospace names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #$ff ; Load literal value into A.
; Book line 270: Load A with literal $ff (decimal 255). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $dc00 ; Write A to CIA1 port A / joystick 2 / keyboard column selection.
; Book line 271: Store A into the byte at $dc00 (CIA1 port A and joystick 2). The register and CPU
; flags are unchanged.
 rts ; Return to caller.
; Book line 272: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; WHAT: Wait for release of fire or Space
; WHY: One held press should not skip multiple screens
; HOW: Poll once per frame until joy bit 4 is high; gameplay does not update here.
; ============================================================================
release:
; Book line 280: release names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr frame ; Call frame; RTS returns here.
; Book line 281: Call frame, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 jsr readkeys ; Call readkeys; RTS returns here.
; Book line 282: Call readkeys, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda joy ; Read joy.
; Book line 283: Load A with the byte at joy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #16 ; Keep only masked bits.
; Book line 284: Keep only bits set in both A and literal 16. Save the result in A and update Z and N;
; carry is unchanged.
 beq release ; Branch if zero/equal (Z=1).
; Book line 285: Branch to release if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts ; Return to caller.
; Book line 286: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ============================================================================
; WHAT: Wait for a new fire press
; WHY: Give the player control over start and restart
; HOW: Poll each frame, cycle title ship colour and return when joy bit 4 is low.
; ============================================================================
waitfire:
; Book line 293: waitfire names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr frame ; Call frame; RTS returns here.
; Book line 294: Call frame, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 jsr readkeys ; Call readkeys; RTS returns here.
; Book line 295: Call readkeys, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 inc anim ; Increase byte by one; wraps at 0/255.
; Book line 296: Increase the byte at anim by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 lda anim ; Read anim.
; Book line 297: Load A with the byte at anim. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #7 ; Keep only masked bits.
; Book line 298: Keep only bits set in both A and literal 7. Save the result in A and update Z and N;
; carry is unchanged.
 sta $d027 ; Write A to player individual sprite colour.
; Book line 299: Store A into the byte at $d027 (sprite 0 colour). The register and CPU flags are
; unchanged.
 lda joy ; Read joy.
; Book line 300: Load A with the byte at joy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #16 ; Keep only masked bits.
; Book line 301: Keep only bits set in both A and literal 16. Save the result in A and update Z and N;
; carry is unchanged.
 bne waitfire ; Branch if not zero/equal (Z=0).
; Book line 302: Branch to waitfire if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts ; Return to caller.
; Book line 303: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; WHAT: Draw the introduction and controls
; WHY: Explain the game before play
; HOW: Fixed high-resolution text on screen A plus a ship sprite; then release and waitfire.
; ============================================================================
title:
; Book line 311: title names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr clear ; Call clear; RTS returns here.
; Book line 312: Call clear, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda #$1c ; Load literal value into A.
; Book line 313: Load A with literal $1c (decimal 28). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d018 ; Write A to screen/font address selection.
; Book line 314: Store A into the byte at $d018 (VIC screen and font selection). The register and CPU
; flags are unchanged.
 lda #8 ; Load literal value into A.
; Book line 315: Load A with literal 8. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d016 ; Write A to horizontal mode and fine-scroll bits.
; Book line 316: Store A into the byte at $d016 (VIC horizontal control and fine scroll). The register
; and CPU flags are unchanged.
 lda #0 ; Load literal value into A.
; Book line 317: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 318: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 lda #<t1 ; Take low address byte.
; Book line 319: Load A with the low address byte of t1 as an immediate value. Z records a zero value;
; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 320: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>t1 ; Take high address byte.
; Book line 321: Load A with the high address byte of t1 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 322: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda #<($047f) ; Take low address byte.
; Book line 323: Load A with the low address byte of ($047f) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 324: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #>($047f) ; Take high address byte.
; Book line 325: Load A with the high address byte of ($047f) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 326: Store A into the byte at $fe. The register and CPU flags are unchanged.
 jsr print ; Call print; RTS returns here.
; Book line 327: Call print, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda #<t2 ; Take low address byte.
; Book line 328: Load A with the low address byte of t2 as an immediate value. Z records a zero value;
; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 329: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>t2 ; Take high address byte.
; Book line 330: Load A with the high address byte of t2 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 331: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda #<($04d0) ; Take low address byte.
; Book line 332: Load A with the low address byte of ($04d0) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 333: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #>($04d0) ; Take high address byte.
; Book line 334: Load A with the high address byte of ($04d0) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 335: Store A into the byte at $fe. The register and CPU flags are unchanged.
 jsr print ; Call print; RTS returns here.
; Book line 336: Call print, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda #<t3 ; Take low address byte.
; Book line 337: Load A with the low address byte of t3 as an immediate value. Z records a zero value;
; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 338: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>t3 ; Take high address byte.
; Book line 339: Load A with the high address byte of t3 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 340: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda #<($056c) ; Take low address byte.
; Book line 341: Load A with the low address byte of ($056c) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 342: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #>($056c) ; Take high address byte.
; Book line 343: Load A with the high address byte of ($056c) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 344: Store A into the byte at $fe. The register and CPU flags are unchanged.
 jsr print ; Call print; RTS returns here.
; Book line 345: Call print, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda #<t4 ; Take low address byte.
; Book line 346: Load A with the low address byte of t4 as an immediate value. Z records a zero value;
; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 347: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>t4 ; Take high address byte.
; Book line 348: Load A with the high address byte of t4 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 349: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda #<($05e6) ; Take low address byte.
; Book line 350: Load A with the low address byte of ($05e6) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 351: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #>($05e6) ; Take high address byte.
; Book line 352: Load A with the high address byte of ($05e6) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 353: Store A into the byte at $fe. The register and CPU flags are unchanged.
 jsr print ; Call print; RTS returns here.
; Book line 354: Call print, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda #<t5 ; Take low address byte.
; Book line 355: Load A with the low address byte of t5 as an immediate value. Z records a zero value;
; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 356: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>t5 ; Take high address byte.
; Book line 357: Load A with the high address byte of t5 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 358: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda #<($0635) ; Take low address byte.
; Book line 359: Load A with the low address byte of ($0635) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 360: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #>($0635) ; Take high address byte.
; Book line 361: Load A with the high address byte of ($0635) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 362: Store A into the byte at $fe. The register and CPU flags are unchanged.
 jsr print ; Call print; RTS returns here.
; Book line 363: Call print, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda #<t6 ; Take low address byte.
; Book line 364: Load A with the low address byte of t6 as an immediate value. Z records a zero value;
; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 365: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>t6 ; Take high address byte.
; Book line 366: Load A with the high address byte of t6 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 367: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda #<($06ac) ; Take low address byte.
; Book line 368: Load A with the low address byte of ($06ac) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 369: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #>($06ac) ; Take high address byte.
; Book line 370: Load A with the high address byte of ($06ac) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 371: Store A into the byte at $fe. The register and CPU flags are unchanged.
 jsr print ; Call print; RTS returns here.
; Book line 372: Call print, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda #<t7 ; Take low address byte.
; Book line 373: Load A with the low address byte of t7 as an immediate value. Z records a zero value;
; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 374: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>t7 ; Take high address byte.
; Book line 375: Load A with the high address byte of t7 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 376: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda #<($0728) ; Take low address byte.
; Book line 377: Load A with the low address byte of ($0728) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 378: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #>($0728) ; Take high address byte.
; Book line 379: Load A with the high address byte of ($0728) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 380: Store A into the byte at $fe. The register and CPU flags are unchanged.
 jsr print ; Call print; RTS returns here.
; Book line 381: Call print, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda #<t8 ; Take low address byte.
; Book line 382: Load A with the low address byte of t8 as an immediate value. Z records a zero value;
; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 383: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>t8 ; Take high address byte.
; Book line 384: Load A with the high address byte of t8 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 385: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda #<($079d) ; Take low address byte.
; Book line 386: Load A with the low address byte of ($079d) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 387: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #>($079d) ; Take high address byte.
; Book line 388: Load A with the high address byte of ($079d) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 389: Store A into the byte at $fe. The register and CPU flags are unchanged.
 jsr print ; Call print; RTS returns here.
; Book line 390: Call print, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda #$a0 ; Load literal value into A.
; Book line 391: Load A with literal $a0 (decimal 160). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $07f8
; Book line 392: Store A into the byte at $07f8 (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
 lda #180 ; Load literal value into A.
; Book line 393: Load A with literal 180. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d000
; Book line 394: Store A into the byte at $d000 (sprite 0 X low byte). The register and CPU flags are
; unchanged.
 lda #105 ; Load literal value into A.
; Book line 395: Load A with literal 105. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d001
; Book line 396: Store A into the byte at $d001 (sprite 0 Y coordinate). The register and CPU flags
; are unchanged.
 lda #3 ; Load literal value into A.
; Book line 397: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d027 ; Write A to player individual sprite colour.
; Book line 398: Store A into the byte at $d027 (sprite 0 colour). The register and CPU flags are
; unchanged.
 lda #1 ; Load literal value into A.
; Book line 399: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 400: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 jsr release ; Call release; RTS returns here.
; Book line 401: Call release, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr waitfire ; Call waitfire; RTS returns here.
; Book line 402: Call waitfire, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.

; ============================================================================
; WHAT: Prepare a complete run while hidden
; WHY: Visible terrain generation caused yellow flashes and fast jerky motion
; HOW: Release fire, turn display off, reset state, build 40 columns, copy buffers, set
; colours/pointers/HUD and reveal on a frame boundary.
; ============================================================================
newgame:
; Book line 410: newgame names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ; Keep the intro visible until fire is released, then build offscreen.
 jsr release ; Call release; RTS returns here.
; Book line 412: Call release, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr raster_off ; Call raster_off; RTS returns here.
; Book line 413: Call raster_off, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda #$0b ; DEN off: never display partially generated terrain/colour RAM
; Book line 414: Load A with literal $0b (decimal 11). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d011 ; Write A to display enable and vertical control.
; Book line 415: Store A into the byte at $d011 (VIC vertical control and raster high bit). The
; register and CPU flags are unchanged.
 lda #0 ; Load literal value into A.
; Book line 416: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 417: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 jsr clear ; Call clear; RTS returns here.
; Book line 418: Call clear, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda #0 ; Load literal value into A.
; Book line 419: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta scorelo ; Store scorelo.
; Book line 420: Store A into the byte at scorelo (score low byte). The register and CPU flags are
; unchanged.
 sta scorehi ; Store scorehi.
; Book line 421: Store A into the byte at scorehi (score high byte). The register and CPU flags are
; unchanged.
 sta ticks ; Store ticks.
; Book line 422: Store A into the byte at ticks (frame clock). The register and CPU flags are
; unchanged.
 sta phase ; Store phase.
; Book line 423: Store A into the byte at phase. The register and CPU flags are unchanged.
 sta opening_col ; Store opening_col.
; Book line 424: Store A into the byte at opening_col. The register and CPU flags are unchanged.
 sta back ; Store back.
; Book line 425: Store A into the byte at back (screen buffer selection). The register and CPU flags
; are unchanged.
 sta shot ; Store shot.
; Book line 426: Store A into the byte at shot. The register and CPU flags are unchanged.
 sta bomb ; Store bomb.
; Book line 427: Store A into the byte at bomb. The register and CPU flags are unchanged.
 sta distance ; Store distance.
; Book line 428: Store A into the byte at distance. The register and CPU flags are unchanged.
 sta stage ; Store stage.
; Book line 429: Store A into the byte at stage. The register and CPU flags are unchanged.
 sta dead ; Store dead.
; Book line 430: Store A into the byte at dead. The register and CPU flags are unchanged.
 sta firecool ; Store firecool.
; Book line 431: Store A into the byte at firecool. The register and CPU flags are unchanged.
 sta soundtimer ; Store soundtimer.
; Book line 432: Store A into the byte at soundtimer. The register and CPU flags are unchanged.
 sta invulnerable ; Store invulnerable.
; Book line 433: Store A into the byte at invulnerable. The register and CPU flags are unchanged.
 lda #3 ; Load literal value into A.
; Book line 434: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta lives ; Store lives.
; Book line 435: Store A into the byte at lives (remaining lives). The register and CPU flags are
; unchanged.
 lda #$a7 ; Load literal value into A.
; Book line 436: Load A with literal $a7 (decimal 167). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta seed ; Store seed.
; Book line 437: Store A into the byte at seed. The register and CPU flags are unchanged.
 lda #200 ; Load literal value into A.
; Book line 438: Load A with literal 200. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta fuel ; Store fuel.
; Book line 439: Store A into the byte at fuel (fuel in half-percent units). The register and CPU
; flags are unchanged.
 lda #80 ; Load literal value into A.
; Book line 440: Load A with literal 80. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipx ; Store shipx.
; Book line 441: Store A into the byte at shipx (ship X low byte). The register and CPU flags are
; unchanged.
 lda #130 ; Load literal value into A.
; Book line 442: Load A with literal 130. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipy ; Store shipy.
; Book line 443: Store A into the byte at shipy (ship Y). The register and CPU flags are unchanged.
 lda #7 ; Load literal value into A.
; Book line 444: Load A with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta fine ; Store fine.
; Book line 445: Store A into the byte at fine (horizontal fine scroll offset). The register and CPU
; flags are unchanged.
 lda #$17 ; Load literal value into A.
; Book line 446: Load A with literal $17 (decimal 23). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d016 ; Write A to horizontal mode and fine-scroll bits.
; Book line 447: Store A into the byte at $d016 (VIC horizontal control and fine scroll). The register
; and CPU flags are unchanged.
 lda #$1c ; Load literal value into A.
; Book line 448: Load A with literal $1c (decimal 28). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d018 ; Write A to screen/font address selection.
; Book line 449: Store A into the byte at $d018 (VIC screen and font selection). The register and CPU
; flags are unchanged.
 lda #$04 ; Load literal value into A.
; Book line 450: Load A with literal $04 (decimal 4). Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 451: Store A into the byte at $fe. The register and CPU flags are unchanged.
 lda #0 ; Load literal value into A.
; Book line 452: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 453: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #40 ; Load literal value into A.
; Book line 454: Load A with literal 40. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta initcols ; Store initcols.
; Book line 455: Store A into the byte at initcols. The register and CPU flags are unchanged.

; ============================================================================
; WHAT: Generate consecutive opening columns
; WHY: A duplicated final column caused a startup seam
; HOW: Shift BEFORE adding each column. Back=0 makes column write to hidden screen B.
; ============================================================================
fillinitial:
; Book line 462: fillinitial names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr shift_initial ; Call shift_initial; RTS returns here.
; Book line 463: Call shift_initial, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr column ; Call column; RTS returns here.
; Book line 464: Call column, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 dec initcols ; Decrease byte by one; wraps at 0/255.
; Book line 465: Decrease the byte at initcols by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 bne fillinitial ; Branch if not zero/equal (Z=0).
; Book line 466: Branch to fillinitial if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ; Copy completed landscape into the second screen.
 ldx #0 ; Load literal value into X.
; Book line 468: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.

; ============================================================================
; WHAT: Synchronise completed screens
; WHY: A swap must reveal the same ready landscape
; HOW: Copy B at $0c00 to A at $0400. Sprite pointers are installed after the copy.
; ============================================================================
copyinitial:
; Book line 475: copyinitial names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda $0c00,x ; Read indexed table or screen entry.
; Book line 476: Load A with the byte at $0c00 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0400,x
; Book line 477: Store A into the byte at $0400 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 lda $0d00,x ; Read indexed table or screen entry.
; Book line 478: Load A with the byte at $0d00 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0500,x
; Book line 479: Store A into the byte at $0500 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 lda $0e00,x ; Read indexed table or screen entry.
; Book line 480: Load A with the byte at $0e00 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0600,x
; Book line 481: Store A into the byte at $0600 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 lda $0f00,x ; Read indexed table or screen entry.
; Book line 482: Load A with the byte at $0f00 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0700,x
; Book line 483: Store A into the byte at $0700 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 inx ; Next X index; 255 wraps to zero.
; Book line 484: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne copyinitial ; Branch if not zero/equal (Z=0).
; Book line 485: Branch to copyinitial if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ldx #0 ; Load literal value into X.
; Book line 486: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.

; ============================================================================
; WHAT: Choose sprite artwork and colours
; WHY: Every screen buffer has its own sprite pointers
; HOW: Install all eight pointers in both tables. Pointer $a0 times 64 means image $2800.
; ============================================================================
ptrs:
; Book line 493: ptrs names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda spriteptrs,x ; Read indexed table or screen entry.
; Book line 494: Load A with the byte at spriteptrs plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta $07f8,x
; Book line 495: Store A into the byte at $07f8 (sprite pointer table in the $0400 screen) plus index
; X. The register and CPU flags are unchanged.
 sta $0ff8,x
; Book line 496: Store A into the byte at $0ff8 plus index X. The register and CPU flags are
; unchanged.
 lda spritecolors,x ; Read indexed table or screen entry.
; Book line 497: Load A with the byte at spritecolors plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $d027,x
; Book line 498: Store A into the byte at $d027 (sprite 0 colour) plus index X. The register and CPU
; flags are unchanged.
 inx ; Next X index; 255 wraps to zero.
; Book line 499: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #8 ; Compare; change flags, preserve register.
; Book line 500: Compare X with literal 8 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne ptrs ; Branch if not zero/equal (Z=0).
; Book line 501: Branch to ptrs if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jsr colors ; Call colors; RTS returns here.
; Book line 502: Call colors, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda #1 ; Load literal value into A.
; Book line 503: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 504: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 lda #0 ; Load literal value into A.
; Book line 505: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d010
; Book line 506: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
 sta spawncool ; Store spawncool.
; Book line 507: Store A into the byte at spawncool. The register and CPU flags are unchanged.
 ldx #7 ; Load literal value into X.
; Book line 508: Load X with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.

; ============================================================================
; WHAT: Hide all empty target slots
; WHY: Uninitialised positions would produce stray sprites
; HOW: Clear activity, delay and position arrays. Only sprite 0 starts enabled.
; ============================================================================
reset_targets:
; Book line 515: reset_targets names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 sta active,x
; Book line 516: Store A into the byte at active (object activity table) plus index X. The register
; and CPU flags are unchanged.
 sta launchwait,x
; Book line 517: Store A into the byte at launchwait plus index X. The register and CPU flags are
; unchanged.
 sta ex,x
; Book line 518: Store A into the byte at ex plus index X. The register and CPU flags are unchanged.
 sta ey,x
; Book line 519: Store A into the byte at ey plus index X. The register and CPU flags are unchanged.
 dex ; Previous X index.
; Book line 520: Decrease X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bpl reset_targets ; Branch while bit 7 of last result is clear.
; Book line 521: Branch to reset_targets if N is 0 (bit 7 clear); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda $d01e
; Book line 522: Load A with the byte at $d01e. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 jsr hud ; Call hud; RTS returns here.
; Book line 523: Call hud, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda shipx ; Read shipx.
; Book line 524: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta $d000
; Book line 525: Store A into the byte at $d000 (sprite 0 X low byte). The register and CPU flags are
; unchanged.
 lda shipy ; Read shipy.
; Book line 526: Load A with the byte at shipy (ship Y). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d001
; Book line 527: Store A into the byte at $d001 (sprite 0 Y coordinate). The register and CPU flags
; are unchanged.
 ; Reveal the complete landscape on a frame boundary, then use the normal loop.
 jsr frame ; Call frame; RTS returns here.
; Book line 529: Call frame, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.

; ============================================================================
; WHAT: Show the finished landscape
; WHY: All visible data must agree at startup
; HOW: Enable the display and raster split; fall into the ordinary main loop, without a special
; fast scroll.
; ============================================================================
reveal_game:
; Book line 537: reveal_game names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #$1b ; Load literal value into A.
; Book line 538: Load A with literal $1b (decimal 27). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d011 ; Write A to display enable and vertical control.
; Book line 539: Store A into the byte at $d011 (VIC vertical control and raster high bit). The
; register and CPU flags are unchanged.
 jsr raster_on ; Call raster_on; RTS returns here.
; Book line 540: Call raster_on, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.

; ============================================================================
; WHAT: Update one game frame
; WHY: Scrolling input objects and collisions must agree on world position
; HOW: Wait for line 250; step fine scroll 7..0; swap buffers on wrap. At fine=3 prepare the
; next shifted screen, then process gameplay.
; ============================================================================
main:
; Book line 548: main names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr frame ; Call frame; RTS returns here.
; Book line 549: Call frame, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 lda fine ; Read fine.
; Book line 550: Load A with the byte at fine (horizontal fine scroll offset). Z records a zero value;
; N copies bit 7. Carry is unchanged.
 bne fine_dec ; Branch if not zero/equal (Z=0).
; Book line 551: Branch to fine_dec if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #7 ; Load literal value into A.
; Book line 552: Load A with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta fine ; Store fine.
; Book line 553: Store A into the byte at fine (horizontal fine scroll offset). The register and CPU
; flags are unchanged.
 lda back ; Read back.
; Book line 554: Load A with the byte at back (screen buffer selection). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 eor #8 ; Toggle the mask bits with XOR.
; Book line 555: Toggle A bits selected by literal 8. Save the result in A and update Z and N; carry
; is unchanged.
 sta back ; Store back.
; Book line 556: Store A into the byte at back (screen buffer selection). The register and CPU flags
; are unchanged.
 beq screen_a ; Branch if zero/equal (Z=1).
; Book line 557: Branch to screen_a if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #$3c ; Load literal value into A.
; Book line 558: Load A with literal $3c (decimal 60). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne screen_set ; Branch if not zero/equal (Z=0).
; Book line 559: Branch to screen_set if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
screen_a:
; Book line 560: screen_a names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #$1c ; Load literal value into A.
; Book line 561: Load A with literal $1c (decimal 28). Z records a zero value; N copies bit 7. Carry
; is unchanged.
screen_set:
; Book line 562: screen_set names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sta $d018 ; Write A to screen/font address selection.
; Book line 563: Store A into the byte at $d018 (VIC screen and font selection). The register and CPU
; flags are unchanged.
 jsr patchcopy ; Call patchcopy; RTS returns here.
; Book line 564: Call patchcopy, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jmp scroll_done ; Continue at scroll_done without a return address.
; Book line 565: Continue execution at scroll_done without saving a return address. Registers and
; flags are unchanged by the jump itself.
fine_dec:
; Book line 566: fine_dec names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 dec fine ; Decrease byte by one; wraps at 0/255.
; Book line 567: Decrease the byte at fine (horizontal fine scroll offset) by one with 8-bit
; wraparound. Update Z and N; carry is unchanged.
scroll_done:
; Book line 568: scroll_done names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda fine ; Read fine.
; Book line 569: Load A with the byte at fine (horizontal fine scroll offset). Z records a zero value;
; N copies bit 7. Carry is unchanged.
 cmp #3 ; Compare; change flags, preserve register.
; Book line 570: Compare A with literal 3 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne no_copy ; Branch if not zero/equal (Z=0).
; Book line 571: Branch to no_copy if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jsr coarse ; Call coarse; RTS returns here.
; Book line 572: Call coarse, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr column ; Call column; RTS returns here.
; Book line 573: Call column, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 inc distance ; Increase byte by one; wraps at 0/255.
; Book line 574: Increase the byte at distance by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 lda distance ; Read distance.
; Book line 575: Load A with the byte at distance. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #127 ; Keep only masked bits.
; Book line 576: Keep only bits set in both A and literal 127. Save the result in A and update Z and
; N; carry is unchanged.
 bne no_copy ; Branch if not zero/equal (Z=0).
; Book line 577: Branch to no_copy if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inc stage ; Increase byte by one; wraps at 0/255.
; Book line 578: Increase the byte at stage by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
no_copy:
; Book line 579: no_copy names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr readkeys ; Call readkeys; RTS returns here.
; Book line 580: Call readkeys, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr move ; Call move; RTS returns here.
; Book line 581: Call move, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 jsr weapons ; Call weapons; RTS returns here.
; Book line 582: Call weapons, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr enemies ; Call enemies; RTS returns here.
; Book line 583: Call enemies, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr hits ; Call hits; RTS returns here.
; Book line 584: Call hits, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 jsr protection ; Call protection; RTS returns here.
; Book line 585: Call protection, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jsr hud ; Call hud; RTS returns here.
; Book line 586: Call hud, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 jsr audio ; Call audio; RTS returns here.
; Book line 587: Call audio, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 inc ticks ; Increase byte by one; wraps at 0/255.
; Book line 588: Increase the byte at ticks (frame clock) by one with 8-bit wraparound. Update Z and
; N; carry is unchanged.
 jsr drain_fuel ; Call drain_fuel; RTS returns here.
; Book line 589: Call drain_fuel, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
fuelok:
; Book line 590: fuelok names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda dead ; Read dead.
; Book line 591: Load A with the byte at dead. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq main_alive ; Branch if zero/equal (Z=1).
; Book line 592: Branch to main_alive if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp lose_life ; Continue at lose_life without a return address.
; Book line 593: Continue execution at lose_life without saving a return address. Registers and flags
; are unchanged by the jump itself.
main_alive:
; Book line 594: main_alive names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jmp main ; Continue at main without a return address.
; Book line 595: Continue execution at main without saving a return address. Registers and flags are
; unchanged by the jump itself.

 ; One unit every eight PAL frames: a full tank lasts about 32 seconds.

; ============================================================================
; WHAT: Drain half-percent tank units
; WHY: The HUD should show steady consumption
; HOW: Every eighth tick subtract one unit; zero requests a death. 200 units lasts about 1600
; PAL frames or 32 seconds.
; ============================================================================
drain_fuel:
; Book line 605: drain_fuel names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda ticks ; Read ticks.
; Book line 606: Load A with the byte at ticks (frame clock). Z records a zero value; N copies bit 7.
; Carry is unchanged.
 and #7 ; Keep only masked bits.
; Book line 607: Keep only bits set in both A and literal 7. Save the result in A and update Z and N;
; carry is unchanged.
 bne fuel_done ; Branch if not zero/equal (Z=0).
; Book line 608: Branch to fuel_done if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda fuel ; Read fuel.
; Book line 609: Load A with the byte at fuel (fuel in half-percent units). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 beq emptyfuel ; Branch if zero/equal (Z=1).
; Book line 610: Branch to emptyfuel if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec fuel ; Decrease byte by one; wraps at 0/255.
; Book line 611: Decrease the byte at fuel (fuel in half-percent units) by one with 8-bit wraparound.
; Update Z and N; carry is unchanged.
 bne fuel_done ; Branch if not zero/equal (Z=0).
; Book line 612: Branch to fuel_done if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
emptyfuel:
; Book line 613: emptyfuel names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 inc dead ; Increase byte by one; wraps at 0/255.
; Book line 614: Increase the byte at dead by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
fuel_done:
; Book line 615: fuel_done names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 rts ; Return to caller.
; Book line 616: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Split at raster 48/66: crisp stationary 40-column HUD, multicolour playfield.
; A-only IRQ leaves main-loop X/Y and all zero-page pointers untouched.

; ============================================================================
; WHAT: Start the HUD split IRQ
; WHY: The HUD must not scroll with the terrain
; HOW: Schedule raster 48, acknowledge pending request, enable VIC IRQ bit 0 and CLI. CIA IRQ
; sources remain off.
; ============================================================================
raster_on:
; Book line 627: raster_on names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sei ; Mask ordinary CPU IRQs.
; Book line 628: Set the interrupt-disable flag to mask ordinary IRQ handling. NMI is not masked, and
; peripheral interrupt sources are not automatically cleared.
 lda #0 ; Load literal value into A.
; Book line 629: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta irq_phase ; Store irq_phase.
; Book line 630: Store A into the byte at irq_phase. The register and CPU flags are unchanged.
 lda #48 ; Load literal value into A.
; Book line 631: Load A with literal 48. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d012 ; Write A to raster line read / IRQ compare write.
; Book line 632: Store A into the byte at $d012 (VIC raster counter or IRQ compare). The register and
; CPU flags are unchanged.
 lda #1 ; Load literal value into A.
; Book line 633: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d019 ; Write A to VIC interrupt flags (write one to acknowledge).
; Book line 634: Store A into the byte at $d019 (VIC interrupt request flags). The register and CPU
; flags are unchanged. For this register, writing a 1 acknowledges the corresponding pending VIC IRQ
; flag.
 sta $d01a ; Write A to VIC interrupt enable.
; Book line 635: Store A into the byte at $d01a (VIC interrupt enables). The register and CPU flags
; are unchanged.
 cli ; Allow CPU IRQs.
; Book line 636: Clear the interrupt-disable flag to permit ordinary IRQ handling once the CPU
; recognises an eligible request. The handler and vectors must already be ready.
 rts ; Return to caller.
; Book line 637: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ============================================================================
; WHAT: Stop the raster split
; WHY: Static screens need stable mode settings
; HOW: SEI, disable VIC IRQs and acknowledge the pending raster flag. This does not restore the
; KERNAL.
; ============================================================================
raster_off:
; Book line 645: raster_off names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sei ; Mask ordinary CPU IRQs.
; Book line 646: Set the interrupt-disable flag to mask ordinary IRQ handling. NMI is not masked, and
; peripheral interrupt sources are not automatically cleared.
 lda #0 ; Load literal value into A.
; Book line 647: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d01a ; Write A to VIC interrupt enable.
; Book line 648: Store A into the byte at $d01a (VIC interrupt enables). The register and CPU flags
; are unchanged.
 lda #1 ; Load literal value into A.
; Book line 649: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d019 ; Write A to VIC interrupt flags (write one to acknowledge).
; Book line 650: Store A into the byte at $d019 (VIC interrupt request flags). The register and CPU
; flags are unchanged. For this register, writing a 1 acknowledges the corresponding pending VIC IRQ
; flag.
 rts ; Return to caller.
; Book line 651: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ============================================================================
; WHAT: Separate fixed HUD from moving cave
; WHY: One D016 setting would make HUD text jerk sideways
; HOW: At line 48 use D016=$08; at line 66 use fine OR $10. Schedule the other line and
; acknowledge D019. Saves only A because X/Y and pointers are untouched.
; ============================================================================
raster_irq:
; Book line 659: raster_irq names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 pha ; Push A on the CPU stack.
; Book line 660: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 lda irq_phase ; Read irq_phase.
; Book line 661: Load A with the byte at irq_phase. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bne irq_field ; Branch if not zero/equal (Z=0).
; Book line 662: Branch to irq_field if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #8 ; Load literal value into A.
; Book line 663: Load A with literal 8. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d016 ; Write A to horizontal mode and fine-scroll bits.
; Book line 664: Store A into the byte at $d016 (VIC horizontal control and fine scroll). The register
; and CPU flags are unchanged.
 lda #66 ; Load literal value into A.
; Book line 665: Load A with literal 66. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d012 ; Write A to raster line read / IRQ compare write.
; Book line 666: Store A into the byte at $d012 (VIC raster counter or IRQ compare). The register and
; CPU flags are unchanged.
 lda #1 ; Load literal value into A.
; Book line 667: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta irq_phase ; Store irq_phase.
; Book line 668: Store A into the byte at irq_phase. The register and CPU flags are unchanged.
 bne irq_ack ; Branch if not zero/equal (Z=0).
; Book line 669: Branch to irq_ack if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
irq_field:
; Book line 670: irq_field names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda fine ; Read fine.
; Book line 671: Load A with the byte at fine (horizontal fine scroll offset). Z records a zero value;
; N copies bit 7. Carry is unchanged.
 ora #$10 ; Set selected bits, preserving others.
; Book line 672: Set A bits present in either A or literal $10 (decimal 16). Save the result in A and
; update Z and N; carry is unchanged.
 sta $d016 ; Write A to horizontal mode and fine-scroll bits.
; Book line 673: Store A into the byte at $d016 (VIC horizontal control and fine scroll). The register
; and CPU flags are unchanged.
 lda #48 ; Load literal value into A.
; Book line 674: Load A with literal 48. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d012 ; Write A to raster line read / IRQ compare write.
; Book line 675: Store A into the byte at $d012 (VIC raster counter or IRQ compare). The register and
; CPU flags are unchanged.
 lda #0 ; Load literal value into A.
; Book line 676: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta irq_phase ; Store irq_phase.
; Book line 677: Store A into the byte at irq_phase. The register and CPU flags are unchanged.
irq_ack:
; Book line 678: irq_ack names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #1 ; Load literal value into A.
; Book line 679: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d019 ; Write A to VIC interrupt flags (write one to acknowledge).
; Book line 680: Store A into the byte at $d019 (VIC interrupt request flags). The register and CPU
; flags are unchanged. For this register, writing a 1 acknowledges the corresponding pending VIC IRQ
; flag.
 pla ; Pull saved byte back into A.
; Book line 681: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
nmi_return:
; Book line 682: nmi_return names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 rti ; Restore interrupted status and program counter.
; Book line 683: Restore processor status and the interrupted program counter from the stack. Resume
; interrupted execution; this is the IRQ or NMI return.


; ============================================================================
; WHAT: Count and flash the respawn shield
; WHY: Immunity must expire with a visible ship
; HOW: Count 150 frames, clear damage while protected, blink sprite 0 with ticks bit 2, and
; always enable sprite 0 at expiry. Terrain blocking is separate in move.
; ============================================================================
protection:
; Book line 692: protection names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ; Restore visibility even if the shield ended on a hidden flash frame.
 lda invulnerable ; Read invulnerable.
; Book line 694: Load A with the byte at invulnerable. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 beq ship_visible ; Branch if zero/equal (Z=1).
; Book line 695: Branch to ship_visible if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec invulnerable ; Decrease byte by one; wraps at 0/255.
; Book line 696: Decrease the byte at invulnerable by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
 beq shield_finished ; Branch if zero/equal (Z=1).
; Book line 697: Branch to shield_finished if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #0 ; Load literal value into A.
; Book line 698: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta dead ; Store dead.
; Book line 699: Store A into the byte at dead. The register and CPU flags are unchanged.
 lda ticks ; Read ticks.
; Book line 700: Load A with the byte at ticks (frame clock). Z records a zero value; N copies bit 7.
; Carry is unchanged.
 and #4 ; Keep only masked bits.
; Book line 701: Keep only bits set in both A and literal 4. Save the result in A and update Z and N;
; carry is unchanged.
 beq ship_visible ; Branch if zero/equal (Z=1).
; Book line 702: Branch to ship_visible if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda $d015 ; Read sprite enable bits.
; Book line 703: Load A with the byte at $d015 (VIC sprite enable bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$fe ; Keep only masked bits.
; Book line 704: Keep only bits set in both A and literal $fe (decimal 254). Save the result in A and
; update Z and N; carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 705: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 rts ; Return to caller.
; Book line 706: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
shield_finished:
; Book line 707: shield_finished names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #0 ; Load literal value into A.
; Book line 708: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta dead ; Store dead.
; Book line 709: Store A into the byte at dead. The register and CPU flags are unchanged.
ship_visible:
; Book line 710: ship_visible names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda $d015 ; Read sprite enable bits.
; Book line 711: Load A with the byte at $d015 (VIC sprite enable bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ora #1 ; Set selected bits, preserving others.
; Book line 712: Set A bits present in either A or literal 1. Save the result in A and update Z and N;
; carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 713: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
protected_done:
; Book line 714: protected_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 rts ; Return to caller.
; Book line 715: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; WHAT: Remove exactly one life
; WHY: Continuous contact must not subtract a life every frame
; HOW: Pause updates for a flash/noise effect, decrement lives, then respawn or gameover.
; ============================================================================
lose_life:
; Book line 723: lose_life names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #$81 ; Load literal value into A.
; Book line 724: Load A with literal $81 (decimal 129). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d40b ; Write A to SID voice 2 control/gate.
; Book line 725: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
 lda #8 ; Load literal value into A.
; Book line 726: Load A with literal 8. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d408
; Book line 727: Store A into the byte at $d408 (SID voice 2 frequency high). The register and CPU
; flags are unchanged.
 ldx #30 ; Load literal value into X.
; Book line 728: Load X with literal 30. Z records a zero value; N copies bit 7. Carry is unchanged.
life_flash:
; Book line 729: life_flash names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr frame ; Call frame; RTS returns here.
; Book line 730: Call frame, saving a return address on the stack. Its RTS resumes after this call. A,
; X, Y and flags are not automatically preserved by a call.
 txa ; Copy X to A.
; Book line 731: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
 and #7 ; Keep only masked bits.
; Book line 732: Keep only bits set in both A and literal 7. Save the result in A and update Z and N;
; carry is unchanged.
 sta $d027 ; Write A to player individual sprite colour.
; Book line 733: Store A into the byte at $d027 (sprite 0 colour). The register and CPU flags are
; unchanged.
 dex ; Previous X index.
; Book line 734: Decrease X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne life_flash ; Branch if not zero/equal (Z=0).
; Book line 735: Branch to life_flash if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec lives ; Decrease byte by one; wraps at 0/255.
; Book line 736: Decrease the byte at lives (remaining lives) by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
 bne respawn_ship ; Branch if not zero/equal (Z=0).
; Book line 737: Branch to respawn_ship if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp gameover ; Continue at gameover without a return address.
; Book line 738: Continue execution at gameover without saving a return address. Registers and flags
; are unchanged by the jump itself.

; ============================================================================
; WHAT: Restore the next ship
; WHY: Avoid an immediate repeat death
; HOW: Clear projectiles, reset ship to 80,130, refill the life-start tank and grant a shield.
; Preserve target enable bits; depot refills are separately only 25 percentage points.
; ============================================================================
respawn_ship:
; Book line 746: respawn_ship names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #0 ; Load literal value into A.
; Book line 747: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta dead ; Store dead.
; Book line 748: Store A into the byte at dead. The register and CPU flags are unchanged.
 sta shot ; Store shot.
; Book line 749: Store A into the byte at shot. The register and CPU flags are unchanged.
 sta bomb ; Store bomb.
; Book line 750: Store A into the byte at bomb. The register and CPU flags are unchanged.
 sta $d404 ; Write A to SID voice 1 control/gate.
; Book line 751: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
 sta $d40b ; Write A to SID voice 2 control/gate.
; Book line 752: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
 lda #200 ; Load literal value into A.
; Book line 753: Load A with literal 200. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta fuel ; Store fuel.
; Book line 754: Store A into the byte at fuel (fuel in half-percent units). The register and CPU
; flags are unchanged.
 lda #80 ; Load literal value into A.
; Book line 755: Load A with literal 80. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipx ; Store shipx.
; Book line 756: Store A into the byte at shipx (ship X low byte). The register and CPU flags are
; unchanged.
 sta $d000
; Book line 757: Store A into the byte at $d000 (sprite 0 X low byte). The register and CPU flags are
; unchanged.
 lda #130 ; Load literal value into A.
; Book line 758: Load A with literal 130. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipy ; Store shipy.
; Book line 759: Store A into the byte at shipy (ship Y). The register and CPU flags are unchanged.
 sta $d001
; Book line 760: Store A into the byte at $d001 (sprite 0 Y coordinate). The register and CPU flags
; are unchanged.
 lda #150 ; Load literal value into A.
; Book line 761: Load A with literal 150. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta invulnerable ; Store invulnerable.
; Book line 762: Store A into the byte at invulnerable. The register and CPU flags are unchanged.
 lda $d015 ; Read sprite enable bits.
; Book line 763: Load A with the byte at $d015 (VIC sprite enable bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$f9 ; Keep only masked bits.
; Book line 764: Keep only bits set in both A and literal $f9 (decimal 249). Save the result in A and
; update Z and N; carry is unchanged.
 ora #1 ; Set selected bits, preserving others.
; Book line 765: Set A bits present in either A or literal 1. Save the result in A and update Z and N;
; carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 766: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 lda #3 ; Load literal value into A.
; Book line 767: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d027 ; Write A to player individual sprite colour.
; Book line 768: Store A into the byte at $d027 (sprite 0 colour). The register and CPU flags are
; unchanged.
 jmp main ; Continue at main without a return address.
; Book line 769: Continue execution at main without saving a return address. Registers and flags are
; unchanged by the jump itself.


; ============================================================================
; WHAT: Apply controls and resolve terrain
; WHY: Shielding should prevent damage, not make rock passable
; HOW: Save old position; apply two-pixel steps with bounds; test hull. Contact kills normally
; or rejects movement during protection.
; ============================================================================
move:
; Book line 778: move names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda shipx ; Read shipx.
; Book line 779: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta oldshipx ; Store oldshipx.
; Book line 780: Store A into the byte at oldshipx. The register and CPU flags are unchanged.
 lda shipy ; Read shipy.
; Book line 781: Load A with the byte at shipy (ship Y). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta oldshipy ; Store oldshipy.
; Book line 782: Store A into the byte at oldshipy. The register and CPU flags are unchanged.
 lda joy ; Read joy.
; Book line 783: Load A with the byte at joy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #1 ; Keep only masked bits.
; Book line 784: Keep only bits set in both A and literal 1. Save the result in A and update Z and N;
; carry is unchanged.
 beq up ; Branch if zero/equal (Z=1).
; Book line 785: Branch to up if Z is 1 (zero or equal); otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 lda keys1 ; Read keys1.
; Book line 786: Load A with the byte at keys1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #2 ; Keep only masked bits.
; Book line 787: Keep only bits set in both A and literal 2. Save the result in A and update Z and N;
; carry is unchanged.
 bne noup ; Branch if not zero/equal (Z=0).
; Book line 788: Branch to noup if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
up:
; Book line 789: up names this assembled address; it emits no bytes and provides a jump, call or data
; reference target.
 lda shipy ; Read shipy.
; Book line 790: Load A with the byte at shipy (ship Y). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 cmp #77 ; Compare; change flags, preserve register.
; Book line 791: Compare A with literal 77 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc noup ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 792: Branch to noup if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 dec shipy ; Decrease byte by one; wraps at 0/255.
; Book line 793: Decrease the byte at shipy (ship Y) by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
 dec shipy ; Decrease byte by one; wraps at 0/255.
; Book line 794: Decrease the byte at shipy (ship Y) by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
noup:
; Book line 795: noup names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda joy ; Read joy.
; Book line 796: Load A with the byte at joy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #2 ; Keep only masked bits.
; Book line 797: Keep only bits set in both A and literal 2. Save the result in A and update Z and N;
; carry is unchanged.
 beq down ; Branch if zero/equal (Z=1).
; Book line 798: Branch to down if Z is 1 (zero or equal); otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 lda keys1 ; Read keys1.
; Book line 799: Load A with the byte at keys1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #32 ; Keep only masked bits.
; Book line 800: Keep only bits set in both A and literal 32. Save the result in A and update Z and N;
; carry is unchanged.
 bne nodown ; Branch if not zero/equal (Z=0).
; Book line 801: Branch to nodown if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
down:
; Book line 802: down names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda shipy ; Read shipy.
; Book line 803: Load A with the byte at shipy (ship Y). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 cmp #218 ; Compare; change flags, preserve register.
; Book line 804: Compare A with literal 218 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs nodown ; Branch if C=1; after compare, value was at least as large.
; Book line 805: Branch to nodown if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 inc shipy ; Increase byte by one; wraps at 0/255.
; Book line 806: Increase the byte at shipy (ship Y) by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
 inc shipy ; Increase byte by one; wraps at 0/255.
; Book line 807: Increase the byte at shipy (ship Y) by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
nodown:
; Book line 808: nodown names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda joy ; Read joy.
; Book line 809: Load A with the byte at joy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #4 ; Keep only masked bits.
; Book line 810: Keep only bits set in both A and literal 4. Save the result in A and update Z and N;
; carry is unchanged.
 beq left ; Branch if zero/equal (Z=1).
; Book line 811: Branch to left if Z is 1 (zero or equal); otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 lda keys1 ; Read keys1.
; Book line 812: Load A with the byte at keys1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #4 ; Keep only masked bits.
; Book line 813: Keep only bits set in both A and literal 4. Save the result in A and update Z and N;
; carry is unchanged.
 bne noleft ; Branch if not zero/equal (Z=0).
; Book line 814: Branch to noleft if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
left:
; Book line 815: left names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda shipx ; Read shipx.
; Book line 816: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 cmp #38 ; Compare; change flags, preserve register.
; Book line 817: Compare A with literal 38 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc noleft ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 818: Branch to noleft if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 dec shipx ; Decrease byte by one; wraps at 0/255.
; Book line 819: Decrease the byte at shipx (ship X low byte) by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
 dec shipx ; Decrease byte by one; wraps at 0/255.
; Book line 820: Decrease the byte at shipx (ship X low byte) by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
noleft:
; Book line 821: noleft names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda joy ; Read joy.
; Book line 822: Load A with the byte at joy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #8 ; Keep only masked bits.
; Book line 823: Keep only bits set in both A and literal 8. Save the result in A and update Z and N;
; carry is unchanged.
 beq right ; Branch if zero/equal (Z=1).
; Book line 824: Branch to right if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda keys2 ; Read keys2.
; Book line 825: Load A with the byte at keys2. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #4 ; Keep only masked bits.
; Book line 826: Keep only bits set in both A and literal 4. Save the result in A and update Z and N;
; carry is unchanged.
 bne noright ; Branch if not zero/equal (Z=0).
; Book line 827: Branch to noright if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
right:
; Book line 828: right names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda shipx ; Read shipx.
; Book line 829: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 cmp #218 ; Compare; change flags, preserve register.
; Book line 830: Compare A with literal 218 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs noright ; Branch if C=1; after compare, value was at least as large.
; Book line 831: Branch to noright if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 inc shipx ; Increase byte by one; wraps at 0/255.
; Book line 832: Increase the byte at shipx (ship X low byte) by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
 inc shipx ; Increase byte by one; wraps at 0/255.
; Book line 833: Increase the byte at shipx (ship X low byte) by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
noright:
; Book line 834: noright names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr ship_terrain ; Call ship_terrain; RTS returns here.
; Book line 835: Call ship_terrain, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 bcc render_ship ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 836: Branch to render_ship if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda invulnerable ; Read invulnerable.
; Book line 837: Load A with the byte at invulnerable. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne shield_block ; Branch if not zero/equal (Z=0).
; Book line 838: Branch to shield_block if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inc dead ; Increase byte by one; wraps at 0/255.
; Book line 839: Increase the byte at dead by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 jmp render_ship ; Continue at render_ship without a return address.
; Book line 840: Continue execution at render_ship without saving a return address. Registers and
; flags are unchanged by the jump itself.

; ============================================================================
; WHAT: Reject a shielded move into rock
; WHY: Clearing dead alone allowed underground flight
; HOW: Restore old coordinates. If scrolling rock also covers that point, push towards the open
; central flight lane.
; ============================================================================
shield_block:
; Book line 848: shield_block names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ; Damage immunity never makes terrain passable. Reject the player's move.
 lda oldshipx ; Read oldshipx.
; Book line 850: Load A with the byte at oldshipx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta shipx ; Store shipx.
; Book line 851: Store A into the byte at shipx (ship X low byte). The register and CPU flags are
; unchanged.
 lda oldshipy ; Read oldshipy.
; Book line 852: Load A with the byte at oldshipy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta shipy ; Store shipy.
; Book line 853: Store A into the byte at shipy (ship Y). The register and CPU flags are unchanged.
 jsr ship_terrain ; Call ship_terrain; RTS returns here.
; Book line 854: Call ship_terrain, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 bcc render_ship ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 855: Branch to render_ship if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 ; A scrolling slope can enter the old position. Push towards the clear
 ; middle of the flight corridor, rather than letting the shield clip in.

; ============================================================================
; WHAT: Resolve rock introduced by scrolling
; WHY: A stationary ship can meet a rising floor
; HOW: Move Y one pixel towards 130 and retest. This relies on the current level always leaving
; its centre lane clear.
; ============================================================================
shield_push:
; Book line 865: shield_push names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda shipy ; Read shipy.
; Book line 866: Load A with the byte at shipy (ship Y). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 cmp #130 ; Compare; change flags, preserve register.
; Book line 867: Compare A with literal 130 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq shield_safe ; Branch if zero/equal (Z=1).
; Book line 868: Branch to shield_safe if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 bcc shield_push_down ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 869: Branch to shield_push_down if C is 0; otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
 dec shipy ; Decrease byte by one; wraps at 0/255.
; Book line 870: Decrease the byte at shipy (ship Y) by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
 jmp shield_recheck ; Continue at shield_recheck without a return address.
; Book line 871: Continue execution at shield_recheck without saving a return address. Registers and
; flags are unchanged by the jump itself.
shield_push_down:
; Book line 872: shield_push_down names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 inc shipy ; Increase byte by one; wraps at 0/255.
; Book line 873: Increase the byte at shipy (ship Y) by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
shield_recheck:
; Book line 874: shield_recheck names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 jsr ship_terrain ; Call ship_terrain; RTS returns here.
; Book line 875: Call ship_terrain, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 bcs shield_push ; Branch if C=1; after compare, value was at least as large.
; Book line 876: Branch to shield_push if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 jmp render_ship ; Continue at render_ship without a return address.
; Book line 877: Continue execution at render_ship without saving a return address. Registers and
; flags are unchanged by the jump itself.
shield_safe:
; Book line 878: shield_safe names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ; The generated cave always leaves the centre flight lane unobstructed.
 lda #80 ; Load literal value into A.
; Book line 880: Load A with literal 80. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shipx ; Store shipx.
; Book line 881: Store A into the byte at shipx (ship X low byte). The register and CPU flags are
; unchanged.
render_ship:
; Book line 882: render_ship names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda shipx ; Read shipx.
; Book line 883: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta $d000
; Book line 884: Store A into the byte at $d000 (sprite 0 X low byte). The register and CPU flags are
; unchanged.
 lda shipy ; Read shipy.
; Book line 885: Load A with the byte at shipy (ship Y). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d001
; Book line 886: Store A into the byte at $d001 (sprite 0 Y coordinate). The register and CPU flags
; are unchanged.
 rts ; Return to caller.
; Book line 887: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Hull contact samples are on the visible multicolour ship outline.

; ============================================================================
; WHAT: Test eight visible hull points
; WHY: Whole-cell collision hits empty corners of shaped terrain
; HOW: Add hullx/hully offsets and call terrain for each. Return C=1 on contact, C=0 if all
; clear. Clobbers A/X/Y, flags and scratch pointers.
; ============================================================================
ship_terrain:
; Book line 897: ship_terrain names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda #0 ; Load literal value into A.
; Book line 898: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta hullprobe ; Store hullprobe.
; Book line 899: Store A into the byte at hullprobe. The register and CPU flags are unchanged.
hull_next:
; Book line 900: hull_next names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ldy hullprobe ; Read hullprobe.
; Book line 901: Load Y with the byte at hullprobe. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 lda shipx ; Read shipx.
; Book line 902: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 903: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc hullx,y ; Add operand and carry to A.
; Book line 904: Add the byte at hullx plus index Y and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta testx ; Store testx.
; Book line 905: Store A into the byte at testx. The register and CPU flags are unchanged.
 lda shipy ; Read shipy.
; Book line 906: Load A with the byte at shipy (ship Y). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 907: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc hully,y ; Add operand and carry to A.
; Book line 908: Add the byte at hully plus index Y and incoming carry to A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta testy ; Store testy.
; Book line 909: Store A into the byte at testy. The register and CPU flags are unchanged.
 jsr terrain ; Call terrain; RTS returns here.
; Book line 910: Call terrain, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 bcs hull_solid ; Branch if C=1; after compare, value was at least as large.
; Book line 911: Branch to hull_solid if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 inc hullprobe ; Increase byte by one; wraps at 0/255.
; Book line 912: Increase the byte at hullprobe by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 lda hullprobe ; Read hullprobe.
; Book line 913: Load A with the byte at hullprobe. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #8 ; Compare; change flags, preserve register.
; Book line 914: Compare A with literal 8 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne hull_next ; Branch if not zero/equal (Z=0).
; Book line 915: Branch to hull_next if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 916: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 rts ; Return to caller.
; Book line 917: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
hull_solid:
; Book line 918: hull_solid names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sec ; Set carry before subtraction, or return C=1.
; Book line 919: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 rts ; Return to caller.
; Book line 920: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; WHAT: Launch and update gun and bomb
; WHY: Projectile motion is independent of ship motion
; HOW: Held fire checks a 14-frame cooldown and free slots. Sprite 1 is the shot; sprite 2 the
; bomb. Each bomb resets its velocity and fractional remainders.
; ============================================================================
weapons:
; Book line 929: weapons names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda firecool ; Read firecool.
; Book line 930: Load A with the byte at firecool. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq ready ; Branch if zero/equal (Z=1).
; Book line 931: Branch to ready if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec firecool ; Decrease byte by one; wraps at 0/255.
; Book line 932: Decrease the byte at firecool by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
ready:
; Book line 933: ready names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda joy ; Read joy.
; Book line 934: Load A with the byte at joy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #16 ; Keep only masked bits.
; Book line 935: Keep only bits set in both A and literal 16. Save the result in A and update Z and N;
; carry is unchanged.
 bne projectiles ; Branch if not zero/equal (Z=0).
; Book line 936: Branch to projectiles if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda firecool ; Read firecool.
; Book line 937: Load A with the byte at firecool. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bne projectiles ; Branch if not zero/equal (Z=0).
; Book line 938: Branch to projectiles if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #14 ; Load literal value into A.
; Book line 939: Load A with literal 14. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta firecool ; Store firecool.
; Book line 940: Store A into the byte at firecool. The register and CPU flags are unchanged.
 lda shot ; Read shot.
; Book line 941: Load A with the byte at shot. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bne trybomb ; Branch if not zero/equal (Z=0).
; Book line 942: Branch to trybomb if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inc shot ; Increase byte by one; wraps at 0/255.
; Book line 943: Increase the byte at shot by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 lda shipx ; Read shipx.
; Book line 944: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 945: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #19 ; Add operand and carry to A.
; Book line 946: Add literal 19 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta sx ; Store sx.
; Book line 947: Store A into the byte at sx. The register and CPU flags are unchanged.
 lda shipy ; Read shipy.
; Book line 948: Load A with the byte at shipy (ship Y). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 949: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #7 ; Add operand and carry to A.
; Book line 950: Add literal 7 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta sy ; Store sy.
; Book line 951: Store A into the byte at sy. The register and CPU flags are unchanged.
 lda #$21 ; Load literal value into A.
; Book line 952: Load A with literal $21 (decimal 33). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d404 ; Write A to SID voice 1 control/gate.
; Book line 953: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
 lda #$38 ; Load literal value into A.
; Book line 954: Load A with literal $38 (decimal 56). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d401
; Book line 955: Store A into the byte at $d401 (SID voice 1 frequency high). The register and CPU
; flags are unchanged.
 lda #5 ; Load literal value into A.
; Book line 956: Load A with literal 5. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta soundtimer ; Store soundtimer.
; Book line 957: Store A into the byte at soundtimer. The register and CPU flags are unchanged.
trybomb:
; Book line 958: trybomb names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda bomb ; Read bomb.
; Book line 959: Load A with the byte at bomb. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bne projectiles ; Branch if not zero/equal (Z=0).
; Book line 960: Branch to projectiles if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inc bomb ; Increase byte by one; wraps at 0/255.
; Book line 961: Increase the byte at bomb by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 lda shipx ; Read shipx.
; Book line 962: Load A with the byte at shipx (ship X low byte). Z records a zero value; N copies bit
; 7. Carry is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 963: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #8 ; Add operand and carry to A.
; Book line 964: Add literal 8 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta bx ; Store bx.
; Book line 965: Store A into the byte at bx. The register and CPU flags are unchanged.
 lda shipy ; Read shipy.
; Book line 966: Load A with the byte at shipy (ship Y). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 967: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #16 ; Add operand and carry to A.
; Book line 968: Add literal 16 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta by ; Store by.
; Book line 969: Store A into the byte at by. The register and CPU flags are unchanged.
 lda #0 ; Load literal value into A.
; Book line 970: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta bombxf ; Store bombxf.
; Book line 971: Store A into the byte at bombxf. The register and CPU flags are unchanged.
 sta bombyf ; Store bombyf.
; Book line 972: Store A into the byte at bombyf. The register and CPU flags are unchanged.
 lda #48 ; Q4 horizontal speed: 3 pixels/frame at release
; Book line 973: Load A with literal 48. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta bombvx ; Store bombvx.
; Book line 974: Store A into the byte at bombvx. The register and CPU flags are unchanged.
 lda #4 ; Initial gentle downward drift, Q4
; Book line 975: Load A with literal 4. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta bombvy ; Store bombvy.
; Book line 976: Store A into the byte at bombvy. The register and CPU flags are unchanged.
projectiles:
; Book line 977: projectiles names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda shot ; Read shot.
; Book line 978: Load A with the byte at shot. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq shot_off ; Branch if zero/equal (Z=1).
; Book line 979: Branch to shot_off if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda sx ; Read sx.
; Book line 980: Load A with the byte at sx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 981: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #5 ; Add operand and carry to A.
; Book line 982: Add literal 5 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta sx ; Store sx.
; Book line 983: Store A into the byte at sx. The register and CPU flags are unchanged.
 bcc shot_pos ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 984: Branch to shot_pos if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #0 ; Load literal value into A.
; Book line 985: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shot ; Store shot.
; Book line 986: Store A into the byte at shot. The register and CPU flags are unchanged.
shot_off:
; Book line 987: shot_off names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda $d015 ; Read sprite enable bits.
; Book line 988: Load A with the byte at $d015 (VIC sprite enable bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$fd ; Keep only masked bits.
; Book line 989: Keep only bits set in both A and literal $fd (decimal 253). Save the result in A and
; update Z and N; carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 990: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 jmp bomb_update ; Continue at bomb_update without a return address.
; Book line 991: Continue execution at bomb_update without saving a return address. Registers and
; flags are unchanged by the jump itself.
shot_pos:
; Book line 992: shot_pos names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 sta $d002
; Book line 993: Store A into the byte at $d002 (sprite 1 X low byte). The register and CPU flags are
; unchanged.
 sta testx ; Store testx.
; Book line 994: Store A into the byte at testx. The register and CPU flags are unchanged.
 lda sy ; Read sy.
; Book line 995: Load A with the byte at sy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d003
; Book line 996: Store A into the byte at $d003 (sprite 1 Y coordinate). The register and CPU flags
; are unchanged.
 sta testy ; Store testy.
; Book line 997: Store A into the byte at testy. The register and CPU flags are unchanged.
 jsr terrain ; Call terrain; RTS returns here.
; Book line 998: Call terrain, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 bcc shot_on ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 999: Branch to shot_on if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #0 ; Load literal value into A.
; Book line 1000: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shot ; Store shot.
; Book line 1001: Store A into the byte at shot. The register and CPU flags are unchanged.
shot_on:
; Book line 1002: shot_on names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda $d015 ; Read sprite enable bits.
; Book line 1003: Load A with the byte at $d015 (VIC sprite enable bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ora #2 ; Set selected bits, preserving others.
; Book line 1004: Set A bits present in either A or literal 2. Save the result in A and update Z and
; N; carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 1005: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.

; ============================================================================
; WHAT: Advance the curved bomb trajectory
; WHY: Constant X/Y steps gave a straight diagonal
; HOW: Q4 horizontal momentum eases down; gravity raises downward speed. Accumulate fractions,
; move whole pixels, then test terrain and edges.
; ============================================================================
bomb_update:
; Book line 1013: bomb_update names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda bomb ; Read bomb.
; Book line 1014: Load A with the byte at bomb. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bne bomb_motion ; Branch if not zero/equal (Z=0).
; Book line 1015: Branch to bomb_motion if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp bomb_off ; Continue at bomb_off without a return address.
; Book line 1016: Continue execution at bomb_off without saving a return address. Registers and flags
; are unchanged by the jump itself.
bomb_motion:
; Book line 1017: bomb_motion names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ; Q4 motion: forward momentum decays; gravity steadily steepens the arc.
 lda bombvx ; Read bombvx.
; Book line 1019: Load A with the byte at bombvx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #16 ; Compare; change flags, preserve register.
; Book line 1020: Compare A with literal 16 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq bomb_no_drag ; Branch if zero/equal (Z=1).
; Book line 1021: Branch to bomb_no_drag if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec bombvx ; Decrease byte by one; wraps at 0/255.
; Book line 1022: Decrease the byte at bombvx by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
bomb_no_drag:
; Book line 1023: bomb_no_drag names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda bombxf ; Read bombxf.
; Book line 1024: Load A with the byte at bombxf. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1025: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc bombvx ; Add operand and carry to A.
; Book line 1026: Add the byte at bombvx and incoming carry to A. Update C, Z, N and V according to
; CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 pha ; Push A on the CPU stack.
; Book line 1027: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 and #15 ; Keep only masked bits.
; Book line 1028: Keep only bits set in both A and literal 15. Save the result in A and update Z and
; N; carry is unchanged.
 sta bombxf ; Store bombxf.
; Book line 1029: Store A into the byte at bombxf. The register and CPU flags are unchanged.
 pla ; Pull saved byte back into A.
; Book line 1030: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1031: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1032: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1033: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1034: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 clc ; Clear carry before addition, or return C=0.
; Book line 1035: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc bx ; Add operand and carry to A.
; Book line 1036: Add the byte at bx and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 bcs bomb_die ; Branch if C=1; after compare, value was at least as large.
; Book line 1037: Branch to bomb_die if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 cmp #248 ; Compare; change flags, preserve register.
; Book line 1038: Compare A with literal 248 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs bomb_die ; Branch if C=1; after compare, value was at least as large.
; Book line 1039: Branch to bomb_die if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 sta bx ; Store bx.
; Book line 1040: Store A into the byte at bx. The register and CPU flags are unchanged.
 lda bombvy ; Read bombvy.
; Book line 1041: Load A with the byte at bombvy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 cmp #80 ; Compare; change flags, preserve register.
; Book line 1042: Compare A with literal 80 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs bomb_terminal ; Branch if C=1; after compare, value was at least as large.
; Book line 1043: Branch to bomb_terminal if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1044: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #3 ; Add operand and carry to A.
; Book line 1045: Add literal 3 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta bombvy ; Store bombvy.
; Book line 1046: Store A into the byte at bombvy. The register and CPU flags are unchanged.
bomb_terminal:
; Book line 1047: bomb_terminal names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda bombyf ; Read bombyf.
; Book line 1048: Load A with the byte at bombyf. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1049: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc bombvy ; Add operand and carry to A.
; Book line 1050: Add the byte at bombvy and incoming carry to A. Update C, Z, N and V according to
; CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 pha ; Push A on the CPU stack.
; Book line 1051: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 and #15 ; Keep only masked bits.
; Book line 1052: Keep only bits set in both A and literal 15. Save the result in A and update Z and
; N; carry is unchanged.
 sta bombyf ; Store bombyf.
; Book line 1053: Store A into the byte at bombyf. The register and CPU flags are unchanged.
 pla ; Pull saved byte back into A.
; Book line 1054: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1055: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1056: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1057: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1058: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 clc ; Clear carry before addition, or return C=0.
; Book line 1059: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc by ; Add operand and carry to A.
; Book line 1060: Add the byte at by and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta by ; Store by.
; Book line 1061: Store A into the byte at by. The register and CPU flags are unchanged.
 cmp #235 ; Compare; change flags, preserve register.
; Book line 1062: Compare A with literal 235 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs bomb_die ; Branch if C=1; after compare, value was at least as large.
; Book line 1063: Branch to bomb_die if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda bx ; Read bx.
; Book line 1064: Load A with the byte at bx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d004
; Book line 1065: Store A into the byte at $d004 (sprite 2 X low byte). The register and CPU flags are
; unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1066: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #5 ; Add operand and carry to A.
; Book line 1067: Add literal 5 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta testx ; Store testx.
; Book line 1068: Store A into the byte at testx. The register and CPU flags are unchanged.
 lda by ; Read by.
; Book line 1069: Load A with the byte at by. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sta $d005
; Book line 1070: Store A into the byte at $d005 (sprite 2 Y coordinate). The register and CPU flags
; are unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1071: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #8 ; Add operand and carry to A.
; Book line 1072: Add literal 8 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta testy ; Store testy.
; Book line 1073: Store A into the byte at testy. The register and CPU flags are unchanged.
 jsr terrain ; Call terrain; RTS returns here.
; Book line 1074: Call terrain, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 bcc bomb_on ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1075: Branch to bomb_on if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
bomb_die:
; Book line 1076: bomb_die names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #0 ; Load literal value into A.
; Book line 1077: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta bomb ; Store bomb.
; Book line 1078: Store A into the byte at bomb. The register and CPU flags are unchanged.
bomb_off:
; Book line 1079: bomb_off names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda $d015 ; Read sprite enable bits.
; Book line 1080: Load A with the byte at $d015 (VIC sprite enable bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #$fb ; Keep only masked bits.
; Book line 1081: Keep only bits set in both A and literal $fb (decimal 251). Save the result in A and
; update Z and N; carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 1082: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 rts ; Return to caller.
; Book line 1083: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
bomb_on:
; Book line 1084: bomb_on names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda $d015 ; Read sprite enable bits.
; Book line 1085: Load A with the byte at $d015 (VIC sprite enable bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ora #4 ; Set selected bits, preserving others.
; Book line 1086: Set A bits present in either A or literal 4. Save the result in A and update Z and
; N; carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 1087: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 rts ; Return to caller.
; Book line 1088: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; WHAT: Update five target slots
; WHY: More targets require sprites 3 through 7
; HOW: Preserve player/projectile bits, rebuild target enable bits, move X left one pixel, and
; launch waiting rockets upwards. Grounded Y stays anchored to the pad.
; ============================================================================
enemies:
; Book line 1097: enemies names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ; Only live target slots enable sprites; their Y remains anchored to a pad.
 lda $d015 ; Read sprite enable bits.
; Book line 1099: Load A with the byte at $d015 (VIC sprite enable bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 and #7 ; Keep only masked bits.
; Book line 1100: Keep only bits set in both A and literal 7. Save the result in A and update Z and N;
; carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 1101: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 ldx #3 ; Load literal value into X.
; Book line 1102: Load X with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
enloop:
; Book line 1103: enloop names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda active,x ; Read indexed table or screen entry.
; Book line 1104: Load A with the byte at active (object activity table) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 beq ennext ; Branch if zero/equal (Z=1).
; Book line 1105: Branch to ennext if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec ex,x ; Decrease byte by one; wraps at 0/255.
; Book line 1106: Decrease the byte at ex plus index X by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
 lda ex,x ; Read indexed table or screen entry.
; Book line 1107: Load A with the byte at ex plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 cmp #27 ; Compare; change flags, preserve register.
; Book line 1108: Compare A with literal 27 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc remove_target ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1109: Branch to remove_target if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 lda kind,x ; Read indexed table or screen entry.
; Book line 1110: Load A with the byte at kind plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 cmp #2 ; Compare; change flags, preserve register.
; Book line 1111: Compare A with literal 2 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne enwrite ; Branch if not zero/equal (Z=0).
; Book line 1112: Branch to enwrite if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda launchwait,x ; Read indexed table or screen entry.
; Book line 1113: Load A with the byte at launchwait plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 beq rocket_fly ; Branch if zero/equal (Z=1).
; Book line 1114: Branch to rocket_fly if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec launchwait,x ; Decrease byte by one; wraps at 0/255.
; Book line 1115: Decrease the byte at launchwait plus index X by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
 jmp enwrite ; Continue at enwrite without a return address.
; Book line 1116: Continue execution at enwrite without saving a return address. Registers and flags
; are unchanged by the jump itself.
rocket_fly:
; Book line 1117: rocket_fly names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 dec ey,x ; Decrease byte by one; wraps at 0/255.
; Book line 1118: Decrease the byte at ey plus index X by one with 8-bit wraparound. Update Z and N;
; carry is unchanged.
 lda ey,x ; Read indexed table or screen entry.
; Book line 1119: Load A with the byte at ey plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 cmp #65 ; Compare; change flags, preserve register.
; Book line 1120: Compare A with literal 65 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc remove_target ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1121: Branch to remove_target if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
enwrite:
; Book line 1122: enwrite names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 txa ; Copy X to A.
; Book line 1123: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
 asl ; Shift left, putting outgoing bit in carry.
; Book line 1124: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 tay ; Copy A to Y.
; Book line 1125: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda ex,x ; Read indexed table or screen entry.
; Book line 1126: Load A with the byte at ex plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $d000,y
; Book line 1127: Store A into the byte at $d000 (sprite 0 X low byte) plus index Y. The register and
; CPU flags are unchanged.
 lda ey,x ; Read indexed table or screen entry.
; Book line 1128: Load A with the byte at ey plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $d001,y
; Book line 1129: Store A into the byte at $d001 (sprite 0 Y coordinate) plus index Y. The register
; and CPU flags are unchanged.
 lda $d015 ; Read sprite enable bits.
; Book line 1130: Load A with the byte at $d015 (VIC sprite enable bits). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 ora spritemask,x ; Set selected bits, preserving others.
; Book line 1131: Set A bits present in either A or the byte at spritemask plus index X. Save the
; result in A and update Z and N; carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 1132: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 jmp ennext ; Continue at ennext without a return address.
; Book line 1133: Continue execution at ennext without saving a return address. Registers and flags
; are unchanged by the jump itself.
remove_target:
; Book line 1134: remove_target names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 jsr respawn ; Call respawn; RTS returns here.
; Book line 1135: Call respawn, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
ennext:
; Book line 1136: ennext names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 inx ; Next X index; 255 wraps to zero.
; Book line 1137: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #8 ; Compare; change flags, preserve register.
; Book line 1138: Compare X with literal 8 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne enloop ; Branch if not zero/equal (Z=0).
; Book line 1139: Branch to enloop if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda spawncool ; Read spawncool.
; Book line 1140: Load A with the byte at spawncool. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq findslot ; Branch if zero/equal (Z=1).
; Book line 1141: Branch to findslot if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec spawncool ; Decrease byte by one; wraps at 0/255.
; Book line 1142: Decrease the byte at spawncool by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
 rts ; Return to caller.
; Book line 1143: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ============================================================================
; WHAT: Find room for a target
; WHY: Do not overwrite a live sprite
; HOW: Search active indices 3..7. A successful spawn waits 24 countdown frames plus the next
; attempt, giving 25-frame spacing.
; ============================================================================
findslot:
; Book line 1151: findslot names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ldx #3 ; Load literal value into X.
; Book line 1152: Load X with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
slotloop:
; Book line 1153: slotloop names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda active,x ; Read indexed table or screen entry.
; Book line 1154: Load A with the byte at active (object activity table) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 beq tryspawn ; Branch if zero/equal (Z=1).
; Book line 1155: Branch to tryspawn if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 inx ; Next X index; 255 wraps to zero.
; Book line 1156: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #8 ; Compare; change flags, preserve register.
; Book line 1157: Compare X with literal 8 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne slotloop ; Branch if not zero/equal (Z=0).
; Book line 1158: Branch to slotloop if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts ; Return to caller.
; Book line 1159: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ============================================================================
; WHAT: Require flat ground under both target feet
; WHY: A single centre height let targets sink into slopes
; HOW: Look under physical X 252 and 269, require equal pad surfaces, choose a kind and subtract
; its visible foot height. testx here is X minus 24 to avoid 8-bit overflow.
; ============================================================================
tryspawn:
; Book line 1167: tryspawn names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 stx savedx ; Store savedx.
; Book line 1168: Store X into the byte at savedx. The register and CPU flags are unchanged.
 ; Both feet must sit on the same designed, flat pad.
 lda #228 ; left foot X=252 minus the 24-pixel screen origin
; Book line 1170: Load A with literal 228. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta testx ; Store testx.
; Book line 1171: Store A into the byte at testx. The register and CPU flags are unchanged.
 jsr padheight ; Call padheight; RTS returns here.
; Book line 1172: Call padheight, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 bcc spawn_no ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1173: Branch to spawn_no if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 sta pad_y ; Store pad_y.
; Book line 1174: Store A into the byte at pad_y. The register and CPU flags are unchanged.
 lda #245 ; right foot X=269 minus the screen origin
; Book line 1175: Load A with literal 245. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta testx ; Store testx.
; Book line 1176: Store A into the byte at testx. The register and CPU flags are unchanged.
 jsr padheight ; Call padheight; RTS returns here.
; Book line 1177: Call padheight, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 bcc spawn_no ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1178: Branch to spawn_no if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 cmp pad_y ; Compare; change flags, preserve register.
; Book line 1179: Compare A with the byte at pad_y without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne spawn_no ; Branch if not zero/equal (Z=0).
; Book line 1180: Branch to spawn_no if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ldx savedx ; Read savedx.
; Book line 1181: Load X with the byte at savedx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 jsr random ; Call random; RTS returns here.
; Book line 1182: Call random, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 and #3 ; Keep only masked bits.
; Book line 1183: Keep only bits set in both A and literal 3. Save the result in A and update Z and N;
; carry is unchanged.
 cmp #3 ; Compare; change flags, preserve register.
; Book line 1184: Compare A with literal 3 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne spawnkind ; Branch if not zero/equal (Z=0).
; Book line 1185: Branch to spawnkind if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #2 ; Load literal value into A.
; Book line 1186: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
spawnkind:
; Book line 1187: spawnkind names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sta kind,x
; Book line 1188: Store A into the byte at kind plus index X. The register and CPU flags are
; unchanged.
 tay ; Copy A to Y.
; Book line 1189: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda targetptrs,y ; Read indexed table or screen entry.
; Book line 1190: Load A with the byte at targetptrs plus index Y. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $07f8,x
; Book line 1191: Store A into the byte at $07f8 (sprite pointer table in the $0400 screen) plus index
; X. The register and CPU flags are unchanged.
 sta $0ff8,x
; Book line 1192: Store A into the byte at $0ff8 plus index X. The register and CPU flags are
; unchanged.
 lda targetcolors,y ; Read indexed table or screen entry.
; Book line 1193: Load A with the byte at targetcolors plus index Y. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $d027,x
; Book line 1194: Store A into the byte at $d027 (sprite 0 colour) plus index X. The register and CPU
; flags are unchanged.
 lda pad_y ; Read pad_y.
; Book line 1195: Load A with the byte at pad_y. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1196: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc footheight,y ; Subtract operand and (1-carry) from A.
; Book line 1197: Subtract the byte at footheight plus index Y and (1 minus incoming carry) from A.
; Update C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ey,x
; Book line 1198: Store A into the byte at ey plus index X. The register and CPU flags are unchanged.
 lda #250 ; Load literal value into A.
; Book line 1199: Load A with literal 250. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ex,x
; Book line 1200: Store A into the byte at ex plus index X. The register and CPU flags are unchanged.
 lda #1 ; Load literal value into A.
; Book line 1201: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta active,x
; Book line 1202: Store A into the byte at active (object activity table) plus index X. The register
; and CPU flags are unchanged.
 lda #48 ; Load literal value into A.
; Book line 1203: Load A with literal 48. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta launchwait,x
; Book line 1204: Store A into the byte at launchwait plus index X. The register and CPU flags are
; unchanged.
 lda #24 ; Load literal value into A.
; Book line 1205: Load A with literal 24. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta spawncool ; Store spawncool.
; Book line 1206: Store A into the byte at spawncool. The register and CPU flags are unchanged.
spawn_no:
; Book line 1207: spawn_no names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 rts ; Return to caller.
; Book line 1208: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ============================================================================
; WHAT: Retire one target slot
; WHY: New targets should wait for a suitable pad
; HOW: Clear active[X] and its D015 bit. The old name does not mean immediate target creation.
; Input X is the target sprite slot.
; ============================================================================
respawn:
; Book line 1216: respawn names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ; Retire a hit/offscreen target; the next pad supplies a fresh one.
 lda #0 ; Load literal value into A.
; Book line 1218: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta active,x
; Book line 1219: Store A into the byte at active (object activity table) plus index X. The register
; and CPU flags are unchanged.
 lda spritemask,x ; Read indexed table or screen entry.
; Book line 1220: Load A with the byte at spritemask plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 eor #$ff ; Toggle the mask bits with XOR.
; Book line 1221: Toggle A bits selected by literal $ff (decimal 255). Save the result in A and update
; Z and N; carry is unchanged.
 and $d015 ; Keep only masked bits.
; Book line 1222: Keep only bits set in both A and the byte at $d015 (VIC sprite enable bits). Save
; the result in A and update Z and N; carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 1223: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 rts ; Return to caller.
; Book line 1224: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Carry set only for the top tile of a flat pad, A = exact surface Y.

; ============================================================================
; WHAT: Locate an exact pad top
; WHY: Installations need level contact surfaces
; HOW: Scan rows 10..23. Glyph 225 is a pad top; any other solid glyph rejects it. Input testx=X
; minus 24. Return C=1/A=surface Y, or C=0; clobbers X/Y and $fb/$fc.
; ============================================================================
padheight:
; Book line 1234: padheight names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda testx ; Read testx.
; Book line 1235: Load A with the byte at testx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1236: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc fine ; Subtract operand and (1-carry) from A.
; Book line 1237: Subtract the byte at fine (horizontal fine scroll offset) and (1 minus incoming
; carry) from A. Update C, Z, N and V according to CPU arithmetic rules; decimal mode changes
; arithmetic behaviour.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1238: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1239: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1240: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 tay ; Copy A to Y.
; Book line 1241: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda #<($0400+10*40) ; Take low address byte.
; Book line 1242: Load A with the low address byte of ($0400+10*40) as an immediate value. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 1243: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>($0400+10*40) ; Take high address byte.
; Book line 1244: Load A with the high address byte of ($0400+10*40) as an immediate value. Z records
; a zero value; N copies bit 7. Carry is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1245: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc back ; Add operand and carry to A.
; Book line 1246: Add the byte at back (screen buffer selection) and incoming carry to A. Update C, Z,
; N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $fc ; Pointer high byte.
; Book line 1247: Store A into the byte at $fc. The register and CPU flags are unchanged.
 ldx #10 ; Load literal value into X.
; Book line 1248: Load X with literal 10. Z records a zero value; N copies bit 7. Carry is unchanged.
padscan:
; Book line 1249: padscan names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda ($fb),y ; Read through pointer plus Y.
; Book line 1250: Load A with the byte at the address in zero-page pair $fb and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
 cmp #225 ; Compare; change flags, preserve register.
; Book line 1251: Compare A with literal 225 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq pad_found ; Branch if zero/equal (Z=1).
; Book line 1252: Branch to pad_found if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cmp #96 ; Compare; change flags, preserve register.
; Book line 1253: Compare A with literal 96 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs not_pad ; Branch if C=1; after compare, value was at least as large.
; Book line 1254: Branch to not_pad if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda $fb
; Book line 1255: Load A with the byte at $fb. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1256: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #40 ; Add operand and carry to A.
; Book line 1257: Add literal 40 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $fb ; Pointer low byte.
; Book line 1258: Store A into the byte at $fb. The register and CPU flags are unchanged.
 bcc padcarry ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1259: Branch to padcarry if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 inc $fc ; Increase byte by one; wraps at 0/255.
; Book line 1260: Increase the byte at $fc by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
padcarry:
; Book line 1261: padcarry names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 inx ; Next X index; 255 wraps to zero.
; Book line 1262: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #24 ; Compare; change flags, preserve register.
; Book line 1263: Compare X with literal 24 without changing X. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne padscan ; Branch if not zero/equal (Z=0).
; Book line 1264: Branch to padscan if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
not_pad:
; Book line 1265: not_pad names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 clc ; Clear carry before addition, or return C=0.
; Book line 1266: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 rts ; Return to caller.
; Book line 1267: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
pad_found:
; Book line 1268: pad_found names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 txa ; Copy X to A.
; Book line 1269: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
 asl ; Shift left, putting outgoing bit in carry.
; Book line 1270: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 asl ; Shift left, putting outgoing bit in carry.
; Book line 1271: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 asl ; Shift left, putting outgoing bit in carry.
; Book line 1272: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc ; Clear carry before addition, or return C=0.
; Book line 1273: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #50 ; Add operand and carry to A.
; Book line 1274: Add literal 50 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1275: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 rts ; Return to caller.
; Book line 1276: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; WHAT: Identify projectile and target hits
; WHY: A shared VIC collision latch would not tell us which object hit which
; HOW: Compare small bounding ranges for each active target. Retire the projectile and call
; targethit. Sprite hitboxes are approximate, not pixel-perfect.
; ============================================================================
hits:
; Book line 1285: hits names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ; Bounding boxes keep projectile/target hits distinct from ship collisions.
 ldx #3 ; Load literal value into X.
; Book line 1287: Load X with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
hitloop:
; Book line 1288: hitloop names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda active,x ; Read indexed table or screen entry.
; Book line 1289: Load A with the byte at active (object activity table) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
 bne hitactive ; Branch if not zero/equal (Z=0).
; Book line 1290: Branch to hitactive if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp nexthit ; Continue at nexthit without a return address.
; Book line 1291: Continue execution at nexthit without saving a return address. Registers and flags
; are unchanged by the jump itself.
hitactive:
; Book line 1292: hitactive names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda ex,x ; Read indexed table or screen entry.
; Book line 1293: Load A with the byte at ex plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1294: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc shipx ; Subtract operand and (1-carry) from A.
; Book line 1295: Subtract the byte at shipx (ship X low byte) and (1 minus incoming carry) from A.
; Update C, Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp #19 ; Compare; change flags, preserve register.
; Book line 1296: Compare A with literal 19 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs no_shiphit ; Branch if C=1; after compare, value was at least as large.
; Book line 1297: Branch to no_shiphit if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda ey,x ; Read indexed table or screen entry.
; Book line 1298: Load A with the byte at ey plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1299: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc shipy ; Subtract operand and (1-carry) from A.
; Book line 1300: Subtract the byte at shipy (ship Y) and (1 minus incoming carry) from A. Update C,
; Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 clc ; Clear carry before addition, or return C=0.
; Book line 1301: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #14 ; Add operand and carry to A.
; Book line 1302: Add literal 14 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp #31 ; Compare; change flags, preserve register.
; Book line 1303: Compare A with literal 31 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs no_shiphit ; Branch if C=1; after compare, value was at least as large.
; Book line 1304: Branch to no_shiphit if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 inc dead ; Increase byte by one; wraps at 0/255.
; Book line 1305: Increase the byte at dead by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
no_shiphit:
; Book line 1306: no_shiphit names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda shot ; Read shot.
; Book line 1307: Load A with the byte at shot. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq bombhit ; Branch if zero/equal (Z=1).
; Book line 1308: Branch to bombhit if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda sx ; Read sx.
; Book line 1309: Load A with the byte at sx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1310: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc ex,x ; Subtract operand and (1-carry) from A.
; Book line 1311: Subtract the byte at ex plus index X and (1 minus incoming carry) from A. Update C,
; Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 clc ; Clear carry before addition, or return C=0.
; Book line 1312: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #5 ; Add operand and carry to A.
; Book line 1313: Add literal 5 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp #26 ; Compare; change flags, preserve register.
; Book line 1314: Compare A with literal 26 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs bombhit ; Branch if C=1; after compare, value was at least as large.
; Book line 1315: Branch to bombhit if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda sy ; Read sy.
; Book line 1316: Load A with the byte at sy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1317: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc ey,x ; Subtract operand and (1-carry) from A.
; Book line 1318: Subtract the byte at ey plus index X and (1 minus incoming carry) from A. Update C,
; Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 clc ; Clear carry before addition, or return C=0.
; Book line 1319: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #4 ; Add operand and carry to A.
; Book line 1320: Add literal 4 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp #23 ; Compare; change flags, preserve register.
; Book line 1321: Compare A with literal 23 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs bombhit ; Branch if C=1; after compare, value was at least as large.
; Book line 1322: Branch to bombhit if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #0 ; Load literal value into A.
; Book line 1323: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta shot ; Store shot.
; Book line 1324: Store A into the byte at shot. The register and CPU flags are unchanged.
 jsr targethit ; Call targethit; RTS returns here.
; Book line 1325: Call targethit, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 jmp nexthit ; Continue at nexthit without a return address.
; Book line 1326: Continue execution at nexthit without saving a return address. Registers and flags
; are unchanged by the jump itself.
bombhit:
; Book line 1327: bombhit names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda bomb ; Read bomb.
; Book line 1328: Load A with the byte at bomb. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq nexthit ; Branch if zero/equal (Z=1).
; Book line 1329: Branch to nexthit if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda bx ; Read bx.
; Book line 1330: Load A with the byte at bx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1331: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc ex,x ; Subtract operand and (1-carry) from A.
; Book line 1332: Subtract the byte at ex plus index X and (1 minus incoming carry) from A. Update C,
; Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 clc ; Clear carry before addition, or return C=0.
; Book line 1333: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #4 ; Add operand and carry to A.
; Book line 1334: Add literal 4 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp #25 ; Compare; change flags, preserve register.
; Book line 1335: Compare A with literal 25 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs nexthit ; Branch if C=1; after compare, value was at least as large.
; Book line 1336: Branch to nexthit if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda by ; Read by.
; Book line 1337: Load A with the byte at by. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1338: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc ey,x ; Subtract operand and (1-carry) from A.
; Book line 1339: Subtract the byte at ey plus index X and (1 minus incoming carry) from A. Update C,
; Z, N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 clc ; Clear carry before addition, or return C=0.
; Book line 1340: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #4 ; Add operand and carry to A.
; Book line 1341: Add literal 4 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp #24 ; Compare; change flags, preserve register.
; Book line 1342: Compare A with literal 24 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs nexthit ; Branch if C=1; after compare, value was at least as large.
; Book line 1343: Branch to nexthit if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #0 ; Load literal value into A.
; Book line 1344: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta bomb ; Store bomb.
; Book line 1345: Store A into the byte at bomb. The register and CPU flags are unchanged.
 jsr targethit ; Call targethit; RTS returns here.
; Book line 1346: Call targethit, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
nexthit:
; Book line 1347: nexthit names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 inx ; Next X index; 255 wraps to zero.
; Book line 1348: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #8 ; Compare; change flags, preserve register.
; Book line 1349: Compare X with literal 8 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne hitloop ; Branch if not zero/equal (Z=0).
; Book line 1350: Branch to hitloop if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts ; Return to caller.
; Book line 1351: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ============================================================================
; WHAT: Award score and optional fuel
; WHY: Only depots should add fuel
; HOW: Kind 1 adds 50 half-percent units, capped at 200. Add 50 BCD score points, trigger SID
; noise and retire target X. CLD restores binary arithmetic afterwards.
; ============================================================================
targethit:
; Book line 1359: targethit names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda kind,x ; Read indexed table or screen entry.
; Book line 1360: Load A with the byte at kind plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 cmp #1 ; Compare; change flags, preserve register.
; Book line 1361: Compare A with literal 1 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bne nofuel ; Branch if not zero/equal (Z=0).
; Book line 1362: Branch to nofuel if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 ; Tank units are half a percent: add 50 units, capped at 200.
 lda fuel ; Read fuel.
; Book line 1364: Load A with the byte at fuel (fuel in half-percent units). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1365: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #50 ; Add operand and carry to A.
; Book line 1366: Add literal 50 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp #200 ; Compare; change flags, preserve register.
; Book line 1367: Compare A with literal 200 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc fuel_added ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1368: Branch to fuel_added if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #200 ; Load literal value into A.
; Book line 1369: Load A with literal 200. Z records a zero value; N copies bit 7. Carry is unchanged.
fuel_added:
; Book line 1370: fuel_added names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sta fuel ; Store fuel.
; Book line 1371: Store A into the byte at fuel (fuel in half-percent units). The register and CPU
; flags are unchanged.
nofuel:
; Book line 1372: nofuel names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 sed ; Enable decimal arithmetic for BCD score.
; Book line 1373: Set decimal mode so subsequent ADC and SBC use packed BCD arithmetic on the 6510.
; Restore binary mode with CLD when finished.
 clc ; Clear carry before addition, or return C=0.
; Book line 1374: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 lda scorelo ; Read scorelo.
; Book line 1375: Load A with the byte at scorelo (score low byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 adc #$50 ; Add operand and carry to A.
; Book line 1376: Add literal $50 (decimal 80) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta scorelo ; Store scorelo.
; Book line 1377: Store A into the byte at scorelo (score low byte). The register and CPU flags are
; unchanged.
 lda scorehi ; Read scorehi.
; Book line 1378: Load A with the byte at scorehi (score high byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 adc #0 ; Add operand and carry to A.
; Book line 1379: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta scorehi ; Store scorehi.
; Book line 1380: Store A into the byte at scorehi (score high byte). The register and CPU flags are
; unchanged.
 cld ; Restore binary arithmetic for positions and pointers.
; Book line 1381: Clear decimal mode so subsequent ADC and SBC use binary arithmetic.
 lda #$81 ; Load literal value into A.
; Book line 1382: Load A with literal $81 (decimal 129). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d40b ; Write A to SID voice 2 control/gate.
; Book line 1383: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
 lda #$18 ; Load literal value into A.
; Book line 1384: Load A with literal $18 (decimal 24). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d408
; Book line 1385: Store A into the byte at $d408 (SID voice 2 frequency high). The register and CPU
; flags are unchanged.
 lda #10 ; Load literal value into A.
; Book line 1386: Load A with literal 10. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta soundtimer ; Store soundtimer.
; Book line 1387: Store A into the byte at soundtimer. The register and CPU flags are unchanged.
 jsr respawn ; Call respawn; RTS returns here.
; Book line 1388: Call respawn, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 rts ; Return to caller.
; Book line 1389: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; WHAT: End short sound effects
; WHY: A SID gate left on can keep sounding
; HOW: Decrement soundtimer once per frame, then clear voice control registers. Voice 1 is shot
; tone, voice 2 noise.
; ============================================================================
audio:
; Book line 1398: audio names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda soundtimer ; Read soundtimer.
; Book line 1399: Load A with the byte at soundtimer. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 beq silence ; Branch if zero/equal (Z=1).
; Book line 1400: Branch to silence if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 dec soundtimer ; Decrease byte by one; wraps at 0/255.
; Book line 1401: Decrease the byte at soundtimer by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
 rts ; Return to caller.
; Book line 1402: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
silence:
; Book line 1403: silence names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #0 ; Load literal value into A.
; Book line 1404: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d404 ; Write A to SID voice 1 control/gate.
; Book line 1405: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
 sta $d40b ; Write A to SID voice 2 control/gate.
; Book line 1406: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
 rts ; Return to caller.
; Book line 1407: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Terrain lookup: carry set for solid custom tile.

; ============================================================================
; WHAT: Test a particular pixel against a shaped glyph
; WHY: A character cell can contain both air and rock
; HOW: Subtract origin and fine offset, find screen character, calculate font row, AND its two-
; bit pair mask. Input testx/testy; return C=1 solid or C=0 air; clobbers A/X/Y and $fb/$fc.
; ============================================================================
terrain:
; Book line 1417: terrain names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda testy ; Read testy.
; Book line 1418: Load A with the byte at testy. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1419: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc #50 ; Subtract operand and (1-carry) from A.
; Book line 1420: Subtract literal 50 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 pha ; Push A on the CPU stack.
; Book line 1421: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 and #7 ; Keep only masked bits.
; Book line 1422: Keep only bits set in both A and literal 7. Save the result in A and update Z and N;
; carry is unchanged.
 sta localy ; Store localy.
; Book line 1423: Store A into the byte at localy. The register and CPU flags are unchanged.
 pla ; Pull saved byte back into A.
; Book line 1424: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1425: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1426: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1427: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 cmp #24 ; Compare; change flags, preserve register.
; Book line 1428: Compare A with literal 24 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs solid ; Branch if C=1; after compare, value was at least as large.
; Book line 1429: Branch to solid if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 tax ; Copy A to X.
; Book line 1430: Copy A to X; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda rowlo,x ; Read indexed table or screen entry.
; Book line 1431: Load A with the byte at rowlo plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 1432: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda rowhi,x ; Read indexed table or screen entry.
; Book line 1433: Load A with the byte at rowhi plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1434: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc back ; Add operand and carry to A.
; Book line 1435: Add the byte at back (screen buffer selection) and incoming carry to A. Update C, Z,
; N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $fc ; Pointer high byte.
; Book line 1436: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda testx ; Read testx.
; Book line 1437: Load A with the byte at testx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1438: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc #24 ; Subtract operand and (1-carry) from A.
; Book line 1439: Subtract literal 24 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1440: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc fine ; Subtract operand and (1-carry) from A.
; Book line 1441: Subtract the byte at fine (horizontal fine scroll offset) and (1 minus incoming
; carry) from A. Update C, Z, N and V according to CPU arithmetic rules; decimal mode changes
; arithmetic behaviour.
 pha ; Push A on the CPU stack.
; Book line 1442: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 and #7 ; Keep only masked bits.
; Book line 1443: Keep only bits set in both A and literal 7. Save the result in A and update Z and N;
; carry is unchanged.
 sta localx ; Store localx.
; Book line 1444: Store A into the byte at localx. The register and CPU flags are unchanged.
 pla ; Pull saved byte back into A.
; Book line 1445: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1446: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1447: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1448: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 tay ; Copy A to Y.
; Book line 1449: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda ($fb),y ; Read through pointer plus Y.
; Book line 1450: Load A with the byte at the address in zero-page pair $fb and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
 cmp #96 ; Compare; change flags, preserve register.
; Book line 1451: Compare A with literal 96 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc air ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1452: Branch to air if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 ; Address character byte at $3000 + char*8 + localy.
 ldy #0 ; Load literal value into Y.
; Book line 1454: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sty $fc ; Pointer high byte.
; Book line 1455: Store Y into the byte at $fc. The register and CPU flags are unchanged.
 asl ; Shift left, putting outgoing bit in carry.
; Book line 1456: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 rol $fc ; Shift left through carry, extending a low-byte shift into a high byte.
; Book line 1457: Rotate the byte at $fc left through carry: old C enters bit 0 and old bit 7 becomes
; C. Update Z and N from the result.
 asl ; Shift left, putting outgoing bit in carry.
; Book line 1458: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 rol $fc ; Shift left through carry, extending a low-byte shift into a high byte.
; Book line 1459: Rotate the byte at $fc left through carry: old C enters bit 0 and old bit 7 becomes
; C. Update Z and N from the result.
 asl ; Shift left, putting outgoing bit in carry.
; Book line 1460: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 rol $fc ; Shift left through carry, extending a low-byte shift into a high byte.
; Book line 1461: Rotate the byte at $fc left through carry: old C enters bit 0 and old bit 7 becomes
; C. Update Z and N from the result.
 clc ; Clear carry before addition, or return C=0.
; Book line 1462: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc localy ; Add operand and carry to A.
; Book line 1463: Add the byte at localy and incoming carry to A. Update C, Z, N and V according to
; CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $fb ; Pointer low byte.
; Book line 1464: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda $fc
; Book line 1465: Load A with the byte at $fc. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 ora #$30 ; Set selected bits, preserving others.
; Book line 1466: Set A bits present in either A or literal $30 (decimal 48). Save the result in A and
; update Z and N; carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 1467: Store A into the byte at $fc. The register and CPU flags are unchanged.
 ldy #0 ; Load literal value into Y.
; Book line 1468: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 lda ($fb),y ; Read through pointer plus Y.
; Book line 1469: Load A with the byte at the address in zero-page pair $fb and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
 ldy localx ; Read localx.
; Book line 1470: Load Y with the byte at localx. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and pairmask,y ; Keep only masked bits.
; Book line 1471: Keep only bits set in both A and the byte at pairmask plus index Y. Save the result
; in A and update Z and N; carry is unchanged.
 beq air ; Branch if zero/equal (Z=1).
; Book line 1472: Branch to air if Z is 1 (zero or equal); otherwise continue at the next instruction.
; Test the current flag, and leave all flags unchanged.
solid:
; Book line 1473: solid names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1474: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 rts ; Return to caller.
; Book line 1475: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
air:
; Book line 1476: air names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 clc ; Clear carry before addition, or return C=0.
; Book line 1477: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 rts ; Return to caller.
; Book line 1478: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; WHAT: Produce repeatable cheap variation
; WHY: Stars and target types need variety
; HOW: Shift seed, XOR $1d if the old high bit was set, and save it. Keep seed nonzero; result
; is also in A.
; ============================================================================
random:
; Book line 1487: random names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda seed ; Read seed.
; Book line 1488: Load A with the byte at seed. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 asl ; Shift left, putting outgoing bit in carry.
; Book line 1489: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 bcc rngok ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1490: Branch to rngok if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 eor #$1d ; Toggle the mask bits with XOR.
; Book line 1491: Toggle A bits selected by literal $1d (decimal 29). Save the result in A and update
; Z and N; carry is unchanged.
rngok:
; Book line 1492: rngok names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 sta seed ; Store seed.
; Book line 1493: Store A into the byte at seed. The register and CPU flags are unchanged.
 rts ; Return to caller.
; Book line 1494: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Build a fresh right-hand column in the inactive screen.

; ============================================================================
; WHAT: Build the next landscape column offscreen
; WHY: Fine scrolling needs fresh data beyond the right edge
; HOW: Look up 32-column floor/roof profiles and edge glyphs. Suppress roof for 64 world
; columns, blend 12 entrance columns, then keep the cave. Write inactive column 39.
; ============================================================================
column:
; Book line 1504: column names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda phase ; Read phase.
; Book line 1505: Load A with the byte at phase. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #31 ; Keep only masked bits.
; Book line 1506: Keep only bits set in both A and literal 31. Save the result in A and update Z and
; N; carry is unchanged.
 tax ; Copy A to X.
; Book line 1507: Copy A to X; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda floors,x ; Read indexed table or screen entry.
; Book line 1508: Load A with the byte at floors plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta floorrow ; Store floorrow.
; Book line 1509: Store A into the byte at floorrow. The register and CPU flags are unchanged.
 lda ceilings,x ; Read indexed table or screen entry.
; Book line 1510: Load A with the byte at ceilings plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta ceilrow ; Store ceilrow.
; Book line 1511: Store A into the byte at ceilrow. The register and CPU flags are unchanged.
 lda floorids,x ; Read indexed table or screen entry.
; Book line 1512: Load A with the byte at floorids plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
 sta floortileid ; Store floortileid.
; Book line 1513: Store A into the byte at floortileid. The register and CPU flags are unchanged.
 txa ; Copy X to A.
; Book line 1514: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
 asl ; Shift left, putting outgoing bit in carry.
; Book line 1515: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc ; Clear carry before addition, or return C=0.
; Book line 1516: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #161 ; Add operand and carry to A.
; Book line 1517: Add literal 161 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ceiltileid ; Store ceiltileid.
; Book line 1518: Store A into the byte at ceiltileid. The register and CPU flags are unchanged.
 ; One-time approach: 64 open-sky columns, then a 12-column cave mouth.
 lda opening_col ; Read opening_col.
; Book line 1520: Load A with the byte at opening_col. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 cmp #76 ; Compare; change flags, preserve register.
; Book line 1521: Compare A with literal 76 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs roof_ready ; Branch if C=1; after compare, value was at least as large.
; Book line 1522: Branch to roof_ready if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 cmp #64 ; Compare; change flags, preserve register.
; Book line 1523: Compare A with literal 64 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcs entrance_roof ; Branch if C=1; after compare, value was at least as large.
; Book line 1524: Branch to entrance_roof if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 lda #0 ; Load literal value into A.
; Book line 1525: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ceilrow ; Store ceilrow.
; Book line 1526: Store A into the byte at ceilrow. The register and CPU flags are unchanged.
 lda #251 ; two blank surface glyphs: no roof above the ground
; Book line 1527: Load A with literal 251. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ceiltileid ; Store ceiltileid.
; Book line 1528: Store A into the byte at ceiltileid. The register and CPU flags are unchanged.
 jmp advance_opening ; Continue at advance_opening without a return address.
; Book line 1529: Continue execution at advance_opening without saving a return address. Registers and
; flags are unchanged by the jump itself.
entrance_roof:
; Book line 1530: entrance_roof names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1531: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc #64 ; Subtract operand and (1-carry) from A.
; Book line 1532: Subtract literal 64 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 tay ; Copy A to Y.
; Book line 1533: Copy A to Y; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
 lda entrance_rows,y ; Read indexed table or screen entry.
; Book line 1534: Load A with the byte at entrance_rows plus index Y. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta ceilrow ; Store ceilrow.
; Book line 1535: Store A into the byte at ceilrow. The register and CPU flags are unchanged.
 tya ; Copy Y to A.
; Book line 1536: Copy Y to A; leave Y unchanged. Update Z and N from the copied value; carry is
; unchanged.
 asl ; Shift left, putting outgoing bit in carry.
; Book line 1537: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
 clc ; Clear carry before addition, or return C=0.
; Book line 1538: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #227 ; Add operand and carry to A.
; Book line 1539: Add literal 227 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ceiltileid ; Store ceiltileid.
; Book line 1540: Store A into the byte at ceiltileid. The register and CPU flags are unchanged.
advance_opening:
; Book line 1541: advance_opening names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 inc opening_col ; Increase byte by one; wraps at 0/255.
; Book line 1542: Increase the byte at opening_col by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
roof_ready:
; Book line 1543: roof_ready names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 inc phase ; Increase byte by one; wraps at 0/255.
; Book line 1544: Increase the byte at phase by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
 lda back ; Read back.
; Book line 1545: Load A with the byte at back (screen buffer selection). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 eor #8 ; Toggle the mask bits with XOR.
; Book line 1546: Toggle A bits selected by literal 8. Save the result in A and update Z and N; carry
; is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1547: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #4 ; Add operand and carry to A.
; Book line 1548: Add literal 4 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $fe ; Destination pointer high byte.
; Book line 1549: Store A into the byte at $fe. The register and CPU flags are unchanged.
 lda #39 ; Load literal value into A.
; Book line 1550: Load A with literal 39. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 1551: Store A into the byte at $fd. The register and CPU flags are unchanged.
 ldx #0 ; Load literal value into X.
; Book line 1552: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
colloop:
; Book line 1553: colloop names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #32 ; Load literal value into A.
; Book line 1554: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
 cpx #2 ; Compare; change flags, preserve register.
; Book line 1555: Compare X with literal 2 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc putcol ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1556: Branch to putcol if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 cpx ceilrow ; Compare; change flags, preserve register.
; Book line 1557: Compare X with the byte at ceilrow without changing X. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 bcc innerrock ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1558: Branch to innerrock if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 beq ceiling_first ; Branch if zero/equal (Z=1).
; Book line 1559: Branch to ceiling_first if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 txa ; Copy X to A.
; Book line 1560: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1561: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc ceilrow ; Subtract operand and (1-carry) from A.
; Book line 1562: Subtract the byte at ceilrow and (1 minus incoming carry) from A. Update C, Z, N and
; V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp #1 ; Compare; change flags, preserve register.
; Book line 1563: Compare A with literal 1 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq ceiling_second ; Branch if zero/equal (Z=1).
; Book line 1564: Branch to ceiling_second if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 cpx floorrow ; Compare; change flags, preserve register.
; Book line 1565: Compare X with the byte at floorrow without changing X. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
 bcc sky_tile ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1566: Branch to sky_tile if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 beq floor_first ; Branch if zero/equal (Z=1).
; Book line 1567: Branch to floor_first if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 txa ; Copy X to A.
; Book line 1568: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1569: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc floorrow ; Subtract operand and (1-carry) from A.
; Book line 1570: Subtract the byte at floorrow and (1 minus incoming carry) from A. Update C, Z, N
; and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 cmp #1 ; Compare; change flags, preserve register.
; Book line 1571: Compare A with literal 1 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 beq floor_second ; Branch if zero/equal (Z=1).
; Book line 1572: Branch to floor_second if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
innerrock:
; Book line 1573: innerrock names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #96 ; Load literal value into A.
; Book line 1574: Load A with literal 96. Z records a zero value; N copies bit 7. Carry is unchanged.
 bne putcol ; Branch if not zero/equal (Z=0).
; Book line 1575: Branch to putcol if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
ceiling_first:
; Book line 1576: ceiling_first names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda ceiltileid ; Read ceiltileid.
; Book line 1577: Load A with the byte at ceiltileid. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 bne putcol ; Branch if not zero/equal (Z=0).
; Book line 1578: Branch to putcol if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
ceiling_second:
; Book line 1579: ceiling_second names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda ceiltileid ; Read ceiltileid.
; Book line 1580: Load A with the byte at ceiltileid. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1581: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #1 ; Add operand and carry to A.
; Book line 1582: Add literal 1 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 bne putcol ; Branch if not zero/equal (Z=0).
; Book line 1583: Branch to putcol if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
floor_first:
; Book line 1584: floor_first names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda floortileid ; Read floortileid.
; Book line 1585: Load A with the byte at floortileid. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 bne putcol ; Branch if not zero/equal (Z=0).
; Book line 1586: Branch to putcol if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
floor_second:
; Book line 1587: floor_second names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 lda floortileid ; Read floortileid.
; Book line 1588: Load A with the byte at floortileid. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1589: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #1 ; Add operand and carry to A.
; Book line 1590: Add literal 1 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 bne putcol ; Branch if not zero/equal (Z=0).
; Book line 1591: Branch to putcol if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
sky_tile:
; Book line 1592: sky_tile names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr random ; Call random; RTS returns here.
; Book line 1593: Call random, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 and #63 ; Keep only masked bits.
; Book line 1594: Keep only bits set in both A and literal 63. Save the result in A and update Z and
; N; carry is unchanged.
 bne emptytile ; Branch if not zero/equal (Z=0).
; Book line 1595: Branch to emptytile if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #94 ; Load literal value into A.
; Book line 1596: Load A with literal 94. Z records a zero value; N copies bit 7. Carry is unchanged.
 bne putcol ; Branch if not zero/equal (Z=0).
; Book line 1597: Branch to putcol if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
emptytile:
; Book line 1598: emptytile names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #32 ; Load literal value into A.
; Book line 1599: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
putcol:
; Book line 1600: putcol names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ldy #0 ; Load literal value into Y.
; Book line 1601: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta ($fd),y ; Write through pointer plus Y.
; Book line 1602: Store A into the byte at the address in zero-page pair $fd and its next byte, plus
; Y. The register and CPU flags are unchanged.
 lda $fd
; Book line 1603: Load A with the byte at $fd. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1604: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #40 ; Add operand and carry to A.
; Book line 1605: Add literal 40 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $fd ; Destination pointer low byte.
; Book line 1606: Store A into the byte at $fd. The register and CPU flags are unchanged.
 bcc colnext ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1607: Branch to colnext if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 inc $fe ; Increase byte by one; wraps at 0/255.
; Book line 1608: Increase the byte at $fe by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
colnext:
; Book line 1609: colnext names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 inx ; Next X index; 255 wraps to zero.
; Book line 1610: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #24 ; Compare; change flags, preserve register.
; Book line 1611: Compare X with literal 24 without changing X. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne colloop ; Branch if not zero/equal (Z=0).
; Book line 1612: Branch to colloop if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts ; Return to caller.
; Book line 1613: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; WHAT: Shift the hidden startup build screen
; WHY: Generate a complete landscape before reveal
; HOW: Move rows 2..23 in B left one cell, then mirror to A. No frame wait here because display
; is off.
; ============================================================================
shift_initial:
; Book line 1622: shift_initial names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 ; Initial landscape is generated in $0c00 then shifted there.
 ldy #0 ; Load literal value into Y.
; Book line 1624: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
si:
; Book line 1625: si names this assembled address; it emits no bytes and provides a jump, call or data
; reference target.
 lda $0c51,y ; Read indexed table or screen entry.
; Book line 1626: Load A with the byte at $0c51 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0c50,y
; Book line 1627: Store A into the byte at $0c50 plus index Y. The register and CPU flags are
; unchanged.
 lda $0c79,y ; Read indexed table or screen entry.
; Book line 1628: Load A with the byte at $0c79 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0c78,y
; Book line 1629: Store A into the byte at $0c78 plus index Y. The register and CPU flags are
; unchanged.
 lda $0ca1,y ; Read indexed table or screen entry.
; Book line 1630: Load A with the byte at $0ca1 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0ca0,y
; Book line 1631: Store A into the byte at $0ca0 plus index Y. The register and CPU flags are
; unchanged.
 lda $0cc9,y ; Read indexed table or screen entry.
; Book line 1632: Load A with the byte at $0cc9 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0cc8,y
; Book line 1633: Store A into the byte at $0cc8 plus index Y. The register and CPU flags are
; unchanged.
 lda $0cf1,y ; Read indexed table or screen entry.
; Book line 1634: Load A with the byte at $0cf1 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0cf0,y
; Book line 1635: Store A into the byte at $0cf0 plus index Y. The register and CPU flags are
; unchanged.
 lda $0d19,y ; Read indexed table or screen entry.
; Book line 1636: Load A with the byte at $0d19 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0d18,y
; Book line 1637: Store A into the byte at $0d18 plus index Y. The register and CPU flags are
; unchanged.
 lda $0d41,y ; Read indexed table or screen entry.
; Book line 1638: Load A with the byte at $0d41 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0d40,y
; Book line 1639: Store A into the byte at $0d40 plus index Y. The register and CPU flags are
; unchanged.
 lda $0d69,y ; Read indexed table or screen entry.
; Book line 1640: Load A with the byte at $0d69 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0d68,y
; Book line 1641: Store A into the byte at $0d68 plus index Y. The register and CPU flags are
; unchanged.
 lda $0d91,y ; Read indexed table or screen entry.
; Book line 1642: Load A with the byte at $0d91 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0d90,y
; Book line 1643: Store A into the byte at $0d90 plus index Y. The register and CPU flags are
; unchanged.
 lda $0db9,y ; Read indexed table or screen entry.
; Book line 1644: Load A with the byte at $0db9 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0db8,y
; Book line 1645: Store A into the byte at $0db8 plus index Y. The register and CPU flags are
; unchanged.
 lda $0de1,y ; Read indexed table or screen entry.
; Book line 1646: Load A with the byte at $0de1 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0de0,y
; Book line 1647: Store A into the byte at $0de0 plus index Y. The register and CPU flags are
; unchanged.
 lda $0e09,y ; Read indexed table or screen entry.
; Book line 1648: Load A with the byte at $0e09 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0e08,y
; Book line 1649: Store A into the byte at $0e08 plus index Y. The register and CPU flags are
; unchanged.
 lda $0e31,y ; Read indexed table or screen entry.
; Book line 1650: Load A with the byte at $0e31 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0e30,y
; Book line 1651: Store A into the byte at $0e30 plus index Y. The register and CPU flags are
; unchanged.
 lda $0e59,y ; Read indexed table or screen entry.
; Book line 1652: Load A with the byte at $0e59 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0e58,y
; Book line 1653: Store A into the byte at $0e58 plus index Y. The register and CPU flags are
; unchanged.
 lda $0e81,y ; Read indexed table or screen entry.
; Book line 1654: Load A with the byte at $0e81 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0e80,y
; Book line 1655: Store A into the byte at $0e80 plus index Y. The register and CPU flags are
; unchanged.
 lda $0ea9,y ; Read indexed table or screen entry.
; Book line 1656: Load A with the byte at $0ea9 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0ea8,y
; Book line 1657: Store A into the byte at $0ea8 plus index Y. The register and CPU flags are
; unchanged.
 lda $0ed1,y ; Read indexed table or screen entry.
; Book line 1658: Load A with the byte at $0ed1 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0ed0,y
; Book line 1659: Store A into the byte at $0ed0 plus index Y. The register and CPU flags are
; unchanged.
 lda $0ef9,y ; Read indexed table or screen entry.
; Book line 1660: Load A with the byte at $0ef9 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0ef8,y
; Book line 1661: Store A into the byte at $0ef8 plus index Y. The register and CPU flags are
; unchanged.
 lda $0f21,y ; Read indexed table or screen entry.
; Book line 1662: Load A with the byte at $0f21 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0f20,y
; Book line 1663: Store A into the byte at $0f20 plus index Y. The register and CPU flags are
; unchanged.
 lda $0f49,y ; Read indexed table or screen entry.
; Book line 1664: Load A with the byte at $0f49 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0f48,y
; Book line 1665: Store A into the byte at $0f48 plus index Y. The register and CPU flags are
; unchanged.
 lda $0f71,y ; Read indexed table or screen entry.
; Book line 1666: Load A with the byte at $0f71 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0f70,y
; Book line 1667: Store A into the byte at $0f70 plus index Y. The register and CPU flags are
; unchanged.
 lda $0f99,y ; Read indexed table or screen entry.
; Book line 1668: Load A with the byte at $0f99 plus index Y. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0f98,y
; Book line 1669: Store A into the byte at $0f98 plus index Y. The register and CPU flags are
; unchanged.
 iny ; Next Y index; 255 wraps to zero.
; Book line 1670: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpy #39 ; Compare; change flags, preserve register.
; Book line 1671: Compare Y with literal 39 without changing Y. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq sidone ; Branch if zero/equal (Z=1).
; Book line 1672: Branch to sidone if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp si ; Continue at si without a return address.
; Book line 1673: Continue execution at si without saving a return address. Registers and flags are
; unchanged by the jump itself.
sidone:
; Book line 1674: sidone names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ldx #0 ; Load literal value into X.
; Book line 1675: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
sicopy:
; Book line 1676: sicopy names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda $0c00,x ; Read indexed table or screen entry.
; Book line 1677: Load A with the byte at $0c00 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0400,x
; Book line 1678: Store A into the byte at $0400 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 lda $0d00,x ; Read indexed table or screen entry.
; Book line 1679: Load A with the byte at $0d00 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0500,x
; Book line 1680: Store A into the byte at $0500 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 lda $0e00,x ; Read indexed table or screen entry.
; Book line 1681: Load A with the byte at $0e00 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0600,x
; Book line 1682: Store A into the byte at $0600 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 lda $0f00,x ; Read indexed table or screen entry.
; Book line 1683: Load A with the byte at $0f00 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
 sta $0700,x
; Book line 1684: Store A into the byte at $0700 (screen RAM in the $0400 screen) plus index X. The
; register and CPU flags are unchanged.
 inx ; Next X index; 255 wraps to zero.
; Book line 1685: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne sicopy ; Branch if not zero/equal (Z=0).
; Book line 1686: Branch to sicopy if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts ; Return to caller.
; Book line 1687: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; WHAT: Reverse the unrolled copy direction
; WHY: Each buffer swap reverses source and destination
; HOW: Tables locate the HIGH address bytes inside LDA/STA instructions. EOR #8 toggles $04xx
; and $0cxx. cr2+2 means byte 2 of a three-byte instruction: self-modifying code.
; ============================================================================
patchcopy:
; Book line 1696: patchcopy names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ldx #0 ; Load literal value into X.
; Book line 1697: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
pc_loop:
; Book line 1698: pc_loop names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda copyreadhi,x ; Read indexed table or screen entry.
; Book line 1699: Load A with the byte at copyreadhi plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 1700: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda copyreadhi_h,x ; Read indexed table or screen entry.
; Book line 1701: Load A with the byte at copyreadhi_h plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 1702: Store A into the byte at $fc. The register and CPU flags are unchanged.
 ldy #0 ; Load literal value into Y.
; Book line 1703: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 lda ($fb),y ; Read through pointer plus Y.
; Book line 1704: Load A with the byte at the address in zero-page pair $fb and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
 eor #8 ; Toggle the mask bits with XOR.
; Book line 1705: Toggle A bits selected by literal 8. Save the result in A and update Z and N; carry
; is unchanged.
 sta ($fb),y ; Write through pointer plus Y.
; Book line 1706: Store A into the byte at the address in zero-page pair $fb and its next byte, plus
; Y. The register and CPU flags are unchanged.
 lda copywritehi,x ; Read indexed table or screen entry.
; Book line 1707: Load A with the byte at copywritehi plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 1708: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda copywritehi_h,x ; Read indexed table or screen entry.
; Book line 1709: Load A with the byte at copywritehi_h plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 1710: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda ($fb),y ; Read through pointer plus Y.
; Book line 1711: Load A with the byte at the address in zero-page pair $fb and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
 eor #8 ; Toggle the mask bits with XOR.
; Book line 1712: Toggle A bits selected by literal 8. Save the result in A and update Z and N; carry
; is unchanged.
 sta ($fb),y ; Write through pointer plus Y.
; Book line 1713: Store A into the byte at the address in zero-page pair $fb and its next byte, plus
; Y. The register and CPU flags are unchanged.
 inx ; Next X index; 255 wraps to zero.
; Book line 1714: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #22 ; Compare; change flags, preserve register.
; Book line 1715: Compare X with literal 22 without changing X. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne pc_loop ; Branch if not zero/equal (Z=0).
; Book line 1716: Branch to pc_loop if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts ; Return to caller.
; Book line 1717: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ============================================================================
; WHAT: Prepare a one-character shift
; WHY: Hardware fine scroll has only eight offsets
; HOW: Y=0..38; each unrolled pair reads source Y+1 and writes destination Y. Rows 0/1 are
; excluded for HUD/separator. column fills the new right edge.
; ============================================================================
coarse:
; Book line 1725: coarse names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 ldy #0 ; Load literal value into Y.
; Book line 1726: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
coarseloop:
; Book line 1727: coarseloop names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
cr2: lda $0451,y ; Read indexed table or screen entry.
; Book line 1728: cr2 names the data or instruction address. Load A with the byte at $0451 (screen RAM
; in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw2: sta $0c50,y
; Book line 1729: cw2 names the data or instruction address. Store A into the byte at $0c50 plus index
; Y. The register and CPU flags are unchanged.
cr3: lda $0479,y ; Read indexed table or screen entry.
; Book line 1730: cr3 names the data or instruction address. Load A with the byte at $0479 (screen RAM
; in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw3: sta $0c78,y
; Book line 1731: cw3 names the data or instruction address. Store A into the byte at $0c78 plus index
; Y. The register and CPU flags are unchanged.
cr4: lda $04a1,y ; Read indexed table or screen entry.
; Book line 1732: cr4 names the data or instruction address. Load A with the byte at $04a1 (screen RAM
; in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw4: sta $0ca0,y
; Book line 1733: cw4 names the data or instruction address. Store A into the byte at $0ca0 plus index
; Y. The register and CPU flags are unchanged.
cr5: lda $04c9,y ; Read indexed table or screen entry.
; Book line 1734: cr5 names the data or instruction address. Load A with the byte at $04c9 (screen RAM
; in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw5: sta $0cc8,y
; Book line 1735: cw5 names the data or instruction address. Store A into the byte at $0cc8 plus index
; Y. The register and CPU flags are unchanged.
cr6: lda $04f1,y ; Read indexed table or screen entry.
; Book line 1736: cr6 names the data or instruction address. Load A with the byte at $04f1 (screen RAM
; in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw6: sta $0cf0,y
; Book line 1737: cw6 names the data or instruction address. Store A into the byte at $0cf0 plus index
; Y. The register and CPU flags are unchanged.
cr7: lda $0519,y ; Read indexed table or screen entry.
; Book line 1738: cr7 names the data or instruction address. Load A with the byte at $0519 (screen RAM
; in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw7: sta $0d18,y
; Book line 1739: cw7 names the data or instruction address. Store A into the byte at $0d18 plus index
; Y. The register and CPU flags are unchanged.
cr8: lda $0541,y ; Read indexed table or screen entry.
; Book line 1740: cr8 names the data or instruction address. Load A with the byte at $0541 (screen RAM
; in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw8: sta $0d40,y
; Book line 1741: cw8 names the data or instruction address. Store A into the byte at $0d40 plus index
; Y. The register and CPU flags are unchanged.
cr9: lda $0569,y ; Read indexed table or screen entry.
; Book line 1742: cr9 names the data or instruction address. Load A with the byte at $0569 (screen RAM
; in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw9: sta $0d68,y
; Book line 1743: cw9 names the data or instruction address. Store A into the byte at $0d68 plus index
; Y. The register and CPU flags are unchanged.
cr10: lda $0591,y ; Read indexed table or screen entry.
; Book line 1744: cr10 names the data or instruction address. Load A with the byte at $0591 (screen
; RAM in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw10: sta $0d90,y
; Book line 1745: cw10 names the data or instruction address. Store A into the byte at $0d90 plus
; index Y. The register and CPU flags are unchanged.
cr11: lda $05b9,y ; Read indexed table or screen entry.
; Book line 1746: cr11 names the data or instruction address. Load A with the byte at $05b9 (screen
; RAM in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw11: sta $0db8,y
; Book line 1747: cw11 names the data or instruction address. Store A into the byte at $0db8 plus
; index Y. The register and CPU flags are unchanged.
cr12: lda $05e1,y ; Read indexed table or screen entry.
; Book line 1748: cr12 names the data or instruction address. Load A with the byte at $05e1 (screen
; RAM in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw12: sta $0de0,y
; Book line 1749: cw12 names the data or instruction address. Store A into the byte at $0de0 plus
; index Y. The register and CPU flags are unchanged.
cr13: lda $0609,y ; Read indexed table or screen entry.
; Book line 1750: cr13 names the data or instruction address. Load A with the byte at $0609 (screen
; RAM in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw13: sta $0e08,y
; Book line 1751: cw13 names the data or instruction address. Store A into the byte at $0e08 plus
; index Y. The register and CPU flags are unchanged.
cr14: lda $0631,y ; Read indexed table or screen entry.
; Book line 1752: cr14 names the data or instruction address. Load A with the byte at $0631 (screen
; RAM in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw14: sta $0e30,y
; Book line 1753: cw14 names the data or instruction address. Store A into the byte at $0e30 plus
; index Y. The register and CPU flags are unchanged.
cr15: lda $0659,y ; Read indexed table or screen entry.
; Book line 1754: cr15 names the data or instruction address. Load A with the byte at $0659 (screen
; RAM in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw15: sta $0e58,y
; Book line 1755: cw15 names the data or instruction address. Store A into the byte at $0e58 plus
; index Y. The register and CPU flags are unchanged.
cr16: lda $0681,y ; Read indexed table or screen entry.
; Book line 1756: cr16 names the data or instruction address. Load A with the byte at $0681 (screen
; RAM in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw16: sta $0e80,y
; Book line 1757: cw16 names the data or instruction address. Store A into the byte at $0e80 plus
; index Y. The register and CPU flags are unchanged.
cr17: lda $06a9,y ; Read indexed table or screen entry.
; Book line 1758: cr17 names the data or instruction address. Load A with the byte at $06a9 (screen
; RAM in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw17: sta $0ea8,y
; Book line 1759: cw17 names the data or instruction address. Store A into the byte at $0ea8 plus
; index Y. The register and CPU flags are unchanged.
cr18: lda $06d1,y ; Read indexed table or screen entry.
; Book line 1760: cr18 names the data or instruction address. Load A with the byte at $06d1 (screen
; RAM in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw18: sta $0ed0,y
; Book line 1761: cw18 names the data or instruction address. Store A into the byte at $0ed0 plus
; index Y. The register and CPU flags are unchanged.
cr19: lda $06f9,y ; Read indexed table or screen entry.
; Book line 1762: cr19 names the data or instruction address. Load A with the byte at $06f9 (screen
; RAM in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw19: sta $0ef8,y
; Book line 1763: cw19 names the data or instruction address. Store A into the byte at $0ef8 plus
; index Y. The register and CPU flags are unchanged.
cr20: lda $0721,y ; Read indexed table or screen entry.
; Book line 1764: cr20 names the data or instruction address. Load A with the byte at $0721 (screen
; RAM in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw20: sta $0f20,y
; Book line 1765: cw20 names the data or instruction address. Store A into the byte at $0f20 plus
; index Y. The register and CPU flags are unchanged.
cr21: lda $0749,y ; Read indexed table or screen entry.
; Book line 1766: cr21 names the data or instruction address. Load A with the byte at $0749 (screen
; RAM in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw21: sta $0f48,y
; Book line 1767: cw21 names the data or instruction address. Store A into the byte at $0f48 plus
; index Y. The register and CPU flags are unchanged.
cr22: lda $0771,y ; Read indexed table or screen entry.
; Book line 1768: cr22 names the data or instruction address. Load A with the byte at $0771 (screen
; RAM in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw22: sta $0f70,y
; Book line 1769: cw22 names the data or instruction address. Store A into the byte at $0f70 plus
; index Y. The register and CPU flags are unchanged.
cr23: lda $0799,y ; Read indexed table or screen entry.
; Book line 1770: cr23 names the data or instruction address. Load A with the byte at $0799 (screen
; RAM in the $0400 screen) plus index Y. Z records a zero value; N copies bit 7. Carry is unchanged.
cw23: sta $0f98,y
; Book line 1771: cw23 names the data or instruction address. Store A into the byte at $0f98 plus
; index Y. The register and CPU flags are unchanged.
 iny ; Next Y index; 255 wraps to zero.
; Book line 1772: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpy #39 ; Compare; change flags, preserve register.
; Book line 1773: Compare Y with literal 39 without changing Y. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 beq coarseend ; Branch if zero/equal (Z=1).
; Book line 1774: Branch to coarseend if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jmp coarseloop ; Continue at coarseloop without a return address.
; Book line 1775: Continue execution at coarseloop without saving a return address. Registers and
; flags are unchanged by the jump itself.
coarseend: rts ; Return to caller.
; Book line 1776: coarseend names the data or instruction address. Pull the saved subroutine return
; address from the stack and resume after its JSR. Do not use this as an interrupt return.


; ============================================================================
; WHAT: Set shared colour RAM
; WHY: Screens are double-buffered but colour RAM is not
; HOW: Rows 0/1 get cyan 3. Terrain gets 9: bit 3 enables multicolour, local colour 1 supplies
; pale edges; D022=2 and D023=10 supply red/rose.
; ============================================================================
colors:
; Book line 1785: colors names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #<$d800 ; Take low address byte.
; Book line 1786: Load A with the low address byte of $d800 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 1787: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>$d800 ; Take high address byte.
; Book line 1788: Load A with the high address byte of $d800 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 1789: Store A into the byte at $fc. The register and CPU flags are unchanged.
 ldx #0 ; Load literal value into X.
; Book line 1790: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
colorrow:
; Book line 1791: colorrow names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 lda #3 ; Load literal value into A.
; Book line 1792: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
 cpx #2 ; Compare; change flags, preserve register.
; Book line 1793: Compare X with literal 2 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
 bcc colorfill ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1794: Branch to colorfill if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 lda #9 ; multicolour flag + pale rock-edge highlights
; Book line 1795: Load A with literal 9. Z records a zero value; N copies bit 7. Carry is unchanged.
colorfill:
; Book line 1796: colorfill names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 ldy #39 ; Load literal value into Y.
; Book line 1797: Load Y with literal 39. Z records a zero value; N copies bit 7. Carry is unchanged.
colorbyte:
; Book line 1798: colorbyte names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 sta ($fb),y ; Write through pointer plus Y.
; Book line 1799: Store A into the byte at the address in zero-page pair $fb and its next byte, plus
; Y. The register and CPU flags are unchanged.
 dey ; Previous Y index.
; Book line 1800: Decrease Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bpl colorbyte ; Branch while bit 7 of last result is clear.
; Book line 1801: Branch to colorbyte if N is 0 (bit 7 clear); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda $fb
; Book line 1802: Load A with the byte at $fb. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1803: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #40 ; Add operand and carry to A.
; Book line 1804: Add literal 40 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $fb ; Pointer low byte.
; Book line 1805: Store A into the byte at $fb. The register and CPU flags are unchanged.
 bcc colorcarry ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1806: Branch to colorcarry if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 inc $fc ; Increase byte by one; wraps at 0/255.
; Book line 1807: Increase the byte at $fc by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
colorcarry:
; Book line 1808: colorcarry names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 inx ; Next X index; 255 wraps to zero.
; Book line 1809: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 cpx #25 ; Compare; change flags, preserve register.
; Book line 1810: Compare X with literal 25 without changing X. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bne colorrow ; Branch if not zero/equal (Z=0).
; Book line 1811: Branch to colorrow if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts ; Return to caller.
; Book line 1812: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; WHAT: Update score fuel lives and sector
; WHY: Buffer swaps must not reveal stale HUD fields
; HOW: Print a 40-character template; overwrite fields; copy row to opposite buffer. Fuel uses
; ceiling(fuel/2) as a three-digit percentage.
; ============================================================================
hud:
; Book line 1821: hud names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda #<hudtext ; Take low address byte.
; Book line 1822: Load A with the low address byte of hudtext as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 1823: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>hudtext ; Take high address byte.
; Book line 1824: Load A with the high address byte of hudtext as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 1825: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda #$00 ; Load literal value into A.
; Book line 1826: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 1827: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #$04 ; Load literal value into A.
; Book line 1828: Load A with literal $04 (decimal 4). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1829: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc back ; Add operand and carry to A.
; Book line 1830: Add the byte at back (screen buffer selection) and incoming carry to A. Update C, Z,
; N and V according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 sta $fe ; Destination pointer high byte.
; Book line 1831: Store A into the byte at $fe. The register and CPU flags are unchanged.
 jsr print ; Call print; RTS returns here.
; Book line 1832: Call print, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 ldy #7 ; Load literal value into Y.
; Book line 1833: Load Y with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
 lda scorehi ; Read scorehi.
; Book line 1834: Load A with the byte at scorehi (score high byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 jsr hexbyte ; Call hexbyte; RTS returns here.
; Book line 1835: Call hexbyte, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda scorelo ; Read scorelo.
; Book line 1836: Load A with the byte at scorelo (score low byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 jsr hexbyte ; Call hexbyte; RTS returns here.
; Book line 1837: Call hexbyte, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 ; Display the real tank level as 000..100 percent, rounded up.
 lda fuel ; Read fuel.
; Book line 1839: Load A with the byte at fuel (fuel in half-percent units). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1840: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #1 ; Add operand and carry to A.
; Book line 1841: Add literal 1 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1842: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 ldx #48 ; Load literal value into X.
; Book line 1843: Load X with literal 48. Z records a zero value; N copies bit 7. Carry is unchanged.
 cmp #100 ; Compare; change flags, preserve register.
; Book line 1844: Compare A with literal 100 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc fuel_under100 ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1845: Branch to fuel_under100 if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1846: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc #100 ; Subtract operand and (1-carry) from A.
; Book line 1847: Subtract literal 100 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 inx ; Next X index; 255 wraps to zero.
; Book line 1848: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
fuel_under100:
; Book line 1849: fuel_under100 names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
 sta fuelpercent ; Store fuelpercent.
; Book line 1850: Store A into the byte at fuelpercent. The register and CPU flags are unchanged.
 ldy #17 ; Load literal value into Y.
; Book line 1851: Load Y with literal 17. Z records a zero value; N copies bit 7. Carry is unchanged.
 txa ; Copy X to A.
; Book line 1852: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
 sta ($fd),y ; Write through pointer plus Y.
; Book line 1853: Store A into the byte at the address in zero-page pair $fd and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny ; Next Y index; 255 wraps to zero.
; Book line 1854: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 lda fuelpercent ; Read fuelpercent.
; Book line 1855: Load A with the byte at fuelpercent. Z records a zero value; N copies bit 7. Carry
; is unchanged.
 ldx #48 ; Load literal value into X.
; Book line 1856: Load X with literal 48. Z records a zero value; N copies bit 7. Carry is unchanged.
fuel_tens:
; Book line 1857: fuel_tens names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 cmp #10 ; Compare; change flags, preserve register.
; Book line 1858: Compare A with literal 10 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
 bcc fuel_units ; Branch if C=0; after compare, unsigned value was smaller.
; Book line 1859: Branch to fuel_units if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
 sec ; Set carry before subtraction, or return C=1.
; Book line 1860: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
 sbc #10 ; Subtract operand and (1-carry) from A.
; Book line 1861: Subtract literal 10 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
 inx ; Next X index; 255 wraps to zero.
; Book line 1862: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 jmp fuel_tens ; Continue at fuel_tens without a return address.
; Book line 1863: Continue execution at fuel_tens without saving a return address. Registers and flags
; are unchanged by the jump itself.
fuel_units:
; Book line 1864: fuel_units names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 pha ; Push A on the CPU stack.
; Book line 1865: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 txa ; Copy X to A.
; Book line 1866: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
 sta ($fd),y ; Write through pointer plus Y.
; Book line 1867: Store A into the byte at the address in zero-page pair $fd and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny ; Next Y index; 255 wraps to zero.
; Book line 1868: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 pla ; Pull saved byte back into A.
; Book line 1869: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 clc ; Clear carry before addition, or return C=0.
; Book line 1870: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #48 ; Add operand and carry to A.
; Book line 1871: Add literal 48 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ($fd),y ; Write through pointer plus Y.
; Book line 1872: Store A into the byte at the address in zero-page pair $fd and its next byte, plus
; Y. The register and CPU flags are unchanged.
 ldy #28 ; Load literal value into Y.
; Book line 1873: Load Y with literal 28. Z records a zero value; N copies bit 7. Carry is unchanged.
 lda lives ; Read lives.
; Book line 1874: Load A with the byte at lives (remaining lives). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1875: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #48 ; Add operand and carry to A.
; Book line 1876: Add literal 48 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ($fd),y ; Write through pointer plus Y.
; Book line 1877: Store A into the byte at the address in zero-page pair $fd and its next byte, plus
; Y. The register and CPU flags are unchanged.
 ldy #37 ; Load literal value into Y.
; Book line 1878: Load Y with literal 37. Z records a zero value; N copies bit 7. Carry is unchanged.
 lda stage ; Read stage.
; Book line 1879: Load A with the byte at stage. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 and #7 ; Keep only masked bits.
; Book line 1880: Keep only bits set in both A and literal 7. Save the result in A and update Z and N;
; carry is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1881: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #49 ; Add operand and carry to A.
; Book line 1882: Add literal 49 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ($fd),y ; Write through pointer plus Y.
; Book line 1883: Store A into the byte at the address in zero-page pair $fd and its next byte, plus
; Y. The register and CPU flags are unchanged.
 ; Keep HUD consistent in both buffers.
 ldy #39 ; Load literal value into Y.
; Book line 1885: Load Y with literal 39. Z records a zero value; N copies bit 7. Carry is unchanged.
hudcopy:
; Book line 1886: hudcopy names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 lda ($fd),y ; Read through pointer plus Y.
; Book line 1887: Load A with the byte at the address in zero-page pair $fd and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
 pha ; Push A on the CPU stack.
; Book line 1888: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 lda $fe
; Book line 1889: Load A with the byte at $fe. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 eor #8 ; Toggle the mask bits with XOR.
; Book line 1890: Toggle A bits selected by literal 8. Save the result in A and update Z and N; carry
; is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 1891: Store A into the byte at $fe. The register and CPU flags are unchanged.
 pla ; Pull saved byte back into A.
; Book line 1892: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 sta ($fd),y ; Write through pointer plus Y.
; Book line 1893: Store A into the byte at the address in zero-page pair $fd and its next byte, plus
; Y. The register and CPU flags are unchanged.
 lda $fe
; Book line 1894: Load A with the byte at $fe. Z records a zero value; N copies bit 7. Carry is
; unchanged.
 eor #8 ; Toggle the mask bits with XOR.
; Book line 1895: Toggle A bits selected by literal 8. Save the result in A and update Z and N; carry
; is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 1896: Store A into the byte at $fe. The register and CPU flags are unchanged.
 dey ; Previous Y index.
; Book line 1897: Decrease Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bpl hudcopy ; Branch while bit 7 of last result is clear.
; Book line 1898: Branch to hudcopy if N is 0 (bit 7 clear); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 rts ; Return to caller.
; Book line 1899: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ============================================================================
; WHAT: Print two packed BCD digits
; WHY: Each nibble already represents one decimal digit
; HOW: Shift/mask, add screen digit code 48 and write at ($fd),Y. Advances Y twice; despite its
; name this is not arbitrary binary-to-decimal conversion.
; ============================================================================
hexbyte:
; Book line 1907: hexbyte names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 pha ; Push A on the CPU stack.
; Book line 1908: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1909: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1910: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1911: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 lsr ; Shift right, putting outgoing bit in carry.
; Book line 1912: Shift A right one bit, insert 0 at bit 7 and move old bit 0 to C. Update Z and N
; from the result.
 clc ; Clear carry before addition, or return C=0.
; Book line 1913: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #48 ; Add operand and carry to A.
; Book line 1914: Add literal 48 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ($fd),y ; Write through pointer plus Y.
; Book line 1915: Store A into the byte at the address in zero-page pair $fd and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny ; Next Y index; 255 wraps to zero.
; Book line 1916: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 pla ; Pull saved byte back into A.
; Book line 1917: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
 and #15 ; Keep only masked bits.
; Book line 1918: Keep only bits set in both A and literal 15. Save the result in A and update Z and
; N; carry is unchanged.
 clc ; Clear carry before addition, or return C=0.
; Book line 1919: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
 adc #48 ; Add operand and carry to A.
; Book line 1920: Add literal 48 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
 sta ($fd),y ; Write through pointer plus Y.
; Book line 1921: Store A into the byte at the address in zero-page pair $fd and its next byte, plus
; Y. The register and CPU flags are unchanged.
 iny ; Next Y index; 255 wraps to zero.
; Book line 1922: Increase Y by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 rts ; Return to caller.
; Book line 1923: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; WHAT: Show final score and restart
; WHY: A fresh run needs all state and copy direction reset
; HOW: Disable raster split, show text/score, wait for fire and patch copy orientation if
; back=$08 before newgame.
; ============================================================================
gameover:
; Book line 1932: gameover names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
 jsr raster_off ; Call raster_off; RTS returns here.
; Book line 1933: Call raster_off, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 lda #$81 ; Load literal value into A.
; Book line 1934: Load A with literal $81 (decimal 129). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d40b ; Write A to SID voice 2 control/gate.
; Book line 1935: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
 lda #$08 ; Load literal value into A.
; Book line 1936: Load A with literal $08 (decimal 8). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d408
; Book line 1937: Store A into the byte at $d408 (SID voice 2 frequency high). The register and CPU
; flags are unchanged.
 ldx #35 ; Load literal value into X.
; Book line 1938: Load X with literal 35. Z records a zero value; N copies bit 7. Carry is unchanged.
explode:
; Book line 1939: explode names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jsr frame ; Call frame; RTS returns here.
; Book line 1940: Call frame, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 txa ; Copy X to A.
; Book line 1941: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
 and #7 ; Keep only masked bits.
; Book line 1942: Keep only bits set in both A and literal 7. Save the result in A and update Z and N;
; carry is unchanged.
 sta $d027 ; Write A to player individual sprite colour.
; Book line 1943: Store A into the byte at $d027 (sprite 0 colour). The register and CPU flags are
; unchanged.
 dex ; Previous X index.
; Book line 1944: Decrease X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
 bne explode ; Branch if not zero/equal (Z=0).
; Book line 1945: Branch to explode if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 lda #0 ; Load literal value into A.
; Book line 1946: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d015 ; Write A to sprite enable bits.
; Book line 1947: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
 sta $d40b ; Write A to SID voice 2 control/gate.
; Book line 1948: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
 sta $d404 ; Write A to SID voice 1 control/gate.
; Book line 1949: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
 lda #$1c ; Load literal value into A.
; Book line 1950: Load A with literal $1c (decimal 28). Z records a zero value; N copies bit 7. Carry
; is unchanged.
 sta $d018 ; Write A to screen/font address selection.
; Book line 1951: Store A into the byte at $d018 (VIC screen and font selection). The register and CPU
; flags are unchanged.
 lda #8 ; Load literal value into A.
; Book line 1952: Load A with literal 8. Z records a zero value; N copies bit 7. Carry is unchanged.
 sta $d016 ; Write A to horizontal mode and fine-scroll bits.
; Book line 1953: Store A into the byte at $d016 (VIC horizontal control and fine scroll). The
; register and CPU flags are unchanged.
 jsr clear ; Call clear; RTS returns here.
; Book line 1954: Call clear, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda #<g1 ; Take low address byte.
; Book line 1955: Load A with the low address byte of g1 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 1956: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>g1 ; Take high address byte.
; Book line 1957: Load A with the high address byte of g1 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 1958: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda #<($04fc) ; Take low address byte.
; Book line 1959: Load A with the low address byte of ($04fc) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 1960: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #>($04fc) ; Take high address byte.
; Book line 1961: Load A with the high address byte of ($04fc) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 1962: Store A into the byte at $fe. The register and CPU flags are unchanged.
 jsr print ; Call print; RTS returns here.
; Book line 1963: Call print, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda #<g2 ; Take low address byte.
; Book line 1964: Load A with the low address byte of g2 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 1965: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>g2 ; Take high address byte.
; Book line 1966: Load A with the high address byte of g2 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 1967: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda #<($059a) ; Take low address byte.
; Book line 1968: Load A with the low address byte of ($059a) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 1969: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #>($059a) ; Take high address byte.
; Book line 1970: Load A with the high address byte of ($059a) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 1971: Store A into the byte at $fe. The register and CPU flags are unchanged.
 jsr print ; Call print; RTS returns here.
; Book line 1972: Call print, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda #<g3 ; Take low address byte.
; Book line 1973: Load A with the low address byte of g3 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 1974: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>g3 ; Take high address byte.
; Book line 1975: Load A with the high address byte of g3 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 1976: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda #<($0614) ; Take low address byte.
; Book line 1977: Load A with the low address byte of ($0614) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 1978: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #>($0614) ; Take high address byte.
; Book line 1979: Load A with the high address byte of ($0614) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 1980: Store A into the byte at $fe. The register and CPU flags are unchanged.
 jsr print ; Call print; RTS returns here.
; Book line 1981: Call print, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda #<($0400+13*40+25) ; Take low address byte.
; Book line 1982: Load A with the low address byte of ($0400+13*40+25) as an immediate value. Z
; records a zero value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 1983: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #>($0400+13*40+25) ; Take high address byte.
; Book line 1984: Load A with the high address byte of ($0400+13*40+25) as an immediate value. Z
; records a zero value; N copies bit 7. Carry is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 1985: Store A into the byte at $fe. The register and CPU flags are unchanged.
 ldy #0 ; Load literal value into Y.
; Book line 1986: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
 lda scorehi ; Read scorehi.
; Book line 1987: Load A with the byte at scorehi (score high byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 jsr hexbyte ; Call hexbyte; RTS returns here.
; Book line 1988: Call hexbyte, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda scorelo ; Read scorelo.
; Book line 1989: Load A with the byte at scorelo (score low byte). Z records a zero value; N copies
; bit 7. Carry is unchanged.
 jsr hexbyte ; Call hexbyte; RTS returns here.
; Book line 1990: Call hexbyte, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda #<g4 ; Take low address byte.
; Book line 1991: Load A with the low address byte of g4 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 1992: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>g4 ; Take high address byte.
; Book line 1993: Load A with the high address byte of g4 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 1994: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda #<($06d6) ; Take low address byte.
; Book line 1995: Load A with the low address byte of ($06d6) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 1996: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #>($06d6) ; Take high address byte.
; Book line 1997: Load A with the high address byte of ($06d6) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 1998: Store A into the byte at $fe. The register and CPU flags are unchanged.
 jsr print ; Call print; RTS returns here.
; Book line 1999: Call print, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 lda #<g5 ; Take low address byte.
; Book line 2000: Load A with the low address byte of g5 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fb ; Pointer low byte.
; Book line 2001: Store A into the byte at $fb. The register and CPU flags are unchanged.
 lda #>g5 ; Take high address byte.
; Book line 2002: Load A with the high address byte of g5 as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fc ; Pointer high byte.
; Book line 2003: Store A into the byte at $fc. The register and CPU flags are unchanged.
 lda #<($0750) ; Take low address byte.
; Book line 2004: Load A with the low address byte of ($0750) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fd ; Destination pointer low byte.
; Book line 2005: Store A into the byte at $fd. The register and CPU flags are unchanged.
 lda #>($0750) ; Take high address byte.
; Book line 2006: Load A with the high address byte of ($0750) as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
 sta $fe ; Destination pointer high byte.
; Book line 2007: Store A into the byte at $fe. The register and CPU flags are unchanged.
 jsr print ; Call print; RTS returns here.
; Book line 2008: Call print, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr release ; Call release; RTS returns here.
; Book line 2009: Call release, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
 jsr waitfire ; Call waitfire; RTS returns here.
; Book line 2010: Call waitfire, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
 ; Restore copy routine to its initial front/back orientation.
 lda back ; Read back.
; Book line 2012: Load A with the byte at back (screen buffer selection). Z records a zero value; N
; copies bit 7. Carry is unchanged.
 beq restart ; Branch if zero/equal (Z=1).
; Book line 2013: Branch to restart if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
 jsr patchcopy ; Call patchcopy; RTS returns here.
; Book line 2014: Call patchcopy, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
restart:
; Book line 2015: restart names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
 jmp newgame ; Continue at newgame without a return address.
; Book line 2016: Continue execution at newgame without saving a return address. Registers and flags
; are unchanged by the jump itself.

hudtext: !scr " score:0000 fuel:100% lives:3 sector:1  "
; Book line 2018: hudtext names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
 !byte 0
; Book line 2019: Emit 1 byte in the shown order for hudtext. These are data or encoded loader bytes,
; not instructions to execute.
t1: !scr "s t a r   s c r a m b l e"
; Book line 2020: t1 names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
 !byte 0
; Book line 2021: Emit 1 byte in the shown order for t1. These are data or encoded loader bytes, not
; instructions to execute.
t2: !scr "- c64 cavern assault -"
; Book line 2022: t2 names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
 !byte 0
; Book line 2023: Emit 1 byte in the shown order for t2. These are data or encoded loader bytes, not
; instructions to execute.
t3: !scr "fly low. strike fast. stay alive."
; Book line 2024: t3 names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
 !byte 0
; Book line 2025: Emit 1 byte in the shown order for t3. These are data or encoded loader bytes, not
; instructions to execute.
t4: !scr "joystick port 2  /  w a s d"
; Book line 2026: t4 names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
 !byte 0
; Book line 2027: Emit 1 byte in the shown order for t4. These are data or encoded loader bytes, not
; instructions to execute.
t5: !scr "fire / space : guns and bombs"
; Book line 2028: t5 names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
 !byte 0
; Book line 2029: Emit 1 byte in the shown order for t5. These are data or encoded loader bytes, not
; instructions to execute.
t6: !scr "bomb fuel depots to refill tank"
; Book line 2030: t6 names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
 !byte 0
; Book line 2031: Emit 1 byte in the shown order for t6. These are data or encoded loader bytes, not
; instructions to execute.
t7: !scr "press fire or space to fly"
; Book line 2032: t7 names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
 !byte 0
; Book line 2033: Emit 1 byte in the shown order for t7. These are data or encoded loader bytes, not
; instructions to execute.
t8: !scr "original graphics / 1 pixel scroll"
; Book line 2034: t8 names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
 !byte 0
; Book line 2035: Emit 1 byte in the shown order for t8. These are data or encoded loader bytes, not
; instructions to execute.
g1: !scr "g a m e  o v e r"
; Book line 2036: g1 names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
 !byte 0
; Book line 2037: Emit 1 byte in the shown order for g1. These are data or encoded loader bytes, not
; instructions to execute.
g2: !scr "your mission has ended"
; Book line 2038: g2 names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
 !byte 0
; Book line 2039: Emit 1 byte in the shown order for g2. These are data or encoded loader bytes, not
; instructions to execute.
g3: !scr "final score:"
; Book line 2040: g3 names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
 !byte 0
; Book line 2041: Emit 1 byte in the shown order for g3. These are data or encoded loader bytes, not
; instructions to execute.
g4: !scr "press fire or space to restart"
; Book line 2042: g4 names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
 !byte 0
; Book line 2043: Emit 1 byte in the shown order for g4. These are data or encoded loader bytes, not
; instructions to execute.
g5: !scr "the cavern is waiting..."
; Book line 2044: g5 names the data or instruction address. Encode the quoted string as Commodore
; screen-code data for direct screen-memory display.
 !byte 0
; Book line 2045: Emit 1 byte in the shown order for g5. These are data or encoded loader bytes, not
; instructions to execute.
; DATA: Low bytes of $0400+40*row.
rowlo: !byte <($0400),<($0428),<($0450),<($0478),<($04a0),<($04c8),<($04f0),<($0518)
; Book line 2047: rowlo names the data or instruction address. Emit 8 bytes in the shown order for
; rowlo. These are data or encoded loader bytes, not instructions to execute.
 !byte <($0540),<($0568),<($0590),<($05b8),<($05e0),<($0608),<($0630),<($0658)
; Book line 2048: Emit 8 bytes in the shown order for rowlo. These are data or encoded loader bytes,
; not instructions to execute.
 !byte <($0680),<($06a8),<($06d0),<($06f8),<($0720),<($0748),<($0770),<($0798)
; Book line 2049: Emit 8 bytes in the shown order for rowlo. These are data or encoded loader bytes,
; not instructions to execute.
 !byte <($07c0)
; Book line 2050: Emit 1 byte in the shown order for rowlo. These are data or encoded loader bytes,
; not instructions to execute.
; DATA: Matching high bytes; add back to select visible buffer.
rowhi: !byte >($0400),>($0428),>($0450),>($0478),>($04a0),>($04c8),>($04f0),>($0518)
; Book line 2052: rowhi names the data or instruction address. Emit 8 bytes in the shown order for
; rowhi. These are data or encoded loader bytes, not instructions to execute.
 !byte >($0540),>($0568),>($0590),>($05b8),>($05e0),>($0608),>($0630),>($0658)
; Book line 2053: Emit 8 bytes in the shown order for rowhi. These are data or encoded loader bytes,
; not instructions to execute.
 !byte >($0680),>($06a8),>($06d0),>($06f8),>($0720),>($0748),>($0770),>($0798)
; Book line 2054: Emit 8 bytes in the shown order for rowhi. These are data or encoded loader bytes,
; not instructions to execute.
 !byte >($07c0)
; Book line 2055: Emit 1 byte in the shown order for rowhi. These are data or encoded loader bytes,
; not instructions to execute.
; DATA: Low address bytes locating LDA operand high bytes, not screen pixels.
copyreadhi: !byte <(cr2+2),<(cr3+2),<(cr4+2),<(cr5+2),<(cr6+2),<(cr7+2),<(cr8+2),<(cr9+2)
; Book line 2057: copyreadhi names the data or instruction address. Emit 8 bytes in the shown order
; for copyreadhi. These are data or encoded loader bytes, not instructions to execute.
 !byte <(cr10+2),<(cr11+2),<(cr12+2),<(cr13+2),<(cr14+2),<(cr15+2),<(cr16+2),<(cr17+2)
; Book line 2058: Emit 8 bytes in the shown order for copyreadhi. These are data or encoded loader
; bytes, not instructions to execute.
 !byte <(cr18+2),<(cr19+2),<(cr20+2),<(cr21+2),<(cr22+2),<(cr23+2)
; Book line 2059: Emit 6 bytes in the shown order for copyreadhi. These are data or encoded loader
; bytes, not instructions to execute.
; DATA: High address bytes locating those LDA operands.
copyreadhi_h: !byte >(cr2+2),>(cr3+2),>(cr4+2),>(cr5+2),>(cr6+2),>(cr7+2),>(cr8+2),>(cr9+2)
; Book line 2061: copyreadhi_h names the data or instruction address. Emit 8 bytes in the shown order
; for copyreadhi_h. These are data or encoded loader bytes, not instructions to execute.
 !byte >(cr10+2),>(cr11+2),>(cr12+2),>(cr13+2),>(cr14+2),>(cr15+2),>(cr16+2),>(cr17+2)
; Book line 2062: Emit 8 bytes in the shown order for copyreadhi_h. These are data or encoded loader
; bytes, not instructions to execute.
 !byte >(cr18+2),>(cr19+2),>(cr20+2),>(cr21+2),>(cr22+2),>(cr23+2)
; Book line 2063: Emit 6 bytes in the shown order for copyreadhi_h. These are data or encoded loader
; bytes, not instructions to execute.
; DATA: Low address bytes locating STA operand high bytes.
copywritehi: !byte <(cw2+2),<(cw3+2),<(cw4+2),<(cw5+2),<(cw6+2),<(cw7+2),<(cw8+2),<(cw9+2)
; Book line 2065: copywritehi names the data or instruction address. Emit 8 bytes in the shown order
; for copywritehi. These are data or encoded loader bytes, not instructions to execute.
 !byte <(cw10+2),<(cw11+2),<(cw12+2),<(cw13+2),<(cw14+2),<(cw15+2),<(cw16+2),<(cw17+2)
; Book line 2066: Emit 8 bytes in the shown order for copywritehi. These are data or encoded loader
; bytes, not instructions to execute.
 !byte <(cw18+2),<(cw19+2),<(cw20+2),<(cw21+2),<(cw22+2),<(cw23+2)
; Book line 2067: Emit 6 bytes in the shown order for copywritehi. These are data or encoded loader
; bytes, not instructions to execute.
; DATA: Matching high address bytes for STA operand locations.
copywritehi_h: !byte >(cw2+2),>(cw3+2),>(cw4+2),>(cw5+2),>(cw6+2),>(cw7+2),>(cw8+2),>(cw9+2)
; Book line 2069: copywritehi_h names the data or instruction address. Emit 8 bytes in the shown order
; for copywritehi_h. These are data or encoded loader bytes, not instructions to execute.
 !byte >(cw10+2),>(cw11+2),>(cw12+2),>(cw13+2),>(cw14+2),>(cw15+2),>(cw16+2),>(cw17+2)
; Book line 2070: Emit 8 bytes in the shown order for copywritehi_h. These are data or encoded loader
; bytes, not instructions to execute.
 !byte >(cw18+2),>(cw19+2),>(cw20+2),>(cw21+2),>(cw22+2),>(cw23+2)
; Book line 2071: Emit 6 bytes in the shown order for copywritehi_h. These are data or encoded loader
; bytes, not instructions to execute.
; DATA: 32 floor row positions; coordinate edits with floorids and edge bitmaps.
floors: !byte 18,18,19,20,20,20,20,20,20,20,20,19,19,18,18,18,17,17,17,16,16,16,16,16,16,16,16,16,16,16,16,17
; Book line 2073: floors names the data or instruction address. Emit 32 bytes in the shown order for
; floors. These are data or encoded loader bytes, not instructions to execute.
; DATA: 97+2*column or pad top 225; the next row uses glyph+1.
floorids: !byte 97,99,101,103,105,225,225,225
; Book line 2075: floorids names the data or instruction address. Emit 8 bytes in the shown order for
; floorids. These are data or encoded loader bytes, not instructions to execute.
 !byte 225,225,225,119,121,123,125,127
; Book line 2076: Emit 8 bytes in the shown order for floorids. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 129,131,133,135,137,225,225,225
; Book line 2077: Emit 8 bytes in the shown order for floorids. These are data or encoded loader
; bytes, not instructions to execute.
 !byte 225,225,225,151,153,155,157,159
; Book line 2078: Emit 8 bytes in the shown order for floorids. These are data or encoded loader
; bytes, not instructions to execute.
; DATA: 12 roof row positions at the cave mouth.
entrance_rows: !byte 2,2,2,2,3,3,3,4,4,4,4,4
; Book line 2080: entrance_rows names the data or instruction address. Emit 12 bytes in the shown
; order for entrance_rows. These are data or encoded loader bytes, not instructions to execute.
; DATA: 32 repeating roof row positions.
ceilings: !byte 5,5,5,5,5,5,5,5,5,5,4,4,4,3,3,3,3,3,2,2,2,2,3,3,3,3,3,4,4,4,5,5
; Book line 2082: ceilings names the data or instruction address. Emit 32 bytes in the shown order for
; ceilings. These are data or encoded loader bytes, not instructions to execute.
; DATA: One 64-byte sprite image pointer per hardware slot; images can be shared.
spriteptrs: !byte $a0,$a1,$a2,$a3,$a4,$a3,$a5,$a4
; Book line 2084: spriteptrs names the data or instruction address. Emit 8 bytes in the shown order
; for spriteptrs. These are data or encoded loader bytes, not instructions to execute. The surrounding
; image definition determines how these bits become pixels.
; DATA: Pointers by target kind, not sprite slot.
targetptrs: !byte $a3,$a4,$a5
; Book line 2086: targetptrs names the data or instruction address. Emit 3 bytes in the shown order
; for targetptrs. These are data or encoded loader bytes, not instructions to execute.
; DATA: Initial per-sprite colours.
spritecolors: !byte 3,7,7,10,5,10,7,5
; Book line 2088: spritecolors names the data or instruction address. Emit 8 bytes in the shown order
; for spritecolors. These are data or encoded loader bytes, not instructions to execute. The
; surrounding image definition determines how these bits become pixels.
; DATA: Per-kind individual spawn colours.
targetcolors: !byte 10,5,7
; Book line 2090: targetcolors names the data or instruction address. Emit 3 bytes in the shown order
; for targetcolors. These are data or encoded loader bytes, not instructions to execute.
; STATE: Active-low joystick bits 0 up, 1 down, 2 left, 3 right, 4 fire; Space also clears fire.
joy: !byte 0
; Book line 2092: joy names the data or instruction address. Emit 1 byte in the shown order for joy.
; These are data or encoded loader bytes, not instructions to execute.
; STATE: W/A/S keyboard column, tested bits 1/2/5.
keys1: !byte 0
; Book line 2094: keys1 names the data or instruction address. Emit 1 byte in the shown order for
; keys1. These are data or encoded loader bytes, not instructions to execute.
; STATE: D keyboard column, tested bit 2.
keys2: !byte 0
; Book line 2096: keys2 names the data or instruction address. Emit 1 byte in the shown order for
; keys2. These are data or encoded loader bytes, not instructions to execute.
; STATE: Title colour counter; wraps after 255.
anim: !byte 0
; Book line 2098: anim names the data or instruction address. Emit 1 byte in the shown order for anim.
; These are data or encoded loader bytes, not instructions to execute.
; STATE: Low two decimal digits in packed BCD.
scorelo: !byte 0
; Book line 2100: scorelo names the data or instruction address. Emit 1 byte in the shown order for
; scorelo. These are data or encoded loader bytes, not instructions to execute.
; STATE: High two BCD digits; four-digit score wraps after 9999.
scorehi: !byte 0
; Book line 2102: scorehi names the data or instruction address. Emit 1 byte in the shown order for
; scorehi. These are data or encoded loader bytes, not instructions to execute.
; STATE: Frame counter; wraps at 256. Masks control periodic effects.
ticks: !byte 0
; Book line 2104: ticks names the data or instruction address. Emit 1 byte in the shown order for
; ticks. These are data or encoded loader bytes, not instructions to execute.
; STATE: Terrain column counter; AND 31 selects the repeating profile.
phase: !byte 0
; Book line 2106: phase names the data or instruction address. Emit 1 byte in the shown order for
; phase. These are data or encoded loader bytes, not instructions to execute.
; STATE: One-time approach counter, saturates at 76.
opening_col: !byte 0
; Book line 2108: opening_col names the data or instruction address. Emit 1 byte in the shown order
; for opening_col. These are data or encoded loader bytes, not instructions to execute.
; STATE: VISIBLE screen offset: 0 selects A, 8 selects B. XOR 8 selects opposite.
back: !byte 0
; Book line 2110: back names the data or instruction address. Emit 1 byte in the shown order for back.
; These are data or encoded loader bytes, not instructions to execute.
; STATE: One active forward-shot slot, 0 inactive.
shot: !byte 0
; Book line 2112: shot names the data or instruction address. Emit 1 byte in the shown order for shot.
; These are data or encoded loader bytes, not instructions to execute.
; STATE: One active bomb slot, 0 inactive.
bomb: !byte 0
; Book line 2114: bomb names the data or instruction address. Emit 1 byte in the shown order for bomb.
; These are data or encoded loader bytes, not instructions to execute.
; STATE: Q4 forward speed, starts 48/16 and eases towards 16/16.
bombvx: !byte 0
; Book line 2116: bombvx names the data or instruction address. Emit 1 byte in the shown order for
; bombvx. These are data or encoded loader bytes, not instructions to execute.
; STATE: Q4 downward speed, starts 4/16 and gains 3/16; approximately 5-pixel cap.
bombvy: !byte 0
; Book line 2118: bombvy names the data or instruction address. Emit 1 byte in the shown order for
; bombvy. These are data or encoded loader bytes, not instructions to execute.
; STATE: Horizontal fractional remainder 0..15.
bombxf: !byte 0
; Book line 2120: bombxf names the data or instruction address. Emit 1 byte in the shown order for
; bombxf. These are data or encoded loader bytes, not instructions to execute.
; STATE: Vertical fractional remainder 0..15.
bombyf: !byte 0
; Book line 2122: bombyf names the data or instruction address. Emit 1 byte in the shown order for
; bombyf. These are data or encoded loader bytes, not instructions to execute.
; STATE: Coarse-shift counter, one increment per eight pixels.
distance: !byte 0
; Book line 2124: distance names the data or instruction address. Emit 1 byte in the shown order for
; distance. These are data or encoded loader bytes, not instructions to execute.
; STATE: Displayed sector counter, not a separate level or difficulty selector.
stage: !byte 0
; Book line 2126: stage names the data or instruction address. Emit 1 byte in the shown order for
; stage. These are data or encoded loader bytes, not instructions to execute.
; STATE: Nonzero requests one life-loss transition.
dead: !byte 0
; Book line 2128: dead names the data or instruction address. Emit 1 byte in the shown order for dead.
; These are data or encoded loader bytes, not instructions to execute.
; STATE: Includes current ship; new run sets three.
lives: !byte 3
; Book line 2130: lives names the data or instruction address. Emit 1 byte in the shown order for
; lives. These are data or encoded loader bytes, not instructions to execute.
; STATE: Remaining shield frames, initially 150.
invulnerable: !byte 0
; Book line 2132: invulnerable names the data or instruction address. Emit 1 byte in the shown order
; for invulnerable. These are data or encoded loader bytes, not instructions to execute.
; STATE: 0 for HUD phase, 1 for playfield phase.
irq_phase: !byte 0
; Book line 2134: irq_phase names the data or instruction address. Emit 1 byte in the shown order for
; irq_phase. These are data or encoded loader bytes, not instructions to execute.
; STATE: Pixel X inside a character, 0..7.
localx: !byte 0
; Book line 2136: localx names the data or instruction address. Emit 1 byte in the shown order for
; localx. These are data or encoded loader bytes, not instructions to execute.
; STATE: Bitmap row inside a character, 0..7.
localy: !byte 0
; Book line 2138: localy names the data or instruction address. Emit 1 byte in the shown order for
; localy. These are data or encoded loader bytes, not instructions to execute.
; STATE: First of two floor edge glyphs.
floortileid: !byte 0
; Book line 2140: floortileid names the data or instruction address. Emit 1 byte in the shown order
; for floortileid. These are data or encoded loader bytes, not instructions to execute.
; STATE: First of two ceiling edge glyphs.
ceiltileid: !byte 0
; Book line 2142: ceiltileid names the data or instruction address. Emit 1 byte in the shown order for
; ceiltileid. These are data or encoded loader bytes, not instructions to execute.
; DATA: Character 94: eight rows, below solid threshold 96.
star_tile: !byte 0,0,0,$0c,0,0,0,0
; Book line 2144: star_tile names the data or instruction address. Emit 8 bytes in the shown order for
; star_tile. These are data or encoded loader bytes, not instructions to execute.
; DATA: Masks select four two-bit pairs; each pair covers two physical X pixels.
pairmask: !byte $c0,$c0,$30,$30,$0c,$0c,$03,$03
; Book line 2146: pairmask names the data or instruction address. Emit 8 bytes in the shown order for
; pairmask. These are data or encoded loader bytes, not instructions to execute.
; STATE: Frames until next launch attempt, reloaded with 14.
firecool: !byte 0
; Book line 2148: firecool names the data or instruction address. Emit 1 byte in the shown order for
; firecool. These are data or encoded loader bytes, not instructions to execute.
; STATE: Frames before sound control registers are silenced.
soundtimer: !byte 0
; Book line 2150: soundtimer names the data or instruction address. Emit 1 byte in the shown order for
; soundtimer. These are data or encoded loader bytes, not instructions to execute.
; STATE: Nonzero pseudo-random state; initial value $a7.
seed: !byte 0
; Book line 2152: seed names the data or instruction address. Emit 1 byte in the shown order for seed.
; These are data or encoded loader bytes, not instructions to execute.
; STATE: Half-percent units 0..200. Depots add 50 up to 200.
fuel: !byte 0
; Book line 2154: fuel names the data or instruction address. Emit 1 byte in the shown order for fuel.
; These are data or encoded loader bytes, not instructions to execute.
; STATE: Temporary remainder for HUD decimal conversion, not another fuel tank.
fuelpercent: !byte 0
; Book line 2156: fuelpercent names the data or instruction address. Emit 1 byte in the shown order
; for fuelpercent. These are data or encoded loader bytes, not instructions to execute.
; STATE: Sprite-origin X, below 256.
shipx: !byte 0
; Book line 2158: shipx names the data or instruction address. Emit 1 byte in the shown order for
; shipx. These are data or encoded loader bytes, not instructions to execute. The surrounding image
; definition determines how these bits become pixels.
; STATE: Sprite-origin Y.
shipy: !byte 0
; Book line 2160: shipy names the data or instruction address. Emit 1 byte in the shown order for
; shipy. These are data or encoded loader bytes, not instructions to execute. The surrounding image
; definition determines how these bits become pixels.
; STATE: X before controls, used to roll back shielded terrain entry.
oldshipx: !byte 0
; Book line 2162: oldshipx names the data or instruction address. Emit 1 byte in the shown order for
; oldshipx. These are data or encoded loader bytes, not instructions to execute. The surrounding image
; definition determines how these bits become pixels.
; STATE: Y before controls.
oldshipy: !byte 0
; Book line 2164: oldshipy names the data or instruction address. Emit 1 byte in the shown order for
; oldshipy. These are data or encoded loader bytes, not instructions to execute. The surrounding image
; definition determines how these bits become pixels.
; STATE: Index 0..7 into hull contact arrays.
hullprobe: !byte 0
; Book line 2166: hullprobe names the data or instruction address. Emit 1 byte in the shown order for
; hullprobe. These are data or encoded loader bytes, not instructions to execute.
; DATA: Eight X offsets on visible ship outline.
hullx: !byte 4,9,19,23,15,7,4,0
; Book line 2168: hullx names the data or instruction address. Emit 8 bytes in the shown order for
; hullx. These are data or encoded loader bytes, not instructions to execute.
; DATA: Matching Y offsets, avoiding transparent sprite margins.
hully: !byte 2,3,6,8,10,13,13,7
; Book line 2170: hully names the data or instruction address. Emit 8 bytes in the shown order for
; hully. These are data or encoded loader bytes, not instructions to execute.
; STATE: Horizontal fine-scroll offset, 7 down through 0.
fine: !byte 0
; Book line 2172: fine names the data or instruction address. Emit 1 byte in the shown order for fine.
; These are data or encoded loader bytes, not instructions to execute.
; STATE: Remaining startup columns, initially 40.
initcols: !byte 0
; Book line 2174: initcols names the data or instruction address. Emit 1 byte in the shown order for
; initcols. These are data or encoded loader bytes, not instructions to execute.
; STATE: Shot X.
sx: !byte 0
; Book line 2176: sx names the data or instruction address. Emit 1 byte in the shown order for sx.
; These are data or encoded loader bytes, not instructions to execute.
; STATE: Shot Y.
sy: !byte 0
; Book line 2178: sy names the data or instruction address. Emit 1 byte in the shown order for sy.
; These are data or encoded loader bytes, not instructions to execute.
; STATE: Bomb integer X, separate from bombxf.
bx: !byte 0
; Book line 2180: bx names the data or instruction address. Emit 1 byte in the shown order for bx.
; These are data or encoded loader bytes, not instructions to execute.
; STATE: Bomb integer Y, separate from bombyf.
by: !byte 0
; Book line 2182: by names the data or instruction address. Emit 1 byte in the shown order for by.
; These are data or encoded loader bytes, not instructions to execute.
; STATE: Terrain pixel X; padheight alone uses X minus 24.
testx: !byte 0
; Book line 2184: testx names the data or instruction address. Emit 1 byte in the shown order for
; testx. These are data or encoded loader bytes, not instructions to execute.
; STATE: Terrain pixel Y in VIC coordinates.
testy: !byte 0
; Book line 2186: testy names the data or instruction address. Emit 1 byte in the shown order for
; testy. These are data or encoded loader bytes, not instructions to execute.
; STATE: Preserves target slot while padheight clobbers X.
savedx: !byte 0
; Book line 2188: savedx names the data or instruction address. Emit 1 byte in the shown order for
; savedx. These are data or encoded loader bytes, not instructions to execute.
; STATE: First floor-edge screen row.
floorrow: !byte 0
; Book line 2190: floorrow names the data or instruction address. Emit 1 byte in the shown order for
; floorrow. These are data or encoded loader bytes, not instructions to execute.
; STATE: First roof-edge row; zero plus blank glyphs means open sky.
ceilrow: !byte 0
; Book line 2192: ceilrow names the data or instruction address. Emit 1 byte in the shown order for
; ceilrow. These are data or encoded loader bytes, not instructions to execute.
; STATE: Target X by sprite index, only 3..7 used.
ex: !fill 8,0
; Book line 2194: ex names the data or instruction address. Emit repeated initial data for ex: 8,0.
; The first expression is the byte count and the second is the fill value.
; STATE: Target Y; grounded targets keep original pad height.
ey: !fill 8,0
; Book line 2196: ey names the data or instruction address. Emit repeated initial data for ey: 8,0.
; The first expression is the byte count and the second is the fill value.
; STATE: 0 installation, 1 fuel depot, 2 rocket.
kind: !fill 8,0
; Book line 2198: kind names the data or instruction address. Emit repeated initial data for kind:
; 8,0. The first expression is the byte count and the second is the fill value.
; STATE: Zero means target slot can be reused.
active: !fill 8,0
; Book line 2200: active names the data or instruction address. Emit repeated initial data for active:
; 8,0. The first expression is the byte count and the second is the fill value.
; STATE: Rocket pad waiting timer, initially 48.
launchwait: !fill 8,0
; Book line 2202: launchwait names the data or instruction address. Emit repeated initial data for
; launchwait: 8,0. The first expression is the byte count and the second is the fill value.
; STATE: Successful-spawn countdown, initially 24.
spawncool: !byte 0
; Book line 2204: spawncool names the data or instruction address. Emit 1 byte in the shown order for
; spawncool. These are data or encoded loader bytes, not instructions to execute.
; STATE: First foot surface Y, compared against second foot.
pad_y: !byte 0
; Book line 2206: pad_y names the data or instruction address. Emit 1 byte in the shown order for
; pad_y. These are data or encoded loader bytes, not instructions to execute.
; DATA: 1 shifted left by slot index, for sprite enable/disable.
spritemask: !byte 1,2,4,8,16,32,64,128
; Book line 2208: spritemask names the data or instruction address. Emit 8 bytes in the shown order
; for spritemask. These are data or encoded loader bytes, not instructions to execute. The surrounding
; image definition determines how these bits become pixels.
; DATA: Visible last occupied row + 1 for installation/depot/rocket: 19/18/19.
footheight: !byte 19,18,19
; Book line 2210: footheight names the data or instruction address. Emit 3 bytes in the shown order
; for footheight. These are data or encoded loader bytes, not instructions to execute.
!if * > $2800 { !error "Code overlaps sprites" }
; Book line 2211: Evaluate the assembly-time condition. The enclosed !error stops the build if code
; has crossed its reserved memory boundary.
; Sprites need 64-byte alignment: pointer $a0 times 64 = $2800.
*=$2800
; Book line 2213: Place subsequent output at C64 address $2800; the origin directive is processed by
; ACME, not executed by the CPU.
; Bitmap pairs: 00 transparent, 01 shared D025, 10 individual, 11 shared D026.
; Multicolour sprite 0: white highlights, red details, individual hull colour.
!byte $00,$00,$00 ; Row 00: 000000000000 (12 double-width pixels)
; Book line 2216: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 01: 000000000000 (12 double-width pixels)
; Book line 2217: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$00,$00 ; Row 02: 003300000000 (12 double-width pixels)
; Book line 2218: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $03,$c0,$00 ; Row 03: 000330000000 (12 double-width pixels)
; Book line 2219: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $03,$f0,$00 ; Row 04: 000333000000 (12 double-width pixels)
; Book line 2220: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $23,$55,$00 ; Row 05: 020311110000 (12 double-width pixels)
; Book line 2221: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $2f,$55,$f0 ; Row 06: 023311113300 (12 double-width pixels)
; Book line 2222: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $af,$55,$fc ; Row 07: 223311113330 (12 double-width pixels)
; Book line 2223: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $2f,$ff,$ff ; Row 08: 023333333333 (12 double-width pixels)
; Book line 2224: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $2f,$ff,$fc ; Row 09: 023333333330 (12 double-width pixels)
; Book line 2225: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$ff,$00 ; Row 10: 003333330000 (12 double-width pixels)
; Book line 2226: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $03,$f0,$00 ; Row 11: 000333000000 (12 double-width pixels)
; Book line 2227: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$c0,$00 ; Row 12: 003330000000 (12 double-width pixels)
; Book line 2228: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$00,$00 ; Row 13: 003300000000 (12 double-width pixels)
; Book line 2229: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 14: 000000000000 (12 double-width pixels)
; Book line 2230: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 15: 000000000000 (12 double-width pixels)
; Book line 2231: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 16: 000000000000 (12 double-width pixels)
; Book line 2232: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 17: 000000000000 (12 double-width pixels)
; Book line 2233: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 18: 000000000000 (12 double-width pixels)
; Book line 2234: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 19: 000000000000 (12 double-width pixels)
; Book line 2235: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 20: 000000000000 (12 double-width pixels)
; Book line 2236: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte 0 ; Padding: image uses 63 bytes in a 64-byte slot.
; Book line 2237: Emit 1 byte in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
; Bitmap pairs: 00 transparent, 01 shared D025, 10 individual, 11 shared D026.
; Multicolour sprite 1: white highlights, red details, individual hull colour.
!byte $00,$00,$00 ; Row 00: 000000000000 (12 double-width pixels)
; Book line 2240: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 01: 000000000000 (12 double-width pixels)
; Book line 2241: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 02: 000000000000 (12 double-width pixels)
; Book line 2242: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 03: 000000000000 (12 double-width pixels)
; Book line 2243: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 04: 000000000000 (12 double-width pixels)
; Book line 2244: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 05: 000000000000 (12 double-width pixels)
; Book line 2245: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$54,$00 ; Row 06: 033311100000 (12 double-width pixels)
; Book line 2246: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $ff,$55,$00 ; Row 07: 333311110000 (12 double-width pixels)
; Book line 2247: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$fc,$00 ; Row 08: 033333300000 (12 double-width pixels)
; Book line 2248: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 09: 000000000000 (12 double-width pixels)
; Book line 2249: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 10: 000000000000 (12 double-width pixels)
; Book line 2250: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 11: 000000000000 (12 double-width pixels)
; Book line 2251: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 12: 000000000000 (12 double-width pixels)
; Book line 2252: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 13: 000000000000 (12 double-width pixels)
; Book line 2253: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 14: 000000000000 (12 double-width pixels)
; Book line 2254: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 15: 000000000000 (12 double-width pixels)
; Book line 2255: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 16: 000000000000 (12 double-width pixels)
; Book line 2256: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 17: 000000000000 (12 double-width pixels)
; Book line 2257: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 18: 000000000000 (12 double-width pixels)
; Book line 2258: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 19: 000000000000 (12 double-width pixels)
; Book line 2259: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 20: 000000000000 (12 double-width pixels)
; Book line 2260: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte 0 ; Padding: image uses 63 bytes in a 64-byte slot.
; Book line 2261: Emit 1 byte in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
; Bitmap pairs: 00 transparent, 01 shared D025, 10 individual, 11 shared D026.
; Multicolour sprite 2: white highlights, red details, individual hull colour.
!byte $00,$00,$00 ; Row 00: 000000000000 (12 double-width pixels)
; Book line 2264: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 01: 000000000000 (12 double-width pixels)
; Book line 2265: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$00,$00 ; Row 02: 003300000000 (12 double-width pixels)
; Book line 2266: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$00,$00 ; Row 03: 003300000000 (12 double-width pixels)
; Book line 2267: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$00,$00 ; Row 04: 003300000000 (12 double-width pixels)
; Book line 2268: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$00,$00 ; Row 05: 003300000000 (12 double-width pixels)
; Book line 2269: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$40,$00 ; Row 06: 033310000000 (12 double-width pixels)
; Book line 2270: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$40,$00 ; Row 07: 033310000000 (12 double-width pixels)
; Book line 2271: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$00,$00 ; Row 08: 003300000000 (12 double-width pixels)
; Book line 2272: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$00,$00 ; Row 09: 003300000000 (12 double-width pixels)
; Book line 2273: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 10: 000000000000 (12 double-width pixels)
; Book line 2274: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 11: 000000000000 (12 double-width pixels)
; Book line 2275: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 12: 000000000000 (12 double-width pixels)
; Book line 2276: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 13: 000000000000 (12 double-width pixels)
; Book line 2277: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 14: 000000000000 (12 double-width pixels)
; Book line 2278: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 15: 000000000000 (12 double-width pixels)
; Book line 2279: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 16: 000000000000 (12 double-width pixels)
; Book line 2280: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 17: 000000000000 (12 double-width pixels)
; Book line 2281: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 18: 000000000000 (12 double-width pixels)
; Book line 2282: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 19: 000000000000 (12 double-width pixels)
; Book line 2283: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 20: 000000000000 (12 double-width pixels)
; Book line 2284: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte 0 ; Padding: image uses 63 bytes in a 64-byte slot.
; Book line 2285: Emit 1 byte in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
; Bitmap pairs: 00 transparent, 01 shared D025, 10 individual, 11 shared D026.
; Multicolour sprite 3: white highlights, red details, individual hull colour.
!byte $00,$30,$00 ; Row 00: 000003000000 (12 double-width pixels)
; Book line 2288: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$fc,$00 ; Row 01: 000033300000 (12 double-width pixels)
; Book line 2289: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$fc,$00 ; Row 02: 000033300000 (12 double-width pixels)
; Book line 2290: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$fc,$00 ; Row 03: 000033300000 (12 double-width pixels)
; Book line 2291: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$fc,$00 ; Row 04: 000033300000 (12 double-width pixels)
; Book line 2292: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $03,$55,$00 ; Row 05: 000311110000 (12 double-width pixels)
; Book line 2293: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $03,$55,$00 ; Row 06: 000311110000 (12 double-width pixels)
; Book line 2294: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$54,$00 ; Row 07: 000011100000 (12 double-width pixels)
; Book line 2295: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$fc,$00 ; Row 08: 000033300000 (12 double-width pixels)
; Book line 2296: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $03,$ff,$00 ; Row 09: 000333330000 (12 double-width pixels)
; Book line 2297: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $03,$ff,$00 ; Row 10: 000333330000 (12 double-width pixels)
; Book line 2298: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$ff,$c0 ; Row 11: 003333333000 (12 double-width pixels)
; Book line 2299: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$ff,$c0 ; Row 12: 003333333000 (12 double-width pixels)
; Book line 2300: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$ff,$f0 ; Row 13: 033333333300 (12 double-width pixels)
; Book line 2301: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$ff,$f0 ; Row 14: 033333333300 (12 double-width pixels)
; Book line 2302: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $33,$33,$30 ; Row 15: 030303030300 (12 double-width pixels)
; Book line 2303: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$ff,$f0 ; Row 16: 033333333300 (12 double-width pixels)
; Book line 2304: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$ff,$f0 ; Row 17: 033333333300 (12 double-width pixels)
; Book line 2305: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$ff,$f0 ; Row 18: 033333333300 (12 double-width pixels)
; Book line 2306: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 19: 000000000000 (12 double-width pixels)
; Book line 2307: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 20: 000000000000 (12 double-width pixels)
; Book line 2308: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte 0 ; Padding: image uses 63 bytes in a 64-byte slot.
; Book line 2309: Emit 1 byte in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
; Bitmap pairs: 00 transparent, 01 shared D025, 10 individual, 11 shared D026.
; Multicolour sprite 4: white highlights, red details, individual hull colour.
!byte $00,$00,$00 ; Row 00: 000000000000 (12 double-width pixels)
; Book line 2312: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 01: 000000000000 (12 double-width pixels)
; Book line 2313: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$ff,$c0 ; Row 02: 003333333000 (12 double-width pixels)
; Book line 2314: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$ff,$c0 ; Row 03: 003333333000 (12 double-width pixels)
; Book line 2315: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$ff,$f0 ; Row 04: 033333333300 (12 double-width pixels)
; Book line 2316: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3c,$00,$f0 ; Row 05: 033000003300 (12 double-width pixels)
; Book line 2317: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $14,$54,$50 ; Row 06: 011011101100 (12 double-width pixels)
; Book line 2318: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3c,$40,$f0 ; Row 07: 033010003300 (12 double-width pixels)
; Book line 2319: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $14,$54,$50 ; Row 08: 011011101100 (12 double-width pixels)
; Book line 2320: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3c,$c0,$f0 ; Row 09: 033030003300 (12 double-width pixels)
; Book line 2321: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $14,$40,$50 ; Row 10: 011010001100 (12 double-width pixels)
; Book line 2322: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3c,$00,$f0 ; Row 11: 033000003300 (12 double-width pixels)
; Book line 2323: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$ff,$f0 ; Row 12: 033333333300 (12 double-width pixels)
; Book line 2324: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$ff,$f0 ; Row 13: 033333333300 (12 double-width pixels)
; Book line 2325: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$ff,$f0 ; Row 14: 033333333300 (12 double-width pixels)
; Book line 2326: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$ff,$f0 ; Row 15: 033333333300 (12 double-width pixels)
; Book line 2327: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$ff,$f0 ; Row 16: 033333333300 (12 double-width pixels)
; Book line 2328: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $3f,$ff,$f0 ; Row 17: 033333333300 (12 double-width pixels)
; Book line 2329: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 18: 000000000000 (12 double-width pixels)
; Book line 2330: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 19: 000000000000 (12 double-width pixels)
; Book line 2331: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 20: 000000000000 (12 double-width pixels)
; Book line 2332: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte 0 ; Padding: image uses 63 bytes in a 64-byte slot.
; Book line 2333: Emit 1 byte in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
; Bitmap pairs: 00 transparent, 01 shared D025, 10 individual, 11 shared D026.
; Multicolour sprite 5: white highlights, red details, individual hull colour.
!byte $00,$3c,$00 ; Row 00: 000003300000 (12 double-width pixels)
; Book line 2336: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$3c,$00 ; Row 01: 000003300000 (12 double-width pixels)
; Book line 2337: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$ff,$00 ; Row 02: 000033330000 (12 double-width pixels)
; Book line 2338: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$ff,$00 ; Row 03: 000033330000 (12 double-width pixels)
; Book line 2339: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$ff,$00 ; Row 04: 000033330000 (12 double-width pixels)
; Book line 2340: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$55,$00 ; Row 05: 000011110000 (12 double-width pixels)
; Book line 2341: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$55,$00 ; Row 06: 000011110000 (12 double-width pixels)
; Book line 2342: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$55,$00 ; Row 07: 000011110000 (12 double-width pixels)
; Book line 2343: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$ff,$00 ; Row 08: 000033330000 (12 double-width pixels)
; Book line 2344: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$ff,$00 ; Row 09: 000033330000 (12 double-width pixels)
; Book line 2345: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $03,$ff,$c0 ; Row 10: 000333333000 (12 double-width pixels)
; Book line 2346: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $03,$ff,$c0 ; Row 11: 000333333000 (12 double-width pixels)
; Book line 2347: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$ff,$f0 ; Row 12: 003333333300 (12 double-width pixels)
; Book line 2348: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $0f,$3c,$f0 ; Row 13: 003303303300 (12 double-width pixels)
; Book line 2349: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$3c,$00 ; Row 14: 000003300000 (12 double-width pixels)
; Book line 2350: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$28,$00 ; Row 15: 000002200000 (12 double-width pixels)
; Book line 2351: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$28,$00 ; Row 16: 000002200000 (12 double-width pixels)
; Book line 2352: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$28,$00 ; Row 17: 000002200000 (12 double-width pixels)
; Book line 2353: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$28,$00 ; Row 18: 000002200000 (12 double-width pixels)
; Book line 2354: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 19: 000000000000 (12 double-width pixels)
; Book line 2355: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte $00,$00,$00 ; Row 20: 000000000000 (12 double-width pixels)
; Book line 2356: Emit 3 bytes in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.
!byte 0 ; Padding: image uses 63 bytes in a 64-byte slot.
; Book line 2357: Emit 1 byte in the shown order for footheight. These are data or encoded loader
; bytes, not instructions to execute.

; Terrain source is outside the RAM font that will receive its copied bytes.
*=$3800
; Book line 2360: Place subsequent output at C64 address $3800; the origin directive is processed by
; ACME, not executed by the CPU.
; Each glyph has 8 rows, each byte encoding four double-width pixel pairs.
; Glyph 96 rock; 97..160 floor; 161..224 roof; 225..226 pad;
; 227..250 cave entrance; 251..255 blank. Pair 00 is transparent/air.
terrain_chars:
; Book line 2364: terrain_chars names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
; Glyph 96 at $3300: rows 0 through 7.
!byte $66,$99,$66,$59,$66,$99,$66,$95
; Book line 2366: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 97 at $3308: rows 0 through 7.
!byte $00,$00,$c0,$f0,$b0,$ac,$af,$6b
; Book line 2368: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 98 at $3310: rows 0 through 7.
!byte $9a,$5a,$56,$59,$65,$95,$55,$56
; Book line 2370: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 99 at $3318: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$c0
; Book line 2372: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 100 at $3320: rows 0 through 7.
!byte $c0,$b0,$bc,$af,$6b,$aa,$5a,$56
; Book line 2374: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 101 at $3328: rows 0 through 7.
!byte $00,$00,$00,$00,$c0,$c0,$b0,$bc
; Book line 2376: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 102 at $3330: rows 0 through 7.
!byte $af,$6b,$6a,$5a,$66,$95,$55,$56
; Book line 2378: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 103 at $3338: rows 0 through 7.
!byte $c0,$ff,$bf,$aa,$aa,$aa,$55,$56
; Book line 2380: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 104 at $3340: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2382: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 105 at $3348: rows 0 through 7.
!byte $3f,$ff,$ea,$aa,$aa,$95,$55,$56
; Book line 2384: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 106 at $3350: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2386: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 107 at $3358: rows 0 through 7.
!byte $ff,$ff,$aa,$aa,$aa,$95,$55,$56
; Book line 2388: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 108 at $3360: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2390: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 109 at $3368: rows 0 through 7.
!byte $ff,$ff,$aa,$aa,$aa,$95,$55,$56
; Book line 2392: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 110 at $3370: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2394: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 111 at $3378: rows 0 through 7.
!byte $ff,$ff,$aa,$aa,$aa,$95,$55,$56
; Book line 2396: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 112 at $3380: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2398: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 113 at $3388: rows 0 through 7.
!byte $ff,$ff,$aa,$aa,$aa,$95,$55,$56
; Book line 2400: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 114 at $3390: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2402: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 115 at $3398: rows 0 through 7.
!byte $ff,$ff,$aa,$aa,$aa,$95,$55,$56
; Book line 2404: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 116 at $33a0: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2406: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 117 at $33a8: rows 0 through 7.
!byte $ff,$ff,$aa,$aa,$aa,$95,$55,$56
; Book line 2408: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 118 at $33b0: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2410: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 119 at $33b8: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$0f
; Book line 2412: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 120 at $33c0: rows 0 through 7.
!byte $ff,$fa,$aa,$aa,$a5,$95,$55,$56
; Book line 2414: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 121 at $33c8: rows 0 through 7.
!byte $00,$00,$03,$0f,$0e,$3a,$fa,$ea
; Book line 2416: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 122 at $33d0: rows 0 through 7.
!byte $a5,$a5,$96,$59,$65,$95,$55,$56
; Book line 2418: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 123 at $33d8: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$03,$0f,$3e
; Book line 2420: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 124 at $33e0: rows 0 through 7.
!byte $3a,$ea,$ea,$a9,$a5,$95,$55,$56
; Book line 2422: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 125 at $33e8: rows 0 through 7.
!byte $00,$00,$00,$0f,$ff,$fa,$aa,$aa
; Book line 2424: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 126 at $33f0: rows 0 through 7.
!byte $a5,$55,$56,$59,$65,$95,$55,$56
; Book line 2426: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 127 at $33f8: rows 0 through 7.
!byte $00,$03,$3f,$fe,$ea,$aa,$a9,$96
; Book line 2428: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 128 at $3400: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2430: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 129 at $3408: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$03
; Book line 2432: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 130 at $3410: rows 0 through 7.
!byte $3f,$fe,$ea,$aa,$a9,$95,$55,$56
; Book line 2434: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 131 at $3418: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$0f,$ff
; Book line 2436: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 132 at $3420: rows 0 through 7.
!byte $fa,$aa,$aa,$a9,$65,$95,$55,$56
; Book line 2438: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 133 at $3428: rows 0 through 7.
!byte $00,$03,$03,$0e,$3e,$fa,$e9,$aa
; Book line 2440: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 134 at $3430: rows 0 through 7.
!byte $a5,$95,$56,$59,$65,$95,$55,$56
; Book line 2442: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 135 at $3438: rows 0 through 7.
!byte $00,$00,$00,$03,$0f,$0e,$3a,$fa
; Book line 2444: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 136 at $3440: rows 0 through 7.
!byte $e9,$a5,$a6,$99,$65,$95,$55,$56
; Book line 2446: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 137 at $3448: rows 0 through 7.
!byte $0f,$3f,$fa,$ea,$aa,$a5,$95,$56
; Book line 2448: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 138 at $3450: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2450: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 139 at $3458: rows 0 through 7.
!byte $ff,$ff,$aa,$aa,$aa,$95,$55,$56
; Book line 2452: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 140 at $3460: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2454: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 141 at $3468: rows 0 through 7.
!byte $ff,$ff,$aa,$aa,$aa,$95,$55,$56
; Book line 2456: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 142 at $3470: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2458: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 143 at $3478: rows 0 through 7.
!byte $ff,$ff,$aa,$aa,$aa,$95,$55,$56
; Book line 2460: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 144 at $3480: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2462: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 145 at $3488: rows 0 through 7.
!byte $ff,$ff,$aa,$aa,$aa,$95,$55,$56
; Book line 2464: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 146 at $3490: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2466: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 147 at $3498: rows 0 through 7.
!byte $ff,$ff,$aa,$aa,$aa,$95,$55,$56
; Book line 2468: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 148 at $34a0: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2470: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 149 at $34a8: rows 0 through 7.
!byte $ff,$ff,$aa,$aa,$aa,$95,$55,$56
; Book line 2472: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 150 at $34b0: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2474: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 151 at $34b8: rows 0 through 7.
!byte $ff,$ff,$aa,$aa,$aa,$95,$55,$56
; Book line 2476: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 152 at $34c0: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2478: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 153 at $34c8: rows 0 through 7.
!byte $fc,$ff,$ab,$aa,$aa,$96,$55,$56
; Book line 2480: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 154 at $34d0: rows 0 through 7.
!byte $95,$55,$56,$59,$65,$95,$55,$56
; Book line 2482: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 155 at $34d8: rows 0 through 7.
!byte $00,$00,$c0,$f0,$bc,$ac,$ab,$6b
; Book line 2484: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 156 at $34e0: rows 0 through 7.
!byte $9a,$56,$56,$59,$65,$95,$55,$56
; Book line 2486: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 157 at $34e8: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$c0
; Book line 2488: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 158 at $34f0: rows 0 through 7.
!byte $f0,$bc,$ac,$ab,$6b,$9a,$56,$56
; Book line 2490: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 159 at $34f8: rows 0 through 7.
!byte $00,$00,$00,$00,$c0,$f0,$b0,$ac
; Book line 2492: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 160 at $3500: rows 0 through 7.
!byte $af,$6b,$5a,$5a,$66,$95,$55,$56
; Book line 2494: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 161 at $3508: rows 0 through 7.
!byte $aa,$aa,$fa,$ff,$0f,$00,$00,$00
; Book line 2496: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 162 at $3510: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2498: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 163 at $3518: rows 0 through 7.
!byte $95,$aa,$aa,$ea,$ff,$3f,$00,$00
; Book line 2500: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 164 at $3520: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2502: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 165 at $3528: rows 0 through 7.
!byte $95,$a5,$aa,$aa,$fa,$ff,$0f,$00
; Book line 2504: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 166 at $3530: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2506: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 167 at $3538: rows 0 through 7.
!byte $95,$55,$aa,$aa,$aa,$ff,$ff,$00
; Book line 2508: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 168 at $3540: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2510: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 169 at $3548: rows 0 through 7.
!byte $95,$55,$aa,$aa,$aa,$ff,$ff,$00
; Book line 2512: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 170 at $3550: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2514: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 171 at $3558: rows 0 through 7.
!byte $95,$5a,$aa,$aa,$af,$ff,$f0,$00
; Book line 2516: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 172 at $3560: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2518: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 173 at $3568: rows 0 through 7.
!byte $9a,$aa,$aa,$af,$ff,$f0,$00,$00
; Book line 2520: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 174 at $3570: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2522: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 175 at $3578: rows 0 through 7.
!byte $aa,$aa,$bf,$ff,$c0,$00,$00,$00
; Book line 2524: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 176 at $3580: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2526: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 177 at $3588: rows 0 through 7.
!byte $af,$ff,$f0,$00,$00,$00,$00,$00
; Book line 2528: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 178 at $3590: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2530: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 179 at $3598: rows 0 through 7.
!byte $f0,$00,$00,$00,$00,$00,$00,$00
; Book line 2532: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 180 at $35a0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2534: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 181 at $35a8: rows 0 through 7.
!byte $96,$5a,$aa,$ab,$af,$fc,$f0,$00
; Book line 2536: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 182 at $35b0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2538: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 183 at $35b8: rows 0 through 7.
!byte $aa,$ab,$bf,$fc,$c0,$00,$00,$00
; Book line 2540: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 184 at $35c0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2542: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 185 at $35c8: rows 0 through 7.
!byte $bf,$f0,$c0,$00,$00,$00,$00,$00
; Book line 2544: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 186 at $35d0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2546: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 187 at $35d8: rows 0 through 7.
!byte $95,$55,$5a,$aa,$aa,$af,$ff,$f0
; Book line 2548: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 188 at $35e0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2550: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 189 at $35e8: rows 0 through 7.
!byte $aa,$aa,$ab,$bf,$fc,$c0,$00,$00
; Book line 2552: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 190 at $35f0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2554: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 191 at $35f8: rows 0 through 7.
!byte $aa,$bf,$ff,$c0,$00,$00,$00,$00
; Book line 2556: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 192 at $3600: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2558: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 193 at $3608: rows 0 through 7.
!byte $ff,$f0,$00,$00,$00,$00,$00,$00
; Book line 2560: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 194 at $3610: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2562: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 195 at $3618: rows 0 through 7.
!byte $c0,$00,$00,$00,$00,$00,$00,$00
; Book line 2564: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 196 at $3620: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2566: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 197 at $3628: rows 0 through 7.
!byte $95,$55,$5a,$aa,$aa,$af,$ff,$f0
; Book line 2568: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 198 at $3630: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2570: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 199 at $3638: rows 0 through 7.
!byte $95,$55,$aa,$aa,$aa,$ff,$ff,$00
; Book line 2572: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 200 at $3640: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2574: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 201 at $3648: rows 0 through 7.
!byte $95,$55,$aa,$aa,$aa,$ff,$ff,$00
; Book line 2576: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 202 at $3650: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2578: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 203 at $3658: rows 0 through 7.
!byte $95,$55,$a6,$aa,$aa,$fa,$ff,$0f
; Book line 2580: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 204 at $3660: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2582: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 205 at $3668: rows 0 through 7.
!byte $0f,$00,$00,$00,$00,$00,$00,$00
; Book line 2584: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 206 at $3670: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2586: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 207 at $3678: rows 0 through 7.
!byte $ff,$3f,$00,$00,$00,$00,$00,$00
; Book line 2588: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 208 at $3680: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2590: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 209 at $3688: rows 0 through 7.
!byte $aa,$fa,$ff,$0f,$00,$00,$00,$00
; Book line 2592: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 210 at $3690: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2594: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 211 at $3698: rows 0 through 7.
!byte $a5,$aa,$aa,$fa,$ff,$0f,$00,$00
; Book line 2596: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 212 at $36a0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2598: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 213 at $36a8: rows 0 through 7.
!byte $95,$55,$a6,$a9,$aa,$fa,$fe,$0f
; Book line 2600: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 214 at $36b0: rows 0 through 7.
!byte $03,$00,$00,$00,$00,$00,$00,$00
; Book line 2602: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 215 at $36b8: rows 0 through 7.
!byte $fe,$3f,$03,$00,$00,$00,$00,$00
; Book line 2604: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 216 at $36c0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2606: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 217 at $36c8: rows 0 through 7.
!byte $aa,$ea,$fa,$3f,$0f,$00,$00,$00
; Book line 2608: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 218 at $36d0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2610: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 219 at $36d8: rows 0 through 7.
!byte $95,$a5,$aa,$aa,$fa,$ff,$0f,$00
; Book line 2612: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 220 at $36e0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2614: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 221 at $36e8: rows 0 through 7.
!byte $3f,$03,$00,$00,$00,$00,$00,$00
; Book line 2616: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 222 at $36f0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2618: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 223 at $36f8: rows 0 through 7.
!byte $ea,$ff,$3f,$00,$00,$00,$00,$00
; Book line 2620: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 224 at $3700: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2622: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 225 at $3708: rows 0 through 7.
!byte $ff,$ff,$aa,$aa,$66,$99,$66,$99
; Book line 2624: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 226 at $3710: rows 0 through 7.
!byte $66,$99,$66,$59,$66,$99,$66,$95
; Book line 2626: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 227 at $3718: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2628: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 228 at $3720: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2630: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 229 at $3728: rows 0 through 7.
!byte $ff,$03,$00,$00,$00,$00,$00,$00
; Book line 2632: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 230 at $3730: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2634: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 231 at $3738: rows 0 through 7.
!byte $aa,$fa,$ff,$0f,$00,$00,$00,$00
; Book line 2636: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 232 at $3740: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2638: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 233 at $3748: rows 0 through 7.
!byte $95,$a5,$aa,$ea,$fa,$3e,$0f,$03
; Book line 2640: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 234 at $3750: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2642: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 235 at $3758: rows 0 through 7.
!byte $3e,$0f,$03,$00,$00,$00,$00,$00
; Book line 2644: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 236 at $3760: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2646: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 237 at $3768: rows 0 through 7.
!byte $a5,$a9,$ea,$fa,$3e,$0f,$03,$00
; Book line 2648: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 238 at $3770: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2650: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 239 at $3778: rows 0 through 7.
!byte $95,$55,$96,$a9,$a9,$ea,$fa,$3e
; Book line 2652: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 240 at $3780: rows 0 through 7.
!byte $0f,$03,$00,$00,$00,$00,$00,$00
; Book line 2654: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 241 at $3788: rows 0 through 7.
!byte $ea,$fa,$3f,$0f,$00,$00,$00,$00
; Book line 2656: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 242 at $3790: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2658: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 243 at $3798: rows 0 through 7.
!byte $aa,$aa,$ea,$ff,$3f,$00,$00,$00
; Book line 2660: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 244 at $37a0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2662: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 245 at $37a8: rows 0 through 7.
!byte $95,$aa,$aa,$aa,$ff,$ff,$00,$00
; Book line 2664: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 246 at $37b0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2666: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 247 at $37b8: rows 0 through 7.
!byte $aa,$aa,$aa,$bf,$ff,$c0,$00,$00
; Book line 2668: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 248 at $37c0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2670: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 249 at $37c8: rows 0 through 7.
!byte $aa,$ab,$bf,$fc,$c0,$00,$00,$00
; Book line 2672: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 250 at $37d0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2674: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 251 at $37d8: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2676: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 252 at $37e0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2678: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 253 at $37e8: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2680: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 254 at $37f0: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2682: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
; Glyph 255 at $37f8: rows 0 through 7.
!byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 2684: Emit 8 bytes in the shown order for terrain_chars. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.

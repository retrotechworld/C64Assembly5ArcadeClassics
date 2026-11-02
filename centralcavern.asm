; ============================================================================
; CENTRAL CAVERN V15 - ABSOLUTE BEGINNER'S ANNOTATED EDITION
; ============================================================================
; WHAT: A Commodore 64 platform-game demonstration in 6510 assembly language.
; WHY: This edition explains the instructions, hardware and program structure.
; HOW: ACME assembles the readable instructions into a runnable .PRG file.
;
; BUILD: acme central_cavern_v15_beginner_commented.asm
; RUN:   Load the resulting PRG in VICE and RUN (BASIC SYS 49152).
;
; IMPORTANT: All game instructions, tables and binary sprite artwork are kept
; unchanged from V15. Comments alone cannot alter how the game plays.
;
; BEGINNER CHEAT SHEET
;   $C000  means hexadecimal C000 (decimal 49152). $0400 is screen memory.
;   #10    means the number 10. Without #, an operand normally names memory.
;   %1010  means a binary number. Each 1/0 represents one bit.
;   A      is the accumulator (the main 8-bit arithmetic register).
;   X, Y   are two 8-bit index registers, often used for arrays and loops.
;   PC     is the program counter: where the CPU fetches the next instruction.
;   Z flag is set when an operation gives zero (or two compared values match).
;   C flag is the carry/borrow flag, used by arithmetic and comparisons.
;   N flag records the top bit of an 8-bit result.
;   JSR    calls a subroutine; RTS returns to the caller.
;   JMP    jumps without remembering a return address.
;   BEQ/BNE/BCC/BCS are conditional branches based on CPU flags.
;   !byte  emits literal bytes; !to chooses the output file.
;   * =    tells ACME where in C64 memory the following bytes belong.
;
; C64 DISPLAY CONCEPTS
;   Screen RAM at $0400 stores WHICH character to show in each cell.
;   Colour RAM at $D800 stores its colour (one entry per character cell).
;   Character bitmaps at $3000 define the 8x8 shape of each character.
;   Hardware sprites are separate movable pictures controlled by VIC-II.
;   Sprite pictures are 24 pixels wide x 21 high, stored in 64-byte blocks.
;   SID at $D400-$D418 is the C64's sound chip.
;   Joystick port 2 is read from CIA register $DC00 (active-low bits).
;
; READING SUGGESTION: start -> main_loop -> controls -> physics -> address
; -> make_level -> sprite_frame -> music_tick. Refer back to constants above.
; ============================================================================

; CENTRAL CAVERN - enhanced C64 / ACME demonstration
; Original demonstration repaired: reliable character set, pointers and physics.
; Build: acme central_cavern_v15_ledge_music.asm
; Run the generated central_cavern_v15_ledge_music.prg in VICE.
!to "central_cavern_v15_beginner_commented.prg", cbm
; Book line 47: Select the output filename and format "central_cavern_v15_beginner_commented.prg",
; cbm. This is an assembler setting and emits no game instruction.

SCREEN = $0400
; Book line 49: Define SCREEN as $0400 (screen RAM in the $0400 screen) at assembly time; this names a
; value or address and emits no storage.
COLORS = $d800
; Book line 50: Define COLORS as $d800 (colour RAM) at assembly time; this names a value or address
; and emits no storage.
FONT   = $3000
; Book line 51: Define FONT as $3000 at assembly time; this names a value or address and emits no
; storage.
JOY2   = $dc00
; Book line 52: Define JOY2 as $dc00 (CIA1 port A and joystick 2) at assembly time; this names a value
; or address and emits no storage.
PTR    = $22            ; two-byte screen pointer ($22/$23)
; Book line 53: Define PTR as $22 at assembly time; this names a value or address and emits no
; storage.
CPTR   = $24            ; two-byte colour pointer ($24/$25)
; Book line 54: Define CPTR as $24 at assembly time; this names a value or address and emits no
; storage.
TX     = $26            ; temporary x position
; Book line 55: Define TX as $26 at assembly time; this names a value or address and emits no storage.
TY     = $27            ; temporary y position
; Book line 56: Define TY as $27 at assembly time; this names a value or address and emits no storage.
PX     = $28            ; player column
; Book line 57: Define PX as $28 at assembly time; this names a value or address and emits no storage.
PY     = $29            ; player row
; Book line 58: Define PY as $29 at assembly time; this names a value or address and emits no storage.
JUMP   = $2a            ; zero = no jump, otherwise index + 1
; Book line 59: Define JUMP as $2a at assembly time; this names a value or address and emits no
; storage.
TICK   = $2b            ; movement divider
; Book line 60: Define TICK as $2b at assembly time; this names a value or address and emits no
; storage.
ITEMS  = $2c            ; number of objects collected
; Book line 61: Define ITEMS as $2c at assembly time; this names a value or address and emits no
; storage.

EMPTY  = 32
; Book line 63: Define EMPTY as 32 at assembly time; this names a value or address and emits no
; storage.
; Custom tiles live at screen codes $60-$67, away from letters A-Z.
; Previously CONVEYOR=5 overwrote the letter E in the copied font.
BRICK  = $60
; Book line 66: Define BRICK as $60 at assembly time; this names a value or address and emits no
; storage.
WILLY  = $61
; Book line 67: Define WILLY as $61 at assembly time; this names a value or address and emits no
; storage.
KEY    = $62
; Book line 68: Define KEY as $62 at assembly time; this names a value or address and emits no
; storage.
CRUMBLE = $63
; Book line 69: Define CRUMBLE as $63 at assembly time; this names a value or address and emits no
; storage.
CONVEYOR = $64
; Book line 70: Define CONVEYOR as $64 at assembly time; this names a value or address and emits no
; storage.
EXIT_TILE = $65
; Book line 71: Define EXIT_TILE as $65 at assembly time; this names a value or address and emits no
; storage.
ENEMY = $66
; Book line 72: Define ENEMY as $66 at assembly time; this names a value or address and emits no
; storage.
SPIKE = $67
; Book line 73: Define SPIKE as $67 at assembly time; this names a value or address and emits no
; storage.

EX = $2d
; Book line 75: Define EX as $2d at assembly time; this names a value or address and emits no storage.
EY = $2e
; Book line 76: Define EY as $2e at assembly time; this names a value or address and emits no storage.
EDIR = $2f
; Book line 77: Define EDIR as $2f at assembly time; this names a value or address and emits no
; storage.
EX2 = $30
; Book line 78: Define EX2 as $30 at assembly time; this names a value or address and emits no
; storage.
EY2 = $31
; Book line 79: Define EY2 as $31 at assembly time; this names a value or address and emits no
; storage.
EDIR2 = $32
; Book line 80: Define EDIR2 as $32 at assembly time; this names a value or address and emits no
; storage.
LIVES = $33
; Book line 81: Define LIVES as $33 at assembly time; this names a value or address and emits no
; storage.
FRAME = $34
; Book line 82: Define FRAME as $34 at assembly time; this names a value or address and emits no
; storage.
OLD1 = $35
; Book line 83: Define OLD1 as $35 at assembly time; this names a value or address and emits no
; storage.
OLD2 = $36
; Book line 84: Define OLD2 as $36 at assembly time; this names a value or address and emits no
; storage.
PLAYER_UNDER = $38
; Book line 85: Define PLAYER_UNDER as $38 at assembly time; this names a value or address and emits
; no storage.
WIN = $37
; Book line 86: Define WIN as $37 at assembly time; this names a value or address and emits no
; storage.
MUSIC_WAIT = $39
; Book line 87: Define MUSIC_WAIT as $39 at assembly time; this names a value or address and emits no
; storage.
MUSIC_STEP = $3a
; Book line 88: Define MUSIC_STEP as $3a at assembly time; this names a value or address and emits no
; storage.
SFX_WAIT = $3b
; Book line 89: Define SFX_WAIT as $3b at assembly time; this names a value or address and emits no
; storage.
SFX_KIND = $3c
; Book line 90: Define SFX_KIND as $3c at assembly time; this names a value or address and emits no
; storage.
LAST_JOY = $3d
; Book line 91: Define LAST_JOY as $3d at assembly time; this names a value or address and emits no
; storage.
PLAYER_COLOR_UNDER = $3e
; Book line 92: Define PLAYER_COLOR_UNDER as $3e at assembly time; this names a value or address and
; emits no storage.
ENEMY1_COLOR_UNDER = $3f
; Book line 93: Define ENEMY1_COLOR_UNDER as $3f at assembly time; this names a value or address and
; emits no storage.
ENEMY2_COLOR_UNDER = $40
; Book line 94: Define ENEMY2_COLOR_UNDER as $40 at assembly time; this names a value or address and
; emits no storage.
GAME_STATE = $41       ; 0=playing, 1=won, 2=game over
; Book line 95: Define GAME_STATE as $41 at assembly time; this names a value or address and emits no
; storage.
PREV_JOY = $42
; Book line 96: Define PREV_JOY as $42 at assembly time; this names a value or address and emits no
; storage.
CONVEY_TICK = $43       ; conveyor movement rate
; Book line 97: Define CONVEY_TICK as $43 at assembly time; this names a value or address and emits no
; storage.
MOVE_CLOCK = $44
; Book line 98: Define MOVE_CLOCK as $44 at assembly time; this names a value or address and emits no
; storage.
; Hardware sprite interpolation state (low and high X, Y).
SPX = $45
; Book line 100: Define SPX as $45 at assembly time; this names a value or address and emits no
; storage.
SPXH = $46
; Book line 101: Define SPXH as $46 at assembly time; this names a value or address and emits no
; storage.
SPY = $47
; Book line 102: Define SPY as $47 at assembly time; this names a value or address and emits no
; storage.
E1X = $48
; Book line 103: Define E1X as $48 at assembly time; this names a value or address and emits no
; storage.
E1XH = $49
; Book line 104: Define E1XH as $49 at assembly time; this names a value or address and emits no
; storage.
E1Y = $4a
; Book line 105: Define E1Y as $4a at assembly time; this names a value or address and emits no
; storage.
E2X = $4b
; Book line 106: Define E2X as $4b at assembly time; this names a value or address and emits no
; storage.
E2XH = $4c
; Book line 107: Define E2XH as $4c at assembly time; this names a value or address and emits no
; storage.
E2Y = $4d
; Book line 108: Define E2Y as $4d at assembly time; this names a value or address and emits no
; storage.
TARGETLO = $4e
; Book line 109: Define TARGETLO as $4e at assembly time; this names a value or address and emits no
; storage.
TARGETHI = $4f
; Book line 110: Define TARGETHI as $4f at assembly time; this names a value or address and emits no
; storage.
SPRLO = $50
; Book line 111: Define SPRLO as $50 at assembly time; this names a value or address and emits no
; storage.
SPRHI = $51        ; sprite interpolation high byte
; Book line 112: Define SPRHI as $51 at assembly time; this names a value or address and emits no
; storage.
DEATH_TIMER = $52   ; PAL frames remaining in death pause
; Book line 113: Define DEATH_TIMER as $52 at assembly time; this names a value or address and emits
; no storage.
DEATH_END = $53     ; 1 if last life was lost
; Book line 114: Define DEATH_END as $53 at assembly time; this names a value or address and emits no
; storage.
MENU_MODE = $54     ; 0=title, 1=game over
; Book line 115: Define MENU_MODE as $54 at assembly time; this names a value or address and emits no
; storage.


; MEMORY PLACEMENT: next assembled bytes begin at $0801.
* = $0801
; Book line 119: Place subsequent output at C64 address $0801; the origin directive is processed by
; ACME, not executed by the CPU.
!byte $0b,$08,$0a,$00,$9e,$34,$39,$31,$35,$32,$00,$00,$00
; Book line 120: Emit 13 bytes in the shown order for program. These are data or encoded loader bytes,
; not instructions to execute.

; Compact original 8-pixel-wide hires characters, with separate colour overlays.
; All six frames are exactly 64 bytes and start on 64-byte boundaries.
; MEMORY PLACEMENT: next assembled bytes begin at $2000.
* = $2000
; Book line 125: Place subsequent output at C64 address $2000; the origin directive is processed by
; ACME, not executed by the CPU.
player_stand:
; Book line 126: player_stand names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 127: Emit 8 bytes in the shown order for player_stand. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$3c,$00,$00
; Book line 128: Emit 8 bytes in the shown order for player_stand. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $7e,$00,$00,$db,$00,$00,$ff,$00
; Book line 129: Emit 8 bytes in the shown order for player_stand. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$3c,$00,$00,$7e,$00,$00,$7e
; Book line 130: Emit 8 bytes in the shown order for player_stand. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$3c,$00,$00,$3c,$00,$00
; Book line 131: Emit 8 bytes in the shown order for player_stand. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $66,$00,$00,$c3,$00,$00,$c3,$00
; Book line 132: Emit 8 bytes in the shown order for player_stand. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 133: Emit 8 bytes in the shown order for player_stand. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 134: Emit 8 bytes in the shown order for player_stand. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
player_stride:
; Book line 135: player_stride names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 136: Emit 8 bytes in the shown order for player_stride. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$3c,$00,$00
; Book line 137: Emit 8 bytes in the shown order for player_stride. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $7e,$00,$00,$db,$00,$00,$ff,$00
; Book line 138: Emit 8 bytes in the shown order for player_stride. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$3c,$00,$00,$7e,$00,$00,$7e
; Book line 139: Emit 8 bytes in the shown order for player_stride. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$3c,$00,$00,$3c,$00,$00
; Book line 140: Emit 8 bytes in the shown order for player_stride. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $36,$00,$00,$63,$00,$00,$c1,$00
; Book line 141: Emit 8 bytes in the shown order for player_stride. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 142: Emit 8 bytes in the shown order for player_stride. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 143: Emit 8 bytes in the shown order for player_stride. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
hazard_open:
; Book line 144: hazard_open names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 145: Emit 8 bytes in the shown order for hazard_open. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$3c,$00,$00
; Book line 146: Emit 8 bytes in the shown order for hazard_open. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $7e,$00,$00,$db,$00,$00,$ff,$00
; Book line 147: Emit 8 bytes in the shown order for hazard_open. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$db,$00,$00,$7e,$00,$00,$3c
; Book line 148: Emit 8 bytes in the shown order for hazard_open. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$66,$00,$00,$c3,$00,$00
; Book line 149: Emit 8 bytes in the shown order for hazard_open. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $42,$00,$00,$c3,$00,$00,$00,$00
; Book line 150: Emit 8 bytes in the shown order for hazard_open. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 151: Emit 8 bytes in the shown order for hazard_open. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 152: Emit 8 bytes in the shown order for hazard_open. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
hazard_closed:
; Book line 153: hazard_closed names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 154: Emit 8 bytes in the shown order for hazard_closed. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$3c,$00,$00
; Book line 155: Emit 8 bytes in the shown order for hazard_closed. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $7e,$00,$00,$db,$00,$00,$ff,$00
; Book line 156: Emit 8 bytes in the shown order for hazard_closed. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$db,$00,$00,$7e,$00,$00,$3c
; Book line 157: Emit 8 bytes in the shown order for hazard_closed. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$db,$00,$00,$66,$00,$00
; Book line 158: Emit 8 bytes in the shown order for hazard_closed. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $c3,$00,$00,$00,$00,$00,$00,$00
; Book line 159: Emit 8 bytes in the shown order for hazard_closed. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 160: Emit 8 bytes in the shown order for hazard_closed. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 161: Emit 8 bytes in the shown order for hazard_closed. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
player_accent:
; Book line 162: player_accent names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 163: Emit 8 bytes in the shown order for player_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 164: Emit 8 bytes in the shown order for player_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$18,$00,$00,$00,$00
; Book line 165: Emit 8 bytes in the shown order for player_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$3c,$00,$00,$3c
; Book line 166: Emit 8 bytes in the shown order for player_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 167: Emit 8 bytes in the shown order for player_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 168: Emit 8 bytes in the shown order for player_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 169: Emit 8 bytes in the shown order for player_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 170: Emit 8 bytes in the shown order for player_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
enemy_accent:
; Book line 171: enemy_accent names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 172: Emit 8 bytes in the shown order for enemy_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 173: Emit 8 bytes in the shown order for enemy_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$24,$00,$00,$00,$00
; Book line 174: Emit 8 bytes in the shown order for enemy_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$18,$00,$00,$00
; Book line 175: Emit 8 bytes in the shown order for enemy_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 176: Emit 8 bytes in the shown order for enemy_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 177: Emit 8 bytes in the shown order for enemy_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 178: Emit 8 bytes in the shown order for enemy_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 179: Emit 8 bytes in the shown order for enemy_accent. These are data or encoded loader
; bytes, not instructions to execute. The surrounding image definition determines how these bits
; become pixels.

; Third colour layer: small hires accents, aligned with sprite rows.
; Player gets yellow helmet/boots; second enemy gets white eyes.
player_third:
; Book line 183: player_third names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 184: Emit 16 bytes in the shown order for player_third. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$3c,$00,$00,$00,$00,$00,$00,$00
; Book line 185: Emit 16 bytes in the shown order for player_third. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 186: Emit 16 bytes in the shown order for player_third. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $42,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 187: Emit 16 bytes in the shown order for player_third. These are data or encoded loader
; bytes, not instructions to execute.
enemy_third:
; Book line 188: enemy_third names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 189: Emit 16 bytes in the shown order for enemy_third. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$24,$00,$00,$00,$00,$00,$00,$00
; Book line 190: Emit 16 bytes in the shown order for enemy_third. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 191: Emit 16 bytes in the shown order for enemy_third. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Book line 192: Emit 16 bytes in the shown order for enemy_third. These are data or encoded loader
; bytes, not instructions to execute.


; Animated secondary-colour masks. One hires pixel per bit: crisp,
; stable two-colour characters using paired hardware sprites.
; MEMORY PLACEMENT: next assembled bytes begin at $2200.
* = $2200
; Book line 198: Place subsequent output at C64 address $2200; the origin directive is processed by
; ACME, not executed by the CPU.
player_accent_walk:
; Book line 199: player_accent_walk names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 200: Emit 8 bytes in the shown order for player_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 201: Emit 8 bytes in the shown order for player_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$18,$00
; Book line 202: Emit 8 bytes in the shown order for player_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$24,$00,$00,$3c
; Book line 203: Emit 8 bytes in the shown order for player_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$3c,$00,$00,$18,$00,$00
; Book line 204: Emit 8 bytes in the shown order for player_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $18,$00,$00,$18,$00,$00,$00,$00
; Book line 205: Emit 8 bytes in the shown order for player_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 206: Emit 8 bytes in the shown order for player_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 207: Emit 8 bytes in the shown order for player_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
; MEMORY PLACEMENT: next assembled bytes begin at $2240.
* = $2240
; Book line 209: Place subsequent output at C64 address $2240; the origin directive is processed by
; ACME, not executed by the CPU.
enemy_accent_walk:
; Book line 210: enemy_accent_walk names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 211: Emit 8 bytes in the shown order for enemy_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 212: Emit 8 bytes in the shown order for enemy_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$24,$00
; Book line 213: Emit 8 bytes in the shown order for enemy_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$18,$00,$00,$24
; Book line 214: Emit 8 bytes in the shown order for enemy_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$18,$00,$00,$00,$00,$00
; Book line 215: Emit 8 bytes in the shown order for enemy_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 216: Emit 8 bytes in the shown order for enemy_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 217: Emit 8 bytes in the shown order for enemy_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 218: Emit 8 bytes in the shown order for enemy_accent_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.


; Native VIC-II multicolour sprites: 00 transparent, 01 white,
; 10 blue, 11 per-sprite colour. Each is exactly 64 bytes.
; MEMORY PLACEMENT: next assembled bytes begin at $2300.
* = $2300
; Book line 224: Place subsequent output at C64 address $2300; the origin directive is processed by
; ACME, not executed by the CPU.
player_multi_stand:
; Book line 225: player_multi_stand names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 226: Emit 8 bytes in the shown order for player_multi_stand. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 227: Emit 8 bytes in the shown order for player_multi_stand. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $3f,$00,$00,$ff,$c0,$00,$d5,$c0
; Book line 228: Emit 8 bytes in the shown order for player_multi_stand. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$37,$00,$00,$aa,$80,$03,$aa
; Book line 229: Emit 8 bytes in the shown order for player_multi_stand. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $c0,$00,$aa,$80,$00,$22,$00,$00
; Book line 230: Emit 8 bytes in the shown order for player_multi_stand. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $22,$00,$00,$f3,$c0,$00,$00,$00
; Book line 231: Emit 8 bytes in the shown order for player_multi_stand. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 232: Emit 8 bytes in the shown order for player_multi_stand. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 233: Emit 8 bytes in the shown order for player_multi_stand. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
player_multi_walk:
; Book line 234: player_multi_walk names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 235: Emit 8 bytes in the shown order for player_multi_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 236: Emit 8 bytes in the shown order for player_multi_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $3f,$00,$00,$ff,$c0,$00,$d5,$c0
; Book line 237: Emit 8 bytes in the shown order for player_multi_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$37,$00,$00,$aa,$80,$03,$aa
; Book line 238: Emit 8 bytes in the shown order for player_multi_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $c0,$00,$aa,$80,$00,$22,$00,$00
; Book line 239: Emit 8 bytes in the shown order for player_multi_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $80,$80,$03,$c0,$3c,$00,$00,$00
; Book line 240: Emit 8 bytes in the shown order for player_multi_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 241: Emit 8 bytes in the shown order for player_multi_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 242: Emit 8 bytes in the shown order for player_multi_walk. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
enemy_multi_open:
; Book line 243: enemy_multi_open names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 244: Emit 8 bytes in the shown order for enemy_multi_open. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$01,$40,$00
; Book line 245: Emit 8 bytes in the shown order for enemy_multi_open. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $05,$50,$00,$05,$50,$00,$05,$50
; Book line 246: Emit 8 bytes in the shown order for enemy_multi_open. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$05,$50,$00,$0f,$f0,$00,$03
; Book line 247: Emit 8 bytes in the shown order for enemy_multi_open. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $c0,$00,$0f,$f0,$00,$0c,$30,$00
; Book line 248: Emit 8 bytes in the shown order for enemy_multi_open. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $08,$20,$00,$08,$20,$00,$00,$00
; Book line 249: Emit 8 bytes in the shown order for enemy_multi_open. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 250: Emit 8 bytes in the shown order for enemy_multi_open. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 251: Emit 8 bytes in the shown order for enemy_multi_open. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
enemy_multi_closed:
; Book line 252: enemy_multi_closed names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 253: Emit 8 bytes in the shown order for enemy_multi_closed. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$01,$40,$00
; Book line 254: Emit 8 bytes in the shown order for enemy_multi_closed. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $05,$50,$00,$05,$50,$00,$05,$50
; Book line 255: Emit 8 bytes in the shown order for enemy_multi_closed. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$05,$50,$00,$0f,$f0,$00,$03
; Book line 256: Emit 8 bytes in the shown order for enemy_multi_closed. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $c0,$00,$0f,$f0,$00,$0f,$f0,$00
; Book line 257: Emit 8 bytes in the shown order for enemy_multi_closed. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $08,$20,$00,$00,$00,$00,$00,$00
; Book line 258: Emit 8 bytes in the shown order for enemy_multi_closed. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 259: Emit 8 bytes in the shown order for enemy_multi_closed. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.
    !byte $00,$00,$00,$00,$00,$00,$00,$00
; Book line 260: Emit 8 bytes in the shown order for enemy_multi_closed. These are data or encoded
; loader bytes, not instructions to execute. The surrounding image definition determines how these
; bits become pixels.

; MEMORY PLACEMENT: next assembled bytes begin at $c000.
* = $c000
; Book line 263: Place subsequent output at C64 address $c000; the origin directive is processed by
; ACME, not executed by the CPU.

; ============================================================================
; ROUTINE: start
; WHAT / WHY / HOW: Entry point: configure the C64, load graphics, show the title, reset game state.
; ============================================================================
start:
; Book line 269: start names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    sei                                  ; Disable maskable interrupts for controlled setup.
; Book line 270: Set the interrupt-disable flag to mask ordinary IRQ handling. NMI is not masked, and
; peripheral interrupt sources are not automatically cleared.
    ldx #$ff                             ; Load a value into index register X. Here # means an immediate number.
; Book line 271: Load X with literal $ff (decimal 255). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    txs                 ; reset stack after menu restart                 ; disable IRQs during memory mapping
; Book line 272: Copy X to stack pointer; leave X unchanged. CPU flags are unchanged. Resetting the
; stack discards its previous depth.
    lda #$03                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 273: Load A with literal $03 (decimal 3). Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta $dd00           ; VIC bank 0: $0000-$3fff
; Book line 274: Store A into the byte at $dd00 (CIA2 port A and VIC bank select). The register and
; CPU flags are unchanged.
    lda #$1b                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 275: Load A with literal $1b (decimal 27). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d011           ; normal 25-row text display
; Book line 276: Store A into the byte at $d011 (VIC vertical control and raster high bit). The
; register and CPU flags are unchanged.
    lda #$08                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 277: Load A with literal $08 (decimal 8). Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta $d016           ; 40-column hires character mode
; Book line 278: Store A into the byte at $d016 (VIC horizontal control and fine scroll). The register
; and CPU flags are unchanged.
    lda #$00                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 279: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta $d015           ; reset sprites until initialized
; Book line 280: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
    lda #$00                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 281: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta $d01c           ; single-colour character mode
; Book line 282: Store A into the byte at $d01c (VIC sprite multicolour bits). The register and CPU
; flags are unchanged.
    jsr copy_font                        ; Call a subroutine; execution returns after its RTS.
; Book line 283: Call copy_font, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    lda #$1c            ; screen $0400, character bitmap $3000
; Book line 284: Load A with literal $1c (decimal 28). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d018                            ; Store accumulator A into memory. Target: VIC-II screen/charset location.
; Book line 285: Store A into the byte at $d018 (VIC screen and font selection). The register and CPU
; flags are unchanged.
    lda #$00                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 286: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta $d021           ; black background
; Book line 287: Store A into the byte at $d021 (VIC background colour). The register and CPU flags
; are unchanged.
    lda #$02                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 288: Load A with literal $02 (decimal 2). Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta $d020           ; red border
; Book line 289: Store A into the byte at $d020 (VIC border colour). The register and CPU flags are
; unchanged.
    jsr init_sound                       ; Call a subroutine; execution returns after its RTS.
; Book line 290: Call init_sound, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    lda #0                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 291: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta MENU_MODE                        ; Store accumulator A into memory.
; Book line 292: Store A into the byte at MENU_MODE. The register and CPU flags are unchanged.
    jsr show_menu                        ; Call a subroutine; execution returns after its RTS.
; Book line 293: Call show_menu, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    jsr make_level                       ; Call a subroutine; execution returns after its RTS.
; Book line 294: Call make_level, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    lda #2                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 295: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta PX                               ; Store accumulator A into memory.
; Book line 296: Store A into the byte at PX (logical player column). The register and CPU flags are
; unchanged.
    lda #21                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 297: Load A with literal 21. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta PY                               ; Store accumulator A into memory.
; Book line 298: Store A into the byte at PY (logical player row). The register and CPU flags are
; unchanged.
    lda #0                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 299: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta JUMP                             ; Store accumulator A into memory.
; Book line 300: Store A into the byte at JUMP (jump table position). The register and CPU flags are
; unchanged.
    sta TICK                             ; Store accumulator A into memory.
; Book line 301: Store A into the byte at TICK (frame clock). The register and CPU flags are
; unchanged.
    sta ITEMS                            ; Store accumulator A into memory.
; Book line 302: Store A into the byte at ITEMS (collected item count). The register and CPU flags are
; unchanged.
    sta FRAME                            ; Store accumulator A into memory.
; Book line 303: Store A into the byte at FRAME. The register and CPU flags are unchanged.
    sta WIN                              ; Store accumulator A into memory.
; Book line 304: Store A into the byte at WIN. The register and CPU flags are unchanged.
    sta GAME_STATE                       ; Store accumulator A into memory.
; Book line 305: Store A into the byte at GAME_STATE (game state selector). The register and CPU flags
; are unchanged.
    sta CONVEY_TICK                      ; Store accumulator A into memory.
; Book line 306: Store A into the byte at CONVEY_TICK. The register and CPU flags are unchanged.
    sta MOVE_CLOCK                       ; Store accumulator A into memory.
; Book line 307: Store A into the byte at MOVE_CLOCK. The register and CPU flags are unchanged.
    lda #$11                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 308: Load A with literal $11 (decimal 17). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta PREV_JOY                         ; Store accumulator A into memory.
; Book line 309: Store A into the byte at PREV_JOY. The register and CPU flags are unchanged.
    lda #3                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 310: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta LIVES                            ; Store accumulator A into memory.
; Book line 311: Store A into the byte at LIVES (remaining lives). The register and CPU flags are
; unchanged.
    lda #27                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 312: Load A with literal 27. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EX                               ; Store accumulator A into memory.
; Book line 313: Store A into the byte at EX. The register and CPU flags are unchanged.
    lda #13                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 314: Load A with literal 13. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EY                               ; Store accumulator A into memory.
; Book line 315: Store A into the byte at EY. The register and CPU flags are unchanged.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 316: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EDIR                             ; Store accumulator A into memory.
; Book line 317: Store A into the byte at EDIR. The register and CPU flags are unchanged.
    lda #6                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 318: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EX2                              ; Store accumulator A into memory.
; Book line 319: Store A into the byte at EX2. The register and CPU flags are unchanged.
    lda #9                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 320: Load A with literal 9. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EY2                              ; Store accumulator A into memory.
; Book line 321: Store A into the byte at EY2. The register and CPU flags are unchanged.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 322: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EDIR2                            ; Store accumulator A into memory.
; Book line 323: Store A into the byte at EDIR2. The register and CPU flags are unchanged.
    jsr init_sprites                     ; Call a subroutine; execution returns after its RTS.
; Book line 324: Call init_sprites, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    jsr draw_status                      ; Call a subroutine; execution returns after its RTS.
; Book line 325: Call draw_status, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.


; ============================================================================
; ROUTINE: main_loop
; WHAT / WHY / HOW: Main loop: wait for the video frame, update audio and game logic repeatedly.
; ============================================================================
main_loop:
; Book line 332: main_loop names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
wait_start:
; Book line 333: wait_start names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    lda $d012                            ; Load a value or memory byte into accumulator A. Target: VIC-II raster scanline.
; Book line 334: Load A with the byte at $d012 (VIC raster counter or IRQ compare). Z records a zero
; value; N copies bit 7. Carry is unchanged.
    cmp #$fa                             ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 335: Compare A with literal $fa (decimal 250) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
    bne wait_start                       ; Branch if not equal/zero flag is clear.
; Book line 336: Branch to wait_start if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
wait_end:
; Book line 337: wait_end names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    lda $d012                            ; Load a value or memory byte into accumulator A. Target: VIC-II raster scanline.
; Book line 338: Load A with the byte at $d012 (VIC raster counter or IRQ compare). Z records a zero
; value; N copies bit 7. Carry is unchanged.
    cmp #$fa                             ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 339: Compare A with literal $fa (decimal 250) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
    beq wait_end                         ; Branch if equal/zero flag is set.
; Book line 340: Branch to wait_end if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    jsr music_tick       ; background melody at full 50 Hz
; Book line 341: Call music_tick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    jsr effects_tick     ; independent effects on SID voice 3
; Book line 342: Call effects_tick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    lda GAME_STATE                       ; Load a value or memory byte into accumulator A.
; Book line 343: Load A with the byte at GAME_STATE (game state selector). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    cmp #3                               ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 344: Compare A with literal 3 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    beq death_frame                      ; Branch if equal/zero flag is set.
; Book line 345: Branch to death_frame if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    jsr sprite_frame     ; update sprite positions each frame
; Book line 346: Call sprite_frame, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    jmp sprite_done                      ; Jump directly to another location.
; Book line 347: Continue execution at sprite_done without saving a return address. Registers and
; flags are unchanged by the jump itself.
death_frame:
; Book line 348: death_frame names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    dec DEATH_TIMER                      ; Subtract one from a memory byte.
; Book line 349: Decrease the byte at DEATH_TIMER by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
    bne sprite_done                      ; Branch if not equal/zero flag is clear.
; Book line 350: Branch to sprite_done if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda DEATH_END                        ; Load a value or memory byte into accumulator A.
; Book line 351: Load A with the byte at DEATH_END. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    bne death_to_game_over               ; Branch if not equal/zero flag is clear.
; Book line 352: Branch to death_to_game_over if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
    jsr reset_level_after_death          ; Call a subroutine; execution returns after its RTS.
; Book line 353: Call reset_level_after_death, saving a return address on the stack. Its RTS resumes
; after this call. A, X, Y and flags are not automatically preserved by a call.
    jmp sprite_done                      ; Jump directly to another location.
; Book line 354: Continue execution at sprite_done without saving a return address. Registers and
; flags are unchanged by the jump itself.
death_to_game_over:
; Book line 355: death_to_game_over names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
    lda #2                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 356: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta GAME_STATE                       ; Store accumulator A into memory.
; Book line 357: Store A into the byte at GAME_STATE (game state selector). The register and CPU flags
; are unchanged.
    jsr draw_status                      ; Call a subroutine; execution returns after its RTS.
; Book line 358: Call draw_status, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 359: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta MENU_MODE                        ; Store accumulator A into memory.
; Book line 360: Store A into the byte at MENU_MODE. The register and CPU flags are unchanged.
    jsr show_menu                        ; Call a subroutine; execution returns after its RTS.
; Book line 361: Call show_menu, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
sprite_done:
; Book line 362: sprite_done names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    ; One tile movement per 4 frames: sprites move 2 pixels each frame,
    ; so visible positions and logical tile collision stay synchronized.
    inc MOVE_CLOCK                       ; Add one to a memory byte.
; Book line 365: Increase the byte at MOVE_CLOCK by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
    lda MOVE_CLOCK                       ; Load a value or memory byte into accumulator A.
; Book line 366: Load A with the byte at MOVE_CLOCK. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    cmp #4                               ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 367: Compare A with literal 4 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bcc main_loop                        ; Branch if carry is clear (often unsigned less-than).
; Book line 368: Branch to main_loop if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
    lda #0                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 369: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta MOVE_CLOCK                       ; Store accumulator A into memory.
; Book line 370: Store A into the byte at MOVE_CLOCK. The register and CPU flags are unchanged.
    lda GAME_STATE                       ; Load a value or memory byte into accumulator A.
; Book line 371: Load A with the byte at GAME_STATE (game state selector). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    bne frozen_game                      ; Branch if not equal/zero flag is clear.
; Book line 372: Branch to frozen_game if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    jsr controls                         ; Call a subroutine; execution returns after its RTS.
; Book line 373: Call controls, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
    jsr conveyor_motion                  ; Call a subroutine; execution returns after its RTS.
; Book line 374: Call conveyor_motion, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
    jsr physics                          ; Call a subroutine; execution returns after its RTS.
; Book line 375: Call physics, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
    lda GAME_STATE                       ; Load a value or memory byte into accumulator A.
; Book line 376: Load A with the byte at GAME_STATE (game state selector). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    bne finish_frame                     ; Branch if not equal/zero flag is clear.
; Book line 377: Branch to finish_frame if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    jsr collect_key                      ; Call a subroutine; execution returns after its RTS.
; Book line 378: Call collect_key, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    lda GAME_STATE                       ; Load a value or memory byte into accumulator A.
; Book line 379: Load A with the byte at GAME_STATE (game state selector). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    bne finish_frame                     ; Branch if not equal/zero flag is clear.
; Book line 380: Branch to finish_frame if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    jsr move_enemies                     ; Call a subroutine; execution returns after its RTS.
; Book line 381: Call move_enemies, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    jsr check_enemy_hits                 ; Call a subroutine; execution returns after its RTS.
; Book line 382: Call check_enemy_hits, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
finish_frame:
; Book line 383: finish_frame names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    jsr draw_status                      ; Call a subroutine; execution returns after its RTS.
; Book line 384: Call draw_status, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    jmp main_loop                        ; Jump directly to another location.
; Book line 385: Continue execution at main_loop without saving a return address. Registers and flags
; are unchanged by the jump itself.
frozen_game:
; Book line 386: frozen_game names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    ; Death state is handled by the per-frame timer above, not FIRE.
    cmp #3                               ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 388: Compare A with literal 3 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    beq main_loop                        ; Branch if equal/zero flag is set.
; Book line 389: Branch to main_loop if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    ; End screens wait for P, not joystick FIRE.
    jmp main_loop                        ; Jump directly to another location.
; Book line 391: Continue execution at main_loop without saving a return address. Registers and flags
; are unchanged by the jump itself.


; ------------------------------------------------------------------
; Title / game-over menu. Screen codes are NOT PETSCII:
; A=1 ... Z=26, space=32, digits=$30..$39.
; Draw centred strings into screen RAM and wait for keyboard P.
; P is keyboard matrix row 5, column 1 (active-low).
; ------------------------------------------------------------------

; ============================================================================
; ROUTINE: show_menu
; WHAT / WHY / HOW: Title/game-over menu: clear screen, print screen-code text and wait for P.
; ============================================================================
show_menu:
; Book line 405: show_menu names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    lda #0                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 406: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta $d015           ; no sprites over the menu
; Book line 407: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
    ldx #0                               ; Load a value into index register X. Here # means an immediate number.
; Book line 408: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
menu_clear:
; Book line 409: menu_clear names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    lda #32                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 410: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+$000,x                    ; Store accumulator A into memory.
; Book line 411: Store A into the byte at SCREEN+$000 plus index X. The register and CPU flags are
; unchanged.
    sta SCREEN+$100,x                    ; Store accumulator A into memory.
; Book line 412: Store A into the byte at SCREEN+$100 plus index X. The register and CPU flags are
; unchanged.
    sta SCREEN+$200,x                    ; Store accumulator A into memory.
; Book line 413: Store A into the byte at SCREEN+$200 plus index X. The register and CPU flags are
; unchanged.
    sta SCREEN+$300,x                    ; Store accumulator A into memory.
; Book line 414: Store A into the byte at SCREEN+$300 plus index X. The register and CPU flags are
; unchanged.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 415: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+$000,x                    ; Store accumulator A into memory.
; Book line 416: Store A into the byte at COLORS+$000 plus index X. The register and CPU flags are
; unchanged.
    sta COLORS+$100,x                    ; Store accumulator A into memory.
; Book line 417: Store A into the byte at COLORS+$100 plus index X. The register and CPU flags are
; unchanged.
    sta COLORS+$200,x                    ; Store accumulator A into memory.
; Book line 418: Store A into the byte at COLORS+$200 plus index X. The register and CPU flags are
; unchanged.
    sta COLORS+$300,x                    ; Store accumulator A into memory.
; Book line 419: Store A into the byte at COLORS+$300 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 420: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    bne menu_clear                       ; Branch if not equal/zero flag is clear.
; Book line 421: Branch to menu_clear if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda MENU_MODE                        ; Load a value or memory byte into accumulator A.
; Book line 422: Load A with the byte at MENU_MODE. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    beq menu_title                       ; Branch if equal/zero flag is set.
; Book line 423: Branch to menu_title if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    ldx #0                               ; Load a value into index register X. Here # means an immediate number.
; Book line 424: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
menu_over_copy:
; Book line 425: menu_over_copy names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda menu_over_text,x                 ; Load a value or memory byte into accumulator A.
; Book line 426: Load A with the byte at menu_over_text plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
    sta SCREEN+10*40+15,x  ; GAME OVER = 9 chars
; Book line 427: Store A into the byte at SCREEN+10*40+15 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 428: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    cpx #9                               ; Compare X with operand. Here # means an immediate number.
; Book line 429: Compare X with literal 9 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne menu_over_copy                   ; Branch if not equal/zero flag is clear.
; Book line 430: Branch to menu_over_copy if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
    jmp menu_prompt                      ; Jump directly to another location.
; Book line 431: Continue execution at menu_prompt without saving a return address. Registers and
; flags are unchanged by the jump itself.
menu_title:
; Book line 432: menu_title names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    ldx #0                               ; Load a value into index register X. Here # means an immediate number.
; Book line 433: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
menu_title_copy:
; Book line 434: menu_title_copy names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda menu_title_text,x                ; Load a value or memory byte into accumulator A.
; Book line 435: Load A with the byte at menu_title_text plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
    sta SCREEN+10*40+14,x ; CAVERN MINER = 12 chars
; Book line 436: Store A into the byte at SCREEN+10*40+14 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 437: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    cpx #12                              ; Compare X with operand. Here # means an immediate number.
; Book line 438: Compare X with literal 12 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne menu_title_copy                  ; Branch if not equal/zero flag is clear.
; Book line 439: Branch to menu_title_copy if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
menu_prompt:
; Book line 440: menu_prompt names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    ldx #0                               ; Load a value into index register X. Here # means an immediate number.
; Book line 441: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
menu_prompt_copy:
; Book line 442: menu_prompt_copy names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda menu_prompt_text,x               ; Load a value or memory byte into accumulator A.
; Book line 443: Load A with the byte at menu_prompt_text plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
    sta SCREEN+13*40+12,x ; PRESS P TO PLAY = 15 chars
; Book line 444: Store A into the byte at SCREEN+13*40+12 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 445: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    cpx #15                              ; Compare X with operand. Here # means an immediate number.
; Book line 446: Compare X with literal 15 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne menu_prompt_copy                 ; Branch if not equal/zero flag is clear.
; Book line 447: Branch to menu_prompt_copy if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
    ; Wait for P to be released before accepting a new press.
menu_release:
; Book line 449: menu_release names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    jsr scan_p                           ; Call a subroutine; execution returns after its RTS.
; Book line 450: Call scan_p, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
    beq menu_release                     ; Branch if equal/zero flag is set.
; Book line 451: Branch to menu_release if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
menu_wait:
; Book line 452: menu_wait names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
menu_raster:
; Book line 453: menu_raster names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    lda $d012                            ; Load a value or memory byte into accumulator A. Target: VIC-II raster scanline.
; Book line 454: Load A with the byte at $d012 (VIC raster counter or IRQ compare). Z records a zero
; value; N copies bit 7. Carry is unchanged.
    cmp #$fa                             ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 455: Compare A with literal $fa (decimal 250) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
    bne menu_raster                      ; Branch if not equal/zero flag is clear.
; Book line 456: Branch to menu_raster if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
menu_raster_end:
; Book line 457: menu_raster_end names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda $d012                            ; Load a value or memory byte into accumulator A. Target: VIC-II raster scanline.
; Book line 458: Load A with the byte at $d012 (VIC raster counter or IRQ compare). Z records a zero
; value; N copies bit 7. Carry is unchanged.
    cmp #$fa                             ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 459: Compare A with literal $fa (decimal 250) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
    beq menu_raster_end                  ; Branch if equal/zero flag is set.
; Book line 460: Branch to menu_raster_end if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    jsr music_tick                       ; Call a subroutine; execution returns after its RTS.
; Book line 461: Call music_tick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    jsr effects_tick                     ; Call a subroutine; execution returns after its RTS.
; Book line 462: Call effects_tick, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    jsr scan_p                           ; Call a subroutine; execution returns after its RTS.
; Book line 463: Call scan_p, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
    bne menu_wait                        ; Branch if not equal/zero flag is clear.
; Book line 464: Branch to menu_wait if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    ; On game over, restart all lives; on title, start first game.
    lda MENU_MODE                        ; Load a value or memory byte into accumulator A.
; Book line 466: Load A with the byte at MENU_MODE. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    beq menu_return                      ; Branch if equal/zero flag is set.
; Book line 467: Branch to menu_return if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    jmp start                            ; Jump directly to another location.
; Book line 468: Continue execution at start without saving a return address. Registers and flags are
; unchanged by the jump itself.
menu_return:
; Book line 469: menu_return names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    rts                                  ; Return from the current subroutine.
; Book line 470: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; ROUTINE: scan_p
; WHAT / WHY / HOW: Keyboard test: check whether the player pressed the P key.
; ============================================================================
scan_p:
; Book line 477: scan_p names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    lda #$df            ; select keyboard row 5
; Book line 478: Load A with literal $df (decimal 223). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $dc00                            ; Store accumulator A into memory. Target: joystick port 2/CIA.
; Book line 479: Store A into the byte at $dc00 (CIA1 port A and joystick 2). The register and CPU
; flags are unchanged.
    lda $dc01                            ; Load a value or memory byte into accumulator A.
; Book line 480: Load A with the byte at $dc01 (CIA1 port B and keyboard rows). Z records a zero
; value; N copies bit 7. Carry is unchanged.
    and #$02            ; zero means P is pressed
; Book line 481: Keep only bits set in both A and literal $02 (decimal 2). Save the result in A and
; update Z and N; carry is unchanged.
    pha                                  ; Push A onto the CPU stack.
; Book line 482: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
    lda #$ff                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 483: Load A with literal $ff (decimal 255). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $dc00                            ; Store accumulator A into memory. Target: joystick port 2/CIA.
; Book line 484: Store A into the byte at $dc00 (CIA1 port A and joystick 2). The register and CPU
; flags are unchanged.
    pla                                  ; Pull A from the CPU stack.
; Book line 485: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
    rts                                  ; Return from the current subroutine.
; Book line 486: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

menu_title_text:
; Book line 488: menu_title_text names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    !byte 3,1,22,5,18,14,32,13,9,14,5,18
; Book line 489: Emit 12 bytes in the shown order for menu_title_text. These are data or encoded
; loader bytes, not instructions to execute.
menu_over_text:
; Book line 490: menu_over_text names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    !byte 7,1,13,5,32,15,22,5,18
; Book line 491: Emit 9 bytes in the shown order for menu_over_text. These are data or encoded loader
; bytes, not instructions to execute.
menu_prompt_text:
; Book line 492: menu_prompt_text names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    !byte 16,18,5,19,19,32,16,32,20,15,32,16,12,1,25
; Book line 493: Emit 15 bytes in the shown order for menu_prompt_text. These are data or encoded
; loader bytes, not instructions to execute.

; Temporarily reveal the character ROM at $d000-$dfff to the CPU.
; CHAREN=0, HIRAM=1 and LORAM=0 ($0001 low bits = %010).
; The VIC sees RAM $3000 independently of the CPU ROM mapping.

; ============================================================================
; ROUTINE: copy_font
; WHAT / WHY / HOW: Character-set setup: copy ROM glyphs into RAM and install game tiles.
; ============================================================================
copy_font:
; Book line 503: copy_font names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    lda $01                              ; Load a value or memory byte into accumulator A.
; Book line 504: Load A with the byte at $01 (6510 ROM and I/O banking port). Z records a zero value;
; N copies bit 7. Carry is unchanged.
    pha                 ; save original CPU memory configuration
; Book line 505: Push A onto the hardware stack, reducing the stack pointer. A and flags are
; unchanged; pair this save with the appropriate later pull.
    and #$f8                             ; Bitwise AND: keep only bits present in both values. Here # means an immediate number.
; Book line 506: Keep only bits set in both A and literal $f8 (decimal 248). Save the result in A and
; update Z and N; carry is unchanged.
    ora #$02                             ; Bitwise OR: set bits present in either value. Here # means an immediate number.
; Book line 507: Set A bits present in either A or literal $02 (decimal 2). Save the result in A and
; update Z and N; carry is unchanged.
    sta $01                              ; Store accumulator A into memory.
; Book line 508: Store A into the byte at $01 (6510 ROM and I/O banking port). The register and CPU
; flags are unchanged.
    ldx #0                               ; Load a value into index register X. Here # means an immediate number.
; Book line 509: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
copy_loop:
; Book line 510: copy_loop names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    lda $d000,x                          ; Load a value or memory byte into accumulator A.
; Book line 511: Load A with the byte at $d000 (sprite 0 X low byte) plus index X. Z records a zero
; value; N copies bit 7. Carry is unchanged.
    sta FONT+$000,x                      ; Store accumulator A into memory.
; Book line 512: Store A into the byte at FONT+$000 plus index X. The register and CPU flags are
; unchanged.
    lda $d100,x                          ; Load a value or memory byte into accumulator A.
; Book line 513: Load A with the byte at $d100 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
    sta FONT+$100,x                      ; Store accumulator A into memory.
; Book line 514: Store A into the byte at FONT+$100 plus index X. The register and CPU flags are
; unchanged.
    lda $d200,x                          ; Load a value or memory byte into accumulator A.
; Book line 515: Load A with the byte at $d200 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
    sta FONT+$200,x                      ; Store accumulator A into memory.
; Book line 516: Store A into the byte at FONT+$200 plus index X. The register and CPU flags are
; unchanged.
    lda $d300,x                          ; Load a value or memory byte into accumulator A.
; Book line 517: Load A with the byte at $d300 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
    sta FONT+$300,x                      ; Store accumulator A into memory.
; Book line 518: Store A into the byte at FONT+$300 plus index X. The register and CPU flags are
; unchanged.
    lda $d400,x                          ; Load a value or memory byte into accumulator A. Target: SID voice 1 frequency low.
; Book line 519: Load A with the byte at $d400 (SID voice 1 frequency low) plus index X. Z records a
; zero value; N copies bit 7. Carry is unchanged.
    sta FONT+$400,x                      ; Store accumulator A into memory.
; Book line 520: Store A into the byte at FONT+$400 plus index X. The register and CPU flags are
; unchanged.
    lda $d500,x                          ; Load a value or memory byte into accumulator A.
; Book line 521: Load A with the byte at $d500 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
    sta FONT+$500,x                      ; Store accumulator A into memory.
; Book line 522: Store A into the byte at FONT+$500 plus index X. The register and CPU flags are
; unchanged.
    lda $d600,x                          ; Load a value or memory byte into accumulator A.
; Book line 523: Load A with the byte at $d600 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
    sta FONT+$600,x                      ; Store accumulator A into memory.
; Book line 524: Store A into the byte at FONT+$600 plus index X. The register and CPU flags are
; unchanged.
    lda $d700,x                          ; Load a value or memory byte into accumulator A.
; Book line 525: Load A with the byte at $d700 plus index X. Z records a zero value; N copies bit 7.
; Carry is unchanged.
    sta FONT+$700,x                      ; Store accumulator A into memory.
; Book line 526: Store A into the byte at FONT+$700 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 527: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    bne copy_loop                        ; Branch if not equal/zero flag is clear.
; Book line 528: Branch to copy_loop if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    pla                                  ; Pull A from the CPU stack.
; Book line 529: Pull the most recently stacked byte into A, increasing the stack pointer. Update Z
; and N from the restored byte.
    sta $01             ; restore I/O visibility
; Book line 530: Store A into the byte at $01 (6510 ROM and I/O banking port). The register and CPU
; flags are unchanged.
    ldx #7                               ; Load a value into index register X. Here # means an immediate number.
; Book line 531: Load X with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
custom_loop:
; Book line 532: custom_loop names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    lda brick_pixels,x                   ; Load a value or memory byte into accumulator A.
; Book line 533: Load A with the byte at brick_pixels plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
    sta FONT+BRICK*8,x                   ; Store accumulator A into memory.
; Book line 534: Store A into the byte at FONT+BRICK*8 plus index X. The register and CPU flags are
; unchanged.
    lda willy_pixels,x                   ; Load a value or memory byte into accumulator A.
; Book line 535: Load A with the byte at willy_pixels plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
    sta FONT+WILLY*8,x                   ; Store accumulator A into memory.
; Book line 536: Store A into the byte at FONT+WILLY*8 plus index X. The register and CPU flags are
; unchanged.
    lda key_pixels,x                     ; Load a value or memory byte into accumulator A.
; Book line 537: Load A with the byte at key_pixels plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
    sta FONT+KEY*8,x                     ; Store accumulator A into memory.
; Book line 538: Store A into the byte at FONT+KEY*8 plus index X. The register and CPU flags are
; unchanged.
    lda crumble_pixels,x                 ; Load a value or memory byte into accumulator A.
; Book line 539: Load A with the byte at crumble_pixels plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
    sta FONT+CRUMBLE*8,x                 ; Store accumulator A into memory.
; Book line 540: Store A into the byte at FONT+CRUMBLE*8 plus index X. The register and CPU flags are
; unchanged.
    lda conveyor_pixels,x                ; Load a value or memory byte into accumulator A.
; Book line 541: Load A with the byte at conveyor_pixels plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
    sta FONT+CONVEYOR*8,x                ; Store accumulator A into memory.
; Book line 542: Store A into the byte at FONT+CONVEYOR*8 plus index X. The register and CPU flags are
; unchanged.
    lda exit_pixels,x                    ; Load a value or memory byte into accumulator A.
; Book line 543: Load A with the byte at exit_pixels plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
    sta FONT+EXIT_TILE*8,x               ; Store accumulator A into memory.
; Book line 544: Store A into the byte at FONT+EXIT_TILE*8 plus index X. The register and CPU flags
; are unchanged.
    lda enemy_pixels,x                   ; Load a value or memory byte into accumulator A.
; Book line 545: Load A with the byte at enemy_pixels plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
    sta FONT+ENEMY*8,x                   ; Store accumulator A into memory.
; Book line 546: Store A into the byte at FONT+ENEMY*8 plus index X. The register and CPU flags are
; unchanged.
    lda spike_pixels,x                   ; Load a value or memory byte into accumulator A.
; Book line 547: Load A with the byte at spike_pixels plus index X. Z records a zero value; N copies
; bit 7. Carry is unchanged.
    sta FONT+SPIKE*8,x                   ; Store accumulator A into memory.
; Book line 548: Store A into the byte at FONT+SPIKE*8 plus index X. The register and CPU flags are
; unchanged.
    dex                                  ; Decrease X by one.
; Book line 549: Decrease X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    bpl custom_loop                      ; Branch if negative flag is clear.
; Book line 550: Branch to custom_loop if N is 0 (bit 7 clear); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 551: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; ROUTINE: make_level
; WHAT / WHY / HOW: Build level: draw platforms, conveyor, hazards, items and exit.
; ============================================================================
make_level:
; Book line 558: make_level names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    ldx #0                               ; Load a value into index register X. Here # means an immediate number.
; Book line 559: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
clear_screen:
; Book line 560: clear_screen names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda #EMPTY                           ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 561: Load A with literal EMPTY. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SCREEN+$000,x                    ; Store accumulator A into memory.
; Book line 562: Store A into the byte at SCREEN+$000 plus index X. The register and CPU flags are
; unchanged.
    sta SCREEN+$100,x                    ; Store accumulator A into memory.
; Book line 563: Store A into the byte at SCREEN+$100 plus index X. The register and CPU flags are
; unchanged.
    sta SCREEN+$200,x                    ; Store accumulator A into memory.
; Book line 564: Store A into the byte at SCREEN+$200 plus index X. The register and CPU flags are
; unchanged.
    sta SCREEN+$300,x                    ; Store accumulator A into memory.
; Book line 565: Store A into the byte at SCREEN+$300 plus index X. The register and CPU flags are
; unchanged.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 566: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+$000,x                    ; Store accumulator A into memory.
; Book line 567: Store A into the byte at COLORS+$000 plus index X. The register and CPU flags are
; unchanged.
    sta COLORS+$100,x                    ; Store accumulator A into memory.
; Book line 568: Store A into the byte at COLORS+$100 plus index X. The register and CPU flags are
; unchanged.
    sta COLORS+$200,x                    ; Store accumulator A into memory.
; Book line 569: Store A into the byte at COLORS+$200 plus index X. The register and CPU flags are
; unchanged.
    sta COLORS+$300,x                    ; Store accumulator A into memory.
; Book line 570: Store A into the byte at COLORS+$300 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 571: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    bne clear_screen                     ; Branch if not equal/zero flag is clear.
; Book line 572: Branch to clear_screen if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.

    ; Status line in C64 screen codes (A=1, B=2, etc.).
    lda #9                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 575: Load A with literal 9. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+0    ; I
; Book line 576: Store A into the byte at SCREEN+24*40+0. The register and CPU flags are unchanged.
    lda #20                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 577: Load A with literal 20. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+1    ; T
; Book line 578: Store A into the byte at SCREEN+24*40+1. The register and CPU flags are unchanged.
    lda #5                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 579: Load A with literal 5. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+2    ; E
; Book line 580: Store A into the byte at SCREEN+24*40+2. The register and CPU flags are unchanged.
    lda #13                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 581: Load A with literal 13. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+3    ; M
; Book line 582: Store A into the byte at SCREEN+24*40+3. The register and CPU flags are unchanged.
    lda #19                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 583: Load A with literal 19. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+4    ; S
; Book line 584: Store A into the byte at SCREEN+24*40+4. The register and CPU flags are unchanged.
    lda #12                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 585: Load A with literal 12. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+15   ; L
; Book line 586: Store A into the byte at SCREEN+24*40+15. The register and CPU flags are unchanged.
    lda #9                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 587: Load A with literal 9. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+16   ; I
; Book line 588: Store A into the byte at SCREEN+24*40+16. The register and CPU flags are unchanged.
    lda #22                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 589: Load A with literal 22. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+17   ; V
; Book line 590: Store A into the byte at SCREEN+24*40+17. The register and CPU flags are unchanged.
    lda #5                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 591: Load A with literal 5. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+18   ; E
; Book line 592: Store A into the byte at SCREEN+24*40+18. The register and CPU flags are unchanged.
    lda #19                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 593: Load A with literal 19. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+19   ; S
; Book line 594: Store A into the byte at SCREEN+24*40+19. The register and CPU flags are unchanged.
    ; Central Cavern-inspired stepped route, designed so that every
    ; platform can be reached with the existing five-row jump.
    ; This is an original C64 adaptation, not a Spectrum map dump.
    ; Lower floor: no impassable enemies blocking the only route.
    ldx #0                               ; Load a value into index register X. Here # means an immediate number.
; Book line 599: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
v4_floor:
; Book line 600: v4_floor names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    lda #BRICK                           ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 601: Load A with literal BRICK. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SCREEN+22*40,x                   ; Store accumulator A into memory.
; Book line 602: Store A into the byte at SCREEN+22*40 plus index X. The register and CPU flags are
; unchanged.
    lda #2                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 603: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+22*40,x                   ; Store accumulator A into memory.
; Book line 604: Store A into the byte at COLORS+22*40 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 605: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    cpx #40                              ; Compare X with operand. Here # means an immediate number.
; Book line 606: Compare X with literal 40 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne v4_floor                         ; Branch if not equal/zero flag is clear.
; Book line 607: Branch to v4_floor if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.

    ; Staggered ascent: floor y22 -> ledge y18 -> y14 -> y10 -> y6.
    ; Gaps on rows 18, 14, 10 and 6 allow deliberate descents.
    ; Keep the collectibles and door at their original coordinates.
    ; The platforms overlap horizontally to allow walking/jumping
    ; around patrols instead of requiring a jump straight over them.
    ldx #1                               ; Load a value into index register X. Here # means an immediate number.
; Book line 614: Load X with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
v4_lower_left:
; Book line 615: v4_lower_left names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda #BRICK                           ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 616: Load A with literal BRICK. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SCREEN+18*40,x                   ; Store accumulator A into memory.
; Book line 617: Store A into the byte at SCREEN+18*40 plus index X. The register and CPU flags are
; unchanged.
    lda #6                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 618: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+18*40,x                   ; Store accumulator A into memory.
; Book line 619: Store A into the byte at COLORS+18*40 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 620: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    cpx #15                              ; Compare X with operand. Here # means an immediate number.
; Book line 621: Compare X with literal 15 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne v4_lower_left                    ; Branch if not equal/zero flag is clear.
; Book line 622: Branch to v4_lower_left if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
    ldx #24                              ; Load a value into index register X. Here # means an immediate number.
; Book line 623: Load X with literal 24. Z records a zero value; N copies bit 7. Carry is unchanged.
v4_lower_right:
; Book line 624: v4_lower_right names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda #BRICK                           ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 625: Load A with literal BRICK. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SCREEN+18*40,x                   ; Store accumulator A into memory.
; Book line 626: Store A into the byte at SCREEN+18*40 plus index X. The register and CPU flags are
; unchanged.
    lda #6                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 627: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+18*40,x                   ; Store accumulator A into memory.
; Book line 628: Store A into the byte at COLORS+18*40 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 629: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    cpx #39                              ; Compare X with operand. Here # means an immediate number.
; Book line 630: Compare X with literal 39 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne v4_lower_right                   ; Branch if not equal/zero flag is clear.
; Book line 631: Branch to v4_lower_right if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.

    ; THIRD TIER: two ledges instead of one long screen-wide barrier.
    ; Gap at columns 19-22 allows an alternative ascent/descent path.
    ; Each ledge is reachable from the lower platforms with a 5-row jump.
    ldx #7                               ; Load a value into index register X. Here # means an immediate number.
; Book line 636: Load X with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
v5_middle_left:
; Book line 637: v5_middle_left names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda #CRUMBLE                         ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 638: Load A with literal CRUMBLE. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SCREEN+14*40,x                   ; Store accumulator A into memory.
; Book line 639: Store A into the byte at SCREEN+14*40 plus index X. The register and CPU flags are
; unchanged.
    lda #7                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 640: Load A with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+14*40,x                   ; Store accumulator A into memory.
; Book line 641: Store A into the byte at COLORS+14*40 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 642: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    cpx #19                              ; Compare X with operand. Here # means an immediate number.
; Book line 643: Compare X with literal 19 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne v5_middle_left                   ; Branch if not equal/zero flag is clear.
; Book line 644: Branch to v5_middle_left if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
    ldx #23                              ; Load a value into index register X. Here # means an immediate number.
; Book line 645: Load X with literal 23. Z records a zero value; N copies bit 7. Carry is unchanged.
v5_middle_right:
; Book line 646: v5_middle_right names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda #CRUMBLE                         ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 647: Load A with literal CRUMBLE. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SCREEN+14*40,x                   ; Store accumulator A into memory.
; Book line 648: Store A into the byte at SCREEN+14*40 plus index X. The register and CPU flags are
; unchanged.
    lda #7                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 649: Load A with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+14*40,x                   ; Store accumulator A into memory.
; Book line 650: Store A into the byte at COLORS+14*40 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 651: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    cpx #35                              ; Compare X with operand. Here # means an immediate number.
; Book line 652: Compare X with literal 35 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne v5_middle_right                  ; Branch if not equal/zero flag is clear.
; Book line 653: Branch to v5_middle_right if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.

    ldx #1                               ; Load a value into index register X. Here # means an immediate number.
; Book line 655: Load X with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
v4_upper_left:
; Book line 656: v4_upper_left names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda #BRICK                           ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 657: Load A with literal BRICK. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SCREEN+10*40,x                   ; Store accumulator A into memory.
; Book line 658: Store A into the byte at SCREEN+10*40 plus index X. The register and CPU flags are
; unchanged.
    lda #5                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 659: Load A with literal 5. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+10*40,x                   ; Store accumulator A into memory.
; Book line 660: Store A into the byte at COLORS+10*40 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 661: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    cpx #18                              ; Compare X with operand. Here # means an immediate number.
; Book line 662: Compare X with literal 18 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne v4_upper_left                    ; Branch if not equal/zero flag is clear.
; Book line 663: Branch to v4_upper_left if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.

    ; Complete the right-hand upper ledge with ordinary bricks first.
    ; Only a SHORT section should be conveyor, not nearly half a row.
    ldx #23                              ; Load a value into index register X. Here # means an immediate number.
; Book line 667: Load X with literal 23. Z records a zero value; N copies bit 7. Carry is unchanged.
v8_upper_right:
; Book line 668: v8_upper_right names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda #BRICK                           ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 669: Load A with literal BRICK. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SCREEN+10*40,x                   ; Store accumulator A into memory.
; Book line 670: Store A into the byte at SCREEN+10*40 plus index X. The register and CPU flags are
; unchanged.
    lda #5                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 671: Load A with literal 5. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+10*40,x                   ; Store accumulator A into memory.
; Book line 672: Store A into the byte at COLORS+10*40 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 673: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    cpx #39                              ; Compare X with operand. Here # means an immediate number.
; Book line 674: Compare X with literal 39 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne v8_upper_right                   ; Branch if not equal/zero flag is clear.
; Book line 675: Branch to v8_upper_right if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.

    ; Small right-moving conveyor, columns 28-34 only.
    ldx #28                              ; Load a value into index register X. Here # means an immediate number.
; Book line 678: Load X with literal 28. Z records a zero value; N copies bit 7. Carry is unchanged.
v4_conveyor:
; Book line 679: v4_conveyor names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    lda #CONVEYOR                        ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 680: Load A with literal CONVEYOR. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SCREEN+10*40,x                   ; Store accumulator A into memory.
; Book line 681: Store A into the byte at SCREEN+10*40 plus index X. The register and CPU flags are
; unchanged.
    lda #3                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 682: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+10*40,x                   ; Store accumulator A into memory.
; Book line 683: Store A into the byte at COLORS+10*40 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 684: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    cpx #35                              ; Compare X with operand. Here # means an immediate number.
; Book line 685: Compare X with literal 35 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne v4_conveyor                      ; Branch if not equal/zero flag is clear.
; Book line 686: Branch to v4_conveyor if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.

    ldx #9                               ; Load a value into index register X. Here # means an immediate number.
; Book line 688: Load X with literal 9. Z records a zero value; N copies bit 7. Carry is unchanged.
v4_top:
; Book line 689: v4_top names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    lda #BRICK                           ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 690: Load A with literal BRICK. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SCREEN+6*40,x                    ; Store accumulator A into memory.
; Book line 691: Store A into the byte at SCREEN+6*40 plus index X. The register and CPU flags are
; unchanged.
    lda #4                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 692: Load A with literal 4. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+6*40,x                    ; Store accumulator A into memory.
; Book line 693: Store A into the byte at COLORS+6*40 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 694: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    cpx #25                              ; Compare X with operand. Here # means an immediate number.
; Book line 695: Compare X with literal 25 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne v4_top                           ; Branch if not equal/zero flag is clear.
; Book line 696: Branch to v4_top if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    ; Second top ledge: an opening at columns 25-28 lets Willy
    ; drop back to the middle tiers for missed collectibles.
    ldx #29                              ; Load a value into index register X. Here # means an immediate number.
; Book line 699: Load X with literal 29. Z records a zero value; N copies bit 7. Carry is unchanged.
v15_top_right:
; Book line 700: v15_top_right names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda #BRICK                           ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 701: Load A with literal BRICK. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SCREEN+6*40,x                    ; Store accumulator A into memory.
; Book line 702: Store A into the byte at SCREEN+6*40 plus index X. The register and CPU flags are
; unchanged.
    lda #4                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 703: Load A with literal 4. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+6*40,x                    ; Store accumulator A into memory.
; Book line 704: Store A into the byte at COLORS+6*40 plus index X. The register and CPU flags are
; unchanged.
    inx                                  ; Increase X by one.
; Book line 705: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    cpx #38                              ; Compare X with operand. Here # means an immediate number.
; Book line 706: Compare X with literal 38 without changing X. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne v15_top_right                    ; Branch if not equal/zero flag is clear.
; Book line 707: Branch to v15_top_right if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.

    ; Spikes are hazards but do not close off the only route.
    lda #SPIKE                           ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 710: Load A with literal SPIKE. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SCREEN+21*40+19                  ; Store accumulator A into memory.
; Book line 711: Store A into the byte at SCREEN+21*40+19. The register and CPU flags are unchanged.
    sta SCREEN+21*40+20                  ; Store accumulator A into memory.
; Book line 712: Store A into the byte at SCREEN+21*40+20. The register and CPU flags are unchanged.
    sta SCREEN+17*40+35                  ; Store accumulator A into memory.
; Book line 713: Store A into the byte at SCREEN+17*40+35. The register and CPU flags are unchanged.
    lda #2                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 714: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+21*40+19                  ; Store accumulator A into memory.
; Book line 715: Store A into the byte at COLORS+21*40+19. The register and CPU flags are unchanged.
    sta COLORS+21*40+20                  ; Store accumulator A into memory.
; Book line 716: Store A into the byte at COLORS+21*40+20. The register and CPU flags are unchanged.
    sta COLORS+17*40+35                  ; Store accumulator A into memory.
; Book line 717: Store A into the byte at COLORS+17*40+35. The register and CPU flags are unchanged.

    ; Seven keys, each above a reachable surface.
    lda #KEY                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 720: Load A with literal KEY. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+21*40+7                   ; Store accumulator A into memory.
; Book line 721: Store A into the byte at SCREEN+21*40+7. The register and CPU flags are unchanged.
    sta SCREEN+17*40+11                  ; Store accumulator A into memory.
; Book line 722: Store A into the byte at SCREEN+17*40+11. The register and CPU flags are unchanged.
    sta SCREEN+17*40+28                  ; Store accumulator A into memory.
; Book line 723: Store A into the byte at SCREEN+17*40+28. The register and CPU flags are unchanged.
    sta SCREEN+13*40+16                  ; Store accumulator A into memory.
; Book line 724: Store A into the byte at SCREEN+13*40+16. The register and CPU flags are unchanged.
    sta SCREEN+9*40+8                    ; Store accumulator A into memory.
; Book line 725: Store A into the byte at SCREEN+9*40+8. The register and CPU flags are unchanged.
    sta SCREEN+9*40+29                   ; Store accumulator A into memory.
; Book line 726: Store A into the byte at SCREEN+9*40+29. The register and CPU flags are unchanged.
    sta SCREEN+5*40+18                   ; Store accumulator A into memory.
; Book line 727: Store A into the byte at SCREEN+5*40+18. The register and CPU flags are unchanged.
    lda #7                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 728: Load A with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+21*40+7                   ; Store accumulator A into memory.
; Book line 729: Store A into the byte at COLORS+21*40+7. The register and CPU flags are unchanged.
    sta COLORS+17*40+11                  ; Store accumulator A into memory.
; Book line 730: Store A into the byte at COLORS+17*40+11. The register and CPU flags are unchanged.
    sta COLORS+17*40+28                  ; Store accumulator A into memory.
; Book line 731: Store A into the byte at COLORS+17*40+28. The register and CPU flags are unchanged.
    sta COLORS+13*40+16                  ; Store accumulator A into memory.
; Book line 732: Store A into the byte at COLORS+13*40+16. The register and CPU flags are unchanged.
    sta COLORS+9*40+8                    ; Store accumulator A into memory.
; Book line 733: Store A into the byte at COLORS+9*40+8. The register and CPU flags are unchanged.
    sta COLORS+9*40+29                   ; Store accumulator A into memory.
; Book line 734: Store A into the byte at COLORS+9*40+29. The register and CPU flags are unchanged.
    sta COLORS+5*40+18                   ; Store accumulator A into memory.
; Book line 735: Store A into the byte at COLORS+5*40+18. The register and CPU flags are unchanged.

    ; Door sits on the top platform. Touching it ends the demo.
    lda #EXIT_TILE                       ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 738: Load A with literal EXIT_TILE. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SCREEN+5*40+34                   ; Store accumulator A into memory.
; Book line 739: Store A into the byte at SCREEN+5*40+34. The register and CPU flags are unchanged.
    lda #5                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 740: Load A with literal 5. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta COLORS+5*40+34                   ; Store accumulator A into memory.
; Book line 741: Store A into the byte at COLORS+5*40+34. The register and CPU flags are unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 742: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Build an address from TY * 40 + TX without 8-bit overflow.
; Repeated addition of 40 uses the full 16-bit pointer.
; Also create matching colour-RAM address ($d800 instead of $0400).

; ============================================================================
; ROUTINE: address
; WHAT / WHY / HOW: Convert a tile column and row into a 16-bit screen/colour memory address.
; ============================================================================
address:
; Book line 752: address names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    lda #<SCREEN                         ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 753: Load A with the low address byte of SCREEN as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
    sta PTR                              ; Store accumulator A into memory.
; Book line 754: Store A into the byte at PTR (pointer storage). The register and CPU flags are
; unchanged.
    lda #>SCREEN                         ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 755: Load A with the high address byte of SCREEN as an immediate value. Z records a zero
; value; N copies bit 7. Carry is unchanged.
    sta PTR+1                            ; Store accumulator A into memory.
; Book line 756: Store A into the byte at PTR+1. The register and CPU flags are unchanged.
    ldx TY                               ; Load a value into index register X.
; Book line 757: Load X with the byte at TY. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    beq add_column                       ; Branch if equal/zero flag is set.
; Book line 758: Branch to add_column if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
row_loop:
; Book line 759: row_loop names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    clc                                  ; Clear carry before an addition.
; Book line 760: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
    lda PTR                              ; Load a value or memory byte into accumulator A.
; Book line 761: Load A with the byte at PTR (pointer storage). Z records a zero value; N copies bit
; 7. Carry is unchanged.
    adc #40                              ; Add operand and carry to A. Here # means an immediate number.
; Book line 762: Add literal 40 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
    sta PTR                              ; Store accumulator A into memory.
; Book line 763: Store A into the byte at PTR (pointer storage). The register and CPU flags are
; unchanged.
    bcc no_row_carry                     ; Branch if carry is clear (often unsigned less-than).
; Book line 764: Branch to no_row_carry if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
    inc PTR+1                            ; Add one to a memory byte.
; Book line 765: Increase the byte at PTR+1 by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
no_row_carry:
; Book line 766: no_row_carry names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    dex                                  ; Decrease X by one.
; Book line 767: Decrease X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    bne row_loop                         ; Branch if not equal/zero flag is clear.
; Book line 768: Branch to row_loop if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
add_column:
; Book line 769: add_column names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    clc                                  ; Clear carry before an addition.
; Book line 770: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
    lda PTR                              ; Load a value or memory byte into accumulator A.
; Book line 771: Load A with the byte at PTR (pointer storage). Z records a zero value; N copies bit
; 7. Carry is unchanged.
    adc TX                               ; Add operand and carry to A.
; Book line 772: Add the byte at TX and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
    sta PTR                              ; Store accumulator A into memory.
; Book line 773: Store A into the byte at PTR (pointer storage). The register and CPU flags are
; unchanged.
    bcc no_col_carry                     ; Branch if carry is clear (often unsigned less-than).
; Book line 774: Branch to no_col_carry if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
    inc PTR+1                            ; Add one to a memory byte.
; Book line 775: Increase the byte at PTR+1 by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
no_col_carry:
; Book line 776: no_col_carry names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda PTR                              ; Load a value or memory byte into accumulator A.
; Book line 777: Load A with the byte at PTR (pointer storage). Z records a zero value; N copies bit
; 7. Carry is unchanged.
    sta CPTR                             ; Store accumulator A into memory.
; Book line 778: Store A into the byte at CPTR (colour pointer storage). The register and CPU flags
; are unchanged.
    lda PTR+1                            ; Load a value or memory byte into accumulator A.
; Book line 779: Load A with the byte at PTR+1. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    clc                                  ; Clear carry before an addition.
; Book line 780: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
    adc #$d4            ; $0400 -> $d800
; Book line 781: Add literal $d4 (decimal 212) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
    sta CPTR+1                           ; Store accumulator A into memory.
; Book line 782: Store A into the byte at CPTR+1. The register and CPU flags are unchanged.
    ldy #0                               ; Load a value into index register Y. Here # means an immediate number.
; Book line 783: Load Y with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 784: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; ROUTINE: player_address
; WHAT / WHY / HOW: Select the player tile position for drawing and collision tests.
; ============================================================================
player_address:
; Book line 791: player_address names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda PX                               ; Load a value or memory byte into accumulator A.
; Book line 792: Load A with the byte at PX (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    sta TX                               ; Store accumulator A into memory.
; Book line 793: Store A into the byte at TX. The register and CPU flags are unchanged.
    lda PY                               ; Load a value or memory byte into accumulator A.
; Book line 794: Load A with the byte at PY (logical player row). Z records a zero value; N copies bit
; 7. Carry is unchanged.
    sta TY                               ; Store accumulator A into memory.
; Book line 795: Store A into the byte at TY. The register and CPU flags are unchanged.
    jmp address                          ; Jump directly to another location.
; Book line 796: Continue execution at address without saving a return address. Registers and flags
; are unchanged by the jump itself.


; ============================================================================
; ROUTINE: draw_player
; WHAT / WHY / HOW: Draw the player representation at the logical tile location.
; ============================================================================
draw_player:
; Book line 803: draw_player names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    rts                 ; now rendered by VIC-II sprite 0
; Book line 804: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; ROUTINE: erase_player
; WHAT / WHY / HOW: Remove the previous player representation while preserving the map.
; ============================================================================
erase_player:
; Book line 811: erase_player names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    rts                 ; sprite movement never damages background tiles
; Book line 812: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Joystick 2 is active LOW: pressed directions read as zero.

; ============================================================================
; ROUTINE: controls
; WHAT / WHY / HOW: Read joystick directions and jump input; enforce movement limits.
; ============================================================================
controls:
; Book line 820: controls names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    lda JOY2                             ; Load a value or memory byte into accumulator A.
; Book line 821: Load A with the byte at JOY2 (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    and #$04                             ; Bitwise AND: keep only bits present in both values. Here # means an immediate number.
; Book line 822: Keep only bits set in both A and literal $04 (decimal 4). Save the result in A and
; update Z and N; carry is unchanged.
    bne try_right                        ; Branch if not equal/zero flag is clear.
; Book line 823: Branch to try_right if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda PX                               ; Load a value or memory byte into accumulator A.
; Book line 824: Load A with the byte at PX (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    beq try_right                        ; Branch if equal/zero flag is set.
; Book line 825: Branch to try_right if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    dec PX                               ; Subtract one from a memory byte.
; Book line 826: Decrease the byte at PX (logical player column) by one with 8-bit wraparound. Update
; Z and N; carry is unchanged.
try_right:
; Book line 827: try_right names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    lda JOY2                             ; Load a value or memory byte into accumulator A.
; Book line 828: Load A with the byte at JOY2 (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    and #$08                             ; Bitwise AND: keep only bits present in both values. Here # means an immediate number.
; Book line 829: Keep only bits set in both A and literal $08 (decimal 8). Save the result in A and
; update Z and N; carry is unchanged.
    bne try_jump                         ; Branch if not equal/zero flag is clear.
; Book line 830: Branch to try_jump if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda PX                               ; Load a value or memory byte into accumulator A.
; Book line 831: Load A with the byte at PX (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    cmp #38                              ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 832: Compare A with literal 38 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bcs try_jump                         ; Branch if carry is set (often unsigned >=).
; Book line 833: Branch to try_jump if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
    inc PX                               ; Add one to a memory byte.
; Book line 834: Increase the byte at PX (logical player column) by one with 8-bit wraparound. Update
; Z and N; carry is unchanged.
try_jump:
; Book line 835: try_jump names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    lda JOY2                             ; Load a value or memory byte into accumulator A.
; Book line 836: Load A with the byte at JOY2 (CIA1 port A and joystick 2). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    and #$11            ; up OR fire: jump if EITHER is pressed
; Book line 837: Keep only bits set in both A and literal $11 (decimal 17). Save the result in A and
; update Z and N; carry is unchanged.
    cmp #$11                             ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 838: Compare A with literal $11 (decimal 17) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
    beq controls_done                    ; Branch if equal/zero flag is set.
; Book line 839: Branch to controls_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda JUMP                             ; Load a value or memory byte into accumulator A.
; Book line 840: Load A with the byte at JUMP (jump table position). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    bne controls_done                    ; Branch if not equal/zero flag is clear.
; Book line 841: Branch to controls_done if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
    jsr floor_below                      ; Call a subroutine; execution returns after its RTS.
; Book line 842: Call floor_below, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    bcc controls_done  ; only jump when standing on a brick
; Book line 843: Branch to controls_done if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 844: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta JUMP                             ; Store accumulator A into memory.
; Book line 845: Store A into the byte at JUMP (jump table position). The register and CPU flags are
; unchanged.
    lda #3                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 846: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
    jsr start_effect     ; short jump chirp
; Book line 847: Call start_effect, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
controls_done:
; Book line 848: controls_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    rts                                  ; Return from the current subroutine.
; Book line 849: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; If Willy stands directly above a conveyor, the belt pushes him
; one character right every second movement update. Never leave screen.

; ============================================================================
; ROUTINE: conveyor_motion
; WHAT / WHY / HOW: Apply horizontal conveyor motion while the player is supported.
; ============================================================================
conveyor_motion:
; Book line 858: conveyor_motion names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda JUMP                             ; Load a value or memory byte into accumulator A.
; Book line 859: Load A with the byte at JUMP (jump table position). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    bne conveyor_done                    ; Branch if not equal/zero flag is clear.
; Book line 860: Branch to conveyor_done if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
    lda PY                               ; Load a value or memory byte into accumulator A.
; Book line 861: Load A with the byte at PY (logical player row). Z records a zero value; N copies bit
; 7. Carry is unchanged.
    cmp #23                              ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 862: Compare A with literal 23 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bcs conveyor_done                    ; Branch if carry is set (often unsigned >=).
; Book line 863: Branch to conveyor_done if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
    lda PX                               ; Load a value or memory byte into accumulator A.
; Book line 864: Load A with the byte at PX (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    sta TX                               ; Store accumulator A into memory.
; Book line 865: Store A into the byte at TX. The register and CPU flags are unchanged.
    lda PY                               ; Load a value or memory byte into accumulator A.
; Book line 866: Load A with the byte at PY (logical player row). Z records a zero value; N copies bit
; 7. Carry is unchanged.
    clc                                  ; Clear carry before an addition.
; Book line 867: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
    adc #1                               ; Add operand and carry to A. Here # means an immediate number.
; Book line 868: Add literal 1 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
    sta TY                               ; Store accumulator A into memory.
; Book line 869: Store A into the byte at TY. The register and CPU flags are unchanged.
    jsr address                          ; Call a subroutine; execution returns after its RTS.
; Book line 870: Call address, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
    lda (PTR),y                          ; Load a value or memory byte into accumulator A. Parentheses indicate indirect memory addressing.
; Book line 871: Load A with the byte at the address in zero-page pair PTR and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
    cmp #CONVEYOR                        ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 872: Compare A with literal CONVEYOR without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    bne conveyor_done                    ; Branch if not equal/zero flag is clear.
; Book line 873: Branch to conveyor_done if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
    inc CONVEY_TICK                      ; Add one to a memory byte.
; Book line 874: Increase the byte at CONVEY_TICK by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
    lda CONVEY_TICK                      ; Load a value or memory byte into accumulator A.
; Book line 875: Load A with the byte at CONVEY_TICK. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    and #1                               ; Bitwise AND: keep only bits present in both values. Here # means an immediate number.
; Book line 876: Keep only bits set in both A and literal 1. Save the result in A and update Z and N;
; carry is unchanged.
    bne conveyor_done                    ; Branch if not equal/zero flag is clear.
; Book line 877: Branch to conveyor_done if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
    lda PX                               ; Load a value or memory byte into accumulator A.
; Book line 878: Load A with the byte at PX (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    cmp #38                              ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 879: Compare A with literal 38 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bcs conveyor_done                    ; Branch if carry is set (often unsigned >=).
; Book line 880: Branch to conveyor_done if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
    inc PX                               ; Add one to a memory byte.
; Book line 881: Increase the byte at PX (logical player column) by one with 8-bit wraparound. Update
; Z and N; carry is unchanged.
conveyor_done:
; Book line 882: conveyor_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    rts                                  ; Return from the current subroutine.
; Book line 883: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Return carry SET if tile immediately below player is a brick.
; Bottom boundary acts as solid ground.

; ============================================================================
; ROUTINE: floor_below
; WHAT / WHY / HOW: Test the tiles beneath the player for supporting ground.
; ============================================================================
floor_below:
; Book line 892: floor_below names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    ; A sprite has width, so its feet can still overlap the edge of
    ; a neighbouring platform even when its centre enters a gap.
    ; Check the tile below the centre, then the adjacent tiles.
    lda PY                               ; Load a value or memory byte into accumulator A.
; Book line 896: Load A with the byte at PY (logical player row). Z records a zero value; N copies bit
; 7. Carry is unchanged.
    cmp #23                              ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 897: Compare A with literal 23 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bcs supported                        ; Branch if carry is set (often unsigned >=).
; Book line 898: Branch to supported if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
    lda PY                               ; Load a value or memory byte into accumulator A.
; Book line 899: Load A with the byte at PY (logical player row). Z records a zero value; N copies bit
; 7. Carry is unchanged.
    clc                                  ; Clear carry before an addition.
; Book line 900: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
    adc #1                               ; Add operand and carry to A. Here # means an immediate number.
; Book line 901: Add literal 1 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
    sta TY                               ; Store accumulator A into memory.
; Book line 902: Store A into the byte at TY. The register and CPU flags are unchanged.
    lda PX                               ; Load a value or memory byte into accumulator A.
; Book line 903: Load A with the byte at PX (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    sta TX                               ; Store accumulator A into memory.
; Book line 904: Store A into the byte at TX. The register and CPU flags are unchanged.
    jsr support_at_tx                    ; Call a subroutine; execution returns after its RTS.
; Book line 905: Call support_at_tx, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    bcs supported                        ; Branch if carry is set (often unsigned >=).
; Book line 906: Branch to supported if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
    lda PX                               ; Load a value or memory byte into accumulator A.
; Book line 907: Load A with the byte at PX (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    beq check_support_right              ; Branch if equal/zero flag is set.
; Book line 908: Branch to check_support_right if Z is 1 (zero or equal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
    sec                                  ; Set carry before subtraction.
; Book line 909: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
    sbc #1                               ; Subtract operand and inverse carry from A. Here # means an immediate number.
; Book line 910: Subtract literal 1 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
    sta TX                               ; Store accumulator A into memory.
; Book line 911: Store A into the byte at TX. The register and CPU flags are unchanged.
    jsr support_at_tx                    ; Call a subroutine; execution returns after its RTS.
; Book line 912: Call support_at_tx, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    bcs supported                        ; Branch if carry is set (often unsigned >=).
; Book line 913: Branch to supported if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
check_support_right:
; Book line 914: check_support_right names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
    lda PX                               ; Load a value or memory byte into accumulator A.
; Book line 915: Load A with the byte at PX (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    cmp #38                              ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 916: Compare A with literal 38 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bcs unsupported                      ; Branch if carry is set (often unsigned >=).
; Book line 917: Branch to unsupported if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
    clc                                  ; Clear carry before an addition.
; Book line 918: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
    adc #1                               ; Add operand and carry to A. Here # means an immediate number.
; Book line 919: Add literal 1 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
    sta TX                               ; Store accumulator A into memory.
; Book line 920: Store A into the byte at TX. The register and CPU flags are unchanged.
    jsr support_at_tx                    ; Call a subroutine; execution returns after its RTS.
; Book line 921: Call support_at_tx, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    bcs supported                        ; Branch if carry is set (often unsigned >=).
; Book line 922: Branch to supported if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
unsupported:
; Book line 923: unsupported names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    clc                                  ; Clear carry before an addition.
; Book line 924: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
    rts                                  ; Return from the current subroutine.
; Book line 925: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
supported:
; Book line 926: supported names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    sec                                  ; Set carry before subtraction.
; Book line 927: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
    rts                                  ; Return from the current subroutine.
; Book line 928: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Return carry if the tile at (TX,TY) supports the player's feet.
support_at_tx:
; Book line 931: support_at_tx names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    jsr address                          ; Call a subroutine; execution returns after its RTS.
; Book line 932: Call address, saving a return address on the stack. Its RTS resumes after this call.
; A, X, Y and flags are not automatically preserved by a call.
    lda (PTR),y                          ; Load a value or memory byte into accumulator A. Parentheses indicate indirect memory addressing.
; Book line 933: Load A with the byte at the address in zero-page pair PTR and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
    cmp #BRICK                           ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 934: Compare A with literal BRICK without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    beq support_yes                      ; Branch if equal/zero flag is set.
; Book line 935: Branch to support_yes if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    cmp #CRUMBLE                         ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 936: Compare A with literal CRUMBLE without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    beq support_yes                      ; Branch if equal/zero flag is set.
; Book line 937: Branch to support_yes if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    cmp #CONVEYOR                        ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 938: Compare A with literal CONVEYOR without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    beq support_yes                      ; Branch if equal/zero flag is set.
; Book line 939: Branch to support_yes if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    clc                                  ; Clear carry before an addition.
; Book line 940: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
    rts                                  ; Return from the current subroutine.
; Book line 941: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
support_yes:
; Book line 942: support_yes names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    sec                                  ; Set carry before subtraction.
; Book line 943: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
    rts                                  ; Return from the current subroutine.
; Book line 944: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; ROUTINE: physics
; WHAT / WHY / HOW: Advance the jump arc or apply gravity one logical step.
; ============================================================================
physics:
; Book line 951: physics names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    lda JUMP                             ; Load a value or memory byte into accumulator A.
; Book line 952: Load A with the byte at JUMP (jump table position). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    beq gravity                          ; Branch if equal/zero flag is set.
; Book line 953: Branch to gravity if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    sec                                  ; Set carry before subtraction.
; Book line 954: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
    sbc #1                               ; Subtract operand and inverse carry from A. Here # means an immediate number.
; Book line 955: Subtract literal 1 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
    tax                                  ; Copy A into X.
; Book line 956: Copy A to X; leave A unchanged. Update Z and N from the copied value; carry is
; unchanged.
    lda jump_curve,x                     ; Load a value or memory byte into accumulator A.
; Book line 957: Load A with the byte at jump_curve plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
    cmp #$80                             ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 958: Compare A with literal $80 (decimal 128) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
    beq end_jump                         ; Branch if equal/zero flag is set.
; Book line 959: Branch to end_jump if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    cmp #$ff                             ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 960: Compare A with literal $ff (decimal 255) without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
    bne jump_down                        ; Branch if not equal/zero flag is clear.
; Book line 961: Branch to jump_down if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda PY                               ; Load a value or memory byte into accumulator A.
; Book line 962: Load A with the byte at PY (logical player row). Z records a zero value; N copies bit
; 7. Carry is unchanged.
    beq advance_jump                     ; Branch if equal/zero flag is set.
; Book line 963: Branch to advance_jump if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    dec PY                               ; Subtract one from a memory byte.
; Book line 964: Decrease the byte at PY (logical player row) by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
    jmp advance_jump                     ; Jump directly to another location.
; Book line 965: Continue execution at advance_jump without saving a return address. Registers and
; flags are unchanged by the jump itself.
jump_down:
; Book line 966: jump_down names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    cmp #1                               ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 967: Compare A with literal 1 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne advance_jump                     ; Branch if not equal/zero flag is clear.
; Book line 968: Branch to advance_jump if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    jsr floor_below                      ; Call a subroutine; execution returns after its RTS.
; Book line 969: Call floor_below, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    bcs end_jump                         ; Branch if carry is set (often unsigned >=).
; Book line 970: Branch to end_jump if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
    lda PY                               ; Load a value or memory byte into accumulator A.
; Book line 971: Load A with the byte at PY (logical player row). Z records a zero value; N copies bit
; 7. Carry is unchanged.
    cmp #23                              ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 972: Compare A with literal 23 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bcs end_jump                         ; Branch if carry is set (often unsigned >=).
; Book line 973: Branch to end_jump if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
    inc PY                               ; Add one to a memory byte.
; Book line 974: Increase the byte at PY (logical player row) by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
advance_jump:
; Book line 975: advance_jump names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    inc JUMP                             ; Add one to a memory byte.
; Book line 976: Increase the byte at JUMP (jump table position) by one with 8-bit wraparound. Update
; Z and N; carry is unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 977: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
end_jump:
; Book line 978: end_jump names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    lda #0                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 979: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta JUMP                             ; Store accumulator A into memory.
; Book line 980: Store A into the byte at JUMP (jump table position). The register and CPU flags are
; unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 981: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; ============================================================================
; ROUTINE: gravity
; WHAT / WHY / HOW: Fall when no supporting platform is beneath the player.
; ============================================================================
gravity:
; Book line 987: gravity names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    jsr floor_below                      ; Call a subroutine; execution returns after its RTS.
; Book line 988: Call floor_below, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    bcs gravity_done                     ; Branch if carry is set (often unsigned >=).
; Book line 989: Branch to gravity_done if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
    lda PY                               ; Load a value or memory byte into accumulator A.
; Book line 990: Load A with the byte at PY (logical player row). Z records a zero value; N copies bit
; 7. Carry is unchanged.
    cmp #23                              ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 991: Compare A with literal 23 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bcs gravity_done                     ; Branch if carry is set (often unsigned >=).
; Book line 992: Branch to gravity_done if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
    inc PY                               ; Add one to a memory byte.
; Book line 993: Increase the byte at PY (logical player row) by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
gravity_done:
; Book line 994: gravity_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    rts                                  ; Return from the current subroutine.
; Book line 995: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; ROUTINE: collect_key
; WHAT / WHY / HOW: Detect collectible overlap and update the item counter.
; ============================================================================
collect_key:
; Book line 1002: collect_key names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    jsr player_address                   ; Call a subroutine; execution returns after its RTS.
; Book line 1003: Call player_address, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
    lda (PTR),y                          ; Load a value or memory byte into accumulator A. Parentheses indicate indirect memory addressing.
; Book line 1004: Load A with the byte at the address in zero-page pair PTR and its next byte, plus Y.
; Z records a zero value; N copies bit 7. Carry is unchanged.
    cmp #KEY                             ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 1005: Compare A with literal KEY without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    bne test_spike                       ; Branch if not equal/zero flag is clear.
; Book line 1006: Branch to test_spike if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    inc ITEMS                            ; Add one to a memory byte.
; Book line 1007: Increase the byte at ITEMS (collected item count) by one with 8-bit wraparound.
; Update Z and N; carry is unchanged.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1008: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    jsr start_effect     ; collectible sound
; Book line 1009: Call start_effect, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    lda #EMPTY                           ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1010: Load A with literal EMPTY. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta (PTR),y                          ; Store accumulator A into memory. Parentheses indicate indirect memory addressing.
; Book line 1011: Store A into the byte at the address in zero-page pair PTR and its next byte, plus
; Y. The register and CPU flags are unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 1012: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
test_spike:
; Book line 1013: test_spike names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    cmp #SPIKE                           ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 1014: Compare A with literal SPIKE without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    beq lose_life                        ; Branch if equal/zero flag is set.
; Book line 1015: Branch to lose_life if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    cmp #EXIT_TILE                       ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 1016: Compare A with literal EXIT_TILE without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    bne no_key                           ; Branch if not equal/zero flag is clear.
; Book line 1017: Branch to no_key if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    ; Door opens only after all seven collectibles have been taken.
    lda ITEMS                            ; Load a value or memory byte into accumulator A.
; Book line 1019: Load A with the byte at ITEMS (collected item count). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    cmp #7                               ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 1020: Compare A with literal 7 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bcc no_key                           ; Branch if carry is clear (often unsigned less-than).
; Book line 1021: Branch to no_key if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1022: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta WIN                              ; Store accumulator A into memory.
; Book line 1023: Store A into the byte at WIN. The register and CPU flags are unchanged.
    sta GAME_STATE                       ; Store accumulator A into memory.
; Book line 1024: Store A into the byte at GAME_STATE (game state selector). The register and CPU
; flags are unchanged.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1025: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    jsr start_effect                     ; Call a subroutine; execution returns after its RTS.
; Book line 1026: Call start_effect, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1027: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta MENU_MODE                        ; Store accumulator A into memory.
; Book line 1028: Store A into the byte at MENU_MODE. The register and CPU flags are unchanged.
    jsr show_menu                        ; Call a subroutine; execution returns after its RTS.
; Book line 1029: Call show_menu, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
no_key:
; Book line 1030: no_key names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    rts                                  ; Return from the current subroutine.
; Book line 1031: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

 ; A hit now pauses gameplay for the death effect before rebuilding the level.
 ; GAME_STATE=3 prevents repeated collisions and instant respawning.

; ============================================================================
; ROUTINE: lose_life
; WHAT / WHY / HOW: Handle a collision that costs one life and begins the death sequence.
; ============================================================================
lose_life:
; Book line 1040: lose_life names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    lda GAME_STATE                       ; Load a value or memory byte into accumulator A.
; Book line 1041: Load A with the byte at GAME_STATE (game state selector). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    bne death_already_handled            ; Branch if not equal/zero flag is clear.
; Book line 1042: Branch to death_already_handled if Z is 0 (nonzero or unequal); otherwise continue
; at the next instruction. Test the current flag, and leave all flags unchanged.
    lda #2                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1043: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
    jsr start_effect                     ; Call a subroutine; execution returns after its RTS.
; Book line 1044: Call start_effect, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    lda #35             ; 35 PAL frames = 0.7 seconds
; Book line 1045: Load A with literal 35. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta DEATH_TIMER                      ; Store accumulator A into memory.
; Book line 1046: Store A into the byte at DEATH_TIMER. The register and CPU flags are unchanged.
    lda #3                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1047: Load A with literal 3. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta GAME_STATE                       ; Store accumulator A into memory.
; Book line 1048: Store A into the byte at GAME_STATE (game state selector). The register and CPU
; flags are unchanged.
    lda #0                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1049: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta DEATH_END                        ; Store accumulator A into memory.
; Book line 1050: Store A into the byte at DEATH_END. The register and CPU flags are unchanged.
    sta $d015           ; hide player and enemies during the death pause
; Book line 1051: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
    lda LIVES                            ; Load a value or memory byte into accumulator A.
; Book line 1052: Load A with the byte at LIVES (remaining lives). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    beq last_life                        ; Branch if equal/zero flag is set.
; Book line 1053: Branch to last_life if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    dec LIVES                            ; Subtract one from a memory byte.
; Book line 1054: Decrease the byte at LIVES (remaining lives) by one with 8-bit wraparound. Update Z
; and N; carry is unchanged.
    bne death_already_handled            ; Branch if not equal/zero flag is clear.
; Book line 1055: Branch to death_already_handled if Z is 0 (nonzero or unequal); otherwise continue
; at the next instruction. Test the current flag, and leave all flags unchanged.
last_life:
; Book line 1056: last_life names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1057: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta DEATH_END                        ; Store accumulator A into memory.
; Book line 1058: Store A into the byte at DEATH_END. The register and CPU flags are unchanged.
 death_already_handled:
; Book line 1059: death_already_handled names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
    rts                                  ; Return from the current subroutine.
; Book line 1060: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Restore the complete level, including keys and both enemy patrols.
; Do NOT reset LIVES, music state or SID registers here.

; ============================================================================
; ROUTINE: reset_level_after_death
; WHAT / WHY / HOW: Recreate the level and reset actor positions after a death.
; ============================================================================
reset_level_after_death:
; Book line 1069: reset_level_after_death names this assembled address; it emits no bytes and provides
; a jump, call or data reference target.
    jsr make_level                       ; Call a subroutine; execution returns after its RTS.
; Book line 1070: Call make_level, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    lda #2                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1071: Load A with literal 2. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta PX                               ; Store accumulator A into memory.
; Book line 1072: Store A into the byte at PX (logical player column). The register and CPU flags are
; unchanged.
    lda #21                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1073: Load A with literal 21. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta PY                               ; Store accumulator A into memory.
; Book line 1074: Store A into the byte at PY (logical player row). The register and CPU flags are
; unchanged.
    lda #0                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1075: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta JUMP                             ; Store accumulator A into memory.
; Book line 1076: Store A into the byte at JUMP (jump table position). The register and CPU flags are
; unchanged.
    sta ITEMS                            ; Store accumulator A into memory.
; Book line 1077: Store A into the byte at ITEMS (collected item count). The register and CPU flags
; are unchanged.
    sta FRAME                            ; Store accumulator A into memory.
; Book line 1078: Store A into the byte at FRAME. The register and CPU flags are unchanged.
    sta WIN                              ; Store accumulator A into memory.
; Book line 1079: Store A into the byte at WIN. The register and CPU flags are unchanged.
    sta GAME_STATE                       ; Store accumulator A into memory.
; Book line 1080: Store A into the byte at GAME_STATE (game state selector). The register and CPU
; flags are unchanged.
    sta CONVEY_TICK                      ; Store accumulator A into memory.
; Book line 1081: Store A into the byte at CONVEY_TICK. The register and CPU flags are unchanged.
    sta MOVE_CLOCK                       ; Store accumulator A into memory.
; Book line 1082: Store A into the byte at MOVE_CLOCK. The register and CPU flags are unchanged.
    lda #$11                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1083: Load A with literal $11 (decimal 17). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta PREV_JOY                         ; Store accumulator A into memory.
; Book line 1084: Store A into the byte at PREV_JOY. The register and CPU flags are unchanged.
    lda #27                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1085: Load A with literal 27. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EX                               ; Store accumulator A into memory.
; Book line 1086: Store A into the byte at EX. The register and CPU flags are unchanged.
    lda #13                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1087: Load A with literal 13. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EY                               ; Store accumulator A into memory.
; Book line 1088: Store A into the byte at EY. The register and CPU flags are unchanged.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1089: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EDIR                             ; Store accumulator A into memory.
; Book line 1090: Store A into the byte at EDIR. The register and CPU flags are unchanged.
    lda #6                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1091: Load A with literal 6. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EX2                              ; Store accumulator A into memory.
; Book line 1092: Store A into the byte at EX2. The register and CPU flags are unchanged.
    lda #9                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1093: Load A with literal 9. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EY2                              ; Store accumulator A into memory.
; Book line 1094: Store A into the byte at EY2. The register and CPU flags are unchanged.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1095: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EDIR2                            ; Store accumulator A into memory.
; Book line 1096: Store A into the byte at EDIR2. The register and CPU flags are unchanged.
    jsr init_sprites                     ; Call a subroutine; execution returns after its RTS.
; Book line 1097: Call init_sprites, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    jsr draw_status                      ; Call a subroutine; execution returns after its RTS.
; Book line 1098: Call draw_status, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    rts                                  ; Return from the current subroutine.
; Book line 1099: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Draw enemies as custom characters. Save the tile underneath so
; the platform / collectible is not erased when an enemy moves.
draw_enemies:
; Book line 1103: draw_enemies names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    rts                 ; enemies are now hardware sprites 1 and 2
; Book line 1104: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

erase_enemies:
; Book line 1106: erase_enemies names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    rts                                  ; Return from the current subroutine.
; Book line 1107: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; ROUTINE: move_enemies
; WHAT / WHY / HOW: Move enemy tile coordinates within their patrol boundaries.
; ============================================================================
move_enemies:
; Book line 1114: move_enemies names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    inc FRAME                            ; Add one to a memory byte.
; Book line 1115: Increase the byte at FRAME by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
    lda FRAME                            ; Load a value or memory byte into accumulator A.
; Book line 1116: Load A with the byte at FRAME. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    and #1                               ; Bitwise AND: keep only bits present in both values. Here # means an immediate number.
; Book line 1117: Keep only bits set in both A and literal 1. Save the result in A and update Z and N;
; carry is unchanged.
    bne move_second                      ; Branch if not equal/zero flag is clear.
; Book line 1118: Branch to move_second if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda EDIR                             ; Load a value or memory byte into accumulator A.
; Book line 1119: Load A with the byte at EDIR. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    beq enemy1_left                      ; Branch if equal/zero flag is set.
; Book line 1120: Branch to enemy1_left if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    inc EX                               ; Add one to a memory byte.
; Book line 1121: Increase the byte at EX by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
    lda EX                               ; Load a value or memory byte into accumulator A.
; Book line 1122: Load A with the byte at EX. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    cmp #33                              ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 1123: Compare A with literal 33 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    bcc move_second                      ; Branch if carry is clear (often unsigned less-than).
; Book line 1124: Branch to move_second if C is 0; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
    lda #0                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1125: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EDIR                             ; Store accumulator A into memory.
; Book line 1126: Store A into the byte at EDIR. The register and CPU flags are unchanged.
    jmp move_second                      ; Jump directly to another location.
; Book line 1127: Continue execution at move_second without saving a return address. Registers and
; flags are unchanged by the jump itself.
enemy1_left:
; Book line 1128: enemy1_left names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    dec EX                               ; Subtract one from a memory byte.
; Book line 1129: Decrease the byte at EX by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
    lda EX                               ; Load a value or memory byte into accumulator A.
; Book line 1130: Load A with the byte at EX. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    cmp #24                              ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 1131: Compare A with literal 24 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    bcs move_second                      ; Branch if carry is set (often unsigned >=).
; Book line 1132: Branch to move_second if C is 1; otherwise continue at the next instruction. Test
; the current flag, and leave all flags unchanged.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1133: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EDIR                             ; Store accumulator A into memory.
; Book line 1134: Store A into the byte at EDIR. The register and CPU flags are unchanged.
move_second:
; Book line 1135: move_second names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda FRAME                            ; Load a value or memory byte into accumulator A.
; Book line 1136: Load A with the byte at FRAME. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    and #3                               ; Bitwise AND: keep only bits present in both values. Here # means an immediate number.
; Book line 1137: Keep only bits set in both A and literal 3. Save the result in A and update Z and N;
; carry is unchanged.
    bne move_done                        ; Branch if not equal/zero flag is clear.
; Book line 1138: Branch to move_done if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda EDIR2                            ; Load a value or memory byte into accumulator A.
; Book line 1139: Load A with the byte at EDIR2. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    beq enemy2_left                      ; Branch if equal/zero flag is set.
; Book line 1140: Branch to enemy2_left if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    inc EX2                              ; Add one to a memory byte.
; Book line 1141: Increase the byte at EX2 by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
    lda EX2                              ; Load a value or memory byte into accumulator A.
; Book line 1142: Load A with the byte at EX2. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    cmp #16                              ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 1143: Compare A with literal 16 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    bcc move_done                        ; Branch if carry is clear (often unsigned less-than).
; Book line 1144: Branch to move_done if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
    lda #0                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1145: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EDIR2                            ; Store accumulator A into memory.
; Book line 1146: Store A into the byte at EDIR2. The register and CPU flags are unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 1147: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
enemy2_left:
; Book line 1148: enemy2_left names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    dec EX2                              ; Subtract one from a memory byte.
; Book line 1149: Decrease the byte at EX2 by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
    lda EX2                              ; Load a value or memory byte into accumulator A.
; Book line 1150: Load A with the byte at EX2. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    cmp #4                               ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 1151: Compare A with literal 4 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bcs move_done                        ; Branch if carry is set (often unsigned >=).
; Book line 1152: Branch to move_done if C is 1; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
    lda #1                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1153: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta EDIR2                            ; Store accumulator A into memory.
; Book line 1154: Store A into the byte at EDIR2. The register and CPU flags are unchanged.
move_done:
; Book line 1155: move_done names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    rts                                  ; Return from the current subroutine.
; Book line 1156: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; ROUTINE: check_enemy_hits
; WHAT / WHY / HOW: Check whether player and enemy tile positions overlap.
; ============================================================================
check_enemy_hits:
; Book line 1163: check_enemy_hits names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
    lda PX                               ; Load a value or memory byte into accumulator A.
; Book line 1164: Load A with the byte at PX (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    cmp EX                               ; Compare A with operand; sets flags, does not change A.
; Book line 1165: Compare A with the byte at EX without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    bne check_second_hit                 ; Branch if not equal/zero flag is clear.
; Book line 1166: Branch to check_second_hit if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
    lda PY                               ; Load a value or memory byte into accumulator A.
; Book line 1167: Load A with the byte at PY (logical player row). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    cmp EY                               ; Compare A with operand; sets flags, does not change A.
; Book line 1168: Compare A with the byte at EY without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    beq hit_enemy                        ; Branch if equal/zero flag is set.
; Book line 1169: Branch to hit_enemy if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
check_second_hit:
; Book line 1170: check_second_hit names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
    lda PX                               ; Load a value or memory byte into accumulator A.
; Book line 1171: Load A with the byte at PX (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    cmp EX2                              ; Compare A with operand; sets flags, does not change A.
; Book line 1172: Compare A with the byte at EX2 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    bne hit_done                         ; Branch if not equal/zero flag is clear.
; Book line 1173: Branch to hit_done if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda PY                               ; Load a value or memory byte into accumulator A.
; Book line 1174: Load A with the byte at PY (logical player row). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    cmp EY2                              ; Compare A with operand; sets flags, does not change A.
; Book line 1175: Compare A with the byte at EY2 without changing A. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    bne hit_done                         ; Branch if not equal/zero flag is clear.
; Book line 1176: Branch to hit_done if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
hit_enemy:
; Book line 1177: hit_enemy names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    jsr lose_life                        ; Call a subroutine; execution returns after its RTS.
; Book line 1178: Call lose_life, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
hit_done:
; Book line 1179: hit_done names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    rts                                  ; Return from the current subroutine.
; Book line 1180: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; HUD: digits are C64 screen codes $30..$39 for 0..9.

; ============================================================================
; ROUTINE: draw_status
; WHAT / WHY / HOW: Update the text HUD: items, lives and game state.
; ============================================================================
draw_status:
; Book line 1188: draw_status names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda #9                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1189: Load A with literal 9. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+0                   ; Store accumulator A into memory.
; Book line 1190: Store A into the byte at SCREEN+24*40+0. The register and CPU flags are unchanged.
    lda #20                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1191: Load A with literal 20. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+1                   ; Store accumulator A into memory.
; Book line 1192: Store A into the byte at SCREEN+24*40+1. The register and CPU flags are unchanged.
    lda #5                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1193: Load A with literal 5. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+2                   ; Store accumulator A into memory.
; Book line 1194: Store A into the byte at SCREEN+24*40+2. The register and CPU flags are unchanged.
    lda #13                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1195: Load A with literal 13. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+3                   ; Store accumulator A into memory.
; Book line 1196: Store A into the byte at SCREEN+24*40+3. The register and CPU flags are unchanged.
    lda #19                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1197: Load A with literal 19. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+4                   ; Store accumulator A into memory.
; Book line 1198: Store A into the byte at SCREEN+24*40+4. The register and CPU flags are unchanged.
    lda #12                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1199: Load A with literal 12. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+15                  ; Store accumulator A into memory.
; Book line 1200: Store A into the byte at SCREEN+24*40+15. The register and CPU flags are unchanged.
    lda #9                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1201: Load A with literal 9. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+16                  ; Store accumulator A into memory.
; Book line 1202: Store A into the byte at SCREEN+24*40+16. The register and CPU flags are unchanged.
    lda #22                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1203: Load A with literal 22. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+17                  ; Store accumulator A into memory.
; Book line 1204: Store A into the byte at SCREEN+24*40+17. The register and CPU flags are unchanged.
    lda #5                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1205: Load A with literal 5. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+18                  ; Store accumulator A into memory.
; Book line 1206: Store A into the byte at SCREEN+24*40+18. The register and CPU flags are unchanged.
    lda #19                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1207: Load A with literal 19. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+19                  ; Store accumulator A into memory.
; Book line 1208: Store A into the byte at SCREEN+24*40+19. The register and CPU flags are unchanged.
    lda ITEMS                            ; Load a value or memory byte into accumulator A.
; Book line 1209: Load A with the byte at ITEMS (collected item count). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    clc                                  ; Clear carry before an addition.
; Book line 1210: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
    adc #$30                             ; Add operand and carry to A. Here # means an immediate number.
; Book line 1211: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
    sta SCREEN+24*40+8                   ; Store accumulator A into memory.
; Book line 1212: Store A into the byte at SCREEN+24*40+8. The register and CPU flags are unchanged.
    lda LIVES                            ; Load a value or memory byte into accumulator A.
; Book line 1213: Load A with the byte at LIVES (remaining lives). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    clc                                  ; Clear carry before an addition.
; Book line 1214: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
    adc #$30                             ; Add operand and carry to A. Here # means an immediate number.
; Book line 1215: Add literal $30 (decimal 48) and incoming carry to A. Update C, Z, N and V according
; to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
    sta SCREEN+24*40+21                  ; Store accumulator A into memory.
; Book line 1216: Store A into the byte at SCREEN+24*40+21. The register and CPU flags are unchanged.
    lda GAME_STATE                       ; Load a value or memory byte into accumulator A.
; Book line 1217: Load A with the byte at GAME_STATE (game state selector). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    cmp #2                               ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 1218: Compare A with literal 2 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne check_win_message                ; Branch if not equal/zero flag is clear.
; Book line 1219: Branch to check_win_message if Z is 0 (nonzero or unequal); otherwise continue at
; the next instruction. Test the current flag, and leave all flags unchanged.
    lda #7             ; G
; Book line 1220: Load A with literal 7. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+27                  ; Store accumulator A into memory.
; Book line 1221: Store A into the byte at SCREEN+24*40+27. The register and CPU flags are unchanged.
    lda #1             ; A
; Book line 1222: Load A with literal 1. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+28                  ; Store accumulator A into memory.
; Book line 1223: Store A into the byte at SCREEN+24*40+28. The register and CPU flags are unchanged.
    lda #13            ; M
; Book line 1224: Load A with literal 13. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+29                  ; Store accumulator A into memory.
; Book line 1225: Store A into the byte at SCREEN+24*40+29. The register and CPU flags are unchanged.
    lda #5             ; E
; Book line 1226: Load A with literal 5. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+30                  ; Store accumulator A into memory.
; Book line 1227: Store A into the byte at SCREEN+24*40+30. The register and CPU flags are unchanged.
    lda #32                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1228: Load A with literal 32. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+31                  ; Store accumulator A into memory.
; Book line 1229: Store A into the byte at SCREEN+24*40+31. The register and CPU flags are unchanged.
    lda #15            ; O
; Book line 1230: Load A with literal 15. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+32                  ; Store accumulator A into memory.
; Book line 1231: Store A into the byte at SCREEN+24*40+32. The register and CPU flags are unchanged.
    lda #22            ; V
; Book line 1232: Load A with literal 22. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+33                  ; Store accumulator A into memory.
; Book line 1233: Store A into the byte at SCREEN+24*40+33. The register and CPU flags are unchanged.
    lda #5             ; E
; Book line 1234: Load A with literal 5. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+34                  ; Store accumulator A into memory.
; Book line 1235: Store A into the byte at SCREEN+24*40+34. The register and CPU flags are unchanged.
    lda #18            ; R
; Book line 1236: Load A with literal 18. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SCREEN+24*40+35                  ; Store accumulator A into memory.
; Book line 1237: Store A into the byte at SCREEN+24*40+35. The register and CPU flags are unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 1238: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
check_win_message:
; Book line 1239: check_win_message names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
    lda WIN                              ; Load a value or memory byte into accumulator A.
; Book line 1240: Load A with the byte at WIN. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    beq status_done                      ; Branch if equal/zero flag is set.
; Book line 1241: Branch to status_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda #$17  ; W
; Book line 1242: Load A with literal $17 (decimal 23). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta SCREEN+24*40+30                  ; Store accumulator A into memory.
; Book line 1243: Store A into the byte at SCREEN+24*40+30. The register and CPU flags are unchanged.
    lda #$09  ; I
; Book line 1244: Load A with literal $09 (decimal 9). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta SCREEN+24*40+31                  ; Store accumulator A into memory.
; Book line 1245: Store A into the byte at SCREEN+24*40+31. The register and CPU flags are unchanged.
    lda #$0e  ; N
; Book line 1246: Load A with literal $0e (decimal 14). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta SCREEN+24*40+32                  ; Store accumulator A into memory.
; Book line 1247: Store A into the byte at SCREEN+24*40+32. The register and CPU flags are unchanged.
status_done:
; Book line 1248: status_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    rts                                  ; Return from the current subroutine.
; Book line 1249: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ================================================================
; SID soundtrack: original, extended C64 arrangement inspired by the
; public-domain melody from Grieg's "In the Hall of the Mountain
; King". This is a simplified original SID arrangement, not a recording.
; SID voice 1 ($d400-$d406) plays the melody, voice 2 ($d407-$d40d)
; a steady low accompaniment, voice 3 ($d40e-$d414) sound effects.
; Frequency values assume a PAL C64 clock (~985248 Hz).
; ================================================================

; ============================================================================
; ROUTINE: init_sound
; WHAT / WHY / HOW: Configure SID voices, waveforms and volume.
; ============================================================================
init_sound:
; Book line 1265: init_sound names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    lda #$0f                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1266: Load A with literal $0f (decimal 15). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d418          ; master volume
; Book line 1267: Store A into the byte at $d418 (SID volume and filter mode). The register and CPU
; flags are unchanged.
    lda #$00                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1268: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta MUSIC_STEP                       ; Store accumulator A into memory.
; Book line 1269: Store A into the byte at MUSIC_STEP. The register and CPU flags are unchanged.
    sta MUSIC_WAIT                       ; Store accumulator A into memory.
; Book line 1270: Store A into the byte at MUSIC_WAIT. The register and CPU flags are unchanged.
    sta SFX_WAIT                         ; Store accumulator A into memory.
; Book line 1271: Store A into the byte at SFX_WAIT. The register and CPU flags are unchanged.
    sta $d404                            ; Store accumulator A into memory. Target: SID voice 1 waveform/gate.
; Book line 1272: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
    sta $d40b                            ; Store accumulator A into memory.
; Book line 1273: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
    sta $d412                            ; Store accumulator A into memory. Target: SID voice 3 waveform/gate.
; Book line 1274: Store A into the byte at $d412 (SID voice 3 waveform and gate). The register and CPU
; flags are unchanged.
    lda #$09                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1275: Load A with literal $09 (decimal 9). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d405          ; voice 1 attack/decay
; Book line 1276: Store A into the byte at $d405 (SID voice 1 attack and decay). The register and CPU
; flags are unchanged.
    lda #$87                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1277: Load A with literal $87 (decimal 135). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d406          ; voice 1 sustain/release
; Book line 1278: Store A into the byte at $d406 (SID voice 1 sustain and release). The register and
; CPU flags are unchanged.
    lda #$19                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1279: Load A with literal $19 (decimal 25). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d40c          ; voice 2 attack/decay
; Book line 1280: Store A into the byte at $d40c (SID voice 2 attack and decay). The register and CPU
; flags are unchanged.
    lda #$65                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1281: Load A with literal $65 (decimal 101). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d40d          ; voice 2 sustain/release
; Book line 1282: Store A into the byte at $d40d (SID voice 2 sustain and release). The register and
; CPU flags are unchanged.
    lda #$00                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1283: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d402          ; no pulse width needed (triangle)
; Book line 1284: Store A into the byte at $d402 (SID voice 1 pulse width low). The register and CPU
; flags are unchanged.
    sta $d409                            ; Store accumulator A into memory.
; Book line 1285: Store A into the byte at $d409 (SID voice 2 pulse width low). The register and CPU
; flags are unchanged.
    lda #$11                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1286: Load A with literal $11 (decimal 17). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d40b          ; voice 2 triangle + gate
; Book line 1287: Store A into the byte at $d40b (SID voice 2 waveform and gate). The register and CPU
; flags are unchanged.
    lda #$8c                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1288: Load A with literal $8c (decimal 140). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d407          ; low C3 approximate
; Book line 1289: Store A into the byte at $d407 (SID voice 2 frequency low). The register and CPU
; flags are unchanged.
    lda #$11                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1290: Load A with literal $11 (decimal 17). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d408                            ; Store accumulator A into memory.
; Book line 1291: Store A into the byte at $d408 (SID voice 2 frequency high). The register and CPU
; flags are unchanged.
    lda #$09                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1292: Load A with literal $09 (decimal 9). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d413          ; effect voice ADSR
; Book line 1293: Store A into the byte at $d413 (SID voice 3 attack and decay). The register and CPU
; flags are unchanged.
    lda #$88                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1294: Load A with literal $88 (decimal 136). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d414                            ; Store accumulator A into memory.
; Book line 1295: Store A into the byte at $d414 (SID voice 3 sustain and release). The register and
; CPU flags are unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 1296: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; ROUTINE: music_tick
; WHAT / WHY / HOW: Play the next melody note when the previous note duration expires.
; ============================================================================
music_tick:
; Book line 1303: music_tick names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    lda MUSIC_WAIT                       ; Load a value or memory byte into accumulator A.
; Book line 1304: Load A with the byte at MUSIC_WAIT. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    beq music_next                       ; Branch if equal/zero flag is set.
; Book line 1305: Branch to music_next if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    dec MUSIC_WAIT                       ; Subtract one from a memory byte.
; Book line 1306: Decrease the byte at MUSIC_WAIT by one with 8-bit wraparound. Update Z and N; carry
; is unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 1307: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
music_next:
; Book line 1308: music_next names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    ldx MUSIC_STEP                       ; Load a value into index register X.
; Book line 1309: Load X with the byte at MUSIC_STEP. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    lda melody_lo,x                      ; Load a value or memory byte into accumulator A.
; Book line 1310: Load A with the byte at melody_lo plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
    sta $d400                            ; Store accumulator A into memory. Target: SID voice 1 frequency low.
; Book line 1311: Store A into the byte at $d400 (SID voice 1 frequency low). The register and CPU
; flags are unchanged.
    lda melody_hi,x                      ; Load a value or memory byte into accumulator A.
; Book line 1312: Load A with the byte at melody_hi plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
    sta $d401                            ; Store accumulator A into memory. Target: SID voice 1 frequency high.
; Book line 1313: Store A into the byte at $d401 (SID voice 1 frequency high). The register and CPU
; flags are unchanged.
    lda #$10                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1314: Load A with literal $10 (decimal 16). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d404          ; gate off, then on: retrigger note
; Book line 1315: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
    lda melody_hi,x                      ; Load a value or memory byte into accumulator A.
; Book line 1316: Load A with the byte at melody_hi plus index X. Z records a zero value; N copies bit
; 7. Carry is unchanged.
    beq music_rest                       ; Branch if equal/zero flag is set.
; Book line 1317: Branch to music_rest if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda #$11                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1318: Load A with literal $11 (decimal 17). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d404                            ; Store accumulator A into memory. Target: SID voice 1 waveform/gate.
; Book line 1319: Store A into the byte at $d404 (SID voice 1 waveform and gate). The register and CPU
; flags are unchanged.
music_rest:
; Book line 1320: music_rest names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    lda melody_duration,x                ; Load a value or memory byte into accumulator A.
; Book line 1321: Load A with the byte at melody_duration plus index X. Z records a zero value; N
; copies bit 7. Carry is unchanged.
    sta MUSIC_WAIT                       ; Store accumulator A into memory.
; Book line 1322: Store A into the byte at MUSIC_WAIT. The register and CPU flags are unchanged.
    inx                                  ; Increase X by one.
; Book line 1323: Increase X by one with 8-bit wraparound. Update Z and N; carry is unchanged.
    cpx #96                              ; Compare X with operand. Here # means an immediate number.
; Book line 1324: Compare X with literal 96 without changing X. Z means equal, C means unsigned
; greater or equal, and N is the subtraction result bit 7.
    bcc music_keep                       ; Branch if carry is clear (often unsigned less-than).
; Book line 1325: Branch to music_keep if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
    ldx #0                               ; Load a value into index register X. Here # means an immediate number.
; Book line 1326: Load X with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
music_keep:
; Book line 1327: music_keep names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    stx MUSIC_STEP                       ; Store X into memory.
; Book line 1328: Store X into the byte at MUSIC_STEP. The register and CPU flags are unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 1329: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; A = effect kind (1 key, 2 death, 3 jump).

; ============================================================================
; ROUTINE: start_effect
; WHAT / WHY / HOW: Choose a short SID sound effect (collect, death or jump).
; ============================================================================
start_effect:
; Book line 1337: start_effect names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    sta SFX_KIND                         ; Store accumulator A into memory.
; Book line 1338: Store A into the byte at SFX_KIND. The register and CPU flags are unchanged.
    lda #10                              ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1339: Load A with literal 10. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta SFX_WAIT                         ; Store accumulator A into memory.
; Book line 1340: Store A into the byte at SFX_WAIT. The register and CPU flags are unchanged.
    lda #$00                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1341: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d412                            ; Store accumulator A into memory. Target: SID voice 3 waveform/gate.
; Book line 1342: Store A into the byte at $d412 (SID voice 3 waveform and gate). The register and CPU
; flags are unchanged.
    lda SFX_KIND                         ; Load a value or memory byte into accumulator A.
; Book line 1343: Load A with the byte at SFX_KIND. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    cmp #1                               ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 1344: Compare A with literal 1 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne effect_death                     ; Branch if not equal/zero flag is clear.
; Book line 1345: Branch to effect_death if Z is 0 (nonzero or unequal); otherwise continue at the
; next instruction. Test the current flag, and leave all flags unchanged.
    lda #$50                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1346: Load A with literal $50 (decimal 80). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d40e                            ; Store accumulator A into memory.
; Book line 1347: Store A into the byte at $d40e (SID voice 3 frequency low). The register and CPU
; flags are unchanged.
    lda #$42                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1348: Load A with literal $42 (decimal 66). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d40f                            ; Store accumulator A into memory.
; Book line 1349: Store A into the byte at $d40f (SID voice 3 frequency high). The register and CPU
; flags are unchanged.
    jmp effect_gate                      ; Jump directly to another location.
; Book line 1350: Continue execution at effect_gate without saving a return address. Registers and
; flags are unchanged by the jump itself.
effect_death:
; Book line 1351: effect_death names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    cmp #2                               ; Compare A with operand; sets flags, does not change A. Here # means an immediate number.
; Book line 1352: Compare A with literal 2 without changing A. Z means equal, C means unsigned greater
; or equal, and N is the subtraction result bit 7.
    bne effect_jump                      ; Branch if not equal/zero flag is clear.
; Book line 1353: Branch to effect_jump if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda #$30                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1354: Load A with literal $30 (decimal 48). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d40e                            ; Store accumulator A into memory.
; Book line 1355: Store A into the byte at $d40e (SID voice 3 frequency low). The register and CPU
; flags are unchanged.
    lda #$08                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1356: Load A with literal $08 (decimal 8). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d40f                            ; Store accumulator A into memory.
; Book line 1357: Store A into the byte at $d40f (SID voice 3 frequency high). The register and CPU
; flags are unchanged.
    jmp effect_gate                      ; Jump directly to another location.
; Book line 1358: Continue execution at effect_gate without saving a return address. Registers and
; flags are unchanged by the jump itself.
effect_jump:
; Book line 1359: effect_jump names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda #$00                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1360: Load A with literal $00 (decimal 0). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d40e                            ; Store accumulator A into memory.
; Book line 1361: Store A into the byte at $d40e (SID voice 3 frequency low). The register and CPU
; flags are unchanged.
    lda #$30                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1362: Load A with literal $30 (decimal 48). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d40f                            ; Store accumulator A into memory.
; Book line 1363: Store A into the byte at $d40f (SID voice 3 frequency high). The register and CPU
; flags are unchanged.
effect_gate:
; Book line 1364: effect_gate names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda #$81            ; noise waveform + gate
; Book line 1365: Load A with literal $81 (decimal 129). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d412                            ; Store accumulator A into memory. Target: SID voice 3 waveform/gate.
; Book line 1366: Store A into the byte at $d412 (SID voice 3 waveform and gate). The register and CPU
; flags are unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 1367: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; ROUTINE: effects_tick
; WHAT / WHY / HOW: Count down the sound-effect timer and release its SID voice.
; ============================================================================
effects_tick:
; Book line 1374: effects_tick names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda SFX_WAIT                         ; Load a value or memory byte into accumulator A.
; Book line 1375: Load A with the byte at SFX_WAIT. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    beq effect_done                      ; Branch if equal/zero flag is set.
; Book line 1376: Branch to effect_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    dec SFX_WAIT                         ; Subtract one from a memory byte.
; Book line 1377: Decrease the byte at SFX_WAIT by one with 8-bit wraparound. Update Z and N; carry is
; unchanged.
    bne effect_done                      ; Branch if not equal/zero flag is clear.
; Book line 1378: Branch to effect_done if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda #$80            ; release noise voice
; Book line 1379: Load A with literal $80 (decimal 128). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d412                            ; Store accumulator A into memory. Target: SID voice 3 waveform/gate.
; Book line 1380: Store A into the byte at $d412 (SID voice 3 waveform and gate). The register and CPU
; flags are unchanged.
effect_done:
; Book line 1381: effect_done names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    rts                                  ; Return from the current subroutine.
; Book line 1382: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; The opening theme of Grieg's public-domain In the Hall of the Mountain King.
; Original SID programming: single melody voice and a sustained bass voice.
; Note frequencies calculated for PAL 985248 Hz, with 96 steps per loop.

; ============================================================================
; ROUTINE: melody_lo
; WHAT / WHY / HOW: Low bytes of SID frequency values for the tune.
; ============================================================================
melody_lo:
; Book line 1392: melody_lo names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    !byte $6d,$70,$89,$ed,$9c,$89,$9c,$ed,$70,$ed,$6d,$70
; Book line 1393: Emit 12 bytes in the shown order for melody_lo. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $89,$ed,$9c,$89,$6d,$70,$89,$ed,$9c,$89,$9c,$ed
; Book line 1394: Emit 12 bytes in the shown order for melody_lo. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $70,$ed,$6d,$70,$89,$ed,$9c,$89,$a2,$6d,$70,$89
; Book line 1395: Emit 12 bytes in the shown order for melody_lo. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $ed,$70,$ed,$89,$6d,$89,$a2,$6d,$70,$89,$ed,$70
; Book line 1396: Emit 12 bytes in the shown order for melody_lo. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $a2,$6d,$70,$89,$ed,$70,$ed,$89,$6d,$89,$a2,$6d
; Book line 1397: Emit 12 bytes in the shown order for melody_lo. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $70,$89,$ed,$70,$9c,$13,$45,$da,$45,$13,$9c,$ed
; Book line 1398: Emit 12 bytes in the shown order for melody_lo. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $89,$ed,$9c,$13,$45,$9c,$ed,$89,$6d,$70,$89,$ed
; Book line 1399: Emit 12 bytes in the shown order for melody_lo. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $9c,$89,$9c,$ed,$70,$ed,$6d,$70,$89,$ed,$9c,$89
; Book line 1400: Emit 12 bytes in the shown order for melody_lo. These are data or encoded loader
; bytes, not instructions to execute.

; ============================================================================
; ROUTINE: melody_hi
; WHAT / WHY / HOW: High bytes of SID frequency values for the tune.
; ============================================================================
melody_hi:
; Book line 1406: melody_hi names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    !byte $10,$12,$13,$15,$18,$13,$18,$15,$12,$15,$10,$12
; Book line 1407: Emit 12 bytes in the shown order for melody_hi. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $13,$15,$18,$13,$10,$12,$13,$15,$18,$13,$18,$15
; Book line 1408: Emit 12 bytes in the shown order for melody_hi. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $12,$15,$10,$12,$13,$15,$18,$13,$0e,$10,$12,$13
; Book line 1409: Emit 12 bytes in the shown order for melody_hi. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $15,$12,$15,$13,$10,$13,$0e,$10,$12,$13,$15,$12
; Book line 1410: Emit 12 bytes in the shown order for melody_hi. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $0e,$10,$12,$13,$15,$12,$15,$13,$10,$13,$0e,$10
; Book line 1411: Emit 12 bytes in the shown order for melody_hi. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $12,$13,$15,$12,$18,$1a,$1d,$20,$1d,$1a,$18,$15
; Book line 1412: Emit 12 bytes in the shown order for melody_hi. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $13,$15,$18,$1a,$1d,$18,$15,$13,$10,$12,$13,$15
; Book line 1413: Emit 12 bytes in the shown order for melody_hi. These are data or encoded loader
; bytes, not instructions to execute.
    !byte $18,$13,$18,$15,$12,$15,$10,$12,$13,$15,$18,$13
; Book line 1414: Emit 12 bytes in the shown order for melody_hi. These are data or encoded loader
; bytes, not instructions to execute.

; ============================================================================
; ROUTINE: melody_duration
; WHAT / WHY / HOW: Number of frames to hold each note.
; ============================================================================
melody_duration:
; Book line 1420: melody_duration names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    !byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
; Book line 1421: Emit 12 bytes in the shown order for melody_duration. These are data or encoded
; loader bytes, not instructions to execute.
    !byte $07,$07,$0a,$10,$07,$07,$07,$07,$07,$07,$07,$07
; Book line 1422: Emit 12 bytes in the shown order for melody_duration. These are data or encoded
; loader bytes, not instructions to execute.
    !byte $07,$07,$07,$07,$07,$07,$0a,$10,$07,$07,$07,$07
; Book line 1423: Emit 12 bytes in the shown order for melody_duration. These are data or encoded
; loader bytes, not instructions to execute.
    !byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0a,$10
; Book line 1424: Emit 12 bytes in the shown order for melody_duration. These are data or encoded
; loader bytes, not instructions to execute.
    !byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
; Book line 1425: Emit 12 bytes in the shown order for melody_duration. These are data or encoded
; loader bytes, not instructions to execute.
    !byte $07,$07,$0a,$10,$07,$07,$07,$07,$07,$07,$07,$07
; Book line 1426: Emit 12 bytes in the shown order for melody_duration. These are data or encoded
; loader bytes, not instructions to execute.
    !byte $07,$07,$07,$07,$07,$07,$0a,$10,$07,$07,$07,$07
; Book line 1427: Emit 12 bytes in the shown order for melody_duration. These are data or encoded
; loader bytes, not instructions to execute.
    !byte $07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0a,$10
; Book line 1428: Emit 12 bytes in the shown order for melody_duration. These are data or encoded
; loader bytes, not instructions to execute.


; Five upward tile steps let Willy climb from row 21 to row 17,
; then row 13, row 9, and row 5.  The original 3-step arc could
; never clear a four-tile ledge. Landing checks prevent falling through.
jump_curve:
; Book line 1434: jump_curve names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
    !byte $ff,$ff,$ff,$ff,$ff,$00,$00,$01,$01,$01,$01,$01,$80
; Book line 1435: Emit 13 bytes in the shown order for jump_curve. These are data or encoded loader
; bytes, not instructions to execute.
; ================================================================
; ORIGINAL 24x21 PIXEL SPRITES -- not copied from Manic Miner.
; Player is now the same visible height as the enemies, with orange helmet,
; white face, blue jacket, orange boots and two walking frames.
; VIC-II sprite X = 24 + column*8, Y = 41 + row*8.
; Sprite art occupies rows 5..16, so feet end at row bottom,
; exactly one pixel above the platform on the following tile row.
; This code moves each sprite towards its logical tile position by
; 2 pixels per PAL frame, without changing existing tile collisions.
; ================================================================

; ============================================================================
; ROUTINE: init_sprites
; WHAT / WHY / HOW: Configure VIC-II sprite positions, colours, pointers and mode.
; ============================================================================
init_sprites:
; Book line 1451: init_sprites names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    ; Three native VIC-II multicolour sprites, no overlapping layers.
    ; This eliminates the priority/flicker problems of stacked sprites.
    lda #$07                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1454: Load A with literal $07 (decimal 7). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d015                            ; Store accumulator A into memory. Target: VIC-II sprite enable bits.
; Book line 1455: Store A into the byte at $d015 (VIC sprite enable bits). The register and CPU flags
; are unchanged.
    sta $d01c                            ; Store accumulator A into memory.
; Book line 1456: Store A into the byte at $d01c (VIC sprite multicolour bits). The register and CPU
; flags are unchanged.
    lda #0                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1457: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta $d017                            ; Store accumulator A into memory.
; Book line 1458: Store A into the byte at $d017 (VIC sprite height expansion). The register and CPU
; flags are unchanged.
    sta $d01d                            ; Store accumulator A into memory.
; Book line 1459: Store A into the byte at $d01d (VIC sprite width expansion). The register and CPU
; flags are unchanged.
    lda #$01          ; shared colour 1: white highlights
; Book line 1460: Load A with literal $01 (decimal 1). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d025                            ; Store accumulator A into memory.
; Book line 1461: Store A into the byte at $d025 (shared sprite multicolour 1). The register and CPU
; flags are unchanged.
    lda #$06          ; shared colour 2: blue clothing/shadows
; Book line 1462: Load A with literal $06 (decimal 6). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d026                            ; Store accumulator A into memory.
; Book line 1463: Store A into the byte at $d026 (shared sprite multicolour 2). The register and CPU
; flags are unchanged.
    lda #$08          ; player unique colour: ORANGE, distinct from pink/green enemies
; Book line 1464: Load A with literal $08 (decimal 8). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d027                            ; Store accumulator A into memory.
; Book line 1465: Store A into the byte at $d027 (sprite 0 colour). The register and CPU flags are
; unchanged.
    lda #$0a          ; enemy one unique colour: pink
; Book line 1466: Load A with literal $0a (decimal 10). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d028                            ; Store accumulator A into memory.
; Book line 1467: Store A into the byte at $d028 (sprite 1 colour). The register and CPU flags are
; unchanged.
    lda #$05          ; enemy two unique colour: green
; Book line 1468: Load A with literal $05 (decimal 5). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $d029                            ; Store accumulator A into memory.
; Book line 1469: Store A into the byte at $d029 (sprite 2 colour). The register and CPU flags are
; unchanged.
    lda #$8c          ; new frames at $2300
; Book line 1470: Load A with literal $8c (decimal 140). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $07f8                            ; Store accumulator A into memory.
; Book line 1471: Store A into the byte at $07f8 (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
    lda #$8e                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1472: Load A with literal $8e (decimal 142). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $07f9                            ; Store accumulator A into memory.
; Book line 1473: Store A into the byte at $07f9 (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
    sta $07fa                            ; Store accumulator A into memory.
; Book line 1474: Store A into the byte at $07fa (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
    ; Seed sprite positions at their actual starting tile coordinates.
    lda PX                               ; Load a value or memory byte into accumulator A.
; Book line 1476: Load A with the byte at PX (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    jsr column_to_target                 ; Call a subroutine; execution returns after its RTS.
; Book line 1477: Call column_to_target, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
    lda TARGETLO                         ; Load a value or memory byte into accumulator A.
; Book line 1478: Load A with the byte at TARGETLO. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SPX                              ; Store accumulator A into memory.
; Book line 1479: Store A into the byte at SPX (visible player X low byte). The register and CPU flags
; are unchanged.
    lda TARGETHI                         ; Load a value or memory byte into accumulator A.
; Book line 1480: Load A with the byte at TARGETHI. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SPXH                             ; Store accumulator A into memory.
; Book line 1481: Store A into the byte at SPXH (visible player X high byte). The register and CPU
; flags are unchanged.
    lda PY                               ; Load a value or memory byte into accumulator A.
; Book line 1482: Load A with the byte at PY (logical player row). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    jsr row_to_target                    ; Call a subroutine; execution returns after its RTS.
; Book line 1483: Call row_to_target, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    sta SPY                              ; Store accumulator A into memory.
; Book line 1484: Store A into the byte at SPY (visible player Y). The register and CPU flags are
; unchanged.
    lda EX                               ; Load a value or memory byte into accumulator A.
; Book line 1485: Load A with the byte at EX. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    jsr column_to_target                 ; Call a subroutine; execution returns after its RTS.
; Book line 1486: Call column_to_target, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
    lda TARGETLO                         ; Load a value or memory byte into accumulator A.
; Book line 1487: Load A with the byte at TARGETLO. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta E1X                              ; Store accumulator A into memory.
; Book line 1488: Store A into the byte at E1X. The register and CPU flags are unchanged.
    lda TARGETHI                         ; Load a value or memory byte into accumulator A.
; Book line 1489: Load A with the byte at TARGETHI. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta E1XH                             ; Store accumulator A into memory.
; Book line 1490: Store A into the byte at E1XH. The register and CPU flags are unchanged.
    lda EY                               ; Load a value or memory byte into accumulator A.
; Book line 1491: Load A with the byte at EY. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    jsr row_to_target                    ; Call a subroutine; execution returns after its RTS.
; Book line 1492: Call row_to_target, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    sta E1Y                              ; Store accumulator A into memory.
; Book line 1493: Store A into the byte at E1Y. The register and CPU flags are unchanged.
    lda EX2                              ; Load a value or memory byte into accumulator A.
; Book line 1494: Load A with the byte at EX2. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    jsr column_to_target                 ; Call a subroutine; execution returns after its RTS.
; Book line 1495: Call column_to_target, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
    lda TARGETLO                         ; Load a value or memory byte into accumulator A.
; Book line 1496: Load A with the byte at TARGETLO. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta E2X                              ; Store accumulator A into memory.
; Book line 1497: Store A into the byte at E2X. The register and CPU flags are unchanged.
    lda TARGETHI                         ; Load a value or memory byte into accumulator A.
; Book line 1498: Load A with the byte at TARGETHI. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta E2XH                             ; Store accumulator A into memory.
; Book line 1499: Store A into the byte at E2XH. The register and CPU flags are unchanged.
    lda EY2                              ; Load a value or memory byte into accumulator A.
; Book line 1500: Load A with the byte at EY2. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    jsr row_to_target                    ; Call a subroutine; execution returns after its RTS.
; Book line 1501: Call row_to_target, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    sta E2Y                              ; Store accumulator A into memory.
; Book line 1502: Store A into the byte at E2Y. The register and CPU flags are unchanged.
    jmp write_sprites                    ; Jump directly to another location.
; Book line 1503: Continue execution at write_sprites without saving a return address. Registers and
; flags are unchanged by the jump itself.

; A = column (0..39), output TARGETHI:TARGETLO = 24 + A*8.
column_to_target:
; Book line 1506: column_to_target names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
    sta TARGETLO                         ; Store accumulator A into memory.
; Book line 1507: Store A into the byte at TARGETLO. The register and CPU flags are unchanged.
    lda #0                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1508: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
    sta TARGETHI                         ; Store accumulator A into memory.
; Book line 1509: Store A into the byte at TARGETHI. The register and CPU flags are unchanged.
    asl TARGETLO                         ; Shift bits left; doubles an unsigned value, with carry.
; Book line 1510: Shift the byte at TARGETLO left one bit, insert 0 at bit 0 and move old bit 7 to C.
; Update Z and N from the result.
    rol TARGETHI                         ; Rotate bits left through the carry flag.
; Book line 1511: Rotate the byte at TARGETHI left through carry: old C enters bit 0 and old bit 7
; becomes C. Update Z and N from the result.
    asl TARGETLO                         ; Shift bits left; doubles an unsigned value, with carry.
; Book line 1512: Shift the byte at TARGETLO left one bit, insert 0 at bit 0 and move old bit 7 to C.
; Update Z and N from the result.
    rol TARGETHI                         ; Rotate bits left through the carry flag.
; Book line 1513: Rotate the byte at TARGETHI left through carry: old C enters bit 0 and old bit 7
; becomes C. Update Z and N from the result.
    asl TARGETLO                         ; Shift bits left; doubles an unsigned value, with carry.
; Book line 1514: Shift the byte at TARGETLO left one bit, insert 0 at bit 0 and move old bit 7 to C.
; Update Z and N from the result.
    rol TARGETHI                         ; Rotate bits left through the carry flag.
; Book line 1515: Rotate the byte at TARGETHI left through carry: old C enters bit 0 and old bit 7
; becomes C. Update Z and N from the result.
    clc                                  ; Clear carry before an addition.
; Book line 1516: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
    lda TARGETLO                         ; Load a value or memory byte into accumulator A.
; Book line 1517: Load A with the byte at TARGETLO. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    adc #24            ; sprite pixels start at the left edge of the tile
; Book line 1518: Add literal 24 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
    sta TARGETLO                         ; Store accumulator A into memory.
; Book line 1519: Store A into the byte at TARGETLO. The register and CPU flags are unchanged.
    lda TARGETHI                         ; Load a value or memory byte into accumulator A.
; Book line 1520: Load A with the byte at TARGETHI. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    adc #0                               ; Add operand and carry to A. Here # means an immediate number.
; Book line 1521: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
    sta TARGETHI                         ; Store accumulator A into memory.
; Book line 1522: Store A into the byte at TARGETHI. The register and CPU flags are unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 1523: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; A = row, output A = 41 + A*8 (account for sprite blank top).
row_to_target:
; Book line 1526: row_to_target names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    asl                                  ; Shift bits left; doubles an unsigned value, with carry.
; Book line 1527: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
    asl                                  ; Shift bits left; doubles an unsigned value, with carry.
; Book line 1528: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
    asl                                  ; Shift bits left; doubles an unsigned value, with carry.
; Book line 1529: Shift A left one bit, insert 0 at bit 0 and move old bit 7 to C. Update Z and N from
; the result.
    clc                                  ; Clear carry before an addition.
; Book line 1530: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
    adc #41            ; bottom visible pixel rests just ABOVE supporting tile
; Book line 1531: Add literal 41 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
    rts                                  ; Return from the current subroutine.
; Book line 1532: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; Move 16-bit sprite coordinate at SPRLO/SPRHI towards TARGET.
; The caller copies current X into SPRLO/SPRHI and saves it back.
move_x_toward:
; Book line 1536: move_x_toward names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda SPRHI                            ; Load a value or memory byte into accumulator A.
; Book line 1537: Load A with the byte at SPRHI. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    cmp TARGETHI                         ; Compare A with operand; sets flags, does not change A.
; Book line 1538: Compare A with the byte at TARGETHI without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
    bcc x_plus                           ; Branch if carry is clear (often unsigned less-than).
; Book line 1539: Branch to x_plus if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
    bne x_minus                          ; Branch if not equal/zero flag is clear.
; Book line 1540: Branch to x_minus if Z is 0 (nonzero or unequal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda SPRLO                            ; Load a value or memory byte into accumulator A.
; Book line 1541: Load A with the byte at SPRLO. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    cmp TARGETLO                         ; Compare A with operand; sets flags, does not change A.
; Book line 1542: Compare A with the byte at TARGETLO without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
    bcc x_plus                           ; Branch if carry is clear (often unsigned less-than).
; Book line 1543: Branch to x_plus if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
    beq x_done                           ; Branch if equal/zero flag is set.
; Book line 1544: Branch to x_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
x_minus:
; Book line 1545: x_minus names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    sec                                  ; Set carry before subtraction.
; Book line 1546: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
    lda SPRLO                            ; Load a value or memory byte into accumulator A.
; Book line 1547: Load A with the byte at SPRLO. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sbc #2                               ; Subtract operand and inverse carry from A. Here # means an immediate number.
; Book line 1548: Subtract literal 2 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
    sta SPRLO                            ; Store accumulator A into memory.
; Book line 1549: Store A into the byte at SPRLO. The register and CPU flags are unchanged.
    lda SPRHI                            ; Load a value or memory byte into accumulator A.
; Book line 1550: Load A with the byte at SPRHI. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sbc #0                               ; Subtract operand and inverse carry from A. Here # means an immediate number.
; Book line 1551: Subtract literal 0 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
    sta SPRHI                            ; Store accumulator A into memory.
; Book line 1552: Store A into the byte at SPRHI. The register and CPU flags are unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 1553: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
x_plus:
; Book line 1554: x_plus names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    clc                                  ; Clear carry before an addition.
; Book line 1555: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
    lda SPRLO                            ; Load a value or memory byte into accumulator A.
; Book line 1556: Load A with the byte at SPRLO. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    adc #2                               ; Add operand and carry to A. Here # means an immediate number.
; Book line 1557: Add literal 2 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
    sta SPRLO                            ; Store accumulator A into memory.
; Book line 1558: Store A into the byte at SPRLO. The register and CPU flags are unchanged.
    lda SPRHI                            ; Load a value or memory byte into accumulator A.
; Book line 1559: Load A with the byte at SPRHI. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    adc #0                               ; Add operand and carry to A. Here # means an immediate number.
; Book line 1560: Add literal 0 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
    sta SPRHI                            ; Store accumulator A into memory.
; Book line 1561: Store A into the byte at SPRHI. The register and CPU flags are unchanged.
x_done:
; Book line 1562: x_done names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    rts                                  ; Return from the current subroutine.
; Book line 1563: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.

; A = target Y, X = current Y: approach by 2 pixels.
move_y_toward:
; Book line 1566: move_y_toward names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    sta TARGETLO                         ; Store accumulator A into memory.
; Book line 1567: Store A into the byte at TARGETLO. The register and CPU flags are unchanged.
    txa                                  ; Copy X into A.
; Book line 1568: Copy X to A; leave X unchanged. Update Z and N from the copied value; carry is
; unchanged.
    cmp TARGETLO                         ; Compare A with operand; sets flags, does not change A.
; Book line 1569: Compare A with the byte at TARGETLO without changing A. Z means equal, C means
; unsigned greater or equal, and N is the subtraction result bit 7.
    beq y_done                           ; Branch if equal/zero flag is set.
; Book line 1570: Branch to y_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    bcc y_plus                           ; Branch if carry is clear (often unsigned less-than).
; Book line 1571: Branch to y_plus if C is 0; otherwise continue at the next instruction. Test the
; current flag, and leave all flags unchanged.
    sec                                  ; Set carry before subtraction.
; Book line 1572: Set C to 1. This normally starts a subtraction without incoming borrow; it may also
; return a true condition to a caller.
    sbc #2                               ; Subtract operand and inverse carry from A. Here # means an immediate number.
; Book line 1573: Subtract literal 2 and (1 minus incoming carry) from A. Update C, Z, N and V
; according to CPU arithmetic rules; decimal mode changes arithmetic behaviour.
    rts                                  ; Return from the current subroutine.
; Book line 1574: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.
y_plus:
; Book line 1575: y_plus names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    clc                                  ; Clear carry before an addition.
; Book line 1576: Clear C to 0. This normally starts an addition without incoming carry; it may also
; return a false condition to a caller.
    adc #2                               ; Add operand and carry to A. Here # means an immediate number.
; Book line 1577: Add literal 2 and incoming carry to A. Update C, Z, N and V according to CPU
; arithmetic rules; decimal mode changes arithmetic behaviour.
y_done:
; Book line 1578: y_done names this assembled address; it emits no bytes and provides a jump, call or
; data reference target.
    rts                                  ; Return from the current subroutine.
; Book line 1579: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; ROUTINE: sprite_frame
; WHAT / WHY / HOW: Move visible sprites smoothly towards the logical tile positions.
; ============================================================================
sprite_frame:
; Book line 1586: sprite_frame names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda PX                               ; Load a value or memory byte into accumulator A.
; Book line 1587: Load A with the byte at PX (logical player column). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    jsr column_to_target                 ; Call a subroutine; execution returns after its RTS.
; Book line 1588: Call column_to_target, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
    lda SPX                              ; Load a value or memory byte into accumulator A.
; Book line 1589: Load A with the byte at SPX (visible player X low byte). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    sta SPRLO                            ; Store accumulator A into memory.
; Book line 1590: Store A into the byte at SPRLO. The register and CPU flags are unchanged.
    lda SPXH                             ; Load a value or memory byte into accumulator A.
; Book line 1591: Load A with the byte at SPXH (visible player X high byte). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    sta SPRHI                            ; Store accumulator A into memory.
; Book line 1592: Store A into the byte at SPRHI. The register and CPU flags are unchanged.
    jsr move_x_toward                    ; Call a subroutine; execution returns after its RTS.
; Book line 1593: Call move_x_toward, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    lda SPRLO                            ; Load a value or memory byte into accumulator A.
; Book line 1594: Load A with the byte at SPRLO. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SPX                              ; Store accumulator A into memory.
; Book line 1595: Store A into the byte at SPX (visible player X low byte). The register and CPU flags
; are unchanged.
    lda SPRHI                            ; Load a value or memory byte into accumulator A.
; Book line 1596: Load A with the byte at SPRHI. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SPXH                             ; Store accumulator A into memory.
; Book line 1597: Store A into the byte at SPXH (visible player X high byte). The register and CPU
; flags are unchanged.
    lda PY                               ; Load a value or memory byte into accumulator A.
; Book line 1598: Load A with the byte at PY (logical player row). Z records a zero value; N copies
; bit 7. Carry is unchanged.
    jsr row_to_target                    ; Call a subroutine; execution returns after its RTS.
; Book line 1599: Call row_to_target, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    ldx SPY                              ; Load a value into index register X.
; Book line 1600: Load X with the byte at SPY (visible player Y). Z records a zero value; N copies bit
; 7. Carry is unchanged.
    jsr move_y_toward                    ; Call a subroutine; execution returns after its RTS.
; Book line 1601: Call move_y_toward, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    sta SPY                              ; Store accumulator A into memory.
; Book line 1602: Store A into the byte at SPY (visible player Y). The register and CPU flags are
; unchanged.

    lda EX                               ; Load a value or memory byte into accumulator A.
; Book line 1604: Load A with the byte at EX. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    jsr column_to_target                 ; Call a subroutine; execution returns after its RTS.
; Book line 1605: Call column_to_target, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
    lda E1X                              ; Load a value or memory byte into accumulator A.
; Book line 1606: Load A with the byte at E1X. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SPRLO                            ; Store accumulator A into memory.
; Book line 1607: Store A into the byte at SPRLO. The register and CPU flags are unchanged.
    lda E1XH                             ; Load a value or memory byte into accumulator A.
; Book line 1608: Load A with the byte at E1XH. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SPRHI                            ; Store accumulator A into memory.
; Book line 1609: Store A into the byte at SPRHI. The register and CPU flags are unchanged.
    jsr move_x_toward                    ; Call a subroutine; execution returns after its RTS.
; Book line 1610: Call move_x_toward, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    lda SPRLO                            ; Load a value or memory byte into accumulator A.
; Book line 1611: Load A with the byte at SPRLO. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta E1X                              ; Store accumulator A into memory.
; Book line 1612: Store A into the byte at E1X. The register and CPU flags are unchanged.
    lda SPRHI                            ; Load a value or memory byte into accumulator A.
; Book line 1613: Load A with the byte at SPRHI. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta E1XH                             ; Store accumulator A into memory.
; Book line 1614: Store A into the byte at E1XH. The register and CPU flags are unchanged.
    lda EY                               ; Load a value or memory byte into accumulator A.
; Book line 1615: Load A with the byte at EY. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    jsr row_to_target                    ; Call a subroutine; execution returns after its RTS.
; Book line 1616: Call row_to_target, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    ldx E1Y                              ; Load a value into index register X.
; Book line 1617: Load X with the byte at E1Y. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    jsr move_y_toward                    ; Call a subroutine; execution returns after its RTS.
; Book line 1618: Call move_y_toward, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    sta E1Y                              ; Store accumulator A into memory.
; Book line 1619: Store A into the byte at E1Y. The register and CPU flags are unchanged.

    lda EX2                              ; Load a value or memory byte into accumulator A.
; Book line 1621: Load A with the byte at EX2. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    jsr column_to_target                 ; Call a subroutine; execution returns after its RTS.
; Book line 1622: Call column_to_target, saving a return address on the stack. Its RTS resumes after
; this call. A, X, Y and flags are not automatically preserved by a call.
    lda E2X                              ; Load a value or memory byte into accumulator A.
; Book line 1623: Load A with the byte at E2X. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SPRLO                            ; Store accumulator A into memory.
; Book line 1624: Store A into the byte at SPRLO. The register and CPU flags are unchanged.
    lda E2XH                             ; Load a value or memory byte into accumulator A.
; Book line 1625: Load A with the byte at E2XH. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta SPRHI                            ; Store accumulator A into memory.
; Book line 1626: Store A into the byte at SPRHI. The register and CPU flags are unchanged.
    jsr move_x_toward                    ; Call a subroutine; execution returns after its RTS.
; Book line 1627: Call move_x_toward, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    lda SPRLO                            ; Load a value or memory byte into accumulator A.
; Book line 1628: Load A with the byte at SPRLO. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta E2X                              ; Store accumulator A into memory.
; Book line 1629: Store A into the byte at E2X. The register and CPU flags are unchanged.
    lda SPRHI                            ; Load a value or memory byte into accumulator A.
; Book line 1630: Load A with the byte at SPRHI. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta E2XH                             ; Store accumulator A into memory.
; Book line 1631: Store A into the byte at E2XH. The register and CPU flags are unchanged.
    lda EY2                              ; Load a value or memory byte into accumulator A.
; Book line 1632: Load A with the byte at EY2. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    jsr row_to_target                    ; Call a subroutine; execution returns after its RTS.
; Book line 1633: Call row_to_target, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    ldx E2Y                              ; Load a value into index register X.
; Book line 1634: Load X with the byte at E2Y. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    jsr move_y_toward                    ; Call a subroutine; execution returns after its RTS.
; Book line 1635: Call move_y_toward, saving a return address on the stack. Its RTS resumes after this
; call. A, X, Y and flags are not automatically preserved by a call.
    sta E2Y                              ; Store accumulator A into memory.
; Book line 1636: Store A into the byte at E2Y. The register and CPU flags are unchanged.

    ; Two native multicolour animation frames, 64 bytes each.
    lda FRAME                            ; Load a value or memory byte into accumulator A.
; Book line 1639: Load A with the byte at FRAME. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    and #$04                             ; Bitwise AND: keep only bits present in both values. Here # means an immediate number.
; Book line 1640: Keep only bits set in both A and literal $04 (decimal 4). Save the result in A and
; update Z and N; carry is unchanged.
    beq sprite_pose_a                    ; Branch if equal/zero flag is set.
; Book line 1641: Branch to sprite_pose_a if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    lda #$8d                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1642: Load A with literal $8d (decimal 141). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $07f8                            ; Store accumulator A into memory.
; Book line 1643: Store A into the byte at $07f8 (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
    lda #$8f                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1644: Load A with literal $8f (decimal 143). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $07f9                            ; Store accumulator A into memory.
; Book line 1645: Store A into the byte at $07f9 (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
    sta $07fa                            ; Store accumulator A into memory.
; Book line 1646: Store A into the byte at $07fa (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
    jmp write_sprites                    ; Jump directly to another location.
; Book line 1647: Continue execution at write_sprites without saving a return address. Registers and
; flags are unchanged by the jump itself.
sprite_pose_a:
; Book line 1648: sprite_pose_a names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda #$8c                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1649: Load A with literal $8c (decimal 140). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $07f8                            ; Store accumulator A into memory.
; Book line 1650: Store A into the byte at $07f8 (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
    lda #$8e                             ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1651: Load A with literal $8e (decimal 142). Z records a zero value; N copies bit 7. Carry
; is unchanged.
    sta $07f9                            ; Store accumulator A into memory.
; Book line 1652: Store A into the byte at $07f9 (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
    sta $07fa                            ; Store accumulator A into memory.
; Book line 1653: Store A into the byte at $07fa (sprite pointer table in the $0400 screen). The
; register and CPU flags are unchanged.
write_sprites:
; Book line 1654: write_sprites names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    lda SPX                              ; Load a value or memory byte into accumulator A.
; Book line 1655: Load A with the byte at SPX (visible player X low byte). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    sta $d000                            ; Store accumulator A into memory.
; Book line 1656: Store A into the byte at $d000 (sprite 0 X low byte). The register and CPU flags are
; unchanged.
    lda SPY                              ; Load a value or memory byte into accumulator A.
; Book line 1657: Load A with the byte at SPY (visible player Y). Z records a zero value; N copies bit
; 7. Carry is unchanged.
    sta $d001                            ; Store accumulator A into memory.
; Book line 1658: Store A into the byte at $d001 (sprite 0 Y coordinate). The register and CPU flags
; are unchanged.
    lda E1X                              ; Load a value or memory byte into accumulator A.
; Book line 1659: Load A with the byte at E1X. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta $d002                            ; Store accumulator A into memory.
; Book line 1660: Store A into the byte at $d002 (sprite 1 X low byte). The register and CPU flags are
; unchanged.
    lda E1Y                              ; Load a value or memory byte into accumulator A.
; Book line 1661: Load A with the byte at E1Y. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta $d003                            ; Store accumulator A into memory.
; Book line 1662: Store A into the byte at $d003 (sprite 1 Y coordinate). The register and CPU flags
; are unchanged.
    lda E2X                              ; Load a value or memory byte into accumulator A.
; Book line 1663: Load A with the byte at E2X. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta $d004                            ; Store accumulator A into memory.
; Book line 1664: Store A into the byte at $d004 (sprite 2 X low byte). The register and CPU flags are
; unchanged.
    lda E2Y                              ; Load a value or memory byte into accumulator A.
; Book line 1665: Load A with the byte at E2Y. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    sta $d005                            ; Store accumulator A into memory.
; Book line 1666: Store A into the byte at $d005 (sprite 2 Y coordinate). The register and CPU flags
; are unchanged.
    lda #0                               ; Load a value or memory byte into accumulator A. Here # means an immediate number.
; Book line 1667: Load A with literal 0. Z records a zero value; N copies bit 7. Carry is unchanged.
    ldx SPXH                             ; Load a value into index register X.
; Book line 1668: Load X with the byte at SPXH (visible player X high byte). Z records a zero value; N
; copies bit 7. Carry is unchanged.
    beq sprite_e1bit                     ; Branch if equal/zero flag is set.
; Book line 1669: Branch to sprite_e1bit if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    ora #$01           ; player 9th X bit
; Book line 1670: Set A bits present in either A or literal $01 (decimal 1). Save the result in A and
; update Z and N; carry is unchanged.
sprite_e1bit:
; Book line 1671: sprite_e1bit names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    ldx E1XH                             ; Load a value into index register X.
; Book line 1672: Load X with the byte at E1XH. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    beq sprite_e2bit                     ; Branch if equal/zero flag is set.
; Book line 1673: Branch to sprite_e2bit if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    ora #$02           ; enemy 1 9th X bit
; Book line 1674: Set A bits present in either A or literal $02 (decimal 2). Save the result in A and
; update Z and N; carry is unchanged.
sprite_e2bit:
; Book line 1675: sprite_e2bit names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
    ldx E2XH                             ; Load a value into index register X.
; Book line 1676: Load X with the byte at E2XH. Z records a zero value; N copies bit 7. Carry is
; unchanged.
    beq sprite_bits_done                 ; Branch if equal/zero flag is set.
; Book line 1677: Branch to sprite_bits_done if Z is 1 (zero or equal); otherwise continue at the next
; instruction. Test the current flag, and leave all flags unchanged.
    ora #$04           ; enemy 2 9th X bit
; Book line 1678: Set A bits present in either A or literal $04 (decimal 4). Save the result in A and
; update Z and N; carry is unchanged.
sprite_bits_done:
; Book line 1679: sprite_bits_done names this assembled address; it emits no bytes and provides a
; jump, call or data reference target.
    sta $d010                            ; Store accumulator A into memory. Target: sprite ninth X-coordinate bits.
; Book line 1680: Store A into the byte at $d010 (VIC sprite X high bits). The register and CPU flags
; are unchanged.
    rts                                  ; Return from the current subroutine.
; Book line 1681: Pull the saved subroutine return address from the stack and resume after its JSR. Do
; not use this as an interrupt return.


; ============================================================================
; ROUTINE: brick_pixels
; WHAT / WHY / HOW: Eight binary rows defining one 8x8 brick character.
; ============================================================================
brick_pixels:
; Book line 1688: brick_pixels names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %11111111,%10001000,%10001000,%10001000
; Book line 1690: Emit 4 bytes in the shown order for brick_pixels. These are data or encoded loader
; bytes, not instructions to execute.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %11111111,%10001000,%10001000,%10001000
; Book line 1692: Emit 4 bytes in the shown order for brick_pixels. These are data or encoded loader
; bytes, not instructions to execute.
willy_pixels:
; Book line 1693: willy_pixels names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %00111100,%01111110,%11111111,%00011000
; Book line 1695: Emit 4 bytes in the shown order for willy_pixels. These are data or encoded loader
; bytes, not instructions to execute.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %00011000,%00100100,%01000010,%11000011
; Book line 1697: Emit 4 bytes in the shown order for willy_pixels. These are data or encoded loader
; bytes, not instructions to execute.
key_pixels:
; Book line 1698: key_pixels names this assembled address; it emits no bytes and provides a jump, call
; or data reference target.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %00011000,%00111100,%01111110,%11111111
; Book line 1700: Emit 4 bytes in the shown order for key_pixels. These are data or encoded loader
; bytes, not instructions to execute.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %01111100,%00011000,%00011000,%00000000
; Book line 1702: Emit 4 bytes in the shown order for key_pixels. These are data or encoded loader
; bytes, not instructions to execute.

; Additional 8x8 character graphics (one byte per pixel row).
crumble_pixels:
; Book line 1705: crumble_pixels names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %11111111,%10101010,%11111111,%01010101
; Book line 1707: Emit 4 bytes in the shown order for crumble_pixels. These are data or encoded loader
; bytes, not instructions to execute.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %11111111,%10101010,%11111111,%01010101
; Book line 1709: Emit 4 bytes in the shown order for crumble_pixels. These are data or encoded loader
; bytes, not instructions to execute.
conveyor_pixels:
; Book line 1710: conveyor_pixels names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %11111111,%01010101,%10101010,%01010101
; Book line 1712: Emit 4 bytes in the shown order for conveyor_pixels. These are data or encoded
; loader bytes, not instructions to execute.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %10101010,%01010101,%10101010,%11111111
; Book line 1714: Emit 4 bytes in the shown order for conveyor_pixels. These are data or encoded
; loader bytes, not instructions to execute.
exit_pixels:
; Book line 1715: exit_pixels names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %11111111,%10000001,%10111101,%10100101
; Book line 1717: Emit 4 bytes in the shown order for exit_pixels. These are data or encoded loader
; bytes, not instructions to execute.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %10100101,%10111101,%10000001,%11111111
; Book line 1719: Emit 4 bytes in the shown order for exit_pixels. These are data or encoded loader
; bytes, not instructions to execute.
enemy_pixels:
; Book line 1720: enemy_pixels names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %00111100,%01111110,%11011011,%11111111
; Book line 1722: Emit 4 bytes in the shown order for enemy_pixels. These are data or encoded loader
; bytes, not instructions to execute.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %00100100,%01011010,%10100101,%01000010
; Book line 1724: Emit 4 bytes in the shown order for enemy_pixels. These are data or encoded loader
; bytes, not instructions to execute.
spike_pixels:
; Book line 1725: spike_pixels names this assembled address; it emits no bytes and provides a jump,
; call or data reference target.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %00000000,%00010000,%00111000,%01111100
; Book line 1727: Emit 4 bytes in the shown order for spike_pixels. These are data or encoded loader
; bytes, not instructions to execute.
; Bitmap data: each binary digit represents one pixel bit (1=ink).
    !byte %11111110,%11111111,%11111111,%11111111
; Book line 1729: Emit 4 bytes in the shown order for spike_pixels. These are data or encoded loader
; bytes, not instructions to execute.

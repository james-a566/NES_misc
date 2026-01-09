; ============================================================
; graphics_playground.s — Based on NES boilerplate (ca65) — BG + Sprites
; NROM-128 (16KB PRG), 8KB CHR-ROM
; (initially) Boots to solid BG (tile 0 filled) + movable test sprite 
; File for testing graphics
; ============================================================

; ----------------------------
; iNES HEADER
; ----------------------------
.segment "HEADER"
  .byte "NES", $1A
  .byte $01          ; 1 × 16KB PRG
  .byte $01          ; 1 × 8KB CHR
  .byte $01          ; mapper 0, vertical mirroring
  .byte $00
  .res 8, $00

; ----------------------------
; HW REGS / CONSTANTS
; ----------------------------
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014
JOY1      = $4016

BTN_A      = %10000000
BTN_B      = %01000000
BTN_SELECT = %00100000
BTN_START  = %00010000
BTN_UP     = %00001000
BTN_DOWN   = %00000100
BTN_LEFT   = %00000010
BTN_RIGHT  = %00000001

; PPUMASK presets (includes “show left 8px” bits)
PPUMASK_BG_SPR = %00011110

OAM_BUF = $0200

; ----------------------------
; ZEROPAGE
; ----------------------------
.segment "ZEROPAGE"
nmi_ready:  .res 1
frame_lo:   .res 1
frame_hi:   .res 1
pad1:       .res 1
pad1_prev:  .res 1
pad1_new:   .res 1

tmp:        .res 1
tmp2:       .res 1

vram_lo: .res 1
vram_hi: .res 1


; ----------------------------
; BSS
; ----------------------------
.segment "BSS"
game_state: .res 1

; ----------------------------
; CODE
; ----------------------------
.segment "CODE"

; ----------------------------
; Palette data (32 bytes)
; ----------------------------
Palettes:
  ; BG0 = red, white, cyan
  .byte $0F,$16,$30,$3C
  .byte $0F,$06,$16,$26
  .byte $0F,$09,$19,$29
  .byte $0F,$0C,$1C,$2C

  ; SPR0 = bright (our test sprite uses color index 3 => entry 4)
  .byte $0F,$0F,$0F,$0F  ; SPR0: black
  .byte $0F,$00,$10,$20
  .byte $0F,$06,$16,$26
  .byte $0F,$09,$19,$29

RESET:
  sei
  cld
  ldx #$FF
  txs

  ; APU safety
  lda #$40
  sta $4017
  lda #$00
  sta $4010

  ; PPU off
  lda #$00
  sta PPUCTRL
  sta PPUMASK

  ; warm up
  jsr WaitVBlank
  jsr WaitVBlank

  ; clear RAM + OAM shadow
  jsr ClearRAM
  jsr ClearOAM

  ; VRAM init (rendering still OFF)
  jsr ClearNametable0
  jsr DrawCheckerboard2x2NT0
  jsr InitPalettes
  jsr DrawTestSprite


  ; put tile 1 at (10,12)
  lda #$01
  ldx #10
  ldy #12
  jsr SetTileNT0_AXY

  ; force that whole 32x32 block to BG palette 2
  lda #$02
  ldx #10
  ldy #12
  jsr SetBGPaletteBlockNT0_AXY





  ; align enabling rendering to vblank boundary
  jsr WaitVBlank

  ; scroll = 0,0 (clean latch)
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

  ; push initial sprites to real OAM once
  lda #$00
  sta OAMADDR
  lda #$02
  sta OAMDMA

  ; enable NMI + rendering
  lda #%10000000      ; NMI on
  sta PPUCTRL
  lda #PPUMASK_BG_SPR ; BG + sprites + show left 8px
  sta PPUMASK

MainLoop:
@wait:
  lda nmi_ready
  beq @wait
  lda #$00
  sta nmi_ready

  jsr ReadController1

  ; demo: move sprite with D-pad (held)
  lda pad1
  and #BTN_LEFT
  beq :+
    dec OAM_BUF+3
:
  lda pad1
  and #BTN_RIGHT
  beq :+
    inc OAM_BUF+3
:
  lda pad1
  and #BTN_UP
  beq :+
    dec OAM_BUF+0
:
  lda pad1
  and #BTN_DOWN
  beq :+
    inc OAM_BUF+0
:

  jmp MainLoop

; ----------------------------
; NMI
; ----------------------------
NMI:
  pha
  txa
  pha
  tya
  pha

  lda #$00
  sta OAMADDR
  lda #$02
  sta OAMDMA

  inc frame_lo
  bne :+
    inc frame_hi
:
  lda #$01
  sta nmi_ready

  pla
  tay
  pla
  tax
  pla
  rti

IRQ:
  rti

; ----------------------------
; HELPERS
; ----------------------------
WaitVBlank:
  lda PPUSTATUS
@loop:
  lda PPUSTATUS
  bpl @loop
  rts

; Safe RAM clear: skip stack page ($0100) and OAM shadow page ($0200)
ClearRAM:
  lda #$00
  tax
@clr:
  sta $0000,x
  sta $0300,x
  sta $0400,x
  sta $0500,x
  sta $0600,x
  sta $0700,x
  inx
  bne @clr
  rts

ClearOAM:
  lda #$FF
  ldx #$00
@o:
  sta OAM_BUF,x
  inx
  inx
  inx
  inx
  bne @o
  rts

ClearNametable0:
  lda PPUSTATUS
  lda #$20
  sta PPUADDR
  lda #$00
  sta PPUADDR

  lda #$00          ; tile 0
  ldx #$04
  ldy #$00
@page:
@byte:
  sta PPUDATA
  iny
  bne @byte
  dex
  bne @page

  lda PPUSTATUS
  rts

DrawCheckerboardNT0:
  lda PPUSTATUS
  lda #$20
  sta PPUADDR
  lda #$00
  sta PPUADDR

  ldy #$00          ; row 0..29
@row:
  tya
  and #$01
  sta tmp

  ldx #$20          ; 32 cols
@col:
  lda tmp
  sta PPUDATA
  eor #$01
  sta tmp
  dex
  bne @col

  iny
  cpy #$1E
  bne @row

  ; attributes (palette 0 everywhere)
  lda #$00
  ldx #$40
@attr:
  sta PPUDATA
  dex
  bne @attr

  lda PPUSTATUS
  rts

DrawCheckerboard2x2NT0:
  ; VRAM addr = $2000
  lda PPUSTATUS
  lda #$20
  sta PPUADDR
  lda #$00
  sta PPUADDR

  ldy #$00              ; row = 0..29
@row:
  ; row_group = (row >> 1) & 1  (toggles every 2 rows)
  tya
  lsr a
  and #$01
  sta tmp               ; tmp = row toggle (0/1)

  ldx #$20              ; 32 columns
@col:
  ; col_group = (col >> 1) & 1  (toggles every 2 cols)
  txa
  lsr a
  and #$01
  eor tmp               ; combine row+col for checker pattern
  sta tmp2              ; tmp2 = 0/1

  lda tmp2              ; tile id = 0 or 1
  sta PPUDATA

  dex
  bne @col

  iny
  cpy #$1E
  bne @row

  ; attributes = palette 0 everywhere
  lda #$00
  ldx #$40
@attr:
  sta PPUDATA
  dex
  bne @attr

  lda PPUSTATUS
  rts

; ------------------------------------------------------------
; SetTileNT0_AXY
;  A = tile id
;  X = tile_x (0..31)
;  Y = tile_y (0..29)
; Writes tile to $2000 + (Y*32) + X
; Call with rendering OFF, or during vblank/NMI.
; ------------------------------------------------------------
SetTileNT0_AXY:
  sta tmp              ; save tile id

  ; vram = Y * 32  (16-bit)
  tya
  sta vram_lo
  lda #$00
  sta vram_hi

  ; multiply by 32 = shift left 5 times
  asl vram_lo
  rol vram_hi
  asl vram_lo
  rol vram_hi
  asl vram_lo
  rol vram_hi
  asl vram_lo
  rol vram_hi
  asl vram_lo
  rol vram_hi

  ; add X
  txa
  clc
  adc vram_lo
  sta vram_lo
  lda vram_hi
  adc #$00
  sta vram_hi

  ; add base $2000
  lda vram_hi
  clc
  adc #$20
  sta vram_hi

  ; set PPUADDR and write tile
  lda PPUSTATUS         ; reset latch
  lda vram_hi
  sta PPUADDR
  lda vram_lo
  sta PPUADDR

  lda tmp
  sta PPUDATA
  rts

; ------------------------------------------------------------
; SetBGPaletteBlockNT0_AXY (SIMPLE)
;  A = palette number (0..3)
;  X = tile_x (0..31)
;  Y = tile_y (0..29)
; Sets BG palette for the entire 32x32 attribute cell containing (X,Y)
; NT0 attribute table ($23C0)
; Call during vblank or with rendering OFF.
; ------------------------------------------------------------
SetBGPaletteBlockNT0_AXY:
  and #$03
  sta tmp

  ; vram_lo = (Y>>2)*8 + (X>>2)
  txa
  lsr a
  lsr a
  sta vram_lo         ; x>>2

  tya
  lsr a
  lsr a               ; y>>2
  asl a
  asl a
  asl a               ; (y>>2)*8
  clc
  adc vram_lo
  sta vram_lo

  lda #$23
  sta vram_hi         ; $23C0 page

  ; build attribute byte = p | (p<<2) | (p<<4) | (p<<6)
  lda tmp
  asl a
  asl a               ; p<<2
  ora tmp
  sta tmp             ; tmp = p | (p<<2)

  lda tmp
  asl a
  asl a
  asl a
  asl a               ; (p | p<<2) << 4 = p<<4 | p<<6
  ora tmp             ; full byte

  ; write to $23C0 + index
  lda PPUSTATUS
  lda vram_hi
  sta PPUADDR
  lda #$C0
  clc
  adc vram_lo
  sta PPUADDR

  sta PPUDATA
  rts



InitPalettes:
  lda PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldx #$00
@p:
  lda Palettes,x
  sta PPUDATA
  inx
  cpx #$20
  bne @p
  rts

DrawTestSprite:
  lda #$70
  sta OAM_BUF+0
  lda #$00          ; tile 0 (solid)
  sta OAM_BUF+1
  lda #$00          ; palette 0
  sta OAM_BUF+2
  lda #$80
  sta OAM_BUF+3
  rts

ReadController1:
  lda pad1
  sta pad1_prev

  lda #$01
  sta JOY1
  lda #$00
  sta JOY1

  ldx #$08
  lda #$00
  sta pad1
@r:
  lda JOY1
  and #$01
  lsr a
  rol pad1
  dex
  bne @r

  lda pad1
  eor pad1_prev
  and pad1
  sta pad1_new
  rts

; ----------------------------
; VECTORS
; ----------------------------
.segment "VECTORS"
  .word NMI
  .word RESET
  .word IRQ

; ----------------------------
; CHR (8KB)
; ----------------------------
.segment "CHARS"
  ; Tile 0: solid block
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

  ; Tile 1: solid box (plane 0 only => color index 1)
  .byte $FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF
  .byte $00,$00,$00,$00,$00,$00,$00,$00

  .res 8192-32, $00


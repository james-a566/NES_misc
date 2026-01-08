; ============================================================
; template_bg.s — NES boilerplate (ca65) — BG + Sprites
; NROM-128 (16KB PRG), 8KB CHR-ROM
; Boots to solid BG (tile 0 filled) + movable test sprite
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
  ; BG0 = bright so the filled tile 0 is obvious
  .byte $0F,$30,$30,$30
  .byte $0F,$06,$16,$26
  .byte $0F,$09,$19,$29
  .byte $0F,$0C,$1C,$2C

  ; SPR0 = bright (our test sprite uses color index 3 => entry 4)
  .byte $0F,$16,$16,$16   ; SPR0: bright red (high contrast on white)
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
  jsr InitPalettes
  jsr DrawTestSprite

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

  lda #$00        ; tile index 0
  ldx #$04        ; 1024 bytes (tiles+attrs)
  ldy #$00
@page:
@byte:
  sta PPUDATA
  iny
  bne @byte
  dex
  bne @page

  lda PPUSTATUS   ; clear latch after big VRAM write
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
  ; Tile 0: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .res 8192-16, $00

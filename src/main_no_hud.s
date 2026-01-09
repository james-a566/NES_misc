; ============================================================
; main.s — based on template_bg.s NES boilerplate (ca65) — BG + Sprites
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

; BG0: c0,  c1,  c2,  c3
.byte $0F, $30, $16, $0F

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

    lda #$00
    sta nmi_ready

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


  ; ---- OAM DMA every frame ----
  lda #$00
  sta OAMADDR
  lda #$02
  sta OAMDMA

  ; ---- keep scroll stable ----
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

  inc frame_lo
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
  ldx #$40        ; 1024 bytes (tiles+attrs)
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
  lda #$01          ; tile 1 (solid)
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
; CHR MAP
; $00        blank (all $00)
; $01        test / debug tile
; $02–$0F    reserved / padding
; $10–$19    digits 0–9
; $1A-$1F    reserved / padding
; $20-27     "Score/lives" letters

.segment "CHARS"
CHR_START:

; Tiles $00-$0F

; Tile $00: blank/space
  .byte $00,$00,$00,$00,$00,$00,$00,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $01: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile $02: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile $03: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile $04: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile $05: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile $06: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile $07: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile $08: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile $09: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile $0A: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile $0B: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile $0C: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile $0D: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile $0E: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile $0F: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  


; Tiles $10 - $1F

; Digits 0-9 at tiles $10-$19 (1bpp: plane0 set, plane1 clear)
Digits:
  ; Tile $10: 0
  .byte $3C,$66,$6E,$76,$66,$66,$3C,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$00
  ; Tile $11: 1
  .byte $18,$38,$18,$18,$18,$18,$3C,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$00
  ; Tile $12: 2
  .byte $3C,$66,$06,$0C,$18,$30,$7E,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$00
  ; Tile $13: 3
  .byte $3C,$66,$06,$1C,$06,$66,$3C,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$00
  ; Tile $14: 4
  .byte $0C,$1C,$3C,$6C,$7E,$0C,$0C,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$00
  ; Tile $15: 5
  .byte $7E,$60,$7C,$06,$06,$66,$3C,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$00
  ; Tile $16: 6
  .byte $1C,$30,$60,$7C,$66,$66,$3C,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$00
  ; Tile $17: 7
  .byte $7E,$66,$06,$0C,$18,$18,$18,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$00
  ; Tile $18: 8
  .byte $3C,$66,$66,$3C,$66,$66,$3C,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$00
  ; Tile $19: 9
  .byte $3C,$66,$66,$3E,$06,$0C,$38,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$00

 ; Tile $1A: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

 ; Tile $1B: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

 ; Tile $1C: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF 

 ; Tile $1D: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  
 ; Tile $1E: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

 ; Tile $1F: solid block (16 bytes = 2 planes)
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

  
; Tiles $20 - $2F:
; ------------------------------------------------------------
; Letters for "SCORE" at tiles $20-$24 (1bpp)
; ------------------------------------------------------------

; Tile $20 = 'S'
.byte $3E,$60,$60,$3C,$06,$06,$7C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $21 = 'C'
.byte $3C,$66,$60,$60,$60,$66,$3C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $22 = 'O'
.byte $3C,$66,$66,$66,$66,$66,$3C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $23 = 'R'
.byte $7C,$66,$66,$7C,$6C,$66,$66,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $24 = 'E'
.byte $7E,$60,$60,$7C,$60,$60,$7E,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; ------------------------------------------------------------
; Letters for "LIVES" (only 'L','I','V' needed) at tiles $25-$27 (1bpp)
; ------------------------------------------------------------

; Tile $25 = 'L'
.byte $60,$60,$60,$60,$60,$60,$7E,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $26 = 'I'
.byte $3C,$18,$18,$18,$18,$18,$3C,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $27 = 'V'
.byte $66,$66,$66,$66,$66,$3C,$18,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00


  ; Tiles $30 - $3F:

  ; Tiles $40 - $4F:

  ; Tiles $50 - $5F:

  ; Tiles $60 - $6F:

  ; Tiles $70 - $7F:

  ; Tiles $80 - $8F:

  ; Tiles $90 - $9F:

  ; Tiles $A0 - $AF:

  ; Tiles $B0 - $BF:

  ; Tiles $C0 - #CF:

  ; Tiles $D0 - $DF:

  ; Tiles $E0 - $EF:

  ; Tiles $F0 - $FF:

CHR_END:
.res 8192 - (CHR_END - CHR_START), $00
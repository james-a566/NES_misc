; ============================================================
; template_sprite.s — NES boilerplate (ca65) — Sprites only
; NROM-128 (16KB PRG), 8KB CHR-ROM
; Boots to a movable test sprite (BG off)
; ============================================================

.segment "HEADER"
  .byte "NES", $1A
  .byte $01
  .byte $01
  .byte $01
  .byte $00
  .res 8, $00

PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014
JOY1      = $4016

BTN_UP     = %00001000
BTN_DOWN   = %00000100
BTN_LEFT   = %00000010
BTN_RIGHT  = %00000001

PPUMASK_SPR = %00010110   ; sprites on + show left 8px sprites

OAM_BUF = $0200

.segment "ZEROPAGE"
nmi_ready:  .res 1
frame_lo:   .res 1
frame_hi:   .res 1
pad1:       .res 1
pad1_prev:  .res 1

.segment "BSS"
game_state: .res 1

.segment "CODE"

Palettes:
  ; BG (still write 32 bytes for completeness; BG will be off)
  .byte $0F,$0F,$0F,$0F
  .byte $0F,$0F,$0F,$0F
  .byte $0F,$0F,$0F,$0F
  .byte $0F,$0F,$0F,$0F
  ; SPR0 bright
  .byte $0F,$30,$30,$30
  .byte $0F,$00,$10,$20
  .byte $0F,$06,$16,$26
  .byte $0F,$09,$19,$29

RESET:
  sei
  cld
  ldx #$FF
  txs

  lda #$40
  sta $4017
  lda #$00
  sta $4010

  lda #$00
  sta PPUCTRL
  sta PPUMASK

  jsr WaitVBlank
  jsr WaitVBlank

  jsr ClearRAM
  jsr ClearOAM

  lda #$00
  sta nmi_ready
  sta frame_lo
  sta frame_hi
  sta pad1
  sta pad1_prev
  sta game_state

  jsr InitPalettes
  jsr DrawTestSprite

  jsr WaitVBlank

  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

  lda #$00
  sta OAMADDR
  lda #$02
  sta OAMDMA

  lda #%10000000
  sta PPUCTRL
  lda #PPUMASK_SPR
  sta PPUMASK

MainLoop:
@wait:
  lda nmi_ready
  beq @wait
  lda #$00
  sta nmi_ready

  jsr ReadController1

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

WaitVBlank:
  lda PPUSTATUS
@loop:
  lda PPUSTATUS
  bpl @loop
  rts

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
  lda #$00
  sta OAM_BUF+1
  lda #$00
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
  rts

.segment "VECTORS"
  .word NMI
  .word RESET
  .word IRQ

.segment "CHARS"
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .res 8192-16, $00

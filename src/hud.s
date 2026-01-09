; ============================
; hud.s — reusable HUD module (BG)
; Contract:
; - Tile $00 is blank (space)
; - Digits at DIGIT_TILE_BASE ($10..$19)
; - Letters at $20..$27 (S C O R E L I V)
; - Call HUD_NMI from NMI (vblank) for VRAM updates
; ============================

.export HUD_Init, HUD_DrawStatic, HUD_NMI
.export HUD_IncScore, HUD_SetLives

; --- PPU regs (duplicate is fine) ---
PPUSTATUS = $2002
PPUADDR   = $2006
PPUDATA   = $2007

; ----------------------------
; HUD layout (tile coords)
; ----------------------------
SCORE_X       = 24
SCORE_Y       = 2
SCORE_LABEL_X = 18

LIVES_LABEL_X = 2
LIVES_X       = 8
LIVES_Y       = 2

; ----------------------------
; CHR tile IDs (HUD)
; ----------------------------
DIGIT_TILE_BASE = $10

LETTER_S = $20
LETTER_C = $21
LETTER_O = $22
LETTER_R = $23
LETTER_E = $24
LETTER_L = $25
LETTER_I = $26
LETTER_V = $27

; ----------------------------
; ZEROPAGE (HUD state)
; ----------------------------
.segment "ZEROPAGE"
hud_score_hi:     .res 1     ; packed BCD: thousands/hundreds
hud_score_lo:     .res 1     ; packed BCD: tens/ones
hud_score_dirty:  .res 1

hud_lives:        .res 1     ; 0..9
hud_lives_dirty:  .res 1

hud_tmp:          .res 1
hud_vram_lo:      .res 1
hud_vram_hi:      .res 1

; ----------------------------
; CODE
; ----------------------------
.segment "CODE"

; Public: initialize HUD values + mark dirty
HUD_Init:
  lda #$00
  sta hud_score_hi
  sta hud_score_lo

  lda #$03
  sta hud_lives

  lda #$01
  sta hud_score_dirty
  sta hud_lives_dirty
  rts

; Public: draw static labels ("LIVES " and "SCORE ")
; Call during init while rendering is OFF (or during vblank)
HUD_DrawStatic:
  ; "SCORE " at (SCORE_LABEL_X, SCORE_Y)
  ldx #SCORE_LABEL_X
  ldy #SCORE_Y
  jsr HUD_SetNT0Addr_XY

  lda #LETTER_S  
  jsr HUD_PutA
  lda #LETTER_C  
  jsr HUD_PutA
  lda #LETTER_O  
  jsr HUD_PutA
  lda #LETTER_R  
  jsr HUD_PutA
  lda #LETTER_E  
  jsr HUD_PutA
  lda #$00       
  jsr HUD_PutA   ; space

  ; "LIVES " at (LIVES_LABEL_X, LIVES_Y)
  ldx #LIVES_LABEL_X
  ldy #LIVES_Y
  jsr HUD_SetNT0Addr_XY

  lda #LETTER_L  
  jsr HUD_PutA
  lda #LETTER_I  
  jsr HUD_PutA
  lda #LETTER_V  
  jsr HUD_PutA
  lda #LETTER_E  
  jsr HUD_PutA
  lda #LETTER_S  
  jsr HUD_PutA
  lda #$00       
  jsr HUD_PutA   ; space
  rts

; Public: call from NMI (vblank) — redraw if dirty
HUD_NMI:
  lda hud_score_dirty
  beq @no_score
    lda #$00
    sta hud_score_dirty
    jsr HUD_DrawScore4
@no_score:

  lda hud_lives_dirty
  beq @no_lives
    lda #$00
    sta hud_lives_dirty
    jsr HUD_DrawLives1
@no_lives:
  rts

; Public: score++
HUD_IncScore:
  ; increment ones
  lda hud_score_lo
  clc
  adc #$01
  sta hud_score_lo

  lda hud_score_lo
  and #$0F
  cmp #$0A
  bcc @mark

  ; carry to tens
  lda hud_score_lo
  and #$F0
  sta hud_score_lo

  lda hud_score_lo
  clc
  adc #$10
  sta hud_score_lo

  lda hud_score_lo
  and #$F0
  cmp #$A0
  bcc @mark

  ; carry to hundreds
  lda hud_score_lo
  and #$0F
  sta hud_score_lo

  lda hud_score_hi
  clc
  adc #$01
  sta hud_score_hi

  lda hud_score_hi
  and #$0F
  cmp #$0A
  bcc @mark

  ; carry to thousands
  lda hud_score_hi
  and #$F0
  sta hud_score_hi

  lda hud_score_hi
  clc
  adc #$10
  sta hud_score_hi

  lda hud_score_hi
  and #$F0
  cmp #$A0
  bcc @mark

  ; wrap 9999 -> 0000
  lda #$00
  sta hud_score_hi
  sta hud_score_lo

@mark:
  lda #$01
  sta hud_score_dirty
  rts

; Public: set lives = A (0..9)
HUD_SetLives:
  and #$0F
  sta hud_lives
  lda #$01
  sta hud_lives_dirty
  rts

; --- internal: draw score at SCORE_X/SCORE_Y ---
HUD_DrawScore4:
  ldx #SCORE_X
  ldy #SCORE_Y
  jsr HUD_SetNT0Addr_XY

  ; thousands
  lda hud_score_hi
  lsr a
  lsr a
  lsr a
  lsr a
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA

  ; hundreds
  lda hud_score_hi
  and #$0F
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA

  ; tens
  lda hud_score_lo
  lsr a
  lsr a
  lsr a
  lsr a
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA

  ; ones
  lda hud_score_lo
  and #$0F
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA
  rts

; --- internal: draw lives digit at LIVES_X/LIVES_Y ---
HUD_DrawLives1:
  ldx #LIVES_X
  ldy #LIVES_Y
  jsr HUD_SetNT0Addr_XY

  lda hud_lives
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA
  rts

; --- internal: convenience write ---
HUD_PutA:
  sta PPUDATA
  rts

; --- internal: set NT0 addr from tile X,Y (0..31,0..29) ---
HUD_SetNT0Addr_XY:
  stx hud_vram_lo
  lda #$00
  sta hud_vram_hi

  tya
  sta hud_tmp

  lda hud_tmp
  sta hud_vram_lo
  lda #$00
  sta hud_vram_hi

  asl hud_vram_lo
  rol hud_vram_hi
  asl hud_vram_lo
  rol hud_vram_hi
  asl hud_vram_lo
  rol hud_vram_hi
  asl hud_vram_lo
  rol hud_vram_hi
  asl hud_vram_lo
  rol hud_vram_hi        ; *32

  txa
  clc
  adc hud_vram_lo
  sta hud_vram_lo
  lda hud_vram_hi
  adc #$20               ; + $2000
  sta hud_vram_hi

  lda PPUSTATUS
  lda hud_vram_hi
  sta PPUADDR
  lda hud_vram_lo
  sta PPUADDR
  rts

; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		frames.inc
;		Purpose:	Stack frames
;		Created:	19th April 2023
;		Reviewed: 	No
;		Author : 	Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

; ************************************************************************************************
;
;						Upper 3 bits : identifier, lower 5 : total frame size
;
; ************************************************************************************************

FRAME_GOSUB = $E4 							; Gosub has 4 bytes
FRAME_FOR = $C0+19 							; For has 19 bytes
FRAME_LOOP = $A0+6 							; GP.DO has 6 bytes
FRAME_SELECT = $80+7 						; GP.SELECT has 7 bytes
FRAME_FNSTATE = $60+4 					; GP.FN's saved string state has 4 bytes
FRAME_FNSLOT = $40+7 					; ...and one saved evaluation stack slot has 7

;
;		Identifiers are the UPPER 3 BITS, so there are only eight and six are now spoken for:
;		7 GOSUB, 6 FOR, 5 GP.DO, 4 GP.SELECT, 3 GP.FN state, 2 GP.FN slot. $FF is the
;		stack-empty fail marker StackFindFrame stops on -- it is id 7 size 31, which no real
;		frame can be, so it can never be mistaken for a GOSUB.
;
;		GP.SELECT no longer opens one (01/09/26) but keeps its id, since nothing needs it.
;		A GP.FN call opens ONE state frame and ONE slot frame per live evaluation stack slot,
;		rather than one frame holding the lot: the size field is five bits, and twelve slots
;		of six bytes is 72. Every frame carrying its own true size is what lets StackFindFrame
;		walk over them correctly if a RETURN ever has to.
;

; ************************************************************************************************
;
;									Changes and Updates
;
; ************************************************************************************************
;
;		Date			Notes
;		==== 			=====
;
; ************************************************************************************************

; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		data.inc
;		Purpose:	Common Data
;		Created:	11th April 2023
;		Reviewed: 	No
;		Author:		Paul Robson (paul@robsons.org.uk)
;
; ************************************************************************************************
; ************************************************************************************************

; ************************************************************************************************
;
;									Mandatory Zero page code
;
; ************************************************************************************************

		.section zeropage
zsTemp: 									; string temporary area.
		.fill 	2
runtimeStackPtr: 							; runtime stack pointer
		.fill 	2
		.send zeropage


; ************************************************************************************************
;
;										Non Zero Page Data
;
; ************************************************************************************************

		.section storage

;
;		stringLowMemory used to sit here. Nothing ever wrote it -- only fre.asm read it -- so it
;		was two bytes of permanent zero, and FRE() returned an address instead of a count. The
;		low end of the free gap is availableMemory (support/allocate.asm); there is no second
;		copy of it now, deliberately.
;
stringHighMemory: 							; string heap ceiling; allocations grow DOWN from here
		.fill 	2

		.send 	storage

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


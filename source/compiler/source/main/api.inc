; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		api.inc
;		Purpose:	API Constants for compiler
;		Created:	7th October 2023
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
;
;		Open the input file or from memory.
;
BLC_OPENIN = 0
;
;		Close the input file. Cannot be reopened.
;
BLC_CLOSEIN = 1
;
;		Read the next line from the source file. This should be returned into YX and should
; 		point to the line number data ; e.g. the offset to next, line number etc.
;		Returns CS if line available, CC finished.
;
BLC_READIN = 2
;
;		Reset the code writing pointer. Code has to be stored in memory as it is passed over
; 		at the end to fix up all the line number references. It can be stored on BLC_CLOSEOUT
;
BLC_RESETOUT = 3
;
;		Close the output - at this point you can write the generated code if you want.
;
BLC_CLOSEOUT = 4
;
;		Write a byte X at the object pointer and bump that address.
;
BLC_WRITEOUT = 5
;
;		Print character X to display / stream for errors & information
;
BLC_PRINTCHAR = 6
;
;		Translate AsmSymName (the name as written inside a GP.ASM {VAR}) through BASLOAD's
;		#SYMFILE, leaving the crunched name in AsmSymCrunched. CC = found. CS = failed, with
;		A = 0 when the symbol file itself is missing and A = 1 when the name is not in it.
;
;		HERE RATHER THAN IN THE COMPILER LIBRARY because the file name is derived from
;		GPC.INPUT's source line, which is an application symbol -- the same reason ScanGPUsage
;		lives on that side. The two buffers are the compiler's, because the application links
;		the compiler library and so can see them, and not the other way round.
;
BLC_SYMLOOKUP = 7
;
;		End of the FIRST pass. The object's length is now known and everything that follows from
;		it can be settled: how much of the runtime this program needs, where its object code will
;		land, where its workspace starts -- and whether it fits at all.
;
;		PASS TWO NEEDS ALL OF THAT WHILE IT IS COMPILING, which is why it is asked for here
;		rather than at the end. Returns CS if the program is too big, having already said so.
;
BLC_ENDPASS1 = 8
;
;		End of the SECOND pass. Whatever the application still has in hand goes out here, so
;		that the object is complete before the two passes are compared and the output closed.
;
BLC_ENDPASS2 = 9

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


; ************************************************************************************************
; ************************************************************************************************
;
;		Name:		deferror.asm
;		Purpose:	Deferred syntax error (defer-to-runtime throw-stub)
;		Created:	16th July 2026
;		Author : 	Claude
;
; ************************************************************************************************
; ************************************************************************************************

		.section 	code

; ************************************************************************************************
;
;		The compiler emits this opcode in place of a statement it could not parse (see
;		DeferStatementToRuntime / CompilerErrorHandler). If execution never reaches it -- the
;		usual case, unreachable or dead code -- nothing happens. If it IS reached, it raises a
;		SYNTAX ERROR at runtime, exactly where the interpreter would, reported at the current
;		line. It carries no operand.
;
; ************************************************************************************************

CommandDeferredError: ;; [.deferror]
		.entercmd
		.error_syntax

		.send 	code

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

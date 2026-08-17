# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		c64tokens.py
#		Purpose :	Create c64 tokens files / C64 tokens class.
#		Date :		11th April 2023
#		Author : 	Paul Robson (paul@robsons.org.uk)
#
# *******************************************************************************************
# *******************************************************************************************

import os,re,sys

# *******************************************************************************************
#
#										C64 token class
#
# *******************************************************************************************

class C64TokenStore(object):

	def __init__(self):
		self.idToToken = {}
		self.tokenToID = {}
		self.append(self.get())
		self.append(self.getX16())
		self.append(self.getGP())

	def append(self,src):
		src = src.replace(" ","").replace("\t","").replace("\n","")
		for s in src.split("|"):
			m = s.upper().split(":")
			self.idToToken[int(m[0])] = m[1]
			self.tokenToID[m[1]] = int(m[0])

	def dump(self):
		ids = [x for x in self.idToToken.keys()]
		ids.sort()
		for i in ids:
			print("{0}_{1:20} = ${2:x} ; ${2:0x} {3}".format(self.getHeader(),self.tidy(self.idToToken[i]),i,self.idToToken[i].lower()))

	def tidy(self,s):
		s = s.replace("+","PLUS").replace("-","MINUS").replace("*","TIMES").replace("/","DIVIDE").replace("^","POWER")
		s = s.replace("(","LB").replace(">","GREATER").replace("<","LESS").replace("=","EQUAL").replace("$","DOLLAR")
		s = s.replace("#","HASH").replace("","").replace("","").replace("","").replace("","")
		#
		#		GP keywords are dotted (GP.DO), and the C64 dump is assembled as
		#		common-source/source/generated/c64tokens.inc -- a dot would be an illegal symbol
		#		character there. "CMD_" is the same substitution pcode.py already applies to its
		#		own dotted names, so PCD_ and C64_ spell a dotted keyword identically. Idempotent
		#		for every pre-GP token: nothing in get() or getX16() contains a dot.
		#
		s = s.replace(".","CMD_")
		#s = s.replace("","").replace("","").replace("","").replace("","").replace("","")
		return s 

	def getHeader(self):
		return "C64"

	def getAllTokens(self):
		return [x for x in self.tokenToID.keys()]
		
	def getToken(self,i):
		return self.idToToken[i] if i in self.idToToken else None

	def getID(self,t):
		t = t.strip().upper()
		return self.tokenToID[t] if t in self.tokenToID else None

	def getBinary(self):
		return ",".join([self.getToken(i) for i in range(self.getID("+"),self.getID("<")+1)])

	def get(self):
		return """
				128:END|129:FOR|130:NEXT|131:DATA|132:INPUT#|133:INPUT|134:DIM|135:READ|136:LET|137:GOTO|138:RUN|139:IF|
				140:RESTORE|141:GOSUB|142:RETURN|143:REM|144:STOP|145:ON|146:WAIT|147:LOAD|148:SAVE|149:VERIFY|150:DEF|151:POKE|152:PRINT#
				|153:PRINT|154:CONT|155:LIST|156:CLR|157:CMD|158:SYS|159:OPEN|160:CLOSE|161:GET|162:NEW|163:TAB(|164:TO|165:FN|166:SPC(
				|167:THEN|168:NOT|169:STEP|170:+|171:-|172:*|173:/|174:^|175:AND|176:OR|177:>|178:=|179:<|180:SGN|181:INT|182:ABS|183:USR
				|184:FRE|185:POS|186:SQR|187:RND|188:LOG|189:EXP|190:COS|191:SIN|192:TAN|193:ATN|194:PEEK|195:LEN|196:STR$|197:VAL|198:ASC
				|199:CHR$|200:LEFT$|201:RIGHT$|202:MID$|203:GO|255:PI"""

	#
	#		X16 keywords. Statements run sequentially from $CE80; the functions re-anchor at a
	#		FIXED $CED0, keyed off where VPEEK sits in this list. That is what makes the table
	#		extensible: statements can be appended without disturbing a single function token.
	#
	#		THE ORDER HERE IS THE ROM'S ORDER AND MUST STAY THAT WAY -- it is not cosmetic, it
	#		IS the token numbering. Verified against R49 by decoding the keyword table out of
	#		BASIC ROM bank 4 (see docs/memory/blitz-x16-rom-abi-verification.md). Two fixes
	#		from that check:
	#
	#		  - LINPUT# precedes LINPUT in the ROM. They were the other way round here, so both
	#		    tokenised to the wrong byte.
	#		  - SPRITE..HBLOAD and TDATA/TATTR/MOD were added to X16 BASIC after R43 and were
	#		    missing entirely. The list dated from the R42/R43 era.
	#
	#		BASLOAD and HBLOAD are listed for correct TOKENISATION only; they are interactive
	#		(BASLOAD is typed "Command" in the manual, HBLOAD is not documented at all), so the
	#		compiler is not expected to ever generate code for them -- like LIST or NEW.
	#
	def getX16(self):
		s = """
				MON|DOS|OLD|GEOS|VPOKE|VLOAD|SCREEN|PSET|LINE|FRAME|RECT|CHAR|MOUSE|COLOR|TEST|RESET|CLS|CODEX|LOCATE|BOOT|KEYMAP|BLOAD|BVLOAD
				|BVERIFY|BANK|FMINIT|FMNOTE|FMDRUM|FMINST|FMVIB|FMFREQ|FMVOL|FMPAN|FMPLAY|FMCHORD|FMPOKE|PSGINIT|PSGNOTE|PSGVOL|PSGWAV|PSGFREQ
				|PSGPAN|PSGPLAY|PSGCHORD|REBOOT|POWEROFF|I2CPOKE|SLEEP|BSAVE|MENU|REN|LINPUT#|LINPUT|BINPUT#|HELP|BANNER|EXEC|TILE|EDIT
				|SPRITE|SPRMEM|MOVSPR|BASLOAD|OVAL|RING|HBLOAD
				|VPEEK|MX|MY|MB|JOY|HEX$|BIN$|I2CPEEK|POINTER|STRPTR|RPT$|MWHEEL|TDATA|TATTR|MOD"""

		s = s.replace("\n","").replace(" ","").replace("\t","").split("|")
		vpeek = s.index("VPEEK")
		return "|".join(["{0}:{1}".format(i+0xCE80+(0 if i < vpeek else 0x50-vpeek),s[i]) for i in range(0,len(s))])

	#
	#		GP.BASIC keywords -- our own extension set, NOT anything the X16 ROM knows.
	#
	#		Allocated from $CE7F DOWNWARD, and that direction is the whole point. getX16() above
	#		numbers the ROM's statements upward from $CE80 and re-anchors its functions at a fixed
	#		$CED0, so the ROM's own scheme can never reach below $CE80 however much it grows. That
	#		makes $CE01-$CE7F 127 slots a future ROM revision structurally cannot collide with --
	#		unlike the tempting gaps ABOVE the keywords ($CEC2-$CECF, $CEDF-$CEFF), which is
	#		exactly where it does grow.
	#
	#		$CE00 is excluded: a zero second byte means "unshifted" in the compiler's table format.
	#
	#		Unlike getX16() these are written out EXPLICITLY as id:NAME rather than computed from
	#		list position, so adding one can never renumber the others. Do not convert this to a
	#		positional list, and do not append GP names to getX16() -- that would renumber real ROM
	#		keywords.
	#
	#		The cost of using one: a PRG containing a $CE7x byte cannot be LISTed or RUN by the
	#		ROM, because there is no handler behind it. Programs using GP keywords are compile-only.
	#
	def getGP(self):
		return """
				52863:GP.DO|52862:GP.LOOP|52861:GP.EXITDO|52860:GP.CALL|
				52859:GP.A|52858:GP.X|52857:GP.Y|52856:GP.C|
				52855:GP.INSTR|52854:GP.STRPTR|
				52853:GP.TRIM|52852:GP.LTRIM|52851:GP.UPPER|52850:GP.LOWER|
				52849:GP.RTRIM|52848:GP.COMP|52847:GP.SORT|52846:GP.ARRPTR|52845:GP.STASH|52844:GP.RESTR"""

	#
	#		52852 was GP.PAD for a few hours on 16th August 2026, removed before it ever shipped --
	#		padding GROWS a string, an in-place handler only ever has the block and not the
	#		variable slot, so it could never reallocate. It is STRHELP.PAD in BASL now
	#		(GPC-BASIC/STRHELP.INC.BL). GP.LTRIM took the slot the same day; nothing tokenised
	#		with GP.PAD ever left the scratchpad, so there is no stale PRG to mis-read it.
	#


if __name__ == "__main__":
	print(";\n;\tThis file is automatically generated.\n;")
	c64 = C64TokenStore()
	c64.dump()
	#print(c64.getBinary())
	#print(c64.getX16())

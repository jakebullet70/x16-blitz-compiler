# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		tokenise.py
#		Purpose :	Tokenise text file to BASIC
#		Date :		29th April 2023
#		Author : 	Paul Robson (paul@robsons.org.uk)
#
# *******************************************************************************************
# *******************************************************************************************

import os,sys,re
from c64tokens import *

# *******************************************************************************************
#
#								Tokeniser Worker
#
# *******************************************************************************************

class Tokeniser(object):
	#
	#		Tokens that are NOT spelled out as text and must never be matched from source.
	#
	#		$FF is the only one: it is the PETSCII CHARACTER for pi, not a keyword. The C64 keyword
	#		tokens stop at GO ($CB), and the ROM's own tokeniser never turns the letters P and I
	#		into $FF -- typing "PI=3" gives a VARIABLE called PI, and stock X16 BASIC accepts that
	#		quite happily. Matching the text here turned every such variable into an assignment to
	#		pi, which IS a syntax error, so any program with a variable named PI was silently
	#		corrupted on the way in. Proof: the same source typed at the emulator ran fine, and
	#		tokenised by this tool gave "?SYNTAX ERROR IN 20" on the same ROM.
	#
	#		The name has to stay in the token table -- the compiler's unary.def looks pi up by it,
	#		and a program that really wants pi carries the $FF character -- so skip it here rather
	#		than removing it there.
	#
	NOT_SPELLED_AS_TEXT = { 0xFF }

	def __init__(self):
		self.tokens = C64TokenStore()
		self.longest = max([len(s) for s in self.tokens.getAllTokens()])

	def tokeniseBody(self,body):
		body = body.upper().strip()
		self.data = []
		while body != "":
			body = self.tokeniseOne(body)
		return self.data+[0]

	def tokeniseOne(self,s):
		if s[0] == '"':
			m = re.match('^(\\".*?\\")(.*)$',s)
			assert m is not None,"Unbalanced quotes "+s
			self.data += [ord(c) for c in m.group(1)]
			return m.group(2)
			
		if s[0] >= "A" and s[0] <= "Z":
			m = re.match("^([A-Z]+[\\(\\$\\#]?)(.*)$",s)
			assert m is not None
			#
			#		Longest match first, up to self.longest -- NOT a hardcoded 7. The X16 has
			#		two 8-character keywords, PSGCHORD and POWEROFF, and capping at 7 did not
			#		merely fail to tokenise them: it fell through to a character-at-a-time
			#		scan, so PSGCHORD matched the OR in psgchORd and came out as
			#		P S G C H <$B0 OR> D -- a boolean operator welded into the keyword.
			#		PSGCHORD is a command the compiler supports, so it was unusable.
			#
			for l in range(self.longest,1,-1):
				token = self.tokens.getID(s[:l])
				if token in self.NOT_SPELLED_AS_TEXT:
					continue
				if token is not None and len(self.tokens.getToken(token)) == l:
					if token >= 0x100:
						self.data.append(token >> 8)
					self.data.append(token & 0xFF)
					#print(s,"["+s[l:]+"]",l)
					return s[l:]

		token = self.tokens.getID(s[0])
		self.data.append(ord(s[0]) if token is None else token)
		return s[1:]

	def tokeniseLine(self,s):
		m = re.match("^(\\d+)\\s*(.*)$",s)
		assert m is not None,"Bad line format "+s
		line = int(m.group(1))
		return [line & 0xFF,line >> 8] + self.tokeniseBody(m.group(2).strip())

# *******************************************************************************************
#
#									Program converter
#
# *******************************************************************************************

class ProgramTokeniser(object):
	#
	def __init__(self,loadAddress = 0x801):
		self.loadAddress = loadAddress
		self.address = self.loadAddress
		self.binary = [self.address & 0xFF,self.address >> 8]
		self.tokeniser = Tokeniser()
	#
	def add(self,s):
		line = self.tokeniser.tokeniseLine(s)
		startNextLine = self.address + len(line) + 2
		line = [startNextLine & 0xFF,startNextLine >> 8] + line 
		self.binary += line 
		self.address = startNextLine 
		assert len(self.binary) - 2 + self.loadAddress == self.address
	#
	def get(self):
		return self.binary + [ 0,0 ]
	#
	def write(self,fileName):
		open(fileName,"wb").write(bytes(self.get()))

if __name__ == "__main__":
	if len(sys.argv) != 3:
		sys.stderr.write("python tokenise.py <input> <output>\n")
		sys.exit(-1)
	pt = ProgramTokeniser()
	for l in open(sys.argv[1]).readlines():
		l = l.strip()
		if l != "":
			pt.add(l)			
	pt.write(sys.argv[2])
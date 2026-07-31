# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		binary.py
#		Purpose :	Test binary operators (not comparison)
#		Date :		5th May 2023
#		Author : 	Paul Robson (paul@robsons.org.uk)
#
# *******************************************************************************************
# *******************************************************************************************

from tests import *
import random

# *******************************************************************************************
#
#									Basic binary classes
#
# *******************************************************************************************

class TestBinary(TestScript):
	def addTest(self):
		#
		#		4 Functions for numbers.
		#
		n1 = self.getNumber()
		n2 = self.getNumber()
		self.checkEqual("{0}+{1}".format(n1,n2),n1+n2)
		self.checkEqual("{0}-{1}".format(n1,n2),n1-n2)
		self.checkAreNearlyEqual("{0}*{1}".format(n1,n2),n1*n2)
		if n2 != 0:
			self.checkAreNearlyEqual("{0}/{1}".format(n1,n2),n1/n2)
		#
		#		String concatentation.
		#
		s1 = IString()
		s1.updateValue()
		s2 = IString()
		s2.updateValue()
		self.checkStringEqual("{0}+{1}".format(s1.render(),s2.render()),'"'+s1.getValue()+s2.getValue()+'"')
		#
		#		And / Or
		#
		#
		#		Operands are SIGNED, -32768..32767. They used to be masked with & 0xFFFF, which
		#		turned every negative into 32768..65535 -- values stock X16 BASIC does not accept
		#		at all: measured on R49, "65535 AND -1" and "32768 AND -1" are ?ILLEGAL QUANTITY
		#		ERROR, while 32767 and -32768 are fine. The runtime now refuses them too (OUT OF
		#		RANGE, andor.asm), so generating them made the test program stop mid-run -- it
		#		never reached $FFFF and the emulator waited for a dump that never came.
		#
		#		The expected value is still computed in two's complement, because that is what
		#		AND/OR do to the bits once the operands are in range.
		#
		fnc = "and" if random.randint(0,1) == 0 else "or"
		n1 = random.randint(-0x8000,0x7FFF)
		n2 = random.randint(-0x8000,0x7FFF)
		r = (n1 & 0xFFFF) & (n2 & 0xFFFF) if fnc == "and" else (n1 & 0xFFFF) | (n2 & 0xFFFF)
		if (r & 0x8000) != 0:
			r = r - 0x10000
		self.checkEqual("({0} {2} {1})".format(n1,n2,fnc),r)
		
TestBinary()		
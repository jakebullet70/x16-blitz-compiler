# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		test_binary.py
#		Purpose :	Generate binary function code
#		Date :		11th April 2023
#		Author : 	Paul Robson (paul@robsons.org.uk)
#
# *******************************************************************************************
# *******************************************************************************************

import random

def randomInt():
	return random.randint(-50000,50000)

def randomFloat():
	return random.randint(-1000000,1000000)/12347

def randomString():
	return "".join([chr(random.randint(0,25)+97) for x in range(0,random.randint(0,5))])

#
#	Every float in a test -- operands AND the expected result -- goes through here, at full
#	precision.
#
#	This used to be "{0:.8f}", and that broke the tests two ways at once. Eight DECIMAL places is
#	not eight SIGNIFICANT digits: a quotient of -0.00280734 carries only six, and the assertions
#	compare with FloatCompare, which is deliberately approximate to about one part in 2^19. So the
#	expected constant was the least accurate thing in the comparison, eating most of the tolerance
#	before iFloat32's own error was even considered.
#
#	Worse, the operands were rounded on the way out while the expected result was computed from the
#	UNROUNDED values -- so the emulator was asked to reproduce an answer to a slightly different
#	sum. For an operand near 8.1e-05 that rounding is a relative error of 6e-05, thirty times the
#	tolerance. Both together made the suite fail roughly one run in thirty, on whichever random
#	draw happened to produce a small quotient, and there was nothing wrong with the arithmetic.
#
#	repr() round-trips exactly, and floatcom.py now accepts exponent notation.
#
def fnum(x):
	return repr(float(x))

for n in range(0,20):
	#
	n1 = randomInt()
	n2 = randomInt()
	print("{0}  {1} + {2} f.cmp = assert".format(n1,n2,n1+n2))
	if True:
		print("{0}  {1} - {2} f.cmp = assert".format(n1,n2,n1-n2))
		print("{0}  {1} * {2} f.cmp = assert".format(n1,n2,n1*n2))
		if n2 != 0 and True:
			print("{0}  {1} / {2} f.cmp = assert".format(n1,n2,fnum(n1/n2)))

	if True:
		if random.randint(0,4):
			n1 = n2
		print("{0}  {1} f.cmp = {2} f.cmp = assert".format(n1,n2,-1 if n1 == n2 else 0))
		print("{0}  {1} f.cmp <> {2} f.cmp = assert".format(n1,n2,-1 if n1 != n2 else 0))
		print("{0}  {1} f.cmp > {2} f.cmp = assert".format(n1,n2,-1 if n1 > n2 else 0))
		print("{0}  {1} f.cmp >= {2} f.cmp = assert".format(n1,n2,-1 if n1 >= n2 else 0))
		print("{0}  {1} f.cmp < {2} f.cmp = assert".format(n1,n2,-1 if n1 < n2 else 0))
		print("{0}  {1} f.cmp <= {2} f.cmp = assert".format(n1,n2,-1 if n1 <= n2 else 0))


	if True:
		n1 = randomFloat()
		n2 = randomFloat()
		print("{0}  {1} + {2} f.cmp = assert".format(fnum(n1),fnum(n2),fnum(n1+n2)))
		print("{0}  {1} - {2} f.cmp = assert".format(fnum(n1),fnum(n2),fnum(n1-n2)))
		print("{0}  {1} * {2} f.cmp = assert".format(fnum(n1),fnum(n2),fnum(n1*n2)))
		if n2 != 0:
			print("{0}  {1} / {2} f.cmp = assert".format(fnum(n1),fnum(n2),fnum(n1/n2)))

	if True:
		n1 = randomFloat()
		n2 = randomFloat()
		if random.randint(0,4):
			n1 = n2
		print("{0}  {1} f.cmp > {2} f.cmp = assert".format(fnum(n1),fnum(n2),-1 if n1 > n2 else 0))
		print("{0}  {1} f.cmp >= {2} f.cmp = assert".format(fnum(n1),fnum(n2),-1 if n1 >= n2 else 0))
		print("{0}  {1} f.cmp < {2} f.cmp = assert".format(fnum(n1),fnum(n2),-1 if n1 < n2 else 0))
		print("{0}  {1} f.cmp <= {2} f.cmp = assert".format(fnum(n1),fnum(n2),-1 if n1 <= n2 else 0))
		print("{0}  {1} f.cmp = {2} f.cmp = assert".format(fnum(n1),fnum(n2),-1 if n1 == n2 else 0))
		print("{0}  {1} f.cmp <> {2} f.cmp = assert".format(fnum(n1),fnum(n2),-1 if n1 != n2 else 0))


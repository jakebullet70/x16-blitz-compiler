# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		arrays.py
#		Purpose :	Test arrays
#		Date :		7th May 2023
#		Author : 	Paul Robson (paul@robsons.org.uk)
#
# *******************************************************************************************
# *******************************************************************************************

from tests import *
import random,sys

# *******************************************************************************************
#
#								  Array testing class
#
# *******************************************************************************************

class TestArray(object):
	#
	#		Set once by TestArrays: the name of an integer array whose element k holds exactly k,
	#		and the largest subscript it covers. Some subscripts are then rendered through it, so
	#		the generated program contains A(NX%(3)) as well as A(3) -- the same element, but a
	#		NESTED subscript.
	#
	#		That shape used to mis-compile and this suite could not see it, because every
	#		subscript it generated was a bare literal. The inner reference and the outer one
	#		shared the compiler's single subscript counter, so A(B(I)) came out as a two-subscript
	#		access against a one-dimensional array and failed at RUNTIME with BAD ARRAY INDEX.
	#
	indexArray = None
	indexMax = -1

	def __init__(self,dimension = 1):
		ext = 12 if dimension == 1 else 4
		self.dim = [random.randint(2,ext) for i in range(0,dimension)]
		self.depth = dimension
		self.elements = {}
		self.name = self.elementFactory().getName()

	def getName(self):
		return self.name

	def create(self):
		return "dim {0}({1})".format(self.getName(),",".join([str(d) for d in self.dim]))

	def renderIndex(self,index):
		#
		#		"3,1" -> program text for those subscripts, routing some of them through the
		#		index array. The value is unchanged, so the caller's expected results -- which
		#		are keyed on the literal form -- stay correct either way.
		#
		out = []
		for p in index.split(","):
			if TestArray.indexArray is not None and int(p) <= TestArray.indexMax \
					and random.randint(0,2) == 0:
				out.append("{0}({1})".format(TestArray.indexArray,p))
			else:
				out.append(p)
		return ",".join(out)

	def update(self):
		newValue = self.elementFactory()
		newValue.updateValue()
		index = ",".join([str(random.randint(0,self.dim[d])) for d in range(0,self.depth)])
		self.elements[index] = newValue
		return self.getName()+"("+self.renderIndex(index)+") = "+newValue.render()

	def validate(self,out):
		k = [x for x in self.elements.keys()]
		k.sort()
		for x in k:
			out.checkExpression("{0}({1}) <> {2}".format(self.getName(),self.renderIndex(x),self.elements[x].render()))

class StringArray(TestArray):
	def  elementFactory(self):
		return IString()

class IntegerArray(TestArray):
	def  elementFactory(self):
		return IInteger()

class FloatArray(TestArray):
	def  elementFactory(self):
		return IFloat()

# *******************************************************************************************
#
#										Arrays test
#
# *******************************************************************************************

class TestArrays(TestScript):
	def initialisePhase(self):
		self.charsLeft = 4096
		self.arrays = {}
		for i in range(0,3):
			self.appendArray(FloatArray(self.getDimensions()))
			self.appendArray(IntegerArray(self.getDimensions()))
			self.appendArray(StringArray(self.getDimensions()))

		for v in self.arrays.values():
			self.render(v.create())
		#
		#		The index array, filled so element k is k. Built with a FOR loop rather than 13
		#		assignments to keep it to two lines -- linesLeft is the budget that decides how
		#		many real tests get generated. Its name is picked clear of the arrays above; a
		#		scalar loop counter cannot collide with them, arrays and scalars being separate
		#		namespaces.
		#
		TestArray.indexMax = 12
		TestArray.indexArray = self.freeArrayName()
		self.render("dim {0}({1})".format(TestArray.indexArray,TestArray.indexMax))
		self.render("for zz=0 to {0}:{1}(zz)=zz:next".format(TestArray.indexMax,TestArray.indexArray))

	def freeArrayName(self):
		while True:
			name = chr(random.randint(65,90))+chr(random.randint(65,90))+"%"
			if name not in self.arrays:
				return name

	def getDimensions(self):
		return 1 if random.randint(0,3) != 0 else 2

	def appendArray(self,newVar):
		if newVar.getName() not in self.arrays:
			self.arrays[newVar.getName()] = newVar

	def addTest(self):
		for v in self.arrays.values():
			self.render(v.update())
		
	def validatePhase(self):
		for v in self.arrays.values():
			v.validate(self)

TestArrays()		
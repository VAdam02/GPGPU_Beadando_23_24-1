#define FLOAT_PLUSINF 0x7F800000
#define FLOAT_MINUSINF 0xFF800000
#define FLOAT_EFFECTIVELYZERO 0.0f

#define SIGNMASK 0x80000000
#define EXPBIGSMALLMASK 0x40000000
#define BIG_FLOATNOTSTOREEXPMASK 0x3FFFFF00

////////////////////CONFIG////////////////////
#define ARRAY_SIZE 2 //ARRAY_SIZE * sizeof(array_vec_t) * 8 bits
#define index_t char //255 max value / 4 -> 64 max array size
#define element_t uint //32bit must be unsigned
#define array_vec_t uint4 //vec4 of element_t
#define shift_t char //shift_t.maxVal >= sizeof(element_t) * 8
////////////////////CONFIG////////////////////

#define VEC_SIZE (sizeof(array_vec_t) / sizeof(element_t))
#define ELEMENT_TYPE_BIT_SIZE (sizeof(element_t) * 8)

// (VEC_SIZE * ELEMENT_TYPE_BIT_SIZE) * ARRAY_SIZE
typedef struct {
	array_vec_t binaryRep[ARRAY_SIZE];
} BigFloat;

BigFloat add(BigFloat a, BigFloat b);
BigFloat subt(BigFloat a, BigFloat b);

/**
 * Converts a BigFloat to a float
 * @param a Value to convert
 * @return float value
 */
float toFloat(BigFloat a)
{
	//TODO handle INF and NAN
	unsigned int tmp = a.binaryRep[0][0];
	int result = tmp & (SIGNMASK | EXPBIGSMALLMASK); //1bit sign and 1bit highest exponent bit

	if ((tmp & BIG_FLOATNOTSTOREEXPMASK) > 0) //bigger than float max exponent
	{
		//return INF or EFFECTIVELY ZERO
		return (result & EXPBIGSMALLMASK) ? as_float((result & SIGNMASK) | FLOAT_PLUSINF) : FLOAT_EFFECTIVELYZERO;
	}

	result |= (tmp & 0x7F) << 23; //7bit low exponent
	tmp = a.binaryRep[0][1];
	result |= tmp >> 9; //23bit mantissa //FIXME

	return as_float(result);
}

//1.0f  = 0x3F80 0000 = 0 01111111 00000000000000000000000
//0.5f  = 0x3F00 0000 = 0 01111110 00000000000000000000000
//0.0f  = 0x0000 0000 = 0 00000000 00000000000000000000000
//-0.5f = 0xBF00 0000 = 1 01111110 00000000000000000000000
//-1.0f = 0xBF80 0000 = 1 01111111 00000000000000000000000

bool isNum(BigFloat a)
{
	return (a.binaryRep[0][0] & 0x7FFFFFFF) != 0x7FFFFFFF;
}

bool isInf(BigFloat a)
{
	return !isNum(a) && (a.binaryRep[0][0] & 0x80000000) == 0x80000000;
}

bool isNan(BigFloat a)
{
	return !isNum(a) && !isInf(a);
}

/**
* Compares two BigFloats absolute value
* @param a
* @param b
* @return 1 if a > b, -1 if a < b, 0 if a == b
*/
char compAbs(BigFloat a, BigFloat b) {
	//exponent
	if ((a.binaryRep[0][0] & 0x7FFFFFFF) > (b.binaryRep[0][0] & 0x7FFFFFFF)) return 1;
	if ((a.binaryRep[0][0] & 0x7FFFFFFF) < (b.binaryRep[0][0] & 0x7FFFFFFF)) return -1;

	//mantissa
	for (int i = 0; i < sizeof(a.binaryRep); i++)
	{
		for (int j = 0; j < sizeof(a.binaryRep[i]); j++)
		{
			if (a.binaryRep[i][j] > b.binaryRep[i][j]) return 1;
			if (a.binaryRep[i][j] < b.binaryRep[i][j]) return -1;
		}
	}

	return 0;
}

/**
* Compares two BigFloats
* @param a
* @param b
* @return 1 if a > b, -1 if a < b, 0 if a == b
*/
char comp(BigFloat a, BigFloat b) {
	//sign bit
	if ((a.binaryRep[0][0] & 0x80000000) < (b.binaryRep[0][0] & 0x80000000)) return 1;
	if ((a.binaryRep[0][0] & 0x80000000) > (b.binaryRep[0][0] & 0x80000000)) return -1;

	return compAbs(a, b);
}

BigFloat add(BigFloat a, BigFloat b);

					if (a.binaryRep[k][l] == 0) continue; //skip 0
//FIXME exponentDiff is not really okey because it's not calculating with the other bits
//TODO handle shifted out bits by exponentDiff
//TODO handle shifted back bits on overflow at exponent
/**
 * Subtracts two BigFloats
 * @param a Left side of the subtraction
 * @param b Right side of the subtraction
 * @return a - b
 */
BigFloat subt(BigFloat a, BigFloat b) {
	//TODO handle INF and NAN

	if ((a.binaryRep[0][0] & SIGNMASK) != (b.binaryRep[0][0] & SIGNMASK)) //It's an addition
	{
		a.binaryRep[0][0] = (SIGNMASK & ~a.binaryRep[0][0]) | (~SIGNMASK & a.binaryRep[0][0]);
		return add(a, b);
	}

	if (compAbs(a, b) == -1) //Reverse the numbers so the first one is bigger abs
	{
		a.binaryRep[0][0] = (SIGNMASK & ~a.binaryRep[0][0]) | (~SIGNMASK & a.binaryRep[0][0]);
		b.binaryRep[0][0] = (SIGNMASK & ~b.binaryRep[0][0]) | (~SIGNMASK & b.binaryRep[0][0]);
		return subt(b, a);
	}

	////////////////////////////////////////
	////////////HANDLING MANTISSA///////////
	////////////////////////////////////////
	BigFloat result;

	element_t exponentDiff = a.binaryRep[0][0] - b.binaryRep[0][0]; //we can ignore the sign bit because it's the same for both numbers
	char overflow = 0; //0 or 1
	for (index_t i = ARRAY_SIZE - 1; i >= 0; i--)
	{
		for (index_t j = VEC_SIZE - 1; j >= 0; j--)
		{
			if (i == 0 && j == 0) continue; //skip sign and exponent part

			//shift b to mach a exponent
			index_t blockDiff = exponentDiff / ELEMENT_TYPE_BIT_SIZE; //how much blocks should be shifted right
			shift_t extraShift = exponentDiff % ELEMENT_TYPE_BIT_SIZE; //how much bits should be shifted right in the last block
			index_t rightIndex = i * VEC_SIZE + j;
			if (rightIndex < 1 + blockDiff) { rightIndex = 0; }
			else { rightIndex -= blockDiff; }
			//index of the right side of the current block
			index_t iIndex = rightIndex / VEC_SIZE;
			index_t jIndex = rightIndex % VEC_SIZE;

			//index of the left side of the current block
			index_t leftIndex = rightIndex - 1;
			index_t i2Index = leftIndex / VEC_SIZE;
			index_t j2Index = leftIndex % VEC_SIZE;

			element_t shiftedB;
			if (rightIndex == 0)
			{
				shiftedB = 0;
			}
			else if (leftIndex > 0)
			{
				element_t tmp = b.binaryRep[iIndex][jIndex] >> extraShift;
				element_t tmp2 = b.binaryRep[i2Index][j2Index] << (ELEMENT_TYPE_BIT_SIZE - extraShift);
				shiftedB = tmp | (extraShift > 0 ? tmp2 : 0);
			}
			else if (leftIndex == 0)
			{
				element_t tmp = b.binaryRep[iIndex][jIndex] >> extraShift;
				element_t tmp2 = 1 << (ELEMENT_TYPE_BIT_SIZE - extraShift);
				shiftedB = tmp | (extraShift > 0 ? tmp2 : 0);
			}

			result.binaryRep[i][j] = a.binaryRep[i][j] - shiftedB - overflow;
			overflow = (a.binaryRep[i][j] - shiftedB - overflow) > a.binaryRep[i][j];
		}
	}
	
	if (exponentDiff == 0) overflow = 1;

	if (overflow)
	{
		for (index_t i = ARRAY_SIZE - 1; i >= 0; i--)
		{
			for (index_t j = VEC_SIZE - 1; j >= 0; j--)
			{
				if (i == 0 && j == 0) continue; //skip sign and exponent

				//shift result to mach exponent
				index_t leftIndex = i * VEC_SIZE + j;
				//index of the left side of the current block
				index_t iIndex = leftIndex / VEC_SIZE;
				index_t jIndex = leftIndex % VEC_SIZE;

				//index of the right side of the current block
				index_t rightIndex = leftIndex + 1;
				index_t i2Index = rightIndex / VEC_SIZE;
				index_t j2Index = rightIndex % VEC_SIZE;

				element_t shiftedResult;
				if (rightIndex < ARRAY_SIZE * VEC_SIZE)
				{
					element_t tmp = result.binaryRep[iIndex][jIndex] << 1;
					element_t tmp2 = result.binaryRep[i2Index][j2Index] >> (ELEMENT_TYPE_BIT_SIZE - 1);
					shiftedResult = tmp | tmp2;
				}
				else if (rightIndex == ARRAY_SIZE * VEC_SIZE)
				{
					shiftedResult = result.binaryRep[iIndex][jIndex] << 1;
				}

				result.binaryRep[i][j] = shiftedResult;
			}
		}
	}

	////////////////////////////////////////
	///////HANDLING SIGN AND EXPONENT///////
	////////////////////////////////////////
	result.binaryRep[0][0] = a.binaryRep[0][0] - overflow;

	//TODO handle INF and NAN

	return result;
}

//TODO handle shifted out bits by exponentDiff
//TODO handle shifted back bits on overflow at exponent
/**
 * Adds two BigFloats
 * @param a Left side of the addition
 * @param b Right side of the addition
 * @return a + b
 */
BigFloat add(BigFloat a, BigFloat b) {
	//TODO handle INF and NAN

	if ((a.binaryRep[0][0] & SIGNMASK) != (b.binaryRep[0][0] & SIGNMASK)) return subt(a, b); //It's a subtraction

	if (compAbs(a, b) == -1) return add(b, a); //Reverse the numbers so the first one is bigger

	////////////////////////////////////////
	////////////HANDLING MANTISSA///////////
	////////////////////////////////////////
	BigFloat result;

	element_t exponentDiff = a.binaryRep[0][0] - b.binaryRep[0][0]; //we can ignore the sign bit because it's the same for both numbers
	char overflow = 0; //0 or 1
	for (index_t i = ARRAY_SIZE - 1; i >= 0; i--)
	{
		for (index_t j = VEC_SIZE - 1; j >= 0; j--)
		{
			if (i == 0 && j == 0) continue; //skip sign and exponent part

			//shift b to mach a exponent
			index_t blockDiff = exponentDiff / ELEMENT_TYPE_BIT_SIZE; //how much blocks should be shifted right
			shift_t extraShift = exponentDiff % ELEMENT_TYPE_BIT_SIZE; //how much bits should be shifted right in the last block
			index_t rightIndex = i * VEC_SIZE + j;
			if (rightIndex < 1 + blockDiff) { rightIndex = 0; }
			else { rightIndex -= blockDiff; }
			//index of the right side of the current block
			index_t iIndex = rightIndex / VEC_SIZE;
			index_t jIndex = rightIndex % VEC_SIZE;

			//index of the left side of the current block
			index_t leftIndex = rightIndex - 1;
			index_t i2Index = leftIndex / VEC_SIZE;
			index_t j2Index = leftIndex % VEC_SIZE;

			element_t shiftedB;
			if (rightIndex == 0)
			{
				shiftedB = 0;
			}
			else if (leftIndex > 0)
			{
				element_t tmp = b.binaryRep[iIndex][jIndex] >> extraShift;
				element_t tmp2 = b.binaryRep[i2Index][j2Index] << (ELEMENT_TYPE_BIT_SIZE - extraShift);
				shiftedB = tmp | (extraShift > 0 ? tmp2 : 0);
			}
			else if (leftIndex == 0)
			{
				element_t tmp = b.binaryRep[iIndex][jIndex] >> extraShift;
				element_t tmp2 = 1 << (ELEMENT_TYPE_BIT_SIZE - extraShift);
				shiftedB = tmp | (extraShift > 0 ? tmp2 : 0);
			}

			result.binaryRep[i][j] = a.binaryRep[i][j] + shiftedB + overflow;
			overflow = (overflow + a.binaryRep[i][j] + shiftedB) < a.binaryRep[i][j];
		}
	}

	if (exponentDiff == 0) overflow = 1;

	if (overflow)
	{
		for (index_t i = ARRAY_SIZE - 1; i >= 0; i--)
		{
			for (index_t j = VEC_SIZE - 1; j >= 0; j--)
			{
				if (i == 0 && j == 0) continue; //skip sign and exponent

				//shift result to mach exponent
				index_t rightIndex = i * VEC_SIZE + j;
				//index of the right side of the current block
				index_t iIndex = rightIndex / VEC_SIZE;
				index_t jIndex = rightIndex % VEC_SIZE;

				//index of the left side of the current block
				index_t leftIndex = rightIndex - 1;
				index_t i2Index = leftIndex / VEC_SIZE;
				index_t j2Index = leftIndex % VEC_SIZE;

				element_t shiftedResult;
				if (leftIndex > 0)
				{
					element_t tmp = result.binaryRep[iIndex][jIndex] >> 1;
					element_t tmp2 = result.binaryRep[i2Index][j2Index] << (ELEMENT_TYPE_BIT_SIZE-1);
					shiftedResult = tmp | tmp2;
				}
				else if (leftIndex == 0)
				{
					shiftedResult = result.binaryRep[iIndex][jIndex] >> 1;
				}

				result.binaryRep[i][j] = shiftedResult;
			}
		}
	}
	
	////////////////////////////////////////
	///////HANDLING SIGN AND EXPONENT///////
	////////////////////////////////////////
	result.binaryRep[0][0] = a.binaryRep[0][0] + overflow;

	//TODO handle INF and NAN

	return result;
}
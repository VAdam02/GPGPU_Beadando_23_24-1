#define FLOAT_PLUSINF 0x7F800000
#define FLOAT_MINUSINF 0xFF800000
#define FLOAT_EFFECTIVELYZERO 0.0f

#define SIGNMASK 0x80000000
#define EXPBIGSMALLMASK 0x40000000
#define BIG_FLOATNOTSTOREEXPMASK 0x3FFFFF00

// (4 * 32bit) * 2 = 256bit
typedef struct {
	uint4 binaryRep[2];
} BigFloat;

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
BigFloat subst(BigFloat a, BigFloat b) {
	//TODO handle INF and NAN

	//FIXME invert one of the sign bits
	if ((a.binaryRep[0][0] & 0x80000000) != (b.binaryRep[0][0] & 0x80000000)) return add(a, b); //It's an addition

	if (compAbs(a, b) == -1) return subst(b, a); //FIXME sign bit change needed

	////////////////////////////////////////
	////////////HANDLING MANTISSA///////////
	////////////////////////////////////////
	BigFloat result;
	int exponentDiff = a.binaryRep[0][0] - b.binaryRep[0][0]; //we can ignore the sign bit because it's the same for both numbers
	char overflow = 0; //0 or 1
	for (int i = sizeof(result.binaryRep) - 1; i >= 0; i--)
	{
		for (int j = sizeof(result.binaryRep[i]) - 1; j >= 0; j--)
		{
			if (i == 0 && j == 0) continue; //skip sign and exponent

			result.binaryRep[i][j] = a.binaryRep[i][j] - overflow - (b.binaryRep[i][j] >> exponentDiff);
			overflow = a.binaryRep[i][j] < (b.binaryRep[i][j] >> exponentDiff) + overflow;
		}
	}

	////////////////////////////////////////
	///////HANDLING SIGN AND EXPONENT///////
	////////////////////////////////////////
	//sign bit is OK
	//FIXME may the first bit of the mantissa is 0 so normalise it

	return result;
}

/**
 * Adds two BigFloats
 * @param a Left side of the addition
BigFloat add(BigFloat a, BigFloat b) {
	//TODO handle INF and NAN

	if ((a.binaryRep[0][0] & SIGNMASK) != (b.binaryRep[0][0] & SIGNMASK)) return subst(a, b); //It's a subtraction

	if (compAbs(a, b) == -1) return add(b, a); //Reverse the numbers so the first one is bigger

	////////////////////////////////////////
	////////////HANDLING MANTISSA///////////
	////////////////////////////////////////
	BigFloat result;

	element_t exponentDiff = a.binaryRep[0][0] - b.binaryRep[0][0]; //we can ignore the sign bit because it's the same for both numbers
	char overflow = 0; //0 or 1
	for (index_t i = ARRAY_SIZE - 1; i >= 0; i--)
	{
		for (char j = (sizeof(result.binaryRep[i]) / sizeof(result.binaryRep[i][0])) - 1; j >= 0; j--)
		{
			if (i == 0 && j == 0) continue; //skip sign and exponent part

			//shift b to mach a exponent
			if (rightIndex < 1 + blockDiff) { rightIndex = 0; }
			else { rightIndex -= blockDiff; }
			//index of the right side of the current block
			unsigned int jIndex = rightIndex % (sizeof(result.binaryRep[i]) / sizeof(result.binaryRep[i][j]));
			index_t jIndex = rightIndex % VEC_SIZE;

			//index of the left side of the current block
			index_t i2Index = leftIndex / VEC_SIZE;
			index_t j2Index = leftIndex % VEC_SIZE;

			unsigned int shiftedB;
			if (rightIndex == 0)
			{
				shiftedB = 0;
			}
			else if (leftIndex > 0)
			{
				unsigned int tmp2 = b.binaryRep[i2Index][j2Index] << (sizeof(result.binaryRep[i][j])*8 - extraShift);
				shiftedB = tmp | (extraShift > 0 ? tmp2 : 0);
			}
			else if (leftIndex == 0)
			{
				unsigned int tmp2 = 1 << (sizeof(result.binaryRep[i][j])*8 - extraShift);
				shiftedB = tmp | (extraShift > 0 ? tmp2 : 0);
			}

			result.binaryRep[i][j] = overflow + a.binaryRep[i][j] + shiftedB;
			overflow = (overflow + a.binaryRep[i][j] + shiftedB) < a.binaryRep[i][j];
		}
	}

	if (exponentDiff == 0) overflow = 1;

	if (overflow)
	{
		for (index_t i = ARRAY_SIZE - 1; i >= 0; i--)
		{
			for (char j = (sizeof(result.binaryRep[i]) / sizeof(result.binaryRep[i][0])) - 1; j >= 0; j--)
			{
				if (i == 0 && j == 0) continue; //skip sign and exponent

				//shift result to mach exponent
				index_t rightIndex = i * VEC_SIZE + j;
				//index of the right side of the current block
				unsigned int jIndex = rightIndex % (sizeof(result.binaryRep[i]) / sizeof(result.binaryRep[i][j]));
				index_t jIndex = rightIndex % VEC_SIZE;

				//index of the left side of the current block
				index_t i2Index = leftIndex / VEC_SIZE;
				index_t j2Index = leftIndex % VEC_SIZE;

				unsigned int shiftedResult;
				element_t shiftedResult;
				if (leftIndex > 0)
				{
					unsigned int tmp2 = result.binaryRep[i2Index][j2Index] << (sizeof(result.binaryRep[i][j])*8-1);
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

	return result;
}
////////////////////CONFIG////////////////////
typedef	uint	element_t;			//element_t.maxVal >= ELEMENT_TYPE_BIT_SIZE * VEC_SIZE * ARRAY_SIZE
typedef uint4	array_vec_t;		//sizeof(array_vec_t[0]) == sizeof(element_t)

typedef ulong	element_t_double;	//element_t_double.maxVal >= element_t.maxVal * element_t.maxVal
typedef	char	index_t;			//index_t.maxVal >= ARRAY_SIZE * VEC_SIZE
typedef char	shift_t;			//shift_t.maxVal >= ELEMENT_TYPE_BIT_SIZE

#define	ARRAY_SIZE	2	//sizeof(BigFloat) == ARRAY_SIZE * VEC_SIZE * ELEMENT_TYPE_BIT_SIZE
////////////////////CONFIG////////////////////

#define ELEMENT_TYPE_BIT_SIZE (sizeof(element_t) * 8)
#define VEC_SIZE (sizeof(array_vec_t) / sizeof(element_t))

#define SIGNMASK (~((~((element_t)0)) >> 1))
#define EXPBIGSMALLMASK (SIGNMASK >> 1)
#define EXPLOWMASK (((~((element_t)0)) & (~SIGNMASK) & (~EXPBIGSMALLMASK)))
#define EXPFULLMASK (EXPBIGSMALLMASK | EXPLOWMASK)
#define BIG_FLOATNOTSTOREEXPMASK ((~((element_t)0xFF)) & (~SIGNMASK) & (~EXPBIGSMALLMASK))

#define FLOAT_PLUSINF 0x7F800000
#define FLOAT_MINUSINF 0xFF800000
#define FLOAT_NAN 0x7FC00000
#define FLOAT_EFFECTIVELYZERO 0.0f

#define makeItEmpty_BigFloat(name) \
	for (index_t empty_BigFloat_i = 0; empty_BigFloat_i < ARRAY_SIZE; empty_BigFloat_i++) \
	for (index_t empty_BigFloat_j = 0; empty_BigFloat_j < VEC_SIZE; empty_BigFloat_j++) \
		name.binaryRep[empty_BigFloat_i][empty_BigFloat_j] = 0;

#define deepCopy_BigFloat(valueToCopy, valueFromCopy) \
	for (index_t deepCopy_BigFloat_ij = 0; deepCopy_BigFloat_ij < ARRAY_SIZE * VEC_SIZE; deepCopy_BigFloat_ij++) \
		valueToCopy.binaryRep[deepCopy_BigFloat_ij / VEC_SIZE][deepCopy_BigFloat_ij % VEC_SIZE] = valueFromCopy.binaryRep[deepCopy_BigFloat_ij / VEC_SIZE][deepCopy_BigFloat_ij % VEC_SIZE];

#define handleZeroCase(bigfloatToCheck, returnValIfZero) \
	bool handleZeroCase_isZero = true; \
	for (index_t handleZeroCase_ij = 0; handleZeroCase_ij < ARRAY_SIZE * VEC_SIZE; handleZeroCase_ij++) \
		if (bigfloatToCheck.binaryRep[handleZeroCase_ij / VEC_SIZE][handleZeroCase_ij % VEC_SIZE] != 0) \
			handleZeroCase_isZero = false; \
	if (handleZeroCase_isZero) return returnValIfZero;



typedef struct {
	array_vec_t binaryRep[ARRAY_SIZE];
} BigFloat;

float toFloat(BigFloat a);
bool isNum(BigFloat a);
bool isInf(BigFloat a);
bool isNan(BigFloat a);
bool isZero(BigFloat a);
char compAbs(BigFloat a, BigFloat b);
char comp(BigFloat a, BigFloat b);
BigFloat div(BigFloat a, BigFloat b);
BigFloat mult(BigFloat a, BigFloat b);
BigFloat subt(BigFloat a, BigFloat b);
BigFloat add(BigFloat a, BigFloat b);

/**
 * Converts a BigFloat to a float
 * @param a Value to convert
 * @return float value
 */
float toFloat(BigFloat a)
{
	if ((a.binaryRep[0][0] & BIG_FLOATNOTSTOREEXPMASK) != 0 || isInf(a)) return (a.binaryRep[0][0] & SIGNMASK) ? FLOAT_MINUSINF : FLOAT_PLUSINF;
	if (isNan(a)) return FLOAT_NAN;

	unsigned int tmp = (a.binaryRep[0][0] & SIGNMASK); //1bit sign
	tmp |= (a.binaryRep[0][0] & EXPBIGSMALLMASK) << 1; //1bit highest exponent bit
	tmp |= (a.binaryRep[0][0] & 0x7F) << 23; //7bit low exponent
	tmp |= a.binaryRep[0][1] >> 9; //23bit mantissa //FIXME

	return as_float(tmp);
}

/**
 * Converts a float to a BigFloat
 * @param a Value to convert
 * @return BigFloat value
 */
BigFloat fromFloat(float a)
{
	BigFloat result;
	makeItEmpty_BigFloat(result);

	unsigned int tmp = as_uint(a);

	result.binaryRep[0][0] = (tmp & SIGNMASK); //1bit sign
	result.binaryRep[0][0] |= (tmp & 0x40000000); //1bit highest exponent bit
	result.binaryRep[0][0] |= (tmp & 0x3F800000) >> 23; //7bit low exponent
	result.binaryRep[0][1] = (tmp & 0x007FFFFF) << 9; //23bit mantissa //FIXME

	return result;
}

/**
 * Check if a BigFloat is a number (not NaN or INF)
 * @param a Value to check
 * @return true if a is a number, false otherwise
 */
bool isNum(BigFloat a)
{
	return (a.binaryRep[0][0] & EXPFULLMASK) != EXPFULLMASK;
}

/**
 * Checks if a BigFloat is INF
 * @param a Value to check
 * @return true if a is INF, false otherwise
 */
bool isInf(BigFloat a)
{
	if (isNum(a)) return false;
	for (index_t ij = 1; ij < ARRAY_SIZE * VEC_SIZE; ij++)
		if (a.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] != 0)
			return false;
	return true;
}

/**
 * Checks if a BigFloat is NaN
 * @param a Value to check
 * @return true if a is NaN, false otherwise
 */
bool isNan(BigFloat a) {
	return !isNum(a) && !isInf(a);
}

/**
 * Check if a BigFloat is zero
 * @param a Value to compare
 * @return true if a is zero, false otherwise
 */
bool isZero(BigFloat a) {
	for (index_t ij = 0; ij < ARRAY_SIZE * VEC_SIZE; ij++)
		if (a.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] != 0)
			return false;
	return true;
}

/**
 * Compares two BigFloats' absolute value
 * @param a First value
 * @param b Second value
 * @return 1 if |a| > |b|, -1 if |a| < |b|, 0 if |a| == |b|
 */
char compAbs(BigFloat a, BigFloat b) {
	//exponent
	if ((a.binaryRep[0][0] & EXPFULLMASK) > (b.binaryRep[0][0] & EXPFULLMASK)) return 1;
	if ((a.binaryRep[0][0] & EXPFULLMASK) < (b.binaryRep[0][0] & EXPFULLMASK)) return -1;

	//mantissa
	for (index_t ij = 1; ij < ARRAY_SIZE * VEC_SIZE; ij++) {
		if (a.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] > b.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE]) return 1;
		if (a.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] < b.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE]) return -1;
	}

	return 0;
}

/**
 * Compares two BigFloats
 * @param a First value
 * @param b Second value
 * @return 1 if a > b, -1 if a < b, 0 if a == b
 */
char comp(BigFloat a, BigFloat b) {
	//sign bit
	if ((a.binaryRep[0][0] & SIGNMASK) < (b.binaryRep[0][0] & SIGNMASK)) return 1;
	if ((a.binaryRep[0][0] & SIGNMASK) > (b.binaryRep[0][0] & SIGNMASK)) return -1;

	if (a.binaryRep[0][0] & SIGNMASK) return -compAbs(b, a);
	else return compAbs(a, b);
}

/**
 * Divides two BigFloats
 * @param a Left side of the division
 * @param b Right side of the division
 * @return a / b
 */
BigFloat div(BigFloat a, BigFloat b) {
	//TODO handle INF and NAN

	element_t b_ceil = (b.binaryRep[0][0] & EXPFULLMASK); //not rounded
	for (index_t ij = 1; ij < ARRAY_SIZE * VEC_SIZE; ij++) {
		if (b.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] != 0)
		{
			b_ceil++;
			break; //rounded up
		}
	}

	BigFloat result;
	makeItEmpty_BigFloat(result);

	BigFloat a_new = a;
	while (true) {
		element_t a_floor = (a_new.binaryRep[0][0] & EXPFULLMASK) << ELEMENT_TYPE_BIT_SIZE; //rounded down
		element_t div = a_floor - b_ceil + EXPBIGSMALLMASK - 1;

		BigFloat partialResult;
		makeItEmpty_BigFloat(partialResult);
		partialResult.binaryRep[0][0] = div;

		BigFloat ref = result;

		result = add(result, partialResult);
		a_new = subt(a_new, mult(partialResult, b));

		if (comp(ref, result) == 0) break; //stop, if no change
		if (isZero(a_new)) break; //stop if solved
	}

	return result;
}

/**
 * Multiplies two BigFloats
 * @param a Left side of the multiplication
 * @param b Right side of the multiplication
 * @return a * b
 */
BigFloat mult(BigFloat a, BigFloat b) {
	//TODO handle INF and NAN

	if (compAbs(a, b) == -1) return mult(b, a); //Reverse the numbers so the first one is bigger

	BigFloat result;
	makeItEmpty_BigFloat(result);

	element_t exp_a = a.binaryRep[0][0] & EXPFULLMASK;
	element_t exp_b = b.binaryRep[0][0] & EXPFULLMASK;

	//TODO make it look better
	for (index_t i = ARRAY_SIZE - 1; i >= 0; i--)
	for (index_t k = ARRAY_SIZE - 1; k >= 0; k--)
	for (index_t j = VEC_SIZE   - 1; j >= 0; j--)
	for (index_t l = VEC_SIZE   - 1; l >= 0; l--)
	{
		//TODO underflow if exp_a is small
		element_t exp_a_block = exp_a - ELEMENT_TYPE_BIT_SIZE * VEC_SIZE * i - ELEMENT_TYPE_BIT_SIZE * j;

		//TODO underflow if exp_a is small
		element_t exp_b_block = exp_b - ELEMENT_TYPE_BIT_SIZE * VEC_SIZE * k - ELEMENT_TYPE_BIT_SIZE * l;

		element_t a_block = (i == 0 && j == 0) ? (k == 0 && l == 0) ? 1 : 1 : a.binaryRep[i][j];
		if (a_block == 0) continue; //skip if 0

		element_t b_block = (k == 0 && l == 0) ? (i == 0 && j == 0) ? 1 : 1 : b.binaryRep[k][l];
		if (b_block == 0) continue; //skip if 0

		element_t_double exp = (element_t_double)exp_a_block + (element_t_double)exp_b_block - (element_t_double)EXPLOWMASK;
		element_t_double mult = (element_t_double)a_block * (element_t_double)b_block;
		
		//TODO make it work with any bitsize
		if (mult <= 0x00000000FFFFFFFF) { mult <<= 32; exp -= 32; } //00000000 00000001
		if (mult <= 0x0000FFFF00000000) { mult <<= 16; exp -= 16; } //00000001 00000000
		if (mult <= 0x00FF000000000000) { mult <<= 8;  exp -=  8; } //00010000 00000000
		if (mult <= 0x0F00000000000000) { mult <<= 4;  exp -=  4; } //01000000 00000000
		if (mult <= 0x3000000000000000) { mult <<= 2;  exp -=  2; } //10000000 00000000
		if (mult <= 0x4000000000000000) { mult <<= 1;  exp -=  1; } //40000000 00000000
		if (mult <= 0x8000000000000000) { mult <<= 1;  exp -=  1; } //80000000 00000000
		//00000000 00000000
		exp += 2 * ELEMENT_TYPE_BIT_SIZE;


		BigFloat tmp2;
		makeItEmpty_BigFloat(tmp2);
		//TODO make it work with any vec size
		tmp2.binaryRep[0][0] = exp & EXPFULLMASK;
		tmp2.binaryRep[0][1] = mult >> ELEMENT_TYPE_BIT_SIZE;
		tmp2.binaryRep[0][2] = mult;
		result = add(result, tmp2);
	}

	//sign bit
	element_t signbit = (a.binaryRep[0][0] & SIGNMASK) != (b.binaryRep[0][0] & SIGNMASK);
	result.binaryRep[0][0] = (signbit << (ELEMENT_TYPE_BIT_SIZE-1)) | (result.binaryRep[0][0] & ~SIGNMASK);

	//TODO handle INF and NAN

	return result;
}

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
	////////HANDLING EFFECTIVELY ZERO///////
	////////////////////////////////////////
	handleZeroCase(b, a);

	////////////////////////////////////////
	////////////HANDLING MANTISSA///////////
	////////////////////////////////////////
	BigFloat result;

	element_t exponentDiff = a.binaryRep[0][0] - b.binaryRep[0][0]; //we can ignore the sign bit because it's the same for both numbers
	char overflow = 0; //0 or 1
	
	//TODO make it look better
	for (index_t i = ARRAY_SIZE - 1; i >= 0; i--)
	{
		for (index_t j = VEC_SIZE - 1; j >= 0; j--)
		{
			if (i == 0 && j == 0) continue; //skip sign and exponent part

			//TODO it can be negative if the two numbers are close enough
			element_t localExponent = exponentDiff + (i * VEC_SIZE + j) * ELEMENT_TYPE_BIT_SIZE;
			//how much B bits need to be shifted right
			index_t b_shift_block = localExponent / ELEMENT_TYPE_BIT_SIZE;
			shift_t b_shift_bit = localExponent % ELEMENT_TYPE_BIT_SIZE;

			index_t b_left_i = (b_shift_block - 1) / VEC_SIZE;
			if (b_left_i >= ARRAY_SIZE) b_left_i = -1;
			index_t b_left_j = (b_shift_block - 1) % VEC_SIZE;
			element_t b_left = (b_left_i == 0 && b_left_j == 0) ? 1 : (((element_t)-1 ^ ((element_t)-1 >> 1)) & b_left_i ? 0 : b.binaryRep[b_left_i][b_left_j]);
			index_t b_right_i = b_shift_block / VEC_SIZE;
			if (b_right_i >= ARRAY_SIZE) b_right_i = -1;
			index_t b_right_j = b_shift_block % VEC_SIZE;
			element_t b_right = (b_right_i == 0 && b_right_j == 0) ? 1 : (((element_t)-1 ^ ((element_t)-1 >> 1)) & b_right_i) ? 0 : b.binaryRep[b_right_i][b_right_j];

			element_t shiftedB = (b_shift_bit ? (b_left << (ELEMENT_TYPE_BIT_SIZE - b_shift_bit)) : 0) | (b_right >> b_shift_bit);

			result.binaryRep[i][j] = a.binaryRep[i][j] - shiftedB - overflow;
			overflow = (a.binaryRep[i][j] - shiftedB - overflow) > a.binaryRep[i][j];
		}
	}

	////////////////////////////////////////
	///////HANDLING SIGN AND EXPONENT///////
	////////////////////////////////////////
	if (exponentDiff == 0 || overflow) {
		index_t emptyBlocks = 0;
		element_t val = 0;
		for (index_t ij = 1; ij < ARRAY_SIZE * VEC_SIZE; ij++) {
			if (result.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] == 0) emptyBlocks++;
			else
			{
				val = result.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE];
				break;
			}
		}

		shift_t emptyBits = 0;
		if (val != 0)
		{
			if (val <= 0x0000FFFF) { val <<= 16; emptyBits += 16; } //00000001
			if (val <= 0x00FFFFFF) { val <<= 8;  emptyBits +=  8; } //00010000
			if (val <= 0x0FFFFFFF) { val <<= 4;  emptyBits +=  4; } //01000000
			if (val <= 0x3FFFFFFF) { val <<= 2;  emptyBits +=  2; } //10000000
			if (val <= 0x7FFFFFFF) { val <<= 1;  emptyBits +=  1; } //40000000
			if (val <= 0xFFFFFFFF) { val <<= 1;  emptyBits +=  1; } //80000000
			//TODO make it work with any bitsize

			if (emptyBits > 0)
				for (index_t ij = emptyBlocks + 1; ij < ARRAY_SIZE * VEC_SIZE; ij++) {
					element_t result_left = result.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE];
					element_t result_right = ij+1 < ARRAY_SIZE * VEC_SIZE ? result.binaryRep[(ij + 1) / VEC_SIZE][(ij + 1) % VEC_SIZE] : 0;
					result.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] = (result_left << emptyBits) | (result_right >> (ELEMENT_TYPE_BIT_SIZE - emptyBits));
				}

			result.binaryRep[0][0] = (a.binaryRep[0][0] & EXPFULLMASK) - (emptyBlocks * ELEMENT_TYPE_BIT_SIZE + emptyBits);
		}
		else result.binaryRep[0][0] = 0; //won't happen with overflow
	}
	else result.binaryRep[0][0] = a.binaryRep[0][0];

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
	////////HANDLING EFFECTIVELY ZERO///////
	////////////////////////////////////////
	handleZeroCase(b, a);

	////////////////////////////////////////
	////////////HANDLING MANTISSA///////////
	////////////////////////////////////////
	BigFloat result;

	//TODO maybe problem with EXPBIGSMALLMASK
	element_t exponentDiff = a.binaryRep[0][0] - b.binaryRep[0][0]; //we can ignore the sign bit because it's the same for both numbers
	char overflow = 0; //0 or 1
	//TODO make it look better
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
		//TODO make it look better
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
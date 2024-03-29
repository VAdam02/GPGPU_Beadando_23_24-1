////////////////////CONFIG////////////////////
typedef	uint	element_t;			//element_t.maxVal >= ELEMENT_TYPE_BIT_SIZE * VEC_SIZE * ARRAY_SIZE
typedef uint4	array_vec_t;		//sizeof(array_vec_t[0]) == sizeof(element_t)

typedef ulong	element_t_double;	//element_t_double.maxVal >= element_t.maxVal * element_t.maxVal
typedef	char	index_t;			//index_t.maxVal >= ARRAY_SIZE * VEC_SIZE
typedef char	shift_t;			//shift_t.maxVal >= ELEMENT_TYPE_BIT_SIZE

#define	ARRAY_SIZE	1	//sizeof(BigFloat) == ARRAY_SIZE * VEC_SIZE * ELEMENT_TYPE_BIT_SIZE
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
	for (index_t empty_BigFloat_ij = 0; empty_BigFloat_ij < ARRAY_SIZE * VEC_SIZE; empty_BigFloat_ij++) \
		name.binaryRep[empty_BigFloat_ij / VEC_SIZE][empty_BigFloat_ij % VEC_SIZE] = 0;

#define makeItNaN_BigFloat(name) \
	for (index_t nan_BigFloat_ij = 0; nan_BigFloat_ij < ARRAY_SIZE * VEC_SIZE; nan_BigFloat_ij++) \
		name.binaryRep[nan_BigFloat_ij / VEC_SIZE][nan_BigFloat_ij % VEC_SIZE] = 0xFFFFFFFF;

#define makeItInf_BigFloat(name, sign) \
	for (index_t inf_BigFloat_ij = 1; inf_BigFloat_ij < ARRAY_SIZE * VEC_SIZE; inf_BigFloat_ij++) \
		name.binaryRep[inf_BigFloat_ij / VEC_SIZE][inf_BigFloat_ij % VEC_SIZE] = 0; \
	name.binaryRep[0][0] = (sign << 31) | EXPBIGSMALLMASK;

#define deepCopy_BigFloat(valueToCopy, valueFromCopy) \
	for (index_t deepCopy_BigFloat_ij = 0; deepCopy_BigFloat_ij < ARRAY_SIZE * VEC_SIZE; deepCopy_BigFloat_ij++) \
		valueToCopy.binaryRep[deepCopy_BigFloat_ij / VEC_SIZE][deepCopy_BigFloat_ij % VEC_SIZE] = valueFromCopy.binaryRep[deepCopy_BigFloat_ij / VEC_SIZE][deepCopy_BigFloat_ij % VEC_SIZE];

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
float toFloat(BigFloat a) {
	if ((a.binaryRep[0][0] & EXPBIGSMALLMASK) && (a.binaryRep[0][0] & BIG_FLOATNOTSTOREEXPMASK) > 0) return (a.binaryRep[0][0] & SIGNMASK) ? FLOAT_MINUSINF : FLOAT_PLUSINF;
	if (isNan(a)) return FLOAT_NAN;
	if (isZero(a)) return FLOAT_EFFECTIVELYZERO;

	unsigned int tmp = (a.binaryRep[0][0] & EXPBIGSMALLMASK); //1bit highest exponent bit
	tmp |= (a.binaryRep[0][0] & 0x7F) << 23; //7bit low exponent
	unsigned int roundedMantissa = (0x01000000 + (a.binaryRep[0][1] >> 8) + 1) >> 1; //implicit 1 + 24 bit mantissa -> implicit 1 + 23-24 bit mantissa
	if (roundedMantissa & 0xFF000000)
	{
		roundedMantissa = roundedMantissa >> 1;
		tmp += 0x00800000;
	}
	tmp |= roundedMantissa & 0x007FFFFF; //23 bit mantissa
	if (tmp & 0x80000000) tmp = 0x7F800000; //INF
	if (tmp == 0x7F800000) tmp = 0x7FC00000; //NAN
	tmp |= (a.binaryRep[0][0] & SIGNMASK);


	return as_float(tmp);
}

/**
 * Converts a float to a BigFloat
 * @param a Value to convert
 * @return BigFloat value
 */
BigFloat fromFloat(float a) {
	BigFloat result;
	makeItEmpty_BigFloat(result);

	unsigned int tmp = as_uint(a);

	uint sign = (tmp >> 31) & 0x1;
	uint bigSmallExp = (tmp >> 30) & 0x1;
	uint exponent = (tmp >> 23) & 0x7F;
	uint mantissa = tmp & 0x007FFFFF;

	result.binaryRep[0][0] = sign << 31;
	result.binaryRep[0][0] |= bigSmallExp << 30;
	result.binaryRep[0][0] |= exponent;
	if (bigSmallExp == 0 && a != 0.0f) result.binaryRep[0][0] |= 0x3FFFFF80;
	
	result.binaryRep[0][1] = mantissa << 9;

	return result;
}

/**
 * Check if a BigFloat is a number (not NaN or INF)
 * @param a Value to check
 * @return true if a is a number, false otherwise
 */
bool isNum(BigFloat a) {
	return (a.binaryRep[0][0] & EXPFULLMASK) != EXPFULLMASK;
}

/**
 * Checks if a BigFloat is INF
 * @param a Value to check
 * @return true if a is INF, false otherwise
 */
bool isInf(BigFloat a) {
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
	if (a.binaryRep[0][0] & EXPFULLMASK) return false;
	for (index_t ij = 1; ij < ARRAY_SIZE * VEC_SIZE; ij++)
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
	//handling special cases
	if (isNan(b)) return b;
	if (isInf(a)) return a;
	if (isZero(b)) {
		BigFloat result;
		makeItNaN_BigFloat(result);
		return result;
	}
	if (isZero(a)) return a;

	//rounding up B and get the exponent
	element_t b_ceil = (b.binaryRep[0][0] & EXPFULLMASK); //not rounded
	for (index_t ij = 1; ij < ARRAY_SIZE * VEC_SIZE; ij++)
		if (b.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] != 0) {
			b_ceil++;
			break; //rounded up
		}

	BigFloat result;
	makeItEmpty_BigFloat(result);

	BigFloat a_new = a;
	int i = 0;
	while (i < (ARRAY_SIZE * VEC_SIZE - 1) * ELEMENT_TYPE_BIT_SIZE) {
		//A / B = C -> ~A / ~B = D -> A - (D * B) =: A iteratively and the result is SUM(D)

		//rounding down A and get the exponent
		element_t a_floor = (a_new.binaryRep[0][0] & EXPFULLMASK) << ELEMENT_TYPE_BIT_SIZE; //rounded down
		element_t div = a_floor - b_ceil + EXPBIGSMALLMASK - 1;

		BigFloat partialResult;
		makeItEmpty_BigFloat(partialResult);
		partialResult.binaryRep[0][0] = div;

		BigFloat ref = result; //previous result

		result = add(result, partialResult); //final result
		a_new = subt(a_new, mult(partialResult, b)); //new A

		if (comp(ref, result) == 0) break; //stop, if no change
		if (isZero(a_new)) {
			result.binaryRep[0][0] -= 1;
			break; //stop if solved
		}
		i++;
	}

	result.binaryRep[0][0] = (result.binaryRep[0][0] & EXPFULLMASK) | (SIGNMASK * ((a.binaryRep[0][0] & SIGNMASK) != (b.binaryRep[0][0] & SIGNMASK))); //sign bit

	if (isNan(result)) { //if the result is too big it will be NaN so to make it accureta transform it to INF
		element_t sign = result.binaryRep[0][0] >> (ELEMENT_TYPE_BIT_SIZE - 1) & 0x1;
		makeItInf_BigFloat(result, sign);
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
	//if |A| < |B| than convert it to B * A for easier handling
	if (compAbs(a, b) == -1) return mult(b, a);

	//handling special cases
	if (isInf(a)) return a;
	if (isNan(b)) return b;
	if (isZero(b)) return a;

	BigFloat result;
	makeItEmpty_BigFloat(result);

	if (isZero(b)) return result; //A * 0 = 0

	for (index_t ij = ARRAY_SIZE * VEC_SIZE - 1; ij >= 0; ij--)
	for (index_t kl = ARRAY_SIZE * VEC_SIZE - 1; kl >= 0; kl--) {
		//iterating over each block off A and for each block iterating over each block of B and multiplying them

		element_t exp_a_block = (a.binaryRep[0][0] & EXPFULLMASK) - ELEMENT_TYPE_BIT_SIZE * ij; //exponent of the current block of A
		element_t exp_b_block = (b.binaryRep[0][0] & EXPFULLMASK) - ELEMENT_TYPE_BIT_SIZE * kl; //exponent of the current block of B

		//check if any of the blocks is 0 beacuse X * 0 = 0
		element_t a_block = (ij == 0) ? 1 : a.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE];
		if (a_block == 0) continue; //skip if 0

		element_t b_block = (kl == 0) ? 1 : b.binaryRep[kl / VEC_SIZE][kl % VEC_SIZE];
		if (b_block == 0) continue; //skip if 0

		//calculate the exponent and the mantissa of the result
		element_t_double exp = (element_t_double)exp_a_block + (element_t_double)exp_b_block - (element_t_double)EXPLOWMASK;
		element_t_double mult = (element_t_double)a_block * (element_t_double)b_block;

		if (mult != 0) exp += ELEMENT_TYPE_BIT_SIZE * 2;

		//the result is processed with a double as basicly size type so align the bits to make the first to the implicit 1
		if (mult <= 0x00000000FFFFFFFF) { mult <<= 32; exp -= 32; } //00000000 00000001 ->   00000001 00000000
		if (mult <= 0x0000FFFFFFFFFFFF) { mult <<= 16; exp -= 16; } //00000001 00000000 ->   00010000 00000000
		if (mult <= 0x00FFFFFFFFFFFFFF) { mult <<= 8;  exp -=  8; } //00010000 00000000 ->   01000000 00000000
		if (mult <= 0x0FFFFFFFFFFFFFFF) { mult <<= 4;  exp -=  4; } //01000000 00000000 ->   10000000 00000000
		if (mult <= 0x3FFFFFFFFFFFFFFF) { mult <<= 2;  exp -=  2; } //10000000 00000000	->   40000000 00000000
		if (mult <= 0x7FFFFFFFFFFFFFFF) { mult <<= 1;  exp -=  1; } //40000000 00000000 ->   80000000 00000000
		if (mult <= 0xFFFFFFFFFFFFFFFF) { mult <<= 1;  exp -=  1; } //80000000 00000000 -> 1 00000000 00000000

		//adding the result to the final result
		BigFloat tmp;
		makeItEmpty_BigFloat(tmp);
		tmp.binaryRep[0][0] = exp & EXPFULLMASK;
		tmp.binaryRep[0][1] = mult >> ELEMENT_TYPE_BIT_SIZE;
		tmp.binaryRep[0][2] = mult;

		result = add(result, tmp);
	}

	////////////////////////////////////////
	/////////////HANDLING SIGN//////////////
	////////////////////////////////////////
	element_t signbit = (a.binaryRep[0][0] & SIGNMASK) != (b.binaryRep[0][0] & SIGNMASK);
	result.binaryRep[0][0] = (signbit << (ELEMENT_TYPE_BIT_SIZE-1)) | (result.binaryRep[0][0] & EXPFULLMASK);

	if (isNan(result)) { //if the result is too big it will be NaN so to make it accureta transform it to INF
		element_t sign = result.binaryRep[0][0] >> (ELEMENT_TYPE_BIT_SIZE - 1) & 0x1;
		makeItInf_BigFloat(result, sign);
	}

	return result;
}

/**
 * Subtracts two BigFloats, please note that it may cause side effects on the input values
 * @param a Left side of the subtraction
 * @param b Right side of the subtraction
 * @return a - b
 */
BigFloat subt(BigFloat a, BigFloat b) {
	//if it's a an A - (-B) than convert it to A + B
	if ((a.binaryRep[0][0] & SIGNMASK) != (b.binaryRep[0][0] & SIGNMASK)) {
		b.binaryRep[0][0] = (SIGNMASK & ~b.binaryRep[0][0]) | (~SIGNMASK & b.binaryRep[0][0]);
		return add(a, b);
	}

	//if |A| < |B| than convert it to (-B) - A for easier handling
	if (compAbs(a, b) == -1) {
		a.binaryRep[0][0] = (SIGNMASK & ~a.binaryRep[0][0]) | (~SIGNMASK & a.binaryRep[0][0]);
		b.binaryRep[0][0] = (SIGNMASK & ~b.binaryRep[0][0]) | (~SIGNMASK & b.binaryRep[0][0]);

		return subt(b, a);
	}

	//handling special cases
	if (isInf(a)) return a;
	if (isNan(b)) return b;
	if (isZero(b)) return a;

	////////////////////////////////////////
	////////////HANDLING MANTISSA///////////
	////////////////////////////////////////
	BigFloat result;

	element_t exponentDiff = a.binaryRep[0][0] - b.binaryRep[0][0]; //we can ignore the sign bit because it's the same for both numbers
	char overflow = 0; //0 or 1

	for (index_t ij = ARRAY_SIZE * VEC_SIZE - 1; ij > 0; ij--) {
		//iterating over each block off the A except the first one (the exponent) and calculating the correct mantissa part for the B to make the subtraction simple

		element_t localExponent = -exponentDiff + ij * ELEMENT_TYPE_BIT_SIZE; //exponent difference between A and B's block
		shift_t b_shift_bit = (ELEMENT_TYPE_BIT_SIZE) - (localExponent % ELEMENT_TYPE_BIT_SIZE); //how many bits need to be shifted do get the correct exponent
		index_t b_shift_block = localExponent / ELEMENT_TYPE_BIT_SIZE + ((localExponent % ELEMENT_TYPE_BIT_SIZE) != 0); //how many blocks need to be shifted

		element_t b_right; //current block with the implicit 1 if needed
		if (b_shift_block == 0) b_right = 1; //implicit 1
		else if (b_shift_block >= ARRAY_SIZE * VEC_SIZE) b_right = 0; //too right or too left
		else b_right = b.binaryRep[b_shift_block / VEC_SIZE][b_shift_block % VEC_SIZE];

		element_t b_left; //block on the left of the current block with the implicit 1 if needed
		if (b_shift_block - 1 == 0) b_left = 1; //implicit 1
		else if (b_shift_block - 1 >= ARRAY_SIZE * VEC_SIZE) b_left = 0; //too right or too left
		else b_left = b.binaryRep[(b_shift_block - 1) / VEC_SIZE][(b_shift_block - 1) % VEC_SIZE];

		element_t shiftedB = (b_shift_bit ? (b_left << (ELEMENT_TYPE_BIT_SIZE - b_shift_bit)) : 0) | (b_right >> b_shift_bit); //shiting and merging the blocks to get the block with the correct exponent

		result.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] = a.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] - shiftedB - overflow; //just subtracting the A and B's blocks
		overflow = (a.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] - shiftedB - overflow) > a.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE]; //if |A| - |B| - overflow > |A| that can't be happened in any case except there is an overflow
	}

	////////////////////////////////////////
	///////HANDLING SIGN AND EXPONENT///////
	////////////////////////////////////////
	if (exponentDiff == 0 || overflow) { //if there is an overflow or the exponents are the same that would mean there is an overflow too but it's hidden from plain sight because it would be the implicit 1
		index_t emptyBlocks = 0; //how many blocks became empty because of the small distance between the numbers
		element_t val = 0; //the value of the first non empty block if there is any
		for (index_t ij = 1; ij < ARRAY_SIZE * VEC_SIZE; ij++)
			if (result.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] == 0) emptyBlocks++;
			else {
				val = result.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE];
				break;
			}

		shift_t emptyBits = 0; //how many bits became empty in the block because of the small distance between the numbers
		if (val != 0) {
			//if there is a 1 on the right most bit how much bits need to be shifted left to make it shifted out on the left and make it the implicit 1
			//how much bits need to be shifted left to make the first 1 on the left most bit to implicit 1
			if (val <= 0x0000FFFF) { val <<= 16; emptyBits += 16; } //00000001 ->   00010000
			if (val <= 0x00FFFFFF) { val <<= 8;  emptyBits +=  8; } //00010000 ->   01000000
			if (val <= 0x0FFFFFFF) { val <<= 4;  emptyBits +=  4; } //01000000 ->   10000000
			if (val <= 0x3FFFFFFF) { val <<= 2;  emptyBits +=  2; } //10000000 ->   40000000
			if (val <= 0x7FFFFFFF) { val <<= 1;  emptyBits +=  1; } //40000000 ->   80000000
			if (val <= 0xFFFFFFFF) { val <<= 1;  emptyBits +=  1; } //80000000 -> 1 00000000

			for (index_t ij = emptyBlocks + 1; ij < ARRAY_SIZE * VEC_SIZE; ij++) {
				//iterate from the first non empty block and clear all of the empty bits from the front
				element_t result_left = result.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE]; //current block
				element_t result_right = ij+1 < ARRAY_SIZE * VEC_SIZE ? result.binaryRep[(ij + 1) / VEC_SIZE][(ij + 1) % VEC_SIZE] : 0; //block on the right of the current block
				result.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] = (result_left << emptyBits) | (result_right >> (ELEMENT_TYPE_BIT_SIZE - emptyBits)); //merging the blocks
			}

			result.binaryRep[0][0] = (a.binaryRep[0][0] - (emptyBlocks * ELEMENT_TYPE_BIT_SIZE + emptyBits)) & EXPFULLMASK; //calculating new exponent based on the shift
		}
		else result.binaryRep[0][0] = 0; //won't happen with overflow
	}
	else result.binaryRep[0][0] = a.binaryRep[0][0]; //if there is no overflow just copy the exponent

	result.binaryRep[0][0] = (result.binaryRep[0][0] & EXPFULLMASK); //clearing the sign bit

	if (!isZero(result)) result.binaryRep[0][0] |= (a.binaryRep[0][0] & SIGNMASK); //if the result is not zero copy the sign bit

	return result;
}

/**
 * Adds two BigFloats, please note that it may cause side effects on the input values
 * @param a Left side of the addition
 * @param b Right side of the addition
 * @return a + b
 */
BigFloat add(BigFloat a, BigFloat b) {
	//if it's a an A + (-B) than convert it to A - B
	if ((a.binaryRep[0][0] & SIGNMASK) != (b.binaryRep[0][0] & SIGNMASK)) {
		b.binaryRep[0][0] = (SIGNMASK & (~b.binaryRep[0][0])) | (EXPFULLMASK & b.binaryRep[0][0]);
		return subt(a, b);
	}

	//if |A| < |B| than convert it to B + A for easier handling
	if (compAbs(a, b) == -1) return add(b, a);

	//handling special cases
	if (isInf(a)) return a;
	if (isNan(b)) return b;
	if (isZero(b)) return a;

	////////////////////////////////////////
	////////////HANDLING MANTISSA///////////
	////////////////////////////////////////
	BigFloat result;

	element_t exponentDiff = a.binaryRep[0][0] - b.binaryRep[0][0]; //we can ignore the sign bit because it's the same for both numbers

	char overflow = 0; //0 or 1
	for (index_t ij = ARRAY_SIZE * VEC_SIZE - 1; ij > 0; ij--) { 
		//iterating over each block off the A except the first one (the exponent) and calculating the correct mantissa part for the B to make the addition simple

		element_t localExponent = -exponentDiff + ij * ELEMENT_TYPE_BIT_SIZE; //exponent difference between A and B's block
		shift_t b_shift_bit = (ELEMENT_TYPE_BIT_SIZE) - (localExponent % ELEMENT_TYPE_BIT_SIZE); //how many bits need to be shifted do get the correct exponent
		index_t b_shift_block = localExponent / ELEMENT_TYPE_BIT_SIZE + ((localExponent % ELEMENT_TYPE_BIT_SIZE) != 0); //how many blocks need to be shifted

		element_t b_right; //current block with the implicit 1 if needed
		if (b_shift_block == 0) b_right = 1; //implicit 1
		else if (b_shift_block >= ARRAY_SIZE * VEC_SIZE) b_right = 0; //too right or too left
		else b_right = b.binaryRep[b_shift_block / VEC_SIZE][b_shift_block % VEC_SIZE];

		element_t b_left; //block on the left of the current block with the implicit 1 if needed
		if (b_shift_block - 1 == 0) b_left = 1; //implicit 1
		else if (b_shift_block - 1 >= ARRAY_SIZE * VEC_SIZE) b_left = 0; //too right or too left
		else b_left = b.binaryRep[(b_shift_block - 1) / VEC_SIZE][(b_shift_block - 1) % VEC_SIZE];

		element_t shiftedB = (b_shift_bit ? (b_left << (ELEMENT_TYPE_BIT_SIZE - b_shift_bit)) : 0) | (b_right >> b_shift_bit); //shiting and merging the blocks to get the block with the correct exponent

		result.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] = a.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] + shiftedB + overflow; //just adding the A and B's blocks
		overflow = (overflow + a.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] + shiftedB) < a.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE]; //if |A| + |B| + overflow < |A| that can't be happened in any case except there is an overflow
	}

	if (overflow || exponentDiff == 0) //if there is an overflow or the exponents are the same that would mean there is an overflow too but it's hidden from plain sight because it would be the implicit 1
		for (index_t ij = ARRAY_SIZE * VEC_SIZE - 1; ij > 0; ij--) { //if this happens we are sure there's need to be an increase in the exponent so shift all the mantissa to the right by one
			element_t right = result.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE]; //current block
			element_t left = ((ij-1) == 0) ? (overflow && exponentDiff == 0) : result.binaryRep[(ij-1) / VEC_SIZE][(ij-1) % VEC_SIZE]; //block on the left of the current block

			result.binaryRep[ij / VEC_SIZE][ij % VEC_SIZE] = (left << (ELEMENT_TYPE_BIT_SIZE - 1)) | (right >> 1); //merging the blocks
		}
	
	////////////////////////////////////////
	///////HANDLING SIGN AND EXPONENT///////
	////////////////////////////////////////
	result.binaryRep[0][0] = a.binaryRep[0][0] + (overflow || (exponentDiff == 0)); //calculating new exponent based on every type of overflow
	
	if (isNan(result)) { //if the result is too big it will be NaN so to make it accureta transform it to INF
		element_t sign = result.binaryRep[0][0] >> (ELEMENT_TYPE_BIT_SIZE - 1) & 0x1; //get the sign bit
		makeItInf_BigFloat(result, sign); //using a define to make the transformation easier to read but keep it efficient
	}

	return result;
}
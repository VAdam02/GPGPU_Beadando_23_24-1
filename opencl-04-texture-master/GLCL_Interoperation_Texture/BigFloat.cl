typedef struct {
	int4 binaryRep[2];
} BigFloat;

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

//FIXME exponentDiff is not really okey because it's not calculating with the other bits
//FIXME abs(A) must be bigger than abs(B)
BigFloat subst(BigFloat a, BigFloat b) {
	//TODO handle INF and NAN

	//FIXME invert one of the sign bits
	if ((a.binaryRep[0][0] & 80000000) != (b.binaryRep[0][0] & 80000000)) return add(a, b); //It's an addition

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

	//FIXME may the first bit of the mantissa is 0 so normalise it

	if (overflow)
	{
		//TODO it's only can be occured if abs(A) is smaller than abs(B)
	}

	return result;
}

//FIXME exponentDiff is not really okey because it's not calculating with the other bits
//FIXME abs(A) must be bigger than abs(B)
BigFloat add(BigFloat a, BigFloat b) {
	//TODO handle INF and NAN

	if ((a.binaryRep[0][0] & 80000000) != (b.binaryRep[0][0] & 80000000)) return subst(a, b); //It's a subtraction

	////////////////////////////////////////
	////////////HANDLING MANTISSA///////////
	////////////////////////////////////////
	BigFloat result;
	int exponentDiff = a.binaryRep[0][0] - b.binaryRep[0][0]; //we can ignore the sign bit because it's the same for both numbers
	char overflow = 0; //0 or 1
	for (int i = sizeof(result.binaryRep) - 1; i >= 0; i--)
	{
		for (int j = sizeof(result.binaryRep[i]) - 1; j >= 0 ; j--)
		{
			if (i == 0 && j == 0) continue; //skip sign and exponent

			result.binaryRep[i][j] = a.binaryRep[i][j] + overflow + (b.binaryRep[i][j] >> exponentDiff);
			overflow = (a.binaryRep[i][j] + overflow) >> 31 & (b.binaryRep[i][j] >> exponentDiff) >> 31;
		}
	}
	
	if (overflow)
	{
		for (int i = sizeof(result.binaryRep) - 1; i >= 0; i--)
		{
			for (int j = sizeof(result.binaryRep[i]) - 1; j >= 0 ; j--)
			{
				if (i == 0 && j == 0) continue; //skip sign and exponent

				result.binaryRep[i][j] >>= 1;
				if (j == 0)
				{
					result.binaryRep[i][j] |= result.binaryRep[i - 1][sizeof(result.binaryRep[i - 1]) - 1] << 31;
				}
				else
				{
					result.binaryRep[i][j] |= result.binaryRep[i][j - 1] << 31;
				}
			}
		}
		result.binaryRep[0][1] |= 0x80000000;
	}

	////////////////////////////////////////
	///////HANDLING SIGN AND EXPONENT///////
	////////////////////////////////////////
	result.binaryRep[0][0] = a.binaryRep[0][0] + overflow;

	return result;
}
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

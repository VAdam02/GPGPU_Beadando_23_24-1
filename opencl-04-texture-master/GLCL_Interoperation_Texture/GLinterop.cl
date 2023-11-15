#import "BigFloat.cl"

__kernel void texture_kernel(
	__write_only image2d_t im,
	int w, int h,
	int max_iter, float scale, float x, float y)
{
	int2 coord = { get_global_id(0), get_global_id(1) };

	BigFloat a, b;
	a.binaryRep[0][0] = 0x20000000;
	a.binaryRep[0][1] = 0x0F000000;
	a.binaryRep[0][2] = 0x00F00000;
	a.binaryRep[0][3] = 0x000F0000;
	a.binaryRep[1][0] = 0x0000F000;
	a.binaryRep[1][1] = 0x00000F00;
	a.binaryRep[1][2] = 0x000000F0;
	a.binaryRep[1][3] = 0x0000000F;

	b.binaryRep[0][0] = 0x20000001;
	b.binaryRep[0][1] = 0x0F000000;
	b.binaryRep[0][2] = 0x00F00000;
	b.binaryRep[0][3] = 0x000F0000;
	b.binaryRep[1][0] = 0x0000F000;
	b.binaryRep[1][1] = 0x00000F00;
	b.binaryRep[1][2] = 0x000000F0;
	b.binaryRep[1][3] = 0x0000000F;
	// 
	//a.binaryRep[0][0] = 0x0;
	//a.binaryRep[0][1] = 0x0;
	//a.binaryRep[0][2] = 0x0;
	//a.binaryRep[0][3] = 0x0;
	//a.binaryRep[1][0] = 0x0;
	//a.binaryRep[1][1] = 0x0;
	//a.binaryRep[1][2] = 0x0;
	//a.binaryRep[1][3] = 0x0;
	//
	//a.binaryRep[0][0] = 0xFFFFFFFF;
	//a.binaryRep[0][1] = 0xFFFFFFFF;
	//a.binaryRep[0][2] = 0xFFFFFFFF;
	//a.binaryRep[0][3] = 0xFFFFFFFF;
	//a.binaryRep[1][0] = 0xFFFFFFFF;
	//a.binaryRep[1][1] = 0xFFFFFFFF;
	//a.binaryRep[1][2] = 0xFFFFFFFF;
	//a.binaryRep[1][3] = 0xFFFFFFFF;


	//a.binaryRep[0][0] = 0x0000007F; // 1.0f
	//a.binaryRep[0][0] = 0x0000007E; // 0.5f
	//a.binaryRep[0][0] = 0x0000007D; // 0.25f
	//a.binaryRep[0][0] = 0x20000007;
	//a.binaryRep[0][0] = 0x00000000; // 0.0f
	//a.binaryRep[0][0] = 0xBFFFFFFE; //-0.5f
	//a.binaryRep[0][0] = 0xBFFFFFFF; //-1.0f
	//a.binaryRep[0][0] = 0x4FFFFFFE; //TOO BIG FOR FLOAT
	//a.binaryRep[0][0] = 0x3FFFFFFE; //TOO SMALL FOR FLOAT

	//a.binaryRep[0][1] = 0xFFFFFFFF; //7F
	//a.binaryRep[0][1] = 0x00000000; //40
	
	float4 color2;
	/*
	color2 = {
		toFloat(a),
		toFloat(add(a, a)),//(toFloat(add(a, a)) - 0.25f) * 2,
		//(toFloat(add(a, a)) < 1.0f / 0.0f ? (toFloat(add(a, a)) >= 0.0f ? 0.0f : 0.5f) : 1.0f),
		(toFloat(a) < 1.0f/0.0f ? (toFloat(a) >= 0.0f ? 0.0f : 0.5f) : 1.0f),
		//0 - num; 0.5 - nan; 1 - inf
		1.0f };
	*/

	//color2.g = 7 * coord.y / (float)h;

	BigFloat disp1 = a;
	//BigFloat disp1 = add(a, a);
	//BigFloat disp2 = add(add(a, a), a);
	//BigFloat disp2 = add(a, add(a, a));
	//BigFloat disp2 = add(add(a, a), add(a, a));
	
	BigFloat disp2 = b;

	//BigFloat disp2 = subt(add(a, a), a);
	BigFloat disp3 = subt(a, b);
	//BigFloat disp2 = b;

	float xindex = 24-(24 * coord.y / (float)h);
	float yindex = (32 * coord.x / (float)w);

	int tmp;

	if (xindex < 8) {
		tmp = disp1.binaryRep[(int)((xindex) / 4)][(int)(xindex) % 4];
	}
	else if (xindex < 16)
	{
		tmp = disp2.binaryRep[(int)((xindex - 8) / 4)][(int)(xindex - 8) % 4];
	}
	else {
		//tmp = add(add(a, a), add(a, a)).binaryRep[(int)((xindex-8) / 4)][(int)(xindex-8) % 4];
		tmp = disp3.binaryRep[(int)((xindex - 16) / 4)][(int)(xindex - 16) % 4];
	}
	
	color2.r = ((tmp << (int)(yindex)) & 0x80000000);

	float width = 0.25;
	float asd = yindex + width / 2;
	float asd2 = xindex + width / 2;

	color2.g = fabs(asd2 /4 - (int)(asd2 /4)) *4 < width || fabs(asd /8 - (int)(asd /8)) *8 < width ? 1 : 0;
	color2.b = fabs(asd2 - (int)(asd2)) < width || fabs(asd - (int)(asd)) < width ? 1 : 0;

	write_imagef(im, coord, color2);

	/*
	float2 c = { coord.x / (float)w - 0.5f, coord.y / (float)h - 0.5f }; // -0.5..0.5, -0.5..0.5

	// zoom + movement
	c /= scale;
	c.x += x;
	c.y += y;

	float2 z = c;
  
	int iter = 0;
	for (; iter < max_iter; ++iter)
	{
		float3 tmp = z.xyx * z.xyy; // SWIZZLE
		z.x = tmp.x - tmp.y; // Re
		z.y = 2*tmp.z; // Im
		z += c;

		if (tmp.x + tmp.y > 2 * 2) {
			break;
		}
	}
  
	float col = iter / (float)max_iter;
	float4 color = { 
		col * coord.x / (float)w,
		col * coord.y / (float)h, 
		col, 1.0f };
	write_imagef(im, coord, color);
	*/
}

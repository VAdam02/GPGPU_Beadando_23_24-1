#import "BigFloat.cl"

__kernel void texture_kernel(
	__write_only image2d_t im,
	int w, int h,
	int max_iter, float scale, float x, float y)
{
	int2 coord = { get_global_id(0), get_global_id(1) };

	BigFloat a, b;
	//a.binaryRep[0][0] = 0x0000007F; // 1.0f
	a.binaryRep[0][0] = 0x0000007E; // 0.5f
	//a.binaryRep[0][0] = 0xBFFFFFFE; //-0.5f
	//a.binaryRep[0][0] = 0xBFFFFFFF; //-1.0f
	//a.binaryRep[0][0] = 0x4FFFFFFE; //TOO BIG FOR FLOAT
	//a.binaryRep[0][0] = 0x3FFFFFFE; //TOO SMALL FOR FLOAT
	a.binaryRep[0][1] = 0;
	a.binaryRep[0][2] = 0;
	a.binaryRep[0][3] = 0;
	a.binaryRep[1][0] = 0;
	a.binaryRep[1][1] = 0;
	a.binaryRep[1][2] = 0;
	a.binaryRep[1][3] = 0;

	float4 color = {
		toFloat(a),
		toFloat(a),
		toFloat(a),
		1.0f };

	write_imagef(im, coord, color);


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

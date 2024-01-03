#import "BigFloat.cl"

__kernel void texture_kernel(
	__write_only image2d_t im,
	int w, int h,
	int max_iter, float scale, float x, float y)
{
	int2 coord = { get_global_id(0), get_global_id(1) };

	float4 color2 = {
		0.0f,
		0.0f,
		0.0f,
		1.0f };

	BigFloat c_x = div(fromFloat(coord.x), fromFloat(w));
	BigFloat c_y = div(fromFloat(coord.y), fromFloat(h));

	// zoom + movement
	c_x = div(c_x, fromFloat(scale));
	c_y = div(c_y, fromFloat(scale));
	c_x = add(c_x, fromFloat(x));
	c_y = add(c_y, fromFloat(y));

	BigFloat z_x;
	deepCopy_BigFloat(z_x, c_x);
	BigFloat z_y;
	deepCopy_BigFloat(z_y, c_y);

	int iter = 0;
	for (; iter < max_iter; ++iter)
	{
		BigFloat tmp_x = mult(z_x, z_x);
		BigFloat tmp_y = mult(z_y, z_y);
		BigFloat tmp_z = mult(z_x, z_y);

		z_x = subt(tmp_x, tmp_y); // Re
		z_y = mult(fromFloat(2), tmp_z); // Im 

		z_x = add(z_x, c_x);
		z_y = add(z_y, c_y);

		if (toFloat(add(tmp_x, tmp_y)) > 2 * 2) {
			break;
		}
	}

	color2.x = (float)iter / (float)max_iter;


	float2 c = { coord.x / (float)w, coord.y / (float)h };

	// zoom + movement
	c /= scale;
	c.x += x;
	c.y += y;

	float2 z = c;

	iter = 0;
	for (; iter < max_iter; ++iter)
	{
		float3 tmp = z.xyx * z.xyy; // SWIZZLE
		z.x = tmp.x - tmp.y; // Re
		z.y = 2 * tmp.z; // Im
		z += c;

		if (tmp.x + tmp.y > 2 * 2) {
			break;
		}
	}

	color2.z = (float)iter / (float)max_iter;



	write_imagef(im, coord, color2);
}

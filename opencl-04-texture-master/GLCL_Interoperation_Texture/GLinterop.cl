__kernel void texture_kernel(
  __write_only image2d_t im,
  int w, int h,
  int max_iter)
{
  int2 coord = { get_global_id(0), get_global_id(1) };

  float2 c = { coord.x / (float)w - 0.5f, coord.y / (float)h - 0.5f }; // -0.5..0.5, -0.5..0.5

  // zoom + movement
  c *= 3.0f;
  c.x -= 0.5f;

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
}

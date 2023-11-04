#include "MyApp.h"
#include "GLUtils.hpp"

#include <GL/GLU.h>
#include <math.h>
#include <oclutils.hpp>


bool CMyApp::InitGL()
{
  glClearColor(0.125f, 0.25f, 0.5f, 1.0f);

  // Create texture
  texture = initTexture(texture_size, texture_size);

  scale = 1.0/3.0;
  center = glm::vec2(0, 0);
  max_iter = 50;

  return true;
}

bool CMyApp::InitCL()
{
  try
  {
    ///////////////////////////
    // Initialize OpenCL API //
    ///////////////////////////

    cl::vector<cl::Platform> platforms;
    cl::Platform::get(&platforms);

    // Try to get the sharing platform!
    bool create_context_success = false;
    for (auto platform : platforms) {
      // Next, create an OpenCL context on the platform.  Attempt to
      // create a GPU-based context.
      cl_context_properties contextProperties[] =
      {
  #ifdef _WIN32
        CL_CONTEXT_PLATFORM, (cl_context_properties)(platform)(),
        CL_GL_CONTEXT_KHR,   (cl_context_properties)wglGetCurrentContext(),
        CL_WGL_HDC_KHR,      (cl_context_properties)wglGetCurrentDC(),
  #elif defined( __GNUC__)
        CL_CONTEXT_PLATFORM, (cl_context_properties)(platform)(),
        CL_GL_CONTEXT_KHR,   (cl_context_properties)glXGetCurrentContext(),
        CL_GLX_DISPLAY_KHR,  (cl_context_properties)glXGetCurrentDisplay(),
  #elif defined(__APPLE__)
        //todo
  #endif
        0
      };

      // Create Context
      try {
        context = cl::Context(CL_DEVICE_TYPE_GPU, contextProperties);
        create_context_success = true;
        break;
      }
      catch (cl::Error error) {}
    }

    if (!create_context_success)
      throw cl::Error(CL_INVALID_CONTEXT, "Failed to create CL/GL shared context");

    // Create Command Queue
    cl::vector<cl::Device> devices = context.getInfo<CL_CONTEXT_DEVICES>();
    command_queue = cl::CommandQueue(context, devices[0]);

    /////////////////////////////////
    // Load, then build the kernel //
    /////////////////////////////////

    // Read source file
    std::ifstream sourceFile("GLinterop.cl");
    std::string sourceCode(std::istreambuf_iterator<char>(sourceFile), (std::istreambuf_iterator<char>()));
    cl::Program::Sources source(1, std::make_pair(sourceCode.c_str(), sourceCode.length() + 1));

    // Make program of the source code in the context
    program = cl::Program(context, source);
    try {
      program.build(devices);
    }
    catch (cl::Error error) {
      std::cout << program.getBuildInfo<CL_PROGRAM_BUILD_LOG>(devices[0]) << std::endl;
      throw error;
    }
    // Make kernel
    kernel_tex = cl::Kernel(program, "texture_kernel");

    // Create Mem Objs
    cl_tex_mem = cl::Image2DGL(context,
      CL_MEM_WRITE_ONLY, GL_TEXTURE_2D, 0, texture);

    // Query textures
    performTexQuery(); // Just to check..
  }
  catch (cl::Error error)
  {
    std::cout << error.what() << "(" << oclErrorString(error.err()) << ")" << std::endl;
    return false;
  }
  return true;
}

void CMyApp::Clean()
{
  // after we have released the OpenCL references, we can delete the underlying OpenGL objects
  if (texture != 0)
  {
    glBindBuffer(GL_TEXTURE_RECTANGLE_ARB, texture);
    glDeleteBuffers(1, &texture);
  }
}

#pragma region Update (CL)

void CMyApp::computeTexture()
{
  // Set arguments to kernel
  kernel_tex.setArg(0, cl_tex_mem); // buffer
  kernel_tex.setArg(1, texture_size); // integer value
  kernel_tex.setArg(2, texture_size); // integer value
  kernel_tex.setArg(3, max_iter); // integer value
  kernel_tex.setArg(4, scale); // float value
  kernel_tex.setArg(5, center.x); // float value
  kernel_tex.setArg(6, center.y); // float value

  // Run the kernel on specific ND range
  cl::NDRange global(texture_size, texture_size);
  command_queue.enqueueNDRangeKernel(kernel_tex, cl::NullRange, global, cl::NullRange);
}

void CMyApp::Update()
{
  static Uint32 last_time = SDL_GetTicks();
  delta_time = (SDL_GetTicks() - last_time) / 1000.0f;

  // CL
  try {
    cl::vector<cl::Memory> acquirable;
    acquirable.push_back(cl_tex_mem);

    // Acquire GL Objects
    command_queue.enqueueAcquireGLObjects(&acquirable);
    {
      // Perform computations
      computeTexture();

      // Wait for all computations to finish
      command_queue.finish();
    }
    // Release GL Objects
    command_queue.enqueueReleaseGLObjects(&acquirable);

  }
  catch (cl::Error error) {
    std::cout << error.what() << "(" << oclErrorString(error.err()) << ")" << std::endl;
    exit(1);
  }

  last_time = SDL_GetTicks();
}

#pragma endregion

#pragma region Render (GL)

void CMyApp::displayTexture(int w, int h)
{
  glEnable(GL_TEXTURE_RECTANGLE_ARB);
  glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);
  glBegin(GL_QUADS);

  const double half_width = 0.85;

  glTexCoord2f(0, 0);
  glVertex2f(-half_width, -half_width);

  glTexCoord2f(0, h);
  glVertex2f(-half_width, half_width);

  glTexCoord2f(w, h);
  glVertex2f(half_width, half_width);

  glTexCoord2f(w, 0);
  glVertex2f(half_width, -half_width);

  glEnd();
  glDisable(GL_TEXTURE_RECTANGLE_ARB);
}

void CMyApp::Render()
{
  // clear frame buffer (GL_COLOR_BUFFER_BIT) and the Z buffer (GL_DEPTH_BUFFER_BIT)
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

  glDisable(GL_DEPTH_TEST);
  glDepthMask(GL_FALSE);

  // GL
  displayTexture(texture_size, texture_size);
}

#pragma endregion

#pragma region etc

void CMyApp::KeyboardDown(SDL_KeyboardEvent& key)
{
  const float move_speed = 0.05;
  const float zoom_speed = 1.05;

  switch (key.keysym.sym)
  {
    // TODO

  case 'r':
    max_iter += 1;
    break;
  case 'f':
    max_iter -= 1;
    break;
  case 'w':
	center.y += move_speed / scale;
	break;
  case 'a':
    center.x -= move_speed / scale;
    break;
  case 's':
    center.y -= move_speed / scale;
    break;
  case 'd':
	center.x += move_speed / scale;
	break;
  case 1073741911: //numpad +
	scale *= zoom_speed;
	break;
  case 1073741910: //numpad -
    scale /= zoom_speed;
    break;
  default:
    break;
  }
  if (max_iter < 1)
    max_iter = 1;
}

void CMyApp::KeyboardUp(SDL_KeyboardEvent& key)
{
}

void CMyApp::MouseMove(SDL_MouseMotionEvent& mouse)
{
}

void CMyApp::MouseDown(SDL_MouseButtonEvent& mouse)
{
}

void CMyApp::MouseUp(SDL_MouseButtonEvent& mouse)
{
}

void CMyApp::MouseWheel(SDL_MouseWheelEvent& wheel)
{
}

// new windows width (_w) and height (_h)
void CMyApp::Resize(int _w, int _h)
{
  glViewport(0, 0, _w, _h);
  windowH = _h;
  windowW = _w;
}

CMyApp::CMyApp(void)
{
}

CMyApp::~CMyApp(void)
{
}

#pragma endregion

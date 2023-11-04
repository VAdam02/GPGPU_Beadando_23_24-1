#pragma once

// GLEW
#include <GL/glew.h>

// SDL
#include <SDL.h>
#include <SDL_opengl.h>

// Utils
#include "gVertexBuffer.h"
#include "gShaderProgram.h"

// CL
#include <iostream>
#include <fstream>
#include <sstream>

#define __NO_STD_VECTOR
#define __CL_ENABLE_EXCEPTIONS

#ifdef __APPLE__
#include <CL/cl.hpp>
#else
#include <CL/cl.hpp>
#include <CL/cl_gl.h>
#endif

#ifdef __GNUC__
#include <GL/glx.h>
#endif

class CMyApp
{
public:
  CMyApp(void);
  ~CMyApp(void);

  bool InitGL();
  bool InitCL();

  void Clean();

  void Update();
  void Render();

  void KeyboardDown(SDL_KeyboardEvent&);
  void KeyboardUp(SDL_KeyboardEvent&);
  void MouseMove(SDL_MouseMotionEvent&);
  void MouseDown(SDL_MouseButtonEvent&);
  void MouseUp(SDL_MouseButtonEvent&);
  void MouseWheel(SDL_MouseWheelEvent&);
  void Resize(int, int);
protected:

  int max_iter;

  // GL
  int windowH, windowW;
  GLuint texture;
  void displayTexture(int w, int h);

  // CL
  cl::Context context;
  cl::CommandQueue command_queue;
  cl::Program program;

  void computeTexture();

  cl::Kernel kernel_tex;
  cl::Image2DGL cl_tex_mem;

  float delta_time;

  const int texture_size = 512;

#pragma region GL functions

  GLuint initTexture(int width, int height)
  {
    GLuint tex;

    // make a texture for output
    glGenTextures(1, &tex);              // texture

    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, tex);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);

    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA32F_ARB, width,
      height, 0, GL_RGBA, GL_FLOAT, NULL);

    return tex;
  }

#pragma endregion

#pragma region CL functions

  void performTexQuery()
  {
    // source: https://code.google.com/p/opencl-book-samples/source/browse/trunk/src/Chapter_10/GLinterop/GLinterop.cpp

    cl_int errNum;
    std::cout << "Performing queries on OpenGL objects:" << std::endl;
    // example usage of getting information about a GL memory object
    cl_gl_object_type obj_type;
    GLuint objname;
    errNum = clGetGLObjectInfo(cl_tex_mem(), &obj_type, &objname);
    if (errNum != CL_SUCCESS) {
      std::cerr << "Failed to get object information" << std::endl;
    }
    else {
      if (obj_type == CL_GL_OBJECT_TEXTURE2D) {
        std::cout << "Queried a texture object succesfully." << std::endl;
        std::cout << "Object name is: " << objname << std::endl;
      }

    }

    // Example usage of how to get information about the texture object
    GLenum param;
    size_t param_ret_size;
    errNum = clGetGLTextureInfo(cl_tex_mem(), CL_GL_TEXTURE_TARGET, sizeof(GLenum), &param, &param_ret_size);
    if (errNum != CL_SUCCESS) {
      std::cerr << "Failed to get texture information" << std::endl;
    }
    else {
      // we have set it to use GL_TEXTURE_RECTANGLE_ARB.  We expect it to be reflectedin the query here
      if (param == GL_TEXTURE_RECTANGLE_ARB) {
        std::cout << "Texture rectangle ARB is being used." << std::endl;
      }
    }
  }

#pragma endregion
};
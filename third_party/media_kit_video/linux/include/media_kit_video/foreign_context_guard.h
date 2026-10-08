// WatchTV patch, see PATCHES.md.
//
// GDK keeps its own OpenGL context current on the platform thread: GLX on
// X11, EGL (desktop OpenGL API) on Wayland. Mesa does not allow making an
// EGL context current on a thread while that context is current
// (EGL_BAD_ACCESS), so it is released for the duration of the guard and
// made current again afterwards.

#ifndef FOREIGN_CONTEXT_GUARD_H_
#define FOREIGN_CONTEXT_GUARD_H_

#include <epoxy/egl.h>
#include <epoxy/glx.h>
#include <gdk/gdkx.h>

class ForeignContextGuard {
 public:
  ForeignContextGuard() {
    // Only touch GLX on X11, where libGL is loaded anyway.
    if (GDK_IS_X11_DISPLAY(gdk_display_get_default())) {
      glx_context_ = glXGetCurrentContext();
      if (glx_context_ != NULL) {
        glx_display_ = glXGetCurrentDisplay();
        glx_draw_ = glXGetCurrentDrawable();
        glx_read_ = glXGetCurrentReadDrawable();
        glXMakeContextCurrent(glx_display_, None, None, NULL);
      }
    }
    api_ = eglQueryAPI();
    const EGLenum apis[] = {EGL_OPENGL_API, EGL_OPENGL_ES_API};
    for (int i = 0; i < 2; i++) {
      eglBindAPI(apis[i]);
      EGLContext context = eglGetCurrentContext();
      if (context != EGL_NO_CONTEXT) {
        egl_[i] = {true, eglGetCurrentDisplay(),
                   eglGetCurrentSurface(EGL_DRAW),
                   eglGetCurrentSurface(EGL_READ), context};
        eglMakeCurrent(egl_[i].display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                       EGL_NO_CONTEXT);
      }
    }
    eglBindAPI(api_);
  }

  ~ForeignContextGuard() {
    const EGLenum apis[] = {EGL_OPENGL_API, EGL_OPENGL_ES_API};
    for (int i = 0; i < 2; i++) {
      if (egl_[i].saved) {
        eglBindAPI(apis[i]);
        eglMakeCurrent(egl_[i].display, egl_[i].draw, egl_[i].read,
                       egl_[i].context);
      }
    }
    eglBindAPI(api_);
    if (glx_context_ != NULL) {
      glXMakeContextCurrent(glx_display_, glx_draw_, glx_read_, glx_context_);
    }
  }

  ForeignContextGuard(const ForeignContextGuard&) = delete;
  ForeignContextGuard& operator=(const ForeignContextGuard&) = delete;

 private:
  struct SavedEgl {
    bool saved = false;
    EGLDisplay display = EGL_NO_DISPLAY;
    EGLSurface draw = EGL_NO_SURFACE;
    EGLSurface read = EGL_NO_SURFACE;
    EGLContext context = EGL_NO_CONTEXT;
  };

  EGLenum api_ = EGL_OPENGL_ES_API;
  SavedEgl egl_[2];
  GLXContext glx_context_ = NULL;
  Display* glx_display_ = NULL;
  GLXDrawable glx_draw_ = None;
  GLXDrawable glx_read_ = None;
};

#endif  // FOREIGN_CONTEXT_GUARD_H_

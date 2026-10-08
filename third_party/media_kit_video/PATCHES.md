# Local changes to media_kit_video 2.0.1

Copied from <https://pub.dev/packages/media_kit_video> (MIT, see `LICENSE`)
without `example/`. Used through `dependency_overrides` in the app's
`pubspec.yaml`. Drop this copy once an upstream release contains both fixes.

## Linux: hardware rendering with newer Flutter versions

`linux/video_output.cc`, `linux/texture_gl.cc`

Newer Flutter versions (the Linux embedder's `FlOpenGLManager`) keep no EGL
context current on the platform thread. media_kit queried
`eglGetCurrentContext()` there, found nothing and fell back to S/W rendering
("EGL display or context is invalid"), converting every frame on the CPU.

- `video_output_new`: when no context is current, get the EGL display from
  the GDK display the way Flutter does, choose a config with Flutter's
  attributes and create the isolated mpv context with it. EGLImage sharing
  only needs the same EGLDisplay.
- Release the isolated context afterwards instead of "restoring" a context
  that was never current.
- On X11, GTK keeps its own GLX context current on the platform thread.
  Mesa then refuses to make an EGL context current (`EGL_BAD_ACCESS`).
  `ForeignContextGuard` (`linux/include/media_kit_video/foreign_context_guard.h`)
  releases the GLX and EGL (GL and GLES API) contexts of the thread for the
  time media_kit uses its own context, then makes them current again.
- `texture_gl_dispose`: with no current context, queue the deletion of
  Flutter's texture and delete it on the raster thread at the next
  `texture_gl_populate_texture`.

## Linux: do not block the raster thread (upstream f702a64, media-kit#1440)

`linux/texture_gl.cc`: pass `MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME = 0`, so
rendering does not wait for mpv's present-sync and halve Flutter's frame
rate.

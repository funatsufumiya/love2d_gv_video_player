// gv_video_decoder.h
#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif


#ifdef _WIN32
#  ifdef GV_VIDEO_DECODER_EXPORTS
#    define GV_API __declspec(dllexport)
#  else
#    define GV_API __declspec(dllimport)
#  endif
#else
#  define GV_API
#endif

typedef struct gv_video_decoder gv_video_decoder;

GV_API gv_video_decoder* gv_video_decoder_open(const char* path);
GV_API void gv_video_decoder_close(gv_video_decoder* decoder);

GV_API uint32_t gv_video_decoder_get_width(gv_video_decoder* decoder);
GV_API uint32_t gv_video_decoder_get_height(gv_video_decoder* decoder);
GV_API uint32_t gv_video_decoder_get_frame_count(gv_video_decoder* decoder);
GV_API float    gv_video_decoder_get_fps(gv_video_decoder* decoder);
GV_API uint32_t gv_video_decoder_get_format(gv_video_decoder* decoder);
GV_API uint32_t gv_video_decoder_get_frame_bytes(gv_video_decoder* decoder);
GV_API uint32_t gv_video_decoder_decode_frame(gv_video_decoder* dec, uint32_t frame, void* out_buf);

#ifdef __cplusplus
}
#endif

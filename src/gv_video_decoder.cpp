#include "gv_video_decoder.hpp"

// FIXME temporal implementation
extern "C" int gv_decode_frame(const uint8_t* input, int input_size, uint8_t* output, int output_size) {
    int copy_size = (input_size < output_size) ? input_size : output_size;
    for (int i = 0; i < copy_size; ++i) {
        output[i] = input[i];
    }
    return copy_size;
}

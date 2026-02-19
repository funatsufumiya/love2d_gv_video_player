#include "gv_video_decoder.hpp"

#include "lz4.h"

// FIXME temporal implementation
extern "C" int gv_decode_frame(const uint8_t* input, int input_size, uint8_t* output, int output_size) {
    int copy_size = (input_size < output_size) ? input_size : output_size;
    for (int i = 0; i < copy_size; ++i) {
        output[i] = input[i];
    }
    return copy_size;
}

// lz4 roundtrip test: returns 1 if decompress(compress(input)) == input, else 0
extern "C" int gv_lz4_roundtrip(const uint8_t* input, int input_size) {
    if (!input || input_size <= 0) return 0;
    int max_compressed = LZ4_compressBound(input_size);
    uint8_t* compressed = new uint8_t[max_compressed];
    uint8_t* restored = new uint8_t[input_size];
    int compressed_size = LZ4_compress_default((const char*)input, (char*)compressed, input_size, max_compressed);
    if (compressed_size <= 0) {
        delete[] compressed; delete[] restored;
        return 0;
    }
    int restored_size = LZ4_decompress_safe((const char*)compressed, (char*)restored, compressed_size, input_size);
    int ok = (restored_size == input_size);
    for (int i = 0; ok && i < input_size; ++i) {
        if (input[i] != restored[i]) ok = 0;
    }
    delete[] compressed; delete[] restored;
    return ok;
}

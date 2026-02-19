#pragma once
#include <cstdint>

#ifdef _WIN32
#define DLL_EXPORT __declspec(dllexport)
#else
#define DLL_EXPORT
#endif

extern "C" {
    // sample
    DLL_EXPORT int gv_decode_frame(const uint8_t* input, int input_size, uint8_t* output, int output_size);

    // lz4 roundtrip test: returns 1 if decompress(compress(input)) == input, else 0
    DLL_EXPORT int gv_lz4_roundtrip(const uint8_t* input, int input_size);
}

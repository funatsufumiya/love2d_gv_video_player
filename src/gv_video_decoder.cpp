
#include "gv_video_decoder.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <vector>
#include <string>
#include "gv_video.hpp"
#include "optional.hpp"
#include "lz4.h"

struct gv_video_decoder {
    FILE* fp = nullptr;
    uint32_t width = 0, height = 0, frame_count = 0, frame_bytes = 0, format = 0;
    float fps = 0.0f;
    std::vector<Lz4Block> lz4_blocks;
    std::vector<uint8_t> lz4_buffer;
    bool valid = false;
};

extern "C" {

gv_video_decoder* gv_video_decoder_open(const char* path) {
    FILE* fp = fopen(path, "rb");
    if (!fp) return nullptr;
    gv_video_decoder* dec = new gv_video_decoder();
    dec->fp = fp;
    fseek(fp, 0, SEEK_END);
    long filesize = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    if (filesize < (long)kRawMemoryAt) { fclose(fp); delete dec; return nullptr; }
    fread(&dec->width, 4, 1, fp);
    fread(&dec->height, 4, 1, fp);
    fread(&dec->frame_count, 4, 1, fp);
    fread(&dec->fps, 4, 1, fp);
    fread(&dec->format, 4, 1, fp);
    fread(&dec->frame_bytes, 4, 1, fp);
    
    dec->lz4_blocks.resize(dec->frame_count);
    fseek(fp, filesize - sizeof(Lz4Block) * dec->frame_count, SEEK_SET);
    fread(dec->lz4_blocks.data(), sizeof(Lz4Block), dec->frame_count, fp);
    
    uint64_t max_block = 0;
    for (auto& b : dec->lz4_blocks) max_block = (b.size > max_block) ? b.size : max_block;
    dec->lz4_buffer.resize((size_t)max_block);
    dec->valid = true;
    return dec;
}

void gv_video_decoder_close(gv_video_decoder* dec) {
    if (!dec) return;
    if (dec->fp) fclose(dec->fp);
    delete dec;
}

uint32_t gv_video_decoder_get_width(gv_video_decoder* dec) { return dec ? dec->width : 0; }
uint32_t gv_video_decoder_get_height(gv_video_decoder* dec) { return dec ? dec->height : 0; }
uint32_t gv_video_decoder_get_frame_count(gv_video_decoder* dec) { return dec ? dec->frame_count : 0; }
float    gv_video_decoder_get_fps(gv_video_decoder* dec) { return dec ? dec->fps : 0.0f; }
uint32_t gv_video_decoder_get_format(gv_video_decoder* dec) { return dec ? dec->format : 0; }
uint32_t gv_video_decoder_get_frame_bytes(gv_video_decoder* dec) { return dec ? dec->frame_bytes : 0; }

uint32_t gv_video_decoder_decode_frame(gv_video_decoder* dec, uint32_t frame, void* out_buf) {
    if (!dec || !dec->valid || frame >= dec->frame_count) return 0;
    Lz4Block& blk = dec->lz4_blocks[frame];
    fseek(dec->fp, (long)blk.address, SEEK_SET);
    if (fread(dec->lz4_buffer.data(), 1, (size_t)blk.size, dec->fp) != blk.size) return 0;
    int ret = LZ4_decompress_safe((const char*)dec->lz4_buffer.data(), (char*)out_buf, (int)blk.size, (int)dec->frame_bytes);
    if (ret <= 0) return 0;
    return (uint32_t)ret;
}

} // extern "C"

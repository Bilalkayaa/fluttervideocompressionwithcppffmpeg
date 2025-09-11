#include <string>
#include <cstdlib>
#include <cstring>
#include <cmath>

extern "C"
{
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
#include <libavutil/opt.h>
#include <libavutil/imgutils.h>
#include <libavutil/avutil.h>
#include <libavutil/display.h>
}

extern "C" __attribute__((visibility("default")))
const char *
get_video_metadata(const char *file_path)
{
    AVFormatContext *formatContext = nullptr;

    // Dosya açma
    int ret = avformat_open_input(&formatContext, file_path, nullptr, nullptr);
    if (ret < 0)
    {
        return strdup("Error opening file");
    }

    // Stream bilgilerini bulma
    ret = avformat_find_stream_info(formatContext, nullptr);
    if (ret < 0)
    {
        avformat_close_input(&formatContext);
        return strdup("Error finding stream info");
    }

    // Süreyi al ve kontrol et
    int64_t duration = formatContext->duration;
    if (duration == AV_NOPTS_VALUE)
    {
        duration = 0;
    }
    double durationInSeconds = std::abs(static_cast<double>(duration)) / AV_TIME_BASE;

    // Format bilgilerini yazma
    char buffer[1024];
    snprintf(buffer, sizeof(buffer), "Format: %s\nDuration: %.2f seconds\nBitrate: %ld kb/s\nStreams: %d\n",
             formatContext->iformat->name,
             durationInSeconds,
             formatContext->bit_rate / 1000,
             formatContext->nb_streams);

    avformat_close_input(&formatContext);

    // Kopyalanmış stringi döndür
    return strdup(buffer);
}

extern "C" __attribute__((visibility("default")))
const char *
compress_video(const char *input_file_path, const char *output_file_path)
{
    AVFormatContext *ifmt = nullptr;
    AVFormatContext *ofmt = nullptr;
    AVCodecContext *dec_ctx = nullptr;
    AVCodecContext *enc_ctx = nullptr;
    const AVCodec *dec = nullptr;
    const AVCodec *enc = nullptr;
    SwsContext *sws = nullptr;
    AVStream *in_vst = nullptr;
    AVStream *out_vst = nullptr;

    int ret = avformat_open_input(&ifmt, input_file_path, nullptr, nullptr);
    if (ret < 0)
    {
        return strdup("Error opening input file");
    }

    ret = avformat_find_stream_info(ifmt, nullptr);
    if (ret < 0)
    {
        avformat_close_input(&ifmt);
        return strdup("Error finding stream info");
    }

    int video_stream_index = av_find_best_stream(ifmt, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    if (video_stream_index < 0)
    {
        avformat_close_input(&ifmt);
        return strdup("No video stream found");
    }
    in_vst = ifmt->streams[video_stream_index];

    dec = avcodec_find_decoder(in_vst->codecpar->codec_id);
    if (!dec)
    {
        avformat_close_input(&ifmt);
        return strdup("Video decoder not found");
    }

    dec_ctx = avcodec_alloc_context3(dec);
    if (!dec_ctx)
    {
        avformat_close_input(&ifmt);
        return strdup("Could not allocate decoder context");
    }

    ret = avcodec_parameters_to_context(dec_ctx, in_vst->codecpar);
    if (ret < 0)
    {
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&ifmt);
        return strdup("Failed to copy decoder parameters");
    }
    ret = avcodec_open2(dec_ctx, dec, nullptr);
    if (ret < 0)
    {
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&ifmt);
        return strdup("Failed to open decoder");
    }

    ret = avformat_alloc_output_context2(&ofmt, nullptr, nullptr, output_file_path);
    if (ret < 0 || !ofmt)
    {
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&ifmt);
        return strdup("Failed to create output context");
    }

    // Prefer software encoders to avoid permission issues with HW encoders
    enc = avcodec_find_encoder_by_name("libx264");
    if (!enc)
        enc = avcodec_find_encoder_by_name("mpeg4");
    if (!enc)
        enc = avcodec_find_encoder_by_name("libx265");
    if (!enc)
    {
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&ifmt);
        avformat_free_context(ofmt);
        return strdup("No suitable software encoder found (libx264/mpeg4/libx265)\n");
    }

    out_vst = avformat_new_stream(ofmt, enc);
    if (!out_vst)
    {
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&ifmt);
        avformat_free_context(ofmt);
        return strdup("Failed to create output stream");
    }

    enc_ctx = avcodec_alloc_context3(enc);
    if (!enc_ctx)
    {
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&ifmt);
        avformat_free_context(ofmt);
        return strdup("Could not allocate encoder context");
    }

    int in_w = dec_ctx->width;
    int in_h = dec_ctx->height;
    double scale_w = 1280.0 / (in_w > 0 ? in_w : 1280.0);
    double scale_h = 720.0 / (in_h > 0 ? in_h : 720.0);
    double scale = fmin(1.0, fmin(scale_w, scale_h));
    int out_w = ((int)floor((in_w * scale) / 2.0)) * 2;
    int out_h = ((int)floor((in_h * scale) / 2.0)) * 2;
    if (out_w <= 0)
        out_w = 1280;
    if (out_h <= 0)
        out_h = 720;

    enc_ctx->width = out_w;
    enc_ctx->height = out_h;
    enc_ctx->pix_fmt = AV_PIX_FMT_YUV420P;
    AVRational in_fps = av_guess_frame_rate(ifmt, in_vst, nullptr);
    if (in_fps.num == 0 || in_fps.den == 0)
        in_fps = (AVRational){30, 1};
    enc_ctx->time_base = av_inv_q(in_fps);
    enc_ctx->framerate = in_fps;
    enc_ctx->gop_size = 60;
    enc_ctx->max_b_frames = 2;
    enc_ctx->bit_rate = 2'500'000;

    if (ofmt->oformat->flags & AVFMT_GLOBALHEADER)
    {
        enc_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    if (strcmp(enc->name, "libx264") == 0)
    {
        av_opt_set(enc_ctx->priv_data, "preset", "medium", 0);
        av_opt_set(enc_ctx->priv_data, "profile", "main", 0);
        av_opt_set(enc_ctx->priv_data, "tune", "film", 0);
        av_opt_set(enc_ctx->priv_data, "crf", "22", 0);
        enc_ctx->bit_rate = 0;
    }
    else if (strcmp(enc->name, "mpeg4") == 0)
    {
        enc_ctx->max_b_frames = 0; // safer for mpeg4 on Android
        enc_ctx->gop_size = 12;
        // Some mpeg4 encoders prefer standard time_base like 1/30
        enc_ctx->time_base = (AVRational){1, 30};
        enc_ctx->framerate = (AVRational){30, 1};
        // Optional rate control tuning
        av_opt_set_int(enc_ctx->priv_data, "qmin", 3, 0);
        av_opt_set_int(enc_ctx->priv_data, "qmax", 31, 0);
    }

    ret = avcodec_open2(enc_ctx, enc, nullptr);
    if (ret < 0)
    {
        char err[128];
        av_strerror(ret, err, sizeof(err));
        avcodec_free_context(&enc_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&ifmt);
        avformat_free_context(ofmt);
        char msg[256];
        snprintf(msg, sizeof(msg), "Failed to open encoder: %s, %s", enc->name, err);
        return strdup(msg);
    }

    ret = avcodec_parameters_from_context(out_vst->codecpar, enc_ctx);
    if (ret < 0)
    {
        avcodec_free_context(&enc_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&ifmt);
        avformat_free_context(ofmt);
        return strdup("Failed to set encoder parameters");
    }
    out_vst->time_base = enc_ctx->time_base;
    out_vst->avg_frame_rate = enc_ctx->framerate;

    if (!(ofmt->oformat->flags & AVFMT_NOFILE))
    {
        ret = avio_open(&ofmt->pb, output_file_path, AVIO_FLAG_WRITE);
        if (ret < 0)
        {
            avcodec_free_context(&enc_ctx);
            avcodec_free_context(&dec_ctx);
            avformat_close_input(&ifmt);
            avformat_free_context(ofmt);
            return strdup("Failed to open output file");
        }
    }

    // Preserve rotation/display matrix if present so vertical videos play correctly
    {
        size_t sd_size = 0;
        uint8_t *sd = av_stream_get_side_data(in_vst, AV_PKT_DATA_DISPLAYMATRIX, &sd_size);
        if (sd && sd_size > 0)
        {
            uint8_t *dst = av_stream_new_side_data(out_vst, AV_PKT_DATA_DISPLAYMATRIX, sd_size);
            if (dst)
            {
                memcpy(dst, sd, sd_size);
            }
        }

        // Also pass through legacy rotate metadata if present
        AVDictionaryEntry *rotate_tag = av_dict_get(in_vst->metadata, "rotate", nullptr, 0);
        if (rotate_tag && rotate_tag->value)
        {
            av_dict_set(&out_vst->metadata, "rotate", rotate_tag->value, 0);
        }
    }

    ret = avformat_write_header(ofmt, nullptr);
    if (ret < 0)
    {
        if (!(ofmt->oformat->flags & AVFMT_NOFILE))
            avio_closep(&ofmt->pb);
        avcodec_free_context(&enc_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&ifmt);
        avformat_free_context(ofmt);
        char err[128];
        av_strerror(ret, err, sizeof(err));
        char msg[192];
        snprintf(msg, sizeof(msg), "Failed to write header: %s", err);
        return strdup(msg);
    }

    sws = sws_getContext(in_w, in_h, dec_ctx->pix_fmt,
                         out_w, out_h, enc_ctx->pix_fmt,
                         SWS_LANCZOS, nullptr, nullptr, nullptr);
    if (!sws)
    {
        if (!(ofmt->oformat->flags & AVFMT_NOFILE))
            avio_closep(&ofmt->pb);
        avcodec_free_context(&enc_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&ifmt);
        avformat_free_context(ofmt);
        return strdup("Failed to init scaler");
    }

    AVFrame *frame = av_frame_alloc();
    AVFrame *sws_frame = av_frame_alloc();
    AVPacket *pkt = av_packet_alloc();
    AVPacket *enc_pkt = av_packet_alloc();
    if (!frame || !sws_frame || !pkt || !enc_pkt)
    {
        if (pkt)
            av_packet_free(&pkt);
        if (enc_pkt)
            av_packet_free(&enc_pkt);
        if (frame)
            av_frame_free(&frame);
        if (sws_frame)
            av_frame_free(&sws_frame);
        sws_freeContext(sws);
        if (!(ofmt->oformat->flags & AVFMT_NOFILE))
            avio_closep(&ofmt->pb);
        avcodec_free_context(&enc_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&ifmt);
        avformat_free_context(ofmt);
        return strdup("Failed to allocate frames/packets");
    }

    sws_frame->format = enc_ctx->pix_fmt;
    sws_frame->width = enc_ctx->width;
    sws_frame->height = enc_ctx->height;
    ret = av_frame_get_buffer(sws_frame, 32);
    if (ret < 0)
    {
        av_packet_free(&pkt);
        av_packet_free(&enc_pkt);
        av_frame_free(&frame);
        av_frame_free(&sws_frame);
        sws_freeContext(sws);
        if (!(ofmt->oformat->flags & AVFMT_NOFILE))
            avio_closep(&ofmt->pb);
        avcodec_free_context(&enc_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&ifmt);
        avformat_free_context(ofmt);
        return strdup("Failed to alloc sws frame buffer");
    }

    int64_t next_pts = 0;
    while ((ret = av_read_frame(ifmt, pkt)) >= 0)
    {
        if (pkt->stream_index == video_stream_index)
        {
            ret = avcodec_send_packet(dec_ctx, pkt);
            if (ret == 0)
            {
                while ((ret = avcodec_receive_frame(dec_ctx, frame)) == 0)
                {
                    sws_scale(sws,
                              frame->data,
                              frame->linesize,
                              0,
                              dec_ctx->height,
                              sws_frame->data,
                              sws_frame->linesize);

                    // Generate monotonic PTS in encoder time_base
                    sws_frame->pts = next_pts++;

                    ret = avcodec_send_frame(enc_ctx, sws_frame);
                    if (ret == 0)
                    {
                        while ((ret = avcodec_receive_packet(enc_ctx, enc_pkt)) == 0)
                        {
                            enc_pkt->stream_index = out_vst->index;
                            enc_pkt->pts = av_rescale_q(enc_pkt->pts, enc_ctx->time_base, out_vst->time_base);
                            enc_pkt->dts = av_rescale_q(enc_pkt->dts, enc_ctx->time_base, out_vst->time_base);
                            enc_pkt->duration = av_rescale_q(enc_pkt->duration, enc_ctx->time_base, out_vst->time_base);
                            av_interleaved_write_frame(ofmt, enc_pkt);
                            av_packet_unref(enc_pkt);
                        }
                    }
                }
            }
        }
        av_packet_unref(pkt);
    }

    avcodec_send_frame(enc_ctx, nullptr);
    while (avcodec_receive_packet(enc_ctx, enc_pkt) == 0)
    {
        enc_pkt->stream_index = out_vst->index;
        enc_pkt->pts = av_rescale_q(enc_pkt->pts, enc_ctx->time_base, out_vst->time_base);
        enc_pkt->dts = av_rescale_q(enc_pkt->dts, enc_ctx->time_base, out_vst->time_base);
        enc_pkt->duration = av_rescale_q(enc_pkt->duration, enc_ctx->time_base, out_vst->time_base);
        av_interleaved_write_frame(ofmt, enc_pkt);
        av_packet_unref(enc_pkt);
    }

    av_write_trailer(ofmt);

    av_packet_free(&pkt);
    av_packet_free(&enc_pkt);
    av_frame_free(&frame);
    av_frame_free(&sws_frame);
    sws_freeContext(sws);
    if (!(ofmt->oformat->flags & AVFMT_NOFILE))
        avio_closep(&ofmt->pb);
    avcodec_free_context(&enc_ctx);
    avcodec_free_context(&dec_ctx);
    avformat_close_input(&ifmt);
    avformat_free_context(ofmt);

    return strdup("Video compression completed successfully");
}

extern "C" __attribute__((visibility("default"))) void free_cstring(const char *str)
{
    if (str != nullptr)
    {
        free((void *)str);
    }
}

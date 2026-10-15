"""Inspect real ffmpeg argv/output, without exporting raw server log lines."""
import shlex


class AuditFailure(Exception):
    pass


def command_from_log(text):
    for line in text.splitlines():
        if "/ffmpeg " in line and not line.lstrip().startswith("{"):
            return shlex.split(line[line.index("/usr/"):])
    raise AuditFailure("ffmpeg command not found")


def codecs(argv, kind):
    flags = {f"-c:{kind}", f"-codec:{kind}", f"-c:{kind}:0", f"-codec:{kind}:0"}
    return [argv[i + 1] for i, value in enumerate(argv[:-1]) if value in flags]


def audit(argv, mode, streams):
    video = codecs(argv, "v")
    audio = codecs(argv, "a")
    if not video or not audio:
        raise AuditFailure("missing explicit stream codecs")
    actual_video = next((s for s in streams if s.get("codec_type") == "video"), {})
    actual_audio = next((s for s in streams if s.get("codec_type") == "audio"), {})
    if any(s.get("codec_type") == "subtitle" for s in streams):
        raise AuditFailure("unexpected output subtitle stream")
    width, height = actual_video.get("width"), actual_video.get("height")
    if mode in ("remux", "audioOnly"):
        if set(video) != {"copy"}:
            raise AuditFailure("copy path video encoder")
        forbidden = {"-vf", "-filter_complex", "-filter_complex_script", "-lavfi", "-s", "-pix_fmt"}
        if any(value in forbidden or value.startswith(("-filter:v", "-filter_script:v", "-s:v", "-pix_fmt:")) for value in argv):
            raise AuditFailure("copy path pixel processing")
        if actual_video.get("codec_name") != "h264":
            raise AuditFailure("copy path changed authored H264 codec")
        if (width, height) != (3840, 2160):
            raise AuditFailure("copy path changed original 4K dimensions")
        if mode == "remux" and set(audio) != {"copy"}:
            raise AuditFailure("remux changed audio")
        if mode == "audioOnly" and ("copy" in audio or actual_audio.get("codec_name") != "aac"):
            raise AuditFailure("audio-only did not encode AAC")
    elif mode == "video":
        if "copy" in video or actual_video.get("codec_name") != "h264":
            raise AuditFailure("approved video did not encode H264")
        if not width or not height or width > 1920 or height > 1080:
            raise AuditFailure("approved video exceeded disclosed resolution")
        rates = [argv[i + 1] for i, flag in enumerate(argv[:-1]) if flag in {"-b:v", "-b:v:0"}]
        maxima = [argv[i + 1] for i, flag in enumerate(argv[:-1]) if flag in {"-maxrate", "-maxrate:v", "-maxrate:v:0"}]
        buffers = [argv[i + 1] for i, flag in enumerate(argv[:-1]) if flag in {"-bufsize", "-bufsize:v", "-bufsize:v:0"}]
        # Jellyfin's libx264 CRF path uses a finite VBV cap, not -b:v.
        # Require that real cap; an average target alone does not bound quality.
        if not maxima or not buffers or any(not value.isdecimal() or not 0 < int(value) <= 8_000_000 for value in rates + maxima):
            raise AuditFailure("approved video exceeded or omitted disclosed bitrate")
        if any(not value.isdecimal() or not 0 < int(value) <= 16_000_000 for value in buffers):
            raise AuditFailure("approved video omitted or exceeded bounded VBV buffer")
    else:
        raise AuditFailure("unknown mode")
    return {"mode": mode, "video_encoders": video, "audio_encoders": audio,
            "output_video": actual_video.get("codec_name"), "output_audio": actual_audio.get("codec_name"),
            "width": width, "height": height, "video_copy": set(video) == {"copy"}}

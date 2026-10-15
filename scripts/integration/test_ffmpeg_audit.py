import unittest
from ffmpeg_audit import AuditFailure, audit, command_from_log


class AuditTests(unittest.TestCase):
    def streams(self, width=3840, height=2160):
        return [{"codec_type": "video", "codec_name": "h264", "width": width, "height": height},
                {"codec_type": "audio", "codec_name": "aac"}]

    def test_rejects_video_encoding_or_processing_even_if_output_still_4k(self):
        for argv in [["-codec:v:0", "libx264", "-codec:a:0", "copy"],
                     ["-codec:v:0", "copy", "-codec:a:0", "copy", "-vf", "tonemap,scale=1920:1080"],
                     ["-codec:v:0", "copy", "-codec:a:0", "copy", "-filter_complex", "subtitles=fixture.srt"]]:
            with self.assertRaises(AuditFailure):
                audit(argv, "remux", self.streams())

    def test_output_probe_detects_unreported_resolution_loss(self):
        with self.assertRaises(AuditFailure):
            audit(["-codec:v:0", "copy", "-codec:a:0", "aac"], "audioOnly", self.streams(1920, 1080))

    def test_real_log_style_quoting_and_codec_flags(self):
        argv = command_from_log('metadata\n/usr/lib/jellyfin-ffmpeg/ffmpeg -i file:"/media/Fixture Copy 4K.mkv" -codec:v:0 copy -codec:a:0 copy output.m3u8\nffmpeg version')
        result = audit(argv, "remux", self.streams())
        self.assertTrue(result["video_copy"])
        self.assertNotIn("/media", str(result))

    def test_approved_video_cannot_exceed_disclosed_limit(self):
        with self.assertRaises(AuditFailure):
            audit(["-codec:v:0", "libx264", "-codec:a:0", "aac"], "video", self.streams())


if __name__ == "__main__":
    unittest.main()

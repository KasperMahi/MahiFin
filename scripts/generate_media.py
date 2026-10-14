"""Author legally shareable deterministic test inputs with an installed FFmpeg."""
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1] / "TestFixtures/PlaybackFixtures"
root.mkdir(parents=True, exist_ok=True)
if not shutil.which("ffmpeg"):
    raise SystemExit("FFmpeg required for synthetic-media integration tests")
(root / "synthetic.srt").write_text("1\n00:00:01,000 --> 00:00:20,000\nSynthetic subtitle\n", encoding="utf-8")
for ext in ("mp4", "mkv"):
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "color=c=blue:s=256x144:r=24:d=24", "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=24"]
    if ext == "mkv":
        command += ["-i", str(root / "synthetic.srt"), "-map", "0:v", "-map", "1:a", "-map", "2:s", "-c:s", "srt"]
    command += ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-t", "24", str(root / ("synthetic." + ext))]
    subprocess.run(command, check=True)
print("Authored 24-second H.264/AAC MP4/MKV and embedded SRT subtitle fixtures")

# Synthetic playback fixtures

CI creates synthetic H.264/AAC MP4 and MKV clips and an authored subtitle with scripts/generate_media.py. No real titles, voices, copyrighted pictures or external media are used. Generated binaries are ignored; they are test-only inputs, not a capability guarantee.

The SRT muxing input lives in the separate ignored PlaybackInputs directory, outside app resources. The MKV test expects exactly one embedded subtitle; bundling the same-name SRT beside it would make VLC auto-discover an additional external track.

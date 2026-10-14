import AVFoundation
import VideoToolbox
import MahiFinCore

enum NativeCapabilities {
    static func probe(preference: EnginePreference) -> DeviceCapabilities {
        var value = DeviceCapabilities()
        value.alternativeAvailable = preference != .native
        // Hardware decoding availability is not a guarantee about every profile, bitrate, display or audio chain.
        if !VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) { value.videoCodecs.remove("hevc") }
        // H.264 also has AVFoundation software decoding; absence of a hardware decoder
        // alone must not force a low-resolution SDR original into server conversion.
        let modes = AVPlayer.availableHDRModes
        if modes.contains(.hdr10) { value.hdrFormats.insert("HDR10") }
        if modes.contains(.hlg) { value.hdrFormats.insert("HLG") }
        if preference == .alternative { value.nativeContainers = [] }
        return value
    }
}

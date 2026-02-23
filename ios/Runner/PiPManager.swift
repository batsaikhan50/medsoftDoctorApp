import AVKit
import Flutter
import WebRTC
import flutter_webrtc

// MARK: - Custom Video View using AVSampleBufferDisplayLayer

class CustomVideoView: UIView {
    override class var layerClass: AnyClass {
        return AVSampleBufferDisplayLayer.self
    }

    var sampleBufferLayer: AVSampleBufferDisplayLayer {
        return layer as! AVSampleBufferDisplayLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        sampleBufferLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Frame Renderer: RTCVideoFrame -> CMSampleBuffer

class RTCFrameRenderer: NSObject, RTCVideoRenderer {
    private let displayLayer: AVSampleBufferDisplayLayer
    private var pixelBufferPool: CVPixelBufferPool?
    private var frameCount = 0

    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        super.init()
    }

    func setSize(_ size: CGSize) {
        // Recreate pixel buffer pool when size changes
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pixelBufferPool)
    }

    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame = frame else { return }

        // Skip every other frame for performance
        frameCount += 1
        if frameCount % 2 != 0 { return }

        guard let pixelBuffer = extractPixelBuffer(from: frame) else { return }
        guard let sampleBuffer = createSampleBuffer(from: pixelBuffer, timestamp: frame.timeStampNs) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.displayLayer.status == .failed {
                self.displayLayer.flush()
            }
            self.displayLayer.enqueue(sampleBuffer)
        }
    }

    private func extractPixelBuffer(from frame: RTCVideoFrame) -> CVPixelBuffer? {
        if let rtcPixelBuffer = frame.buffer as? RTCCVPixelBuffer {
            return rtcPixelBuffer.pixelBuffer
        }

        // Handle I420 buffer
        if let i420Buffer = frame.buffer as? RTCI420Buffer {
            return convertI420ToPixelBuffer(i420Buffer, width: Int(frame.width), height: Int(frame.height))
        }

        return nil
    }

    private func convertI420ToPixelBuffer(_ buffer: RTCI420Buffer, width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?

        if let pool = pixelBufferPool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        } else {
            let attrs: [String: Any] = [
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            ]
            CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer)
        }

        guard let pb = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        // Convert I420 (YUV) to BGRA using vImage or manual conversion
        let dstBase = CVPixelBufferGetBaseAddress(pb)!
        let dstStride = CVPixelBufferGetBytesPerRow(pb)

        let yPlane = buffer.dataY
        let uPlane = buffer.dataU
        let vPlane = buffer.dataV
        let yStride = Int(buffer.strideY)
        let uStride = Int(buffer.strideU)
        let vStride = Int(buffer.strideV)

        for row in 0..<height {
            for col in 0..<width {
                let y = Int(yPlane[row * yStride + col])
                let u = Int(uPlane[(row / 2) * uStride + (col / 2)])
                let v = Int(vPlane[(row / 2) * vStride + (col / 2)])

                let c = y - 16
                let d = u - 128
                let e = v - 128

                let r = max(0, min(255, (298 * c + 409 * e + 128) >> 8))
                let g = max(0, min(255, (298 * c - 100 * d - 208 * e + 128) >> 8))
                let b = max(0, min(255, (298 * c + 516 * d + 128) >> 8))

                let offset = row * dstStride + col * 4
                dstBase.storeBytes(of: UInt8(b), toByteOffset: offset, as: UInt8.self)
                dstBase.storeBytes(of: UInt8(g), toByteOffset: offset + 1, as: UInt8.self)
                dstBase.storeBytes(of: UInt8(r), toByteOffset: offset + 2, as: UInt8.self)
                dstBase.storeBytes(of: UInt8(255), toByteOffset: offset + 3, as: UInt8.self)
            }
        }

        return pb
    }

    private func createSampleBuffer(from pixelBuffer: CVPixelBuffer, timestamp: Int64) -> CMSampleBuffer? {
        var formatDescription: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )

        guard let format = formatDescription else { return nil }

        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(value: timestamp, timescale: 1_000_000_000),
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer
    }
}

// MARK: - Remote Frame Observer

class RemoteFrameObserver: NSObject, RTCVideoRenderer {
    private let renderer: RTCFrameRenderer

    init(renderer: RTCFrameRenderer) {
        self.renderer = renderer
        super.init()
    }

    func setSize(_ size: CGSize) {
        renderer.setSize(size)
    }

    func renderFrame(_ frame: RTCVideoFrame?) {
        renderer.renderFrame(frame)
    }
}

// MARK: - PiP Manager

@available(iOS 15.0, *)
class PiPManager: NSObject, AVPictureInPictureControllerDelegate {
    static var shared: PiPManager?

    private var pipController: AVPictureInPictureController?
    private var videoView: CustomVideoView?
    private var frameRenderer: RTCFrameRenderer?
    private var frameObserver: RemoteFrameObserver?
    private var remoteVideoTrack: RTCVideoTrack?
    private var pipContentSource: AVPictureInPictureController.ContentSource?

    override init() {
        super.init()
    }

    func setup() {
        // Activate audio session for PiP
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("PiPManager: Audio session error: \(error)")
        }

        // Create the video view and renderer
        videoView = CustomVideoView(frame: CGRect(x: 0, y: 0, width: 180, height: 320))
        frameRenderer = RTCFrameRenderer(displayLayer: videoView!.sampleBufferLayer)
        frameObserver = RemoteFrameObserver(renderer: frameRenderer!)
    }

    func setRemoteTrack(trackId: String) {
        // Remove old observer
        if let oldTrack = remoteVideoTrack, let observer = frameObserver {
            oldTrack.remove(observer)
        }

        // Access remote track via flutter_webrtc plugin (Objective-C class)
        guard let plugin = FlutterWebRTCPlugin.sharedSingleton() else {
            print("PiPManager: Could not get FlutterWebRTCPlugin singleton")
            return
        }

        // remoteTrackForId: returns RTCMediaStreamTrack, cast to RTCVideoTrack
        guard let mediaTrack = plugin.remoteTrack(forId: trackId),
              let videoTrack = mediaTrack as? RTCVideoTrack else {
            print("PiPManager: Could not find remote video track: \(trackId)")
            return
        }

        remoteVideoTrack = videoTrack
        if let observer = frameObserver {
            videoTrack.add(observer)
        }
    }

    func startPiP() {
        guard let videoView = videoView else {
            print("PiPManager: videoView not initialized")
            return
        }

        if pipController == nil {
            let source = AVPictureInPictureController.ContentSource(
                sampleBufferDisplayLayer: videoView.sampleBufferLayer,
                playbackDelegate: self
            )
            pipContentSource = source
            pipController = AVPictureInPictureController(contentSource: source)
            pipController?.delegate = self
            pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if self?.pipController?.isPictureInPictureActive == false {
                self?.pipController?.startPictureInPicture()
            }
        }
    }

    func stopPiP() {
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
    }

    func disposePiP() {
        stopPiP()
        if let track = remoteVideoTrack, let observer = frameObserver {
            track.remove(observer)
        }
        remoteVideoTrack = nil
        pipController = nil
        pipContentSource = nil
        videoView = nil
        frameRenderer = nil
        frameObserver = nil
    }

    // MARK: - AVPictureInPictureControllerDelegate

    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiPManager: PiP will start")
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiPManager: PiP started")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiPManager: PiP stopped")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("PiPManager: Failed to start PiP: \(error.localizedDescription)")
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

@available(iOS 15.0, *)
extension PiPManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        // No-op for live video
    }

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        // Handle render size change if needed
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

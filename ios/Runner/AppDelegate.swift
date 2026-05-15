import Flutter
import AudioToolbox
import AVFoundation
import CoreHaptics
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let alarmSoundPlayer = AlarmSoundPlayer()
  private let alarmVibrationPlayer = AlarmVibrationPlayer()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "codex_paralarm/alarm_sound",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "getVolume" {
        result(AVAudioSession.sharedInstance().outputVolume)
        return
      }

      if call.method == "vibrate" {
        let arguments = call.arguments as? [String: Any]
        let pattern = arguments?["pattern"] as? String ?? "pulse"
        self?.alarmVibrationPlayer.play(pattern: pattern)
        result(nil)
        return
      }

      guard call.method == "play" else {
        result(FlutterMethodNotImplemented)
        return
      }

      let arguments = call.arguments as? [String: Any]
      let sound = arguments?["sound"] as? String ?? "alert"
      do {
        try self?.alarmSoundPlayer.play(sound: sound)
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "ALARM_SOUND_FAILED",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }
}

private final class AlarmVibrationPlayer {
  private var engine: CHHapticEngine?

  func play(pattern: String) {
    playSystemVibration(pattern: pattern)
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
      return
    }

    do {
      let engine = try preparedEngine()
      let events = hapticEvents(pattern: pattern)
      let hapticPattern = try CHHapticPattern(events: events, parameters: [])
      let player = try engine.makePlayer(with: hapticPattern)
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      playImpactFallback(pattern: pattern)
    }
  }

  private func preparedEngine() throws -> CHHapticEngine {
    if let engine {
      try engine.start()
      return engine
    }

    let newEngine = try CHHapticEngine()
    newEngine.stoppedHandler = { [weak self] _ in
      self?.engine = nil
    }
    try newEngine.start()
    engine = newEngine
    return newEngine
  }

  private func hapticEvents(pattern: String) -> [CHHapticEvent] {
    let pulses: [(TimeInterval, TimeInterval)]
    switch pattern {
    case "urgent":
      pulses = [(0.00, 0.36), (0.52, 0.36), (1.04, 0.48)]
    case "long":
      pulses = [(0.00, 1.10)]
    default:
      pulses = [(0.00, 0.10), (0.20, 0.10), (0.40, 0.10)]
    }

    return pulses.map { start, duration in
      CHHapticEvent(
        eventType: .hapticContinuous,
        parameters: [
          CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
          CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
        ],
        relativeTime: start,
        duration: duration
      )
    }
  }

  private func playSystemVibration(pattern: String) {
    let timings: [TimeInterval]
    switch pattern {
    case "urgent":
      timings = [0.0, 0.45, 0.45]
    case "long":
      timings = [0.0, 0.55, 0.55]
    default:
      timings = [0.0, 0.16, 0.16]
    }

    var accumulated: TimeInterval = 0
    for delay in timings {
      accumulated += delay
      let deadline = DispatchTime.now() + accumulated
      DispatchQueue.main.asyncAfter(deadline: deadline) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
      }
    }
  }

  private func playImpactFallback(pattern: String) {
    let style: UIImpactFeedbackGenerator.FeedbackStyle = pattern == "pulse" ? .medium : .heavy
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.prepare()
    generator.impactOccurred(intensity: 1.0)
  }
}

private final class AlarmSoundPlayer: NSObject, AVAudioPlayerDelegate {
  private var players: [AVAudioPlayer] = []

  func play(sound: String) throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .playAndRecord,
      mode: .default,
      options: [.defaultToSpeaker, .mixWithOthers]
    )
    try session.setActive(true)

    let data = Self.makeWavData(sound: sound)
    let player = try AVAudioPlayer(data: data)
    player.delegate = self
    player.volume = 1.0
    player.prepareToPlay()
    players.append(player)
    player.play()
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    players.removeAll { $0 === player }
  }

  private static func makeWavData(sound: String) -> Data {
    let sampleRate = 44100
    let duration = sound == "click"
      ? 0.16
      : (sound == "danger" ? 0.075 : (sound == "loudBeep" ? 1.44 : 0.62))
    let sampleCount = Int(Double(sampleRate) * duration)
    let bytesPerSample = 2
    let dataSize = UInt32(sampleCount * bytesPerSample)
    var data = Data()

    appendString("RIFF", to: &data)
    appendUInt32(36 + dataSize, to: &data)
    appendString("WAVE", to: &data)
    appendString("fmt ", to: &data)
    appendUInt32(16, to: &data)
    appendUInt16(1, to: &data)
    appendUInt16(1, to: &data)
    appendUInt32(UInt32(sampleRate), to: &data)
    appendUInt32(UInt32(sampleRate * bytesPerSample), to: &data)
    appendUInt16(UInt16(bytesPerSample), to: &data)
    appendUInt16(16, to: &data)
    appendString("data", to: &data)
    appendUInt32(dataSize, to: &data)

    for index in 0..<sampleCount {
      let progress = Double(index) / Double(sampleCount)
      let frameTime = Double(index) / Double(sampleRate)
      let isLoudBeep = sound == "loudBeep"
      let beepCycle = frameTime.truncatingRemainder(dividingBy: 0.08)
      let isSilent = isLoudBeep && beepCycle > 0.052
      let frequency = sound == "click"
        ? 1320.0
        : (sound == "danger"
          ? 1760.0
          : (isLoudBeep
          ? 1760.0
          : (progress < 0.5 ? 880.0 : 1320.0)))
      let localProgress = isLoudBeep ? min(1.0, beepCycle / 0.052) : progress
      let envelope = isSilent
        ? 0.0
        : (sound == "danger"
          ? min(1.0, min(progress * 40.0, (1.0 - progress) * 18.0))
          : (isLoudBeep
          ? min(1.0, min(localProgress * 18.0, (1.0 - localProgress) * 14.0))
          : min(1.0, min(progress * 24.0, (1.0 - progress) * 12.0))))
      let sample = sin(2.0 * Double.pi * frequency * Double(index) / Double(sampleRate))
      let gain = isLoudBeep ? 0.94 : 0.82
      let value = Int16(max(-1.0, min(1.0, sample * envelope)) * Double(Int16.max) * gain)
      appendInt16(value, to: &data)
    }

    return data
  }

  private static func appendString(_ value: String, to data: inout Data) {
    data.append(value.data(using: .ascii)!)
  }

  private static func appendUInt16(_ value: UInt16, to data: inout Data) {
    var littleEndian = value.littleEndian
    data.append(Data(bytes: &littleEndian, count: MemoryLayout<UInt16>.size))
  }

  private static func appendUInt32(_ value: UInt32, to data: inout Data) {
    var littleEndian = value.littleEndian
    data.append(Data(bytes: &littleEndian, count: MemoryLayout<UInt32>.size))
  }

  private static func appendInt16(_ value: Int16, to data: inout Data) {
    var littleEndian = value.littleEndian
    data.append(Data(bytes: &littleEndian, count: MemoryLayout<Int16>.size))
  }
}

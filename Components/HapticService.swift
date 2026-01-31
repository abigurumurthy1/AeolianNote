import SwiftUI
import CoreHaptics

final class HapticService {
    static let shared = HapticService()

    private var engine: CHHapticEngine?

    private init() {
        prepareHaptics()
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptic engine error: \(error)")
        }
    }

    func playLaunch() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            // Fallback to UIKit haptics
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            return
        }

        var events: [CHHapticEvent] = []

        // Rising intensity
        for i in stride(from: 0, to: 0.3, by: 0.05) {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(i / 0.3) * 0.8)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: i)
            events.append(event)
        }

        // Final whoosh
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0.3, duration: 0.2)
        events.append(event)

        playPattern(events)
    }

    func playCatch() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            return
        }

        var events: [CHHapticEvent] = []

        // Soft catch
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        events.append(event)

        playPattern(events)
    }

    func playNotification() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            return
        }

        var events: [CHHapticEvent] = []

        // Wind chime pattern
        for (index, delay) in [0.0, 0.1, 0.2].enumerated() {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(0.8 - Double(index) * 0.2))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: delay)
            events.append(event)
        }

        playPattern(events)
    }

    func playUnfold() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            return
        }

        var events: [CHHapticEvent] = []

        // Paper unfold
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 0.3)
        events.append(event)

        playPattern(events)
    }

    private func playPattern(_ events: [CHHapticEvent]) {
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }
}

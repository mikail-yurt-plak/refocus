import Foundation
import AVFoundation
import Combine

/// Ambient sesleri yöneten sınıf
/// 3-4 adet white noise/ambient ses, varsayılan kapalı
class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published var currentSound: AmbientSound?
    @Published var isPlaying = false
    @Published var volume: Float = 0.5

    private var audioPlayer: AVAudioPlayer?

    private init() {
        setupAudioSession()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session hatası: \(error)")
        }
        #endif
    }

    // MARK: - Playback Control

    /// Ambient ses çal
    func play(_ sound: AmbientSound) {
        stop()

        guard let url = sound.fileURL else {
            print("Ses dosyası bulunamadı: \(sound.fileName)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Sonsuz döngü
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            currentSound = sound
            isPlaying = true
        } catch {
            print("Ses çalma hatası: \(error)")
        }
    }

    /// Sesi durdur
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentSound = nil
        isPlaying = false
    }

    /// Sesi duraklatı/devam ettir
    func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
        } else {
            audioPlayer?.play()
            isPlaying = true
        }
    }

    /// Ses seviyesini ayarla
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        audioPlayer?.volume = volume
    }

    /// Fade out yaparak durdur
    func fadeOutAndStop(duration: TimeInterval = 2.0) {
        guard let player = audioPlayer else { return }

        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeStep = player.volume / Float(steps)

        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                player.volume -= volumeStep
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.stop()
        }
    }
}

/// Ambient ses tipleri
enum AmbientSound: String, CaseIterable, Identifiable {
    case rain = "rain"
    case forest = "forest"
    case whiteNoise = "white_noise"
    case lofi = "lofi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rain: return "Yağmur"
        case .forest: return "Orman"
        case .whiteNoise: return "White Noise"
        case .lofi: return "Lo-Fi"
        }
    }

    var icon: String {
        switch self {
        case .rain: return "cloud.rain.fill"
        case .forest: return "leaf.fill"
        case .whiteNoise: return "waveform"
        case .lofi: return "headphones"
        }
    }

    var description: String {
        switch self {
        case .rain: return "Sakinleştirici yağmur sesleri"
        case .forest: return "Doğa sesleri ve kuş cıvıltıları"
        case .whiteNoise: return "Odaklanma için beyaz gürültü"
        case .lofi: return "Hafif ambient müzik"
        }
    }

    var fileName: String {
        return "\(rawValue).mp3"
    }

    var fileURL: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: "mp3")
    }

    /// Deep Work için önerilen
    var isRecommendedForDeepWork: Bool {
        switch self {
        case .whiteNoise, .rain: return true
        default: return false
        }
    }
}

// MARK: - Sound Picker View

import SwiftUI

/// Ses seçici view
struct SoundPickerView: View {
    @ObservedObject var audioManager = AudioManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Ses listesi
                    ForEach(AmbientSound.allCases) { sound in
                        SoundCard(
                            sound: sound,
                            isSelected: audioManager.currentSound == sound,
                            isPlaying: audioManager.isPlaying && audioManager.currentSound == sound
                        ) {
                            if audioManager.currentSound == sound && audioManager.isPlaying {
                                audioManager.stop()
                            } else {
                                audioManager.play(sound)
                            }
                        }
                    }

                    // Ses seviyesi
                    if audioManager.isPlaying {
                        VStack(spacing: 8) {
                            Text("Ses Seviyesi")
                                .font(.caption)
                                .foregroundColor(.textSecondary)

                            Slider(
                                value: Binding(
                                    get: { Double(audioManager.volume) },
                                    set: { audioManager.setVolume(Float($0)) }
                                ),
                                in: 0...1
                            )
                            .tint(.focusGreen)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    }

                    Spacer()

                    // Kapat butonu
                    if audioManager.isPlaying {
                        Button(action: { audioManager.stop() }) {
                            Text("Sesi Kapat")
                                .font(.button)
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 24)
            }
            .navigationTitle("Ambient Sesler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

/// Ses kartı komponenti
struct SoundCard: View {
    let sound: AmbientSound
    let isSelected: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // İkon
                Image(systemName: sound.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .focusGreen)
                    .frame(width: 48, height: 48)
                    .background(isSelected ? Color.focusGreen : Color.focusGreen.opacity(0.1))
                    .cornerRadius(12)

                // Bilgi
                VStack(alignment: .leading, spacing: 4) {
                    Text(sound.displayName)
                        .font(.bodyLarge)
                        .foregroundColor(.textPrimary)

                    Text(sound.description)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Oynatma durumu
                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.focusGreen)
                        .symbolEffect(.variableColor.iterative)
                }
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
        .padding(.horizontal, 24)
    }
}

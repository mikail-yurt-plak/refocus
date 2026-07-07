import SwiftUI

/// Watch ana ekranı: aktif seansta canlı sayaç + bitir/molayı atla;
/// boşta bugünün özeti, önerilen metod ve tek dokunuşla başlatma.
struct WatchSessionView: View {
    @ObservedObject private var manager = WatchSessionManager.shared
    @State private var showingMethodPicker = false
    /// Kullanıcının listeden seçtiği metod; nil = telefonun önerisi
    @State private var selectedMethod: FocusMethod?

    private let focusGreen = Color(red: 0.18, green: 0.49, blue: 0.44)

    private var recommended: FocusMethod {
        manager.recommendedMethod.flatMap(FocusMethod.init(rawValue:)) ?? .pomodoro
    }

    /// Süre satırı; metodun adı zaten "52/17" gibi oranın kendisiyse tekrarlama
    private func durationLine(_ method: FocusMethod) -> String? {
        let line = "\(method.focusDuration)/\(method.breakDuration)"
        return line == method.rawValue ? nil : line
    }

    /// Kartta gösterilen metod: kullanıcının seçimi, yoksa öneri
    private var displayMethod: FocusMethod {
        selectedMethod ?? recommended
    }

    var body: some View {
        Group {
            if let state = manager.state {
                activeSession(state)
            } else {
                idleView
            }
        }
        .padding(.horizontal, 4)
        .sheet(isPresented: $showingMethodPicker) {
            methodPicker
        }
    }

    // MARK: - Aktif seans

    private func activeSession(_ state: WatchSessionManager.SessionState) -> some View {
        VStack(spacing: 6) {
            Text(state.methodName)
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Sistem kendisi sayar: duvar saatiyle her zaman tutarlı
            Text(timerInterval: Date.now...max(Date.now, state.endDate),
                 countsDown: true)
                .font(.system(size: 38, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(state.isBreak ? Color.blue.opacity(0.85) : focusGreen)
                .multilineTextAlignment(.center)

            Text(state.isBreak ? "common.label.break" : "common.label.focus")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if state.isBreak {
                Button {
                    manager.skipBreak()
                } label: {
                    Text("focus.skip_break")
                        .font(.footnote)
                }
                .tint(focusGreen)
                .disabled(!manager.isReachable)
            }

            Button {
                manager.endSession()
            } label: {
                Text("focus.end_session")
                    .font(.footnote)
            }
            .tint(.secondary)
            .disabled(!manager.isReachable)
        }
    }

    // MARK: - Boş durum

    private var idleView: some View {
        VStack(spacing: 8) {
            // Bugünün özeti: sakin tek satır
            if manager.todayMinutes > 0 {
                HStack(spacing: 4) {
                    Text("friends.today")
                    Text("·")
                    Text(String(format: String(localized: "common.minutes_format"),
                                manager.todayMinutes))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            // Önerilen metod; dokununca seçici açılır
            Button {
                showingMethodPicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(displayMethod.icon)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(displayMethod.rawValue)
                            .font(.footnote.weight(.medium))
                        if let durations = durationLine(displayMethod) {
                            Text(durations)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.bordered)

            Button {
                manager.startSession(method: selectedMethod)
                selectedMethod = nil // sonraki seansta öneri yeniden öne çıksın
            } label: {
                Text("home.start_session")
                    .font(.headline)
            }
            .tint(focusGreen)
            .disabled(!manager.isReachable)

            if !manager.isReachable {
                Text("watch.phone_unreachable")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Metod seçici

    private var methodPicker: some View {
        List(FocusMethod.allCases, id: \.self) { method in
            Button {
                // Yalnızca seçer; başlatma her zaman "Seansı Başlat" ile
                selectedMethod = method
                showingMethodPicker = false
            } label: {
                HStack(spacing: 8) {
                    Text(method.icon)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(method.rawValue)
                            .font(.footnote.weight(.medium))
                        if let durations = durationLine(method) {
                            Text(durations)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if method == displayMethod {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(focusGreen)
                    } else if method == recommended {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(focusGreen.opacity(0.6))
                    }
                }
            }
        }
        .navigationTitle(Text("method.choose_title"))
    }
}

#Preview {
    WatchSessionView()
}

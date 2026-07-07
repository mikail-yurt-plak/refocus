import SwiftUI

/// Watch ana ekranı: aktif seansta canlı sayaç + bitir;
/// boşta önerilen seansı tek dokunuşla başlat.
struct WatchSessionView: View {
    @ObservedObject private var manager = WatchSessionManager.shared

    private let focusGreen = Color(red: 0.18, green: 0.49, blue: 0.44)

    var body: some View {
        Group {
            if let state = manager.state {
                activeSession(state)
            } else {
                idleView
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Aktif seans

    private func activeSession(_ state: WatchSessionManager.SessionState) -> some View {
        VStack(spacing: 8) {
            Text(state.methodName)
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Sistem kendisi sayar: duvar saatiyle her zaman tutarlı
            Text(timerInterval: Date.now...max(Date.now, state.endDate),
                 countsDown: true)
                .font(.system(size: 40, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(state.isBreak ? Color.blue.opacity(0.85) : focusGreen)
                .multilineTextAlignment(.center)

            Text(state.isBreak ? "common.label.break" : "common.label.focus")
                .font(.caption2)
                .foregroundStyle(.secondary)

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
        VStack(spacing: 10) {
            Text("watch.start_hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                manager.startSession()
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
}

#Preview {
    WatchSessionView()
}

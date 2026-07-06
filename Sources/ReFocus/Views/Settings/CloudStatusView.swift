import SwiftUI
import CloudKit

/// iCloud bağlantı ve senkron durumu - isteğe bağlı bakılan sakin bir özet
struct CloudStatusView: View {
    @Environment(\.dismiss) private var dismiss
    let sessionManager: SessionManager

    @State private var accountStatus: CKAccountStatus?

    private var isCloudWorking: Bool {
        accountStatus == .available && CloudStore.shared.isCloudBacked
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Durum simgesi
                        Image(systemName: isCloudWorking ? "checkmark.icloud" : "icloud.slash")
                            .font(.system(size: 44))
                            .foregroundColor(isCloudWorking ? .focusGreen : .textTertiary)
                            .padding(.top, 8)

                        VStack(spacing: 0) {
                            statusRow(
                                label: Text("cloudstatus.account"),
                                value: accountStatus == .available
                                    ? Text("cloudstatus.account.connected")
                                    : Text("cloudstatus.account.unavailable"),
                                isPositive: accountStatus == .available
                            )

                            Divider().padding(.leading, 16)

                            statusRow(
                                label: Text("cloudstatus.storage"),
                                value: isCloudWorking
                                    ? Text("cloudstatus.storage.cloud")
                                    : Text("cloudstatus.storage.local"),
                                isPositive: isCloudWorking
                            )

                            Divider().padding(.leading, 16)

                            HStack {
                                Text(String(
                                    format: String(localized: "cloudstatus.sessions_format"),
                                    sessionManager.getAllSessions().count
                                ))
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)
                                Spacer()
                            }
                            .padding(16)
                        }
                        .background(Color.cardBackground)
                        .cornerRadius(16)

                        Text(isCloudWorking ? "cloudstatus.hint.ok" : "cloudstatus.hint.unavailable")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isCloudWorking ? Color.focusGreen.opacity(0.08) : Color.gentleWarning)
                            .cornerRadius(12)
                    }
                    .padding(24)
                }
            }
            .navigationTitle(Text("cloudstatus.title"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailingCompat) {
                    Button(String(localized: "common.button.close")) {
                        dismiss()
                    }
                    .foregroundColor(.focusGreen)
                }
            }
            .task {
                accountStatus = try? await CKContainer(
                    identifier: "iCloud.com.mikailyurt.refocus"
                ).accountStatus()
            }
        }
    }

    private func statusRow(label: Text, value: Text, isPositive: Bool) -> some View {
        HStack(alignment: .top) {
            label
                .font(.subheadline)
                .foregroundColor(.textPrimary)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(isPositive ? Color.focusGreen : Color.orange)
                    .frame(width: 7, height: 7)
                    .padding(.top, 5)

                value
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(16)
    }
}

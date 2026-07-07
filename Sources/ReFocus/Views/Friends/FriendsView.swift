import SwiftUI

/// Arkadaşlar ekranı - birlikte çalışma varlığı.
/// Sıralama ve karşılaştırma yok: herkesin günü kendi başına, yargısız gösterilir.
struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = FriendSyncManager.shared

    @State private var nameInput = ""
    @State private var phoneInput = ""
    @State private var inviteURL: URL?
    @State private var isPreparingInvite = false
    @State private var inviteFailed = false
    @State private var friendToRemove: FriendSummary?
    @State private var viewerToRemove: FriendSyncManager.ShareViewer?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if !manager.iCloudAvailable {
                            noticeCard(text: Text("friends.icloud_required"))
                        }

                        if manager.isEnabled {
                            inviteSection
                            friendsSection
                            viewersSection
                        } else {
                            setupSection
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle(Text("friends.title"))
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
                await manager.refreshFriends()
                await manager.refreshViewers()
            }
            .confirmationDialog(
                Text("friends.viewers.remove_confirm"),
                isPresented: Binding(
                    get: { viewerToRemove != nil },
                    set: { if !$0 { viewerToRemove = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(String(localized: "friends.viewers.remove"), role: .destructive) {
                    if let viewer = viewerToRemove {
                        Task { await manager.removeViewer(viewer) }
                    }
                    viewerToRemove = nil
                }
            }
            .confirmationDialog(
                Text("friends.remove_confirm"),
                isPresented: Binding(
                    get: { friendToRemove != nil },
                    set: { if !$0 { friendToRemove = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(String(localized: "friends.remove"), role: .destructive) {
                    if let friend = friendToRemove {
                        Task { await manager.removeFriend(friend) }
                    }
                    friendToRemove = nil
                }
            }
        }
    }

    // MARK: - Kurulum (görünen ad)

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "person.2")
                .font(.largeTitle)
                .foregroundColor(.focusGreen)

            Text("friends.setup.description")
                .font(.body)
                .foregroundColor(.textPrimary)

            Text("friends.setup.privacy")
                .font(.caption)
                .foregroundColor(.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("friends.setup.name_label")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                TextField(String(localized: "friends.setup.name_placeholder"), text: $nameInput)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding()
                    .background(Color.appBackground)
                    .cornerRadius(12)
            }

            Button {
                manager.displayName = nameInput.trimmingCharacters(in: .whitespaces)
            } label: {
                Text("common.button.continue")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(nameInput.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.textTertiary : Color.focusGreen)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(nameInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Davet

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let url = inviteURL {
                ShareLink(item: url) {
                    inviteLabel(icon: "square.and.arrow.up", key: "friends.invite")
                }
                .buttonStyle(.plain)

                Text("friends.invite.ready_note")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            } else {
                Text("friends.invite.phone_label")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                TextField(String(localized: "friends.invite.phone_placeholder"), text: $phoneInput)
                    .textFieldStyle(.plain)
                    .font(.body)
                    #if os(iOS)
                    .keyboardType(.phonePad)
                    #endif
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color.appBackground)
                    .cornerRadius(12)

                Text("friends.invite.channel_note")
                    .font(.caption)
                    .foregroundColor(.textTertiary)

                if inviteFailed {
                    Text("friends.invite.error_lookup")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Button {
                    isPreparingInvite = true
                    inviteFailed = false
                    Task {
                        do {
                            inviteURL = try await manager.createInvite(
                                forContact: phoneInput.trimmingCharacters(in: .whitespaces)
                            )
                        } catch {
                            inviteFailed = true
                        }
                        isPreparingInvite = false
                    }
                } label: {
                    if isPreparingInvite {
                        inviteLabel(icon: "hourglass", key: "friends.invite.preparing")
                    } else {
                        inviteLabel(icon: "person.badge.plus", key: "friends.invite.send")
                    }
                }
                .buttonStyle(.plain)
                .disabled(isPreparingInvite || phoneInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Text("friends.invite.note")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Özetimi görenler

    @ViewBuilder
    private var viewersSection: some View {
        if !manager.viewers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("friends.viewers.title")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                ForEach(manager.viewers) { viewer in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewer.label
                                 ?? String(localized: "friends.viewers.anonymous"))
                                .font(.body)
                                .foregroundColor(.textPrimary)

                            if !viewer.hasAccepted {
                                Text("friends.viewers.pending")
                                    .font(.caption)
                                    .foregroundColor(.textTertiary)
                            }
                        }

                        Spacer()

                        Button {
                            viewerToRemove = viewer
                        } label: {
                            Image(systemName: "person.badge.minus")
                                .foregroundColor(.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("friends.viewers.remove"))
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(16)
        }
    }

    private func inviteLabel(icon: String, key: LocalizedStringKey) -> some View {
        HStack {
            Image(systemName: icon)
            Text(key)
                .font(.body.weight(.medium))
            Spacer()
        }
        .foregroundColor(.focusGreen)
    }

    // MARK: - Arkadaş listesi

    @ViewBuilder
    private var friendsSection: some View {
        if manager.friends.isEmpty {
            VStack(spacing: 12) {
                if manager.isRefreshing {
                    ProgressView()
                } else {
                    Text("friends.empty.title")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    Text("friends.empty.description")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            ForEach(manager.friends) { friend in
                FriendCard(friend: friend)
                    .contextMenu {
                        Button(role: .destructive) {
                            friendToRemove = friend
                        } label: {
                            Label(String(localized: "friends.remove"), systemImage: "person.badge.minus")
                        }
                    }
            }
        }
    }
}

// MARK: - Arkadaş kartı

private struct FriendCard: View {
    let friend: FriendSummary
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(friend.displayName)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                if friend.isFocusing {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.focusGreen)
                            .frame(width: 7, height: 7)
                        Text(presenceText)
                            .font(.caption)
                            .foregroundColor(.focusGreen)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.focusGreen.opacity(0.12))
                    .cornerRadius(8)
                }

                Spacer()

                Text("friends.week_total")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
                Text(minutesText(friend.weekTotalMinutes))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.focusGreen)
            }

            if let today = friend.today, today.totalMinutes > 0 {
                HStack(spacing: 8) {
                    Text("friends.today")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    Text(minutesText(today.totalMinutes))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.textPrimary)
                    Text(sessionsText(today.sessionCount))
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }

                if !today.contexts.isEmpty {
                    contextChips(today.contexts)
                }
            } else {
                Text("friends.no_activity")
                    .font(.subheadline)
                    .foregroundColor(.textTertiary)
            }

            let pastDays = friend.days.filter { !Calendar.current.isDateInToday($0.date) && $0.totalMinutes > 0 }
            if !pastDays.isEmpty {
                Button {
                    withAnimation(.easeInOut) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                        Text("friends.recent_days")
                            .font(.caption)
                    }
                    .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    ForEach(pastDays) { day in
                        dayRow(day)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }

    private func dayRow(_ day: FriendDayActivity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(day.date, format: .dateTime.weekday(.wide).day().month())
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(minutesText(day.totalMinutes))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.textPrimary)
                Text(sessionsText(day.sessionCount))
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
            if !day.contexts.isEmpty {
                contextChips(day.contexts)
            }
        }
        .padding(.top, 4)
    }

    private func contextChips(_ contexts: [(name: String, minutes: Int)]) -> some View {
        FlowLayoutCompat {
            ForEach(Array(contexts.enumerated()), id: \.offset) { _, context in
                HStack(spacing: 4) {
                    Text(context.name)
                    Text(minutesText(context.minutes))
                        .foregroundColor(.textTertiary)
                }
                .font(.caption)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.appBackground)
                .cornerRadius(8)
            }
        }
    }

    /// "Şu an odakta" / "25 dk süredir odakta"
    private var presenceText: String {
        if let since = friend.focusingSince {
            let minutes = Int(Date().timeIntervalSince(since) / 60)
            if minutes >= 1 {
                return String(
                    format: String(localized: "friends.presence.since_format"),
                    minutesText(minutes)
                )
            }
        }
        return String(localized: "friends.presence.focusing")
    }

    private func minutesText(_ minutes: Int) -> String {
        String(format: String(localized: "friends.minutes_format"), minutes)
    }

    private func sessionsText(_ count: Int) -> String {
        String(format: String(localized: "friends.sessions_format"), count)
    }
}

/// Basit akış yerleşimi (chip'ler için)
private struct FlowLayoutCompat: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Yardımcı kart

private func noticeCard(text: Text) -> some View {
    text
        .font(.caption)
        .foregroundColor(.textSecondary)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gentleWarning)
        .cornerRadius(12)
}

#Preview {
    FriendsView()
}

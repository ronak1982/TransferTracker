import SwiftUI
import CloudKit

struct DashboardView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager

    @State private var selectedList: TransferList?
    @State private var showingNewListForm = false
    @State private var showingJoinSheet = false
    @State private var pendingShareMetadata: CKShare.Metadata?
    @State private var showingManualJoin = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient (matches your original dark dashboard)
                LinearGradient(
                    colors: [Color(hex: "0f172a"), Color(hex: "1e293b")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {

                        // 1) Transfer Tracker title (first)
                        titleCard

                        // 2) Recent Activity (second)
                        recentActivityCard

                        // 3) Actions (Join first, Create second)
                        actionButtons

                        // 4) Lists
                        listsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewListForm) {
                NewListFormView(isPresented: $showingNewListForm)
                    .environmentObject(cloudKitManager)
            }
            .sheet(isPresented: $showingManualJoin) {
                ManualJoinView(isPresented: $showingManualJoin)
                    .environmentObject(cloudKitManager)
            }
        }
    }

    // MARK: - Header Cards

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Transfer Tracker")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color(hex: "a5b4fc"))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "0f172a"),
                                    Color(hex: "1e293b")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }

    private var recentActivityCard: some View {
        NavigationLink(destination: ActivityFeedView().environmentObject(cloudKitManager)) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Activity")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("See what changed across your lists")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.70))
                }
                Spacer()
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(Color.white.opacity(0.80))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Join first
            Button {
                showingManualJoin = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Join Shared List")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }

            // Create second (filled + readable)
            Button {
                showingNewListForm = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Create New Transfer List")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "3b82f6"), Color(hex: "8b5cf6")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: - Lists

    private var listsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Lists")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 4)

            if cloudKitManager.transferLists.isEmpty {
                Text("No transfer lists yet. Create one or join a shared list.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.70))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(cloudKitManager.transferLists) { list in
                        NavigationLink(destination: TransferListDetailView(transferList: list)) {
                            TransferListCard(list: list)
                                .environmentObject(cloudKitManager)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Manual Join (paste link)
/// Allows the user to paste a CloudKit share URL, fetch its metadata, and then
/// reuse the existing `JoinListView` (so the join/accept logic stays in one place).
private struct ManualJoinView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Binding var isPresented: Bool

    @State private var shareLink: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var metadata: CKShare.Metadata?

    var body: some View {
        ZStack {
            // Keep styling consistent with the dashboard.
            LinearGradient(
                colors: [Color(hex: "0f172a"), Color(hex: "1e293b")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if let metadata {
                // Hand off to the existing join UI/logic.
                JoinListView(shareMetadata: metadata, isPresented: $isPresented)
                    .environmentObject(cloudKitManager)
            } else {
                VStack(spacing: 16) {
                    HStack {
                        Text("Join Shared List")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button("Close") { isPresented = false }
                            .foregroundColor(.white.opacity(0.9))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Paste share link")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))

                        TextField("icloud.com/share/...", text: $shareLink, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.URL)
                            .padding(12)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red.opacity(0.9))
                        }
                    }
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button {
                        Task { await fetchMetadata() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isLoading ? "Loading…" : "Continue")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "5b6cff"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isLoading)

                    Spacer()
                }
                .padding(16)
            }
        }
    }

    private func fetchMetadata() async {
        let trimmed = shareLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            await MainActor.run { errorMessage = "Invalid link. Please paste the full iCloud share URL." }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let fetched = try await CKContainer.default().shareMetadata(for: url)
            await MainActor.run {
                metadata = fetched
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Could not read this share link. Try copying it again."
            }
            print("ManualJoinView: failed to fetch CKShare metadata: \(error)")
        }
    }
}

// MARK: - Transfer List Card (compact)

struct TransferListCard: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    let list: TransferList

    @State private var shareURL: URL? = nil
    @State private var showingShareSheet = false
    @State private var showShareAlert = false
    @State private var shareAlertMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Created by \(list.createdBy ?? "Me")")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.65))
                }

                Spacer()

                // Compact share button (smaller to show more lists)
                Button {
                    Task { await createShare() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Share")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Share Status", isPresented: $showShareAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(shareAlertMessage)
        }
    }

    @MainActor
    private func createShare() async {
        do {
            let share = try await cloudKitManager.createShare(for: list)
            if let url = share.url {
                shareURL = url
                showingShareSheet = true
            } else {
                shareAlertMessage = "Share created, but no URL was available."
                showShareAlert = true
            }
        } catch {
            shareAlertMessage = "Failed to create share: \(error.localizedDescription)"
            showShareAlert = true
        }
    }
}


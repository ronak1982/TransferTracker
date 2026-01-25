import SwiftUI
import CloudKit
import UIKit

struct DashboardView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Binding var selectedList: TransferList?

    @State private var showingNewListForm = false

    // Manual join (paste share link)
    @State private var showingManualJoin = false
    @State private var manualShareURLString = ""
    @State private var manualJoinError: String?
    @State private var pendingShareMetadata: CKShare.Metadata?
    @State private var showingJoinSheet = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0f172a"), Color(hex: "1e293b")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    joinListButton
                    createListButton

                    listsSection
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingNewListForm) {
            NewListFormView(isPresented: $showingNewListForm)
        }
        .sheet(isPresented: $showingManualJoin) {
            ManualJoinSheet(
                urlString: $manualShareURLString,
                errorMessage: $manualJoinError,
                onJoin: { urlString in
                    await fetchShareMetadata(from: urlString)
                },
                onClose: {
                    showingManualJoin = false
                }
            )
        }
        .sheet(isPresented: $showingJoinSheet, onDismiss: {
            Task { await cloudKitManager.fetchTransferLists() }
        }) {
            if let metadata = pendingShareMetadata {
                JoinListView(shareMetadata: metadata, isPresented: $showingJoinSheet)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Preparing join…")
                        .foregroundColor(Color(hex: "94a3b8"))
                }
                .padding()
            }
        }
        .task { await cloudKitManager.fetchTransferLists() }
        .refreshable { await cloudKitManager.fetchTransferLists() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transfer Tracker")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "60a5fa"), Color(hex: "a78bfa")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("Manage your product transfers with ease")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "94a3b8"))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var joinListButton: some View {
        Button(action: {
            manualJoinError = nil
            showingManualJoin = true
        }) {
            HStack {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 20))
                Text("Join Transfer List")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color(hex: "10b981"), Color(hex: "059669")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color(hex: "10b981").opacity(0.25), radius: 10, y: 5)
        }
    }

    private var createListButton: some View {
        Button(action: { showingNewListForm = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                Text("Create New Transfer List")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color(hex: "3b82f6"), Color(hex: "8b5cf6")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color(hex: "3b82f6").opacity(0.3), radius: 10, y: 5)
        }
    }

    @ViewBuilder
    private var listsSection: some View {
        if cloudKitManager.isLoading {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 50)
        } else if cloudKitManager.transferLists.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 64))
                    .foregroundColor(Color(hex: "64748b").opacity(0.5))

                Text("No transfer lists yet")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "64748b"))

                Text("Create your first list to get started")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "64748b"))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 50)
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(cloudKitManager.transferLists) { list in
                    NavigationLink(destination: TransferListDetailView(transferList: list)) {
                        TransferListCard(list: list)
                    }
                }
            }
        }
    }

    private func fetchShareMetadata(from urlString: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmed), trimmed.contains("icloud.com/share") else {
            await MainActor.run {
                manualJoinError = "Please paste a valid iCloud share link (icloud.com/share/…)."
            }
            return
        }

        await MainActor.run { manualJoinError = nil }

        do {
            let metadata = try await CKContainer.default().shareMetadata(for: url)

            await MainActor.run {
                showingManualJoin = false
                pendingShareMetadata = metadata
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showingJoinSheet = true
                }
            }
        } catch {
            await MainActor.run {
                manualJoinError = "Could not read share link. Please try again.\n\n\(error.localizedDescription)"
            }
        }
    }
}

private struct ManualJoinSheet: View {
    @Binding var urlString: String
    @Binding var errorMessage: String?

    let onJoin: (String) async -> Void
    let onClose: () -> Void

    @State private var isJoining = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0f172a"), Color(hex: "1e293b")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Join Transfer List")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "e2e8f0"))

                    Text("Paste the iCloud share link you received. This is useful if tapping the link did not open the list correctly.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "94a3b8"))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Share Link")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "94a3b8"))

                        TextField("https://icloud.com/share/…", text: $urlString, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(hex: "e2e8f0"))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            )
                    }

                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "fca5a5"))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "7f1d1d").opacity(0.35))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "ef4444").opacity(0.35), lineWidth: 1)
                                    )
                            )
                    }

                    HStack(spacing: 12) {
                        Button {
                            urlString = UIPasteboard.general.string ?? ""
                        } label: {
                            HStack {
                                Image(systemName: "doc.on.clipboard")
                                Text("Paste")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "60a5fa"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "3b82f6").opacity(0.18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "3b82f6").opacity(0.25), lineWidth: 1)
                                    )
                            )
                        }

                        Button {
                            Task {
                                errorMessage = nil
                                isJoining = true
                                defer { isJoining = false }
                                await onJoin(urlString)
                            }
                        } label: {
                            HStack {
                                if isJoining {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                Text(isJoining ? "Joining…" : "Join")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "10b981"), Color(hex: "059669")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .disabled(isJoining || urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity((isJoining || urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.6 : 1)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { onClose() }
                        .foregroundColor(Color(hex: "94a3b8"))
                }
            }
        }
    }
}

struct TransferListCard: View {
    let list: TransferList
    @EnvironmentObject var cloudKitManager: CloudKitManager

    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    @State private var isSharing = false
    @State private var showShareAlert = false
    @State private var shareAlertMessage = ""

    var isShared: Bool {
        list.databaseScope == "shared"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(list.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "e2e8f0"))
                    .lineLimit(2)

                Spacer()

                if isShared {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "10b981"), Color(hex: "059669")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)

                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                    Text("Created by \(list.createdBy)")
                        .font(.system(size: 14))
                        .lineLimit(1)
                }
                .foregroundColor(Color(hex: "94a3b8"))

                if isShared {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "10b981"))
                        Text("Shared list")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "10b981"))
                    }
                }
            }

            Spacer()

            Button(action: {
                Task { await shareList() }
            }) {
                HStack {
                    if isSharing {
                        ProgressView()
                            .tint(Color(hex: "60a5fa"))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "link")
                            .font(.system(size: 14))
                        Text("Share")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(Color(hex: "60a5fa"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "3b82f6").opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "3b82f6").opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSharing)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Share Status", isPresented: $showShareAlert) {
            Button("OK") { }
        } message: {
            Text(shareAlertMessage)
        }
    }

    private func shareList() async {
        await MainActor.run { isSharing = true }

        do {
            let share = try await cloudKitManager.createShare(for: list)

            await MainActor.run {
                isSharing = false

                if let url = share.url {
                    shareURL = url
                    showingShareSheet = true
                } else {
                    shareAlertMessage = "Share was created, but no URL was returned. Try again in a moment."
                    showShareAlert = true
                }
            }
        } catch {
            await MainActor.run {
                isSharing = false
                shareAlertMessage = "Could not create share link.\n\n\(error.localizedDescription)"
                showShareAlert = true
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


// MARK: - Hex Color Helper
extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: (Double(a) / 255) * opacity)
    }
}


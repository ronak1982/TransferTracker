import SwiftUI
import CloudKit

struct DashboardView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Binding var selectedList: TransferList?
    @State private var showingNewListForm = false
    @State private var showingJoinFromLink = false
    @State private var testShareURL = ""
    @State private var pendingShareMetadata: CKShare.Metadata?
    @State private var showingJoinSheet = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "0f172a"), Color(hex: "1e293b")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

            // MARK: - Recent Activity (Phase 5C)
            NavigationLink(destination: ActivityFeedView().environmentObject(cloudKitManager)) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recent Activity")
                            .font(.headline)
                        Text("See what changed across your lists")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

                    // Header
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

                    // Join Shared List Button
                    Button(action: {
                        showingJoinFromLink = true
                    }) {
                        HStack {
                            Image(systemName: "link")
                                .font(.system(size: 18))
                            Text("Join Shared List")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "10b981"))
                        )
                        .shadow(color: Color(hex: "10b981").opacity(0.25), radius: 10, y: 5)
                    }

                    // New List Button
                    Button(action: {
                        showingNewListForm = true
                    }) {
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
                    
                    // Lists Grid
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
                                    TransferListCard(list: list, onShareCreated: { url in
                                        testShareURL = url
                                    })
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingNewListForm) {
            NewListFormView(isPresented: $showingNewListForm)
        }
        .sheet(isPresented: $showingJoinFromLink) {
            JoinFromLinkView(
                isPresented: $showingJoinFromLink,
                shareURL: testShareURL,
                onMetadataFetched: { metadata in
                    // Close test view and show join sheet on main view
                    showingJoinFromLink = false
                    pendingShareMetadata = metadata
                    
                    // Delay slightly to ensure test view is dismissed first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingJoinSheet = true
                    }
                }
            )
        }
        // Join sheet on main dashboard (not on test view!)
        .sheet(isPresented: $showingJoinSheet) {
            // Refresh dashboard when join sheet closes
            Task {
                await cloudKitManager.fetchTransferLists()
            }
        } content: {
            if let metadata = pendingShareMetadata {
                JoinListView(shareMetadata: metadata, isPresented: $showingJoinSheet)
            }
        }
        .task {
            await cloudKitManager.fetchTransferLists()
        }
        .refreshable {
            await cloudKitManager.fetchTransferLists()
        }
    }
}

// Join From Link View - Fetches share metadata from a pasted URL
struct JoinFromLinkView: View {
    @Binding var isPresented: Bool
    let shareURL: String
    let onMetadataFetched: (CKShare.Metadata) -> Void
    
    @State private var manualURL = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0f172a"), Color(hex: "1e293b")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Join Shared List")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "e2e8f0"))
                    
                    Text("Paste a shared link to join a transfer list")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "94a3b8"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if !shareURL.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Created Share:")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "94a3b8"))
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(shareURL)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color(hex: "60a5fa"))
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.05))
                                    )
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = shareURL
                                manualURL = shareURL
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Copy & Use This URL")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "60a5fa"))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(hex: "60a5fa").opacity(0.2))
                                )
                            }
                        }
                        .padding()
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Share URL:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "e2e8f0"))
                        
                        TextEditor(text: $manualURL)
                            .frame(height: 100)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .foregroundColor(Color(hex: "e2e8f0"))
                            .scrollContentBackground(.hidden)
                    }
                    .padding(.horizontal)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        Task {
                            await joinFromLink()
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Join Shared List")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "10b981"))
                    )
                    .padding(.horizontal)
                    .disabled(manualURL.isEmpty || isLoading)
                    .opacity(manualURL.isEmpty ? 0.5 : 1.0)
                    
                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationTitle("Test Join")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0f172a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                    .foregroundColor(Color(hex: "e2e8f0"))
                }
            }
        }
    }
    
    private func joinFromLink() async {
        guard let url = URL(string: manualURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Invalid URL format"
            return
        }
        
        guard url.absoluteString.contains("icloud.com") else {
            errorMessage = "Not a CloudKit share URL"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("JOIN: Fetching share metadata for URL: \(url.absoluteString)")
        
        CKContainer.default().fetchShareMetadata(with: url) { fetchedMetadata, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                    print("JOIN: Error fetching metadata: \(error)")
                    return
                }
                
                if let fetchedMetadata = fetchedMetadata {
                    print("JOIN: Got metadata! Calling parent handler")
                    // Pass metadata back to parent
                    onMetadataFetched(fetchedMetadata)
                } else {
                    errorMessage = "No metadata returned"
                    print("JOIN: No metadata returned")
                }
            }
        }
    }
}

struct TransferListCard: View {
    let list: TransferList
    let onShareCreated: (String) -> Void
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
                Task {
                    await shareList()
                }
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
        await MainActor.run {
            isSharing = true
        }
        
        do {
            let share = try await cloudKitManager.createShare(for: list)
            
            await MainActor.run {
                isSharing = false
                
                if let url = share.url {
                    shareURL = url
                    onShareCreated(url.absoluteString)
                    showingShareSheet = true
                    print("Share URL: \(url.absoluteString)")
                } else {
                    shareAlertMessage = "Share created but no URL was generated. Try again."
                    showShareAlert = true
                }
            }
        } catch {
            await MainActor.run {
                isSharing = false
                shareAlertMessage = "Error creating share: \(error.localizedDescription)"
                showShareAlert = true
            }
            print("❌ Share error: \(error)")
        }
    }
}

// Share Sheet for iOS
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Color extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

#Preview {
    NavigationStack {
        DashboardView(selectedList: .constant(nil))
            .environmentObject(CloudKitManager.shared)
    }
}



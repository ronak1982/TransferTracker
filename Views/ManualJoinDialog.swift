import SwiftUI
import CloudKit
import OSLog

/// Manual join dialog - user pastes iCloud share link to join a list
struct ManualJoinDialog: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Binding var isPresented: Bool
    
    @State private var pastedURL: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var shareMetadata: CKShare.Metadata?
    @State private var showingJoinSheet: Bool = false
    
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TransferTracker",
                             category: "manual-join")
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0f172a"), Color(hex: "1e293b")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Icon
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "60a5fa"), Color(hex: "a78bfa")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.top, 20)
                        
                        VStack(spacing: 12) {
                            Text("Join a Shared List")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(hex: "e2e8f0"))
                            
                            Text("Paste the iCloud share link you received")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "94a3b8"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Paste Area
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Share Link")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "e2e8f0"))
                            
                            TextEditor(text: $pastedURL)
                                .frame(height: 100)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(Color(hex: "e2e8f0"))
                                .scrollContentBackground(.hidden)
                            
                            // Quick paste button
                            Button(action: {
                                if let clipboard = UIPasteboard.general.string {
                                    pastedURL = clipboard
                                }
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Paste from Clipboard")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "60a5fa"))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: "3b82f6").opacity(0.2))
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "1.circle.fill")
                                    .foregroundColor(Color(hex: "60a5fa"))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Get the share link")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(hex: "e2e8f0"))
                                    Text("Ask the list owner to share the link with you via Messages, email, or any messaging app")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "94a3b8"))
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "2.circle.fill")
                                    .foregroundColor(Color(hex: "60a5fa"))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Paste the link above")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(hex: "e2e8f0"))
                                    Text("The link should look like: https://www.icloud.com/share/...")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "94a3b8"))
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "3.circle.fill")
                                    .foregroundColor(Color(hex: "60a5fa"))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Tap Join List")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(hex: "e2e8f0"))
                                    Text("You'll be added as a collaborator and can view/edit transfers")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "94a3b8"))
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "3b82f6").opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "3b82f6").opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)
                        
                        // Error Message
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
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    await processJoinLink()
                                }
                            }) {
                                if isProcessing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    HStack {
                                        Image(systemName: "person.badge.plus")
                                        Text("Join List")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
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
                            .disabled(pastedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                            .opacity(pastedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                            
                            Button(action: {
                                isPresented = false
                            }) {
                                Text("Cancel")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "94a3b8"))
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Join List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0f172a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showingJoinSheet) {
            // Refresh dashboard when join completes
            isPresented = false
        } content: {
            if let metadata = shareMetadata {
                JoinListView(shareMetadata: metadata, isPresented: $showingJoinSheet)
                    .environmentObject(cloudKitManager)
            }
        }
    }
    
    // MARK: - Join Processing
    
    private func processJoinLink() async {
        let trimmed = pastedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            errorMessage = "Please paste a share link"
            return
        }
        
        guard let url = URL(string: trimmed) else {
            errorMessage = "Invalid URL format"
            return
        }
        
        guard url.absoluteString.lowercased().contains("icloud.com") else {
            errorMessage = "This doesn't look like an iCloud share link"
            return
        }
        
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
        }
        
        log.info("🔗 Processing join link: \(url.absoluteString, privacy: .public)")
        
        // Strip any fragment that might interfere
        var canonical = url
        if var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            comps.fragment = nil
            canonical = comps.url ?? url
        }
        
        let container = CKContainer.default()
        
        container.fetchShareMetadata(with: canonical) { metadata, error in
            DispatchQueue.main.async {
                isProcessing = false
                
                if let error = error {
                    log.error("❌ Failed to fetch share metadata: \(error.localizedDescription, privacy: .public)")
                    
                    // Better error messages
                    if error.localizedDescription.contains("already accepted") {
                        errorMessage = "You've already joined this list. Check your dashboard."
                    } else if error.localizedDescription.contains("network") {
                        errorMessage = "Network error. Please check your connection and try again."
                    } else {
                        errorMessage = "Could not load share link. Please verify the link and try again."
                    }
                    return
                }
                
                guard let metadata = metadata else {
                    log.error("❌ No metadata returned")
                    errorMessage = "Invalid share link"
                    return
                }
                
                log.info("✅ Got share metadata, presenting join sheet")
                shareMetadata = metadata
                showingJoinSheet = true
            }
        }
    }
}

#Preview {
    ManualJoinDialog(isPresented: .constant(true))
        .environmentObject(CloudKitManager.shared)
}

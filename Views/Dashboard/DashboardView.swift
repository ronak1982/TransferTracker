import SwiftUI
import CloudKit

struct DashboardView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Binding var selectedList: TransferList?
    @State private var showingNewListForm = false
    
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
                                    TransferListCard(list: list)
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
        .task {
            print("🔍 Dashboard loading...")
            await cloudKitManager.fetchTransferLists()
        }
        .refreshable {
            print("🔄 Manual refresh...")
            await cloudKitManager.fetchTransferLists()
        }
        .onAppear {
            print("👀 Dashboard appeared")
            print("📊 Current lists count: \(cloudKitManager.transferLists.count)")
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
    
    var displayUsers: String {
        if list.authorizedUsers.count >= 2 {
            return "\(list.authorizedUsers[0]) • \(list.authorizedUsers[1])"
        } else if list.authorizedUsers.count == 1 {
            return list.authorizedUsers[0]
        } else {
            return "No users"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(list.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "e2e8f0"))
                .lineLimit(2)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14))
                    Text(displayUsers)
                        .font(.system(size: 14))
                        .lineLimit(1)
                }
                .foregroundColor(Color(hex: "94a3b8"))
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
                    showingShareSheet = true
                } else {
                    shareAlertMessage = "Share created but no URL was generated. Try again."
                    showShareAlert = true
                }
            }
        } catch {
            await MainActor.run {
                isSharing = false
                shareAlertMessage = "Error creating share: \(error.localizedDescription)\n\nMake sure you're signed into iCloud on this device."
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

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    NavigationStack {
        DashboardView(selectedList: .constant(nil))
            .environmentObject(CloudKitManager.shared)
    }
}

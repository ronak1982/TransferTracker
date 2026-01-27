import SwiftUI
import CloudKit

struct DashboardView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Binding var selectedList: TransferList?
    @State private var navigateToListID: String? = nil
    @State private var showingNewListForm = false
    @State private var showingManualJoin = false
    
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
                    
                    // Join List Button
                    Button(action: {
                        showingManualJoin = true
                    }) {
                        HStack {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Join Shared List")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Paste iCloud share link to collaborate")
                                    .font(.system(size: 13))
                                    .opacity(0.85)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "10b981"), Color(hex: "059669")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color(hex: "10b981").opacity(0.3), radius: 10, y: 5)
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
                            
                            Text("Create a new list or join a shared one")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "64748b"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(cloudKitManager.transferLists) { list in
                                TransferListCardWithNavigation(
                                    list: list,
                                    navigateToListID: $navigateToListID
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            
            // ✅ Navigation links at the root level
            ForEach(cloudKitManager.transferLists) { list in
                NavigationLink(
                    destination: TransferListDetailView(transferList: list)
                        .environmentObject(cloudKitManager),
                    tag: list.id,
                    selection: $navigateToListID
                ) {
                    EmptyView()
                }
                .opacity(0)
                .frame(width: 0, height: 0)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingNewListForm) {
            NewListFormView(isPresented: $showingNewListForm)
        }
        .sheet(isPresented: $showingManualJoin) {
            Task {
                await cloudKitManager.fetchTransferLists()
            }
        } content: {
            ManualJoinDialog(isPresented: $showingManualJoin)
                .environmentObject(cloudKitManager)
        }
        .task {
            await cloudKitManager.fetchTransferLists()
        }
        .refreshable {
            await cloudKitManager.fetchTransferLists()
        }
    }
}

// ✅ NEW: Separate component that handles both card display and navigation
struct TransferListCardWithNavigation: View {
    let list: TransferList
    @Binding var navigateToListID: String?
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
            // ✅ Tappable header/content area
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
            }
            .contentShape(Rectangle()) // ✅ Make entire area tappable
            .onTapGesture {
                print("🎯 Card tapped for list: \(list.title)")
                navigateToListID = list.id
            }
            
            Spacer()
            
            // ✅ Share button - separate from tap area
            Button(action: {
                print("📤 Share button tapped for list: \(list.title)")
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
                    print("✅ Share URL: \(url.absoluteString)")
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

#Preview {
    NavigationStack {
        DashboardView(selectedList: .constant(nil))
            .environmentObject(CloudKitManager.shared)
    }
}

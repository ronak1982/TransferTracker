import SwiftUI
import CloudKit

struct JoinListView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    let shareMetadata: CKShare.Metadata
    @Binding var isPresented: Bool
    
    @State private var userName = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0f172a"), Color(hex: "1e293b")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "60a5fa"), Color(hex: "a78bfa")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 12) {
                    Text("Join Transfer List")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "e2e8f0"))
                    
                    if let title = shareMetadata.share[CKShare.SystemFieldKey.title] as? String {
                        Text(title)
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "60a5fa"))
                    }
                    
                    Text("Enter your name to access this list")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "94a3b8"))
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Name")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "e2e8f0"))
                    
                    TextField("e.g., John Smith", text: $userName)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .foregroundColor(Color(hex: "e2e8f0"))
                        .font(.system(size: 18))
                }
                .padding(.horizontal, 32)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                        )
                        .padding(.horizontal, 32)
                }
                
                Button(action: {
                    Task {
                        await joinList()
                    }
                }) {
                    if isJoining {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Join List")
                            .font(.system(size: 18, weight: .semibold))
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
                .padding(.horizontal, 32)
                .disabled(userName.isEmpty || isJoining)
                .opacity(userName.isEmpty ? 0.5 : 1.0)
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Cancel")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "94a3b8"))
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func joinList() async {
        guard !userName.isEmpty else {
            errorMessage = "Please enter your name"
            return
        }
        
        isJoining = true
        errorMessage = nil
        
        do {
            print("🔵 Accepting share...")
            
            // Accept the CloudKit share
            let container = CKContainer.default()
            _ = try await container.accept(shareMetadata)
            
            print("✅ Share accepted, fetching lists...")
            
            // Fetch the shared list
            await cloudKitManager.fetchTransferLists()
            
            // Find the list we just joined
            let shareTitle = shareMetadata.share[CKShare.SystemFieldKey.title] as? String
            
            if let sharedList = cloudKitManager.transferLists.first(where: { $0.title == shareTitle }) {
                print("🔍 Found shared list: \(sharedList.title)")
                print("🔍 Authorized users: \(sharedList.authorizedUsers)")
                print("🔍 User entered: \(userName)")
                
                // ✅ VALIDATE ACCESS
                if cloudKitManager.validateUserAccess(userName: userName, for: sharedList) {
                    print("✅ User is authorized!")
                    
                    await MainActor.run {
                        isPresented = false
                    }
                } else {
                    print("❌ User NOT authorized!")
                    
                    await MainActor.run {
                        errorMessage = """
                        You are not authorized to access this list.
                        
                        Authorized users: \(sharedList.authorizedUsers.joined(separator: ", "))
                        
                        Please enter one of these names exactly.
                        """
                        isJoining = false
                    }
                }
            } else {
                print("⚠️ Could not find shared list, allowing access anyway")
                // Couldn't find list, allow access (CloudKit already accepted)
                await MainActor.run {
                    isPresented = false
                }
            }
        } catch {
            print("❌ Error joining list: \(error)")
            
            await MainActor.run {
                errorMessage = "Failed to join list: \(error.localizedDescription)"
                isJoining = false
            }
        }
    }
}

#Preview {
    Text("Join List View Preview")
        .foregroundColor(.white)
}

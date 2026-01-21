import SwiftUI
import CloudKit

struct JoinListView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    let shareMetadata: CKShare.Metadata
    @Binding var isPresented: Bool
    
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var joinSuccessful = false
    
    var listTitle: String {
        shareMetadata.share[CKShare.SystemFieldKey.title] as? String ?? "Transfer List"
    }
    
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
                
                if joinSuccessful {
                    // Success State
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color(hex: "10b981"))
                    
                    VStack(spacing: 12) {
                        Text("Joined Successfully!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "e2e8f0"))
                        
                        Text("You can now view and edit this list")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "94a3b8"))
                    }
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Done")
                            .font(.system(size: 18, weight: .semibold))
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
                    }
                } else {
                    // Join Request State
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
                        
                        Text(listTitle)
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "60a5fa"))
                        
                        Text("Accept this invitation to collaborate")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "94a3b8"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
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
                        Task { await acceptShare() }
                    }) {
                        if isJoining {
                            ProgressView().tint(.white)
                        } else {
                            Text("Accept Invitation")
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
                    .disabled(isJoining)
                    
                    Button(action: { isPresented = false }) {
                        Text("Cancel")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "94a3b8"))
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func acceptShare() async {
        print("📱 Accepting share...")
        isJoining = true
        errorMessage = nil
        
        do {
            let container = CKContainer.default()
            let acceptedShare = try await container.accept(shareMetadata)
            
            print("✅ Share accepted!")
            print("   Share URL: \(acceptedShare.url?.absoluteString ?? "none")")
            
            let sharedDB = container.sharedCloudDatabase
            
            // ✅ FIXED: rootRecordID is not optional, so no need for guard let
            let rootRecordID = shareMetadata.rootRecordID
            
            print("   Fetching root record: \(rootRecordID.recordName)")
            print("   Zone: \(rootRecordID.zoneID.zoneName), Owner: \(rootRecordID.zoneID.ownerName)")
            
            // Fetch the root record directly using its ID
            let rootRecord = try await sharedDB.record(for: rootRecordID)
            
            var sharedList = TransferList.fromCKRecord(rootRecord)
            sharedList.databaseScope = "shared"
            print("✅ Found shared list: \(sharedList.title)")
            
            // Add to local cache
            try await cloudKitManager.upsertSharedListLocally(sharedList)
            
            print("✅ List added to your dashboard")
            
            await MainActor.run {
                joinSuccessful = true
                isJoining = false
            }
            
            // Auto-close after 1.5 seconds
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                isPresented = false
            }
            
        } catch {
            print("❌ Error accepting share: \(error)")
            await MainActor.run {
                errorMessage = "Failed to accept invitation: \(error.localizedDescription)"
                isJoining = false
            }
        }
    }
}

#Preview {
    Text("Join List View Preview")
}

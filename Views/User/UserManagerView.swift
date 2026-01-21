import SwiftUI
import CloudKit

struct UserManagerView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    let transferList: TransferList
    @Binding var isPresented: Bool
    
    @State private var participants: [ShareParticipant] = []
    @State private var isLoadingParticipants = true
    @State private var showingDeleteConfirmation = false
    @State private var showingLeaveConfirmation = false  // ✅ NEW
    @State private var isDeleting = false
    @State private var errorMessage: String?
    
    var isOwner: Bool {
        transferList.isOwner(currentUserRecordID: cloudKitManager.currentUserRecordID)
    }
    
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
                    VStack(alignment: .leading, spacing: 24) {
                        // List Info Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("List Information")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "e2e8f0"))
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Title")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "94a3b8"))
                                    Text(transferList.title)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "e2e8f0"))
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Created By")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "94a3b8"))
                                    Text(transferList.createdBy)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "e2e8f0"))
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        // Transfer Names Section
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Transfer Names")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "e2e8f0"))
                                Text("Names of entities involved in transfers")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "94a3b8"))
                            }
                            
                            if transferList.transferEntities.isEmpty {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(Color(hex: "60a5fa"))
                                    Text("No transfer names defined. You can add custom names when creating transfers.")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "94a3b8"))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: "3b82f6").opacity(0.1))
                                )
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(transferList.transferEntities, id: \.self) { name in
                                        HStack {
                                            Image(systemName: "tag.fill")
                                                .foregroundColor(Color(hex: "60a5fa"))
                                                .font(.system(size: 14))
                                            
                                            Text(name)
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hex: "e2e8f0"))
                                            
                                            Spacer()
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.05))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                )
                                        )
                                    }
                                }
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        // Collaborators Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Collaborators")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: "e2e8f0"))
                                    Text("People who can view and edit this list")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "94a3b8"))
                                }
                                
                                Spacer()
                                
                                if isLoadingParticipants {
                                    ProgressView()
                                        .tint(Color(hex: "60a5fa"))
                                        .scaleEffect(0.8)
                                }
                            }
                            
                            if transferList.databaseScope == "shared" || !participants.isEmpty {
                                ForEach(participants) { participant in
                                    HStack(spacing: 12) {
                                        Image(systemName: participant.role == .owner ? "crown.fill" : "person.fill")
                                            .foregroundColor(participant.role == .owner ? Color(hex: "f59e0b") : Color(hex: "60a5fa"))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(participant.name)
                                                .font(.system(size: 16))
                                                .foregroundColor(Color(hex: "e2e8f0"))
                                            
                                            Text(participant.roleDescription)
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(hex: "94a3b8"))
                                        }
                                        
                                        Spacer()
                                        
                                        if participant.canDelete {
                                            HStack(spacing: 4) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(Color(hex: "10b981"))
                                                    .font(.system(size: 12))
                                                Text("Can delete")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(Color(hex: "94a3b8"))
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(Color(hex: "10b981").opacity(0.1))
                                            )
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                    )
                                }
                            } else {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(Color(hex: "60a5fa"))
                                    Text("Share this list to add collaborators")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "94a3b8"))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: "3b82f6").opacity(0.1))
                                )
                            }
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
                        }
                        
                        // Owner Actions
                        if isOwner {
                            Divider()
                                .background(Color.white.opacity(0.2))
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Owner Actions")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "e2e8f0"))
                                
                                Button(action: {
                                    showingDeleteConfirmation = true
                                }) {
                                    HStack {
                                        if isDeleting {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "trash.fill")
                                            Text("Delete This List")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(hex: "ef4444"))
                                    )
                                }
                                .disabled(isDeleting)
                                
                                Text("⚠️ This will permanently delete the list and all its transfers for everyone")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "94a3b8"))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                        } else if transferList.databaseScope == "shared" {
                            // ✅ NEW: Participant Actions - Leave List
                            Divider()
                                .background(Color.white.opacity(0.2))
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Participant Actions")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "e2e8f0"))
                                
                                Button(action: {
                                    showingLeaveConfirmation = true
                                }) {
                                    HStack {
                                        if isDeleting {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                            Text("Leave This List")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(hex: "f59e0b"))
                                    )
                                }
                                .disabled(isDeleting)
                                
                                Text("⚠️ You will lose access to this list and all its transfers")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "94a3b8"))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                        } else {
                            // Non-shared list info
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(Color(hex: "60a5fa"))
                                Text("Only the list owner can delete this list")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "94a3b8"))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "3b82f6").opacity(0.1))
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("List Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0f172a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(Color(hex: "e2e8f0"))
                }
            }
        }
        .task {
            await loadParticipants()
        }
        .confirmationDialog(
            "Delete \"\(transferList.title)\"?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                Task { await deleteList() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the list and all transfers for everyone. This cannot be undone.")
        }
        // ✅ NEW: Leave confirmation dialog
        .confirmationDialog(
            "Leave \"\(transferList.title)\"?",
            isPresented: $showingLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave List", role: .destructive) {
                Task { await leaveList() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will lose access to this list and all its transfers. The list will remain available to other participants.")
        }
    }
    
    private func loadParticipants() async {
        isLoadingParticipants = true
        
        do {
            let fetchedParticipants = try await cloudKitManager.fetchShareParticipants(for: transferList)
            
            await MainActor.run {
                participants = fetchedParticipants
                isLoadingParticipants = false
            }
        } catch {
            print("⚠️ Failed to load participants: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingParticipants = false
            }
        }
    }
    
    private func deleteList() async {
        isDeleting = true
        errorMessage = nil
        
        do {
            try await cloudKitManager.deleteTransferList(transferList)
            
            print("✅ List deleted successfully")
            
            // Refresh the dashboard
            await cloudKitManager.fetchTransferLists()
            
            await MainActor.run {
                isPresented = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete list: \(error.localizedDescription)"
                isDeleting = false
            }
        }
    }
    
    // ✅ NEW: Leave list function for participants
    // ✅ NEW: Leave list function for participants
        private func leaveList() async {
            isDeleting = true
            errorMessage = nil
            
            // Remove from local storage only - CloudKit share remains for others
            await MainActor.run {
                if let idx = cloudKitManager.transferLists.firstIndex(where: { $0.id == transferList.id }) {
                    cloudKitManager.transferLists.remove(at: idx)
                    cloudKitManager.saveToLocalStorage()
                }
            }
            
            print("✅ Left shared list")
            
            // Refresh the dashboard
            await cloudKitManager.fetchTransferLists()
            
            await MainActor.run {
                isPresented = false
            }
    }
}

#Preview {
    UserManagerView(
        transferList: TransferList(
            title: "2026 Transfers",
            createdBy: "John Smith"
        ),
        isPresented: .constant(true)
    )
    .environmentObject(CloudKitManager.shared)
}

import SwiftUI

struct UserManagerView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    let transferList: TransferList
    @Binding var isPresented: Bool
    
    @State private var listName: String = ""
    @State private var authorizedUsers: [String] = []
    @State private var newUserName = ""
    @State private var editingIndex: Int?
    @State private var isSaving = false
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
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // List Name Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("List Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "94a3b8"))
                            
                            TextField("Enter list name", text: $listName)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(Color(hex: "e2e8f0"))
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        // Authorized Users Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Authorized Users")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "e2e8f0"))
                            
                            Text("These users can access and add transfers to this list")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "94a3b8"))
                            
                            // Current Users List
                            ForEach(Array(authorizedUsers.enumerated()), id: \.offset) { index, user in
                                HStack {
                                    if editingIndex == index {
                                        TextField("User name", text: Binding(
                                            get: { authorizedUsers[index] },
                                            set: { authorizedUsers[index] = $0 }
                                        ))
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.05))
                                        )
                                        .foregroundColor(Color(hex: "e2e8f0"))
                                        
                                        Button(action: {
                                            editingIndex = nil
                                        }) {
                                            Text("Done")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(Color(hex: "10b981"))
                                        }
                                    } else {
                                        HStack {
                                            Image(systemName: "person.fill")
                                                .foregroundColor(Color(hex: "60a5fa"))
                                            Text(user)
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
                                        
                                        Button(action: {
                                            editingIndex = index
                                        }) {
                                            Image(systemName: "pencil")
                                                .foregroundColor(Color(hex: "60a5fa"))
                                        }
                                        
                                        Button(action: {
                                            authorizedUsers.remove(at: index)
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(Color(hex: "ef4444"))
                                        }
                                    }
                                }
                            }
                            
                            // Add New User
                            HStack {
                                TextField("Add new user", text: $newUserName)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(Color(hex: "e2e8f0"))
                                
                                Button(action: addUser) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(hex: "10b981"))
                                }
                                .disabled(newUserName.trimmingCharacters(in: .whitespaces).isEmpty)
                                .opacity(newUserName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
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
                        
                        // Save Button
                        Button(action: {
                            Task {
                                await saveChanges()
                            }
                        }) {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Save Changes")
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
                        .disabled(isSaving || listName.trimmingCharacters(in: .whitespaces).isEmpty || authorizedUsers.isEmpty)
                        .opacity((listName.trimmingCharacters(in: .whitespaces).isEmpty || authorizedUsers.isEmpty) ? 0.5 : 1.0)
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit List Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0f172a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(Color(hex: "e2e8f0"))
                }
            }
        }
        .onAppear {
            listName = transferList.title
            authorizedUsers = transferList.authorizedUsers
        }
    }
    
    private func addUser() {
        let trimmedName = newUserName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        // Check for duplicates
        if authorizedUsers.contains(where: { $0.lowercased() == trimmedName.lowercased() }) {
            errorMessage = "This user is already in the list"
            return
        }
        
        authorizedUsers.append(trimmedName)
        newUserName = ""
        errorMessage = nil
    }
    
    private func saveChanges() async {
        let trimmedName = listName.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a list name"
            return
        }
        
        guard !authorizedUsers.isEmpty else {
            errorMessage = "Please add at least one authorized user"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            var updatedList = transferList
            updatedList.title = trimmedName
            updatedList.authorizedUsers = authorizedUsers
            
            try await cloudKitManager.updateTransferList(updatedList)
            
            await MainActor.run {
                isPresented = false
            }
            
            // Refresh the lists
            await cloudKitManager.fetchTransferLists()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save changes: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

#Preview {
    UserManagerView(
        transferList: TransferList(
            title: "2026 Transfers",
            authorizedUsers: ["John Smith", "Sarah Johnson"],
            createdBy: "Admin"
        ),
        isPresented: .constant(true)
    )
    .environmentObject(CloudKitManager.shared)
}

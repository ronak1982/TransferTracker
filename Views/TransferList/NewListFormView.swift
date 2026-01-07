import SwiftUI

struct NewListFormView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Binding var isPresented: Bool
    
    @State private var title = ""
    @State private var authorizedUsersText = ""
    @State private var isCreating = false
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
                        Text("Create a new transfer list to track products and collaborate with your team.")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "94a3b8"))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("List Title")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "e2e8f0"))
                            
                            TextField("e.g., '2026 Transfers'", text: $title)
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
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Authorized Users")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "e2e8f0"))
                            
                            Text("Enter names separated by commas")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "64748b"))
                            
                            TextEditor(text: $authorizedUsersText)
                                .frame(height: 120)
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
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                isPresented = false
                            }) {
                                Text("Cancel")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "e2e8f0"))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.1))
                                    )
                            }
                            
                            Button(action: {
                                Task {
                                    await createList()
                                }
                            }) {
                                if isCreating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Create List")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "10b981"))
                            )
                            .disabled(title.isEmpty || isCreating)
                            .opacity(title.isEmpty ? 0.5 : 1.0)
                        }
                        .padding(.top, 12)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Transfer List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0f172a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private func createList() async {
        print("🔵 CREATE LIST BUTTON TAPPED")
        print("🔵 Title: '\(title)'")
        print("🔵 Users text: '\(authorizedUsersText)'")
        
        guard !title.isEmpty else {
            errorMessage = "Please enter a title"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        let users = authorizedUsersText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        print("🔵 Parsed users: \(users)")
        print("🔵 Calling CloudKit createTransferList...")
        
        do {
            let newList = try await cloudKitManager.createTransferList(
                title: title,
                authorizedUsers: users
            )
            
            print("✅ LIST CREATED SUCCESSFULLY!")
            print("✅ List ID: \(newList.id)")
            print("✅ List recordName: \(newList.recordName ?? "nil")")
            print("✅ Current lists in manager: \(cloudKitManager.transferLists.count)")
            
            // Wait a moment for UI to update
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                print("✅ Closing form...")
                isPresented = false
            }
        } catch {
            print("❌ ERROR CREATING LIST!")
            print("❌ Error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            
            await MainActor.run {
                errorMessage = "Failed to create list: \(error.localizedDescription)"
                isCreating = false
            }
        }
    }
}

#Preview {
    NewListFormView(isPresented: .constant(true))
        .environmentObject(CloudKitManager.shared)
}

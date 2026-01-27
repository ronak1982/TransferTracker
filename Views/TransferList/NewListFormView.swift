import SwiftUI

struct NewListFormView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Binding var isPresented: Bool
    
    @State private var title = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var transferEntities: [String] = []
    @State private var newEntityName = ""
    
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
                        Text("Create a new transfer list. Share it with your team to collaborate in real-time.")
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
                        
                        // Transfer Entities Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Transfer Names")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "e2e8f0"))
                            
                            Text("Enter names separated by commas (e.g., Warehouse 1, Store A, John Smith)")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "94a3b8"))
                            
                            TextField("Warehouse 1, Store A, John Smith", text: $newEntityName)
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
                                .onChange(of: newEntityName) {
                                    // Parse comma-separated values in real-time
                                    let names = newEntityName
                                        .split(separator: ",")
                                        .map { $0.trimmingCharacters(in: .whitespaces) }
                                        .filter { !$0.isEmpty }
                                    transferEntities = names
                                }
                            
                            if !transferEntities.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Preview:")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "94a3b8"))
                                    
                                    ForEach(transferEntities, id: \.self) { name in
                                        HStack {
                                            Image(systemName: "tag.fill")
                                                .foregroundColor(Color(hex: "60a5fa"))
                                                .font(.system(size: 12))
                                            
                                            Text(name)
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(hex: "e2e8f0"))
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.white.opacity(0.05))
                                        )
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        
                        // Info box
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Color(hex: "60a5fa"))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Collaborate with your team")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "e2e8f0"))
                                Text("Share this list so others can view and edit transfers. Only you can delete the list.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "94a3b8"))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "3b82f6").opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(hex: "3b82f6").opacity(0.3), lineWidth: 1)
                                )
                        )
                        
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
        guard !title.isEmpty else {
            errorMessage = "Please enter a title"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        do {
            let newList = try await cloudKitManager.createTransferList(title: title, transferEntities: transferEntities)
            
            print("✅ List created: \(newList.id)")
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                isPresented = false
            }
        } catch {
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



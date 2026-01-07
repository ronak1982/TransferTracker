import SwiftUI

struct ProductFormView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    let transferList: TransferList
    var existingProduct: Product?
    @Binding var isPresented: Bool
    var onSave: () -> Void
    
    @State private var name = ""
    @State private var bottles = ""
    @State private var cases = ""
    @State private var costPerUnit = ""
    @State private var notes = ""
    @State private var fromUser = ""
    @State private var toUser = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var isEditing: Bool {
        existingProduct != nil
    }
    
    var availableUsers: [String] {
        transferList.authorizedUsers
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
                        // Transfer Direction Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Transfer Direction")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "e2e8f0"))
                            
                            HStack(spacing: 12) {
                                // From User
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .foregroundColor(Color(hex: "ef4444"))
                                        Text("From")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: "e2e8f0"))
                                    }
                                    
                                    Menu {
                                        ForEach(availableUsers, id: \.self) { user in
                                            Button(user) {
                                                fromUser = user
                                                // Auto-select "To" as the other user
                                                autoSelectToUser()
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(fromUser.isEmpty ? "Select sender" : fromUser)
                                                .foregroundColor(fromUser.isEmpty ? Color(hex: "64748b") : Color(hex: "e2e8f0"))
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(Color(hex: "64748b"))
                                                .font(.system(size: 12))
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
                                
                                // Arrow
                                Image(systemName: "arrow.right")
                                    .foregroundColor(Color(hex: "60a5fa"))
                                    .font(.system(size: 24, weight: .bold))
                                    .padding(.top, 20)
                                
                                // To User
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(Color(hex: "10b981"))
                                        Text("To")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: "e2e8f0"))
                                    }
                                    
                                    Menu {
                                        ForEach(availableUsers, id: \.self) { user in
                                            Button(user) {
                                                toUser = user
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(toUser.isEmpty ? "Select recipient" : toUser)
                                                .foregroundColor(toUser.isEmpty ? Color(hex: "64748b") : Color(hex: "e2e8f0"))
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(Color(hex: "64748b"))
                                                .font(.system(size: 12))
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
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "1e293b"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        // Product Details Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Product Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "e2e8f0"))
                            
                            TextField("e.g., 'Premium Wine'", text: $name)
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
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Bottles")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "e2e8f0"))
                                
                                TextField("0", text: $bottles)
                                    .keyboardType(.decimalPad)
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
                                Text("Cases")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "e2e8f0"))
                                
                                TextField("0", text: $cases)
                                    .keyboardType(.decimalPad)
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
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cost Per Unit")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "e2e8f0"))
                            
                            HStack {
                                Text("$")
                                    .foregroundColor(Color(hex: "94a3b8"))
                                TextField("0.00", text: $costPerUnit)
                                    .keyboardType(.decimalPad)
                                    .foregroundColor(Color(hex: "e2e8f0"))
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
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes (Optional)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "e2e8f0"))
                            
                            TextEditor(text: $notes)
                                .frame(height: 80)
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
                        
                        // Summary Preview
                        if !name.isEmpty && !fromUser.isEmpty && !toUser.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Transfer Summary")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "e2e8f0"))
                                
                                HStack {
                                    Text("\(fromUser) → \(toUser)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: "60a5fa"))
                                }
                                
                                HStack {
                                    Text("Total Units:")
                                        .foregroundColor(Color(hex: "94a3b8"))
                                    Spacer()
                                    Text(String(format: "%.0f", calculateTotalUnits()))
                                        .foregroundColor(Color(hex: "e2e8f0"))
                                        .fontWeight(.semibold)
                                }
                                
                                HStack {
                                    Text("Total Cost:")
                                        .foregroundColor(Color(hex: "94a3b8"))
                                    Spacer()
                                    Text(String(format: "$%.2f", calculateTotalCost()))
                                        .foregroundColor(Color(hex: "10b981"))
                                        .fontWeight(.bold)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "10b981").opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(hex: "10b981").opacity(0.3), lineWidth: 1)
                                    )
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
                                    await saveProduct()
                                }
                            }) {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isEditing ? "Update" : "Add Transfer")
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
                            .disabled(name.isEmpty || fromUser.isEmpty || toUser.isEmpty || isSaving)
                            .opacity((name.isEmpty || fromUser.isEmpty || toUser.isEmpty) ? 0.5 : 1.0)
                        }
                        .padding(.top, 12)
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditing ? "Edit Transfer" : "Add Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0f172a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            if let product = existingProduct {
                name = product.name
                bottles = String(format: "%.0f", product.bottles)
                cases = String(format: "%.0f", product.cases)
                costPerUnit = String(format: "%.2f", product.costPerUnit)
                notes = product.notes
                fromUser = product.fromUser
                toUser = product.toUser
            } else {
                // Default to first user as sender if available
                if !availableUsers.isEmpty {
                    fromUser = availableUsers[0]
                    autoSelectToUser()
                }
            }
        }
    }
    
    // Auto-select "To" user as the other person
    private func autoSelectToUser() {
        if availableUsers.count >= 2 {
            // Find the first user that's not the fromUser
            if let otherUser = availableUsers.first(where: { $0 != fromUser }) {
                toUser = otherUser
            }
        }
    }
    
    private func calculateTotalUnits() -> Double {
        let bottlesCount = Double(bottles) ?? 0
        let casesCount = Double(cases) ?? 0
        return bottlesCount + casesCount
    }
    
    private func calculateTotalCost() -> Double {
        let cost = Double(costPerUnit) ?? 0
        return calculateTotalUnits() * cost
    }
    
    private func saveProduct() async {
        guard !name.isEmpty else {
            errorMessage = "Please enter a product name"
            return
        }
        
        guard !fromUser.isEmpty else {
            errorMessage = "Please select who is sending"
            return
        }
        
        guard !toUser.isEmpty else {
            errorMessage = "Please select who is receiving"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            if let existing = existingProduct {
                // Update existing product
                var updatedProduct = existing
                updatedProduct.name = name
                updatedProduct.bottles = Double(bottles) ?? 0
                updatedProduct.cases = Double(cases) ?? 0
                updatedProduct.costPerUnit = Double(costPerUnit) ?? 0
                updatedProduct.notes = notes
                updatedProduct.fromUser = fromUser
                updatedProduct.toUser = toUser
                updatedProduct.updatedBy = cloudKitManager.currentUserName
                updatedProduct.updatedAt = Date()
                
                try await cloudKitManager.updateProduct(updatedProduct, in: transferList)
            } else {
                // Create new product
                let newProduct = Product(
                    name: name,
                    bottles: Double(bottles) ?? 0,
                    cases: Double(cases) ?? 0,
                    costPerUnit: Double(costPerUnit) ?? 0,
                    notes: notes,
                    fromUser: fromUser,
                    toUser: toUser,
                    addedBy: cloudKitManager.currentUserName.isEmpty ? "Unknown" : cloudKitManager.currentUserName,
                    transferListID: transferList.id
                )
                
                try await cloudKitManager.addProduct(newProduct, to: transferList)
            }
            
            await MainActor.run {
                onSave()
                isPresented = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

#Preview {
    ProductFormView(
        transferList: TransferList(
            title: "2026 Transfers",
            authorizedUsers: ["John Smith", "Sarah Johnson"],
            createdBy: "Admin"
        ),
        isPresented: .constant(true),
        onSave: {}
    )
    .environmentObject(CloudKitManager.shared)
}

import SwiftUI

struct TransferListDetailView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    let transferList: TransferList
    
    @State private var products: [Product] = []
    @State private var isLoading = false
    @State private var showingAddProduct = false
    @State private var showingUserManager = false
    @State private var timeFilter: TimeFilter = .all
    @State private var editingProduct: Product?
    @State private var showingExportOptions = false
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var showingDatePicker = false
    @State private var refreshTrigger = false
    
    var filteredProducts: [Product] {
        let calendar = Calendar.current
        
        return products.filter { product in
            switch timeFilter {
            case .all:
                return true
            case .month:
                let productMonth = calendar.component(.month, from: product.addedAt)
                let productYear = calendar.component(.year, from: product.addedAt)
                return productMonth == selectedMonth && productYear == selectedYear
            case .year:
                let productYear = calendar.component(.year, from: product.addedAt)
                return productYear == selectedYear
            }
        }
    }
    
    var userBreakdown: [(user: String, total: Double)] {
        var breakdown: [String: Double] = [:]
        
        for product in filteredProducts {
            breakdown[product.fromUser, default: 0] += product.totalCost
        }
        
        return breakdown.sorted { $0.key < $1.key }.map { (user: $0.key, total: $0.value) }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0f172a"), Color(hex: "1e293b")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 12) {
                    // User Breakdown Cards
                    VStack(spacing: 12) {
                        ForEach(userBreakdown, id: \.user) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.user)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: "e2e8f0"))
                                    
                                    Text("Sent")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "94a3b8"))
                                }
                                
                                Spacer()
                                
                                Text(String(format: "$%.2f", item.total))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(hex: "60a5fa"))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Time Filter with Date Navigation
                    VStack(spacing: 12) {
                        Picker("Time Period", selection: $timeFilter) {
                            ForEach(TimeFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if timeFilter != .all {
                            HStack {
                                Button(action: {
                                    if timeFilter == .month {
                                        changeMonth(by: -1)
                                    } else {
                                        selectedYear -= 1
                                    }
                                }) {
                                    Image(systemName: "chevron.left")
                                        .foregroundColor(Color(hex: "60a5fa"))
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(0.05))
                                        )
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showingDatePicker = true
                                }) {
                                    HStack {
                                        Image(systemName: "calendar")
                                        Text(currentDateString())
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(Color(hex: "e2e8f0"))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.05))
                                    )
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    if timeFilter == .month {
                                        changeMonth(by: 1)
                                    } else {
                                        selectedYear += 1
                                    }
                                }) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color(hex: "60a5fa"))
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(0.05))
                                        )
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            showingAddProduct = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Transfer")
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
                        }
                        
                        Button(action: {
                            showingUserManager = true
                        }) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        
                        Button(action: {
                            showingExportOptions = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Products List
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 50)
                    } else if filteredProducts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 64))
                                .foregroundColor(Color(hex: "64748b").opacity(0.5))
                            
                            Text("No transfers yet")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "64748b"))
                            
                            Text("Add your first transfer to get started")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "64748b"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredProducts) { product in
                                ProductCard(
                                    product: product,
                                    onEdit: {
                                        editingProduct = product
                                    },
                                    onDelete: {
                                        Task {
                                            await deleteProduct(product)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .navigationTitle(transferList.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "0f172a"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadProducts()
        }
        .refreshable {
            await loadProducts()
        }
        // ✅ FIXED: Updated onChange to use new iOS 17+ syntax (no deprecation warning)
        .onChange(of: refreshTrigger) {
            Task {
                await loadProducts()
            }
        }
        .sheet(isPresented: $showingAddProduct) {
            ProductFormView(
                transferList: transferList,
                isPresented: $showingAddProduct,
                onSave: {
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        refreshTrigger.toggle()
                    }
                }
            )
        }
        .sheet(item: $editingProduct) { product in
            ProductFormView(
                transferList: transferList,
                existingProduct: product,
                isPresented: Binding(
                    get: { editingProduct != nil },
                    set: { if !$0 { editingProduct = nil } }
                ),
                onSave: {
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        refreshTrigger.toggle()
                    }
                }
            )
        }
        .sheet(isPresented: $showingUserManager) {
            UserManagerView(transferList: transferList, isPresented: $showingUserManager)
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(
                transferList: transferList,
                products: filteredProducts,
                isPresented: $showingExportOptions
            )
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerView(
                selectedMonth: $selectedMonth,
                selectedYear: $selectedYear,
                showMonthPicker: timeFilter == .month,
                isPresented: $showingDatePicker
            )
        }
    }
    
    private func currentDateString() -> String {
        if timeFilter == .month {
            let monthName = Calendar.current.monthSymbols[selectedMonth - 1]
            return "\(monthName) \(selectedYear)"
        } else {
            return "\(selectedYear)"
        }
    }
    
    private func changeMonth(by value: Int) {
        selectedMonth += value
        if selectedMonth > 12 {
            selectedMonth = 1
            selectedYear += 1
        } else if selectedMonth < 1 {
            selectedMonth = 12
            selectedYear -= 1
        }
    }
    
    private func loadProducts() async {
        isLoading = true
        do {
            let fetchedProducts = try await cloudKitManager.fetchProducts(for: transferList)
            await MainActor.run {
                products = fetchedProducts
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func deleteProduct(_ product: Product) async {
        do {
            try await cloudKitManager.deleteProduct(product, from: transferList)
            await loadProducts()
        } catch {
            print("❌ Error deleting product: \(error)")
        }
    }
}

// Date Picker View
struct DatePickerView: View {
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    let showMonthPicker: Bool
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0f172a"), Color(hex: "1e293b")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    if showMonthPicker {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Month")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "94a3b8"))
                            
                            Picker("Month", selection: $selectedMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Year")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "94a3b8"))
                        
                        Picker("Year", selection: $selectedYear) {
                            ForEach(2020...2030, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "10b981"))
                            )
                    }
                }
                .padding()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0f172a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

struct ProductCard: View {
    let product: Product
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "e2e8f0"))
                    
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "ef4444"))
                        Text(product.fromUser)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "ef4444"))
                        
                        Image(systemName: "arrow.forward")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "60a5fa"))
                        
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "10b981"))
                        Text(product.toUser)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "10b981"))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "60a5fa"))
                    }
                    
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "ef4444"))
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bottles")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "94a3b8"))
                    Text(String(format: "%.0f", product.bottles))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "e2e8f0"))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cases")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "94a3b8"))
                    Text(String(format: "%.0f", product.cases))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "e2e8f0"))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cost/Unit")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "94a3b8"))
                    Text(String(format: "$%.2f", product.costPerUnit))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "e2e8f0"))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "94a3b8"))
                    Text(String(format: "$%.2f", product.totalCost))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "10b981"))
                }
            }
            
            if !product.notes.isEmpty {
                Text(product.notes)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "94a3b8"))
                    .padding(.top, 4)
            }
            
            HStack {
                Text("Logged by \(product.addedBy)")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "64748b"))
                
                Spacer()
                
                Text(product.addedAt, style: .date)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "64748b"))
            }
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .confirmationDialog(
            "Delete this transfer?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }
}

// ✅ FIXED PREVIEW - Uses new model structure (no authorizedUsers)
#Preview {
    NavigationStack {
        TransferListDetailView(
            transferList: TransferList(
                title: "2026 Transfers",
                createdBy: "Admin"
            )
        )
        .environmentObject(CloudKitManager.shared)
    }
}


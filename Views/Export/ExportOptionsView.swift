import SwiftUI
import PDFKit

// Enhanced Export Options View with Multiple Formats
struct ExportOptionsView: View {
    let transferList: TransferList
    let products: [Product]
    @Binding var isPresented: Bool
    @State private var showingShareSheet = false
    @State private var exportItems: [Any] = []
    
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
                    VStack(spacing: 20) {
                        Text("Choose your export format")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "94a3b8"))
                            .multilineTextAlignment(.center)
                            .padding(.top)
                        
                        // PDF Export
                        ExportButton(
                            icon: "doc.richtext",
                            title: "Export as PDF",
                            description: "Professional document format",
                            gradient: [Color(hex: "ef4444"), Color(hex: "dc2626")]
                        ) {
                            exportAsPDF()
                        }
                        
                        // Excel Export
                        ExportButton(
                            icon: "tablecells",
                            title: "Export as Excel",
                            description: "Microsoft Excel spreadsheet (.xlsx)",
                            gradient: [Color(hex: "10b981"), Color(hex: "059669")]
                        ) {
                            exportAsExcel()
                        }
                        
                        // CSV Export
                        ExportButton(
                            icon: "doc.text",
                            title: "Export as CSV",
                            description: "Comma-separated values",
                            gradient: [Color(hex: "3b82f6"), Color(hex: "2563eb")]
                        ) {
                            exportAsCSV()
                        }
                        
                        // Numbers Export
                        ExportButton(
                            icon: "chart.bar.doc.horizontal",
                            title: "Export for Numbers",
                            description: "Apple Numbers compatible",
                            gradient: [Color(hex: "f59e0b"), Color(hex: "d97706")]
                        ) {
                            exportForNumbers()
                        }
                        
                        // Cancel Button
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "e2e8f0"))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0f172a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: exportItems)
        }
    }
    
    // MARK: - Export Functions
    
    private func exportAsPDF() {
        let pdfData = generatePDF()
        
        // Save to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(transferList.title).pdf")
        try? pdfData.write(to: tempURL)
        
        exportItems = [tempURL]
        showingShareSheet = true
    }
    
    private func exportAsExcel() {
        let excelContent = generateExcelXML()
        
        // Save to temporary file with .xls extension (Excel XML format)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(transferList.title).xls")
        try? excelContent.write(to: tempURL, atomically: true, encoding: .utf8)
        
        exportItems = [tempURL]
        showingShareSheet = true
    }
    
    private func exportAsCSV() {
        let csv = generateCSV()
        exportItems = [csv]
        showingShareSheet = true
    }
    
    private func exportForNumbers() {
        // Numbers can open Excel files, so we use the same format
        let excelContent = generateExcelXML()
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(transferList.title).xls")
        try? excelContent.write(to: tempURL, atomically: true, encoding: .utf8)
        
        exportItems = [tempURL]
        showingShareSheet = true
    }
    
    // MARK: - Generation Functions
    
    private func generatePDF() -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "Transfer Tracker",
            kCGPDFContextTitle: transferList.title
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 60
            
            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            let title = transferList.title
            title.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40
            
            // Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            let dateStr = "Generated: \(dateFormatter.string(from: Date()))"
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            dateStr.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: dateAttributes)
            yPosition += 40
            
            // User Totals
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.black
            ]
            
            "User Totals:".draw(at: CGPoint(x: 60, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25
            
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            
            // Calculate totals
            var userTotals: [String: Double] = [:]
            for product in products {
                userTotals[product.fromUser, default: 0] += product.totalCost
            }
            
            for (user, total) in userTotals.sorted(by: { $0.key < $1.key }) {
                let line = "\(user) sent: $\(String(format: "%.2f", total))"
                line.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: normalAttributes)
                yPosition += 20
            }
            
            yPosition += 20
            
            // Products Header
            "Transfers:".draw(at: CGPoint(x: 60, y: yPosition), withAttributes: headerAttributes)
            yPosition += 30
            
            // Column Headers
            let smallBoldAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 10),
                .foregroundColor: UIColor.black
            ]
            
            "Product".draw(at: CGPoint(x: 60, y: yPosition), withAttributes: smallBoldAttributes)
            "From".draw(at: CGPoint(x: 180, y: yPosition), withAttributes: smallBoldAttributes)
            "To".draw(at: CGPoint(x: 260, y: yPosition), withAttributes: smallBoldAttributes)
            "Bottles".draw(at: CGPoint(x: 330, y: yPosition), withAttributes: smallBoldAttributes)
            "Cases".draw(at: CGPoint(x: 390, y: yPosition), withAttributes: smallBoldAttributes)
            "$/Unit".draw(at: CGPoint(x: 440, y: yPosition), withAttributes: smallBoldAttributes)
            "Total".draw(at: CGPoint(x: 500, y: yPosition), withAttributes: smallBoldAttributes)
            yPosition += 20
            
            // Products
            let smallAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.black
            ]
            
            for product in products {
                // Check if we need a new page
                if yPosition > 720 {
                    context.beginPage()
                    yPosition = 60
                }
                
                product.name.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: smallAttributes)
                product.fromUser.draw(at: CGPoint(x: 180, y: yPosition), withAttributes: smallAttributes)
                product.toUser.draw(at: CGPoint(x: 260, y: yPosition), withAttributes: smallAttributes)
                "\(Int(product.bottles))".draw(at: CGPoint(x: 330, y: yPosition), withAttributes: smallAttributes)
                "\(Int(product.cases))".draw(at: CGPoint(x: 390, y: yPosition), withAttributes: smallAttributes)
                "$\(String(format: "%.2f", product.costPerUnit))".draw(at: CGPoint(x: 440, y: yPosition), withAttributes: smallAttributes)
                "$\(String(format: "%.2f", product.totalCost))".draw(at: CGPoint(x: 500, y: yPosition), withAttributes: smallAttributes)
                yPosition += 20
            }
        }
        
        return data
    }
    
    private func generateExcelXML() -> String {
        var xml = """
        <?xml version="1.0"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
                  xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
        <Worksheet ss:Name="Transfers">
        <Table>
        """
        
        // Header Row
        xml += """
        <Row>
            <Cell><Data ss:Type="String">Product Name</Data></Cell>
            <Cell><Data ss:Type="String">From User</Data></Cell>
            <Cell><Data ss:Type="String">To User</Data></Cell>
            <Cell><Data ss:Type="String">Bottles</Data></Cell>
            <Cell><Data ss:Type="String">Cases</Data></Cell>
            <Cell><Data ss:Type="String">Cost Per Unit</Data></Cell>
            <Cell><Data ss:Type="String">Total Cost</Data></Cell>
            <Cell><Data ss:Type="String">Date</Data></Cell>
            <Cell><Data ss:Type="String">Notes</Data></Cell>
        </Row>
        """
        
        // Data Rows
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        for product in products {
            let dateString = dateFormatter.string(from: product.addedAt)
            xml += """
            <Row>
                <Cell><Data ss:Type="String">\(product.name.xmlEscaped)</Data></Cell>
                <Cell><Data ss:Type="String">\(product.fromUser.xmlEscaped)</Data></Cell>
                <Cell><Data ss:Type="String">\(product.toUser.xmlEscaped)</Data></Cell>
                <Cell><Data ss:Type="Number">\(product.bottles)</Data></Cell>
                <Cell><Data ss:Type="Number">\(product.cases)</Data></Cell>
                <Cell><Data ss:Type="Number">\(product.costPerUnit)</Data></Cell>
                <Cell><Data ss:Type="Number">\(product.totalCost)</Data></Cell>
                <Cell><Data ss:Type="String">\(dateString)</Data></Cell>
                <Cell><Data ss:Type="String">\(product.notes.xmlEscaped)</Data></Cell>
            </Row>
            """
        }
        
        xml += """
        </Table>
        </Worksheet>
        </Workbook>
        """
        
        return xml
    }
    
    private func generateCSV() -> String {
        var csv = "Product Name,From User,To User,Bottles,Cases,Cost Per Unit,Total Cost,Date,Notes\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        for product in products {
            let dateString = dateFormatter.string(from: product.addedAt)
            csv += "\"\(product.name)\",\"\(product.fromUser)\",\"\(product.toUser)\",\(product.bottles),\(product.cases),\(product.costPerUnit),\(product.totalCost),\(dateString),\"\(product.notes)\"\n"
        }
        
        return csv
    }
}

// MARK: - Export Button Component

struct ExportButton: View {
    let icon: String
    let title: String
    let description: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "e2e8f0"))
                    
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "94a3b8"))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(hex: "64748b"))
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
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - XML Escaping Extension

extension String {
    var xmlEscaped: String {
        return self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

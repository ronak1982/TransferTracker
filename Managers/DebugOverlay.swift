import SwiftUI
import Combine

// Debug Logger Class
class DebugLogger: ObservableObject {
    static let shared = DebugLogger()
    
    @Published var logs: [String] = []
    
    private init() {}
    
    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            self.logs.append(logEntry)
            print(logEntry) // Also print to Xcode console
        }
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
}

struct DebugOverlay: View {
    @ObservedObject var logger: DebugLogger
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Button(action: {
                    isExpanded.toggle()
                }) {
                    HStack {
                        Text("🐛 Debug Logs (\(logger.logs.count))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(Color.purple)
                }
                
                // Expandable log list
                if isExpanded {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(logger.logs.enumerated().reversed()), id: \.offset) { index, log in
                                Text(log)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    .background(Color.black.opacity(0.9))
                    
                    // Clear button
                    Button(action: {
                        logger.clear()
                    }) {
                        Text("Clear Logs")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(Color.red)
                    }
                }
            }
            .cornerRadius(8)
            .shadow(radius: 10)
        }
        .padding()
    }
}

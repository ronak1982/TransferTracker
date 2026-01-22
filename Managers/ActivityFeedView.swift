import SwiftUI

struct ActivityFeedView: View {
    // IMPORTANT:
    // This reads your locally-cached activity events stored in UserDefaults.
    // It does NOT query CloudKit (so it avoids recordName/queryable issues).
    
    private let eventsKeyPrefix = "SavedChangeEventsKey_"
    
    @State private var events: [ChangeEvent] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0f172a"), Color(hex: "1e293b")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 12)
                    } else if events.isEmpty {
                        Text("No activity yet.")
                            .foregroundColor(Color.white.opacity(0.75))
                            .padding(.top, 8)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(events) { e in
                                ActivityRow(event: e)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFromUserDefaults() }
    }
    
    private func loadFromUserDefaults() {
        isLoading = true
        
        let defaults = UserDefaults.standard
        let all = defaults.dictionaryRepresentation()
        
        var merged: [ChangeEvent] = []
        
        for (key, value) in all {
            guard key.hasPrefix(eventsKeyPrefix) else { continue }
            // Your cache is typically Data stored under the key.
            if let data = value as? Data {
                if let decoded = try? JSONDecoder().decode([ChangeEvent].self, from: data) {
                    merged.append(contentsOf: decoded)
                }
            }
        }
        
        // Newest first
        merged.sort { $0.createdAt > $1.createdAt }
        
        // Keep it lightweight in the dashboard/feed
        events = Array(merged.prefix(150))
        isLoading = false
    }
}

private struct ActivityRow: View {
    let event: ChangeEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 10, height: 10)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(event.summary)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Text(event.createdAt, style: .date)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.65))
                }
                
                HStack(spacing: 8) {
                    // Avoid hard dependency on a computed property name in the model.
                    // If the model changes, this remains stable.
                    Text((event.actorName?.isEmpty == false) ? (event.actorName ?? "") : "Someone")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.70))
                    
                    Text("•")
                        .foregroundColor(Color.white.opacity(0.35))
                    
                    Text("\(event.entityType) \(event.action)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.65))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}


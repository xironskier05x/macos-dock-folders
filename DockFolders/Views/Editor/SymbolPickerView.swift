import SwiftUI

public struct SymbolPickerView: View {
    @Binding var selectedSymbol: String
    @State private var searchSymbol: String = ""

    let popularSymbols = [
        "folder.badge.gear", "sparkles", "terminal.fill", "wrench.and.screwdriver", "hammer.fill",
        "cpu", "cloud.fill", "music.note", "photo.fill", "film.fill", "gamecontroller.fill",
        "book.fill", "briefcase.fill", "chart.bar.fill", "cart.fill", "paintpalette.fill",
        "desktopcomputer", "laptopcomputer", "externaldrive.fill", "network", "bolt.fill",
        "star.fill", "heart.fill", "bookmark.fill", "tag.fill", "bell.fill", "lock.fill",
        "person.2.fill", "cube.box.fill", "doc.text.fill"
    ]

    var filteredSymbols: [String] {
        let q = searchSymbol.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return popularSymbols }
        return popularSymbols.filter { $0.contains(q) }
    }

    var isValidCustomSymbol: Bool {
        NSImage(systemSymbolName: selectedSymbol, accessibilityDescription: nil) != nil
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SF Symbol")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                TextField("Search or Enter Symbol…", text: $selectedSymbol)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
            }

            if !selectedSymbol.isEmpty && !isValidCustomSymbol {
                Text("⚠️ '\(selectedSymbol)' is not recognized as a valid SF Symbol.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter popular symbols…", text: $searchSymbol)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(6)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(filteredSymbols, id: \.self) { symbol in
                    let isSelected = selectedSymbol == symbol
                    Button(action: { selectedSymbol = symbol }) {
                        Image(systemName: symbol)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

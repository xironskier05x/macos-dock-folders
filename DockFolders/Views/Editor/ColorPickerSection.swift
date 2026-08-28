import SwiftUI

public struct ColorPickerSection: View {
    @Binding var selectedHex: String

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tile Color")
                .font(.subheadline)
                .fontWeight(.medium)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(IconConfiguration.presetColors, id: \.hex) { preset in
                    let isSelected = selectedHex.uppercased() == preset.hex.uppercased()
                    Button(action: { selectedHex = preset.hex }) {
                        Circle()
                            .fill(Color(nsColor: preset.color))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: isSelected ? 2.5 : 0)
                                    .padding(-2)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(preset.name)
                }
            }
        }
    }
}

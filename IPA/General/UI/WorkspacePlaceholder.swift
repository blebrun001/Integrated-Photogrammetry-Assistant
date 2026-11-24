import SwiftUI

struct WorkspacePlaceholder<Action: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: Text
    var dropTargeted: Bool? = nil
    @ViewBuilder let action: () -> Action

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 76, height: 76)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
                .accessibilityHidden(true)
            Text(title).font(.title2.weight(.semibold))
            detail.foregroundStyle(.secondary)
            action().controlSize(.large).padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(dropTargeted == true ? Color.accentColor : Color(nsColor: .separatorColor),
                              style: StrokeStyle(lineWidth: dropTargeted == true ? 2 : 1, dash: dropTargeted == nil ? [] : [6, 5]))
                .allowsHitTesting(false)
        }
    }
}

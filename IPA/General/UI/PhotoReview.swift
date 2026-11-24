import SwiftUI

struct PhotoReview: View {
    @ObservedObject var session: PhotoSession
    let review: Bool
    let next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button("Add photos…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = true
                    if panel.runModal() == .OK { session.add(panel.urls) }
                }
                Text("\(session.selected.count) / \(session.photos.count) selected")
                Spacer()
                Button(review ? "Reconstruct" : "Review photos", action: next)
                    .disabled(review ? session.selected.isEmpty : session.photos.isEmpty)
            }
            if review {
                HStack {
                    tolerance("Blur", $session.blur)
                    tolerance("Highlights", $session.highlights)
                    tolerance("Shadows", $session.shadows)
                }
                HStack {
                    Toggle("Deselect flagged photos", isOn: $session.exclude)
                    Button("Analyze again") { session.analyze() }
                }
            }
            Text(session.status).font(.caption).foregroundStyle(.secondary)
            if session.photos.isEmpty {
                ContentUnavailableView("Drop photos or a folder here", systemImage: "photo.on.rectangle")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))]) {
                        ForEach($session.photos) { $photo in
                            VStack(alignment: .leading) {
                                if let thumb = photo.preview {
                                    Image(nsImage: thumb).resizable().scaledToFit().frame(height: 96)
                                }
                                Toggle(photo.id.lastPathComponent, isOn: Binding(
                                    get: { photo.selected },
                                    set: { photo.selected = $0; photo.manualSelection = true }
                                ))
                                    .lineLimit(1).help(photo.id.path)
                                Text(photo.defects.map { NSLocalizedString($0, comment: "Photo quality") }.joined(separator: " · ")).font(.caption).foregroundStyle(.orange)
                            }.padding(6)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in session.add(urls); return true }
    }

    private func tolerance(_ label: String, _ value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            Text("\(NSLocalizedString(label, comment: "Photo quality")) tolerance · \(Int(value.wrappedValue * 100))%").font(.caption)
            Slider(value: value, in: 0...1)
        }
    }
}

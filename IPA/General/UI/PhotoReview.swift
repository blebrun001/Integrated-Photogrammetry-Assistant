import SwiftUI

struct PhotoReview: View {
    @ObservedObject var session: PhotoSession
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Source photos")
                        .font(.title.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("\(session.selected.count) / \(session.photos.count) selected")
                        .monospacedDigit().foregroundStyle(.secondary)
                }
                Spacer()
                if !session.photos.isEmpty {
                    Button("Add photos…", systemImage: "plus", action: choosePhotos)
                }
            }
            if !session.photos.isEmpty { qualityControls }
            if session.photos.isEmpty {
                WorkspacePlaceholder(
                    symbol: "photo.stack",
                    title: "Drop photos or a folder here",
                    detail: Text("Original files stay in their current location."),
                    dropTargeted: dropTargeted
                ) {
                    Button("Add photos…", systemImage: "plus", action: choosePhotos)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        ForEach($session.photos) { $photo in
                            PhotoTile(photo: $photo)
                        }
                    }.padding(3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if dropTargeted {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .allowsHitTesting(false)
                    }
                }
            }
            if !session.status.isEmpty {
                Divider()
                Text(session.status).font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in
            session.add(urls)
            return true
        } isTargeted: { dropTargeted = $0 }
    }

    private var qualityControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Photo quality", systemImage: "slider.horizontal.3").font(.headline)
                Spacer()
                Toggle("Deselect flagged photos", isOn: $session.exclude)
                Button("Analyze again", systemImage: "arrow.clockwise") { session.analyze() }
            }
            HStack(spacing: 24) {
                tolerance("Blur", $session.blur)
                tolerance("Highlights", $session.highlights)
                tolerance("Shadows", $session.shadows)
            }
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func tolerance(_ label: String, _ value: Binding<Double>) -> some View {
        let name = NSLocalizedString(label, comment: "Photo quality")
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(name) tolerance · \(Int(value.wrappedValue * 100))%")
                .font(.callout).monospacedDigit()
            Slider(value: value, in: 0...1) { Text(name) }.labelsHidden()
        }
    }

    private func choosePhotos() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { session.add(panel.urls) }
    }
}

private struct PhotoTile: View {
    @Binding var photo: PhotoItem

    var body: some View {
        Toggle(isOn: Binding(get: { photo.selected }, set: {
            photo.selected = $0
            photo.manualSelection = true
        })) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Rectangle().fill(.quaternary)
                    if let thumb = photo.preview {
                        Image(nsImage: thumb).resizable().scaledToFit()
                    } else {
                        Image(systemName: "photo").font(.title).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 104)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: photo.selected ? "checkmark.square.fill" : "square")
                            .foregroundStyle(photo.selected ? Color.accentColor : .secondary)
                        Text(photo.id.lastPathComponent)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    if !photo.defects.isEmpty {
                        Label(photo.defects.map { NSLocalizedString($0, comment: "Photo quality") }
                            .joined(separator: " · "), systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(photo.selected ? Color.accentColor.opacity(0.65) : Color(nsColor: .separatorColor))
            }
            .contentShape(Rectangle())
        }
        .toggleStyle(.button)
        .buttonStyle(.plain)
        .accessibilityIdentifier("photo.\(photo.id.lastPathComponent)")
        .help(photo.id.path)
    }
}

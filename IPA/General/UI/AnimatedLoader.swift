import SwiftUI

struct AnimatedLoader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frame = 1

    var body: some View {
        Image("img\(frame)")
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
            .task(id: reduceMotion) {
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(100)) }
                    catch { return }
                    frame = frame % 24 + 1
                }
            }
    }
}

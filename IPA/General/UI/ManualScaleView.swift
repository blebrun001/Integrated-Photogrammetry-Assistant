import SwiftUI

struct ManualScaleView: View {
    @ObservedObject var model: ViewerViewModel
    @State private var distance: Double?
    @State private var picking = true

    var body: some View {
        Form {
            Section {
                Text("Click two points, then add their known distance.")
                    .foregroundStyle(.secondary)
                Picker("Interaction", selection: $picking) {
                    Text("Place points").tag(true)
                    Text("Orbit camera").tag(false)
                }
                .pickerStyle(.segmented)
                .onChange(of: picking) { model.setManualPicking(picking) }
                Text("Points selected: \(model.manualPoints) / 2")
                    .monospacedDigit()
            }
            Section("Reference") {
                HStack {
                    TextField("Distance (cm)", value: $distance, format: .number)
                        .textFieldStyle(.roundedBorder)
                    Button("Add reference") {
                        if let distance { model.addManualReference(distance) }
                    }
                    .disabled(model.manualPoints != 2 || (distance ?? 0) <= 0)
                }
                Text("\(model.manualReferences) reference(s)")
                    .foregroundStyle(.secondary)
                Button("Apply calibration") { model.applyManualScale() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.manualReferences == 0)
            }
            Section("Calibration") {
                if model.calibration.isEmpty {
                    Text("Uncalibrated")
                } else {
                    Text("Calibrated") + Text(" · ") + Text(LocalizedStringKey(model.calibration))
                }
            }
        }
        .formStyle(.grouped)
        .disabled(model.source == nil)
    }
}

//  DataverseUploadTabView.swift
//  Wrapper view that hosts the Dataverse uploader inside IPA's module layout.

import SwiftUI

struct DataverseUploadTabView: View {
    @StateObject private var adapter: IPASettingsAdapter

    let suggestedFile: URL?

    init(suggestedFile: URL? = nil, settingsManager: SettingsManager = SettingsManager.instance) {
        self.suggestedFile = suggestedFile
        _adapter = StateObject(wrappedValue: IPASettingsAdapter(settingsManager: settingsManager))
    }

    var body: some View {
        DataverseUploadView(adapter: adapter, client: DataverseClient.self, suggestedFile: suggestedFile)
            .padding(.bottom, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

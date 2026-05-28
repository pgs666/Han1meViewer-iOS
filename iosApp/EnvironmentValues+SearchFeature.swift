import SwiftUI
import Han1meShared

private struct SearchFeatureKey: EnvironmentKey {
    static let defaultValue: SearchFeature? = nil
}

extension EnvironmentValues {
    /// Globally-injected SearchFeature so deep child views (e.g. the artist
    /// card inside VideoDetailView) can navigate to artist-videos lists
    /// without every intermediate view having to thread a SearchFeature
    /// parameter. Set once in Han1meViewerApp via .environment(\.searchFeature, ...).
    var searchFeature: SearchFeature? {
        get { self[SearchFeatureKey.self] }
        set { self[SearchFeatureKey.self] = newValue }
    }
}

import SwiftUI

/// Wraps a tab's content so it is only instantiated the first time that tab is selected.
/// Subsequent selections reuse the already-alive view, preserving scroll position and state.
struct LazyTabContent<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder let content: () -> Content
    @State private var hasBeenSelected = false

    var body: some View {
        Group {
            if hasBeenSelected {
                content()
            } else {
                Color.clear
            }
        }
        .onAppear {
            if isSelected { hasBeenSelected = true }
        }
        .onChange(of: isSelected) { _, selected in
            if selected { hasBeenSelected = true }
        }
    }
}

import SwiftUI

struct MenuBarTitleView: View {
    @StateObject private var viewModel = MenuBarViewModel()

    var body: some View {
        Text(viewModel.title.isEmpty ? "—:—" : viewModel.title)
            .monospacedDigit()
    }
}

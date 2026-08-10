import SwiftUI

struct MoreOverviewFixtureHostView: View {
    @State private var state: MoreOverviewState

    init(state: MoreOverviewState) {
        _state = State(initialValue: state)
    }

    var body: some View {
        MoreOverviewScreenView(state: $state, isLiveMode: false)
    }
}

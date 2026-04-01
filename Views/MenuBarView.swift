import SwiftUI

// MARK: - Menu Bar View
struct MenuBarView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.currentSongTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appTextPrimary)
                .lineLimit(1)
            
            if !viewModel.artist.isEmpty {
                Text(viewModel.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
            }
            
            HStack(spacing: 12) {
                Button(action: { viewModel.previousSong() }) {
                    Image(systemName: "backward.end.fill")
                }
                Button(action: { viewModel.togglePlayPause() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }
                Button(action: { viewModel.nextSong() }) {
                    Image(systemName: "forward.end.fill")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.appHighlight)
            
            Divider()
                .overlay(Color.appDivider)
            
            Button(L10n.t(.playlist)) {
                openWindow(id: "playlist")
            }
            Button("Wored") {
                openWindow(id: "player")
            }
        }
        .padding(10)
        .frame(width: 220)
        .background(Color.appBackground)
    }
}

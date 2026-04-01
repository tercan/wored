import SwiftUI

// MARK: - Legacy ContentView (for compatibility)
struct ContentView: View {
    @StateObject private var viewModel = AudioPlayerViewModel()
    
    var body: some View {
        PlayerView(viewModel: viewModel)
    }
}

// MARK: - Info Row Helper
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.appTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.appTextPrimary)
        }
    }
}

struct InfoLinkRow: View {
    let label: String
    let title: String
    let url: URL
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.appTextSecondary)
            Spacer()
            Link(title, destination: url)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .underline()
        }
    }
}

#Preview {
    ContentView()
}

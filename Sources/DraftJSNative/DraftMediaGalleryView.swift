import AVKit
import SwiftUI

struct DraftMediaGalleryView: View {
    let items: [DraftMediaItem]
    let caption: String?
    let mediaURLForID: (String) -> URL?
    let playbackURLForID: (String) -> URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if items.isEmpty {
                Text("Media unavailable").foregroundStyle(.secondary)
            } else if items.count == 1 {
                DraftMediaTileView(item: items[0], url: mediaURLForID(items[0].mediaID),
                                   playbackURL: playbackURLForID(items[0].mediaID), isGallery: false)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(items.indices, id: \.self) { index in
                        DraftMediaTileView(
                            item: items[index],
                            url: mediaURLForID(items[index].mediaID),
                            playbackURL: playbackURLForID(items[index].mediaID),
                            isGallery: true
                        )
                    }
                }
            }
            if let caption, !caption.isEmpty {
                Text(caption).font(.system(size: 14)).foregroundStyle(.secondary)
            }
        }
    }
}

private struct DraftMediaTileView: View {
    let item: DraftMediaItem
    let url: URL?
    let playbackURL: URL?
    let isGallery: Bool

    private var isPlayable: Bool {
        let category = item.category?.lowercased() ?? ""
        return category.contains("video") || category.contains("gif")
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if isPlayable, let playbackURL {
                DraftVideoPlayerView(url: playbackURL, height: isGallery ? 180 : 240)
            } else if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        if isGallery {
                            image.resizable().scaledToFill()
                        } else {
                            image.resizable().scaledToFit()
                        }
                    case .failure:
                        unavailable
                    case .empty:
                        ProgressView()
                    @unknown default:
                        unavailable
                    }
                }
            } else {
                unavailable
            }
            if let category = item.category?.lowercased(), isPlayable, playbackURL == nil {
                Text(category.contains("gif") ? "GIF" : "Video")
                    .font(.caption.weight(.semibold))
                    .padding(6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isGallery ? 180 : nil)
        .clipped()
        .accessibilityLabel(isPlayable && playbackURL == nil
            ? "Video poster; playback URL required" : "Article media")
    }

    private var unavailable: some View {
        Text("Media unavailable")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: isGallery ? 180 : 120)
            .background(.quaternary)
    }
}

private struct DraftVideoPlayerView: View {
    @State private var player: AVPlayer
    let height: CGFloat

    init(url: URL, height: CGFloat) {
        _player = State(initialValue: AVPlayer(url: url))
        self.height = height
    }

    var body: some View {
        VideoPlayer(player: player)
            .frame(height: height)
            .onDisappear { player.pause() }
    }
}

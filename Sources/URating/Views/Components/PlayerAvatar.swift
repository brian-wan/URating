import SwiftUI

struct PlayerAvatar: View {
    let initials: String
    let colorHex: String
    let size: CGFloat
    let photoData: Data?

    init(player: Player, size: CGFloat = 40) {
        self.initials  = player.initials
        self.colorHex  = player.colorHex
        self.photoData = player.photoData
        self.size      = size
    }

    init(initials: String, colorHex: String, size: CGFloat = 40) {
        self.initials  = initials
        self.colorHex  = colorHex
        self.photoData = nil
        self.size      = size
    }

    var body: some View {
        Group {
            if let data = photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(hex: colorHex)
                    Text(initials)
                        .font(.system(size: size * 0.38, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

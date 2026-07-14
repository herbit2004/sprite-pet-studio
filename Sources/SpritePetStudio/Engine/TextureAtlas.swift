import AppKit
import SpriteKit

final class TextureAtlas {
    enum AtlasError: LocalizedError {
        case imageUnreadable(URL)

        var errorDescription: String? {
            switch self {
            case .imageUnreadable(let url):
                return "无法读取桌宠图集：\(url.path)"
            }
        }
    }

    let definition: AtlasDefinition
    private let baseTexture: SKTexture

    init(imageURL: URL, project: PetProjectDefinition) throws {
        guard let image = NSImage(contentsOf: imageURL) else {
            throw AtlasError.imageUnreadable(imageURL)
        }
        self.definition = project.atlas
        baseTexture = SKTexture(image: image)
        baseTexture.filteringMode = project.atlas.filtering == .nearest ? .nearest : .linear
    }

    func texture(for frame: PetFrameDefinition) -> SKTexture {
        return atlasTexture(column: frame.column, row: frame.row)
    }

    private func atlasTexture(column: Int, row: Int) -> SKTexture {
        let columns = max(1, definition.columns)
        let rows = max(1, definition.rows)
        let safeColumn = max(0, min(column, columns - 1))
        let safeRow = max(0, min(row, rows - 1))
        let width = 1 / CGFloat(columns)
        let height = 1 / CGFloat(rows)
        let rect = CGRect(
            x: CGFloat(safeColumn) * width,
            y: 1 - CGFloat(safeRow + 1) * height,
            width: width,
            height: height
        )
        let texture = SKTexture(rect: rect, in: baseTexture)
        texture.filteringMode = definition.filtering == .nearest ? .nearest : .linear
        return texture
    }
}

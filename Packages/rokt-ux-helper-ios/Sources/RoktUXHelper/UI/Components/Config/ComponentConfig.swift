import Foundation
struct ComponentConfig {
    let parent: ComponentParentType
    let position: Int?

    func updateParent(_ parent: ComponentParentType) -> ComponentConfig {
        return ComponentConfig(parent: parent, position: self.position)
    }

    func updatePosition(_ position: Int?) -> ComponentConfig {
        return ComponentConfig(parent: self.parent, position: position)
    }
}

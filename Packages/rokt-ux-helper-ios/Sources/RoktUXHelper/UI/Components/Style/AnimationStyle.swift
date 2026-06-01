import Foundation
import DcuiSchema
import Combine
import SwiftUI

struct AnimationStyle {
    var duration: TimeInterval
    var style: BaseStyles
}

extension AnimationStyle {

    init?<S, P>(
        transition: ConditionalStyleTransition<S, P>?,
        transform: (S) -> BaseStyles?
    ) {
        guard let transition, let style = transform(transition.value) else { return nil }
        self.duration = Double(transition.duration)/1000.0
        self.style = style
    }
}

import SwiftUI
import DcuiSchema

protocol CommonContainerStylingProperties {
    var justifyContent: FlexJustification? { get }
    var alignItems: FlexAlignment? { get }
    var shadow: Shadow? { get }
    var overflow: Overflow? { get }
    var blur: Float? { get }
}

extension ContainerStylingProperties: CommonContainerStylingProperties {}

extension ZStackContainerStylingProperties: CommonContainerStylingProperties {}

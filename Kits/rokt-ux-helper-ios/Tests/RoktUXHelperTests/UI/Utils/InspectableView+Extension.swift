import Foundation
import SwiftUI
@testable import ViewInspector

extension InspectableView where View: SingleViewContent {
    
    func modifierIgnoreAny<T>(_ type: T.Type, _ index: Int? = nil) throws -> InspectableView<ViewType.ViewModifier<T>>
    where T: ViewModifier {
        let name = Inspector.typeName(type: type)
        let isChildAny = Inspector.isAnyView(value: try child().view)
        var target = isChildAny ? try child() : content
        while Inspector.isAnyView(value: target.view),
              content.medium.viewModifiers.reversed().compactMap({ modifier in
                  try? Inspector.attribute(label: "modifier", value: modifier, type: type)
              }).dropFirst(index ?? 0).first == nil
        {
            guard let anyView = try? InspectableView<ViewType.AnyView>.init(target, parent: self),
                  let childView = try? ViewType.AnyView.child(anyView.content, preservingModifiers: true) else {
                break
            }
            target = childView
        }
        guard let view = target.medium.viewModifiers.reversed().compactMap({ modifier in
            try? Inspector.attribute(label: "modifier", value: modifier, type: type)
        }).dropFirst(index ?? 0).first else {
            throw InspectionError.modifierNotFound(
                parent: Inspector.typeName(value: content.view),
                modifier: name, index: index ?? 0
            )
        }
        let medium = target.medium.resettingViewModifiers()
        let modifierContent = try Inspector.unwrap(view: view, medium: medium)
        let base = ViewType.ViewModifier<T>.inspectionCall(typeName: name)
        let call = ViewType.inspectionCall(base: base, index: index)
        return try .init(modifierContent, parent: self, call: call)
    }
    
    func ignoreAny<T: BaseViewType>(_ type: T.Type? = nil) throws -> InspectableView<T> {
        var targetInspectableView = try child()
        while Inspector.isAnyView(value: targetInspectableView.view) {
            guard let anyView = try? InspectableView<ViewType.AnyView>.init(targetInspectableView, parent: self),
                  let childView = try? ViewType.AnyView.child(anyView.content, preservingModifiers: true) else {
                break
            }
            targetInspectableView = childView
        }
        return try .init(targetInspectableView, parent: self)
    }
}

extension ViewType.AnyView {
    
    public static func child(_ content: Content, preservingModifiers: Bool) throws -> Content {
        let view = try Inspector.attribute(path: "storage|view", value: content.view)
        let medium = preservingModifiers ? content.medium : content.medium.resettingViewModifiers()
        return try Inspector.unwrap(view: view, medium: medium)
    }
}

extension Inspector {
    static func isAnyView(value: Any) -> Bool {
        typeName(type: type(of: value), namespaced: true, generics: .remove).contains("SwiftUI.AnyView")
    }
}

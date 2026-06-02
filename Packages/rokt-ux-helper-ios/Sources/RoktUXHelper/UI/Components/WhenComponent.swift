import SwiftUI
import Combine

@available(iOS 15, *)
struct WhenComponent: View {
    let config: ComponentConfig
    @ObservedObject private var model: WhenViewModel

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?
    @Binding var styleState: StyleState

    @Binding var currentProgress: Int
    let totalOffers: Int

    @Binding var customStateMap: RoktUXCustomStateMap?
    @Binding var globalCustomStateMap: RoktUXCustomStateMap?

    @EnvironmentObject var globalScreenSize: GlobalScreenSize

    let parentOverride: ComponentParentOverride?

    @SwiftUI.Environment(\.colorScheme) var colorScheme: ColorScheme

    @State private var visible: Bool?
    @State private var toggleTransition = false

    private var getOpacity: Double {
        toggleTransition ? 1 : 0
    }

    private var shouldApply: Bool {
        model.shouldApply(
            WhenComponentUIState(
                currentProgress: currentProgress,
                totalOffers: totalOffers,
                position: config.position,
                width: globalScreenSize.width ?? 0,
                isDarkMode: colorScheme == .dark,
                customStateMap: customStateMap,
                globalCustomStateMap: globalCustomStateMap))
    }

    init(
        config: ComponentConfig,
        model: WhenViewModel,
        parentWidth: Binding<CGFloat?>,
        parentHeight: Binding<CGFloat?>,
        styleState: Binding<StyleState>,
        parentOverride: ComponentParentOverride?
    ) {
        self.config = config
        self._model = ObservedObject(wrappedValue: model)

        _parentWidth = parentWidth
        _parentHeight = parentHeight
        _styleState = styleState
        _currentProgress = model.currentProgress
        totalOffers = model.totalItems
        _customStateMap = model.customStateMap
        _globalCustomStateMap = model.globalCustomStateMap

        self.parentOverride = parentOverride
        model.componentConfig = config
    }

    var body: some View {
        Group {
            if visible == true || shouldApply {
                buildComponent()
            }
        }
        .opacity(getOpacity)
        .onChange(of: shouldApply) { newValue in
            if newValue {
                transitionIn()
            } else {
                transitionOut()
            }
        }
        .onChange(of: globalScreenSize.width) { newValue in
            model.width = newValue ?? 0
        }
        .onLoad {
            transitionIn()
        }
    }

    @ViewBuilder func buildComponent() -> some View {
        if let children = model.children {
            ForEach(children, id: \.self) { child in
                LayoutSchemaComponent(config: config,
                                      layout: child,
                                      parentWidth: $parentWidth,
                                      parentHeight: $parentHeight,
                                      styleState: $styleState,
                                      parentOverride: parentOverride)
            }
        }
    }

    private func transitionIn() {
        visible = true
        withAnimation(
            .easeIn(duration: model.fadeInDuration)) {
                toggleTransition = true
            }
    }

    private func transitionOut() {
        if #available(iOS 17.0, *) {
            withAnimation(
                .easeOut(duration: model.fadeOutDuration)) {
                    toggleTransition = false
                } completion: {
                    visible = false
                }
        } else {
            // Earlier versions must set visibility after a manual delay
            withAnimation(
                .easeOut(duration: model.fadeOutDuration)) {
                    toggleTransition = false
                }
            DispatchQueue.main.asyncAfter(deadline: .now() + model.fadeOutDuration) {
                visible = false
            }
        }
    }
}

struct WhenComponentUIState {
    let currentProgress: Int
    let totalOffers: Int
    let position: Int?
    let width: CGFloat
    let isDarkMode: Bool
    let customStateMap: RoktUXCustomStateMap?
    let globalCustomStateMap: RoktUXCustomStateMap?
}

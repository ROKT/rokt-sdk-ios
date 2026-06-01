import Foundation

@available(iOS 15, *)
protocol SyntaxMapping {
    associatedtype Context
    func map(consumer: LayoutSchemaViewModel, context: Context)
}

import Foundation

extension CGSize {

    func precised(_ value: Int = 2) -> CGSize {
        .init(
            width: width.precised(value),
            height: height.precised(value)
        )
    }
}

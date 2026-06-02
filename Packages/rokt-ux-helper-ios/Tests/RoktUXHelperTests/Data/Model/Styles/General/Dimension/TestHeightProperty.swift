import XCTest
@testable import RoktUXHelper

@available(iOS 13, *)
final class TestHeightProperty: XCTestCase {
    func test_height_percentage_nil() {
        // Arrange
        let height = HeightProperty(dimensionType: nil)
        // Act
        let heightPercentage = height.heightPercentage
        // Assert
        XCTAssertNil(heightPercentage)
    }
    
    func test_height_percentage_value_nil() {
        // Arrange
        let height = HeightProperty(dimensionType: nil)
        // Act
        let heightPercentage = height.heightPercentage
        // Assert
        XCTAssertNil(heightPercentage)
    }
    
    func test_height_percentage_value_valid() {
        // Arrange
        let height = HeightProperty(dimensionType: .percentage(100))
        // Act
        let heightPercentage = height.heightPercentage
        // Assert
        XCTAssertEqual(heightPercentage, 100)
    }

    func test_init_withValidValues_shouldParseAllValues() throws {
        let rawValues: [String: Any] = [
            "value": "fit-height",
            "type": "fit"
        ]

        let data = try JSONSerialization.data(withJSONObject: rawValues)
        let sut = try TestConstants.decoder.decode(HeightProperty.self, from: data)

        let dimensionValue = try XCTUnwrap(sut)

        guard case .fit(let fitProperty) = dimensionValue.dimensionType else {
            XCTFail("Could not generate fitProperty")
            return
        }

        XCTAssertEqual(fitProperty, .fitHeight)
        XCTAssertNil(sut.heightPercentage)
    }

    func test_init_withFixedType_shouldParseAllValues() throws {
        let rawValues: [String: Any] = [
            "value": 333,
            "type": "fixed"
        ]

        let data = try JSONSerialization.data(withJSONObject: rawValues)
        let sut = try TestConstants.decoder.decode(HeightProperty.self, from: data)

        let dimensionValue = try XCTUnwrap(sut)

        guard case .fixed(let fixedValue) = dimensionValue.dimensionType else {
            XCTFail("Could not generate fitProperty")
            return
        }

        XCTAssertEqual(fixedValue, 333.0)
        XCTAssertNil(sut.heightPercentage)
    }

    func test_init_withPercentageType_shouldParseAllValues() throws {
        let rawValues: [String: Any] = [
            "value": 23,
            "type": "percentage"
        ]

        let data = try JSONSerialization.data(withJSONObject: rawValues)
        let sut = try TestConstants.decoder.decode(HeightProperty.self, from: data)

        let dimensionValue = try XCTUnwrap(sut)

        guard case .percentage(let percentageValue) = dimensionValue.dimensionType else {
            XCTFail("Could not generate fitProperty")
            return
        }

        XCTAssertEqual(percentageValue, 23)
        XCTAssertEqual(sut.heightPercentage, 23)
    }

    func test_init_withInvalidDimensionType_throwsError() throws {
        let rawValues: [String: Any] = [
            "value": "fit-height",
            "type": "invalid-type"
        ]

        let data = try JSONSerialization.data(withJSONObject: rawValues)
        XCTAssertThrowsError(try TestConstants.decoder.decode(HeightProperty.self, from: data))
    }

    func test_init_usingDimensionType() {
        let dimension = HeightDimensionType.percentage(30)
        let sut = HeightProperty(dimensionType: dimension)

        XCTAssertEqual(sut.dimensionType, dimension)
        XCTAssertEqual(sut.heightPercentage, 30)
    }

    func test_init_withInValidDimensionType_throwsError() throws {
        let rawValues: [String: Any] = [
            "value": "fit-height"
        ]

        let data = try JSONSerialization.data(withJSONObject: rawValues)
        XCTAssertThrowsError(try TestConstants.decoder.decode(HeightProperty.self, from: data))
    }
}

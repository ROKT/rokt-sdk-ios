import XCTest
@testable import Rokt_Widget

// MARK: - Mock Enricher

private class MockAttributeEnricher: AttributeEnricher {
    var attributesToReturn: [String: String]
    var receivedConfig: RoktConfig? // To verify config passing

    init(attributesToReturn: [String: String] = [:]) {
        self.attributesToReturn = attributesToReturn
    }

    func enrich(config: RoktConfig?) -> [String: String] {
        self.receivedConfig = config
        return attributesToReturn
    }
}

// MARK: - Test Data Constants

private struct TestData {
    static let initialKey = "initialKey"
    static let anotherKey = "anotherKey"
    static let enricherKey = "enricherKey"
    static let anotherEnricherKey = "anotherEnricherKey"
    static let commonKey = "commonKey"
    static let initialOnlyKey = "initialOnlyKey"
    static let enricherOnlyKey = "enricherOnlyKey"
    static let enricher1Key = "enricher1Key"
    static let enricher2Key = "enricher2Key"
    static let keyA = "keyA"
    static let keyB = "keyB"
    static let keyC = "keyC"
    static let keyD = "keyD"

    static let initialValue = "initialValue"
    static let initialVersion = "initialVersion"
    static let initialData = "initialData"
    static let enricherValue = "enricherValue"
    static let enricherVersion = "enricherVersion"
    static let enricherData = "enricherData"
    static let enricher1Value = "value1"
    static let enricher2Value = "value2"
    static let enricher1Version = "enricher1Version"
    static let enricher2Version = "enricher2Version"
    static let enricher1Data = "data1"
    static let enricher2Data = "data2"
    static let initialAValue = "initialA"
    static let initialBValue = "initialB"
    static let enricher1BValue = "enricher1B"
    static let enricher1CValue = "enricher1C"
    static let enricher2CValue = "enricher2C"
    static let enricher2DValue = "enricher2D"

    static let initialIntValue = "123"
    static let enricherIntValue = "456"
    static let enricher2IntValue = "789"
}

class TestAttributeEnricher: XCTestCase {

    // MARK: - Test Cases

    func testEnrich_withNoEnrichers_shouldReturnOriginalAttributes() {
        // Given
        let initialAttributes: [String: String] = [
            TestData.initialKey: TestData.initialValue,
            TestData.anotherKey: TestData.initialIntValue
        ]
        let enrichers: [AttributeEnricher] = []
        let sut = AttributeEnrichment(enrichers: enrichers)
        let mockConfig = RoktConfig.Builder().build()

        // When
        let result = sut.enrich(attributes: initialAttributes, config: mockConfig)

        // Then
        XCTAssertEqual(
            result.count,
            initialAttributes.count,
            "Result count should match initial attributes count when no enrichers are present."
        )
        XCTAssertEqual(
            result[TestData.initialKey],
            TestData.initialValue,
            "Value for 'initialKey' should remain unchanged."
        )
        XCTAssertEqual(
            result[TestData.anotherKey],
            TestData.initialIntValue,
            "Value for 'anotherKey' should remain unchanged."
        )
    }

    func testEnrich_withSingleEnricher_shouldAddEnricherAttributes() {
        // Given
        let initialAttributes: [String: String] = [TestData.initialKey: TestData.initialValue]
        let enricherAttributes: [String: String] = [
            TestData.enricherKey: TestData.enricherValue,
            TestData.anotherEnricherKey: TestData.enricherIntValue
        ]
        let mockEnricher = MockAttributeEnricher(attributesToReturn: enricherAttributes)
        let sut = AttributeEnrichment(enrichers: [mockEnricher])
        let mockConfig = RoktConfig.Builder().build()

        // When
        let result = sut.enrich(attributes: initialAttributes, config: mockConfig)

        // Then
        XCTAssertEqual(
            result.count,
            initialAttributes.count + enricherAttributes.count,
            "Result count should be sum of initial and enricher attributes."
        )
        XCTAssertEqual(result[TestData.initialKey], TestData.initialValue)
        XCTAssertEqual(result[TestData.enricherKey], TestData.enricherValue)
        XCTAssertEqual(result[TestData.anotherEnricherKey], TestData.enricherIntValue)
        XCTAssertTrue(mockEnricher.receivedConfig === mockConfig, "Enricher should have received the config object.")
    }

    func testEnrich_withSingleEnricher_shouldOverwriteInitialAttributesOnKeyClash() {
        // Given
        let initialAttributes: [String: String] = [
            TestData.commonKey: TestData.initialVersion,
            TestData.initialOnlyKey: TestData.initialData
        ]
        let enricherAttributes: [String: String] = [
            TestData.commonKey: TestData.enricherVersion,
            TestData.enricherOnlyKey: TestData.enricherData
        ]
        let mockEnricher = MockAttributeEnricher(attributesToReturn: enricherAttributes)
        let sut = AttributeEnrichment(enrichers: [mockEnricher])
        let mockConfig = RoktConfig.Builder().build()

        // When
        let result = sut.enrich(attributes: initialAttributes, config: mockConfig)

        // Then
        XCTAssertEqual(result.count, 3, "Result count should reflect merged keys.")
        XCTAssertEqual(
            result[TestData.commonKey],
            TestData.enricherVersion,
            "Enricher value should overwrite initial value for commonKey."
        )
        XCTAssertEqual(result[TestData.initialOnlyKey], TestData.initialData)
        XCTAssertEqual(result[TestData.enricherOnlyKey], TestData.enricherData)
    }

    func testEnrich_withMultipleEnrichers_shouldCombineAllAttributes() {
        // Given
        let initialAttributes: [String: String] = [TestData.initialKey: TestData.initialValue]
        let enricher1Attributes: [String: String] = [TestData.enricher1Key: TestData.enricher1Value]
        let enricher2Attributes: [String: String] = [
            TestData.enricher2Key: TestData.enricher2Value,
            TestData.anotherKey: TestData.enricher2IntValue
        ]

        let mockEnricher1 = MockAttributeEnricher(attributesToReturn: enricher1Attributes)
        let mockEnricher2 = MockAttributeEnricher(attributesToReturn: enricher2Attributes)
        let sut = AttributeEnrichment(enrichers: [mockEnricher1, mockEnricher2])
        let mockConfig = RoktConfig.Builder().build()

        // When
        let result = sut.enrich(attributes: initialAttributes, config: mockConfig)

        // Then
        XCTAssertEqual(result.count, 4, "Result count should be sum of initial and all enricher attributes.")
        XCTAssertEqual(result[TestData.initialKey], TestData.initialValue)
        XCTAssertEqual(result[TestData.enricher1Key], TestData.enricher1Value)
        XCTAssertEqual(result[TestData.enricher2Key], TestData.enricher2Value)
        XCTAssertEqual(result[TestData.anotherKey], TestData.enricher2IntValue)
        XCTAssertTrue(mockEnricher1.receivedConfig === mockConfig, "Enricher 1 should have received the config object.")
        XCTAssertTrue(mockEnricher2.receivedConfig === mockConfig, "Enricher 2 should have received the config object.")
    }

    func testEnrich_withMultipleEnrichers_shouldOverwriteWithLaterEnricherOnKeyClash() {
        // Given
        let initialAttributes: [String: String] = [TestData.commonKey: TestData.initialVersion]
        let enricher1Attributes: [String: String] = [
            TestData.commonKey: TestData.enricher1Version,
            TestData.enricher1Key: TestData.enricher1Data
        ]
        let enricher2Attributes: [String: String] = [
            TestData.commonKey: TestData.enricher2Version,
            TestData.enricher2Key: TestData.enricher2Data
        ]

        let mockEnricher1 = MockAttributeEnricher(attributesToReturn: enricher1Attributes)
        let mockEnricher2 = MockAttributeEnricher(attributesToReturn: enricher2Attributes)
        let sut = AttributeEnrichment(enrichers: [mockEnricher1, mockEnricher2])
        let mockConfig = RoktConfig.Builder().build()

        // When
        let result = sut.enrich(attributes: initialAttributes, config: mockConfig)

        // Then
        XCTAssertEqual(result.count, 3, "Result count should reflect merged keys.")
        XCTAssertEqual(
            result[TestData.commonKey],
            TestData.enricher2Version,
            "Later enricher (enricher2) value should overwrite for commonKey."
        )
        XCTAssertEqual(result[TestData.enricher1Key], TestData.enricher1Data)
        XCTAssertEqual(result[TestData.enricher2Key], TestData.enricher2Data)
    }

    func testEnrich_withMultipleEnrichers_shouldHandleClashWithInitialAndBetweenEnrichers() {
        // Given
        let initialAttributes: [String: String] = [TestData.keyA: TestData.initialAValue, TestData.keyB: TestData.initialBValue]
        let enricher1Attributes: [String: String] = [
            TestData.keyB: TestData.enricher1BValue,
            TestData.keyC: TestData.enricher1CValue
        ]
        let enricher2Attributes: [String: String] = [
            TestData.keyC: TestData.enricher2CValue,
            TestData.keyD: TestData.enricher2DValue
        ]

        let mockEnricher1 = MockAttributeEnricher(attributesToReturn: enricher1Attributes)
        let mockEnricher2 = MockAttributeEnricher(attributesToReturn: enricher2Attributes)
        let sut = AttributeEnrichment(enrichers: [mockEnricher1, mockEnricher2])
        let mockConfig = RoktConfig.Builder().build()

        // When
        let result = sut.enrich(attributes: initialAttributes, config: mockConfig)

        // Then
        XCTAssertEqual(result.count, 4, "Result count should be 4 after all merges.")
        XCTAssertEqual(result[TestData.keyA], TestData.initialAValue, "keyA should remain from initial attributes.")
        XCTAssertEqual(
            result[TestData.keyB],
            TestData.enricher1BValue,
            "keyB should be from enricher1, overwriting initial."
        )
        XCTAssertEqual(
            result[TestData.keyC],
            TestData.enricher2CValue,
            "keyC should be from enricher2, overwriting enricher1."
        )
        XCTAssertEqual(result[TestData.keyD], TestData.enricher2DValue, "keyD should be from enricher2.")
    }

    func testEnrich_withNilConfig_shouldPassNilToEnrichers() {
        // Given
        let initialAttributes: [String: String] = [TestData.initialKey: TestData.initialValue]
        let enricherAttributes: [String: String] = [TestData.enricherKey: TestData.enricherValue]
        let mockEnricher = MockAttributeEnricher(attributesToReturn: enricherAttributes)
        let sut = AttributeEnrichment(enrichers: [mockEnricher])

        // When
        _ = sut.enrich(attributes: initialAttributes, config: nil)

        // Then
        XCTAssertNil(mockEnricher.receivedConfig, "Enricher should have received nil for config.")
    }
}

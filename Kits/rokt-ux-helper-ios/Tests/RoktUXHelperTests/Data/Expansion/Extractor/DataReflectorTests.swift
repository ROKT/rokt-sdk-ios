import XCTest
@testable import RoktUXHelper

final class DataReflectorTests: XCTestCase {
    var sut: DataReflector!

    override func setUp() {
        super.setUp()

        sut = DataReflector()
    }

    override func tearDown() {
        sut = nil

        super.tearDown()
    }

    func test_getReflectedValue_withValidKeys_returnsValue() {
        XCTAssertEqual(
            sut.getReflectedValue(data: fakeSuburbMirror, keys: ["house", "owner", "pet", "name"]) as? String,
            "Ginger"
        )
    }

    func test_getReflectedValue_withInvalidKeys_returnsNil() {
        XCTAssertNil(sut.getReflectedValue(data: fakeSuburbMirror, keys: ["nonexistent"]))
    }

    func test_getReflectedValue_withPartialKeys_returnsNonStringValue() {
        // With Any? return type, partial keys resolve to the intermediate object
        XCTAssertNotNil(sut.getReflectedValue(data: fakeSuburbMirror, keys: ["house", "owner"]))
    }

    func test_getReflectedValue_withHeterogeneousDictionary_returnsValue() {
        let productMirror = Mirror(reflecting: ProductDetails(copy: ["pricing.amount": 14.99]))

        XCTAssertEqual(
            sut.getReflectedValue(data: productMirror, keys: ["copy", "pricing", "amount"]) as? Double,
            14.99
        )
    }
}

struct Pet {
    let name: String
}

struct Human {
    let pet: Pet
}

struct House {
    let owner: Human
}

struct Suburb {
    let house: House
}

struct ProductDetails {
    let copy: [String: Any]
}

let fakePet = Pet(name: "Ginger")
let fakeHuman = Human(pet: fakePet)
let fakeHouse = House(owner: fakeHuman)
let fakeSuburb = Suburb(house: fakeHouse)
let fakeSuburbMirror = Mirror(reflecting: Suburb(house: fakeHouse))

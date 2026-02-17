import Foundation

protocol StateBagManaging {
    func addState(id: String, state: any Bag)
    func removeState(id: String)
    func getState(id: String) -> (any Bag)?
    func increasePlacements(id: String)
    func decreasePlacements(id: String)
    func initiateInstantPurchase(id: String)
    func finishInstantPurchase(id: String)
    func find(where: (any Bag) -> Bool) -> (any Bag)?
}

class StateBagManager: StateBagManaging {
    private(set) var stateMap: [String: any Bag] = [:]

    func addState(id: String, state: any Bag) {
        stateMap[id] = state
    }

    func removeState(id: String) {
        stateMap.removeValue(forKey: id)
    }

    func getState(id: String) -> (any Bag)? {
        stateMap[id]
    }

    func increasePlacements(id: String) {
        stateMap[id]?.loadedPlacements += 1
    }
    func decreasePlacements(id: String) {
        stateMap[id]?.loadedPlacements -= 1
        checkRemoveState(id: id)
    }

    func initiateInstantPurchase(id: String) {
        stateMap[id]?.instantPurchaseInitiated = true
    }

    func finishInstantPurchase(id: String) {
        stateMap[id]?.instantPurchaseInitiated = false
        checkRemoveState(id: id)
    }

    func find(where: (any Bag) -> Bool) -> (any Bag)? {
        stateMap.values.first(where: `where`)
    }

    private func checkRemoveState(id: String) {
        guard let loadedPlacements = stateMap[id]?.loadedPlacements,
              loadedPlacements <= 0,
              stateMap[id]?.instantPurchaseInitiated == false else { return }
        removeState(id: id)
    }
}

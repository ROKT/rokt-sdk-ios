import Foundation

protocol StateBagManaging {
    func addState(id: String, state: any Bag)
    func removeState(id: String)
    func getState(id: String) -> (any Bag)?
    func increasePlacements(id: String)
    func decreasePlacements(id: String)
    func initiateInstantPurchase(id: String)
    func finishInstantPurchase(id: String)
    func removeStateIfUnused(id: String)
    func find(where: (any Bag) -> Bool) -> (any Bag)?
}

class StateBagManager: StateBagManaging {
    private(set) var stateMap: [String: any Bag] = [:]
    /// Whether a purchase of the execute `id` is still outstanding somewhere its state cannot see: a checkout the
    /// payment orchestrator holds for that execute (a Step-1 request out, a result waiting for its confirm, a purchase
    /// in flight, an approval sheet up). Such a purchase still has a result to deliver through the state, so the state
    /// is kept until it has. The default sees no such purchase.
    var hasOutstandingPurchase: (String) -> Bool = { _ in false }

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

    /// Drops the state for `id` once nothing holds it: no placement loaded, no instant purchase initiated and no
    /// purchase of the execute outstanding. Called when the last outstanding purchase of an execute ended without a
    /// finish of its own (it was dropped: its placement closed, its session was cleared, or it was cancelled or failed
    /// after that), so state kept for that purchase does not outlive it. A dropped purchase can never finish, so the
    /// instant-purchase flag its tap set is cleared here first: nothing else would clear it, and while it stays set
    /// the state can never go and `find(where:)` could still pick this execute for a later `purchaseFinalized`. The
    /// flag is left alone while a purchase of the execute is still outstanding, since that one may yet finish and
    /// clear it itself. A state whose placements are still loaded is kept, with the flag cleared, until the last of
    /// them unloads.
    func removeStateIfUnused(id: String) {
        if !hasOutstandingPurchase(id) {
            stateMap[id]?.instantPurchaseInitiated = false
        }
        checkRemoveState(id: id)
    }

    func find(where: (any Bag) -> Bool) -> (any Bag)? {
        stateMap.values.first(where: `where`)
    }

    private func checkRemoveState(id: String) {
        guard let loadedPlacements = stateMap[id]?.loadedPlacements,
              loadedPlacements <= 0,
              stateMap[id]?.instantPurchaseInitiated == false,
              !hasOutstandingPurchase(id) else { return }
        removeState(id: id)
    }
}

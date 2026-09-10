import Foundation

protocol StateBagManaging {
    func addState(id: String, state: any Bag)
    func removeState(id: String)
    func getState(id: String) -> (any Bag)?
    func increasePlacements(id: String)
    func decreasePlacements(id: String)
    func initiateInstantPurchase(id: String)
    func finishInstantPurchase(id: String)
    func beginExtensionPurchase(id: String) -> UUID
    func finishExtensionPurchase(id: String, token: UUID)
    func removeStateIfUnused(id: String)
    func find(where: (any Bag) -> Bool) -> (any Bag)?
}

class StateBagManager: StateBagManaging {
    private(set) var stateMap: [String: any Bag] = [:]
    /// Whether a built-in checkout of the execute `id` is still outstanding somewhere its state cannot see: one the
    /// payment orchestrator holds for that execute (a Step-1 request out, a result waiting for its confirm, a purchase
    /// in flight, an approval sheet up). Such a checkout still has a result to deliver through the state, so the state
    /// is kept until it has. Purchases handed to a payment extension are held here instead
    /// (``beginExtensionPurchase(id:)``), since the orchestrator's tables cannot see them. The default sees no such
    /// checkout.
    var hasOutstandingPurchase: (String) -> Bool = { _ in false }
    /// Purchases of each execute handed to a payment extension and not yet reported back, by the token minted when
    /// each was handed over. The extension's completion is the only report-back such a purchase has, so the state is
    /// kept until it arrives; an extension that never reports back keeps that one execute's state until the SDK is
    /// initialised again, which replaces this keeper and every hold with it.
    private var extensionPurchases: [String: Set<UUID>] = [:]

    func addState(id: String, state: any Bag) {
        stateMap[id] = state
    }

    func removeState(id: String) {
        stateMap.removeValue(forKey: id)
        extensionPurchases.removeValue(forKey: id)
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

    /// Records that a purchase of the execute `id` has been handed to a payment extension, and returns the token that
    /// names it. The state is kept while any such purchase is out, whatever the orchestrator sees, so the extension's
    /// completion still finds the state to deliver its result through.
    func beginExtensionPurchase(id: String) -> UUID {
        let token = UUID()
        extensionPurchases[id, default: []].insert(token)
        return token
    }

    /// Records that the extension purchase `token` of the execute `id` has reported back, once its result has been
    /// delivered. The SDK holds the purchase's terminal outcome at this point, so the instant-purchase flag the tap
    /// set is finished here, the way a built-in Step-2 finishes it, and the state goes once nothing else holds it. A
    /// token not held for `id` (a purchase already finished, or one of another execute) changes nothing, so a
    /// completion delivered twice cannot finish a later tap. An outcome the extension reports as cancelled ends the
    /// hand-off the same way: the flag is finished and a later tap is a new hand-off (a built-in PayPal cancel, by
    /// contrast, puts its order back on offer for the confirm button and leaves the flag alone).
    func finishExtensionPurchase(id: String, token: UUID) {
        guard extensionPurchases[id]?.remove(token) != nil else { return }
        if extensionPurchases[id]?.isEmpty == true {
            extensionPurchases.removeValue(forKey: id)
        }
        finishInstantPurchase(id: id)
    }

    /// Drops the state for `id` once nothing holds it: no placement loaded, no instant purchase initiated and no
    /// purchase of the execute outstanding. Called when the last outstanding built-in checkout of an execute ended
    /// without a finish of its own (it was dropped: its placement closed, its session was cleared, or it was cancelled
    /// or failed after that), so state kept for that checkout does not outlive it. A dropped checkout can never
    /// finish, so the instant-purchase flag its tap set is cleared here first: nothing else would clear it, and while
    /// it stays set the state can never go and `find(where:)` could still pick this execute for a later
    /// `purchaseFinalized`. The flag is left alone while a built-in checkout or an extension purchase of the execute is
    /// still outstanding: a built-in checkout may yet finish and clear it itself, and an extension purchase finishes it
    /// when it reports back (``finishExtensionPurchase(id:token:)``). A state whose placements are still loaded is
    /// kept, with the flag cleared, until the last of them unloads.
    func removeStateIfUnused(id: String) {
        if !isPurchaseOutstanding(id) {
            stateMap[id]?.instantPurchaseInitiated = false
        }
        checkRemoveState(id: id)
    }

    func find(where: (any Bag) -> Bool) -> (any Bag)? {
        stateMap.values.first(where: `where`)
    }

    /// A built-in checkout the orchestrator holds for the execute, or a purchase handed to a payment extension and not
    /// yet reported back.
    private func isPurchaseOutstanding(_ id: String) -> Bool {
        hasOutstandingPurchase(id) || !(extensionPurchases[id]?.isEmpty ?? true)
    }

    private func checkRemoveState(id: String) {
        guard let loadedPlacements = stateMap[id]?.loadedPlacements,
              loadedPlacements <= 0,
              stateMap[id]?.instantPurchaseInitiated == false,
              !isPurchaseOutstanding(id) else { return }
        removeState(id: id)
    }
}

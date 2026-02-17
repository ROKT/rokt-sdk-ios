import Foundation
import UIKit
import XCTest
import Quick
import Nimble
@testable import Rokt_Widget
@testable import RoktUXHelper

let kValidInitWithCacheFilename = "validInitWithCache"

var mockImplementation: MockRoktInternalImplementation!

class MockRoktInternalImplementation: RoktInternalImplementation {
    var executingLayoutPage: LayoutPageExecutePayload?
    var executingPluginIds: [String]? {
        guard let page = executingLayoutPage?.page,
              let pageData = page.data(using: .utf8),
              let pageDecodedData = try? JSONDecoder().decode(RoktUXExperienceResponse.self, from: pageData),
              let pageModel = pageDecodedData.getPageModel()
        else {
            return nil
        }
        guard let layoutPlugins = pageModel.layoutPlugins else { return nil }
        return layoutPlugins.compactMap { (plugin) -> String? in plugin.pluginId }
    }
    override func processLayoutPageExecutePayload(_ page: String,
                                                  selectionId: String,
                                                  viewName: String? = nil,
                                                  attributes: [String: String]) -> LayoutPageExecutePayload? {
        executingLayoutPage = super.processLayoutPageExecutePayload(
            page,
            selectionId: selectionId,
            viewName: viewName,
            attributes: attributes
        )
        return executingLayoutPage
    }
}

class RoktExperienceCacheExecuteTests: QuickSpec {
    private let testCacheDirectoryName = "test_RoktExperienceCache"
    private let mockedViewName = "test-view-name"
    private let mockedNonMatchingViewName = "test-different-view-name"
    private let mockedAttributes = ["email": "jenny.law@rokt.com",
                                    "confirmation": "123456"]
    private let mockedReorderedAttributes = ["confirmation": "123456",
                                             "email": "jenny.law@rokt.com"]
    private let mockedNonMatchingAttributes = ["email": "jenny.law@rokt.com",
                                               "confirmation": "123457"]
    private let mockedExperienceResponse = ["response": "experienceResponse"]

    func executeRokt(viewName: String? = nil,
                     attributes: [String: String] = [:],
                     config: RoktConfig? = nil) {
        mockImplementation.mapEvents(isGlobal: true, onEvent: { event in
            if event is RoktEvent.InitComplete {
                mockImplementation.execute(
                    viewName: viewName,
                    attributes: attributes,
                    placements: nil,
                    config: config,
                    onRoktEvent: nil
                )
            }
        })

        mockImplementation.initWith(
            roktTagId: "test_tag_id",
            mParticleKitDetails: nil,
        )
    }

    override func spec() {
        describe("Rokt modal controller") {

            var testVC: UIViewController!

            beforeEach {
                testVC = nil
                UIApplication.shared.keyWindow!.rootViewController = nil
                mockImplementation = MockRoktInternalImplementation()
            }

            context("Test execute with cache enabled") {

                beforeEach {
                    self.prepareExperienceCacheTestFiles(self.testCacheDirectoryName)

                    // Stub response for init call
                    self.stubInit(kValidInitWithCacheFilename)

                    // Stub response for execute call
                    self.stubExecute(kValidLayoutOverlayFilename, isLayout: true)

                    mockImplementation.executingLayoutPage = nil

                    testVC = UIViewController()

                    UIApplication.shared.keyWindow!.rootViewController = testVC
                    _ = testVC.view
                }

                it("uses execute response when no cache config") {
                    let stubCachedResponseAsString = self.getJsonFileContents(kValidLayoutOverlayFilename)
                    let stubNewResponseAsString = self.getJsonFileContents(kValidLayoutGroupedFilename)

                    // Initial execute with original response
                    self.executeRokt()
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubCachedResponseAsString), timeout: .seconds(5)
                    )

                    // Stub execute to return new response
                    self.stubExecute(kValidLayoutGroupedFilename, isLayout: true)

                    // Reset executingLayoutPage before second execute
                    mockImplementation.executingLayoutPage = nil

                    // Second execute with new response
                    self.executeRokt()

                    // Check uses new response
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubNewResponseAsString), timeout: .seconds(60)
                    )
                }

                it("uses valid cache based off cache attributes") {
                    // Set cache config with cache attributes
                    let config = RoktConfig.Builder()
                        .cacheConfig(RoktConfig.CacheConfig(
                            cacheAttributes: self.mockedAttributes
                        ))
                        .build()
                    let stubCachedResponseAsString = self.getJsonFileContents(kValidLayoutOverlayFilename)

                    // Initial execute with original response
                    self.executeRokt(config: config)
                    expect(mockImplementation.executingLayoutPage?.page)
                        .toEventually(equal(stubCachedResponseAsString), timeout: .seconds(5))

                    // Stub execute to return new response
                    self.stubExecute(kValidLayoutGroupedFilename, isLayout: true)

                    // Second execute with same config, returning new response
                    self.executeRokt(config: config)

                    // Check uses original (cached) response
                    expect(mockImplementation.executingLayoutPage?.page)
                        .toEventually(equal(stubCachedResponseAsString), timeout: .seconds(5))
                }

                it("does not use cache on non-matching cache attributes") {
                    // Set cache config with cache attributes
                    let config = RoktConfig.Builder()
                        .cacheConfig(RoktConfig.CacheConfig(
                            cacheAttributes: self.mockedAttributes
                        ))
                        .build()
                    let stubCachedResponseAsString = self.getJsonFileContents(kValidLayoutOverlayFilename)

                    // Initial execute with original response
                    self.executeRokt(config: config)
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubCachedResponseAsString),
                        timeout: .seconds(5)
                    )

                    // Stub execute to return new response
                    self.stubExecute(kValidLayoutGroupedFilename, isLayout: true)

                    // Second execute with different cache attributes, returning new response
                    let newConfig = RoktConfig.Builder()
                        .cacheConfig(RoktConfig.CacheConfig(
                            cacheAttributes: self.mockedNonMatchingAttributes
                        ))
                        .build()
                    self.executeRokt(config: newConfig)

                    // Check uses new response
                    let stubNewResponseAsString = self.getJsonFileContents(kValidLayoutGroupedFilename)
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubNewResponseAsString),
                        timeout: .seconds(1)
                    )
                }

                it("uses valid cache based off execute attributes") {
                    // Set cache config
                    let config = RoktConfig.Builder()
                        .cacheConfig(RoktConfig.CacheConfig())
                        .build()
                    let stubCachedResponseAsString = self.getJsonFileContents(kValidLayoutOverlayFilename)

                    // Initial execute with execute attributes, returning original response
                    self.executeRokt(attributes: self.mockedAttributes, config: config)
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubCachedResponseAsString),
                        timeout: .seconds(5)
                    )

                    // Stub execute to return new response
                    self.stubExecute(kValidLayoutGroupedFilename, isLayout: true)

                    // Second execute with same execute attributes, returning new response
                    self.executeRokt(attributes: self.mockedAttributes, config: config)

                    // Check uses original response
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubCachedResponseAsString),
                        timeout: .seconds(5)
                    )
                }

                it("does not use cache on non-matching execute attributes") {
                    // Set cache config
                    let config = RoktConfig.Builder()
                        .cacheConfig(RoktConfig.CacheConfig())
                        .build()
                    let stubCachedResponseAsString = self.getJsonFileContents(kValidLayoutOverlayFilename)

                    // Initial execute with execute attributes, returning original response
                    self.executeRokt(attributes: self.mockedAttributes, config: config)
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubCachedResponseAsString),
                        timeout: .seconds(5)
                    )

                    // Stub execute to return new response
                    self.stubExecute(kValidLayoutGroupedFilename, isLayout: true)

                    // Second execute with different execute attributes, returning new response
                    self.executeRokt(attributes: self.mockedNonMatchingAttributes, config: config)

                    // Check uses new response
                    let stubNewResponseAsString = self.getJsonFileContents(kValidLayoutGroupedFilename)
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubNewResponseAsString),
                        timeout: .seconds(5)
                    )
                }

                it("uses valid cache based off re-ordered attributes") {
                    // Set cache config
                    let config = RoktConfig.Builder()
                        .cacheConfig(RoktConfig.CacheConfig())
                        .build()
                    let stubCachedResponseAsString = self.getJsonFileContents(kValidLayoutOverlayFilename)

                    // Initial execute with execute attributes, returning original response
                    self.executeRokt(attributes: self.mockedAttributes, config: config)
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubCachedResponseAsString),
                        timeout: .seconds(5)
                    )

                    // Stub execute to return new response
                    self.stubExecute(kValidLayoutGroupedFilename, isLayout: true)

                    // Second execute with reordered attributes, returning new response
                    self.executeRokt(attributes: self.mockedReorderedAttributes, config: config)

                    // Check uses original response
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubCachedResponseAsString),
                        timeout: .seconds(5)
                    )
                }

                it("uses valid cache based off viewName") {
                    // Set cache config
                    let config = RoktConfig.Builder()
                        .cacheConfig(RoktConfig.CacheConfig())
                        .build()
                    let stubCachedResponseAsString = self.getJsonFileContents(kValidLayoutOverlayFilename)

                    // Initial execute with execute viewName and attributes, returning original response
                    self.executeRokt(viewName: self.mockedViewName, attributes: self.mockedAttributes, config: config)
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubCachedResponseAsString),
                        timeout: .seconds(5)
                    )

                    // Stub execute to return new response
                    self.stubExecute(kValidLayoutGroupedFilename, isLayout: true)

                    // Second execute with same viewName and attributes, returning new response
                    self.executeRokt(viewName: self.mockedViewName, attributes: self.mockedAttributes, config: config)

                    // Check uses original response
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubCachedResponseAsString),
                        timeout: .seconds(5)
                    )
                }

                it("does not use cache on non-matching viewName") {
                    // Set cache config
                    let config = RoktConfig.Builder()
                        .cacheConfig(RoktConfig.CacheConfig())
                        .build()
                    let stubCachedResponseAsString = self.getJsonFileContents(kValidLayoutOverlayFilename)

                    // Initial execute with execute attributes, returning original response
                    self.executeRokt(attributes: self.mockedAttributes, config: config)
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubCachedResponseAsString),
                        timeout: .seconds(5)
                    )

                    // Stub execute to return new response
                    self.stubExecute(kValidLayoutGroupedFilename, isLayout: true)

                    // Second execute with different viewName, returning new response
                    self.executeRokt(
                        viewName: self.mockedNonMatchingViewName,
                        attributes: self.mockedAttributes,
                        config: config
                    )

                    // Check uses new response
                    let stubNewResponseAsString = self.getJsonFileContents(kValidLayoutGroupedFilename)
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubNewResponseAsString),
                        timeout: .seconds(5)
                    )
                }

                it("uses cached plugin view states") {
                    // Set cache config with cache attributes
                    let config = RoktConfig.Builder()
                        .cacheConfig(RoktConfig.CacheConfig(
                            cacheAttributes: self.mockedAttributes
                        ))
                        .build()

                    // Initial execute
                    self.executeRokt(config: config)

                    let exp = self.expectation(description: "Await execute")
                    _ = XCTWaiter.wait(for: [exp], timeout: 2)

                    let exp2 = self.expectation(description: "Await events")
                    _ = XCTWaiter.wait(for: [exp2], timeout: 5)

                    // Check initial plugin view state
                    guard let pluginId = mockImplementation.executingPluginIds?.first else {
                        return XCTFail("pluginId should not be nil")
                    }
                    let initialPluginViewState = RoktPluginViewState(pluginId: pluginId)
                    let states = mockImplementation.executingLayoutPage?.cacheProperties?.pluginViewStates
                    expect(states?.contains(initialPluginViewState))
                        .toEventually(beTrue(), timeout: .seconds(10))

                    // Update plugin view states
                    let customStateId = CustomStateIdentifiable(position: 3, key: "state")
                    let customStateMap = RoktUXCustomStateMap(uniqueKeysWithValues: [(key: customStateId,
                                                                                      value: 1)])
                    let pluginViewStateUpdates = RoktPluginViewState(
                        pluginId: pluginId,
                        offerIndex: 4,
                        isPluginDismissed: true,
                        customStateMap: customStateMap
                    )
                    mockImplementation.executingLayoutPage?.cacheProperties?.onPluginViewStateChange?(pluginViewStateUpdates)

                    // Second execute with same config
                    self.executeRokt(config: config)

                    let exp3 = self.expectation(description: "Await execute and events")
                    _ = XCTWaiter.wait(for: [exp3], timeout: 10)

                    // Check uses cached plugin view state
                    let pluginViewState = RoktPluginViewState(
                        pluginId: pluginId,
                        offerIndex: 4,
                        isPluginDismissed: true,
                        customStateMap: customStateMap
                    )
                    expect(mockImplementation.executingLayoutPage?.cacheProperties?.pluginViewStates?.contains(pluginViewState))
                        .toEventually(beTrue(), timeout: .seconds(20))
                }

                it("does not use cached sent events on non-matching attributes") {
                    // Set cache config with cache attributes
                    let config = RoktConfig.Builder()
                        .cacheConfig(RoktConfig.CacheConfig(
                        ))
                        .build()

                    var initialEvents = []
                    self.stubEvents { event in
                        initialEvents.append(event)
                    }

                    // Initial execute
                    self.executeRokt(attributes: self.mockedAttributes, config: config)

                    let exp = self.expectation(description: "Await execute and events")
                    _ = XCTWaiter.wait(for: [exp], timeout: 2)

                    // Check initial sent events
                    expect(initialEvents).toEventuallyNot(beNil(), timeout: .seconds(5))

                    var secondEvents = []
                    self.stubEvents { event in
                        secondEvents.append(event)
                    }

                    // Second execute with different attributes
                    self.executeRokt(attributes: self.mockedNonMatchingAttributes, config: config)

                    let exp2 = self.expectation(description: "Await execute and events")
                    _ = XCTWaiter.wait(for: [exp2], timeout: 2)

                    // Check second sent events
                    expect(secondEvents).toEventuallyNot(beNil())
                }

                it("uses initial plugin view states on non-matching attributes") {
                    // Set cache config with cache attributes
                    let config = RoktConfig.Builder()
                        .cacheConfig(RoktConfig.CacheConfig(
                            cacheAttributes: self.mockedAttributes
                        ))
                        .build()

                    // Initial execute
                    self.executeRokt(attributes: self.mockedAttributes, config: config)

                    let exp = self.expectation(description: "Test after 1s")
                    _ = XCTWaiter.wait(for: [exp], timeout: 1)

                    // Check initial plugin view state
                    guard let pluginId = mockImplementation.executingPluginIds?.first else {
                        return XCTFail("pluginId should not be nil")
                    }
                    let initialPluginViewState = RoktPluginViewState(pluginId: pluginId)
                    expect(mockImplementation.executingLayoutPage?.cacheProperties?.pluginViewStates?
                        .contains(initialPluginViewState))
                        .toEventually(beTrue())

                    // Update plugin view states
                    let customStateId = CustomStateIdentifiable(position: 3, key: "state")
                    let customStateMap = RoktUXCustomStateMap(uniqueKeysWithValues: [(key: customStateId,
                                                                                      value: 1)])
                    let pluginViewStateUpdates = RoktPluginViewState(
                        pluginId: pluginId,
                        offerIndex: 4,
                        isPluginDismissed: true,
                        customStateMap: customStateMap
                    )
                    mockImplementation.executingLayoutPage?.cacheProperties?.onPluginViewStateChange?(pluginViewStateUpdates)

                    // Second execute with different cache attributes
                    self.executeRokt(attributes: self.mockedNonMatchingAttributes, config: config)

                    // Check uses initial plugin view state
                    expect(mockImplementation.executingLayoutPage?.cacheProperties?.pluginViewStates?
                        .contains(initialPluginViewState))
                        .toEventually(beTrue(), timeout: .seconds(5))
                }

                afterEach {
                    self.deleteExperienceCacheTestFiles()
                    mockImplementation.executingLayoutPage = nil
                    testVC = nil
                    UIApplication.shared.keyWindow!.rootViewController = nil
                }
            }

            context("Test execute without cache enabled") {

                beforeEach {
                    // Stub response for init call (cache feature flag NOT enabled)
                    self.stubInit(kValidInitFilename)

                    // Stub response for execute call
                    self.stubExecute(kValidLayoutOverlayFilename, isLayout: true)

                    mockImplementation.executingLayoutPage = nil

                    testVC = UIViewController()

                    UIApplication.shared.keyWindow!.rootViewController = testVC
                    _ = testVC.view
                }

                it("ignores cached") {
                    let config = RoktConfig.Builder()
                        .colorMode(.dark)
                        .cacheConfig(RoktConfig.CacheConfig(
                            cacheDuration: TimeInterval(20),
                            cacheAttributes: self.mockedAttributes
                        ))
                        .build()
                    let stubCachedResponseAsString = self.getJsonFileContents(kValidLayoutOverlayFilename)
                    let stubNewResponseAsString = self.getJsonFileContents(kValidLayoutGroupedFilename)

                    self.executeRokt(config: config)
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubCachedResponseAsString),
                        timeout: .seconds(5)
                    )

                    self.stubExecute(kValidLayoutGroupedFilename, isLayout: true)
                    self.executeRokt(config: config)
                    expect(mockImplementation.executingLayoutPage?.page).toEventually(
                        equal(stubNewResponseAsString),
                        timeout: .seconds(5)
                    )
                }

                afterEach {
                    self.deleteExperienceCacheTestFiles()
                    testVC = nil
                    UIApplication.shared.keyWindow!.rootViewController = nil
                }
            }

            afterEach {
                self.deleteExperienceCacheTestFiles()
            }
        }
    }
}

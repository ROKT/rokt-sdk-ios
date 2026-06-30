import XCTest
@testable import Rokt_Widget

/// Structural coverage for the offers render adapter. Proves the emitted JSON
/// matches the renderer's decode contract: camelCase re-homing, verbatim DCUI
/// schema passthrough, positive/negative response-option bucketing, the required
/// placementContext/placements keys, and that icons are dropped. The DCUI
/// render-compat (the schema strings actually parsing) is proven separately.
final class TestSelectExperienceAdapter: XCTestCase {

    private func adapt(_ json: String) throws -> [String: Any] {
        let response = try JSONDecoder().decode(SelectResponse.self, from: Data(json.utf8))
        let string = try SelectExperienceAdapter.experienceJSONString(from: response)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(string.utf8)) as? [String: Any]
        )
    }

    private let payload = """
    {
      "session_id": "session-123",
      "session_token": { "token": "rotated-session-token", "expires_at": 1774474053000 },
      "page_instance_guid": "pig-123",
      "page_context": { "page_instance_guid": "pig-123", "page_id": "checkout", "token": "page-token" },
      "plugins": [
        {
          "plugin": {
            "id": "plugin-1",
            "name": "dcui",
            "target_element_selector": "#rokt",
            "config": {
              "instance_guid": "ig-1",
              "token": "plugin-token",
              "outer_layout_schema": "{\\"layout\\":{\\"node\\":\\"outer\\"}}",
              "slots": [
                {
                  "instance_guid": "slot-1",
                  "token": "slot-token",
                  "layout_variant": {
                    "layout_variant_id": "lv-1",
                    "module_name": "dcui",
                    "layout_variant_schema": "{\\"node\\":\\"root\\"}"
                  },
                  "offer": {
                    "campaign_id": "campaign-1",
                    "creative": {
                      "referral_creative_id": "rc-1",
                      "instance_guid": "creative-ig-1",
                      "token": "creative-token",
                      "copy": { "creative.title": "Hello" },
                      "images": { "hero": { "light": "l.png", "dark": "d.png" } },
                      "links": { "privacy": { "url": "https://x", "title": "Privacy" } },
                      "icons": { "close": { "name": "x" } },
                      "response_options_map": {
                        "positive": {
                          "id": "ro-pos", "instance_guid": "ig-pos", "token": "tok-pos",
                          "action": "Url", "signal_type": "SignalResponse",
                          "is_positive": true, "url": "https://accept"
                        },
                        "negative": {
                          "id": "ro-neg", "instance_guid": "ig-neg", "token": "tok-neg",
                          "action": "CaptureOnly", "is_positive": false
                        }
                      }
                    }
                  }
                }
              ]
            }
          }
        }
      ]
    }
    """

    func test_topLevelShapeMatchesRenderContract() throws {
        let exp = try adapt(payload)

        XCTAssertEqual(exp["sessionId"] as? String, "session-123")
        // Outermost token is the session token (rolled-forward JWT).
        XCTAssertEqual(exp["token"] as? String, "rotated-session-token")

        let placementContext = try XCTUnwrap(exp["placementContext"] as? [String: Any])
        XCTAssertEqual(placementContext["pageInstanceGuid"] as? String, "pig-123")
        XCTAssertEqual(placementContext["token"] as? String, "page-token")

        // placements is required by the decoder but empty for the plugins render path.
        let placements = try XCTUnwrap(exp["placements"] as? [Any])
        XCTAssertTrue(placements.isEmpty)
    }

    func test_dcuiSchemasPassThroughVerbatim() throws {
        let exp = try adapt(payload)
        let config = try XCTUnwrap(
            ((exp["plugins"] as? [[String: Any]])?.first?["plugin"] as? [String: Any])?["config"] as? [String: Any]
        )
        XCTAssertEqual(config["outerLayoutSchema"] as? String, "{\"layout\":{\"node\":\"outer\"}}")
        XCTAssertEqual(config["token"] as? String, "plugin-token")

        let slot = try XCTUnwrap((config["slots"] as? [[String: Any]])?.first)
        let layoutVariant = try XCTUnwrap(slot["layoutVariant"] as? [String: Any])
        XCTAssertEqual(layoutVariant["layoutVariantSchema"] as? String, "{\"node\":\"root\"}")
        XCTAssertEqual(layoutVariant["moduleName"] as? String, "dcui")
    }

    func test_responseOptionsBucketedByIsPositiveAndIconsDropped() throws {
        let exp = try adapt(payload)
        let creative = try XCTUnwrap(creative(in: exp))

        let options = try XCTUnwrap(creative["responseOptionsMap"] as? [String: Any])
        let positive = try XCTUnwrap(options["positive"] as? [String: Any])
        let negative = try XCTUnwrap(options["negative"] as? [String: Any])
        XCTAssertEqual(positive["action"] as? String, "Url")
        XCTAssertEqual(positive["isPositive"] as? Bool, true)
        XCTAssertEqual(negative["action"] as? String, "CaptureOnly")
        XCTAssertEqual(negative["isPositive"] as? Bool, false)

        // icons have no render-side target and must not be emitted.
        XCTAssertNil(creative["icons"])
        XCTAssertNotNil(creative["copy"])
        XCTAssertNotNil(creative["images"])
    }

    func test_offerDroppedWhenCreativeAbsent() throws {
        let leanPayload = """
        {
          "session_id": "s",
          "session_token": { "token": "t", "expires_at": 1 },
          "plugins": [
            { "plugin": { "config": { "slots": [ { "token": "slot-token", "offer": { "campaign_id": "c1" } } ] } } }
          ]
        }
        """
        let exp = try adapt(leanPayload)
        let slot = try XCTUnwrap(firstSlot(in: exp))
        // No creative -> offer is dropped entirely.
        XCTAssertNil(slot["offer"])
    }

    func test_fallbacksWhenPageContextAbsentAndOptionsOmittedWhenEmpty() throws {
        let lean = """
        {
          "session_id": "s",
          "session_token": { "token": "sess-token", "expires_at": 1 },
          "page_instance_guid": "top-pig",
          "plugins": [
            { "plugin": { "config": {
              "token": "ptok",
              "outer_layout_schema": "{\\"layout\\":{}}",
              "slots": [ { "token": "stok", "offer": { "creative": { "referral_creative_id": "rc" } } } ]
            } } }
          ]
        }
        """
        let exp = try adapt(lean)

        // No page_context -> placementContext falls back to the top-level guid + session token.
        let placementContext = try XCTUnwrap(exp["placementContext"] as? [String: Any])
        XCTAssertEqual(placementContext["pageInstanceGuid"] as? String, "top-pig")
        XCTAssertEqual(placementContext["token"] as? String, "sess-token")

        let creative = try XCTUnwrap(creative(in: exp))
        // No copy on the wire -> empty object; no options/images -> keys omitted.
        XCTAssertNotNil(creative["copy"])
        XCTAssertNil(creative["responseOptionsMap"])
        XCTAssertNil(creative["images"])
    }

    // MARK: - helpers

    private func firstSlot(in exp: [String: Any]) -> [String: Any]? {
        let config = ((exp["plugins"] as? [[String: Any]])?.first?["plugin"] as? [String: Any])?["config"] as? [String: Any]
        return (config?["slots"] as? [[String: Any]])?.first
    }

    private func creative(in exp: [String: Any]) -> [String: Any]? {
        (firstSlot(in: exp)?["offer"] as? [String: Any])?["creative"] as? [String: Any]
    }
}

import XCTest
@testable import Rokt_Widget

/// Serialization coverage for the inert v2 offers network models.
///
/// Mirrors Android #1039's `SelectSerializationTest`: proves the request encodes
/// to the transactions `/v2/sessions/offers` contract shape (session identity is
/// carried solely by the `Authorization` JWT, never in the body) and that the
/// response decodes both a realistic payload (pre-serialized DCUI schema strings,
/// nested creative) and a lean payload.
final class TestTxnSelectSerialization: XCTestCase {

    // MARK: - Request

    func test_request_encodesToOffersContractShape() throws {
        let request = TxnSelectRequest(
            page: TxnSelectPage(pageIdentifier: "checkout"),
            channel: TxnSelectChannel(sdkVersion: "5.2.2"),
            attributes: ["standalone": "notdefined"],
            privacyControl: TxnSelectPrivacyControl(
                noFunctional: false,
                noTargeting: false,
                doNotShareOrSell: false
            )
        )

        let expectedJSON = """
        {
          "page": { "page_identifier": "checkout" },
          "channel": { "type": "msdk", "sdk_version": "5.2.2" },
          "attributes": { "standalone": "notdefined" },
          "privacy_control": { "no_functional": false, "no_targeting": false, "do_not_share_or_sell": false }
        }
        """

        let encoded = try JSONEncoder().encode(request)
        let actual = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? NSDictionary)
        let expected = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(expectedJSON.utf8)) as? NSDictionary
        )
        // channel.type is a model default yet must still appear: the offers
        // contract relies on the backend receiving the "msdk" channel source.
        XCTAssertEqual(actual, expected)
    }

    func test_request_omitsSessionIdentityAndPrivacyControlWhenAbsent() throws {
        // No session_id / mp_session_id / mpid in the body — identity is the JWT
        // sub claim in the Authorization header only. privacy_control is omitted
        // entirely when nil rather than encoded as null.
        let request = TxnSelectRequest(
            page: TxnSelectPage(pageIdentifier: "checkout"),
            channel: TxnSelectChannel(sdkVersion: "5.2.2"),
            attributes: [:],
            privacyControl: nil
        )

        let encoded = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        XCTAssertNil(object["session_id"])
        XCTAssertNil(object["mp_session_id"])
        XCTAssertNil(object["mpid"])
        XCTAssertNil(object["customer"])
        XCTAssertNil(object["privacy_control"])
    }

    // MARK: - Response

    private func decode(_ json: String) throws -> TxnSelectResponse {
        try JSONDecoder().decode(TxnSelectResponse.self, from: Data(json.utf8))
    }

    func test_response_decodesRealisticPayloadWithPlugins() throws {
        let payload = """
        {
          "session_id": "session-123",
          "session_token": { "token": "rotated-session-token", "expires_at": 1774474053000 },
          "page_instance_guid": "page-instance-guid-123",
          "page_context": {
            "page_instance_guid": "page-instance-guid-123",
            "page_id": "checkout",
            "token": "page-token"
          },
          "plugins": [
            {
              "plugin": {
                "id": "plugin-1",
                "name": "dcui",
                "target_element_selector": "#rokt",
                "config": {
                  "instance_guid": "ig-1",
                  "token": "plugin-token",
                  "outer_layout_schema": "{\\"layout\\":\\"Overlay\\"}",
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
                          "copy": { "creative.title": "Hello" }
                        }
                      }
                    }
                  ]
                }
              }
            }
          ],
          "event_data": { "creative-ig-1": { "token": "evt-token" } }
        }
        """

        let response = try decode(payload)

        XCTAssertEqual(response.sessionId, "session-123")
        XCTAssertEqual(response.sessionToken.token, "rotated-session-token")
        XCTAssertEqual(response.sessionToken.expiresAt, 1_774_474_053_000)
        XCTAssertEqual(response.pageInstanceGuid, "page-instance-guid-123")
        XCTAssertEqual(response.pageContext?.pageId, "checkout")

        let config = try XCTUnwrap(response.plugins?.first?.plugin?.config)
        XCTAssertEqual(config.instanceGuid, "ig-1")
        // DCUI schemas stay as pre-serialized JSON strings (no re-encoding).
        XCTAssertEqual(config.outerLayoutSchema, "{\"layout\":\"Overlay\"}")

        let slot = try XCTUnwrap(config.slots.first)
        XCTAssertEqual(slot.layoutVariant?.layoutVariantSchema, "{\"node\":\"root\"}")
        XCTAssertEqual(slot.offer?.creative?.copy?["creative.title"], "Hello")
        XCTAssertEqual(response.eventData?["creative-ig-1"]?.token, "evt-token")
    }

    func test_response_decodesLeanPayloadWithNoPlugins() throws {
        let payload = """
        {
          "session_id": "session-123",
          "session_token": { "token": "rotated-session-token", "expires_at": 1774474053000 }
        }
        """

        let response = try decode(payload)

        XCTAssertEqual(response.sessionId, "session-123")
        XCTAssertEqual(response.pageInstanceGuid, "")
        XCTAssertNil(response.plugins)
        XCTAssertNil(response.pageContext)
    }

    func test_response_ignoresUnknownKeys() throws {
        // Provider emits omitempty throughout and carries more fields than the
        // SDK models; unknown keys must not fail the decode.
        let payload = """
        {
          "session_id": "session-123",
          "session_token": { "token": "t", "expires_at": 1 },
          "placements": [ { "unexpected": true } ],
          "metadata": { "selection_id": "abc" }
        }
        """

        let response = try decode(payload)
        XCTAssertEqual(response.sessionId, "session-123")
    }

    func test_response_decodesTypedCatalogItems() throws {
        // catalog_items decodes into the typed model (mapping to render models is
        // still deferred to the mapper). Unknown wire keys are tolerated.
        let payload = """
        {
          "session_id": "session-123",
          "session_token": { "token": "t", "expires_at": 1 },
          "plugins": [
            { "plugin": { "config": { "slots": [
              { "offer": { "campaign_id": "c1", "catalog_items": [
                {
                  "catalog_item_id": "cat-1",
                  "title": "Sample item",
                  "price": 9.99,
                  "currency": "USD",
                  "min_item_count": 1,
                  "quantity_must_be_synchronized": true,
                  "images": { "hero": { "light": "light.png", "dark": "dark.png" } },
                  "token": "catalog-token",
                  "unexpected_field": "ignored"
                }
              ] } }
            ] } } }
          ]
        }
        """

        let response = try decode(payload)
        let item = try XCTUnwrap(
            response.plugins?.first?.plugin?.config?.slots.first?.offer?.catalogItems?.first
        )
        XCTAssertEqual(item.catalogItemId, "cat-1")
        XCTAssertEqual(item.title, "Sample item")
        XCTAssertEqual(item.price, 9.99)
        XCTAssertEqual(item.currency, "USD")
        XCTAssertEqual(item.minItemCount, 1)
        XCTAssertEqual(item.quantityMustBeSynchronized, true)
        XCTAssertEqual(item.images?["hero"]?.light, "light.png")
        XCTAssertEqual(item.token, "catalog-token")
    }
}

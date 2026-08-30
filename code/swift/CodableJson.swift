// Codable: encoding and decoding JSON with the compiler writing most of it.

import Foundation

struct Order: Codable {
    let orderId: String
    let userId: Int
    let total: Decimal
    let status: Status
    let shippedAt: Date?

    enum Status: String, Codable {
        case pending, paid, shipped, delivered, cancelled
    }

    // CodingKeys map JSON names onto Swift names.
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case userId = "user_id"
        case total, status
        case shippedAt = "shipped_at"
    }
}

// A custom init(from:) takes over when the mapping is not one to one.
struct Station: Codable {
    let name: String
    let zone: Int
    let stepFree: Bool

    enum CodingKeys: String, CodingKey {
        case name, zone
        case facilities
    }

    enum FacilityKeys: String, CodingKey {
        case stepFree = "step_free"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        zone = try container.decodeIfPresent(Int.self, forKey: .zone) ?? 1

        let facilities = try container.nestedContainer(keyedBy: FacilityKeys.self, forKey: .facilities)
        stepFree = try facilities.decode(Bool.self, forKey: .stepFree)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(zone, forKey: .zone)
        var facilities = container.nestedContainer(keyedBy: FacilityKeys.self, forKey: .facilities)
        try facilities.encode(stepFree, forKey: .stepFree)
    }
}

do {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let orders = [
        Order(orderId: "ORD-10001", userId: 82, total: 104.35, status: .delivered,
              shippedAt: Date(timeIntervalSince1970: 1_762_161_300)),
        Order(orderId: "ORD-10002", userId: 6, total: 42.99, status: .pending, shippedAt: nil),
    ]

    let data = try encoder.encode(orders)
    print(String(decoding: data, as: UTF8.self))

    let decoded = try decoder.decode([Order].self, from: data)
    print("\ndecoded \(decoded.count), first is \(decoded[0].orderId), status \(decoded[0].status)")
    print("total:", decoded.reduce(Decimal(0)) { $0 + $1.total })

    // The nested shape, through the custom coding above.
    let stationJson = Data("""
    [{"name": "Alder Cross", "zone": 2, "facilities": {"step_free": true}},
     {"name": "Quill Wharf", "facilities": {"step_free": false}}]
    """.utf8)

    let stations = try decoder.decode([Station].self, from: stationJson)
    for station in stations {
        print("\(station.name) zone \(station.zone) step free \(station.stepFree)")
    }

    // A snake_case strategy avoids writing CodingKeys at all.
    struct Reading: Codable {
        let deviceId: String
        let temperatureC: Double
    }
    let snakeDecoder = JSONDecoder()
    snakeDecoder.keyDecodingStrategy = .convertFromSnakeCase
    let reading = try snakeDecoder.decode(
        Reading.self,
        from: Data(#"{"device_id": "SNS-01", "temperature_c": 21.4}"#.utf8)
    )
    print("\nsnake case:", reading)

    // Decoding failures say exactly which key went wrong.
    do {
        _ = try decoder.decode([Order].self, from: Data(#"[{"order_id": "X"}]"#.utf8))
    } catch let DecodingError.keyNotFound(key, context) {
        print("missing key \(key.stringValue): \(context.debugDescription)")
    } catch {
        print("failed:", error)
    }

    // JSONSerialization is the untyped route, for shapes without a struct.
    if let loose = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
        print("loose read:", loose[0]["order_id"] as Any)
    }
} catch {
    print("failed:", error)
}

import Testing
@testable import Cirrus
import Foundation

struct JSONCodersTests {
    struct TestModel: Codable, Equatable {
        let name: String
        let date: Date
        let count: Int
    }

    @Test func roundTripPreservesDates() throws {
        let original = TestModel(name: "test", date: Date(timeIntervalSince1970: 1000000), count: 42)
        let data = try JSONEncoder.cirrus.encode(original)
        let decoded = try JSONDecoder.cirrus.decode(TestModel.self, from: data)
        #expect(decoded == original)
    }

    @Test func encoderProducesSortedKeys() throws {
        let model = TestModel(name: "test", date: Date(timeIntervalSince1970: 0), count: 1)
        let data = try JSONEncoder.cirrus.encode(model)
        let json = String(data: data, encoding: .utf8)!
        let countIndex = json.range(of: "\"count\"")!.lowerBound
        let dateIndex = json.range(of: "\"date\"")!.lowerBound
        let nameIndex = json.range(of: "\"name\"")!.lowerBound
        #expect(countIndex < dateIndex)
        #expect(dateIndex < nameIndex)
    }

    @Test func encoderProducesPrettyPrintedOutput() throws {
        let model = TestModel(name: "test", date: Date(timeIntervalSince1970: 0), count: 1)
        let data = try JSONEncoder.cirrus.encode(model)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\n"))
    }

    @Test func decoderHandlesISO8601Dates() throws {
        let json = """
        {"name":"test","date":"1970-01-12T13:46:40Z","count":1}
        """
        let model = try JSONDecoder.cirrus.decode(TestModel.self, from: Data(json.utf8))
        #expect(model.date == Date(timeIntervalSince1970: 1000000))
    }
}

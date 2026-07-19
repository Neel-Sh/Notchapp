import Foundation

struct LocalJSONStore {
    let rootURL: URL

    init(rootURL: URL? = nil) {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.rootURL = base.appendingPathComponent("NotchShelf", isDirectory: true)
        }
    }

    var shelfDirectory: URL {
        rootURL.appendingPathComponent("Shelf", isDirectory: true)
    }

    func prepareDirectories() throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shelfDirectory, withIntermediateDirectories: true)
    }

    func load<T: Decodable>(_ type: T.Type, from filename: String, default defaultValue: T) -> T {
        let url = rootURL.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else {
            return defaultValue
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(T.self, from: data)) ?? defaultValue
    }

    func save<T: Encodable>(_ value: T, to filename: String) throws {
        try prepareDirectories()
        let url = rootURL.appendingPathComponent(filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }
}

import Foundation

public struct DisplayProfile: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var curve: BrightnessCurve

    public init(id: String, name: String, curve: BrightnessCurve = .default) {
        self.id = id
        self.name = name
        self.curve = curve
    }
}

public struct MaclumSettings: Codable, Equatable, Sendable {
    public private(set) var profiles: [DisplayProfile]

    public init(profiles: [DisplayProfile] = []) {
        self.profiles = Self.uniqueProfiles(from: profiles)
    }

    public static let `default` = MaclumSettings()

    @discardableResult
    public mutating func synchronizeProfiles(with displays: [DDCDisplay]) -> Bool {
        let storedProfiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        let activeIDs = Set(displays.map(\.id))
        let activeProfiles = displays.map { display in
            var profile = storedProfiles[display.id] ?? DisplayProfile(id: display.id, name: display.name)
            profile.name = display.name
            return profile
        }
        let inactiveProfiles = profiles.filter { !activeIDs.contains($0.id) }
        let updatedProfiles = activeProfiles + inactiveProfiles

        guard profiles != updatedProfiles else { return false }
        profiles = updatedProfiles
        return true
    }

    public func activeProfiles(for displays: [DDCDisplay]) -> [DisplayProfile] {
        let profilesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        return displays.compactMap { profilesByID[$0.id] }
    }

    public func inactiveProfiles(for displays: [DDCDisplay]) -> [DisplayProfile] {
        let activeIDs = Set(displays.map(\.id))
        return profiles.filter { !activeIDs.contains($0.id) }
    }

    public mutating func setCurve(_ curve: BrightnessCurve, for displayID: String) {
        guard let index = profiles.firstIndex(where: { $0.id == displayID }) else { return }
        profiles[index].curve = curve
    }

    @discardableResult
    public mutating func removeProfile(id: String) -> Bool {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return false }
        profiles.remove(at: index)
        return true
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let profiles = try container.decodeIfPresent([DisplayProfile].self, forKey: .profiles) {
            self.init(profiles: profiles)
            return
        }

        guard container.contains(.curve) else {
            self.init()
            return
        }

        let curve = try container.decode(BrightnessCurve.self, forKey: .curve)
        let displayID = try container.decodeIfPresent(String.self, forKey: .selectedDisplayID)
        self.init(profiles: displayID.map { [DisplayProfile(id: $0, name: "External Display", curve: curve)] } ?? [])
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profiles, forKey: .profiles)
    }

    private enum CodingKeys: String, CodingKey {
        case profiles
        case curve
        case selectedDisplayID
    }

    private static func uniqueProfiles(from profiles: [DisplayProfile]) -> [DisplayProfile] {
        var seenIDs = Set<String>()
        return profiles.filter { seenIDs.insert($0.id).inserted }
    }
}

public struct SettingsStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> MaclumSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .default }
        return try JSONDecoder().decode(MaclumSettings.self, from: Data(contentsOf: fileURL))
    }

    public func save(_ settings: MaclumSettings) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: fileURL, options: .atomic)
    }
}

import Foundation

public enum BrowsingMode: String, Codable, CaseIterable, Sendable { case embedded, browserApp }

public struct GlobalShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public static let control: UInt32 = 1
    public static let option: UInt32 = 2
    public static let shift: UInt32 = 4
    public static let command: UInt32 = 8
    public static let `default` = Self(keyCode: 47, modifiers: control | option)
    public static let keys: [(name: String, code: UInt32)] = [
        ("A",0),("B",11),("C",8),("D",2),("E",14),("F",3),("G",5),("H",4),("I",34),
        ("J",38),("K",40),("L",37),("M",46),("N",45),("O",31),("P",35),("Q",12),
        ("R",15),("S",1),("T",17),("U",32),("V",9),("W",13),("X",7),("Y",16),("Z",6),
        (",",43),(".",47),("/",44),(";",41),("'",39),
        ("[",33),("]",30),("\\",42),("-",27),("=",24),
        ("F1",122),("F2",120),("F3",99),("F4",118),("F5",96),("F6",97),("F7",98),
        ("F8",100),("F9",101),("F10",109),("F11",103),("F12",111),("F19",80),
    ]
    public init(keyCode: UInt32, modifiers: UInt32) { self.keyCode = keyCode; self.modifiers = modifiers }
    public var isValid: Bool {
        Self.keys.contains(where: { $0.code == keyCode }) && modifiers & ~15 == 0 && modifiers & (Self.control | Self.command) != 0
    }
    public var label: String {
        [(Self.control,"⌃"),(Self.option,"⌥"),(Self.shift,"⇧"),(Self.command,"⌘")]
            .filter { modifiers & $0.0 != 0 }.map(\.1).joined() + (Self.keys.first { $0.code == keyCode }?.name ?? "?")
    }
}

public enum DotEntryURL {
    public static func validate(_ input: String) -> URL? {
        guard let url = URL(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", url.host?.lowercased() == "chatgpt.com",
              url.user == nil, url.password == nil, url.port == nil || url.port == 443 else { return nil }
        return url
    }
}

public struct DotPreferences: Codable, Equatable, Sendable {
    public var entryURL = DotIdentity.entryURL.absoluteString
    public var hideOnFocusLoss = true
    public var keepOpen = false
    public var preloadAtLaunch = false
    public var focusComposerOnShow = true
    public var hasCompletedOnboarding = false
    public var browsingMode: BrowsingMode = .embedded
    public var shortcut: GlobalShortcut? = .default
    public var viewportWidth: Double = 480
    public var viewportHeight: Double = 720
    public var preferredX: Double?
    public var preferredY: Double?
    public var browserAppBookmark: Data?
    public var browserAppName: String?
    public init() {}

    enum CodingKeys: String, CodingKey {
        case entryURL, hideOnFocusLoss, keepOpen, preloadAtLaunch, focusComposerOnShow, hasCompletedOnboarding,
             browsingMode, shortcut, viewportWidth, viewportHeight, preferredX, preferredY,
             browserAppBookmark, browserAppName
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        entryURL = try values.decodeIfPresent(String.self, forKey: .entryURL) ?? entryURL
        hideOnFocusLoss = try values.decodeIfPresent(Bool.self, forKey: .hideOnFocusLoss) ?? hideOnFocusLoss
        keepOpen = try values.decodeIfPresent(Bool.self, forKey: .keepOpen) ?? keepOpen
        preloadAtLaunch = try values.decodeIfPresent(Bool.self, forKey: .preloadAtLaunch) ?? preloadAtLaunch
        focusComposerOnShow = try values.decodeIfPresent(Bool.self, forKey: .focusComposerOnShow) ?? focusComposerOnShow
        hasCompletedOnboarding = try values.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? hasCompletedOnboarding
        browsingMode = try values.decodeIfPresent(BrowsingMode.self, forKey: .browsingMode) ?? browsingMode
        if values.contains(.shortcut) { shortcut = try values.decodeIfPresent(GlobalShortcut.self, forKey: .shortcut) }
        viewportWidth = try values.decodeIfPresent(Double.self, forKey: .viewportWidth) ?? viewportWidth
        viewportHeight = try values.decodeIfPresent(Double.self, forKey: .viewportHeight) ?? viewportHeight
        preferredX = try values.decodeIfPresent(Double.self, forKey: .preferredX)
        preferredY = try values.decodeIfPresent(Double.self, forKey: .preferredY)
        browserAppBookmark = try values.decodeIfPresent(Data.self, forKey: .browserAppBookmark)
        browserAppName = try values.decodeIfPresent(String.self, forKey: .browserAppName)
        self = sanitized()
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(entryURL, forKey: .entryURL)
        try values.encode(hideOnFocusLoss, forKey: .hideOnFocusLoss)
        try values.encode(keepOpen, forKey: .keepOpen)
        try values.encode(preloadAtLaunch, forKey: .preloadAtLaunch)
        try values.encode(focusComposerOnShow, forKey: .focusComposerOnShow)
        try values.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try values.encode(browsingMode, forKey: .browsingMode)
        // An explicit null means disabled; a missing key means an older version
        // that should receive the default shortcut during migration.
        try values.encode(shortcut, forKey: .shortcut)
        try values.encode(viewportWidth, forKey: .viewportWidth)
        try values.encode(viewportHeight, forKey: .viewportHeight)
        try values.encodeIfPresent(preferredX, forKey: .preferredX)
        try values.encodeIfPresent(preferredY, forKey: .preferredY)
        try values.encodeIfPresent(browserAppBookmark, forKey: .browserAppBookmark)
        try values.encodeIfPresent(browserAppName, forKey: .browserAppName)
    }

    public func sanitized() -> Self {
        var copy = self
        if DotEntryURL.validate(entryURL) == nil { copy.entryURL = DotIdentity.entryURL.absoluteString }
        if let shortcut, !shortcut.isValid { copy.shortcut = .default }
        copy.viewportWidth = viewportWidth.isFinite ? min(max(viewportWidth, 420), 10000) : 480
        copy.viewportHeight = viewportHeight.isFinite ? min(max(viewportHeight, 520), 10000) : 720
        if preferredX?.isFinite != true || preferredY?.isFinite != true { copy.preferredX = nil; copy.preferredY = nil }
        if browserAppBookmark == nil { copy.browsingMode = .embedded }
        return copy
    }
}

public struct PreferencesRepository {
    private let defaults: UserDefaults
    private let key = "YourDotMini.preferences.v1"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func load() -> DotPreferences {
        guard let data = defaults.data(forKey: key), let result = try? JSONDecoder().decode(DotPreferences.self, from: data) else { return DotPreferences() }
        return result.sanitized()
    }
    public func save(_ value: DotPreferences) throws { defaults.set(try JSONEncoder().encode(value.sanitized()), forKey: key) }
}

import Foundation

public enum BuildConfig {
    public static let appBundleID = Bundle.main.bundleIdentifier ?? "io.goodkind.stickies-improved"
    public static let iCloudContainerIdentifier = "iCloud.io.goodkind.stickies-improved"
    public static let sparkleFeedURL = Bundle.main
        .object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
    public static let sparklePublicKey = ""
    public static let buildVersion = Bundle.main
        .object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    public static let marketingVersion = Bundle.main
        .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
}

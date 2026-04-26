import ProjectDescription

let appName = "StickiesImproved"
let organizationName = "goodkind.io"
let bundleId = "io.goodkind.stickies-improved"

let debug = Configuration.debug(
    name: "Debug",
    xcconfig: "Config/debug.xcconfig"
)

let release = Configuration.release(
    name: "Release",
    xcconfig: "Config/release.xcconfig"
)

let scripts: [TargetScript] = [
    .pre(
        script: """
        "${SRCROOT}/Scripts/generate-config.sh"
        """,
        name: "Generate Build Config",
        outputPaths: [
            "$(DERIVED_FILE_DIR)/Generated/Config.generated.swift"
        ]
    )
]

let settings = Settings.settings(
    base: [
        "SWIFT_VERSION": "6.0",
        "CODE_SIGN_STYLE": "Manual",
        "DEVELOPMENT_TEAM": "$(DEVELOPMENT_TEAM)",
        "CODE_SIGN_IDENTITY": "$(CODE_SIGN_IDENTITY)",
        "MARKETING_VERSION": "$(MARKETING_VERSION)",
        "CURRENT_PROJECT_VERSION": "$(CURRENT_PROJECT_VERSION)",
        "ENABLE_HARDENED_RUNTIME": "YES"
    ],
    configurations: [debug, release],
    defaultSettings: .recommended
)

let infoPlist: [String: Plist.Value] = [
    "CFBundleDisplayName": .string(appName),
    "CFBundleShortVersionString": .string("$(MARKETING_VERSION)"),
    "CFBundleVersion": .string("$(CURRENT_PROJECT_VERSION)"),
    "LSApplicationCategoryType": .string("public.app-category.productivity"),
    "NSUbiquitousContainers": .dictionary([
        "$(ICLOUD_CONTAINER_IDENTIFIER)": .dictionary([
            "NSUbiquitousContainerName": .string(appName),
            "NSUbiquitousContainerSupportedFolderLevels": .string("Any")
        ])
    ]),
    "SUEnableAutomaticChecks": .boolean(true),
    "SUAllowsAutomaticUpdates": .boolean(true),
    "SUFeedURL": .string("$(SPARKLE_FEED_URL)")
]

let project = Project(
    name: appName,
    organizationName: organizationName,
    settings: settings,
    targets: [
        .target(
            name: "\(appName)Core",
            destinations: [.mac],
            product: .framework,
            bundleId: "\(bundleId).core",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .default,
            sources: [
                "Models/**",
                "Stores/**",
                "Services/**",
                "Support/BuildConfig.swift",
                "Support/RuntimeEnvironment.swift"
            ],
            scripts: scripts,
            dependencies: [
                .external(name: "Sparkle")
            ]
        ),
        .target(
            name: appName,
            destinations: [.mac],
            product: .app,
            bundleId: bundleId,
            deploymentTargets: .macOS("15.0"),
            infoPlist: .extendingDefault(with: infoPlist),
            sources: [
                "App/**",
                "Views/**",
                "Support/NoteCommands.swift",
                "Support/StickyWindowChromeBridge.swift"
            ],
            resources: [],
            entitlements: "Config/StickiesImproved.entitlements",
            dependencies: [
                .target(name: "\(appName)Core")
            ],
            settings: .settings(
                base: [
                    "PRODUCT_NAME": .string(appName),
                    "PRODUCT_BUNDLE_IDENTIFIER": .string("$(APP_BUNDLE_ID)")
                ]
            )
        ),
        .target(
            name: "\(appName)Tests",
            destinations: [.mac],
            product: .unitTests,
            bundleId: "\(bundleId).tests",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .default,
            sources: ["Tests/StickiesTests/**"],
            dependencies: [
                .target(name: "\(appName)Core")
            ]
        )
    ],
    schemes: [
        .scheme(
            name: appName,
            shared: true,
            buildAction: .buildAction(targets: ["\(appName)"]),
            testAction: .targets(["\(appName)Tests"], configuration: "Debug"),
            runAction: .runAction(configuration: "Debug"),
            archiveAction: .archiveAction(configuration: "Release"),
            profileAction: .profileAction(configuration: "Release"),
            analyzeAction: .analyzeAction(configuration: "Debug")
        )
    ]
)

// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "APWebAuthentication",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "APWebAuthentication",
            targets: ["APWebAuthentication"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.0.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.0"),
        .package(url: "https://github.com/rhodgkins/SwiftHTTPStatusCodes.git", from: "3.3.0"),
        .package(url: "https://github.com/JonasGessner/JGProgressHUD.git", from: "2.0.0"),
        .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols.git", from: "6.2.0"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.0.0"),
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", from: "2.1.1"),
        .package(url: "https://github.com/SwifterSwift/SwifterSwift.git", from: "8.0.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),
        .package(url: "https://github.com/sunshinejr/SwiftyUserDefaults.git", from: "5.0.0"),
        .package(url: "https://github.com/devicekit/DeviceKit.git", from: "5.0.0"),
        .package(path: "../APUserAgentGenerator")
    ],
    targets: [
        .target(
            name: "APWebAuthentication",
            dependencies: [
                "Alamofire",
                "CryptoSwift",
                .product(name: "HTTPStatusCodes", package: "SwiftHTTPStatusCodes"),
                "JGProgressHUD",
                "SnapKit",
                "SwiftyBeaver",
                "SFSafeSymbols",
                "SwifterSwift",
                "SwiftyJSON",
                "SwiftyUserDefaults",
                "DeviceKit",
                "APUserAgentGenerator"
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "APWebAuthenticationTests",
            dependencies: ["APWebAuthentication"],
            path: "Tests"
        )
    ]
)

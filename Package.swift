// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "APWebAuthentication",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "APWebAuthentication",
            targets: ["APWebAuthentication"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.11.0"),
        .package(url: "https://github.com/rhodgkins/SwiftHTTPStatusCodes.git", from: "3.3.0"),
        .package(url: "https://github.com/JonasGessner/JGProgressHUD.git", from: "2.0.0"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "6.0.0"),
        .package(url: "https://github.com/SwifterSwift/SwifterSwift.git", from: "8.0.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),
        .package(url: "https://github.com/aporat/APUserAgentGenerator.git", branch: "main"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.0")
    ],
    targets: [
        .target(
            name: "APWebAuthentication",
            dependencies: [
                "Alamofire",
                .product(name: "HTTPStatusCodes", package: "SwiftHTTPStatusCodes"),
                "JGProgressHUD",
                "SnapKit",
                "SwifterSwift",
                "SwiftyJSON",
                "APUserAgentGenerator",
                "KeychainAccess"
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

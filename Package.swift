// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AeolianNote",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AeolianNote",
            targets: ["AeolianNote"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "AeolianNote",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            path: "."
        ),
    ]
)

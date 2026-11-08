// swift-tools-version: 6.0
// O conhecimento de treino do CRUNNING: sem UI, determinístico e testado.
// Só Foundation, para os testes rodarem em qualquer Mac (e até em Linux).
import PackageDescription

let package = Package(
    name: "CrunningCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CrunningCore", targets: ["CrunningCore"]),
    ],
    targets: [
        .target(name: "CrunningCore"),
        .testTarget(name: "CrunningCoreTests", dependencies: ["CrunningCore"]),
    ]
)

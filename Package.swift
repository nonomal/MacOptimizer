// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacOptimizer",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "AppUninstaller", targets: ["AppUninstaller"])
    ],
    targets: [
        .executableTarget(
            name: "AppUninstaller",
            path: "AppUninstaller",
            exclude: [
                "Info.plist",
                "compile_errors.txt",
                "resource"
            ],
            resources: [
                .process("AppIcon.icns"),
                .process("ButtonClick.m4a"),
                .process("CleanDidFinish-Winter.m4a"),
                .process("CleanDidFinish.m4a"),
                .process("Intro.mp4"),
                .process("Uninstaller.jpg"),
                .process("Uninstaller@2x.jpg"),
                .process("appuploader.png"),
                .process("clean-up.866fafd0.png"),
                .process("deepclean_app_residue.png"),
                .process("deepclean_cache_files.png"),
                .process("deepclean_large_files.png"),
                .process("deepclean_log_files.png"),
                .process("deepclean_system_junk.png"),
                .process("feizhilou.png"),
                .process("kongjianshentou copy.png"),
                .process("kongjianshentou.png"),
                .process("malware@2x.png"),
                .process("protection.80f7790f.png"),
                .process("resubscribe_welcome.png"),
                .process("resubscribe_welcome@2x.png"),
                .process("shenduqingli.png"),
                .process("smart-scan.2f4ddf59.png"),
                .process("system-junk-mouse.png"),
                .process("system_clean_menu.png"),
                .process("welcome.icns"),
                .process("welcome.png"),
                .process("yibiaopan_2026.png"),
                .process("yinpan_2026.png"),
                .process("yinsi.png"),
                .process("youhua.png"),
                .process("zhiwendunpai_2026.png")
            ]
        ),
        .testTarget(
            name: "AppUninstallerTests",
            dependencies: ["AppUninstaller"]
        )
    ]
)

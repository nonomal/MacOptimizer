import Foundation

@main
enum DynamicLocalizationVerifier {
    private struct Case {
        let simplifiedChinese: String
        let english: String
        let expected: [AppLanguage: String]
    }

    static func main() {
        let cases: [Case] = [
            Case(
                simplifiedChinese: "已删除 3 个快照",
                english: "Deleted 3 snapshots",
                expected: [
                    .chinese: "已删除 3 个快照",
                    .traditionalChinese: "已刪除 3 個快照",
                    .english: "Deleted 3 snapshots",
                    .japanese: "3個のスナップショットを削除しました",
                    .korean: "스냅샷 3개 삭제됨",
                    .russian: "Удалено снимков: 3"
                ]
            ),
            Case(
                simplifiedChinese: "已使用 2 GB，共 8 GB",
                english: "2 GB used of 8 GB",
                expected: [
                    .chinese: "已使用 2 GB，共 8 GB",
                    .traditionalChinese: "已使用 2 GB，共 8 GB",
                    .english: "2 GB used of 8 GB",
                    .japanese: "2 GB / 8 GB 使用済み",
                    .korean: "8 GB 중 2 GB 사용됨",
                    .russian: "Занято: 2 GB из 8 GB"
                ]
            ),
            Case(
                simplifiedChinese: "确定要删除“demo.txt”吗？此操作无法撤销。",
                english: "Are you sure you want to delete \"demo.txt\"? This action cannot be undone.",
                expected: [
                    .chinese: "确定要删除“demo.txt”吗？此操作无法撤销。",
                    .traditionalChinese: "您確定要刪除「demo.txt」嗎？此動作無法復原。",
                    .english: "Are you sure you want to delete \"demo.txt\"? This action cannot be undone.",
                    .japanese: "「demo.txt」を削除してもよろしいですか？この操作は元に戻せません。",
                    .korean: "\"demo.txt\" 파일을 삭제하시겠습니까? 이 작업은 취소할 수 없습니다.",
                    .russian: "Вы уверены, что хотите удалить «demo.txt»? Это действие необратимо."
                ]
            ),
            Case(
                simplifiedChinese: "此操作将清除 App 的所有缓存、日志和配置数据。\nApp 本身（42 MB）将被保留。",
                english: "This will clean all cache, logs, and config data.\nThe app itself (42 MB) will be kept.",
                expected: [
                    .chinese: "此操作将清除 App 的所有缓存、日志和配置数据。\nApp 本身（42 MB）将被保留。",
                    .traditionalChinese: "此操作將清除 App 的所有快取、記錄檔和配置資料。\nApp 本身（42 MB）將被保留。",
                    .english: "This will clean all cache, logs, and config data.\nThe app itself (42 MB) will be kept.",
                    .japanese: "これにより、App のキャッシュ、ログ、構成データがすべてクリーンアップされます。\nApp 本体（42 MB）は保持されます。",
                    .korean: "이 작업은 앱의 모든 캐시, 로그 및 구성 데이터를 정리합니다.\n앱 자체(42 MB)는 유지됩니다.",
                    .russian: "Будут удалены все кэш, журналы и данные конфигурации.\nСамо приложение (42 MB) будет сохранено."
                ]
            )
        ]

        let localization = LocalizationManager()
        var failures: [String] = []

        for testCase in cases {
            for language in AppLanguage.allCases {
                localization.currentLanguage = language
                let actual = localization.text(testCase.simplifiedChinese, testCase.english)
                guard let expected = testCase.expected[language], actual == expected else {
                    failures.append("\(language.rawValue): \(testCase.english) -> \(actual)")
                    continue
                }
            }
        }

        if failures.isEmpty {
            print("Dynamic localization verification passed (\(cases.count) cases x \(AppLanguage.allCases.count) languages).")
            return
        }

        failures.forEach { fputs("FAIL: \($0)\n", stderr) }
        exit(EXIT_FAILURE)
    }
}

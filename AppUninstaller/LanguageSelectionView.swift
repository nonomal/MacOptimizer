import SwiftUI

struct LanguageSelectionView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var selection = AppLanguage.suggested
    let isInitialSetup: Bool
    let onComplete: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.45, green: 0.06, blue: 0.35),
                    Color(red: 0.13, green: 0.07, blue: 0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.07)).frame(width: 74, height: 74)
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundColor(Color(red: 0.36, green: 0.85, blue: 0.98))
                }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(AppLanguage.allCases) { language in
                        languageButton(language)
                    }
                }
                .frame(maxWidth: 510)

                Button {
                    localization.setLanguage(selection)
                    onComplete()
                } label: {
                    HStack(spacing: 8) {
                        Text(continueTitle)
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 210, height: 42)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.18, green: 0.68, blue: 0.95), Color(red: 0.47, green: 0.35, blue: 0.96)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: Color.blue.opacity(0.28), radius: 14, y: 5)
                }
                .buttonStyle(.plain)
            }
            .padding(38)
        }
        .frame(minWidth: 720, minHeight: 560)
        .onAppear { selection = isInitialSetup ? AppLanguage.suggested : localization.currentLanguage }
    }

    private func languageButton(_ language: AppLanguage) -> some View {
        let selected = selection == language
        return Button { selection = language } label: {
            HStack(spacing: 12) {
                Text(language.flag).font(.system(size: 23))
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                    Text(language.localeIdentifier)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.38))
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? Color.cyan : Color.white.opacity(0.20))
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(Color.white.opacity(selected ? 0.10 : 0.045), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.cyan.opacity(0.58) : Color.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        switch selection {
        case .chinese: return "选择您的语言"
        case .traditionalChinese: return "選擇您的語言"
        case .english: return "Choose your language"
        case .japanese: return "言語を選択"
        case .korean: return "언어를 선택하세요"
        case .russian: return "Выберите язык"
        }
    }

    private var subtitle: String {
        switch selection {
        case .chinese: return "您可以稍后在设置中随时更改语言"
        case .traditionalChinese: return "您可以稍後在設定中隨時更改語言"
        case .english: return "You can change this later in Settings"
        case .japanese: return "言語は後から設定で変更できます"
        case .korean: return "언어는 나중에 설정에서 변경할 수 있습니다"
        case .russian: return "Язык можно изменить позже в настройках"
        }
    }

    private var continueTitle: String {
        switch selection {
        case .chinese: return "继续"
        case .traditionalChinese: return "繼續"
        case .english: return "Continue"
        case .japanese: return "続ける"
        case .korean: return "계속"
        case .russian: return "Продолжить"
        }
    }
}

struct LanguagePreferencesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LanguageSelectionView(isInitialSetup: false) { dismiss() }
            .frame(width: 720, height: 560)
    }
}

import SwiftUI

struct SettingsView: View {
    @ObservedObject var loc = LocalizationManager.shared
    @StateObject private var updateService = UpdateCheckerService.shared
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true
    
    // Environment to close the sheet/window
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(t("设置", "設定", "Settings", "設定", "설정", "Настройки"))
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .padding(5)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.black.opacity(0.2))
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // App Info Section
                    VStack(alignment: .center, spacing: 12) {
                        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                            .resizable()
                            .frame(width: 80, height: 80)
                        
                        Text(loc.currentLanguage.productName)
                            .font(.headline)
                        
                        Text("\(t("版本", "版本", "Version", "バージョン", "버전", "Версия")) \(updateService.currentVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    
                    Divider().opacity(0.5)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(t("语言", "語言", "Language", "言語", "언어", "Язык"))
                            .font(.headline)

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(loc.currentLanguage.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                Text(t(
                                    "更改后立即应用到整个应用；系统权限文字会在重启后更新",
                                    "變更後會立即套用到整個應用程式；系統權限文字會在重新啟動後更新",
                                    "Changes apply immediately; system permission text updates after relaunch",
                                    "変更はすぐにアプリ全体へ反映されます。システム権限の表示は再起動後に更新されます",
                                    "변경 사항은 앱 전체에 즉시 적용되며 시스템 권한 문구는 재실행 후 업데이트됩니다",
                                    "Изменения применяются сразу; текст системных разрешений обновится после перезапуска"
                                ))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Picker("", selection: Binding(
                                get: { loc.currentLanguage },
                                set: { loc.setLanguage($0) }
                            )) {
                                ForEach(AppLanguage.allCases) { language in
                                    Text("\(language.flag) \(language.displayName)").tag(language)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 170)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
                    }

                    Divider().opacity(0.5)
                    
                    // Update Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(t("软件更新", "軟體更新", "Software Update", "ソフトウェアアップデート", "소프트웨어 업데이트", "Обновление ПО"))
                            .font(.headline)
                        
                        // Auto Check Toggle
                        Toggle(isOn: $autoCheckUpdates) {
                            Text(t("自动检测更新", "自動檢查更新", "Automatically check for updates", "アップデートを自動的に確認", "업데이트 자동 확인", "Автоматически проверять обновления"))
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        
                        // Check Button / Status
                        if updateService.isChecking {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.5)
                                Text(t("正在检测更新...", "正在檢查更新...", "Checking for updates...", "アップデートを確認中...", "업데이트 확인 중...", "Проверка обновлений..."))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            if updateService.hasUpdate {
                                // New Version Available
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.yellow)
                                        Text("\(t("发现新版本", "發現新版本", "New version available", "新しいバージョンがあります", "새 버전 사용 가능", "Доступна новая версия")): \(updateService.latestVersion)")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                    }
                                    
                                    if !updateService.releaseNotes.isEmpty {
                                        Text(updateService.releaseNotes)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(3)
                                    }
                                    
                                    Button(action: {
                                        if let url = updateService.downloadURL {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }) {
                                        Text(t("立即更新", "立即更新", "Update Now", "今すぐアップデート", "지금 업데이트", "Обновить сейчас"))
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                                
                            } else {
                                // No Update / Checked
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(t("当前已是最新版本", "目前已是最新版本", "MacOptimizer is up to date", "最新バージョンです", "최신 버전입니다", "Установлена последняя версия"))
                                            .foregroundColor(.secondary)
                                        Text(t("上次检测：刚刚", "上次檢查：剛剛", "Last checked: Just now", "最終確認：たった今", "마지막 확인: 방금", "Последняя проверка: только что"))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button(action: {
                                        Task {
                                            await updateService.checkForUpdates()
                                        }
                                    }) {
                                        Text(t("检测更新", "檢查更新", "Check for Updates", "アップデートを確認", "업데이트 확인", "Проверить обновления"))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.white.opacity(0.1))
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if autoCheckUpdates && !updateService.hasUpdate && !updateService.isChecking {
                Task {
                    await updateService.checkForUpdates()
                }
            }
        }
    }

    private func t(
        _ simplifiedChinese: String,
        _ traditionalChinese: String,
        _ english: String,
        _ japanese: String,
        _ korean: String,
        _ russian: String
    ) -> String {
        loc.text(
            simplifiedChinese: simplifiedChinese,
            traditionalChinese: traditionalChinese,
            english: english,
            japanese: japanese,
            korean: korean,
            russian: russian
        )
    }
}

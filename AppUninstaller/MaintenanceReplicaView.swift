import SwiftUI
import AppKit

struct MaintenanceReplicaView: View {
    @StateObject private var service = MaintenanceService.shared
    @ObservedObject private var loc = LocalizationManager.shared

    @State private var screen: Screen = .intro
    @State private var orbHovered = false

    private enum Screen {
        case intro
        case details
        case running
        case complete
    }

    private let originalTasks: [MaintenanceTask] = [
        .freeRam,
        .purgeableSpace,
        .flushDns,
        .speedUpMail,
        .rebuildSpotlight,
        .repairPermissions,
        .timeMachine
    ]

    var body: some View {
        ZStack {
            switch screen {
            case .intro:
                introView
            case .details:
                detailsView
            case .running:
                runningView
            case .complete:
                completeView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $service.showConfirmDialog) {
            MaintenanceConfirmDialog(service: service, loc: loc)
        }
    }

    private var introView: some View {
        HStack(spacing: 23) {
            ZStack(alignment: .topLeading) {
                Text(localized("维护", "Maintenance"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .offset(y: 0)

                Text(localized("运行一组可快速优化系统性能的脚本。", "Run scripts that quickly optimize system performance."))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.79))
                    .offset(y: 40)

                introBenefit(
                    asset: "maintenance_benefit_drive",
                    title: localized("提高驱动器性能", "Improve drive performance"),
                    detail: localized("保护磁盘，确保其文件系统和物理状态良好。", "Protect disks and keep their file systems healthy.")
                )
                .offset(y: 95)

                introBenefit(
                    asset: "maintenance_benefit_apps",
                    title: localized("消除应用程序错误", "Eliminate application errors"),
                    detail: localized("通过修改权限以及运行维护脚本解决不适当的应用程序行为。", "Repair permissions and run maintenance scripts."))
                .offset(y: 190)

                introBenefit(
                    asset: "maintenance_benefit_search",
                    title: localized("提高搜索性能", "Improve search performance"),
                    detail: localized("为您的“聚焦”数据库重新建立索引，提高搜索速度和质量。", "Reindex Spotlight to improve search speed and quality."))
                .offset(y: 286)

                Button {
                    screen = .details
                } label: {
                    Text(localized("查看 \(MaintenanceTask.allCases.count) 个任务…", "View \(MaintenanceTask.allCases.count) Tasks…"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.08, green: 0.15, blue: 0.22))
                        .padding(.horizontal, 15)
                        .frame(height: 30)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.48, green: 0.93, blue: 0.98), Color(red: 0.27, green: 0.78, blue: 0.98)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                }
                .buttonStyle(MaintenanceCompactButtonStyle())
                .offset(y: 379)
            }
            .frame(width: 337, height: 410, alignment: .topLeading)

            replicaAsset("maintenance_module")
                .frame(width: 315, height: 315)
                .scaleEffect(x: 1.074, y: 1.083)
                .offset(x: 11, y: 7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(x: -4, y: -23)
    }

    private func introBenefit(asset: String, title: String, detail: String) -> some View {
        HStack(spacing: 20) {
            replicaAsset(asset)
                .frame(width: 40, height: 40)
                .opacity(0.48)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(2)
            }
        }
    }

    private var detailsView: some View {
        CleanMyMacThreeColumnLayout(categoryWidth: 377) {
            taskListPanel
        } detail: {
            taskDetailsPanel
        } bottomOverlay: {
            orbButton(
                title: localized("运行", "Run"),
                disabled: service.selectedTasks.isEmpty
            ) {
                screen = .running
                Task {
                    await service.runSelectedTasks()
                    screen = service.runWasCancelled ? .details : .complete
                }
            }
        }
    }

    private var taskListPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                screen = .intro
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                    Text(localized("简介", "Intro"))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
            .padding(.leading, 14)
            .padding(.top, 19)
            .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(originalTasks) { task in
                        taskRow(task)
                    }

                    HStack(spacing: 7) {
                        Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
                        Text(localized("增强", "EXTRA"))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.35))
                        Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 4)

                    taskRow(.repairApps, isAdditional: true)
                }
                .padding(.leading, 10)
                .padding(.trailing, 1)
                .padding(.top, 5)
                .padding(.bottom, 110)
            }
        }
    }

    private func taskRow(_ task: MaintenanceTask, isAdditional: Bool = false) -> some View {
        Button {
            service.selectedTask = task
            if service.selectedTasks.contains(task) {
                service.selectedTasks.remove(task)
            } else {
                service.selectedTasks.insert(task)
            }
        } label: {
            HStack(spacing: 10) {
                replicaCheckBox(selected: service.selectedTasks.contains(task))

                replicaAsset(taskAsset(task))
                    .frame(width: 40, height: 40)

                Text(localizedTaskTitle(task))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.84))
                    .lineLimit(1)

                Spacer(minLength: 4)

                if isAdditional {
                    Text(localized("新增", "NEW"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.cyan.opacity(0.76))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(service.selectedTask == task ? Color.black.opacity(0.13) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(MaintenanceCategoryButtonStyle())
    }

    private var taskDetailsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(localized("维护", "Maintenance"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.56))
                Spacer()
            }
            .padding(.top, 20)

            Text(localizedTaskTitle(service.selectedTask))
                .font(.system(size: 23, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 31)

            Text(localizedTaskDescription(service.selectedTask))
                .font(.system(size: 11.5))
                .foregroundColor(.white.opacity(0.80))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)

            Text(localized("使用推荐：", "Recommended use:"))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.54))
                .padding(.top, 48)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(localizedRecommendations(service.selectedTask), id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text(recommendation)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.72))
                }
            }
            .padding(.top, 8)

            Spacer()

            Text(
                localized(
                    "上次运行日期： \(service.getLastRunDate(for: service.selectedTask, chinese: true))",
                    "Last run: \(service.getLastRunDate(for: service.selectedTask, chinese: false))"
                )
            )
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.68))
            .padding(.bottom, 108)
        }
        .padding(.horizontal, 38)
    }

    private var runningView: some View {
        VStack(spacing: 19) {
            Spacer()

            Text(localized("正在执行维护任务…", "Running maintenance tasks…"))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 7) {
                ForEach(Array(service.selectedTasks).sorted(by: { $0.rawValue < $1.rawValue })) { task in
                    HStack(spacing: 12) {
                        replicaAsset(taskAsset(task)).frame(width: 35, height: 35)
                        Text(localizedTaskTitle(task))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.82))
                        Spacer()
                        if let result = service.taskResults.first(where: { $0.task == task }) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.success ? .cyan : .orange)
                        } else if service.currentRunningTask == task {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.65)
                        } else {
                            Circle().stroke(Color.white.opacity(0.24), lineWidth: 1).frame(width: 14, height: 14)
                        }
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 48)
                    .background(Color.black.opacity(service.currentRunningTask == task ? 0.13 : 0.04), in: RoundedRectangle(cornerRadius: 9))
                }
            }
            .frame(width: 390)

            Text("\(service.completedTasks.count) / \(service.selectedTasks.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.54))

            Spacer()

            orbButton(title: localized("停止", "Stop"), disabled: false) {
                service.stopRunningTasks()
            }
            .padding(.bottom, 23)
        }
    }

    private var completeView: some View {
        VStack(spacing: 17) {
            Spacer()
            ZStack {
                Circle().fill(Color.cyan.opacity(0.14)).frame(width: 108, height: 108).blur(radius: 10)
                Circle().stroke(Color.cyan.opacity(0.68), lineWidth: 2).frame(width: 76, height: 76)
                Image(systemName: service.completedTasks.isEmpty ? "xmark" : "checkmark")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(service.completedTasks.isEmpty ? localized("没有完成任何任务", "No Tasks Completed") : localized("完成", "Complete"))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text(service.completedTasks.isEmpty
                 ? localized("查看任务日志以了解失败原因。", "Review the task log for failure details.")
                 : localized("您的 Mac 现在运行起来应该更加顺畅。", "Your Mac should now run more smoothly."))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.64))

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(service.taskResults, id: \.task.rawValue) { result in
                        HStack(spacing: 11) {
                            replicaAsset(taskAsset(result.task)).frame(width: 31, height: 31)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(localizedTaskTitle(result.task))
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.84))
                                Text(result.message)
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.white.opacity(0.50))
                            }
                            Spacer()
                            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(result.success ? .cyan : .orange)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 47)
                        .background(Color.black.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(width: 430, height: min(CGFloat(service.taskResults.count) * 53, 190))

            Spacer()

            Button {
                service.completedTasks.removeAll()
                service.taskResults.removeAll()
                service.selectedTasks.removeAll()
                screen = .details
            } label: {
                Text(localized("完成", "Done"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .frame(height: 34)
                    .background(Color.white.opacity(0.14), in: Capsule())
            }
            .buttonStyle(MaintenanceCompactButtonStyle())
            .padding(.bottom, 34)
        }
    }

    private func replicaCheckBox(selected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(selected ? Color.cyan.opacity(0.92) : Color.white.opacity(0.44), lineWidth: 1.4)
                .frame(width: 15, height: 15)
            if selected {
                Circle().fill(Color.cyan.opacity(0.92)).frame(width: 15, height: 15)
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(Color(red: 0.18, green: 0.28, blue: 0.42))
            }
        }
    }

    private func orbButton(title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CleanMyMacActionOrb(
                title: title,
                gradient: LinearGradient(
                    colors: disabled
                        ? [Color.white.opacity(0.09), Color.white.opacity(0.035)]
                        : [Color(red: 0.58, green: 0.67, blue: 0.93), Color(red: 0.37, green: 0.25, blue: 0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                glowColor: .cyan,
                ringColor: Color.white.opacity(0.40),
                disabled: disabled,
                isHovered: orbHovered
            )
        }
        .buttonStyle(MaintenanceOrbButtonStyle())
        .disabled(disabled)
        .onHover { orbHovered = $0 }
    }

    private func localizedTaskTitle(_ task: MaintenanceTask) -> String {
        loc.currentLanguage == .chinese ? task.title : task.englishTitle
    }

    private func localizedTaskDescription(_ task: MaintenanceTask) -> String {
        loc.currentLanguage == .chinese ? task.description : task.englishDescription
    }

    private func localizedRecommendations(_ task: MaintenanceTask) -> [String] {
        loc.currentLanguage == .chinese ? task.recommendations : task.englishRecommendations
    }

    private func taskAsset(_ task: MaintenanceTask) -> String {
        switch task {
        case .freeRam: return "maintenance_free_ram"
        case .purgeableSpace: return "maintenance_purgeable"
        case .flushDns: return "maintenance_dns"
        case .speedUpMail: return "maintenance_mail"
        case .rebuildSpotlight: return "maintenance_spotlight"
        case .repairPermissions: return "maintenance_permissions"
        case .repairApps: return "maintenance_repair_apps"
        case .timeMachine: return "maintenance_time_machine"
        }
    }

    private func replicaAsset(_ name: String) -> some View {
        Group {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
            }
        }
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        loc.text(chinese, english)
    }
}

private struct MaintenanceCompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

private struct MaintenanceCategoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.76 : 1)
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct MaintenanceOrbButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

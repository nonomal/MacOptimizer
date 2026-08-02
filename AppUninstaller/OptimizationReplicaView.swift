import SwiftUI
import AppKit

/// CleanMyMac-style shell backed by the existing OptimizerService. The first
/// three tasks mirror the installed reference; the company's four additional
/// optimization tasks remain available below them.
struct OptimizationReplicaView: View {
    @ObservedObject private var service = OptimizerService.shared
    @ObservedObject private var loc = LocalizationManager.shared

    @State private var screen: Screen = .intro
    @State private var searchText = ""
    @State private var showAdditionalTasks = false
    @State private var orbHovered = false

    private enum Screen {
        case intro
        case details
        case running
        case complete
    }

    private let referenceTasks: [OptimizerTask] = [.heavyConsumers, .launchAgents, .hungApps]
    private let additionalTasks: [OptimizerTask] = [.networkOptimize, .bootOptimize, .memoryOptimize, .appAccelerate]

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
        .onAppear {
            service.scan()
        }
        .sheet(isPresented: $service.showMemoryConfirmAlert) {
            MemoryConfirmationDialog(service: service, loc: loc)
        }
        .sheet(isPresented: $service.showBootConfirmAlert) {
            BootOptimizationDialog(service: service, loc: loc)
        }
    }

    private var introView: some View {
        GeometryReader { geometry in
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(localized("优化", "Optimization"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text(localized("通过管理正在运行的应用来提升 Mac 性能。", "透過管理正在執行的應用程式來提升 Mac 效能。", "Improve Mac performance by controlling running applications.", "実行中のアプリを管理してMacのパフォーマンスを向上させます。", "실행 중인 앱을 관리하여 Mac 성능을 향상합니다.", "Повысьте производительность Mac, управляя запущенными приложениями."))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.80))
                        .padding(.top, 8)

                    introBenefit(
                        asset: "optimization_benefit_launch",
                        title: localized("管理应用启动代理", "管理應用程式啟動代理", "Manage application launch agents", "アプリの起動エージェントを管理", "앱 시작 에이전트 관리", "Управление агентами запуска"),
                        detail: localized("管理 Mac 上的应用辅助程序。", "管理 Mac 上的應用程式輔助程式。", "Control the helper apps on your Mac.", "Mac上のアプリ補助プログラムを管理します。", "Mac의 앱 도우미 프로그램을 관리합니다.", "Управляйте вспомогательными программами на Mac.")
                    )
                    .padding(.top, 41)

                    introBenefit(
                        asset: "optimization_benefit_running",
                        title: localized("控制正在运行的应用", "控制正在執行的應用程式", "Control running applications", "実行中のアプリを管理", "실행 중인 앱 관리", "Управление запущенными приложениями"),
                        detail: localized("管理登录项，只运行真正需要的内容。", "管理登入項目，只執行真正需要的內容。", "Manage login items and run only what you need.", "ログイン項目を管理し、必要なものだけを実行します。", "로그인 항목을 관리하고 필요한 항목만 실행합니다.", "Управляйте объектами входа и запускайте только необходимое.")
                    )
                    .padding(.top, 56)

                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            screen = .details
                        }
                    } label: {
                        Text(localized("查看项目", "View Items"))
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
                    .buttonStyle(OptimizationCompactButtonStyle())
                    .padding(.top, 52)
                }
                .frame(width: 346, alignment: .leading)

                replicaAsset("optimization_module")
                    .frame(width: 339, height: 339)
                    .offset(x: -4, y: 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(x: 9, y: -24)
        }
    }

    private func introBenefit(asset: String, title: String, detail: String) -> some View {
        HStack(spacing: 16) {
            replicaAsset(asset)
                .frame(width: 40, height: 40)
                .opacity(0.48)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.56))
            }
        }
    }

    private var detailsView: some View {
        CleanMyMacThreeColumnLayout(categoryWidth: 398) {
            taskPanel
        } detail: {
            detailPanel
        } bottomOverlay: {
            CleanMyMacBottomActionCluster {
                orbButton(title: actionTitle, disabled: selectedCount == 0) {
                    screen = .running
                    Task {
                        await service.executeAllSelectedTasks()
                        if service.executionWasCancelled {
                            screen = .details
                        } else {
                            screen = .complete
                        }
                    }
                }
            } accessory: {
                if selectedCount > 0 {
                    Text(selectedCountLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                }
            }
        }
    }

    private var taskPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { screen = .intro }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                    Text(localized("返回", "Back"))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
            .padding(.leading, 14)
            .padding(.top, 19)

            HStack(spacing: 3) {
                Spacer()
                Text(localized("排序方式按 名称", "Sort by Name"))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.43))
            .padding(.trailing, 12)
            .padding(.top, 27)
            .padding(.bottom, 10)

            VStack(spacing: 4) {
                ForEach(referenceTasks) { task in
                    categoryRow(task)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showAdditionalTasks.toggle()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: showAdditionalTasks ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                        Text(localized("更多优化功能", "更多最佳化功能", "Additional optimization", "その他の最適化", "추가 최적화", "Дополнительная оптимизация"))
                            .font(.system(size: 10, weight: .medium))
                        Spacer()
                        Text("4")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.42))
                    .padding(.horizontal, 17)
                    .frame(height: 28)
                }
                .buttonStyle(.plain)

                if showAdditionalTasks {
                    ForEach(additionalTasks) { task in
                        categoryRow(task, compact: true)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 10)

            Spacer()
        }
    }

    private func categoryRow(_ task: OptimizerTask, compact: Bool = false) -> some View {
        let state = selectionState(for: task)

        return Button {
            toggleCategory(task)
        } label: {
            HStack(spacing: 12) {
                optimizationCheckBox(state: state)

                taskIcon(task)
                    .frame(width: compact ? 34 : 40, height: compact ? 34 : 40)

                Text(task.title(for: loc.currentLanguage))
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
                    .foregroundColor(.white.opacity(taskHasItems(task) || task.isOneClickOptimize ? 0.82 : 0.28))
                    .lineLimit(1)

                Spacer(minLength: 4)

                if selectedItemCount(for: task) > 0 {
                    Text(localized("\(selectedItemCount(for: task)) 项", "\(selectedItemCount(for: task)) 個項目", "\(selectedItemCount(for: task)) items", "\(selectedItemCount(for: task))項目", "\(selectedItemCount(for: task))개 항목", "Элементов: \(selectedItemCount(for: task))"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.78))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: compact ? 45 : 55)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(service.selectedTask == task ? Color.black.opacity(0.13) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(OptimizationCategoryButtonStyle())
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(localized("优化", "Optimization"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.58))
                Spacer()
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                    TextField(localized("搜索", "Search"), text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.78))
                }
                .padding(.horizontal, 10)
                .frame(width: 200, height: 30)
                .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Text(service.selectedTask.title(for: loc.currentLanguage))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Text(service.selectedTask.description(for: loc.currentLanguage))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.78))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.top, 5)

            HStack(spacing: 3) {
                Spacer()
                Text(localized("排序方式按 名称", "Sort by Name"))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.43))
            .padding(.trailing, 18)
            .padding(.top, 25)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    taskDetailRows
                }
                .padding(.horizontal, 20)
                .padding(.top, 9)
                .padding(.bottom, 130)
            }
        }
    }

    @ViewBuilder
    private var taskDetailRows: some View {
        switch service.selectedTask {
        case .heavyConsumers:
            if filteredHeavyProcesses.isEmpty {
                emptyTaskLabel(localized("未发现高资源占用应用", "未發現高資源佔用應用程式", "No heavy-consuming applications found", "高負荷のアプリは見つかりませんでした", "리소스를 과도하게 사용하는 앱이 없습니다", "Ресурсоёмкие приложения не найдены"))
            } else {
                ForEach(filteredHeavyProcesses) { process in
                    processRow(process, source: .heavyConsumers)
                }
            }
        case .launchAgents:
            if filteredLaunchAgents.isEmpty {
                emptyTaskLabel(localized("未发现启动代理", "未發現啟動代理程式", "No launch agents found", "起動エージェントは見つかりませんでした", "시작 에이전트가 없습니다", "Агенты запуска не найдены"))
            } else {
                ForEach(filteredLaunchAgents) { agent in
                    launchAgentRow(agent)
                }
            }
        case .hungApps:
            if filteredHungApps.isEmpty {
                emptyTaskLabel(localized("未发现无响应的应用", "未發現無回應的應用程式", "No hung applications found", "応答しないアプリは見つかりませんでした", "응답하지 않는 앱이 없습니다", "Зависшие приложения не найдены"))
            } else {
                ForEach(filteredHungApps) { process in
                    processRow(process, source: .hungApps)
                }
            }
        default:
            VStack(spacing: 15) {
                Image(systemName: service.selectedTask.icon)
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(.white.opacity(0.70))
                Text(localized("选择左侧任务，然后点击底部的“执行”。", "選擇左側工作，然後按一下底部的「執行」。", "Select this task, then click Run at the bottom.", "左側のタスクを選択し、下部の「実行」をクリックしてください。", "왼쪽에서 작업을 선택한 후 하단의 실행을 클릭하세요.", "Выберите задачу слева и нажмите «Запустить» внизу."))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.56))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 38)
        }
    }

    private func processRow(_ process: OptimizerProcessItem, source: OptimizerTask) -> some View {
        Button {
            if source == .heavyConsumers,
               let index = service.heavyProcesses.firstIndex(where: { $0.id == process.id }) {
                service.heavyProcesses[index].isSelected.toggle()
            } else if source == .hungApps,
                      let index = service.hungApps.firstIndex(where: { $0.id == process.id }) {
                service.hungApps[index].isSelected.toggle()
            }
            syncTaskSelection(source)
        } label: {
            HStack(spacing: 13) {
                optimizationCheckBox(state: process.isSelected ? .all : .none)
                Image(nsImage: process.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                Text(process.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.84))
                Spacer()
                Text(process.usageDescription)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.46))
            }
            .frame(height: 45)
            .contentShape(Rectangle())
        }
        .buttonStyle(OptimizationRowButtonStyle())
    }

    private func launchAgentRow(_ agent: LaunchAgentItem) -> some View {
        Button {
            if let index = service.launchAgents.firstIndex(where: { $0.id == agent.id }) {
                service.launchAgents[index].isSelected.toggle()
            }
            syncTaskSelection(.launchAgents)
        } label: {
            HStack(spacing: 13) {
                optimizationCheckBox(state: agent.isSelected ? .all : .none)
                Image(nsImage: agent.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.84))
                        .lineLimit(1)
                    Text(agent.label)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.40))
                        .lineLimit(1)
                }
                Spacer()
            }
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(OptimizationRowButtonStyle())
    }

    private func emptyTaskLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.30))
            .frame(maxWidth: .infinity)
            .padding(.top, 34)
    }

    private var runningView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(localized("正在执行优化任务…", "正在執行最佳化工作…", "Running optimization tasks…", "最適化タスクを実行中…", "최적화 작업 실행 중…", "Выполнение задач оптимизации…"))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 8) {
                ForEach(Array(service.selectedTasks).sorted(by: { $0.rawValue < $1.rawValue })) { task in
                    HStack(spacing: 12) {
                        taskIcon(task).frame(width: 34, height: 34)
                        Text(task.title(for: loc.currentLanguage))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.82))
                        Spacer()
                        if service.completedTasks.contains(task) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.cyan)
                        } else if service.executingTask == task {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.65)
                        } else {
                            Circle().stroke(Color.white.opacity(0.24), lineWidth: 1).frame(width: 14, height: 14)
                        }
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 48)
                    .background(Color.black.opacity(service.executingTask == task ? 0.13 : 0.04), in: RoundedRectangle(cornerRadius: 9))
                }
            }
            .frame(width: 380)

            Text("\(service.completedTasks.count) / \(service.selectedTasks.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.54))

            Spacer()

            orbButton(title: localized("停止", "Stop"), disabled: false) {
                service.cancelExecution()
            }
            .padding(.bottom, 22)
        }
    }

    private var completeView: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(Color.cyan.opacity(0.14)).frame(width: 108, height: 108).blur(radius: 10)
                Circle().stroke(Color.cyan.opacity(0.70), lineWidth: 2).frame(width: 76, height: 76)
                Image(systemName: "checkmark").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
            }
            Text(localized("优化完成", "最佳化完成", "Optimization Complete", "最適化完了", "최적화 완료", "Оптимизация завершена"))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            Text(localized("已完成 \(service.completedTasks.count) 项优化任务。", "已完成 \(service.completedTasks.count) 項最佳化工作。", "Completed \(service.completedTasks.count) optimization tasks.", "\(service.completedTasks.count)件の最適化タスクを完了しました。", "최적화 작업 \(service.completedTasks.count)개를 완료했습니다.", "Завершено задач оптимизации: \(service.completedTasks.count)."))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.62))
            Spacer()
            Button {
                service.showResults = false
                service.completedTasks.removeAll()
                clearSelections()
                screen = .details
                service.scan()
            } label: {
                Text(localized("完成", "Done"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .frame(height: 34)
                    .background(Color.white.opacity(0.14), in: Capsule())
            }
            .buttonStyle(OptimizationCompactButtonStyle())
            .padding(.bottom, 36)
        }
    }

    private enum CheckState {
        case none
        case some
        case all
    }

    private func optimizationCheckBox(state: CheckState) -> some View {
        ZStack {
            Circle()
                .stroke(state == .none ? Color.white.opacity(0.44) : Color.cyan.opacity(0.92), lineWidth: 1.4)
                .frame(width: 15, height: 15)
            if state != .none {
                Circle().fill(Color.cyan.opacity(0.92)).frame(width: 15, height: 15)
                Image(systemName: state == .some ? "minus" : "checkmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(Color(red: 0.18, green: 0.28, blue: 0.42))
            }
        }
    }

    private func taskIcon(_ task: OptimizerTask) -> some View {
        Group {
            if let asset = referenceAsset(for: task) {
                replicaAsset(asset)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.16))
                    Image(systemName: task.icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.82))
                }
            }
        }
    }

    private func referenceAsset(for task: OptimizerTask) -> String? {
        switch task {
        case .heavyConsumers: return "optimization_high_consuming"
        case .launchAgents: return "optimization_launch_agents"
        case .hungApps: return "optimization_hung_apps"
        default: return nil
        }
    }

    private func selectionState(for task: OptimizerTask) -> CheckState {
        if task.isOneClickOptimize {
            return service.selectedTasks.contains(task) ? .all : .none
        }

        let values: [Bool]
        switch task {
        case .heavyConsumers: values = service.heavyProcesses.map(\.isSelected)
        case .launchAgents: values = service.launchAgents.map(\.isSelected)
        case .hungApps: values = service.hungApps.map(\.isSelected)
        default: values = []
        }

        guard !values.isEmpty else { return .none }
        if values.allSatisfy({ $0 }) { return .all }
        if values.contains(true) { return .some }
        return .none
    }

    private func toggleCategory(_ task: OptimizerTask) {
        service.selectedTask = task
        let shouldSelect = selectionState(for: task) != .all

        switch task {
        case .heavyConsumers:
            for index in service.heavyProcesses.indices { service.heavyProcesses[index].isSelected = shouldSelect }
        case .launchAgents:
            for index in service.launchAgents.indices { service.launchAgents[index].isSelected = shouldSelect }
        case .hungApps:
            for index in service.hungApps.indices { service.hungApps[index].isSelected = shouldSelect }
        default:
            break
        }

        if shouldSelect && (task.isOneClickOptimize || taskHasItems(task)) {
            service.selectedTasks.insert(task)
        } else {
            service.selectedTasks.remove(task)
        }
    }

    private func syncTaskSelection(_ task: OptimizerTask) {
        if selectedItemCount(for: task) > 0 {
            service.selectedTasks.insert(task)
        } else {
            service.selectedTasks.remove(task)
        }
    }

    private func taskHasItems(_ task: OptimizerTask) -> Bool {
        switch task {
        case .heavyConsumers: return !service.heavyProcesses.isEmpty
        case .launchAgents: return !service.launchAgents.isEmpty
        case .hungApps: return !service.hungApps.isEmpty
        default: return true
        }
    }

    private func selectedItemCount(for task: OptimizerTask) -> Int {
        switch task {
        case .heavyConsumers: return service.heavyProcesses.filter(\.isSelected).count
        case .launchAgents: return service.launchAgents.filter(\.isSelected).count
        case .hungApps: return service.hungApps.filter(\.isSelected).count
        default: return service.selectedTasks.contains(task) ? 1 : 0
        }
    }

    private var selectedCount: Int {
        OptimizerTask.allCases.reduce(0) { $0 + selectedItemCount(for: $1) }
    }

    private var selectedCountLabel: String {
        if service.selectedTasks == [.heavyConsumers] {
            return localized("\(selectedItemCount(for: .heavyConsumers)) 个应用", "\(selectedItemCount(for: .heavyConsumers)) 個應用程式", "\(selectedItemCount(for: .heavyConsumers)) applications", "\(selectedItemCount(for: .heavyConsumers))個のアプリ", "앱 \(selectedItemCount(for: .heavyConsumers))개", "Приложений: \(selectedItemCount(for: .heavyConsumers))")
        }
        return localized("已选择 \(selectedCount) 项", "已選擇 \(selectedCount) 個項目", "\(selectedCount) selected", "\(selectedCount)項目を選択", "\(selectedCount)개 선택됨", "Выбрано: \(selectedCount)")
    }

    private var actionTitle: String {
        guard service.selectedTasks.count == 1, let task = service.selectedTasks.first else {
            return localized("执行", "Run")
        }
        switch task {
        case .heavyConsumers: return localized("退出", "結束", "Quit", "終了", "종료", "Завершить")
        case .launchAgents: return localized("移除", "Remove")
        case .hungApps: return localized("重新启动", "重新啟動", "Relaunch", "再起動", "다시 실행", "Перезапустить")
        default: return localized("执行", "Run")
        }
    }

    private func clearSelections() {
        service.selectedTasks.removeAll()
        for index in service.heavyProcesses.indices { service.heavyProcesses[index].isSelected = false }
        for index in service.launchAgents.indices { service.launchAgents[index].isSelected = false }
        for index in service.hungApps.indices { service.hungApps[index].isSelected = false }
    }

    private var filteredHeavyProcesses: [OptimizerProcessItem] {
        filtered(service.heavyProcesses, name: \.name)
    }

    private var filteredHungApps: [OptimizerProcessItem] {
        filtered(service.hungApps, name: \.name)
    }

    private var filteredLaunchAgents: [LaunchAgentItem] {
        filtered(service.launchAgents, name: \.name)
    }

    private func filtered<T>(_ items: [T], name: KeyPath<T, String>) -> [T] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0[keyPath: name].localizedCaseInsensitiveContains(searchText) }
    }

    private func orbButton(title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CleanMyMacActionOrb(
                title: title,
                gradient: LinearGradient(
                    colors: disabled
                        ? [Color.white.opacity(0.09), Color.white.opacity(0.035)]
                        : [Color(red: 0.54, green: 0.68, blue: 0.95), Color(red: 0.34, green: 0.25, blue: 0.66)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                glowColor: .cyan,
                ringColor: Color.white.opacity(0.40),
                disabled: disabled,
                isHovered: orbHovered
            )
        }
        .buttonStyle(OptimizationOrbButtonStyle())
        .disabled(disabled)
        .onHover { orbHovered = $0 }
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

    private func localized(_ simplifiedChinese: String, _ traditionalChinese: String, _ english: String, _ japanese: String, _ korean: String, _ russian: String) -> String {
        loc.text(simplifiedChinese: simplifiedChinese, traditionalChinese: traditionalChinese, english: english, japanese: japanese, korean: korean, russian: russian)
    }
}

private struct OptimizationCompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

private struct OptimizationRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.black.opacity(configuration.isPressed ? 0.10 : 0), in: RoundedRectangle(cornerRadius: 7))
            .opacity(configuration.isPressed ? 0.76 : 1)
    }
}

private struct OptimizationCategoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.76 : 1)
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct OptimizationOrbButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

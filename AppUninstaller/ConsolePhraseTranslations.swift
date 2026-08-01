import Foundation

/// Curated translations for the new console and shared application chrome.
/// Keys are the canonical English copy used by `LocalizationManager.text`.
enum ConsolePhraseTranslations {
    static let values: [String: [AppLanguage: String]] = [
        "Console": [.japanese: "コンソール", .korean: "콘솔", .russian: "Консоль"],
        "Monitor": [.japanese: "コンソール", .korean: "콘솔", .russian: "Консоль"],
        "Overview": [.japanese: "概要", .korean: "개요", .russian: "Обзор"],
        "Applications": [.japanese: "アプリケーション", .korean: "애플리케이션", .russian: "Приложения"],
        "App Manager": [.japanese: "アプリ管理", .korean: "앱 관리", .russian: "Управление приложениями"],
        "Processes": [.japanese: "プロセス", .korean: "프로세스", .russian: "Процессы"],
        "Process Manager": [.japanese: "プロセス管理", .korean: "프로세스 관리", .russian: "Управление процессами"],
        "Network": [.japanese: "ネットワーク診断", .korean: "네트워크 진단", .russian: "Диагностика сети"],
        "Network Diagnostics": [.japanese: "ネットワーク診断", .korean: "네트워크 진단", .russian: "Диагностика сети"],
        "Ports": [.japanese: "ポート", .korean: "포트", .russian: "Порты"],
        "Port Manager": [.japanese: "ポート管理", .korean: "포트 관리", .russian: "Управление портами"],
        "Safety Center": [.japanese: "セキュリティセンター", .korean: "보안 센터", .russian: "Центр безопасности"],
        "System Overview": [.japanese: "システム概要", .korean: "시스템 개요", .russian: "Обзор системы"],
        "Memory": [.japanese: "メモリ", .korean: "메모리", .russian: "Память"],
        "Memory Usage": [.japanese: "メモリ使用量", .korean: "메모리 사용량", .russian: "Использование памяти"],
        "CPU Usage": [.japanese: "CPU 使用率", .korean: "CPU 사용량", .russian: "Загрузка CPU"],
        "Download": [.japanese: "ダウンロード", .korean: "다운로드", .russian: "Загрузка"],
        "Upload": [.japanese: "アップロード", .korean: "업로드", .russian: "Отправка"],
        "Downloaded": [.japanese: "受信合計", .korean: "총 다운로드", .russian: "Загружено"],
        "Uploaded": [.japanese: "送信合計", .korean: "총 업로드", .russian: "Отправлено"],
        "Current speed": [.japanese: "現在の速度", .korean: "현재 속도", .russian: "Текущая скорость"],
        "System load": [.japanese: "システム負荷", .korean: "시스템 부하", .russian: "Нагрузка системы"],
        "Live · 2 sec": [.japanese: "2 秒ごとに更新", .korean: "2초마다 업데이트", .russian: "Обновление каждые 2 с"],
        "Foreground applications": [.japanese: "実行中のアプリ", .korean: "실행 중인 앱", .russian: "Запущенные приложения"],
        "Sorted by current processor use": [.japanese: "現在の CPU 使用率順", .korean: "현재 CPU 사용량순", .russian: "По текущей загрузке CPU"],
        "Network Traffic": [.japanese: "ネットワーク通信量", .korean: "네트워크 트래픽", .russian: "Сетевой трафик"],
        "Details": [.japanese: "詳細", .korean: "상세 정보", .russian: "Подробнее"],
        "View": [.japanese: "表示", .korean: "보기", .russian: "Открыть"],
        "Application Details": [.japanese: "アプリの詳細", .korean: "앱 상세 정보", .russian: "Сведения о приложении"],
        "Process Details": [.japanese: "プロセスの詳細", .korean: "프로세스 상세 정보", .russian: "Сведения о процессе"],
        "Port Details": [.japanese: "ポートの詳細", .korean: "포트 상세 정보", .russian: "Сведения о порте"],
        "Developer": [.japanese: "開発元", .korean: "개발자", .russian: "Разработчик"],
        "Source": [.japanese: "入手元", .korean: "출처", .russian: "Источник"],
        "Size": [.japanese: "サイズ", .korean: "크기", .russian: "Размер"],
        "Status": [.japanese: "状態", .korean: "상태", .russian: "Состояние"],
        "State": [.japanese: "状態", .korean: "상태", .russian: "Состояние"],
        "User": [.japanese: "ユーザー", .korean: "사용자", .russian: "Пользователь"],
        "Type": [.japanese: "種類", .korean: "유형", .russian: "Тип"],
        "Path": [.japanese: "パス", .korean: "경로", .russian: "Путь"],
        "Protocol": [.japanese: "プロトコル", .korean: "프로토콜", .russian: "Протокол"],
        "Address": [.japanese: "アドレス", .korean: "주소", .russian: "Адрес"],
        "Running": [.japanese: "実行中", .korean: "실행 중", .russian: "Запущено"],
        "Active": [.japanese: "有効", .korean: "활성", .russian: "Активно"],
        "Stopped": [.japanese: "停止中", .korean: "중지됨", .russian: "Остановлено"],
        "Off": [.japanese: "オフ", .korean: "꺼짐", .russian: "Выкл."],
        "Cancel": [.japanese: "キャンセル", .korean: "취소", .russian: "Отмена"],
        "Force Quit": [.japanese: "強制終了", .korean: "강제 종료", .russian: "Завершить принудительно"],
        "End Process": [.japanese: "プロセスを終了", .korean: "프로세스 종료", .russian: "Завершить процесс"],
        "Show in Finder": [.japanese: "Finder に表示", .korean: "Finder에서 보기", .russian: "Показать в Finder"],
        "Clean App Data": [.japanese: "アプリデータを消去", .korean: "앱 데이터 정리", .russian: "Очистить данные приложения"],
        "Move Data to Trash": [.japanese: "データをゴミ箱に入れる", .korean: "데이터를 휴지통으로 이동", .russian: "Переместить данные в Корзину"],
        "Unknown version": [.japanese: "バージョン不明", .korean: "버전 알 수 없음", .russian: "Версия неизвестна"],
        "Not Connected": [.japanese: "未接続", .korean: "연결되지 않음", .russian: "Не подключено"],
        "Loading installed applications…": [.japanese: "インストール済みアプリを読み込み中…", .korean: "설치된 앱을 불러오는 중…", .russian: "Загрузка приложений…"],
        "Loading processes…": [.japanese: "プロセスを読み込み中…", .korean: "프로세스를 불러오는 중…", .russian: "Загрузка процессов…"],
        "Loading network ports…": [.japanese: "ネットワークポートを読み込み中…", .korean: "네트워크 포트를 불러오는 중…", .russian: "Загрузка сетевых портов…"],
        "No applications found": [.japanese: "アプリが見つかりません", .korean: "앱을 찾을 수 없음", .russian: "Приложения не найдены"],
        "No processes found": [.japanese: "プロセスが見つかりません", .korean: "프로세스를 찾을 수 없음", .russian: "Процессы не найдены"],
        "No ports found": [.japanese: "ポートが見つかりません", .korean: "포트를 찾을 수 없음", .russian: "Порты не найдены"],
        "Try another search": [.japanese: "別の条件で検索してください", .korean: "다른 검색어를 사용해 보세요", .russian: "Попробуйте другой запрос"],
        "Search name, developer or bundle ID": [.japanese: "名前、開発元、Bundle ID を検索", .korean: "이름, 개발자 또는 Bundle ID 검색", .russian: "Поиск по имени, разработчику или Bundle ID"],
        "Search name, PID or user": [.japanese: "名前、PID、ユーザーを検索", .korean: "이름, PID 또는 사용자 검색", .russian: "Поиск по имени, PID или пользователю"],
        "Search process, port, PID or address": [.japanese: "プロセス、ポート、PID、アドレスを検索", .korean: "프로세스, 포트, PID 또는 주소 검색", .russian: "Поиск процесса, порта, PID или адреса"],
        "Listening only": [.japanese: "待受のみ", .korean: "수신 대기만", .russian: "Только прослушивание"],
        "Default route": [.japanese: "デフォルトルート", .korean: "기본 경로", .russian: "Маршрут по умолчанию"],
        "DNS resolution": [.japanese: "DNS 解決", .korean: "DNS 확인", .russian: "Разрешение DNS"],
        "Connection checks": [.japanese: "接続診断", .korean: "연결 진단", .russian: "Проверка соединения"],
        "Run Again": [.japanese: "再診断", .korean: "다시 진단", .russian: "Проверить снова"],
        "Running diagnostics…": [.japanese: "診断中…", .korean: "진단 중…", .russian: "Выполняется диагностика…"],
        "Monitoring": [.japanese: "監視時間", .korean: "모니터링", .russian: "Мониторинг"],
        "Downloads": [.japanese: "ダウンロード監視", .korean: "다운로드 감시", .russian: "Загрузки"],
        "Browser Blocking": [.japanese: "ブラウザブロック", .korean: "브라우저 차단", .russian: "Блокировка в браузере"],
        "Threats": [.japanese: "脅威", .korean: "위협", .russian: "Угрозы"],
        "Threat History": [.japanese: "脅威の履歴", .korean: "위협 기록", .russian: "История угроз"],
        "Download Details": [.japanese: "ダウンロード監視の詳細", .korean: "다운로드 감시 상세", .russian: "Сведения о загрузках"],
        "Browser Extension": [.japanese: "ブラウザ拡張機能", .korean: "브라우저 확장 프로그램", .russian: "Расширение браузера"],
        "Browser content blocker not connected": [.japanese: "ブラウザのコンテンツブロッカーが未接続です", .korean: "브라우저 콘텐츠 차단 확장 프로그램이 연결되지 않았습니다", .russian: "Блокировщик содержимого браузера не подключен"],
        "No threats detected": [.japanese: "脅威は検出されていません", .korean: "감지된 위협 없음", .russian: "Угрозы не обнаружены"],
        "Monitored folder": [.japanese: "監視フォルダ", .korean: "감시 폴더", .russian: "Отслеживаемая папка"],
        "Detection": [.japanese: "検出方法", .korean: "감지 방식", .russian: "Метод обнаружения"],
        "Application": [.japanese: "アプリケーション", .korean: "애플리케이션", .russian: "Приложение"],
        "Background process": [.japanese: "バックグラウンドプロセス", .korean: "백그라운드 프로세스", .russian: "Фоновый процесс"],
        "Command path": [.japanese: "コマンドパス", .korean: "명령 경로", .russian: "Путь команды"],
        "Developer distribution": [.japanese: "開発元から配布", .korean: "개발자 배포", .russian: "От разработчика"],
        "Application size": [.japanese: "アプリのサイズ", .korean: "앱 크기", .russian: "Размер приложения"]
        ,"Smart Scan": [.japanese: "スマートスキャン", .korean: "스마트 스캔", .russian: "Умное сканирование"]
        ,"Cleanup": [.japanese: "クリーンアップ", .korean: "정리", .russian: "Очистка"]
        ,"System Junk": [.japanese: "システムジャンク", .korean: "시스템 정크", .russian: "Системный мусор"]
        ,"Mail Attachments": [.japanese: "メールの添付ファイル", .korean: "메일 첨부 파일", .russian: "Почтовые вложения"]
        ,"Trash Bins": [.japanese: "ゴミ箱", .korean: "휴지통", .russian: "Корзины"]
        ,"Deep Clean": [.japanese: "ディープクリーン", .korean: "정밀 정리", .russian: "Глубокая очистка"]
        ,"Protection": [.japanese: "保護", .korean: "보호", .russian: "Защита"]
        ,"Malware Removal": [.japanese: "マルウェア削除", .korean: "악성 소프트웨어 제거", .russian: "Удаление вредоносных программ"]
        ,"Privacy": [.japanese: "プライバシー", .korean: "개인정보 보호", .russian: "Конфиденциальность"]
        ,"Speed": [.japanese: "高速化", .korean: "속도", .russian: "Скорость"]
        ,"Optimization": [.japanese: "最適化", .korean: "최적화", .russian: "Оптимизация"]
        ,"Maintenance": [.japanese: "メンテナンス", .korean: "유지 관리", .russian: "Обслуживание"]
        ,"Uninstaller": [.japanese: "アンインストーラ", .korean: "제거 프로그램", .russian: "Деинсталлятор"]
        ,"Updater": [.japanese: "アップデータ", .korean: "업데이트", .russian: "Обновление"]
        ,"Extensions": [.japanese: "機能拡張", .korean: "확장 프로그램", .russian: "Расширения"]
        ,"Files": [.japanese: "ファイル", .korean: "파일", .russian: "Файлы"]
        ,"Space Lens": [.japanese: "スペースレンズ", .korean: "공간 렌즈", .russian: "Обзор диска"]
        ,"Large & Old Files": [.japanese: "大容量・古いファイル", .korean: "크고 오래된 파일", .russian: "Большие и старые файлы"]
        ,"Shredder": [.japanese: "シュレッダー", .korean: "파일 분쇄기", .russian: "Шредер"]
        ,"File Manager": [.japanese: "ファイル管理", .korean: "파일 관리", .russian: "Файловый менеджер"]
        ,"Assistant": [.japanese: "アシスタント", .korean: "도우미", .russian: "Помощник"]
        ,"Loading…": [.japanese: "読み込み中…", .korean: "불러오는 중…", .russian: "Загрузка…"]
        ,"Cleaning": [.japanese: "クリーニング中", .korean: "정리 중", .russian: "Очистка"]
        ,"Removing": [.japanese: "削除中", .korean: "제거 중", .russian: "Удаление"]
        ,"Safe": [.japanese: "安全", .korean: "안전", .russian: "Безопасно"]
        ,"Checking": [.japanese: "確認中", .korean: "확인 중", .russian: "Проверка"]
        ,"Language": [.japanese: "言語", .korean: "언어", .russian: "Язык"]
        ,"Settings": [.japanese: "設定", .korean: "설정", .russian: "Настройки"]
        ,"Software Update": [.japanese: "ソフトウェアアップデート", .korean: "소프트웨어 업데이트", .russian: "Обновление ПО"]
        ,"Automatically check for updates": [.japanese: "アップデートを自動確認", .korean: "업데이트 자동 확인", .russian: "Автоматически проверять обновления"]
        ,"Check for Updates": [.japanese: "アップデートを確認", .korean: "업데이트 확인", .russian: "Проверить обновления"]
        ,"Bundle ID": [.japanese: "Bundle ID", .korean: "Bundle ID", .russian: "Bundle ID"]
        ,"CPU": [.japanese: "CPU", .korean: "CPU", .russian: "CPU"]
        ,"Process": [.japanese: "プロセス", .korean: "프로세스", .russian: "Процесс"]
        ,"Port": [.japanese: "ポート", .korean: "포트", .russian: "Порт"]
        ,"Application process": [.japanese: "アプリケーションプロセス", .korean: "애플리케이션 프로세스", .russian: "Процесс приложения"]
        ,"Current-user background process": [.japanese: "現在のユーザーのバックグラウンドプロセス", .korean: "현재 사용자의 백그라운드 프로세스", .russian: "Фоновый процесс текущего пользователя"]
        ,"Application data cleaned": [.japanese: "アプリデータを消去しました", .korean: "앱 데이터 정리 완료", .russian: "Данные приложения очищены"]
        ,"Force quit request sent": [.japanese: "強制終了を要求しました", .korean: "강제 종료 요청을 보냈습니다", .russian: "Запрос на завершение отправлен"]
        ,"Installed application details and status": [.japanese: "インストール済みアプリの入手元、サイズ、状態を表示", .korean: "설치된 앱의 출처, 크기 및 상태 보기", .russian: "Источник, размер и состояние установленных приложений"]
        ,"CPU, memory and command paths for current-user processes": [.japanese: "現在のユーザーのプロセス、CPU、メモリ、コマンドパス", .korean: "현재 사용자 프로세스의 CPU, 메모리 및 명령 경로", .russian: "CPU, память и пути команд процессов текущего пользователя"]
        ,"Live listening ports and owning processes": [.japanese: "実際の待受ポートと所有プロセス", .korean: "실제 수신 대기 포트 및 소유 프로세스", .russian: "Активные порты и процессы-владельцы"]
        ,"Live traffic and read-only checks; no settings are changed": [.japanese: "リアルタイム通信量と読み取り専用診断。設定は変更しません", .korean: "실시간 트래픽 및 읽기 전용 진단; 설정은 변경되지 않습니다", .russian: "Трафик и диагностика только для чтения; настройки не изменяются"]
        ,"Download monitoring and security capability status": [.japanese: "ダウンロード監視とセキュリティ機能の状態", .korean: "다운로드 감시 및 보안 기능 상태", .russian: "Мониторинг загрузок и состояние функций безопасности"]
        ,"Last 40 seconds": [.japanese: "直近 40 秒", .korean: "최근 40초", .russian: "Последние 40 секунд"]
        ,"Ports unavailable": [.japanese: "ポートを読み込めません", .korean: "포트를 불러올 수 없음", .russian: "Порты недоступны"]
        ,"Processes unavailable": [.japanese: "プロセスを読み込めません", .korean: "프로세스를 불러올 수 없음", .russian: "Процессы недоступны"]
        ,"Installed applications could not be read": [.japanese: "インストール済みアプリを読み込めませんでした", .korean: "설치된 앱을 읽을 수 없습니다", .russian: "Не удалось прочитать список приложений"]
        ,"No network connections match this filter": [.japanese: "条件に一致するネットワーク接続はありません", .korean: "필터와 일치하는 네트워크 연결이 없습니다", .russian: "Нет соединений, соответствующих фильтру"]
        ,"Read-only checks for default route and DNS resolution": [.japanese: "デフォルトルートと DNS 解決を読み取り専用で確認", .korean: "기본 경로 및 DNS 확인을 읽기 전용으로 검사", .russian: "Проверка маршрута и DNS только для чтения"]
        ,"Download monitoring is on": [.japanese: "ダウンロード監視はオンです", .korean: "다운로드 감시가 켜져 있습니다", .russian: "Мониторинг загрузок включён"]
        ,"Download monitoring is off": [.japanese: "ダウンロード監視はオフです", .korean: "다운로드 감시가 꺼져 있습니다", .russian: "Мониторинг загрузок выключен"]
        ,"Monitors new files in Downloads; browser blocking requires a separate extension": [.japanese: "ダウンロード内の新規ファイルを監視します。ブラウザのブロックには別の拡張機能が必要です", .korean: "다운로드의 새 파일을 감시합니다. 브라우저 차단에는 별도 확장 프로그램이 필요합니다", .russian: "Отслеживает новые файлы в Загрузках; для блокировки в браузере нужно расширение"]
        ,"Scan on new or modified files in Downloads": [.japanese: "ダウンロード内の新規・変更ファイルをスキャン", .korean: "다운로드의 새 파일 또는 수정된 파일 검사", .russian: "Сканирование новых и изменённых файлов в Загрузках"]
        ,"There are no recorded detections": [.japanese: "検出履歴はありません", .korean: "기록된 감지 내역이 없습니다", .russian: "Нет зарегистрированных обнаружений"]
        ,"This version does not generate simulated ad-blocking data. Real statistics require a connected browser extension.": [.japanese: "このバージョンは広告ブロックの模擬データを生成しません。実際の統計にはブラウザ拡張機能の接続が必要です。", .korean: "이 버전은 광고 차단 시뮬레이션 데이터를 생성하지 않습니다. 실제 통계에는 브라우저 확장 프로그램 연결이 필요합니다.", .russian: "Эта версия не создаёт имитацию блокировки рекламы. Для реальной статистики требуется расширение браузера."]
        ,"Clean application data?": [.japanese: "アプリデータを消去しますか？", .korean: "앱 데이터를 정리할까요?", .russian: "Очистить данные приложения?"]
        ,"Force quit this app?": [.japanese: "このアプリを強制終了しますか？", .korean: "이 앱을 강제 종료할까요?", .russian: "Завершить приложение принудительно?"]
        ,"Force quit this process?": [.japanese: "このプロセスを強制終了しますか？", .korean: "이 프로세스를 강제 종료할까요?", .russian: "Завершить процесс принудительно?"]
        ,"End this process?": [.japanese: "このプロセスを終了しますか？", .korean: "이 프로세스를 종료할까요?", .russian: "Завершить этот процесс?"]
        ,"Unsaved work may be lost.": [.japanese: "未保存の内容が失われる可能性があります。", .korean: "저장하지 않은 내용이 손실될 수 있습니다.", .russian: "Несохранённые данные могут быть потеряны."]
        ,"Force quitting may lose unsaved data or interrupt related services.": [.japanese: "強制終了すると未保存のデータが失われ、関連サービスが中断する場合があります。", .korean: "강제 종료하면 저장하지 않은 데이터가 손실되거나 관련 서비스가 중단될 수 있습니다.", .russian: "Принудительное завершение может привести к потере данных или остановке служб."]
        ,"Ending the process also closes its other ports.": [.japanese: "プロセスを終了すると、そのプロセスの他のポートも閉じます。", .korean: "프로세스를 종료하면 해당 프로세스의 다른 포트도 닫힙니다.", .russian: "Завершение процесса также закроет другие принадлежащие ему порты."]
        ,"Caches, logs and preferences will be moved to Trash while the app remains installed. A running app will be force quit first.": [.japanese: "アプリ本体を残し、キャッシュ、ログ、設定をゴミ箱に移動します。実行中のアプリは先に強制終了します。", .korean: "앱은 유지하고 캐시, 로그 및 설정을 휴지통으로 이동합니다. 실행 중인 앱은 먼저 강제 종료됩니다.", .russian: "Кэши, журналы и настройки будут перемещены в Корзину, приложение останется установленным. Запущенное приложение будет завершено."]
        ,"Wi-Fi status": [.japanese: "ネットワーク状態", .korean: "네트워크 상태", .russian: "Состояние сети"]
        ,"Live load, application and network status for this Mac": [.japanese: "この Mac の負荷、アプリ、ネットワーク状態をリアルタイム表示", .korean: "이 Mac의 부하, 앱 및 네트워크 상태를 실시간으로 확인", .russian: "Нагрузка, приложения и сеть этого Mac в реальном времени"]
        ,"Live transfer trend for the last 40 seconds": [.japanese: "直近 40 秒の送受信推移", .korean: "최근 40초간 실시간 송수신 추세", .russian: "Передача данных за последние 40 секунд"]
        ,"Status and app information": [.japanese: "実行状態とアプリ情報", .korean: "실행 상태 및 앱 정보", .russian: "Состояние и сведения о приложениях"]
        ,"Listeners and owning processes": [.japanese: "待受アドレスと所有プロセス", .korean: "수신 주소 및 소유 프로세스", .russian: "Адреса и процессы-владельцы"]
        ,"Downloads and threat history": [.japanese: "ダウンロード監視と脅威履歴", .korean: "다운로드 감시 및 위협 기록", .russian: "Загрузки и история угроз"]
        ,"Network interface": [.japanese: "ネットワークインターフェイス", .korean: "네트워크 인터페이스", .russian: "Сетевой интерфейс"]
        ,"Stop": [.japanese: "停止", .korean: "중지", .russian: "Остановить"]
        ,"Name": [.japanese: "名前", .korean: "이름", .russian: "Имя"]
        ,"Search": [.japanese: "検索", .korean: "검색", .russian: "Поиск"]
        ,"Back": [.japanese: "戻る", .korean: "뒤로", .russian: "Назад"]
        ,"Remove": [.japanese: "削除", .korean: "제거", .russian: "Удалить"]
        ,"Done": [.japanese: "完了", .korean: "완료", .russian: "Готово"]
        ,"Start Over": [.japanese: "やり直す", .korean: "다시 시작", .russian: "Начать заново"]
        ,"Select All": [.japanese: "すべて選択", .korean: "모두 선택", .russian: "Выбрать все"]
        ,"Deselect All": [.japanese: "すべて選択解除", .korean: "모두 선택 해제", .russian: "Снять выделение"]
        ,"Scan": [.japanese: "スキャン", .korean: "검사", .russian: "Сканировать"]
        ,"Clean": [.japanese: "クリーンアップ", .korean: "정리", .russian: "Очистить"]
        ,"Run": [.japanese: "実行", .korean: "실행", .russian: "Запустить"]
        ,"Review Items": [.japanese: "項目を確認", .korean: "항목 검토", .russian: "Просмотреть объекты"]
        ,"Open System Settings": [.japanese: "システム設定を開く", .korean: "시스템 설정 열기", .russian: "Открыть настройки системы"]
        ,"Very clean!": [.japanese: "とてもきれいです！", .korean: "아주 깨끗합니다!", .russian: "Всё чисто!"]
        ,"Selected": [.japanese: "選択済み", .korean: "선택됨", .russian: "Выбрано"]
        ,"Scan complete!": [.japanese: "スキャン完了！", .korean: "검사 완료!", .russian: "Сканирование завершено!"]
        ,"Scan complete": [.japanese: "スキャン完了", .korean: "검사 완료", .russian: "Сканирование завершено"]
        ,"Scan Complete": [.japanese: "スキャン完了", .korean: "검사 완료", .russian: "Сканирование завершено"]
        ,"Other": [.japanese: "その他", .korean: "기타", .russian: "Другое"]
        ,"Mail": [.japanese: "メール", .korean: "메일", .russian: "Почта"]
        ,"Leftovers": [.japanese: "残留ファイル", .korean: "남은 파일", .russian: "Остатки"]
        ,"Intro": [.japanese: "概要", .korean: "소개", .russian: "Обзор"]
        ,"Empty": [.japanese: "空にする", .korean: "비우기", .russian: "Очистить"]
        ,"All Applications": [.japanese: "すべてのアプリ", .korean: "모든 앱", .russian: "Все приложения"]
        ,"View Items": [.japanese: "項目を表示", .korean: "항목 보기", .russian: "Показать объекты"]
        ,"View Extensions": [.japanese: "機能拡張を表示", .korean: "확장 프로그램 보기", .russian: "Показать расширения"]
        ,"Uninstall": [.japanese: "アンインストール", .korean: "제거", .russian: "Удалить приложение"]
        ,"System Trash": [.japanese: "システムのゴミ箱", .korean: "시스템 휴지통", .russian: "Системная Корзина"]
        ,"Smart Selection": [.japanese: "スマート選択", .korean: "스마트 선택", .russian: "Умный выбор"]
        ,"Review Details": [.japanese: "詳細を確認", .korean: "상세 정보 검토", .russian: "Просмотреть детали"]
        ,"Review Remaining": [.japanese: "残りを確認", .korean: "남은 항목 검토", .russian: "Просмотреть оставшееся"]
        ,"Remove Extensions": [.japanese: "機能拡張を削除", .korean: "확장 프로그램 제거", .russian: "Удалить расширения"]
        ,"Sort by Name": [.japanese: "名前順", .korean: "이름순", .russian: "Сортировать по имени"]
        ,"Some Files Require Admin Privileges": [.japanese: "一部のファイルには管理者権限が必要です", .korean: "일부 파일에는 관리자 권한이 필요합니다", .russian: "Для некоторых файлов нужны права администратора"]
        ,"Confirm Run": [.japanese: "実行の確認", .korean: "실행 확인", .russian: "Подтверждение запуска"]
        ,"Continue": [.japanese: "続ける", .korean: "계속", .russian: "Продолжить"]
        ,"Delete with Admin": [.japanese: "管理者権限で削除", .korean: "관리자 권한으로 삭제", .russian: "Удалить с правами администратора"]
        ,"Running Apps Detected": [.japanese: "実行中のアプリを検出", .korean: "실행 중인 앱 감지", .russian: "Обнаружены запущенные приложения"]
        ,"Clean selected junk and run optimization tasks.": [.japanese: "選択した不要データを消去し、最適化タスクを実行します。", .korean: "선택한 정크를 정리하고 최적화 작업을 실행합니다.", .russian: "Очистить выбранный мусор и запустить оптимизацию."]
        ,"Welcome to MacOptimizer": [.japanese: "MacOptimizer へようこそ", .korean: "MacOptimizer에 오신 것을 환영합니다", .russian: "Добро пожаловать в MacOptimizer"]
        ,"Start a comprehensive, careful scan of your Mac.": [.japanese: "Mac を総合的かつ詳細にスキャンします。", .korean: "Mac을 종합적이고 꼼꼼하게 검사하세요.", .russian: "Запустите полное и тщательное сканирование Mac."]
        ,"Waiting...": [.japanese: "待機中...", .korean: "대기 중...", .russian: "Ожидание..."]
        ,"Running tasks...": [.japanese: "タスクを実行中...", .korean: "작업 실행 중...", .russian: "Выполнение задач..."]
        ,"Checking it...": [.japanese: "確認中...", .korean: "확인 중...", .russian: "Проверка..."]
        ,"Just a moment. This will be quick.": [.japanese: "少々お待ちください。まもなく完了します。", .korean: "잠시만 기다려 주세요. 곧 완료됩니다.", .russian: "Подождите немного. Это быстро."]
        ,"Just a moment. We all want this to be effortless.": [.japanese: "少々お待ちください。すぐに完了します。", .korean: "잠시만 기다려 주세요. 곧 간단히 완료됩니다.", .russian: "Подождите немного. Всё будет готово."]
        ,"Okay, here's what I found.": [.japanese: "見つかった項目はこちらです。", .korean: "찾은 항목은 다음과 같습니다.", .russian: "Вот что удалось найти."]
        ,"Everything needed to keep your Mac clean, safe, and optimized is ready. Run it now!": [.japanese: "Mac をきれい、安全、快適に保つためのタスクが準備できました。今すぐ実行しましょう！", .korean: "Mac을 깨끗하고 안전하며 최적화된 상태로 유지할 작업이 준비되었습니다. 지금 실행하세요!", .russian: "Все задачи для очистки, защиты и оптимизации Mac готовы. Запустите их сейчас!"]
        ,"Nice work!": [.japanese: "完了しました！", .korean: "잘했습니다!", .russian: "Отлично!"]
        ,"Your Mac is in great shape.": [.japanese: "Mac は良好な状態です。", .korean: "Mac 상태가 아주 좋습니다.", .russian: "Ваш Mac в отличном состоянии."]
        ,"View Details...": [.japanese: "詳細を表示...", .korean: "상세 정보 보기...", .russian: "Подробнее..."]
        ,"Good": [.japanese: "良好", .korean: "양호", .russian: "Хорошо"]
        ,"No threats found": [.japanese: "脅威は見つかりませんでした", .korean: "위협을 찾지 못했습니다", .russian: "Угрозы не найдены"]
        ,"threats": [.japanese: "件の脅威", .korean: "개 위협", .russian: "угроз"]
        ,"tasks can be run": [.japanese: "件のタスクを実行可能", .korean: "개 작업 실행 가능", .russian: "задач можно запустить"]
        ,"Unneeded junk removed": [.japanese: "不要なデータを削除しました", .korean: "불필요한 정크 제거 완료", .russian: "Ненужный мусор удалён"]
        ,"Potential issues resolved": [.japanese: "潜在的な問題を解決しました", .korean: "잠재적 문제 해결 완료", .russian: "Потенциальные проблемы устранены"]
        ,"Your Mac is performing at its best": [.japanese: "Mac は最高のパフォーマンスです", .korean: "Mac이 최상의 성능으로 작동합니다", .russian: "Mac работает с максимальной производительностью"]
        ,"Cleaning your system…": [.japanese: "システムをクリーニング中…", .korean: "시스템 정리 중…", .russian: "Очистка системы…"]
        ,"Protecting your system…": [.japanese: "システムを保護中…", .korean: "시스템 보호 중…", .russian: "Защита системы…"]
        ,"Optimizing your system...": [.japanese: "システムを最適化中...", .korean: "시스템 최적화 중...", .russian: "Оптимизация системы..."]
        ,"Finding unwanted files...": [.japanese: "不要なファイルを検索中...", .korean: "불필요한 파일 검색 중...", .russian: "Поиск ненужных файлов..."]
        ,"Determining potential threats...": [.japanese: "潜在的な脅威を確認中...", .korean: "잠재적 위협 확인 중...", .russian: "Поиск потенциальных угроз..."]
        ,"Defining suitable tasks...": [.japanese: "適切なタスクを選定中...", .korean: "적절한 작업 구성 중...", .russian: "Подбор подходящих задач..."]
        ,"Remove unwanted junk": [.japanese: "不要なデータを削除", .korean: "불필요한 정크 제거", .russian: "Удалить ненужный мусор"]
        ,"Eliminate potential threats": [.japanese: "潜在的な脅威を排除", .korean: "잠재적 위협 제거", .russian: "Устранить потенциальные угрозы"]
        ,"Improve system performance": [.japanese: "システム性能を向上", .korean: "시스템 성능 향상", .russian: "Повысить производительность системы"]
        ,"Cleanup Details": [.japanese: "クリーンアップの詳細", .korean: "정리 상세 정보", .russian: "Сведения об очистке"]
        ,"Back to Summary": [.japanese: "概要に戻る", .korean: "요약으로 돌아가기", .russian: "Вернуться к сводке"]
        ,"Sort by ": [.japanese: "並び順：", .korean: "정렬 기준: ", .russian: "Сортировать: "]
        ,"Clean your system for maximum performance and free space.": [.japanese: "システムをクリーニングして、最高の性能と空き容量を確保します。", .korean: "최상의 성능과 여유 공간을 위해 시스템을 정리하세요.", .russian: "Очистите систему для максимальной производительности и свободного места."]
        ,"Empty all Trash bins on your Mac, including Mail and Photos trash.": [.japanese: "メールや写真を含む Mac 上のすべてのゴミ箱を空にします。", .korean: "메일 및 사진 휴지통을 포함하여 Mac의 모든 휴지통을 비웁니다.", .russian: "Очистить все Корзины на Mac, включая Почту и Фото."]
        ,"System Cache": [.japanese: "システムキャッシュ", .korean: "시스템 캐시", .russian: "Системный кэш"]
        ,"Downloads & Updates": [.japanese: "ダウンロードとアップデート", .korean: "다운로드 및 업데이트", .russian: "Загрузки и обновления"]
        ,"User Cache": [.japanese: "ユーザーキャッシュ", .korean: "사용자 캐시", .russian: "Кэш пользователя"]
        ,"Trash": [.japanese: "ゴミ箱", .korean: "휴지통", .russian: "Корзина"]
        ,"System Logs": [.japanese: "システムログ", .korean: "시스템 로그", .russian: "Системные журналы"]
        ,"User Logs": [.japanese: "ユーザーログ", .korean: "사용자 로그", .russian: "Журналы пользователя"]
        ,"Duplicates": [.japanese: "重複ファイル", .korean: "중복 파일", .russian: "Дубликаты"]
        ,"Similar Photos": [.japanese: "類似写真", .korean: "유사한 사진", .russian: "Похожие фото"]
        ,"Localizations": [.japanese: "言語ファイル", .korean: "언어 파일", .russian: "Файлы локализации"]
        ,"Large Files": [.japanese: "大容量ファイル", .korean: "대용량 파일", .russian: "Большие файлы"]
        ,"Virus Protection": [.japanese: "ウイルス保護", .korean: "바이러스 보호", .russian: "Защита от вирусов"]
        ,"App Updates": [.japanese: "アプリのアップデート", .korean: "앱 업데이트", .russian: "Обновления приложений"]
        ,"Startup Items": [.japanese: "起動項目", .korean: "시작 항목", .russian: "Объекты входа"]
        ,"Performance": [.japanese: "パフォーマンス", .korean: "성능", .russian: "Производительность"]
    ]
}

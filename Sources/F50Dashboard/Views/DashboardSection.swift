import Foundation

enum DashboardSection: CaseIterable, Hashable {
    case overview
    case messages

    /// 启动时默认打开哪一栏。F50_SECTION=messages 可直接进短信，便于截图和排查。
    static var initial: DashboardSection {
        ProcessInfo.processInfo.environment["F50_SECTION"] == "messages" ? .messages : .overview
    }

    var title: String {
        switch self {
        case .overview: return "概览"
        case .messages: return "短信"
        }
    }
}

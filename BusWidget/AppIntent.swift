import AppIntents
import WidgetKit

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "バス時刻表設定" }
    static var description: IntentDescription { "学校バスの時刻表を表示します。" }

    // 路線タイプの選択
    @Parameter(title: "路線", default: .fromSeisekiToSchool)
    var routeType: RouteTypeEnum
}

// 路線タイプの列挙型
enum RouteTypeEnum: String, AppEnum {
    case fromSeisekiToSchool
    case fromNagayamaToSchool
    case fromSchoolToSeiseki
    case fromSchoolToNagayama

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: "路線タイプ")
    }

    static var caseDisplayRepresentations: [RouteTypeEnum: DisplayRepresentation] = [
        .fromSeisekiToSchool: DisplayRepresentation(title: "聖蹟桜ヶ丘駅発 → 学校行"),
        .fromNagayamaToSchool: DisplayRepresentation(title: "永山駅発 → 学校行"),
        .fromSchoolToSeiseki: DisplayRepresentation(title: "学校発 → 聖蹟桜ヶ丘駅行"),
        .fromSchoolToNagayama: DisplayRepresentation(title: "学校発 → 永山駅行")
    ]
}

// プレビュー用の拡張
extension ConfigurationAppIntent {
    fileprivate static var seiseki: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.routeType = .fromSeisekiToSchool
        return intent
    }

    fileprivate static var nagayama: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.routeType = .fromNagayamaToSchool
        return intent
    }

    fileprivate static var schoolToSeiseki: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.routeType = .fromSchoolToSeiseki
        return intent
    }

    fileprivate static var schoolToNagayama: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.routeType = .fromSchoolToNagayama
        return intent
    }
}

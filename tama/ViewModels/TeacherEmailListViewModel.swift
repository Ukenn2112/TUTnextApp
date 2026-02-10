import Combine
import Foundation
import SwiftUI

/// 教員メール一覧ViewModel
final class TeacherEmailListViewModel: ObservableObject {
    @Published var teachers: [Teacher] = []
    @Published var searchText: String = ""
    @Published var selectedTeachers: Set<UUID> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var teachersBySection: [String: [Teacher]] = [:]

    private let service = TeacherEmailListService()
    private var cancellables = Set<AnyCancellable>()

    /// 五十音行の見出し
    private let japaneseSections = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ"]

    /// 検索テキストでフィルタリングされた教員一覧
    var filteredTeachers: [Teacher] {
        if searchText.isEmpty {
            return teachers
        } else {
            return teachers.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.furigana?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    /// 教員一覧を読み込む
    func loadTeachers() {
        isLoading = true
        errorMessage = nil

        service.fetchTeachers()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] teachers in
                self?.teachers = teachers
                self?.organizeTeachersBySection(teachers)
            }
            .store(in: &cancellables)
    }

    /// 教員を五十音行ごとにグループ分けする
    private func organizeTeachersBySection(_ teachers: [Teacher]) {
        var sections: [String: [Teacher]] = [:]

        // 全ての五十音行グループを初期化
        for section in japaneseSections {
            sections[section] = []
        }

        // 「その他」グループを追加
        sections["その他"] = []

        for teacher in teachers {
            if let furigana = teacher.furigana, !furigana.isEmpty {
                let firstChar = String(furigana.prefix(1))
                var assigned = false

                // 該当する五十音行グループを判定
                for section in japaneseSections {
                    if firstChar.hasPrefix(section) ||
                       (section == "あ" && "あいうえお".contains(firstChar)) ||
                       (section == "か" && "かきくけこがぎぐげご".contains(firstChar)) ||
                       (section == "さ" && "さしすせそざじずぜぞ".contains(firstChar)) ||
                       (section == "た" && "たちつてとだぢづでど".contains(firstChar)) ||
                       (section == "な" && "なにぬねの".contains(firstChar)) ||
                       (section == "は" && "はひふへほばびぶべぼぱぴぷぺぽ".contains(firstChar)) ||
                       (section == "ま" && "まみむめも".contains(firstChar)) ||
                       (section == "や" && "やゆよ".contains(firstChar)) ||
                       (section == "ら" && "らりるれろ".contains(firstChar)) ||
                       (section == "わ" && "わをん".contains(firstChar)) {
                        sections[section]?.append(teacher)
                        assigned = true
                        break
                    }
                }

                // どのグループにも該当しない場合は「その他」へ
                if !assigned {
                    sections["その他"]?.append(teacher)
                }
            } else {
                // ふりがな情報がない教員は「その他」へ
                sections["その他"]?.append(teacher)
            }
        }

        // 各グループ内をふりがな順にソート
        for (key, value) in sections {
            sections[key] = value.sorted {
                ($0.furigana ?? "") < ($1.furigana ?? "")
            }
        }

        teachersBySection = sections
    }

    /// 教員の選択状態を切り替える
    func toggleSelection(for teacher: Teacher) {
        if selectedTeachers.contains(teacher.id) {
            selectedTeachers.remove(teacher.id)
        } else {
            selectedTeachers.insert(teacher.id)
        }
    }

    /// 教員が選択されているか確認する
    func isSelected(teacher: Teacher) -> Bool {
        return selectedTeachers.contains(teacher.id)
    }

    /// 選択された教員のメールアドレスをクリップボードにコピーする
    func copySelectedEmails() {
        let selectedEmails = teachers
            .filter { selectedTeachers.contains($0.id) }
            .map { $0.email }
            .joined(separator: ",")

        UIPasteboard.general.string = selectedEmails
    }

    /// 選択をクリアする
    func clearSelection() {
        selectedTeachers.removeAll()
    }
}

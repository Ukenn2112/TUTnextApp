import Foundation
import Combine
import SwiftUI

class TeacherEmailListViewModel: ObservableObject {
    @Published var teachers: [Teacher] = []
    @Published var searchText: String = ""
    @Published var selectedTeachers: Set<UUID> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var teachersBySection: [String: [Teacher]] = [:]
    
    private let service = TeacherEmailListService()
    private var cancellables = Set<AnyCancellable>()
    
    // 五十音行开头
    private let japaneseSections = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ"]
    
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
    
    // 将教师按五十音行分组
    private func organizeTeachersBySection(_ teachers: [Teacher]) {
        var sections: [String: [Teacher]] = [:]
        
        // 初始化所有可能的分组
        for section in japaneseSections {
            sections[section] = []
        }
        
        // 添加"その他"(其他)分组
        sections["その他"] = []
        
        for teacher in teachers {
            if let furigana = teacher.furigana, !furigana.isEmpty {
                let firstChar = String(furigana.prefix(1))
                var assigned = false
                
                // 确定该教师应该属于哪个五十音行组
                for section in japaneseSections {
                    // 假名分类逻辑，这里是简化版，实际应考虑更详细的匹配
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
                
                // 如果没有匹配任何组，放入"其他"分组
                if !assigned {
                    sections["その他"]?.append(teacher)
                }
            } else {
                // 没有假名信息的老师放入"其他"分组
                sections["その他"]?.append(teacher)
            }
        }
        
        // 对每个组内的教师按假名排序
        for (key, value) in sections {
            sections[key] = value.sorted { 
                ($0.furigana ?? "") < ($1.furigana ?? "")
            }
        }
        
        // 更新已分组的教师
        teachersBySection = sections
    }
    
    func toggleSelection(for teacher: Teacher) {
        if selectedTeachers.contains(teacher.id) {
            selectedTeachers.remove(teacher.id)
        } else {
            selectedTeachers.insert(teacher.id)
        }
    }
    
    func isSelected(teacher: Teacher) -> Bool {
        return selectedTeachers.contains(teacher.id)
    }
    
    func copySelectedEmails() {
        let selectedEmails = teachers
            .filter { selectedTeachers.contains($0.id) }
            .map { $0.email }
            .joined(separator: ",")
        
        UIPasteboard.general.string = selectedEmails
    }
    
    func clearSelection() {
        selectedTeachers.removeAll()
    }
}

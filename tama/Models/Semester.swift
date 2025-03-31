import Foundation

struct Semester {
    let year: Int
    let termNo: Int
    let termName: String
    
    var shortYearString: String {
        String(year % 100)
    }
    
    var fullDisplayName: String {
        "\(year)年度\(termName)"
    }
    
    static let current = Semester(
        year: 2025,
        termNo: 1,
        termName: "春学期"
    )
}

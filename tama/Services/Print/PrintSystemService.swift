import Foundation

/// Print system service protocol
public protocol PrintSystemServiceProtocol {
    func login() async throws -> Bool
    func uploadFile(fileData: Data, fileName: String, settings: PrintSettings) async throws -> PrintResult
    func fetchPrintDetails(id: String) async throws -> PrintResult
}

/// Print system service implementation using Core modules
public final class PrintSystemService: PrintSystemServiceProtocol {
    public static let shared = PrintSystemService()
    
    private let baseURL: String
    private let fixedId: String
    private let fixedPassword: String
    private let networkClient: NetworkClientProtocol
    
    public init(
        baseURL: String = "https://cloudodp.fujifilm.com",
        fixedId: String = "836-tamauniv01",
        fixedPassword: String = "tama1989",
        networkClient: NetworkClientProtocol = NetworkClient.shared
    ) {
        self.baseURL = baseURL
        self.fixedId = fixedId
        self.fixedPassword = fixedPassword
        self.networkClient = networkClient
    }
    
    public func login() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/guestweb/login") else {
            throw AppError.network(.noConnection)
        }
        
        // Login is a form POST with id and password
        let body = "id=\(fixedId)&password=\(fixedPassword)&lang=ja"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await networkClient.requestRaw(.init(path: url.absoluteString, method: .post, body: nil))
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AppError.auth(.invalidCredentials)
        }
        
        return true
    }
    
    public func uploadFile(fileData: Data, fileName: String, settings: PrintSettings) async throws -> PrintResult {
        guard let url = URL(string: "\(baseURL)/api/tenants/2102%3ACOD1/user/prints/") else {
            throw AppError.network(.noConnection)
        }
        
        // Build multipart form data
        let boundary = UUID().uuidString
        var body = Data()
        
        // Add file data
        let contentType = getContentType(for: fileName)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add other form fields
        addFormField(&body, boundary: boundary, name: "title", value: fileName)
        addFormField(&body, boundary: boundary, name: "isGlobal", value: "true")
        addFormField(&body, boundary: boundary, name: "colorMode", value: "auto")
        addFormField(&body, boundary: boundary, name: "plex", value: settings.plex.apiValue)
        addFormField(&body, boundary: boundary, name: "nUp", value: settings.nUp.apiValue)
        addFormField(&body, boundary: boundary, name: "startPage", value: String(settings.startPage))
        addFormField(&body, boundary: boundary, name: "autoNetprint", value: "false")
        
        if let pin = settings.pin {
            addFormField(&body, boundary: boundary, name: "pin", value: pin)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        let (data, _) = try await networkClient.requestRaw(.init(path: url.absoluteString, method: .post, body: body))
        
        // Parse response and fetch print details
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let printId = json["id"] as? String else {
            throw AppError.decoding(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid response")))
        }
        
        return try await fetchPrintDetails(id: printId)
    }
    
    public func fetchPrintDetails(id: String) async throws -> PrintResult {
        guard let url = URL(string: "\(baseURL)/api/tenants/2102%3ACOD1/user/prints/\(id)") else {
            throw AppError.network(.noConnection)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let prCode = json["prCode"] as? String else {
            throw AppError.decoding(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid print details")))
        }
        
        return PrintResult(
            printNumber: prCode,
            fileName: json["title"] as? String ?? "",
            expiryDate: formatExpiryDate(json["expiresAt"] as? String),
            pageCount: json["pages"] as? Int ?? 0,
            duplex: PlexType(rawValue: json["plex"] as? String ?? "")?.displayName ?? "片面",
            fileSize: "\(json["size"] as? Int ?? 0) KB",
            nUp: NUpType(rawValue: "\(json["nUp"] as? Int ?? 1)")?.displayName ?? "しない"
        )
    }
    
    private func addFormField(_ body: inout Data, boundary: String, name: String, value: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }
    
    private func getContentType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "xdw": return "application/vnd.fujifilm.xdw"
        case "xbd": return "application/vnd.fujifilm.xbd"
        case "pdf": return "application/pdf"
        case "xps": return "application/vnd.ms-xpsdocument"
        case "jpg", "jpeg", "jpe": return "image/jpeg"
        case "png": return "image/png"
        case "tif", "tiff": return "image/tiff"
        case "rtf": return "application/rtf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        default: return "application/octet-stream"
        }
    }
    
    private func formatExpiryDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        guard let utcDate = formatter.date(from: dateString) else { return dateString }
        
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.timeZone = .current
        
        return formatter.string(from: utcDate)
    }
}

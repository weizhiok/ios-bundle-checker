import SwiftUI

// --- 程序的入口 (App) ---
@main
struct BundleCheckerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// --- 程序的界面 (View) ---
struct ContentView: View {
    @State private var results: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bundle ID 深度检测")
                .font(.title2)
                .bold()
                .padding(.top, 40)
                .padding(.bottom, 10)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(results, id: \.self) { result in
                        Text(result)
                            .font(.system(size: 13, design: .monospaced)) // 使用等宽字体方便阅读
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            performChecks()
        }
    }

    func performChecks() {
        var logs: [String] = []
        
        // --- 1. 官方 API 获取 (最容易被 Hook) ---
        if let apiID = Bundle.main.bundleIdentifier {
            logs.append("🔹 [API层] Bundle.main:\n\(apiID)")
        } else {
            logs.append("🔹 [API层] Bundle.main:\n获取失败")
        }
        
        // --- 2. Info.plist 文件读取 (绕过内存 Hook) ---
        if let infoPath = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let infoDict = NSDictionary(contentsOfFile: infoPath),
           let plistID = infoDict["CFBundleIdentifier"] as? String {
            logs.append("📂 [文件层] Info.plist:\n\(plistID)")
        } else {
            logs.append("📂 [文件层] Info.plist:\n未找到文件")
        }
        
        // --- 3. 描述文件解析 (最底层的真实身份) ---
        // 这一步是检测“重签名”最核心的手段
        if let provisionPath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") {
            do {
                let url = URL(fileURLWithPath: provisionPath)
                let data = try Data(contentsOf: url)
                // 强制使用 Latin1 读取二进制混杂文本，避免 UTF8 解码失败
                let content = String(data: data, encoding: .isoLatin1) ?? ""
                
                // 查找 Application Identifier 字段
                if let range = content.range(of: "<key>application-identifier</key>") {
                    let sub = content[range.upperBound...]
                    if let start = sub.range(of: "<string>"), let end = sub.range(of: "</string>") {
                        let fullID = String(sub[start.upperBound..<end.lowerBound])
                        logs.append("🔒 [证书层] 描述文件:\n\(fullID)")
                    } else {
                        logs.append("🔒 [证书层] 描述文件:\n解析Key失败")
                    }
                } else {
                    logs.append("🔒 [证书层] 描述文件:\n未找到AppID字段")
                }
                
                // 额外检测: Team Name (签名团队)
                if let teamRange = content.range(of: "<key>TeamName</key>") {
                    let sub = content[teamRange.upperBound...]
                    if let start = sub.range(of: "<string>"), let end = sub.range(of: "</string>") {
                        let teamName = String(sub[start.upperBound..<end.lowerBound])
                        logs.append("bust [证书层] 签名团队:\n\(teamName)")
                    }
                }
                
            } catch {
                logs.append("🔒 [证书层] 读取错误:\n\(error.localizedDescription)")
            }
        } else {
            logs.append("🔒 [证书层] 描述文件:\n不存在 (可能是模拟器)")
        }

        self.results = logs
    }
}

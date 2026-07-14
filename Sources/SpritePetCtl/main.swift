import AppKit
import Foundation

let arguments = CommandLine.arguments.dropFirst()

func usage() -> Never {
    FileHandle.standardError.write(Data("用法：spritepetctl trigger <事件名称>\n".utf8))
    exit(64)
}

guard arguments.count == 2, arguments.first == "trigger" else { usage() }
let name = String(arguments.last!)
guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
      let url = URL(string: "spritepet://trigger/\(encoded)") else { usage() }

if !NSWorkspace.shared.open(url) {
    FileHandle.standardError.write(Data("无法打开桌宠工坊，请先安装并启动 App。\n".utf8))
    exit(1)
}

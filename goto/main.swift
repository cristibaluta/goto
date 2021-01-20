//
//  Created by Cristian Baluta on 03/07/2020.
//

import Foundation

let appVersion = "21.01.20"

enum Command: String {
    case list = "list"
    case set = "set"
    case delete = "delete"
    case terminal = "terminal"
    case finder = "finder"
}

func printHelp() {
    print("")
    print("goto \(appVersion) - (c)2021 Imagin soft")
    print("")
    print("Usage:")
    print("     list            List all paths")
    print("     set <name>      Assign a name to current directory path")
    print("     delete <name>   Delete the path with name")
    print("     finder <name>   Open new Finder window at path")
    print("     terminal <name> Open new Terminal tab at path")
    print("     <name>          Open new Terminal tab at path")
    print("")
}

let applicationSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let plistPath = applicationSupportDirectory.appendingPathComponent("com.cristibaluta.goto")
    .appendingPathExtension("plist")
var arguments = ProcessInfo.processInfo.arguments

arguments.remove(at: 0)// First arg is the filepath and needs to be removed

guard arguments.count > 0 else {
    printHelp()
    exit(0)
}

@discardableResult
func shell (launchPath: String, arguments: [String]) -> String {
    let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: String.Encoding.utf8)!
        if output.count > 0 {
            //remove newline character.
            let lastIndex = output.index(before: output.endIndex)
            return String(output[output.startIndex ..< lastIndex])
        }
        return output
}

func bash (command: String, arguments: [String]) -> String {
    let whichPathForCommand = shell(launchPath: "/bin/sh", arguments: [ "-l", "-c", "which \(command)" ])
    return shell(launchPath: whichPathForCommand, arguments: arguments)
}

func readPlist() -> [String: String] {
    var propertyListFormat = PropertyListSerialization.PropertyListFormat.xml
    var plistData: [String: String] = [:]
    var plist = FileManager.default.contents(atPath: plistPath.path)
    if plist == nil {
        // If no plist create one now
        plist = Data()
        savePlist([:])
    }
    plist = FileManager.default.contents(atPath: plistPath.path)
    do {//convert the data to a dictionary and handle errors.
        plistData = try PropertyListSerialization.propertyList(from: plist!,
                                                               options: .mutableContainersAndLeaves,
                                                               format: &propertyListFormat) as! [String: String]

    } catch {
        print("Error reading plist: \(error)")
    }
    return plistData
}

func savePlist (_ plistData: [String: String]) {
    do {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let plist = try encoder.encode(plistData)
        try plist.write(to: plistPath)
    } catch {
        print(error)
    }
}

let commandStr = arguments.remove(at: 0)
if let command = Command(rawValue: commandStr) {
    switch command {
        case .set:
            let cwd = FileManager.default.currentDirectoryPath
            let projectName = arguments.remove(at: 0)
            var projects = readPlist()
            projects[projectName] = cwd
            savePlist(projects)
        case .delete:
            let projectName = arguments.remove(at: 0)
            var projects = readPlist()
            projects[projectName] = nil
            savePlist(projects)
        case .list:
            for (key, value) in readPlist() {
                print("  \(key) -> \(value)")
            }
        case .finder:
            let projectName = arguments.remove(at: 0)
            let projects = readPlist()
            if let path = projects[projectName] {
                _ = bash(command: "open", arguments: [path])
            }
        case .terminal:
            let projectName = arguments.remove(at: 0)
            if let projectPath = readPlist()[projectName] {
                print("Switching to project '\(projectName)' at path '\(projectPath)'")
                _ = bash(command: "osascript", arguments: ["-e", "tell application \"System Events\" to tell process \"Terminal\" to keystroke \"t\" using command down", "-e", "tell application \"Terminal\" to do script \"cd \(projectPath)\" in front window"])
            }
    }
} else {
    // No command found, means the argument is a project name, so switch to it
    let projectName = commandStr
    if let projectPath = readPlist()[projectName] {
        print("Switching to project '\(projectName)' at path '\(projectPath)'")
        _ = bash(command: "osascript", arguments: ["-e", "tell application \"System Events\" to tell process \"Terminal\" to keystroke \"t\" using command down", "-e", "tell application \"Terminal\" to do script \"cd \(projectPath)\" in front window"])
    }
}

exit(0)

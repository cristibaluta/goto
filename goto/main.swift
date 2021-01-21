//
//  Created by Cristian Baluta on 03/07/2020.
//

import Foundation

let appVersion = "21.01.21"

enum Command: String {
    case list = "list"
    case set = "set"
    case delete = "delete"
    case terminal = "terminal"
    case finder = "finder"
    case file = "file"
}

func printHelp() {
    print("")
    print("goto \(appVersion) - (c)2021 Imagin Soft")
    print("")
    print("Usage:")
    print("     list               List all paths")
    print("     set <name> [path]  Assign a name to the path. If path is missing use current directory")
    print("     delete <name>      Delete the path with name")
    print("     finder <name>      Open new Finder window at path")
    print("     terminal <name>    Open new Terminal tab at path")
    print("     <name>             Open new Terminal tab or file at path")
    print("     file <name>        Open file at path")
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

func openTerminal (_ path: String) {
    print("Go to path '\(path)'")
    _ = bash(command: "osascript", arguments: ["-e", "tell application \"System Events\" to tell process \"Terminal\" to keystroke \"t\" using command down", "-e", "tell application \"Terminal\" to do script \"cd '\(path)'\" in front window"])
}

func openDir (_ path: String) {
    _ = bash(command: "open", arguments: [path])
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
            if let path = arguments.first {
                projects[projectName] = path
            } else {
                projects[projectName] = cwd
            }
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
        case .finder, .file:
            let projectName = arguments.remove(at: 0)
            if let path = readPlist()[projectName] {
                openDir(path)
            } else {
                print("Path doesn't exist")
            }
        case .terminal:
            let projectName = arguments.remove(at: 0)
            if let path = readPlist()[projectName] {
                openTerminal(path)
            } else {
                print("Path doesn't exist")
            }
    }
} else {
    // No command found, analyze if the path is a folder or file
    let projectName = arguments.remove(at: 0)
    if let path = readPlist()[projectName] {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue {
                openTerminal(path)
            } else {
                openDir(path)
            }
        } else {
            print("Path doesn't exist")
        }
    } else {
        print("Path doesn't exist")
    }
}

exit(0)

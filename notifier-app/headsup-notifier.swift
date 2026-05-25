// headsup-notifier — post a macOS notification using this .app bundle's
// icon. Compiled at install time by setup.sh and dropped into
// headsup-notifier.app/Contents/MacOS/.
//
// Why a custom binary: macOS Notification Center always renders the icon
// of the bundle that posted the notification. terminal-notifier's
// `-appIcon` flag has been a no-op since macOS Big Sur; osascript-fired
// notifications get Script Editor's icon. The only way to show OUR icon
// is to post from inside our own .app bundle via UNUserNotificationCenter.
//
// Usage:
//   headsup-notifier <title> <subtitle> <body> [group-id]
//
// Exits 0 on success, 1 on bad args, 2 on permission denied.
// First run prompts: "headsup wants to send notifications. Allow?"

import Foundation
import UserNotifications

let args = CommandLine.arguments
guard args.count >= 4 else {
    FileHandle.standardError.write(Data("usage: headsup-notifier <title> <subtitle> <body> [group-id]\n".utf8))
    exit(1)
}

let title = args[1]
let subtitle = args[2]
let body = args[3]
let groupId = args.count > 4 ? args[4] : "default"

let center = UNUserNotificationCenter.current()
let semaphore = DispatchSemaphore(value: 0)
var finalExit: Int32 = 0

center.requestAuthorization(options: [.alert, .sound]) { granted, error in
    guard granted else {
        FileHandle.standardError.write(Data("notification permission denied\n".utf8))
        finalExit = 2
        semaphore.signal()
        return
    }

    let content = UNMutableNotificationContent()
    content.title = title
    if !subtitle.isEmpty { content.subtitle = subtitle }
    content.body = body
    content.sound = .default
    // threadIdentifier groups notifications in Notification Center so a
    // newer notification with the same group replaces the older one
    // (matches the dedup behavior the old terminal-notifier path had).
    content.threadIdentifier = groupId

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )

    center.add(request) { err in
        if let err = err {
            FileHandle.standardError.write(Data("notification post failed: \(err)\n".utf8))
            finalExit = 3
        }
        semaphore.signal()
    }
}

// Authorization callback can take a moment on first run; cap it so a
// hung permission dialog doesn't keep the watchdog process alive.
_ = semaphore.wait(timeout: .now() + 10)
exit(finalExit)

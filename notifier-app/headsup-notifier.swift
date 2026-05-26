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
// Implementation notes:
//   - UNUserNotificationCenter requires the calling process to be a
//     proper NSApplication, not a bare CLI binary, or macOS silently
//     refuses to even show the authorization prompt. We instantiate
//     NSApplication.shared and drive the runloop briefly so the
//     framework sees a real app context.
//   - LSUIElement is OMITTED from Info.plist so the system treats this
//     as a regular foreground-eligible app. The binary exits quickly
//     so there's no lingering Dock icon.
//   - Bundle is ad-hoc codesigned by build-notifier.sh so macOS persists
//     the user's Allow/Deny across runs (cdhash identity).
//
// Usage:
//   headsup-notifier <title> <subtitle> <body> [group-id]
//
// Exits 0 on success, 1 on bad args, 2 on permission denied.

import Cocoa
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

// AppDelegate handles app lifecycle so NSApplication sees us as a
// proper Cocoa app — required for UNUserNotificationCenter to function.
class AppDelegate: NSObject, NSApplicationDelegate {
    var exitCode: Int32 = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async {
                guard granted else {
                    FileHandle.standardError.write(Data("notification permission denied\n".utf8))
                    if let error = error {
                        FileHandle.standardError.write(Data("  (\(error.localizedDescription))\n".utf8))
                    }
                    self.exitCode = 2
                    NSApp.terminate(nil)
                    return
                }
                self.postNotification()
            }
        }
    }

    func postNotification() {
        let content = UNMutableNotificationContent()
        content.title = title
        if !subtitle.isEmpty { content.subtitle = subtitle }
        content.body = body
        content.sound = .default
        // threadIdentifier groups notifications in Notification Center
        // so a newer notification with the same group replaces the older.
        content.threadIdentifier = groupId

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { err in
            DispatchQueue.main.async {
                if let err = err {
                    FileHandle.standardError.write(Data("notification post failed: \(err)\n".utf8))
                    self.exitCode = 3
                }
                NSApp.terminate(nil)
            }
        }
    }
}

let app = NSApplication.shared
// .accessory keeps us out of the Dock and command-tab list while still
// counting as a foreground app for permission purposes.
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate

// Safety net: if anything hangs, force-exit after 10s.
DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
    NSApp.terminate(nil)
}

app.run()
exit(delegate.exitCode)

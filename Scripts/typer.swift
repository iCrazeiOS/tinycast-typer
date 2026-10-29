// types <text-file> into the frontmost app one character at a time, using unicode keyboard events
//
// usage: typer <text-file> <key-delay-ms> <start-delay-ms> <newline-mode>
//
// every character is a real key down/up pair carrying a unicode payload, so accented letters and
// emoji arrive intact instead of being mapped through the current keyboard layout.

import ApplicationServices
import CoreGraphics
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 5 else {
    FileHandle.standardError.write(Data("usage: typer <text-file> <key-delay-ms> <start-delay-ms> <newline-mode>\n".utf8))
    exit(64)
}

let textPath = arguments[1]
let keyDelay = (Double(arguments[2]) ?? 0) / 1000
let startDelay = (Double(arguments[3]) ?? 0) / 1000
let newlineMode = arguments[4]

guard let text = try? String(contentsOfFile: textPath, encoding: .utf8) else {
    FileHandle.standardError.write(Data("typer: could not read \(textPath)\n".utf8))
    exit(65)
}

// Without this the events below are simply dropped, which looks like the helper doing nothing.
guard AXIsProcessTrusted() else {
    FileHandle.standardError.write(Data("typer: accessibility permission is not granted\n".utf8))
    exit(77)
}

guard let source = CGEventSource(stateID: .combinedSessionState) else {
    FileHandle.standardError.write(Data("typer: could not open an event source\n".utf8))
    exit(70)
}

func post(keyCode: CGKeyCode) {
    guard
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
    else { return }
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}

/// One character, carried as a unicode string so the layout never has to map it.
func post(character: String) {
    let units = Array(character.utf16)
    guard
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
    else { return }

    units.withUnsafeBufferPointer { buffer in
        guard let base = buffer.baseAddress else { return }
        down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
        up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
    }

    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}

func pauseBetweenKeys() {
    guard keyDelay > 0 else { return }
    Thread.sleep(forTimeInterval: keyDelay)
}

if startDelay > 0 {
    Thread.sleep(forTimeInterval: startDelay)
}

for character in text {
    switch character {
    case "\n", "\r", "\r\n":
        if newlineMode == "type" {
            post(keyCode: 36)
        } else if newlineMode == "space" {
            post(character: " ")
        }
    case "\t":
        post(keyCode: 48)
    default:
        guard let scalar = character.unicodeScalars.first else { continue }
        // Control characters have no typing equivalent; skipping beats typing garbage.
        if scalar.value < 0x20 || scalar.value == 0x7F { continue }
        post(character: String(character))
    }
    pauseBetweenKeys()
}

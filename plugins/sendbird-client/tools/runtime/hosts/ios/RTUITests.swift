// Runtime harness UI test (generated into a copy of the app by hosts/ios.sh). Launches the app
// as user A, opens the chat screen, and checks what user B (the Node peer, driven by ios.sh at
// the same time) sends. Writes one JSON line per step to RT_STEPS_FILE and screenshots to
// RT_SHOTS: the simulator shares the Mac's file system, so both are host paths.
import XCTest

final class RTUITests: XCTestCase {
    private let env = ProcessInfo.processInfo.environment
    private var app: XCUIApplication!
    private var shotIndex = 0
    private var failed: [String] = []

    private var outDir: String { env["RT_OUT"] ?? NSTemporaryDirectory() }

    private func record(_ step: String, _ ok: Bool?, _ detail: String, shot: String? = nil) {
        guard let path = env["RT_STEPS_FILE"] else { return }
        let line: [String: Any] = ["step": step, "ok": ok.map { $0 as Any } ?? NSNull(), "detail": detail,
                                   "screenshot": shot.map { $0 as Any } ?? NSNull()]
        guard var data = try? JSONSerialization.data(withJSONObject: line) else { return }
        data.append(0x0A)
        if let handle = FileHandle(forWritingAtPath: path) { handle.seekToEndOfFile(); handle.write(data); handle.closeFile() }
        if ok == false { failed.append("\(step): \(detail)") }
        print("RTSTEP \(step): \(ok == nil ? "n/a" : (ok! ? "ok" : "FAIL")) — \(detail)")
    }

    @discardableResult
    private func shot(_ name: String) -> String {
        shotIndex += 1
        let file = String(format: "%02d-ios-%@.png", shotIndex + 20, name)
        let dir = env["RT_SHOTS"] ?? outDir
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent(file))
        return "screens/\(file)"
    }

    private func dump(_ name: String) {
        try? app.debugDescription.write(toFile: outDir + "/ios-hierarchy-\(name).txt", atomically: true, encoding: .utf8)
    }

    private var aborted: Bool { FileManager.default.fileExists(atPath: outDir + "/.rt-abort") }

    /// Polls `cond` once a second until it holds, the timeout passes, or ios.sh aborts the run.
    private func waitUntil(_ timeout: TimeInterval, _ cond: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if cond() { return true }
            if aborted { return false }
            Thread.sleep(forTimeInterval: 1)
        }
        return cond()
    }

    /// Any element whose label (static texts, buttons, cells) or value (text views) contains `text`.
    private func element(containing text: String) -> XCUIElement? {
        let byLabel = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        if byLabel.exists { return byLabel }
        let byValue = app.textViews.matching(NSPredicate(format: "value CONTAINS %@", text)).firstMatch
        if byValue.exists { return byValue }
        return nil
    }

    func testRuntime() throws {
        continueAfterFailure = true
        // a React Native app is built outside this test's project and found by its bundle identifier
        if let bundleId = env["RT_BUNDLE_ID"], !bundleId.isEmpty {
            app = XCUIApplication(bundleIdentifier: bundleId)
        } else {
            app = XCUIApplication()
        }
        let viaForm = env["RT_SIGNIN_FORM"] == "1"
        // the launch hook signs in only when the app has no sign-in form of its own
        app.launchEnvironment["RT_USER_ID"] = viaForm ? "" : (env["RT_USER_A"] ?? "")
        app.launchEnvironment["RT_STEPS_FILE"] = env["RT_STEPS_FILE"] ?? ""
        app.launch()
        let launched = app.wait(for: .runningForeground, timeout: 60)
        Thread.sleep(forTimeInterval: 3)
        record("launch", launched, launched ? "app is in the foreground" : "app did not reach the foreground", shot: shot("launched"))
        if viaForm { signInThroughForm(env["RT_USER_A"] ?? "") }
        // React Native: the harness entry in the app's JavaScript made the call (hosts/react-native.sh)
        if !viaForm, let hook = env["RT_SIGNIN_HOOK"], !hook.isEmpty { record("sign-in", true, hook) }

        let chatUI = env["RT_CHAT_UI"] == "1"
        if chatUI {
            let direct = env["RT_DIRECT"] == "1"
            // a button that leads to chats, never one that makes something new ("New channel", "Create chat"), as on
            // Android (2026-10-24: a React Native home with "New channel" and a channel list without a title)
            let listPredicate = NSPredicate(format: "label MATCHES[c] %@ AND NOT (label MATCHES[c] %@)",
                                            ".*(chat|channel|message|inbox).*", ".*\\b(new|create|add|start)\\b.*")
            // direct chat: the button that opens the conversation ("Chat with seller", "Message seller"),
            // never one to a list ("Channels", "Inbox") or one that makes something new; a label with
            // "with" or "seller" comes first (2026-10-19: a React Native home had "Channels" and "View product")
            let directPredicate = NSPredicate(format: "label MATCHES[c] %@ AND NOT (label MATCHES[c] %@)",
                                              ".*(chat|message|contact).*", ".*\\b(channels?|inbox|new|create|add)\\b.*")
            let preferredPredicate = NSPredicate(format: "label MATCHES[c] %@", ".*\\b(with|seller)\\b.*")
            // A React Native Pressable or Touchable without accessibilityRole="button" is no button to
            // XCUITest: it is an "other" element whose label is its text. Buttons are tried first; the
            // touchable only when no button matches (2026-10-19: a RN app whose buttons had no role)
            // Only a short label without commas counts on such an element: React Native reads a whole list row out as
            // one label ("Always Developers, 3, ... SendBird's chat API"), and a row whose last message says "chat"
            // is no chat button (2026-10-24: the harness opened an unrelated channel and never saw B's)
            let shortLabel = NSPredicate(format: "label MATCHES %@", "[^,]{1,30}")
            let firstEntry: ([NSPredicate]) -> XCUIElement = { preds in
                let p = NSCompoundPredicate(andPredicateWithSubpredicates: preds)
                let button = self.app.buttons.matching(p).firstMatch
                return button.exists ? button : self.app.otherElements.matching(NSCompoundPredicate(andPredicateWithSubpredicates: preds + [shortLabel])).firstMatch
            }
            // the stable identifier of templates/starters-bp/BEST_PRACTICES.md comes first
            let taggedEntry = app.descendants(matching: .any).matching(identifier: "sb_open_channels").firstMatch
            let currentEntry: () -> XCUIElement = {
                if !direct && taggedEntry.exists { return taggedEntry }
                guard direct else { return firstEntry([listPredicate]) }
                let preferred = firstEntry([directPredicate, preferredPredicate])
                return preferred.exists ? preferred : firstEntry([directPredicate])
            }
            let entryReady: () -> Bool = { let e = currentEntry(); return e.exists && e.isHittable && e.isEnabled }
            var opened = false
            var entryLabel = ""
            // some apps present the channel list right after sign-in: a "Channels" title with cells
            // (never in direct chat: the button, not a list, has to open the conversation)
            // (a React Native FlatList has no cells: there the list counts as shown once B's channel is a row on it, or
            // the app tags the list sb_channel_list)
            // A list without a title also counts once B's channel is a row: by its name, or by B's first message (this
            // run's tag) when the row shows member names instead
            let channelName = env["RT_CHANNEL"] ?? ""
            let firstTextB = env["RT_TEXT_B1"] ?? ""
            let bRowShown = { (!channelName.isEmpty && self.element(containing: channelName) != nil)
                || (!firstTextB.isEmpty && self.element(containing: firstTextB) != nil) }
            let listShown = { !direct && (self.app.descendants(matching: .any).matching(identifier: "sb_channel_list").firstMatch.exists
                || self.app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Channels")).firstMatch.exists
                && (self.app.cells.count > 0 || bRowShown())
                || bRowShown()) }
            // direct chat: the chat button may sit on a product screen one tap away from home
            if direct && !waitUntil(10, entryReady) {
                let product = firstEntry([NSPredicate(format: "label MATCHES[c] %@", ".*product.*")])
                if product.exists && product.isHittable { product.tap(); Thread.sleep(forTimeInterval: 2) }
            }
            if waitUntil(40, { listShown() || entryReady() }) {
                if listShown() {
                    entryLabel = "(the channel list was already on screen)"
                } else {
                    let entry = currentEntry()
                    entryLabel = entry.label  // read before the tap: the button is gone once the screen changes
                    entry.tap()
                }
                opened = true
            }
            Thread.sleep(forTimeInterval: 4)
            if opened {
                record("chat-screen", true, "tapped \"\(entryLabel)\" on the home screen", shot: shot("channel-list"))
            } else {
                dump("chat-screen")
                record("chat-screen", false, "no chat or channel button on the home screen", shot: shot("no-chat-entry"))
            }

            let name = env["RT_CHANNEL"] ?? ""
            let b1 = env["RT_TEXT_B1"] ?? "", a1 = env["RT_TEXT_A1"] ?? "", b2 = env["RT_TEXT_B2"] ?? ""
            if opened && env["RT_DIRECT"] == "1" {
                // the button opened a 1:1 conversation with B directly: send, then wait for B's reply
                let inputShown = waitUntil(30, { self.messageInputs().count > 0 })
                if !inputShown { dump("direct-chat") }
                record("channel", inputShown, inputShown ? "\"\(entryLabel)\" opened a 1:1 conversation" : "\"\(entryLabel)\" did not open a conversation (no message input within 30 s)", shot: shot("direct-chat"))
                sendMessage(a1)
                if waitUntil(150, { element(containing: b2) != nil }) {
                    record("message-a-live", true, "A sees B's reply \"\(b2)\"", shot: shot("live"))
                } else {
                    dump("message-a-live")
                    record("message-a-live", false, "A never showed B's reply \"\(b2)\"", shot: shot("no-live"))
                }
            } else if opened {
                var cell: XCUIElement?
                // a row that does not show the channel name is found by B's message, which carries this run's tag:
                // a table row only (in a conversation the same text is a message, not a row), and only to open it;
                // A must still see the message inside the conversation (2026-10-24: a Chat SDK list showed
                // "2 members (1 unread)" and the last message, never the name)
                var byPreview = false
                let previewRow = { () -> XCUIElement? in
                    guard !b1.isEmpty else { return nil }
                    let row = self.app.cells.containing(NSPredicate(format: "label CONTAINS %@", b1)).firstMatch
                    return row.exists ? row : nil
                }
                if waitUntil(180, { cell = element(containing: name); if cell == nil, let row = previewRow() { cell = row; byPreview = true }; return cell != nil }) , let cell {
                    if byPreview { record("channel-name", nil, "A's list row for \"\(name)\" does not show the channel name; found the row by B's message \"\(b1)\"") }
                    cell.tap()
                    // the conversation is open only when its message input is on screen; the list row alone
                    // can already show B's message as a preview
                    let convOpen = waitUntil(15, { self.messageInputs().count > 0 })
                    if !convOpen { dump("channel") }
                    record("channel", convOpen, convOpen ? "\"\(name)\" (opened by B) appeared in A's list and A opened it" : "\"\(name)\" appeared in A's list, but tapping it did not open a conversation (no message input within 15 s)", shot: shot(convOpen ? "channel-open" : "not-opened"))
                    if convOpen {
                        if waitUntil(30, { element(containing: b1) != nil }) {
                            record("message-a-receives", true, "A sees \"\(b1)\"", shot: shot("received"))
                        } else {
                            dump("message-a-receives")
                            record("message-a-receives", false, "A never showed \"\(b1)\"", shot: shot("not-received"))
                        }
                        sendMessage(a1)
                        if waitUntil(150, { element(containing: b2) != nil }) {
                            record("message-a-live", true, "A sees B's next message \"\(b2)\" without reopening", shot: shot("live"))
                        } else {
                            record("message-a-live", false, "A never showed B's next message \"\(b2)\"", shot: shot("no-live"))
                        }
                        if env["RT_RICH"] == "1" { richFeatures(b1: b1, a1: a1) }
                    }
                } else {
                    dump("channel")
                    record("channel", false, "A's list never showed \"\(name)\"", shot: shot("no-channel"))
                }
            }
            for text in (env["RT_EXPECT_TEXT"] ?? "").split(separator: "\n").map(String.init) {
                let seen = waitUntil(10) { element(containing: text) != nil }
                record("custom", seen, seen ? "text \"\(text)\" is on screen" : "text \"\(text)\" is not on screen", shot: shot("custom"))
            }
            for id in (env["RT_EXPECT_SELECTOR"] ?? "").split(separator: "\n").map(String.init) {
                let el = app.descendants(matching: .any)[id]
                let seen = waitUntil(10) { el.exists }
                if !seen { dump("custom-\(id)") }
                record("custom", seen, seen ? "element \(id) is on screen" : "element \(id) is not on screen", shot: shot("custom"))
            }
        } else {
            // No chat screen: keep the app running until ios.sh has checked A's presence.
            _ = waitUntil(240) { FileManager.default.fileExists(atPath: outDir + "/.rt-release") }
            shot("idle")
        }
        let alive = app.state == .runningForeground
        record("no-crash", alive, alive ? "app still in the foreground at the end" : "app is no longer running (state \(app.state.rawValue))")
        if !failed.isEmpty { XCTFail(failed.joined(separator: "; ")) }
    }

    /// Types the user ID into the app's first text field and taps its "Sign in" / "Log in" button.
    /// Signs in through the app's own form. The field and the button are found by where they are on
    /// screen (RTSignin.swift), not by the button's label, so a form in any language works.
    private func signInThroughForm(_ user: String) {
        var nodes: [RTSigninNode] = []
        var fieldPick: RTSigninPick?
        var found = waitUntil(20, { nodes = signinNodes(); fieldPick = rtPickSigninField(nodes); return fieldPick != nil })
        // A form that opens behind a button ("Sign in" presents an alert with the user ID field): tap
        // that button once and look again (a 2026-10 TC run: "0 text field(s) on screen").
        if !found {
            let opener = app.buttons.matching(NSPredicate(format: "label MATCHES[c] %@", "(sign ?in|log ?in|login|로그인|시작.*)")).firstMatch
            if opener.exists && opener.isHittable {
                opener.tap()
                found = waitUntil(15, { nodes = signinNodes(); fieldPick = rtPickSigninField(nodes); return fieldPick != nil })
            }
        }
        guard found, let fieldPick else {
            dump("sign-in")
            record("sign-in", false, "the app's sign-in form did not appear (no user ID text field: \(nodes.filter { $0.kind == .field }.count) text field(s) on screen)", shot: shot("no-sign-in-form"))
            return
        }
        tap(nodes[fieldPick.index])
        // Clear what the app put in the field first: typing after a prefilled "buyer-1" signed in as
        // "buyer-1rt-ios-…", a user the server did not know (a 2026-10 TC run).
        let focused = app.textFields.matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
        if focused.exists, let text = focused.value as? String, !text.isEmpty, text != (focused.placeholderValue ?? "") {
            app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count))
        }
        app.typeText(user)
        // the button is read after typing: a form may enable it only once the field has text
        var buttonPick: RTSigninPick?
        let ready = waitUntil(10, {
            nodes = signinNodes()
            guard let f = rtPickSigninField(nodes) else { return false }
            buttonPick = rtPickSigninButton(nodes, field: f.index)
            return buttonPick.map { nodes[$0.index].enabled } ?? false
        })
        guard ready, let buttonPick else {
            dump("sign-in")
            let why = buttonPick.map { "\"\(nodes[$0.index].label)\" (\($0.rule)) stayed disabled after typing" } ?? "no button to submit it"
            record("sign-in", false, "found the user ID field (\(fieldPick.rule)) but \(why)", shot: shot("no-sign-in-button"))
            return
        }
        var pick = buttonPick
        // Close the keyboard before the tap: it can cover the button, and the tap then lands on the keyboard
        // and sign-in never happens (2026-10-25: a React Native form whose button sat 5 pt above the frame
        // XCUITest reports for the iOS 27 keyboard, which draws its top bar above that frame). The return key
        // ends editing in a single-line field (a tap outside does not blur a React Native field); then the
        // form is read again, since it moves once the keyboard is gone.
        if app.keyboards.count > 0 {
            let typedInto = nodes[fieldPick.index]
            app.typeText("\n")
            Thread.sleep(forTimeInterval: 2)
            if app.keyboards.count > 0 { closeKeyboard() }
            nodes = signinNodes()
            // the return key may have submitted the form itself: the field typed into is gone (another
            // screen's field, such as a message input, is not the form)
            let sameField = { (n: RTSigninNode) in n.kind == .field && n.identifier == typedInto.identifier && n.placeholder == typedInto.placeholder }
            guard nodes.contains(where: sameField), let field = rtPickSigninField(nodes) else {
                record("sign-in", true, "A=\(user) typed into the app's own form (\(fieldPick.rule)) and submitted it with the return key", shot: shot("signed-in"))
                return
            }
            guard let again = rtPickSigninButton(nodes, field: field.index), !coveredByKeyboard(nodes[again.index]) else {
                dump("sign-in")
                record("sign-in", false, "the keyboard covers the sign-in button and the return key did not close it", shot: shot("sign-in-covered"))
                return
            }
            pick = again
        }
        let label = nodes[pick.index].label  // read before the tap: the button may be gone afterwards
        tap(nodes[pick.index])
        Thread.sleep(forTimeInterval: 3)
        record("sign-in", true, "A=\(user) typed into the app's own form (\(fieldPick.rule)) and tapped \"\(label)\" (\(pick.rule))", shot: shot("signed-in"))
    }

    /// Whether a keyboard is still on screen near the node: the iOS 27 keyboard draws its top bar about
    /// 45 pt above the frame XCUITest reports, so a node that ends within 60 pt of that frame counts.
    private func coveredByKeyboard(_ node: RTSigninNode) -> Bool {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return false }
        let k = keyboard.frame
        return k.height > 0 && k.minY.isFinite && node.y + node.h > Double(k.minY) - 60
    }

    /// Text fields and buttons on screen, read from one snapshot (a screen that changes mid-read
    /// would make element-by-element queries fail).
    private func signinNodes() -> [RTSigninNode] {
        guard let root = try? app.snapshot() else { return [] }
        var nodes: [RTSigninNode] = []
        var stack: [XCUIElementSnapshot] = [root]
        while let node = stack.popLast() {
            stack.append(contentsOf: node.children.reversed())
            let kind: RTSigninNode.Kind
            switch node.elementType {
            case .textField: kind = .field
            case .button: kind = .button
            // a React Native Pressable without accessibilityRole="button": a labelled "other" element
            // with no children of its own (containers, the keyboard's among them, have children).
            // Without this the nearest "button" below the field was a keyboard suggestion (2026-10-19)
            case .other where !node.label.isEmpty && node.children.isEmpty: kind = .button
            default: continue
            }
            let f = node.frame
            nodes.append(RTSigninNode(kind: kind, identifier: node.identifier, label: node.label, placeholder: node.placeholderValue ?? "",
                                      enabled: node.isEnabled, x: Double(f.minX), y: Double(f.minY), w: Double(f.width), h: Double(f.height)))
        }
        return nodes
    }

    private func tap(_ node: RTSigninNode) {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: node.x + node.w / 2, dy: node.y + node.h / 2)).tap()
    }

    /// Types into the chat screen's message input (the text view nearest the bottom) and sends.
    /// Message inputs on screen: UIKit uses a text view, a SwiftUI TextField is a text field.
    private func messageInputs() -> [XCUIElement] {
        // UIKit draws message bubbles as text views too: leave out those inside a list row
        let rows = rowFrames()
        return (app.textViews.allElementsBoundByIndex + app.textFields.allElementsBoundByIndex)
            // an off-screen element has an infinite frame, and asking whether it is hittable throws
            .filter { el in el.exists && el.frame.minX.isFinite && el.frame.width > 0 && el.isHittable && !rows.contains { $0.contains(el.frame) } }
    }

    /// Frames of the list rows on screen, read from one snapshot: rows come and go while a screen
    /// changes, and reading them one by one fails on a row that has just gone.
    private func rowFrames() -> [CGRect] {
        guard let root = try? app.snapshot() else { return [] }
        var rows: [CGRect] = []
        var stack: [XCUIElementSnapshot] = [root]
        while let node = stack.popLast() {
            if node.elementType == .cell { rows.append(node.frame) } else { stack.append(contentsOf: node.children) }
        }
        return rows
    }

    private func sendMessage(_ text: String, step: String = "message-a-types") {
        guard let input = messageInputs().max(by: { $0.frame.maxY < $1.frame.maxY }) else {
            dump("input")
            record(step, false, "no message input on the chat screen", shot: shot("no-input"))
            return
        }
        input.tap()
        input.typeText(text)
        let inputFrame = input.frame
        // "send" but not an attachment button ("Send image", "Send file", "Send photo")
        let labeled = app.buttons.matching(NSPredicate(format: "(label MATCHES[c] %@ OR identifier MATCHES[c] %@) AND NOT (label MATCHES[c] %@)", ".*send.*", ".*send.*", ".*(image|file|photo|attach|camera|voice|video).*")).firstMatch
        // UIKit's send button may carry no label: then take the button right of the input, on its row.
        func unlabeledSend() -> XCUIElement? {
            app.buttons.allElementsBoundByIndex
                .filter { $0.exists && $0.isHittable && abs($0.frame.midY - inputFrame.midY) < 30 && $0.frame.minX >= inputFrame.maxX - 4 }
                .max(by: { $0.frame.minX < $1.frame.minX })
        }
        // React Native UIKit's send button is a touchable without a button role, so it is no button to
        // XCUITest: an unlabeled, icon-sized element right of the input, on its row. A Chat SDK screen's
        // Pressable without accessibilityRole is the same kind of element with its text as the label
        // ("Send"; 2026-10-24: a React Native demo's composer). Read from one snapshot (asking each of a
        // React Native screen's many elements one by one takes too long).
        func touchableSend() -> CGRect? {
            guard let root = try? app.snapshot() else { return nil }
            var best: CGRect?
            var stack: [XCUIElementSnapshot] = [root]
            let sendLabel = NSPredicate(format: "SELF MATCHES[c] %@ AND NOT (SELF MATCHES[c] %@)", ".*send.*", ".*(image|file|photo|attach|camera|voice|video).*")
            while let node = stack.popLast() {
                stack.append(contentsOf: node.children)
                let f = node.frame
                let unlabeledIcon = node.label.isEmpty && f.width <= 64
                let labeledSend = !node.label.isEmpty && node.label.count <= 20 && node.children.isEmpty && sendLabel.evaluate(with: node.label) && f.width <= 160
                guard node.elementType == .other, unlabeledIcon || labeledSend, f.width > 0, f.height <= 64,
                      abs(f.midY - inputFrame.midY) < 30, f.minX >= inputFrame.maxX - 4, f.maxX <= root.frame.maxX else { continue }
                if best == nil || f.minX > best!.minX { best = f }
            }
            return best
        }
        var found: XCUIElement?
        var touchable: CGRect?
        if waitUntil(5, { found = (labeled.exists && labeled.isHittable) ? labeled : unlabeledSend(); if found == nil { touchable = touchableSend() }; return found != nil || touchable != nil }) {
            if let send = found {
                let name = send.label.isEmpty ? (send.identifier.isEmpty ? "the unlabeled button right of the input" : send.identifier) : send.label
                send.tap()
                record(step, true, "typed \"\(text)\" and tapped \"\(name)\"", shot: shot("typed"))
            } else if let f = touchable {
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.midX, dy: f.midY)).tap()
                record(step, true, "typed \"\(text)\" and tapped the touchable right of the input", shot: shot("typed"))
            }
        } else {
            dump("send")
            record(step, false, "no send button after typing", shot: shot("no-send"))
        }
    }

    // MARK: - rich conversation features (RT_RICH=1)
    // After the two-way exchange: a reaction on B's message, an edit and a delete of A's own
    // messages, an image attachment, and a message search. Each step only drives the screen and
    // records what it saw; ios.sh checks the server for what each action left there.

    private func richFeatures(b1: String, a1: String) {
        let edited = env["RT_TEXT_A1_EDITED"] ?? "", a2 = env["RT_TEXT_A2"] ?? "", keyword = env["RT_SEARCH"] ?? ""
        closeKeyboard()
        reaction(on: b1)
        edit(a1, to: edited)
        deleteOwn(a2)
        attachImage()
        search(keyword)
    }

    private func hittable(_ q: XCUIElementQuery) -> [XCUIElement] {
        q.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
    }

    /// A menu entry, button, or alert action whose label is one of `names` (case-insensitive).
    private func menuItem(_ names: [String]) -> XCUIElement? {
        let pred = NSPredicate(format: "label IN[c] %@", names)
        for q in [app.alerts.buttons, app.sheets.buttons, app.buttons, app.cells, app.staticTexts, app.menuItems] {
            // the last match: a confirmation alert sits on top of the menu entry that opened it
            let m = q.matching(pred)
            let n = m.count
            if n > 0 {
                let e = m.element(boundBy: n - 1)
                if e.exists && e.isHittable { return e }
            }
        }
        return nil
    }

    /// A short name for a tapped element: its label, unless that is empty or a run-on summary.
    private func describe(_ e: XCUIElement, _ fallback: String) -> String {
        let l = e.label
        return (l.isEmpty || l.count > 40) ? (e.identifier.isEmpty ? fallback : e.identifier) : l
    }

    /// Closes the keyboard the way a user does: tap the empty part of the message list, then drag
    /// the list down. Messages hidden behind the keyboard cannot be long-pressed.
    private func closeKeyboard() {
        var tries = 0
        while app.keyboards.count > 0 && tries < 3 {
            switch tries {
            case 0: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32)).tap()
            case 1: if app.tables.count > 0 { app.tables.firstMatch.swipeDown() } else { app.swipeDown() }
            default: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
            }
            Thread.sleep(forTimeInterval: 1.5)
            tries += 1
        }
    }

    /// The message bubble that shows `text`: long-press it the way a user does.
    private func longPress(_ text: String, step: String) -> Bool {
        closeKeyboard()
        guard let el = element(containing: text), el.isHittable else {
            dump(step)
            record(step, false, "message \"\(text)\" is not on screen to long-press", shot: shot("\(step)-no-message"))
            return false
        }
        el.press(forDuration: 1.2)
        Thread.sleep(forTimeInterval: 1.5)
        return true
    }

    private func dismissMenu() {
        if let cancel = menuItem(["Cancel", "Close"]) { cancel.tap() } else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap() }
        Thread.sleep(forTimeInterval: 1)
    }

    private func reaction(on text: String) {
        guard longPress(text, step: "rich-reaction") else { return }
        dump("rich-reaction-menu")
        let menuShot = shot("rich-reaction-menu")
        // the emoji row sits above the text menu (Copy / Reply / ...): anchor on the menu's TOP entry.
        // menuItem returns the last match, which on a long menu (Copy, Mark as unread, Reply in thread)
        // is three rows below the emoji row and outside the 160-point window searched below.
        let menuNames = ["Copy", "Reply", "Edit", "Delete", "Reply in thread", "Mark as unread"]
        let anchor = [app.buttons, app.cells, app.staticTexts, app.menuItems]
            .flatMap { hittable($0.matching(NSPredicate(format: "label IN[c] %@", menuNames))) }
            .min(by: { $0.frame.minY < $1.frame.minY }) ?? menuItem(menuNames)
        let emojiNamed = hittable(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'sendbird_emoji' OR label BEGINSWITH 'sendbird_emoji'")))
        var pick = emojiNamed.first
        if pick == nil, let anchor {
            let top = anchor.frame.minY
            // the row right above the menu, its leftmost entry (a sheet's drag handle sits higher up)
            pick = (hittable(app.cells) + hittable(app.buttons) + hittable(app.images))
                .filter { $0.frame.maxY <= top + 2 && $0.frame.minY > top - 160 && $0.frame.width < 80 && $0.frame.height < 80 }
                .min(by: { (-$0.frame.maxY, $0.frame.minX) < (-$1.frame.maxY, $1.frame.minX) })
        }
        guard let emoji = pick else {
            record("rich-reaction", false, "long-pressed \"\(text)\" but found no emoji to tap in the menu (menu items: \(anchor?.label ?? "none"))", shot: menuShot)
            dismissMenu()
            return
        }
        let name = emoji.identifier.isEmpty ? (emoji.label.isEmpty ? "the first emoji of the menu" : emoji.label) : emoji.identifier
        emoji.tap()
        Thread.sleep(forTimeInterval: 3)
        record("rich-reaction", true, "long-pressed B's \"\(text)\" and tapped \(name)", shot: shot("rich-reaction-done"))
    }

    private func edit(_ text: String, to newText: String) {
        guard longPress(text, step: "rich-edit") else { return }
        dump("rich-edit-menu")
        guard let item = menuItem(["Edit"]) else {
            record("rich-edit", false, "long-pressed A's \"\(text)\" but the menu has no Edit", shot: shot("rich-edit-no-item"))
            dismissMenu()
            return
        }
        item.tap()
        Thread.sleep(forTimeInterval: 1.5)
        guard let input = messageInputs().max(by: { $0.frame.maxY < $1.frame.maxY }) else {
            dump("rich-edit-input")
            record("rich-edit", false, "tapped Edit but no text input appeared", shot: shot("rich-edit-no-input"))
            return
        }
        input.tap()
        let current = (input.value as? String) ?? ""
        input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: max(current.count, text.count) + 4))
        input.typeText(newText)
        let editShot = shot("rich-edit-typing")
        dump("rich-edit-typing")
        let inputFrame = input.frame
        let labeled = hittable(app.buttons.matching(NSPredicate(format: "label MATCHES[c] %@", "(save|done|update|edit|send|ok)"))).last
        let right = hittable(app.buttons).filter { abs($0.frame.midY - inputFrame.midY) < 40 && $0.frame.minX >= inputFrame.maxX - 4 }.max(by: { $0.frame.minX < $1.frame.minX })
        guard let save = labeled ?? right else {
            record("rich-edit", false, "typed the new text but found no Save button", shot: editShot)
            return
        }
        let name = save.label.isEmpty ? "the unlabeled button right of the input" : save.label
        save.tap()
        Thread.sleep(forTimeInterval: 3)
        closeKeyboard()
        let shown = waitUntil(15) { self.element(containing: newText) != nil }
        record("rich-edit", shown, shown ? "changed A's \"\(text)\" to \"\(newText)\" (tapped \(name)); the new text is on screen" : "tapped \(name) after typing \"\(newText)\", but the new text is not on screen", shot: shot("rich-edit-done"))
    }

    private func deleteOwn(_ text: String) {
        sendMessage(text, step: "rich-delete-send")
        closeKeyboard()
        guard waitUntil(20, { self.element(containing: text) != nil }) else {
            record("rich-delete", false, "A's \"\(text)\" never showed on screen after sending", shot: shot("rich-delete-not-sent"))
            return
        }
        // ios.sh confirms the server has the message before A deletes it
        let seen = waitUntil(120) { FileManager.default.fileExists(atPath: self.outDir + "/.rt-a2-seen") }
        if !seen { record("rich-delete", false, "the server never had \"\(text)\" (B did not see it), so there is nothing to delete", shot: shot("rich-delete-unseen")); return }
        guard longPress(text, step: "rich-delete") else { return }
        dump("rich-delete-menu")
        guard let item = menuItem(["Delete"]) else {
            record("rich-delete", false, "long-pressed A's \"\(text)\" but the menu has no Delete", shot: shot("rich-delete-no-item"))
            dismissMenu()
            return
        }
        item.tap()
        Thread.sleep(forTimeInterval: 1.5)
        let confirmShot = shot("rich-delete-confirm")
        dump("rich-delete-confirm")
        if let confirm = menuItem(["Delete", "OK", "Yes", "Confirm"]) { confirm.tap(); Thread.sleep(forTimeInterval: 3) }
        let gone = waitUntil(15) { self.element(containing: text) == nil }
        record("rich-delete", gone, gone ? "deleted A's \"\(text)\"; it is no longer on screen" : "tapped Delete, but \"\(text)\" is still on screen", shot: gone ? shot("rich-delete-done") : confirmShot)
    }

    private func attachImage() {
        closeKeyboard()
        guard let input = messageInputs().max(by: { $0.frame.maxY < $1.frame.maxY }) else {
            record("rich-attach", false, "no message input to find the attachment button by", shot: shot("rich-attach-no-input"))
            return
        }
        let row = input.frame
        let labeled = hittable(app.buttons.matching(NSPredicate(format: "label MATCHES[c] %@ OR identifier MATCHES[c] %@", ".*(image|photo|attach|add|plus|file|more).*", ".*(image|photo|attach|add|plus|file|more).*")))
            .filter { abs($0.frame.midY - row.midY) < 40 && $0.frame.maxX <= row.minX + 4 }
        let left = hittable(app.buttons).filter { abs($0.frame.midY - row.midY) < 40 && $0.frame.maxX <= row.minX + 4 }.min(by: { $0.frame.minX < $1.frame.minX })
        // prefer an image button over a file one when the app shows both
        let imageFirst = labeled.first { $0.label.range(of: "image|photo", options: [.regularExpression, .caseInsensitive]) != nil }
        guard let attach = imageFirst ?? labeled.first ?? left else {
            dump("rich-attach")
            record("rich-attach", false, "no attachment button left of the message input", shot: shot("rich-attach-no-button"))
            return
        }
        let name = describe(attach, "the button left of the input")
        attach.tap()
        Thread.sleep(forTimeInterval: 2)
        dump("rich-attach-menu")
        let menuShot = shot("rich-attach-menu")
        // an action sheet (Camera / Photo library / Files) may come first
        if let lib = menuItem(["Photo library", "Photo Library", "Photos", "Gallery", "Photo & video library", "Photo & Video Library", "Library", "Choose photo", "Photo"]) {
            lib.tap(); Thread.sleep(forTimeInterval: 3)
        }
        Thread.sleep(forTimeInterval: 3)
        dump("rich-attach-picker")
        let pickerShot = shot("rich-attach-picker")
        // the system photo picker: its photos are images labeled "Photo, <date>". The picker runs in
        // its own process; when its contents are not in the app's tree, tap where its first photo is
        // (the top-left cell of the grid, under its title bar: the newest photo, the one ios.sh added)
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH[c] 'Photo'")).firstMatch
        var how = "tapped the first photo of the picker"
        if waitUntil(20, { photo.exists && photo.isHittable }) {
            photo.tap()
        } else if app.windows.count > 1 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.17, dy: 0.25)).tap()
            how = "tapped the top-left photo of the picker by position (the picker runs outside the app)"
        } else {
            record("rich-attach", false, "tapped \(name) but no photo picker showed up", shot: menuShot)
            dismissMenu()
            return
        }
        _ = pickerShot
        Thread.sleep(forTimeInterval: 2)
        dump("rich-attach-picked")
        // some pickers or previews ask once more before sending
        if let add = menuItem(["Add", "Send", "Done", "Choose"]) { add.tap(); Thread.sleep(forTimeInterval: 2) }
        Thread.sleep(forTimeInterval: 4)
        record("rich-attach", true, "tapped \(name), \(how)", shot: shot("rich-attach-done"))
        // stay on the conversation until ios.sh has seen the upload arrive (or given up)
        _ = waitUntil(450) { FileManager.default.fileExists(atPath: self.outDir + "/.rt-file-seen") }
        shot("rich-attach-sent")
    }

    private func search(_ keyword: String) {
        closeKeyboard()
        // the channel header's right-hand button opens channel settings, where search lives;
        // an app may also put a Search button in the header itself
        var searchEntry = menuItem(["Search", "Search in channel", "Search messages"])
        if searchEntry == nil {
            let navButtons = hittable(app.navigationBars.buttons)
            if let settings = navButtons.max(by: { $0.frame.maxX < $1.frame.maxX }), navButtons.count > 1 || settings.frame.minX > app.frame.midX {
                settings.tap()
                Thread.sleep(forTimeInterval: 4)
                dump("rich-search-settings")
                searchEntry = waitUntil(10, { self.menuItem(["Search", "Search in channel", "Search messages", "Message search"]) != nil }) ? menuItem(["Search", "Search in channel", "Search messages", "Message search"]) : nil
            }
        }
        guard let entry = searchEntry else {
            dump("rich-search")
            record("rich-search", false, "no Search entry in the channel header or its settings", shot: shot("rich-search-no-entry"))
            return
        }
        let entryName = describe(entry, "Search")
        entry.tap()
        Thread.sleep(forTimeInterval: 4)
        dump("rich-search-screen")
        let field = (hittable(app.searchFields) + hittable(app.textFields)).first
        guard let field else {
            record("rich-search", false, "opened \"\(entryName)\" but found no search field", shot: shot("rich-search-no-field"))
            return
        }
        field.tap()
        field.typeText(keyword + "\n")
        Thread.sleep(forTimeInterval: 2)
        // a result row shows the message text: B's first message carries the keyword
        let hit = app.cells.containing(NSPredicate(format: "label CONTAINS %@", keyword)).firstMatch
        let found = waitUntil(30) { hit.exists || self.app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", keyword)).count > 1 }
        dump("rich-search-results")
        record("rich-search", found, found ? "searched \"\(keyword)\" from \"\(entryName)\"; results list messages with it" : "searched \"\(keyword)\" from \"\(entryName)\", but no result showed", shot: shot("rich-search-results"))
    }
}

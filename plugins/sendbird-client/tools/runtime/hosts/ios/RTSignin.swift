import Foundation

// Finds an app's sign-in form without reading the button's label, so the harness signs in to an app
// in any language ("Sign in", "로그인", "대화 시작하기" all work). RTUITests reads the screen into
// RTSigninNode values and asks these functions; they are pure, so tests/runtime/signin runs them on
// recorded screens. The Android harness has the same rules (hosts/android/RTSignin.kt).

struct RTSigninNode {
    enum Kind: String { case field, button }
    var kind: Kind
    var identifier: String   // accessibility identifier (iOS) or resource id (Android)
    var label: String        // label, text, or content description
    var placeholder: String
    var enabled: Bool
    var x: Double, y: Double, w: Double, h: Double

    var visible: Bool { w > 0 && h > 0 && x.isFinite && y.isFinite }
    func contains(_ o: RTSigninNode) -> Bool { o.x >= x && o.y >= y && o.x + o.w <= x + w && o.y + o.h <= y + h }
}

struct RTSigninPick { let index: Int; let rule: String }

// the id after the last "/": an Android resource id is "com.example:id/sb_login_user_id"
private func rtIdName(_ id: String) -> String { String(id.split(separator: "/").last ?? "").lowercased() }

private func rtMatches(_ text: String, _ pattern: String) -> Bool {
    text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}

/// The user ID field. Rules, in order:
/// 1. the field whose id is a starter convention (sb_login_user_id, user, user_id, userid, username)
/// 2. the only text field on screen
/// 3. the only field whose label or placeholder names a user ID ("User ID", "아이디", "사용자")
func rtPickSigninField(_ nodes: [RTSigninNode]) -> RTSigninPick? {
    let fields = nodes.indices.filter { nodes[$0].kind == .field && nodes[$0].visible }
    let ids: Set<String> = ["sb_login_user_id", "user", "user_id", "userid", "username"]
    if let i = fields.first(where: { ids.contains(rtIdName(nodes[$0].identifier)) }) { return RTSigninPick(index: i, rule: "id \(nodes[i].identifier)") }
    if fields.count == 1 { return RTSigninPick(index: fields[0], rule: "the only text field") }
    let named = fields.filter { rtMatches(nodes[$0].label + " " + nodes[$0].placeholder, "user|\\bid\\b|아이디|사용자") }
    if named.count == 1 { return RTSigninPick(index: named[0], rule: "the field named \"\(nodes[named[0]].placeholder.isEmpty ? nodes[named[0]].label : nodes[named[0]].placeholder)\"") }
    return nil
}

/// The button that submits the form, read after the user ID is typed. Rules, in order:
/// 1. the button whose id is a starter convention (sb_login_button, login_button, signin_button)
/// 2. the button nearest the field at or below its top (beside it, then under it), enabled or not:
///    a sign-in button that is still disabled is waited for, not passed over for the next one down;
///    a cancel or close button never counts here (a sign-in alert puts "Cancel" left of "Sign in" on
///    the same row, and the left one won the tie: a 2026-10 TC run)
/// 3. the only enabled button on screen
/// 4. a button labelled sign in / log in / login, then 로그인 / 시작 (the label is the last resort)
/// Buttons inside the field (a clear button) never count.
func rtPickSigninButton(_ nodes: [RTSigninNode], field: Int) -> RTSigninPick? {
    let f = nodes[field]
    let buttons = nodes.indices.filter { nodes[$0].kind == .button && nodes[$0].visible && !f.contains(nodes[$0]) }
    let ids: Set<String> = ["sb_login_button", "login_button", "signin_button"]
    if let i = buttons.first(where: { ids.contains(rtIdName(nodes[$0].identifier)) }) { return RTSigninPick(index: i, rule: "id \(nodes[i].identifier)") }
    let below = buttons.filter { nodes[$0].y >= f.y && !rtMatches(nodes[$0].label, "^(cancel|close|dismiss|취소|닫기)$") }
    let gap = { (b: RTSigninNode) in max(0, b.y - (f.y + f.h)) }
    let dx = { (b: RTSigninNode) in abs((b.x + b.w / 2) - (f.x + f.w / 2)) }
    // nearest first; at the same distance the one more centered under the field, then the left one
    if let i = below.min(by: { (gap(nodes[$0]), dx(nodes[$0]), nodes[$0].x) < (gap(nodes[$1]), dx(nodes[$1]), nodes[$1].x) }) {
        return RTSigninPick(index: i, rule: "the button nearest below the field")
    }
    let enabled = buttons.filter { nodes[$0].enabled }
    if enabled.count == 1 { return RTSigninPick(index: enabled[0], rule: "the only enabled button") }
    for pattern in ["\\b(sign|log) ?in\\b|^login$", "로그인|시작"] {
        if let i = enabled.first(where: { rtMatches(nodes[$0].label, pattern) }) { return RTSigninPick(index: i, rule: "the label \"\(nodes[i].label)\"") }
    }
    return nil
}

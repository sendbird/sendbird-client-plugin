package rt.harness

// Finds an app's sign-in form without reading the button's label, so the harness signs in to an app
// in any language ("Sign in", "로그인", "대화 시작하기" all work). RTRuntimeTest reads the screen into
// RTSigninNode values and asks these functions; they are pure, so tests/runtime/signin runs them on
// recorded screens. The iOS harness has the same rules (hosts/ios/RTSignin.swift).

data class RTSigninNode(
    val field: Boolean,      // a text field; otherwise a button (a clickable node)
    val id: String,          // resource id ("com.example:id/sb_login_user_id", or a Compose test tag)
    val label: String,       // text or content description
    val placeholder: String, // hint
    val enabled: Boolean,
    val x: Int, val y: Int, val w: Int, val h: Int,
) {
    val visible get() = w > 0 && h > 0
    fun contains(o: RTSigninNode) = o.x >= x && o.y >= y && o.x + o.w <= x + w && o.y + o.h <= y + h
}

data class RTSigninPick(val index: Int, val rule: String)

// the id after the last "/"
private fun idName(id: String) = id.substringAfterLast('/').lowercase()

/** The user ID field. Rules, in order:
 *  1. the field whose id is a starter convention (sb_login_user_id, user, user_id, userid, username)
 *  2. the only text field on screen
 *  3. the only field whose label or hint names a user ID ("User ID", "아이디", "사용자") */
fun rtPickSigninField(nodes: List<RTSigninNode>): RTSigninPick? {
    val fields = nodes.indices.filter { nodes[it].field && nodes[it].visible }
    val ids = setOf("sb_login_user_id", "user", "user_id", "userid", "username")
    fields.firstOrNull { idName(nodes[it].id) in ids }?.let { return RTSigninPick(it, "id ${nodes[it].id}") }
    if (fields.size == 1) return RTSigninPick(fields[0], "the only text field")
    val named = fields.filter { Regex("(?i)user|\\bid\\b|아이디|사용자").containsMatchIn(nodes[it].label + " " + nodes[it].placeholder) }
    if (named.size == 1) return RTSigninPick(named[0], "the field named \"${nodes[named[0]].placeholder.ifEmpty { nodes[named[0]].label }}\"")
    return null
}

/** The button that submits the form, read after the user ID is typed. Rules, in order:
 *  1. the button whose id is a starter convention (sb_login_button, login_button, signin_button)
 *  2. the button nearest the field at or below its top (beside it, then under it), enabled or not:
 *     a sign-in button that is still disabled is waited for, not passed over for the next one down;
 *     a cancel or close button never counts here (a sign-in dialog puts "Cancel" left of "Sign in" on
 *     the same row, and the left one won the tie: a 2026-10 TC run)
 *  3. the only enabled button on screen
 *  4. a button labelled sign in / log in / login, then 로그인 / 시작 (the label is the last resort)
 *  Buttons inside the field (a clear or trailing icon) never count. */
fun rtPickSigninButton(nodes: List<RTSigninNode>, field: Int): RTSigninPick? {
    val f = nodes[field]
    val buttons = nodes.indices.filter { !nodes[it].field && nodes[it].visible && !f.contains(nodes[it]) }
    val ids = setOf("sb_login_button", "login_button", "signin_button")
    buttons.firstOrNull { idName(nodes[it].id) in ids }?.let { return RTSigninPick(it, "id ${nodes[it].id}") }
    val below = buttons.filter { nodes[it].y >= f.y && !Regex("(?i)^(cancel|close|dismiss|취소|닫기)$").containsMatchIn(nodes[it].label.trim()) }
    fun gap(b: RTSigninNode) = maxOf(0, b.y - (f.y + f.h))
    fun dx(b: RTSigninNode) = Math.abs((b.x + b.w / 2) - (f.x + f.w / 2))
    // nearest first; at the same distance the one more centered under the field, then the left one
    below.minWithOrNull(compareBy({ gap(nodes[it]) }, { dx(nodes[it]) }, { nodes[it].x }))?.let { return RTSigninPick(it, "the button nearest below the field") }
    val enabled = buttons.filter { nodes[it].enabled }
    if (enabled.size == 1) return RTSigninPick(enabled[0], "the only enabled button")
    for (pattern in listOf("(?i)\\b(sign|log) ?in\\b|^login$", "로그인|시작")) {
        enabled.firstOrNull { Regex(pattern).containsMatchIn(nodes[it].label) }?.let { return RTSigninPick(it, "the label \"${nodes[it].label}\"") }
    }
    return null
}

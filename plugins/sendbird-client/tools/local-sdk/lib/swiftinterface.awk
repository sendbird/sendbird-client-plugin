# Public surface of a .swiftinterface, grouped by type. Called by read-swiftinterface.sh
# with -v MODULE=<module name>. POSIX awk only (macOS ships BWK awk).
# Exit 4 when scopes or #if blocks do not balance: the parse went wrong somewhere and
# members could be attributed to the wrong type.

function clip(s) { return length(s) > 400 ? substr(s, 1, 400) " …" : s }

# Drop `Swift.`, `Foundation.`, `<MODULE>.` and similar prefixes before a type name.
function strip_modules(s,   out, pre, m) {
  out = ""
  while (match(s, NOISE)) {
    pre = substr(s, 1, RSTART - 1); m = substr(s, RSTART, RLENGTH)
    # keep the boundary character before the module and the letter after the dot
    if (m ~ /^[^A-Za-z0-9_]/) { pre = pre substr(m, 1, 1) }
    out = out pre substr(m, RLENGTH, 1)
    s = substr(s, RSTART + RLENGTH)
  }
  return out s
}

function tidy(t) {
  gsub(/@objc(\([^)]*\))?([ ]+|$)/, "", t)
  gsub(/@_(hasMissingDesignatedInitializers|inheritsConvenienceInitializers|hasStorage|borrowed|nonoverride|alwaysEmitIntoClient|transparent|unsafeInheritExecutor)([ ]+|$)/, "", t)
  gsub(/@_(effects|semantics|silgen_name|implements|specialize|documentation|originallyDefinedIn)\([^)]*\)[ ]*/, "", t)
  gsub(/@(inlinable|discardableResult|preconcurrency)[ ]+/, "", t)
  gsub(/(^|[ ])dynamic[ ]+/, " ", t)
  t = strip_modules(t)
  gsub(/[ \t]+/, " ", t); sub(/^ /, "", t); sub(/ $/, "", t)
  return t
}

# Split leading attributes (`@name` or `@name(...)`, quotes and nested parens respected)
# into NA/ATTR[], the declaration into REST. Attribute arguments hold free text
# (deprecation messages), so access checks never look at them.
function split_attrs(t,   i, j, n, c, depth, q) {
  NA = 0; i = 1; n = length(t)
  while (substr(t, i, 1) == "@") {
    j = i + 1
    while (j <= n && substr(t, j, 1) ~ /[A-Za-z0-9_.]/) j++
    if (substr(t, j, 1) == "(") {
      depth = 0; q = 0
      for (; j <= n; j++) {
        c = substr(t, j, 1)
        if (q) { if (c == "\\") j++; else if (c == "\"") q = 0; continue }
        if (c == "\"") q = 1
        else if (c == "(") depth++
        else if (c == ")") { depth--; if (depth == 0) { j++; break } }
      }
    }
    ATTR[++NA] = substr(t, i, j - i)
    i = j; while (substr(t, i, 1) == " ") i++
  }
  REST = substr(t, i)
}

function modifiers_of(rest) {
  if (match(rest, /(^| )(func|var|let|init|subscript|case|typealias|associatedtype|class|struct|enum|protocol|actor|extension|operator|precedencegroup|deinit|macro)([ (<?!]|$)/))
    return substr(rest, 1, RSTART)
  return rest
}

function count(s, ch,   n, i) { n = 0; for (i = 1; i <= length(s); i++) if (substr(s, i, 1) == ch) n++; return n }

function section(key) {
  if (!(key in HAS)) { HAS[key] = 1; ORDER[++NS] = key }
}
function add_member(key, m) { section(key); MEM[key] = MEM[key] (MEM[key] == "" ? "" : "\n") clip(m) }
function add_conf(key, p) {
  section(key)
  if ((key SUBSEP p) in CSEEN) return
  CSEEN[key SUBSEP p] = 1; CONF[key] = CONF[key] (CONF[key] == "" ? "" : "; ") p
}

function scope(   i) { for (i = SP; i >= 1; i--) if (FK[i] == "type" || FK[i] == "ext") return i; return 0 }
function push(kind, key, isreq) { SP++; FK[SP] = kind; FKEY[SP] = key; FREQ[SP] = isreq; FD[SP] = 1; FACC[SP] = ""; FTEXT[SP] = "" }

BEGIN {
  NOISE = "(^|[^A-Za-z0-9_])(Swift|_Concurrency|ObjectiveC|Foundation|UIKit"
  if (MODULE != "") NOISE = NOISE "|" MODULE
  NOISE = NOISE ")\\.[A-Za-z_]"
  SP = 0; NIF = 0; NP = 0; NS = 0; dropped = 0
}

{
  t = $0; gsub(/[ \t]+/, " ", t); sub(/^ /, "", t); sub(/ $/, "", t)
  if (t == "" || t ~ /^\/\//) next

  if (t ~ /^#if([ (]|$)/) { NIF++; IFSKIP[NIF] = (NIF > 1 && IFSKIP[NIF - 1]); next }
  if (t ~ /^#(else|elseif)([ (]|$)/) { if (NIF) IFSKIP[NIF] = 1; next }
  if (t ~ /^#endif/) { if (NIF) NIF--; next }
  if (NIF && IFSKIP[NIF]) next
  if (t ~ /^(@_exported )?import /) next

  # Inside a function body or accessor block: track depth, collect get/set.
  if (SP && FK[SP] == "body") {
    if (FD[SP] == 1 && t ~ /^(@[A-Za-z_]+ )*((mutating|nonmutating) )?(get|set)([^A-Za-z0-9_]|$)/) {
      if (t ~ /(^| )get([^A-Za-z0-9_]|$)/ && FACC[SP] !~ /g/) FACC[SP] = FACC[SP] "g"
      if (t ~ /(^| )set([^A-Za-z0-9_]|$)/ && FACC[SP] !~ /s/) FACC[SP] = FACC[SP] "s"
    }
    FD[SP] += count(t, "{") - count(t, "}")
    if (FD[SP] <= 0) {
      line = FTEXT[SP]
      if (FACC[SP] != "") line = line " { " (FACC[SP] ~ /g/ ? "get" : "") (FACC[SP] ~ /g/ && FACC[SP] ~ /s/ ? " " : "") (FACC[SP] ~ /s/ ? "set" : "") " }"
      key = FKEY[SP]; SP--
      add_member(key, line)
    }
    next
  }
  # Inside a dropped (non-public) declaration: skip until its closing brace.
  if (SP && FK[SP] == "skip") {
    FD[SP] += count(t, "{") - count(t, "}")
    if (FD[SP] <= 0) SP--
    next
  }
  if (t == "}") { if (SP) SP--; next }

  # A line holding only attributes belongs to the declaration on the next line.
  split_attrs(t)
  if (REST == "") { for (i = 1; i <= NA; i++) PEND[++NP] = ATTR[i]; next }
  n = 0
  for (i = 1; i <= NP; i++) A[++n] = PEND[i]
  for (i = 1; i <= NA; i++) A[++n] = ATTR[i]
  NP = 0
  rest = REST; mods = modifiers_of(rest)

  opens = (rest ~ /\{ ?$/)
  s = scope(); inreq = (s && FREQ[s])

  if (rest ~ /^deinit([^A-Za-z0-9_]|$)/) { if (opens) push("skip"); next }
  nonpub = (mods ~ /(^| )(internal|fileprivate|private|package)( |$)/)
  kept = ""
  for (i = 1; i <= n; i++) {
    if (A[i] ~ /^@(usableFromInline|_spi)([^A-Za-z0-9_]|$)/ || A[i] ~ /^@available\( *\* *, *unavailable([^A-Za-z0-9_]|$)/) nonpub = 1
    if (A[i] ~ /^@(available|MainActor|_Concurrency\.MainActor|preconcurrency|escaping|Sendable|nonobjc|IBInspectable|IBDesignable|frozen|propertyWrapper|resultBuilder|dynamicMemberLookup|objcMembers)([^A-Za-z0-9_]|$)/)
      kept = kept A[i] " "
  }
  if (nonpub) { dropped++; if (opens) push("skip"); next }
  ispub = (mods ~ /(^| )(public|open)( |$)/)
  full = kept rest

  # Type declaration (`class func` / `class var` are static members, not types).
  if (match(rest, /(^| )(class|struct|enum|protocol|actor|extension) [A-Za-z_][A-Za-z0-9_.]*/)) {
    m = substr(rest, RSTART, RLENGTH); sub(/^ /, "", m)
    kind = m; sub(/ .*/, "", kind)
    name = m; sub(/^[a-z]+ /, "", name)
    if (name !~ /^(func|var|let|subscript)$/) {
      name = tidy(name)
      head = full; sub(/ ?\{ ?\}? ?$/, "", head); head = tidy(head)
      if (kind == "extension") {
        e = rest; sub(/ ?\{ ?\}? ?$/, "", e); e = tidy(e)
        if (match(e, /^extension [A-Za-z0-9_.]+ ?: ?/)) { EXTN[++NE] = name; EXTP[NE] = substr(e, RLENGTH + 1) }
        if (opens) push("ext", name, 0)
        next
      }
      if (!ispub && !inreq) { dropped++; if (opens) push("skip"); next }
      key = (s ? FKEY[s] "." : "") name
      section(key); KIND[key] = kind; DECL[key] = head
      if (opens) push("type", key, (kind == "protocol" || kind == "enum"))
      next
    }
  }

  # A member, or a top-level func/var/typealias. Operator and precedence-group
  # declarations carry no access modifier and are always public.
  isop = (rest ~ /^((prefix|infix|postfix) operator|precedencegroup)([^A-Za-z0-9_]|$)/)
  if (!ispub && !inreq && !isop) { dropped++; if (opens) push("skip"); next }
  key = s ? FKEY[s] : "(top level)"
  text = full; sub(/ ?\{ ?$/, "", text); text = tidy(text)
  if (opens) { push("body", key, 0); FTEXT[SP] = text; next }
  add_member(key, text)
}

END {
  if (SP || NIF || NP) {
    printf "unbalanced interface (open scopes %d, open #if %d, dangling attributes %d)\n", SP, NIF, NP > "/dev/stderr"
    exit 4
  }
  # Conformances from extensions attach to the type when it is declared here.
  for (i = 1; i <= NE; i++) {
    if ((EXTN[i] in DECL)) add_conf(EXTN[i], EXTP[i]); else add_conf("extension " EXTN[i], EXTP[i])
  }
  # Members added through `extension Foo {}` where Foo is not declared here (e.g. UIColor).
  for (i = 1; i <= NS; i++) {
    k = ORDER[i]
    if ((k in DECL) || k == "(top level)" || k ~ /^extension /) continue
    nk = "extension " k
    if (MEM[k] != "") { section(nk); MEM[nk] = MEM[nk] (MEM[nk] == "" ? "" : "\n") MEM[k] }
    if (CONF[k] != "") add_conf(nk, CONF[k])
    GONE[k] = 1
  }
  members = 0
  for (i = 1; i <= NS; i++) {
    k = ORDER[i]
    if (k in GONE) continue
    if (!(k in DECL) && MEM[k] == "" && CONF[k] == "") continue
    print ((k in DECL) ? "## " KIND[k] " " k : "## " k)
    if (k in DECL) { d = DECL[k]; gsub(/_/, "\\_", d); print "_" d "_" }
    if (CONF[k] != "") { c = CONF[k]; gsub(/_/, "\\_", c); print "_conforms to (extensions): " c "_" }
    if (MEM[k] != "") {
      cnt = split(MEM[k], ms, "\n")
      for (j = 1; j <= cnt; j++) { mm = ms[j]; gsub(/`/, "'", mm); print "- `" mm "`"; members++ }
    }
    print ""
  }
  printf "swiftinterface: %d members, %d non-public declarations dropped\n", members, dropped > "/dev/stderr"
}

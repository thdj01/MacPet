import Foundation

/// Models write math as LaTeX ($…$, \(…\), \[…\], $$…$$), which NSTextView can't typeset.
/// This turns it into readable Unicode: \frac{a+b}{2} → (a + b)/2, x^2 → x², \alpha → α.
enum LaTeX {
    struct Segment { let text: String; let display: Bool }

    static let placeholderBase: UInt16 = 0xE000

    /// Pulls math spans out of `text`, leaving a private-use placeholder for each so Markdown parsing can't mangle them.
    static func extract(_ text: String) -> (String, [Segment]) {
        let c = Array(text)
        var out = "", math: [Segment] = []
        var i = 0

        func find(_ delim: String, from start: Int) -> Int? {
            let d = Array(delim)
            var j = start
            while j + d.count <= c.count {
                if c[j] == "\\" && d != ["\\", "]"] && d != ["\\", ")"] { j += 2; continue }
                if Array(c[j..<j + d.count]) == d { return j }
                j += 1
            }
            return nil
        }
        func emit(_ body: ArraySlice<Character>, display: Bool) {
            let lines = toUnicode(String(body)).components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            out.unicodeScalars.append(Unicode.Scalar(placeholderBase + UInt16(math.count))!)
            math.append(Segment(text: lines.joined(separator: "\n"), display: display))
        }

        while i < c.count {
            let ch = c[i], next: Character? = i + 1 < c.count ? c[i + 1] : nil
            guard math.count < 6000 else { out.append(contentsOf: c[i...]); break }
            if ch == "`" {  // leave inline code alone
                var j = i
                while j < c.count && c[j] == "`" { j += 1 }
                let ticks = String(repeating: "`", count: j - i)
                if let r = String(c[j...]).range(of: ticks) {
                    let end = j + String(c[j...])[..<r.upperBound].count
                    out.append(contentsOf: c[i..<end]); i = end
                } else {
                    out.append(contentsOf: c[i..<j]); i = j
                }
                continue
            }
            if ch == "\\", next == "[" || next == "(" {
                let display = next == "["
                if let j = find(display ? "\\]" : "\\)", from: i + 2) {
                    emit(c[(i + 2)..<j], display: display); i = j + 2; continue
                }
            }
            if ch == "\\", next == "$" { out.append("\\$"); i += 2; continue }
            if ch == "$", next == "$", let j = find("$$", from: i + 2), j > i + 2 {
                emit(c[(i + 2)..<j], display: true); i = j + 2; continue
            }
            if ch == "$", let n = next, !n.isWhitespace, let j = find("$", from: i + 1), j > i + 1,
               !c[j - 1].isWhitespace, j + 1 >= c.count || !c[j + 1].isNumber, !c[(i + 1)..<j].contains("\n") {
                emit(c[(i + 1)..<j], display: false); i = j + 1; continue
            }
            out.append(ch); i += 1
        }
        return (out, math)
    }

    /// Plain-text version of a message with all math converted (for the speech bubble).
    static func plain(_ text: String) -> String {
        let (s, math) = extract(text)
        var out = ""
        for u in s.unicodeScalars {
            let k = Int(u.value) - Int(placeholderBase)
            if k >= 0 && k < math.count { out += math[k].text.replacingOccurrences(of: "\n", with: "; ") }
            else { out.unicodeScalars.append(u) }
        }
        return out.replacingOccurrences(of: "\\$", with: "$")
    }

    static func toUnicode(_ src: String) -> String {
        var p = Parser(c: Array(src))
        return p.sequence()
    }

    // MARK: - Parser

    private struct Parser {
        let c: [Character]
        var i = 0

        mutating func sequence(until close: Character? = nil) -> String {
            var s = ""
            while i < c.count {
                let ch = c[i]
                if ch == close { i += 1; return s }
                if ch == "^" || ch == "_" {
                    i += 1
                    s += LaTeX.script(atom(), sup: ch == "^")
                } else if ch.isWhitespace || ch == "&" {
                    i += 1
                    if !s.isEmpty && !s.hasSuffix(" ") && !s.hasSuffix("\n") { s += " " }
                } else {
                    s += atom()
                }
            }
            return s
        }

        mutating func skipSpace() { while i < c.count && c[i].isWhitespace { i += 1 } }

        mutating func atom() -> String {
            skipSpace()
            guard i < c.count else { return "" }
            let ch = c[i]
            i += 1
            switch ch {
            case "{": return sequence(until: "}")
            case "}": return ""
            case "\\": return command()
            case "~": return " "
            case "'": return "′"
            case "-": return "−"
            case "*": return "∗"
            default: return String(ch)
            }
        }

        mutating func command() -> String {
            guard i < c.count else { return "\\" }
            var name = ""
            if c[i].isLetter {
                while i < c.count && c[i].isLetter { name.append(c[i]); i += 1 }
            } else {
                name = String(c[i]); i += 1
            }
            switch name {
            case "\\": return "\n"
            case ",", ";", ":", ">", " ": return " "
            case "!": return ""
            case "quad": return "  "
            case "qquad": return "    "
            case "{", "}", "%", "$", "&", "#", "_": return name
            case "|": return "‖"
            case "frac", "dfrac", "tfrac", "cfrac":
                let a = atom(), b = atom()
                return LaTeX.fraction(a, b)
            case "binom", "dbinom", "tbinom":
                let a = atom(), b = atom()
                return "C(\(a), \(b))"
            case "sqrt":
                skipSpace()
                var index: String?
                if i < c.count && c[i] == "[" { i += 1; index = sequence(until: "]") }
                let body = atom()
                let root = switch index {
                case nil: "√"
                case "3": "∛"
                case "4": "∜"
                default: LaTeX.script(index!, sup: true) + "√"
                }
                return root + LaTeX.group(body)
            case "text", "textrm", "mathrm", "textbf", "mathbf", "mathit", "textit", "mathsf", "textsf",
                 "texttt", "mathtt", "operatorname", "boldsymbol", "bm", "mbox", "hbox", "emph", "textnormal",
                 "mathcal", "mathscr", "mathfrak", "underbrace", "overbrace", "boxed", "color":
                if name == "color" { _ = atom() }
                return atom()
            case "mathbb":
                return String(atom().map { LaTeX.doubleStruck[$0] ?? $0 })
            case "left", "right", "big", "Big", "bigg", "Bigg", "bigl", "bigr", "Bigl", "Bigr", "biggl", "biggr", "middle":
                skipSpace()
                if i < c.count && c[i] == "." { i += 1; return "" }
                return atom()
            case "displaystyle", "textstyle", "scriptstyle", "limits", "nolimits", "nonumber", "notag":
                return ""
            case "begin", "end":
                let env = atom()
                if name == "begin" && (env == "array" || env == "tabular") { _ = atom() }
                let open = name == "begin"
                switch env.replacingOccurrences(of: "∗", with: "") {
                case "pmatrix": return open ? "(" : ")"
                case "bmatrix": return open ? "[" : "]"
                case "vmatrix": return "|"
                case "Bmatrix", "cases": return open ? "{ " : ""
                default: return ""
                }
            case "hat", "widehat": return LaTeX.accent(atom(), "\u{0302}")
            case "bar": return LaTeX.accent(atom(), "\u{0304}")
            case "vec", "overrightarrow": return LaTeX.accent(atom(), "\u{20D7}")
            case "dot": return LaTeX.accent(atom(), "\u{0307}")
            case "ddot": return LaTeX.accent(atom(), "\u{0308}")
            case "tilde", "widetilde": return LaTeX.accent(atom(), "\u{0303}")
            case "overline": return String(atom().flatMap { [$0, "\u{0305}"] })
            case "underline": return String(atom().flatMap { [$0, "\u{0332}"] })
            case "not":
                let a = atom()
                return ["=": "≠", "∈": "∉", "⊂": "⊄", "⊆": "⊈", "≡": "≢", "<": "≮", ">": "≯", "∼": "≁"][a] ?? a + "\u{0338}"
            case "pmod": return " (mod \(atom()))"
            case "bmod", "mod": return " mod "
            case "overset", "stackrel":
                _ = atom()
                return atom()
            default:
                if LaTeX.functions.contains(name) {
                    // \sin\theta → "sin θ", \sin(x) → "sin(x)"
                    skipSpace()
                    let follows = i < c.count && (c[i].isLetter || c[i].isNumber || c[i] == "\\")
                    return follows ? name + " " : name
                }
                return LaTeX.symbols[name] ?? name
            }
        }
    }

    // MARK: - Helpers

    static func script(_ arg: String, sup: Bool) -> String {
        let trimmed = arg.trimmingCharacters(in: .whitespaces)
        let t = trimmed.replacingOccurrences(of: " ", with: "")
        if t.isEmpty { return "" }
        if sup && t == "∘" { return "°" }
        if sup && t.allSatisfy({ $0 == "′" }) { return t }
        let table = sup ? superscripts : subscripts
        let mapped = t.compactMap { table[$0] }
        if mapped.count == t.count { return String(mapped) }
        let simple = t.count == 1 || t.allSatisfy { $0.isLetter || $0.isNumber }
        return (sup ? "^" : "_") + (simple ? t : "(\(trimmed))")
    }

    static func fraction(_ a: String, _ b: String) -> String {
        let a = a.trimmingCharacters(in: .whitespaces), b = b.trimmingCharacters(in: .whitespaces)
        if let v = vulgar["\(a)/\(b)"] { return v }
        if a.allSatisfy(\.isNumber) && b.allSatisfy(\.isNumber) && !a.isEmpty && !b.isEmpty {
            return script(a, sup: true) + "⁄" + script(b, sup: false)
        }
        return group(a) + "/" + group(b)
    }

    /// Wraps compound expressions in parentheses so a/b and √x stay unambiguous.
    static func group(_ s: String) -> String {
        let s = s.trimmingCharacters(in: .whitespaces)
        var depth = 0, compound = false
        for ch in s {
            if "([{".contains(ch) { depth += 1 } else if ")]}".contains(ch) { depth -= 1 }
            else if depth == 0 && " +−-±∓·×÷/=<>≤≥,".contains(ch) { compound = true; break }
        }
        return compound ? "(\(s))" : s
    }

    static func accent(_ s: String, _ mark: Character) -> String { s.isEmpty ? String(mark) : s + String(mark) }

    static let functions: Set<String> = [
        "sin", "cos", "tan", "sec", "csc", "cot", "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh",
        "log", "ln", "lg", "exp", "lim", "liminf", "limsup", "max", "min", "sup", "inf", "det", "gcd", "lcm",
        "deg", "dim", "ker", "arg", "Pr", "hom", "tr", "rank", "sgn",
    ]

    static let vulgar: [String: String] = [
        "1/2": "½", "1/3": "⅓", "2/3": "⅔", "1/4": "¼", "3/4": "¾", "1/5": "⅕", "2/5": "⅖", "3/5": "⅗",
        "4/5": "⅘", "1/6": "⅙", "5/6": "⅚", "1/8": "⅛", "3/8": "⅜", "5/8": "⅝", "7/8": "⅞",
    ]

    static let doubleStruck: [Character: Character] = [
        "N": "ℕ", "Z": "ℤ", "Q": "ℚ", "R": "ℝ", "C": "ℂ", "P": "ℙ", "H": "ℍ", "E": "𝔼", "F": "𝔽", "1": "𝟙",
    ]

    static let superscripts: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "−": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
        "a": "ᵃ", "b": "ᵇ", "c": "ᶜ", "d": "ᵈ", "e": "ᵉ", "f": "ᶠ", "g": "ᵍ", "h": "ʰ", "i": "ⁱ", "j": "ʲ",
        "k": "ᵏ", "l": "ˡ", "m": "ᵐ", "n": "ⁿ", "o": "ᵒ", "p": "ᵖ", "r": "ʳ", "s": "ˢ", "t": "ᵗ", "u": "ᵘ",
        "v": "ᵛ", "w": "ʷ", "x": "ˣ", "y": "ʸ", "z": "ᶻ",
        "A": "ᴬ", "B": "ᴮ", "D": "ᴰ", "E": "ᴱ", "G": "ᴳ", "H": "ᴴ", "I": "ᴵ", "J": "ᴶ", "K": "ᴷ", "L": "ᴸ",
        "M": "ᴹ", "N": "ᴺ", "O": "ᴼ", "P": "ᴾ", "R": "ᴿ", "T": "ᵀ", "U": "ᵁ", "V": "ⱽ", "W": "ᵂ",
        "α": "ᵅ", "β": "ᵝ", "γ": "ᵞ", "δ": "ᵟ", "ε": "ᵋ", "θ": "ᶿ", "φ": "ᵠ", "χ": "ᵡ", "′": "′", "∗": "*",
    ]

    static let subscripts: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "−": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ", "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "o": "ₒ",
        "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ", "v": "ᵥ", "x": "ₓ",
        "β": "ᵦ", "γ": "ᵧ", "ρ": "ᵨ", "φ": "ᵩ", "χ": "ᵪ",
    ]

    static let symbols: [String: String] = [
        // Greek
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε", "varepsilon": "ε", "zeta": "ζ",
        "eta": "η", "theta": "θ", "vartheta": "ϑ", "iota": "ι", "kappa": "κ", "lambda": "λ", "mu": "μ", "nu": "ν",
        "xi": "ξ", "omicron": "ο", "pi": "π", "varpi": "ϖ", "rho": "ρ", "varrho": "ϱ", "sigma": "σ", "varsigma": "ς",
        "tau": "τ", "upsilon": "υ", "phi": "φ", "varphi": "φ", "chi": "χ", "psi": "ψ", "omega": "ω",
        "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ", "Xi": "Ξ", "Pi": "Π", "Sigma": "Σ",
        "Upsilon": "Υ", "Phi": "Φ", "Psi": "Ψ", "Omega": "Ω",
        // Operators and relations
        "cdot": "·", "times": "×", "div": "÷", "pm": "±", "mp": "∓", "ast": "∗", "star": "⋆", "circ": "∘",
        "bullet": "•", "oplus": "⊕", "otimes": "⊗", "odot": "⊙",
        "le": "≤", "leq": "≤", "ge": "≥", "geq": "≥", "leqslant": "≤", "geqslant": "≥", "ne": "≠", "neq": "≠",
        "approx": "≈", "equiv": "≡", "sim": "∼", "simeq": "≃", "cong": "≅", "propto": "∝", "ll": "≪", "gg": "≫",
        "lt": "<", "gt": ">", "coloneqq": "≔", "doteq": "≐",
        "sum": "∑", "prod": "∏", "coprod": "∐", "int": "∫", "iint": "∬", "iiint": "∭", "oint": "∮",
        "partial": "∂", "nabla": "∇", "infty": "∞", "degree": "°", "prime": "′",
        // Arrows
        "to": "→", "rightarrow": "→", "leftarrow": "←", "gets": "←", "leftrightarrow": "↔", "Rightarrow": "⇒",
        "Leftarrow": "⇐", "Leftrightarrow": "⇔", "implies": "⇒", "impliedby": "⇐", "iff": "⇔", "mapsto": "↦",
        "uparrow": "↑", "downarrow": "↓", "longrightarrow": "⟶", "longleftarrow": "⟵", "Longrightarrow": "⟹",
        "rightleftharpoons": "⇌", "hookrightarrow": "↪",
        // Sets and logic
        "in": "∈", "notin": "∉", "ni": "∋", "subset": "⊂", "subseteq": "⊆", "supset": "⊃", "supseteq": "⊇",
        "cup": "∪", "cap": "∩", "bigcup": "⋃", "bigcap": "⋂", "setminus": "∖", "emptyset": "∅", "varnothing": "∅",
        "forall": "∀", "exists": "∃", "nexists": "∄", "neg": "¬", "lnot": "¬", "land": "∧", "wedge": "∧",
        "lor": "∨", "vee": "∨", "top": "⊤", "bot": "⊥", "vdash": "⊢", "models": "⊨",
        "therefore": "∴", "because": "∵",
        // Geometry and misc
        "angle": "∠", "perp": "⊥", "parallel": "∥", "triangle": "△", "square": "□", "cdots": "⋯", "ldots": "…",
        "dots": "…", "vdots": "⋮", "ddots": "⋱", "langle": "⟨", "rangle": "⟩", "lfloor": "⌊", "rfloor": "⌋",
        "lceil": "⌈", "rceil": "⌉", "lbrace": "{", "rbrace": "}", "mid": "|", "vert": "|", "Vert": "‖",
        "hbar": "ℏ", "ell": "ℓ", "Re": "ℜ", "Im": "ℑ", "aleph": "ℵ", "wp": "℘", "checkmark": "✓", "dagger": "†",
        "S": "§", "copyright": "©", "backslash": "\\", "colon": ":",
    ]
}

# DeskPet

A little cartoon cat (default name **Mochi**) that lives on your Mac's screen and doubles as a
personal AI assistant. It walks along the Dock, hops onto your windows, naps, reacts when you
pet or throw it, and chats with you through a free local model, a free cloud model, or Claude.
Native Swift (AppKit + Core Graphics), all art drawn in code, no Dock icon.

## Build & run

```sh
./scripts/build_app.sh      # builds build/DeskPet.app
open build/DeskPet.app
```

Requires macOS 14+ and Swift 5.9+ (Command Line Tools are enough). To keep it around, copy
`build/DeskPet.app` to `/Applications` and turn on **Launch at Login** in the menu.

## Chatting

Press **⌃⌥C** anywhere, Option-click the pet, or choose **Chat…** from the menu-bar icon.
Replies stream into the chat window and the pet's mouth moves while it talks; a short
preview pops up in its speech bubble. **New Chat** starts fresh. History is saved in
`~/Library/Application Support/DeskPet/chat.json`.

No system prompt is sent, so the model answers as itself. To steer it, add your own text
under **Assistant → Custom Instructions…** (leave it empty for none).

### Choosing a brain (Assistant menu)

| Option | Cost | Setup |
|---|---|---|
| **Local** (Ollama) | Free, private, offline | `brew install ollama && brew services start ollama`, then `ollama pull gemma3:4b` |
| **Groq**, **Google Gemini**, **OpenRouter**, **Cerebras** | Free tier (limits apply) | Pick one; the key page opens; paste a free key |
| **Claude** | Paid API key | Paste a key from console.anthropic.com |

Keys are stored in your login Keychain. Cloud model lists are fetched live from each provider.
Free tiers can change, and some (like Google's) may use your conversations to improve their models.

Add more local models any time with `ollama pull <name>` (see ollama.com/library); they show up
in the menu. Test one from Terminal:

```sh
.build/release/MacPet --ask "Explain closures in Swift" gemma3:4b
```

## Playing with the pet

| Do this | It does this |
|---|---|
| Click | Waves, hops, or says hi |
| Double-click | Happy dance |
| Rub the cursor over it | Purrs, blushes, hearts |
| Drag and throw | Flails, flies, gets dizzy on a hard landing |
| Whip the cursor past it | Startles and "hides" behind a post |
| Menu → Give a Treat / Super Size / Nap | Eats, grows big for 15 s, sleeps |

On its own it wanders, sits, naps when tired, jumps onto the tops of windows (and rides along
when you drag them), and reads along while you type. Food, joy and energy drift over time.
**Pet** menu: rename, fur color (ginger, gray, charcoal, cream), size, follow cursor,
stand on windows, break reminders. No special macOS permissions are needed.

## Code map

| File | Role |
|---|---|
| `Pet.swift` | State machine, physics, reactions, moods, talking animation |
| `PetRenderer.swift` | Core Graphics drawing of the cat (static parts cached) |
| `PetWindow.swift` | Transparent panel, sprite layer, IOSurface rendering, speech bubble |
| `Assistant.swift` | Conversation, provider choice, streaming, persistence |
| `Backends.swift` | Streaming clients: Ollama, OpenAI-compatible clouds, Claude; Keychain |
| `ChatUI.swift` | Chat window |
| `World.swift` | Screens, Dock-safe floor, walkable window tops |
| `AppDelegate.swift` | Main loop (15/30/60 Hz adaptive), menus, hotkey |
| `Stats.swift` | Needs + settings persistence |
| `Sensors.swift` | Idle time, typing, battery |

Dev helpers: `MacPet --preview out.png` renders a pose sheet, `MacPet --bench` times rendering,
`MacPet --ask "question" [model]` streams a local reply, `PET_DEBUG=1` logs frame stats.

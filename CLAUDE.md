# Clotch

App macOS native (Swift/SwiftUI) qui affiche un compagnon animé dans le notch du MacBook, réagissant en temps réel à l'activité de Claude Code.

## Stack technique

- **Swift 5 / SwiftUI** — macOS 15.0+ (Sequoia)
- **Xcode project** généré via `xcodegen` depuis `project.yml`
- **Aucune dépendance externe** — pas de SPM packages
- **Sentiment** : `NLTagger` (framework NaturalLanguage d'Apple, 100% on-device, 0 token)

## Architecture

```
Clotch/
├── ClotchApp.swift              # @main entry point
├── AppDelegate.swift            # Lifecycle, init services, show panel
├── Core/                        # Fenêtre et notch
│   ├── NotchPanel.swift         # NSPanel .mainMenu+3, full-width, transparent
│   ├── NotchHitTestView.swift   # Click-through sélectif (screen coords)
│   ├── NotchShape.swift         # Shape animable pour le clip du notch
│   ├── NSScreen+Notch.swift     # Détection notch, taille, bezelPath
│   ├── AppSettings.swift        # UserDefaults + SMAppService (launch at login)
│   └── ScreenSelector.swift     # Sélection écran built-in
├── Models/                      # Données
│   ├── HookEvent.swift          # Événements Claude Code (Decodable) + cwd
│   ├── ClotchState.swift        # ClotchTask enum + SpinnerVerbs
│   ├── EmotionState.swift       # Scores émotionnels avec decay exponentiel
│   ├── SessionData.swift        # Session + ActivityItem + projectName
│   ├── UsageQuota.swift         # Quotas API Claude
│   └── NotificationSound.swift  # Sons système
├── Services/                    # Logique métier
│   ├── SocketServer.swift       # Unix socket /tmp/clotch.sock (listen + client queues)
│   ├── HookInstaller.swift      # Installation hooks nested dans ~/.claude/settings.json
│   ├── ClotchStateMachine.swift # Routage événements → sessions → UI + tasks + notifications
│   ├── SentimentAnalyzer.swift  # NLTagger on-device
│   ├── ConversationParser.swift # Parsing JSONL incrémental
│   ├── SessionStore.swift       # Multi-sessions
│   ├── UsageService.swift       # Lecture quotas OAuth Claude Code
│   ├── SoundService.swift       # Sons conditionnels + peek sound
│   ├── NotchPanelManager.swift  # Géométrie, expand/collapse, hit areas
│   ├── TerminalFocusDetector.swift
│   └── EventMonitor.swift       # Global mouse/keyboard events
├── UI/                          # Composants SwiftUI
│   ├── NotchContentView.swift   # Vue principale (clip shape notch) + peek extension
│   ├── ActivityRowView.swift    # Feed avec icônes tasks (☐ ■ ✅)
│   ├── UsageBarView.swift       # Barre usage (texte blanc, bar clampée)
│   └── ...
├── Views/                       # Vues composées
│   ├── ExpandedPanelView.swift  # Panel avec feed, island, usage, settings
│   ├── GrassIslandView.swift    # Île avec sprites (masquée si 0 session)
│   ├── PanelSettingsView.swift  # Settings + Author + Launch at Login
│   └── Components/
│       ├── SpriteSheetView.swift # 6 frames 64x64, pixel-perfect
│       └── BobAnimation.swift
└── Resources/
    ├── clotch-hook.sh           # Script hook (python3, envoie cwd + tool_input)
    └── Assets.xcassets/         # 16 sprite sheets (task×emotion), icône app, grass
```

## Pipeline événements

```
Claude Code hook → stdin JSON → clotch-hook.sh → python3 → Unix socket
→ SocketServer → HookEvent → ClotchStateMachine → SessionStore → SwiftUI
```

## Hooks supportés

| Hook | Usage |
|------|-------|
| `UserPromptSubmit` | Prompt utilisateur → working + sentiment |
| `PreToolUse` | Outil en cours → spinner + feed |
| `PostToolUse` | Outil terminé → retour working |
| `Stop` | Tâche finie → idle + notification macOS |
| `Notification` | Permission requise → peek sprite + son |
| `StopFailure` | Erreur API → notification |
| `PreCompact` / `PostCompact` | Compaction contexte → sprite compacting |
| `TaskCreated` / `TaskCompleted` | Tasks dans le feed (☐/✅) |
| `SubagentStop` | Fin subagent |

## Commandes de build

```bash
# Générer le projet Xcode
xcodegen generate

# Build debug
xcodebuild -scheme Clotch -configuration Debug build

# Build release + DMG
./scripts/build-dmg.sh
```

## Fichier de hooks Claude Code

Les hooks sont dans `~/.claude/settings.json` au format **nested** (obligatoire) :
```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "command": "~/.claude/hooks/clotch-hook.sh", "type": "command", "timeout": 5000 }] }
    ]
  }
}
```

Les hooks sont chargés au **démarrage de session**. Modifier settings.json nécessite de redémarrer Claude Code.

Le `HookInstaller` installe automatiquement les hooks au format nested au premier lancement.

## Peek (extension du notch)

Quand Claude attend une réponse (hook `Notification` ou tool `AskUserQuestion`), le notch s'élargit de 50pt à droite avec le sprite qui apparaît dans le prolongement. Même bezel, même hauteur — extension naturelle du notch.

## Points d'attention

- La fenêtre NSPanel couvre **toute la largeur de l'écran** (500pt de haut). Seule la zone notch (220pt large) est visible grâce au clip shape SwiftUI. Ne pas réduire la taille de la fenêtre.
- Le window level `.mainMenu + 3` est nécessaire pour apparaître au-dessus de la barre de menu.
- `isFloatingPanel = true` et `becomesKeyOnlyIfNeeded = true` sont obligatoires.
- Le socket `/tmp/clotch.sock` a les permissions `0600` (sécurité).
- Ne jamais ajouter d'appels API pour l'analyse de sentiment — tout doit rester on-device via NLTagger.
- Le `notchWidth` est hardcodé à 220pt — la détection via `auxiliaryTopLeftArea` donne une valeur trop large.
- Le hook script lit `hook_event_name` depuis le JSON stdin (pas depuis une env var).

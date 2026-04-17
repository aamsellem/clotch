# Clotch

Compagnon macOS pour Claude Code — un petit personnage animé vit dans le notch de votre MacBook et réagit en temps réel a votre activite.

**0 token consomme** — analyse de sentiment 100% on-device, aucun appel API.

## Fonctionnalites

- **Personnage anime dans le notch** — sprites pixel-art qui changent selon l'etat (idle, working, sleeping, happy, sad)
- **Suivi en temps reel** — voit quand Claude Code reflechit, utilise des outils, ou a termine
- **Peek notification** — le notch s'etend sur le cote quand Claude attend votre reponse (permission, question)
- **Analyse de sentiment on-device** — NLTagger d'Apple, aucun appel reseau, **0 token**
- **Tasks dans le feed** — suivi des taches Claude Code avec icones (cree/en cours/termine)
- **Nom du projet** — affiche le repertoire de travail au lieu d'un ID de session
- **Multi-sessions** — chaque session Claude Code a son propre sprite sur l'ile
- **Activity feed** — prompts utilisateur, tool uses, reponses assistant
- **Suivi des quotas** — barre de progression de l'utilisation API (lecture seule)
- **Notifications macOS** — quand Claude termine ou attend (si le terminal n'est pas focus)
- **Sons** — alertes sonores configurables, muettes quand le terminal est actif
- **Launch at Login** — demarrage automatique via SMAppService

## Securite

| | Autres apps | Clotch |
|---|---|---|
| Sentiment | API cloud (tokens) | NLTagger on-device (0 token) |
| Credentials | API key requise | Aucune cle requise |
| Socket | Variable | `/tmp/clotch.sock` (chmod 600) |
| Donnees envoyees | Prompts vers le cloud | Rien — tout reste local |

## Prerequis

- macOS 15.0+ (Sequoia)
- MacBook avec notch (fonctionne aussi sans, avec un pill flottant)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installe
- Xcode 16+ (pour builder depuis les sources)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Installation

### Depuis le DMG

1. Telecharger `Clotch-1.0.0.dmg` depuis les [releases](https://github.com/aamsellem/clotch/releases)
2. Ouvrir le DMG et glisser Clotch dans Applications
3. Lancer Clotch **avant** de demarrer une session Claude Code
4. Les hooks s'installent automatiquement au premier lancement

### Depuis les sources

```bash
git clone https://github.com/aamsellem/clotch.git
cd clotch
xcodegen generate
xcodebuild -scheme Clotch -configuration Release build

# Ou creer un DMG :
./scripts/build-dmg.sh
```

## Comment ca marche

```
Claude Code  ──hook──>  clotch-hook.sh  ──socket──>  Clotch.app
   (event)                (python3)              (state machine → UI)
```

1. Claude Code execute des **hooks** a chaque evenement (prompt, tool use, stop, permission)
2. Le hook script envoie un JSON au **socket Unix** `/tmp/clotch.sock`
3. La **state machine** de Clotch met a jour la session correspondante
4. L'**UI SwiftUI** reagit en temps reel (sprite, status dot, activity feed)

### Hooks supportes

| Hook | Reaction |
|------|----------|
| `UserPromptSubmit` | Sprite passe en working + sentiment |
| `PreToolUse` / `PostToolUse` | Spinner + nom de l'outil dans le feed |
| `Stop` | Idle + notification macOS si terminal pas focus |
| `Notification` | **Peek** — le notch s'etend avec le sprite |
| `StopFailure` | Notification d'erreur |
| `PreCompact` / `PostCompact` | Sprite en mode compacting |
| `TaskCreated` / `TaskCompleted` | Icones dans le feed |

## Configuration

Cliquez sur le notch pour ouvrir le panel, puis sur l'icone engrenage :

- **Show sprite** — afficher/masquer le personnage anime
- **Sentiment analysis** — activer/desactiver l'analyse on-device
- **Enable sounds** — notifications sonores
- **Launch at Login** — demarrage automatique

## Architecture

```
Clotch/
├── Core/         # NSPanel, NotchShape, hit testing, screen detection
├── Models/       # HookEvent, SessionData, EmotionState, UsageQuota
├── Services/     # SocketServer, StateMachine, SentimentAnalyzer, HookInstaller
├── UI/           # NotchContentView, ActivityRowView, UsageBarView
├── Views/        # ExpandedPanelView, GrassIslandView, PanelSettingsView
└── Resources/    # Sprite sheets pixel-art, hook script
```

## Auteur

**Aurelien Amsellem** — [github.com/aamsellem](https://github.com/aamsellem)

Built with Claude Code.

## Licence

MIT

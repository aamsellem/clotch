# Clotch

Compagnon macOS pour Claude Code — un petit personnage animé vit dans le notch de votre MacBook et réagit en temps réel à votre activité.

Inspiré de [notchi](https://github.com/sk-ruban/notchi), repensé pour la **sécurité** et l'**économie de tokens**.

## Fonctionnalités

- **Personnage animé dans le notch** — sprites pixel-art qui changent selon l'état (idle, working, sleeping, happy, sad)
- **Suivi en temps réel** — voit quand Claude Code réfléchit, utilise des outils, ou a terminé
- **Analyse de sentiment on-device** — utilise NLTagger d'Apple (NaturalLanguage framework), aucun appel réseau, **0 token consommé**
- **Multi-sessions** — chaque session Claude Code a son propre sprite sur l'île
- **Activity feed** — prompts utilisateur, tool uses, réponses assistant
- **Suivi des quotas** — barre de progression de l'utilisation API (lecture seule)
- **Sons de notification** — alertes sonores configurables, muettes quand le terminal est actif
- **Launch at Login** — démarrage automatique via SMAppService

## Sécurité

| | Notchi | Clotch |
|---|---|---|
| Sentiment | API Claude Haiku (tokens) | NLTagger on-device (0 token) |
| Credentials | API key dans Keychain | Aucune clé requise |
| Socket | `/tmp/notchi.sock` | `/tmp/clotch.sock` (chmod 600) |
| Données envoyées | Prompts vers API Anthropic | Rien — tout reste local |

## Prérequis

- macOS 15.0+ (Sequoia)
- MacBook avec notch (fonctionne aussi sans, avec un pill flottant)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installé
- Xcode 16+ (pour builder depuis les sources)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Installation

### Depuis le DMG

1. Télécharger `Clotch-1.0.0.dmg` depuis les releases
2. Ouvrir le DMG et glisser Clotch dans Applications
3. Lancer Clotch **avant** de démarrer une session Claude Code
4. Les hooks s'installent automatiquement au premier lancement

### Depuis les sources

```bash
git clone <repo-url> clotch
cd clotch
xcodegen generate
xcodebuild -scheme Clotch -configuration Release build

# Ou créer un DMG :
./scripts/build-dmg.sh
```

## Comment ça marche

```
Claude Code  ──hook──>  clotch-hook.sh  ──socket──>  Clotch.app
   (event)                (python3)              (state machine → UI)
```

1. Claude Code exécute des **hooks** à chaque événement (prompt, tool use, stop)
2. Le hook script envoie un JSON au **socket Unix** `/tmp/clotch.sock`
3. La **state machine** de Clotch met à jour la session correspondante
4. L'**UI SwiftUI** réagit en temps réel (sprite, status dot, activity feed)

## Configuration

Cliquez sur le notch pour ouvrir le panel, puis sur l'icône ⚙️ :

- **Show sprite** — afficher/masquer le personnage animé
- **Sentiment analysis** — activer/désactiver l'analyse de sentiment on-device
- **Enable sounds** — notifications sonores
- **Launch at Login** — démarrage automatique

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

## Licence

MIT

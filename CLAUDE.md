# Server Rush — Data Center Tycoon

## Project Info
- **Repo**: https://github.com/Mukund2/ServerRush
- **Stack**: SpriteKit + SwiftUI overlay, iOS 17+, XcodeGen
- **Purpose**: Mistral AI Worldwide Hackathon (Feb 28 - Mar 1, 2026). Supercell sponsors video game award.
- **Build**: `cd /Users/mukund/Projects/ServerRush && xcodegen generate && xcodebuild -project ServerRush.xcodeproj -scheme ServerRush -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- **Current state**: Compiles and runs. Architecture is solid (21 Swift files, 3800 lines). BUT the game is not playable — it's a skeleton with cold cyberpunk colors and no game feel. Needs full overhaul.

---

## BRANCH RULES (READ THIS FIRST)

- **`main` is the hackathon submission. DO NOT merge anything into `main`.**
- The `cozy-overhaul` branch is a post-hackathon visual overhaul (wood panel UI, grass tufts, butterflies, etc.). It is a **separate side project** — do NOT merge it into `main`.
- New work should branch off `main` or `cozy-overhaul` as appropriate. Never merge either direction without explicit user approval.

---

## GAME DESIGN DECISIONS (User-confirmed, do not change)

### Core Gameplay Loop
- **Incident-focused** — incidents are the STAR of the gameplay, not just a side mechanic
- Building/placing equipment is the setup phase; responding to incidents is the actual game
- Constant stream of problems to solve, more like a firefighting/whack-a-mole game
- Fast-paced, satisfying, never boring

### Incident Resolution Mechanic
- **Drag tools to fix** — each incident type has a specific tool:
  - Overheating → drag fire extinguisher to the rack
  - DDoS Attack → drag shield to the rack
  - Power Outage → drag wrench/generator to the rack
  - Cable Failure → drag cable/plug to the rack
- Tools appear as draggable icons when incident is active
- Drag-and-drop feels satisfying with snap animation + particles on resolve
- Takes 1-3 seconds per incident (fast, not tedious)

### Map & Progression
- **One endless map that grows** (NOT 3 separate levels)
- Start with a small area (like a closet), buy expansion tiles at the edges with coins
- Visual "buy this area" tiles with coin price shown (like Hay Day's land expansion)
- No level transitions — continuous growth of your data center
- Milestones unlock new equipment types as you grow
- Revenue goals still exist but as milestones, not level gates

### Visual Style
- **Hay Day / Stardew Valley** — warm earth tones, wood textures, cream backgrounds
- Warm color palette:
  - Backgrounds: warm cream (#F5E6D3), soft tan (#E8D7C6)
  - Primary accent: warm orange (#E8985E)
  - Secondary: warm gold (#D4A574)
  - Positive: warm sage green (#7DB77D)
  - Warning: warm amber
  - Critical: warm rust (#D85B56)
  - Text: dark brown (#3D2B1F), warm gray (#8B7355)
- Rounded sans-serif fonts (SF Pro Rounded), NOT monospaced
- Wood textures, soft shadows, rounded corners everywhere
- Equipment should look charming, not technical

### AI Guide Character
- **Ambient + tappable** — walks around the data center as a sprite
- Named character with personality (not "AI GUIDE")
- Walks around, periodically speaks ambient tips (voiced via ElevenLabs)
- Player can tap to ask questions/chat (Mistral generates text, ElevenLabs speaks)
- Reacts to events: runs toward incidents, cheers on builds, celebrates milestones
- **NOT integral to gameplay** — game works perfectly without API. Fallback dialogue strings.
- ElevenLabs integration point: user sets up voice separately

### Game Feel Requirements
- **Every action produces feedback**: visual + haptic + UI response
- Building: bounce-in + dust puff particles + haptic + cost animation
- Revenue: coin sprites float from racks toward HUD
- Incidents: telegraph 2 sec before → dramatic appearance → satisfying drag-to-fix → celebration
- Clear objectives always visible on screen
- Milestone popups for achievements
- Save progress to UserDefaults (expansion state, money, equipment, unlocks)

---

## ANTI-PATTERNS (DO NOT DO THESE)
- No dark/cyberpunk/corporate colors (no dark navy backgrounds, no neon cyan)
- No "AI-generated" looking color schemes
- No monospaced fonts except money counter
- No engineering dashboards pretending to be games
- No walls of stats/numbers
- No cold/sterile UI
- No sharp geometric shapes — use rounded, warm, organic shapes

---

## Architecture Reference

```
SwiftUI Layer (HUD, menus, chat) ←→ GameState (@Observable) ←→ SpriteKit (iso world, sprites, particles)
```

### Key Files
- `Theme.swift` — centralized design system (colors, fonts, spacing)
- `Models/GameState.swift` — @Observable central state, save/load via UserDefaults
- `Game/GameScene.swift` — main SKScene, isometric rendering, particles, animations
- `Game/IsometricUtils.swift` — coordinate math + programmatic texture generation
- `Game/SimulationEngine.swift` — 1-sec tick: revenue, resources, damage, milestones
- `Game/IncidentScheduler.swift` — random event spawning with telegraph system
- `Game/InputHandler.swift` — touch handling, drag-to-fix incidents
- `Game/CameraController.swift` — pinch zoom + pan with inertia
- `Views/*` — all SwiftUI overlay views
- `Services/MistralService.swift` — Mistral API for guide chat
- `Services/AudioManager.swift` — haptic feedback patterns

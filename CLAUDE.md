# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Product Overview

**ReFocus** is a personalized focus and time management assistant for iOS and macOS. It automatically selects the most suitable time management method based on user focus profiles and reduces distractions through gentle guidance.

**This is NOT a Pomodoro app.** It's a focus assistant that answers: "How should I work most productively today?"

## Core Product Philosophy

These principles MUST guide all technical decisions:

- **No decision burden on users** - Personalization is done through behavior observation, not settings
- **The app guides, never forces or judges** - No blocking, only awareness
- **UI stays in the background, focus comes forward** - Minimal, calm interface
- **No gamification** - No badges, leaderboards, or social features
- **The product is a calm coach, not a discipline tool**

## Development Commands

### iOS Development
```bash
# Open Xcode project
open ReFocus.xcodeproj

# Run on simulator
xcodebuild -scheme ReFocus -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Run tests
xcodebuild test -scheme ReFocus -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run single test
xcodebuild test -scheme ReFocus -only-testing:ReFocusTests/ProfileEngineTests
```

### macOS Development
```bash
# Run on macOS
xcodebuild -scheme ReFocus -destination 'platform=macOS' build

# Run tests
xcodebuild test -scheme ReFocus -destination 'platform=macOS'
```

## High-Level Architecture

### 1. Profile System
The core intelligence of the app. Consists of:

- **Onboarding Module** - 4 questions, max 30 seconds
  - Work type
  - When user struggles (10-15min / 20-30min / 40+min)
  - What's hardest (starting / continuing / finishing)
  - Phone checking frequency

- **Profile Types** (never shown to user):
  - Short Focus (Kısa Odaklı)
  - Medium Focus (Orta Odaklı)
  - Deep Focus (Derin Odaklı)
  - Fluctuating Focus (Dalgalı Odaklı)

- **Profile Engine** - Observes behavior and adjusts recommendations over time

### 2. Method Selection Engine (MVP: Rule-Based)

**Not AI-required for MVP.** Simple rule-based system:

```
IF attention < 20min → Pomodoro (25/5)
IF Pomodoro feels short → 40/10
IF uninterrupted work is high → Deep Work (90min)
IF frequently interrupted during day → 52/17
```

Four methods available in MVP:
- Pomodoro (25/5)
- Extended Focus (40/10)
- Optimal (52/17)
- Deep Work (90min)

### 3. Interruption Tracking System

**Critical:** This is behavioral observation, NOT blocking.

Measured behaviors:
- App backgrounding events
- Return time duration
- Total interruption time per session

**Display to user:** Visual flow bars, not raw numbers
- `┃█████░░██░████░░░████┃` - Filled = focus, gaps = interruptions
- Text: "Odak akışın genel olarak korundu" (Your focus flow was generally maintained)

### 4. Gentle Nudge Microcopy System

All messages must be:
- Non-judgmental
- Normalizing
- Empowering

Examples from design doc:
- Session start: "Bu seans sırasında dikkatin dağılabilir. Fark ettiğinde geri dönmen yeterli."
- Background 30-60s: "Bir süreliğine ara verdin. Hazırsan kaldığın yerden devam edebiliriz."
- Long interruption (2-3min): "Dönmek zor olabilir. İstersen bu seansı kısa tutabiliriz."

**Never:** Blame, shame, or pressure the user.

### 5. Feedback Loop

After each session, collect lightweight feedback:
- Was it difficult?
- Did you stay focused?
- Was the duration appropriate?

This data refines the profile and method selection.

### 6. Daily Summary & Retrospective

End-of-day shows:
- Total focus time
- Method used
- Tomorrow's recommendation

Weekly/monthly heatmap:
- Color intensity = focus flow quality
- No numbers, no comparisons
- Text like: "Geçen haftaya göre daha hızlı geri dönüyorsun"

Status indicators (no red, no judgment):
- 🟢 Stable (Stabil)
- 🟡 Fluctuating (Dalgalı)
- 🔵 Tough Day (Zor Gün)

## Screen Architecture (MVP: 6 Screens)

1. **Onboarding** - Card-based questions with progress bar
2. **Daily Recommendation (Home)** - Shows recommended method, single CTA: "Başla"
3. **Focus Screen** - Large timer, smooth animation, calming background
4. **Break Screen** - Countdown, gentle break suggestions
5. **Session End Feedback** - Quick reflection questions
6. **Day End Summary** - Total focus time, method used, tomorrow's suggestion

## Design System

### Colors
```swift
// Primary
let primaryGreen = Color(hex: "#2E7D6F") // Focus Green
let background = Color(hex: "#F6F8F7")
let cardWhite = Color(hex: "#FFFFFF")
let breakBlue = Color(hex: "#E8F1F8")
let gentleWarning = Color(hex: "#FFF4E5")
```

### Typography
- Font: SF Pro (iOS native) / Inter (fallback)
- Headings: Semibold
- Body: Regular
- Timer: Medium/Semibold

### Style Principles
- Minimal
- Rounded corners
- Generous whitespace
- Subtle animations
- Never aggressive or attention-grabbing

## Ambient Sounds

**Decision:** ✅ Yes, but limited

- 3-4 ambient/white noise tracks
- Default: OFF
- Recommended especially for Deep Work mode
- Goal: Environmental feel, not music

## Notification Strategy

### NEVER Do:
- Continuous push notifications
- Random "start working" reminders
- Blaming language

### MVP Notifications:
- Daily start reminder (optional)
- Session end notification
- Silent end-of-day summary

## Out of Scope for MVP

The following should NOT be implemented:
- Task lists
- Calendar integration
- Social features
- Badges/leaderboards
- Forced blocking mechanisms
- Multiple ambient sound playlists
- Complex statistics and comparisons

## Testing Considerations

When writing tests:
- Test profile classification logic thoroughly
- Test method selection rules
- Verify interruption tracking accuracy
- Test feedback loop data persistence
- Ensure all microcopy is non-judgmental
- Verify animations are smooth and calming

## Code Style Notes

- Use SwiftUI for UI (modern, declarative)
- Combine framework for reactive data flow
- Keep business logic separate from UI
- Profile engine should be testable independently
- All user-facing strings must be localizable
- Interruption tracking should handle app lifecycle events properly

## Important Constraints

1. **Never block** - The app observes and guides, never restricts access
2. **Never judge** - All language must be empowering and normalizing
3. **No decision fatigue** - Minimize settings, maximize automatic behavior
4. **Calm > Productive** - UI should reduce anxiety, not increase it
5. **Privacy first** - All data stays local, no tracking beyond app usage

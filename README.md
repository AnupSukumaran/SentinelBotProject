# SentinelBot iOS

iOS companion app for the SentinelBot autonomous surveillance robot. SwiftUI + Combine + MQTT.

## Quick start

1. **Open** `SentinelBot.xcodeproj` in Xcode 15 or later.
2. **Add CocoaMQTT** — needed for Phase B onwards:
   - `File → Add Package Dependencies…`
   - URL: `https://github.com/emqx/CocoaMQTT`
   - Select **CocoaMQTT** (not the Web variant) when prompted, add it to the **SentinelBot** target.
3. **Build and run** (⌘R) — you should see the SentinelBot placeholder screen on the simulator.
4. **Run tests** (⌘U) — all model tests should pass.

> **Why no CocoaMQTT yet?** The package needs to be resolved by Xcode itself (it can't be checked in). The current code base only references it from files that arrive in Phase B — until then the project compiles without it.

## Phase status

| Phase | Status | What's in it |
|---|---|---|
| **A** | ✅ Done | Models, Service protocols, Persistence (full), AppContainer, Logger, Constants, Tests for models |
| **B** | 🚧 Next | Real `MQTTService` (CocoaMQTT delegate → Combine), `CommandService`, `TelemetryService` |
| **C** | ⏳ | Settings + Connection screens, broker config persistence wired through |
| **D** | ⏳ | Joystick + ControlView, talking to real Mosquitto |
| **E** | ⏳ | Telemetry view: distance gauge, battery, alert banner |
| **F** | ⏳ | Position map, polish |

## MQTT topic contract

Topics defined in `Core/Utilities/Constants.swift` must match the robot-side `mqtt_bridge_node.py`:

| Direction | Topic | Payload |
|---|---|---|
| iOS → Pi | `sentinelbot/cmd/move` | `MoveCommand` JSON |
| iOS → Pi | `sentinelbot/cmd/mode` | `ModeCommand` JSON |
| iOS → Pi | `sentinelbot/cmd/estop` | `EmergencyStopCommand` JSON |
| Pi → iOS | `sentinelbot/status/distance` | `DistanceReading` JSON |
| Pi → iOS | `sentinelbot/status/battery` | `BatteryStatus` JSON |
| Pi → iOS | `sentinelbot/status/position` | `Position` JSON |
| Pi → iOS | `sentinelbot/status/mode` | `ModeStatus` JSON |
| LWT/Retained | `sentinelbot/presence/robot` | `"online"` / `"offline"` |

## Architecture

MVVM + protocol-based service layer. See `SentinelBot_iOS_Architecture.md` (separate doc) for the full breakdown.

```
View (SwiftUI)
   ↓ binds to @Published
ViewModel (@MainActor ObservableObject)
   ↓ calls protocol
Service (MQTT, Command, Telemetry, Persistence)
   ↓ uses
Models (pure Swift, Codable)
```

The `MQTTServiceProtocol` is the keystone — every other service depends on it through that protocol, never on CocoaMQTT directly. That means swapping libraries (or moving to URLSession WebSockets) is a one-file change, and tests run instantly with `MockMQTTService`.

## Project layout

```
SentinelBot/
├── SentinelBotApp.swift              App entry point + AppContainer
├── Core/
│   ├── Models/                        Pure data, all Codable
│   ├── Services/                      Protocols + PersistenceService
│   ├── Extensions/                    Color+Theme
│   └── Utilities/                     Logger, Constants, Haptic
├── Features/                          Per-feature MVVM (Phase C onward)
│   ├── Control/
│   ├── Telemetry/
│   ├── Map/
│   ├── Settings/
│   └── Connection/
├── Resources/
│   └── Assets.xcassets
└── Preview Content/
    └── Preview Assets.xcassets

SentinelBotTests/
├── Models/                            Codable + validation tests
├── Mocks/                             MockMQTTService for ViewModel tests
├── ViewModels/                        (populated in Phases C–E)
└── Services/                          (populated in Phase B)
```

## Notes

- **Deployment target**: iOS 16.0
- **Bundle ID**: `com.sentinelbot.app` — change to your own before signing
- **Code signing**: set to "Automatic". Pick a team in Signing & Capabilities before running on device.
- **Orientation**: portrait + landscape both supported (the joystick view in Phase D works better in landscape)

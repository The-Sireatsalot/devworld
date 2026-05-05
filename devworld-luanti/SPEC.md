# DevWorld — Luanti Edition

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  DevWorld Luanti Server (port 30001)                        │
│  ts4.zocomputer.io:10617 (TCP, public)                    │
│  Minetest 5.6.1 — Flat void world with glowing buildings   │
│  /home/workspace/devworld-luanti/                          │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│  DevWorld Web Client (https://devworld-crusius.zocomputer.io)│
│  React Three Fiber — 3D spatial IDE overlay                 │
│  WebSocket bridge to Luanti for real-time state             │
└─────────────────────────────────────────────────────────────┘
```

## Luanti Server

- **Address:** `ts4.zocomputer.io:10617` (public TCP)
- **Protocol:** Minetest native UDP-over-TCP
- **Download:** https://www.luanti.org/download/

## Installation

1. Download Luanti client for your OS (Windows/Mac/Linux/Android)
2. Open game, go to "Play" → "Add Server"
3. Enter: `ts4.zocomputer.io` port `10617`
4. Click Connect

## Console Commands

Once connected, use chat for DevWorld commands:

- `/devworld list` — List all buildings
- `/devworld go <id>` — Teleport to a building (e.g., `/devworld go api-gateway`)
- `/devworld teleport` — Return to spawn
- `/devworld reload` — Regenerate the world

## Building Map

| Building | Type | Description |
|----------|------|-------------|
| API Gateway | gateway | Central routing hub |
| Auth Service | service | JWT & session management |
| User Service | service | User profiles & accounts |
| Payment Service | service | Stripe & billing |
| Postgres (Main) | database | Primary relational DB |
| Redis Cache | database | In-memory cache |
| Message Queue | queue | Async job processing |
| Notification Fn | function | Email & push notifications |

## Luanti → Web Bridge (TODO)

- [ ] WebSocket server on Zo that bridges Minetest protocol ↔ web
- [ ] Real-time building status synced to web HUD
- [ ] Click building in Luanti → opens file in web editor
- [ ] Web editor changes → reflected in Luanti world

## Mod Structure

```
/home/workspace/devworld-luanti/
├── worldmods/devworld/
│   ├── mod.conf          — Mod metadata
│   ├── init.lua          — Main game logic
│   └── textures/         — All texture files (24 textures)
├── world/                — Minetest world data
│   └── worldmods/devworld → symlink to worldmods/devworld
└── minetest.conf         — Server config
```
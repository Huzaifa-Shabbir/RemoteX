# RemoteX

> **Control your Windows PC from your phone — wirelessly, in real time.**

RemoteX is a full-stack remote desktop control system that lets you stream your PC screen to a mobile device and send touch gestures back as mouse/keyboard input. Pair over your local network using a QR code, share files between devices, and manage everything through polished Flutter UIs on both ends.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Repository Structure](#repository-structure)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [1. Backend Server](#1-backend-server)
  - [2. Windows Desktop App](#2-windows-desktop-app)
  - [3. Mobile App](#3-mobile-app)
- [Environment Variables](#environment-variables)
- [How Pairing Works](#how-pairing-works)
- [API Reference](#api-reference)
- [Project Structure Deep-Dive](#project-structure-deep-dive)
- [License](#license)

---

## Overview

RemoteX is split across three sub-projects that work together:

| Sub-project | Description |
|---|---|
| `remote_desktop_controller_windows` | Flutter desktop app — runs on the PC being controlled. Captures the screen, streams it over WebSocket/UDP, and receives input commands. |
| `remote_desktop_controller_mobile` | Flutter mobile app — runs on Android/iOS. Receives the screen stream and translates touch gestures into remote control signals. |
| `remotex_server` | Node.js/Express backend — handles auth (via Supabase JWT), device registry, file sharing, and session management (MongoDB). |

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                   RemoteX System                     │
│                                                      │
│  ┌─────────────┐   QR Pairing    ┌────────────────┐  │
│  │  Mobile App │◄──────────────►│   Windows App  │  │
│  │  (Flutter)  │   WebSocket     │   (Flutter)    │  │
│  │             │   UDP Stream    │                │  │
│  └──────┬──────┘                 └───────┬────────┘  │
│         │                                │           │
│         │    REST API (JWT-protected)     │           │
│         └──────────────┬─────────────────┘           │
│                        ▼                             │
│              ┌─────────────────┐                     │
│              │  remotex_server │                     │
│              │  (Node/Express) │                     │
│              └────────┬────────┘                     │
│                       │                              │
│            ┌──────────┴──────────┐                   │
│            ▼                     ▼                   │
│       ┌─────────┐         ┌──────────────┐           │
│       │ MongoDB │         │   Supabase   │           │
│       │(devices,│         │ (auth +      │           │
│       │sessions,│         │  file store) │           │
│       │ files)  │         └──────────────┘           │
│       └─────────┘                                    │
└──────────────────────────────────────────────────────┘
```

The Windows app captures the desktop via shared memory (FFI + native C++ bindings), encodes frames, and streams them over WebSocket/UDP to the mobile app. Touch input from the phone is sent back as control signals, which the Windows app replays as actual mouse/keyboard events.

---

## Features

### 🖥️ Windows Desktop App
- **Live screen streaming** — captures the desktop using native C++ shared memory and streams encoded frames
- **Remote input control** — receives gesture input from the mobile app and replays it as real mouse/keyboard events
- **QR code pairing** — generates a QR payload (`ip:udp_port:ws_port`) for one-tap mobile connection
- **Shared folder** — upload/download files to and from the paired mobile device
- **Dark/Light theme** — persistent theme toggle with a polished sidebar-based dashboard UI
- **Supabase authentication** — sign in / sign up with session persistence

### 📱 Mobile App
- **Screen receiver** — renders the live stream from the PC in real time
- **Gesture input** — translates taps, drags, and swipes into remote control commands
- **QR scanner** — scan the PC's pairing QR code to connect instantly
- **Shared folder** — browse and preview files (images, PDFs, videos, audio) shared from the PC
- **Dark/Light theme** — system-aware, toggleable theming
- **Supabase authentication** — same account works across both apps

### 🌐 Backend Server
- **JWT-protected REST API** — all routes verified via Supabase Auth tokens
- **Device registry** — create and list devices (PC/mobile) per user
- **File management** — upload to Supabase Storage, metadata stored in MongoDB, served via signed URLs
- **Session management** — track pairing sessions (waiting → active → ended)
- **Pair token system** — 5-minute expiring tokens for secure device pairing

---

## Repository Structure

```
huzaifa-shabbir-remotex/
├── remote_desktop_controller_mobile/   # Flutter mobile app (Android, iOS, Windows)
│   └── lib/
│       ├── main.dart
│       ├── connection/                 # WebSocket state & gesture input
│       ├── receiver/                   # Screen stream receiver
│       ├── screens/                    # All UI screens
│       │   ├── home_screen.dart
│       │   ├── qr_scan_screen.dart     # QR pairing
│       │   ├── connection_flow_screen.dart
│       │   ├── shared_folder_screen.dart
│       │   ├── sign_in_screen.dart
│       │   └── sign_up_screen.dart
│       ├── theme/                      # Theme controller & theming
│       └── webrtc/                     # Logger
│
├── remote_desktop_controller_windows/  # Flutter Windows desktop app
│   └── lib/
│       ├── main.dart
│       ├── dashboard_page.dart         # Main sidebar dashboard + QR dialog
│       ├── screen_streaming_page.dart  # Stream viewer
│       ├── shared_folder_page.dart     # File sharing UI
│       ├── core/
│       │   ├── streaming/              # WebSocket input, streaming service,
│       │   │                           # remote control, encode & resize, pairing state
│       │   ├── Screen Capture/         # Shared memory reader (FFI)
│       │   ├── theme/                  # App theme, colors, provider, toggle
│       │   └── ui/                     # Global messenger
│       ├── features/
│       │   ├── auth/                   # Supabase sign-in/up pages + service
│       │   └── shared/                 # File service + file preview pages
│       └── native/                     # FFI bindings for native screen capture
│
└── remotex_server/                     # Node.js/Express backend
    ├── server.js                       # Entry point
    ├── database.js                     # MongoDB connection
    ├── config/
    │   └── supabase.js                 # Supabase client
    ├── middleware/
    │   └── auth.js                     # JWT verification middleware
    ├── models/
    │   ├── Device.js                   # Device schema
    │   ├── File.js                     # File metadata schema
    │   └── Session.js                  # Session schema
    └── routes/
        ├── deviceRoutes.js             # POST /devices/create, GET /devices
        ├── fileRoutes.js               # Upload, list, get (signed URL), delete
        └── pairRoutes.js               # POST /pair/create, POST /pair/connect
```

---

## Tech Stack

**Mobile & Desktop Apps**
- [Flutter](https://flutter.dev/) / Dart
- `supabase_flutter` — authentication & storage client
- `mobile_scanner` — QR code scanning
- `qr_flutter` — QR code generation (Windows app)
- `provider` — state management
- `syncfusion_flutter_pdfviewer` — in-app PDF preview
- `video_player` / `just_audio` — media preview
- `flutter_dotenv` — environment config

**Backend Server**
- [Node.js](https://nodejs.org/) + [Express 5](https://expressjs.com/)
- [MongoDB](https://www.mongodb.com/) + [Mongoose](https://mongoosejs.com/) — device, file, and session data
- [Supabase](https://supabase.com/) — authentication (JWT) + file storage
- `multer` — file upload handling
- `ws` — WebSocket support
- `jsonwebtoken` / `jwks-rsa` — token verification

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- [Node.js](https://nodejs.org/) v18+
- A [Supabase](https://supabase.com/) project with:
  - Auth enabled
  - A storage bucket named `remotex-files`
- A [MongoDB](https://www.mongodb.com/) instance (local or Atlas)

---

### 1. Backend Server

```bash
cd remotex_server
npm install
```

Create a `.env` file (see [Environment Variables](#environment-variables)), then:

```bash
# Development (with auto-reload)
npm run dev

# Production
npm start
```

The server starts on port `3000` by default. Visit `http://localhost:3000` — you should see `Remotex backend running 🚀`.

---

### 2. Windows Desktop App

```bash
cd remote_desktop_controller_windows
flutter pub get
```

Create a `.env` file in the project root:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
BACKEND_URL=http://localhost:3000
```

Run on Windows:

```bash
flutter run -d windows
```

---

### 3. Mobile App

```bash
cd remote_desktop_controller_mobile
flutter pub get
```

Create a `.env` file in the project root:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
BACKEND_URL=http://your-local-ip:3000
```

> **Note:** Use your machine's local IP address (e.g. `192.168.1.x`), not `localhost`, so the mobile device can reach the server over your network.

Run on Android or iOS:

```bash
flutter run
```

---

## Environment Variables

### `remotex_server/.env`

| Variable | Description |
|---|---|
| `PORT` | Server port (default: `3000`) |
| `MONGO_URI` | MongoDB connection string |
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anon/public key (used by auth middleware) |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key (used for storage operations) |

---

## How Pairing Works

RemoteX uses a direct local-network connection for low-latency screen streaming:

1. The **Windows app** resolves its local IP and starts WebSocket + UDP servers on configurable ports.
2. It generates a QR code encoding the payload: `ip:udp_port:ws_port` (e.g. `192.168.1.10:5000:8080`).
3. The **mobile app** scans the QR code, parses the IP and ports, and opens connections to both servers.
4. The Windows app begins streaming encoded frames over UDP; the mobile app renders them in real time.
5. Touch gestures on the mobile are sent back over WebSocket as control events.

For cloud-assisted pairing (via the backend), the pair token route creates a short-lived 5-minute token that the mobile app can use to discover the PC's device ID without needing to scan a QR code.

---

## API Reference

All routes except the health check require a valid Supabase JWT in the `Authorization: Bearer <token>` header.

### Devices

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/devices/create` | Register a new device (`deviceName`, `deviceType`: `pc` or `mobile`) |
| `GET` | `/devices` | List all devices belonging to the authenticated user |

### Files

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/files/upload` | Upload a file (multipart/form-data, field: `file`) |
| `GET` | `/files` | List all files uploaded by the authenticated user |
| `GET` | `/files/:id` | Get a signed URL for a specific file (valid for 60 seconds) |
| `DELETE` | `/files/:id` | Delete a file from storage and database |

### Pairing

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/pair/create` | Create a 5-minute pairing token for a device |
| `POST` | `/pair/connect` | Connect using a pairing token; returns the paired device ID |

### Health

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/` | Health check — returns `"Remotex backend running 🚀"` |

---

## Project Structure Deep-Dive

### Screen Capture Pipeline (Windows)

The Windows app uses FFI bindings (`native/remote_capture_ffi.dart`) to call into native C++ code that reads desktop frames from shared memory. The `shared_Memory_Reader.dart` module handles the shared memory interface. Frames are then passed to `resize_And_Encode.dart` for compression before being pushed out by `streaming_service.dart`.

### Remote Input (Windows)

`websocket_Input.dart` listens for incoming control messages over WebSocket. `remote_control_service.dart` translates those messages into Win32 input events (mouse move, click, scroll, keyboard).

### Gesture Input (Mobile)

`gesture_Input.dart` captures touch events from the mobile screen and serializes them into control messages sent to the Windows app's WebSocket server.

### Authentication Flow

Both apps use `supabase_flutter` for sign-in/sign-up. The resulting JWT is stored and attached to all backend API requests. The server's `auth.js` middleware calls `supabase.auth.getUser(token)` to verify every request.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

*Built with Flutter & Node.js by Huzaifa Shabbir*

# MeshCore SAR

Flutter app for Search and Rescue operations over a [MeshCore](https://github.com/meshcore-dev) mesh radio network via Bluetooth Low Energy.

## What It Does

MeshCore SAR helps teams coordinate in low-connectivity or no-connectivity environments using mesh radio + BLE.

- Send text messages to contacts, rooms, and channels
- Share voice clips and field images
- Track team movement and location updates
- Work with offline maps and field overlays
- Mark and share SAR points of interest

## Core Features

### Messaging

- Direct and group chat over mesh
- Contact and room awareness from live mesh telemetry
- Message overlays integrated with map and tactical tools

### Voice

- Push-to-talk voice clips optimized for low bandwidth
- Voice is fetched on demand when someone presses play
- Automatic playback when fetch completes
- Works well for short field updates where text is too slow

### Images

- Capture from camera or pick from gallery
- Automatic compression before sending (optimized for mesh transport)
- Receiver sees a placeholder and taps to load the image
- Full-screen image viewer for quick field inspection

### Maps & Navigation

- Multiple base maps (street, topo, satellite, terrain)
- Offline tile download for selected areas
- Optional MBTiles import for custom/offline map packages
- Team member markers with freshness indicators
- SAR markers (person found, fire, staging, custom object markers)
- Compass-assisted orientation and target direction UI

### Tracking & Trails

- Continuous GPS tracking with configurable update thresholds
- Personal trail recording with distance and duration stats
- Contact trail visibility controls
- GPX export/import for trail sharing and reuse

### Tactical Drawing

- Draw lines/rectangles directly on map
- Distance measurement mode
- Share drawings to channel/room
- Toggle received drawings and SAR marker visibility

## Permissions (App Use)

- Bluetooth: mesh device communication
- Location: team tracking and map position updates
- Microphone: voice clip recording
- Camera / Photos: image messaging

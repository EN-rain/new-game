# M0 baseline — 2026-07-16

## Environment

- OS: Windows 11 Pro 10.0.26100
- CPU: Intel Core i5-1135G7, 4 cores / 8 logical processors
- RAM: 16,952,647,680 bytes
- GPU: Intel Iris Xe Graphics
- Godot: 4.6.2.stable.mono.official.71f334935
- .NET SDK: 8.0.401
- Client: desktop-only, Windows x86_64 baseline

## Foundation measurements

- `dotnet build` Debug (warm restore): 1.14 seconds, 0 warnings, 0 errors
- `dotnet build` Release (warm restore): 0.85 seconds, 0 warnings, 0 errors
- Pure unit tests: 3 passed in 26 ms
- Godot startup `Main::Setup2`: 0.318303 seconds
- Autoload load: 0.480880 seconds
- Main scene load: 0.035982 seconds
- `Main::Start`: 0.517637 seconds

## Runtime status

- Isolated mixed-language integration scene: pass
- Existing GDScript smoke scenes: 4 passed
  - Slime detection/death: 2,562 ms process elapsed
  - Overlay pause: 1,452 ms process elapsed
  - Round popup timing: 6,429 ms process elapsed
  - Lancer solo: 3,543 ms process elapsed
- Windows x86_64 Debug export: 100,919,296-byte executable; graphical process remained healthy for the five-second launch gate
- Windows x86_64 Release export: 104,790,528-byte executable; graphical process remained healthy for the five-second launch gate
- Existing auth main scene in headless mode: blocked by Godot signal 11 after startup; benchmark data above was written before the crash
- Solo representative run: not measured in M0 automation
- Multiplayer representative run: not measured; requires backend and two clients
- Managed allocations/GC/frame/physics percentiles: not measured
- Save/load and reconnect latency: not measured

Do not use the startup-only numbers or smoke-scene process durations as gameplay performance baselines. M0 remains gated on representative full solo/multiplayer runs for frame, physics, allocation, GC, network, save/load, and reconnect metrics.

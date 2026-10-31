# Changelog

## 1.0.0 - 2026-10-06

- First release of the OXLYN Series core.
- Mutual handshake with every OXLYN script (per-product keys, fresh nonce on each verification, replay refused).
- Registry of connected scripts: `oxlynlib` console command (server + F8), `GetProducts` / `IsConnected` exports.
- Assisted restart of a script that started before `oxlyn-lib`.
- Scripts reconnect after a quick `restart oxlyn-lib`; they stop themselves if it stays down.
- Optional convar `oxlyn_lib_debug` for verbose logging.

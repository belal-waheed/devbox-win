---
name: tauri-v2-rust
description: Official Tauri v2 and Rust desktop application architecture covering IPC commands, thread-safe state management, capabilities security model, system tray, window lifecycles, and background daemons.
---

# Tauri v2 & Rust Desktop Application Architecture

Comprehensive architecture and implementation standards for **Tauri v2** desktop applications using Rust, native system integration, the v2 permissions/capabilities security model, and frontend IPC bindings.

---

## When to Use This Skill

Trigger whenever building, refactoring, or securing Tauri desktop applications:
- Writing Rust IPC commands with `#[tauri::command]` and thread-safe managed state.
- Configuring Tauri v2 security boundaries, permissions, and `src-tauri/capabilities/*.json`.
- Implementing system tray icons, menus, and window visibility toggles (hide-on-minimize / hide-on-close).
- Managing multi-window lifecycles using `WebviewWindowBuilder`.
- Setting up background daemons, autostart on system boot, or single-instance guards.

---

## 1. Tauri v2 vs v1 Architecture Highlights

| Feature | Tauri v1 | Tauri v2 |
|---|---|---|
| **Security Model** | Monolithic `allowlist` in `tauri.conf.json` | Modular **Capabilities** and **Permissions** (`src-tauri/capabilities/`) |
| **System Tray** | `SystemTray` & `SystemTrayEvent` | `tauri::tray::TrayIconBuilder` & `MenuBuilder` |
| **Core Imports** | `@tauri-apps/api/tauri` (`invoke`) | `@tauri-apps/api/core` (`invoke`) |
| **Mobile Support** | Experimental / Separate | First-class unified desktop & mobile runtime |
| **Plugins** | In-crate features | Standalone modular crates (`tauri-plugin-*`) |

---

## 2. IPC Commands & Managed State

### Rust Command Implementation with Typed State
```rust
// src-tauri/src/commands.rs
use std::sync::Mutex;
use serde::{Deserialize, Serialize};
use tauri::State;

#[derive(Default)]
pub struct AppState {
    pub counter: Mutex<i32>,
}

#[derive(Serialize, Deserialize)]
pub struct CommandPayload {
    pub message: String,
    pub delta: i32,
}

#[derive(Serialize)]
pub struct CommandResponse {
    pub success: bool,
    pub current_value: i32,
}

#[tauri::command]
pub async fn increment_counter(
    payload: CommandPayload,
    state: State<'_, AppState>,
) -> Result<CommandResponse, String> {
    let mut counter = state
        .counter
        .lock()
        .map_err(|e| format!("Failed to acquire lock: {}", e))?;

    *counter += payload.delta;

    Ok(CommandResponse {
        success: true,
        current_value: *counter,
    })
}
```

### Application Initialization (`main.rs` / `lib.rs`)
```rust
// src-tauri/src/lib.rs
mod commands;

use commands::{increment_counter, AppState};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            Some(vec!["--minimized"]),
        ))
        .manage(AppState::default())
        .invoke_handler(tauri::generate_handler![
            increment_counter
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

### TypeScript IPC Invocation
```typescript
// src/lib/api.ts
import { invoke } from '@tauri-apps/api/core';

export interface CommandPayload {
  message: string;
  delta: number;
}

export interface CommandResponse {
  success: boolean;
  current_value: number;
}

export async function executeIncrement(delta: number): Promise<CommandResponse> {
  try {
    return await invoke<CommandResponse>('increment_counter', {
      payload: {
        message: 'Increment requested',
        delta,
      },
    });
  } catch (err) {
    console.error('IPC command failed:', err);
    throw new Error(typeof err === 'string' ? err : 'Unknown IPC error');
  }
}
```

---

## 3. Tauri v2 Security & Capabilities Model

In Tauri v2, permissions are declared per capability file in `src-tauri/capabilities/`.

### Default Capability Configuration
```json
// src-tauri/capabilities/default.json
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default-capability",
  "description": "Permissions for main application window",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "shell:allow-open",
    "autostart:default"
  ]
}
```

### Hardening Rules
1. **Principle of Least Privilege:** Never grant `*:*` or wildcard permissions.
2. **Explicit Window Scoping:** Restrict permissions to specific window labels (`windows: ["main"]`).
3. **URL Validation in Shell:** When using `shell:allow-open`, configure strict regex filters to prevent arbitrary command execution or protocol hijacking.

---

## 4. System Tray & Background Daemon Architecture

### Tray Icon & Context Menu Setup
```rust
// src-tauri/src/tray.rs
use tauri::{
    menu::{MenuBuilder, MenuItemBuilder},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Manager,
};

pub fn create_tray(app: &AppHandle) -> Result<(), Box<dyn std::error::Error>> {
    let show_item = MenuItemBuilder::with_id("show", "Show Application").build(app)?;
    let quit_item = MenuItemBuilder::with_id("quit", "Quit").build(app)?;

    let menu = MenuBuilder::new(app)
        .items(&[&show_item, &quit_item])
        .build()?;

    let _tray = TrayIconBuilder::new()
        .icon(app.default_window_icon().unwrap().clone())
        .menu(&menu)
        .menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "show" => {
                if let Some(window) = app.get_webview_window("main") {
                    let _ = window.show();
                    let _ = window.set_focus();
                }
            }
            "quit" => {
                app.exit(0);
            }
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                ..
            } = event
            {
                let app = tray.app_handle();
                if let Some(window) = app.get_webview_window("main") {
                    let is_visible = window.is_visible().unwrap_or(false);
                    if is_visible {
                        let _ = window.hide();
                    } else {
                        let _ = window.show();
                        let _ = window.set_focus();
                    }
                }
            }
        })
        .build(app)?;

    Ok(())
}
```

### Intercept Close Event (Hide to Tray)
```rust
// In lib.rs or main window builder
use tauri::WindowEvent;

pub fn configure_window_events(window: &tauri::WebviewWindow) {
    let window_clone = window.clone();
    window.on_window_event(move |event| {
        if let WindowEvent::CloseRequested { api, .. } = event {
            // Prevent process termination; hide window instead
            api.prevent_close();
            let _ = window_clone.hide();
        }
    });
}
```

---

## 5. Multi-Window Lifecycles

```rust
// src-tauri/src/windows.rs
use tauri::{AppHandle, WebviewUrl, WebviewWindowBuilder};

pub fn open_settings_window(app: &AppHandle) -> Result<(), tauri::Error> {
    if let Some(existing) = app.get_webview_window("settings") {
        existing.show()?;
        existing.set_focus()?;
        return Ok(());
    }

    WebviewWindowBuilder::new(app, "settings", WebviewUrl::App("/settings".into()))
        .title("Application Settings")
        .inner_size(600.0, 480.0)
        .resizable(false)
        .center()
        .build()?;

    Ok(())
}
```

# ⚡ Android App Optimizer (ADB Dexopt TUI)

An interactive, high-performance PowerShell TUI utility to manage, force-compile, profile, or reset Android runtime (`dexopt` / ART) bytecode optimization across all installed packages or specific user-selected applications via ADB.

Unlike traditional blind compile scripts, this tool provides real-time ANSI in-place console navigation, pre/post compilation status telemetry, friendly package identification, and granular control over compilation filters.

---

## ⚡ What It Does

When an Android device is restored or apps are installed, bytecode is typically left uncompiled or restricted to Play Store baseline profiles. Full native code compilation normally only triggers when the phone is plugged in, idle, and fully charged overnight (`JobScheduler`).

This tool lets you:

* **Force Ahead-of-Time (AOT) Compilation:** Pre-compile bytecode into native ARM64 machine code (`speed`, `speed-profile`, etc.) to eliminate on-the-fly JIT compilation stutter and frame drops.
* **Target Specific Packages or Bulk:** Selectively optimize heavy daily drivers (browsers, launchers, social media) or process the entire device package registry.
* **Secondary DEX Optimization:** Target dynamically loaded split APKs, feature modules, and runtime classpaths with `--secondary-dex`.
* **Reset & Purge:** Instantly wipe pre-compiled `.odex`, `.vdex`, and `.art` artifacts via `--reset` to reclaim disk space or debug runtime behavior.
* **Live In-Console Terminal UI:** Full ANSI-driven cursor navigation, real-time live-search package filtering, multi-select toggles, and status reporting without console flicker or buffer overflows.

---

## 🧠 Under the Hood: How It Works

Android no longer uses legacy "odexing" (Dalvik VM bytecode reordering). Modern Android versions (Android 5.0+ and ART APEX modules) rely on **ART (Android Runtime)** and **`dex2oat`** to compile Dalvik bytecode into true Linux ELF machine code.

When you run an optimization pass with this tool, `dex2oat` creates three core artifacts on internal storage:

| File Extension | Artifact Name | Description |
| :--- | :--- | :--- |
| **`.odex`** | **ELF Shared Object** | Native ARM64/ARM32 machine instructions executed directly by the hardware processor. |
| **`.vdex`** | **Verified DEX** | Pre-verified, uncompressed DEX bytecode metadata. Speeds up class verification if the runtime falls back to JIT. |
| **`.art`** | **ART Image** | Pre-initialized heap state containing static class references and string constants mapped straight into virtual RAM on launch. |

---

## 🎛️ Compilation Filters Explained

The script presents compile filters ordered strictly from **least comprehensive** to **most comprehensive**:

| Filter | Status | Description | Recommended Use Case |
| :--- | :--- | :--- | :--- |
| `extract` | 🔴 *Not Recommended* | Unpacks raw DEX bytecode from the APK; no native compilation. | Low-memory storage testing. |
| `verify` | 🔴 *Not Recommended* | Runs structural safety checks and emits `.vdex`; code runs purely via interpreter/JIT. | Default for resource overlays / theme APKs. |
| `quicken` | 🔴 *Not Recommended* | Minimal bytecode opcode optimization without compiling machine code. | Legacy lightweight mode. |
| `space-profile` | 🟡 *Moderate* | Profile-guided optimization prioritizing minimal storage footprint. | Constrained storage devices. |
| `space` | 🟡 *Moderate* | Full AOT compilation tuned to produce smaller binary size over raw loop speed. | Low internal storage availability. |
| `speed-profile` | 🟢 **Recommended** | Profile-guided AOT. Compiles hot methods based on Google Play Cloud Profiles and local runtime usage. | Balanced performance with low storage impact. |
| `speed` | 🟢 **Recommended** *(Default)* | Full AOT. Compiles all executable DEX methods to native ARM64 code. | Maximum snappiness, zero JIT lag after a restore. |
| `everything` | 🔴 *Not Recommended* | Compiles all bytecode, cold execution branches, and debugging frames. | Wastes disk space without noticeable speed gains over `speed`. |

> **Note on `speed` vs `speed-profile`:** Freshly restored devices lack runtime profile history. Running `speed` guarantees maximum immediate UI fluidity by compiling all methods ahead of time, eliminating on-the-fly JIT stutter.

---

## 📋 Prerequisites & Dependencies

Before running the script, ensure you have the following installed and configured:

1. **Windows Host Machine:**
   * **PowerShell 5.1+** or **PowerShell 7+** (Windows Terminal recommended).
   * **Android SDK Platform-Tools (`adb`)** installed and in your system's `PATH`.
     * *Verify in terminal:* `adb version`
2. **Android Device Configuration:**
   * **USB Debugging** enabled under *Settings > Developer Options*.
   * Connected via USB (or wireless ADB) and **Authorized** (RSA key fingerprint accepted on phone; `adb devices` shows `device`).

---

## 📦 Installation & Download

### Option 1: Direct Release Download (Easiest)
1. Go to the [**Releases**](https://github.com/KyleFerrigan/Android-App-Optimizer/releases) page.
2. Download the latest `ADB_App_Optimizer.ps1` script directly.
3. Place it into any folder of your choice (e.g., `D:\Scripts`).

### Option 2: Clone the Repository
```powershell
git clone https://github.com/KyleFerrigan/Android-App-Optimizer.git
cd Android-App-Optimizer
```

---

## 🚀 How to Run

1. Open PowerShell or Windows Terminal.
2. If PowerShell restricts running downloaded scripts on your machine, allow execution for the current process:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
3. Navigate to the script's directory and execute:
   ```powershell
   .\ADB_App_Optimizer.ps1
   ```

---

## 🎮 Interactive Controls Cheatsheet

### General Navigation Menus
* **`Up / Down Arrow`**: Move cursor between options.
* **`Enter`**: Confirm selection.

### Multi-Select Package Browser
* **`Up / Down Arrow`**: Move selection cursor (`>`).
* **`Spacebar`**: Toggle package selection (`[*]`) on or off (`[ ]`).
* **`Character Keys (A-Z, 0-9)`**: Type anywhere to filter packages in real time by name or package ID.
* **`Backspace`**: Delete last character from active search query.
* **`Enter`**: Confirm and execute on all checked packages (auto-selects focused item if none are checked).
* **`Escape`**: Cancel operation and cleanly exit back to terminal.

---

## ⚠️ Notes & Thermal Advisory

* **Thermals:** Compiling hundreds of packages with `-m speed` will push your device's SoC to sustained multi-core load for 10–25 minutes. Place your phone on a flat surface or near airflow to avoid thermal throttling.
* **Storage Footprint:** Full `speed` compilation generates native ELF binaries for every method. Internal storage usage will expand by approximately 1–3 GB depending on installed app volume.
* **Play Store Updates:** When Google Play updates an app, Android resets that specific app's compilation filter back to the cloud profile baseline until your next compilation pass or idle maintenance window.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE) — feel free to modify, redistribute, and use it however you wish.
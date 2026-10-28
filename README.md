# ADB App Optimizer (ART dexopt Orchestrator)

A clean, interactive PowerShell terminal utility that orchestrates Android Ahead-of-Time (AOT) compilation and runtime DEX optimization (`dexopt`) over ADB.

It bypasses the days-long wait for Android's background idle maintenance service, giving you direct control over ART compilation filters across all installed packages or specific target apps.

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
|---|---|---|
| **`.odex`** | **ELF Shared Object** | Native ARM64/ARM32 machine instructions executed directly by the hardware processor. |
| **`.vdex`** | **Verified DEX** | Pre-verified, uncompressed DEX bytecode metadata. Speeds up class verification if the runtime falls back to JIT. |
| **`.art`** | **ART Image** | Pre-initialized heap state containing static class references and string constants mapped straight into virtual RAM on launch. |

---

## 🎛️ Compilation Filters Explained

The script presents compile filters ordered strictly from **least comprehensive** to **most comprehensive**:

| Filter | Status | Description | Recommended Use Case |
|---|---|---|---|
| `extract` | 🔴 *Not Recommended* | Unpacks raw DEX bytecode from the APK; no native compilation. | Low-memory storage testing. |
| `verify` | 🔴 *Not Recommended* | Runs structural safety checks and emits `.vdex`; code is run purely via interpreter/JIT. | Default for resource overlays / theme APKs. |
| `quicken` | 🔴 *Not Recommended* | Minimal bytecode opcode optimization without compiling machine code. | Legacy lightweight mode. |
| `space-profile` | 🟡 *Moderate* | Profile-guided optimization prioritizing minimal storage footprint. | Constrained storage devices. |
| `space` | 🟡 *Moderate* | Full AOT compilation tuned to produce smaller binary size over raw loop speed. | Low internal storage availability. |
| `speed-profile` | 🟢 **Recommended** | Profile-guided AOT. Compiles hot methods based on Google Play Cloud Profiles and local runtime usage. | Balanced performance with low storage impact. |
| `speed` | 🟢 **Recommended** *(Default)* | Full AOT. Compiles all executable DEX methods to native ARM64 code. | Maximum snappiness, zero JIT lag after a restore. |
| `everything` | 🔴 *Not Recommended* | Compiles all bytecode, cold execution branches, and debugging frames. | Wastes disk space without noticeable speed gains over `speed`. |

---

## 📋 Prerequisites & Dependencies

Before running the script, ensure you have the following installed and configured:

1. **Windows PowerShell 5.1** or **PowerShell 7+** (Windows Terminal recommended).
2. **Android Platform Tools (ADB):**
   * Must be installed and accessible in your system's `PATH`.
   * Verify by running `adb devices` in a terminal.
3. **Android Device Configuration:**
   * **USB Debugging** enabled in *Settings > Developer Options*.
   * Device connected via USB (or wireless ADB) and **Authorized** (RSA key fingerprint accepted on phone).

---

## 🚀 How to Run

1. Clone or download this repository:
   ```bash
   git clone https://github.com/yourusername/adb-app-optimizer.git
   cd adb-app-optimizer
   ```

2. Connect your device and verify ADB detects it:
   ```bash
   adb devices
   ```

3. Open PowerShell in the script directory and execute:
   ```powershell
   .\ADB_App_Optimizer.ps1
   ```

*(Note: If PowerShell blocks script execution, run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` once to allow local script runs).*

---

## 🎮 Interactive Controls Cheatsheet

### Main & Action Menus
* **`Up / Down Arrow`**: Navigate options.
* **`Enter`**: Confirm selection.

### Multi-Select Package Browser
* **`Up / Down Arrow`**: Move cursor through the list.
* **`Spacebar`**: Toggle package selection (`[*]`) on or off (`[ ]`).
* **`Character Keys (A-Z, 0-9)`**: Type anywhere to filter package names in real time.
* **`Backspace`**: Delete last character from active search filter.
* **`Enter`**: Submit all toggled packages (or auto-selects the focused package if none are checked).
* **`Escape`**: Cancel and safely exit back to terminal.

---

## ⚠️ Notes & Thermal Advisory

* **Thermals:** Compiling 400+ packages with `-m speed` will push your device's SoC to 100% load across all CPU cores for 10–25 minutes. Place the phone face down on a flat surface or in front of a fan to prevent aggressive thermal throttling.
* **Storage Footprint:** Full `speed` compilation generates native ELF binaries for every method. Expect your internal storage usage to grow by 1–3 GB depending on how many apps are installed.
* **Play Store Updates:** Whenever Google Play updates an app, Android resets its compilation filter back to the cloud profile baseline until your next compilation run or idle maintenance cycle.
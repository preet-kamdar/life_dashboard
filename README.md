# 🧬 Life Dashboard: Gamified Life OS

> **"Turn your life into a tactical operation."**

A high-performance, offline-first personal operating system built with **Flutter**. It blends the aesthetics of **Android 16 (Material You Expressive)** with a **Cyberpunk/Tactical** interface.

This isn't just a todo list; it's a command center for your existence.

---

## ⚡ Key Systems

### 1. 📱 Dashboard Stream (Android 16 Style)
A unified "Notification Stream" that aggregates everything happening *now*.
* **Visual Log (New):** A Google Photos-style grid that logs one photo per day to chronicle your life visually.
* **Active Protocols:** See your daily routines as checkable notifications.
* **Mission Status:** Track active objectives and timers.
* **Neural Logs:** Quick access to recent AI vent sessions.

### 2. 🎯 Missions (Active Objectives)
* **3D Reactive Orbs:** Tasks are visualized as floating 3D spheres that decay over time.
* **Physics-Based Interaction:** Drag, spin, and interact with your tasks.
* **Priority System:** "Priority" missions pulse with your system's accent color.

### 3. 🛡️ Daily Protocols (Routines)
* **Glassmorphism UI:** Routines appear as frosted glass cards that "light up" (fill with color) when completed.
* **Tactical Checkboxes:** Satisfying animations for marking daily habits.

### 4. 🧠 Neural Link (Vent / AI)
* **The Sergeant:** A built-in AI persona (via Local LLM) that roasts you if you are lazy and commands you to work.
* **Ruthless Mode:** Toggle this in settings if you want the AI to be extra aggressive.
* **Privacy First:** Connects to your local endpoint (e.g., Ollama/LM Studio); no data leaves your network.

### 5. 📟 System Log (Journal)
* **Git-Style Commits:** Journal entries are hashed (`a1b2c`) and treated like code commits.
* **Terminal Interface:** A CLI-inspired input field (`git commit -m "Day summary"`) for rapid logging.
* **Diff View:** Review your life's history like a version control system.

### 6. 🧘 Zen Mode (Focus)
* **DVD Physics:** A bouncing clock that changes color on impact to keep your screen alive during deep work.
* **Dynamic Rain:** High-performance rain particle system for ambience.
* **RAM Buffer:** A "temporary thought" text area that clears itself when you exit focus mode.

### 7. 📊 System Monitor (Stats)
* **Heatmap:** A GitHub-style contribution graph showing your productivity consistency.
* **Rank System:** Level up from *Recruit* to *Commander* based on focus minutes and commits.

---

## 🛠️ Tech Stack & Architecture

* **Framework:** Flutter (Dart)
* **Design System:** Material You 3 (Expressive) + Custom Shaders
* **Local Database:** `Hive` (NoSQL, ultra-fast, offline-only)
* **State Management:** `ValueListenable` (Reactive database streams)
* **Theming:** `dynamic_color` (Syncs with Android Wallpaper) + `google_fonts` (Outfit / JetBrains Mono)
* **Hardware:** Access to Camera (`image_picker`) for Visual Log.

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.0+)
* (Optional) A local LLM running (e.g., Ollama) for the Neural Link.

### Installation

1.  **Clone the Repository**
    ```bash
    git clone [https://github.com/preet-kamdar/life_dashboard.git](https://github.com/preet-kamdar/life_dashboard.git)
    cd life_dashboard
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Run the System**
    ```bash
    flutter run
    ```

---

## ⚙️ Configuration

* **AI Endpoint:** Go to `Settings > Intelligence > AI Endpoint` to set your local LLM URL (default: `localhost:11434`).
* **Wallpaper Sync:** Go to `Settings > Appearance`. Toggle **"Sync with wallpaper"** to pull colors from your Android system, or turn it off to pick a manual neon color.

---

## 🔮 Roadmap
* [ ] **Cloud Sync:** Encrypted backup to GDrive.
* [ ] **Widget Support:** Home screen widgets for active missions.
* [ ] **Desktop HUD:** A dedicated landscape mode for Windows/Linux secondary monitors.

---

> *System Status: ONLINE* // *Operator: Preet*
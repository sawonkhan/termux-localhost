Termux Localhost Tool v1.0 (Full Documentation)

Developer: @error_rat
Version: 1.0
Platform: Termux (Android)

============================================================

📌 Overview

Termux Localhost Tool is a complete management console for running local development servers on Android using Termux.
It supports:

PHP server (php -S)

HTML static server (Python http.server)

Python server (app.py or module mode)

Cloudflare Tunnel public exposure

Automatic folder generation

Status display with PID, ports, and tunnel URL

Shortcut command: start-server

Colorful, emoji-rich interface for easy navigation


The goal is to make Android a mini local development environment.

============================================================

📦 Requirements

Before installing, run these commands inside Termux:

pkg update -y && pkg upgrade -y
pkg install -y php python git curl cloudflared zip

For file access:

termux-setup-storage

This will allow the tool to store website files inside:

/storage/emulated/0/localhost/

============================================================

📂 Folder Structure

When running for the first time, the script auto-creates:

/storage/emulated/0/localhost/
 ├── php/
 │    └── index.php
 ├── html/
 │    └── index.html
 └── python/
      └── app.py

You can place any project files inside these directories.

============================================================

⚙️ Installation

1. Place termux_localhost_tool.sh in your Termux home directory:



~/termux_localhost_tool.sh

2. Make it executable:



chmod +x ~/termux_localhost_tool.sh

3. Start the tool:



./termux_localhost_tool.sh

4. On first run, the script will:



Ask for storage permission if needed

Create required folders

Install the shortcut command:


start-server

From next time, simply type:

start-server

============================================================

📜 Menu Options

1. Start PHP server
2. Start HTML server
3. Start Python server
4. Stop a service
5. Status (PID & ports)
6. Expose via Cloudflare Tunnel
7. Create folders & samples
8. Exit

You may type:

A number (1–8)

Or a keyword (php, html, python, tunnel, stop, status, create, exit)


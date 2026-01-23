# 🚀 Adaptive Build Deployer (manage_builds.sh)
**The ultimate all-in-one automation tool for Android ROM Developers.**

This script is designed to handle the heavy lifting of your release cycle. It finds your latest build in the `out/` tree, extracts version data, uploads to your provider of choice (Google Drive or SourceForge), verifies the file is actually there, and generates a beautiful Telegram announcement.

---

## ⚡ Quick Start (Cloning)

To get started with the scripts from the repository, run the following commands:

```bash
# Clone the repository
git clone [https://github.com/PisselShit/scripts.git](https://github.com/PisselShit/scripts.git)
cd scripts

# Give execution permission to the manager
chmod +x manage_builds.sh

# Run the script
./manage_builds.sh



Key Features
​•  Original Precision Scanning: Uses your preferred logic to scan specifically in /*/out/target/product/[device]/*.zip. It ignores OTA packages, target files, and symbols to find only flashable builds.
​•  ROM Version Extraction: Automatically detects the ROM version (e.g., v4.1, 13.0, 1.0) directly from the filename using advanced regex.
​•  Integrity Verification: The script performs a "Handshake" with the cloud after upload to verify the file exists and is readable before firing the Telegram notification.
​•  Telegram Pro UI: Sends a clean Markdown message to your channel with a "Download Now" inline button.
​•  SSH & SourceForge Helper: Auto-generates SSH keys and copies them to your clipboard automatically for instant, passwordless SourceForge authentication.
​•  Persistent Sessions: Remembers your last ROM project name (stored in .last_session) so you don't have to re-type it every time you rebuild.
​•  Bookmark System: Save your favorite cloud directory paths for quick selection in future builds.
​
Detailed Setup Instructions:
​1. The Setup Wizard On the first launch, the script enters Wizard Mode. You will need:
​Cloud Provider: Select 1 for Google Drive (Rclone) or 2 for SourceForge (SSH/Rsync).
​2. Telegram Bot Token: Obtained from @BotFather.
​3. Chat ID: The ID of the channel or group where the builds should be posted:
on telegram @userinfo3bot to get chatid
4.​ Build Root: The local path on your machine where your ROM source code is located.
​5. SourceForge SSH Integration (If using SF)
​When you select SourceForge:
​The script checks for an existing SSH key.
​If none exists, it generates a high-security ed25519 key for you.
​The script will automatically copy the public key to your clipboard.
​6.Log into your SourceForge Account Settings.
​Navigate to SSH Keys and paste your key.
​Once done, you will never be asked for a password during uploads.
​7. Google Drive Integration (If using GDrive)
​Ensure you have run rclone config beforehand to set up your Google Drive remote. Note the name of the remote (e.g., drive) as the script will ask for it

​🚀 Usage Guide
​1) 📤 Upload New Build
​Scanning: The script searches out/target/product/ based on your input device.
​Versioning: It shows you the detected version and file size for confirmation.
​Destination: Choose between the Default Auto-Path (Project/Device), a Saved Bookmark, or enter a Custom Path.
​Verification: The script uploads, then verifies the file on the cloud. Only then does it offer to post to Telegram.
​2) ☁️ Manage Cloud Storage
​Provides a built-in file browser for your cloud root.
​Lists all .zip files in your directory tree so you can verify what is currently available to users.
​3) 📂 Manage Directories
​View, add, or delete your saved path bookmarks.
​🔒 Safety & Integrity
​No Deletions: This script contains zero rm or delete commands. Your local and cloud files are safe.
​Link Guard: Prevents sending "broken" download links. If the cloud provider doesn't confirm the file is there, the Telegram broadcast is aborted

### Main Menu Status
The script now tracks your activity. In the main menu, you will see:
* **Last ROM:** The project name you most recently worked on.
* **Last Path:** The specific cloud directory or bookmark you used.

This allows you to quickly verify your destination before starting the next upload.
...


### ⚙️ Option 5: Quick Config
Instead of re-running the entire setup when your Telegram Bot Token expires or you move your Android source code to a different drive, use **Option 5**.
* **Telegram:** Swap tokens or chat IDs instantly.
* **Paths:** Update your local search root.
* **Re-Wizard:** If you want to switch from Google Drive to SourceForge entirely, choose the "Full Setup Wizard" option here.

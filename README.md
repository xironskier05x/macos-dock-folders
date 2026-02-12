# Dock Folders

Turn any folder into a **clickable Dock icon** that shows its contents as a popup menu — like macOS Dock stacks, but with custom icons.

> [!WARNING]
> This automation is provided **as-is** for personal use. The repository is public for anyone who wants to fork and adapt it.
> Please do not open issues for support or feature requests.

## Features

📂 **Native popup menus** — Shows folder contents in a clean list

🎨 **Custom icons** — Preserves folder icons (including Emoji) in the Dock

🕵️ **Clean experience** — Hidden from CMD+Tab and Dock recent apps

⚡ **Fast** — Uses native macOS APIs and AppleScript

🖱️ **Click-to-open** — Opens selected items or the folder itself

## Usage

### Quick Start

Generate a Dock app for a single folder:

```bash
./dock-folders.sh ~/Documents/dock-folders/coding
```

Or build apps for **all** folders in a directory:

```bash
./dock-folders.sh --all ~/Documents/dock-folders
```

Then drag the generated `.app` files from `./build/` into your Dock.

> [!NOTE]
> **First launch:** If the folder is in `~/Documents`, `~/Desktop`, or `~/Downloads`, macOS will ask for permission to access it. Click **Allow**.

### Setup

1. **Create a folder** to hold your dock shortcuts:

   ```bash
   mkdir -p ~/Documents/dock-folders
   ```

2. **Create sub-folders** for each Dock group:

   ```bash
   mkdir ~/Documents/dock-folders/coding
   mkdir ~/Documents/dock-folders/music
   ```

3. **Add items**: Drag apps, aliases, files, or folders into these directories.

4. **Add icons**: Use [Customize Folder](https://support.apple.com/guide/mac-help/customize-folders-files-mac-mchlp2313/mac) or Finder's _Get Info_ panel to set custom icons. The script will automatically use them.

### Options

| Option            | Description                                       |
| ----------------- | ------------------------------------------------- |
| `--all <dir>`     | Build apps for all sub-folders in `<dir>`         |
| `<folder>`        | Build an app for a single folder                  |
| `OUTPUT_DIR=path` | Change the output directory (default: `./build/`) |

## Installation

No dependencies required. The script uses only built-in macOS tools.

1. Download `dock-folders.sh`
2. Make it executable:
   ```bash
   chmod +x dock-folders.sh
   ```
3. Run it!

## Images

![macos-dock-folders-old](https://github.com/user-attachments/assets/723bb143-b7ac-4e77-ae9f-21b139148560)

![macos-dock-folders-new](https://github.com/user-attachments/assets/dfdf0579-0ea7-4bf2-98a7-114312f419ac)

## License

[MIT](LICENSE)

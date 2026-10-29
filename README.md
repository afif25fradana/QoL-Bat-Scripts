# QoL Batch Scripts

A small collection of personal, standalone Windows utility scripts I use to keep my `Downloads`, `Desktop`, and screenshot folders tidy without installing third-party software.

Every script runs out of the box on Windows using a polyglot batch/PowerShell wrapper (no extra runtime or package manager required).

### Core Principles
- **Preview before doing anything**: you see exactly what will move or rename, then press `y` to confirm (or Enter to cancel).
- **Nothing is deleted**: files are only organized or renamed.
- **Subfolders are untouched**: only loose files directly in the current folder are processed.
- **Easily reversible**: made a mistake? Run `undo_last_action.bat` to put everything back where it was.

---

## `organize_by_type.bat`

Sorts loose files into neat, categorized subfolders based on extension.

### What it does
- Groups files into standard folders:
  - **Documents**: `.pdf`, `.doc`, `.docx`, `.xlsx`, `.xls`, `.ppt`, `.pptx`, `.txt`, `.csv`, `.rtf`, `.odt`, `.epub`, `.mobi`, `.tsv`, `.docm`, `.xlsm`
  - **Tech Doc**: `.html`, `.htm`, `.json`, `.md`
  - **Compressed**: `.zip`, `.rar`, `.7z`, `.tar`, `.gz`, `.iso`, `.xz`, `.bz2`, `.tgz`
  - **Programs**: `.exe`, `.msi`, `.mcaddon`, `.mcpack`, `.apk`, `.appx`, `.msix`, `.jar`
  - **Videos**: `.mp4`, `.mkv`, `.avi`, `.mov`, `.webm`, `.ts`, `.3gp`, `.m4v`, `.wmv`, `.flv`
  - **Music**: `.mp3`, `.wav`, `.flac`, `.opus`, `.m4a`, `.ogg`, `.aac`
  - **Images**: `.png`, `.jpg`, `.jpeg`, `.jfif`, `.gif`, `.webp`, `.svg`, `.bmp`, `.avif`, `.ico`, `.heic`, `.heif`, `.tiff`, `.tif`, `.raw`
  - **Fonts**: `.ttf`, `.otf`, `.woff`, `.woff2`
  - **Others**: any unrecognized extension
- **Safe in `Downloads`**: ignores active downloads (`.crdownload`, `.part`, `.partial`, `.opdownload`, `.download`, `.aria2`, `.tmp`) so incomplete downloads are never interrupted.
- Ignores companion scripts (`.bat`, `.cmd`, `.ps1`, `.sh`), shortcuts (`.lnk`, `.url`), git files, and system files (`desktop.ini`, `Thumbs.db`).
- Skips Windows reserved names (`CON`, `NUL`, `PRN`, etc.) and symlinks/junctions.
- Automatically handles duplicate names by adding numeric suffixes (`_1`, `_2`).
- Writes an action log (`organize_log_<timestamp>.txt`) listing all moved files so you have a record of what happened.

### How to use
1. Drop `organize_by_type.bat` into the folder you want to clean up.
2. Double-click the file to run it.
3. Check the preview list and category counts.
4. Press `y` to organize, or press Enter to cancel safely.

---

## `rename_screenshots.bat`

Renames loose image files and screenshots to consistent timestamp filenames (`yyyy-MM-dd_HH-mm-ss.ext`).

### What it does
- Scans loose `.png`, `.jpg`, and `.jpeg` files.
- For `.jpg`/`.jpeg` photos, reads EXIF `Date Taken` when available, falling back to file `Last Modified` time if missing.
- For `.png` files, renames based on `Last Modified` time.
- Skips files that already match the timestamp naming pattern.
- Skips Windows reserved device names and symlinks/junctions.
- Resolves timestamp collisions smoothly (`_1`, `_2`).
- Writes an action log (`rename_log_<timestamp>.txt`) recording old and new names.

### How to use
1. Drop `rename_screenshots.bat` into your screenshots folder.
2. Double-click to run it.
3. Review the `old_name -> new_timestamp_name` preview.
4. Press `y` to rename, or press Enter to cancel.

---

## `undo_last_action.bat`

Rolls back the most recent run of `organize_by_type.bat` or `rename_screenshots.bat` in the current folder.

### What it does
- Automatically finds the newest `organize_log_*.txt` or `rename_log_*.txt` in the folder (or you can drag and drop a specific log file onto it).
- Restores files in reverse order to their original locations or original names.
- **Collision barrier**: will never overwrite an existing file if something else has already taken that spot.
- Removes category subfolders if they become empty after files are moved back.
- Marks the processed log as `.undone` so running the script a second time rolls back the action before that.
- Writes an `undo_log_<timestamp>.txt` recording restored items.

### How to use
1. Double-click `undo_last_action.bat` in the folder where you want to undo an action (or drag a log file directly onto the `.bat` file).
2. Review the preview list of files to be restored.
3. Press `y` to restore, or press Enter to cancel.

---

## Related

**[dns-bench](https://github.com/afif25fradana/dns-bench)** — measures DNS latency, jitter, and packet loss across public resolvers from your actual Windows connection and recommends the fastest stable pair.

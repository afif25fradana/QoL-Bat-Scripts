# QoL Batch Scripts

A collection of personal, lightweight Quality of Life (QoL) batch scripts for Windows.

Both scripts show a preview and ask for confirmation before making changes:
- You see exactly what will move or rename, then press `y` to confirm (or Enter to cancel).
- Only loose files in the current folder are touched — never subfolders, and nothing is deleted.

---

## `organize_by_type.bat`

Automatically organizes loose files in any directory (such as `Downloads`, `Desktop`, or any working folder) into neat, categorized subfolders.

### What it does
- Groups files into categorized folders based on extension:
  - **Documents**: `.pdf`, `.doc`, `.docx`, `.xlsx`, `.xls`, `.ppt`, `.pptx`, `.txt`, `.csv`, `.rtf`, `.odt`, `.epub`, `.mobi`, `.tsv`, `.docm`, `.xlsm`
  - **Tech Doc**: `.html`, `.htm`, `.json`, `.md`
  - **Compressed**: `.zip`, `.rar`, `.7z`, `.tar`, `.gz`, `.iso`, `.xz`, `.bz2`, `.tgz`
  - **Programs**: `.exe`, `.msi`, `.mcaddon`, `.mcpack`, `.apk`, `.appx`, `.msix`, `.jar`
  - **Videos**: `.mp4`, `.mkv`, `.avi`, `.mov`, `.webm`, `.ts`, `.3gp`, `.m4v`, `.wmv`, `.flv`
  - **Music**: `.mp3`, `.wav`, `.flac`, `.opus`, `.m4a`, `.ogg`, `.aac`
  - **Images**: `.png`, `.jpg`, `.jpeg`, `.jfif`, `.gif`, `.webp`, `.svg`, `.bmp`, `.avif`, `.ico`, `.heic`, `.heif`, `.tiff`, `.tif`, `.raw`
  - **Fonts**: `.ttf`, `.otf`, `.woff`, `.woff2`
  - **Others**: Unrecognized file extensions
- Automatically ignores companion scripts (`.bat`, `.cmd`, `.ps1`, `.sh`), shortcuts (`.lnk`, `.url`), git files (`.gitignore`, etc.), OS metadata (`desktop.ini`, `Thumbs.db`), and previous run logs (`organize_log_*.txt`, `rename_log_*.txt`).
- Skips Windows reserved names (`con`, `nul`, etc.) and symlinks/junctions.
- Resolves destination name collisions automatically by appending numeric suffixes (`_1`, `_2`, etc.).
- Generates an action log (`organize_log_<timestamp>.txt`) in the target folder recording old and new paths for every item moved or failed.

### How to use
1. Copy `organize_by_type.bat` into the folder you want to organize.
2. Double-click the `.bat` file to run it.
3. Review the categorized preview and summary.
4. Type `y` to confirm and move the files, or press Enter/`n` to cancel safely without making any changes.

---

## `rename_screenshots.bat`

Batch renames loose screenshots and image files based on their timestamp (`yyyy-MM-dd_HH-mm-ss.ext`).

### What it does
- Scans loose `.png`, `.jpg`, and `.jpeg` files and generates new names based on timestamp.
- For `.jpg`/`.jpeg` photos, reads EXIF `Date Taken` if present, falling back to `Last Modified` time if unavailable.
- For `.png` files, renames based on `Last Modified` time.
- Automatically skips files that already match the timestamp naming pattern.
- Skips Windows reserved names (`con`, `nul`, etc.).
- Handles same-second timestamp collisions cleanly (`_1`, `_2`, etc.).
- Generates an action log (`rename_log_<timestamp>.txt`) in the target folder recording old and new names for every item renamed or failed.

### How to use
1. Copy `rename_screenshots.bat` into the folder containing your screenshots.
2. Double-click the `.bat` file to run it.
3. Review the preview list showing `old_name -> new_timestamp_name`.
4. Type `y` to confirm and rename the files, or press Enter/`n` to cancel safely without making any changes.

---

## Related

**[dns-bench](https://github.com/afif25fradana/dns-bench)** — measures DNS latency, jitter, and packet loss across public resolvers from your actual Windows connection and recommends the fastest stable pair.

# QoL Batch Scripts

A collection of personal, lightweight Quality of Life (QoL) batch scripts for Windows.

Both scripts are **safe and non-destructive by default**:
- Always display a preview of planned actions and require an explicit `y/N` confirmation before touching any files.
- Only process loose files directly in the target folder's root (where the `.bat` file is run).
- Never recurse into subfolders and never touch anything outside the target folder, so existing organized folders or project folders are always safe.

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
  - **Images**: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg`, `.bmp`, `.avif`, `.ico`, `.heic`, `.heif`, `.tiff`, `.tif`, `.raw`
  - **Others**: Unrecognized file extensions
- Automatically ignores companion scripts (`.bat`, `.cmd`, `.ps1`, `.sh`), shortcuts (`.lnk`, `.url`), git files (`.gitignore`, etc.), and OS metadata (`desktop.ini`, `Thumbs.db`).
- Resolves destination name collisions automatically by appending numeric suffixes (`_1`, `_2`, etc.).

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
- For `.jpg`/`.jpeg` photos, automatically reads EXIF `Date Taken` (`DateTimeOriginal`/`DateTimeDigitized`) if present, silently falling back to `Last Modified` time if EXIF is absent or unreadable.
- For `.png` files, renames based on `Last Modified` time.
- Automatically skips files that already match the timestamp naming pattern.
- Handles same-second timestamp collisions cleanly (`_1`, `_2`, etc.).

### How to use
1. Copy `rename_screenshots.bat` into the folder containing your screenshots.
2. Double-click the `.bat` file to run it.
3. Review the preview list showing `old_name -> new_timestamp_name`.
4. Type `y` to confirm and rename the files, or press Enter/`n` to cancel safely without making any changes.

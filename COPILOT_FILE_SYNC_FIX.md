# Fixing VS Code Copilot File Sync Issues

## The Problem

Sometimes VS Code Copilot's file editing tools get out of sync with the actual files on disk. Symptoms include:

- **Edits don't apply** - Copilot says it made changes but nothing happens
- **"String not found" errors** - The `replace_string_in_file` tool can't find text that exists in the file
- **Phantom file content** - Copilot's `read_file` returns old/cached content that doesn't match the actual file
- **Line count mismatch** - Copilot thinks the file has X lines, but it actually has Y lines

### How to Diagnose

Ask Copilot to check the file line count:

```
How many lines are in home_screen.dart?
```

Then verify in PowerShell:

```powershell
(Get-Content "path\to\file.dart").Count
```

If the numbers don't match, you have a sync issue.

---

## The Solution: Use PowerShell Directly

Instead of using Copilot's built-in file editing tools, have Copilot use PowerShell commands to read and modify files directly on disk.

### Reading Files

Instead of `read_file`, use:

```powershell
Get-Content "C:\path\to\file.dart" | Select-Object -Skip 99 -First 50
```

This reads 50 lines starting from line 100 (0-indexed skip).

### Finding Text

```powershell
Select-String -Path "C:\path\to\file.dart" -Pattern "searchText" | Select-Object -First 5
```

### Replacing Text in a File

For simple single-line replacements:

```powershell
(Get-Content "C:\path\to\file.dart") -replace 'oldText', 'newText' | Set-Content "C:\path\to\file.dart"
```

### Replacing Multi-Line Blocks

For replacing entire sections of code, use this pattern:

```powershell
$file = "C:\path\to\file.dart"
$content = Get-Content $file

# Keep lines 1-180 (before the section to replace)
$before = $content[0..179]

# Keep lines 307+ (after the section to replace)
$after = $content[306..($content.Count-1)]

# New code to insert
$newCode = @'
  void myNewMethod() {
    // Your new code here
    print("Hello!");
  }
'@

# Combine and write back
($before + $newCode + $after) | Set-Content $file
```

### Inserting New Lines at a Specific Position

```powershell
$file = "C:\path\to\file.dart"
$content = Get-Content $file
$insertAt = 250  # Line number to insert AFTER

$before = $content[0..($insertAt-1)]
$after = $content[$insertAt..($content.Count-1)]

$newLines = @'
  // New code to insert
  Widget buildSomething() {
    return Container();
  }
'@

($before + $newLines + $after) | Set-Content $file
```

---

## Step-by-Step Fix Process

1. **Tell Copilot about the issue:**

   ```
   The file editing tools are out of sync. Please use PowerShell commands
   directly to read and modify files instead of the built-in tools.
   ```

2. **Have Copilot verify the actual file content:**

   ```
   Use PowerShell to show me lines 180-210 of home_screen.dart
   ```

3. **Make edits using PowerShell:**

   ```
   Use PowerShell to replace lines 181-306 with this new code: [paste code]
   ```

4. **Verify the changes:**

   ```powershell
   Get-Content "C:\path\to\file.dart" | Select-Object -Skip 180 -First 30
   ```

5. **Hot reload or restart the app:**
   - Press `r` in the Flutter terminal for hot reload
   - Press `R` for hot restart
   - Or run `flutter run -d windows` again

---

## Preventing the Issue

1. **Save files before asking Copilot to edit** - Press Ctrl+S
2. **Close and reopen files** that seem stuck
3. **Run `flutter clean`** if builds seem stale
4. **Restart VS Code** if issues persist
5. **Check for unsaved changes** (dot indicator on file tabs)

---

## Example Prompt for Copilot

When you encounter this issue, paste this to Copilot:

```
I'm having a file sync issue where your file editing tools are returning
cached content that doesn't match the actual file on disk.

Please use PowerShell commands directly to:
1. Read file content: Get-Content "path" | Select-Object -Skip X -First Y
2. Find text: Select-String -Path "path" -Pattern "text"
3. Replace content: Use the array slicing method to replace line ranges

Do NOT use read_file or replace_string_in_file tools - they're out of sync.
```

---

## Quick Reference Commands

| Task               | PowerShell Command                                                 |
| ------------------ | ------------------------------------------------------------------ |
| Count lines        | `(Get-Content $file).Count`                                        |
| Read lines 100-150 | `Get-Content $file \| Select-Object -Skip 99 -First 51`            |
| Find text          | `Select-String -Path $file -Pattern "text"`                        |
| Find line number   | `Select-String -Path $file -Pattern "text" \| % { $_.LineNumber }` |
| Simple replace     | `(Get-Content $file) -replace 'old','new' \| Set-Content $file`    |

---

## Notes

- PowerShell array indexing is **0-based** (line 1 = index 0)
- `Select-Object -Skip X` skips X lines, so `-Skip 99` starts at line 100
- Always verify changes with `Get-Content` after modifications
- Use `@' ... '@` for multi-line strings (here-strings) in PowerShell

---

## VS Code Settings Applied

A `.vscode/settings.json` file has been created with optimized settings:

```json
{
  "files.autoSave": "off",
  "files.watcherExclude": {
    "**/build/**": true,
    "**/.dart_tool/**": true
  },
  "editor.formatOnSave": true,
  "[dart]": {
    "editor.defaultFormatter": "Dart-Code.dart-code"
  }
}
```

---

## Refactored File Structure

Large files have been split into smaller modules in `lib/screens/home/`:

```
lib/screens/
├── home_screen.dart          # Main coordinator (~90 lines)
├── home/
│   ├── home.dart             # Barrel exports
│   ├── home_tab.dart         # Home tab (~700 lines)
│   └── widgets/
│       ├── balance_card.dart
│       └── quick_play_card.dart
```

This structure keeps individual files under 1000 lines, making them easier for Copilot to edit reliably.

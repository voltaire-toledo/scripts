# Windows Terminal Configuration

Essential settings for modern CLI tools, ANSI styling, and rebuilt-ready environments.

## 1. Quick Configuration Guide

| Menu Path | Setting | Value |
| :--- | :--- | :--- |
| `Profiles > Defaults > Appearance` | **Intense text style** | `Bold font with bright colors` |
| `Profiles > [Specific Profile] > Appearance` | **Automatically adjust lightness...**| `Automatic` |
| `Profiles > Defaults > Appearance` | **Font face** | `CaskaydiaCove Nerd Font Mono` |
| `Interaction` | **Auto-copy selection** | `On` |
| `Interaction` | **Format when copying** | `Plain text only` |
| `Startup` | **Default terminal application**| `Windows Terminal` |

## 2. Verification
To confirm all decorations (Bold and Bright) are working correctly, run the demonstration script:

```powershell
.\Show-AnsiDemo.ps1
```

## 3. Setting Summaries

- **Intense text style**: Forces the terminal to use a thicker font weight and bright color variant for the `[1m]` ANSI attribute.
- **Automatically adjust lightness**: Ensures visibility by shifting text luminosity when attributes overlap background colors (found in individual profile settings).
- **Nerd Font**: Enables rendering of specialized icons and glyphs used in modern shell prompts (e.g., Oh My Posh).
- **Interaction**: Simplifies copy-paste by automating the clipboard action and stripping rich-text formatting.
- **Startup**: Ensures Windows Terminal is the default handler for all command-line processes.

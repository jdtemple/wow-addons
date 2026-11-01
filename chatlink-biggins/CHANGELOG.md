# Changelog

All notable changes to **ChatLink Biggins** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-11-01

### Added
- **Player Name Hover Tooltips:** Moving your mouse over any player name in chat now displays their character tooltip in the native `GameTooltip` frame.
- **Tier 1 Unit Token Resolution:** For party members, raid members, current target, or nearby players, automatically resolves live unit tokens and calls `GameTooltip:SetUnit()`. Seamlessly inherits enhancements from tooltip addons like **MouseOverTooltip** (item level, spec, mount, class borders).
- **Tier 2 Remote Player Identity Cards:** For cross-zone players or strangers in Trade/General chat, uses `GetPlayerInfoByGUID()` to render a clean, stock-styled identity card showing class color, race, realm, and guild info (when available).
- **Chat Line GUID Resolution:** Resolves player GUIDs via `C_ChatInfo.GetChatLineSenderGUID()` and incoming chat event caching to reliably retrieve player identity data.
- **Temporary Window & Whisper Tab Support:** Automatically hooks floating chat windows and whisper tabs via `FCF_OpenTemporaryWindow`.
- **Options & Slash Commands:** Added `[x] Show Player Tooltips on Name Hover` in Options, and added `/clb tooltips` (or `/clb hover`) slash command toggle.

---

## [1.0.0] - 2026-10-24

### Added
- **Initial Release** of ChatLink Biggins for World of Warcraft (Retail 12.1.7 / 11.x).
- **Single-Pattern Protocol Isolation:** Robust, collision-free link detection for standard `https://` and `http://` URLs across all public and private chat channels.
- **100% Blizzard Factory Copy Dialog:** Native `StaticPopupDialogs` implementation featuring auto-selected text and immediate keyboard focus (`Ctrl+C` -> `Enter`).
- **Sentence Punctuation Stripping:** Automatically trims trailing punctuation (`.,;:!?)[]'"`) from freeform chat text.
- **Pipe Escape Protection:** Strict `|` boundary enforcement protecting adjacent item, spell, and color hyperlinks.
- **Modern Blizzard Canvas UI:** Full integration under `Game Menu -> Options -> AddOns -> Biggins AddOns -> ChatLink` with master enable toggle, bracket toggle, and top-right `[ Defaults ]` button.
- **Embedded LibBigginsSuite Integration:** Seamless parent suite navigation with suite branding and quick-jump access.
- **Slash Commands:** Comprehensive command engine via `/clb` and `/chatlink`.

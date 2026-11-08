# Music info cleanup rules

How song, artist and album text is cleaned up. These rules combine the Tasker task **Parse Music Track**, the Kustom widget **Music_Old**, and the way the **Now Playing** card in this suite applies them.

Every rule starts from four values that the player reports: **title**, **artist**, **album** and **app**.

## 1. Tasker task "Parse Music Track"

### General rules

| Field | Rule |
|---|---|
| **Track** | The title up to the first ` - `. If there is no ` - `, the whole title. |
| **Album** | If the title contains a `"`, the text after the first `"` up to the next one. For example, `Song (From "Film")` gives **Film**. Otherwise, the album up to the first ` (`. |
| **Artist** | The player's artist, unchanged. |

### App-specific rules

These replace the general rules for the named apps.

| App | Track | Artist | Album |
|---|---|---|---|
| **Audible** | The player's artist field (the chapter or book part) | `Audible` | Title before ` - ` (the book) |
| **Pocket Casts** | Title before ` - ` | Artist field (the podcast) | Artist field (the podcast) |
| **YouTube** | Title before ` - ` | Artist field (the channel) | `From Youtube` |

The task also sets two Kustom flags, `MUSICPLAY` (1 when music plays) and `MEDIAAPP` (1 for Audible, Pocket Casts and YouTube), and shows a debug popup with the app name. None of these change the text.

## 2. Kustom widget "Music_Old"

The widget has a switch between using Tasker's cleaned fields and reading the player directly.

### Using Tasker's fields

These apply on top of the Tasker rules above.

| Field | Rule |
|---|---|
| **Track** | Cut at the first ` (`, at most 35 characters, with `Chapter ` removed. |
| **Album** | In CAPITALS, at most 30 characters. |

### Reading the player directly (without Tasker)

| Field | Rule |
|---|---|
| **Track** | The title up to the first `-`, then up to the first `(`. No spaces are needed around either character. |
| **Album** | The album up to the first `(`, at most 23 characters. |

The widget does not show the artist. For Audible it also uses a playback-speed setting in its time display.

## 3. Rules on the Now Playing card

The card keeps the Tasker and Kustom behavior and extends it for YouTube-style uploads. The rules run in this order, for every player.

| Step | Rule |
|---|---|
| **1. Quotes** | Curly quotes (`“ ” ‘ ’`) are treated as straight quotes. |
| **2. Film** | A film is found only in `From "Film"`, `From 'Film'` or `(From Film)`. Any other quoted text stays in the song name. |
| **3. Pipes** | For `Song \| Film \| Singer \| Composer`, the song is the first part. The album is the next part that is not an upload tag, so `Song \| Video Song \| Film` still gives **Film**. |
| **4. Brackets** | Text in `( )` or `[ ]` is removed when it starts with `From`, or when it is an upload tag: anything with *official, video, lyric, audio, visualizer, remaster* or *full song*, or the whole words *HD, HQ, 4K, 8K, 720p, 1080p*. `(feat. X)`, `(ft. X)` and `(featuring X)` are removed and X moves to the artist line. Other brackets stay, e.g. `(Male Version)` or `(Remix)`. |
| **5. Dash** | For `A - B`, the song is **A**. If **A** is the artist (`Artist - Song`), the song is **B** instead. |
| **6. Chapter** | `Chapter ` is removed only at the start of the song name. |
| **7. Artist** | Channel suffixes are removed: ` - Topic`, `VEVO`, ` Official`. A featured artist is added after a comma unless already listed. |
| **8. Album** | The film from step 2. Otherwise the player's album before ` (`. Otherwise the album from step 3. Shown in CAPITALS. |

App-specific rules then apply:

| App | Rule |
|---|---|
| **Audible** | Album is the title before ` - ` (the book), artist is **Audible**, song is the artist field before ` (` without a leading `Chapter `. |
| **Pocket Casts** | Album and artist are the artist field (the podcast). |
| **YouTube** | Album is **From Youtube**, but only when no film or album was found. |

### Examples

| Player reports | Card shows |
|---|---|
| `Poove Poove (From "Devadoothan")` | Song **Poove Poove**, album **DEVADOOTHAN** |
| `Poove Poove (From “Devadoothan”)` (curly quotes) | Song **Poove Poove**, album **DEVADOOTHAN** |
| `Raathinkal Poothaali \| Bharatham \| K J Yesudas \| Johnson` | Song **Raathinkal Poothaali**, album **BHARATHAM** |
| `Song Title (Official Video) [4K]` | Song **Song Title** |
| `Song Title (Male Version)` | Song **Song Title (Male Version)** |
| `Song (feat. Guest Singer)` by Main Artist | Song **Song**, artist **Main Artist, Guest Singer** |
| `K J Yesudas - Poove Poove (Lyrical)` by K J Yesudas - Topic | Song **Poove Poove**, artist **K J Yesudas** |
| `Song "Live"` | Song **Song "Live"**, no album |
| `New Chapter Begins` | Song **New Chapter Begins** |
| `Song Name - Remastered 2011`, album `Album (Deluxe Edition)` | Song **Song Name**, album **ALBUM** |
| Audible: `Project Hail Mary - Chapter 3` by Andy Weir | Song **Andy Weir**, artist **Audible**, album **PROJECT HAIL MARY** |
| Pocket Casts: `Episode 12 - Guests` by The Podcast | Song **Episode 12**, artist and album **The Podcast** |
| YouTube app: `Live Session - Part 1 (HD)` by Channel | Song **Live Session**, artist **Channel**, album **FROM YOUTUBE** |

### How the card differs from the originals

- **Only a `From` quote is a film.** The Tasker task used any quoted text as the album.
- **Brackets are kept unless they are tags.** The Tasker and Kustom rules cut everything from ` (` onward.
- **`Artist - Song` titles are recognised,** and `|` titles, curly quotes and channel names are handled. These are new.
- **`Chapter ` is removed only at the start.** The Kustom widget removed it anywhere in the name.
- **YouTube keeps a film it found** instead of always showing From Youtube.
- **No fixed character limits.** The 35, 30 and 23 character cuts are not used; the card shortens text to fit its width.
- **The artist is shown,** because the card has a line for it. **The album is hidden** when it is the same as the song name.
- **Apps are matched by their Windows app ID.** An ID containing `audible` or `pocketcasts` matches those apps. YouTube matches the YouTube app or the YouTube web app installed from Edge or Chrome. YouTube in a normal Edge tab reports only Edge, so the YouTube album rule cannot apply there, but steps 1–8 still do.
- **The Kustom "read the player directly" mode is not included.** Its `-` and `(` splits need no spaces, so they would also cut names such as "Jay-Z".

The rules are implemented in `M.cleanMedia` in `NerdWidgets/@Resources/Scripts/Model.lua`.

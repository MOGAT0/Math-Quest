# Math Quest — Dev Commands Cheat Sheet

> ⚠️ Every command that changes the date, class or database **writes to the active save file** (`mathquest_data.json`). Copy the save first if you want to keep it.

---

## 1. In-game dev console

| | |
|---|---|
| **Open / close** | Press **Delete** while in the world (the console belongs to the player). |
| **Run** | Type the command and press **Enter** or the Submit button. |
| **Arguments** | Separated by spaces. Use `"quotes"` for text that contains spaces. |
| **Values** | `true` / `false` become booleans; numbers become int or float; anything else stays text. |
| **Named style** | `name=value` also works; the name is ignored and only the value is kept, in order. |
| **Case** | Command names are case-sensitive (lowercase). Season names are not. |

### Commands

| Command | Arguments | What it does | Example |
|---|---|---|---|
| `change_date` | `<season> <year> <day>` | Jumps the calendar to a date. It ends the current day first (the festival and random events pack up), then starts the new date as if Matthew woke up on it. Seasons: `spring`, `summer`, `autumn` (or `fall`), `winter`. Days: 1–28. | `change_date summer 1 14` |
| `set_time` | `<hour> [minute]` | Sets the clock (24-hour). Stamina is kept as it was, and the date never changes (use `change_date` for that). | `set_time 18` · `set_time 13 30` · `set_time 13:30` |
| `update_class` | `<grade> <lesson>` | Sets the next class to attend. Grades: `g1`–`g3`, lessons `g1-l1` … `g3-l10`; final exam: `g4 final`. | `update_class g2 g2-l5` |
| `follow_player` | `<npc_name> <true\|false>` | Makes an NPC follow Matthew, or stop. Only **Arith** supports it. | `follow_player Arith true` |

The console prints `Command executed: ...` on success, or an error with the correct usage.

### Handy recipes

| Goal | Commands |
|---|---|
| Visit a festival (all-day) | `change_date spring 1 13` → walk to the event location |
| Visit an evening festival | `change_date summer 1 14` → `set_time 18` |
| Hear a festival theme song | `change_date spring 1 20` → `set_time 3` → wait for 4:00 (or sleep) |
| Test bedtime | `set_time 13` → sleep is allowed · `set_time 9` → "It's still daytime..." |
| Test midnight date change | `set_time 23 50` → stay awake past 00:00 |
| See the 9 PM "go home" arrow | `set_time 20 55` |
| Skip to the Grade 3 finale | `update_class g3 g3-l10` → attend class |
| Try the final exam | `update_class g4 final` → attend class |

### Festival dates

| Festival | Date | Opens |
|---|---|---|
| Academy Magic Fest | `spring 1 13` | all day |
| Easter Holiday | `spring 1 20` | all day |
| Star Festival | `summer 1 14` | 6 PM (`set_time 18`) |
| Harvest Fair | `autumn 1 10` | all day |
| Night of Lanterns | `autumn 1 27` | 6 PM (`set_time 18`) |
| Winter Solstice | `winter 1 24` | all day |

---

## 2. Database console (db editor)

| | |
|---|---|
| **Open** | On the **main menu**, hold **Ctrl + Shift + \\** for 3 seconds. |
| **Use** | Type SQL-like queries; results show in the table and log. The left panel lists all tables and columns. |

### Queries

| Query | What it does | Example |
|---|---|---|
| `SHOW TABLES` | Lists all tables. | `SHOW TABLES` |
| `SELECT` | Reads rows (supports `WHERE`, `LIMIT`, sub-queries). | `SELECT kp, current_lesson FROM progress WHERE is_active = true` |
| `UPDATE` | Changes rows. A `WHERE` clause is required; set several columns with commas. | `UPDATE progress SET kp = 999 WHERE is_active = true` |
| `INSERT INTO` | Adds a row (missing columns get their defaults). | `INSERT INTO streak (date, days) VALUES ("2026-10-19", 1)` |
| `DELETE FROM` | Removes rows. | `DELETE FROM festival WHERE event_id = "harvest_fair"` |
| `TRUNCATE TABLE` | Empties a table but keeps it. | `TRUNCATE TABLE festival` |
| `ALTER TABLE` | Changes a table's columns. | — |
| `CREATE TABLE` / `DROP TABLE` | Creates or deletes a table. | — |
| `CLEAR` | Clears the console log. | `CLEAR` |

### Useful queries

| Goal | Query |
|---|---|
| Give KP | `UPDATE progress SET kp = 5000 WHERE is_active = true` |
| Check progress | `SELECT current_chapter, current_grade, current_lesson, kp FROM progress WHERE is_active = true` |
| Mark a chapter done / undone | `UPDATE checklist SET is_done = true WHERE chapter = grade1_complete` |
| Replay all festivals | `TRUNCATE TABLE festival` |
| Reset festival tokens | `UPDATE festival_profile SET tokens = 0, special = "{}" WHERE id = 1` |
| Forget seen events | `UPDATE calendar SET seen_events = "[]" WHERE id = 1` |

> ⚠️ Never `DROP TABLE` one of the six template tables (`checklist`, `progress`, `streak`, `calendar`, `festival`, `festival_profile`). The game restores missing tables and columns on the next start, but the rows in them are lost.
> ⚠️ KP is read from the save only when the game starts (and after rewards or purchases). After changing `kp` in the db console, **restart the game**. Otherwise the next reward or purchase adds to the old in-memory KP and writes it back over your edit.

---

## 3. Other dev helpers

| Helper | How |
|---|---|
| Reset everything | Settings → **Reset Data**. Wipes the save and the analysis log, then rebuilds the save from the template. |
| Export answers | Settings → **Export Analysis** (CSV and graphs). |
| Force a random event | Set `EventDirector.force_next = true` in code; the next roll after waking or after class always hits. |

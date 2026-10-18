# Math Quest — System Pseudocode

Math Quest is a 2D educational RPG (Godot 4.5). Matthew, a student from Earth, is pulled into a magic world. He studies Grade 1–3 math at the Academy as "spells", earns Knowledge Points (KP), lives through a day/night calendar with random events and festivals, and finally passes the last exam to open the portal home.

This document describes the whole game as pseudocode, from boot to ending.

---

## 0. Global services (autoloads, always running)

```
GameManager        clock, stamina, KP in memory, current target, scene loading
StoryLineManager   story graph (data/story_data.json): chapter -> dialogues -> next chapter
DataManager        save file (JSON "database" of tables) + default template
db                 SQL-like console over DataManager (SELECT / UPDATE / INSERT ...)
MusicPlayer        background playlist, one-shot sounds, festival theme songs
AnalysisReport     log of every answer + export to CSV / graphs
CalendarManager    in-game date (day, season, year), weekdays, major events
EventDirector      random daily events (riddles, fetch quests)
FestivalDirector   major events run as festivals
```

---

## 1. Boot and main menu

```
ON GAME START:
    DataManager.load_database()              # read save file if it exists
    DataManager.ensure_base_tables()         # see section 2
    show boot splash -> loading screen -> main menu

MAIN MENU:
    PLAY      -> show 3 save slots
    SLOT n    -> mark progress row n as the active save, then CONTINUE
    CONTINUE  -> chapter_id = checklist id of progress.current_chapter
                 IF chapter_id <= 2:  load prologue scene (Earth classroom, alley portal)
                 ELSE:                load the magic world
    SETTINGS  -> volume sliders, credits, export analysis, reset data
    QUIT      -> confirm, then exit
```

---

## 2. Save data (DataManager)

```
TEMPLATE TABLES:
    checklist         one row per story chapter: (id, chapter, is_done)
    progress          one row per save slot: current_chapter, grade, lesson,
                      location, Arith position, crystals c1..c3, open_portal, kp = 300
    streak            daily streak (date, days)
    calendar          day, season, year, next_random_day, seen_events
    festival          one row per festival joined: stamps, badge, progress
    festival_profile  festival tokens, best scores, collectibles, special tokens

FUNCTION ensure_base_tables():                 # runs every start
    FOR each table in TEMPLATE:
        IF table missing:            create it and add its starting rows
        ELSE:
            add any missing column (fill rows with the column default)
            IF one-row table is empty: add its starting row
            IF checklist misses chapters: append them
    save if anything changed
    # => a new device always gets a complete save; old saves get upgraded

FUNCTION insert(table, row):
    give row an auto-increment id
    fill every missing column with its default
    validate types, append, save

FUNCTION clear_data():                          # Settings > Reset data
    database = empty
    ensure_base_tables()                        # rebuild template immediately
    emit data_cleared
        -> GameManager reloads KP (300), stamina full, clock 8:00
        -> CalendarManager reloads Spring 1, Year 1
        -> FestivalDirector closes any festival
        -> AnalysisReport empties the answer log
```

---

## 3. Story and chapters

```
STORY GRAPH (StoryLineManager):
    prologue_classroom -> alley_portal -> magical_forest -> wizard_castle_intro
    -> arith_study_book -> academy_interview -> school_admission
    -> [ for each lesson: market_food_n -> gradeG_lessonL_class -> gradeG_lessonL_test -> home_sleep_n ]
    -> grade1_complete -> grade2_complete -> grade3_complete
    -> library_ms_richie -> interactive_review -> wizard_final_trial
    -> portal_key_awarded -> return_earth_exam -> victory_epilogue

CHAPTER SCENE (dialogue trigger):
    ON ready:
        IF checklist[chapter].is_done: advance_to_next_chapter() and skip
        ELSE: lock player clicks, load the chapter's dialogues
    NEXT / PREVIOUS buttons step through dialogue lines (typewriter + voice)
    ON last line: advance_to_next_chapter()

FUNCTION advance_to_next_chapter():
    emit chapter_done(chapter)        -> world.update_checklist(chapter)
    GameManager.current_chapter = StoryLineManager.get_next_node(chapter)
    move Arith (the guide) to the next place, unlock player
    IF this chapter opens something (e.g. entrance exam): open it

FUNCTION world.update_checklist(chapter):
    save player position + chapter in progress
    checklist[chapter].is_done = true
    save Arith position (early chapters)
```

### Entrance exam (academy_interview)

```
BUILD pages: for each chapter in book_data.json -> 1 lesson card + 1 card per question
SHOW treasure-map path (one stop per page) + parchment card
LESSON CARD:
    tap pictures to count (badges show tap order) -> big counter
    one short line + tip, read aloud (TTS) -> "Let's go!"
QUESTION CARD:
    picture grid + NumberPad / choice tiles, question read aloud
    ON check:
        IF correct: green glow, confetti, star on map, say "Great job!"
                    wait 1.6 s -> next card automatically
        ELSE:       shake, red flash; after 2 misses show hint
AFTER last question: certificate -> Return -> chapter done
```

---

## 4. World loop (every frame)

```
PLAYER:
    input = keyboard WASD + on-screen joystick
    IF clicks allowed: move (or follow navigation path), play step animation
    update HUD: KP, stamina bar, crystals
    near bed / merchant / NPC: show "Press [E]" (desktop) or Interact button (mobile)

TARGET INDICATOR (quest arrow):
    main target = GameManager.target_location (story goal)
    side targets = active random events / festival booths
    IF target on screen: lock onto it (snap within ~1 m)
    ELSE: arrow at screen edge pointing to it

CLOCK (GameManager, only while game time is enabled):
    current_time += 24 / (minutes_per_day * 60) * delta
    stamina -= 5 per in-game hour
    IF clock wrapped past 24:00: emit midnight_passed
    emit hour_changed(current_time)  -> daylight tint, lamps, festivals, music

DAYLIGHT: tint the world by hour (CanvasModulate), lights glow at night
AT 21:00 (after class): arrow points to Arith's house (go home to sleep)
```

---

## 5. Calendar, sleep and waking

```
CALENDAR: 4 seasons x 28 days, 7-day weeks; Spring 1 Year 1 = Monday
is_school_day = NOT (a major event that closes the school is today)

ON midnight_passed:
    CalendarManager.next_day()           # never twice in the same night

BED (matthew_sleep):
    ON press E:
        IF time > 12:00 OR time < 4:00:  go_to_sleep()
        ELSE: popup "It's still daytime... I can only sleep after 12 noon."

    go_to_sleep():
        stop music, play dream sound, fade screen, hide player, start timer

    wake_up():
        IF midnight did not already pass tonight: CalendarManager.next_day()
        clock = 4:00, stamina refilled, music resumes
        EventDirector.expire_all() (yesterday's events vanish) + morning roll
        first time only: open Arith's letter
        after letter closed: Matthew's speech bubble:
            IF school day:  "A fresh new day to learn new things! I should hurry and go to school."
            ELSE:           "A fresh new day! There is a festival today. Let's go and have fun!"

MUSIC AT WAKE TIME (MusicPlayer):
    ON hour_changed(t):
        IF 4:00 <= t < 5:00 AND (clock was before 4:00 OR the day just changed)
           AND theme not yet played today:
            IF today has a major event with a theme song: play it once
    ON theme finished: continue the normal playlist where it was
```

---

## 6. Academy class (the core learning loop)

```
ENTER ACADEMY (school day only):
    teleport into class, pause the clock
    load curriculum.json lesson for progress.current_grade / current_lesson
    teacher = Mr. Archimedes (Ma'am Cruz for the final exam)

LECTURE:
    play lecture steps on the blackboard (say / show / animate), read aloud
    player can Replay or Begin

QUESTIONS (one queue per lesson):
    FOR each question:
        show question card (typed + TTS)
        mount the right input: NumberPad, choices, clock, number line,
            pattern, tally, market, sharing, garden... ("stations")
        HINT button: show a hint
        ON cast (submit):
            is_correct = AnswerRules.matches(given, expected, input_type)
            AnalysisReport.record_answer(lesson, question, given, correct, time, hint_used)
            IF correct: streak += 1, fire spell animation
            ELSE:       wrong_count += 1, shatter animation, board shows answer
                        + explanation of why
            stars = 3 if wrong_count == 0 / 2 if <= 2 / else 1
            NEXT -> next question

LESSON COMPLETE:
    reward = 50 + (grade-1)*10 + (lesson-1)*2  (+50 for lesson 10 / final exam)
    show "Spell Mastered!", stars, +reward KP, confetti
    ON "Return to the hall":
        kp += reward
        emit class_end(grade, lesson):
            lesson 10 of a grade -> award a crystal (emerald / ruby / diamond)
            g3-l10 -> grade-3 cinematic, unlock chapter 8
            world: teleport to academy gate, clock = 21:00
            EventDirector: evening roll on the way home
            Matthew's bubble: "Class is finally over! I can't wait to go home and sleep...
                               Should I go to the shop first? Hmmm..."
        save next lesson: g1-l1 .. g1-l10 -> g2 .. -> g3-l10 -> final exam -> done
    RELEARN: after all classes, any finished lesson can be replayed (no KP)
```

---

## 7. Shop (merchants)

```
TALK TO MERCHANT -> dialogue -> SHOP
    stock = random products from vendors_data.json
    items the player can't afford are dimmed
    ON buy(item):
        IF price > KP: refuse
        math challenge on NumberPad, one of:
            "You have K KP. It costs P. How much is left?"   (K - P = ?)
            "It cost P, your change is C. How much did you have?"  (? - P = C)
        IF correct: KP -= price, give item (e.g. food refills stamina)
        ELSE: try again
```

---

## 8. Random events (EventDirector)

```
ROLL after waking and after class:
    IF random() < 0.6:
        spawn 2..5 events (max 12 alive), each at a free spot in the town
        weighted pick from events.json "random" (never the same visitor twice)

EVENT TYPES:
    RIDDLE:  NPC asks a review question from a lesson already studied
             correct -> reward KP;  wrong -> try again / leave
    FETCH:   NPC lost items -> items appear with arrows -> collect all
             -> return -> "How many did you find?" (NumberPad) -> reward KP

Every event NPC has a shadow, a "!" mark, a "Press [E]" prompt and a quest arrow.
Sleeping ends the day: unfinished events disappear.
```

---

## 9. Major events / festivals (FestivalDirector)

```
EVENTS (data/events.json):
    Academy Magic Fest   Spring 13   all day   school closed
    Easter Holiday       Spring 20   all day   school closed   egg hunt
    Star Festival        Summer 14   6 PM      after class     star hunt, lantern release
    Harvest Fair         Autumn 10   all day   school closed   apple hunt, prize pumpkin
    Night of Lanterns    Autumn 27   6 PM      after class     light 8 lanterns, parade
    Winter Solstice      Winter 24   all day   school closed   snowmen, snowfall + gift

ON festival day:
    wait for opens_at hour (if any), then open the festival at %event_location:
        host NPC in the middle, booth stalls + street lamps in a ring around it
        main arrow -> festival; academy closed with a popup (if closes_school)
    HOST: gives a stamp card
    BOOTHS: each is a short math mini-game (patterns, number line, money,
            telling time, sharing, tally...) -> stamp + festival tokens
    HUNT / QUEST: collect hidden items around town for a bonus
    PRIZE BOOTH: spend tokens on food (stamina), a KP pouch, a special token
    TRAVELING TRADER: trades special tokens for KP
    ALL STAMPS -> badge + 25 bonus KP -> festival ending:
        lanterns / prize pumpkin / snowfall + Arith's gift
    progress saved in tables festival + festival_profile (journal in the calendar)
```

---

## 10. Endgame

```
ON g3-l10 finished: chapter grade3_complete -> cinematic -> chapter 8 unlocked
LIBRARY (Ms. Richie) -> interactive review -> wizard final trial (final exam, Ma'am Cruz)
ON 3 crystals placed: portal spawns (open_portal = true)
ENTER PORTAL -> final class scene -> return-to-Earth exam -> victory epilogue
```

---

## 11. Settings

```
VOLUME: master / music / SFX sliders -> audio buses
EXPORT ANALYSIS:
    IF no answers yet: "No analysis data yet. Finish a few lessons first!"
    ELSE: pick a folder -> write summary CSV, answers CSV and graphs PNG
          (mobile: private folder + share sheet)
RESET DATA:
    confirm -> DataManager.clear_data() -> back to main menu
```

---

## 12. Developer console (testing)

```
change_date <season> <year> <day>   jump the calendar (e.g. to a festival)
set_time <hour> [minute]            set the clock (24-hour)
db console                          SQL-like queries on the save tables
```

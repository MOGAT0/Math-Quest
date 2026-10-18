# Math Quest — Description of the System

## Overview

Math Quest is a 2D educational role-playing game built with the Godot 4.5 engine for Windows and Android. It teaches Grade 1 to Grade 3 mathematics through a story. The player is Matthew, a student who is pulled through a portal into a magic world. To return to Earth he must enroll in a magic academy, where math lessons are taught as "spells". He passes each lesson to earn Knowledge Points (KP) and three crystals, and passes a final exam to open the portal home.

The game combines a structured curriculum with a living game world. Learning happens in the academy's classes. Practice also happens outside the classroom: in shops, random town events and seasonal festivals, all of which use the same math skills. Every answer the player gives is recorded, so a teacher or parent can export a learning-analysis report.

## Story and progression

The game follows a fixed story made of chapters, stored in a story file. Each chapter has dialogue and a goal, such as meeting the guide Arith, passing the academy's entrance exam, or attending a class. A checklist in the save data records which chapters are done. The game uses it to restore the player's progress, place characters, and point the quest arrow at the next goal.

The main path is:

1. **Prologue.** Matthew falls through a portal on Earth and arrives in the magic world.
2. **Admission.** He meets Arith, studies with her, and takes the entrance exam.
3. **School life.** He completes Grade 1, Grade 2 and Grade 3. Each grade has 10 lessons, and each lesson day follows the same rhythm: market, class, home, sleep.
4. **Crystals.** Finishing the last lesson of each grade awards a crystal: an emerald, a ruby and a diamond.
5. **Endgame.** After Grade 3 he reviews in the library, passes the final exam, places the three crystals, and opens the portal back to Earth.

## Main features

### Entrance exam
The entrance exam is laid out as a treasure map, with one stop for every page. Each chapter starts with a short visual lesson in which the player taps pictures to count them. That is followed by one question per card. Number answers use an on-screen number pad, and the other questions use large answer tiles. Questions and lessons are read aloud with text-to-speech, written in simple B1 English for young learners. A correct answer moves on to the next card automatically, and a hint appears after two wrong answers.

### Academy classes
The class is the core learning activity. Lessons come from a curriculum file covering Grades 1 to 3 plus a final exam. Each class has two parts:
- **Lecture.** The teacher, Mr. Archimedes (Ma'am Cruz for the final exam), explains the topic step by step on a blackboard, with voice narration.
- **Questions.** Each question uses the input that fits its topic: a number pad, multiple choice, a clock, a number line, patterns, tallies, money, sharing and other interactive "stations". A wrong answer shows the correct answer and an explanation.

Performance is shown as one to three stars. Completing a lesson awards KP based on the grade and lesson number, with a bonus for the last lesson of a grade. Finished lessons can be replayed later for review.

### Day, night and calendar
The world has a running clock and a calendar of four seasons with 28 days each. Time drains the player's stamina, which can be refilled with food.
- At night Matthew goes home to sleep. Sleep is allowed only after 12 noon or before 4 AM.
- The date changes at midnight, or when he wakes up if he went to bed before midnight.
- Each morning starts at 4 AM, and the academy is open every day except on festival days that close it.

Speech bubbles over Matthew's head guide the player. After class he wonders whether to visit the shop before going home. In the morning he reminds himself to hurry to school.

### Shops
Merchants sell items for KP. To buy, the player must solve a money problem, such as working out the change, on a number pad. Shopping becomes practice in subtraction.

### Random events
After waking up and after class, the town may fill with visitors:
- **Riddle visitors** ask review questions taken from lessons the player has already studied.
- **Fetch visitors** ask the player to find lost items and then count them.

Completing an event rewards KP. Unfinished events disappear when the day ends.

### Festivals (major events)
Six festivals are spread across the year: Academy Magic Fest, Easter Holiday, Star Festival, Harvest Fair, Night of Lanterns and Winter Solstice. Each has its own theme song, which plays from 4 AM on the festival day.

At the festival grounds, a host gives the player a stamp card, and each booth is a short math game. The festivals also include:
- item hunts and quests;
- a prize booth and a traveling trader who exchanges special tokens for KP;
- a special ending, such as a lantern release, a prize pumpkin or a winter gift.

Completing all booths earns a badge and bonus KP. Progress is recorded in a festival journal inside the calendar.

### Quest guidance
A quest arrow always points to the current goal: the academy, home at night, a festival, or an active event. When the target is on screen, the arrow locks onto it.

## Data and records

All progress is kept in a local save file, organized like a small database with six tables:

| Table | What it records |
|---|---|
| Checklist | Chapters completed |
| Progress | Current chapter, grade, lesson, location, KP, crystals |
| Streak | Daily streak |
| Calendar | Date and events seen |
| Festival | Festival progress for each year |
| Festival profile | Tokens, best scores, collectibles |

The game keeps a default template of these tables:
- On a new device it creates a complete save file automatically.
- After an update it adds any missing parts to an older save without losing the player's progress.

A separate analysis file records every answer: the date and time, grade, lesson, question, the player's answer, whether it was correct, and whether a hint was used. From Settings this can be exported as CSV tables and graphs for teachers or parents.

## Settings and controls

The Settings menu has:
- music, sound-effect and master volume sliders;
- credits;
- the analysis export;
- **Reset Data**, which erases all progress and the answer log, then rebuilds a fresh save from the template.

The game supports three save slots. On a computer it is played with the keyboard; on phones and tablets it uses an on-screen joystick and buttons.

## Intended users

The system is designed for Grade 1 to Grade 3 learners who are building basic number sense:
- counting, place value, and addition and subtraction;
- skip counting, multiplication and division basics;
- time, money, and patterns.

It is written in simple English, supported by pictures and voice.

Teachers and parents act as secondary users. They can review a learner's performance through the exported analysis report.

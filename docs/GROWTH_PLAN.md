# Cat growth: plan (not implemented yet)

## Goal

The cat visibly grows up, so caring for it over weeks feels meaningful, without ever punishing absence and without death.

## Rules

- Growth is measured in **care days** (`state.login.days`, days the player opened the game), not in calendar time.
  A player who takes a break finds the same cat they left.
- Stages:

  | Stage | Care days | Look | Gameplay |
  |---|---|---|---|
  | Kitten | 0–6 | current sprites, slightly smaller head-to-body ratio | sleeps more (energy decay ×1.2), learns faster (XP ×1.2) |
  | Junior | 7–29 | 1 px taller body, longer legs | balanced (current values) |
  | Adult | 30+ | full-size body, calmer idle | happiness decay ×0.8; unlocks "adult" accessories and a "wise cat" badge |

- A short celebration scene on stage change (confetti, the cat on a cushion, a photo saved automatically to the album).
- The player can't skip or reverse stages. Coat, ears, tail and accessories carry over.

## Technical design

- `CatState.stage` is **derived** (`CatStage(days: login.days)`), so no migration is needed and the rules can be rebalanced later.
- Stage modifiers live in `Balance.stageModifiers[stage]`; `CatSimulator.applyStep` multiplies the relevant rates.
- Art: every body layer gets a stage variant (`cat_kitten_idle_0`, `cat_adult_idle_0`; junior keeps today's names).
  Ears, tail and accessory layers are reused, with a per-stage pixel offset table in `CatNode`, so the art workload is about 14 extra body frames per stage instead of every layer.
- Tests: stage boundaries, modifiers applied, offline days not counted, stage never decreases.

## Open questions for later

- Should the player be able to "keep" kitten looks (a cosmetic toggle) after growing up?
- Multiple cats or adoption: needs a save-format change (`cats: [CatState]`), so plan it separately.

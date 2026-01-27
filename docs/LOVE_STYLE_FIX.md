# LOVE Style Fix (LOVE_A/B/C)

## Summary
- LOVE_A/B/C are now selected per-user and persisted in the `users.love_style` column.
- Romance prompt assembly injects only the chosen style block (LOVE_A or LOVE_B or LOVE_C).
- Prompt content was updated to match the Asuka/Rei/Mari definitions exactly, while allowing romance tone in romance mode.
- Logging now records user_id, arisa_mode, love_style, and the injected section name, plus a system prompt header preview.

## Manual Verification Checklist
1. `/start` → tap 💞恋愛 → `/love_a` → chat 5 turns, confirm Asuka-like dominance (commands, pressure, jealousy).
2. `/love_b` → chat, confirm Rei-like brevity (few words, precise empathy, minimal questions).
3. `/love_c` → chat, confirm Mari-like sweetness (clingy affirmation, close distance, light erotic nuance).

## Notes
- The romance mode uses only the selected LOVE_* block at runtime.
- If no love style is set, the first romance entry assigns a random style for that user and persists it.

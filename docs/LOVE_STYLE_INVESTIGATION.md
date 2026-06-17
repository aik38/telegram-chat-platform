# Love Style Investigation (LOVE_A / LOVE_B / LOVE_C)

## Scope
- Trace `/love_a`, `/love_b`, `/love_c` from command handling to the OpenAI call.
- Identify where `love_style` is set, stored, and read.
- Inspect prompt composition and whether the selected style is injected into LLM messages.

## Trace Summary
1. Admin command handlers map `/love_a`, `/love_b`, `/love_c` to style values and call `set_current_love_style_card`.
2. The love style value is stored only in module-level globals in `bot/arisa_runtime.py`.
3. When a user is in romance mode, `build_arisa_messages` appends `LOVE_STYLE_CARD=<value>` to internal flags.
4. The romance prompt file includes *all* LOVE_A/B/C sections, and no code selects a single section based on the current card.
5. The system prompt used for romance is built from `characters/arisa/prompts/base.txt` + `romance.txt` (full file), plus extra global instructions.

## Key Observations
- Love style selection is not persisted in the DB and is not per-user.
- The value is only included as a raw internal flag line; there is no instruction in prompts telling the model to use this flag to choose a section.
- The romance prompt file contains all three style definitions simultaneously.
- Additional global prompts (system_prompt, boundary_lines, style.md, and `_arisa_tone_prompt`) apply uniformly to every style.

## Conclusion
Love style differentiation is effectively lost because the code never selects or injects a single LOVE_A/B/C block into the system prompt. Instead, all styles are provided together while the selected style is only appended as an internal flag with no explicit use.

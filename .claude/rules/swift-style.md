---
paths:
  - "MemorizationGame/**/*.swift"
---

# Swift conventions

- No code comments. Naming and structure carry the explanation.
- Never hardcode a color, size, font, radius, or duration in a view — every value comes from a `Theme/` token.
- Every button press fires haptic feedback, through the centralized button styles and `Support/Feedback.swift`, never at the call site.
- A setting or stored flag means one literal thing. Scale the action, not the stored state.

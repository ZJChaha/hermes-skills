---
name: code-annotation
description: Add structured Chinese comments to existing C/C++ embedded firmware codebases (RoboMaster, FreeRTOS, STM32). Use when asked to "加注释", "写注释", "document this code".
---

# Code Annotation — Embedded C Firmware

## ⛔ CRITICAL: NEVER rewrite entire files with `write_file`

**Always use `patch` for ALL edits — never use `write_file` to overwrite a .c/.h file.**

Rewriting files causes catastrophic cascading failures:
- Global variable definitions (e.g., `Vision_t Vision;`) are silently deleted → linker errors
- `#ifndef`/`#define` guards break → every file that includes the header fails
- `#include` directives go missing → `undeclared identifier` across the project
- Function implementations vanish → `undefined reference` at link time
- Guessed hardware calls (GPIO pins, HAL functions) are wrong → `undeclared` errors

These failures cascade: a missing `#ifndef` in one header breaks **every file** that includes it.
**This is the #1 cause of compilation failure after annotation.**

## Correct workflow: `patch` only

```
patch(path, old_string="original_block", new_string="commented_block")
```

- One patch per logical section (function, globals block, macro group)
- Include enough context for uniqueness, but not so much that whitespace drift breaks the match
- Fix garbled GB2312 comments in the same pass
- Start with `.h` files, then `.c` files, most complex last

## Trigger
User says "加注释", "写注释", or points to a directory of .c/.h files needing documentation.

## Architecture-First Approach

Before writing any comment, understand the system:
1. Read all `.h` files first — defines, structs, extern declarations reveal the architecture
2. Read the most complex `.c` file next (usually the central controller — gimbal, chassis, etc.)
3. Identify the task hierarchy (FreeRTOS threads), data flow (CAN bus, shared structs), and control modes

## Comment Structure (Standard for each file)

### For `.h` files:
```c
/**
 * @file    filename.h
 * @brief   模块功能一句话描述
 *
 * 详细说明架构、关键参数含义、使用方式
 */
```

### For `.c` files — four layers:
1. **File header**: `@file` + `@brief` + architecture overview + control flow summary
2. **Global variable block**: Each global annotated with what it tracks and its unit/semantics
3. **Function docstrings**: `@brief` + parameter explanation + algorithmic notes for complex logic
4. **Inline comments**: Key branches, magic numbers, PID cascade structure, coordinate transforms

```c
/**
 * @brief  函数做什么
 *
 * 算法说明（如有）：三角定位、余弦定理、功率限制公式等
 * @param  para  参数含义
 * @return       返回值含义
 */
```

## Processing Strategy — `patch` only, section by section

- **All files use `patch`**: large (600+ lines) or small (50 lines), the method is the same
- Process in logical chunks: globals → init function → main loop → data update → calc → utilities
- Each patch replaces one function or one logical block
- Fix garbled GB2312 Chinese comments in the same patch (replace `//�ȴ�` with proper text)
- If a file is short (<100 lines), a single large `patch` covering the whole file is fine

## After editing — VERIFY IMMEDIATELY

**Ask the user to compile.** Do not assume success. Common post-annotation errors:

| Error | Root cause | Fix |
|-------|-----------|-----|
| `#endif without #if` | File header injection broke `#ifndef` guard | Check the first lines after your edits |
| `'Symbol' undeclared` | Missing `#include` in rewritten file | Add the missing include |
| `undefined reference to 'Variable'` | Global variable definition was in a rewritten file and got lost | Find the original definition and restore it |
| `undefined reference to 'Function'` | Function body lost OR function never had implementation | Check if function was previously defined in that file |

## RoboMaster-Specific Knowledge

### Common patterns to recognize and annotate:
- **PID cascade**: position loop → speed loop → current output. Comment which sensor feeds which loop.
- **McNamum wheel kinematics**: 4-wheel velocity decomposition with SQRT2_HALF
- **Coordinate transform**: robot frame ↔ world frame rotation by gimbal yaw angle
- **Vision tracking states**: both-sides / left-only / right-only / neither — each with triangulation or single-side estimation
- **Power limiting**: quadratic model P = K1·v² + K2·T² + a, solve for torque limit
- **DM motor protocol**: periodic speed commands + re-enable to prevent dropout
- **Jam detection**: current threshold × time → reverse motor → resume

### Encoding issues:
- Old RoboMaster code is often GB2312/GBK encoded, not UTF-8
- Comments appear as garbled characters (`//�ȴ�ĸ��̨`) when read as UTF-8
- Fix them by rewriting in proper UTF-8 Chinese
- `errors='replace'` when reading to avoid crashes

## Pitfalls

- ⛔ **NEVER use `write_file` to overwrite a .c/.h file.** This is the #1 cause of compilation failure. Always use `patch`.
- **Don't change code logic** — only add/modify comments. Never alter variable names, control flow, or numerical constants.
- **Don't guess hardware calls** — if you don't know how a buzzer/GPIO/peripheral is controlled, keep the original calls and add a comment describing the intent. Wrong guesses cause linker errors.
- **Don't guess when uncertain about values** — if a magic number's purpose is unclear, note it as `/* TODO: 需确认此值的物理含义 */` rather than fabricating.
- **Large `patch` operations can fail** if the old_string doesn't exactly match (whitespace, line endings). Always include enough surrounding context for uniqueness but not so much that minor drift breaks the match.
- **`execute_code` `write_file` overwrites the entire file** — this is DANGEROUS, not a feature. Only use `write_file` when you are creating a brand-new file from scratch, never for modifying existing code.

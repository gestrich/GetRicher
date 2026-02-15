# CLAUDE.md — Finance Project

## Architecture Skills

This project follows the Swift app architecture defined at https://github.com/gestrich/swift-app-architecture. When working on this codebase, **always** read the following skills before making changes:

### `/swift-architecture` — Code Placement & Structure
- Read the main `SKILL.md` **and all files it references** (layer definitions, dependency rules, placement guidance, feature creation, configuration, code style, reference examples)
- Use when: adding new files, deciding where code belongs, creating features, reviewing architectural compliance
- Err on the side of reading more referenced files than you think you need

### `/swift-swiftui` — UI Patterns
- Read the main `SKILL.md` **and all files it references** (enum-based state, model composition, dependency injection, view state vs model state, view identity, observable model conventions)
- Use when: building SwiftUI views, creating observable models, implementing state management, connecting use cases to UI
- Err on the side of reading more referenced files than you think you need

## General Guidance

- When in doubt about where to place new code, read `/swift-architecture` first
- When in doubt about UI patterns, read `/swift-swiftui` first
- **Read broadly**: if a SKILL.md references other files that are even possibly related to your task, read them too. More context is better than less.

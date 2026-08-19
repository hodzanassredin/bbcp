---
name: bb-skills
description: Index of BlackBox Component Builder skills
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: index
---

## What I do

- Provide navigation to all BlackBox skills
- List available documentation categories
- Show quick start commands

## When to use me

Use when looking for the right skill for your task.

## Skills Directory Structure

```
.agents/skills/
├── cp-language/      # Component Pascal language
├── bb-tutorial/      # Tutorials (Tut-1..Tut-6)
├── system-core/      # Kernel, Files, Stores
├── system-mvc/       # Models, Views, Controllers
├── system-dialog/    # Dialog, Controls
├── system-ports/     # Ports, Fonts, Printing
├── system-utils/     # Strings, Dates, Math
├── system-documents/ # Documents, Converters
├── system-meta/      # Meta-programming
├── text-system/      # TextModels, TextViews
├── form-system/      # FormModels, FormControllers
├── dev-tools/        # DevCompiler, DevDebug
├── std-commands/     # StdCmds, StdDialog
├── obx-examples/     # Example code
└── other-subsystems/ # Crypto, SQL, XHTML
```

## Language & Basics

| Skill | Description |
|-------|-------------|
| [cp-language](cp-language/SKILL.md) | Component Pascal syntax, types, modules |
| [bb-tutorial](bb-tutorial/SKILL.md) | Tutorials: Views, Models, Controllers |

## System Modules

| Skill | Description |
|-------|-------------|
| [system-core](system-core/SKILL.md) | Kernel, Files, Stores |
| [system-mvc](system-mvc/SKILL.md) | Models, Views, Controllers |
| [system-dialog](system-dialog/SKILL.md) | Dialog, Controls |
| [system-ports](system-ports/SKILL.md) | Ports, Fonts, Printing |
| [system-utils](system-utils/SKILL.md) | Strings, Dates, Math |
| [system-documents](system-documents/SKILL.md) | Documents, Converters |
| [system-meta](system-meta/SKILL.md) | Meta-programming |

## Subsystems

| Skill | Description |
|-------|-------------|
| [text-system](text-system/SKILL.md) | TextModels, TextViews |
| [form-system](form-system/SKILL.md) | FormModels, FormControllers |
| [dev-tools](dev-tools/SKILL.md) | DevCompiler, DevDebug |
| [std-commands](std-commands/SKILL.md) | StdCmds, StdDialog |
| [other-subsystems](other-subsystems/SKILL.md) | Crypto, SQL, XHTML |

## Examples

| Skill | Description |
|-------|-------------|
| [obx-examples](obx-examples/SKILL.md) | Code examples from Obx/ |

## Quick Start

### Compile and Run

```bash
# Compile module
echo "DevCompiler.CompileThis ModuleName" | ./run-BlackBoxInterp

# Run command
echo "ModuleName.CommandName" | ./run-BlackBoxInterp

# Compile subsystem
echo "DevCompiler.CompileSubs Obx" | ./run-BlackBoxInterp
```

### Convert Documentation

```bash
odcey text ./Docu/CP-Lang.odc
odcey text ./System/Docu/Views.odc
```

### Edit .odc Files

```bash
# Convert to text
odcey text ./file.odc > ./file.odc.txt

# Edit the .txt file

# Convert back
echo 'OdxEditor.Do "file.odc.txt" "file.odc"' | ./run-BlackBoxInterp
```

## Key Concepts

1. **Model-View-Controller** - Separate data, display, and input
2. **Stores** - Serializable objects with undo/redo
3. **Messages** - Broadcast notifications between components
4. **Hooks** - Extension points for platform-specific code
5. **Interactors** - Global records bound to UI controls

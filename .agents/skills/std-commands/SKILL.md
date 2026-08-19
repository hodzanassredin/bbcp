---
name: std-commands
description: Standard commands and dialogs
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: Std
---

## What I do

- Document StdCmds for file and view operations
- Explain dialog opening patterns
- Cover StdLog for output
- Show string resources usage

## When to use me

Use when opening dialogs, working with files, or logging output.

## Documentation Source

`Std/Docu/Cmds.odc`, `Std/Docu/Dialog.odc`

## StdCmds

Standard command library.

### File Operations

```oberon
StdCmds.Open           (* Open file dialog *)
StdCmds.OpenDoc        (* Open document *)
StdCmds.Save           (* Save current document *)
StdCmds.SaveAs         (* Save with new name *)
StdCmds.Close          (* Close document *)
```

### Dialog Operations

```oberon
(* Auxiliary dialog - standalone, for data entry *)
StdCmds.OpenAuxDialog('Obx/Rsrc/PhoneUI', 'Phone Database');

(* Tool dialog - works with document below it *)
StdCmds.OpenToolDialog('Text/Rsrc/Cmds', 'Find / Replace');
```

### View Operations

```oberon
StdCmds.CloseView      (* Close current view *)
StdCmds.FocusView      (* Set focus to view *)
```

### Clipboard

```oberon
StdCmds.Copy           (* Copy to clipboard *)
StdCmds.Cut            (* Cut to clipboard *)
StdCmds.Paste          (* Paste from clipboard *)
```

### Guards

```oberon
StdCmds.UnloadGuard    (* Guard for unload operation *)
```

### Parameterized Commands

```oberon
(* With string parameter *)
StdCmds.OpenAuxDialog('Obx/Rsrc/MyDialog', 'Title')

(* Color guard with integer parameter *)
StdCmds.ColorGuard(00000FFH)
```

## StdDialog

Standard dialog module (private, but important).

### Preferences

```oberon
VAR prefs*: RECORD
    scaleFactor*: INTEGER;  (* 50-200, display scaling *)
    language*: INTEGER;
    ...
END;
```

### Dialog Types

1. **Auxiliary Window** - Self-contained dialog for data entry
2. **Tool Window** - Dialog for working with document below

### FormControllers.Focus Behavior

- In **Tool Window**: Returns form in top document window
- In **Auxiliary Window**: Returns form of the dialog itself

## StdLog / Log

Logging output.

```oberon
IMPORT Log;

Log.String("message"); Log.Ln;  (* output with newline *)
Log.Int(42); Log.Ln;            (* output integer *)
Log.Char('X');                  (* output character *)
Log.Real(3.14); Log.Ln;         (* output real *)
Log.Hex(255, 8); Log.Ln;        (* output hex *)
```

## StdLoader

Module loading and unloading.

```oberon
IMPORT StdLoader;

(* Unload module *)
StdLoader.Unload("ModuleName");
```

## StdInterpreter

Command interpretation.

```oberon
IMPORT StdInterpreter;

(* Execute command string *)
StdInterpreter.Call("ModuleName.CommandName", res);
```

## Menu Registration

Add commands to menus via `System/Rsrc/Menus`:

```
MENU "Tools"
    "My Command"    ""    "MyModule.Do"    "MyModule.Guard"
END
```

Then: `Info -> Update Menus`

## String Resources

Store localized strings in `<Subsystem>/Rsrc/Strings`:

```
STRINGS
On       Switch On
Off      Switch Off
list[0]  First Option
list[1]  Second Option
```

Use in code:
```oberon
par.label := "#Obx:On";  (* looks up "On" in Obx/Rsrc/Strings *)
```

## Converting Documentation

```bash
odcey text ./Std/Docu/Cmds.odc
odcey text ./Std/Docu/Dialog.odc
odcey text ./Std/Docu/Log.odc
odcey text ./Std/Docu/Interpreter.odc
odcey text ./Std/Docu/Loader.odc
```

---
name: system-dialog
description: Dialog and Controls system for UI
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: System
---

## What I do

- Explain Dialog module for interactors
- Document Guards and Notifiers patterns
- Cover control types and their properties
- Show string resources usage

## When to use me

Use when building dialogs, working with controls, or implementing UI interactivity.

## Documentation Source

`System/Docu/Dialog.odc`, `System/Docu/Controls.odc`

## Dialog Module

Core dialog and interactor support.

### Platform Constants

```oberon
CONST
    windows* = 10;
    linux* = 30;
    freebsd* = 50;
    openbsd* = 51;
    netbsd* = 52;
```

### Interactors

An interactor is a global record with exported fields bound to controls:

```oberon
VAR
    phone*: RECORD
        name*, number*: ARRAY 64 OF CHAR;
        lookupByName*: BOOLEAN
    END;
```

### Dialog.Update

Refreshes all controls bound to an interactor:
```oberon
Dialog.Update(phone);  (* after modifying phone fields *)
```

### Dialog.List, Dialog.Selection, Dialog.Combo

Complex control types:

```oberon
VAR
    list*: Dialog.List;       (* ListBox *)
    sel*: Dialog.Selection;   (* SelectionBox *)
    combo*: Dialog.Combo;     (* ComboBox *)

(* Initialize list *)
list.SetLen(3);
list.SetItem(0, "Option A");
list.SetItem(1, "Option B");
list.SetItem(2, "Option C");
Dialog.UpdateList(list);  (* refresh items *)

(* Or from resources *)
list.SetResources("#Obx:options");  (* reads from Obx/Rsrc/Strings *)
```

## Guards

Guards control state of controls: enabled/disabled, read-only, undefined.

```oberon
PROCEDURE XyzGuard* (VAR par: Dialog.Par);
BEGIN
    par.disabled := ...    (* TRUE = disabled *)
    par.readOnly := ...    (* TRUE = read-only *)
    par.undef := ...       (* TRUE = undefined *)
    par.label := "..."     (* change label *)
    par.checked := ...     (* for menu items *)
END XyzGuard;
```

### Guard Rules

- May set only one of: `disabled`, `readOnly`, `undef` to TRUE
- Should not have side effects
- Must be efficient (called frequently)
- Must be exported (`*`)

### Parameterized Guards

```oberon
PROCEDURE ColorGuard* (color: INTEGER; VAR par: Dialog.Par);
BEGIN
    par.checked := (currentColor = color)
END ColorGuard;

(* In menu: StdCmds.ColorGuard(00000FFH) *)
```

## Notifiers

Notifiers are called on user interaction.

```oberon
PROCEDURE XyzNotifier* (op, from, to: INTEGER);
BEGIN
    IF op = Dialog.changed THEN
        (* value changed *)
    ELSIF op = Dialog.pressed THEN
        (* button pressed / mouse down *)
    ELSIF op = Dialog.released THEN
        (* button released / mouse up *)
    END
END XyzNotifier;
```

### op Values

| op | Meaning |
|----|---------|
| Dialog.pressed | Mouse/button down |
| Dialog.released | Mouse/button up |
| Dialog.changed | Value changed |
| Dialog.included | Set element added |
| Dialog.excluded | Set element removed |
| Dialog.set | Selection changed |

## Control Types

| Type | Description |
|------|-------------|
| Caption | Static text |
| PushButton | Command button |
| TextField | Text input |
| CheckBox | Boolean flag |
| RadioButton | Selection from group |
| ListBox | List selection |
| SelectionBox | Multiple selection |
| ComboBox | Editable dropdown |
| DateField | Date input |
| TimeField | Time input |
| ColorField | Color picker |
| UpDown | Spinner control |

## Showing Messages

```oberon
Dialog.ShowMsg("Operation completed");
Dialog.ShowStatus("Ready");
Dialog.ShowParamMsg("^0 items found", count$);
```

## String Resources

```oberon
(* Use localized string *)
par.label := "#Obx:On";  (* looks up in Obx/Rsrc/Strings *)

(* With parameters *)
Dialog.MapParamString(key, s0, s1, s2, s3, OUT result);
```

## Hooks

Hooks allow platform-specific implementations:

| Hook | Purpose |
|------|---------|
| GetHook | Dialog boxes (GetOK, GetColor, etc.) |
| ShowHook | Message display |
| BeepHook | Sound feedback |
| HostLocHook | Path handling |
| FontsHook | Font management |

## Converting Documentation

```bash
odcey text ./System/Docu/Dialog.odc
odcey text ./System/Docu/Controls.odc
```

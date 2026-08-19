---
name: bb-tutorial
description: BlackBox tutorials covering MVC architecture
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: documentation
---

## What I do

- Guide through BlackBox tutorials (Tut-1 to Tut-6)
- Explain user interaction and event loops
- Cover Views, Models, Controllers pattern
- Describe containers and advanced topics

## When to use me

Use when learning BlackBox architecture, understanding the MVC pattern, or following the tutorial series.

## Documentation Source

`Docu/Tut-1.odc` through `Docu/Tut-6.odc`, `Docu/Tut-A.odc`, `Docu/Tut-B.odc`

## Tutorial Structure

| File | Content |
|------|---------|
| Tut-1 | User Interaction, Event Loops, Object-Oriented Programming |
| Tut-2 | Views - drawing, handling messages, embedding |
| Tut-3 | Models - data management, undo/redo, broadcasting |
| Tut-4 | Controllers - input handling, focus, selection |
| Tut-5 | Containers - compound documents, embedded views |
| Tut-6 | Advanced topics - meta-programming, scripting |
| Tut-A | Appendix A - Framework Architecture |
| Tut-B | Appendix B - BlackBox Philosophy |

## Tut-1: User Interaction

Key concepts:
- User-friendliness and non-modal interfaces
- Event loops and inverted programming (frameworks)
- Object-oriented programming for UI

BlackBox is **non-modal**: every dialog is non-modal, users can always switch between tasks.

## Tut-2: Views

A View is the contents of a window. Views handle:
- Drawing (`Restore` method)
- Messages (`HandleViewMsg`, `HandleCtrlMsg`, `HandleModelMsg`)
- Properties (`HandlePropMsg`)

```oberon
TYPE
    MyView = POINTER TO RECORD (Views.View)
        data: INTEGER
    END;

PROCEDURE (v: MyView) Restore (f: Views.Frame; l, t, r, b: INTEGER);
BEGIN
    f.DrawRect(l, t, r, b, Ports.fill, Ports.white);
    f.DrawString(l, t, Ports.black, "Hello", f.rider.font)
END Restore;
```

## Tut-3: Models

A Model represents data. Views display models.
- Multiple views can display the same model
- Models broadcast changes to views
- Undo/redo through Operations

```oberon
TYPE
    MyModel = POINTER TO RECORD (Models.Model)
        items: ItemList
    END;

PROCEDURE (m: MyModel) Modify (...);
BEGIN
    Models.Broadcast(m, msg)  (* notify views *)
END Modify;
```

## Tut-4: Controllers

Controllers handle input:
- Mouse events
- Keyboard events
- Focus management
- Selection

```oberon
PROCEDURE (c: MyController) HandleCtrlMsg (f: Views.Frame; 
    VAR msg: Controllers.Message; VAR focus: Views.View);
BEGIN
    IF msg IS Controllers.WheelMsg THEN
        (* handle mouse wheel *)
    ELSIF msg IS Controllers.PollOpsMsg THEN
        (* enable/disable operations *)
    END
END HandleCtrlMsg;
```

## Tut-5: Containers

Containers hold embedded views:
- Text with embedded views
- Forms with controls
- Compound documents

## Tut-6: Advanced Topics

- Meta-programming (reflection)
- Scripting
- Dynamic loading

## Converting Tutorials

```bash
odcey text ./Docu/Tut-1.odc
odcey text ./Docu/Tut-2.odc
odcey text ./Docu/Tut-3.odc
odcey text ./Docu/Tut-4.odc
odcey text ./Docu/Tut-5.odc
odcey text ./Docu/Tut-6.odc
odcey text ./Docu/Tut-A.odc
odcey text ./Docu/Tut-B.odc
```

## Running Examples

Examples are in `Obx/Mod/`:
```bash
# Compile and run
echo "DevCompiler.CompileThis ObxViews1" | ./run-BlackBoxInterp
```

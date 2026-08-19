---
name: system-mvc
description: Model-View-Controller architecture in BlackBox
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: System
---

## What I do

- Explain MVC architecture pattern
- Document Models, Views, Controllers APIs
- Show message broadcasting patterns
- Cover view rendering and input handling

## When to use me

Use when implementing custom views, models, or controllers, or understanding BlackBox architecture.

## Documentation Source

`System/Docu/Models.odc`, `System/Docu/Views.odc`, `System/Docu/Controllers.odc`

## Architecture

```
┌─────────────┐     updates      ┌─────────────┐
│    View     │ ◄─────────────── │    Model    │
│ (display)   │                  │   (data)    │
└─────────────┘                  └─────────────┘
       ▲                                ▲
       │ user input                     │ modifications
       │                                │
┌─────────────┐                  ┌─────────────┐
│ Controller  │ ───────────────► │    Model    │
│   (input)   │   modifications  │             │
└─────────────┘                  └─────────────┘
```

## Models

Models represent data and notify views of changes.

```oberon
IMPORT Models;

TYPE
    MyModel = POINTER TO ABSTRACT RECORD (Models.Model)
        data: INTEGER
    END;

(* Broadcast changes to views *)
PROCEDURE Modify (m: MyModel; newValue: INTEGER);
VAR msg: Models.UpdateMsg;
BEGIN
    Models.BeginModification(Models.clean, m);
    m.data := newValue;
    Models.EndModification(Models.clean, m);
    msg.model := m;
    Models.Broadcast(m, msg)
END Modify;

(* Undoable modification *)
PROCEDURE UndoableModify (m: MyModel; newValue: INTEGER);
VAR op: ModifyOp;
BEGIN
    op := NewModifyOp(m, newValue);
    Models.Do(m, "Modify", op)  (* undoable *)
END UndoableModify;
```

### Model Context

For embedded views:
```oberon
TYPE
    Context = POINTER TO ABSTRACT RECORD
        (c: Context) ThisModel (): Model, NEW, ABSTRACT;
        (c: Context) GetSize (OUT w, h: INTEGER), NEW, ABSTRACT;
        (c: Context) SetSize (w, h: INTEGER), NEW, EMPTY
    END;
```

## Views

Views display models and handle messages.

```oberon
IMPORT Views, Ports;

TYPE
    MyView = POINTER TO RECORD (Views.View)
        model: MyModel
    END;

(* Draw the view *)
PROCEDURE (v: MyView) Restore (f: Views.Frame; l, t, r, b: INTEGER);
BEGIN
    f.DrawRect(l, t, r, b, Ports.fill, Ports.white);
    IF v.model # NIL THEN
        (* draw based on model data *)
    END
END Restore;

(* Handle model change notifications *)
PROCEDURE (v: MyView) HandleModelMsg- (VAR msg: Models.Message);
BEGIN
    IF msg IS Models.UpdateMsg THEN
        Views.Update(v, Views.keepFrames)  (* redraw *)
    END
END HandleModelMsg;

(* Handle view messages *)
PROCEDURE (v: MyView) HandleViewMsg- (f: Views.Frame; VAR msg: Views.Message);
BEGIN
    IF msg IS Views.NotifyMsg THEN
        (* view was modified *)
    END
END HandleViewMsg;
```

### View Properties

```oberon
PROCEDURE (v: MyView) HandlePropMsg- (VAR p: Views.PropMessage);
BEGIN
    IF p IS Properties.SizePref THEN
        p(Properties.SizePref).w := 100 * Ports.mm;
        p(Properties.SizePref).h := 50 * Ports.mm
    END
END HandlePropMsg;
```

## Controllers

Controllers handle user input (mouse, keyboard).

```oberon
IMPORT Controllers;

TYPE
    MyController = POINTER TO RECORD (Controllers.Controller)
        view: MyView
    END;

(* Handle control messages *)
PROCEDURE (c: MyController) HandleCtrlMsg (f: Views.Frame; 
    VAR msg: Controllers.Message; VAR focus: Views.View);
BEGIN
    IF msg IS Controllers.PollMsg THEN
        (* poll for capabilities *)
        msg(Controllers.PollMsg).valid := {Controllers.copy, Controllers.paste}
    ELSIF msg IS Controllers.EditMsg THEN
        (* edit operations: cut, copy, paste, delete *)
        CASE msg(Controllers.EditMsg).op OF
        | Controllers.copy: ...
        | Controllers.paste: ...
        END
    END
END HandleCtrlMsg;
```

### Mouse Input

```oberon
PROCEDURE (c: MyController) HandleCtrlMsg (...);
BEGIN
    IF msg IS Controllers.TrackMsg THEN
        (* mouse tracking *)
        Controllers.MarkRect(f, l, t, r, b, Ports.hilite);
        REPEAT
            f.MarkRect(l, t, r, b, Ports.hilite);
            Controllers.CollectInput(f, x, y, modifiers, isDown);
            (* update based on mouse position *)
        UNTIL ~isDown
    ELSIF msg IS Controllers.PollOpsMsg THEN
        (* enable/disable operations based on context *)
    END
END HandleCtrlMsg;
```

## Broadcasting Messages

```oberon
(* To all views in a domain *)
Models.Broadcast(model, msg);
Views.Domaincast(domain, msg);

(* To all views globally *)
Views.Omnicast(msg);
```

## Converting Documentation

```bash
odcey text ./System/Docu/Models.odc
odcey text ./System/Docu/Views.odc
odcey text ./System/Docu/Controllers.odc
odcey text ./System/Docu/Containers.odc
```

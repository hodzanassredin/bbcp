---
name: form-system
description: Form models and controllers for dialogs
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: Form
---

## What I do

- Explain FormModels for layout containers
- Document FormControllers for input handling
- Show how to create and open dialogs
- Cover control iteration patterns

## When to use me

Use when building dialogs, forms, or tool windows.

## Documentation Source

`Form/Docu/Models.odc`, `Form/Docu/Views.odc`, `Form/Docu/Controllers.odc`

## Overview

Forms are container models that hold rectangular views (controls) in arbitrary layouts. Used for:
- Data entry dialogs
- Tool windows
- Property inspectors

## FormModels

Container model for views.

```oberon
IMPORT FormModels, Views, Ports;

VAR form: FormModels.Model;
    view: Views.View;
BEGIN
    form := FormModels.dir.New();
    
    (* Insert view at position *)
    form.Insert(view, 10*Ports.mm, 10*Ports.mm, 100*Ports.mm, 30*Ports.mm);
    
    (* Delete view *)
    form.Delete(view);
    
    (* Resize view *)
    form.Resize(view, l, t, r, b);
    
    (* Move view *)
    form.Move(view, dx, dy);
    
    (* Copy view *)
    form.Copy(view, dx, dy);
END;
```

### Form Reader/Writer

```oberon
VAR rd: FormModels.Reader; wr: FormModels.Writer; v: Views.View;
BEGIN
    rd := form.NewReader(NIL);
    rd.ReadView(v);
    WHILE v # NIL DO
        (* process view *)
        rd.ReadView(v)
    END;
    
    wr := form.NewWriter(NIL);
    wr.WriteView(newView, l, t, r, b);
END;
```

### Context

Each embedded view has a context:
```oberon
TYPE
    Context = POINTER TO ABSTRACT RECORD (Models.Context)
        (c: Context) ThisModel (): FormModels.Model, ABSTRACT;
        (c: Context) GetRect (OUT l, t, r, b: INTEGER), NEW, ABSTRACT
    END;
```

## FormControllers

Handle form editing and control interaction.

```oberon
IMPORT FormControllers;

VAR c: FormControllers.Controller;
    sel: FormControllers.List;
BEGIN
    c := FormControllers.Focus();  (* get focused form *)
    IF c # NIL THEN
        (* Access form model *)
        c.form;
        
        (* Check selection *)
        IF c.HasSelection() THEN
            sel := c.GetSelection();
            WHILE sel # NIL DO
                (* sel.view is selected view *)
                sel := sel.next
            END
        END
    END
END;
```

### Iterating Controls in Form

```oberon
PROCEDURE IterateControls (c: FormControllers.Controller);
VAR rd: FormModels.Reader; v: Views.View;
BEGIN
    IF c # NIL THEN
        rd := c.form.NewReader(NIL);
        rd.ReadView(v);
        WHILE v # NIL DO
            IF v IS Controls.Control THEN
                (* work with v(Controls.Control) *)
            END;
            rd.ReadView(v)
        END
    END
END IterateControls;
```

## Creating Forms

### Visual Editor

```bash
# In BlackBox GUI:
Controls -> New Form -> Empty
# Add controls from Controls menu
# Set properties: Edit -> Object Properties
# Save: File -> Save -> MySubsys/Rsrc/MyForm
```

### Programmatic Creation

```oberon
PROCEDURE CreateForm;
VAR form: FormModels.Model; v: Views.View;
BEGIN
    form := FormModels.dir.New();
    v := Controls.NewCaption("Label", NIL);
    form.Insert(v, 10*Ports.mm, 10*Ports.mm, 50*Ports.mm, 20*Ports.mm);
    ...
END CreateForm;
```

## Opening Dialogs

```oberon
IMPORT StdCmds;

(* Auxiliary dialog - standalone *)
StdCmds.OpenAuxDialog('Obx/Rsrc/PhoneUI', 'Phone Database');

(* Tool dialog - works with document below *)
StdCmds.OpenToolDialog('Text/Rsrc/Cmds', 'Find / Replace');
```

## Auto-Generated Forms

BlackBox can auto-generate a form from an interactor:

```bash
# In BlackBox GUI:
Controls -> New Form -> Create
# Enter module name with interactor
```

## Converting Documentation

```bash
odcey text ./Form/Docu/Models.odc
odcey text ./Form/Docu/Views.odc
odcey text ./Form/Docu/Controllers.odc
odcey text ./Form/Docu/Cmds.odc
odcey text ./Form/Docu/Gen.odc
```

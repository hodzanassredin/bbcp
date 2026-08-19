---
name: text-system
description: Text models and views for text processing
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: Text
---

## What I do

- Explain TextModels for text data management
- Document TextViews for text display
- Cover TextControllers for editing
- Show TextMappers for parsing

## When to use me

Use when working with text documents, text editors, or parsing text.

## Documentation Source

`Text/Docu/Models.odc`, `Text/Docu/Views.odc`, `Text/Docu/Controllers.odc`

## TextModels

Text model with readers and writers.

```oberon
IMPORT TextModels;

VAR t: TextModels.Model;
    rd: TextModels.Reader;
    wr: TextModels.Writer;
    pos, len: INTEGER;
BEGIN
    t := TextModels.dir.New();  (* create empty text *)
    len := t.Length();          (* get length *)
END;
```

### Special Characters

```oberon
CONST
    viewcode = 2X;      (* embedded view marker *)
    tab = 9X;           (* tab *)
    line = 0DX;         (* line break / carriage return *)
    para = 0EX;         (* paragraph break *)
    zwspace = 8BX;      (* zero-width space *)
    nbspace = 0A0X;     (* non-breaking space *)
```

### Reading Text

```oberon
PROCEDURE ReadAllText (t: TextModels.Model; OUT str: ARRAY OF CHAR);
VAR rd: TextModels.Reader; ch: CHAR; i: INTEGER;
BEGIN
    i := 0;
    rd := t.NewReader(NIL);
    rd.SetPos(0);
    rd.ReadChar(ch);
    WHILE ~rd.eos DO
        str[i] := ch;
        INC(i);
        rd.ReadChar(ch)
    END;
    str[i] := 0X
END ReadAllText;

(* Read with attributes *)
rd.ReadPrev(view, pos, attr);  (* get view at position *)
```

### Writing Text

```oberon
PROCEDURE WriteText (t: TextModels.Model; IN str: ARRAY OF CHAR);
VAR wr: TextModels.Writer;
BEGIN
    wr := t.NewWriter(NIL);
    wr.SetPos(t.Length());  (* append at end *)
    wr.WriteString(str)
END WriteText;
```

### Modifying Text

```oberon
(* Delete range *)
t.Delete(beg, end);

(* Insert text from another model *)
t.InsertCopy(pos, source, beg, end);

(* Replace range *)
t.Replace(beg, end, source, beg0, end0);
```

### Text Attributes

```oberon
TYPE
    Attributes = POINTER TO RECORD
        color-: Ports.Color;
        font-: Fonts.Font;
        offset-: INTEGER;  (* superscript/subscript *)
    END;

(* Set attributes for range *)
t.SetAttr(beg, end, attr);

(* Get properties for range *)
prop := t.Prop(beg, end);
```

### Embedding Views

```oberon
wr.WriteView(view, l, t, r, b);  (* embed view in text *)
```

## TextViews

View for displaying text models.

```oberon
IMPORT TextViews;

VAR v: TextViews.View;
BEGIN
    v := TextViews.dir.New(t);  (* create view for text model *)
    v := TextViews.dir.New(t, 0, t.Length());  (* with range *)
END;
```

### Selection

```oberon
PROCEDURE GetSelection (v: TextViews.View; OUT beg, end: INTEGER);
BEGIN
    IF v.HasSelection() THEN
        v.GetSelection(beg, end)
    END
END GetSelection;
```

## TextControllers

Handle text editing and navigation.

```oberon
IMPORT TextControllers;

VAR c: TextControllers.Controller;
BEGIN
    c := TextControllers.Focus();
    IF c # NIL THEN
        (* c.view is the TextViews.View *)
        (* c.text is the TextModels.Model *)
    END
END;
```

## TextMappers

Parse text into structured values.

```oberon
IMPORT TextMappers;

VAR scan: TextMappers.Scanner;
    fmt: TextMappers.Formatter;
BEGIN
    scan.ConnectTo(t);
    scan.SetPos(0);
    scan.Scan;  (* read next token *)
    WHILE scan.type # TextMappers.eot DO
        CASE scan.type OF
        | TextMappers.int: x := scan.int;
        | TextMappers.real: x := scan.real;
        | TextMappers.string: s := scan.string;
        END;
        scan.Scan
    END;
    
    fmt.ConnectTo(t);
    fmt.WriteString("Value: ");
    fmt.WriteInt(42);
END;
```

## Converting Documentation

```bash
odcey text ./Text/Docu/Models.odc
odcey text ./Text/Docu/Views.odc
odcey text ./Text/Docu/Controllers.odc
odcey text ./Text/Docu/Rulers.odc
odcey text ./Text/Docu/Mappers.odc
odcey text ./Text/Docu/Setters.odc
```

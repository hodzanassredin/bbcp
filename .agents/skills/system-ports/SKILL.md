---
name: system-ports
description: Graphics, fonts, and printing
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: System
---

## What I do

- Document Ports module for graphics
- Explain Fonts for typography
- Cover Printing for output

## When to use me

Use when drawing in views, working with fonts, or printing.

## Documentation Source

`System/Docu/Ports.odc`, `System/Docu/Fonts.odc`, `System/Docu/Printing.odc`

## Ports Module

Platform abstraction for graphics output.

### Constants

```oberon
CONST
    point = 1;       (* 1/72 inch *)
    mm = 100;        (* 1/100 mm *)
    inch = 72 * mm;  (* 1 inch = 72 points *)
```

### Color

```oberon
TYPE Color = INTEGER;

CONST
    white = 0FFFFFFH;
    black = 0;
    red = 0FF0000H;
    green = 000FF00H;
    blue = 00000FFH;
    transparent = 0FF000000H;
```

### Frame

Drawing context (abstract):
```oberon
TYPE
    Frame = POINTER TO ABSTRACT RECORD
        (f: Frame) DrawRect (x, y, w, h, mode: INTEGER; color: Color), NEW, ABSTRACT;
        (f: Frame) DrawLine (x0, y0, x1, y1, mode: INTEGER; color: Color), NEW, ABSTRACT;
        (f: Frame) DrawString (x, y: INTEGER; color: Color; IN str: ARRAY OF CHAR; font: Fonts.Font), NEW, ABSTRACT;
        (f: Frame) DrawOval (x, y, w, h, mode: INTEGER; color: Color), NEW, ABSTRACT;
        (f: Frame) DrawPath (IN data: ARRAY OF BYTE; size: INTEGER; ...), NEW, ABSTRACT;
        (f: Frame) MarkRect (x, y, w, h, mode: INTEGER; color: Color), NEW, ABSTRACT;
        rider: Files.Rider;  (* for coordinate conversion *)
    END;
```

### Drawing Modes

```oberon
CONST
    paint = 0;      (* source overwrites destination *)
    invert = 1;     (* XOR with destination *)
    hilite = 2;     (* highlight mode *)
    fill = 0;       (* fill shape *)
    frame = 1;      (* draw outline only *)
```

### Drawing in View.Restore

```oberon
PROCEDURE (v: MyView) Restore (f: Views.Frame; l, t, r, b: INTEGER);
BEGIN
    (* Clear background *)
    f.DrawRect(l, t, r - l, b - t, Ports.fill, Ports.white);
    
    (* Draw line *)
    f.DrawLine(l, t, r, b, Ports.paint, Ports.black);
    
    (* Draw string *)
    f.DrawString(l, t + 12*Ports.point, Ports.black, "Hello", f.rider.font);
    
    (* Draw rectangle outline *)
    f.DrawRect(l, t, 100*Ports.mm, 50*Ports.mm, Ports.frame, Ports.red);
    
    (* Highlight/selection *)
    f.MarkRect(sl, st, sw, sh, Ports.hilite, Ports.transparent);
END Restore;
```

### Coordinate System

- Origin at top-left
- Y increases downward
- Units in 1/100 mm (Ports.mm)

## Fonts

```oberon
IMPORT Fonts;

VAR font: Fonts.Font;
BEGIN
    (* Get font by name and size *)
    font := Fonts.dir.This("Arial", 12 * Fonts.point);
    
    (* Font properties *)
    font.height;    (* total height *)
    font.ascent;    (* above baseline *)
    font.descent;   (* below baseline *)
    font.width;     (* average width *)
END;
```

### Font Attributes

```oberon
TYPE
    Font = POINTER TO ABSTRACT RECORD (Stores.Store)
        typeface-: ARRAY 32 OF CHAR;
        size-, style-, weight-: INTEGER;
    END;

CONST
    normal = 0; bold = 1;       (* weight *)
    roman = 0; italic = 1;      (* style *)
```

## Printing

```oberon
IMPORT Printing;

VAR printer: Printing.Printer;
BEGIN
    printer := Printing.dir.Current();
    IF printer # NIL THEN
        Printing.Print(printer, view, pageList)
    END
END;
```

### Print Hook

```oberon
TYPE
    Hook = POINTER TO ABSTRACT RECORD
        (h: Hook) PageSetup (VAR page: Page), NEW, ABSTRACT;
        (h: Hook) GetPrinterList (OUT list: PrinterList), NEW, ABSTRACT;
    END;
```

## Converting Documentation

```bash
odcey text ./System/Docu/Ports.odc
odcey text ./System/Docu/Fonts.odc
odcey text ./System/Docu/Printing.odc
```

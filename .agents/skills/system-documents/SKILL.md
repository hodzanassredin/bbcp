---
name: system-documents
description: Document management and file format converters
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: System
---

## What I do

- Document StdDocuments for window/file management
- Explain Converters for file format handling
- Cover Properties for view attributes

## When to use me

Use when working with documents, importing/exporting files, or handling properties.

## Documentation Source

`System/Docu/Documents.odc`, `System/Docu/Converters.odc`

## StdDocuments

Document management (windows, files).

```oberon
IMPORT StdDocuments;

TYPE
    Document = POINTER TO RECORD (Stores.Store)
        view-: Views.View;
        domain-: Stores.Domain;
    END;
```

### Import/Export .odc Files

```oberon
PROCEDURE ImportDocument (loc: Files.Locator; IN name: Files.Name;
                          OUT doc: Document; OUT res: INTEGER);

PROCEDURE ExportDocument (loc: Files.Locator; IN name: Files.Name;
                          doc: Document; OUT res: INTEGER);
```

### Usage

```oberon
VAR doc: StdDocuments.Document; loc: Files.Locator; name: Files.Name; res: INTEGER;
BEGIN
    loc := Files.dir.This("Obx/Rsrc");
    name := "MyDoc";
    doc := StdDocuments.ImportDocument(loc, name, res);
    IF res = 0 THEN
        (* doc.view is the root view *)
    END;
    
    StdDocuments.ExportDocument(loc, "Output", doc, res);
END;
```

### Document Registry

```oberon
(* Iterate open documents *)
StdDocuments.GetFirst(loc, d);
WHILE d # NIL DO
    (* process document d *)
    StdDocuments.GetNext(d)
END;
```

## Converters

File format conversion framework.

### Registration

```oberon
Converters.Register(
    "ModuleName.ImportProc",   (* import procedure *)
    "ModuleName.ExportProc",   (* export procedure *)
    "Description",             (* file type description *)
    "ext",                     (* file extension *)
    {}                         (* options *)
);
```

### Import Procedure

```oberon
PROCEDURE ImportProc (loc: Files.Locator; IN name: Files.Name;
                      OUT conv: Converters.Converter; OUT view: Views.View;
                      OUT isApp: BOOLEAN; OUT res: INTEGER);
VAR f: Files.File; rd: Files.Reader;
BEGIN
    f := Files.dir.Old(loc, name, Files.read);
    IF f = NIL THEN res := 1; RETURN END;
    rd := f.NewReader(NIL);
    (* read file and create view *)
    view := CreateViewFromFile(rd);
    res := 0
END ImportProc;
```

### Export Procedure

```oberon
PROCEDURE ExportProc (loc: Files.Locator; IN name: Files.Name;
                      conv: Converters.Converter; view: Views.View;
                      OUT res: INTEGER);
VAR f: Files.File; wr: Files.Writer;
BEGIN
    f := Files.dir.New(loc, Files.dontAsk);
    wr := f.NewWriter(NIL);
    (* write view to file *)
    WriteViewToFile(wr, view);
    wr.Update;
    Files.dir.Register(f);
    res := 0
END ExportProc;
```

### Built-in Converters

| Format | Extension | Module |
|--------|-----------|--------|
| Oberon Document | .odc | StdDocuments |
| Text | .txt, .text | TextDocs |
| Rich Text | .rtf | StdRtf |
| HTML | .htm, .html | Xhtml |

### Query Converters

```oberon
VAR list: Converters.List;
BEGIN
    list := Converters.list;
    WHILE list # NIL DO
        (* list.conv is the converter *)
        (* list.conv.fileType is description *)
        (* list.conv.ext is extension *)
        list := list.next
    END
END;
```

## Properties

Property inspection and modification.

```oberon
IMPORT Properties;

TYPE
    Property = POINTER TO ABSTRACT RECORD (Stores.Store)
        next: Property
    END;
```

### Property Messages

```oberon
TYPE
    SizePref = RECORD (Property)
        w, h: INTEGER;
        wRel, hRel: INTEGER
    END;
    
    FocusPref = RECORD (Property)
        set: BOOLEAN
    END;
```

## Converting Documentation

```bash
odcey text ./System/Docu/Documents.odc
odcey text ./System/Docu/Converters.odc
odcey text ./System/Docu/Properties.odc
```

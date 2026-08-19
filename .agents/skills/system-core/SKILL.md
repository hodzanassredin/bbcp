---
name: system-core
description: Core system modules - Kernel, Files, Stores
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: System
---

## What I do

- Explain Kernel module loading and type system
- Cover Files API for file I/O
- Document Stores serialization framework
- Show undo/redo with Operations

## When to use me

Use when working with file I/O, serialization, module loading, or implementing undo/redo.

## Documentation Source

`System/Docu/Kernel.odc`, `System/Docu/Files.odc`, `System/Docu/Stores.odc`

## Kernel

Core runtime services:
- Module loading and unloading
- Memory management (garbage collection)
- Type registration and checking
- Trap handling

```oberon
IMPORT Kernel;

(* Check if module loaded *)
IF Kernel.ThisMod("ModuleName") # NIL THEN ... END;

(* Get type by name *)
typ := Kernel.ThisType(obj, "TypeName");
```

## Files

File system abstraction:
- Locators (directories)
- Files (binary data)
- Readers/Writers

```oberon
IMPORT Files;

VAR loc: Files.Locator; name: Files.Name; f: Files.File;
    rd: Files.Reader; wr: Files.Writer;
BEGIN
    loc := Files.dir.This("Obx/Rsrc");
    f := Files.dir.Old(loc, "Data", Files.read);
    IF f # NIL THEN
        rd := f.NewReader(NIL);
        rd.ReadInt(x);
        ...
    END;
    
    f := Files.dir.New(loc, Files.dontAsk);
    wr := f.NewWriter(NIL);
    wr.WriteInt(42);
    wr.Update;  (* commit changes *)
    Files.dir.Register(f)  (* save file *)
END;
```

### Path Handling

```oberon
PROCEDURE SplitPath (IN path: ARRAY OF CHAR; OUT loc: Files.Locator; OUT name: Files.Name);
VAR i, j: INTEGER; dir: ARRAY Files.PathLength OF CHAR;
BEGIN
    i := 0; j := 0;
    WHILE path[i] # 0X DO
        IF path[i] = '/' THEN j := i + 1 END;
        INC(i)
    END;
    (* extract dir and name *)
END SplitPath;
```

## Stores

Serialization framework:
- Reader/Writer for binary I/O
- Store = serializable object
- Domain = context for undo/redo
- Operation = undoable action

```oberon
IMPORT Stores;

TYPE
    MyStore = POINTER TO RECORD (Stores.Store)
        field: INTEGER
    END;

(* Internalize - read from file *)
PROCEDURE (s: MyStore) Internalize- (VAR rd: Stores.Reader);
BEGIN
    rd.ReadVersion(min, max, version);
    rd.ReadInt(s.field)
END Internalize;

(* Externalize - write to file *)
PROCEDURE (s: MyStore) Externalize- (VAR wr: Stores.Writer);
BEGIN
    wr.WriteVersion(version);
    wr.WriteInt(s.field)
END Externalize;

(* Copy *)
PROCEDURE (s: MyStore) CopyFrom- (source: Stores.Store);
BEGIN
    s.field := source(MyStore).field
END CopyFrom;
```

### Operation (Undo/Redo)

```oberon
TYPE
    ModifyOp = POINTER TO RECORD (Stores.Operation)
        model: MyModel;
        oldValue, newValue: INTEGER
    END;

PROCEDURE (op: ModifyOp) Do;
BEGIN
    op.model.value := op.newValue;
    Models.Broadcast(op.model, UpdateMsg)
END Do;
```

### Domain

A Domain groups related stores and manages undo/redo:
```oberon
domain := Stores.NewDomain();
sequencer := domain.GetSequencer();  (* for undo/redo *)
```

## Services

Action scheduling and utilities:
```oberon
IMPORT Services;

(* Schedule deferred action *)
Services.PushBack(action, lowPriority);

(* Time measurement *)
t := Services.Ticks();
```

## Converting Documentation

```bash
odcey text ./System/Docu/Kernel.odc
odcey text ./System/Docu/Files.odc
odcey text ./System/Docu/Stores.odc
odcey text ./System/Docu/Services.odc
```

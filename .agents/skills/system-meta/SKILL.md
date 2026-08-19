---
name: system-meta
description: Meta-programming and reflection
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: System
---

## What I do

- Document Meta module for reflection
- Explain item lookup and enumeration
- Cover type information access
- Show procedure calling by name

## When to use me

Use when implementing inspectors, scripting, or dynamic module access.

## Documentation Source

`System/Docu/Meta.odc`

## Meta Module

Reflection and meta-programming interface.

### Looking Up Items

```oberon
IMPORT Meta;

VAR item: Meta.Item; mod: Meta.Module;
BEGIN
    (* Lookup by qualified name *)
    Meta.LookupPath("ModuleName.VarName", item);
    
    (* Lookup module *)
    mod := Meta.ThisMod("ModuleName");
    IF mod # NIL THEN
        Meta.Lookup(mod, "VarName", item)
    END;
END;
```

### Meta.Item

```oberon
TYPE
    Item = RECORD
        type: BYTE;       (* type of item *)
        mod: Module;      (* containing module *)
        obj: ANYPTR;      (* the actual object *)
        (* Value accessors *)
        intVal: LONGINT;
        realVal: REAL;
        strVal: String;
        boolVal: BOOLEAN;
        setVal: SET;
    END;
```

### Item Types

```oberon
CONST
    var = 1;        (* variable *)
    const = 2;      (* constant *)
    type = 3;       (* type *)
    proc = 4;       (* procedure *)
    varParam = 5;   (* VAR parameter *)
    (* value types *)
    intVal = 10; realVal = 11; boolVal = 12; setVal = 13;
    strVal = 14; charVal = 15; ptrVal = 16; arrVal = 17;
```

### Checking Item Validity

```oberon
IF item.Valid() THEN
    CASE item.type OF
    | Meta.intVal: Log.Int(item.intVal);
    | Meta.realVal: Log.Real(item.realVal);
    | Meta.strVal: Log.String(item.strVal);
    | Meta.boolVal: Log.Bool(item.boolVal);
    ELSE
        Log.String("Other type")
    END;
    Log.Ln
END;
```

### Enumerating Module Items

```oberon
PROCEDURE ListModuleItems (modName: ARRAY OF CHAR);
VAR mod: Meta.Module; item: Meta.Item; name: Meta.Name;
BEGIN
    mod := Meta.ThisMod(modName);
    IF mod # NIL THEN
        name := "";
        Meta.Lookup(mod, name, item);  (* get first item *)
        WHILE item.Valid() DO
            Log.String(name);
            Log.Char(9X);  (* tab *)
            Log.Int(item.type);
            Log.Ln;
            Meta.LookupNext(mod, name, item)  (* get next *)
        END
    END
END ListModuleItems;
```

### Calling Procedures

```oberon
PROCEDURE CallProc (IN path: ARRAY OF CHAR);
VAR item: Meta.Item; res: INTEGER;
BEGIN
    Meta.LookupPath(path, item);
    IF item.Valid() & (item.type = Meta.proc) THEN
        Meta.Call(item, NIL, NIL, res);  (* call with no params *)
        IF res # 0 THEN Log.String("Call failed") END
    END
END CallProc;
```

### Type Information

```oberon
VAR typ: Meta.Type;
BEGIN
    typ := Meta.ThisType(obj, "TypeName");
    IF typ # NIL THEN
        (* typ.base is base type *)
        (* typ.size is type size *)
        (* typ.pointer indicates if pointer type *)
    END
END;
```

### Getting/Setting Variables

```oberon
VAR item: Meta.Item; value: INTEGER;
BEGIN
    Meta.LookupPath("ModuleName.intValue", item);
    IF item.Valid() & (item.type = Meta.intVal) THEN
        value := item.intVal;     (* get *)
        Meta.SetInt(item, 42);    (* set *)
    END
END;
```

## Use Cases

1. **Scripting** - Execute commands by name
2. **Inspectors** - Display object contents
3. **Serialization** - Save/restore object state
4. **Testing** - Access module internals
5. **Debugging** - Examine running system

## Converting Documentation

```bash
odcey text ./System/Docu/Meta.odc
```

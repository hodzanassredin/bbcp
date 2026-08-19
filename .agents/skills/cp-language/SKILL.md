---
name: cp-language
description: Component Pascal language reference and syntax
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: language
---

## What I do

- Provide Component Pascal syntax reference
- Explain types, records, methods, and parameter modes
- Document naming conventions and code style
- Cover module structure and exports

## When to use me

Use when writing or understanding Component Pascal code, defining types, or learning the language syntax.

## Documentation Source

`Docu/CP-Lang.odc`, `Docu/CP-New.odc`

## Basic Types

| Type | Description |
|------|-------------|
| BOOLEAN | TRUE or FALSE |
| SHORTINT, INTEGER, LONGINT | Signed integers |
| SHORTREAL, REAL | Floating point |
| SET | Bit set (0..31) |
| CHAR | 16-bit Unicode character |
| SHORTCHAR | 8-bit character (ISO 8859-1) |

## Record Types

```oberon
Point = RECORD x, y: INTEGER END;           (* Final - cannot be extended *)

View = EXTENSIBLE RECORD (* Can be extended *)
    field: INTEGER
END;

Handler = ABSTRACT RECORD (* Cannot instantiate *)
    data: INTEGER
END;

Token = LIMITED RECORD (* Only allocatable in defining module *)
    id: INTEGER
END;
```

## Methods

```oberon
PROCEDURE (t: T) FinalMethod (x: INTEGER), NEW;        (* cannot override *)
PROCEDURE (t: T) ExtMethod (x: INTEGER), NEW, EXTENSIBLE;
PROCEDURE (t: T) AbsMethod (x: INTEGER), NEW, ABSTRACT; (* no body *)
PROCEDURE (t: T) EmptyMethod (x: INTEGER), NEW, EMPTY;  (* no-op default *)
```

## Parameter Modes

```oberon
PROCEDURE P (value: INTEGER;       (* value parameter - copied *)
             VAR inout: INTEGER;    (* read/write reference *)
             IN in: ARRAY OF CHAR;  (* read-only, efficient *)
             OUT out: INTEGER);     (* write-only, undefined on entry *)
```

## Export Marks

- `*` - Normal export (read/write, callable)
- `-` - Implement-only export (read-only for variables)

```oberon
VAR data-: INTEGER;  (* read-only from outside *)
PROCEDURE Do*;       (* callable from outside *)
```

## Module Structure

```oberon
MODULE ModuleName;
(**
    project = "BlackBox 2.0"
    license = "The 2-Clause BSD License"
**)

    IMPORT S := SYSTEM, OtherModule;

    CONST name* = value;

    TYPE Type* = POINTER TO RECORD (BaseType) field*: INTEGER END;

    VAR var-: Type;

    PROCEDURE Proc* (param: INTEGER);
    BEGIN
    END Proc;

BEGIN
    (* initialization *)
END ModuleName.
```

## Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Module | PascalCase | StdDialog, DevCompiler |
| Type | PascalCase | View, FileInfo |
| Procedure | PascalCase | Calculate, GetSubLoc |
| Variable | camelCase | viewHook, curItem |
| Constant | camelCase | nameLen, littleEndian |

## Assertions and Trap Numbers

| Range | Purpose |
|-------|---------|
| 0-19 | Free, temporary breakpoints |
| 20-59 | Preconditions (parameter validation) |
| 60-99 | Postconditions (result validation) |
| 100-120 | Invariants |
| 126 | Not Yet Implemented |
| 128 | Silent trap |

```oberon
ASSERT(name # "", 20);    (* precondition *)
HALT(100);                (* invariant violation *)
```

## Statements

```oberon
(* Assignment *)
x := expr;

(* If *)
IF cond THEN stmts ELSIF cond2 THEN stmts2 ELSE stmts3 END;

(* Case *)
CASE x OF
| 0: stmts
| 1..9: stmts
ELSE stmts
END;

(* Loops *)
WHILE cond DO stmts END;
REPEAT stmts UNTIL cond;
FOR i := 0 TO n-1 BY step DO stmts END;
LOOP stmts END;  (* use EXIT to break *)

(* With - type guard *)
WITH v: T DO v.field END;
```

## Predeclared Procedures

| Procedure | Description |
|-----------|-------------|
| NEW(p) | Allocate dynamic variable |
| INC(x), DEC(x) | Increment/decrement |
| ODD(x) | x MOD 2 # 0 |
| ABS(x) | Absolute value |
| LEN(a) | Array length |
| MIN(T), MAX(T) | Type bounds |
| ORD(ch) | Character to integer |
| CHR(n) | Integer to character |
| SHORT(x), LONG(x) | Type conversion |
| ENTIER(x) | Floor function |
| ASH(x, n) | Arithmetic shift |
| SYSTEM.BIT(a, n) | Test bit |

## What's New in Component Pascal (vs Oberon-2)

1. **Covariant pointer function results** - Function can return extended type
2. **IN and OUT parameters** - More precise parameter modes
3. **NEW marker** - Explicit indication of new methods
4. **Record attributes** - EXTENSIBLE, ABSTRACT, LIMITED
5. **Simplified pointer compatibility** - Pointers compatible by structure

## Converting Documentation

```bash
odcey text ./Docu/CP-Lang.odc
odcey text ./Docu/CP-New.odc
```

---
name: system-utils
description: Utility modules - Strings, Dates, Math
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: System
---

## What I do

- Document Strings module for text operations
- Explain Dates for date/time handling
- Cover Math for mathematical functions

## When to use me

Use when manipulating strings, dates, or performing calculations.

## Documentation Source

`System/Docu/Strings.odc`, `System/Docu/Dates.odc`, `System/Docu/Math.odc`

## Strings Module

String operations.

### Procedures

```oberon
IMPORT Strings;

VAR s, t: ARRAY 256 OF CHAR;
    pos, len: INTEGER;
    res: INTEGER;
BEGIN
    (* Length *)
    len := Strings.Length(s);
    
    (* Append *)
    Strings.Append(s, t);  (* t := t + s *)
    
    (* Insert *)
    Strings.Insert(s, pos, t);  (* insert s into t at pos *)
    
    (* Delete *)
    Strings.Delete(t, pos, len);  (* delete len chars from t at pos *)
    
    (* Replace *)
    Strings.Replace(s, pos, t);  (* replace t[pos..] with s *)
    
    (* Extract *)
    Strings.Extract(t, pos, len, s);  (* s := t[pos..pos+len-1] *)
    
    (* Capitalize *)
    Strings.Capitalize(t);  (* t := UPPER(t) *)
    
    (* Compare *)
    IF Strings.Compare(s, t) = 0 THEN  (* s = t *)
    ELSIF Strings.Compare(s, t) < 0 THEN  (* s < t *)
    END;
    
    (* Compare with options *)
    Strings.Compare(s, t, FALSE, res);  (* case-sensitive *)
    Strings.Compare(s, t, TRUE, res);   (* case-insensitive *)
    
    (* Search *)
    pos := Strings.Pos(s, t, 0);  (* find s in t, -1 if not found *)
END;
```

### Type Conversion

```oberon
VAR i: INTEGER; r: REAL; s: ARRAY 32 OF CHAR;
BEGIN
    (* Int to string *)
    Strings.IntToString(i, s);
    
    (* String to int *)
    Strings.StringToInt(s, i, res);  (* res = 0 if ok *)
    
    (* Real to string *)
    Strings.RealToString(r, s);
    
    (* String to real *)
    Strings.StringToReal(s, r, res);
END;
```

## Dates Module

Date and time handling.

```oberon
IMPORT Dates;

VAR d: Dates.Date; t: Dates.Time; dt: Dates.DateTime;
BEGIN
    (* Get current date/time *)
    Dates.GetDate(d);
    Dates.GetTime(t);
    Dates.GetDateTime(dt);
    
    (* Date components *)
    d.year; d.month; d.day;
    
    (* Time components *)
    t.hour; t.minute; t.second; t.second100;
    
    (* Date validation *)
    IF Dates.ValidDate(d.year, d.month, d.day) THEN ... END;
    
    (* Day of week (0=Sunday) *)
    day := Dates.DayOfWeek(d);
    
    (* Date arithmetic *)
    Dates.DateToDays(d, days);
    Dates.DaysToDate(days, d);
END;
```

### Date Type

```oberon
TYPE
    Date = RECORD
        day, month, year: INTEGER
    END;
    
    Time = RECORD
        second100, second, minute, hour: INTEGER
    END;
    
    DateTime = RECORD
        date: Date;
        time: Time
    END;
```

## Math Module

Mathematical functions.

```oberon
IMPORT Math;

VAR x, y: REAL;
BEGIN
    (* Basic functions *)
    x := Math.Sqrt(y);
    x := Math.Power(base, exp);
    x := Math.Exp(y);
    x := Math.Ln(y);
    x := Math.Log(y);      (* base 10 *)
    x := Math.Log2(y);     (* base 2 *)
    
    (* Trigonometric *)
    x := Math.Sin(y);
    x := Math.Cos(y);
    x := Math.Tan(y);
    x := Math.ArcSin(y);
    x := Math.ArcCos(y);
    x := Math.ArcTan(y);
    x := Math.ArcTan2(y2, y1);
    
    (* Hyperbolic *)
    x := Math.Sinh(y);
    x := Math.Cosh(y);
    x := Math.Tanh(y);
    
    (* Rounding *)
    x := Math.Floor(y);
    x := Math.Ceiling(y);
    x := Math.Round(y);
    
    (* Constants *)
    Math.pi;    (* 3.14159... *)
    Math.e;     (* 2.71828... *)
END;
```

## SMath Module

Safe math with error handling.

```oberon
IMPORT SMath;

VAR x, y: REAL; ok: BOOLEAN;
BEGIN
    x := SMath.Sqrt(y, ok);
    IF ~ok THEN (* handle error *) END;
END;
```

## Integers Module

Integer utilities.

```oberon
IMPORT Integers;

VAR i, j: INTEGER;
BEGIN
    (* GCD and LCM *)
    i := Integers.Gcd(a, b);
    j := Integers.Lcm(a, b);
    
    (* Power *)
    i := Integers.IntPower(base, exp);
END;
```

## Unicode Module

Unicode support.

```oberon
IMPORT Unicode;

VAR ch: CHAR; cls: INTEGER;
BEGIN
    (* Character classification *)
    IF Unicode.IsLetter(ch) THEN ... END;
    IF Unicode.IsDigit(ch) THEN ... END;
    IF Unicode.IsUpper(ch) THEN ... END;
    IF Unicode.IsLower(ch) THEN ... END;
    
    (* Case conversion *)
    upper := Unicode.ToUpper(ch);
    lower := Unicode.ToLower(ch);
END;
```

## Converting Documentation

```bash
odcey text ./System/Docu/Strings.odc
odcey text ./System/Docu/Dates.odc
odcey text ./System/Docu/Math.odc
odcey text ./System/Docu/SMath.odc
odcey text ./System/Docu/Integers.odc
odcey text ./System/Docu/Unicode.odc
odcey text ./System/Docu/Utf.odc
```

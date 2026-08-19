---
name: dev-tools
description: Development tools - compiler and debugger
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: Dev
---

## What I do

- Document DevCompiler commands
- Explain compilation workflows
- Cover DevDebug inspection tools
- Show meta-programming with Meta module

## When to use me

Use when compiling modules, debugging, or using reflection.

## Documentation Source

`Dev/Docu/Compiler.odc`, `Dev/Docu/Debug.odc`

## DevCompiler

Component Pascal compiler commands.

### Commands

| Command | Description |
|---------|-------------|
| Compile | Compile module in focus view |
| CompileAndUnload | Compile and unload old version |
| CompileModuleList | Compile selected module names |
| CompileSelection | Compile module where beginning is selected |
| CompileThis | Compile modules listed after command |
| CompileSubs | Compile all modules in subsystems |
| MakeList | Generate ordered compile list by dependencies |

### Usage

```bash
# Compile specific module
echo "DevCompiler.CompileThis ModuleName" | ./run-BlackBoxInterp

# Compile multiple modules
echo "DevCompiler.CompileThis ObxViews1 ObxViews2" | ./run-BlackBoxInterp

# Compile subsystem
echo "DevCompiler.CompileSubs Obx" | ./run-BlackBoxInterp

# Compile multiple subsystems
echo "DevCompiler.CompileSubs Obx Text Form" | ./run-BlackBoxInterp

# Compile all non-standard subsystems
echo "DevCompiler.CompileSubs +" | ./run-BlackBoxInterp

# Compile all subsystems
echo "DevCompiler.CompileSubs *" | ./run-BlackBoxInterp

# Generate compile list (ordered by dependencies)
echo "DevCompiler.MakeList Obx" | ./run-BlackBoxInterp
```

### Compiler Options

Options are specified after module name:
```
DevCompiler.CompileModuleList
ModuleName option1 option2
```

### Error Handling

- On first error, offending source opens showing the error
- Remaining uncompiled modules stay selected
- Trap numbers in assertions help locate issues

## DevDebug

Debugging and inspection tools.

### Inspector

```bash
# Open inspector on selection
DevDebug.Inspect
```

### Markers

Debug markers for code navigation.

### HeapSpy

Memory analysis tool.

## DevCommander

Command input view (commander).

```oberon
IMPORT DevCommanders;

VAR cmd: DevCommanders.View;
BEGIN
    cmd := DevCommanders.dir.New();
    (* Commander allows typing and executing commands *)
END;
```

## DevLinker

Link compiled modules into standalone executable.

## DevPacker

Pack resources into .odc containers.

## Meta Module

Reflection and meta-programming.

```oberon
IMPORT Meta;

VAR item: Meta.Item;
BEGIN
    Meta.LookupPath("ModuleName.VarName", item);
    IF item.Valid() THEN
        CASE item.type OF
        | Meta.intVal: x := item.intVal;
        | Meta.realVal: x := item.realVal;
        | Meta.strVal: s := item.strVal;
        END
    END
END;
```

### Meta.Item

```oberon
TYPE
    Item = RECORD
        type: BYTE;
        intVal: LONGINT;
        realVal: REAL;
        strVal: String;
        obj: ANYPTR;
        ...
    END;
```

## Converting Documentation

```bash
odcey text ./Dev/Docu/Compiler.odc
odcey text ./Dev/Docu/Debug.odc
odcey text ./Dev/Docu/Inspector.odc
odcey text ./Dev/Docu/Commanders.odc
odcey text ./Dev/Docu/Linker.odc
odcey text ./Dev/Docu/Packer.odc
```

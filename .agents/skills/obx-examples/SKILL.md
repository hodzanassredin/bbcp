---
name: obx-examples
description: Example code from Obx subsystem
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: Obx
---

## What I do

- List and explain example modules in Obx/
- Provide learning path through examples
- Show how to compile and run examples

## When to use me

Use when learning BlackBox, looking for code examples, or understanding patterns.

## Documentation Source

`Obx/Docu/*.odc`

## Hello World Examples

### ObxHello0
Simplest example - module with command.

```oberon
MODULE ObxHello0;
    IMPORT Log;
    
    PROCEDURE Do*;
    BEGIN
        Log.String("Hello World"); Log.Ln
    END Do;
    
BEGIN
END ObxHello0.
```

Run: `echo 'ObxHello0.Do' | ./run-BlackBoxInterp`

### ObxHello1
Module with exported variable.

## Views Examples

| Module | Description |
|--------|-------------|
| ObxViews0 | Simple view with Restore |
| ObxViews1 | View with model |
| ObxViews2 | View with controller |
| ObxViews3-14 | Various view features |

## Model Examples

| Module | Description |
|--------|-------------|
| ObxCount0 | Simple counter model |
| ObxCount1 | Model with undo/redo |

## Dialog Examples

| Module | Description |
|--------|-------------|
| ObxDialog | Basic dialog usage |
| ObxPhoneUI | Phone lookup dialog |
| ObxPhoneUI1 | Dialog with guards/notifiers |
| ObxAddress0/1/2 | Address book with forms |
| ObxUnitConv | Unit converter |

## Control Examples

| Module | Description |
|--------|-------------|
| ObxControls | Various control types |
| ObxCtrls | Control programming |
| ObxFldCtrls | Field controls |

## Container Examples

| Module | Description |
|--------|-------------|
| ObxTabs | Tabbed views |
| ObxTabViews | Tab view container |
| ObxWrappers | View wrappers |

## Graphical Examples

| Module | Description |
|--------|-------------|
| ObxLines | Line drawing |
| ObxCubes | 3D cubes |
| ObxGraphs | Graph visualization |

## Form Examples

| Module | Description |
|--------|-------------|
| ObxOrders | Order entry form |
| ObxPDBRep0-4 | Phone database reports |

## Utility Examples

| Module | Description |
|--------|-------------|
| ObxConv | Conversion utilities |
| ObxFact | Factorial calculation |
| ObxPi | Calculate Pi |
| ObxRandom | Random numbers |
| ObxRatCalc | Rational calculator |
| ObxPatterns | Pattern matching |
| ObxMMerge | Mail merge |

## File Examples

| Module | Description |
|--------|-------------|
| ObxOpen0/1 | File opening |
| ObxFileTree | File tree view |
| ObxLookup0/1 | File lookup |

## Controller Examples

| Module | Description |
|--------|-------------|
| ObxScroll | Scrolling |
| ObxTickers | Ticker display |
| ObxContIter | Container iteration |
| ObxControlShifter | Control shifter |

## Store Examples

| Module | Description |
|--------|-------------|
| ObxStores | Serialization |

## Database Examples

| Module | Description |
|--------|-------------|
| ObxDb | Simple database |
| ObxPhoneDB | Phone database backend |

## Running Examples

```bash
# Compile
echo "DevCompiler.CompileThis ObxHello0" | ./run-BlackBoxInterp

# Run command
echo "ObxHello0.Do" | ./run-BlackBoxInterp

# Open dialog
echo "StdCmds.OpenAuxDialog('Obx/Rsrc/PhoneUI', 'Phonebook')" | ./run-BlackBoxInterp

# Compile entire Obx subsystem
echo "DevCompiler.CompileSubs Obx" | ./run-BlackBoxInterp
```

## Key Learning Path

1. ObxHello0 → Basic commands
2. ObxViews0-2 → Views and models
3. ObxCount0-1 → Models with undo
4. ObxDialog → Dialog basics
5. ObxPhoneUI → Complete dialog example
6. ObxControls → Control types
7. ObxAddress0-2 → Full application

## Converting Documentation

```bash
# All Obx documentation
for f in Obx/Docu/*.odc; do
    odcey text "$f" > "${f%.odc}.txt"
done
```

# OCF amd64 v2 (Dev-семейство, нативные 64-битные указатели)

Целевой формат эмиттера DevCPE (processor=12). Эталон принципов: 32-битный DevCP,
эталон 64-бит: Hr (HrOcf/HrE).

## Карта файла

```
ObjFile = HeaderBlk MetaBlk DescBlk CodeBlk FixBlk UseBlk
```

- HeaderBlk: tag(4)=6F4F4346H processor(4)=12 hs ms ds cs vs (по 4),
  nofImports(RNum), name(utf8,0), имена импортов, Align(16). hs = headSize.
- MetaBlk (ms байт @hs): RefBlk, ExportDir, ptrs, import-таблица, names, consts.
- DescBlk (ds байт @hs+ms): ModDesc, дескрипторы типов (ProcTable для amd64 не пишется).
- CodeBlk (cs байт): машкод. VarBlk в файле НЕТ (vs только размер, аллоцируется).
- FixBlk сразу после CodeBlk: 6 групп:
  1. KNewRec.links 2. KNewArr.links 3. meta 4. desc 5. code 6. data.
  Группа = пары RNum(head) RNum(offset), терминатор 0 (один байт 0).
- UseBlk: per import: записи mTyp=2/mVar=3/mProc=4 + name + RNum(fprint) +
  цепочка (OutLink), терминатор 0X на импорт.

## Цепочки и слоты

- head > 0 → адрес в CodeBlk; head < 0: |head| < ms → MetaBlk, иначе DescBlk
  (adr = |head| - ms). В слоте 4 байта метаданных: typ*1000000H + next24
  (next со знаковым расширением).
- Для processor=12 все указательные слоты 8 байт: 4 метаданных + 4 sentinel
  (11223344H); лоадер перезаписывает все 8 байт значением adr+offset.
- Типы фиксапов: absolute=100 (для amd64: 8-байтная запись), relative=101
  (disp32 = target-ladr-4), copy=102 (для amd64: копия 8 байт из adr+offset),
  table=103/tableend=104 (case-записи 8 байт, следующий элемент link+8),
  short=105, ripBased=106..114 (immLen=typ-106; disp32 = target-(ladr+4+immLen)).

## ModDesc (DescBlk+0, == Kernel64.Module)

```
next     @0   (8)     opts     @8  (4)   refcnt  @12 (4)
compTime @16 (12)     loadTime @28 (12)  ext     @40 (4)   pad @44 (4)
term     @48  (8)
nofimps  @56 (4) nofptrs @60 (4) csize @64 (4) dsize @68 (4) rsize @72 (4) pad @76 (4)
code @80 data @88 refs @96 procBase @104 varBase @112
names @120 ptrs @128 imports @136 export @144   (все по 8)
name @152 (256 байт)        → конец 408, Align(8)
```

## Type descriptor (record) == Kernel64.Type

```
[marker: -1 (8 байт FF)] [method n-1] ... [method 0]   (по 8 байт; method i @ desc-8-8i)
desc: size @0 (4) pad @4
      mod  @8 (8)
      id   @16 (4) pad @20    (id = mRecord+attr*4+extlev*16+NameIdx*256)
      base @24 (16 × 8)
      fields @152 (8)
      ptroffs @160 (по 4 байта, маркеры -(4*n+4) и -1)
```
Array/DynArr/Pointer/ProcTyp descs: size(4) pad(4) mod(8) id(4) pad(4) elem/base(8) ptroffs.

## Export Directory

`num(4)` + записи по 24 байта: fprint(4) offs(4) id(4) pad(4) ostruct(8).
id = mode + vis*16 + NameIdx*256. offs: mProc → code offset; mVar → dsize+adr.

## Код (amd64)

- CALL: E8 rel32 (+relative цепочка); прямые вызовы (procVarIndirect выкл).
- Глобальные данные: RIP-relative (ripBased*), disp32 → все блоки модуля и модули
  друг друга в пределах ±2 ГБ (лоадер: единая арена).
- imm64/moffs64: 8-байтные слоты, absolute (8-байтная запись).
- CASE: mov r11, imm64(tab); jmp [r11 + idx*8]; записи таблицы 8 байт,
  typ=table/tableend, содержимое = code offset альтернативы.

## UseBlk семантика лоадера (как 32-бит bbrun.c)

Fixup(newRecAdr); Fixup(newArrAdr); Fixup(mad); Fixup(dad); Fixup(cad); Fixup(vad);
затем per-import: x=RNum; цикл: ReadName, fp=RNum, resolve obj →
mTyp: opt=RNum... Fixup(obj.ostruct); mVar: Fixup(desc.varBase+obj.offs);
mProc: Fixup(desc.procBase+obj.offs); запись desc.imports[i] = module.

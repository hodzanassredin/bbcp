# Таблицы методов: нумерация, раскладка, артефакт refs (end-of-proc)

## Вывод (2026-07-24)

«Сдвинутая» таблица методов LinKernel.Platform из сессии-расследования — **артефакт
измерения, а не баг компилятора**. Статический разбор OCF и live-дамп в gdb
совпадают на 100%: таблица корректна.

## Конвенция amd64 (OCF v2)

- Номера методов (`obj.num`, mthno) присваивает `DevCPVamd64.CountTProcs`
  обходом BST `rec.link` **в алфавитном порядке** (in-order), начиная с
  `DevCPT.anytyp.n = 1` (num 0 = скрытый FINALIZE из ANYREC).
- Расширения: override получает `num` базового метода (`redef.num` из .osf).
- Эмиссия (CPE.OutDesc): маркер -1 (8 байт), затем слоты i = n-1..0; слот num i
  лежит по `tag - 8*(i+1)`. Caller (CPCamd64): `call *(Mth0Offset - 8*num)(tag)`,
  Mth0Offset = -8. Совместимо.
- Методы, не переопределённые в расширении из другого модуля: слот = `copy`-fixup
  из дескриптора базового типа (`OutReference(xb.strobj, -8-8*i, copy)`).

Пример: LinKernel.Platform (24 слота): 0=FINALIZE(0), 1=AllocateClusterMem,
2=AllocateModMem, 3=Commit, 4=DeallocateClusterMem, 5=DeallocateModMem,
6=Debug(copy→Kernel), 7=FatalError, 8=GetLoadTime, 9=GetTrapInfo,
10=InActivationStack, 11=InitModule(copy), 12=IsReadable, 13=LoadDll,
14=PageSize, 15=PrintHeaderInfo, 16=ProtectMemExec, 17=ProtectMemRead,
18=Setup, 19=SetupModListAccess(copy), 20=Start, 21=Terminate, 22=ThisDllObj,
23=Time.

## АРТЕФАКТ: refs в OCF — смещения КОНЦА процедур

`DevCPE.OutRefName` вызывается из `DevCPVamd64.procs` ПОСЛЕ генерации тела и
пишет текущий `pc`. Поэтому запись `(off, name)` в refs означает «proc `name`
ЗАКАНЧИВАЕТСЯ на `off`», а не начинается. `ocf.py refs` + старый `owner()`
(«наибольший ref ≤ off») мапил каждый адрес на ПРЕДЫДУЩУЮ процедуру — отсюда
иллюзия «каждый слот содержит следующий метод, первый = 0, последний = чужой».

- Правильный маппинг: proc i занимает `(refs[i-1].adr, refs[i].adr]`;
  owner(off) = первый ref с `adr > off`... точнее `start <= off < adr` с бегущим
  start (исправлено в tools64/ocf.py).
- gdb-дамп слотов надо сравнивать с `cad + code offset` из статического
  резолвера, а не с именами из сырого `ocf.py refs`.

## Инструменты

- `tools64/desc.py FILE` — статический дамп дескрипторов записей из OCF:
  находит маркеры -1, определяет n (size+id слова), резолвит слоты через
  fixup-группы (симулирует bbrun64.Fixup, включая table/tableend и copy).
- `tools64/ocf.py` — owner() исправлен под end-offset refs.
- Live-проверка слотов: `ThisModule("LinKernel")` → Module* == dad;
  tag = (char*)mod + <desc offset>; сравнивать слоты с `mod->code + off`.

## Микро-репродукция (работает корректно)

`System/Mod/TestT2.odc.txt` (ABSTRACT запись A, 8 методов, один объявлен поздно)
+ `System/Mod/TestT3.odc.txt` (B(A) + ErrLog с методом, как в LinKernel).
`tools64/c64.sh SystemTestT2/SystemTestT3`, затем `tools64/desc.py` на OCF —
таблицы алфавитные и консистентные с call-site'ами (UseIt: `call *-0x20(tag)`
= num 3 = M1).

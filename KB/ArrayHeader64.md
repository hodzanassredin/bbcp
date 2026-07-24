# Раскладка хедера динамических массивов (amd64)

Источник истины — кодогенератор (Dev/Mod/CPCamd64.odc.txt), все ядра обязаны
соответствовать. x = ADR(b.last) — указатель на поле last блока.

## Раскладка (консенсус после фикса 2026-07-24)

Block = 4 поля по 8 байт: tag@b+0, last@b+8(=x), actual@b+16(x+8), first@b+24(x+16).

- len[0] : x+0x18 (4 байта), len[i]: x+0x18+4*i
- данные : x+0x18+4*nofdim
- headSize (от x) = 4*nofdim + 24
- NewArr: b.last := x + size - elsize; b.first := x + headSize
- len[0] пишет НЕ NewArr, а SetDim (генерируется после вызова NewArr,
  с пропуском при NIL через флаги от GenComp в New)
- NewBlock(size): size БЕЗ тега; внутри +8 под тег, округление до 16, мин 24

## Места в компиляторе (CPCamd64)

- LenDesc: ДВА разных смещения! VarPar (стековый open-array параметр):
  `INC(len.offset, typ.n * 4 + 8)` — стек: [adr8][len0 4]...
  Ind (heap dyn array): `INC(len.offset, typ.n * 4 + 16)` — [last8][actual8][first8][len0 4]...
  Эти ветки РАЗЛИЧАЮТСЯ: единый INC после IF ломает одну из них (регрессия
  2026-07-24: +16 для обеих → StringToUtf8 читал LEN(out) из чужого слота →
  ASSERT(res=0) в LinEnv.GetEnv при буте).
- DeRef: DynArr `x.offset := ArrDOffs + btyp.size + 8`;
  Array (static) `x.offset := ArrDOffs + 16`
- SetDim: `z.offset := ArrDOffs + 16 + dimtyp.n * 4`
- ArrDOffs = 8 (константа в CPCamd64 и CPC486)

## История бага

Компилятор читал LEN по x+0x10 (LenDesc +8), SetDim писал по x+0x0C
(ArrDOffs+4), Kernel64.NewArr был заглушкой (nofelem*8, без last/first/len),
System Kernel.NewArr имел headSize=8*nofdim+24. Четыре несогласованных
представления одновременно. Симптом: HALT (проверка границ) в
Integers.SetLength при буте — LEN читался = 0.

Kernel64_full.odc.txt (референс, не собирается) — 8-байтные lens,
8*nofdim+24: с нашим компилятором НЕ совместим, не использовать как образец.

## $$-ребайндинг

bbrun64.c перебивает импорты "$$..." на kernel="Kernel64" — поэтому NEW
всех модулей (включая System Kernel) зовёт Kernel64.NewRec/NewArr (bump-heap
в данных Kernel64). StdLoader при динамической загрузке фиксит тем же
S.ADR(Kernel.NewArr) — System Kernel (кластерная куча + GC). Обе реализации
обязаны иметь одинаковую раскладку — поэтому 4-полевой Block в обоих.

## Порядок инициализации при буте (bbrun64)

Kernel.InitModule бежит рекурсивно mod.next ПЕРЕД телом — тела идут от
хвоста списка к голове, и рекурсия ОСТАНАВЛИВАЕТСЯ на первом модуле с
init-флагом. Поэтому bbrun64: инфра (7 модулей) → цикл тел по loadOrder
(порядок загрузки = топологический) → LinLoader/LinIntLoader ПОСЛЕДНИМ
(его тело грузит главный модуль через StdLoader). LinInit/LinIntInit
исключены из статического скана — грузятся динамически (иначе
LinLoader.Load падает в FatalError "already loaded" с неинициализированным
err → краш в Dialog.MapStringRes из-за Librarian.lib = NIL).

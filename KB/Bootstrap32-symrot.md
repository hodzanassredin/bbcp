# Bootstrap dev0 (32-bit) — sym-rot, impProc, восстановление

Дата: 2026-08-17. Контекст: этап 3 (удаление intrealtyp) сломал 32-битный
bootstrap-компилятор; здесь — что произошло и как чинить.

## Как устроен bootstrap

- `dev0Linux` (bbcp/) — 32-битный packed-хост, запакован 2026-07-23.
  Модули компилятора НЕ пакуются (см. tools64/repack-dev0.sh): грузятся с диска
  из `bbcp/Dev/Code`. Поэтому правки компилятора = go32.sh (32-битная
  перекомпиляция), без repack.
- Цепочка: dev0 (32-bit userland) → DevCompiler64 → 64-битные ocf в bbcp64use.
- `bbcp/Dev/Code` + `bbcp/Dev/Sym` НЕ под git — бэкапить перед опасными
  операциями: `tar czf /tmp/bbcp-dev-bak.tgz Dev/Code Dev/Sym`.

## Смена интерфейса CPT = пересборка ВСЕХ клиентов

Удаление `DevCPT.intrealtyp` (этап 3) → старые ocf, ссылающиеся на удалённый
объект, не грузятся: `object DevCPT.intrealtyp not found (imported from
DevCPC486)`. Лоадер проверяет объекты по имени; fingerprint (foot print)
экспортированные ПЕРЕМЕННЫЕ, похоже, не покрывает (типы/процедуры — да).
intrealtyp сидел не только в CPCamd64/CPVamd64/CPH/CPT (есть .odc.txt), но и в
**CPV486.odc и CPC486.odc** (CPV486.odc.txt не существовало — ссылка была
скрыта в бинарном .odc!). Урок: перед удалением экспорта грепать ВСЕ .odc через
OdcText.Export, не только *.odc.txt.

## Рецепт восстановления dev0, когда его компилятор сам не грузится

Chicken-and-egg: dev0 не может пересобрать свой же компилятор, т.к. для этого
нужно его загрузить. Выход — чужой 32-битный компилятор из bbcb2:

```sh
# scratch use-dir: ТОЛЬКО исходник, БЕЗ Sym/Code (иначе лоадер bbcb2-хоста
# подхватит bbcp-шный DevCPT.osf и упадёт на своём же CPC486)
rm -rf /tmp/recov2 && mkdir -p /tmp/recov2/Dev/Mod
cp ~/sources/bbcp/Dev/Mod/CPC486.odc /tmp/recov2/Dev/Mod/
cd /tmp/recov2
echo 'DevCompiler.CompileThis DevCPC486' | ~/sources/bbcb2-2.0~a1.build332/run-BlackBoxInterp
cp /tmp/recov2/Dev/Code/CPC486.ocf ~/sources/bbcp/Dev/Code/
# аналогично DevCPV486; затем полный прогон:
cd ~/sources/bbcp && tools64/go32.sh DevCPM DevCPT DevCPB DevCPS DevCPP DevCPH \
  DevCPE DevCPL486 DevCPC486 DevCPV486 DevCPLamd64 DevCPCamd64 DevCPVamd64
```

run-BlackBoxInterp ставит BB_USE_DIR=cwd → запускать ИЗ /tmp/recov2.
NB: `BB_USE_DIR=bbcp` целиком НЕЛЬЗЯ — bbcb2-хост падает на старте
(StdInterpreter: syntax error — bbcp'шные Std sym ему чужие).

## impProc — маркер процессора в .osf

Смещение 4 в .osf = processor (DevCPT.Import, CPT.odc.txt ~1189):
`impProc # 0 & processor # 0 & impProc # processor → err 151 "incorrect symbol
file"`. Значения: 0 = portable, 10 = Linux/x86 (Lin/Sym/* — норма), 12 = amd64.

Сканер заражения 64-битными sym:

```sh
python3 -c "
import glob,struct
for f in glob.glob('*/Sym/*.osf'):
    d=open(f,'rb').read(8)
    if len(d)>=5 and struct.unpack('<I',d[:4])[0]==0x6F4F5346 and d[4] not in (0,10):
        print(f, d[4])"
```

## Sym-rot в bbcp (открытая проблема)

- `System/Sym/Kernel.osf` (2026-08-09 01:40) — impProc=12: bbcp/System
  перезаписан 64-битной сборкой (CompileSubs DevCompiler64 писал в bbcp?).
  Любая 32-битная компиляция модуля с `IMPORT Kernel` → err 151.
- 32-битная пересборка Kernel НЕВОЗМОЖНА после этапа 3: источник использует
  нативный Int64, а 486-бэкенд без intrealtyp/UseReals даёт err 260
  ("operand inapplicable to function"). Это осознанная цена: 32-bit legacy
  выкидываем.
- `Dev/Sym/Markers.osf` (июль) ссылается на старый fp Views → DevCPM
  (импортирует StdLog(новый)+DevMarkers(старый)) не пересобирается 32-бит:
  "Views.View^ is not consistently imported FP249". DevCPM.ocf (09-08)
  рабочий, грузится — трогать не нужно, но рекомпиляция сломана.
- Новая подсистема на лету (Zz/Mod/P.odc) НЕ компилируется dev0
  ("incorrect symbol file" даже без импортов) — для пробников использовать
  существующую подсистему (Dev/Mod/ZzProbe.odc работает).

Стратегический выход (обсуждено): self-hosting (DevCompiler64 внутри bbrun64)
или замороженный bbcp32-снапшот для bootstrap. Пока: правила — (1) 32-бит
пересобираем ТОЛЬКО модули компилятора DevCP*, (2) перед сменой интерфейса
CPT/CPH — полный go32-прогон всей цепочки в ОДНОЙ сессии.

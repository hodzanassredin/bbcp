# Crypto64: порт bbext/Crypto на amd64 (2026-08-19)

Репа: `~/sources/bbext/Crypto64` (GitHub: bbext/Crypto64 — создаётся вручную,
git push не создаёт репу). Drop-in replacement: имена модулей прежние
(CryptoAES...), папка в мире — `Crypto`. Source of truth — `Mod/*.odc.txt`
(UTF-8), сборка `./build.sh` (sync OdcTextU + dev0, стэши как go64.sh).

## Главные грабли порта

1. **`[code]`-процедуры — x86-32 ассемблер.** Компилируются молча, на amd64
   выполняют мусор (pop ecx из чужого стека) → зависания/падения. Все 15 штук в
   CryptoAosCompat переписаны на чистый CP: UAdd64/USub64 через LONGINT_PARTS
   (младшая/старшая половины, перенос через ZE32 — так избегаем signed
   overflow), ULSH64 = SYSTEM.LSH (наш amd64 LSH на Int64 нативный, logical),
   UDiv/UMod 8/16/32 через zero-extend в больший тип, ULss/UGtr через flip
   знакового бита (`ORD(BITS(x) / {31})`), Bsr32 циклом, CDQ/UGetHighBits64
   через SYSTEM.VAL(LONGINT_PARTS, ...). NB: `SYSTEM.VAL(T, x)[i]` не парсится —
   сначала VAL в переменную, потом индексация (err 113/121).

2. **`L`-суффикс — 64-битный HEX** (KB/CPS-hex-literals.md). Кейс BigNumbers:
   A2-оригинал `100000000H` (2^32, база цифр bignum); портер 2023 написал
   `100000000L` — в BB 1.7 это ДЕСЯТИЧНЫЕ 1e8 (баг апстрима: mul давал
   десятичные цифры, EQ с AssignHex (база 2^32) не сходился), в BB 2.0 `L` =
   hex = 2^32 = правильная база A2. **Не "чинить" `100000000L` в
   AosBigNumbers!** А вот в AosStreams.Net64 десятичная 1e8 — намеренная
   (SHORT-совместимая сериализация), оставлена десятичной (без L).

3. **TRAP sig=15 = SIGTERM от timeout** — это ЗАВИСАНИЕ, а не падение. Вечный
   цикл в UMul64Raw выглядел как "TRAP".

4. **StdLog в консоли буферизован**: при крахе буфер теряется — "тихое"
   падение. Для бисекции крашей писать маркеры через `Console.WriteStr`
   (небуферизован).

5. **Консольный хост: `command error` (напр. incompatible parameter list)
   обрывает остаток stdin** — команды после ошибочной не выполняются.

6. **`inconsistently imported` (DevHeapSpy.par в CryptoFortunaRng)**: если при
   компиляции не спрятать 32-битные Sym ($BB/*/Sym), компилятор резолвит
   импорты через fallback в 32-битные sym → fingerprint расходится с 64-битным
   ocf в мире. build.sh должен прятать их, как go64.sh. И прятать только
   $USE/Dev/Code, а $USE/Dev/Sym оставлять (иначе импорты Dev* = err 152).

7. **64-битные интерфейсные расхождения**: DevHeapSpy.par.allocated стал
   LONGINT → SHORT в вызове AppendInt16 (FortunaRng).

8. Параметризованные команды тестов хотят ПОЛНОЕ имя модуля:
   `CryptoTestCiphers.Ecb1("CryptoAES", 128)`, не "aes" (Meta.LookupPath).

## Статус тестов (BB64, консоль)

Все зелёные: MD5/SHA1/SHA2-256/SHA3, HMAC (md5/sha1/sha2-256 + concat),
BigNumbers Test1 (Add/Sub/Mul/ModExp vs Integers), шифры AES/DES/3DES/ARC4/
CAST/IDEA (ECB/CBC/CTR + *2-векторы), DH SSL512/SSH, RSA Test1 (sign/verify),
X25519 Generate/Agreement/FromPrivateKey×3. Прогон: команды из
`/tmp/crypto-run*.txt`, мир bbcp64use.

## TODO

- ClickHouse#56681: прогнать TLSStream против play.clickhouse.com
  (ECDHE-RSA-AES128-GCM-SHA256, group x25519) — см. tasks.
- Пуш в GitHub после создания репы bbext/Crypto64.

## ClickHouse#56681 — ЗАКРЫТО (2026-08-19)

- Сервер уже чинится сам: openssl `ECDHE-RSA-AES128-GCM-SHA256 -tls1_2 -groups
  x25519` против play.clickhouse.com:443 сейчас успешен (Let's Encrypt cert).
- Наш клиент тоже: ObxProbe68 (CryptoTLSStream.NewStream -> GET /) получил
  `HTTP/1.0 302 Found`. Handshake TLS1.2 прошёл, SNI отправлен.
- Наши 5 default suites (TLS.InitDefaults): ECDHE_RSA_AES128_CBC_SHA256,
  RSA_AES128_CBC_SHA, RSA_3DES_EDE_CBC_SHA, ECDHE_RSA_AES128_GCM_SHA256 —
  достаточно для этого сервера. Расширение (CHACHA20/ECDSA/TLS1.3) — отдельная
  история, не требуется.

---
name: other-subsystems
description: Additional subsystems - Crypto, SQL, XHTML
license: MIT
compatibility: opencode
metadata:
  audience: developers
  subsystem: various
---

## What I do

- Document Crypto subsystem for hashing and encryption
- Explain SQL subsystem for database access
- Cover XHTML for HTML export

## When to use me

Use when working with cryptography, databases, or HTML export.

## Documentation Source

`Crypto/Docu/*.odc`, `Sql/Docu/*.odc`, `Xhtml/Docu/*.odc`

## Crypto Subsystem

Cryptographic services.

### Hashing

```oberon
IMPORT CryptoHashes;

VAR hash: CryptoHashes.Hash; data: ARRAY 1024 OF BYTE; digest: ARRAY 32 OF BYTE;
BEGIN
    (* MD5 *)
    hash := CryptoHashes.MD5;
    hash.Initialize;
    hash.Update(data, LEN(data));
    hash.Finalize(digest);
    
    (* SHA-1, SHA-256 *)
    hash := CryptoHashes.SHA1;
    hash := CryptoHashes.SHA256;
END;
```

### Ciphers

```oberon
IMPORT CryptoCiphers;

VAR cipher: CryptoCiphers.Cipher; key, iv, data: ARRAY 32 OF BYTE;
BEGIN
    (* AES *)
    cipher := CryptoCiphers.AES;
    cipher.Initialize(key, iv, CryptoCiphers.encrypt);
    cipher.Process(data, LEN(data));
END;
```

### Random

```oberon
IMPORT CryptoRandom;

VAR bytes: ARRAY 16 OF BYTE;
BEGIN
    CryptoRandom.GetBytes(bytes);
END;
```

## SQL Subsystem

Database connectivity.

### Basic Usage

```oberon
IMPORT Sql;

VAR db: Sql.Database; res: INTEGER;
BEGIN
    db := Sql.OpenDatabase("host", "user", "password", "database", res);
    IF res = 0 THEN
        (* execute query *)
        Sql.Exec(db, "SELECT * FROM table", callback, NIL, res);
        Sql.CloseDatabase(db)
    END
END;
```

## XHTML Subsystem

HTML/XHTML export.

### Export to HTML

```oberon
IMPORT Xhtml;

(* Text documents can be exported to HTML via converter *)
```

## Lists Subsystem

List utilities.

```oberon
IMPORT Lists;

TYPE
    List = POINTER TO RECORD
        next: List
    END;
```

## Hyper Subsystem

Hyperlink support.

## Hr Subsystem

Horizontal rules in text.

## Odf Subsystem

OpenDocument format support.

## Cpc Subsystem

Cross-platform C code generation.

## Converting Documentation

```bash
# Crypto
odcey text ./Crypto/Docu/Hashes.odc
odcey text ./Crypto/Docu/Ciphers.odc

# SQL
odcey text ./Sql/Docu/*.odc

# XHTML
odcey text ./Xhtml/Docu/*.odc
```

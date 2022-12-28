# Microsoft Endpoint Management Configuration Manager Naming Conventions

## Introduction

The purpose of this document is to provide a system wide naming standard for Microsoft Endpoint Management Configuration Manager (`MEMCM`) environment.

## Allowed Characters

Allowed characters in the console and source folders.

| Name          | Character               |
| ------------- | :--------:              |
| Alphanumeric  | `[A - Z, a - z, 0 - 9]` |
| Space         | `' '`                   |
| Underscore    | `_`                     |
| Period        | `.`                     |
| Dash          | `-`                     |

## Definitions

### Object Names

Object names are created using by `Prefixes` and `Fields`. Prefixes are separated by dash (`-`). Fields are separated by space-dash-space (` - `). Field values are separated by space (` `). If used, version numbers are separated by period (`.`).

### Brackets

Brackets are used to specify they type of the field or prefix.

* [] - Mandatory
* {} - Optional
* () - Conditional - Can be either mandatory or optional.

> Note
> The order in which they appear must be respected.

## Descriptions

Console objects should have a short description, specifying what they are used for.

## Device Collections

Collections should have a short description, specifying what they are used for. For temporary or test collections a deletion date should be specified.

### General

```text
{TST/TMP}         --> Prefix if the collection is temporary or test
[Collection Type] --> APP/SU/MW...
{Environment}     --> Environment or customer
[Machine Type]    --> Server or Workstation
(Platform)        --> Linux/Windows/Other - Mandatory for non windows devices
{OS version}      --> 7, 10, 2016...
{Scope}           --> Collection resources scope
{Deployment Type} --> Deployment type
{Open}            --> Open descriptor
```

### Formatting

| Field          | Max Characters | Case   |
| -------------  | :------------: | :----: |
| TST/TMP        | 3              | Upper  |

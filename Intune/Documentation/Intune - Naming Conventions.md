# Microsoft Intune Naming Conventions

## Introduction

The purpose of this document is to provide a system wide naming standard for Microsoft Intune (`Intune`) environment.

## Definitions

### Brackets

Brackets are used to specify the type or prefix of the field.

* `[]` - Mandatory.
* `{}` - Optional.
* `()` - Conditional. Can be either mandatory or optional.
* `<>` - Translation needed.
* ` `  - No brackets is literal.

> Notes
> The order in which they appear must be respected.

## Allowed Characters

Allowed characters in the console and source folders.

| Name          | Character               |
| ------------- | :-------------:         |
| Alphanumeric  | `[A - Z, a - z, 0 - 9]` |
| Space         | `' '`                   |
| Underscore    | `_`                     |
| Period        | `.`                     |
| Dash          | `-`                     |

## Names

* Object names are created using by '`Prefixes`' and '`Fields`'.
* Prefixes are separated by dash '`-`'.
* Fields are separated by space-dash-space '` - `'.
* Field values are separated by space '` `'.
* Version numbers are separated by period '`.`'.
* Test or temporary object will use the `_DEV` prefix.

## Descriptions

* Objects will have a short description, specifying what they are used for.
* Temporary objects will have a deletion date specified here in ISO 8601 format (`YYYY-MM-DD`).

## Formatting

| Field            | Max Characters                | Case   |
| --------------   | :-------------:               | :----: |
| Prefix           | 3 excluding `_`               | Upper  |
| AAD Group Prefix | 6                             | Title  |
| Name             | 20                            | Title  |
| Function         | 10                            | Title  |
| Type             | 10                            | Title  |
| Open             | 10                            | Title  |

> Notes
> Combined length should not exceed 50 characters.

## Prefixes

* `_DEV`      - Object is temporary or test. Added before the next two prefixes.
* `ALL`       - Object is global. Prefix is literal.
* `<Company>` - Object is or applies to Company. Prefix needs to be translated from the [Company Abreviation List](https://docs.google.com/spreadsheets/d/1r7DSQzzg6IeVc2N8LXuBhlPI4SB3yCzgGR4TAbFCgrM/edit#gid=0).
* `Intune`    - Used only for AAD Group names, these have different naming conventions from the standard naming schema.

### Example

```text
[_DEV]
[ALL]
[VIT]
[Intune]
```

> Notes
> Complete examples after finishing this document

## Fields

```text
[AplicabiltiyArea] --> Area where the object applies (To be Defined)
[Name]             --> Name of the object
[Purpose]          --> What the object purpuse is in as few words as possible (summarize)
{Open}             --> Open object descriptor, add additional info here
```

> Notes
> The Field order needs to be respected
> !!! Define Applicability Area !!!


## Categories

### Groups

| Field             | Max Characters  | Case   | Available Values | Description              |
| :--------------:  | :-------------: | :----: | :--------------: | :--------------:         |
| [Prefix]            | 6               | Title  | `Intune`       | Intune prefix            |
| [Type]              | 1               | Title  | `U` or `D`     | `User` or `Device` group |
| [CompanyAbreviation]              | 3              | Title  |                |                          |
| [Purpose]          | 10              | Title  |                 |                          |
| {Open}              | 10              | Title  |                |                          |

```text
## Example
Intune - U - VIT - All
Intune - U - VIT - App - 7zip
Intune - U - VIT - App - Custom Token
Intune - U - VIT - Intune License
Intune - U - VIT - Windows Enterprise License
Intune - D - VIT - Autopilot Profile
```

> Notes
> !! Needs Further discussion with the team !!
> !!! How to specify Exceptions !!!


### Device Names

| Index | Field             | Max Characters  | Case   | Available Values | Mandatory | Description          |
| ----- | :--------------:  | :-------------: | :----: | :--------------: | :-------: | :--------------:     |
| 1     | Prefix            | 3               | Upper  | `[<Company>]`    | Yes       | Company abreviation  |
| 2     | Name              | 12              | Upper  | `[SerialNumber]` | Yes       | Partial or full SN   |

> Notes
> Delimiter for computer names is `-` with no spaces

```text
## Example
[<Company>][SerialNumber] --> VIT-SN1234567890
```

### Configuration Profiles

| Index | Field             | Max Characters  | Case   | Available Values    | Mandatory | Description                                   |
| ----- | :--------------:  | :-------------: | :----: | :--------------:    | :-------: | :--------------:                              |
| 1     | Prefix            | 3               | Upper  | `[<Company>]`       | Yes       | Company abreviation                           |
| 2     | Function          | 10              | Title  | `[Function]`        | Yes       | What it is does, short and concise            |
| 3     | Open              | 10              | Title  | `{Open}`            | No        | Other `Usefull` description                   |

```text
[<Company>][<OperatingSystem>][Type][Function]{Open} --> VIT - macOS - Certificate - GlobalCA
```

> Notes
> Delimiter for configuration profiles is as defined in [<ins>*Names*</ins>](##Names) space-dash-space '` - `'
> !!! How to specify Exceptions !!!

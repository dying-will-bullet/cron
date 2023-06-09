<h1 align="center"> cron ⏳ </h1>

[![CI](https://github.com/dying-will-bullet/cron/actions/workflows/ci.yaml/badge.svg)](https://github.com/dying-will-bullet/cron/actions/workflows/ci.yaml)
![](https://img.shields.io/badge/language-zig-%23ec915c)

## Supported format

| Field Name   | Mandatory | Allowed Values  | Default Value | Allowed Special Characters |
| ------------ | --------- | --------------- | ------------- | -------------------------- |
| Seconds      | No        | 0-59            | 0             | \* / , -                   |
| Minutes      | Yes       | 0-59            | N/A           | \* / , -                   |
| Hours        | Yes       | 0-23            | N/A           | \* / , -                   |
| Day of month | Yes       | 1-31            | N/A           | \* / , - ? L               |
| Month        | Yes       | 1-12 or JAN-DEC | N/A           | \* / , -                   |
| Day of week  | Yes       | 0-6 or SUN-SAT  | N/A           | \* / , - ? L               |
| Year         | No        | 1970-2099       | \*            | \* / , -                   |

## LICENSE

MIT License Copyright (c) 2023, Hanaasagi

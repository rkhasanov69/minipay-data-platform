# MiniPay Data Platform

Учебный pet-проект: построение небольшой платформы данных с нуля для вымышленной
платёжной системы MiniPay — максимально приближенно к тому, как это устроено
в реальных компаниях.

## Что будет в проекте

- OLTP-источник данных на PostgreSQL (пользователи, карты, мерчанты, транзакции)
- ETL/ELT на Python, включая генерацию правдоподобных тестовых данных
- Оркестрация пайплайнов через Airflow
- Слой трансформаций на dbt (staging → intermediate → marts)
- Аналитические витрины и BI-дашборды поверх них

## Статус

В процессе разработки.


## Docker

`scripts/setup-docker.sh` ставит Docker Engine из официального репозитория с сетевыми
настройками, которые не пересекаются с корпоративным VPN (диапазоны `10.10.0.0/16` и
`10.20.0.0/16` в `daemon.json`).

### Перед первым запуском на новой машине

Обязательно проверь сети машины и убедись, что диапазоны выше ничего не пересекают:

    ip addr
    ip route

Если пересечение есть — поменяй значения `bip` и `default-address-pools` внутри
`scripts/setup-docker.sh` до запуска.

### Запуск

    chmod +x scripts/setup-docker.sh
    tmux new -s docker-setup
    ./scripts/setup-docker.sh

Запуск через `tmux` — не опционально: если во время установки Docker поднимется на
дефолтном диапазоне, конфликтующем с VPN, и SSH оборвётся, скрипт продолжит работать
на сервере, и можно будет вернуться командой `tmux attach -t docker-setup`.

После завершения — перелогинься по SSH (чтобы применилась группа `docker`) и проверь:

    groups
    docker run hello-world

## PostgreSQL (docker-compose)

`compose.yaml` поднимает PostgreSQL для OLTP-источника данных MiniPay.

### Перед первым запуском на новой машине

`.env` в git не входит (см. `.gitignore`) — создай его вручную рядом с `compose.yaml`:

    POSTGRES_PASSWORD=<свой пароль>

### Запуск

    docker compose up -d
    docker compose ps

### Проверка

    docker compose exec postgres-oltp psql -U minipay -d minipay_oltp


## OLTP-схема (PostgreSQL)

DDL-скрипты для схемы `minipay_oltp` лежат в папке `sql/`, пронумерованы в порядке применения:

- `sql/01_oltp_schema.sql` — основные таблицы: `users`, `merchants`, `cards`, `transactions`.
- `sql/02_transaction_status_history.sql` — журнал изменений статуса транзакции.
- `sql/03_backfill_transaction_status_history.sql` — идемпотентный бэкфилл: досоздаёт записи в журнале статусов для транзакций, у которых их ещё нет (например, вставленных до появления этой логики в генераторе).



Применяются на уже поднятом контейнере с Postgres (см. раздел выше), по порядку номеров файлов:

```bash
cat sql/01_oltp_schema.sql | docker compose exec -T postgres-oltp psql -U minipay -d minipay_oltp
cat sql/02_transaction_status_history.sql | docker compose exec -T postgres-oltp psql -U minipay -d minipay_oltp
cat sql/03_backfill_transaction_status_history.sql | docker compose exec -T postgres-oltp psql -U minipay -d minipay_oltp
```

Скрипты безопасно перезапускать повторно (используют `CREATE TABLE IF NOT EXISTS` и обёрнуты в транзакцию `BEGIN`/`COMMIT`). При появлении новых таблиц в будущем достаточно будет применить только новые файлы с большим номером.


## Тестовые данные (Python)

Генерация тестовых данных для MiniPay разбита на несколько скриптов в `scripts/`:

- `scripts/seed_merchants.py` — одноразовый сид справочника мерчантов (курируемый список реальных узбекских брендов). Запускается вручную, когда нужно докинуть мерчантов — не входит в регулярный прогон.
- `scripts/generate_test_data.py` — регулярная генерация: `users` (Faker, локаль `uz_UZ`, имя/фамилия согласованы по полу, телефон в формате `998XXXXXXXXX`, город — из списка крупных городов Узбекистана, статус — 90% `active`) и `cards` (1-3 карты на каждого пользователя, тип карты и статус — с реалистичными весами).
- `scripts/generate_transactions.py` — независимая генерация `transactions` поверх уже существующих активных карт и мерчантов (сам ничего не создаёт в `users`/`cards`/`merchants`, только читает их id), плюс сразу пишет соответствующую историю в `transaction_status_history` (каждая транзакция стартует с `pending`, и если финальный статус другой — добавляется вторая запись).

### Перед первым запуском на новой машине

Нужно Python-окружение (venv) с зависимостями из `requirements.txt`.
`scripts/setup-python-env.sh` идемпотентен: ставит системный пакет `python3.12-venv`, если его ещё нет, создаёт `venv/` (если его ещё нет), ставит зависимости, и добавляет alias `activate-mp` в `~/.bashrc` (если его там ещё нет) — быстрая активация venv из любого места одной командой.

    chmod +x scripts/setup-python-env.sh
    ./scripts/setup-python-env.sh

После первого запуска скрипта на машине — один раз выполни `source ~/.bashrc` (или открой новый терминал), чтобы текущий шелл подхватил новый alias. Дальше на этой машине `activate-mp` работает сразу в любом новом терминале, без дополнительных действий.

`.env` с `POSTGRES_PASSWORD` должен уже существовать (см. раздел PostgreSQL выше) — все генераторы используют его для подключения к базе.

### Запуск

    activate-mp
    python3 scripts/seed_merchants.py       # один раз, при необходимости
    python3 scripts/generate_test_data.py   # users + cards
    python3 scripts/generate_transactions.py

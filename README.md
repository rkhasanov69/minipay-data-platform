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

Применяются на уже поднятом контейнере с Postgres (см. раздел выше), по порядку номеров файлов:

```bash
cat sql/01_oltp_schema.sql | docker compose exec -T postgres-oltp psql -U minipay -d minipay_oltp
cat sql/02_transaction_status_history.sql | docker compose exec -T postgres-oltp psql -U minipay -d minipay_oltp
```

Скрипты безопасно перезапускать повторно (используют `CREATE TABLE IF NOT EXISTS` и обёрнуты в транзакцию `BEGIN`/`COMMIT`). При появлении новых таблиц в будущем достаточно будет применить только новые файлы с большим номером.

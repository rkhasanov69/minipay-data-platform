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

В процессе разработки. Уже реализовано: OLTP-источник, генерация тестовых данных, raw-слой в отдельном DWH с инкрементальной загрузкой, регулярный запуск генераторов по cron и ежедневные бекапы. Дальше: оркестрация (Airflow), dbt, аналитические витрины, BI.


## Docker

`scripts/setup-docker.sh` ставит Docker Engine из официального репозитория с сетевыми
настройками, которые не пересекаются с корпоративным VPN (диапазоны `10.10.0.0/16` и
`10.20.0.0/16` в `daemon.json`).

### Перед первым запуском на новой машине

Обязательно проверь сети машины и убедись, что диапазоны выше ничего не пересекают:

```bash
ip addr
ip route
```

Если пересечение есть — поменяй значения `bip` и `default-address-pools` внутри
`scripts/setup-docker.sh` до запуска.

### Запуск

```bash
chmod +x scripts/setup-docker.sh
tmux new -s docker-setup
./scripts/setup-docker.sh
```

Запуск через `tmux` — не опционально: если во время установки Docker поднимется на
дефолтном диапазоне, конфликтующем с VPN, и SSH оборвётся, скрипт продолжит работать
на сервере, и можно будет вернуться командой `tmux attach -t docker-setup`.

После завершения — перелогинься по SSH (чтобы применилась группа `docker`) и проверь:

```bash
groups
docker run hello-world
```


## PostgreSQL (docker-compose)

`compose.yaml` поднимает два контейнера PostgreSQL: `postgres-oltp` (источник данных MiniPay, порт `5432`) и `postgres-dwh` (хранилище, порт `5433`, см. раздел про DWH ниже). Оба сервиса подняты с `restart: unless-stopped` — переживают перезагрузку хоста и падения демона, но не мешают осознанной ручной остановке.

### Перед первым запуском на новой машине

`.env` в git не входит (см. `.gitignore`) — создай его вручную рядом с `compose.yaml`:

```
POSTGRES_PASSWORD=<свой пароль>
DWH_POSTGRES_PASSWORD=<свой пароль>
```

Первая переменная — пароль OLTP-базы, вторая — пароль контейнера `postgres-dwh`.

### Запуск

```bash
docker compose up -d
docker compose ps
```

### Проверка

```bash
docker compose exec postgres-oltp psql -U minipay -d minipay_oltp
```


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

Файлы `sql/04_*` и следующие относятся к хранилищу (DWH), они описаны в разделе про DWH ниже.


## Тестовые данные (Python)

Генерация тестовых данных для MiniPay разбита на несколько скриптов в `scripts/`:

- `scripts/seed_merchants.py` — одноразовый сид справочника мерчантов (курируемый список реальных узбекских брендов). Запускается вручную, когда нужно докинуть мерчантов — не входит в регулярный прогон.
- `scripts/generate_test_data.py` — регулярная генерация: `users` (Faker, локаль `uz_UZ`, имя/фамилия согласованы по полу, телефон в формате `998XXXXXXXXX`, город — из списка крупных городов Узбекистана, статус — 90% `active`) и `cards` (1-3 карты каждому пользователю, у которого ещё нет ни одной карты — поэтому карты старых пользователей при повторных запусках не растут; тип карты и статус — с реалистичными весами). За один запуск создаётся 10 новых пользователей.
- `scripts/generate_transactions.py` — независимая генерация `transactions` (100 за запуск) поверх уже существующих активных карт и мерчантов (сам ничего не создаёт в `users`/`cards`/`merchants`, только читает их id), плюс сразу пишет соответствующую историю в `transaction_status_history` (каждая транзакция стартует с `pending`, и если финальный статус другой — добавляется вторая запись).

Регулярный запуск генераторов по расписанию описан в разделе «Расписание и бекапы (cron)» ниже.

### Перед первым запуском на новой машине

Нужно Python-окружение (venv) с зависимостями из `requirements.txt`.
`scripts/setup-python-env.sh` идемпотентен: ставит системный пакет `python3.12-venv`, если его ещё нет, создаёт `venv/` (если его ещё нет), ставит зависимости, и добавляет alias `activate-mp` в `~/.bashrc` (если его там ещё нет) — быстрая активация venv из любого места одной командой.

```bash
chmod +x scripts/setup-python-env.sh
./scripts/setup-python-env.sh
```

После первого запуска скрипта на машине — один раз выполни `source ~/.bashrc` (или открой новый терминал), чтобы текущий шелл подхватил новый alias. Дальше на этой машине `activate-mp` работает сразу в любом новом терминале, без дополнительных действий.

`.env` с `POSTGRES_PASSWORD` должен уже существовать (см. раздел PostgreSQL выше) — все генераторы используют его для подключения к базе.

### Запуск вручную

```bash
activate-mp
python3 scripts/seed_merchants.py       # один раз, при необходимости
python3 scripts/generate_test_data.py   # users + cards
python3 scripts/generate_transactions.py
```


## DWH и raw-слой (PostgreSQL)

Для аналитики поднят отдельный контейнер `postgres-dwh` (база `minipay_dwh`, порт `5433`), физически отделённый от продакшн-базы `minipay_oltp` — тяжёлые аналитические запросы не должны нагружать OLTP.

Первый слой хранилища — `raw`: точная копия таблиц источника (`users`, `cards`, `merchants`, `transactions`, `transaction_status_history`), без бизнес-ограничений (`CHECK`, `UNIQUE`, `FOREIGN KEY`) — только структура и типы данных. Задача raw-слоя — зафиксировать данные "как есть", без интерпретации; проверки бизнес-логики переезжают на слой трансформаций (dbt).

Применить схему:

```bash
cat sql/04_dwh_raw_schema.sql | docker compose exec -T postgres-dwh psql -U minipay -d minipay_dwh
```

Проверить результат:

```bash
docker compose exec postgres-dwh psql -U minipay -d minipay_dwh -c "\dt raw.*"
```

Extract-Load: копирование данных из OLTP в raw (`scripts/load_raw.py`). Загрузка инкрементальная — точка отсчёта по каждой таблице хранится в служебной таблице `raw.load_log`, по колонке `updated_at` (`changed_at` для `transaction_status_history`). При каждом запуске скрипт запрашивает из OLTP строки, изменившиеся с прошлого запуска, с запасом в 10 минут назад (lookback) — это защита от гонки между моментом, когда Postgres присваивает `updated_at` (в начале транзакции), и моментом реального коммита: без запаса строка из долгой транзакции может закоммититься уже после того, как указатель ушёл дальше, и навсегда выпасть из инкрементальной загрузки. Найденные строки удаляются из raw по `id` (`DELETE ... WHERE id = ANY(...)`) и вставляются заново — идемпотентно, поэтому повторно попавшие в окно перекрытия строки не создают дублей. При полностью пустом `load_log` (первый запуск) выполняется полная первичная загрузка.

Применить схему служебной таблицы (одноразово, при первом развёртывании):

```bash
cat sql/05_raw_load_log.sql | docker compose exec -T postgres-dwh psql -U minipay -d minipay_dwh
```

Изначально `raw.load_log` хранила ещё и `last_id` — отдельный указатель по id для `transaction_status_history`. Сейчас все пять таблиц используют единый механизм по времени с запасом на пересечение, и колонка стала не нужна:

```bash
cat sql/06_drop_load_log_last_id.sql | docker compose exec -T postgres-dwh psql -U minipay -d minipay_dwh
```

Запуск загрузки:

```bash
activate-mp
python scripts/load_raw.py
```


## Расписание и бекапы (cron)

Регулярные задачи запускаются через cron — на каждой машине независимо. Важно: **crontab не хранится в git**, он живёт на самой машине под конкретным пользователем, поэтому актуальный список задач записан здесь. При любом изменении расписания обновляй этот раздел.

Время в crontab — серверное (UTC), а не местное.

| Задача | Расписание | Что запускает | Лог |
|---|---|---|---|
| Бекап OLTP и DWH | ежедневно, 03:00 | `scripts/backup_db.sh` | `backups/backup.log` |
| Новые пользователи и карты | каждые 3 часа, в :05 | `scripts/run_generator.sh generate_test_data.py` | `logs/generators.log` |
| Новые транзакции | каждый час, в :15 | `scripts/run_generator.sh generate_transactions.py` | `logs/generators.log` |

Обе машины (рабочая и домашняя) генерируют данные независимо, поэтому содержимое баз на них со временем расходится — это осознанное решение, данные синтетические.

### Бекап

`scripts/backup_db.sh` делает полный дамп (схема + данные, формат custom) обеих баз — `minipay_oltp` и `minipay_dwh` — прямо из контейнеров (`pg_dump -Fc`) и кладёт в `backups/` файлы вида `minipay_oltp_2026-09-21.dump`. Дампы старше 7 суток удаляются, но только если оба новых дампа успешно созданы. Папка `backups/` в `.gitignore`.

Проверка, что бекап пригоден к восстановлению (во временную базу, рабочую не трогаем):

```bash
docker compose exec -T postgres-oltp createdb -U minipay restore_test
cat backups/minipay_oltp_<дата>.dump | docker compose exec -T postgres-oltp pg_restore -U minipay -d restore_test
docker compose exec -T postgres-oltp psql -U minipay -d restore_test -c "SELECT count(*) FROM transactions;"
docker compose exec -T postgres-oltp dropdb -U minipay restore_test
```

### Запуск скриптов через обёртку

`scripts/run_generator.sh <имя_скрипта.py>` запускает один Python-скрипт из `scripts/` через `venv/bin/python` (без ручной активации окружения) и пишет в вывод время начала и окончания — так удобно читать лог. Перед запуском сам переходит в корень репозитория, поэтому работает из любой папки.

### Настройка на новой машине

Предварительно: репозиторий склонирован, контейнеры подняты, venv создан (`scripts/setup-python-env.sh`).

```bash
mkdir -p logs
./scripts/backup_db.sh                                  # проверка руками
./scripts/run_generator.sh generate_test_data.py        # проверка руками
./scripts/run_generator.sh generate_transactions.py     # проверка руками
pwd                                                     # запомнить путь к репозиторию
crontab -e
```

В crontab добавить три строки, подставив вместо `<ПУТЬ>` путь из `pwd`:

```
0 3 * * * <ПУТЬ>/scripts/backup_db.sh >> <ПУТЬ>/backups/backup.log 2>&1
5 */3 * * * <ПУТЬ>/scripts/run_generator.sh generate_test_data.py >> <ПУТЬ>/logs/generators.log 2>&1
15 * * * * <ПУТЬ>/scripts/run_generator.sh generate_transactions.py >> <ПУТЬ>/logs/generators.log 2>&1
```

Проверить: `crontab -l`. Папка `logs/` должна существовать заранее — иначе cron не сможет открыть лог и задача молча не запустится.

## Оркестрация (Airflow)

Для регулярного запуска `load_raw.py` используется Apache Airflow 2.10.5 (slim-образ), поднятый через тот же `docker-compose` вместе с остальной инфраструктурой.

### Компоненты

- **postgres-airflow** — отдельная PostgreSQL-база для служебных (metadata) данных Airflow: история запусков, статусы задач, пользователи веб-интерфейса. Не путать с `postgres-dwh`. Порт наружу не публикуется — доступна только внутри docker-сети.
- **airflow-init** — разовая инициализация: создаёт схему в metadata-базе и первого администратора веб-интерфейса. Запускается один раз, не является постоянным сервисом.
- **airflow-scheduler** — основной постоянный процесс: следит за расписанием DAG-ов и исполняет задачи (executor — `LocalExecutor`, локальные параллельные процессы без внешних зависимостей типа Celery/Redis).
- **airflow-webserver** — веб-интерфейс (порт 8080). Поднимается **по требованию**, не постоянно, через профиль `ui` — чтобы не расходовать память впустую на серверах с её нехваткой.

### Собственный образ

Используется slim-образ Airflow (`apache/airflow:slim-2.10.5-python3.9`) — без лишних предустановленных провайдеров. Поверх него собирается свой образ (см. `Dockerfile`) с доустановкой:

- `apache-airflow-providers-postgres` — драйвер для подключения к своей же metadata-базе;
- `psycopg2-binary`, `python-dotenv` — зависимости самого `scripts/load_raw.py`, который запускается внутри контейнера.

### Переменные окружения (`.env`)

Дополнительно к уже описанным выше нужны:

AIRFLOW_POSTGRES_PASSWORD=<пароль для metadata-базы Airflow>
AIRFLOW_FERNET_KEY=<ключ шифрования Airflow>


Fernet-ключ должен быть одинаковым для `airflow-init`/`airflow-scheduler`/`airflow-webserver` (задаётся один раз через общий блок `x-airflow-common` в `compose.yaml`), но **не обязан совпадать** между разными окружениями (рабочий/домашний сервер) — у каждого своя независимая metadata-база. Генерируется так:

```bash
docker run --rm apache/airflow:slim-2.10.5-python3.9 python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

### Подключение load_raw.py

Внутри контейнеров Airflow скрипт подключается к базам не через `localhost` (как при запуске через cron на хосте), а по именам сервисов в docker-сети. Это задаётся переменными окружения в `x-airflow-common` (`OLTP_HOST`, `OLTP_PORT`, `DWH_HOST`, `DWH_PORT`) — сам скрипт при их отсутствии по умолчанию падает обратно на `localhost` и старые порты, так что для запуска через cron ничего менять не пришлось.

### Первый запуск / развёртывание на новом сервере

```bash
mkdir -p dags   # git не хранит пустые папки, создаётся руками
docker compose up --build airflow-init
docker compose up -d --build airflow-scheduler
```

Поднять веб-интерфейс (по требованию):

```bash
docker compose --profile ui up -d airflow-webserver
```

Остановить:

```bash
docker compose stop airflow-webserver
```

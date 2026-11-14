# Переход с локального JSON на Supabase

Сейчас каталог лежит в `assets/data/catalog.json` и работает офлайн.
Когда контента станет много и его нужно будет обновлять без релиза
приложения, переносим его в Supabase (Postgres + Auth + Storage).

## Схема базы

```sql
create table subjects (
  id          text primary key,
  name        text not null,
  color       text not null default '#4F46E5',
  icon        text not null default 'menu_book',
  sort_order  int  not null default 0
);

create table textbooks (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,          -- старый id из JSON
  subject_id  text not null references subjects(id),
  grade       int  not null check (grade between 1 and 11),
  title       text not null,
  author      text not null default '',
  year        int,
  publisher   text not null default '',
  color       text not null default '#4F46E5',
  cover_url   text,
  created_at  timestamptz not null default now()
);

create table tasks (
  id           uuid primary key default gen_random_uuid(),
  textbook_id  uuid not null references textbooks(id) on delete cascade,
  number       text not null,
  page         int,
  condition    text not null,
  image_url    text,
  created_at   timestamptz not null default now(),
  unique (textbook_id, number)
);

create table solutions (
  id          uuid primary key default gen_random_uuid(),
  task_id     uuid not null references tasks(id) on delete cascade,
  author      text not null default 'Команда ГДЗ',
  rating      numeric(2,1) not null default 0,
  steps       text[] not null,
  answer      text not null default '',
  image_url   text,
  published   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- Поиск по номеру, условию, названию и автору учебника
create extension if not exists pg_trgm;

create index tasks_condition_trgm on tasks using gin (condition gin_trgm_ops);
create index tasks_number_trgm on tasks using gin (number gin_trgm_ops);
create index textbooks_title_trgm on textbooks using gin (title gin_trgm_ops);
create index textbooks_author_trgm on textbooks using gin (author gin_trgm_ops);
```

## Публичный доступ на чтение

```sql
alter table subjects  enable row level security;
alter table textbooks enable row level security;
alter table tasks     enable row level security;
alter table solutions enable row level security;

create policy "read subjects"  on subjects  for select using (true);
create policy "read textbooks" on textbooks for select using (true);
create policy "read tasks"     on tasks     for select using (true);
create policy "read published solutions"
  on solutions for select using (published = true);
```

Запись — только через service-role (админка/импорт), не из приложения.

## Поиск одним запросом

```sql
create or replace function search_tasks(q text)
returns setof tasks
language sql stable as $$
  select t.*
  from tasks t
  join textbooks tb on tb.id = t.textbook_id
  join subjects  s  on s.id = tb.subject_id
  where q <> '' and (
    t.number    ilike '%' || q || '%' or
    t.condition ilike '%' || q || '%' or
    tb.title    ilike '%' || q || '%' or
    tb.author   ilike '%' || q || '%' or
    s.name      ilike '%' || q || '%'
  )
  limit 50;
$$;
```

## Изображения

- Bucket `covers` — обложки учебников (публичный).
- Bucket `solutions` — фото решений (публичный, только чтение).
- Загрузка — из админки через service-role.

## Как подключить во Flutter

1. Добавить зависимость:

```yaml
dependencies:
  supabase_flutter: ^2.0.0
```

2. Инициализировать в `main()`:

```dart
await Supabase.initialize(url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY);
```

3. Заменить загрузку JSON в `AppState.init()` на запросы:

```dart
final subjects = await Supabase.instance.client.from('subjects').select();
final textbooks = await Supabase.instance.client.from('textbooks').select();
final tasks = await Supabase.instance.client
    .from('tasks')
    .select('*, solutions(*)');
```

4. Смаппить ответы в те же модели (`Subject`, `Textbook`, `TaskItem`,
   `Solution`) — экраны менять не придётся.

5. Кэш для офлайна: сохранять ответы в `shared_preferences` или
   в локальную SQLite (пакет `drift`/`sqflite`), обновлять по TTL.

## Импорт текущего JSON

Скрипт импорта: прочитать `assets/data/catalog.json`, вставить предметы,
учебники, задания и решения. `slug` учебника = старый `id`, чтобы ссылки
в избранном не потерялись.

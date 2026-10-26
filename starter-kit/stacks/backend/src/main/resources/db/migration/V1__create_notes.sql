-- One file per change. Never edit a migration after it is merged; add V2, V3, ...
create table notes (
    id         bigint generated always as identity primary key,
    title      text        not null check (length(title) between 1 and 200),
    body       text,
    created_at timestamptz not null default now()
);

create index notes_created_at_idx on notes (created_at desc);

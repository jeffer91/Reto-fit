-- =====================================================================
-- Reto Fit Familia · configuración de Supabase
-- Cómo usarlo:
--   1. Cambia CAMBIA-ESTE-PIN (línea marcada abajo) por el PIN de la familia.
--   2. En Supabase: SQL Editor → New query → pega todo → Run.
-- Se puede volver a ejecutar sin perder datos.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------- Tablas ----------
create table if not exists public.informes (
  id            bigint generated always as identity primary key,
  persona       text    not null check (length(btrim(persona)) between 1 and 40),
  persona_key   text    not null,
  fecha         date    not null,
  mes           text    not null check (mes ~ '^\d{4}-\d{2}$'),
  puntuacion    numeric not null check (puntuacion between 0 and 150),
  peso          numeric not null check (peso between 10 and 300),
  grasa_pct     numeric not null check (grasa_pct between 1 and 75),
  masa_grasa    numeric not null check (masa_grasa between 0.5 and 200),
  masa_muscular numeric not null check (masa_muscular between 5 and 150),
  imc           numeric not null check (imc between 8 and 80),
  altura        numeric,
  genero        text,
  edad          integer,
  creado        timestamptz not null default now(),
  unique (persona_key, mes)
);

create table if not exists public.pagos (
  id          bigint generated always as identity primary key,
  persona     text    not null,
  persona_key text    not null,
  mes         text    not null check (mes ~ '^\d{4}-\d{2}$'),
  monto       integer not null default 0,
  pagado      boolean not null default false,
  pagado_en   timestamptz,
  unique (persona_key, mes)
);

-- PIN de la familia (guardado cifrado; nadie puede leer esta tabla desde la app)
create table if not exists public.reto_config (
  id       integer primary key default 1 check (id = 1),
  pin_hash text not null
);

-- ---------- Seguridad ----------
-- Todos pueden VER informes y pagos. Nadie escribe directo:
-- solo a través de las funciones de abajo, que piden el PIN.
alter table public.informes    enable row level security;
alter table public.pagos       enable row level security;
alter table public.reto_config enable row level security;

drop policy if exists "ver informes" on public.informes;
create policy "ver informes" on public.informes for select to anon, authenticated using (true);
drop policy if exists "ver pagos" on public.pagos;
create policy "ver pagos" on public.pagos for select to anon, authenticated using (true);

revoke all on public.reto_config from anon, authenticated;
revoke insert, update, delete on public.informes, public.pagos from anon, authenticated;
grant select on public.informes, public.pagos to anon, authenticated;

-- ---------- Funciones ----------
-- "María" y "Maria" son la misma persona
create or replace function public.reto_key(p text) returns text
language sql immutable as $$
  select lower(translate(btrim(regexp_replace(coalesce(p, ''), '\s+', ' ', 'g')),
                         'ÁÉÍÓÚÜÑáéíóúüñ', 'AEIOUUNaeiouun'));
$$;

create or replace function public.reto_pin_ok(p_pin text) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (select 1 from public.reto_config c
                 where c.id = 1 and c.pin_hash = extensions.crypt(coalesce(p_pin, ''), c.pin_hash));
$$;

create or replace function public.verificar_pin(p_pin text) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select public.reto_pin_ok(p_pin);
$$;

create or replace function public.guardar_informes(p_pin text, p_informes jsonb) returns integer
language plpgsql security definer set search_path = public, extensions as $$
declare
  r jsonb;
  n integer := 0;
begin
  if not public.reto_pin_ok(p_pin) then
    raise exception 'PIN incorrecto';
  end if;
  if jsonb_typeof(p_informes) <> 'array' then
    raise exception 'Formato inválido';
  end if;
  for r in select * from jsonb_array_elements(p_informes) loop
    insert into public.informes
      (persona, persona_key, fecha, mes, puntuacion, peso, grasa_pct, masa_grasa, masa_muscular, imc, altura, genero, edad)
    values (
      btrim(regexp_replace(r->>'persona', '\s+', ' ', 'g')),
      public.reto_key(r->>'persona'),
      (r->>'fecha')::date,
      to_char((r->>'fecha')::date, 'YYYY-MM'),
      (r->>'puntuacion')::numeric,
      (r->>'peso')::numeric,
      (r->>'grasaPct')::numeric,
      (r->>'masaGrasa')::numeric,
      (r->>'masaMuscular')::numeric,
      (r->>'imc')::numeric,
      nullif(r->>'altura', '')::numeric,
      case when r->>'genero' in ('Hombre', 'Mujer') then r->>'genero' end,
      nullif(r->>'edad', '')::integer
    )
    on conflict (persona_key, mes) do update set
      persona = excluded.persona, fecha = excluded.fecha,
      puntuacion = excluded.puntuacion, peso = excluded.peso, grasa_pct = excluded.grasa_pct,
      masa_grasa = excluded.masa_grasa, masa_muscular = excluded.masa_muscular, imc = excluded.imc,
      altura = coalesce(excluded.altura, informes.altura),
      genero = coalesce(excluded.genero, informes.genero),
      edad = coalesce(excluded.edad, informes.edad),
      creado = now();
    n := n + 1;
  end loop;
  return n;
end;
$$;

create or replace function public.borrar_informe(p_pin text, p_persona text, p_mes text) returns integer
language plpgsql security definer set search_path = public, extensions as $$
declare n integer;
begin
  if not public.reto_pin_ok(p_pin) then
    raise exception 'PIN incorrecto';
  end if;
  delete from public.informes where persona_key = public.reto_key(p_persona) and mes = p_mes;
  get diagnostics n = row_count;
  return n;
end;
$$;

create or replace function public.marcar_pago(p_pin text, p_persona text, p_mes text, p_monto integer, p_pagado boolean)
returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.reto_pin_ok(p_pin) then
    raise exception 'PIN incorrecto';
  end if;
  insert into public.pagos (persona, persona_key, mes, monto, pagado, pagado_en)
  values (btrim(p_persona), public.reto_key(p_persona), p_mes, coalesce(p_monto, 0), p_pagado,
          case when p_pagado then now() end)
  on conflict (persona_key, mes) do update set
    persona = excluded.persona, monto = excluded.monto, pagado = excluded.pagado, pagado_en = excluded.pagado_en;
  return p_pagado;
end;
$$;

revoke all on function public.reto_pin_ok(text) from public, anon, authenticated;
grant execute on function public.verificar_pin(text) to anon, authenticated;
grant execute on function public.guardar_informes(text, jsonb) to anon, authenticated;
grant execute on function public.borrar_informe(text, text, text) to anon, authenticated;
grant execute on function public.marcar_pago(text, text, text, integer, boolean) to anon, authenticated;

-- ---------- PIN de la familia ----------
insert into public.reto_config (id, pin_hash)
values (1, extensions.crypt('CAMBIA-ESTE-PIN', extensions.gen_salt('bf')))   -- <<< CAMBIA EL PIN AQUÍ
on conflict (id) do update set pin_hash = excluded.pin_hash;

-- ---------- Informes que ya estaban en la app ----------
insert into public.informes
  (persona, persona_key, fecha, mes, puntuacion, peso, grasa_pct, masa_grasa, masa_muscular, imc, altura, genero, edad)
values
  ('Jefferson', 'jefferson', '2026-10-04', '2026-10', 63, 94.10, 34.7, 32.65, 57.31, 31.4, 173, 'Hombre', 35),
  ('Jefferson', 'jefferson', '2026-11-08', '2026-11', 61, 90.75, 35.3, 32.03, 54.81, 30.3, 173, 'Hombre', 35),
  ('Kelly',     'kelly',     '2026-10-04', '2026-10', 69, 52.75, 33.3, 17.57, 32.81, 21.7, 156, 'Mujer', 26)
on conflict (persona_key, mes) do nothing;

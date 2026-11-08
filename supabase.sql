-- =====================================================================
-- Reto Fit Familia · configuración de Supabase
-- Cómo usarlo: en Supabase, SQL Editor → New query → pega todo → Run.
-- Acceso directo (sin PIN). No se permiten informes duplicados.
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
  oculto        boolean not null default false,   -- borrar = ocultar (se puede recuperar)
  unique (persona_key, mes)
);
alter table public.informes add column if not exists oculto boolean not null default false;

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
-- Todos pueden VER informes y pagos. Nadie escribe directo en las tablas:
-- solo a través de las funciones de abajo, que validan los datos y evitan duplicados.
alter table public.informes    enable row level security;
alter table public.pagos       enable row level security;
alter table public.reto_config enable row level security;

drop policy if exists "ver informes" on public.informes;
create policy "ver informes" on public.informes for select to anon, authenticated using (not oculto);
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
  select true;   -- acceso directo: no se pide PIN
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
  k integer;
begin
  if jsonb_typeof(p_informes) <> 'array' then
    raise exception 'Formato inválido';
  end if;
  for r in select * from jsonb_array_elements(p_informes) loop
    -- Informe idéntico ya guardado (aunque sea con otro nombre): no se repite
    if exists (
      select 1 from public.informes i
      where not i.oculto
        and i.fecha = (r->>'fecha')::date
        and i.peso = (r->>'peso')::numeric
        and i.masa_grasa = (r->>'masaGrasa')::numeric
        and i.masa_muscular = (r->>'masaMuscular')::numeric
        and i.puntuacion = (r->>'puntuacion')::numeric
    ) then
      continue;
    end if;
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
    -- Un informe por persona y mes: solo reemplaza uno que había sido borrado
    on conflict (persona_key, mes) do update set
      persona = excluded.persona, fecha = excluded.fecha,
      puntuacion = excluded.puntuacion, peso = excluded.peso, grasa_pct = excluded.grasa_pct,
      masa_grasa = excluded.masa_grasa, masa_muscular = excluded.masa_muscular, imc = excluded.imc,
      altura = excluded.altura, genero = excluded.genero, edad = excluded.edad,
      oculto = false, creado = now()
    where informes.oculto;
    get diagnostics k = row_count;
    n := n + k;
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
  update public.informes set oculto = true
   where persona_key = public.reto_key(p_persona) and mes = p_mes and not oculto;
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

-- ---------- Informes que ya estaban en la app ----------
insert into public.informes
  (persona, persona_key, fecha, mes, puntuacion, peso, grasa_pct, masa_grasa, masa_muscular, imc, altura, genero, edad)
values
  ('Jefferson', 'jefferson', '2026-10-04', '2026-10', 63, 94.10, 34.7, 32.65, 57.31, 31.4, 173, 'Hombre', 35),
  ('Jefferson', 'jefferson', '2026-11-08', '2026-11', 61, 90.75, 35.3, 32.03, 54.81, 30.3, 173, 'Hombre', 35),
  ('Kelly',     'kelly',     '2026-10-04', '2026-10', 69, 52.75, 33.3, 17.57, 32.81, 21.7, 156, 'Mujer', 26)
on conflict (persona_key, mes) do nothing;

-- =====================================================================
-- Ponderación del avance: datos extra del informe y guardado que completa sin duplicar
-- =====================================================================
alter table public.informes add column if not exists grasa_visceral numeric;
alter table public.informes add column if not exists meta_grasa numeric;
alter table public.informes add column if not exists meta_musculo numeric;
alter table public.informes add column if not exists grasa_min numeric;
alter table public.informes add column if not exists grasa_max numeric;
alter table public.informes add column if not exists musculo_min numeric;
alter table public.informes add column if not exists musculo_max numeric;

-- Guarda informes nuevos y completa con datos extra los que ya estaban (sin duplicar).
-- Devuelve {"nuevos": n, "completados": c}
create or replace function public.guardar_informes2(p_informes jsonb) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  r jsonb;
  n integer := 0;
  c integer := 0;
  k integer;
  tid bigint;
begin
  if jsonb_typeof(p_informes) <> 'array' then
    raise exception 'Formato inválido';
  end if;
  for r in select * from jsonb_array_elements(p_informes) loop
    select i.id into tid from public.informes i
     where not i.oculto
       and i.fecha = (r->>'fecha')::date
       and i.peso = (r->>'peso')::numeric
       and i.masa_grasa = (r->>'masaGrasa')::numeric
       and i.masa_muscular = (r->>'masaMuscular')::numeric
       and i.puntuacion = (r->>'puntuacion')::numeric
     limit 1;
    if tid is not null then
      update public.informes set
        grasa_visceral = coalesce(grasa_visceral, nullif(r->>'visceral', '')::numeric),
        meta_grasa     = coalesce(meta_grasa,     nullif(r->>'metaGrasa', '')::numeric),
        meta_musculo   = coalesce(meta_musculo,   nullif(r->>'metaMusculo', '')::numeric),
        grasa_min      = coalesce(grasa_min,      nullif(r->>'grasaMin', '')::numeric),
        grasa_max      = coalesce(grasa_max,      nullif(r->>'grasaMax', '')::numeric),
        musculo_min    = coalesce(musculo_min,    nullif(r->>'musculoMin', '')::numeric),
        musculo_max    = coalesce(musculo_max,    nullif(r->>'musculoMax', '')::numeric),
        altura         = coalesce(altura,         nullif(r->>'altura', '')::numeric),
        genero         = coalesce(genero, case when r->>'genero' in ('Hombre', 'Mujer') then r->>'genero' end),
        edad           = coalesce(edad,           nullif(r->>'edad', '')::integer)
      where id = tid
        and ((grasa_visceral is null and nullif(r->>'visceral', '') is not null)
          or (meta_grasa is null and nullif(r->>'metaGrasa', '') is not null)
          or (meta_musculo is null and nullif(r->>'metaMusculo', '') is not null)
          or (grasa_max is null and nullif(r->>'grasaMax', '') is not null)
          or (musculo_max is null and nullif(r->>'musculoMax', '') is not null));
      get diagnostics k = row_count;
      c := c + k;
      continue;
    end if;
    insert into public.informes
      (persona, persona_key, fecha, mes, puntuacion, peso, grasa_pct, masa_grasa, masa_muscular, imc, altura, genero, edad,
       grasa_visceral, meta_grasa, meta_musculo, grasa_min, grasa_max, musculo_min, musculo_max)
    values (
      btrim(regexp_replace(r->>'persona', '\s+', ' ', 'g')),
      public.reto_key(r->>'persona'),
      (r->>'fecha')::date,
      to_char((r->>'fecha')::date, 'YYYY-MM'),
      (r->>'puntuacion')::numeric, (r->>'peso')::numeric, (r->>'grasaPct')::numeric,
      (r->>'masaGrasa')::numeric, (r->>'masaMuscular')::numeric, (r->>'imc')::numeric,
      nullif(r->>'altura', '')::numeric,
      case when r->>'genero' in ('Hombre', 'Mujer') then r->>'genero' end,
      nullif(r->>'edad', '')::integer,
      nullif(r->>'visceral', '')::numeric, nullif(r->>'metaGrasa', '')::numeric, nullif(r->>'metaMusculo', '')::numeric,
      nullif(r->>'grasaMin', '')::numeric, nullif(r->>'grasaMax', '')::numeric,
      nullif(r->>'musculoMin', '')::numeric, nullif(r->>'musculoMax', '')::numeric
    )
    on conflict (persona_key, mes) do update set
      persona = excluded.persona, fecha = excluded.fecha,
      puntuacion = excluded.puntuacion, peso = excluded.peso, grasa_pct = excluded.grasa_pct,
      masa_grasa = excluded.masa_grasa, masa_muscular = excluded.masa_muscular, imc = excluded.imc,
      altura = excluded.altura, genero = excluded.genero, edad = excluded.edad,
      grasa_visceral = excluded.grasa_visceral, meta_grasa = excluded.meta_grasa, meta_musculo = excluded.meta_musculo,
      grasa_min = excluded.grasa_min, grasa_max = excluded.grasa_max,
      musculo_min = excluded.musculo_min, musculo_max = excluded.musculo_max,
      oculto = false, creado = now()
    where informes.oculto;
    get diagnostics k = row_count;
    n := n + k;
  end loop;
  return jsonb_build_object('nuevos', n, 'completados', c);
end;
$$;

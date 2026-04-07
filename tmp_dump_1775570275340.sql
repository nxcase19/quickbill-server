--
-- PostgreSQL database dump
--

\restrict V9FkrgehpO97ZzryAaCr3L4LX7W3ssIIxOQSm3ZwjBJ4xhrddlGa6L0NzwdvCmf

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: extensions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA extensions;


--
-- Name: graphql; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql;


--
-- Name: graphql_public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql_public;


--
-- Name: pgbouncer; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pgbouncer;


--
-- Name: realtime; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA realtime;


--
-- Name: storage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA storage;


--
-- Name: vault; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA vault;


--
-- Name: pg_graphql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_graphql WITH SCHEMA graphql;


--
-- Name: EXTENSION pg_graphql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_graphql IS 'pg_graphql: GraphQL support';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: supabase_vault; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;


--
-- Name: EXTENSION supabase_vault; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION supabase_vault IS 'Supabase Vault Extension';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: aal_level; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.aal_level AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


--
-- Name: code_challenge_method; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.code_challenge_method AS ENUM (
    's256',
    'plain'
);


--
-- Name: factor_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_status AS ENUM (
    'unverified',
    'verified'
);


--
-- Name: factor_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_type AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


--
-- Name: oauth_authorization_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_authorization_status AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


--
-- Name: oauth_client_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_client_type AS ENUM (
    'public',
    'confidential'
);


--
-- Name: oauth_registration_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_registration_type AS ENUM (
    'dynamic',
    'manual'
);


--
-- Name: oauth_response_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_response_type AS ENUM (
    'code'
);


--
-- Name: one_time_token_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.one_time_token_type AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


--
-- Name: action; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.action AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'TRUNCATE',
    'ERROR'
);


--
-- Name: equality_op; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.equality_op AS ENUM (
    'eq',
    'neq',
    'lt',
    'lte',
    'gt',
    'gte',
    'in'
);


--
-- Name: user_defined_filter; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.user_defined_filter AS (
	column_name text,
	op realtime.equality_op,
	value text
);


--
-- Name: wal_column; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_column AS (
	name text,
	type_name text,
	type_oid oid,
	value jsonb,
	is_pkey boolean,
	is_selectable boolean
);


--
-- Name: wal_rls; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_rls AS (
	wal jsonb,
	is_rls_enabled boolean,
	subscription_ids uuid[],
	errors text[]
);


--
-- Name: buckettype; Type: TYPE; Schema: storage; Owner: -
--

CREATE TYPE storage.buckettype AS ENUM (
    'STANDARD',
    'ANALYTICS',
    'VECTOR'
);


--
-- Name: email(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.email() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


--
-- Name: FUNCTION email(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.email() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';


--
-- Name: jwt(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.jwt() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


--
-- Name: FUNCTION role(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.role() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


--
-- Name: FUNCTION uid(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.uid() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';


--
-- Name: grant_pg_cron_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_cron_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_cron'
  )
  THEN
    grant usage on schema cron to postgres with grant option;

    alter default privileges in schema cron grant all on tables to postgres with grant option;
    alter default privileges in schema cron grant all on functions to postgres with grant option;
    alter default privileges in schema cron grant all on sequences to postgres with grant option;

    alter default privileges for user supabase_admin in schema cron grant all
        on sequences to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on tables to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on functions to postgres with grant option;

    grant all privileges on all tables in schema cron to postgres with grant option;
    revoke all on table cron.job from postgres;
    grant select on table cron.job to postgres with grant option;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_cron_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_cron_access() IS 'Grants access to pg_cron';


--
-- Name: grant_pg_graphql_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_graphql_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    func_is_graphql_resolve bool;
BEGIN
    func_is_graphql_resolve = (
        SELECT n.proname = 'resolve'
        FROM pg_event_trigger_ddl_commands() AS ev
        LEFT JOIN pg_catalog.pg_proc AS n
        ON ev.objid = n.oid
    );

    IF func_is_graphql_resolve
    THEN
        -- Update public wrapper to pass all arguments through to the pg_graphql resolve func
        DROP FUNCTION IF EXISTS graphql_public.graphql;
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language sql
        as $$
            select graphql.resolve(
                query := query,
                variables := coalesce(variables, '{}'),
                "operationName" := "operationName",
                extensions := extensions
            );
        $$;

        -- This hook executes when `graphql.resolve` is created. That is not necessarily the last
        -- function in the extension so we need to grant permissions on existing entities AND
        -- update default permissions to any others that are created after `graphql.resolve`
        grant usage on schema graphql to postgres, anon, authenticated, service_role;
        grant select on all tables in schema graphql to postgres, anon, authenticated, service_role;
        grant execute on all functions in schema graphql to postgres, anon, authenticated, service_role;
        grant all on all sequences in schema graphql to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on tables to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on functions to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on sequences to postgres, anon, authenticated, service_role;

        -- Allow postgres role to allow granting usage on graphql and graphql_public schemas to custom roles
        grant usage on schema graphql_public to postgres with grant option;
        grant usage on schema graphql to postgres with grant option;
    END IF;

END;
$_$;


--
-- Name: FUNCTION grant_pg_graphql_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_graphql_access() IS 'Grants access to pg_graphql';


--
-- Name: grant_pg_net_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_net_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_net'
  )
  THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_roles
      WHERE rolname = 'supabase_functions_admin'
    )
    THEN
      CREATE USER supabase_functions_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
    END IF;

    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    IF EXISTS (
      SELECT FROM pg_extension
      WHERE extname = 'pg_net'
      -- all versions in use on existing projects as of 2025-02-20
      -- version 0.12.0 onwards don't need these applied
      AND extversion IN ('0.2', '0.6', '0.7', '0.7.1', '0.8', '0.10.0', '0.11.0')
    ) THEN
      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

      REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
      REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

      GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
      GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    END IF;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_net_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_net_access() IS 'Grants access to pg_net';


--
-- Name: pgrst_ddl_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_ddl_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    IF cmd.command_tag IN (
      'CREATE SCHEMA', 'ALTER SCHEMA'
    , 'CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE'
    , 'CREATE FOREIGN TABLE', 'ALTER FOREIGN TABLE'
    , 'CREATE VIEW', 'ALTER VIEW'
    , 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW'
    , 'CREATE FUNCTION', 'ALTER FUNCTION'
    , 'CREATE TRIGGER'
    , 'CREATE TYPE', 'ALTER TYPE'
    , 'CREATE RULE'
    , 'COMMENT'
    )
    -- don't notify in case of CREATE TEMP table or other objects created on pg_temp
    AND cmd.schema_name is distinct from 'pg_temp'
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: pgrst_drop_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_drop_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  obj record;
BEGIN
  FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
  LOOP
    IF obj.object_type IN (
      'schema'
    , 'table'
    , 'foreign table'
    , 'view'
    , 'materialized view'
    , 'function'
    , 'trigger'
    , 'type'
    , 'rule'
    )
    AND obj.is_temporary IS false -- no pg_temp objects
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: set_graphql_placeholder(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.set_graphql_placeholder() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
    DECLARE
    graphql_is_dropped bool;
    BEGIN
    graphql_is_dropped = (
        SELECT ev.schema_name = 'graphql_public'
        FROM pg_event_trigger_dropped_objects() AS ev
        WHERE ev.schema_name = 'graphql_public'
    );

    IF graphql_is_dropped
    THEN
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language plpgsql
        as $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;
    END IF;

    END;
$_$;


--
-- Name: FUNCTION set_graphql_placeholder(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.set_graphql_placeholder() IS 'Reintroduces placeholder function for graphql_public.graphql';


--
-- Name: get_auth(text); Type: FUNCTION; Schema: pgbouncer; Owner: -
--

CREATE FUNCTION pgbouncer.get_auth(p_usename text) RETURNS TABLE(username text, password text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
  BEGIN
      RAISE DEBUG 'PgBouncer auth request: %', p_usename;

      RETURN QUERY
      SELECT
          rolname::text,
          CASE WHEN rolvaliduntil < now()
              THEN null
              ELSE rolpassword::text
          END
      FROM pg_authid
      WHERE rolname=$1 and rolcanlogin;
  END;
  $_$;


--
-- Name: apply_rls(jsonb, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer DEFAULT (1024 * 1024)) RETURNS SETOF realtime.wal_rls
    LANGUAGE plpgsql
    AS $$
declare
-- Regclass of the table e.g. public.notes
entity_ regclass = (quote_ident(wal ->> 'schema') || '.' || quote_ident(wal ->> 'table'))::regclass;

-- I, U, D, T: insert, update ...
action realtime.action = (
    case wal ->> 'action'
        when 'I' then 'INSERT'
        when 'U' then 'UPDATE'
        when 'D' then 'DELETE'
        else 'ERROR'
    end
);

-- Is row level security enabled for the table
is_rls_enabled bool = relrowsecurity from pg_class where oid = entity_;

subscriptions realtime.subscription[] = array_agg(subs)
    from
        realtime.subscription subs
    where
        subs.entity = entity_
        -- Filter by action early - only get subscriptions interested in this action
        -- action_filter column can be: '*' (all), 'INSERT', 'UPDATE', or 'DELETE'
        and (subs.action_filter = '*' or subs.action_filter = action::text);

-- Subscription vars
roles regrole[] = array_agg(distinct us.claims_role::text)
    from
        unnest(subscriptions) us;

working_role regrole;
claimed_role regrole;
claims jsonb;

subscription_id uuid;
subscription_has_access bool;
visible_to_subscription_ids uuid[] = '{}';

-- structured info for wal's columns
columns realtime.wal_column[];
-- previous identity values for update/delete
old_columns realtime.wal_column[];

error_record_exceeds_max_size boolean = octet_length(wal::text) > max_record_bytes;

-- Primary jsonb output for record
output jsonb;

begin
perform set_config('role', null, true);

columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'columns') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

old_columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'identity') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

for working_role in select * from unnest(roles) loop

    -- Update `is_selectable` for columns and old_columns
    columns =
        array_agg(
            (
                c.name,
                c.type_name,
                c.type_oid,
                c.value,
                c.is_pkey,
                pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
            )::realtime.wal_column
        )
        from
            unnest(columns) c;

    old_columns =
            array_agg(
                (
                    c.name,
                    c.type_name,
                    c.type_oid,
                    c.value,
                    c.is_pkey,
                    pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                )::realtime.wal_column
            )
            from
                unnest(old_columns) c;

    if action <> 'DELETE' and count(1) = 0 from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            -- subscriptions is already filtered by entity
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 400: Bad Request, no primary key']
        )::realtime.wal_rls;

    -- The claims role does not have SELECT permission to the primary key of entity
    elsif action <> 'DELETE' and sum(c.is_selectable::int) <> count(1) from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 401: Unauthorized']
        )::realtime.wal_rls;

    else
        output = jsonb_build_object(
            'schema', wal ->> 'schema',
            'table', wal ->> 'table',
            'type', action,
            'commit_timestamp', to_char(
                ((wal ->> 'timestamp')::timestamptz at time zone 'utc'),
                'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
            ),
            'columns', (
                select
                    jsonb_agg(
                        jsonb_build_object(
                            'name', pa.attname,
                            'type', pt.typname
                        )
                        order by pa.attnum asc
                    )
                from
                    pg_attribute pa
                    join pg_type pt
                        on pa.atttypid = pt.oid
                where
                    attrelid = entity_
                    and attnum > 0
                    and pg_catalog.has_column_privilege(working_role, entity_, pa.attname, 'SELECT')
            )
        )
        -- Add "record" key for insert and update
        || case
            when action in ('INSERT', 'UPDATE') then
                jsonb_build_object(
                    'record',
                    (
                        select
                            jsonb_object_agg(
                                -- if unchanged toast, get column name and value from old record
                                coalesce((c).name, (oc).name),
                                case
                                    when (c).name is null then (oc).value
                                    else (c).value
                                end
                            )
                        from
                            unnest(columns) c
                            full outer join unnest(old_columns) oc
                                on (c).name = (oc).name
                        where
                            coalesce((c).is_selectable, (oc).is_selectable)
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                    )
                )
            else '{}'::jsonb
        end
        -- Add "old_record" key for update and delete
        || case
            when action = 'UPDATE' then
                jsonb_build_object(
                        'old_record',
                        (
                            select jsonb_object_agg((c).name, (c).value)
                            from unnest(old_columns) c
                            where
                                (c).is_selectable
                                and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                        )
                    )
            when action = 'DELETE' then
                jsonb_build_object(
                    'old_record',
                    (
                        select jsonb_object_agg((c).name, (c).value)
                        from unnest(old_columns) c
                        where
                            (c).is_selectable
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                            and ( not is_rls_enabled or (c).is_pkey ) -- if RLS enabled, we can't secure deletes so filter to pkey
                    )
                )
            else '{}'::jsonb
        end;

        -- Create the prepared statement
        if is_rls_enabled and action <> 'DELETE' then
            if (select 1 from pg_prepared_statements where name = 'walrus_rls_stmt' limit 1) > 0 then
                deallocate walrus_rls_stmt;
            end if;
            execute realtime.build_prepared_statement_sql('walrus_rls_stmt', entity_, columns);
        end if;

        visible_to_subscription_ids = '{}';

        for subscription_id, claims in (
                select
                    subs.subscription_id,
                    subs.claims
                from
                    unnest(subscriptions) subs
                where
                    subs.entity = entity_
                    and subs.claims_role = working_role
                    and (
                        realtime.is_visible_through_filters(columns, subs.filters)
                        or (
                          action = 'DELETE'
                          and realtime.is_visible_through_filters(old_columns, subs.filters)
                        )
                    )
        ) loop

            if not is_rls_enabled or action = 'DELETE' then
                visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
            else
                -- Check if RLS allows the role to see the record
                perform
                    -- Trim leading and trailing quotes from working_role because set_config
                    -- doesn't recognize the role as valid if they are included
                    set_config('role', trim(both '"' from working_role::text), true),
                    set_config('request.jwt.claims', claims::text, true);

                execute 'execute walrus_rls_stmt' into subscription_has_access;

                if subscription_has_access then
                    visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
                end if;
            end if;
        end loop;

        perform set_config('role', null, true);

        return next (
            output,
            is_rls_enabled,
            visible_to_subscription_ids,
            case
                when error_record_exceeds_max_size then array['Error 413: Payload Too Large']
                else '{}'
            end
        )::realtime.wal_rls;

    end if;
end loop;

perform set_config('role', null, true);
end;
$$;


--
-- Name: broadcast_changes(text, text, text, text, text, record, record, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.broadcast_changes(topic_name text, event_name text, operation text, table_name text, table_schema text, new record, old record, level text DEFAULT 'ROW'::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Declare a variable to hold the JSONB representation of the row
    row_data jsonb := '{}'::jsonb;
BEGIN
    IF level = 'STATEMENT' THEN
        RAISE EXCEPTION 'function can only be triggered for each row, not for each statement';
    END IF;
    -- Check the operation type and handle accordingly
    IF operation = 'INSERT' OR operation = 'UPDATE' OR operation = 'DELETE' THEN
        row_data := jsonb_build_object('old_record', OLD, 'record', NEW, 'operation', operation, 'table', table_name, 'schema', table_schema);
        PERFORM realtime.send (row_data, event_name, topic_name);
    ELSE
        RAISE EXCEPTION 'Unexpected operation type: %', operation;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to process the row: %', SQLERRM;
END;

$$;


--
-- Name: build_prepared_statement_sql(text, regclass, realtime.wal_column[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]) RETURNS text
    LANGUAGE sql
    AS $$
      /*
      Builds a sql string that, if executed, creates a prepared statement to
      tests retrive a row from *entity* by its primary key columns.
      Example
          select realtime.build_prepared_statement_sql('public.notes', '{"id"}'::text[], '{"bigint"}'::text[])
      */
          select
      'prepare ' || prepared_statement_name || ' as
          select
              exists(
                  select
                      1
                  from
                      ' || entity || '
                  where
                      ' || string_agg(quote_ident(pkc.name) || '=' || quote_nullable(pkc.value #>> '{}') , ' and ') || '
              )'
          from
              unnest(columns) pkc
          where
              pkc.is_pkey
          group by
              entity
      $$;


--
-- Name: cast(text, regtype); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime."cast"(val text, type_ regtype) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
  res jsonb;
begin
  if type_::text = 'bytea' then
    return to_jsonb(val);
  end if;
  execute format('select to_jsonb(%L::'|| type_::text || ')', val) into res;
  return res;
end
$$;


--
-- Name: check_equality_op(realtime.equality_op, regtype, text, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
      /*
      Casts *val_1* and *val_2* as type *type_* and check the *op* condition for truthiness
      */
      declare
          op_symbol text = (
              case
                  when op = 'eq' then '='
                  when op = 'neq' then '!='
                  when op = 'lt' then '<'
                  when op = 'lte' then '<='
                  when op = 'gt' then '>'
                  when op = 'gte' then '>='
                  when op = 'in' then '= any'
                  else 'UNKNOWN OP'
              end
          );
          res boolean;
      begin
          execute format(
              'select %L::'|| type_::text || ' ' || op_symbol
              || ' ( %L::'
              || (
                  case
                      when op = 'in' then type_::text || '[]'
                      else type_::text end
              )
              || ')', val_1, val_2) into res;
          return res;
      end;
      $$;


--
-- Name: is_visible_through_filters(realtime.wal_column[], realtime.user_defined_filter[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
    /*
    Should the record be visible (true) or filtered out (false) after *filters* are applied
    */
        select
            -- Default to allowed when no filters present
            $2 is null -- no filters. this should not happen because subscriptions has a default
            or array_length($2, 1) is null -- array length of an empty array is null
            or bool_and(
                coalesce(
                    realtime.check_equality_op(
                        op:=f.op,
                        type_:=coalesce(
                            col.type_oid::regtype, -- null when wal2json version <= 2.4
                            col.type_name::regtype
                        ),
                        -- cast jsonb to text
                        val_1:=col.value #>> '{}',
                        val_2:=f.value
                    ),
                    false -- if null, filter does not match
                )
            )
        from
            unnest(filters) f
            join unnest(columns) col
                on f.column_name = col.name;
    $_$;


--
-- Name: list_changes(name, name, integer, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.list_changes(publication name, slot_name name, max_changes integer, max_record_bytes integer) RETURNS SETOF realtime.wal_rls
    LANGUAGE sql
    SET log_min_messages TO 'fatal'
    AS $$
      with pub as (
        select
          concat_ws(
            ',',
            case when bool_or(pubinsert) then 'insert' else null end,
            case when bool_or(pubupdate) then 'update' else null end,
            case when bool_or(pubdelete) then 'delete' else null end
          ) as w2j_actions,
          coalesce(
            string_agg(
              realtime.quote_wal2json(format('%I.%I', schemaname, tablename)::regclass),
              ','
            ) filter (where ppt.tablename is not null and ppt.tablename not like '% %'),
            ''
          ) w2j_add_tables
        from
          pg_publication pp
          left join pg_publication_tables ppt
            on pp.pubname = ppt.pubname
        where
          pp.pubname = publication
        group by
          pp.pubname
        limit 1
      ),
      w2j as (
        select
          x.*, pub.w2j_add_tables
        from
          pub,
          pg_logical_slot_get_changes(
            slot_name, null, max_changes,
            'include-pk', 'true',
            'include-transaction', 'false',
            'include-timestamp', 'true',
            'include-type-oids', 'true',
            'format-version', '2',
            'actions', pub.w2j_actions,
            'add-tables', pub.w2j_add_tables
          ) x
      )
      select
        xyz.wal,
        xyz.is_rls_enabled,
        xyz.subscription_ids,
        xyz.errors
      from
        w2j,
        realtime.apply_rls(
          wal := w2j.data::jsonb,
          max_record_bytes := max_record_bytes
        ) xyz(wal, is_rls_enabled, subscription_ids, errors)
      where
        w2j.w2j_add_tables <> ''
        and xyz.subscription_ids[1] is not null
    $$;


--
-- Name: quote_wal2json(regclass); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.quote_wal2json(entity regclass) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
      select
        (
          select string_agg('' || ch,'')
          from unnest(string_to_array(nsp.nspname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
        )
        || '.'
        || (
          select string_agg('' || ch,'')
          from unnest(string_to_array(pc.relname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
          )
      from
        pg_class pc
        join pg_namespace nsp
          on pc.relnamespace = nsp.oid
      where
        pc.oid = entity
    $$;


--
-- Name: send(jsonb, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.send(payload jsonb, event text, topic text, private boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  generated_id uuid;
  final_payload jsonb;
BEGIN
  BEGIN
    -- Generate a new UUID for the id
    generated_id := gen_random_uuid();

    -- Check if payload has an 'id' key, if not, add the generated UUID
    IF payload ? 'id' THEN
      final_payload := payload;
    ELSE
      final_payload := jsonb_set(payload, '{id}', to_jsonb(generated_id));
    END IF;

    -- Set the topic configuration
    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    -- Attempt to insert the message
    INSERT INTO realtime.messages (id, payload, event, topic, private, extension)
    VALUES (generated_id, final_payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      -- Capture and notify the error
      RAISE WARNING 'ErrorSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$$;


--
-- Name: subscription_check_filters(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.subscription_check_filters() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    /*
    Validates that the user defined filters for a subscription:
    - refer to valid columns that the claimed role may access
    - values are coercable to the correct column type
    */
    declare
        col_names text[] = coalesce(
                array_agg(c.column_name order by c.ordinal_position),
                '{}'::text[]
            )
            from
                information_schema.columns c
            where
                format('%I.%I', c.table_schema, c.table_name)::regclass = new.entity
                and pg_catalog.has_column_privilege(
                    (new.claims ->> 'role'),
                    format('%I.%I', c.table_schema, c.table_name)::regclass,
                    c.column_name,
                    'SELECT'
                );
        filter realtime.user_defined_filter;
        col_type regtype;

        in_val jsonb;
    begin
        for filter in select * from unnest(new.filters) loop
            -- Filtered column is valid
            if not filter.column_name = any(col_names) then
                raise exception 'invalid column for filter %', filter.column_name;
            end if;

            -- Type is sanitized and safe for string interpolation
            col_type = (
                select atttypid::regtype
                from pg_catalog.pg_attribute
                where attrelid = new.entity
                      and attname = filter.column_name
            );
            if col_type is null then
                raise exception 'failed to lookup type for column %', filter.column_name;
            end if;

            -- Set maximum number of entries for in filter
            if filter.op = 'in'::realtime.equality_op then
                in_val = realtime.cast(filter.value, (col_type::text || '[]')::regtype);
                if coalesce(jsonb_array_length(in_val), 0) > 100 then
                    raise exception 'too many values for `in` filter. Maximum 100';
                end if;
            else
                -- raises an exception if value is not coercable to type
                perform realtime.cast(filter.value, col_type);
            end if;

        end loop;

        -- Apply consistent order to filters so the unique constraint on
        -- (subscription_id, entity, filters) can't be tricked by a different filter order
        new.filters = coalesce(
            array_agg(f order by f.column_name, f.op, f.value),
            '{}'
        ) from unnest(new.filters) f;

        return new;
    end;
    $$;


--
-- Name: to_regrole(text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.to_regrole(role_name text) RETURNS regrole
    LANGUAGE sql IMMUTABLE
    AS $$ select role_name::regrole $$;


--
-- Name: topic(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.topic() RETURNS text
    LANGUAGE sql STABLE
    AS $$
select nullif(current_setting('realtime.topic', true), '')::text;
$$;


--
-- Name: allow_any_operation(text[]); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.allow_any_operation(expected_operations text[]) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  WITH current_operation AS (
    SELECT storage.operation() AS raw_operation
  ),
  normalized AS (
    SELECT CASE
      WHEN raw_operation LIKE 'storage.%' THEN substr(raw_operation, 9)
      ELSE raw_operation
    END AS current_operation
    FROM current_operation
  )
  SELECT EXISTS (
    SELECT 1
    FROM normalized n
    CROSS JOIN LATERAL unnest(expected_operations) AS expected_operation
    WHERE expected_operation IS NOT NULL
      AND expected_operation <> ''
      AND n.current_operation = CASE
        WHEN expected_operation LIKE 'storage.%' THEN substr(expected_operation, 9)
        ELSE expected_operation
      END
  );
$$;


--
-- Name: allow_only_operation(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.allow_only_operation(expected_operation text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  WITH current_operation AS (
    SELECT storage.operation() AS raw_operation
  ),
  normalized AS (
    SELECT
      CASE
        WHEN raw_operation LIKE 'storage.%' THEN substr(raw_operation, 9)
        ELSE raw_operation
      END AS current_operation,
      CASE
        WHEN expected_operation LIKE 'storage.%' THEN substr(expected_operation, 9)
        ELSE expected_operation
      END AS requested_operation
    FROM current_operation
  )
  SELECT CASE
    WHEN requested_operation IS NULL OR requested_operation = '' THEN FALSE
    ELSE COALESCE(current_operation = requested_operation, FALSE)
  END
  FROM normalized;
$$;


--
-- Name: can_insert_object(text, text, uuid, jsonb); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$$;


--
-- Name: enforce_bucket_name_length(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.enforce_bucket_name_length() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$$;


--
-- Name: extension(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.extension(name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
_parts text[];
_filename text;
BEGIN
	select string_to_array(name, '/') into _parts;
	select _parts[array_length(_parts,1)] into _filename;
	-- @todo return the last part instead of 2
	return reverse(split_part(reverse(_filename), '.', 1));
END
$$;


--
-- Name: filename(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.filename(name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[array_length(_parts,1)];
END
$$;


--
-- Name: foldername(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.foldername(name text) RETURNS text[]
    LANGUAGE plpgsql
    AS $$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[1:array_length(_parts,1)-1];
END
$$;


--
-- Name: get_common_prefix(text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_common_prefix(p_key text, p_prefix text, p_delimiter text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT CASE
    WHEN position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)) > 0
    THEN left(p_key, length(p_prefix) + position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)))
    ELSE NULL
END;
$$;


--
-- Name: get_size_by_bucket(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_size_by_bucket() RETURNS TABLE(size bigint, bucket_id text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    return query
        select sum((metadata->>'size')::int) as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$$;


--
-- Name: list_multipart_uploads_with_delimiter(text, text, text, integer, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_multipart_uploads_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, next_key_token text DEFAULT ''::text, next_upload_token text DEFAULT ''::text) RETURNS TABLE(key text, id text, created_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$_$;


--
-- Name: list_objects_with_delimiter(text, text, text, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_objects_with_delimiter(_bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, start_after text DEFAULT ''::text, next_token text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, metadata jsonb, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;

    -- Configuration
    v_is_asc BOOLEAN;
    v_prefix TEXT;
    v_start TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_is_asc := lower(coalesce(sort_order, 'asc')) = 'asc';
    v_prefix := coalesce(prefix_param, '');
    v_start := CASE WHEN coalesce(next_token, '') <> '' THEN next_token ELSE coalesce(start_after, '') END;
    v_file_batch_size := LEAST(GREATEST(max_keys * 2, 100), 1000);

    -- Calculate upper bound for prefix filtering (bytewise, using COLLATE "C")
    IF v_prefix = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix, 1) = delimiter_param THEN
        v_upper_bound := left(v_prefix, -1) || chr(ascii(delimiter_param) + 1);
    ELSE
        v_upper_bound := left(v_prefix, -1) || chr(ascii(right(v_prefix, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'AND o.name COLLATE "C" < $3 ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'AND o.name COLLATE "C" >= $3 ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- ========================================================================
    -- SEEK INITIALIZATION: Determine starting position
    -- ========================================================================
    IF v_start = '' THEN
        IF v_is_asc THEN
            v_next_seek := v_prefix;
        ELSE
            -- DESC without cursor: find the last item in range
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;

            IF v_next_seek IS NOT NULL THEN
                v_next_seek := v_next_seek || delimiter_param;
            ELSE
                RETURN;
            END IF;
        END IF;
    ELSE
        -- Cursor provided: determine if it refers to a folder or leaf
        IF EXISTS (
            SELECT 1 FROM storage.objects o
            WHERE o.bucket_id = _bucket_id
              AND o.name COLLATE "C" LIKE v_start || delimiter_param || '%'
            LIMIT 1
        ) THEN
            -- Cursor refers to a folder
            IF v_is_asc THEN
                v_next_seek := v_start || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_start || delimiter_param;
            END IF;
        ELSE
            -- Cursor refers to a leaf object
            IF v_is_asc THEN
                v_next_seek := v_start || delimiter_param;
            ELSE
                v_next_seek := v_start;
            END IF;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= max_keys;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(v_peek_name, v_prefix, delimiter_param);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Emit and skip to next folder (no heap access needed)
            name := rtrim(v_common_prefix, delimiter_param);
            id := NULL;
            updated_at := NULL;
            created_at := NULL;
            last_accessed_at := NULL;
            metadata := NULL;
            RETURN NEXT;
            v_count := v_count + 1;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := left(v_common_prefix, -1) || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_common_prefix;
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query USING _bucket_id, v_next_seek,
                CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix) ELSE v_prefix END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(v_current.name, v_prefix, delimiter_param);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := v_current.name;
                    EXIT;
                END IF;

                -- Emit file
                name := v_current.name;
                id := v_current.id;
                updated_at := v_current.updated_at;
                created_at := v_current.created_at;
                last_accessed_at := v_current.last_accessed_at;
                metadata := v_current.metadata;
                RETURN NEXT;
                v_count := v_count + 1;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := v_current.name || delimiter_param;
                ELSE
                    v_next_seek := v_current.name;
                END IF;

                EXIT WHEN v_count >= max_keys;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


--
-- Name: operation(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.operation() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$$;


--
-- Name: protect_delete(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.protect_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if storage.allow_delete_query is set to 'true'
    IF COALESCE(current_setting('storage.allow_delete_query', true), 'false') != 'true' THEN
        RAISE EXCEPTION 'Direct deletion from storage tables is not allowed. Use the Storage API instead.'
            USING HINT = 'This prevents accidental data loss from orphaned objects.',
                  ERRCODE = '42501';
    END IF;
    RETURN NULL;
END;
$$;


--
-- Name: search(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;
    v_delimiter CONSTANT TEXT := '/';

    -- Configuration
    v_limit INT;
    v_prefix TEXT;
    v_prefix_lower TEXT;
    v_is_asc BOOLEAN;
    v_order_by TEXT;
    v_sort_order TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;
    v_skipped INT := 0;
BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_limit := LEAST(coalesce(limits, 100), 1500);
    v_prefix := coalesce(prefix, '') || coalesce(search, '');
    v_prefix_lower := lower(v_prefix);
    v_is_asc := lower(coalesce(sortorder, 'asc')) = 'asc';
    v_file_batch_size := LEAST(GREATEST(v_limit * 2, 100), 1000);

    -- Validate sort column
    CASE lower(coalesce(sortcolumn, 'name'))
        WHEN 'name' THEN v_order_by := 'name';
        WHEN 'updated_at' THEN v_order_by := 'updated_at';
        WHEN 'created_at' THEN v_order_by := 'created_at';
        WHEN 'last_accessed_at' THEN v_order_by := 'last_accessed_at';
        ELSE v_order_by := 'name';
    END CASE;

    v_sort_order := CASE WHEN v_is_asc THEN 'asc' ELSE 'desc' END;

    -- ========================================================================
    -- NON-NAME SORTING: Use path_tokens approach (unchanged)
    -- ========================================================================
    IF v_order_by != 'name' THEN
        RETURN QUERY EXECUTE format(
            $sql$
            WITH folders AS (
                SELECT path_tokens[$1] AS folder
                FROM storage.objects
                WHERE objects.name ILIKE $2 || '%%'
                  AND bucket_id = $3
                  AND array_length(objects.path_tokens, 1) <> $1
                GROUP BY folder
                ORDER BY folder %s
            )
            (SELECT folder AS "name",
                   NULL::uuid AS id,
                   NULL::timestamptz AS updated_at,
                   NULL::timestamptz AS created_at,
                   NULL::timestamptz AS last_accessed_at,
                   NULL::jsonb AS metadata FROM folders)
            UNION ALL
            (SELECT path_tokens[$1] AS "name",
                   id, updated_at, created_at, last_accessed_at, metadata
             FROM storage.objects
             WHERE objects.name ILIKE $2 || '%%'
               AND bucket_id = $3
               AND array_length(objects.path_tokens, 1) = $1
             ORDER BY %I %s)
            LIMIT $4 OFFSET $5
            $sql$, v_sort_order, v_order_by, v_sort_order
        ) USING levels, v_prefix, bucketname, v_limit, offsets;
        RETURN;
    END IF;

    -- ========================================================================
    -- NAME SORTING: Hybrid skip-scan with batch optimization
    -- ========================================================================

    -- Calculate upper bound for prefix filtering
    IF v_prefix_lower = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix_lower, 1) = v_delimiter THEN
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(v_delimiter) + 1);
    ELSE
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(right(v_prefix_lower, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'AND lower(o.name) COLLATE "C" < $3 ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'AND lower(o.name) COLLATE "C" >= $3 ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- Initialize seek position
    IF v_is_asc THEN
        v_next_seek := v_prefix_lower;
    ELSE
        -- DESC: find the last item in range first (static SQL)
        IF v_upper_bound IS NOT NULL THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower AND lower(o.name) COLLATE "C" < v_upper_bound
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSIF v_prefix_lower <> '' THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSE
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        END IF;

        IF v_peek_name IS NOT NULL THEN
            v_next_seek := lower(v_peek_name) || v_delimiter;
        ELSE
            RETURN;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= v_limit;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek AND lower(o.name) COLLATE "C" < v_upper_bound
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix_lower <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(lower(v_peek_name), v_prefix_lower, v_delimiter);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Handle offset, emit if needed, skip to next folder
            IF v_skipped < offsets THEN
                v_skipped := v_skipped + 1;
            ELSE
                name := split_part(rtrim(storage.get_common_prefix(v_peek_name, v_prefix, v_delimiter), v_delimiter), v_delimiter, levels);
                id := NULL;
                updated_at := NULL;
                created_at := NULL;
                last_accessed_at := NULL;
                metadata := NULL;
                RETURN NEXT;
                v_count := v_count + 1;
            END IF;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := lower(left(v_common_prefix, -1)) || chr(ascii(v_delimiter) + 1);
            ELSE
                v_next_seek := lower(v_common_prefix);
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix_lower is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query
                USING bucketname, v_next_seek,
                    CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix_lower) ELSE v_prefix_lower END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(lower(v_current.name), v_prefix_lower, v_delimiter);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := lower(v_current.name);
                    EXIT;
                END IF;

                -- Handle offset skipping
                IF v_skipped < offsets THEN
                    v_skipped := v_skipped + 1;
                ELSE
                    -- Emit file
                    name := split_part(v_current.name, v_delimiter, levels);
                    id := v_current.id;
                    updated_at := v_current.updated_at;
                    created_at := v_current.created_at;
                    last_accessed_at := v_current.last_accessed_at;
                    metadata := v_current.metadata;
                    RETURN NEXT;
                    v_count := v_count + 1;
                END IF;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := lower(v_current.name) || v_delimiter;
                ELSE
                    v_next_seek := lower(v_current.name);
                END IF;

                EXIT WHEN v_count >= v_limit;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


--
-- Name: search_by_timestamp(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_by_timestamp(p_prefix text, p_bucket_id text, p_limit integer, p_level integer, p_start_after text, p_sort_order text, p_sort_column text, p_sort_column_after text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_cursor_op text;
    v_query text;
    v_prefix text;
BEGIN
    v_prefix := coalesce(p_prefix, '');

    IF p_sort_order = 'asc' THEN
        v_cursor_op := '>';
    ELSE
        v_cursor_op := '<';
    END IF;

    v_query := format($sql$
        WITH raw_objects AS (
            SELECT
                o.name AS obj_name,
                o.id AS obj_id,
                o.updated_at AS obj_updated_at,
                o.created_at AS obj_created_at,
                o.last_accessed_at AS obj_last_accessed_at,
                o.metadata AS obj_metadata,
                storage.get_common_prefix(o.name, $1, '/') AS common_prefix
            FROM storage.objects o
            WHERE o.bucket_id = $2
              AND o.name COLLATE "C" LIKE $1 || '%%'
        ),
        -- Aggregate common prefixes (folders)
        -- Both created_at and updated_at use MIN(obj_created_at) to match the old prefixes table behavior
        aggregated_prefixes AS (
            SELECT
                rtrim(common_prefix, '/') AS name,
                NULL::uuid AS id,
                MIN(obj_created_at) AS updated_at,
                MIN(obj_created_at) AS created_at,
                NULL::timestamptz AS last_accessed_at,
                NULL::jsonb AS metadata,
                TRUE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NOT NULL
            GROUP BY common_prefix
        ),
        leaf_objects AS (
            SELECT
                obj_name AS name,
                obj_id AS id,
                obj_updated_at AS updated_at,
                obj_created_at AS created_at,
                obj_last_accessed_at AS last_accessed_at,
                obj_metadata AS metadata,
                FALSE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NULL
        ),
        combined AS (
            SELECT * FROM aggregated_prefixes
            UNION ALL
            SELECT * FROM leaf_objects
        ),
        filtered AS (
            SELECT *
            FROM combined
            WHERE (
                $5 = ''
                OR ROW(
                    date_trunc('milliseconds', %I),
                    name COLLATE "C"
                ) %s ROW(
                    COALESCE(NULLIF($6, '')::timestamptz, 'epoch'::timestamptz),
                    $5
                )
            )
        )
        SELECT
            split_part(name, '/', $3) AS key,
            name,
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
        FROM filtered
        ORDER BY
            COALESCE(date_trunc('milliseconds', %I), 'epoch'::timestamptz) %s,
            name COLLATE "C" %s
        LIMIT $4
    $sql$,
        p_sort_column,
        v_cursor_op,
        p_sort_column,
        p_sort_order,
        p_sort_order
    );

    RETURN QUERY EXECUTE v_query
    USING v_prefix, p_bucket_id, p_level, p_limit, p_start_after, p_sort_column_after;
END;
$_$;


--
-- Name: search_v2(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_v2(prefix text, bucket_name text, limits integer DEFAULT 100, levels integer DEFAULT 1, start_after text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text, sort_column text DEFAULT 'name'::text, sort_column_after text DEFAULT ''::text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_sort_col text;
    v_sort_ord text;
    v_limit int;
BEGIN
    -- Cap limit to maximum of 1500 records
    v_limit := LEAST(coalesce(limits, 100), 1500);

    -- Validate and normalize sort_order
    v_sort_ord := lower(coalesce(sort_order, 'asc'));
    IF v_sort_ord NOT IN ('asc', 'desc') THEN
        v_sort_ord := 'asc';
    END IF;

    -- Validate and normalize sort_column
    v_sort_col := lower(coalesce(sort_column, 'name'));
    IF v_sort_col NOT IN ('name', 'updated_at', 'created_at') THEN
        v_sort_col := 'name';
    END IF;

    -- Route to appropriate implementation
    IF v_sort_col = 'name' THEN
        -- Use list_objects_with_delimiter for name sorting (most efficient: O(k * log n))
        RETURN QUERY
        SELECT
            split_part(l.name, '/', levels) AS key,
            l.name AS name,
            l.id,
            l.updated_at,
            l.created_at,
            l.last_accessed_at,
            l.metadata
        FROM storage.list_objects_with_delimiter(
            bucket_name,
            coalesce(prefix, ''),
            '/',
            v_limit,
            start_after,
            '',
            v_sort_ord
        ) l;
    ELSE
        -- Use aggregation approach for timestamp sorting
        -- Not efficient for large datasets but supports correct pagination
        RETURN QUERY SELECT * FROM storage.search_by_timestamp(
            prefix, bucket_name, v_limit, levels, start_after,
            v_sort_ord, v_sort_col, sort_column_after
        );
    END IF;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log_entries; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.audit_log_entries (
    instance_id uuid,
    id uuid NOT NULL,
    payload json,
    created_at timestamp with time zone,
    ip_address character varying(64) DEFAULT ''::character varying NOT NULL
);


--
-- Name: TABLE audit_log_entries; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.audit_log_entries IS 'Auth: Audit trail for user actions.';


--
-- Name: custom_oauth_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.custom_oauth_providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_type text NOT NULL,
    identifier text NOT NULL,
    name text NOT NULL,
    client_id text NOT NULL,
    client_secret text NOT NULL,
    acceptable_client_ids text[] DEFAULT '{}'::text[] NOT NULL,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    pkce_enabled boolean DEFAULT true NOT NULL,
    attribute_mapping jsonb DEFAULT '{}'::jsonb NOT NULL,
    authorization_params jsonb DEFAULT '{}'::jsonb NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    email_optional boolean DEFAULT false NOT NULL,
    issuer text,
    discovery_url text,
    skip_nonce_check boolean DEFAULT false NOT NULL,
    cached_discovery jsonb,
    discovery_cached_at timestamp with time zone,
    authorization_url text,
    token_url text,
    userinfo_url text,
    jwks_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT custom_oauth_providers_authorization_url_https CHECK (((authorization_url IS NULL) OR (authorization_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_authorization_url_length CHECK (((authorization_url IS NULL) OR (char_length(authorization_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_client_id_length CHECK (((char_length(client_id) >= 1) AND (char_length(client_id) <= 512))),
    CONSTRAINT custom_oauth_providers_discovery_url_length CHECK (((discovery_url IS NULL) OR (char_length(discovery_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_identifier_format CHECK ((identifier ~ '^[a-z0-9][a-z0-9:-]{0,48}[a-z0-9]$'::text)),
    CONSTRAINT custom_oauth_providers_issuer_length CHECK (((issuer IS NULL) OR ((char_length(issuer) >= 1) AND (char_length(issuer) <= 2048)))),
    CONSTRAINT custom_oauth_providers_jwks_uri_https CHECK (((jwks_uri IS NULL) OR (jwks_uri ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_jwks_uri_length CHECK (((jwks_uri IS NULL) OR (char_length(jwks_uri) <= 2048))),
    CONSTRAINT custom_oauth_providers_name_length CHECK (((char_length(name) >= 1) AND (char_length(name) <= 100))),
    CONSTRAINT custom_oauth_providers_oauth2_requires_endpoints CHECK (((provider_type <> 'oauth2'::text) OR ((authorization_url IS NOT NULL) AND (token_url IS NOT NULL) AND (userinfo_url IS NOT NULL)))),
    CONSTRAINT custom_oauth_providers_oidc_discovery_url_https CHECK (((provider_type <> 'oidc'::text) OR (discovery_url IS NULL) OR (discovery_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_oidc_issuer_https CHECK (((provider_type <> 'oidc'::text) OR (issuer IS NULL) OR (issuer ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_oidc_requires_issuer CHECK (((provider_type <> 'oidc'::text) OR (issuer IS NOT NULL))),
    CONSTRAINT custom_oauth_providers_provider_type_check CHECK ((provider_type = ANY (ARRAY['oauth2'::text, 'oidc'::text]))),
    CONSTRAINT custom_oauth_providers_token_url_https CHECK (((token_url IS NULL) OR (token_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_token_url_length CHECK (((token_url IS NULL) OR (char_length(token_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_userinfo_url_https CHECK (((userinfo_url IS NULL) OR (userinfo_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_userinfo_url_length CHECK (((userinfo_url IS NULL) OR (char_length(userinfo_url) <= 2048)))
);


--
-- Name: flow_state; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.flow_state (
    id uuid NOT NULL,
    user_id uuid,
    auth_code text,
    code_challenge_method auth.code_challenge_method,
    code_challenge text,
    provider_type text NOT NULL,
    provider_access_token text,
    provider_refresh_token text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    authentication_method text NOT NULL,
    auth_code_issued_at timestamp with time zone,
    invite_token text,
    referrer text,
    oauth_client_state_id uuid,
    linking_target_id uuid,
    email_optional boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE flow_state; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.flow_state IS 'Stores metadata for all OAuth/SSO login flows';


--
-- Name: identities; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.identities (
    provider_id text NOT NULL,
    user_id uuid NOT NULL,
    identity_data jsonb NOT NULL,
    provider text NOT NULL,
    last_sign_in_at timestamp with time zone,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    email text GENERATED ALWAYS AS (lower((identity_data ->> 'email'::text))) STORED,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: TABLE identities; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.identities IS 'Auth: Stores identities associated to a user.';


--
-- Name: COLUMN identities.email; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.identities.email IS 'Auth: Email is a generated column that references the optional email property in the identity_data';


--
-- Name: instances; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.instances (
    id uuid NOT NULL,
    uuid uuid,
    raw_base_config text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: TABLE instances; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.instances IS 'Auth: Manages users across multiple sites.';


--
-- Name: mfa_amr_claims; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_amr_claims (
    session_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    authentication_method text NOT NULL,
    id uuid NOT NULL
);


--
-- Name: TABLE mfa_amr_claims; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_amr_claims IS 'auth: stores authenticator method reference claims for multi factor authentication';


--
-- Name: mfa_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_challenges (
    id uuid NOT NULL,
    factor_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone,
    ip_address inet NOT NULL,
    otp_code text,
    web_authn_session_data jsonb
);


--
-- Name: TABLE mfa_challenges; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_challenges IS 'auth: stores metadata about challenge requests made';


--
-- Name: mfa_factors; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_factors (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    friendly_name text,
    factor_type auth.factor_type NOT NULL,
    status auth.factor_status NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    secret text,
    phone text,
    last_challenged_at timestamp with time zone,
    web_authn_credential jsonb,
    web_authn_aaguid uuid,
    last_webauthn_challenge_data jsonb
);


--
-- Name: TABLE mfa_factors; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_factors IS 'auth: stores metadata about factors';


--
-- Name: COLUMN mfa_factors.last_webauthn_challenge_data; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa_factors.last_webauthn_challenge_data IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';


--
-- Name: oauth_authorizations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_authorizations (
    id uuid NOT NULL,
    authorization_id text NOT NULL,
    client_id uuid NOT NULL,
    user_id uuid,
    redirect_uri text NOT NULL,
    scope text NOT NULL,
    state text,
    resource text,
    code_challenge text,
    code_challenge_method auth.code_challenge_method,
    response_type auth.oauth_response_type DEFAULT 'code'::auth.oauth_response_type NOT NULL,
    status auth.oauth_authorization_status DEFAULT 'pending'::auth.oauth_authorization_status NOT NULL,
    authorization_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:03:00'::interval) NOT NULL,
    approved_at timestamp with time zone,
    nonce text,
    CONSTRAINT oauth_authorizations_authorization_code_length CHECK ((char_length(authorization_code) <= 255)),
    CONSTRAINT oauth_authorizations_code_challenge_length CHECK ((char_length(code_challenge) <= 128)),
    CONSTRAINT oauth_authorizations_expires_at_future CHECK ((expires_at > created_at)),
    CONSTRAINT oauth_authorizations_nonce_length CHECK ((char_length(nonce) <= 255)),
    CONSTRAINT oauth_authorizations_redirect_uri_length CHECK ((char_length(redirect_uri) <= 2048)),
    CONSTRAINT oauth_authorizations_resource_length CHECK ((char_length(resource) <= 2048)),
    CONSTRAINT oauth_authorizations_scope_length CHECK ((char_length(scope) <= 4096)),
    CONSTRAINT oauth_authorizations_state_length CHECK ((char_length(state) <= 4096))
);


--
-- Name: oauth_client_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_client_states (
    id uuid NOT NULL,
    provider_type text NOT NULL,
    code_verifier text,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE oauth_client_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.oauth_client_states IS 'Stores OAuth states for third-party provider authentication flows where Supabase acts as the OAuth client.';


--
-- Name: oauth_clients; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_clients (
    id uuid NOT NULL,
    client_secret_hash text,
    registration_type auth.oauth_registration_type NOT NULL,
    redirect_uris text NOT NULL,
    grant_types text NOT NULL,
    client_name text,
    client_uri text,
    logo_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    client_type auth.oauth_client_type DEFAULT 'confidential'::auth.oauth_client_type NOT NULL,
    token_endpoint_auth_method text NOT NULL,
    CONSTRAINT oauth_clients_client_name_length CHECK ((char_length(client_name) <= 1024)),
    CONSTRAINT oauth_clients_client_uri_length CHECK ((char_length(client_uri) <= 2048)),
    CONSTRAINT oauth_clients_logo_uri_length CHECK ((char_length(logo_uri) <= 2048)),
    CONSTRAINT oauth_clients_token_endpoint_auth_method_check CHECK ((token_endpoint_auth_method = ANY (ARRAY['client_secret_basic'::text, 'client_secret_post'::text, 'none'::text])))
);


--
-- Name: oauth_consents; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_consents (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    client_id uuid NOT NULL,
    scopes text NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT oauth_consents_revoked_after_granted CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at))),
    CONSTRAINT oauth_consents_scopes_length CHECK ((char_length(scopes) <= 2048)),
    CONSTRAINT oauth_consents_scopes_not_empty CHECK ((char_length(TRIM(BOTH FROM scopes)) > 0))
);


--
-- Name: one_time_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.one_time_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_type auth.one_time_token_type NOT NULL,
    token_hash text NOT NULL,
    relates_to text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT one_time_tokens_token_hash_check CHECK ((char_length(token_hash) > 0))
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.refresh_tokens (
    instance_id uuid,
    id bigint NOT NULL,
    token character varying(255),
    user_id character varying(255),
    revoked boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    parent character varying(255),
    session_id uuid
);


--
-- Name: TABLE refresh_tokens; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.refresh_tokens IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.refresh_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.refresh_tokens_id_seq OWNED BY auth.refresh_tokens.id;


--
-- Name: saml_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_providers (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    entity_id text NOT NULL,
    metadata_xml text NOT NULL,
    metadata_url text,
    attribute_mapping jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    name_id_format text,
    CONSTRAINT "entity_id not empty" CHECK ((char_length(entity_id) > 0)),
    CONSTRAINT "metadata_url not empty" CHECK (((metadata_url = NULL::text) OR (char_length(metadata_url) > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK ((char_length(metadata_xml) > 0))
);


--
-- Name: TABLE saml_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_providers IS 'Auth: Manages SAML Identity Provider connections.';


--
-- Name: saml_relay_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_relay_states (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    request_id text NOT NULL,
    for_email text,
    redirect_to text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    flow_state_id uuid,
    CONSTRAINT "request_id not empty" CHECK ((char_length(request_id) > 0))
);


--
-- Name: TABLE saml_relay_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_relay_states IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';


--
-- Name: schema_migrations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: TABLE schema_migrations; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.schema_migrations IS 'Auth: Manages updates to the auth system.';


--
-- Name: sessions; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sessions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    factor_id uuid,
    aal auth.aal_level,
    not_after timestamp with time zone,
    refreshed_at timestamp without time zone,
    user_agent text,
    ip inet,
    tag text,
    oauth_client_id uuid,
    refresh_token_hmac_key text,
    refresh_token_counter bigint,
    scopes text,
    CONSTRAINT sessions_scopes_length CHECK ((char_length(scopes) <= 4096))
);


--
-- Name: TABLE sessions; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sessions IS 'Auth: Stores session data associated to a user.';


--
-- Name: COLUMN sessions.not_after; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.not_after IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';


--
-- Name: COLUMN sessions.refresh_token_hmac_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_hmac_key IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';


--
-- Name: COLUMN sessions.refresh_token_counter; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_counter IS 'Holds the ID (counter) of the last issued refresh token.';


--
-- Name: sso_domains; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_domains (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    domain text NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK ((char_length(domain) > 0))
);


--
-- Name: TABLE sso_domains; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_domains IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';


--
-- Name: sso_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_providers (
    id uuid NOT NULL,
    resource_id text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    disabled boolean,
    CONSTRAINT "resource_id not empty" CHECK (((resource_id = NULL::text) OR (char_length(resource_id) > 0)))
);


--
-- Name: TABLE sso_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_providers IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';


--
-- Name: COLUMN sso_providers.resource_id; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sso_providers.resource_id IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    instance_id uuid,
    id uuid NOT NULL,
    aud character varying(255),
    role character varying(255),
    email character varying(255),
    encrypted_password character varying(255),
    email_confirmed_at timestamp with time zone,
    invited_at timestamp with time zone,
    confirmation_token character varying(255),
    confirmation_sent_at timestamp with time zone,
    recovery_token character varying(255),
    recovery_sent_at timestamp with time zone,
    email_change_token_new character varying(255),
    email_change character varying(255),
    email_change_sent_at timestamp with time zone,
    last_sign_in_at timestamp with time zone,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    is_super_admin boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    phone text DEFAULT NULL::character varying,
    phone_confirmed_at timestamp with time zone,
    phone_change text DEFAULT ''::character varying,
    phone_change_token character varying(255) DEFAULT ''::character varying,
    phone_change_sent_at timestamp with time zone,
    confirmed_at timestamp with time zone GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
    email_change_token_current character varying(255) DEFAULT ''::character varying,
    email_change_confirm_status smallint DEFAULT 0,
    banned_until timestamp with time zone,
    reauthentication_token character varying(255) DEFAULT ''::character varying,
    reauthentication_sent_at timestamp with time zone,
    is_sso_user boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    is_anonymous boolean DEFAULT false NOT NULL,
    CONSTRAINT users_email_change_confirm_status_check CHECK (((email_change_confirm_status >= 0) AND (email_change_confirm_status <= 2)))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.users IS 'Auth: Stores user login data within a secure schema.';


--
-- Name: COLUMN users.is_sso_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.users.is_sso_user IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';


--
-- Name: webauthn_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.webauthn_challenges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    challenge_type text NOT NULL,
    session_data jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    CONSTRAINT webauthn_challenges_challenge_type_check CHECK ((challenge_type = ANY (ARRAY['signup'::text, 'registration'::text, 'authentication'::text])))
);


--
-- Name: webauthn_credentials; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.webauthn_credentials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    credential_id bytea NOT NULL,
    public_key bytea NOT NULL,
    attestation_type text DEFAULT ''::text NOT NULL,
    aaguid uuid,
    sign_count bigint DEFAULT 0 NOT NULL,
    transports jsonb DEFAULT '[]'::jsonb NOT NULL,
    backup_eligible boolean DEFAULT false NOT NULL,
    backed_up boolean DEFAULT false NOT NULL,
    friendly_name text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_used_at timestamp with time zone
);


--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    plan_type text DEFAULT 'free'::text,
    trial_started_at timestamp without time zone,
    trial_ends_at timestamp without time zone,
    subscription_ends_at timestamp without time zone,
    subscription_id text,
    cancel_at_period_end boolean DEFAULT false,
    stripe_customer_id text
);


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.companies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid,
    name text
);


--
-- Name: company_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid,
    name text,
    address text,
    tax_id text,
    phone text,
    updated_at timestamp without time zone DEFAULT now(),
    logo_url text,
    company_name text,
    company_name_en text,
    language text DEFAULT 'th'::text,
    date_format text DEFAULT 'thai'::text,
    company_name_th text,
    signature_url text,
    auto_signature_enabled boolean DEFAULT false,
    name_th text
);


--
-- Name: customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers (
    id bigint NOT NULL,
    company_id bigint,
    name text,
    phone text,
    account_id uuid NOT NULL,
    address text,
    tax_id text,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: customers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.customers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: customers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.customers_id_seq OWNED BY public.customers.id;


--
-- Name: document_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_items (
    id bigint NOT NULL,
    document_id bigint,
    description text,
    quantity numeric,
    unit_price numeric,
    line_no integer DEFAULT 1,
    total numeric DEFAULT 0,
    qty numeric DEFAULT 0,
    line_total numeric DEFAULT 0
);


--
-- Name: document_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.document_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.document_items_id_seq OWNED BY public.document_items.id;


--
-- Name: document_running; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_running (
    id integer NOT NULL,
    doc_type text,
    current_no integer DEFAULT 0,
    account_id uuid
);


--
-- Name: document_running_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.document_running_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_running_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.document_running_id_seq OWNED BY public.document_running.id;


--
-- Name: documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documents (
    id bigint NOT NULL,
    company_id bigint,
    doc_no text,
    customer_name text,
    total numeric,
    paid_amount numeric DEFAULT 0,
    payment_status text,
    doc_type text,
    doc_date date,
    subtotal numeric DEFAULT 0,
    vat_rate numeric DEFAULT 0,
    status text DEFAULT 'unpaid'::text,
    vat_enabled boolean DEFAULT false,
    order_id bigint,
    account_id uuid,
    note text,
    customer_address text,
    customer_phone text,
    customer_tax_id text,
    company_name text,
    company_address text,
    company_tax_id text,
    is_locked boolean DEFAULT false NOT NULL,
    company_logo_url text,
    company_phone text,
    created_at timestamp without time zone DEFAULT now(),
    group_id uuid
);


--
-- Name: documents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.documents_id_seq OWNED BY public.documents.id;


--
-- Name: feedbacks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feedbacks (
    id integer NOT NULL,
    account_id text NOT NULL,
    user_id text,
    type text NOT NULL,
    message text NOT NULL,
    page text,
    created_at timestamp without time zone DEFAULT now(),
    status text DEFAULT 'open'::text
);


--
-- Name: feedbacks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.feedbacks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: feedbacks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.feedbacks_id_seq OWNED BY public.feedbacks.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id bigint NOT NULL,
    document_id bigint,
    amount numeric,
    method text,
    company_id bigint,
    order_id bigint,
    account_id uuid,
    payment_date timestamp without time zone DEFAULT now()
);


--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    id bigint NOT NULL,
    company_id bigint,
    name text,
    default_price numeric
);


--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- Name: purchase_invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_invoices (
    id bigint NOT NULL,
    account_id uuid NOT NULL,
    company_id bigint,
    supplier_name text,
    tax_id text,
    doc_no text,
    doc_date date,
    subtotal numeric(12,2) DEFAULT 0,
    vat_amount numeric(12,2) DEFAULT 0,
    total numeric(12,2) DEFAULT 0,
    note text,
    created_at timestamp without time zone DEFAULT now(),
    source text,
    source_id uuid,
    document_status character varying(50) DEFAULT 'issued'::character varying,
    status character varying(50) DEFAULT 'active'::character varying,
    deleted_at timestamp without time zone,
    source_type character varying(50) DEFAULT 'manual'::character varying
);


--
-- Name: purchase_invoices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.purchase_invoices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: purchase_invoices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.purchase_invoices_id_seq OWNED BY public.purchase_invoices.id;


--
-- Name: purchase_order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_order_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    purchase_order_id uuid,
    description text,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    amount numeric DEFAULT 0,
    account_id uuid
);


--
-- Name: purchase_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    supplier_name text,
    tax_id text,
    doc_no text,
    doc_date date,
    subtotal numeric DEFAULT 0,
    vat_amount numeric DEFAULT 0,
    total numeric DEFAULT 0,
    status text DEFAULT 'draft'::text,
    note text,
    purchase_invoice_id integer,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    vat_type text DEFAULT 'none'::text,
    supplier_address text,
    supplier_phone text,
    supplier_tax_id text,
    issue_date date,
    company_name text,
    company_address text,
    company_tax_id text,
    company_logo_url text,
    company_phone text,
    is_locked boolean DEFAULT false NOT NULL
);


--
-- Name: running_numbers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.running_numbers (
    company_id bigint NOT NULL,
    next_no bigint DEFAULT 1 NOT NULL
);


--
-- Name: running_numbers_account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.running_numbers_account (
    account_id uuid NOT NULL,
    doc_type text NOT NULL,
    next_no integer DEFAULT 1 NOT NULL
);


--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suppliers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    name text NOT NULL,
    address text,
    phone text,
    tax_id text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    deleted_at timestamp without time zone
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid,
    company_id uuid,
    email text,
    password_hash text,
    google_sub text,
    google_email text,
    google_name text,
    google_picture text
);


--
-- Name: messages; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
)
PARTITION BY RANGE (inserted_at);


--
-- Name: schema_migrations; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: subscription; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.subscription (
    id bigint NOT NULL,
    subscription_id uuid NOT NULL,
    entity regclass NOT NULL,
    filters realtime.user_defined_filter[] DEFAULT '{}'::realtime.user_defined_filter[] NOT NULL,
    claims jsonb NOT NULL,
    claims_role regrole GENERATED ALWAYS AS (realtime.to_regrole((claims ->> 'role'::text))) STORED NOT NULL,
    created_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    action_filter text DEFAULT '*'::text,
    CONSTRAINT subscription_action_filter_check CHECK ((action_filter = ANY (ARRAY['*'::text, 'INSERT'::text, 'UPDATE'::text, 'DELETE'::text])))
);


--
-- Name: subscription_id_seq; Type: SEQUENCE; Schema: realtime; Owner: -
--

ALTER TABLE realtime.subscription ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME realtime.subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: buckets; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets (
    id text NOT NULL,
    name text NOT NULL,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    public boolean DEFAULT false,
    avif_autodetection boolean DEFAULT false,
    file_size_limit bigint,
    allowed_mime_types text[],
    owner_id text,
    type storage.buckettype DEFAULT 'STANDARD'::storage.buckettype NOT NULL
);


--
-- Name: COLUMN buckets.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.buckets.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: buckets_analytics; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_analytics (
    name text NOT NULL,
    type storage.buckettype DEFAULT 'ANALYTICS'::storage.buckettype NOT NULL,
    format text DEFAULT 'ICEBERG'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: buckets_vectors; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_vectors (
    id text NOT NULL,
    type storage.buckettype DEFAULT 'VECTOR'::storage.buckettype NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: migrations; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.migrations (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    hash character varying(40) NOT NULL,
    executed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: objects; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.objects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bucket_id text,
    name text,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    last_accessed_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/'::text)) STORED,
    version text,
    owner_id text,
    user_metadata jsonb
);


--
-- Name: COLUMN objects.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.objects.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: s3_multipart_uploads; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads (
    id text NOT NULL,
    in_progress_size bigint DEFAULT 0 NOT NULL,
    upload_signature text NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    version text NOT NULL,
    owner_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_metadata jsonb,
    metadata jsonb
);


--
-- Name: s3_multipart_uploads_parts; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads_parts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    upload_id text NOT NULL,
    size bigint DEFAULT 0 NOT NULL,
    part_number integer NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    etag text NOT NULL,
    owner_id text,
    version text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vector_indexes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.vector_indexes (
    id text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    bucket_id text NOT NULL,
    data_type text NOT NULL,
    dimension integer NOT NULL,
    distance_metric text NOT NULL,
    metadata_configuration jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('auth.refresh_tokens_id_seq'::regclass);


--
-- Name: customers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers ALTER COLUMN id SET DEFAULT nextval('public.customers_id_seq'::regclass);


--
-- Name: document_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_items ALTER COLUMN id SET DEFAULT nextval('public.document_items_id_seq'::regclass);


--
-- Name: document_running id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_running ALTER COLUMN id SET DEFAULT nextval('public.document_running_id_seq'::regclass);


--
-- Name: documents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents ALTER COLUMN id SET DEFAULT nextval('public.documents_id_seq'::regclass);


--
-- Name: feedbacks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedbacks ALTER COLUMN id SET DEFAULT nextval('public.feedbacks_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- Name: purchase_invoices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_invoices ALTER COLUMN id SET DEFAULT nextval('public.purchase_invoices_id_seq'::regclass);


--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.audit_log_entries (instance_id, id, payload, created_at, ip_address) FROM stdin;
\.


--
-- Data for Name: custom_oauth_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.custom_oauth_providers (id, provider_type, identifier, name, client_id, client_secret, acceptable_client_ids, scopes, pkce_enabled, attribute_mapping, authorization_params, enabled, email_optional, issuer, discovery_url, skip_nonce_check, cached_discovery, discovery_cached_at, authorization_url, token_url, userinfo_url, jwks_uri, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.flow_state (id, user_id, auth_code, code_challenge_method, code_challenge, provider_type, provider_access_token, provider_refresh_token, created_at, updated_at, authentication_method, auth_code_issued_at, invite_token, referrer, oauth_client_state_id, linking_target_id, email_optional) FROM stdin;
\.


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) FROM stdin;
\.


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.instances (id, uuid, raw_base_config, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_amr_claims (session_id, created_at, updated_at, authentication_method, id) FROM stdin;
\.


--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_challenges (id, factor_id, created_at, verified_at, ip_address, otp_code, web_authn_session_data) FROM stdin;
\.


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at, secret, phone, last_challenged_at, web_authn_credential, web_authn_aaguid, last_webauthn_challenge_data) FROM stdin;
\.


--
-- Data for Name: oauth_authorizations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_authorizations (id, authorization_id, client_id, user_id, redirect_uri, scope, state, resource, code_challenge, code_challenge_method, response_type, status, authorization_code, created_at, expires_at, approved_at, nonce) FROM stdin;
\.


--
-- Data for Name: oauth_client_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_client_states (id, provider_type, code_verifier, created_at) FROM stdin;
\.


--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_clients (id, client_secret_hash, registration_type, redirect_uris, grant_types, client_name, client_uri, logo_uri, created_at, updated_at, deleted_at, client_type, token_endpoint_auth_method) FROM stdin;
\.


--
-- Data for Name: oauth_consents; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_consents (id, user_id, client_id, scopes, granted_at, revoked_at) FROM stdin;
\.


--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.one_time_tokens (id, user_id, token_type, token_hash, relates_to, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.refresh_tokens (instance_id, id, token, user_id, revoked, created_at, updated_at, parent, session_id) FROM stdin;
\.


--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_providers (id, sso_provider_id, entity_id, metadata_xml, metadata_url, attribute_mapping, created_at, updated_at, name_id_format) FROM stdin;
\.


--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_relay_states (id, sso_provider_id, request_id, for_email, redirect_to, created_at, updated_at, flow_state_id) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.schema_migrations (version) FROM stdin;
20171026211738
20171026211808
20171026211834
20180103212743
20180108183307
20180119214651
20180125194653
00
20210710035447
20210722035447
20210730183235
20210909172000
20210927181326
20211122151130
20211124214934
20211202183645
20220114185221
20220114185340
20220224000811
20220323170000
20220429102000
20220531120530
20220614074223
20220811173540
20221003041349
20221003041400
20221011041400
20221020193600
20221021073300
20221021082433
20221027105023
20221114143122
20221114143410
20221125140132
20221208132122
20221215195500
20221215195800
20221215195900
20230116124310
20230116124412
20230131181311
20230322519590
20230402418590
20230411005111
20230508135423
20230523124323
20230818113222
20230914180801
20231027141322
20231114161723
20231117164230
20240115144230
20240214120130
20240306115329
20240314092811
20240427152123
20240612123726
20240729123726
20240802193726
20240806073726
20241009103726
20250717082212
20250731150234
20250804100000
20250901200500
20250903112500
20250904133000
20250925093508
20251007112900
20251104100000
20251111201300
20251201000000
20260115000000
20260121000000
20260219120000
20260302000000
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sessions (id, user_id, created_at, updated_at, factor_id, aal, not_after, refreshed_at, user_agent, ip, tag, oauth_client_id, refresh_token_hmac_key, refresh_token_counter, scopes) FROM stdin;
\.


--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_domains (id, sso_provider_id, domain, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_providers (id, resource_id, created_at, updated_at, disabled) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) FROM stdin;
\.


--
-- Data for Name: webauthn_challenges; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.webauthn_challenges (id, user_id, challenge_type, session_data, created_at, expires_at) FROM stdin;
\.


--
-- Data for Name: webauthn_credentials; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.webauthn_credentials (id, user_id, credential_id, public_key, attestation_type, aaguid, sign_count, transports, backup_eligible, backed_up, friendly_name, created_at, updated_at, last_used_at) FROM stdin;
\.


--
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.accounts (id, name, plan_type, trial_started_at, trial_ends_at, subscription_ends_at, subscription_id, cancel_at_period_end, stripe_customer_id) FROM stdin;
cf532569-58e0-4019-a00f-17a4966af22f	-	basic	2026-03-30 06:30:57.610835	2026-04-03 15:59:05.491201	2026-05-03 15:59:05.487	sub_1TGZMO5cA1FGMBICHdBLwK0Z	t	cus_UF3TKIDz7syQuM
9e051997-6e28-4b2a-af7a-5fef68524c52	-	trial	2026-04-04 04:06:01.964245	2026-04-11 04:06:01.964245	\N	\N	f	\N
07c55228-eacb-4cd8-9490-1f6f75adc2a6	-	trial	2026-04-04 04:16:59.076646	2026-04-11 04:16:59.076646	\N	\N	f	\N
85f90f95-902a-4973-8349-114d333f1f6d	-	pro	2026-03-31 16:28:56.825512	2026-04-04 06:07:10.338104	2026-05-04 06:07:10.344	sub_1TINML8z46z6gnCWCN7CigSa	f	cus_UGvALusKg9o1og
15609794-437b-4504-91a1-9a1a0c055ea8	-	trial	2026-04-04 18:07:51.789948	2026-04-11 18:07:51.789948	\N	\N	f	\N
d9892940-318d-45aa-819f-20b23d1aa336	-	trial	2026-04-05 10:57:51.307793	2026-04-12 10:57:51.307793	\N	\N	f	\N
50ebcc47-10bc-4f05-9da5-04ca074acd86	-	trial	2026-04-05 15:56:09.123667	2026-04-12 15:56:09.123667	\N	\N	f	\N
9d38fa5c-2f63-454a-a8c3-bbe684292236	-	trial	2026-04-05 16:21:19.655251	2026-04-12 16:21:19.655251	\N	\N	f	\N
c8dc8caa-fb14-4cbf-8e30-da29c8ef0ac0	-	trial	2026-04-06 09:57:55.020037	2026-04-13 09:57:55.020037	\N	\N	f	\N
d9690699-aa6a-4750-a095-0f41daa0ad3e	-	pro	2026-03-30 22:40:47.384808	2026-03-30 22:41:40.119675	2026-04-29 22:41:39.311	sub_1TGoV35cA1FGMBICPuqyMs2F	f	\N
f4730610-3b71-4293-971d-e783c27e71da	-	business	2026-03-30 22:42:50.242648	2026-03-30 22:43:12.218818	2026-04-29 22:43:11.406	sub_1TGoWX5cA1FGMBIC0ksTHqXD	t	\N
62f62fde-9246-4046-8cb1-44ea71c88eed	-	basic	2026-03-31 00:23:40.766867	2026-03-31 01:30:34.081719	2026-04-30 01:30:32.293	sub_1TGqC35cA1FGMBICZmyiPRJU	f	\N
3b34b55e-f428-42ed-b913-32c313dfcfd9	-	free	2026-04-03 01:22:46.609743	2026-04-10 01:22:46.609743	\N	\N	f	\N
981d9a04-3481-4b68-b259-89044e600f46	-	pro	2026-04-02 16:24:06.620621	2026-04-03 01:23:21.380975	2026-05-03 01:23:21.379	sub_1THvUm5cA1FGMBICEcXtVHA8	f	\N
6923c1d9-4f5a-40ba-8a1c-98fbf65f237a	-	free	2026-04-03 04:41:09.174102	2026-04-10 04:41:09.174102	\N	\N	f	\N
ccaf622d-3ecc-4a57-9055-25c5c292cd2b	-	basic	2026-04-03 02:11:33.890585	2026-04-03 08:54:48.444584	2026-05-03 08:54:48.432	sub_1TI3V35cA1FGMBICGe9Xx9dP	f	\N
b79d79f9-02d5-4707-b34b-cbaa885e90c4	-	pro	2026-03-28 13:03:52.683222	2026-04-04 13:03:52.683222	2026-04-29 16:16:39.461975	\N	f	\N
6466b94b-6852-4797-9378-7ae617809699	หจก. ซีทีดี อินเตอร์เทรด	pro	2026-03-28 05:34:35.653547	2026-04-04 05:34:35.653547	2026-04-29 16:16:39.461975	\N	f	\N
e588ae04-1f53-4a43-a0cf-f8d921693b18	-	pro	2026-03-28 11:30:44.962316	2026-04-04 11:30:44.962316	2026-04-29 16:16:39.461975	\N	f	\N
f86ea2b3-412d-40fa-a75c-efc0f23a4ac2	-	pro	2026-03-28 05:37:14.88905	2026-04-04 05:37:14.88905	2026-04-29 16:16:39.461975	\N	f	\N
0fe26c00-1639-4523-9971-8700ac12c31e	-	pro	2026-03-29 15:10:25.517234	2026-04-05 15:10:25.517234	2026-04-29 16:16:39.461975	\N	f	\N
aab7591d-19da-43ca-b51e-3169b4c67447	-	pro	2026-03-30 04:53:47.024648	2026-04-06 04:53:47.024648	2026-04-29 16:16:39.461975	\N	t	\N
4282ac46-6b21-4774-8558-3671ea5e7286	-	pro	2026-03-30 00:04:19.396019	2026-03-30 06:44:42.962927	2026-04-29 16:16:39.461975	\N	f	\N
\.


--
-- Data for Name: companies; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.companies (id, account_id, name) FROM stdin;
634dfd90-166c-49ea-a03f-211a1502bffc	6466b94b-6852-4797-9378-7ae617809699	หจก. ซีทีดี อินเตอร์เทรด
15d65058-4d3c-40ab-a5f9-bbf29c60b398	f86ea2b3-412d-40fa-a75c-efc0f23a4ac2	-
fcafe18b-a9ad-46eb-bddd-d6750212c7b6	e588ae04-1f53-4a43-a0cf-f8d921693b18	-
43b9b265-4b27-4c92-979f-c15f54d6dac4	b79d79f9-02d5-4707-b34b-cbaa885e90c4	-
e2a687b2-c91f-43c3-bbef-fdbd4d791c1f	0fe26c00-1639-4523-9971-8700ac12c31e	-
54d4faaf-a159-48b9-8151-9283c134e104	4282ac46-6b21-4774-8558-3671ea5e7286	-
9f268602-28e8-4b75-88ea-2a3a0dd96bc6	aab7591d-19da-43ca-b51e-3169b4c67447	-
ba977b0c-0efe-4acf-a417-2a50f6e3cd7e	cf532569-58e0-4019-a00f-17a4966af22f	-
9c0f5cc3-97e8-49d1-bba5-4ad40457b90b	d9690699-aa6a-4750-a095-0f41daa0ad3e	-
83fb7bb1-eb1c-4b29-9b9b-89aa308be8ca	f4730610-3b71-4293-971d-e783c27e71da	-
0dccffc2-db29-440a-b2f9-ea2833ea868c	62f62fde-9246-4046-8cb1-44ea71c88eed	-
2cbd90e7-6347-4bdf-ad7b-e827c2107698	85f90f95-902a-4973-8349-114d333f1f6d	-
e72c5228-e497-46c5-a705-c20c344e172f	981d9a04-3481-4b68-b259-89044e600f46	-
f13f8cb6-27bd-4518-9737-2a9e8ec743fc	3b34b55e-f428-42ed-b913-32c313dfcfd9	-
f04f114b-3582-4b48-8353-b386e775b01a	ccaf622d-3ecc-4a57-9055-25c5c292cd2b	-
bd3ce7c7-4556-4ada-a309-56aea278c887	6923c1d9-4f5a-40ba-8a1c-98fbf65f237a	-
e8736d54-4feb-4d02-8d94-8ac5be2e0392	9e051997-6e28-4b2a-af7a-5fef68524c52	-
431c827b-7414-466f-9dc8-7399f4a73aa7	07c55228-eacb-4cd8-9490-1f6f75adc2a6	-
e8c9ae67-dfc9-475b-93de-3ea7d608c678	15609794-437b-4504-91a1-9a1a0c055ea8	-
b003c755-1b95-44cd-9bc6-d844b5618f3c	d9892940-318d-45aa-819f-20b23d1aa336	-
05e896c0-50ef-4ee9-bca4-5b5146cc42d2	50ebcc47-10bc-4f05-9da5-04ca074acd86	-
7be88329-c7cb-4c2f-a29b-ba6521765a7e	9d38fa5c-2f63-454a-a8c3-bbe684292236	-
18f8d045-9f22-4b10-8a72-2cf07bdfedae	c8dc8caa-fb14-4cbf-8e30-da29c8ef0ac0	-
\.


--
-- Data for Name: company_settings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.company_settings (id, account_id, name, address, tax_id, phone, updated_at, logo_url, company_name, company_name_en, language, date_format, company_name_th, signature_url, auto_signature_enabled, name_th) FROM stdin;
b3d3f8a6-4892-4a3c-ae76-807f1c30a087	981d9a04-3481-4b68-b259-89044e600f46	\N	\N	\N	\N	2026-04-02 16:24:06.843634	\N	\N	\N	th	thai	\N	\N	f	\N
9ca2e239-21b1-4b3e-8742-73070245526a	e588ae04-1f53-4a43-a0cf-f8d921693b18	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	0846661234	2026-03-28 12:10:56.021233	/uploads/logos/1774699852522-S__6381582.jpg	หจก. บ้านนาดอยคำ		th	thai	\N	\N	f	\N
c27c0279-6560-454a-aaae-8c33bbd77196	b79d79f9-02d5-4707-b34b-cbaa885e90c4	\N	\N	\N	\N	2026-03-28 13:03:53.178299	\N	\N	\N	th	thai	\N	\N	f	\N
503095ff-dade-452f-856e-0ebc7cbcb4c8	0fe26c00-1639-4523-9971-8700ac12c31e	\N	\N	\N	\N	2026-03-29 15:10:26.039499	\N	\N	\N	th	thai	\N	\N	f	\N
46be1626-d9d2-4ad5-b3c2-2a97d82abbee	4282ac46-6b21-4774-8558-3671ea5e7286	\N	\N	\N	\N	2026-03-30 00:04:19.931274	\N	\N	\N	th	thai	\N	\N	f	\N
00df2f78-25c4-4f91-b922-3a7f5ffbfb79	aab7591d-19da-43ca-b51e-3169b4c67447	\N	\N	\N	\N	2026-03-30 04:53:47.51247	\N	\N	\N	th	thai	\N	\N	f	\N
84d5b91e-7629-4c1c-9ebd-363275dbd7bb	d9690699-aa6a-4750-a095-0f41daa0ad3e	\N	\N	\N	\N	2026-03-30 22:40:47.881006	\N	\N	\N	th	thai	\N	\N	f	\N
7def5851-6900-4067-9269-527ca9725d95	f4730610-3b71-4293-971d-e783c27e71da	\N	\N	\N	\N	2026-03-30 22:42:50.74776	\N	\N	\N	th	thai	\N	\N	f	\N
db2762c6-f54d-49c6-9e26-f046ac7223b3	d9892940-318d-45aa-819f-20b23d1aa336	ครัวผัวหล่ออาหารตามสั่ง	111 ชัยวัฒน์10 ข.บางค้อ ข.จอมทอง กทม.10150		+66972014747	2026-04-05 11:05:05.536111	\N	ครัวผัวหล่ออาหารตามสั่ง	Hua Lor Kitchen	th	thai	\N	\N	t	\N
48c50d23-1a01-4c82-8c3f-d451feb6b36e	62f62fde-9246-4046-8cb1-44ea71c88eed	\N	\N	\N	\N	2026-03-31 00:23:41.227893	\N	\N	\N	th	thai	\N	\N	f	\N
9cb4aa04-c967-4a4a-a128-20ff45f207d9	85f90f95-902a-4973-8349-114d333f1f6d	\N	\N	\N	\N	2026-03-31 16:28:57.105338	\N	\N	\N	th	thai	\N	\N	f	\N
587cb5b6-af1a-4452-b920-c99ac92a549f	3b34b55e-f428-42ed-b913-32c313dfcfd9	\N	\N	\N	\N	2026-04-03 01:52:45.369743	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775181159750-0000.png	\N	\N	th	thai	\N	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775181165237-0000.png	f	\N
5cc676f2-4abe-441f-940f-e5b5a6f1a568	6923c1d9-4f5a-40ba-8a1c-98fbf65f237a	\N	\N	\N	\N	2026-04-03 04:41:09.445816	\N	\N	\N	th	thai	\N	\N	f	\N
786cb103-9aa6-40a1-89f2-0abd4eb39c2f	9e051997-6e28-4b2a-af7a-5fef68524c52	หจก. ซีทีดี อินเตอร์เทรด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย 42000	14205001651087	0849197741	2026-04-04 04:13:56.657345	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775275918903-MLT_logo.png	หจก. ซีทีดี อินเตอร์เทรด		th	thai	\N	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775275926893-0000.png	t	\N
de015489-8007-437b-9869-4163bdfedc61	07c55228-eacb-4cd8-9490-1f6f75adc2a6	\N	\N	\N	\N	2026-04-04 04:16:59.406548	\N	\N	\N	th	thai	\N	\N	f	\N
ca79a2c5-8ef0-47b7-80bc-68cdf0e45624	15609794-437b-4504-91a1-9a1a0c055ea8	\N	\N	\N	\N	2026-04-04 18:07:52.120084	\N	\N	\N	th	thai	\N	\N	f	\N
8b361c24-79e6-4da2-a01e-b87b072d907a	6466b94b-6852-4797-9378-7ae617809699	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	0849197741	2026-04-05 15:44:53.780993	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775403892990-MLT_logo.png	บริษัท มลทต6จำกัด	MLT	th	thai	บริษัท เมืองเลยแทรกเตอร์ จำกัด	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144711639-0000.png	t	บริษัท เมืองเลยแทรกเตอร์ จำกัด
fad5e939-f897-4046-aee4-c1b3c907f005	ccaf622d-3ecc-4a57-9055-25c5c292cd2b	บ้านขนมไทย	222 หมู่17 อ.วังน้อย จ.อยุธยา	1254774412547	0555552124	2026-04-03 08:15:51.05941	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775204142416-Untitled-2.png	บ้านขนมไทย		th	thai	\N	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775204147533-________________________________________________________________________________19_.png	f	\N
22af89a0-fe6d-4f7d-bf8c-76ee7b66eb84	50ebcc47-10bc-4f05-9da5-04ca074acd86	\N	\N	\N	\N	2026-04-05 15:58:45.003977	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775404724151-Screenshot_2026-03-18-06-27-39-60_f4e4ecb26678a2259e115c26f2593e0f.jpg	\N	\N	th	thai	\N	\N	f	\N
4d03d518-9337-49cb-a708-9b55e00fb0b0	cf532569-58e0-4019-a00f-17a4966af22f	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	0846612354	2026-04-05 09:46:33.972504	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	บริษัท เมืองเลยแทรกเตอร์ จำกัด		th	thai	\N	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354826085-0000.png	t	\N
a42a9190-2a56-45e5-a96d-9dd866312c2c	9d38fa5c-2f63-454a-a8c3-bbe684292236	หจก.ซีทีดี อินเตอร์เทรด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	1420560010187	0849197741	2026-04-05 16:31:35.580952	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775406622210-IMG_5147.jpeg	หจก.ซีทีดี อินเตอร์เทรด		th	thai	\N	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775406634090-IMG_5146.png	t	\N
d4bb28fd-34db-4c49-b6e1-2e1cda43066d	f86ea2b3-412d-40fa-a75c-efc0f23a4ac2	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย 42000	1420008767543	0849197741	2026-04-06 15:32:06.027465	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775489424350-IMG_5147.jpeg	บริษัท เมืองเลยแทรกเตอร์ จำกัด		th	thai	\N	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775489446604-IMG_5146.png	t	\N
05cc4645-7931-45d7-ba5c-a25798726354	c8dc8caa-fb14-4cbf-8e30-da29c8ef0ac0	\N	\N	\N	\N	2026-04-06 09:57:55.873246	\N	\N	\N	th	thai	\N	\N	f	\N
\.


--
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.customers (id, company_id, name, phone, account_id, address, tax_id, deleted_at, created_at) FROM stdin;
1	1	ทดสอบ	0849197741	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	2026-03-26 10:53:50.311361
4	\N	หจก.ซีทีดี อินเตอร์เทรด	0849197741	6466b94b-6852-4797-9378-7ae617809699	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000061087	\N	2026-03-26 10:53:50.311361
6	\N	SoftDel Customer	0899999999	00000000-0000-0000-0000-000000000001	Addr	TAXC	2026-03-26 10:34:33.130748	2026-03-26 10:53:50.311361
7	\N	ทดสอบ5	0546987741	6466b94b-6852-4797-9378-7ae617809699	323 หมู่4 ต.นาอาน อ.เมือง จ.เลย	1254455448574	2026-03-26 11:06:28.192011	2026-03-26 10:53:50.311361
8	\N	ร้านบ้านทุ่ง	0541236547	6466b94b-6852-4797-9378-7ae617809699	42 หมู่4 	1235411125474	\N	2026-03-27 16:02:29.144644
9	\N	ครัวบ้านสวน	0875462541	6466b94b-6852-4797-9378-7ae617809699	56 หมู่2 ต.นาดินดำ อ.เมือง จ.เลย 42000	1420900036547	\N	2026-03-28 01:18:07.195434
3	\N	ทดสอบ2	0849197741	6466b94b-6852-4797-9378-7ae617809699	287 หมู่6	1420500036598	2026-03-28 05:21:04.340222	2026-03-26 10:53:50.311361
10	\N	น้องนุชการค้า	0854451265	e588ae04-1f53-4a43-a0cf-f8d921693b18	42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	1420633354698	\N	2026-03-28 11:34:49.472649
12	\N	อาราแต  มะดาโอ๊ะ	0654412325	e588ae04-1f53-4a43-a0cf-f8d921693b18	52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	1457800025469	\N	2026-03-28 11:41:21.80331
11	\N	สมชาย ใจดี	0574111254	e588ae04-1f53-4a43-a0cf-f8d921693b18	87 หมู่13 ต.ท่าข่าม อ.เมือง จ.เลย 42000	1450233365987	2026-03-28 12:07:46.868949	2026-03-28 11:36:10.337606
13	\N	หจก.ซีทีดี อินเตอร์เทรด	0849197741	85f90f95-902a-4973-8349-114d333f1f6d	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	1420506500178	\N	2026-03-31 16:36:16.033456
14	\N	สมชาย ซื้อดี	0885456321	3b34b55e-f428-42ed-b913-32c313dfcfd9	23 หมู่7 ต.นาอาน อ.เมือง จ.เลย	1450033362354	\N	2026-04-03 01:23:52.202552
15	\N	น้องปลา	0224125474	ccaf622d-3ecc-4a57-9055-25c5c292cd2b	14 หมู่7 ต.นาดี อ.เมือง จ.เลย 42000	1254411121547	\N	2026-04-03 08:32:38.890723
16	\N	บริษัท เมืองเลย แทรกเตอร์ จำกัด	0884451247	9e051997-6e28-4b2a-af7a-5fef68524c52	323 หมู่4 ต.นาอาน อ.เมือง จ.เลย 42000	1450023625874	\N	2026-04-04 04:10:59.735574
17	\N	ตาแกะการค้า	0856632147	cf532569-58e0-4019-a00f-17a4966af22f	42 หมู่8 ต.นาดี อ.ด่านซ้าย จ.เลย	1420300065457	\N	2026-04-05 02:21:05.557745
18	\N	ร้านภูฟ้าอาหารสด	0874514246	cf532569-58e0-4019-a00f-17a4966af22f	97 หมู่4 ต.ด่านซ้าย อ.ด่านซ้าย จ.เลย 42000	1450366001478	\N	2026-04-05 02:22:05.068738
19	\N	จรัญพาณิชย์	0985747472	cf532569-58e0-4019-a00f-17a4966af22f	274 หมู่11 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1423500087451	\N	2026-04-05 02:23:44.112299
20	\N	สมศักดิ์กาค้า	0554214574	f86ea2b3-412d-40fa-a75c-efc0f23a4ac2	10 หมู่2 ต.ปากหมัน อ.ด่านซ้าย จ.เลย 42000	1250044457124	\N	2026-04-06 15:44:22.145044
\.


--
-- Data for Name: document_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.document_items (id, document_id, description, quantity, unit_price, line_no, total, qty, line_total) FROM stdin;
1	4	ธำหะะ	\N	700	1	0	1	700
2	5	ธำหะะ	\N	700	1	0	1	700
3	6	ธำหะะ	\N	700	1	0	1	700
4	7	Test	\N	500	1	0	1	500
5	8	Test	\N	500	1	0	1	500
6	9	Test	\N	500	1	0	1	500
7	10	Test	\N	500	1	0	1	500
8	11	Test	\N	500	1	0	1	500
9	12	Test	\N	500	1	0	1	500
10	13	Test	\N	500	1	0	1	500
11	14	Test	\N	500	1	0	1	500
12	15	Test	\N	500	1	0	1	500
13	16	Test	\N	500	1	0	1	500
14	17	Test	\N	500	1	0	1	500
15	18	Test	\N	500	1	0	1	500
16	19	หกดหกดหกด	\N	800	1	0	1	800
17	20	หกดหกดหกด	\N	800	1	0	1	800
18	21	หกดหกดหกด	\N	800	1	0	1	800
19	22	หกดหกดหกด	\N	800	1	0	1	800
20	23	ธำหำะะ	\N	800	1	0	1	800
21	24	ฟหกฟหกฟหกฟ	\N	778	1	0	1	778
22	28	ฟหกฟหกฟหก	\N	41000	1	0	1	41000
23	32	Test	\N	500	1	0	10	5000
24	36	Test	\N	500	1	0	1	500
25	40	ธำหะ	\N	500	1	0	1	500
26	44	sadadasdasd	\N	500	1	0	1	500
27	48	ddsadad	\N	800	1	0	1	800
28	52	sdasd	\N	400	1	0	1	400
29	53	fgdfgg	\N	450	1	0	1	450
30	57	มะม่วงแก้ว	\N	587	1	0	1	587
31	58	ปลาหมึกแห้ง (กิโล)	\N	500	1	0	3	1500
32	62	มะละกอ กิโลละ300	\N	300	1	0	2	600
33	66	บริการถมและปรับดิน	\N	5800	1	0	1	5800
34	66	ดิน200รถ	\N	350	2	0	200	70000
35	67	ค่าบริการขุดสระ	\N	50000	1	0	1	50000
36	71	มะม่วง	\N	20	1	0	5000	100000
37	71	มะปราง	\N	20	2	0	10000	200000
38	71	มะนาว	\N	100	3	0	500	50000
39	75	สียอมไม้	\N	542	1	0	20	10840
40	75	สีเคลือบเงา	\N	565	2	0	10	5650
41	76	มะม่วง	\N	20	1	0	50	1000
42	80	สายไฟ 2x1.5 VCT	\N	20	1	0	100	2000
43	83	มะม่วงดอง	\N	450	1	0	50	22500
44	87	หดหกดหกด	\N	22	1	0	1000	22000
45	91	มะม่วงหาว	\N	23	1	0	1000	23000
46	95	กฟหกฟหกฟก	\N	500	1	0	1	500
47	99	หดดหกดด	\N	500	1	0	400	200000
48	103	fgdgg	\N	4000	1	0	1	4000
49	107	asdasdasd	\N	500	1	0	11	5500
50	111	ปลานิลสด	\N	70	1	0	400	28000
51	115	dasdasd	\N	500	1	0	12	6000
52	117	กกฟหกฟห	\N	867	1	0	1	867
53	121	ฟหกฟกฟก	\N	800	1	0	1	800
54	125	กหฟก	\N	200	1	0	1	200
55	129	หกดดหกด	\N	497	1	0	1	497
56	133	sadasdas	\N	500	1	0	1	500
57	135	หฤฆฟ	\N	496	1	0	1	496
58	137	กฟหกฟหก	\N	5000	1	0	1	5000
59	139	เดหดหด	\N	8000	1	0	1	8000
60	143	กหฟกฟหก	\N	400	1	0	1	400
61	147	วสวาสวาวา	\N	5000	1	0	1	5000
62	151	dsadasd	\N	797	1	0	1	797
63	155	กฟหกฟก	\N	8000	1	0	1	8000
64	157	ปลากระพง	\N	240	1	0	100	24000
65	164	เส้นก๋วยเตี๋ยวอย่างดี	\N	24	1	0	500	12000
66	165	มะปรางหวาน	\N	20	1	0	500	10000
67	169	dadad	\N	500	1	0	1	500
68	173	มะม่วงดอง	\N	35	1	0	500	17500
69	177	มะม่วงแก้ว	\N	54	1	0	50	2700
70	181	ค่าขุดดินรถละ300	\N	300	1	0	30	9000
71	182	มะม่วงเปรี้ยว	\N	12	1	0	50	600
72	188	ฟหกก	\N	80	1	0	1	80
73	188	กหฟก	\N	87	2	0	1	87
74	190	กกหฟฟฟ	\N	500	1	0	1	500
75	194	มะเขือยาว	\N	20	1	0	135	2700
76	198	กหฟฟฟ	\N	798	1	0	1	798
77	202	มะเขือยาว	\N	10	1	0	500	5000
78	206	หฟกฟหก	\N	800	1	0	1	800
79	206	ฟกกฟห	\N	897	2	0	1	897
80	212	มะนาว	\N	45	1	0	80	3600
81	214	มะเขือ	\N	40	1	0	500	20000
82	214	พริก	\N	135	2	0	500	67500
83	218	กหฟกฟ	\N	496	1	0	1	496
84	222	ฟหกฟก	\N	500	1	0	1	500
85	226	เกดเกดเ	\N	699	1	0	1	699
86	226	เกดเ	\N	100	2	0	1	100
87	230	เดกเกเ	\N	800	1	0	1	800
88	230	เดกเกเ	\N	400	2	0	1	400
89	234	หกดหกด	\N	800	1	0	1	800
90	238	fsdffs	\N	500	1	0	1	500
91	239	ฆฟห	\N	500	1	0	1	500
92	243	มะม่วงดอง	\N	500	1	0	1	500
93	247	มะนาว	\N	54	1	0	500	27000
94	251	มะเขือ	\N	21	1	0	400	8400
95	255	มะไฟ	\N	12	1	0	400	4800
96	259	มะม่วง	\N	50	1	0	500	25000
97	263	ลายน้ำ	\N	800	1	0	1	800
98	267	กหฟกฟก	\N	700	1	0	1	700
99	271	dasdad	\N	852	1	0	1	852
100	275	กหฟก	\N	400	1	0	1	400
101	279	ฟหกฟหก	\N	497	1	0	1	497
102	283	กหดหกด	\N	900	1	0	1	900
103	287	ปลานิล	\N	80	1	0	800	64000
104	291	อะไหล่ล้อ CAT305SR	\N	500	1	0	1	500
105	295	ซีลยาง	\N	532	1	0	1000	532000
106	299	กหฟกฟหก	\N	80000	1	0	1	80000
107	303	ปลากระป่อง(แพ็ค)	\N	22	1	0	200	4400
108	307	ปบาหมึกสด	\N	250	1	0	30	7500
109	311	สลักแม็คโคร 45มิล	\N	1250	1	0	1	1250
110	311	ปั้มไฮดรอริก PC50	\N	25000	2	0	1	25000
111	311	ไทนอลไดร์	\N	25000	3	0	1	25000
112	315	ตะกร้า เบอร์34	\N	45	1	0	500	22500
113	319	เบียร์ช้าง(ลัง)	\N	675	1	0	20	13500
114	323	น้ำจิ้มซีฟู๊ด	\N	25	1	0	50	1250
115	323	น้ำจิ้มลูกชิ้น	\N	15	2	0	100	1500
116	327	ค่าเช่ารถขุด PC60 1วัน	\N	4500	1	0	1	4500
117	331	เช่ารถขุด PC30 (วันละ)	\N	5000	1	0	5	25000
118	335	สลักบุ้งกี๋ PC20	\N	500	1	0	5	2500
119	339	ช้อนส้อม(คูา)	\N	14	1	0	500	7000
\.


--
-- Data for Name: document_running; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.document_running (id, doc_type, current_no, account_id) FROM stdin;
\.


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.documents (id, company_id, doc_no, customer_name, total, paid_amount, payment_status, doc_type, doc_date, subtotal, vat_rate, status, vat_enabled, order_id, account_id, note, customer_address, customer_phone, customer_tax_id, company_name, company_address, company_tax_id, is_locked, company_logo_url, company_phone, created_at, group_id) FROM stdin;
181	\N	INV-202603-0001	น้องนุชการค้า	9630	9630	unpaid	INV	2026-03-28	9000	0.07	paid	t	1774697717171	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	t	\N	0846661234	2026-03-31 23:21:02.399726	\N
206	\N	INV-202603-0026	น้องนุชการค้า	1815.79	0	unpaid	INV	2026-03-28	1697	0.07	draft	t	1774699709489	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
207	\N	QT-202603-0027	น้องนุชการค้า	1815.79	0	unpaid	QT	2026-03-28	1697	0.07	draft	t	1774699709489	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
208	\N	DN-202603-0028	น้องนุชการค้า	1815.79	0	unpaid	DN	2026-03-28	1697	0.07	draft	t	1774699709489	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
209	\N	RC-202603-0029	น้องนุชการค้า	1815.79	0	unpaid	RC	2026-03-28	1697	0.07	draft	t	1774699709489	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
226	\N	INV-202603-0046	อาราแต  มะดาโอ๊ะ	854.9300000000001	0	unpaid	INV	2026-03-28	799	0.07	draft	t	1774701762898	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
227	\N	QT-202603-0047	อาราแต  มะดาโอ๊ะ	854.9300000000001	0	unpaid	QT	2026-03-28	799	0.07	draft	t	1774701762898	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
228	\N	DN-202603-0048	อาราแต  มะดาโอ๊ะ	854.9300000000001	0	unpaid	DN	2026-03-28	799	0.07	draft	t	1774701762898	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
229	\N	RC-202603-0049	อาราแต  มะดาโอ๊ะ	854.9300000000001	0	unpaid	RC	2026-03-28	799	0.07	draft	t	1774701762898	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
238	\N	INV-202603-0178	หจก.ซีทีดี อินเตอร์เทรด	535	535	unpaid	INV	2026-03-31	500	0.07	paid	t	1774999312693	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774628793548-MLT_logo.png	0849197741	2026-03-31 23:21:52.64829	\N
239	\N	INV-202604-0179	ร้านบ้านทุ่ง	500	500	unpaid	INV	2026-04-02	500	0	paid	f	1775144998138	6466b94b-6852-4797-9378-7ae617809699		42 หมู่4	0541236547	1235411125474	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-02 15:49:58.128954	\N
242	\N	RC-202604-0182	ร้านบ้านทุ่ง	500	500	unpaid	RC	2026-04-02	500	0	paid	f	1775144998138	6466b94b-6852-4797-9378-7ae617809699		42 หมู่4	0541236547	1235411125474	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-02 15:49:58.128954	\N
254	\N	RC-202604-0012	สมชาย ซื้อดี	8988	0	unpaid	RC	2026-04-03	8400	0.07	draft	t	1775180276039	3b34b55e-f428-42ed-b913-32c313dfcfd9		23 หมู่7 ต.นาอาน อ.เมือง จ.เลย	0885456321	1450033362354				f	\N		2026-04-03 01:37:56.024824	c926db75-2880-4f03-b908-ffeb02507ba0
89	\N	DN-202603-0086	หจก.ซีทีดี อินเตอร์เทรด	23540	0	unpaid	DN	2026-03-26	22000	0.07	draft	t	1774535559683	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
90	\N	RC-202603-0087	หจก.ซีทีดี อินเตอร์เทรด	23540	0	unpaid	RC	2026-03-26	22000	0.07	draft	t	1774535559683	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
95	\N	INV-202603-0092	หจก.ซีทีดี อินเตอร์เทรด	535	0	unpaid	INV	2026-03-26	500	0.07	draft	t	1774538147806	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
96	\N	QT-202603-0093	หจก.ซีทีดี อินเตอร์เทรด	535	0	unpaid	QT	2026-03-26	500	0.07	draft	t	1774538147806	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
52	\N	INV-000003	ทดสอบ	428	428	\N	INV	2026-03-23	400	0.07	paid	t	1774305671644	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
4	1	INV-000001	ทดสอบ	700	0	unpaid	INV	2026-03-21	700	0	unpaid	f	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
5	1	INV-000002	ทดสอบ	700	0	unpaid	INV	2026-03-21	700	0	unpaid	f	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
7	1	INV-000004	ทดสอบ	535	0	\N	INV	2026-03-21	500	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
8	1	QT-000005	ทดสอบ	535	0	\N	QT	2026-03-21	500	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
9	1	DN-000006	ทดสอบ	535	0	\N	DN	2026-03-21	500	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
11	1	INV-000008	ทดสอบ	535	0	\N	INV	2026-03-21	500	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
12	1	QT-000009	ทดสอบ	535	0	\N	QT	2026-03-21	500	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
13	1	DN-000010	ทดสอบ	535	0	\N	DN	2026-03-21	500	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
15	1	INV-000012	ทดสอบ	535	0	\N	INV	2026-03-21	500	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
16	1	QT-000013	ทดสอบ	535	0	\N	QT	2026-03-21	500	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
17	1	DN-000014	ทดสอบ	535	0	\N	DN	2026-03-21	500	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
19	1	INV-000016	ทดสอบ	856	0	\N	INV	2026-03-21	800	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
10	1	RC-000007	ทดสอบ	535	0	\N	RC	2026-03-21	500	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
14	1	RC-000011	ทดสอบ	535	0	\N	RC	2026-03-21	500	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
91	\N	INV-202603-0088	หจก.ซีทีดี อินเตอร์เทรด	24610	0	unpaid	INV	2026-03-26	23000	0.07	draft	t	1774535607219	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
92	\N	QT-202603-0089	หจก.ซีทีดี อินเตอร์เทรด	24610	0	unpaid	QT	2026-03-26	23000	0.07	draft	t	1774535607219	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
93	\N	DN-202603-0090	หจก.ซีทีดี อินเตอร์เทรด	24610	0	unpaid	DN	2026-03-26	23000	0.07	draft	t	1774535607219	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
94	\N	RC-202603-0091	หจก.ซีทีดี อินเตอร์เทรด	24610	0	unpaid	RC	2026-03-26	23000	0.07	draft	t	1774535607219	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
76	\N	INV-000012	หจก.ซีทีดี อินเตอร์เทรด	1070	1070	\N	INV	2026-03-25	1000	0.07	paid	t	1774481416258	6466b94b-6852-4797-9378-7ae617809699		\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
77	\N	QT-000012	หจก.ซีทีดี อินเตอร์เทรด	1070	1070	\N	QT	2026-03-25	1000	0.07	paid	t	1774481416258	6466b94b-6852-4797-9378-7ae617809699		\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
97	\N	DN-202603-0094	หจก.ซีทีดี อินเตอร์เทรด	535	0	unpaid	DN	2026-03-26	500	0.07	draft	t	1774538147806	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
98	\N	RC-202603-0095	หจก.ซีทีดี อินเตอร์เทรด	535	0	unpaid	RC	2026-03-26	500	0.07	draft	t	1774538147806	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
182	\N	INV-202603-0002	สมชาย ใจดี	642	642	unpaid	INV	2026-03-28	600	0.07	paid	t	1774697770810	e588ae04-1f53-4a43-a0cf-f8d921693b18		87 หมู่13 ต.ท่าข่าม อ.เมือง จ.เลย 42000	0574111254	1450233365987	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	t	\N	0846661234	2026-03-31 23:21:02.399726	\N
129	\N	INV-202603-0126	หจก.ซีทีดี อินเตอร์เทรด	497	0	unpaid	INV	2026-03-27	497	0	draft	f	1774575936704	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
130	\N	QT-202603-0127	หจก.ซีทีดี อินเตอร์เทรด	497	0	unpaid	QT	2026-03-27	497	0	draft	f	1774575936704	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
131	\N	DN-202603-0128	หจก.ซีทีดี อินเตอร์เทรด	497	0	unpaid	DN	2026-03-27	497	0	draft	f	1774575936704	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
132	\N	RC-202603-0129	หจก.ซีทีดี อินเตอร์เทรด	497	0	unpaid	RC	2026-03-27	497	0	draft	f	1774575936704	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
139	\N	INV-202603-0136	หจก.ซีทีดี อินเตอร์เทรด	8560	0	unpaid	INV	2026-03-27	8000	0.07	draft	t	1774591214387	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
140	\N	RC-202603-0137	หจก.ซีทีดี อินเตอร์เทรด	8560	0	unpaid	RC	2026-03-27	8000	0.07	draft	t	1774591214387	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
141	\N	DN-202603-0138	หจก.ซีทีดี อินเตอร์เทรด	8560	0	unpaid	DN	2026-03-27	8000	0.07	draft	t	1774591214387	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
142	\N	QT-202603-0139	หจก.ซีทีดี อินเตอร์เทรด	8560	0	unpaid	QT	2026-03-27	8000	0.07	draft	t	1774591214387	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
69	\N	DN-000009	ทดสอบ2	53500	53500	\N	DN	2026-03-25	50000	0.07	paid	t	1774410998425	6466b94b-6852-4797-9378-7ae617809699	บ้านนาดินดำ 5วัน	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
70	\N	RC-000009	ทดสอบ2	53500	53500	\N	RC	2026-03-25	50000	0.07	paid	t	1774410998425	6466b94b-6852-4797-9378-7ae617809699	บ้านนาดินดำ 5วัน	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
75	\N	INV-000011	หจก.ซีทีดี อินเตอร์เทรด	17644.3	17644.3	\N	INV	2026-03-25	16490	0.07	paid	t	1774480643678	6466b94b-6852-4797-9378-7ae617809699		\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
62	\N	INV-000007	ทดสอบ2	642	642	\N	INV	2026-03-24	600	0.07	paid	t	1774312687291	6466b94b-6852-4797-9378-7ae617809699	โปรกรับประทานภายใน 3วัน	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
63	\N	QT-000007	ทดสอบ2	642	642	\N	QT	2026-03-24	600	0.07	paid	t	1774312687291	6466b94b-6852-4797-9378-7ae617809699	โปรกรับประทานภายใน 3วัน	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
99	\N	INV-202603-0096	หจก.ซีทีดี อินเตอร์เทรด	214000	0	unpaid	INV	2026-03-26	200000	0.07	draft	t	1774539107252	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
100	\N	QT-202603-0097	หจก.ซีทีดี อินเตอร์เทรด	214000	0	unpaid	QT	2026-03-26	200000	0.07	draft	t	1774539107252	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
101	\N	DN-202603-0098	หจก.ซีทีดี อินเตอร์เทรด	214000	0	unpaid	DN	2026-03-26	200000	0.07	draft	t	1774539107252	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
102	\N	RC-202603-0099	หจก.ซีทีดี อินเตอร์เทรด	214000	0	unpaid	RC	2026-03-26	200000	0.07	draft	t	1774539107252	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
115	\N	INV-202603-0112	หจก.ซีทีดี อินเตอร์เทรด	6420	0	unpaid	INV	2026-03-27	6000	0.07	draft	t	1774572590608	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต2 จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
116	\N	RC-202603-0113	หจก.ซีทีดี อินเตอร์เทรด	6420	0	unpaid	RC	2026-03-27	6000	0.07	draft	t	1774572590608	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต2 จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
133	\N	INV-202603-0130	หจก.ซีทีดี อินเตอร์เทรด	535	0	unpaid	INV	2026-03-27	500	0.07	draft	t	1774587031573	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
134	\N	RC-202603-0131	หจก.ซีทีดี อินเตอร์เทรด	535	0	unpaid	RC	2026-03-27	500	0.07	draft	t	1774587031573	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
143	\N	INV-202603-0140	หจก.ซีทีดี อินเตอร์เทรด	428	0	unpaid	INV	2026-03-27	400	0.07	draft	t	1774592645196	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
144	\N	QT-202603-0141	หจก.ซีทีดี อินเตอร์เทรด	428	0	unpaid	QT	2026-03-27	400	0.07	draft	t	1774592645196	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
145	\N	DN-202603-0142	หจก.ซีทีดี อินเตอร์เทรด	428	0	unpaid	DN	2026-03-27	400	0.07	draft	t	1774592645196	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
146	\N	RC-202603-0143	หจก.ซีทีดี อินเตอร์เทรด	428	0	unpaid	RC	2026-03-27	400	0.07	draft	t	1774592645196	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
80	\N	INV-000013	หจก.ซีทีดี อินเตอร์เทรด	2140	2140	\N	INV	2026-03-25	2000	0.07	paid	t	1774481839867	6466b94b-6852-4797-9378-7ae617809699		\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
81	\N	QT-000013	หจก.ซีทีดี อินเตอร์เทรด	2140	2140	\N	QT	2026-03-25	2000	0.07	paid	t	1774481839867	6466b94b-6852-4797-9378-7ae617809699		\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
82	\N	DN-000013	หจก.ซีทีดี อินเตอร์เทรด	2140	2140	\N	DN	2026-03-25	2000	0.07	paid	t	1774481839867	6466b94b-6852-4797-9378-7ae617809699		\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
64	\N	DN-000007	ทดสอบ2	642	642	\N	DN	2026-03-24	600	0.07	paid	t	1774312687291	6466b94b-6852-4797-9378-7ae617809699	โปรกรับประทานภายใน 3วัน	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
86	\N	RC-000014	หจก.ซีทีดี อินเตอร์เทรด	24075	24075	\N	RC	2026-03-26	22500	0.07	paid	t	1774509931496	6466b94b-6852-4797-9378-7ae617809699		\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
57	\N	INV-000005	ทดสอบ2	628.09	628.09	\N	INV	2026-03-23	587	0.07	paid	t	1774306288230	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
243	\N	INV-202604-0001	ทดสอบ	535	0	unpaid	INV	2026-04-03	500	0.07	draft	t	1775179399018	3b34b55e-f428-42ed-b913-32c313dfcfd9								f	\N		2026-04-03 01:23:19.008319	\N
103	\N	INV-202603-0100	หจก.ซีทีดี อินเตอร์เทรด	4280	0	unpaid	INV	2026-03-26	4000	0.07	draft	t	1774539580879	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
104	\N	DN-202603-0101	หจก.ซีทีดี อินเตอร์เทรด	4280	0	unpaid	DN	2026-03-26	4000	0.07	draft	t	1774539580879	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
105	\N	QT-202603-0102	หจก.ซีทีดี อินเตอร์เทรด	4280	0	unpaid	QT	2026-03-26	4000	0.07	draft	t	1774539580879	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
106	\N	RC-202603-0103	หจก.ซีทีดี อินเตอร์เทรด	4280	0	unpaid	RC	2026-03-26	4000	0.07	draft	t	1774539580879	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
117	\N	INV-202603-0114	หจก.ซีทีดี อินเตอร์เทรด	927.69	0	unpaid	INV	2026-03-27	867	0.07	draft	t	1774575157153	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต3 จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
118	\N	QT-202603-0115	หจก.ซีทีดี อินเตอร์เทรด	927.69	0	unpaid	QT	2026-03-27	867	0.07	draft	t	1774575157153	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต3 จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
119	\N	DN-202603-0116	หจก.ซีทีดี อินเตอร์เทรด	927.69	0	unpaid	DN	2026-03-27	867	0.07	draft	t	1774575157153	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต3 จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
120	\N	RC-202603-0117	หจก.ซีทีดี อินเตอร์เทรด	927.69	0	unpaid	RC	2026-03-27	867	0.07	draft	t	1774575157153	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต3 จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
135	\N	INV-202603-0132	หจก.ซีทีดี อินเตอร์เทรด	496	0	unpaid	INV	2026-03-27	496	0	draft	f	1774587515723	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
136	\N	RC-202603-0133	หจก.ซีทีดี อินเตอร์เทรด	496	0	unpaid	RC	2026-03-27	496	0	draft	f	1774587515723	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
147	\N	INV-202603-0144	หจก.ซีทีดี อินเตอร์เทรด	5350	0	unpaid	INV	2026-03-27	5000	0.07	draft	t	1774594976579	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
148	\N	QT-202603-0145	หจก.ซีทีดี อินเตอร์เทรด	5350	0	unpaid	QT	2026-03-27	5000	0.07	draft	t	1774594976579	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
149	\N	DN-202603-0146	หจก.ซีทีดี อินเตอร์เทรด	5350	0	unpaid	DN	2026-03-27	5000	0.07	draft	t	1774594976579	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
150	\N	RC-202603-0147	หจก.ซีทีดี อินเตอร์เทรด	5350	0	unpaid	RC	2026-03-27	5000	0.07	draft	t	1774594976579	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
47	\N	RC-000001	ทดสอบ	535	535	\N	RC	2026-03-23	500	0.07	paid	t	1774271998078	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
18	1	RC-000015	ทดสอบ	535	535	\N	RC	2026-03-21	500	0.07	paid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
65	\N	RC-000007	ทดสอบ2	642	642	\N	RC	2026-03-24	600	0.07	paid	t	1774312687291	6466b94b-6852-4797-9378-7ae617809699	โปรกรับประทานภายใน 3วัน	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
112	\N	QT-202603-0109	หจก.ซีทีดี อินเตอร์เทรด	29960	29960	unpaid	QT	2026-03-26	28000	0.07	paid	t	1774567270999	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
107	\N	INV-202603-0104	หจก.ซีทีดี อินเตอร์เทรด	5885	0	unpaid	INV	2026-03-26	5500	0.07	draft	t	1774566967891	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
108	\N	QT-202603-0105	หจก.ซีทีดี อินเตอร์เทรด	5885	0	unpaid	QT	2026-03-26	5500	0.07	draft	t	1774566967891	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
109	\N	DN-202603-0106	หจก.ซีทีดี อินเตอร์เทรด	5885	0	unpaid	DN	2026-03-26	5500	0.07	draft	t	1774566967891	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
110	\N	RC-202603-0107	หจก.ซีทีดี อินเตอร์เทรด	5885	0	unpaid	RC	2026-03-26	5500	0.07	draft	t	1774566967891	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
121	\N	INV-202603-0118	ทดสอบ2	856	0	unpaid	INV	2026-03-27	800	0.07	draft	t	1774575371389	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6	0849197741	1420500036598	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
122	\N	QT-202603-0119	ทดสอบ2	856	0	unpaid	QT	2026-03-27	800	0.07	draft	t	1774575371389	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6	0849197741	1420500036598	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
123	\N	DN-202603-0120	ทดสอบ2	856	0	unpaid	DN	2026-03-27	800	0.07	draft	t	1774575371389	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6	0849197741	1420500036598	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
124	\N	RC-202603-0121	ทดสอบ2	856	0	unpaid	RC	2026-03-27	800	0.07	draft	t	1774575371389	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6	0849197741	1420500036598	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
137	\N	INV-202603-0134	หจก.ซีทีดี อินเตอร์เทรด	5000	0	unpaid	INV	2026-03-27	5000	0	draft	f	1774587953916	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
138	\N	RC-202603-0135	หจก.ซีทีดี อินเตอร์เทรด	5000	0	unpaid	RC	2026-03-27	5000	0	draft	f	1774587953916	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
44	\N	INV-000001	ทดสอบ	535	535	\N	INV	2026-03-23	500	0.07	paid	t	1774271998078	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
45	\N	QT-000001	ทดสอบ	535	535	\N	QT	2026-03-23	500	0.07	paid	t	1774271998078	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
46	\N	DN-000001	ทดสอบ	535	535	\N	DN	2026-03-23	500	0.07	paid	t	1774271998078	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
6	1	INV-000003	ทดสอบ	700	700	unpaid	INV	2026-03-21	700	0	paid	f	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
67	\N	INV-000009	ทดสอบ2	53500	53500	\N	INV	2026-03-25	50000	0.07	paid	t	1774410998425	6466b94b-6852-4797-9378-7ae617809699	บ้านนาดินดำ 5วัน	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
183	\N	QT-202603-0003	สมชาย ใจดี	642	642	unpaid	QT	2026-03-28	600	0.07	paid	t	1774697770810	e588ae04-1f53-4a43-a0cf-f8d921693b18		87 หมู่13 ต.ท่าข่าม อ.เมือง จ.เลย 42000	0574111254	1450233365987	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	t	\N	0846661234	2026-03-31 23:21:02.399726	\N
184	\N	DN-202603-0004	สมชาย ใจดี	642	642	unpaid	DN	2026-03-28	600	0.07	paid	t	1774697770810	e588ae04-1f53-4a43-a0cf-f8d921693b18		87 หมู่13 ต.ท่าข่าม อ.เมือง จ.เลย 42000	0574111254	1450233365987	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	t	\N	0846661234	2026-03-31 23:21:02.399726	\N
185	\N	RC-202603-0005	สมชาย ใจดี	642	642	unpaid	RC	2026-03-28	600	0.07	paid	t	1774697770810	e588ae04-1f53-4a43-a0cf-f8d921693b18		87 หมู่13 ต.ท่าข่าม อ.เมือง จ.เลย 42000	0574111254	1450233365987	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	t	\N	0846661234	2026-03-31 23:21:02.399726	\N
244	\N	QT-202604-0002	ทดสอบ	535	0	unpaid	QT	2026-04-03	500	0.07	draft	t	1775179399018	3b34b55e-f428-42ed-b913-32c313dfcfd9								f	\N		2026-04-03 01:23:19.008319	\N
245	\N	DN-202604-0003	ทดสอบ	535	0	unpaid	DN	2026-04-03	500	0.07	draft	t	1775179399018	3b34b55e-f428-42ed-b913-32c313dfcfd9								f	\N		2026-04-03 01:23:19.008319	\N
20	1	QT-000017	ทดสอบ	856	0	\N	QT	2026-03-21	800	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
21	1	DN-000018	ทดสอบ	856	0	\N	DN	2026-03-21	800	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
186	\N	QT-202603-0006	น้องนุชการค้า	178.69	0	unpaid	QT	2026-03-28	167	0.07	draft	t	1774697984692	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
187	\N	DN-202603-0007	น้องนุชการค้า	178.69	0	unpaid	DN	2026-03-28	167	0.07	draft	t	1774697984692	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
188	\N	INV-202603-0008	น้องนุชการค้า	178.69	0	unpaid	INV	2026-03-28	167	0.07	draft	t	1774697984692	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
189	\N	RC-202603-0009	น้องนุชการค้า	178.69	0	unpaid	RC	2026-03-28	167	0.07	draft	t	1774697984692	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
210	\N	QT-202603-0030	น้องนุชการค้า	3852	0	unpaid	QT	2026-03-28	3600	0.07	draft	t	1774699729828	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
211	\N	DN-202603-0031	น้องนุชการค้า	3852	0	unpaid	DN	2026-03-28	3600	0.07	draft	t	1774699729828	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
212	\N	INV-202603-0032	น้องนุชการค้า	3852	0	unpaid	INV	2026-03-28	3600	0.07	draft	t	1774699729828	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
213	\N	RC-202603-0033	น้องนุชการค้า	3852	0	unpaid	RC	2026-03-28	3600	0.07	draft	t	1774699729828	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
230	\N	INV-202603-0050	น้องนุชการค้า	1284	0	unpaid	INV	2026-03-28	1200	0.07	draft	t	1774701782756	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
231	\N	QT-202603-0051	น้องนุชการค้า	1284	0	unpaid	QT	2026-03-28	1200	0.07	draft	t	1774701782756	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
232	\N	DN-202603-0052	น้องนุชการค้า	1284	0	unpaid	DN	2026-03-28	1200	0.07	draft	t	1774701782756	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
233	\N	RC-202603-0053	น้องนุชการค้า	1284	0	unpaid	RC	2026-03-28	1200	0.07	draft	t	1774701782756	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
48	\N	INV-000002	ทดสอบ	856	856	\N	INV	2026-03-23	800	0.07	paid	t	1774272059923	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
246	\N	RC-202604-0004	ทดสอบ	535	0	unpaid	RC	2026-04-03	500	0.07	draft	t	1775179399018	3b34b55e-f428-42ed-b913-32c313dfcfd9								f	\N		2026-04-03 01:23:19.008319	\N
22	1	RC-000019	ทดสอบ	856	0	\N	RC	2026-03-21	800	0.07	unpaid	t	\N	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
78	\N	DN-000012	หจก.ซีทีดี อินเตอร์เทรด	1070	1070	\N	DN	2026-03-25	1000	0.07	paid	t	1774481416258	6466b94b-6852-4797-9378-7ae617809699		\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
79	\N	RC-000012	หจก.ซีทีดี อินเตอร์เทรด	1070	1070	\N	RC	2026-03-25	1000	0.07	paid	t	1774481416258	6466b94b-6852-4797-9378-7ae617809699		\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
190	\N	INV-202603-0010	สมชาย ใจดี	535	0	unpaid	INV	2026-03-28	500	0.07	draft	t	1774698013290	e588ae04-1f53-4a43-a0cf-f8d921693b18		87 หมู่13 ต.ท่าข่าม อ.เมือง จ.เลย 42000	0574111254	1450233365987	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
191	\N	QT-202603-0011	สมชาย ใจดี	535	0	unpaid	QT	2026-03-28	500	0.07	draft	t	1774698013290	e588ae04-1f53-4a43-a0cf-f8d921693b18		87 หมู่13 ต.ท่าข่าม อ.เมือง จ.เลย 42000	0574111254	1450233365987	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
192	\N	DN-202603-0012	สมชาย ใจดี	535	0	unpaid	DN	2026-03-28	500	0.07	draft	t	1774698013290	e588ae04-1f53-4a43-a0cf-f8d921693b18		87 หมู่13 ต.ท่าข่าม อ.เมือง จ.เลย 42000	0574111254	1450233365987	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
193	\N	RC-202603-0013	สมชาย ใจดี	535	0	unpaid	RC	2026-03-28	500	0.07	draft	t	1774698013290	e588ae04-1f53-4a43-a0cf-f8d921693b18		87 หมู่13 ต.ท่าข่าม อ.เมือง จ.เลย 42000	0574111254	1450233365987	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
214	\N	INV-202603-0034	อาราแต  มะดาโอ๊ะ	93625	0	unpaid	INV	2026-03-28	87500	0.07	draft	t	1774699760686	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
215	\N	DN-202603-0035	อาราแต  มะดาโอ๊ะ	93625	0	unpaid	DN	2026-03-28	87500	0.07	draft	t	1774699760686	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
216	\N	QT-202603-0036	อาราแต  มะดาโอ๊ะ	93625	0	unpaid	QT	2026-03-28	87500	0.07	draft	t	1774699760686	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
217	\N	RC-202603-0037	อาราแต  มะดาโอ๊ะ	93625	0	unpaid	RC	2026-03-28	87500	0.07	draft	t	1774699760686	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
234	\N	INV-202603-0054	น้องนุชการค้า	800	0	unpaid	INV	2026-03-28	800	0	draft	f	1774701809143	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
235	\N	QT-202603-0055	น้องนุชการค้า	800	0	unpaid	QT	2026-03-28	800	0	draft	f	1774701809143	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
236	\N	DN-202603-0056	น้องนุชการค้า	800	0	unpaid	DN	2026-03-28	800	0	draft	f	1774701809143	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
87	\N	INV-202603-0084	หจก.ซีทีดี อินเตอร์เทรด	23540	0	unpaid	INV	2026-03-26	22000	0.07	draft	t	1774535559683	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
88	\N	QT-202603-0085	หจก.ซีทีดี อินเตอร์เทรด	23540	0	unpaid	QT	2026-03-26	22000	0.07	draft	t	1774535559683	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	\N	\N	2026-03-31 23:21:02.399726	\N
125	\N	INV-202603-0122	ทดสอบ	214	0	unpaid	INV	2026-03-27	200	0.07	draft	t	1774575701727	6466b94b-6852-4797-9378-7ae617809699			0849197741		บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
126	\N	QT-202603-0123	ทดสอบ	214	0	unpaid	QT	2026-03-27	200	0.07	draft	t	1774575701727	6466b94b-6852-4797-9378-7ae617809699			0849197741		บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
127	\N	DN-202603-0124	ทดสอบ	214	0	unpaid	DN	2026-03-27	200	0.07	draft	t	1774575701727	6466b94b-6852-4797-9378-7ae617809699			0849197741		บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
128	\N	RC-202603-0125	ทดสอบ	214	0	unpaid	RC	2026-03-27	200	0.07	draft	t	1774575701727	6466b94b-6852-4797-9378-7ae617809699			0849197741		บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	\N	2026-03-31 23:21:02.399726	\N
68	\N	QT-000009	ทดสอบ2	53500	53500	\N	QT	2026-03-25	50000	0.07	paid	t	1774410998425	6466b94b-6852-4797-9378-7ae617809699	บ้านนาดินดำ 5วัน	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
113	\N	DN-202603-0110	หจก.ซีทีดี อินเตอร์เทรด	29960	29960	unpaid	DN	2026-03-26	28000	0.07	paid	t	1774567270999	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
114	\N	RC-202603-0111	หจก.ซีทีดี อินเตอร์เทรด	29960	29960	unpaid	RC	2026-03-26	28000	0.07	paid	t	1774567270999	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
36	1	INV-000024	ทดสอบ	535	535	\N	INV	2026-03-22	500	0.07	paid	t	1774139465928	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
37	1	QT-000024	ทดสอบ	535	535	\N	QT	2026-03-22	500	0.07	paid	t	1774139465928	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
38	1	DN-000024	ทดสอบ	535	535	\N	DN	2026-03-22	500	0.07	paid	t	1774139465928	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
40	1	INV-000025	ทดสอบ	535	535	\N	INV	2026-03-22	500	0.07	paid	t	1774145334929	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
42	1	DN-000025	ทดสอบ	535	535	\N	DN	2026-03-22	500	0.07	paid	t	1774145334929	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
43	1	QT-000025	ทดสอบ	535	535	\N	QT	2026-03-22	500	0.07	paid	t	1774145334929	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
25	1	QT-000021	ทดสอบ	832.46	832.46	\N	QT	2026-03-21	778	0.07	paid	t	1774094710070	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
26	1	DN-000021	ทดสอบ	832.46	832.46	\N	DN	2026-03-21	778	0.07	paid	t	1774094710070	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
24	1	INV-000021	ทดสอบ	832.46	832.46	\N	INV	2026-03-21	778	0.07	paid	t	1774094710070	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
23	1	INV-000020	ทดสอบ	856	856	\N	INV	2026-03-21	800	0.07	paid	t	1774094502331	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
28	1	INV-000022	ทดสอบ	43870	43870	\N	INV	2026-03-21	41000	0.07	paid	t	1774104537601	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
29	1	QT-000022	ทดสอบ	43870	43870	\N	QT	2026-03-21	41000	0.07	paid	t	1774104537601	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
30	1	DN-000022	ทดสอบ	43870	43870	\N	DN	2026-03-21	41000	0.07	paid	t	1774104537601	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
32	1	INV-000023	ทดสอบ	5350	5350	\N	INV	2026-03-21	5000	0.07	paid	t	1774104980569	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
33	1	QT-000023	ทดสอบ	5350	5350	\N	QT	2026-03-21	5000	0.07	paid	t	1774104980569	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
34	1	DN-000023	ทดสอบ	5350	5350	\N	DN	2026-03-21	5000	0.07	paid	t	1774104980569	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
58	\N	INV-000006	ทดสอบ2	1605	1605	\N	INV	2026-03-23	1500	0.07	paid	t	1774306350311	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
59	\N	QT-000006	ทดสอบ2	1605	1605	\N	QT	2026-03-23	1500	0.07	paid	t	1774306350311	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
60	\N	DN-000006	ทดสอบ2	1605	1605	\N	DN	2026-03-23	1500	0.07	paid	t	1774306350311	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
53	\N	INV-000004	ทดสอบ	481.5	481.5	\N	INV	2026-03-23	450	0.07	paid	t	1774305699511	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
55	\N	DN-000004	ทดสอบ	481.5	481.5	\N	DN	2026-03-23	450	0.07	paid	t	1774305699511	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
56	\N	QT-000004	ทดสอบ	481.5	481.5	\N	QT	2026-03-23	450	0.07	paid	t	1774305699511	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
39	1	RC-000024	ทดสอบ	535	535	\N	RC	2026-03-22	500	0.07	paid	t	1774139465928	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
41	1	RC-000025	ทดสอบ	535	535	\N	RC	2026-03-22	500	0.07	paid	t	1774145334929	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
27	1	RC-000021	ทดสอบ	832.46	832.46	\N	RC	2026-03-21	778	0.07	paid	t	1774094710070	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
31	1	RC-000022	ทดสอบ	43870	43870	\N	RC	2026-03-21	41000	0.07	paid	t	1774104537601	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
35	1	RC-000023	ทดสอบ	5350	5350	\N	RC	2026-03-21	5000	0.07	paid	t	1774104980569	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
61	\N	RC-000006	ทดสอบ2	1605	1605	\N	RC	2026-03-23	1500	0.07	paid	t	1774306350311	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
54	\N	RC-000004	ทดสอบ	481.5	481.5	\N	RC	2026-03-23	450	0.07	paid	t	1774305699511	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
66	\N	INV-000008	ทดสอบ2	81106	81106	\N	INV	2026-03-24	75800	0.07	paid	t	1774356491628	6466b94b-6852-4797-9378-7ae617809699		\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
71	\N	INV-000010	ทดสอบ2	374500	374500	\N	INV	2026-03-25	350000	0.07	paid	t	1774479478672	6466b94b-6852-4797-9378-7ae617809699	ผลไม้แม่ลำใย	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
72	\N	QT-000010	ทดสอบ2	374500	374500	\N	QT	2026-03-25	350000	0.07	paid	t	1774479478672	6466b94b-6852-4797-9378-7ae617809699	ผลไม้แม่ลำใย	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
73	\N	DN-000010	ทดสอบ2	374500	374500	\N	DN	2026-03-25	350000	0.07	paid	t	1774479478672	6466b94b-6852-4797-9378-7ae617809699	ผลไม้แม่ลำใย	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
74	\N	RC-000010	ทดสอบ2	374500	374500	\N	RC	2026-03-25	350000	0.07	paid	t	1774479478672	6466b94b-6852-4797-9378-7ae617809699	ผลไม้แม่ลำใย	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
83	\N	INV-000014	หจก.ซีทีดี อินเตอร์เทรด	24075	24075	\N	INV	2026-03-26	22500	0.07	paid	t	1774509931496	6466b94b-6852-4797-9378-7ae617809699		\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
84	\N	QT-000014	หจก.ซีทีดี อินเตอร์เทรด	24075	24075	\N	QT	2026-03-26	22500	0.07	paid	t	1774509931496	6466b94b-6852-4797-9378-7ae617809699		\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
85	\N	DN-000014	หจก.ซีทีดี อินเตอร์เทรด	24075	24075	\N	DN	2026-03-26	22500	0.07	paid	t	1774509931496	6466b94b-6852-4797-9378-7ae617809699		\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
111	\N	INV-202603-0108	หจก.ซีทีดี อินเตอร์เทรด	29960	29960	unpaid	INV	2026-03-26	28000	0.07	paid	t	1774567270999	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
194	\N	INV-202603-0014	อาราแต  มะดาโอ๊ะ	2889	0	unpaid	INV	2026-03-28	2700	0.07	draft	t	1774698082245	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
195	\N	QT-202603-0015	อาราแต  มะดาโอ๊ะ	2889	0	unpaid	QT	2026-03-28	2700	0.07	draft	t	1774698082245	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
196	\N	DN-202603-0016	อาราแต  มะดาโอ๊ะ	2889	0	unpaid	DN	2026-03-28	2700	0.07	draft	t	1774698082245	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
197	\N	RC-202603-0017	อาราแต  มะดาโอ๊ะ	2889	0	unpaid	RC	2026-03-28	2700	0.07	draft	t	1774698082245	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
259	\N	INV-202604-0001	ทดสอบ	26750	0	unpaid	INV	2026-04-03	25000	0.07	draft	t	1775182326706	ccaf622d-3ecc-4a57-9055-25c5c292cd2b								f	\N		2026-04-03 02:12:06.694066	ad8c6545-a625-45a9-ab0a-087d7a558b94
151	\N	INV-202603-0148	หจก.ซีทีดี อินเตอร์เทรด	852.79	0	unpaid	INV	2026-03-27	797	0.07	cancelled	t	1774597521911	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
152	\N	QT-202603-0149	หจก.ซีทีดี อินเตอร์เทรด	852.79	0	unpaid	QT	2026-03-27	797	0.07	cancelled	t	1774597521911	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
155	\N	INV-202603-0152	หจก.ซีทีดี อินเตอร์เทรด	8560	0	unpaid	INV	2026-03-27	8000	0.07	cancelled	t	1774597921325	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
156	\N	RC-202603-0153	หจก.ซีทีดี อินเตอร์เทรด	8560	0	unpaid	RC	2026-03-27	8000	0.07	cancelled	t	1774597921325	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
157	\N	INV-202603-0154	หจก.ซีทีดี อินเตอร์เทรด	25680	0	unpaid	INV	2026-03-27	24000	0.07	draft	t	1774625848010	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
158	\N	QT-202603-0155	หจก.ซีทีดี อินเตอร์เทรด	25680	0	unpaid	QT	2026-03-27	24000	0.07	draft	t	1774625848010	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
159	\N	DN-202603-0156	หจก.ซีทีดี อินเตอร์เทรด	25680	0	unpaid	DN	2026-03-27	24000	0.07	draft	t	1774625848010	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
160	\N	RC-202603-0157	หจก.ซีทีดี อินเตอร์เทรด	25680	0	unpaid	RC	2026-03-27	24000	0.07	draft	t	1774625848010	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
153	\N	DN-202603-0150	หจก.ซีทีดี อินเตอร์เทรด	852.79	0	unpaid	DN	2026-03-27	797	0.07	cancelled	t	1774597521911	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
154	\N	RC-202603-0151	หจก.ซีทีดี อินเตอร์เทรด	852.79	0	unpaid	RC	2026-03-27	797	0.07	cancelled	t	1774597521911	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774327832094-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
161	\N	QT-202603-0158	ร้านบ้านทุ่ง	12840	0	unpaid	QT	2026-03-27	12000	0.07	draft	t	1774627447453	6466b94b-6852-4797-9378-7ae617809699		42 หมู่4	0541236547	1235411125474	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774627412526-0000.png	0849197741	2026-03-31 23:21:02.399726	\N
162	\N	DN-202603-0159	ร้านบ้านทุ่ง	12840	0	unpaid	DN	2026-03-27	12000	0.07	draft	t	1774627447453	6466b94b-6852-4797-9378-7ae617809699		42 หมู่4	0541236547	1235411125474	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774627412526-0000.png	0849197741	2026-03-31 23:21:02.399726	\N
163	\N	RC-202603-0160	ร้านบ้านทุ่ง	12840	0	unpaid	RC	2026-03-27	12000	0.07	draft	t	1774627447453	6466b94b-6852-4797-9378-7ae617809699		42 หมู่4	0541236547	1235411125474	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774627412526-0000.png	0849197741	2026-03-31 23:21:02.399726	\N
164	\N	INV-202603-0161	ร้านบ้านทุ่ง	12840	0	unpaid	INV	2026-03-27	12000	0.07	draft	t	1774627447453	6466b94b-6852-4797-9378-7ae617809699		42 หมู่4	0541236547	1235411125474	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774627412526-0000.png	0849197741	2026-03-31 23:21:02.399726	\N
165	\N	INV-202603-0162	หจก.ซีทีดี อินเตอร์เทรด	10700	0	unpaid	INV	2026-03-27	10000	0.07	draft	t	1774628050427	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774627412526-0000.png	0849197741	2026-03-31 23:21:02.399726	\N
166	\N	QT-202603-0163	หจก.ซีทีดี อินเตอร์เทรด	10700	0	unpaid	QT	2026-03-27	10000	0.07	draft	t	1774628050427	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774627412526-0000.png	0849197741	2026-03-31 23:21:02.399726	\N
167	\N	DN-202603-0164	หจก.ซีทีดี อินเตอร์เทรด	10700	0	unpaid	DN	2026-03-27	10000	0.07	draft	t	1774628050427	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774627412526-0000.png	0849197741	2026-03-31 23:21:02.399726	\N
168	\N	RC-202603-0165	หจก.ซีทีดี อินเตอร์เทรด	10700	0	unpaid	RC	2026-03-27	10000	0.07	draft	t	1774628050427	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774627412526-0000.png	0849197741	2026-03-31 23:21:02.399726	\N
198	\N	INV-202603-0018	อาราแต  มะดาโอ๊ะ	853.86	0	unpaid	INV	2026-03-28	798	0.07	draft	t	1774698136065	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
247	\N	INV-202604-0005	สมชาย ซื้อดี	28890	0	unpaid	INV	2026-04-03	27000	0.07	draft	t	1775180247521	3b34b55e-f428-42ed-b913-32c313dfcfd9		23 หมู่7 ต.นาอาน อ.เมือง จ.เลย	0885456321	1450033362354				f	\N		2026-04-03 01:37:27.506004	e3803102-89ec-441f-a37c-af9f8a70a235
199	\N	QT-202603-0019	อาราแต  มะดาโอ๊ะ	853.86	0	unpaid	QT	2026-03-28	798	0.07	draft	t	1774698136065	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
200	\N	RC-202603-0020	อาราแต  มะดาโอ๊ะ	853.86	0	unpaid	RC	2026-03-28	798	0.07	draft	t	1774698136065	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
201	\N	DN-202603-0021	อาราแต  มะดาโอ๊ะ	853.86	0	unpaid	DN	2026-03-28	798	0.07	draft	t	1774698136065	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
169	\N	INV-202603-0166	หจก.ซีทีดี อินเตอร์เทรด	535	535	unpaid	INV	2026-03-27	500	0.07	paid	t	1774628840182	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774628793548-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
170	\N	QT-202603-0167	หจก.ซีทีดี อินเตอร์เทรด	535	535	unpaid	QT	2026-03-27	500	0.07	paid	t	1774628840182	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774628793548-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
171	\N	DN-202603-0168	หจก.ซีทีดี อินเตอร์เทรด	535	535	unpaid	DN	2026-03-27	500	0.07	paid	t	1774628840182	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774628793548-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
172	\N	RC-202603-0169	หจก.ซีทีดี อินเตอร์เทรด	535	535	unpaid	RC	2026-03-27	500	0.07	paid	t	1774628840182	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774628793548-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
173	\N	INV-202603-0170	หจก.ซีทีดี อินเตอร์เทรด	18725	0	unpaid	INV	2026-03-28	17500	0.07	draft	t	1774660599078	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774628793548-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
174	\N	QT-202603-0171	หจก.ซีทีดี อินเตอร์เทรด	18725	0	unpaid	QT	2026-03-28	17500	0.07	draft	t	1774660599078	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774628793548-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
175	\N	DN-202603-0172	หจก.ซีทีดี อินเตอร์เทรด	18725	0	unpaid	DN	2026-03-28	17500	0.07	draft	t	1774660599078	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774628793548-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
176	\N	RC-202603-0173	หจก.ซีทีดี อินเตอร์เทรด	18725	0	unpaid	RC	2026-03-28	17500	0.07	draft	t	1774660599078	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	/uploads/logos/1774628793548-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
218	\N	INV-202603-0038	อาราแต  มะดาโอ๊ะ	530.72	0	unpaid	INV	2026-03-28	496	0.07	draft	t	1774699886343	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
219	\N	QT-202603-0039	อาราแต  มะดาโอ๊ะ	530.72	0	unpaid	QT	2026-03-28	496	0.07	draft	t	1774699886343	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
220	\N	DN-202603-0040	อาราแต  มะดาโอ๊ะ	530.72	0	unpaid	DN	2026-03-28	496	0.07	draft	t	1774699886343	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
221	\N	RC-202603-0041	อาราแต  มะดาโอ๊ะ	530.72	0	unpaid	RC	2026-03-28	496	0.07	draft	t	1774699886343	e588ae04-1f53-4a43-a0cf-f8d921693b18		52 หมู่7 ต.มะแวะ อ.มะโอ๊ะ จ.นาราธิวาส 88540	0654412325	1457800025469	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
177	\N	INV-202603-0174	หจก.ซีทีดี อินเตอร์เทรด	2889	2889	unpaid	INV	2026-03-28	2700	0.07	paid	t	1774661034044	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774628793548-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
248	\N	QT-202604-0006	สมชาย ซื้อดี	28890	0	unpaid	QT	2026-04-03	27000	0.07	draft	t	1775180247521	3b34b55e-f428-42ed-b913-32c313dfcfd9		23 หมู่7 ต.นาอาน อ.เมือง จ.เลย	0885456321	1450033362354				f	\N		2026-04-03 01:37:27.506004	e3803102-89ec-441f-a37c-af9f8a70a235
178	\N	QT-202603-0175	หจก.ซีทีดี อินเตอร์เทรด	2889	2889	unpaid	QT	2026-03-28	2700	0.07	paid	t	1774661034044	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774628793548-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
179	\N	DN-202603-0176	หจก.ซีทีดี อินเตอร์เทรด	2889	2889	unpaid	DN	2026-03-28	2700	0.07	paid	t	1774661034044	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774628793548-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
180	\N	RC-202603-0177	หจก.ซีทีดี อินเตอร์เทรด	2889	2889	unpaid	RC	2026-03-28	2700	0.07	paid	t	1774661034044	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	/uploads/logos/1774628793548-MLT_logo.png	0849197741	2026-03-31 23:21:02.399726	\N
202	\N	INV-202603-0022	วินัย ใจดี	5350	0	unpaid	INV	2026-03-28	5000	0.07	draft	t	1774699655139	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่9 ต.บ้านหม้อ องเมือง จ.สระบุรี 21320	0845552361	1430022269874	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
203	\N	QT-202603-0023	วินัย ใจดี	5350	0	unpaid	QT	2026-03-28	5000	0.07	draft	t	1774699655139	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่9 ต.บ้านหม้อ องเมือง จ.สระบุรี 21320	0845552361	1430022269874	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
204	\N	DN-202603-0024	วินัย ใจดี	5350	0	unpaid	DN	2026-03-28	5000	0.07	draft	t	1774699655139	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่9 ต.บ้านหม้อ องเมือง จ.สระบุรี 21320	0845552361	1430022269874	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
205	\N	RC-202603-0025	วินัย ใจดี	5350	0	unpaid	RC	2026-03-28	5000	0.07	draft	t	1774699655139	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่9 ต.บ้านหม้อ องเมือง จ.สระบุรี 21320	0845552361	1430022269874	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	\N	0846661234	2026-03-31 23:21:02.399726	\N
222	\N	INV-202603-0042	น้องนุชการค้า	535	0	unpaid	INV	2026-03-28	500	0.07	draft	t	1774701741960	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
223	\N	QT-202603-0043	น้องนุชการค้า	535	0	unpaid	QT	2026-03-28	500	0.07	draft	t	1774701741960	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
224	\N	DN-202603-0044	น้องนุชการค้า	535	0	unpaid	DN	2026-03-28	500	0.07	draft	t	1774701741960	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
225	\N	RC-202603-0045	น้องนุชการค้า	535	0	unpaid	RC	2026-03-28	500	0.07	draft	t	1774701741960	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
237	\N	RC-202603-0057	น้องนุชการค้า	800	0	unpaid	RC	2026-03-28	800	0	draft	f	1774701809143	e588ae04-1f53-4a43-a0cf-f8d921693b18		42 หมู่7 ต.นาแห้ว อ.นาแห้ว จ.เลย	0854451265	1420633354698	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	f	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	2026-03-31 23:21:02.399726	\N
240	\N	QT-202604-0180	ร้านบ้านทุ่ง	500	500	unpaid	QT	2026-04-02	500	0	paid	f	1775144998138	6466b94b-6852-4797-9378-7ae617809699		42 หมู่4	0541236547	1235411125474	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-02 15:49:58.128954	\N
241	\N	DN-202604-0181	ร้านบ้านทุ่ง	500	500	unpaid	DN	2026-04-02	500	0	paid	f	1775144998138	6466b94b-6852-4797-9378-7ae617809699		42 หมู่4	0541236547	1235411125474	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-02 15:49:58.128954	\N
249	\N	DN-202604-0007	สมชาย ซื้อดี	28890	0	unpaid	DN	2026-04-03	27000	0.07	draft	t	1775180247521	3b34b55e-f428-42ed-b913-32c313dfcfd9		23 หมู่7 ต.นาอาน อ.เมือง จ.เลย	0885456321	1450033362354				f	\N		2026-04-03 01:37:27.506004	e3803102-89ec-441f-a37c-af9f8a70a235
250	\N	RC-202604-0008	สมชาย ซื้อดี	28890	0	unpaid	RC	2026-04-03	27000	0.07	draft	t	1775180247521	3b34b55e-f428-42ed-b913-32c313dfcfd9		23 หมู่7 ต.นาอาน อ.เมือง จ.เลย	0885456321	1450033362354				f	\N		2026-04-03 01:37:27.506004	e3803102-89ec-441f-a37c-af9f8a70a235
251	\N	INV-202604-0009	สมชาย ซื้อดี	8988	0	unpaid	INV	2026-04-03	8400	0.07	draft	t	1775180276039	3b34b55e-f428-42ed-b913-32c313dfcfd9		23 หมู่7 ต.นาอาน อ.เมือง จ.เลย	0885456321	1450033362354				f	\N		2026-04-03 01:37:56.024824	c926db75-2880-4f03-b908-ffeb02507ba0
252	\N	QT-202604-0010	สมชาย ซื้อดี	8988	0	unpaid	QT	2026-04-03	8400	0.07	draft	t	1775180276039	3b34b55e-f428-42ed-b913-32c313dfcfd9		23 หมู่7 ต.นาอาน อ.เมือง จ.เลย	0885456321	1450033362354				f	\N		2026-04-03 01:37:56.024824	c926db75-2880-4f03-b908-ffeb02507ba0
253	\N	DN-202604-0011	สมชาย ซื้อดี	8988	0	unpaid	DN	2026-04-03	8400	0.07	draft	t	1775180276039	3b34b55e-f428-42ed-b913-32c313dfcfd9		23 หมู่7 ต.นาอาน อ.เมือง จ.เลย	0885456321	1450033362354				f	\N		2026-04-03 01:37:56.024824	c926db75-2880-4f03-b908-ffeb02507ba0
255	\N	INV-202604-0013	สมชาย ซื้อดี	5136	5136	unpaid	INV	2026-04-03	4800	0.07	paid	t	1775180290062	3b34b55e-f428-42ed-b913-32c313dfcfd9		23 หมู่7 ต.นาอาน อ.เมือง จ.เลย	0885456321	1450033362354				t	\N		2026-04-03 01:38:10.047445	ec6697e9-d599-45d5-a726-7d373fad0ecc
256	\N	QT-202604-0014	สมชาย ซื้อดี	5136	5136	unpaid	QT	2026-04-03	4800	0.07	paid	t	1775180290062	3b34b55e-f428-42ed-b913-32c313dfcfd9		23 หมู่7 ต.นาอาน อ.เมือง จ.เลย	0885456321	1450033362354				t	\N		2026-04-03 01:38:10.047445	ec6697e9-d599-45d5-a726-7d373fad0ecc
257	\N	DN-202604-0015	สมชาย ซื้อดี	5136	5136	unpaid	DN	2026-04-03	4800	0.07	paid	t	1775180290062	3b34b55e-f428-42ed-b913-32c313dfcfd9		23 หมู่7 ต.นาอาน อ.เมือง จ.เลย	0885456321	1450033362354				t	\N		2026-04-03 01:38:10.047445	ec6697e9-d599-45d5-a726-7d373fad0ecc
258	\N	RC-202604-0016	สมชาย ซื้อดี	5136	5136	unpaid	RC	2026-04-03	4800	0.07	paid	t	1775180290062	3b34b55e-f428-42ed-b913-32c313dfcfd9		23 หมู่7 ต.นาอาน อ.เมือง จ.เลย	0885456321	1450033362354				t	\N		2026-04-03 01:38:10.047445	ec6697e9-d599-45d5-a726-7d373fad0ecc
337	\N	DN-202604-0003	นายสมชาย  รักดี	2675	2675	unpaid	DN	2026-04-06	2500	0.07	paid	t	1775489638995	f86ea2b3-412d-40fa-a75c-efc0f23a4ac2		43 หมู่7 ต.นาอ้อ อ.เมือง จ.เลย 42050	0887675467	192786653627	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย 42000	1420008767543	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775489424350-IMG_5147.jpeg	0849197741	2026-04-06 15:33:58.941525	2634b891-a864-4716-aa70-7ae8b8097954
338	\N	RC-202604-0004	นายสมชาย  รักดี	2675	2675	unpaid	RC	2026-04-06	2500	0.07	paid	t	1775489638995	f86ea2b3-412d-40fa-a75c-efc0f23a4ac2		43 หมู่7 ต.นาอ้อ อ.เมือง จ.เลย 42050	0887675467	192786653627	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย 42000	1420008767543	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775489424350-IMG_5147.jpeg	0849197741	2026-04-06 15:33:58.941525	2634b891-a864-4716-aa70-7ae8b8097954
260	\N	QT-202604-0002	ทดสอบ	26750	0	unpaid	QT	2026-04-03	25000	0.07	draft	t	1775182326706	ccaf622d-3ecc-4a57-9055-25c5c292cd2b								f	\N		2026-04-03 02:12:06.694066	ad8c6545-a625-45a9-ab0a-087d7a558b94
261	\N	DN-202604-0003	ทดสอบ	26750	0	unpaid	DN	2026-04-03	25000	0.07	draft	t	1775182326706	ccaf622d-3ecc-4a57-9055-25c5c292cd2b								f	\N		2026-04-03 02:12:06.694066	ad8c6545-a625-45a9-ab0a-087d7a558b94
262	\N	RC-202604-0004	ทดสอบ	26750	0	unpaid	RC	2026-04-03	25000	0.07	draft	t	1775182326706	ccaf622d-3ecc-4a57-9055-25c5c292cd2b								f	\N		2026-04-03 02:12:06.694066	ad8c6545-a625-45a9-ab0a-087d7a558b94
263	\N	INV-202604-0005	ทดสอบ	856	0	unpaid	INV	2026-04-03	800	0.07	draft	t	1775190329601	ccaf622d-3ecc-4a57-9055-25c5c292cd2b								f	\N		2026-04-03 04:25:29.551411	c6a20cc7-494a-4ee7-8072-60604785a80e
264	\N	QT-202604-0006	ทดสอบ	856	0	unpaid	QT	2026-04-03	800	0.07	draft	t	1775190329601	ccaf622d-3ecc-4a57-9055-25c5c292cd2b								f	\N		2026-04-03 04:25:29.551411	c6a20cc7-494a-4ee7-8072-60604785a80e
265	\N	DN-202604-0007	ทดสอบ	856	0	unpaid	DN	2026-04-03	800	0.07	draft	t	1775190329601	ccaf622d-3ecc-4a57-9055-25c5c292cd2b								f	\N		2026-04-03 04:25:29.551411	c6a20cc7-494a-4ee7-8072-60604785a80e
266	\N	RC-202604-0008	ทดสอบ	856	0	unpaid	RC	2026-04-03	800	0.07	draft	t	1775190329601	ccaf622d-3ecc-4a57-9055-25c5c292cd2b								f	\N		2026-04-03 04:25:29.551411	c6a20cc7-494a-4ee7-8072-60604785a80e
267	\N	INV-202604-0009	หกฟฟกฟ	749	0	unpaid	INV	2026-04-03	700	0.07	draft	t	1775190930003	ccaf622d-3ecc-4a57-9055-25c5c292cd2b								f	\N		2026-04-03 04:35:29.951248	142c4d5b-e1b5-46f9-9ec8-3685d25b4104
268	\N	QT-202604-0010	หกฟฟกฟ	749	0	unpaid	QT	2026-04-03	700	0.07	draft	t	1775190930003	ccaf622d-3ecc-4a57-9055-25c5c292cd2b								f	\N		2026-04-03 04:35:29.951248	142c4d5b-e1b5-46f9-9ec8-3685d25b4104
269	\N	DN-202604-0011	หกฟฟกฟ	749	0	unpaid	DN	2026-04-03	700	0.07	draft	t	1775190930003	ccaf622d-3ecc-4a57-9055-25c5c292cd2b								f	\N		2026-04-03 04:35:29.951248	142c4d5b-e1b5-46f9-9ec8-3685d25b4104
270	\N	RC-202604-0012	หกฟฟกฟ	749	0	unpaid	RC	2026-04-03	700	0.07	draft	t	1775190930003	ccaf622d-3ecc-4a57-9055-25c5c292cd2b								f	\N		2026-04-03 04:35:29.951248	142c4d5b-e1b5-46f9-9ec8-3685d25b4104
271	\N	INV-202604-0001	dadasd	911.64	0	unpaid	INV	2026-04-03	852	0.07	draft	t	1775191289499	6923c1d9-4f5a-40ba-8a1c-98fbf65f237a								f	\N		2026-04-03 04:41:29.447437	0a5af001-9887-4fb7-a821-6b3ffadb7207
272	\N	QT-202604-0002	dadasd	911.64	0	unpaid	QT	2026-04-03	852	0.07	draft	t	1775191289499	6923c1d9-4f5a-40ba-8a1c-98fbf65f237a								f	\N		2026-04-03 04:41:29.447437	0a5af001-9887-4fb7-a821-6b3ffadb7207
273	\N	DN-202604-0003	dadasd	911.64	0	unpaid	DN	2026-04-03	852	0.07	draft	t	1775191289499	6923c1d9-4f5a-40ba-8a1c-98fbf65f237a								f	\N		2026-04-03 04:41:29.447437	0a5af001-9887-4fb7-a821-6b3ffadb7207
274	\N	RC-202604-0004	dadasd	911.64	0	unpaid	RC	2026-04-03	852	0.07	draft	t	1775191289499	6923c1d9-4f5a-40ba-8a1c-98fbf65f237a								f	\N		2026-04-03 04:41:29.447437	0a5af001-9887-4fb7-a821-6b3ffadb7207
275	\N	INV-202604-0005	กหฟกฟห	428	0	unpaid	INV	2026-04-03	400	0.07	draft	t	1775192338425	6923c1d9-4f5a-40ba-8a1c-98fbf65f237a								f	\N		2026-04-03 04:58:58.370163	f1e6a59e-a655-4251-9910-b8717e4b66b3
276	\N	QT-202604-0006	กหฟกฟห	428	0	unpaid	QT	2026-04-03	400	0.07	draft	t	1775192338425	6923c1d9-4f5a-40ba-8a1c-98fbf65f237a								f	\N		2026-04-03 04:58:58.370163	f1e6a59e-a655-4251-9910-b8717e4b66b3
277	\N	DN-202604-0007	กหฟกฟห	428	0	unpaid	DN	2026-04-03	400	0.07	draft	t	1775192338425	6923c1d9-4f5a-40ba-8a1c-98fbf65f237a								f	\N		2026-04-03 04:58:58.370163	f1e6a59e-a655-4251-9910-b8717e4b66b3
278	\N	RC-202604-0008	กหฟกฟห	428	0	unpaid	RC	2026-04-03	400	0.07	draft	t	1775192338425	6923c1d9-4f5a-40ba-8a1c-98fbf65f237a								f	\N		2026-04-03 04:58:58.370163	f1e6a59e-a655-4251-9910-b8717e4b66b3
335	\N	INV-202604-0001	นายสมชาย  รักดี	2675	2675	unpaid	INV	2026-04-06	2500	0.07	paid	t	1775489638995	f86ea2b3-412d-40fa-a75c-efc0f23a4ac2		43 หมู่7 ต.นาอ้อ อ.เมือง จ.เลย 42050	0887675467	192786653627	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย 42000	1420008767543	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775489424350-IMG_5147.jpeg	0849197741	2026-04-06 15:33:58.941525	2634b891-a864-4716-aa70-7ae8b8097954
336	\N	QT-202604-0002	นายสมชาย  รักดี	2675	2675	unpaid	QT	2026-04-06	2500	0.07	paid	t	1775489638995	f86ea2b3-412d-40fa-a75c-efc0f23a4ac2		43 หมู่7 ต.นาอ้อ อ.เมือง จ.เลย 42050	0887675467	192786653627	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย 42000	1420008767543	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775489424350-IMG_5147.jpeg	0849197741	2026-04-06 15:33:58.941525	2634b891-a864-4716-aa70-7ae8b8097954
49	\N	QT-000002	ทดสอบ	856	856	\N	QT	2026-03-23	800	0.07	paid	t	1774272059923	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
50	\N	DN-000002	ทดสอบ	856	856	\N	DN	2026-03-23	800	0.07	paid	t	1774272059923	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
283	\N	INV-202604-0013	มาสิ	963	0	unpaid	INV	2026-04-03	900	0.07	draft	t	1775204171436	ccaf622d-3ecc-4a57-9055-25c5c292cd2b		ดหดหกด	ดกหดห	หดหดกหด	บ้านขนมไทย	222 หมู่17 อ.วังน้อย จ.อยุธยา	1254774412547	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775204142416-Untitled-2.png	0555552124	2026-04-03 08:16:11.424883	77fa1467-971f-490e-aaf0-7b985a82c42c
284	\N	QT-202604-0014	มาสิ	963	0	unpaid	QT	2026-04-03	900	0.07	draft	t	1775204171436	ccaf622d-3ecc-4a57-9055-25c5c292cd2b		ดหดหกด	ดกหดห	หดหดกหด	บ้านขนมไทย	222 หมู่17 อ.วังน้อย จ.อยุธยา	1254774412547	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775204142416-Untitled-2.png	0555552124	2026-04-03 08:16:11.424883	77fa1467-971f-490e-aaf0-7b985a82c42c
285	\N	DN-202604-0015	มาสิ	963	0	unpaid	DN	2026-04-03	900	0.07	draft	t	1775204171436	ccaf622d-3ecc-4a57-9055-25c5c292cd2b		ดหดหกด	ดกหดห	หดหดกหด	บ้านขนมไทย	222 หมู่17 อ.วังน้อย จ.อยุธยา	1254774412547	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775204142416-Untitled-2.png	0555552124	2026-04-03 08:16:11.424883	77fa1467-971f-490e-aaf0-7b985a82c42c
286	\N	RC-202604-0016	มาสิ	963	0	unpaid	RC	2026-04-03	900	0.07	draft	t	1775204171436	ccaf622d-3ecc-4a57-9055-25c5c292cd2b		ดหดหกด	ดกหดห	หดหดกหด	บ้านขนมไทย	222 หมู่17 อ.วังน้อย จ.อยุธยา	1254774412547	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775204142416-Untitled-2.png	0555552124	2026-04-03 08:16:11.424883	77fa1467-971f-490e-aaf0-7b985a82c42c
51	\N	RC-000002	ทดสอบ	856	856	\N	RC	2026-03-23	800	0.07	paid	t	1774272059923	6466b94b-6852-4797-9378-7ae617809699	\N	\N	\N	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	\N	\N	2026-03-31 23:21:02.399726	\N
339	\N	INV-202604-0005	สมศักดิ์กาค้า	7490	0	unpaid	INV	2026-04-06	7000	0.07	draft	t	1775490291323	f86ea2b3-412d-40fa-a75c-efc0f23a4ac2		10 หมู่2 ต.ปากหมัน อ.ด่านซ้าย จ.เลย 42000	0554214574	1250044457124	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย 42000	1420008767543	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775489424350-IMG_5147.jpeg	0849197741	2026-04-06 15:44:51.272573	d61f54a1-9c21-4962-bfa8-dd69b5b9c991
287	\N	INV-202604-0017	น้องปลา	68480	68480	unpaid	INV	2026-04-03	64000	0.07	paid	t	1775205185893	ccaf622d-3ecc-4a57-9055-25c5c292cd2b		14 หมู่7 ต.นาดี อ.เมือง จ.เลย 42000	0224125474	1254411121547	บ้านขนมไทย	222 หมู่17 อ.วังน้อย จ.อยุธยา	1254774412547	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775204142416-Untitled-2.png	0555552124	2026-04-03 08:33:05.892197	dfe8972c-2d22-4ef9-b0c4-100f48d86d6d
288	\N	QT-202604-0018	น้องปลา	68480	68480	unpaid	QT	2026-04-03	64000	0.07	paid	t	1775205185893	ccaf622d-3ecc-4a57-9055-25c5c292cd2b		14 หมู่7 ต.นาดี อ.เมือง จ.เลย 42000	0224125474	1254411121547	บ้านขนมไทย	222 หมู่17 อ.วังน้อย จ.อยุธยา	1254774412547	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775204142416-Untitled-2.png	0555552124	2026-04-03 08:33:05.892197	dfe8972c-2d22-4ef9-b0c4-100f48d86d6d
289	\N	DN-202604-0019	น้องปลา	68480	68480	unpaid	DN	2026-04-03	64000	0.07	paid	t	1775205185893	ccaf622d-3ecc-4a57-9055-25c5c292cd2b		14 หมู่7 ต.นาดี อ.เมือง จ.เลย 42000	0224125474	1254411121547	บ้านขนมไทย	222 หมู่17 อ.วังน้อย จ.อยุธยา	1254774412547	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775204142416-Untitled-2.png	0555552124	2026-04-03 08:33:05.892197	dfe8972c-2d22-4ef9-b0c4-100f48d86d6d
290	\N	RC-202604-0020	น้องปลา	68480	68480	unpaid	RC	2026-04-03	64000	0.07	paid	t	1775205185893	ccaf622d-3ecc-4a57-9055-25c5c292cd2b		14 หมู่7 ต.นาดี อ.เมือง จ.เลย 42000	0224125474	1254411121547	บ้านขนมไทย	222 หมู่17 อ.วังน้อย จ.อยุธยา	1254774412547	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775204142416-Untitled-2.png	0555552124	2026-04-03 08:33:05.892197	dfe8972c-2d22-4ef9-b0c4-100f48d86d6d
291	\N	INV-202604-0001	บริษัท เมืองเลย แทรกเตอร์ จำกัด	535	0	unpaid	INV	2026-04-04	500	0.07	draft	t	1775276019331	9e051997-6e28-4b2a-af7a-5fef68524c52		323 หมู่4 ต.นาอาน อ.เมือง จ.เลย 42000	0884451247	1450023625874	หจก. ซีทีดี อินเตอร์เทรด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย 42000	14205001651087	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775275918903-MLT_logo.png	0849197741	2026-04-04 04:13:39.281314	ad4f8821-3ba7-45e0-8ce8-dc296da04d0c
292	\N	QT-202604-0002	บริษัท เมืองเลย แทรกเตอร์ จำกัด	535	0	unpaid	QT	2026-04-04	500	0.07	draft	t	1775276019331	9e051997-6e28-4b2a-af7a-5fef68524c52		323 หมู่4 ต.นาอาน อ.เมือง จ.เลย 42000	0884451247	1450023625874	หจก. ซีทีดี อินเตอร์เทรด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย 42000	14205001651087	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775275918903-MLT_logo.png	0849197741	2026-04-04 04:13:39.281314	ad4f8821-3ba7-45e0-8ce8-dc296da04d0c
293	\N	DN-202604-0003	บริษัท เมืองเลย แทรกเตอร์ จำกัด	535	0	unpaid	DN	2026-04-04	500	0.07	draft	t	1775276019331	9e051997-6e28-4b2a-af7a-5fef68524c52		323 หมู่4 ต.นาอาน อ.เมือง จ.เลย 42000	0884451247	1450023625874	หจก. ซีทีดี อินเตอร์เทรด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย 42000	14205001651087	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775275918903-MLT_logo.png	0849197741	2026-04-04 04:13:39.281314	ad4f8821-3ba7-45e0-8ce8-dc296da04d0c
294	\N	RC-202604-0004	บริษัท เมืองเลย แทรกเตอร์ จำกัด	535	0	unpaid	RC	2026-04-04	500	0.07	draft	t	1775276019331	9e051997-6e28-4b2a-af7a-5fef68524c52		323 หมู่4 ต.นาอาน อ.เมือง จ.เลย 42000	0884451247	1450023625874	หจก. ซีทีดี อินเตอร์เทรด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย 42000	14205001651087	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775275918903-MLT_logo.png	0849197741	2026-04-04 04:13:39.281314	ad4f8821-3ba7-45e0-8ce8-dc296da04d0c
295	\N	INV-202604-0187	หจก.ซีทีดี อินเตอร์เทรด	569240	569240	unpaid	INV	2026-04-04	532000	0.07	paid	t	1775327308619	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-04 18:28:28.577492	65db4c78-3092-4c04-a3cf-2b04248ee789
296	\N	DN-202604-0188	หจก.ซีทีดี อินเตอร์เทรด	569240	569240	unpaid	DN	2026-04-04	532000	0.07	paid	t	1775327308619	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-04 18:28:28.577492	65db4c78-3092-4c04-a3cf-2b04248ee789
297	\N	QT-202604-0189	หจก.ซีทีดี อินเตอร์เทรด	569240	569240	unpaid	QT	2026-04-04	532000	0.07	paid	t	1775327308619	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-04 18:28:28.577492	65db4c78-3092-4c04-a3cf-2b04248ee789
298	\N	RC-202604-0190	หจก.ซีทีดี อินเตอร์เทรด	569240	569240	unpaid	RC	2026-04-04	532000	0.07	paid	t	1775327308619	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-04 18:28:28.577492	65db4c78-3092-4c04-a3cf-2b04248ee789
279	\N	INV-202604-0183	หจก.ซีทีดี อินเตอร์เทรด	531.79	531.79	unpaid	INV	2026-04-03	497	0.07	paid	t	1775197679118	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-03 06:27:59.07524	fe43a596-2f36-4649-94dd-68fac5590895
280	\N	QT-202604-0184	หจก.ซีทีดี อินเตอร์เทรด	531.79	531.79	unpaid	QT	2026-04-03	497	0.07	paid	t	1775197679118	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-03 06:27:59.07524	fe43a596-2f36-4649-94dd-68fac5590895
281	\N	DN-202604-0185	หจก.ซีทีดี อินเตอร์เทรด	531.79	531.79	unpaid	DN	2026-04-03	497	0.07	paid	t	1775197679118	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-03 06:27:59.07524	fe43a596-2f36-4649-94dd-68fac5590895
282	\N	RC-202604-0186	หจก.ซีทีดี อินเตอร์เทรด	531.79	531.79	unpaid	RC	2026-04-03	497	0.07	paid	t	1775197679118	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-03 06:27:59.07524	fe43a596-2f36-4649-94dd-68fac5590895
299	\N	INV-202604-0191	หจก.ซีทีดี อินเตอร์เทรด	85600	85600	unpaid	INV	2026-04-04	80000	0.07	paid	t	1775332813683	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-04 20:00:13.639327	01bd481e-4c42-4193-901e-ba43fdaf7892
300	\N	QT-202604-0192	หจก.ซีทีดี อินเตอร์เทรด	85600	85600	unpaid	QT	2026-04-04	80000	0.07	paid	t	1775332813683	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-04 20:00:13.639327	01bd481e-4c42-4193-901e-ba43fdaf7892
301	\N	DN-202604-0193	หจก.ซีทีดี อินเตอร์เทรด	85600	85600	unpaid	DN	2026-04-04	80000	0.07	paid	t	1775332813683	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-04 20:00:13.639327	01bd481e-4c42-4193-901e-ba43fdaf7892
302	\N	RC-202604-0194	หจก.ซีทีดี อินเตอร์เทรด	85600	85600	unpaid	RC	2026-04-04	80000	0.07	paid	t	1775332813683	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-04 20:00:13.639327	01bd481e-4c42-4193-901e-ba43fdaf7892
307	\N	INV-202604-0005	ร้านภูฟ้าอาหารสด	8025	8025	unpaid	INV	2026-04-05	7500	0.07	paid	t	1775355945815	cf532569-58e0-4019-a00f-17a4966af22f		97 หมู่4 ต.ด่านซ้าย อ.ด่านซ้าย จ.เลย 42000	0874514246	1450366001478	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 02:25:45.80954	0bc70650-9429-4736-b979-74f73e17a362
308	\N	QT-202604-0006	ร้านภูฟ้าอาหารสด	8025	8025	unpaid	QT	2026-04-05	7500	0.07	paid	t	1775355945815	cf532569-58e0-4019-a00f-17a4966af22f		97 หมู่4 ต.ด่านซ้าย อ.ด่านซ้าย จ.เลย 42000	0874514246	1450366001478	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 02:25:45.80954	0bc70650-9429-4736-b979-74f73e17a362
309	\N	DN-202604-0007	ร้านภูฟ้าอาหารสด	8025	8025	unpaid	DN	2026-04-05	7500	0.07	paid	t	1775355945815	cf532569-58e0-4019-a00f-17a4966af22f		97 หมู่4 ต.ด่านซ้าย อ.ด่านซ้าย จ.เลย 42000	0874514246	1450366001478	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 02:25:45.80954	0bc70650-9429-4736-b979-74f73e17a362
310	\N	RC-202604-0008	ร้านภูฟ้าอาหารสด	8025	8025	unpaid	RC	2026-04-05	7500	0.07	paid	t	1775355945815	cf532569-58e0-4019-a00f-17a4966af22f		97 หมู่4 ต.ด่านซ้าย อ.ด่านซ้าย จ.เลย 42000	0874514246	1450366001478	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 02:25:45.80954	0bc70650-9429-4736-b979-74f73e17a362
303	\N	INV-202604-0001	จรัญพาณิชย์	4708	4708	unpaid	INV	2026-04-05	4400	0.07	paid	t	1775355919075	cf532569-58e0-4019-a00f-17a4966af22f		274 หมู่11 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	0985747472	1423500087451	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 02:25:19.068709	730d8ac7-551b-4c5f-b0f7-a3c34b3fb1e1
304	\N	QT-202604-0002	จรัญพาณิชย์	4708	4708	unpaid	QT	2026-04-05	4400	0.07	paid	t	1775355919075	cf532569-58e0-4019-a00f-17a4966af22f		274 หมู่11 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	0985747472	1423500087451	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 02:25:19.068709	730d8ac7-551b-4c5f-b0f7-a3c34b3fb1e1
305	\N	DN-202604-0003	จรัญพาณิชย์	4708	4708	unpaid	DN	2026-04-05	4400	0.07	paid	t	1775355919075	cf532569-58e0-4019-a00f-17a4966af22f		274 หมู่11 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	0985747472	1423500087451	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 02:25:19.068709	730d8ac7-551b-4c5f-b0f7-a3c34b3fb1e1
306	\N	RC-202604-0004	จรัญพาณิชย์	4708	4708	unpaid	RC	2026-04-05	4400	0.07	paid	t	1775355919075	cf532569-58e0-4019-a00f-17a4966af22f		274 หมู่11 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	0985747472	1423500087451	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 02:25:19.068709	730d8ac7-551b-4c5f-b0f7-a3c34b3fb1e1
311	\N	INV-202604-0195	หจก.ซีทีดี อินเตอร์เทรด	54837.5	0	unpaid	INV	2026-04-05	51250	0.07	draft	t	1775356705486	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-05 02:38:25.489004	d8432ad3-3722-4637-b0da-8d6b9c3bda32
312	\N	QT-202604-0196	หจก.ซีทีดี อินเตอร์เทรด	54837.5	0	unpaid	QT	2026-04-05	51250	0.07	draft	t	1775356705486	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-05 02:38:25.489004	d8432ad3-3722-4637-b0da-8d6b9c3bda32
313	\N	DN-202604-0197	หจก.ซีทีดี อินเตอร์เทรด	54837.5	0	unpaid	DN	2026-04-05	51250	0.07	draft	t	1775356705486	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-05 02:38:25.489004	d8432ad3-3722-4637-b0da-8d6b9c3bda32
314	\N	RC-202604-0198	หจก.ซีทีดี อินเตอร์เทรด	54837.5	0	unpaid	RC	2026-04-05	51250	0.07	draft	t	1775356705486	6466b94b-6852-4797-9378-7ae617809699		287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	142000061087	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	2026-04-05 02:38:25.489004	d8432ad3-3722-4637-b0da-8d6b9c3bda32
315	\N	INV-202604-0009	ตาแกะการค้า	24075	0	unpaid	INV	2026-04-05	22500	0.07	draft	t	1775373189642	cf532569-58e0-4019-a00f-17a4966af22f		42 หมู่8 ต.นาดี อ.ด่านซ้าย จ.เลย	0856632147	1420300065457	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 07:13:09.646525	9cdb4afc-cb76-4171-af13-cfa3c20963b4
316	\N	QT-202604-0010	ตาแกะการค้า	24075	0	unpaid	QT	2026-04-05	22500	0.07	draft	t	1775373189642	cf532569-58e0-4019-a00f-17a4966af22f		42 หมู่8 ต.นาดี อ.ด่านซ้าย จ.เลย	0856632147	1420300065457	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 07:13:09.646525	9cdb4afc-cb76-4171-af13-cfa3c20963b4
317	\N	DN-202604-0011	ตาแกะการค้า	24075	0	unpaid	DN	2026-04-05	22500	0.07	draft	t	1775373189642	cf532569-58e0-4019-a00f-17a4966af22f		42 หมู่8 ต.นาดี อ.ด่านซ้าย จ.เลย	0856632147	1420300065457	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 07:13:09.646525	9cdb4afc-cb76-4171-af13-cfa3c20963b4
318	\N	RC-202604-0012	ตาแกะการค้า	24075	0	unpaid	RC	2026-04-05	22500	0.07	draft	t	1775373189642	cf532569-58e0-4019-a00f-17a4966af22f		42 หมู่8 ต.นาดี อ.ด่านซ้าย จ.เลย	0856632147	1420300065457	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 07:13:09.646525	9cdb4afc-cb76-4171-af13-cfa3c20963b4
319	\N	INV-202604-0013	จรัญพาณิชย์	14445	0	unpaid	INV	2026-04-05	13500	0.07	draft	t	1775373228160	cf532569-58e0-4019-a00f-17a4966af22f		274 หมู่11 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	0985747472	1423500087451	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 07:13:48.16572	01463bb7-9cff-420f-8a74-1e5439cb8184
320	\N	QT-202604-0014	จรัญพาณิชย์	14445	0	unpaid	QT	2026-04-05	13500	0.07	draft	t	1775373228160	cf532569-58e0-4019-a00f-17a4966af22f		274 หมู่11 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	0985747472	1423500087451	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 07:13:48.16572	01463bb7-9cff-420f-8a74-1e5439cb8184
321	\N	DN-202604-0015	จรัญพาณิชย์	14445	0	unpaid	DN	2026-04-05	13500	0.07	draft	t	1775373228160	cf532569-58e0-4019-a00f-17a4966af22f		274 หมู่11 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	0985747472	1423500087451	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 07:13:48.16572	01463bb7-9cff-420f-8a74-1e5439cb8184
322	\N	RC-202604-0016	จรัญพาณิชย์	14445	0	unpaid	RC	2026-04-05	13500	0.07	draft	t	1775373228160	cf532569-58e0-4019-a00f-17a4966af22f		274 หมู่11 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	0985747472	1423500087451	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	f	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 07:13:48.16572	01463bb7-9cff-420f-8a74-1e5439cb8184
323	\N	INV-202604-0017	ร้านภูฟ้าอาหารสด	2942.5	2942.5	unpaid	INV	2026-04-05	2750	0.07	paid	t	1775382273702	cf532569-58e0-4019-a00f-17a4966af22f		97 หมู่4 ต.ด่านซ้าย อ.ด่านซ้าย จ.เลย 42000	0874514246	1450366001478	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 09:44:33.687316	b1c91453-fca7-4a31-b8ec-c96ab658ffd4
324	\N	QT-202604-0018	ร้านภูฟ้าอาหารสด	2942.5	2942.5	unpaid	QT	2026-04-05	2750	0.07	paid	t	1775382273702	cf532569-58e0-4019-a00f-17a4966af22f		97 หมู่4 ต.ด่านซ้าย อ.ด่านซ้าย จ.เลย 42000	0874514246	1450366001478	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 09:44:33.687316	b1c91453-fca7-4a31-b8ec-c96ab658ffd4
325	\N	DN-202604-0019	ร้านภูฟ้าอาหารสด	2942.5	2942.5	unpaid	DN	2026-04-05	2750	0.07	paid	t	1775382273702	cf532569-58e0-4019-a00f-17a4966af22f		97 หมู่4 ต.ด่านซ้าย อ.ด่านซ้าย จ.เลย 42000	0874514246	1450366001478	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 09:44:33.687316	b1c91453-fca7-4a31-b8ec-c96ab658ffd4
326	\N	RC-202604-0020	ร้านภูฟ้าอาหารสด	2942.5	2942.5	unpaid	RC	2026-04-05	2750	0.07	paid	t	1775382273702	cf532569-58e0-4019-a00f-17a4966af22f		97 หมู่4 ต.ด่านซ้าย อ.ด่านซ้าย จ.เลย 42000	0874514246	1450366001478	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	2026-04-05 09:44:33.687316	b1c91453-fca7-4a31-b8ec-c96ab658ffd4
327	\N	INV-202604-0001	สมชาย แสนดี	4815	4815	unpaid	INV	2026-04-05	4500	0.07	paid	t	1775404655828	50ebcc47-10bc-4f05-9da5-04ca074acd86		323 หมู่4	0884633894	22573527826628				t	\N		2026-04-05 15:57:35.81618	4557ee2b-0a01-4754-9c2a-9c6e04544a90
328	\N	QT-202604-0002	สมชาย แสนดี	4815	4815	unpaid	QT	2026-04-05	4500	0.07	paid	t	1775404655828	50ebcc47-10bc-4f05-9da5-04ca074acd86		323 หมู่4	0884633894	22573527826628				t	\N		2026-04-05 15:57:35.81618	4557ee2b-0a01-4754-9c2a-9c6e04544a90
329	\N	DN-202604-0003	สมชาย แสนดี	4815	4815	unpaid	DN	2026-04-05	4500	0.07	paid	t	1775404655828	50ebcc47-10bc-4f05-9da5-04ca074acd86		323 หมู่4	0884633894	22573527826628				t	\N		2026-04-05 15:57:35.81618	4557ee2b-0a01-4754-9c2a-9c6e04544a90
330	\N	RC-202604-0004	สมชาย แสนดี	4815	4815	unpaid	RC	2026-04-05	4500	0.07	paid	t	1775404655828	50ebcc47-10bc-4f05-9da5-04ca074acd86		323 หมู่4	0884633894	22573527826628				t	\N		2026-04-05 15:57:35.81618	4557ee2b-0a01-4754-9c2a-9c6e04544a90
331	\N	INV-202604-0001	นายสมชาย	26750	26750	unpaid	INV	2026-04-05	25000	0.07	paid	t	1775406819053	9d38fa5c-2f63-454a-a8c3-bbe684292236		36 หมู่ 7 ต.นาแขม อ.เมือง จ.เลย	0878656413	1420877786542	หจก.ซีทีดี อินเตอร์เทรด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	1420560010187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775406622210-IMG_5147.jpeg	0849197741	2026-04-05 16:33:39.055208	5ed2511a-ddb9-4fcc-aa9b-9596e37b7c5a
332	\N	QT-202604-0002	นายสมชาย	26750	26750	unpaid	QT	2026-04-05	25000	0.07	paid	t	1775406819053	9d38fa5c-2f63-454a-a8c3-bbe684292236		36 หมู่ 7 ต.นาแขม อ.เมือง จ.เลย	0878656413	1420877786542	หจก.ซีทีดี อินเตอร์เทรด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	1420560010187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775406622210-IMG_5147.jpeg	0849197741	2026-04-05 16:33:39.055208	5ed2511a-ddb9-4fcc-aa9b-9596e37b7c5a
333	\N	DN-202604-0003	นายสมชาย	26750	26750	unpaid	DN	2026-04-05	25000	0.07	paid	t	1775406819053	9d38fa5c-2f63-454a-a8c3-bbe684292236		36 หมู่ 7 ต.นาแขม อ.เมือง จ.เลย	0878656413	1420877786542	หจก.ซีทีดี อินเตอร์เทรด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	1420560010187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775406622210-IMG_5147.jpeg	0849197741	2026-04-05 16:33:39.055208	5ed2511a-ddb9-4fcc-aa9b-9596e37b7c5a
334	\N	RC-202604-0004	นายสมชาย	26750	26750	unpaid	RC	2026-04-05	25000	0.07	paid	t	1775406819053	9d38fa5c-2f63-454a-a8c3-bbe684292236		36 หมู่ 7 ต.นาแขม อ.เมือง จ.เลย	0878656413	1420877786542	หจก.ซีทีดี อินเตอร์เทรด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	1420560010187	t	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775406622210-IMG_5147.jpeg	0849197741	2026-04-05 16:33:39.055208	5ed2511a-ddb9-4fcc-aa9b-9596e37b7c5a
\.


--
-- Data for Name: feedbacks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.feedbacks (id, account_id, user_id, type, message, page, created_at, status) FROM stdin;
1	6466b94b-6852-4797-9378-7ae617809699	82cfd3c8-0dde-40ac-a392-110bf842b3fa	feature	ขอระบบ ภพ30	/dashboard	2026-04-05 07:15:24.446115	open
2	6466b94b-6852-4797-9378-7ae617809699	82cfd3c8-0dde-40ac-a392-110bf842b3fa	bug	ยังไม่สมบูรณ์แบบ	/dashboard	2026-04-05 07:16:23.729898	open
3	6466b94b-6852-4797-9378-7ae617809699	82cfd3c8-0dde-40ac-a392-110bf842b3fa	bug	ทดสอบส่งบั๊ก	/dashboard	2026-04-05 07:17:10.29521	open
4	6466b94b-6852-4797-9378-7ae617809699	82cfd3c8-0dde-40ac-a392-110bf842b3fa	bug	แจ้งปัญหาทางเมล์ไม่ได้	/dashboard	2026-04-05 07:24:23.50748	open
5	6466b94b-6852-4797-9378-7ae617809699	82cfd3c8-0dde-40ac-a392-110bf842b3fa	bug	ทอสอบแจ้งปัญหา	/dashboard	2026-04-05 07:41:04.588231	open
6	6466b94b-6852-4797-9378-7ae617809699	82cfd3c8-0dde-40ac-a392-110bf842b3fa	feature	อยากให้เพิ่ม ภพ.30	/dashboard	2026-04-05 07:41:35.165906	open
7	6466b94b-6852-4797-9378-7ae617809699	82cfd3c8-0dde-40ac-a392-110bf842b3fa	feature	อยากได้ฟีเจอร์โหดๆ ดีๆ	/history	2026-04-05 09:34:11.098698	open
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.payments (id, document_id, amount, method, company_id, order_id, account_id, payment_date) FROM stdin;
1	6	700	cash	\N	\N	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
2	18	535	cash	\N	\N	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
3	\N	832.46	\N	1	1774094710070	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
4	\N	832.46	\N	1	1774094710070	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
5	\N	832.46	\N	1	1774094710070	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
6	\N	832.46	\N	1	1774094710070	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
7	\N	832.46	\N	1	1774094710070	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
8	\N	832.46	\N	1	1774094710070	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
9	\N	832.46	\N	1	1774094710070	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
10	\N	832.46	\N	1	1774094710070	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
11	\N	832.46	\N	1	1774094710070	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
12	\N	856	\N	1	1774094502331	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
13	\N	43870	\N	1	1774104537601	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
14	\N	5350	\N	1	1774104980569	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
15	\N	535	\N	1	1774139465928	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
16	\N	535	\N	1	1774145334929	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
17	\N	535	\N	\N	1774271998078	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
18	\N	642	\N	\N	1774312687291	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
19	\N	1605	\N	\N	1774306350311	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
20	\N	628.09	\N	\N	1774306288230	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
21	\N	481.5	\N	\N	1774305699511	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 07:21:51.307085
22	\N	81106	\N	\N	1774356491628	6466b94b-6852-4797-9378-7ae617809699	2026-03-24 21:42:59.047749
23	\N	53500	\N	\N	1774410998425	6466b94b-6852-4797-9378-7ae617809699	2026-03-25 03:56:45.562365
24	\N	374500	\N	\N	1774479478672	6466b94b-6852-4797-9378-7ae617809699	2026-03-25 22:58:11.056107
25	\N	17644.3	\N	\N	1774480643678	6466b94b-6852-4797-9378-7ae617809699	2026-03-25 23:17:31.786564
26	\N	2140	\N	\N	1774481839867	6466b94b-6852-4797-9378-7ae617809699	2026-03-26 03:40:22.777254
27	\N	24075	\N	\N	1774509931496	6466b94b-6852-4797-9378-7ae617809699	2026-03-26 07:25:51.523011
28	\N	29960	\N	\N	1774567270999	6466b94b-6852-4797-9378-7ae617809699	2026-03-26 23:21:28.06313
29	\N	535	\N	\N	1774628840182	6466b94b-6852-4797-9378-7ae617809699	2026-03-28 00:52:45.096215
30	\N	1070	\N	\N	1774481416258	6466b94b-6852-4797-9378-7ae617809699	2026-03-28 01:24:45.997144
31	\N	2889	\N	\N	1774661034044	6466b94b-6852-4797-9378-7ae617809699	2026-03-28 01:24:55.095484
32	\N	642	\N	\N	1774697770810	e588ae04-1f53-4a43-a0cf-f8d921693b18	2026-03-28 11:36:20.657279
33	\N	9630	\N	\N	1774697717171	e588ae04-1f53-4a43-a0cf-f8d921693b18	2026-03-28 11:36:24.105679
34	\N	535	\N	\N	1774999312693	6466b94b-6852-4797-9378-7ae617809699	2026-03-31 23:22:21.431766
35	\N	500	\N	\N	1775144998138	6466b94b-6852-4797-9378-7ae617809699	2026-04-02 15:56:12.527489
36	\N	5136	\N	\N	1775180290062	3b34b55e-f428-42ed-b913-32c313dfcfd9	2026-04-03 01:46:58.968381
37	\N	68480	\N	\N	1775205185893	ccaf622d-3ecc-4a57-9055-25c5c292cd2b	2026-04-03 08:33:14.134897
38	\N	569240	\N	\N	1775327308619	6466b94b-6852-4797-9378-7ae617809699	2026-04-04 18:28:40.397875
39	\N	531.79	\N	\N	1775197679118	6466b94b-6852-4797-9378-7ae617809699	2026-04-04 18:28:44.632338
40	\N	8025	\N	\N	1775355945815	cf532569-58e0-4019-a00f-17a4966af22f	2026-04-05 02:25:54.740407
41	\N	4708	\N	\N	1775355919075	cf532569-58e0-4019-a00f-17a4966af22f	2026-04-05 02:25:58.052864
42	\N	85600	\N	\N	1775332813683	6466b94b-6852-4797-9378-7ae617809699	2026-04-05 02:38:32.564351
43	\N	2942.5	\N	\N	1775382273702	cf532569-58e0-4019-a00f-17a4966af22f	2026-04-05 09:44:38.551988
44	\N	4815	\N	\N	1775404655828	50ebcc47-10bc-4f05-9da5-04ca074acd86	2026-04-05 15:57:45.362454
45	\N	26750	\N	\N	1775406819053	9d38fa5c-2f63-454a-a8c3-bbe684292236	2026-04-05 16:34:32.642281
46	\N	2675	\N	\N	1775489638995	f86ea2b3-412d-40fa-a75c-efc0f23a4ac2	2026-04-06 15:37:41.47867
47	\N	428	\N	\N	1774305671644	6466b94b-6852-4797-9378-7ae617809699	2026-04-06 15:42:46.332291
48	\N	856	\N	\N	1774272059923	6466b94b-6852-4797-9378-7ae617809699	2026-04-06 15:42:49.630284
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.products (id, company_id, name, default_price) FROM stdin;
1	1	Test	200
\.


--
-- Data for Name: purchase_invoices; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.purchase_invoices (id, account_id, company_id, supplier_name, tax_id, doc_no, doc_date, subtotal, vat_amount, total, note, created_at, source, source_id, document_status, status, deleted_at, source_type) FROM stdin;
1	6466b94b-6852-4797-9378-7ae617809699	\N	sdasdasd	5456464	456466	2026-03-23	500.00	35.00	535.00		2026-03-24 22:49:55.499746	\N	\N	issued	active	\N	manual
2	6466b94b-6852-4797-9378-7ae617809699	\N	ผู้ขาย2	2456211147854	22365	2026-03-25	2000.00	140.00	2140.00	\N	2026-03-25 11:27:48.425943	PO	ce944b2a-a78f-42e6-a344-9e66b82325df	issued	active	\N	manual
3	6466b94b-6852-4797-9378-7ae617809699	\N	กฟหกฟห	5456456	5145546	2026-03-25	500.00	35.00	535.00	\N	2026-03-25 22:17:36.522105	PO	159df7ce-c9c4-41d8-ac13-34c3a2163484	issued	active	\N	manual
4	6466b94b-6852-4797-9378-7ae617809699	\N	ฟหกกฟหก	หฟกฟหก525		2026-03-25	0.00	0.00	0.00	\N	2026-03-25 22:27:05.066701	PO	d86eac94-8438-4c7e-bd76-3521a07f5968	issued	active	\N	manual
5	6466b94b-6852-4797-9378-7ae617809699	\N	ฟกฟหกฟ	กหฟก5524	PO-202603-001	2026-03-26	4512.00	315.84	4827.84	\N	2026-03-25 22:38:00.327469	PO	2703e856-9cbe-471c-82dc-f57fee0051c6	issued	active	\N	manual
6	6466b94b-6852-4797-9378-7ae617809699	\N	กหฟกฟหก	2325412	PO-202603-002	2026-03-26	120466.00	8432.62	128898.62	\N	2026-03-25 22:44:19.331755	PO	c906900f-9564-4cf9-abc4-a0bf3f7cd713	issued	active	\N	manual
7	6466b94b-6852-4797-9378-7ae617809699	\N	หกดกหดด	1112122	PO-202603-003	2026-03-26	23019.00	1611.33	24630.33	\N	2026-03-25 23:15:11.977267	PO	6c494fce-77ee-416e-91bb-a9c235087635	issued	active	\N	manual
8	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านดาว	445125447884	PO-202603-006	2026-03-26	10000.00	700.00	10700.00	\N	2026-03-26 09:42:49.245777	PO	5105e717-4512-4989-9b21-5c7bf446e433	issued	active	\N	manual
9	6466b94b-6852-4797-9378-7ae617809699	\N	หจก. บ้านนับดิน	4521233254784	PO-202603-007	2026-03-26	300000.00	21000.00	321000.00	\N	2026-03-26 09:48:25.596655	PO	e746d9eb-ba86-4b8d-84c7-fc9ae253b704	issued	active	\N	manual
10	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254411254785	PO-202603-008	2026-03-26	120500.00	8435.00	128935.00	\N	2026-03-26 09:49:35.468569	PO	f547e6cf-fc91-4bc1-b28e-1ac2d7fe2be7	issued	active	\N	manual
11	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-009	\N	40000.00	2800.00	42800.00	\N	2026-03-26 11:59:59.705853	PO	6134cd59-b5e7-46be-a685-969612e487fe	issued	active	\N	manual
12	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-010	2026-03-26	50000.00	3500.00	53500.00	\N	2026-03-26 12:20:02.27001	PO	af57ef23-9c82-47b8-bb72-8d440b4da79a	issued	active	\N	manual
13	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-011	2026-03-25	50000.00	3500.00	53500.00	\N	2026-03-26 13:13:14.367118	PO	caf18fb2-ad68-4212-92e7-2446fee11efb	issued	active	\N	manual
14	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-012	2026-03-26	26000.00	1820.00	27820.00	\N	2026-03-26 13:13:21.752466	PO	8e07b9e3-bd6e-485d-9efd-3e12c5202a81	issued	active	\N	manual
15	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-013	2026-03-27	35000.00	2450.00	37450.00	\N	2026-03-26 23:28:08.262522	PO	b7d59130-95d5-48af-b4c5-6b86f97062cb	issued	active	\N	manual
16	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-014	2026-03-27	31500.00	2205.00	33705.00	\N	2026-03-26 23:29:16.040473	PO	84e436ec-9297-405a-867b-5dca7a45337a	issued	active	\N	manual
17	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-015	2026-03-27	500.00	35.00	535.00	\N	2026-03-27 01:31:56.306746	PO	09031006-c1be-4b74-9899-86f102d8f551	issued	active	\N	manual
18	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-016	2026-03-27	500.00	0.00	500.00	\N	2026-03-27 01:46:13.396678	PO	e1f59b72-f1d9-43c5-a782-54e9024e3be0	issued	active	\N	manual
19	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-017	2026-03-27	52.00	0.00	52.00	\N	2026-03-27 04:49:53.374108	PO	c7665081-00c0-41b8-8557-c0f68ec799f4	issued	active	\N	manual
20	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-018	2026-03-27	500.00	0.00	500.00	\N	2026-03-27 04:57:51.316221	PO	74f51b50-c313-455e-895a-e2cee4e5f3d1	issued	active	\N	manual
21	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-019	2026-03-27	4000.00	280.00	4280.00	\N	2026-03-27 05:06:43.65272	PO	d045a9b4-5aac-4df1-a5e0-da68213ca48e	issued	active	\N	manual
22	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-020	2026-03-27	8000.00	560.00	8560.00	\N	2026-03-27 06:00:44.120696	PO	10c1cf17-c988-4baf-a41c-0be24b0f8c64	issued	active	\N	manual
23	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-022	2026-03-27	500.00	35.00	535.00	\N	2026-03-27 09:17:38.996481	PO	e3e30b3c-0522-4d8e-beb2-2a3a35293640	issued	active	\N	manual
24	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-024	2026-03-27	21000.00	1470.00	22470.00	\N	2026-03-27 15:40:15.510818	PO	a02050ee-8b4a-458a-b8f5-f7a693333921	issued	active	\N	manual
25	6466b94b-6852-4797-9378-7ae617809699	\N	ร้านเจริญวัสดุ	123540025467	PO-202603-025	2026-03-27	8750.00	612.50	9362.50	\N	2026-03-27 16:06:41.967572	PO	20e6b2fc-8f90-4191-96f5-c06c1ba5827e	issued	active	\N	manual
26	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202603-026	2026-03-27	800.00	56.00	856.00	\N	2026-03-27 16:27:57.605827	PO	145a2569-5c95-481a-b738-0a080f58a425	issued	active	\N	manual
27	6466b94b-6852-4797-9378-7ae617809699	\N	บ้านดาว บ้านดิน	4565211125454	PO-202603-027	2026-03-28	12000.00	840.00	12840.00	\N	2026-03-28 01:19:04.427658	PO	753a6b4e-7918-40df-9e63-3311ab0395db	issued	active	\N	manual
28	e588ae04-1f53-4a43-a0cf-f8d921693b18	\N	สมหญิง แซ่ลี	1465033321452	PO-202603-001	2026-03-27	1640.00	114.80	1754.80	\N	2026-03-28 11:38:27.822301	PO	95002c5d-df64-431f-b061-73ed3d6ea3c0	issued	active	\N	manual
29	e588ae04-1f53-4a43-a0cf-f8d921693b18	\N	สมหญิง แซ่ลี	1465033321452	PO-202603-002	2026-03-28	6150.00	430.50	6580.50	\N	2026-03-28 12:10:27.357067	PO	b13725aa-9618-4fc6-9044-628d4941b3f9	issued	active	\N	manual
30	e588ae04-1f53-4a43-a0cf-f8d921693b18	\N	สมหญิง แซ่ลี	1465033321452	PO-202603-003	2026-03-28	7000.00	490.00	7490.00	\N	2026-03-28 12:12:17.765221	PO	3a917c81-44cd-4f36-8e06-fdf2b70a8a5f	issued	active	\N	manual
31	85f90f95-902a-4973-8349-114d333f1f6d	\N	หจก. สมชายค้าไม้	1450300069451	PO-202603-001	2026-03-31	80000.00	5600.00	85600.00	\N	2026-03-31 16:38:29.345134	PO	a4b2a83e-aa89-45b5-9891-df6e783a8511	issued	active	\N	manual
32	3b34b55e-f428-42ed-b913-32c313dfcfd9	\N	สมหญิง ขายดี	1420533326521	PO-202604-001	2026-04-03	25000.00	1750.00	26750.00	\N	2026-04-03 01:48:22.768909	PO	8693dce1-bc9b-43ec-a652-f56e183fa3aa	issued	active	\N	manual
33	9e051997-6e28-4b2a-af7a-5fef68524c52	\N	หจก. เรืองพร	1420032212547	PO-202604-001	2026-04-04	900.00	63.00	963.00	\N	2026-04-04 04:14:55.280301	PO	98d18b9d-5845-45cd-bffa-7add721967ad	issued	active	\N	manual
34	6466b94b-6852-4797-9378-7ae617809699	\N	ร้านเจริญวัสดุ	123540025467	PO-202604-001	2026-04-03	800.00	0.00	800.00	\N	2026-04-04 19:52:51.421315	PO	34f16a55-3bc0-4f91-b2af-16f18525c4f9	issued	active	\N	manual
35	6466b94b-6852-4797-9378-7ae617809699	\N	หจก.บ้านนับดิน	1254633369874	PO-202604-002	2026-04-05	88000.00	6160.00	94160.00	\N	2026-04-05 01:59:11.006874	PO	b38311e5-3e4d-4c62-853a-a11546da5903	issued	active	\N	manual
36	cf532569-58e0-4019-a00f-17a4966af22f	\N	หจก.ซีทีดี อินเตอร์เทรด	1420650001078	PO-202604-001	2026-04-05	15248.00	1067.36	16315.36	\N	2026-04-05 02:34:26.370222	PO	7dbe53a1-cb4a-4017-aa66-0e793a6a60c7	issued	active	\N	manual
37	6466b94b-6852-4797-9378-7ae617809699	\N	น้องฟ้าการช่าง	1254700125478	125478	2026-04-01	5000.00	350.00	5350.00		2026-04-05 03:26:37.331809	\N	\N	issued	active	\N	manual
38	6466b94b-6852-4797-9378-7ae617809699	\N	น้องฟ้าเจริญวัสดุ	12587425487	12544788	2026-04-05	10000.00	700.00	10700.00		2026-04-05 03:27:46.908004	\N	\N	issued	active	\N	manual
39	6466b94b-6852-4797-9378-7ae617809699	\N	ร้านเจริญวัสดุ	123540025467	PO-202604-003	2026-04-05	57000.00	3990.00	60990.00	\N	2026-04-05 03:38:21.426446	PO	a89cfb62-4c3f-4cb8-afe6-9be1926df365	issued	active	\N	manual
40	9d38fa5c-2f63-454a-a8c3-bbe684292236	\N	นายสมชาย	1245366608367	PO-202604-001	2026-04-05	1200.00	84.00	1284.00	\N	2026-04-05 16:36:09.235208	PO	4f954739-4107-45be-9384-e87cccea1047	issued	active	\N	manual
\.


--
-- Data for Name: purchase_order_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.purchase_order_items (id, purchase_order_id, description, quantity, unit_price, amount, account_id) FROM stdin;
5c96c50e-e436-435f-93b5-15ee8cca9bf8	19b80bda-5cf3-4011-bf66-ba6a3b045594	แตงโม	10	45	450	6466b94b-6852-4797-9378-7ae617809699
90fbd3f1-59cf-485d-8581-0265e5ccc529	19b80bda-5cf3-4011-bf66-ba6a3b045594	มะปราง	10	45	450	6466b94b-6852-4797-9378-7ae617809699
cd1bce25-e722-40fa-b76c-4c561ad9ddf9	ce944b2a-a78f-42e6-a344-9e66b82325df	แตงโมง	20	100	2000	6466b94b-6852-4797-9378-7ae617809699
76f17293-52f1-4f6b-8e61-ccefa43f1db0	159df7ce-c9c4-41d8-ac13-34c3a2163484	นมผง	10	50	500	6466b94b-6852-4797-9378-7ae617809699
7eb9f15a-80c8-4b50-8da7-402c7c489bba	d86eac94-8438-4c7e-bd76-3521a07f5968	กหฟกฟหก	20	500	10000	6466b94b-6852-4797-9378-7ae617809699
a3133661-76fa-46b5-bdf8-da095782c9ea	d86eac94-8438-4c7e-bd76-3521a07f5968	กหเกเเ	30	200	6000	6466b94b-6852-4797-9378-7ae617809699
bd7ac799-c38b-4f47-a300-2c2fa5c2c554	2703e856-9cbe-471c-82dc-f57fee0051c6	กหฟกฟหก	20	50	1000	6466b94b-6852-4797-9378-7ae617809699
e3fcc816-98fd-47f4-9995-25bd1012210b	2703e856-9cbe-471c-82dc-f57fee0051c6	กหดเกดเ	50	40	2000	6466b94b-6852-4797-9378-7ae617809699
64915219-6528-40b2-a20e-1baa1ad1faa2	2703e856-9cbe-471c-82dc-f57fee0051c6	ดหดหด	54	28	1512	6466b94b-6852-4797-9378-7ae617809699
6384a3f7-2a92-4f92-ba43-c0f9fe355f26	c906900f-9564-4cf9-abc4-a0bf3f7cd713	กหฟกฟหก	80	254	20320	6466b94b-6852-4797-9378-7ae617809699
346b9402-6ad4-49f2-a9cf-bda52206c9a2	c906900f-9564-4cf9-abc4-a0bf3f7cd713	ฟหกฟหกฟ	87	254	22098	6466b94b-6852-4797-9378-7ae617809699
5d6b42c5-7c78-46a0-9587-ee4df202c16d	c906900f-9564-4cf9-abc4-a0bf3f7cd713	กหฟกฟหก	542	144	78048	6466b94b-6852-4797-9378-7ae617809699
c3d2c13e-e897-46e9-8364-8163fb6da2ed	6c494fce-77ee-416e-91bb-a9c235087635	ดกหดหกดหกด	25	411	10275	6466b94b-6852-4797-9378-7ae617809699
8657e96a-5876-4497-92e4-368f829716ce	6c494fce-77ee-416e-91bb-a9c235087635	หฟกฟหกฟ	54	236	12744	6466b94b-6852-4797-9378-7ae617809699
ae18052c-b753-4f80-9635-9baea52447ff	f4ad2bd7-2a6f-4493-bb8a-35b737a4abd1	มะม่วงดอง	50	250	12500	6466b94b-6852-4797-9378-7ae617809699
5207b0c7-f2e7-442a-8e5e-666e6b59adae	f4ad2bd7-2a6f-4493-bb8a-35b737a4abd1	มะขามแช่อิ่ม	50	240	12000	6466b94b-6852-4797-9378-7ae617809699
b620039e-3eb9-4fa3-aafd-5d263ed315fa	872b80ac-c861-4cb9-8cd8-cf4b1c52450f	กหฟกฟหกก	50	500	25000	6466b94b-6852-4797-9378-7ae617809699
f11b65e2-db1e-480a-bffd-104804a87f59	5105e717-4512-4989-9b21-5c7bf446e433	ขนุน	500	20	10000	6466b94b-6852-4797-9378-7ae617809699
e715373a-2f3c-4ba3-bafd-74daf7af3f60	e746d9eb-ba86-4b8d-84c7-fc9ae253b704	สับปะรด	500	600	300000	6466b94b-6852-4797-9378-7ae617809699
6c84abc8-d06d-4838-ba6c-164035f3857c	f547e6cf-fc91-4bc1-b28e-1ac2d7fe2be7	มะเขือ	500	241	120500	6466b94b-6852-4797-9378-7ae617809699
ef83b799-cad2-4872-8d4a-5018eba6e148	6134cd59-b5e7-46be-a685-969612e487fe	มะนาว	4000	10	40000	6466b94b-6852-4797-9378-7ae617809699
72dd61d4-366a-4f0e-9884-3b86eb2d8db7	af57ef23-9c82-47b8-bb72-8d440b4da79a	มะขาวหวาน	500	100	50000	6466b94b-6852-4797-9378-7ae617809699
dcfc7a59-eb8c-443f-b5e4-4e667dc1556e	caf18fb2-ad68-4212-92e7-2446fee11efb	มะขาวหวาน	500	100	50000	6466b94b-6852-4797-9378-7ae617809699
0fc27822-9d8f-45d1-823c-0f3309dd3f9f	8e07b9e3-bd6e-485d-9efd-3e12c5202a81	มะม่วงแก้ว	500	52	26000	6466b94b-6852-4797-9378-7ae617809699
68e67607-7029-4464-b0cb-39b80ae22d53	b7d59130-95d5-48af-b4c5-6b86f97062cb	ปลาหมอแดดเดียว	500	70	35000	6466b94b-6852-4797-9378-7ae617809699
d6af5a9d-27b7-4d78-81af-87a2765dc1fb	84e436ec-9297-405a-867b-5dca7a45337a	ปลาช่อนแดดดเดียว	300	105	31500	6466b94b-6852-4797-9378-7ae617809699
99fa45ed-80dc-469a-9e46-67368dd31573	09031006-c1be-4b74-9899-86f102d8f551	ฟหกฟหกฟหกฟ	1	500	500	6466b94b-6852-4797-9378-7ae617809699
73bd3ef1-6fa4-4043-8195-499773913086	e1f59b72-f1d9-43c5-a782-54e9024e3be0	กฟหกฟหก	1	500	500	6466b94b-6852-4797-9378-7ae617809699
a382d6bc-c53a-4ec9-9a0a-fc9d4aa38440	c7665081-00c0-41b8-8557-c0f68ec799f4	asdasda	1	52	52	6466b94b-6852-4797-9378-7ae617809699
3dda3904-29fa-4331-8972-f0b27929629c	74f51b50-c313-455e-895a-e2cee4e5f3d1	กหฟกฟหก	1	500	500	6466b94b-6852-4797-9378-7ae617809699
f06c3a24-45d4-4dab-939d-b823b30292d6	d045a9b4-5aac-4df1-a5e0-da68213ca48e	กหฟกฟหกฟหก	10	400	4000	6466b94b-6852-4797-9378-7ae617809699
9283dad2-9bc3-4ad4-9bf5-a3082054424e	10c1cf17-c988-4baf-a41c-0be24b0f8c64	หกฟกฟหกฟก	1	8000	8000	6466b94b-6852-4797-9378-7ae617809699
f31f972f-1cd4-4cc1-b58d-20a0d4e7ff2d	ee8b96fa-577f-49fa-917d-56593531e708	หฤฆฟห	1	800	800	6466b94b-6852-4797-9378-7ae617809699
8ff48822-6037-4cd6-b4a8-050a1e66d3ca	e3e30b3c-0522-4d8e-beb2-2a3a35293640	กฟหกฟหก	1	500	500	6466b94b-6852-4797-9378-7ae617809699
90e90ae6-2983-4b87-9746-49024028f915	6391330a-bd40-4972-a2f8-b38f9a1dc04f	กฟหกฟก	1	900	900	6466b94b-6852-4797-9378-7ae617809699
e69271b0-7ab2-4cae-8afd-d277619fa2cd	a02050ee-8b4a-458a-b8f5-f7a693333921	มะม่วงเบา	500	42	21000	6466b94b-6852-4797-9378-7ae617809699
cdab0020-e233-402d-af88-69a11d3bff23	20e6b2fc-8f90-4191-96f5-c06c1ba5827e	ปูนเสือ	50	175	8750	6466b94b-6852-4797-9378-7ae617809699
31947c82-4058-401d-8a37-29300417683e	145a2569-5c95-481a-b738-0a080f58a425	ad	1	800	800	6466b94b-6852-4797-9378-7ae617809699
e63d828e-f37e-4eb7-964f-c786ed46763e	753a6b4e-7918-40df-9e63-3311ab0395db	มะยงชิด	500	24	12000	6466b94b-6852-4797-9378-7ae617809699
f2c233ef-2a3a-42da-a8e5-afaf74328218	95002c5d-df64-431f-b061-73ed3d6ea3c0	กะหล่ำดอก	70	12	840	e588ae04-1f53-4a43-a0cf-f8d921693b18
7f325c2b-8a2f-4430-a146-0ab140382f58	95002c5d-df64-431f-b061-73ed3d6ea3c0	สับปะรด	10	80	800	e588ae04-1f53-4a43-a0cf-f8d921693b18
96cdfddc-37c6-4d10-ac7c-4ecde15a3f3f	b13725aa-9618-4fc6-9044-628d4941b3f9	มะพร้าว	50	123	6150	e588ae04-1f53-4a43-a0cf-f8d921693b18
092b205c-5938-4639-9324-0c7f43e6735b	3a917c81-44cd-4f36-8e06-fdf2b70a8a5f	กหฟก	1	7000	7000	e588ae04-1f53-4a43-a0cf-f8d921693b18
0cac52c8-223c-477f-8d4a-5fc15bad810e	a9170b97-37bf-4035-8c9f-6b5314eb9eb1	กฟหก	1	801	801	e588ae04-1f53-4a43-a0cf-f8d921693b18
62ff4a4d-88ef-4610-8458-924aa6fbb975	d12641c0-77a1-4f91-8a6f-e6f78965fcc6	หฟกฟก	1	800	800	e588ae04-1f53-4a43-a0cf-f8d921693b18
d83d0476-6e0d-411f-8206-d068ef7253e4	a4b2a83e-aa89-45b5-9891-df6e783a8511	ไม้สัก 32ยก	32	2500	80000	85f90f95-902a-4973-8349-114d333f1f6d
541899c4-0340-4911-8e12-e26a438b27aa	8693dce1-bc9b-43ec-a652-f56e183fa3aa	มะม่วงแก้ว	500	50	25000	3b34b55e-f428-42ed-b913-32c313dfcfd9
3fce248e-829d-4ee7-9124-068a42a51a10	3cee0296-214c-4dc4-b5a8-012019116501	กหฟกฟก	1	800	800	ccaf622d-3ecc-4a57-9055-25c5c292cd2b
59418f8e-c0fd-4e9c-8a59-1930b81bd394	25672751-a836-41d0-8969-db0f4f653b49	ปผแผแ	1	500	500	6923c1d9-4f5a-40ba-8a1c-98fbf65f237a
629f3a8e-c779-47db-8530-a0b2b71d7b23	34f16a55-3bc0-4f91-b2af-16f18525c4f9	กหฟกฟหก	1	800	800	6466b94b-6852-4797-9378-7ae617809699
378c231e-5e59-431f-9ba0-a2a984e52711	a353aae6-1491-4ef5-bb79-9bef6ad4cddb	กหฟกฟหก	1	800	800	ccaf622d-3ecc-4a57-9055-25c5c292cd2b
a1fa1df6-9edd-409d-b1aa-d88fa32df3c4	98d18b9d-5845-45cd-bffa-7add721967ad	ท่อ PVC 1นิ้ว	20	45	900	9e051997-6e28-4b2a-af7a-5fef68524c52
7af2fcd5-fd49-4508-afce-a478ad17d7cd	b38311e5-3e4d-4c62-853a-a11546da5903	มะขาม	4000	22	88000	6466b94b-6852-4797-9378-7ae617809699
50205a63-7dcb-47ac-a6f0-78b0dd1e1a61	7dbe53a1-cb4a-4017-aa66-0e793a6a60c7	เครื่องทำความเย็น	1	15248	15248	cf532569-58e0-4019-a00f-17a4966af22f
9cc7b9e4-a73b-41ea-8b44-9115b5beae52	a89cfb62-4c3f-4cb8-afe6-9be1926df365	มะม่วง	1000	57	57000	6466b94b-6852-4797-9378-7ae617809699
b4e1bfd4-3011-4ff6-81da-62b794eb1c2a	4f954739-4107-45be-9384-e87cccea1047	มะม่วงแก้ว	100	12	1200	9d38fa5c-2f63-454a-a8c3-bbe684292236
\.


--
-- Data for Name: purchase_orders; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.purchase_orders (id, account_id, supplier_name, tax_id, doc_no, doc_date, subtotal, vat_amount, total, status, note, purchase_invoice_id, created_at, updated_at, vat_type, supplier_address, supplier_phone, supplier_tax_id, issue_date, company_name, company_address, company_tax_id, company_logo_url, company_phone, is_locked) FROM stdin;
19b80bda-5cf3-4011-bf66-ba6a3b045594	6466b94b-6852-4797-9378-7ae617809699	สายยนต์	1420366656987	22354	2026-03-25	900	63	963	paid	สินค้ามีราคาดีมาก	\N	2026-03-25 11:03:18.741885	2026-03-25 11:03:30.350844	none	\N	\N	\N	\N	\N	\N	\N	\N	\N	t
5105e717-4512-4989-9b21-5c7bf446e433	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านดาว	445125447884	PO-202603-006	2026-03-26	10000	700	10700	paid		\N	2026-03-26 09:42:41.834667	2026-03-26 09:42:41.834667	vat7	\N	\N	\N	\N	\N	\N	\N	\N	\N	t
ce944b2a-a78f-42e6-a344-9e66b82325df	6466b94b-6852-4797-9378-7ae617809699	ผู้ขาย2	2456211147854	22365	2026-03-25	2000	140	2140	paid	กินให้หมดภายในวันเดียว	2	2026-03-25 11:27:33.953297	2026-03-25 11:27:48.425943	none	\N	\N	\N	\N	\N	\N	\N	\N	\N	t
caf18fb2-ad68-4212-92e7-2446fee11efb	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-011	2026-03-25	50000	3500	53500	paid	ผลไม้บ้านผิงอัน	\N	2026-03-26 12:20:36.176689	2026-03-26 12:20:36.176689	vat7	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	2026-03-25	\N	\N	\N	\N	\N	t
84e436ec-9297-405a-867b-5dca7a45337a	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-014	2026-03-27	31500	2205	33705	paid		\N	2026-03-26 23:29:09.334969	2026-03-26 23:29:09.334969	vat7	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	2026-03-27	\N	\N	\N	\N	\N	t
159df7ce-c9c4-41d8-ac13-34c3a2163484	6466b94b-6852-4797-9378-7ae617809699	กฟหกฟห	5456456	5145546	2026-03-25	500	35	535	paid		3	2026-03-25 13:16:46.015612	2026-03-25 22:17:36.522105	none	\N	\N	\N	\N	\N	\N	\N	\N	\N	t
e746d9eb-ba86-4b8d-84c7-fc9ae253b704	6466b94b-6852-4797-9378-7ae617809699	หจก. บ้านนับดิน	4521233254784	PO-202603-007	2026-03-26	300000	21000	321000	paid		\N	2026-03-26 09:48:17.528928	2026-03-26 09:48:17.528928	vat7	\N	\N	\N	\N	\N	\N	\N	\N	\N	t
d86eac94-8438-4c7e-bd76-3521a07f5968	6466b94b-6852-4797-9378-7ae617809699	ฟหกกฟหก	หฟกฟหก525		2026-03-25	0	0	0	paid	กหฟกฟหกฟหก	4	2026-03-25 22:26:38.632777	2026-03-25 22:27:05.066701	vat7	\N	\N	\N	\N	\N	\N	\N	\N	\N	t
8e07b9e3-bd6e-485d-9efd-3e12c5202a81	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-012	2026-03-26	26000	1820	27820	paid		\N	2026-03-26 13:13:05.083879	2026-03-26 13:13:05.083879	vat7	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	2026-03-26	\N	\N	\N	\N	\N	t
2703e856-9cbe-471c-82dc-f57fee0051c6	6466b94b-6852-4797-9378-7ae617809699	ฟกฟหกฟ	กหฟก5524	PO-202603-001	2026-03-26	4512	315.84	4827.84	paid		5	2026-03-25 22:37:42.038121	2026-03-25 22:38:00.327469	vat7	\N	\N	\N	\N	\N	\N	\N	\N	\N	t
f547e6cf-fc91-4bc1-b28e-1ac2d7fe2be7	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254411254785	PO-202603-008	2026-03-26	120500	8435	128935	paid		\N	2026-03-26 09:49:29.915138	2026-03-26 09:49:29.915138	vat7	\N	\N	\N	\N	\N	\N	\N	\N	\N	t
c906900f-9564-4cf9-abc4-a0bf3f7cd713	6466b94b-6852-4797-9378-7ae617809699	กหฟกฟหก	2325412	PO-202603-002	2026-03-26	120466	8432.62	128898.62	paid	กหฟกฟหกฟหก	6	2026-03-25 22:44:06.79486	2026-03-25 22:44:19.331755	vat7	\N	\N	\N	\N	\N	\N	\N	\N	\N	t
74f51b50-c313-455e-895a-e2cee4e5f3d1	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-018	\N	500	0	500	paid		\N	2026-03-27 04:57:44.695002	2026-03-27 04:57:44.695002	none	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	2026-03-27	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	/uploads/logos/1774327832094-MLT_logo.png	\N	t
6c494fce-77ee-416e-91bb-a9c235087635	6466b94b-6852-4797-9378-7ae617809699	หกดกหดด	1112122	PO-202603-003	2026-03-26	23019	1611.33	24630.33	paid	ดกหดหกดหกดหกด	7	2026-03-25 22:49:20.032834	2026-03-25 23:15:11.977267	vat7	\N	\N	\N	\N	\N	\N	\N	\N	\N	t
6134cd59-b5e7-46be-a685-969612e487fe	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-009	\N	40000	2800	42800	paid		\N	2026-03-26 11:59:48.669522	2026-03-26 11:59:48.669522	vat7	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	\N	\N	\N	\N	\N	\N	t
f4ad2bd7-2a6f-4493-bb8a-35b737a4abd1	6466b94b-6852-4797-9378-7ae617809699	หจก.นงค์ลักษณ์	4521141254787	PO-202603-004	2026-03-26	24500	1715	26215	paid		\N	2026-03-26 07:21:43.024086	2026-03-26 07:21:43.024086	vat7	\N	\N	\N	\N	\N	\N	\N	\N	\N	t
e1f59b72-f1d9-43c5-a782-54e9024e3be0	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-016	\N	500	0	500	paid		\N	2026-03-27 01:46:07.108707	2026-03-27 01:46:07.108707	none	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	2026-03-27	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	/uploads/logos/1774327832094-MLT_logo.png	\N	t
b7d59130-95d5-48af-b4c5-6b86f97062cb	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-013	2026-03-27	35000	2450	37450	paid		\N	2026-03-26 23:27:58.195968	2026-03-26 23:27:58.195968	vat7	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	2026-03-27	\N	\N	\N	\N	\N	t
872b80ac-c861-4cb9-8cd8-cf4b1c52450f	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านดาว	5542111145444	PO-202603-005	2026-03-26	25000	1750	26750	paid		\N	2026-03-26 09:35:11.130324	2026-03-26 09:35:11.130324	vat7	\N	\N	\N	\N	\N	\N	\N	\N	\N	t
af57ef23-9c82-47b8-bb72-8d440b4da79a	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-010	\N	50000	3500	53500	paid	ผลไม้บ้านผิงอัน	\N	2026-03-26 12:19:39.313316	2026-03-26 12:19:39.313316	vat7	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	2026-03-26	\N	\N	\N	\N	\N	t
09031006-c1be-4b74-9899-86f102d8f551	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-015	\N	500	35	535	paid		\N	2026-03-27 01:31:49.34595	2026-03-27 01:31:49.34595	vat7	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	2026-03-27	บริษัท มลทต3 จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	/uploads/logos/1774327832094-MLT_logo.png	\N	t
c7665081-00c0-41b8-8557-c0f68ec799f4	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-017	\N	52	0	52	paid		\N	2026-03-27 04:49:43.433451	2026-03-27 04:49:43.433451	none	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	2026-03-27	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	/uploads/logos/1774327832094-MLT_logo.png	\N	t
d045a9b4-5aac-4df1-a5e0-da68213ca48e	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-019	\N	4000	280	4280	paid		\N	2026-03-27 05:06:35.870101	2026-03-27 05:06:35.870101	vat7	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	2026-03-27	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	/uploads/logos/1774327832094-MLT_logo.png	\N	t
10c1cf17-c988-4baf-a41c-0be24b0f8c64	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-020	2026-03-27	8000	560	8560	paid		\N	2026-03-27 06:00:37.562442	2026-03-27 06:00:37.562442	vat7	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	2026-03-27	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	/uploads/logos/1774327832094-MLT_logo.png	0849197741	t
ee8b96fa-577f-49fa-917d-56593531e708	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-021	2026-03-27	800	56	856	approved		\N	2026-03-27 07:48:50.986864	2026-03-27 07:48:50.986864	vat7	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	2026-03-27	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	/uploads/logos/1774327832094-MLT_logo.png	0849197741	t
e3e30b3c-0522-4d8e-beb2-2a3a35293640	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-022	2026-03-27	500	35	535	paid		\N	2026-03-27 08:17:54.051939	2026-03-27 08:17:54.051939	vat7	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	\N	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	/uploads/logos/1774327832094-MLT_logo.png	0849197741	t
6391330a-bd40-4972-a2f8-b38f9a1dc04f	6466b94b-6852-4797-9378-7ae617809699	บ้านดาว บ้านดิน	4565211125454	PO-202603-023	2026-03-27	900	63	963	cancelled		\N	2026-03-27 09:18:06.753481	2026-03-27 09:18:09.977515	vat7	542 หมู่7 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย 42160	0852462213	4565211125454	\N	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	/uploads/logos/1774327832094-MLT_logo.png	0849197741	t
145a2569-5c95-481a-b738-0a080f58a425	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-026	2026-03-27	800	56	856	paid		\N	2026-03-27 16:27:48.119296	2026-03-27 16:27:48.119296	vat7	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	\N	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	/uploads/logos/1774628793548-MLT_logo.png	0849197741	t
a02050ee-8b4a-458a-b8f5-f7a693333921	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202603-024	2026-03-27	21000	1470	22470	paid		\N	2026-03-27 15:40:05.178677	2026-03-27 15:40:05.178677	vat7	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	\N	บริษัท มลทต5จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	/uploads/logos/1774327832094-MLT_logo.png	0849197741	t
a9170b97-37bf-4035-8c9f-6b5314eb9eb1	e588ae04-1f53-4a43-a0cf-f8d921693b18	สมหญิง แซ่ลี	1465033321452	PO-202603-004	2026-03-28	801	56.07	857.07	draft		\N	2026-03-28 12:13:01.264336	2026-03-28 12:13:01.264336	vat7	78 หมู่8 ต.เข็กน้อย อ.น้ำหนาว จ.เพชรบูรณ์ 45110	0523365941	1465033321452	\N	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	f
d12641c0-77a1-4f91-8a6f-e6f78965fcc6	e588ae04-1f53-4a43-a0cf-f8d921693b18	สมหญิง แซ่ลี	1465033321452	PO-202603-005	2026-03-28	800	0	800	draft		\N	2026-03-28 12:43:50.291211	2026-03-28 12:43:50.291211	none	78 หมู่8 ต.เข็กน้อย อ.น้ำหนาว จ.เพชรบูรณ์ 45110	0523365941	1465033321452	\N	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	f
20e6b2fc-8f90-4191-96f5-c06c1ba5827e	6466b94b-6852-4797-9378-7ae617809699	ร้านเจริญวัสดุ	123540025467	PO-202603-025	2026-03-27	8750	612.5	9362.5	paid		\N	2026-03-27 16:06:00.61614	2026-03-27 16:06:00.61614	vat7	45 หมู่7 ต.นาดี อ.ด่านซ้าย จ.เลย	0541236547	123540025467	\N	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	/uploads/logos/1774627412526-0000.png	0849197741	t
b13725aa-9618-4fc6-9044-628d4941b3f9	e588ae04-1f53-4a43-a0cf-f8d921693b18	สมหญิง แซ่ลี	1465033321452	PO-202603-002	2026-03-28	6150	430.5	6580.5	paid		\N	2026-03-28 12:10:19.419058	2026-03-28 12:10:19.419058	vat7	78 หมู่8 ต.เข็กน้อย อ.น้ำหนาว จ.เพชรบูรณ์ 45110	0523365941	1465033321452	\N	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	\N	0846661234	t
753a6b4e-7918-40df-9e63-3311ab0395db	6466b94b-6852-4797-9378-7ae617809699	บ้านดาว บ้านดิน	4565211125454	PO-202603-027	2026-03-28	12000	840	12840	paid		\N	2026-03-28 01:18:51.983029	2026-03-28 01:18:51.983029	vat7	542 หมู่7 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย 42160	0852462213	4565211125454	\N	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	/uploads/logos/1774628793548-MLT_logo.png	0849197741	t
95002c5d-df64-431f-b061-73ed3d6ea3c0	e588ae04-1f53-4a43-a0cf-f8d921693b18	สมหญิง แซ่ลี	1465033321452	PO-202603-001	2026-03-27	1640	114.8	1754.8	paid		\N	2026-03-28 11:38:12.757931	2026-03-28 11:38:12.757931	vat7	78 หมู่8 ต.เข็กน้อย อ.น้ำหนาว จ.เพชรบูรณ์ 45110	0523365941	1465033321452	2026-03-27	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	\N	0846661234	t
25672751-a836-41d0-8969-db0f4f653b49	6923c1d9-4f5a-40ba-8a1c-98fbf65f237a	ผปแผปแ		PO-202604-001	2026-04-03	500	35	535	draft		\N	2026-04-03 05:05:01.797809	2026-04-03 05:05:01.797809	vat7	ปผแผปแ			\N				\N		f
3a917c81-44cd-4f36-8e06-fdf2b70a8a5f	e588ae04-1f53-4a43-a0cf-f8d921693b18	สมหญิง แซ่ลี	1465033321452	PO-202603-003	2026-03-28	7000	490	7490	paid		\N	2026-03-28 12:12:11.1026	2026-03-28 12:12:11.1026	vat7	78 หมู่8 ต.เข็กน้อย อ.น้ำหนาว จ.เพชรบูรณ์ 45110	0523365941	1465033321452	\N	หจก. บ้านนาดอยคำ	232 หมู่4 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย	1450300069874	/uploads/logos/1774699852522-S__6381582.jpg	0846661234	t
8693dce1-bc9b-43ec-a652-f56e183fa3aa	3b34b55e-f428-42ed-b913-32c313dfcfd9	สมหญิง ขายดี	1420533326521	PO-202604-001	2026-04-03	25000	1750	26750	paid		\N	2026-04-03 01:48:09.728927	2026-04-03 01:48:09.728927	vat7	41 หมู่14 ต.นาดร อ.เมือง จ.เลย	0884512474	1420533326521	\N				\N		t
a4b2a83e-aa89-45b5-9891-df6e783a8511	85f90f95-902a-4973-8349-114d333f1f6d	หจก. สมชายค้าไม้	1450300069451	PO-202603-001	2026-03-31	80000	5600	85600	paid		\N	2026-03-31 16:37:53.015918	2026-03-31 16:37:53.015918	vat7	25 หมู่11 ต.นาอาน อ.เมือง จ.เลย 42000	0844451245	1450300069451	2026-03-31				\N		t
a353aae6-1491-4ef5-bb79-9bef6ad4cddb	ccaf622d-3ecc-4a57-9055-25c5c292cd2b	ฟหกฟหก		PO-202604-002	2026-04-03	800	0	800	draft		\N	2026-04-03 08:14:46.446725	2026-04-03 08:14:46.446725	none	กหฟกฟหก	กหฟกฟหกฟ		\N				\N		f
3cee0296-214c-4dc4-b5a8-012019116501	ccaf622d-3ecc-4a57-9055-25c5c292cd2b	กหฟกฟหก		PO-202604-001	2026-04-03	800	56	856	received		\N	2026-04-03 04:36:01.266619	2026-04-03 04:36:01.266619	vat7	กหฟก			\N				\N		f
34f16a55-3bc0-4f91-b2af-16f18525c4f9	6466b94b-6852-4797-9378-7ae617809699	ร้านเจริญวัสดุ	123540025467	PO-202604-001	2026-04-03	800	0	800	paid		\N	2026-04-03 07:35:53.18769	2026-04-03 07:35:53.18769	none	45 หมู่7 ต.นาดี อ.ด่านซ้าย จ.เลย	0541236547	123540025467	\N	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	t
98d18b9d-5845-45cd-bffa-7add721967ad	9e051997-6e28-4b2a-af7a-5fef68524c52	หจก. เรืองพร	1420032212547	PO-202604-001	2026-04-04	900	63	963	paid		\N	2026-04-04 04:14:50.070361	2026-04-04 04:14:50.070361	vat7	254 หมู่7 ต.นาอาน อ.เมือง จ.เลย 42000	0054412147	1420032212547	\N	หจก. ซีทีดี อินเตอร์เทรด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย 42000	14205001651087	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775275918903-MLT_logo.png	0849197741	t
a89cfb62-4c3f-4cb8-afe6-9be1926df365	6466b94b-6852-4797-9378-7ae617809699	ร้านเจริญวัสดุ	123540025467	PO-202604-003	2026-04-05	57000	3990	60990	paid		\N	2026-04-05 03:37:05.245671	2026-04-05 03:37:05.245671	vat7	45 หมู่7 ต.นาดี อ.ด่านซ้าย จ.เลย	0541236547	123540025467	2026-04-05	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	t
b38311e5-3e4d-4c62-853a-a11546da5903	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	1254633369874	PO-202604-002	2026-04-05	88000	6160	94160	paid		\N	2026-04-05 01:58:43.938624	2026-04-05 01:58:43.938624	vat7	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	\N	บริษัท มลทต6จำกัด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	142000650187	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775144925786-1.jpg	0849197741	t
7dbe53a1-cb4a-4017-aa66-0e793a6a60c7	cf532569-58e0-4019-a00f-17a4966af22f	หจก.ซีทีดี อินเตอร์เทรด	1420650001078	PO-202604-001	2026-04-05	15248	1067.36	16315.36	paid		\N	2026-04-05 02:34:17.229009	2026-04-05 02:34:17.229009	vat7	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	1420650001078	\N	บริษัท เมืองเลยแทรกเตอร์ จำกัด	287 หมู่ 6 ต.นาอาน อ.เมือง จ.เลย 42000	1420000201697	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775354817483-MLT_logo.png	0846612354	t
4f954739-4107-45be-9384-e87cccea1047	9d38fa5c-2f63-454a-a8c3-bbe684292236	นายสมชาย	1245366608367	PO-202604-001	2026-04-05	1200	84	1284	paid		\N	2026-04-05 16:35:50.472458	2026-04-05 16:35:50.472458	vat7	บ้านนาน้อย	0089764561	1245366608367	2026-04-05	หจก.ซีทีดี อินเตอร์เทรด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	1420560010187	https://enxhpxhbnzrncijqboqh.supabase.co/storage/v1/object/public/uploads/company/1775406622210-IMG_5147.jpeg	0849197741	t
\.


--
-- Data for Name: running_numbers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.running_numbers (company_id, next_no) FROM stdin;
1	26
\.


--
-- Data for Name: running_numbers_account; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.running_numbers_account (account_id, doc_type, next_no) FROM stdin;
6466b94b-6852-4797-9378-7ae617809699	INV	15
\.


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.suppliers (id, account_id, name, address, phone, tax_id, created_at, updated_at, deleted_at) FROM stdin;
33906a60-ece3-47dc-962d-83aeff516a69	00000000-0000-0000-0000-000000000001	SoftDel Supplier	Addr	0888888888	TAXS	2026-03-26 10:34:33.08026	2026-03-26 10:34:33.08026	2026-03-26 10:34:33.176706
0ba30d7d-5f4b-42f5-812a-8c5ed8aa5c5f	6466b94b-6852-4797-9378-7ae617809699	SUPP_SOFT_DELETE_TEST				2026-03-26 10:54:09.209331	2026-03-26 10:54:16.205433	2026-03-26 10:54:16.205433
84a338c0-bf00-47a0-a0a5-5b98390fd11d	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	42 หมู่6 ต.นาแห้ว อ.นาแห้ว จ.เลย	0541233692	1254699985424	2026-03-26 10:28:00.325415	2026-03-26 11:25:18.660876	2026-03-26 11:25:18.660876
d2fa032e-cf92-45cc-a402-97ee73e05a62	6466b94b-6852-4797-9378-7ae617809699	หจก.บ้านนับดิน	323 หมู่4 บ้านฟากนา ต.นาอาน อ.เมือง จ.เลย 42000	0587412236	1254633369874	2026-03-26 11:27:05.193995	2026-03-26 11:27:05.193995	\N
63c7236b-b57a-45fa-b34b-3c4a2d04f1f5	6466b94b-6852-4797-9378-7ae617809699	บ้านดาว บ้านดิน	542 หมู่7 ต.ท่าสวรรค์ อ.นาด้วง จ.เลย 42160	0852462213	4565211125454	2026-03-27 05:10:20.002022	2026-03-27 05:10:20.002022	\N
62238a91-a04c-415a-9f52-618f6364abc8	6466b94b-6852-4797-9378-7ae617809699	หจก. 254	42 หมู่4 ต.นาอาน อ.เมือง จ.เลย	0884512365	1245575654123	2026-03-27 09:32:34.102516	2026-03-27 09:32:43.008285	2026-03-27 09:32:43.008285
5ebf5b67-1013-4bc6-bda2-30aa2176bb05	6466b94b-6852-4797-9378-7ae617809699	ร้านเรืองพร	365 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0884565214	143026000654	2026-03-27 15:43:56.594021	2026-03-27 15:44:17.616282	\N
def0d982-3807-4978-878c-a7d17322354a	6466b94b-6852-4797-9378-7ae617809699	ร้านเจริญวัสดุ	45 หมู่7 ต.นาดี อ.ด่านซ้าย จ.เลย	0541236547	123540025467	2026-03-27 16:05:30.294876	2026-03-27 16:05:30.294876	\N
72ed796f-d89e-4299-ae0c-d34157e16148	e588ae04-1f53-4a43-a0cf-f8d921693b18	สมหญิง แซ่ลี	78 หมู่8 ต.เข็กน้อย อ.น้ำหนาว จ.เพชรบูรณ์ 45110	0523365941	1465033321452	2026-03-28 11:37:26.329223	2026-03-28 11:37:26.329223	\N
239c53d2-c25c-4c51-b900-6732ad5f393b	85f90f95-902a-4973-8349-114d333f1f6d	หจก. สมชายค้าไม้	25 หมู่11 ต.นาอาน อ.เมือง จ.เลย 42000	0844451245	1450300069451	2026-03-31 16:37:13.638696	2026-03-31 16:37:13.638696	\N
d4c12d06-7ffa-4795-bf84-d3ef992634f1	3b34b55e-f428-42ed-b913-32c313dfcfd9	สมหญิง ขายดี	41 หมู่14 ต.นาดร อ.เมือง จ.เลย	0884512474	1420533326521	2026-04-03 01:47:48.891576	2026-04-03 01:47:48.891576	\N
23fedf63-d762-4005-b4b0-4d07d9468055	9e051997-6e28-4b2a-af7a-5fef68524c52	หจก. เรืองพร	254 หมู่7 ต.นาอาน อ.เมือง จ.เลย 42000	0054412147	1420032212547	2026-04-04 04:11:41.041837	2026-04-04 04:11:41.041837	\N
942951b0-e82e-4bb2-b332-bbf91337aec7	cf532569-58e0-4019-a00f-17a4966af22f	หจก.ซีทีดี อินเตอร์เทรด	287 หมู่6 ต.นาอาน อ.เมือง จ.เลย	0849197741	1420650001078	2026-04-05 02:24:31.285977	2026-04-05 02:24:31.285977	\N
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, account_id, company_id, email, password_hash, google_sub, google_email, google_name, google_picture) FROM stdin;
1cfab6bd-7efa-456c-8c85-ba932a4e4a6c	b79d79f9-02d5-4707-b34b-cbaa885e90c4	43b9b265-4b27-4c92-979f-c15f54d6dac4	mymakecase2@gmail.com	$2b$10$YoEOewANbGstgfKxZg.AOe5LrBwhcXy67qvO2tHdkArH1F/963vSu	\N	\N	\N	\N
5dc1cefc-1030-49c6-8fe8-f135dab23849	4282ac46-6b21-4774-8558-3671ea5e7286	54d4faaf-a159-48b9-8151-9283c134e104	nxcase378@gmail.com	$2b$10$o6DqXEgdzD.WhfW8u.QnRuAgLEKK/g2QJ412CsfgBT4Qpt0cQQzxC	\N	\N	\N	\N
52c523b0-16be-4377-b751-fe55d5854c93	aab7591d-19da-43ca-b51e-3169b4c67447	9f268602-28e8-4b75-88ea-2a3a0dd96bc6	nxcase38@gmail.com	$2b$10$zffLpFLOtMDJPVL1DJEta.6DxDaQ9EUAEF8dc8Kv6QTWeZxJ5cQcy	\N	\N	\N	\N
8f2c4aea-baea-43a4-9b9a-00532505de0c	d9690699-aa6a-4750-a095-0f41daa0ad3e	9c0f5cc3-97e8-49d1-bba5-4ad40457b90b	nxcase21@gmail.com	$2b$10$5VzUSXhrnNulCqW3yRoTyOWohzvrVet4/4m6GOepIKe5Bf94ogEum	\N	\N	\N	\N
46dfa8ae-bac1-4762-8b96-c4b982ffaede	f4730610-3b71-4293-971d-e783c27e71da	83fb7bb1-eb1c-4b29-9b9b-89aa308be8ca	nxcase22@gmail.com	$2b$10$lStlVNah8PcslSt9Un2V9uT05JKeLQESAeYr.e/dhRyc5i13UMnYi	\N	\N	\N	\N
c3c5da7a-533b-469e-9b2c-d8f17d76e9af	62f62fde-9246-4046-8cb1-44ea71c88eed	0dccffc2-db29-440a-b2f9-ea2833ea868c	nxcase23@gmail.com	$2b$10$NeCgJHT2n48tznIw7n9NgOooSeGFqdDVi1WopKL2xGBrlrtZNrxZ6	\N	\N	\N	\N
7622a90e-71d6-40d6-8170-b9d0e9524c90	981d9a04-3481-4b68-b259-89044e600f46	e72c5228-e497-46c5-a705-c20c344e172f	nxcase30@gmail.com	$2b$10$7sBwdDRlPDrTS8Xbxtf03O6iliXt0d54WEJ5LaoVqTx9pL16s1K56	\N	\N	\N	\N
f10c6fd3-6e3d-4372-8207-d329214d4e5c	3b34b55e-f428-42ed-b913-32c313dfcfd9	f13f8cb6-27bd-4518-9737-2a9e8ec743fc	nxcase24@gmail.com	$2b$10$LZKZyLlSDWbpjxX8Holr5OdqIfMbVM8WM3lGgQIWrfyHwGkYkZXVy	\N	\N	\N	\N
261bfef8-6d9b-42a0-aa38-3d38a65e0ed1	ccaf622d-3ecc-4a57-9055-25c5c292cd2b	f04f114b-3582-4b48-8353-b386e775b01a	nxcase25@gmail.com	$2b$10$Eitd32CKqYw2pfcvMCQLv.Ol1z0pKucyKEqjbNaX0S2EKBjYk5ZSa	\N	\N	\N	\N
bb71d5dd-d64e-4a35-aca1-c2ab426c2e39	6923c1d9-4f5a-40ba-8a1c-98fbf65f237a	bd3ce7c7-4556-4ada-a309-56aea278c887	nxacse25@gmail.com	$2b$10$ga/.V3do3rClarwBmeUUmemypmJ02F2MzG2.x0.BalmnPZ7QtnlIq	\N	\N	\N	\N
959c5c2a-3770-4634-bef0-925ae9c4c92c	0fe26c00-1639-4523-9971-8700ac12c31e	e2a687b2-c91f-43c3-bbef-fdbd4d791c1f	nxcase37@gmail.com	$2b$10$rPYuFpl.Hpz0peD4cRokEeLzcSI/eFtyXNsUeZsf7QWIAnJUQckYu	111008676422038306473	\N	\N	\N
195cfe73-9653-4269-a7b6-bae157057690	cf532569-58e0-4019-a00f-17a4966af22f	ba977b0c-0efe-4acf-a417-2a50f6e3cd7e	nxcase20@gmail.com	$2b$10$zsXwF3RCEciPGy3Kkdv0V.bQoe/Uq1eVXXfrTi5hLvRGBeAevRK1a	111777423444084906663	\N	\N	\N
82cfd3c8-0dde-40ac-a392-110bf842b3fa	6466b94b-6852-4797-9378-7ae617809699	634dfd90-166c-49ea-a03f-211a1502bffc	nxcase19@gmail.com	$2b$10$lodv/U9KbcTVbpYEpvgAy.oStE4AWkDvV/Oc83vnVHCCHOQbWzPq.	101135935509823788379	\N	\N	\N
ffd19b24-ebb3-4120-a668-fcc129615193	85f90f95-902a-4973-8349-114d333f1f6d	2cbd90e7-6347-4bdf-ad7b-e827c2107698	sujittrasaiyon@gmail.com	$2b$10$iMRZz8Gy.tuxHLT4CIJnbuWBA0RFp8czjsBSvZ1cLbIn2NPSSIUS6	108273100370177753488	\N	\N	\N
2f1f70b3-0953-481e-ae46-2046187ca8e3	9e051997-6e28-4b2a-af7a-5fef68524c52	e8736d54-4feb-4d02-8d94-8ac5be2e0392	ctdinterr@gmail.com	\N	104719919104638244747	\N	\N	\N
f3954347-cd74-41cb-91a3-7e1b6b568ca9	07c55228-eacb-4cd8-9490-1f6f75adc2a6	431c827b-7414-466f-9dc8-7399f4a73aa7	sujittrapingan@gmail.com	\N	105022305099933184831	\N	\N	\N
2604eabd-f4f2-406b-88a2-af593a522ab0	e588ae04-1f53-4a43-a0cf-f8d921693b18	fcafe18b-a9ad-46eb-bddd-d6750212c7b6	find4rich@gmail.com	$2b$10$dKiCl7xuNKndR5NgHVPD.O7O1eXb7l74TJbRpKfLiNSrgO72TzwWy	100427204675255709717	\N	\N	\N
5ed379ba-d371-4e43-8df9-0f7265c836da	15609794-437b-4504-91a1-9a1a0c055ea8	e8c9ae67-dfc9-475b-93de-3ea7d608c678	3866shop@gmail.com	\N	106329827307077877891	\N	\N	\N
a6c065a9-6477-4419-85e0-f4301e53b405	d9892940-318d-45aa-819f-20b23d1aa336	b003c755-1b95-44cd-9bc6-d844b5618f3c	vantamas110802@gmail.com	$2b$10$6FT4be0NJD.Xv95S3yufU.2BQXdUa.JVeDGEp1DE5cBxoiuuLGMAq	\N	\N	\N	\N
656ec062-ddf8-40b0-81a6-f79ffebe9e9e	50ebcc47-10bc-4f05-9da5-04ca074acd86	05e896c0-50ef-4ee9-bca4-5b5146cc42d2	thaiuvprinter@gmail.com	\N	100662717657396016234	\N	\N	\N
97b9b834-608a-4a2b-8568-081ef2a078e6	9d38fa5c-2f63-454a-a8c3-bbe684292236	7be88329-c7cb-4c2f-a29b-ba6521765a7e	kasetparuay1995@gmail.com	\N	104077375226318472116	\N	\N	\N
3dec1601-9702-4850-b18f-5f139e4223ab	f86ea2b3-412d-40fa-a75c-efc0f23a4ac2	15d65058-4d3c-40ab-a5f9-bbf29c60b398	mymakecase@gmail.com	$2b$10$Zn2qVisOkx4Ptgo0oVyhmuk2P.FT3jZa9uz19yocSk4ZkVIfg9eeC	105305652625046439682	\N	\N	\N
95869871-8b65-40bc-af06-e9a3fc83185d	c8dc8caa-fb14-4cbf-8e30-da29c8ef0ac0	18f8d045-9f22-4b10-8a72-2cf07bdfedae	supraneesutan@gmail.com	$2b$10$NaJ5PIZsfBmZB1ITY/ckROUeankyqd7oGEn4ECzPcvhpL71PObbB2	\N	\N	\N	\N
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.schema_migrations (version, inserted_at) FROM stdin;
20211116024918	2026-03-20 21:18:33
20211116045059	2026-03-20 21:18:34
20211116050929	2026-03-20 21:18:34
20211116051442	2026-03-20 21:18:34
20211116212300	2026-03-20 21:18:34
20211116213355	2026-03-20 21:18:34
20211116213934	2026-03-20 21:18:34
20211116214523	2026-03-20 21:18:35
20211122062447	2026-03-20 21:18:35
20211124070109	2026-03-20 21:18:35
20211202204204	2026-03-20 21:18:35
20211202204605	2026-03-20 21:18:35
20211210212804	2026-03-20 21:18:35
20211228014915	2026-03-20 21:18:35
20220107221237	2026-03-20 21:18:35
20220228202821	2026-03-20 21:18:35
20220312004840	2026-03-20 21:18:35
20220603231003	2026-03-20 21:18:36
20220603232444	2026-03-20 21:18:36
20220615214548	2026-03-20 21:18:36
20220712093339	2026-03-20 21:18:36
20220908172859	2026-03-20 21:18:36
20220916233421	2026-03-20 21:18:36
20230119133233	2026-03-20 21:18:36
20230128025114	2026-03-20 21:18:36
20230128025212	2026-03-20 21:18:36
20230227211149	2026-03-20 21:18:36
20230228184745	2026-03-20 21:18:36
20230308225145	2026-03-20 21:18:36
20230328144023	2026-03-20 21:18:36
20231018144023	2026-03-20 21:18:36
20231204144023	2026-03-20 21:18:36
20231204144024	2026-03-20 21:18:36
20231204144025	2026-03-20 21:18:36
20240108234812	2026-03-20 21:18:36
20240109165339	2026-03-20 21:18:36
20240227174441	2026-03-20 21:18:36
20240311171622	2026-03-20 21:18:36
20240321100241	2026-03-20 21:18:36
20240401105812	2026-03-20 21:18:36
20240418121054	2026-03-20 21:18:36
20240523004032	2026-03-21 02:28:08
20240618124746	2026-03-21 02:28:08
20240801235015	2026-03-21 02:28:08
20240805133720	2026-03-21 02:28:08
20240827160934	2026-03-21 02:28:08
20240919163303	2026-03-21 02:28:08
20240919163305	2026-03-21 02:28:08
20241019105805	2026-03-21 02:28:08
20241030150047	2026-03-21 02:28:08
20241108114728	2026-03-21 02:28:08
20241121104152	2026-03-21 02:28:08
20241130184212	2026-03-21 02:28:08
20241220035512	2026-03-21 02:28:08
20241220123912	2026-03-21 02:28:08
20241224161212	2026-03-21 02:28:08
20250107150512	2026-03-21 02:28:08
20250110162412	2026-03-21 02:28:08
20250123174212	2026-03-21 02:28:08
20250128220012	2026-03-21 02:28:08
20250506224012	2026-03-21 02:28:08
20250523164012	2026-03-21 02:28:08
20250714121412	2026-03-21 02:28:08
20250905041441	2026-03-21 02:28:08
20251103001201	2026-03-21 02:28:08
20251120212548	2026-03-21 02:28:08
20251120215549	2026-03-21 02:28:08
20260218120000	2026-03-21 02:28:08
\.


--
-- Data for Name: subscription; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.subscription (id, subscription_id, entity, filters, claims, created_at, action_filter) FROM stdin;
\.


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets (id, name, owner, created_at, updated_at, public, avif_autodetection, file_size_limit, allowed_mime_types, owner_id, type) FROM stdin;
uploads	uploads	\N	2026-04-02 15:34:52.171954+00	2026-04-02 15:34:52.171954+00	t	f	\N	\N	\N	STANDARD
STORAGE_BUCKET	STORAGE_BUCKET	\N	2026-04-02 15:38:21.015261+00	2026-04-02 15:38:21.015261+00	t	f	\N	\N	\N	STANDARD
\.


--
-- Data for Name: buckets_analytics; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets_analytics (name, type, format, created_at, updated_at, id, deleted_at) FROM stdin;
\.


--
-- Data for Name: buckets_vectors; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets_vectors (id, type, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.migrations (id, name, hash, executed_at) FROM stdin;
0	create-migrations-table	e18db593bcde2aca2a408c4d1100f6abba2195df	2026-03-20 21:18:33.503284
1	initialmigration	6ab16121fbaa08bbd11b712d05f358f9b555d777	2026-03-20 21:18:33.722632
2	storage-schema	f6a1fa2c93cbcd16d4e487b362e45fca157a8dbd	2026-03-20 21:18:33.730849
3	pathtoken-column	2cb1b0004b817b29d5b0a971af16bafeede4b70d	2026-03-20 21:18:34.250886
4	add-migrations-rls	427c5b63fe1c5937495d9c635c263ee7a5905058	2026-03-20 21:18:35.899804
5	add-size-functions	79e081a1455b63666c1294a440f8ad4b1e6a7f84	2026-03-20 21:18:35.910276
6	change-column-name-in-get-size	ded78e2f1b5d7e616117897e6443a925965b30d2	2026-03-20 21:18:35.959902
7	add-rls-to-buckets	e7e7f86adbc51049f341dfe8d30256c1abca17aa	2026-03-20 21:18:35.965467
8	add-public-to-buckets	fd670db39ed65f9d08b01db09d6202503ca2bab3	2026-03-20 21:18:35.970304
9	fix-search-function	af597a1b590c70519b464a4ab3be54490712796b	2026-03-20 21:18:35.982613
10	search-files-search-function	b595f05e92f7e91211af1bbfe9c6a13bb3391e16	2026-03-20 21:18:36.046317
11	add-trigger-to-auto-update-updated_at-column	7425bdb14366d1739fa8a18c83100636d74dcaa2	2026-03-20 21:18:36.051781
12	add-automatic-avif-detection-flag	8e92e1266eb29518b6a4c5313ab8f29dd0d08df9	2026-03-20 21:18:36.057198
13	add-bucket-custom-limits	cce962054138135cd9a8c4bcd531598684b25e7d	2026-03-20 21:18:36.06524
14	use-bytes-for-max-size	941c41b346f9802b411f06f30e972ad4744dad27	2026-03-20 21:18:36.070488
15	add-can-insert-object-function	934146bc38ead475f4ef4b555c524ee5d66799e5	2026-03-20 21:18:36.194552
16	add-version	76debf38d3fd07dcfc747ca49096457d95b1221b	2026-03-20 21:18:36.19952
17	drop-owner-foreign-key	f1cbb288f1b7a4c1eb8c38504b80ae2a0153d101	2026-03-20 21:18:36.204399
18	add_owner_id_column_deprecate_owner	e7a511b379110b08e2f214be852c35414749fe66	2026-03-20 21:18:36.209171
19	alter-default-value-objects-id	02e5e22a78626187e00d173dc45f58fa66a4f043	2026-03-20 21:18:36.222351
20	list-objects-with-delimiter	cd694ae708e51ba82bf012bba00caf4f3b6393b7	2026-03-20 21:18:36.228015
21	s3-multipart-uploads	8c804d4a566c40cd1e4cc5b3725a664a9303657f	2026-03-20 21:18:36.236496
22	s3-multipart-uploads-big-ints	9737dc258d2397953c9953d9b86920b8be0cdb73	2026-03-20 21:18:36.261425
23	optimize-search-function	9d7e604cddc4b56a5422dc68c9313f4a1b6f132c	2026-03-20 21:18:36.284023
24	operation-function	8312e37c2bf9e76bbe841aa5fda889206d2bf8aa	2026-03-20 21:18:36.289349
25	custom-metadata	d974c6057c3db1c1f847afa0e291e6165693b990	2026-03-20 21:18:36.29444
26	objects-prefixes	215cabcb7f78121892a5a2037a09fedf9a1ae322	2026-03-20 21:18:36.299555
27	search-v2	859ba38092ac96eb3964d83bf53ccc0b141663a6	2026-03-20 21:18:36.304137
28	object-bucket-name-sorting	c73a2b5b5d4041e39705814fd3a1b95502d38ce4	2026-03-20 21:18:36.308541
29	create-prefixes	ad2c1207f76703d11a9f9007f821620017a66c21	2026-03-20 21:18:36.313024
30	update-object-levels	2be814ff05c8252fdfdc7cfb4b7f5c7e17f0bed6	2026-03-20 21:18:36.319998
31	objects-level-index	b40367c14c3440ec75f19bbce2d71e914ddd3da0	2026-03-20 21:18:36.32451
32	backward-compatible-index-on-objects	e0c37182b0f7aee3efd823298fb3c76f1042c0f7	2026-03-20 21:18:36.329049
33	backward-compatible-index-on-prefixes	b480e99ed951e0900f033ec4eb34b5bdcb4e3d49	2026-03-20 21:18:36.333433
34	optimize-search-function-v1	ca80a3dc7bfef894df17108785ce29a7fc8ee456	2026-03-20 21:18:36.337882
35	add-insert-trigger-prefixes	458fe0ffd07ec53f5e3ce9df51bfdf4861929ccc	2026-03-20 21:18:36.342652
36	optimise-existing-functions	6ae5fca6af5c55abe95369cd4f93985d1814ca8f	2026-03-20 21:18:36.347174
37	add-bucket-name-length-trigger	3944135b4e3e8b22d6d4cbb568fe3b0b51df15c1	2026-03-20 21:18:36.351806
38	iceberg-catalog-flag-on-buckets	02716b81ceec9705aed84aa1501657095b32e5c5	2026-03-20 21:18:36.359967
39	add-search-v2-sort-support	6706c5f2928846abee18461279799ad12b279b78	2026-03-20 21:18:36.375717
40	fix-prefix-race-conditions-optimized	7ad69982ae2d372b21f48fc4829ae9752c518f6b	2026-03-20 21:18:36.380214
41	add-object-level-update-trigger	07fcf1a22165849b7a029deed059ffcde08d1ae0	2026-03-20 21:18:36.384672
42	rollback-prefix-triggers	771479077764adc09e2ea2043eb627503c034cd4	2026-03-20 21:18:36.390102
43	fix-object-level	84b35d6caca9d937478ad8a797491f38b8c2979f	2026-03-20 21:18:36.394678
44	vector-bucket-type	99c20c0ffd52bb1ff1f32fb992f3b351e3ef8fb3	2026-03-20 21:18:36.399026
45	vector-buckets	049e27196d77a7cb76497a85afae669d8b230953	2026-03-20 21:18:36.404459
46	buckets-objects-grants	fedeb96d60fefd8e02ab3ded9fbde05632f84aed	2026-03-20 21:18:36.488269
47	iceberg-table-metadata	649df56855c24d8b36dd4cc1aeb8251aa9ad42c2	2026-03-20 21:18:36.500149
48	iceberg-catalog-ids	e0e8b460c609b9999ccd0df9ad14294613eed939	2026-03-20 21:18:36.504873
49	buckets-objects-grants-postgres	072b1195d0d5a2f888af6b2302a1938dd94b8b3d	2026-03-20 21:18:36.639036
50	search-v2-optimised	6323ac4f850aa14e7387eb32102869578b5bd478	2026-03-20 21:18:36.644471
51	index-backward-compatible-search	2ee395d433f76e38bcd3856debaf6e0e5b674011	2026-03-20 21:18:36.677234
52	drop-not-used-indexes-and-functions	5cc44c8696749ac11dd0dc37f2a3802075f3a171	2026-03-20 21:18:36.679113
53	drop-index-lower-name	d0cb18777d9e2a98ebe0bc5cc7a42e57ebe41854	2026-03-20 21:18:36.694305
54	drop-index-object-level	6289e048b1472da17c31a7eba1ded625a6457e67	2026-03-20 21:18:36.697179
55	prevent-direct-deletes	262a4798d5e0f2e7c8970232e03ce8be695d5819	2026-03-20 21:18:36.700808
56	fix-optimized-search-function	cb58526ebc23048049fd5bf2fd148d18b04a2073	2026-03-20 21:18:36.714314
57	s3-multipart-uploads-metadata	f127886e00d1b374fadbc7c6b31e09336aad5287	2026-04-06 15:30:27.807201
58	operation-ergonomics	00ca5d483b3fe0d522133d9002ccc5df98365120	2026-04-06 15:30:27.827268
\.


--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.objects (id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata, version, owner_id, user_metadata) FROM stdin;
a2dcc505-fe6f-4d94-8e6e-1a7d610db3cc	uploads	company/1775144711639-0000.png	\N	2026-04-02 15:45:11.998414+00	2026-04-02 15:45:11.998414+00	2026-04-02 15:45:11.998414+00	{"eTag": "\\"a25e3479f3ee705e092adf4b19289893\\"", "size": 4956, "mimetype": "image/png", "cacheControl": "max-age=3600", "lastModified": "2026-04-02T15:45:12.000Z", "contentLength": 4956, "httpStatusCode": 200}	7b4f63f3-7a15-4ea2-bffc-49d232230be8	\N	{}
722fe413-d302-4cbf-ae7a-4347636844c6	uploads	company/1775181159750-0000.png	\N	2026-04-03 01:52:40.212236+00	2026-04-03 01:52:40.212236+00	2026-04-03 01:52:40.212236+00	{"eTag": "\\"a25e3479f3ee705e092adf4b19289893\\"", "size": 4956, "mimetype": "image/png", "cacheControl": "max-age=3600", "lastModified": "2026-04-03T01:52:41.000Z", "contentLength": 4956, "httpStatusCode": 200}	a9deb19a-8232-4409-89b4-b744e0a4fcdb	\N	{}
f7b2ebdc-37ba-4b57-a2eb-9e2624ee7745	uploads	company/1775181165237-0000.png	\N	2026-04-03 01:52:45.344517+00	2026-04-03 01:52:45.344517+00	2026-04-03 01:52:45.344517+00	{"eTag": "\\"a25e3479f3ee705e092adf4b19289893\\"", "size": 4956, "mimetype": "image/png", "cacheControl": "max-age=3600", "lastModified": "2026-04-03T01:52:46.000Z", "contentLength": 4956, "httpStatusCode": 200}	8b59bec4-bed8-464d-aad2-203a609aaa80	\N	{}
30127ca3-a145-4817-b457-91b6a50d5841	uploads	company/1775204142416-Untitled-2.png	\N	2026-04-03 08:15:43.020284+00	2026-04-03 08:15:43.020284+00	2026-04-03 08:15:43.020284+00	{"eTag": "\\"c3c1686845e25621ce1c640dd05ef81a\\"", "size": 1756424, "mimetype": "image/png", "cacheControl": "max-age=3600", "lastModified": "2026-04-03T08:15:43.000Z", "contentLength": 1756424, "httpStatusCode": 200}	f86048cc-cc17-4743-9122-3da276710fe1	\N	{}
79652c01-7055-4ae2-8c61-81eb24edd2e9	uploads	company/1775204147533-________________________________________________________________________________19_.png	\N	2026-04-03 08:15:48.047291+00	2026-04-03 08:15:48.047291+00	2026-04-03 08:15:48.047291+00	{"eTag": "\\"ef29325578565e5bb69c44d43e2ff70d\\"", "size": 37184, "mimetype": "image/png", "cacheControl": "max-age=3600", "lastModified": "2026-04-03T08:15:48.000Z", "contentLength": 37184, "httpStatusCode": 200}	68320b6a-32e0-42bf-98b1-b31acb141ad6	\N	{}
338bb667-e63c-40c7-86fc-6adb9c314308	uploads	company/1775275918903-MLT_logo.png	\N	2026-04-04 04:11:59.652489+00	2026-04-04 04:11:59.652489+00	2026-04-04 04:11:59.652489+00	{"eTag": "\\"a4e620557279dc7689a21b34bcdd043d\\"", "size": 728465, "mimetype": "image/png", "cacheControl": "max-age=3600", "lastModified": "2026-04-04T04:12:00.000Z", "contentLength": 728465, "httpStatusCode": 200}	57a7d291-99da-44a7-9802-be30f37635ca	\N	{}
2e60aad9-f68d-4cbd-84f9-36ca69bc14df	uploads	company/1775275926893-0000.png	\N	2026-04-04 04:12:07.110966+00	2026-04-04 04:12:07.110966+00	2026-04-04 04:12:07.110966+00	{"eTag": "\\"a25e3479f3ee705e092adf4b19289893\\"", "size": 4956, "mimetype": "image/png", "cacheControl": "max-age=3600", "lastModified": "2026-04-04T04:12:08.000Z", "contentLength": 4956, "httpStatusCode": 200}	c6fa3d5e-e33b-42f1-a0b1-470e81b4738b	\N	{}
db32e2b1-e29b-46b8-8f2a-486733f03bbe	uploads	company/1775354817483-MLT_logo.png	\N	2026-04-05 02:06:58.195203+00	2026-04-05 02:06:58.195203+00	2026-04-05 02:06:58.195203+00	{"eTag": "\\"a4e620557279dc7689a21b34bcdd043d\\"", "size": 728465, "mimetype": "image/png", "cacheControl": "max-age=3600", "lastModified": "2026-04-05T02:06:59.000Z", "contentLength": 728465, "httpStatusCode": 200}	b2f4ac7a-3a98-4bd7-b80a-345a609c42e2	\N	{}
b16d2ae3-9e61-4795-9f07-b3c2eda49154	uploads	company/1775354826085-0000.png	\N	2026-04-05 02:07:06.159392+00	2026-04-05 02:07:06.159392+00	2026-04-05 02:07:06.159392+00	{"eTag": "\\"a25e3479f3ee705e092adf4b19289893\\"", "size": 4956, "mimetype": "image/png", "cacheControl": "max-age=3600", "lastModified": "2026-04-05T02:07:07.000Z", "contentLength": 4956, "httpStatusCode": 200}	44203fcc-1e43-4bb8-9ee5-8eb7874e7b90	\N	{}
9f0290c9-64ab-4073-b2d0-89e4c5e311d6	uploads	company/1775403892990-MLT_logo.png	\N	2026-04-05 15:44:53.744332+00	2026-04-05 15:44:53.744332+00	2026-04-05 15:44:53.744332+00	{"eTag": "\\"a4e620557279dc7689a21b34bcdd043d\\"", "size": 728465, "mimetype": "image/png", "cacheControl": "max-age=3600", "lastModified": "2026-04-05T15:44:54.000Z", "contentLength": 728465, "httpStatusCode": 200}	31031d32-862b-4fa2-aa26-8811a4c2e7fb	\N	{}
e5a09c21-9347-4cb2-bcf6-0822d9d19cef	uploads	company/1775404724151-Screenshot_2026-03-18-06-27-39-60_f4e4ecb26678a2259e115c26f2593e0f.jpg	\N	2026-04-05 15:58:44.974534+00	2026-04-05 15:58:44.974534+00	2026-04-05 15:58:44.974534+00	{"eTag": "\\"33c78538eb88cf779f5c41c76b7cdab6\\"", "size": 667276, "mimetype": "image/jpeg", "cacheControl": "max-age=3600", "lastModified": "2026-04-05T15:58:45.000Z", "contentLength": 667276, "httpStatusCode": 200}	1531d39a-8596-456f-842d-0986e4aea469	\N	{}
a044da95-7f6c-4699-9320-5decce34b4a9	uploads	company/1775406622210-IMG_5147.jpeg	\N	2026-04-05 16:30:22.977326+00	2026-04-05 16:30:22.977326+00	2026-04-05 16:30:22.977326+00	{"eTag": "\\"56c80b67d9398891f2f9eef683faccee\\"", "size": 248846, "mimetype": "image/jpeg", "cacheControl": "max-age=3600", "lastModified": "2026-04-05T16:30:23.000Z", "contentLength": 248846, "httpStatusCode": 200}	ef82c4b2-e754-47de-8a56-605ec014798c	\N	{}
aa9dbe49-22ab-437e-8a73-aa6250faab47	uploads	company/1775406634090-IMG_5146.png	\N	2026-04-05 16:30:34.219727+00	2026-04-05 16:30:34.219727+00	2026-04-05 16:30:34.219727+00	{"eTag": "\\"e9aeb476756c37de1128bf0a418883bf\\"", "size": 5917, "mimetype": "image/png", "cacheControl": "max-age=3600", "lastModified": "2026-04-05T16:30:35.000Z", "contentLength": 5917, "httpStatusCode": 200}	915ab59b-f956-4dbf-adab-ec415d64b993	\N	{}
880a1e4f-9582-4105-85cf-cf1b0f774595	uploads	company/1775489424350-IMG_5147.jpeg	\N	2026-04-06 15:30:24.804226+00	2026-04-06 15:30:24.804226+00	2026-04-06 15:30:24.804226+00	{"eTag": "\\"56c80b67d9398891f2f9eef683faccee\\"", "size": 248846, "mimetype": "image/jpeg", "cacheControl": "max-age=3600", "lastModified": "2026-04-06T15:30:25.000Z", "contentLength": 248846, "httpStatusCode": 200}	dcc2870d-264d-44c5-984a-08110b14888b	\N	{}
ed017842-9276-42ea-ac36-a7fc7c32cffc	uploads	company/1775489446604-IMG_5146.png	\N	2026-04-06 15:30:46.811015+00	2026-04-06 15:30:46.811015+00	2026-04-06 15:30:46.811015+00	{"eTag": "\\"e9aeb476756c37de1128bf0a418883bf\\"", "size": 5917, "mimetype": "image/png", "cacheControl": "max-age=3600", "lastModified": "2026-04-06T15:30:47.000Z", "contentLength": 5917, "httpStatusCode": 200}	d55f052c-303d-4219-8835-194b26e89074	\N	{}
\.


--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads (id, in_progress_size, upload_signature, bucket_id, key, version, owner_id, created_at, user_metadata, metadata) FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads_parts (id, upload_id, size, part_number, bucket_id, key, etag, owner_id, version, created_at) FROM stdin;
\.


--
-- Data for Name: vector_indexes; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.vector_indexes (id, name, bucket_id, data_type, dimension, distance_metric, metadata_configuration, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: secrets; Type: TABLE DATA; Schema: vault; Owner: -
--

COPY vault.secrets (id, name, description, secret, key_id, nonce, created_at, updated_at) FROM stdin;
\.


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: -
--

SELECT pg_catalog.setval('auth.refresh_tokens_id_seq', 1, false);


--
-- Name: customers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.customers_id_seq', 20, true);


--
-- Name: document_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.document_items_id_seq', 119, true);


--
-- Name: document_running_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.document_running_id_seq', 1, false);


--
-- Name: documents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.documents_id_seq', 339, true);


--
-- Name: feedbacks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.feedbacks_id_seq', 7, true);


--
-- Name: payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.payments_id_seq', 48, true);


--
-- Name: products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.products_id_seq', 1, true);


--
-- Name: purchase_invoices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.purchase_invoices_id_seq', 40, true);


--
-- Name: subscription_id_seq; Type: SEQUENCE SET; Schema: realtime; Owner: -
--

SELECT pg_catalog.setval('realtime.subscription_id_seq', 1, false);


--
-- Name: mfa_amr_claims amr_id_pk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT amr_id_pk PRIMARY KEY (id);


--
-- Name: audit_log_entries audit_log_entries_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.audit_log_entries
    ADD CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id);


--
-- Name: custom_oauth_providers custom_oauth_providers_identifier_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.custom_oauth_providers
    ADD CONSTRAINT custom_oauth_providers_identifier_key UNIQUE (identifier);


--
-- Name: custom_oauth_providers custom_oauth_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.custom_oauth_providers
    ADD CONSTRAINT custom_oauth_providers_pkey PRIMARY KEY (id);


--
-- Name: flow_state flow_state_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.flow_state
    ADD CONSTRAINT flow_state_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: identities identities_provider_id_provider_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_provider_id_provider_unique UNIQUE (provider_id, provider);


--
-- Name: instances instances_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_authentication_method_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_authentication_method_pkey UNIQUE (session_id, authentication_method);


--
-- Name: mfa_challenges mfa_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id);


--
-- Name: mfa_factors mfa_factors_last_challenged_at_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_last_challenged_at_key UNIQUE (last_challenged_at);


--
-- Name: mfa_factors mfa_factors_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_pkey PRIMARY KEY (id);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_code_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_code_key UNIQUE (authorization_code);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_id_key UNIQUE (authorization_id);


--
-- Name: oauth_authorizations oauth_authorizations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id);


--
-- Name: oauth_client_states oauth_client_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_client_states
    ADD CONSTRAINT oauth_client_states_pkey PRIMARY KEY (id);


--
-- Name: oauth_clients oauth_clients_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_clients
    ADD CONSTRAINT oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_user_client_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_client_unique UNIQUE (user_id, client_id);


--
-- Name: one_time_tokens one_time_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_token_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_unique UNIQUE (token);


--
-- Name: saml_providers saml_providers_entity_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_entity_id_key UNIQUE (entity_id);


--
-- Name: saml_providers saml_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_pkey PRIMARY KEY (id);


--
-- Name: saml_relay_states saml_relay_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: sso_domains sso_domains_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_pkey PRIMARY KEY (id);


--
-- Name: sso_providers sso_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_providers
    ADD CONSTRAINT sso_providers_pkey PRIMARY KEY (id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: webauthn_challenges webauthn_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_challenges
    ADD CONSTRAINT webauthn_challenges_pkey PRIMARY KEY (id);


--
-- Name: webauthn_credentials webauthn_credentials_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_pkey PRIMARY KEY (id);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: company_settings company_settings_account_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_settings
    ADD CONSTRAINT company_settings_account_id_key UNIQUE (account_id);


--
-- Name: company_settings company_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_settings
    ADD CONSTRAINT company_settings_pkey PRIMARY KEY (id);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: document_items document_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_items
    ADD CONSTRAINT document_items_pkey PRIMARY KEY (id);


--
-- Name: document_running document_running_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_running
    ADD CONSTRAINT document_running_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: feedbacks feedbacks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedbacks
    ADD CONSTRAINT feedbacks_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: purchase_invoices purchase_invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_invoices
    ADD CONSTRAINT purchase_invoices_pkey PRIMARY KEY (id);


--
-- Name: purchase_order_items purchase_order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_order_items
    ADD CONSTRAINT purchase_order_items_pkey PRIMARY KEY (id);


--
-- Name: purchase_orders purchase_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT purchase_orders_pkey PRIMARY KEY (id);


--
-- Name: running_numbers_account running_numbers_account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.running_numbers_account
    ADD CONSTRAINT running_numbers_account_pkey PRIMARY KEY (account_id, doc_type);


--
-- Name: running_numbers running_numbers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.running_numbers
    ADD CONSTRAINT running_numbers_pkey PRIMARY KEY (company_id);


--
-- Name: suppliers suppliers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);


--
-- Name: company_settings unique_account; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_settings
    ADD CONSTRAINT unique_account UNIQUE (account_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: subscription pk_subscription; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.subscription
    ADD CONSTRAINT pk_subscription PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: buckets_analytics buckets_analytics_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_analytics
    ADD CONSTRAINT buckets_analytics_pkey PRIMARY KEY (id);


--
-- Name: buckets buckets_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets
    ADD CONSTRAINT buckets_pkey PRIMARY KEY (id);


--
-- Name: buckets_vectors buckets_vectors_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_vectors
    ADD CONSTRAINT buckets_vectors_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_name_key; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_name_key UNIQUE (name);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_pkey PRIMARY KEY (id);


--
-- Name: vector_indexes vector_indexes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_pkey PRIMARY KEY (id);


--
-- Name: audit_logs_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id);


--
-- Name: confirmation_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX confirmation_token_idx ON auth.users USING btree (confirmation_token) WHERE ((confirmation_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: custom_oauth_providers_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_created_at_idx ON auth.custom_oauth_providers USING btree (created_at);


--
-- Name: custom_oauth_providers_enabled_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_enabled_idx ON auth.custom_oauth_providers USING btree (enabled);


--
-- Name: custom_oauth_providers_identifier_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_identifier_idx ON auth.custom_oauth_providers USING btree (identifier);


--
-- Name: custom_oauth_providers_provider_type_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_provider_type_idx ON auth.custom_oauth_providers USING btree (provider_type);


--
-- Name: email_change_token_current_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_current_idx ON auth.users USING btree (email_change_token_current) WHERE ((email_change_token_current)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_new_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_new_idx ON auth.users USING btree (email_change_token_new) WHERE ((email_change_token_new)::text !~ '^[0-9 ]*$'::text);


--
-- Name: factor_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX factor_id_created_at_idx ON auth.mfa_factors USING btree (user_id, created_at);


--
-- Name: flow_state_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX flow_state_created_at_idx ON auth.flow_state USING btree (created_at DESC);


--
-- Name: identities_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_email_idx ON auth.identities USING btree (email text_pattern_ops);


--
-- Name: INDEX identities_email_idx; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.identities_email_idx IS 'Auth: Ensures indexed queries on the email column';


--
-- Name: identities_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_user_id_idx ON auth.identities USING btree (user_id);


--
-- Name: idx_auth_code; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_auth_code ON auth.flow_state USING btree (auth_code);


--
-- Name: idx_oauth_client_states_created_at; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_oauth_client_states_created_at ON auth.oauth_client_states USING btree (created_at);


--
-- Name: idx_user_id_auth_method; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_id_auth_method ON auth.flow_state USING btree (user_id, authentication_method);


--
-- Name: mfa_challenge_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_challenge_created_at_idx ON auth.mfa_challenges USING btree (created_at DESC);


--
-- Name: mfa_factors_user_friendly_name_unique; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX mfa_factors_user_friendly_name_unique ON auth.mfa_factors USING btree (friendly_name, user_id) WHERE (TRIM(BOTH FROM friendly_name) <> ''::text);


--
-- Name: mfa_factors_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_factors_user_id_idx ON auth.mfa_factors USING btree (user_id);


--
-- Name: oauth_auth_pending_exp_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_auth_pending_exp_idx ON auth.oauth_authorizations USING btree (expires_at) WHERE (status = 'pending'::auth.oauth_authorization_status);


--
-- Name: oauth_clients_deleted_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_clients_deleted_at_idx ON auth.oauth_clients USING btree (deleted_at);


--
-- Name: oauth_consents_active_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_client_idx ON auth.oauth_consents USING btree (client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_active_user_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_user_client_idx ON auth.oauth_consents USING btree (user_id, client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_user_order_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_user_order_idx ON auth.oauth_consents USING btree (user_id, granted_at DESC);


--
-- Name: one_time_tokens_relates_to_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_relates_to_hash_idx ON auth.one_time_tokens USING hash (relates_to);


--
-- Name: one_time_tokens_token_hash_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_token_hash_hash_idx ON auth.one_time_tokens USING hash (token_hash);


--
-- Name: one_time_tokens_user_id_token_type_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX one_time_tokens_user_id_token_type_key ON auth.one_time_tokens USING btree (user_id, token_type);


--
-- Name: reauthentication_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX reauthentication_token_idx ON auth.users USING btree (reauthentication_token) WHERE ((reauthentication_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: recovery_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX recovery_token_idx ON auth.users USING btree (recovery_token) WHERE ((recovery_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: refresh_tokens_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id);


--
-- Name: refresh_tokens_instance_id_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id);


--
-- Name: refresh_tokens_parent_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_parent_idx ON auth.refresh_tokens USING btree (parent);


--
-- Name: refresh_tokens_session_id_revoked_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens USING btree (session_id, revoked);


--
-- Name: refresh_tokens_updated_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_updated_at_idx ON auth.refresh_tokens USING btree (updated_at DESC);


--
-- Name: saml_providers_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_providers_sso_provider_id_idx ON auth.saml_providers USING btree (sso_provider_id);


--
-- Name: saml_relay_states_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_created_at_idx ON auth.saml_relay_states USING btree (created_at DESC);


--
-- Name: saml_relay_states_for_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_for_email_idx ON auth.saml_relay_states USING btree (for_email);


--
-- Name: saml_relay_states_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_sso_provider_id_idx ON auth.saml_relay_states USING btree (sso_provider_id);


--
-- Name: sessions_not_after_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_not_after_idx ON auth.sessions USING btree (not_after DESC);


--
-- Name: sessions_oauth_client_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_oauth_client_id_idx ON auth.sessions USING btree (oauth_client_id);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_user_id_idx ON auth.sessions USING btree (user_id);


--
-- Name: sso_domains_domain_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_domains_domain_idx ON auth.sso_domains USING btree (lower(domain));


--
-- Name: sso_domains_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_domains_sso_provider_id_idx ON auth.sso_domains USING btree (sso_provider_id);


--
-- Name: sso_providers_resource_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_providers_resource_id_idx ON auth.sso_providers USING btree (lower(resource_id));


--
-- Name: sso_providers_resource_id_pattern_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_providers_resource_id_pattern_idx ON auth.sso_providers USING btree (resource_id text_pattern_ops);


--
-- Name: unique_phone_factor_per_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX unique_phone_factor_per_user ON auth.mfa_factors USING btree (user_id, phone);


--
-- Name: user_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX user_id_created_at_idx ON auth.sessions USING btree (user_id, created_at);


--
-- Name: users_email_partial_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX users_email_partial_key ON auth.users USING btree (email) WHERE (is_sso_user = false);


--
-- Name: INDEX users_email_partial_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.users_email_partial_key IS 'Auth: A partial unique index that applies only when is_sso_user is false';


--
-- Name: users_instance_id_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, lower((email)::text));


--
-- Name: users_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id);


--
-- Name: users_is_anonymous_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_is_anonymous_idx ON auth.users USING btree (is_anonymous);


--
-- Name: webauthn_challenges_expires_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_challenges_expires_at_idx ON auth.webauthn_challenges USING btree (expires_at);


--
-- Name: webauthn_challenges_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_challenges_user_id_idx ON auth.webauthn_challenges USING btree (user_id);


--
-- Name: webauthn_credentials_credential_id_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX webauthn_credentials_credential_id_key ON auth.webauthn_credentials USING btree (credential_id);


--
-- Name: webauthn_credentials_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_credentials_user_id_idx ON auth.webauthn_credentials USING btree (user_id);


--
-- Name: idx_accounts_stripe_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_accounts_stripe_customer_id ON public.accounts USING btree (stripe_customer_id);


--
-- Name: idx_accounts_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_accounts_subscription_id ON public.accounts USING btree (subscription_id);


--
-- Name: idx_company_settings_account_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_company_settings_account_id_unique ON public.company_settings USING btree (account_id);


--
-- Name: idx_customers_account_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customers_account_deleted ON public.customers USING btree (account_id, deleted_at);


--
-- Name: idx_documents_account_locked; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_documents_account_locked ON public.documents USING btree (account_id, is_locked);


--
-- Name: idx_documents_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_documents_company ON public.documents USING btree (company_id);


--
-- Name: idx_documents_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_documents_group_id ON public.documents USING btree (group_id);


--
-- Name: idx_documents_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_documents_type ON public.documents USING btree (doc_type);


--
-- Name: idx_purchase_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_account ON public.purchase_invoices USING btree (account_id);


--
-- Name: idx_purchase_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_date ON public.purchase_invoices USING btree (doc_date);


--
-- Name: idx_purchase_orders_account_locked; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_orders_account_locked ON public.purchase_orders USING btree (account_id, is_locked);


--
-- Name: idx_suppliers_account_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_suppliers_account_deleted ON public.suppliers USING btree (account_id, deleted_at);


--
-- Name: idx_suppliers_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_suppliers_account_id ON public.suppliers USING btree (account_id);


--
-- Name: uniq_po_doc_no_per_account; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_po_doc_no_per_account ON public.purchase_orders USING btree (account_id, doc_no);


--
-- Name: ix_realtime_subscription_entity; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX ix_realtime_subscription_entity ON realtime.subscription USING btree (entity);


--
-- Name: messages_inserted_at_topic_index; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_inserted_at_topic_index ON ONLY realtime.messages USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: subscription_subscription_id_entity_filters_action_filter_key; Type: INDEX; Schema: realtime; Owner: -
--

CREATE UNIQUE INDEX subscription_subscription_id_entity_filters_action_filter_key ON realtime.subscription USING btree (subscription_id, entity, filters, action_filter);


--
-- Name: bname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bname ON storage.buckets USING btree (name);


--
-- Name: bucketid_objname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bucketid_objname ON storage.objects USING btree (bucket_id, name);


--
-- Name: buckets_analytics_unique_name_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX buckets_analytics_unique_name_idx ON storage.buckets_analytics USING btree (name) WHERE (deleted_at IS NULL);


--
-- Name: idx_multipart_uploads_list; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_multipart_uploads_list ON storage.s3_multipart_uploads USING btree (bucket_id, key, created_at);


--
-- Name: idx_objects_bucket_id_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name ON storage.objects USING btree (bucket_id, name COLLATE "C");


--
-- Name: idx_objects_bucket_id_name_lower; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name_lower ON storage.objects USING btree (bucket_id, lower(name) COLLATE "C");


--
-- Name: name_prefix_search; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX name_prefix_search ON storage.objects USING btree (name text_pattern_ops);


--
-- Name: vector_indexes_name_bucket_id_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX vector_indexes_name_bucket_id_idx ON storage.vector_indexes USING btree (name, bucket_id);


--
-- Name: subscription tr_check_filters; Type: TRIGGER; Schema: realtime; Owner: -
--

CREATE TRIGGER tr_check_filters BEFORE INSERT OR UPDATE ON realtime.subscription FOR EACH ROW EXECUTE FUNCTION realtime.subscription_check_filters();


--
-- Name: buckets enforce_bucket_name_length_trigger; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length();


--
-- Name: buckets protect_buckets_delete; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER protect_buckets_delete BEFORE DELETE ON storage.buckets FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();


--
-- Name: objects protect_objects_delete; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER protect_objects_delete BEFORE DELETE ON storage.objects FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();


--
-- Name: objects update_objects_updated_at; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column();


--
-- Name: identities identities_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: mfa_challenges mfa_challenges_auth_factor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id) ON DELETE CASCADE;


--
-- Name: mfa_factors mfa_factors_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: one_time_tokens one_time_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: saml_providers saml_providers_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_flow_state_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: sso_domains sso_domains_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: webauthn_challenges webauthn_challenges_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_challenges
    ADD CONSTRAINT webauthn_challenges_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: webauthn_credentials webauthn_credentials_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: companies companies_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: purchase_order_items purchase_order_items_purchase_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_order_items
    ADD CONSTRAINT purchase_order_items_purchase_order_id_fkey FOREIGN KEY (purchase_order_id) REFERENCES public.purchase_orders(id) ON DELETE CASCADE;


--
-- Name: users users_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: users users_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: objects objects_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_upload_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES storage.s3_multipart_uploads(id) ON DELETE CASCADE;


--
-- Name: vector_indexes vector_indexes_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets_vectors(id);


--
-- Name: audit_log_entries; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.audit_log_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: flow_state; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.flow_state ENABLE ROW LEVEL SECURITY;

--
-- Name: identities; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;

--
-- Name: instances; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.instances ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_amr_claims; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_amr_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_challenges; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_factors; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_factors ENABLE ROW LEVEL SECURITY;

--
-- Name: one_time_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.one_time_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: refresh_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.refresh_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_relay_states; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_relay_states ENABLE ROW LEVEL SECURITY;

--
-- Name: schema_migrations; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.schema_migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_domains; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

--
-- Name: messages; Type: ROW SECURITY; Schema: realtime; Owner: -
--

ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_analytics; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_analytics ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_vectors; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_vectors ENABLE ROW LEVEL SECURITY;

--
-- Name: migrations; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: objects; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads_parts; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads_parts ENABLE ROW LEVEL SECURITY;

--
-- Name: vector_indexes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.vector_indexes ENABLE ROW LEVEL SECURITY;

--
-- Name: supabase_realtime; Type: PUBLICATION; Schema: -; Owner: -
--

CREATE PUBLICATION supabase_realtime WITH (publish = 'insert, update, delete, truncate');


--
-- Name: issue_graphql_placeholder; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_graphql_placeholder ON sql_drop
         WHEN TAG IN ('DROP EXTENSION')
   EXECUTE FUNCTION extensions.set_graphql_placeholder();


--
-- Name: issue_pg_cron_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_cron_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_cron_access();


--
-- Name: issue_pg_graphql_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_graphql_access ON ddl_command_end
         WHEN TAG IN ('CREATE FUNCTION')
   EXECUTE FUNCTION extensions.grant_pg_graphql_access();


--
-- Name: issue_pg_net_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_net_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_net_access();


--
-- Name: pgrst_ddl_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_ddl_watch ON ddl_command_end
   EXECUTE FUNCTION extensions.pgrst_ddl_watch();


--
-- Name: pgrst_drop_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_drop_watch ON sql_drop
   EXECUTE FUNCTION extensions.pgrst_drop_watch();


--
-- PostgreSQL database dump complete
--

\unrestrict V9FkrgehpO97ZzryAaCr3L4LX7W3ssIIxOQSm3ZwjBJ4xhrddlGa6L0NzwdvCmf


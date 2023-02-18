--  Copyright (c) 2022-2022. Harvard University
--
--  Developed by Research Software Engineering,
--  Faculty of Arts and Sciences, Research Computing (FAS RC)
--  Author: Michael A Bouzinier
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--         http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
--
--
--  Developed by Research Software Engineering,
--  Harvard University Research Computing
--  Author: Michael A Bouzinier
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--         http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
--

-- Procedures to create a random subset of Medicare data for testing
-- These procedures create a smaller subset of data, ut they do not remove
-- or mask PII!

CREATE OR REPLACE PROCEDURE public.subset(
    tname VARCHAR,
    src_schema VARCHAR,
    dest_schema VARCHAR,
    ratio FLOAT
)
LANGUAGE plpgsql
AS $$
DECLARE
    icrs CURSOR FOR
        SELECT
            indexname,
            indexdef
        FROM
            pg_catalog.pg_indexes
        WHERE
            schemaname = src_schema AND tablename = tname
    ;
    cmd VARCHAR;
    t1 VARCHAR;
    t2 VARCHAR;
    cnt INT;
BEGIN
    cnt := public.estimate_rows(src_schema, tname);
    cnt := cnt * ratio;
    t1 := format('%I.%I', src_schema, tname);
    t2 := format('%I.%I', dest_schema, tname);
    EXECUTE format ('CREATE SCHEMA IF NOT EXISTS %I;', dest_schema);
    EXECUTE format ('DROP TABLE IF EXISTS %I.%I;', dest_schema, tname);
    EXECUTE format('CREATE TABLE %I.%I AS ' ||
        'SELECT * FROM %I.%I ORDER BY RANDOM() LIMIT %s',
        dest_schema, tname, src_schema, tname, cnt
        );
    FOR idx in icrs LOOP
        cmd := replace(idx.indexdef, t1, t2);
        cmd := replace(cmd, idx.indexname, idx.indexname || '_');
        EXECUTE cmd;
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE public.add_subset(
    tname VARCHAR,
    src_schema VARCHAR,
    dest_schema VARCHAR,
    ratio FLOAT
)
LANGUAGE plpgsql
AS $$
DECLARE
    t1 VARCHAR;
    t2 VARCHAR;
    cnt INT;
BEGIN
    cnt := public.estimate_rows(src_schema, tname);
    cnt := cnt * ratio;
    t1 := format('%I.%I', src_schema, tname);
    t2 := format('%I.%I', dest_schema, tname);
    EXECUTE format('INSERT INTO %I.%I  ' ||
        'SELECT * FROM %I.%I ORDER BY RANDOM() LIMIT %s ' ||
        'ON CONFLICT DO NOTHING',
        dest_schema, tname, src_schema, tname, cnt
        );
END;
$$;


CREATE OR REPLACE PROCEDURE public.subset(
    master VARCHAR,
    dependent VARCHAR,
    src_schema VARCHAR,
    dest_schema VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    icrs CURSOR FOR
        SELECT
            indexname,
            indexdef
        FROM
            pg_catalog.pg_indexes
        WHERE
            schemaname = src_schema AND tablename = dependent
    ;
    cmd VARCHAR;
    t1 VARCHAR;
    t2 VARCHAR;
BEGIN
    t1 := format('%I.%I', src_schema, dependent);
    t2 := format('%I.%I', dest_schema, dependent);
    EXECUTE format ('CREATE SCHEMA IF NOT EXISTS %I;', dest_schema);
    EXECUTE format ('DROP TABLE IF EXISTS %I.%I;', dest_schema, dependent);
    EXECUTE format('CREATE TABLE %I.%I AS ' ||
        'SELECT * FROM %I.%I WHERE bene_id IN (SELECT bene_id FROM %I.%I)',
        dest_schema, dependent, src_schema, dependent, dest_schema, master
        );
    FOR idx in icrs LOOP
        cmd := replace(idx.indexdef, t1, t2);
        cmd := replace(cmd, idx.indexname, idx.indexname || '_');
        EXECUTE cmd;
    END LOOP;
END;
$$;



CREATE OR REPLACE PROCEDURE cms.subset1y(
    y INT,
    dest_schema VARCHAR,
    ratio FLOAT
)
LANGUAGE plpgsql
AS $$
DECLARE
    src_schema VARCHAR;
    psname VARCHAR;
    dname VARCHAR;
    ipname VARCHAR;
BEGIN
    IF y < 2011 THEN
        psname := format('mcr_bene_%s', y);
        ipname := format('mcr_ip_%s', y);
    ELSIF y < 2016 THEN
        psname := format('mbsf_ab_%s', y);
        ipname := format('medpar_%s', y);
    ELSE
        psname := format('mbsf_abcd_%s', y);
        ipname := format('medpar_%s', y);
    END IF;
    src_schema := 'cms';
    CALL public.subset(psname, src_schema, dest_schema, ratio);
    IF 2010 < y AND y < 2015 THEN
        dname :=  format('mbsf_d_%s', y);
        CALL public.subset(psname, dname, src_schema, dest_schema);
    END IF;
    CALL public.subset(psname, ipname, src_schema, dest_schema);
    -- Add a few records that would violate FK
    CALL public.add_subset(ipname, src_schema, dest_schema, (ratio / 20));
END;
$$;

CREATE OR REPLACE PROCEDURE cms.create_subset(
    dest_schema VARCHAR,
    ratio FLOAT
)
LANGUAGE plpgsql
AS $$
DECLARE
    y INT;
BEGIN
    FOR y IN 1999..2018 LOOP
        CALL cms.subset1y(y, dest_schema, ratio);
        COMMIT;
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE cms.reset(
    sch VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    y INT;
    t VARCHAR;
    c CURSOR (s VARCHAR) FOR
        SELECT
            table_name
        FROM
            information_schema.tables
        WHERE table_schema = s
    ;
BEGIN
    FOR tn IN c(sch) LOOP
        t := tn.table_name;
        RAISE NOTICE '%', t;
        EXECUTE format('DROP TABLE IF EXISTS cms.%I CASCADE;', t);
        EXECUTE format('ALTER TABLE %I.%I SET SCHEMA cms;', sch, t);
    END LOOP;
END;
$$;


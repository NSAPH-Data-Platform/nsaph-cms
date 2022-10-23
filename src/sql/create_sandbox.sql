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

CREATE OR REPLACE PROCEDURE public.subset(
    tname VARCHAR,
    src_schema VARCHAR,
    dest_schema VARCHAR,
    cnt INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    icrs CURSOR FOR
        SELECT
            indexdef
        FROM
            pg_catalog.pg_indexes
        WHERE
            schemaname = src_schema AND tablename = tname
    ;
    cmd VARCHAR;
    t1 VARCHAR;
    t2 VARCHAR;
BEGIN
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
        EXECUTE cmd;
    END LOOP;
END;
$$;



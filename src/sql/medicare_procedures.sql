--  Copyright (c) 2022. Harvard University
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

CREATE SCHEMA IF NOT EXISTS cms;
CREATE OR REPLACE FUNCTION cms.map_bene (
    intbid VARCHAR
)  RETURNS VARCHAR(15)
    IMMUTABLE
AS $body$
DECLARE
    new_bene_id VARCHAR;
BEGIN
    SELECT bene_id FROM cms.bid_to_bene_id WHERE bid = intbid INTO new_bene_id;
    IF new_bene_id IS NOT NULL THEN
        RETURN new_bene_id;
    END IF;
    RETURN intbid;
END;
$body$ LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE cms.map_old_bene(
    y INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    pstable VARCHAR;
    iptable VARCHAR;
    pscol VARCHAR;
    ipcol VARCHAR;
    sql    VARCHAR;
    t VARCHAR;
    c VARCHAR;
BEGIN
    pstable := format('mcr_bene_%s', y);
    iptable := format('mcr_ip_%s', y);
    IF y < 2003 THEN
        pscol := 'intbid';
        ipcol := pscol;
    ELSIF y < 2006 THEN
        pscol := 'bid_5333_1';
        ipcol := pscol;
    ELSE
        pscol := 'bid_5333_3';
        ipcol := 'bid_5333_5';
    END IF;

    FOREACH t IN ARRAY ARRAY [pstable, iptable] LOOP
        IF t = pstable THEN
            c := pscol;
        ELSE
            c := ipcol;
        END IF;
        EXECUTE format('ALTER TABLE cms.%I DROP COLUMN bene_id CASCADE;', t);
        sql := format('ALTER TABLE cms.%I ' ||
               'ADD COLUMN bene_id VARCHAR(15) ' ||
               'GENERATED ALWAYS AS (cms.map_bene(%I)) STORED;',
                t, c
            );
        EXECUTE sql;
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE cms.map_all_old_bene()
LANGUAGE plpgsql
AS $$
DECLARE
    y INT;
BEGIN
    FOR y IN 1999..2006 LOOP
        CALL cms.map_old_bene(y);
        COMMIT;
    END LOOP;
END;
$$;


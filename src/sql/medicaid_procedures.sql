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

CREATE OR REPLACE PROCEDURE medicaid.create_eligibility_by_beneficiary()
LANGUAGE plpgsql
AS $$
DECLARE
    cur_bene_id VARCHAR;
    bene_cursor CURSOR FOR
        SELECT bene_id
        FROM medicaid.beneficiaries AS b
        WHERE NOT EXISTS (
            SELECT * FROM medicaid.e2 AS e
            WHERE b.bene_id = e.bene_id
        )
    ;
BEGIN
    FOR bene_rec in bene_cursor LOOP
        cur_bene_id := bene_rec.bene_id;
        INSERT INTO medicaid.e2
            SELECT * FROM medicaid._eligibility AS _e
            WHERE _e.bene_id = cur_bene_id
        ;
        COMMIT;
        RAISE NOTICE 'bene_id = %', cur_bene_id;
    END LOOP;
END;
$$;


CREATE OR REPLACE PROCEDURE medicaid.create_eligibility_by_year_state()
LANGUAGE plpgsql
AS $$
DECLARE
    s VARCHAR;
    y INT;
    ts TIMESTAMP;
    y_cursor CURSOR FOR
        SELECT generate_series as y FROM generate_series(1999,2030);
    state_cursor CURSOR FOR
        SELECT DISTINCT state_id FROM public.us_states ORDER BY 1;
BEGIN
    DROP TABLE IF EXISTS medicaid.e2 CASCADE;
    CREATE TABLE medicaid.e2 AS SELECT * FROM medicaid._eligibility WITH NO DATA;
    ALTER TABLE medicaid.eligibility ADD PRIMARY KEY (bene_id, year, state, month);
    DROP TABLE IF EXISTS medicaid_audit.ecr CASCADE;
    CREATE TABLE medicaid_audit.ecr (
        state VARCHAR(2),
        year INT,
        ts TIMESTAMP,
        duration INTERVAL
    );
    FOR s_rec in state_cursor LOOP
        s := s_rec.state_id;
        FOR y_rec in y_cursor LOOP
            SELECT now() into ts;
            y := y_rec.y;
            INSERT INTO medicaid.e2
                SELECT * FROM medicaid._eligibility AS _e
                WHERE _e.state = s AND _e.year = y
            ;
            COMMIT;
            --RAISE NOTICE '%:%', s, y;
            INSERT INTO medicaid_audit.ecr (
                state, year, ts, duration
            ) VALUES (
                s, y, now(), now() - ts
            );
        END LOOP;
    END LOOP;
END;
$$;

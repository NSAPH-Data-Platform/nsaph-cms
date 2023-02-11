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

CREATE OR REPLACE PROCEDURE medicare.populate_enrollments()
LANGUAGE plpgsql
AS $$
DECLARE
    cur_bene_id VARCHAR;
    nn INT;
    msg VARCHAR;
    bene_cursor CURSOR FOR
        SELECT bene_id
        FROM medicare.beneficiaries AS b
        WHERE NOT EXISTS (
            SELECT * FROM medicare.enrollments AS e
            WHERE b.bene_id = e.bene_id
        )
    ;
BEGIN
    nn := 0;
    FOR bene_rec in bene_cursor LOOP
        cur_bene_id := bene_rec.bene_id;
        INSERT INTO medicare.enrollments
            SELECT * FROM medicare._enrollments AS _e
            WHERE _e.bene_id = cur_bene_id
        ;
        COMMIT;
        nn := nn + 1;
        msg := format('nn = %s; bene_id = %L', nn, cur_bene_id);
        --RAISE NOTICE msg;
        PERFORM pg_notify('medicare_enrollments_notifications', msg);
    END LOOP;
END;
$$;

DROP TABLE IF EXISTS cms.bid_to_bene_id;
CREATE TABLE cms.bid_to_bene_id (
    BID VARCHAR(9),
    BENE_ID VARCHAR(15),
    PRIMARY KEY (BID)
);

CREATE UNIQUE INDEX IF NOT EXISTS bene_id_to_bid_idx
    on cms.bid_to_bene_id (BENE_ID);

DROP TABLE IF EXISTS cms.bid_to_bene_id_dirty;
CREATE TABLE  cms.bid_to_bene_id_dirty (
    BID VARCHAR(9),
    BENE_ID VARCHAR(15),
    REASON VARCHAR(16)
);

CREATE INDEX IF NOT EXISTS dirty_bid_idx
    on cms.bid_to_bene_id_dirty (BID);

CREATE OR REPLACE FUNCTION "cms"."validate_xwalk" ()  RETURNS trigger
  VOLATILE
AS $body$
    DECLARE
        t_bene_id VARCHAR;
    BEGIN
        IF (NEW.BID IS NULL) THEN
            INSERT INTO cms.bid_to_bene_id_dirty (BID, BENE_ID, REASON)
            VALUES (NEW.BID, NEW.BENE_ID, 'NULL BID');
            RETURN NULL;
        END IF;
        IF EXISTS (
                SELECT FROM cms.bid_to_bene_id as t
                WHERE NEW.BID = t.BID
            ) THEN
            INSERT INTO cms.bid_to_bene_id_dirty (BID, BENE_ID, REASON)
            VALUES (NEW.BID, NEW.BENE_ID, 'DUPLICATE BID');
            SELECT t.bene_id FROM cms.bid_to_bene_id as t
                WHERE NEW.BID = t.BID
                INTO t_bene_id;
            INSERT INTO cms.bid_to_bene_id_dirty (BID, BENE_ID, REASON)
            VALUES (NEW.BID, t_BENE_ID, 'DUPLICATE BID');
            DELETE FROM cms.bid_to_bene_id WHERE BID = NEW.BID;
            RETURN NULL;
        END IF;
        IF EXISTS (
                SELECT FROM cms.bid_to_bene_id_dirty as t
                WHERE NEW.BID = t.BID
            ) THEN
            INSERT INTO cms.bid_to_bene_id_dirty (BID, BENE_ID, REASON)
            VALUES (NEW.BID, NEW.BENE_ID, 'DUPLICATE BID');
        END IF;
        RETURN NEW;
    END;
$body$ LANGUAGE plpgsql;

CREATE TRIGGER "cms_xwalk_validation"
  BEFORE INSERT ON cms.bid_to_bene_id
  FOR EACH ROW
EXECUTE FUNCTION cms.validate_xwalk();

COPY cms.bid_to_bene_id
FROM
    PROGRAM 'awk -F'','' ''{print $2","$3}'' /data/incoming/rce/ci3_d_medicare/crosswalks/bid_bene_xwlk_2007.csv'
WITH csv  HEADER
;

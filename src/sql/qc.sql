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


-- Helper view

CREATE SCHEMA IF NOT EXISTS medicare_qc;
CREATE MATERIALIZED VIEW medicare_qc.admission_counts AS
SELECT
    a.year,
    a.state,
    (
        (
            SELECT
                COUNT(*) AS COUNT
            FROM
                medicare_audit.admissions t
            WHERE (a.state = t.state) AND (a.year = t.year)
        ) +
        (
            SELECT
                COUNT(*) AS COUNT
            FROM
                medicare.admissions t
            WHERE (a.state = t.state) AND (a.year = t.year)
        )
    )  AS total
FROM
    medicare_audit.admissions a
GROUP BY
    a.year,
    a.state
;

-- Admissions QC Table

CREATE MATERIALIZED VIEW medicare_qc.admission_qc1 AS
SELECT
    a.reason,
    a.year,
    a.state,
    MAX(a.state_iso) AS state_iso,
    COUNT(*)  AS COUNT,
    SUM(c.total)    AS TOTAL
FROM
    medicare_audit.admissions a
        left join medicare_qc.admission_counts c on
            c.year = a.year and c.state = a.state
GROUP BY
    a.reason,
    a.year,
    a.state

UNION

SELECT
    'OK'::VARCHAR AS reason,
    a.year,
    a.state,
    MAX(a.state_iso)  AS state_iso,
    COUNT(*)           AS COUNT,
    SUM(c.total)   AS TOTAL
FROM
    medicare.admissions a
        left join medicare_qc.admission_counts c on
            c.year = a.year and c.state = a.state
GROUP BY
    a.year,
    a.state;

-- Enrollments QC


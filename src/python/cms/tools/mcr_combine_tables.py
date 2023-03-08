#  Copyright (c) 2022. Harvard University
#
#  Developed by Research Software Engineering,
#  Faculty of Arts and Sciences, Research Computing (FAS RC)
#  Author: Michael A Bouzinier
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

"""
This utility combines Medicare Patient Summary or Inpatient Admissions data,
that is originally
in the form of one table per year into a single view.

It takes care of different types and format of the most common columns,
such as: year, state, DO[B/D], zip codes, state and county codes.

The actual schema is defined in ../models/medicare.yaml

This utility uses extended syntax compared with the general data modelling
"""

import logging
import os
from pathlib import Path
from typing import List, Tuple, Optional, Dict

import yaml

from nsaph import init_logging
from nsaph.data_model.domain import Domain
from nsaph.data_model.utils import split

from nsaph.db import Connection
from nsaph.loader import DBActivityMonitor

from nsaph.loader.common import DBTableConfig


class MedicareCombinedView:
    ps = "ps"
    ip = "ip"
    supported_tables = [ps, ip, "mbsf_d"]

    def __init__(self, context: DBTableConfig = None):
        if not context:
            context = DBTableConfig(None, __doc__).instantiate()
        self.context = context
        if not self.context.table:
            raise ValueError("'--table' is a required option")
        init_logging(name="combine-tables-into-" + self.context.table)
        self.view = self.context.table.lower()
        if self.view not in self.supported_tables:
            raise ValueError(
                "The only supported options are: " +
                ", ".join(self.supported_tables)
            )
        src = Path(__file__).parents[1]
        rp = os.path.join(src, "models", "medicare.yaml")
        with open(rp) as f:
            content = yaml.safe_load(f)
        self.table = content["medicare"]["tables"][self.view]
        self.schema = content["medicare"]["schema"]
        self.sql = ""
        self.monitor = DBActivityMonitor(context)

    def print_sql(self):
        if not self.sql:
            self.generate_sql()
        print(self.sql)

    def execute(self):
        if self.context.dryrun:
            print("Dry run: nothing is done")
            return
        if not self.sql:
            self.generate_sql()
        with Connection(self.context.db,
                        self.context.connection) as cnxn:
            with cnxn.cursor() as cursor:
                pid = Connection.get_pid(cnxn)
                self.monitor.execute(lambda: cursor.execute(self.sql),
                                     lambda: self.monitor.log_activity(pid))
            cnxn.commit()
        print("All Done")

    def generate_sql(self):
        with Connection(self.context.db,
                        self.context.connection) as cnxn:
            cursor = cnxn.cursor()
            tables = self.get_tables(cursor)
            tt = [self.table_sql(cursor, t) for t in tables]
            view = self.table["create"].get("type", "VIEW")
            sql = "DROP {} IF EXISTS {}.{} CASCADE;\n".format(
                view, self.schema, self.view
            )
            sql += "CREATE SCHEMA IF NOT EXISTS {};\n".format(self.schema)
            sql += "CREATE {} {}.{} AS \n".format(view, self.schema, self.view)
            sql += "\nUNION\n".join(tt)
        self.sql = sql

    def get_tables(self, cursor):
        tables: List[str] = self.table["create"]["from"]
        if "exclude" in self.table["create"]:
            exclusions = set(self.table["create"]["exclude"])
        else:
            exclusions = set()
        if isinstance(tables, str):
            tables = [tables]
        sql = """
        SELECT table_schema, table_name 
        FROM information_schema.tables 
        WHERE ({})
        ORDER BY 1
        """
        cc = []
        for t in tables:
            t = t.replace('*', '%')
            if '.' in t:
                tt = t.split('.')
                cc.append("table_schema LIKE '{}' AND table_name LIKE '{}'"
                    .format(tt[0], tt[1]))
            else:
                cc.append("table_name LIKE '{}'")
        sql = sql.format(" OR ".join(cc))
        logging.debug(sql)
        cursor.execute(sql)
        return [(t[0], t[1]) for t in cursor if t[1] not in exclusions]

    def table_sql(self, cursor, qtable: Tuple) -> str:
        schema, table = qtable
        columns = self.get_columns(cursor, table)
        sql = "SELECT \n{} \nFROM {}.{}"
        cc = []
        for column in columns:
            target, src = column
            cc.append("{} AS {}".format(src, target))
        sql = sql.format(",\n\t".join(cc), schema, table)
        return sql

    def get_columns(self, cursor, table: str) -> List[Tuple]:
        columns: List[Tuple] = []
        column_defs = Domain.get_columns(self.table)
        for clmn in column_defs:
            n, c = split(clmn)
            if "optional" in c and c["optional"]:
                opt = True
            else:
                opt = False
            if "source" in c:
                src = c["source"]
            else:
                src = [n]
            if isinstance(src, str):
                if src.strip()[0] != '(':
                    src = [src]
                else:
                    columns.append((n, src))
                    continue
            if "type" in c and "cast" in c:
                ctype = (c["type"], c["cast"])
            else:
                ctype = None
            macros = dict()
            for candidate in src:
                if '$' in candidate:
                    var = candidate[candidate.find('$') + 1]
                    if var not in c:
                        raise ValueError(
                            "Macro {} is used but is not defined for column {}"
                            " and candidate {}".format(
                                var, n, candidate
                            )
                        )
                    macros[var] = c[var]
            source_column = self.get_column(cursor, table, src, ctype, macros)
            # if "clean" in c:
            #     source_column = c["clean"].format(n=source_column)
            if source_column is None:
                if opt:
                    if "type" in c:
                        source_column = "NULL::" + c["type"]
                    else:
                        source_column = "NULL"
                else:
                    raise ValueError("{}.{}".format(table, n))
            columns.append((n, source_column))
        return columns

    @classmethod
    def get_column(cls, cursor, table: str,
                   candidates: List[str],
                   ctype: Tuple,
                   macros: Dict) -> Optional[str]:
        cols = []
        simple_candidates = [c for c in candidates if '$' not in c]
        ext_candidates = [c for c in candidates if '$' in c]
        for candidate in ext_candidates:
            expr = cls.find_column2arr(cursor, table, candidate, macros)
            if expr:
                cols.append(expr)
        if not cols:
            cols = cls.get_simple_column(cursor, table, simple_candidates, ctype)
        if len(cols) > 1:
            raise ValueError(
                "Multiple options for table {}: {}".format(
                    table,
                    ', '.join(cols)
                )
            )
        if not cols:
            return None
        return cols[0]

    @classmethod
    def get_simple_column(cls, cursor, table: str,
                       candidates: List[str],
                       ctype: Tuple):
        cols = []
        sql = """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE ({})
        AND table_name = '{}'
        AND table_schema = 'cms'
        """
        cc = ["column_name = '{}'".format(c) for c in candidates]
        sql = sql.format(" OR ".join(cc), table)
        logging.debug(sql)
        cursor.execute(sql)
        if ctype is not None:
            casts = ctype[1]
            target_type = ctype[0]
        else:
            casts = None
            target_type = None
        for c in cursor:
            if ctype is not None and c[1].upper() != target_type.upper():
                if c[1] in casts:
                    cast = casts[c[1]]
                elif '*' in casts:
                    cast = casts['*']
                else:
                    raise ValueError(
                        "Column {}.{}: cast from {} to {} is not defined"
                        .format(
                            table, c[0], c[1], target_type
                        )
                    )
                cols.append(cast.format(column_name=c[0]))
            else:
                cols.append(c[0])
        return cols

    @classmethod
    def find_column2arr(cls, cursor, table: str, candidate: str, macros: Dict):
        cc = [candidate]
        for var in macros:
            subst: List[str] = macros[var]
            ccc = []
            for c in cc:
                expansion = [
                    c.replace("${}".format(var), v)
                    for v in subst
                ]
                ccc.extend(expansion)
            cc = ccc
        lst = ["'{}'".format(c) for c in cc]
        condition = "column_name IN ({})".format(', '.join(lst))
        sql = """
        SELECT column_name
        FROM information_schema.columns
        WHERE ({})
        AND table_name = '{}'
        AND table_schema = 'cms'
        """.format(condition, table)
        logging.debug(sql)
        cursor.execute(sql)
        source_columns = [c[0] for c in cursor]
        if not source_columns:
            return None
        if len(source_columns) != len(cc):
            logging.warning(
                "Not all members [{:d}] were found for column {} in table {}"
                .format(len(source_columns), candidate, table)
            )
            return None
        return "ARRAY[{}]".format(','.join(cc))


if __name__ == '__main__':
    mpst = MedicareCombinedView()
    mpst.print_sql()
    mpst.execute()


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
import logging
import os
from pathlib import Path
from typing import List, Tuple, Optional

import yaml

from nsaph import init_logging
from nsaph.data_model.utils import split

from nsaph.db import Connection

from nsaph.loader.common import DBConnectionConfig


class MedicarePatientSummaryTable:
    def __init__(self, context: DBConnectionConfig = None):
        if not context:
            context = DBConnectionConfig(None, __doc__).instantiate()
        self.context = context
        src = Path(__file__).parents[1]
        rp = os.path.join(src, "models", "medicare.yaml")
        with open(rp) as f:
            content = yaml.safe_load(f)
        self.table = content["medicare"]["tables"]["ps"]
        self.schema = content["medicare"]["schema"]
        self.sql = ""

    def print_sql(self):
        if not self.sql:
            self.generate_sql()
        print(self.sql)

    def execute(self):
        if not self.sql:
            self.generate_sql()
        with Connection(self.context.db,
                        self.context.connection) as cnxn:
            with cnxn.cursor() as cursor:
                cursor.execute(self.sql)
            cnxn.commit()
        print("All Done")


    def generate_sql(self):
        with Connection(self.context.db,
                        self.context.connection) as cnxn:
            cursor = cnxn.cursor()
            tables = self.get_tables(cursor)
            tt = [self.table_sql(cursor, t) for t in tables]
            sql = "DROP VIEW IF EXISTS {}.{};\n".format(self.schema, "ps")
            sql += "CREATE VIEW {}.{} AS \n".format(self.schema, "ps")
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
            if src is None:
                cc.append("NULL AS " + target)
            else:
                cc.append("{} AS {}".format(src, target))
        sql = sql.format(",\n\t".join(cc), schema, table)
        return sql

    def get_columns(self, cursor, table: str) -> List[Tuple]:
        columns: List[Tuple] = []
        for clmn in self.table["columns"]:
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
            source_column = self.get_column(cursor, table, src, ctype)
            # if "clean" in c:
            #     source_column = c["clean"].format(n=source_column)
            if (not opt) and (source_column is None):
                raise ValueError("{}.{}".format(table, n))
            columns.append((n, source_column))
        return columns

    def get_column(self, cursor, table: str,
                   candidates: List[str], ctype: Tuple) -> Optional[str]:
        sql = """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE ({})
        AND table_name = '{}'
        """
        cc = ["column_name = '{}'".format(c) for c in candidates]
        sql = sql.format(" OR ".join(cc), table)
        logging.debug(sql)
        cursor.execute(sql)
        cols = []
        for c in cursor:
            if ctype is not None and c[1] != ctype[0]:
                cast = ctype[1][c[1]]
                cols.append(cast.format(column_name=c[0]))
            else:
                cols.append(c[0])
        if len(cols) > 1:
            raise ValueError(table)
        if not cols:
            return None
        return cols[0]




if __name__ == '__main__':
    init_logging()
    mpst = MedicarePatientSummaryTable()
    mpst.print_sql()
    mpst.execute()


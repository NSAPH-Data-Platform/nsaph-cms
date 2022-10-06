"""
Executes PL/pgSQL procedure from a file.

Primarily used to populate a table from a view

File has to be loaded before executing procedure, but
cannot be loaded in advance, because some tables
are created dynamically just before the execution
"""


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
import os

from nsaph.loader import LoaderBase

from nsaph.loader.common import CommonConfig

from nsaph.util.init_core_db import parse_args, init_core, get_sql_dir, execute


class PopulateConfig(CommonConfig):
    def __init__(self, subclass, doc):
        super().__init__(subclass, doc)


class TablePopulator:
    def __init__(self, context: PopulateConfig = None):
        if not context:
            context = PopulateConfig(None, __doc__).instantiate()
        self.context = context
        if not self.context.table:
            raise ValueError("'--table' is a required option")
        if self.context.domain in ['medicaid', 'medicare']:
            self.sql_file = self.context.domain + "_procedures.sql"
        else:
            raise ValueError(
                "Table population is not supported for domain " +
                self.context.domain
            )
        self.domain = LoaderBase.get_domain(
            self.context.domain, self.context.registry
        )
        if self.context.table == 'enrollments':
            self.table = self.domain.fqn(self.context.table)
            self.proc = "CALL {}.populate_{}();".format(
                self.context.domain,
                self.context.table
            )
        return


def init_cms(args):
    sdir = get_sql_dir(__file__)
    execute(args, os.path.join(sdir, "functions.sql"))


if __name__ == '__main__':
    arguments = parse_args()
    init_core(arguments)
    init_cms(arguments)

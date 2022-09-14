"""
Initializes Database with functions and procedures used by CMS package
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

from nsaph.util.init_core_db import parse_args, init_core, get_sql_dir, execute


def init_cms(args):
    sdir = get_sql_dir(__file__)
    execute(args, os.path.join(sdir, "functions.sql"))


if __name__ == '__main__':
    arguments = parse_args()
    init_core(arguments)
    init_cms(arguments)

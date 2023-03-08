"""
Command line tool to create and/or update
Data model for raw CMS data.
"""


#  Copyright (c) 2021. Harvard University
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
from pathlib import Path
from typing import Dict

import yaml

from cms.create_schema_config import CMSSchema
from cms.fts2yaml import MedicaidFTS, MedicareFTS, mcr_type
from nsaph import init_logging


class Registry:
    """
    This class parses File Transfer Summary files and
    creates YAML data model. It can either
    update built-in registry or write
    the model to a designated path
    """

    def __init__(self, context: CMSSchema = None):
        if not context:
            context = CMSSchema(__doc__).instantiate()
            init_logging(name="Introspect-" + context.input)
        self.context = context
        self.registry = None
        self.name = "cms"

    def update(self):
        if self.context.output is None:
            registry_path = self.built_in_registry_path()
        else:
            registry_path = self.context.output

        if (not self.context.reset) and os.path.isfile(registry_path):
            with open(registry_path) as f:
                self.registry = yaml.safe_load(f)
        else:
            self.init()
        if self.context.type == "medicaid":
            self.update_medicaid()
        elif self.context.type == "medicare":
            self.update_medicare()
        else:
            raise ValueError("Unknown data type: " + self.context.type)

        with open(registry_path, "wt") as f:
            f.write(yaml.dump(self.registry))
        return

    def init(self):
        domain = {
            self.name: {
                "reference": "https://resdac.org/getting-started-cms-data",
                "schema": self.name,
                "index": "explicit",
                "quoting": 3,
                "header": False,
                "tables": {
                }
            }
        }
        self.registry = domain
        return

    def update_medicaid(self):
        domain = self.registry[self.name]
        for x in ["ps", "ip"]:
            domain["tables"].update(
                MedicaidFTS(x).init(self.context.input).to_dict()
            )
        domain["tables"]["ps"]["indices"] = {
            "primary": {
                "columns": ["bene_id", "state_cd", "max_yr_dt"]
            }
        }
        domain["tables"]["ip"]["indices"] = {
            "primary": {
                "columns": ["bene_id", "state_cd", "yr_num"]
            }
        }
        return

    def update_medicare(self):
        domain = self.registry[self.name]
        f = self.context.input
        basedir, fts = os.path.split(f)
        t = mcr_type(fts)
        table = MedicareFTS(t).init(f).to_dict()
        domain["tables"].update(table)

    @staticmethod
    def built_in_registry_path():
        src = Path(__file__).parents[3]
        return os.path.join(src, "yml", "cms.yaml")


if __name__ == '__main__':
    Registry().update()
    
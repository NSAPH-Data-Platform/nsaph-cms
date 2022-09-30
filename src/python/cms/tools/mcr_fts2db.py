"""
Command line utility to load raw Medicare data into the database.

Used for 2011 and later years. Looks for FTS files, parses them to generate
database model and extract
metadata required to read DAT files. Then loads data into the database.

This module looks for FTS files, parses them, then looks for corresponding
DAT files. It copies FTS files to destination directory and selects a few
random records from DAT files.

Please note, that if the destination to be used with Medicare
ingestion pipeline, the full path to resulting FTS and DAT files must include
a directory named with the year, e.g. my_data/medicare/2018/*.fts
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
import copy
import glob
import logging
import os
from typing import List

from nsaph import init_logging
from nsaph.loader.index_builder import IndexBuilder

from cms.mcr_data_loader import MedicareDataLoader
from cms.registry import Registry

from cms.create_schema_config import CMSSchema

from cms.fts2yaml import mcr_type
from nsaph.loader.data_loader import DataLoader

from nsaph.loader import LoaderConfig
from nsaph.loader.vacuum import Vacuum


class MedicareLoader:
    """
    Medicare Loader for original medicare data received from Resdac. Used
    for 2011 and later years.

    Looks for FTS files, parses them to generate database model and extract
    metadata required to read DAT files. Then loads data into the database.
    """

    @classmethod
    def process(cls):
        loader = MedicareLoader()
        loader.traverse(loader.pattern)

    def __init__(self):
        self.pattern = "**/*.fts"
        self.context = LoaderConfig(__doc__)
        self.context.domain = "cms"
        self.context.set_empty_args()
        self.root_dir=self.context.data
        self.context.data = [
            os.path.dirname(f) if os.path.isfile(f) else f
            for f in self.context.data
        ]
        if not self.context.incremental and not self.context.sloppy:
            self.context.reset = True
        return

    def traverse(self, pattern: str):
        if isinstance(self.root_dir, list):
            dirs = self.root_dir
        else:
            dirs = [self.root_dir]
        files: List[str] = []
        for d in dirs:
            if os.path.isfile(d):
                files.append(d)
            else:
                files.extend(glob.glob(os.path.join(d, pattern), recursive=True))
        if len(files) == 0:
            self.handle_empty()
        for f in files:
            try:
                self.handle(f)
            except Exception as x:
                logging.exception("Error handling {}. Ignoring.".format(str(f)))
        return

    def handle_empty(self):
        init_logging()
        logging.info("No files to process")
        if not os.path.exists(self.context.registry):
            with open(self.context.registry, "a") as r:
                r.write("# Empty\n")
        return 

    def handle(self, fts_path: str):
        basedir, fname = os.path.split(fts_path)
        _, ydir = os.path.split(basedir)
        try:
            year = int(ydir)
        except:
            raise ValueError(
                "Immediate parent directory '{}' of {} was expected to be named"
                + " as 4 digit year (YYYY), e.g. 2011 or 2018"
                .format(ydir, fts_path)
            )
        f, ext = os.path.splitext(fts_path)
        ttype = mcr_type(fname)
        ctxt = CMSSchema(None,
                         path=self.context.registry,
                         inpt=fts_path,
                         tp= "medicare",
                         reset=False)
        reg = Registry(ctxt)
        reg.update()
        context = copy.deepcopy(self.context)
        context.table = "{}_{:d}".format(ttype, year)

        if os.path.isfile(f + ".csv.gz"):
            loader = self.loader_for_csv(context, f + ".csv.gz")
        elif glob.glob("{}*.dat".format(f)):  #os.path.isfile(f + ".dat"):
            loader = self.loader_for_fwf(context, fts_path)
        else:
            raise ValueError("Data file was not found: " + f)
        if self.context.dryrun:
            print("Dry run: " + fts_path)
        else:
            loader.run()
            IndexBuilder(context).run()
            Vacuum(context).run()

    @staticmethod
    def loader_for_csv(context: LoaderConfig, data_path: str) -> DataLoader:
        context.pattern = [os.path.join("**", os.path.basename(data_path))]
        loader = DataLoader(context)
        loader.csv_delimiter = '\t'
        return loader

    @staticmethod
    def loader_for_fwf(context: LoaderConfig, fts_path: str) -> DataLoader:
        context.data = [fts_path]
        loader = MedicareDataLoader(context)
        return loader


if __name__ == '__main__':
    MedicareLoader.process()

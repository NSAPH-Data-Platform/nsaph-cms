"""

Given original Medicare data, this module creates a small,
randomly selected subset of the data for testing purposes.

It does not remove PII!!!

See also `Random selector for CSV files <random_selector.html>`_

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

import gzip
from argparse import ArgumentParser

import os
import glob
import random
from typing import List

import shutil

from nsaph.loader.project_loader import remove_ext
from nsaph_utils.utils.io_utils import fopen


SEED = 1


class FTSTuple:
    def __init__(self, root: str, fts_file: str):
        self.root = root
        fts_file = fts_file
        basename = remove_ext(fts_file)
        dat_files = glob.glob(basename + '*.dat')
        self.valid = len(dat_files) > 0
        if not self.valid:
            return
        relpath = os.path.relpath(basename, root)
        self.dir = os.path.dirname(relpath)
        self.fts_file = os.path.basename(fts_file)
        self.dat_files = [os.path.basename(f) for f in dat_files]
        return

    def fts_path(self) -> str:
        return os.path.join(self.root, self.dir, self.fts_file)

    def dat_path(self, dat_file) -> str:
        return os.path.join(self.root, self.dir, dat_file)


def find_fts_tuples(root: str) -> List[FTSTuple]:
    pattern = os.path.join(root, "**/*.fts")
    fts_files = glob.glob(pattern, recursive=True)
    result: List[FTSTuple] = []
    for fts_path in fts_files:
        fts = FTSTuple(root, fts_path)
        if not fts.valid:
            continue
        result.append(fts)
    return result


def select(root: str, destination: str, threshold: float):
    data = find_fts_tuples(root)
    random.seed(SEED)
    for fts in data:
        dest = os.path.join(destination, fts.dir)
        if not os.path.isdir(dest):
            os.makedirs(dest)
        if not os.path.isfile(os.path.join(dest, fts.fts_file)):
            shutil.copy(fts.fts_path(), dest)

        for dat_file in fts.dat_files:
            dat_dest = os.path.join(dest, dat_file)
            dat_src = fts.dat_path(dat_file)
            if os.path.isfile(dat_dest):
                print("Skipping: {}".format(dat_src))
                continue
            print("{} ==> {}".format(dat_src, dest))

            with fopen(dat_src, "rt") as src, open(dat_dest, "wt") as output:
                n1 = 0
                n2 = 0
                for line in src:
                    n1 += 1
                    if random.random() < threshold:
                        output.write(line)
                        n2 += 1
                    if (n1 % 1000000) == 0:
                        print('*', end='')
            print("{:d}/{:d}".format(n2, n1))
    print("All Done")


def args():
    """
    Parses command line arguments

      --in INPUT           pattern to select incoming files
      --out OUT            Directory to output the random selection
      --selector SELECTOR  A float value specifying the share of data to be
                           selected

    :return: arguments as dictionary
    """
    parser = ArgumentParser ("Random records selector")
    parser.add_argument("--in",
                        help="Root directory for original data",
                        dest="input",
                        required=True)
    parser.add_argument("--out",
                        help="Directory to output the random selection",
                        default="random_data",
                        required=True)
    parser.add_argument("--selector",
                        help="A float value specifying the "
                             + "share of data to be selected",
                        default=0.02,
                        type=float,
                        required=False)
    arguments = parser.parse_args()
    return arguments


if __name__ == '__main__':
    arg = args()
    select(arg.input, arg.out, arg.selector)


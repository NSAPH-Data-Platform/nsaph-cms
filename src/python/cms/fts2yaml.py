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

"""
Parse utilities for File Transfer Summary (FTS) files generated by SAS.

Tries to recognize a type of a medicare or a medicaid CMS file and
extract metadata

:class:`Abstract class for CMS FTS file <cms.tools.fts2yaml.CMSFTS>`
:class:`Concrete subclass describing Medicare FTS file <cms.tools.fts2yaml.MedicareFTS>`
:class:`Concrete subclass describing Medicaid FTS file <cms.tools.fts2yaml.MedicaidFTS>`

:class:`Abstract class describing a column in a CMS data file <cms.tools.fts2yaml.FTSColumn>`
:class:`Concrete subclass describing a column in a Medicaid data file<cms.tools.fts2yaml.MedicaidFTSColumn>`
:class:`Concrete subclass describing a column in a Medicaid data file<cms.tools.fts2yaml.MedicareFTSColumn>`
:class:`Concrete subclass describing a column not present in the original data but that should be generated in the database <cms.tools.fts2yaml.AliasColumn>`

"""


import glob
import os
from typing import List, Optional, Dict

import yaml

from nsaph import ORIGINAL_FILE_COLUMN
from nsaph_utils.utils.fwf import FWFColumn, FWFMeta
from nsaph_utils.utils.io_utils import fopen
from nsaph.pg_keywords import *


MEDICARE_FILE_TYPES = ["mbsf_abcd", "mbsf_ab", "mbsf_d", "medpar"]
'''Known medicare file types'''


MEDICARE_KEY_COLUMNS = {
    "BENE_ID": [],
    "STATE": ["STATE_CD"],
    "YEAR": ["RFRNC_YR", "MEDPAR_YR_NUM"],
    "ZIP": ["BENE_ZIP", "ZIP_CD"]
}


def mcr_type(file_name: str) -> str:
    """
    Tries to guess medicare file type by its name
    :param file_name: Name of the file
    :return: string denoting file type
    """

    for t in MEDICARE_FILE_TYPES:
        if file_name.startswith(t):
            return t
    raise ValueError("Unsupported Medicare file type: " + file_name)


def width(s:str):
    if '.' in s:
        x = s.split('.')
        return (int(x[0]), int(x[1]))
    return (int(s), None)


class ColumnAttribute:
    """
    Column attribute as read from FTS
    """

    def __init__(self, start:int, end:int, conv):
        self.start = start
        self.end = end
        self.conv = conv

    def arg(self, line:str):
        try:
            return self.conv(line[self.start:self.end].strip())
        except:
            pass

    def __str__(self):
        return "[{:d}:{:d}] {}".format(self.start, self.end, str(self.conv))


class ColumnReader:
    """
    Reads columns section of an FTS file
    """

    def __init__(self, constructor, pattern):
        self.constructor = constructor
        fields = pattern.split(' ')
        assert len(fields) == constructor.nattrs
        self.attributes = []
        c = 0
        for i in range(0, len(fields)):
            l = len(fields[i])
            f = constructor.conv(i)
            self.attributes.append(ColumnAttribute(c, c+l, f))
            c += l + 1
        self.attributes[-1].end = None

    def read(self, line):
        attrs = [a.arg(line) for a in self.attributes]
        return self.constructor(*attrs)


class FTSColumn:
    """
    Metadata object for a column described in FTS file

    A column can be either a CSV or fixed width (fwf) column
    """

    @classmethod
    def conv(cls, i):
        """
        Conversion function that should be applied to
            the i-th attribute of a column

        :param i: attribute
        :return: Callable function
        """

        if i in [0, 4]:
            f = int
        else:
            f = str
        return f

    def __init__(self, order, column, c_type, c_format, c_width, label):
        self.order = order
        self.column = column
        self.type = c_type
        self.format = c_format
        self.width = c_width
        self.label = label
        self.is_input = True
        self._attrs = [
            attr for attr in self.__dict__ if attr[0] != '_'
        ]

    def __eq__(self, o: object) -> bool:
        if not isinstance(o, FTSColumn):
            return False
        if o is self:
            return True
        for attr in self._attrs:
            if getattr(self, attr) != getattr(o, attr):
                return False
        return True

    def __str__(self) -> str:
        return "{:d}: {} [{}]".format(self.order, self.column, self.type)

    def analyze_format(self):
        if self.format is not None:
            if self.format[0].isdigit():
                fmt = self.format
                can_be_numeric = True
            else:
                fmt = self.format[1:]
                can_be_numeric = False
            x = fmt.split('.')
            if x[0].isdigit():
                w = int(x[0])
            else:
                w = None
            if len(x) > 1 and x[1]:
                scale = int(x(1))
            else:
                scale = None
        else:
            w = int(self.width)
            if w != self.width:
                scale = int(str(self.width).split('.')[1])
            else:
                scale = None
            can_be_numeric = True
        return can_be_numeric, scale, w

    def to_sql_type(self):
        """
        SQL Type of the column
        :return: SQL type of the column
        """

        t = self.type.upper()
        if t in [PG_SERIAL_TYPE]:
            return t

        can_be_numeric, scale, wdt = self.analyze_format()
        if t == "CHAR":
            return "{}({:d})".format(PG_STR_TYPE, wdt)
        if t == "NUM":
            if not can_be_numeric:
                return "{}({:d})".format(PG_STR_TYPE, wdt)
            if scale is not None:
                return "{}({:d},{:d})".format(PG_NUMERIC_TYPE, wdt, scale)
            return "{}".format(PG_INT_TYPE)
        if t == "DATE":
            return PG_DATE_TYPE
        raise Exception("Unexpected column type: {}".format(t))

    def to_dict(self):
        return {
            "type": self.to_sql_type(),
            "description": self.label
        }

    def to_fwf_column(self, pos:int) -> FWFColumn:
        """
        Returns a description of a fixed width (fwf) column required to create
        a FWF reader

        :param pos: starting position of the column in a record
        :return: A descriptor for FWF column
        """

        _, scale, width = self.analyze_format()
        return FWFColumn(
            name=self.column,
            type=self.type,
            order=self.order,
            start=pos,
            width = (width, scale)
        )


class AliasColumn(FTSColumn):
    """
    Subclass describing a column not present in the original data but
    that should be generated in the corresponding  database table
    """

    def __init__(self, alias: str, column: FTSColumn):
        super().__init__(column.order, alias,
                         column.type, column.format,
                         column.width, column.label)
        self.target = column.column
        return

    def to_dict(self):
        d = super().to_dict()
        d["index"] = True
        d["source"] = {
            "type": "generated",
            "code": "GENERATED ALWAYS AS ({}) STORED"
                .format(self.target)
        }
        return d


class MedicaidFTSColumn(FTSColumn):
    """
    Subclass for a column in medicaid files
    """

    nattrs = 6


class MedicareFTSColumn(FTSColumn):
    """
    Subclass for a column in medicare files
    """

    nattrs = 7

    @classmethod
    def conv(cls, i):
        if i in [0, 4]:
            f = int
        elif i in [5]:
            f = float
        else:
            f = str
        return f

    def __init__(self, order: int, long_name:str, short_name:str, type:str, start:int, width, desc:str):
        super().__init__(
            order,
            column=short_name,
            c_type=type,
            c_width=width,
            c_format=None,
            label=desc
        )
        self.long_name = long_name
        self.start = start - 1
        try:
            self.end = self.start + self.width
        except:
            raise


class CMSFTS:
    """
    Abstract class for Medicaid and Medicare files from CMS
    """

    common_indices = [
                "BENE_ID",
                ORIGINAL_FILE_COLUMN
            ]

    def __init__(self, type_of_data: str):
        """

        :param type_of_data: Can be either `ps` for personal summary or
            `ip` for inpatient admissions data
        """

        self.table_type = type_of_data.lower()
        self.table_name = None
        self.indices = self.common_indices
        self.columns: List[FTSColumn] = []
        self.pk = None
        self.constructor = None
        self.pattern = None
        self.metadata = dict()
        return

    def init(self, path: str):
        pass

    def read_file(self, f):
        with fopen(f, "rt") as fts:
            lines = [line for line in fts]
        i = 0
        column_reader = None
        for i in range(0, len(lines)):
            line = lines[i]
            if line.startswith('---') and '------------------' in line:
                column_reader = ColumnReader(self.constructor, line)
                break
            if ':' in line:
                x = line.split(':', 1)
                self.metadata[x[0].strip()] = x[1].strip()
            continue

        if 1 > i or i > len(lines) - 2:
            raise Exception("Column definitions are not found in {}".format(f))

        columns = []
        while i < len(lines):
            i += 1
            line = lines[i]
            if not line.strip():
                break
            if line.startswith("Note:"):
                break
            if line.startswith("-") and "End" in line:
                break
            column = column_reader.read(line)
            columns.append(column)

        self.on_after_read_file(columns)
        if not self.columns:
            self.columns = columns
            return

        if len(columns) != len(self.columns):
            raise Exception("Reconciliation required: {}, number of columns".format(f))

        for i in range(len(columns)):
            if columns[i] != self.columns[i]:
                raise Exception("Reconciliation required: {}, column: {}".format(f, columns[i]))

    def on_after_read_file(self, columns: List[FTSColumn]):
        """
        Callback function

        :param columns: columns read from FTS file
        :return:  nothing
        """

        self.add_file_column(columns)

    @staticmethod
    def add_record_column(columns: List[FTSColumn]):
        """
        Adds a RECORD column, to uniquely identify a record in the database.
        A column is of type SERIAL, i.e. auto-incremented

        :param columns:
        :return:
        """
        column = FTSColumn(
            order=len(columns) + 1,
            column="RECORD",
            c_type=PG_SERIAL_TYPE,
            c_format=None,
            c_width=None,
            label="Record number in the file"
        )
        column.is_input = False
        columns.append(column)

    @staticmethod
    def add_file_column(columns: List[FTSColumn]):
        """
        Adds a column containing the name of original file, from which the data
        has been read

        :param columns:
        :return:
        """
        column = FTSColumn(
            order=len(columns) + 1,
            column=ORIGINAL_FILE_COLUMN,
            c_type="CHAR",
            c_format="128",
            c_width=128,
            label="RESDAC original file name"
        )
        column.is_input = False
        columns.append(column)

    def column_to_dict(self, c: FTSColumn) -> dict:
        """
        Returns a column as a dictionary object that can be added to
        YAML data model
        :param c: a column as parsed from FTS
        :return: dictionary
        """

        d = c.to_dict()
        if c.column in self.indices:
            d["index"] = True
        if c.column == ORIGINAL_FILE_COLUMN:
            d["source"] = {
                "type": "file"
            }
            d["index"] = {"required_before_loading_data": True}
        return d

    def to_dict(self):
        """
        Returns full metadata for the file as a dictionary
        to be included in the YAML data model used to
        generate DDL for the corresponding table

        :return:    dictionary
        """

        table = dict()
        tname = self.table_name \
            if self.table_name is not None else self.table_type
        t = dict()
        t["columns"] = [
            {
                c.column: self.column_to_dict(c)
            } for c in self.columns
        ]
        t["primary_key"] = self.pk
        for idx in self.indices:
            if not isinstance(idx, dict):
                continue
            if "indices" not in t:
                t["indices"] = dict()
            t["indices"].update(idx)

        table[tname] = t
        return table

    @staticmethod
    def v2i(v: str):
        return int(v.strip().replace(',',''))

    def to_fwf_meta(self, data_path: str) -> FWFMeta:
        """
        Returns metadata required to read the file if
        it is a fixed width file

        :param data_path:
        :return: Metadata as required by FWF reader
        """

        key = "Exact File Record Length (Bytes in Variable Block)"
        if key in self.metadata:
            record_len = self.v2i(self.metadata[key])
        else:
            raise AssertionError("Record Length is undefined")
        key = "Exact File Size in Bytes with 512 Blocksize"
        fsize = self.v2i(self.metadata.get(key, None))
        key = "Exact File Quantity (Rows)"
        nrows = self.v2i(self.metadata.get(key, None))
        pos = 0
        columns = []
        for c in self.columns:
            if not c.is_input:
                continue
            fwf_column = c.to_fwf_column(pos)
            columns.append(fwf_column)
            pos = fwf_column.end
        return FWFMeta(
            path=data_path,
            record_len=record_len,
            size=fsize,
            number_of_rows=nrows,
            columns=columns
        )

    def print_yaml(self, root_dir: str = None):
        self.init(root_dir)
        table = self.to_dict()
        print(yaml.dump(table))


class MedicaidFTS(CMSFTS):
    """
    Subclass describing Medicaid data file (usually, CSV)
    """

    medicaid_indices = [
                "EL_DOB",
                "EL_SEX_CD",
                "EL_DOD",
                "EL_RACE_ETHNCY_CD"
            ]

    def __init__(self, type_of_data: str):
        super().__init__(type_of_data)
        self.constructor = MedicaidFTSColumn
        assert self.table_type in ["ps", "ip"]
        self.pattern = "**/maxdata_{}_*.fts".format(type_of_data)
        self.indices += self.medicaid_indices
        if self.table_type == "ps":
            year_column = "MAX_YR_DT"
            self.pk = ["MSIS_ID", "STATE_CD", year_column]
            self.indices += self.pk.copy()
            self.indices.append("EL_AGE_GRP_CD")
        else:
            year_column = "YR_NUM"
            self.pk = ["FILE", "RECORD"]
            self.indices += ["MSIS_ID", "STATE_CD", year_column, "RECORD"]

    def init(self, path: str = None):
        if path is not None:
            pattern = os.path.join(path, self.pattern)
        else:
            pattern = self.pattern
        files = glob.glob(pattern)
        for file in files:
            self.read_file(file)
        return self

    def on_after_read_file(self, columns: List[FTSColumn]):
        super().on_after_read_file(columns)
        if self.table_type == "ip":
            self.add_record_column(columns)


class MedicareFTS(CMSFTS):
    """
    Subclass describing Medicare data file (usually, FWF dat file)
    """

    def __init__(self, type_of_data: str):
        super().__init__(type_of_data)
        self.constructor = MedicareFTSColumn
        assert self.table_type in MEDICARE_FILE_TYPES
        self.pattern = "**/{}_*.fts".format(type_of_data)
        self.key_columns: Dict[str, Optional[FTSColumn]] = {
            key: None for key in MEDICARE_KEY_COLUMNS
        }
        self.pk = ["FILE", "RECORD"]
        return

    def init(self, fts_path: str):
        ydir = os.path.basename(os.path.dirname(fts_path))
        self.table_name = "{}_{}".format(self.table_type, ydir)
        self.read_file(fts_path)
        return self

    def on_after_read_file(self, columns: List[FTSColumn]):
        super().on_after_read_file(columns)
        self.add_record_column(columns)
        self.check_key_columns(columns)
        self.add_indices(columns)

    def check_key_columns(self, columns: List[FTSColumn]):
        for column in columns:
            for key in MEDICARE_KEY_COLUMNS:
                candidates = [key] + MEDICARE_KEY_COLUMNS[key]
                if column.column.upper() in candidates:
                    if self.key_columns[key] is not None:
                        raise ValueError(
                            "Duplicate column candidate for " + key
                        )
                    self.key_columns[key] = column
        for key in ["BENE_ID", "YEAR"]:
            if self.key_columns[key] is None:
                raise ValueError("Missing {} column for {}".format(
                    key,  self.table_type
                ))
        if self.table_type.startswith("mbsf_ab"):
            for key in MEDICARE_KEY_COLUMNS:
                if self.key_columns[key] is None:
                    raise ValueError("Missing {} column for {}".format(
                        key,  self.table_type
                    ))
        return

    def add_indices(self, columns: List[FTSColumn]):
        p_idx_columns = []
        for key in MEDICARE_KEY_COLUMNS:
            c = self.key_columns[key]
            if c is None:
                continue
            if key in ["BENE_ID", "YEAR"]:
                p_idx_columns.append(key)
            elif self.table_type.startswith("mbsf_ab") and key in ["STATE"]:
                p_idx_columns.append(key)
            if c.column.upper() == key:
                self.indices.append(key)
            elif c is not None:
                columns.append(AliasColumn(key, c))
        self.indices.append({"primary": {"columns": p_idx_columns}})


if __name__ == '__main__':
    source = MedicaidFTS("ps")
    source.print_yaml()


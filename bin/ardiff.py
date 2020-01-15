#!/usr/bin/env python

import argparse
import logging
import os
import re
import shutil
import subprocess
import sys
import tempfile

#Module constants.
nccmp = "nccmp"
gcp = "gcp"
unknown_file_format = "Unknown file format"
TAR = "tar archive"
DIR = "directory"


class RunError(BaseException):
    pass


def run(command,success=0):
    logger = logging.getLogger(__name__)
    logger.info(" ".join(command) + "\n")
    p = subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    o,e = p.communicate()
    if p.returncode != success:
        raise RunError("%s\n%s\n" % (o,e))
    return o,e


def diff(file1,file2):
    sys.stderr.write("Comparing files %s and %s.\n" % (file1,file2))
    try:
        run([nccmp,"-m","-d","-f","-w","format",file1,file2])
    except RunError as e:
        if unknown_file_format in str(e):
            run(["diff",file1,file2])
        else:
            raise


def gcp_file(filepath):
    if re.match(r'\w+:.+',filepath):
        tmpdir = tempfile.mkdtemp()
        try:
            run([gcp,"-v",filepath,tmpdir])
        except RunError as e:
            shutil.rmtree(tmpdir)
            raise
        name = os.path.basename(filepath.split(":",count=1)[-1])
        return os.path.join(tmpdir,name)
    else:
        raise ValueError("path %s does not match gcp format.\n" % filepath)


class FileObj(object):

    def __init__(self,path):
        self.cleanup = []
        try:
            self.path = gcp_file(path)
            self.cleanup.append(os.path.dirname(self.path))
        except ValueError as e:
            self.path = path
        o = run(["file",path])
        self.ftype = o[0].lstrip(path + ":").strip()
        if self.is_tar():
            self.ftype = TAR

    def clean(self):
        for f in self.cleanup:
            try:
                shutil.rmtree(f)
            except BaseException as e:
                sys.stderr.write(str(e) + "\n")

    def is_tar(self):
        return TAR in self.ftype

    def is_directory(self):
        return DIR in self.ftype

    def untar(self):
        if self.is_tar():
            tmpdir = tempfile.mkdtemp()
            try:
                o = run(["tar","xvf",self.path,"-C",tmpdir])
            except RunError as e:
                shutil.rmtree(tmpdir)
                raise
            self.ftype = DIR
            self.path = tmpdir
            self.cleanup.append(self.path)
        else:
            raise ValueError("not a tar file.")


def main(file1,file2):
    obj = [file1,file2]
    types = set([x.ftype for x in obj])
    if len(types) != 1:
        raise ValueError("\n\t".join(["Input files have different types:"]
                         + list(types)) + "\n")
    for o in obj:
        if o.is_tar():
            o.untar()

    files_list = []
    if obj[0].is_directory():
        for root,dirs,files in os.walk(obj[0].path):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for f in files:
                name = os.path.join(root,f)
                name2 = re.sub(re.escape(obj[0].path),obj[1].path,name,count=1)
                files_list.append((name,name2))
    else:
        files_list.append((obj[0].path,obj[1].path))

    failed = []
    for f in files_list:
        try:
            diff(f[0],f[1])
        except RunError as e:
            sys.stderr.write(str(e))
            failed.append(os.path.basename(f[0]))

    print("%d/%d files passed." % ((len(files_list)-len(failed)),
          len(files_list)))
    print("Files that failed:")
    for f in failed:
        print("\t%s" % f)

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("reference",
                        nargs=1,
                        help="reference file/directory that will be"
                             + " used in the comparison.")
    parser.add_argument("files",
                        nargs="+",
                        help="file/directory that will be diffed."
                             + "  Directories will be fully walked.")
    parser.add_argument("-v",
                        "--verbose",
                        help="increase output verbosity.",
                        action="store_true")
    args = parser.parse_args()

    if args.verbose:
        logging.basicConfig(level=logging.INFO)
    else:
        logging.basicConfig(level=logging.ERROR)

    ref = FileObj(args.reference[0])
    for f in args.files:
        o = FileObj(f)
        main(ref,o)
        o.clean()
    ref.clean()

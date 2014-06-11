import re
import sys

# Prevent any newline translation, and text decoding/encoding, by using bytes,
# rather than strings.
def filter_file(inf_name, outf_name):
    ts_chunkstart = re.compile(b"diff --git ")
    ts_redhat = re.compile(b".*\/.distro\/")
    ts_gitfile = re.compile(b".*\/\.git")
    ts_submodule = re.compile(b".*\/CryptoPkg\/Library\/OpensslLib\/openssl")
    ts_submodule2 = re.compile(b".*\/ArmPkg\/Library\/ArmSoftFloatLib\/berkeley-softfloat-3")
    ts_submodule3 = re.compile(b".*\/UnitTestFrameworkPkg\/Library\/CmockaLib\/cmocka")
    ts_submodule4 = re.compile(b".*\/MdeModulePkg\/Universal\/RegularExpressionDxe\/oniguruma")
    ts_submodule5 = re.compile(b".*\/MdeModulePkg\/Library\/BrotliCustomDecompressLib\/brotli")
    ts_submodule6 = re.compile(b".*\/BaseTools\/Source\/C\/BrotliCompress\/brotli")
    ts_submodule7 = re.compile(b".*\/RedfishPkg\/Library\/JsonLib\/jansson")
    skip = False
    f = open(inf_name, "rb")
    outf = open(outf_name, "wb")
    for line in f.readlines():
        if ts_chunkstart.match(line) is not None:
            if (ts_redhat.match(line) is not None or
                ts_gitfile.match(line) is not None or
                ts_submodule.match(line) is not None or
                ts_submodule2.match(line) is not None or
                ts_submodule3.match(line) is not None or
                ts_submodule4.match(line) is not None or
                ts_submodule5.match(line) is not None or
                ts_submodule6.match(line) is not None or
                ts_submodule7.match(line) is not None):
                skip = True
            else:
                skip = False
        if skip == False:
            outf.write(line)
    outf.close()
    f.close()

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: %s <input filename> <output filename>" % sys.argv[0])
        exit(1)
    filter_file(sys.argv[1], sys.argv[2])

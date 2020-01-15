# Header files

Some of the Perl modules that FRE uses requires additional libraries to be
installed.  In most cases, the Linux distribution will have the libraries
installed, but the required header files are not.  The system administrators
can install the `*-devel` packages for the libraries listed below.  This is the
easiest and most reliable solution.  If the system administrators are unwilling
to install the devel packages,  there are some work arounds described.

## zlib

XML::LibXML needs zlib header files to build.  In most cases, the Linux system
has zlib already installed.  However, it may not have the header files for zlib
(`zconf.g` and `zlib.h`).  To simplify the install, ask the system administer
to install the zlib-devel package.  If they are unwilling to install this
you can "fake" it by downloading the source for the same version of zlib
installed on the system from http://www.zlib.net/fossils/, extract the tarball
and running the `configure` script.  The two header files will be available.
Set the environment variable `CPATH` to point to the extracted tarball directory
before building.

## expat

XML::Parser

https://sourceforge.net/projects/expat/files/expat

run the `configure` script, then run `make`.  The `expat.h` file will be
available in the libs directory.  Set `CPATH` to point to `<extracted_tar>/libs,`
where `<extracted_tar>` is the directory where the tarball was expanded.


## Installing from package

Linux distributions should have a libxml2 package availabe in their package
repositories.  Use the Linux distribution package manager to install the package.

### RHEL/CentOS

`yum install libxml2 libxml2-devel`.

### Debian/Ubuntu

`apt-get install libxml2 libxml2-devel`

## Installing from source

To install libxml2 download the release tarball from ftp://xmlsoft.org/libxml2

The following steps are the minimum to get libxml2 installed.  In other locations
in the FRE installation document, we will refer to the location of the libxml2
installation as `$LIBXML2_ROOT`.

* `wget ftp://xmlsoft.org/libxml2/libxml2-2.9.4.tar.gz`
* `tar zxf libxml2-2.9.4.tar.gz`
* `cd libxml2-2.9.4`
* `./configure --prefix=$LIBXML2_ROOT`
  * Can add `--without-python` to not build the python bindings for libxml2.
* `make`
* `make install`
  * This will install the library into `$LIBXML2_ROOT`

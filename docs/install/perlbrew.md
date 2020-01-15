# Install Perl

Most of the FRE utilities are written in [Perl](https://www.perl.org/).  The
following list of Perl packages are required for FRE to work.  We suggest using
the system Perl, and having a system administer install these Perl packages
using the OS's package manager.  This will insure the prerequisites for these
packages are also installed.  If that is not possible, then two methods can be
used to install packages in non-root locations: [perlbrew](https://perlbrew.pl)
and [spack](https://spack.io/).  Only one of these methods should be used to
install Perl.

## perlbrew

### What is perlbrew?

[perlbrew](https://perlbrew.pl) is a tool to manage multiple perl instances
in a non-standard location, like `$HOME`.  Using perlbrew to install FRE will
install all the Perl prerequisites non-standard location, and avoid the system
Perl.  See the [perlbrew home page](https://perlbrew.pl) for more information
about perlbrew.

### Perlbrew prerequisites

To install perlbrew, and Perl with perlbrew, the following tools are required:

* wget (on Linux)
  * On RHEL/Centos `yum install wget`
* bzip2
  * On RHEL/Centos `yum install bzip2`
* make/gmake
  * On RHEL/Centos `yum install make`
* A C compiler (We suggest gcc)
  * On RHEL/Centos `yum install gcc`

Full installation steps for perlbrew are available on the perlbrew site.  With
the following instructions you should be able to setup perlbrew and install all
the FRE Perl prerequisites in `$PERLBREW_ROOT`.

* Set `PERLBREW_ROOT` to where you want to install perlbrew
  * For bash: `export PERLBREW_ROOT=/path/to/install/dir`
  * For csh: `setenv PERLBREW_ROOT /path/to/install/dir`
  * If `PERLBREW_ROOT` not set, perlbrew will be installed in
    `$HOME/perl5/perlbrew`
  * If perlbrew is not installed in `$HOME/perl5/perlbrew` then `$PERLBREW_ROOT`
    should be set in your shell init scripts.
* Download and run the perlbrew insall script from `https://install.perlbrew.pl`
  * On linux can run `\wget -O - https://install.perlbrew.pl | bash`
* Source the perlbrew shell initialization script:
  * For bash: `. $PERLBREW_ROOT/etc/bashrc`
  * For csh: `source $PERLBREW_ROOT/etc/cshrc`
* Install perl in perlbrew: `perlbrew install 5.24.1`
  * This will install the current Perl version (as of this writing).
  * This step will take some time to complete.

### Using perlbrew

To use perlbrew, the environment must be setup find the `perlbrew` command.  The
easiest way is to source the file `$PERLBREW_ROOT/etc/bashrc` in the
`$HOME/.bash_profile` file.  Once sourced the path where `perlbrew` command was
installed will be added to the `PATH` environment varible.  If using csh or tcsh,
source `$PERLBREW_ROOT/etc/cshrc` in the `$HOME/.cshrc` file.

Once the rc file has been sourced, run `perlbrew switch perl-5.24.1` to activate
the version of Perl installed in the last section and to set it as the default
Perl.

## Install Perl Modules

FRE uses several Perl packages.  The extra modules used by FRE are available on
CPAN.  Perlbrew has an updated CPAN program `cpanm` that should be used to install
the additional Perl modules.  To install the additional Perl modules run the
command:

```sh
perlbrew exec cpanm <Perl::Module>
```

The following Perl packages need to be installed:

* Date::Manip
* File::NFSLock
* XML::LibXML --- requires [libxml2](http://xmlsoft.org/) to be installed
  * TODO: how to handle custom install of libxml2?
  * If libxml2 is installed via rpm, also need -devel package
  * Need zlib-devel package.  How can this be installed manually?
  * Can only use certain versions of libxml2. 2.7.8 should work.
  * For libxml2 set PATH to bin directory of libxml2 install
  * XML::LibXML needs (using cpan will also install these):
    * XML::NamespaceSupport
    * XML::SAX
    * XML::SAX::Base
* XML::Parser
  * Requires expat headers (expat-devel).  See zlib.md.
  * XML::Parser will also install several other dependencies, including Try::Tiny.
* XML::Dumper

* DBI
* Pod::Usage
* Switch


To install these modules, run the command `cpan install <package>` (e.g.
`cpan install Date::Manip` to install the `Date::Manip` perl module.)

Note, the above modules will also install several dependencies.

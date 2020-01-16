## Prerequisite Software

### Required

The following software and libraries are required

* A Fortran compiler (Suggestions [Intel](https://software.intel.com/en-us/fortran-compilers), [PGI](http://www.pgroup.com), [GNU](https://gcc.gnu.org/fortran/))
* A C/C++ Compiler (Suggestions [Intel](https://software.intel.com/en-us/c-compilers), [PGI](http://www.pgroup.com), [GNU](gcc.gnu.org))
* [Perl 5](https://www.perl.org) (At least v5.10.1)
* Environment Modules (with Tcl)
  * [Environment Modules](http://modules.sourceforge.net/)
  * [Lmod](https://www.tacc.utexas.edu/research-development/tacc-projects/lmod)
* [libxml2](http://xmlsoft.org)
* [libxslt](http://xmlsoft.org/libxslt/)
* [eXpat XML Parser](http://expat.sourceforge.net)
* [netCDF 4 library](http://www.unidata.ucar.edu/software/netcdf) (C and Fortran bindings)
* [HDF5](https://www.hdfgroup.org) (Needed for netCDF)
* [nccmp](http://nccmp.sourceforge.net/)
* [git](https://git-scm.com)

The following Perl packages are required.  All are available on
[CPAN](http://search.cpan.org).  The latest version of each should
work.

* [File::NFSLock](http://search.cpan.org/~bbb/File-NFSLock-1.27/lib/File/NFSLock.pm)
* [XML::Parser](http://search.cpan.org/~toddr/XML-Parser-2.44/Parser.pm)
* [XML::Dumper](http://search.cpan.org/~mikewong/XML-Dumper-0.81/Dumper.pm)
* [XML::NamespaceSupport](http://search.cpan.org/~perigrin/XML-NamespaceSupport-1.11/lib/XML/NamespaceSupport.pm)
* [XML::SAX](http://search.cpan.org/~grantm/XML-SAX-0.99/SAX.pm)
* [XML::LibXML](http://search.cpan.org/~shlomif/XML-LibXML-2.0128/LibXML.pod)

### Optional

The following packages are optional.

* MPI library and headers (Some suggestions)
  * The system MPI
  * [OpenMPI](http://www.open-mpi.org/)
  * [mpich](https://www.mpich.org/)
* [GNU make]([CVS](http://www.nongnu.org/cvs/)
* [CVS](http://www.nongnu.org/cvs/)

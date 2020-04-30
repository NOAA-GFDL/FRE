# Bronx-17 Release Notes

Bronx-17 was released on April 30, 2020 as an interim update, while Bronx-18 will contain the more typical assortment of updates and bug fixes. Bronx-17’s updates are limited to mkmf and make templates, intended to support recent Intel compilers (18, 19, 20).

## Make template updates
* Use Intel ISA `-xsse2` instead of `-msse2`. `-xsse2` is slightly more restrictive than `-msse2` and is needed to preserve run-to-run (e.g. processor layout, core count) reproducibility for newer Intel compilers (18+). No reproducibility issues with this update have been observed during MSD testing. Additionally, testing has shown that:
  * generally, `-xsse2` preserves similar behavior compared to Intel 16 `-msse2`
  * Intel 16 produces the same answers using `-xsse2` or `-msse2` (prod/openmp)
  * Intel 16, 17, and 18 reproduce using `-xsse2` (prod/openmp)
  * Intel 16 and 17 reproduce using `-xsse2` and `-msse2` (prod/openmp)
  * Intel 19 and 20 reproduce using `-xsse2` (prod/openmp)
  * Intel 19 reproduces Intel 16 using `-xsse2` (using debug compilations)

  **No user action needed. Please report any reproducibility issues to your FMS liaison.**
* Added preprocessor macro `-DHAVE_SCHED_GETAFFINITY`, which is needed for shared FMS code release 2020.01 or later.

  **No user action needed. Feel free to remove this macro from your XML if defined.**
* Added preprocessor macro `-Duse_netCDF`

  **No user action needed. Feel free to remove this macro from your XML if defined.**

## fremake updates
* Removed `--git`/`-g` option from the `mkmf` call, which had added a macro definition `-D_FILE_VERSION` to the CPPDEFs. Differences in quoting behavior among MPI wrappers was the motivation to remove this feature.

  **No user action needed. However, if you have the `-D_FILE_VERSION` macro set within the `<makeOverrides>` tag in your XML, please remove it, especially if using Intel MPI.**

## Update to freconvert.py (XML conversion tool) to update XMLs to Bronx-17
There were no XML changes since Bronx-15, so if updating from a Bronx-15/16 XML, simply update the `<platform>/<freVersion>` tag.

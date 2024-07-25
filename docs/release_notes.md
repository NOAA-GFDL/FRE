# Bronx-22 Release Notes

Bronx-22 was released on March 25, 2024 to support user management of gaea F5 scratch space by placing previously swept FRE gaea directories in a `volatile` subdirectory. F5 has no sweeper, and using the updated directory defaults will let you more easily distinguish the previously-swept and previously-unswept FRE-generated gaea output. Bronx-22 is exactly Bronx-21 but with these updated directory defaults, and FRE users can use either.

**Reminders**
* Both Bronx-21/22 remove the work directory on normal exit (i.e. no crash or error; to not do this, use `frerun --no-free`)
* Interactive `ardiff` users must set `$TMPDIR` to your F5 scratch space when running on the gaea login hosts (otherwise, `/tmp` will be used which cannot handle such large usage)

## Updated ncrc5 FRE default directories
* Files previously in scrubbed locations are now in a `volatile` subdirectory in your F5 scratch:
  * stdoutDir: `/gpfs/f5/$(project)/scratch/$USER/volatile/$(stem)/$(name)/stdout`
  * archiveDir: `/gpfs/f5/$(project)/scratch/$USER/volatile/$(stem)/$(name)/$(platform)-$(target)`
  * workDir: `/gpfs/f5/$(project)/scratch/$USER/volatile/$(stem)/$(name)/work/$FRE_JOBID`
  * ptmpDir: `/gpfs/f5/$(project)/scratch/$USER/volatile/$(stem)/$(name)/ptmp`
* Unchanged from Bronx-21:
  * rootDir: `/gpfs/f5/$(project)/scratch/$USER/$(stem)`
  * srcDir: `$(rootDir)/$(name)/src`
  * execDir: `$(rootDir)/$(name)/$(platform)-$(target)/exec`
  * scriptsDir: `$(rootDir)/$(name)/$(platform)-$(target)/scripts`

**Recommendations**
* Use Bronx-22 for new experiments, and continue to use Bronx-21 for existing experiments. (Bronx-21 and 22 will remain equal except for the directory default change.)
* Occasionally clean out your `volatile` subdirectory for experiments you no longer need,
or set up a personal F5 sweeper following the example below.
* Reminder: F5 is not backed up. Consider keeping your `src` FRE directory on $HOME if you are developing.

## Example of a scrontab/find-based personal F5 file sweeper

1. **Form a find command.** Determine how you would like to target your `volatile` FRE-generated output that normally would have been transferred to GFDL and in the (F2) past would eventually be removed by the (F2) sweeper.

"Remove files not accessed in 90 days" might be reasonable. To do that,

`find /gpfs/f5/<project>/scratch/<user>/volatile -atime +90`

replacing `<project>` and `<user>` with your project and user name.
That `find` command will print the files. To delete and print the files, add `-delete -print`:

`find /gpfs/f5/<project>/scratch/<user>/volatile -atime +90 -delete -print`

Note that this will leave empty directories.

You can try these find commands out interactively (please be careful!). To use other find-based approaches, refer to the manual (`man find`).

2. **Create a scrontab entry.** Determine how often you would like to run your `find` command.

One a day might be reasonable. To help avoid collective F5 stress at each midnight, please use "once daily at HH", where HH is `<userid> mod 24`. You can determine that by running this at your gaea login shell:

```
echo `id -u`%24 | bc
```

An scrontab entry for once a day at HH (replace `<HH>` below with what you get by typing the above, and replace `<project`> and `<user>` with your project and user names) would be:

`00 <HH> * * * * find /gpfs/f5/<project>/scratch/<user>/volatile -atime +90`

(Again, replace `<HH>`, `<project>`, and `<user>` before using that example.) See the scrontab manual for more (`man scrontab`).

3. **Add the scrontab entry.** Add your find command do your scrontab with `scrontab -e` on the C5 DTNs (the jobs *must* be run on the DTNs, i.e. `--partition=ldtn_c5`, in order to protect F5 I/O on the compute and login nodes). When you do that, if you haven't created a scrontab before, you will see a commented template example. You can replace that with:

```
#SCRON --partition=ldtn_c5
#SCRON --job-name=my-sweeper
#SCRON --output=my-sweeper/log.%j
# Once daily, list volatile FRE-generated files not accessed in last 90 days
00 <HH> * * * * find /gpfs/f5/<project>/scratch/<user>/volatile -atime +90 && date
```

(Again, replace `<HH>`, `<project>`, and `<user>` before using that example.) Notes / explanation:
* Output from the `find` and `date` commands are appended to `$HOME/my-sweeper/log.<JOBID>` each time the scrontab job runs.
* Once installed or modified, a new `<JOBID>` is created for the recurring job, and the `<JOBID>` then remains the same each time it is run.
* The `&& date` after the find command is optional, but useful to show something in the log (as otherwise if the `find` command finds no files, nothing is written to the log).
* Refer to the [scrontab gaeadocs](https://gaeadocs.rdhpcs.noaa.gov/wiki/index.php?title=Cron) for more.

When you are satisfied with the file list targeted for deletion, you can add `-delete -print` to your find command:

```
#SCRON --partition=ldtn_c5
#SCRON --job-name=my-sweeper
#SCRON --output=my-sweeper/log.%j
# Once daily, remove volatile FRE-generated files not accessed in last 90 days
00 <HH> * * * * find /gpfs/f5/<project>/scratch/<user>/volatile -atime +90 -delete -print && date
```

4. **Monitoring your find sweeper.**

`squeue -u $USER` and `scontrol show <JOBID>` show the job if it is running or the next date it is scheduled to run.

The `$HOME/my-sweeper/log.<JOBID>` file will contain the `find` and `date` output.

5. **Changing your find sweeper.**

Use `scrontab -e` to edit or remove/comment out the job.

##

## Updated HSM 1.2.9
* Bug fix for unique hsmput pathology recently discovered, related to repeated hsmputs, hsmget with globbing, and a ptmp cache that is not up-to-date. (See https://gitlab.gfdl.noaa.gov/fre/hsm/-/issues/40)

## Patch release notes
* 2024-07-25 (patch 1): Three bug fixes and two adjustments
  * Output stager fix to check exit status of NCO calls and exit if NetCDF file cannot be read. (Previously, the NCO error was incorrectly interpreted as subregional history files that cannot be combined.)
  * Output stager fix to remove temporary file if combiner fails. (Previously, if combine-ncc failed, its output file was left in the working directory which caused required manual removal in order to retry.)
  * frepp fix to not modify input PTMP history files. (Previously, frepp modified a NetCDF attribute before running fregrid. When using /xtmp for PTMP, sometimes the attribute would be modified twice resulting in a fregrid error.)
  * New ardiff options -d, -m, and -C to check only data, only metadata, and stop early.
  * Output stager to stop unnecessary checking for distributed subregional variable differences in restart files

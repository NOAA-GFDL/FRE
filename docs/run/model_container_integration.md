# Connecting FRE Bronx and FRE 2025.01
This project allows for the integration between Bronx and FRE 2025.01 workflows. Using `fre make` tools in FRE 2025, one can create either a bare-metal executable or a model container that will compile the model. If a container is built, the path to this newly created container can then be included in a group's experiment XML. In the FRE ecosystem, team's can run the model container in the `frerun` command by passing the `--container` option.

### Container assumptions:
- Container assumes set location of runscript INSIDE     
    - `/apps/bin/execrunscript.sh`    
- Need to provide container path in experiment XML
- Container platform to use with `fre make` tools: `hpcme.2023`
- Container utilizes spack stack to find packages within container
- Container uses intel compiler
- Certain paths are mounted to bind in the MPI on the system; these paths may change due to OS releases or updates

## Guide to integrate model container in FRERUN:
1) Create a model container on gaea C5: Follow the fre make steps in order to create a model container:     
    - [Fre make guide](https://noaa-gfdl.github.io/fre-cli/usage.html#guide)    
    - *Required configuration files*: model yaml, compile yaml, and platform yaml     
    - Example yaml configurations files live in the [fre-examples](https://github.com/NOAA-GFDL/fre-examples) repo  
    - One can either (*recommended: create own conda environment at the moment*)        
        - run `module load fre/2025.01` to get access to fre make tools        
        - [create own conda environment](https://github.com/NOAA-GFDL/fre-cli/tree/main?tab=readme-ov-file#method-3-developer---conda-environment-building) and install the fre-cli to acces fre make tools

The container build goes through 3 steps in `fre make` tools:

1. `podman build [options]` : builds the container image
2. `podman save [options]` : saves the image to a local `.tar` file 
3. `apptainer build [options]` : builds a `.sif` (singularity image format) file from the `.tar` file
 
The end result created container will be the `.sif` file and will be generated in your current working directory.

2) Once the container in created, it must be located somewhere that can be accessed by the Bronx tools

    - Potential location: `/gpfs/f5/gfdl_f/world-shared`

3) Include the path to the container in experiment XML
    
    - The experiment XML now has to point to the newly created container. Include `container file` with the path to the container under the experiment name.
    - Example:     
        ```     
        <experiment name="[experiment name]" inherit="[model version]_compile" xmlns:xi="http://www.w3.org/2003/XInclude">
          <container file="path/to/container/"/>      
        ```

4) Run the model container with Bronx:
```
# Load FRE
module load fre/bronx-23

# Running frerun
frerun -x [model XML] -p [platform] -t [target] [experiment name] --container
```
There will be a note that the container will be used for compilation as well.

# LumericalTools

- [Description](#description)
- [Install](#install)
- [Lumerical script usage](#lumerical-script-usage)
  - [Constructing a simulation](#constructing-a-simulation)
    - [**Set required variables**](#set-required-variables)
    - [**Set optional variables**](#set-optional-variables)
  - [Analyzing a simulation](#analyzing-a-simulation)
- [Remote-host execution](#remote-host-execution)
  - [Lumerical dispatch](#lumerical-dispatch)
  - [Remote-host queueing and execution](#remote-host-queueing-and-execution)
- [MATLAB script usage](#matlab-script-usage)
  - [Generating Lumerical scripts with MATLAB](#generating-lumerical-scripts-with-matlab)
  - [Analysis of Lumerical sweeps](#analysis-of-lumerical-sweeps)
- [MATLAB templating system for Lumerical script construction and analysis](#matlab-templating-system-for-lumerical-script-construction-and-analysis)


## Description

This repository consists of a set of:

- [Lumerical scripts](https://www.lumerical.com) for rapid geometry and simulation definition.
- Bash scripts for remote-host execution on a dedicated server running Linux.
- MATLAB scripts for parametrically sweeping and analyzing Lumerical structures.

These three components can be used separately or in combination, and are not interdependent for most functionality.

> Note: this library is fully functional, but the documentation has not been thoroughly checked and may be missing a few options.


## Install

- Clone this repository.
- Lumerical
  - Either add the `common` folder to your Lumerical path, or prepend all files using it with `addpath('/path/to/common');`.
  - Update the first line of all files in the `common` folder that contain `addpath('/home/nickersonm/lumerical/common');` to the correct path, if different from `/home/nickersonm/lumerical/common` and you have not added it to your Lumerical path.
  - Sample Lumerical scripts are in [`common/templates/`](./common/templates/).
- Remote-host execution
  - Copy [`remote-dedicated`](./remote-dedicated/) to the selected Linux remote host and mark as executable.
  - Dependencies
    - `PuTTY` is used in the provided batch files for Windows client Lumerical dispatch, but can be easily customized.
    - `xvnc` is required if using remote-side script execution; a common and standalone variant is [TigerVNC](https://tigervnc.org).
    - [`pueue`](https://github.com/Nukesor/pueue) is required if using remote-side queuing instead of local Lumerical queue management, and requires `pueue` groups `"cad"`, `"engine"`, and `"fdtd-engine"` with execution limits as desired.
  - Verify the remote host has Lumerical installed and correctly licensed.
- MATLAB
  - Add the `MATLAB` folder to your MATLAB path.
  - Dependencies
    - [`appendstruct`](https://github.com/nickersonm/MATLAB-utilities/blob/master/appendstruct.m), [`figureSize`](https://github.com/nickersonm/MATLAB-utilities/blob/master/figureSize.m), [`figureTitle`](https://github.com/nickersonm/MATLAB-utilities/blob/master/figureTitle.m), [`smoothGrid`](https://github.com/nickersonm/MATLAB-utilities/blob/master/smoothGrid.m), and [`titlewrap`](https://github.com/nickersonm/MATLAB-utilities/blob/master/titlewrap.m) functions from my [MATLAB-utilities](https://github.com/nickersonm/MATLAB-utilities) repository.
    - 3rd party [`smoothn`](https://www.mathworks.com/matlabcentral/fileexchange/25634-smoothn) and [`subplot_tight`](https://www.mathworks.com/matlabcentral/fileexchange/30884-controllable-tight-subplot) functions.
  - Sample data collection routines are present in the [`./routines/`](./routines/) folder.


## Lumerical script usage

The set of Lumerical scripts in `common/` interacts with eachother to build epitaxy, etch geometry, and simulation entities given a brief description. With `etchDef` and `epitaxy` variables provided, `lum_setup` can then be called and the appropriate geometry and simulation will be created. The minimum required variables are:

- `etchDef`:      cell list of etches, each element being a structure with fields:
  - `.depth`      etch depth from top of epitaxy
  - `.width`      width of the etch region, unused if .start is specified
  - `.length`     length of the etch region, unused if .end is specified
- `epitaxy`:    cell list of epitaxial layers, top-down, each element being a structure with fields:
  - `.material`   epitaxial material; currently supported: any built-in, 'AlGaAs', 'SiO2', 'SiN' , 'InGaP', 'InGaAs', 'GaAsP', 'LiNbO3_x', 'LiNbO3_z', 'AlOx', 'Au', 'Si'
  - `.thickness`  layer thickness

Details can be found below or in the script and [template](./common/templates/) headers. Of special note is that the `epitaxy` can include quantum well or MQW definitions with thicknesses specified by `.qw` instead of `.thickness`, and the MQW gain results will be calculated and substituted into a material covering the MQW region.

Some minimal examples are:

A **varFDTD simulation of a Si waveguide surrounded by SiN**:

```lumerical
addpath('/home/nickersonm/lumerical/common');   # Replace as necessary, optionally adding multiple potential locations for different environments

# Define 220 nm SOI epitaxy
#   'guiding' hints to center simulation on that layer
epitaxy = {
    {'material': 'Si', 'thickness': 0.220, 'guiding': 1},
    {'material': 'SiO2', 'thickness': 2}
};

# Define waveguide with s-curve
#   This is an etch definition, 'wgspace' automatically treats it as a waveguide definition and generates left and right etches
etchDef = {
    {'depth': 0.5, 'wgspace': 10, 'start': [0, -2, 1], 'end': [20, 2, 1]}
};

# Background and etch material is SiO2
etchMat = 'SiO2';

# Change wavelength to 1300 nm, default 1030 nm is below Si bandgap
lambda = 1.3;

# Restrict to top instead of full epitaxy
simZ = [-1, 0.2]; 

# Reduce simulation Y-extent; default is full etch extents
simY = 8;

# Build simulation
lum_setup;
```

A **MODE simulation of GaAs deep ridge waveguide**:

```lumerical
addpath('/home/nickersonm/lumerical/common');   # Replace as necessary, optionally adding multiple potential locations for different environments

# Define basic AlGaAs/GaAs epitaxy
epitaxy = {
    {'material': 'AlGaAs', 'x':0.3, 'thickness': 1},
    {'material': 'GaAs', 'thickness': 1, 'guiding': 1},
    {'material': 'AlGaAs', 'x': 0.2, 'thickness': 2},
    {'material': 'GaAs', 'thickness': 10, 'name': 'Substrate'}
};

# Define simple ridge waveguide
#   This is an etch definition, 'wgspace' automatically treats it as a waveguide definition and generates left and right etches
etchDef = {
    {'depth': 3, 'wgspace': 10, 'width': 2, 'length': 10}
};

# Run as YZ MODE simulation
sim2D = 1;

# Restrict to guiding layer ±1 µm instead of full epitaxy
simZ = 1; 

# Reduce simulation Y-extent; default is full etch extents
simY = 4;

# Build simulation
lum_setup;
```

Execute the script files in the appropriate Lumerical environment - in the case of these examples, Lumerical MODE.

After constructing the simulation and geometry, and optionally executing it, the `lum_analyze` script can be run to characterize a number of metrics and export the results to a MATLAB file. If the simulation does not yet have results calculated, it will be run before export. Details can be found below and in the `lum_analyze` script header, but a minimal nontrivial example is:

```lumerical
addpath('/home/nickersonm/lumerical/common');   # Replace as necessary, optionally adding multiple potential locations for different environments

# Compare MODE results to a 2 µm MFD gaussian, e.g. for coupling overlap
outField = {'pol': 0, 'mfd': 2};

# Save results to MATLAB file
matFile = 'mode_test.mat';

# Run analysis
lum_analyze;

# Look at overlap with output field, reported as [mode#, overlap, loss]
?[results.modeN, results.Pout, results.modeL];
```

**Further examples can be found in the [`common/templates/`](./common/templates/) folder.**



### Constructing a simulation

<details>

**<summary>Detailed Lumerical script usage</summary>**

> Units: µm lengths, cm^-1 loss, 1e18 cm^-3 doping

Run `lum_setup;` after setting desired variables.

#### **Set required variables**

- `etchDef`:      cell list of etches, each element being a structure with fields:
  - `.depth`      etch depth from top of epitaxy
  - `.width`      width of the etch region, unused if `.start` is specified
  - `.length`     length of the etch region, unused if `.end` is specified
  - Optional etchDef fields:
    - `.layer`      calculates etch depth from '`epitaxy`' matrix (counting from top); overrides `.depth` if specified
      - Requires '`epitaxy`' cell list of epitaxial layers
    - `.wgspace`    generates appropriate etches for a waveguide with the specified `.width`, using this field as an exclusion zone (etch width on each side)
    - `.start`      `[x0,y0,w0]` start location and width, default `prev.end` or `[0,0,width]`
    - `.end`        `[x1,y1,w1]` end location and width, default `start+[length,0,0]`
    - `.name`       name for the etch object, default '`etch#`'
    - `.res`        minimum transverse resolution for this region; will generate `simRes` matrix, can be `[res,yMin,yMax,xMin,xMax]`
    - `.cells`      number of EME cells for this waveguide; will generate `simCellLen` and `simCellN` matrix; default `1`
    - `.bend`       [EME and MODE] bend radius for this waveguide; will generate `simBend`
    - `.sbend`      [EME only] maximum bend radius for an s-bend; will generate appropriate structure for an s-bend with .cells distinct segments
    - `.poly`       `[[x], [y]]` polygon fully defining extents of etch; overrides all other xy size specifications
    - `.thickness`  specify thickness [µm]; appends to '`epitaxy`' cell list as `.material='Au', .meshorder=1` with given `.thickness`, `.z`, `.poly`
    - `.material`   specify material other than '`etch`', optionally combine with '`.thickness`'
    - `.angle`      specify etch angle; will shift top and bottom polygon points
- `epitaxy`:    cell list of epitaxial layers, top-down, each element being a structure with fields:
  - `.material`   epitaxial material; currently supported: any built-in, `'AlGaAs'`, `'SiO2'`, `'SiN'` , `'InGaP'`, `'InGaAs'`, `'GaAsP'`, `'LiNbO3_x'`, `'LiNbO3_z'`, `'AlOx'`, `'Au'`, `'Si'`
  - `.thickness`  layer thickness
  - Optional epitaxy fields:
    - `.x`          composition of first element; default 0, currently supported: `'AlGaAs'`, `'InGaAs'`, `'GaAsP'`
    - `.doping`     dopant concentration [e18 cm^-3]; negative for n-doped, positive for p-doped
    - `.name`       override default layer name
    - `.qw`         quantum well thickness, overrides '`thickness`', adjacent '`qw`' materials simulated and added as single material
    - `.guiding`    use as assumed guiding region; default determined by lowest loss
    - `.color`      optional material color as `[R, G, B, A]`
    - `.meshorder`  specify mesh order; `'etch'` is 1
    - `.z`          specify z-location of bottom of layer; removes cell from layer calculations, e.g. for metal pads
    - `.poly`       xy polygon defining layer, e.g. for metal pads; if not used with '`.z`', gaps will be present in epitaxy
    - `.xmax`       maximum x extent
    - `.xmin`       minimum x extent
- **CHARGE only:**
  - `contacts`:   cell list of electrical contacts, each element being a structure with fields:
    - `.name`       existing geometry name or new geometry (requires `.dz` and `.poly` below)
    - `.V`          array of potentials to apply (optionally scalar)
    - Optional contacts fields:
      - `.poly`       xy polygon defining new geometry
      - `.dz`         z-extents of new geometry
      - `.material`   supported material for new geometry; default `'Au'`
      - `.meshorder`  specify mesh order; default `1`

#### **Set optional variables**

- `regrowth`:   structure with regrowth definition with fields:
  - `.xmin`       minimum x extent of regrowth etch, modifies '`epitaxy`'
  - `.xmax`       maximum x extent of regrowth etch, modifies '`epitaxy`'; ignored if xmin set
  - `.depth`      etch depth to remove original epitaxy to; either depth or layer required
  - `.layer`      auto-compute etch depth from given epitaxy layer (etch-to, not etch-through)
  - `.epitaxy`    cell list of regrowth epitaxial layers, same as standard epitaxy
- `sim2D`:      `0` for full 3D EME, FDTD, or CHARGE, `1` for YZ FDE or CHARGE, `2` for XY varFDTD, FDTD, or CHARGE; default `2`
- `etchMat`:    material for etches, default `'etch'`
- `simX`:       `[min, max]` longitudinal simulation span, default epitaxy extents
- `simY`:       `[min, max]` transverse simulation span, default epitaxy extents less PML
- `simZ`:       `[min, max]` vertical simulation span, default epitaxy extent plus buffer
- `simZlayer`:  calculate minimum Z extent as this epitaxial layer, overrides simZ
- `simBuffer`:  buffers for ports, monitors, etc; default `1` [µm]
- `simAccuracy`:auto-mesh accuracy setting, where applicable; default `4`
- `simRes`:     mesh size in normal regions [µm], can be matrix of `[res,yMin,yMax,[xMin,xMax]]`; default `0.25`
- `simResSub`:  mesh size in substrate region [µm], default `0.25`
- `simResFine`: maximum mesh size in guiding region [µm], default `0.05`
- `simMon`:     output port/monitor, cell of structures
  - `.type`   Optical: `'port'`, `'E'`, `'n'`, `'mov'`, `'time'`; CHARGE: `'Q'`, `'E'`, `'BS'`, `'I'`
  - Optional fields:
    - `.geo`    `'x'`, `'z'`, `'y'`, `'point'`, `'xy'`, `'yz'`, or `'xz'`; optical default `'yz'`, CHARGE default `'z'`
    - `.x`      x location or span; default `simX` or `max(simX)`, can specify `'in'` or `'out'`
    - `.y`      y location or span; default `simY` or `mean(simX)`
    - `.z`      z location or span; default `simZ` or `mean(simZ)`
    - `.name`   name of monitor; default `'mon_<#>_<type>'`
  - Optional fields for '`port`' only:
    - `.pol`    E-field polarization, where applicable, `0` for TE (+y), `1` for TM (+z); default `0`
    - `.rot`    input rotation around z axis [degrees]; default `0`
    - `.amp`    modify relative amplitude; default `1`
    - `.phase`  phase offset for this port
    - `.mfd`    use gaussian source with this MFD [µm], <0 for plane wave; if 3-vector, use `[MFD, y, z]` for recentering
    - Custom Field (where applicable):
      - `.y`      y spatial vector, also sets location
      - `.z`      z spatial vector, also sets location
      - `.power`  spatial matrix defining modal power
      - `.field`  3- or 6-dimensional matrix defining `[Ex, Ey, Ez, (Hx, Hy, Hz)]` fields, overrides `.power` and `.pol`
  - *Default `simMon`*, always included:
        - CHARGE: `{ {'type': 'Q', 'loc': [0,0,0]}, {'type': 'E', 'loc': [0,0,0]}, {'type': 'BS', 'loc': [0,0,0]} }`
        - Optical: Index and Field for xy plane, input, and output, name `<location><type>`
- `monYZ`:     global default `[simMon.y, simMon.z]`; default `[simY, simZ]`
- **For all optical solvers**
  - `lambda`:     wavelength [µm] (partially implemented); default `1.03`
  - `simPol`:     polarization of simulation for 2D simulations; `0` for TE (+y), `1` for TM (+z), default `0`
  - `simPML`:     number of mesh periods for PML border, where applicable; default `8`
  - `inPort`:     input port settings, cell of structures as with '`simMon`', type `'port'` only
    - Optional fields:
      - `.x`      x location; default `min(simX)`
      - `.y`      y location or span; default `simY` or `mean(simX)`
      - `.z`      z location or span; default `simZ` or `mean(simZ)`
      - `.name`   name of monitor; default `'port_<#>'`
      - `.pol`    E-field polarization, where applicable, `0` for TE (+y), `1` for TM (+z); default `0`
      - `.rot`    input rotation around z axis [degrees]; default `0`
      - `.amp`    modify relative amplitude; default `1`
      - `.phase`  phase offset for this port
      - `.mfd`    use gaussian source with this MFD [µm], <0 for plane wave; if 3-vector, use `[MFD, y, z]` for recentering
      - Custom Field (where applicable):
        - `.y`      y spatial vector, also sets location
        - `.z`      z spatial vector, also sets location
        - `.power`  spatial matrix defining modal power
        - `.field`  3- or 6-dimensional matrix defining `[Ex, Ey, Ez, (Hx, Hy, Hz)]` fields, overrides `.power` and `.pol`
    - *Default `inPort`*: `{{'pol': '0'}}`
- **For EME and FDE only**
  - `simModes`:   number of modes to search; linearly impacts memory, default `250`
  - `simModeN`:   search near this index, if provided positive number; default `-1` ('near max n')
  - `simBend`:    enable bend radius for given segments, `[xMin, xMax, radius]`

</details>


### Analyzing a simulation

<details>

**<summary>Detailed Lumerical script usage</summary>**

> Units: µm lengths, cm^-1 loss, 1e18 cm^-3 doping

Run `lum_analyze;` after setting desired variables.

- **Required:**
  - none
- **Optional:**
  - `resultFile`: filename to save analysis to
  - `resultVars`: matrix or string to save to the same line before standard outputs
  - `matFile`:    filename to export data to
  - `dataRes`:    Cartesian resolution to interpolate data [µm], default `0.05`
  - `outField`:    output field to compare to; structure with fields:
    - `.y`      y spatial vector, also sets location
    - `.z`      z spatial vector, also sets location
    - `.pol`    polarization; `0` for TE (+y), `1` for TM (+z), default `0`; will rotate `.field` if nonzero
    - `.rot`    rotation around z axis [degrees]; default `0`
    - One of:
      - `.mfd`    generate gaussian source with this MFD [µm], <0 for plane wave, optionally `[mfd, dy, dz]`
      - `.power`  spatial matrix defining modal power
      - `.E`      3-dimensional matrix defining [Ex, Ey, Ez] fields
  - **EME and FDE only**
    - `maxModes`    maximum number of modes to save; default all computed modes
    - `emeGroupSpan`    set EME group spans before running
- **Output products, where applicable:**
  - `results`     structure with summarized results as:
    - `portNames`   cell list of port names referred to by numbers
    - `S##`         S parameters between all ports, using inputField and outputField where possible
    - `P##`         power overlap between all ports, using inputField and outputField where possible
    - `O##`         complex power overlap between all ports
    - `Ptr`         total power transmission fraction
    - `Pout`        power overlap of output field and outField, if specified; modal vector for FDE
    - `modeN`       [FDE only] vector mapping position in list to mode number
    - `modeL`       [FDE only] vector of modal loss
    - `modeNeff`    [FDE only] vector of modal effective index
    - `modePol`     [FDE only] polarization of mode, TE = `0`
  - `simData`    structure of monitors and ports (and solver for CHARGE) as structures with fields:
    - `.name`       name of port/monitor
    - `.x`,`.y`,`.z`    Cartesian geometry vectors for interpolated data
    - `.<data>`     full return of `<data>` (varies by monitor) in Cartesian format
    - `.<data>_raw`  raw fem data, if present
    - `.vtx`        fem vertices, if present
    - `.elem`       fem element/connectivity definition, if present
    - `.ID`         fem element ID, if present
    - `.loss`       [FDE only] propagation loss of mode
    - `.pol`        [FDE only] polarization of mode, TE = `0`
    - `.neff`       [FDE only] effective index
    - `.ng`         [FDE only] group index
    - `.overlap`    [FDE only] overlap with outField, if specified

</details>


## Remote-host execution

> Note: [`remote-slurm`](./remote-slurm/) is not in a cohesive state and is not currently documented here. It should be functional with some customization to your environment, and is provided as a template. Comments describing the purpose and usage are provided in the assorted scripts.

The [`remote-dedicated`](./remote-dedicated/) set of scripts simplifies the execution of Lumerical simulations on remote hosts. This can work via:

- Simple dispatch from a local Lumerical instance executing work files. Batch files for Windows are provided.
- Remote queueing and execution of script definitions tied in to the [`common/` Lumerical scripts](#lumerical-script-usage).
  - This can be combined with the MATLAB scripts for easy parameter search execution and analysis.

The scripts should all be copied to `~/lumerical/` on the remote host, or the path can be altered in the headers of each script.

> Note: [`lumerical_setup.sh`](./remote-dedicated/lumerical_setup.sh) is not used during execution, but provides an optional brief guide to installing Lumerical and `pueue` on a Debian host.


### Lumerical dispatch

The `run_<solver>.sh` set of bash scripts will execute simulation files for the appropriate solver. Verify that the paths for the `CAD` and `ENG` variables are correct. To use, copy a simulation file to the remote host and run, e.g.:

```sh
./run_fde.sh test.lms
```

A set of `dispatch-<solver>.cmd` files are also provided to automate the dispatch, execution, and retrieval from Lumerical clients on Windows. Before use, modify them to use the appropriate `PuTTY` session in the `login` variable, or otherwise change the SSH command. A few-line shell script can provide equivalent functionality on Linux clients.

To dispatch jobs directly to the remote host from a Lumerical instance running, add a a new remote 'Resource' with the 'Custom' job preset. Select 'bypass mpi on localhost' and 'no default options', entering in the appropriate `dispatch-<solver>.cmd` file. Press 'Run tests' to verify functionality.

The Lumerical client will now treat the remote host as a valid solver, and queue jobs on it when executing a local batch.


### Remote-host queueing and execution

For further flexibility including automated simulation file generation from scripts in the [`common/` Lumerical scripts](#lumerical-script-usage), `Q_parallel.sh` and `Q_selected.sh` can be used to submit entire directories of script files for generation, execution, and analysis at once. These use the [`pueue`](https://github.com/Nukesor/pueue) daemon with `pueue` groups `"cad"`, `"engine"`, and `"fdtd-engine"` - set group execution limits as desired. `pueue_remaining.sh` is provided for easily monitoring queue progress.

This integrates nicely with the [MATLAB scripts](#matlab-script-usage) for executing large sweeps at once, or overnight, on a dedicated solver machine.

Verify that the paths for the `CAD` and `ENG` variables are correct in the `run_<solver>.sh` scripts, that `pueue` is installed successfully with the groups `"cad"`, `"engine"`, and `"fdtd-engine"`, that `xvnc` is a valid command, and that Lumerical is installed and properly licensed. Copy the `common/` scripts to the remote host's `/home/nickersonm/lumerical/common` directory.

With one or more `.lsf` Lumerical scripts on the remote machine, the scripts can then be used simply:

```sh
# Run one FDE simulation defined with a script
~/lumerical/Q_selected.sh fde ~/lumerical/tmp/test.lsf

# Build the simulation file, but don't execute or prepare analysis files
BUILDONLY=1 ~/lumerical/Q_selected.sh fde ~/lumerical/tmp/test.lsf

# Build the simulation file, don't execute, but prepare analysis files
PREBUILD=1 ~/lumerical/Q_selected.sh fde ~/lumerical/tmp/test.lsf

# Manually execute the one simulation file
~/lumerical/run_fde.sh ~/lumerical/tmp/test.lms

# Analyze previously prepared and executed script
POSTBUILD=1 ~/lumerical/Q_selected.sh fde ~/lumerical/tmp/test.lsf

# Run a bunch of scripts forming a sweep of a parameter
~/lumerical/Q_parallel.sh fde ~/lumerical/tmp/sweeps/test_*.lsf

# Also run a CHARGE analysis of the same scripts
#   Temporary *_working_<solver>.lsf Lumerical scripts will have been created by the previous command, so don't queue those
~/lumerical/Q_parallel.sh charge ~/lumerical/tmp/sweeps/test_(^*_fde).lsf

# Watch remaining task count
~/lumerical/pueue_remaining.sh
```



## MATLAB script usage

> Dependencies are [`appendstruct`](https://github.com/nickersonm/MATLAB-utilities/blob/master/appendstruct.m), [`figureSize`](https://github.com/nickersonm/MATLAB-utilities/blob/master/figureSize.m), [`figureTitle`](https://github.com/nickersonm/MATLAB-utilities/blob/master/figureTitle.m), [`smoothGrid`](https://github.com/nickersonm/MATLAB-utilities/blob/master/smoothGrid.m), and [`titlewrap`](https://github.com/nickersonm/MATLAB-utilities/blob/master/titlewrap.m) functions from my [MATLAB-utilities](https://github.com/nickersonm/MATLAB-utilities) repository and the 3rd party [`smoothn`](https://www.mathworks.com/matlabcentral/fileexchange/25634-smoothn) and [`subplot_tight`](https://www.mathworks.com/matlabcentral/fileexchange/30884-controllable-tight-subplot) functions.

The set of MATLAB functions and scripts in [`MATLAB/`](./MATLAB/) provide both a script-construction template for parameter searches and various utilities for analyzing results:

- General photonics utility functions
  - `fieldModeArea`: effective modal area of a given field
  - `fieldMsq`: M^2 calculations for x-normal fields, computed by the method in <https://doi.org/10.1109/JLT.2005.863337>
  - `fieldOverlap`: complex overlap between two fields
  - `analyticalModelGaAs`: GaAs phase modulation and optical absorption model given an optical and electrical field. Assumes pure GaAs.
- Utility functions for dealing with [`lum_analyze` results](#analyzing-a-simulation):
  - `plotMQW`: plot results from a `mqw` structure that is generated by specifying `.qw` layers in the `epitaxy`
  - `plotResultYZ`: plot FDE and/or CHARGE results, optionally both simultaneously
  - `plotResult3D`: plot x-propagation results from EME, varFDTD, or FDTD simulations
- A set of scripts to generate many Lumerical scripts sweeping specified parameters, optionally [enqueue to a remote host](#remote-host-queueing-and-execution), and analyze the results: `buildScriptAndEnqueue`, `buildSweepAndEnqueue`, `retrieveCompleted`, and `sweepPlots_Base`

The first two categories are fairly self explanatory, with further documentation provided in the function headers.

### Generating Lumerical scripts with MATLAB

> First make sure to update the `dirCommon` variable in the header of `buildScriptAndEnqueue`.

The functions `buildScriptAndEnqueue` and `buildSweepAndEnqueue` enable easy sweeping of any parameter(s) defined in a Lumerical script by generating many variants of such script. Simply pass a sweep name, the script contents as a string, and a cell list consisting of variable name and value pairs, such as:

```MATLAB
% Sweep the "x" variable in "myscript.lsf"
script = string(fileread("myscript.lsf"));
buildSweepAndEnqueue("test_sweep", script, ["x", linspace(0,10,101)], 'submitjob', 1, 'session', 'PuTTY-session-name');
```

Optionally alter the default `session` parameter to point to the correct PuTTY session, or even change the `plink` and `pscp` parameters to use SSH instead.

For large sweeps, it may be faster to simply generate the script variants locally:

```MATLAB
buildSweepAndEnqueue("test_sweep", script, ["x", linspace(0,10,101)], 'submitjob', 0);
```

Then copy the files to the remote host and queue them all at once:

```sh
~/lumerical/Q_parallel.sh fde ~/lumerical/tmp/sweeps/test_sweep/*.lsf
```

For either method, the completed results (`.mat` files) can either be manually moved back to the original sweep directory, or `retrieveCompleted()` can be used to read the locally-generated log of submitted files, `submitted.log`.


### Analysis of Lumerical sweeps

Analysis can be performed in MATLAB on many `.mat` file results of Lumerical sweeps with `sweepPlots_Base.m`. Optional variables are [described in the file header](./MATLAB/sweepPlots_Base.m), but required variables are:

- `componentName`: the name of the test, for use in plots
- `outDir`: the directory to write results to
- `resFiles`: the list of result files as an array of strings, without extensions
- `resExts`: the extension(s) of result files
  - These two are combined to look for actual files; for combined electro-optical results incorporating `analyticalModelGaAs`, a list of files without the typical `_<solver>.mat` tail can be provided for `resFiles` and `["_FDE.mat", "_CHARGE.mat"]` can be set for `resExts`
- `params`: a list of simulation parameters via strings to `eval`, typically based on the results which are loaded into variable `R`, such as `R.wWG` and `R.outField.pol`
- `metrics`: a list of result metrics via strings to `eval`, in the same manner, such as `min(R.results.modeL)` for the lowest mode loss or `R.results.modeL(find(R.results.Pout == max(R.results.Pout), 1))` for the loss of the highest-output-overlap mode.

Each file will be analyzed for all `params` and `metrics`, and results will be plotted for any that vary across the group. FDE results have additional default processing added, visible in the `loadDataFile` function of `sweepPlots_Base.m`.


## MATLAB templating system for Lumerical script construction and analysis

Included in the [`MATLAB/template/`](./MATLAB/template/) folder are a set of sample scripts for a MATLAB-based Lumerical script templating system for geometry construction and analysis. A typical Lumerical script has been broken into several parts, several of which can be easily swapped out to define alternate components. This allows easy assembly of a set of related simulations, such as multiple components based on the same process and epitaxy.

The provided Lumerical script pieces are in the [`MATLAB/template/lsf/`](./MATLAB/template/lsf/) folder, and include:

- `10_header_template.lsf` to provide a standard header.
- `20_etch_<material>_WG.lsf` to provide a standard initial waveguide definition and defaults for a given epitaxy; this is something that is likely to be typical across an entire process.
- `22_etch_<material>_<component>.lsf` to provide specific component definitions that either build on or replace the `_WG` definition.
- `30_epi_<epi>.lsf` to define the specific epitaxy.
- `40_inst_<material>.lsf` to define typical 'instrumentation' used in an epitaxy, e.g. ports or common variations of options.
- `90_footer_template.lsf` to provide a standard conclusion to the script, including calling `lum_setup;`.

Each component is assigned a directory, and then consists of 3 MATLAB files:

- `def_<material>_<component>_<epi>.m` to define the component by assembling the whole script file and setting default variables for `buildSweepAndEnqueue`.
- `sweep_<material>_dev_<epi>.m` that loads the definition, sets custom sweep parameters, and then calls `buildSweepAndEnqueue` to create a sweep of Lumerical scripts, that can then be processed with the [remote-host execution scripts](#remote-host-execution) on a remote host.
- `plot_<material>_dev_<epi>.m` that loads the definition, sets analysis variables, and then calls [`sweepPlots_Base.m`](#analysis-of-lumerical-sweeps) to load all resulting `.mat` files and analyze the sweep results.

In my usage, the `sweep_*.m` files are fairly short with most lines being commented out past sweeps for easy reference, and the remainder defining the most recent sweep, such as:

```MATLAB
sweep = {"sim2D", 2, ...
         "wWG1", [1.5, 2.0, 3.0], ...
         "wgBR", linspace(50, 300, 51)};
sweepName = "AR8_dev_Sbend_varFDTD_1";
buildSweepAndEnqueue(scriptName, script, sweep, 'allvars', setVars, 'sweepname', sweepName, ...
                     'submitjob', 0, 'randomize', 0*0.02);
```

By convention, directories starting with `dev` are 3D photonic devices or components like MMIs and s-bends, analyzed with varFDTD and 3D FDTD, while directories starting with `wg` are waveguide cross-sections analyzed with MODE and sometimes CHARGE.

With this templating system, the workflow for developing a new epitaxy, process, and PIC component becomes:

1. For active epitaxies, possibly develop MQWs with [`MQW_peaks`](./MATLAB/template/MQW_peaks/).
2. Define possible epitaxy and basic waveguide structure.
3. Develop epitaxy with [`epi1D`](./MATLAB/template/epi1D/) or similar to determine the optimal epitaxy parameters.
4. Optimize etch depths and cross sections with [`wgPassive`](./MATLAB/template/wgPassive/), [`wgMod`](./MATLAB/template/wgMod/), and [`wgActive`](./MATLAB/template/wgActive/).
5. Develop waveguide components by creating a new `22_etch_<material>_<dev>.lsf` definition and `dev<Component>` set of MATLAB scripts for each one and sweep parameters.

Simply exploring [the provided scripts](./MATLAB/template/) may be helpful for a better understanding.


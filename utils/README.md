HPSC BSP Utilities
==================

This subdirectory contains utility scripts for both development and managing BSP
component revisions via OpenEmbedded recipes and BSP build recipes.

There are two types of "recipes".
The first are OpenEmbedded (Yocto/Poky) recipes, which are specified/configured
in OpenEmbedded Layer repositories (not in this repository!).
The second are BSP build recipes, which are specified in the top-level
`build-recipes` directory in this repository.

Scripts support the `-h` option to see help/usage information.

Development
-----------

These scripts setup shell environments for developers.

* `configure-hpsc-yocto-env.sh` - source this script to configure your shell
environment for modifying the BSP Yocto build configuration.
This is typically only needed if you are using OpenEmbedded tools to manage
layers and layer recipes.
See `set-env-yocto.sh` for Yocto Linux application development.
* `set-env-bare.sh` - source this script to configure your shell environment
with the ARM bare-metal cross-compiler installed within the BSP working
directory structure.
This is typically only needed if you are developing bare-metal applications.
* `set-env-rtems-r52.sh` - source this script to configure your shell
environment with the RTEMS `gen_r52_qemu` BSP environment built and installed
within the BSP working directory structure.
This is typically only needed if you are developing RTEMS applications for RTPS.
* `set-env-yocto.sh` - source this script to configure your shell environment
with the Yocto/Poky SDK built and installed within the BSP working directory
structure.
This is typically only needed if you are cross-compiling for Poky.


OpenEmbedded (Yocto) Recipe Management
--------------------------------------

The `upgrade-recipe-yocto.sh` script uses the OpenEmbedded `devtool` to upgrade
Git revisions within OpenEmbedded recipes.
In particular, this script is intended to update the `arm-trusted-firmware`,
`linux-hpsc`, and `u-boot-hpps` recipes specified in the
[meta-hpsc](https://github.com/ISI-apex/meta-hpsc) repository.
However, it should work for recipes in any layer configured as part of the HPSC
Yocto build that use git repositories as their source.

The script has a variety of options, but only `-r` is required to specify the
recipe to upgrade.
Also use `-c`, and `-B` to specify whether to commit the recipe change to the
layer repository (e.g., `meta-hpsc`) and which branch to do it on.
Specify `-s` and `-b` to upgrade a recipe to a particular Git revision and
branch, otherwise the latest is queried from the remote using the recipe's
current data.

Unlike most other scripts in this repository, this one uses a different working
directory by default -- `DEVEL` instead of `BUILD`.
This keeps Yocto recipe development independent of the normal build process.
The `DEVEL` directory can safely be removed without forcing a complete rebuild
of the normal Yocto build.

For example, to upgrade `arm-trusted-firmware` to the latest and commit the
changes to the `hpsc` branch of `meta-hpsc`:

	./upgrade-recipe-yocto.sh -r arm-trusted-firmware -c 1 -B hpsc

The script may take a few minutes to run, depending on the recipe -- be patient.
If you see output at the end like:

	No changes to recipe file: /path/to/hpsc-bsp/DEVEL/src/meta-hpsc/meta-hpsc-bsp/recipes-bsp/arm-trusted-firmware/arm-trusted-firmware_1.3.bb

then the recipe already specifies the latest revision and there is nothing more
to do.
If you see output at the end like:

	Recipe file upgraded: /path/to/hpsc-bsp/DEVEL/src/meta-hpsc/meta-hpsc-bsp/recipes-bsp/arm-trusted-firmware/arm-trusted-firmware_1.3.bb
	Committing changes to recipe
	[hpsc 1234567] arm-trusted-firmware: upgrade to rev: 890abcd

then changes were made to the recipe.
You probably now want to `git push` the recipe changes in `meta-hpsc`.
Because the build scripts checkout repositories using `https` instead of `ssh`,
you probably need to change the repository's remote URL before pushing (if
you're using a fork or another layer, change the path and URL accordingly):

	cd /path/to/hpsc-bsp/DEVEL/src/meta-hpsc
	git status      # to verify you're ahead of the remote
	git log	        # to see the upgrade commit log
	git remote set-url git@github.com:ISI-apex/meta-hpsc.git
	git push

If you didn't specify `-c 1` in the script command, you won't see the output
"Committing changes to recipe" and the line after.
You will need to `git commit` yourself before pushing.


BSP Recipe Management
---------------------

The `upgrade-recipe-bsp.sh` script upgrades Git revisions specified in HPSC BSP
build-recipes.
Before proceeding, push any changes to repositories for build-recipes you want
to upgrade.
This includes updating recipes in any OpenEmbedded layers so that the layer
(e.g., `meta-hpsc`) updates may be discovered by BSP recipe updates here.

The script has a variety of options, but only `-r` is required to specify the
recipe to upgrade.
Also use `-c` to specify whether to commit the recipe change in this repository.
Specify `-s` and `-b` to upgrade a recipe to a particular Git revision and
branch, otherwise the latest is queried from the remote using the recipe's
current data.

For example, to upgrade `qemu` to the latest and commit the changes:

	./upgrade-recipe-bsp.sh -r sdk/qemu -c 1

If you see output at the end like:

	No changes to recipe file: /path/to/hpsc-bsp/build-recipes/sdk/qemu.sh

then the recipe already specifies the latest revision and there is nothing more
to do.
If you see output at the end like:

	Recipe file upgraded: /path/to/hpsc/hpsc-bsp/build-recipes/sdk/qemu.sh
	Committing changes to recipe
	[hpsc 1234567] sdk/qemu: upgrade to rev: 890abcd

then changes were made to the recipe.
You may now push changes to this repository (after testing, of course):

	git push

If you didn't specify `-c 1` in the script command, you won't see the output
"Committing changes to recipe" and the line after.
You will need to `git commit` yourself before pushing.

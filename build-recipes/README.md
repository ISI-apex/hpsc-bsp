BSP Build Recipes
=================

This directory contains BSP build recipes (not to be confused with
OpenEmbedded/Yocto recipes).

BSP recipes are driven by the top-level `build-recipe.sh` script and inherit a
baseline environment from `ENV.sh`.
Read the comments in those scripts for a more detailed behavioral description.

***Important Notes***

* The build scripts _do not_ manage a dependency tree.
The only concept of a dependency is that recipes may "depend" on environment
exported by others (e.g., to locate SDK/BSP/toolchains).
_The user is responsible for building recipes in the correct order._
Remember to rebuild dependent recipes when a dependency is updated!
* The build scripts _do not_ store any state between executions.
The behavior is undefined if you manually modify source and work directories.
* Recipes are responsible for managing their deployed and installed artifacts.
The build scripts only manage a recipe's source and work directories.


Build Steps
-----------

The basic build steps for most recipes are:

* `fetch` - download sources (typically git repositories or installers) then
            copy the sources to a work directory (keeps sources pristine)
* `late_fetch` - download additional sources which require a work directory to
                 be configured first (e.g., to decide what to actually fetch)
* `build` - compile/package artifacts
* `test` - run unit tests on build artifacts
* `deploy` - deploy artifacts into the integrated BSP directory structure
* `toolchain_install` - install SDKs/BSPs/toolchains for other recipes to use

By default, most steps are no-ops (in `ENV.sh`) until overridden by recipes.

After fetch, `toolchain_uninstall` and `undeploy` steps are invoked so recipes
can remove old artifacts from prior builds (see Important Notes above).
The recipe's work directory is then destroyed (no incremental build by default).

Some behavior can be overridden to optimize a recipe's build.
For example, not deleting the work directory after fetch -- in general, this is
not recommended unless you really trust that incremental builds work correctly
after version updates.
E.g., we trust OpenEmbedded/Yocto, which has its own reliable build system, but
only choose to rely on it because building from scratch is so time-consuming.


Source and Integration Recipes
------------------------------

Some recipes exist exclusively to provide sources for other recipes, e.g.,
`ssw/hpps/yocto/poky`, `ssw/hpps/yocto/meta-openembedded`, and
`ssw/hpps/yocto/meta-hpsc`.
Similarly, some recipes exist exclusively to integrate other recipes, e.g.,
`ssw/hpps/yocto` integrates the aforementioned recipes.
Like other recipes, users are still responsible for building in the correct
order (see Important Notes above).

Regardless of a recipe's purpose, all recipes are driven by the same build
process -- some steps are just no-ops.

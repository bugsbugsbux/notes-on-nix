status: WIP

*These are my notes while learning Nix; they might therefore be
incorrect. I did not try everything described here yet.*

---

# Notes on Nix(OS)

Nix is:
1. a programming language
2. a package manager using the nix programming language
3. a linux distribution using the nix package manager

## FAQ

### How to read the official documentation?

0. You might want to start by reading these notes. It's an attempt to
   distill the information from all the different documentation sources
   into one coherent document.
1. Read the official "Nix Pills" article/blog series at
   <https://nixos.org/guides/nix-pills/>. It explains the nix package
   manager and the ideas it is based upon. Check out the `./pills-demos`
   folder of this repo, which contains the code example from the series
   in its different versions.
2. Read the NixOS manual, to understand how NixOS does things and learn
   about the module system.
   <https://nixos.org/manual/nixos/stable/>
3. Read the nixpkgs manual to understand how to create your own packages
   using stdenv and trivial builders, and how to modify packages.
   <https://nixos.org/manual/nixpkgs/stable/>

### How to print a value?

A value can be printed with the function `builtins.trace`, which takes
two arguments, one to print and a second one to return. Make sure this
part of the code evaluates (nix is lazy!), otherwise nothing happens...

The *repl* provides the command `:print` to *recursively* evaluate and
output the value of an expression. As all repl commands it cannot be
used *within* an expression: It would throw a `syntax error,
unexpected ':'`.

## Overview

The idea behind nix is to *declaratively* manage the state of the
operating system: not only which packages are installed, but also which
services are enabled, how programs are configured, etc. Declaratively
means, one states the intended result and the program (nix) figures out
itself, how to achieve that.

Nix uses a hybrid source- and binary-based approach to package
management: Installing a package retrieves build instructions, but only
actually builds it if it cannot find a cached version (either in the
local- or a remote-**cache**).

*TLDR for the next 2 paragraphs: a profile is a link to a generation
which is a link to an environment which is a folder with the links to
executables which are stored in the nix-store location and made
available for use by including the profile-link in the PATH.*

Locally, nix puts everything into the **nix-store**, which is usually at
`/nix/store`, and makes sure the correct executables are found by
linking them to a folder called an **environment** and putting a link to
it (called a **profile**) in the PATH. Ultimately this means multiple
versions of the same program can be installed without conflict and
programs (/specific versions) can be composed to create arbitrary,
custom environments.

Between profiles and environments there is actually another layer of
linking which is called **generations**: When an environment "changes",
actually, a new environment is created, based on the old one, and the
profile link is updated to point to the new generation. This allows to
simply switch to a different state by changing the link to the relevant
generation, which is just a link to a certain environment.

Therefore, removing a package only creates a new environment without it
and a new generation pointing to this environment. To actually delete
the package, **garbage-collection** needs to be run when there is no
reference to it, meaning all generations which included it need to be
removed first and thus cannot be restored anymore.

A **derivation** is the recipe for a package and turned internally into
a "\*.drv" file (called **store derivation**) in the nix-store (this
step is called **instantiation**). To create it the user calls the
`derivation` function or a wrapper around it. The build process, called
**realisation**, runs in an isolated environment ("sandbox") to ensure
reproducibility on other systems, and uses the instructions (or rather
the standardized build specification) from a "\*.drv" file to produce
the build output(s): the **package**.

**NixOS configuration** is divided into **modules**, which are parts of
a certain structure, that can modify each other. This allows to split
the main config file `/etc/nixos/configuration.nix` into multiple ones
and to modify parts of the config from other parts instead of having to
edit them in-place (in other words: they allow the user to write his
own config file to change other parts of the config).

The default source for nix code is called **nixpkgs** and hosted on
github. It is organized into **channels** (implemented as branches) of
which there are:
- "nixpkgs-unstable" and "nixos-unstable" (for nix and nixos users
  respectively) are updated continuously but only use basic tests;
  failing tests can block the entire channel from time to time.
- The stable channels are called "nixos-YY.MM", use more rigorous
  testing, can be used by both, nix and nixos users, and their packages
  only receive bugfix- and security-updates after the initial release.
- The channels called "\*-small" simply have less binary caches and thus
  receive updates faster.

Since channels change over time there is no guarantee that building the
same configuration always produces the same result. Moreover, there is
no standardized way of making the contents of a repo with nix code
discoverable (Does it provide a package, a module, etc?). To fix these
problems nix introduced **flakes** which are officially still
experimental but already used by most of the community. A flake is a
repo with a `./flake.nix` file which has a certain structure and defines
build outputs, dependencies, etc; a `./flake.lock` file pins the
dependencies to a specific version.

As mentioned, the idea behind nix is not only to install packages in a
declarative way, but also to configure them; this works well for global
programs, but not so much for user-environments, which are configured in
the home directory. The program "**home-manager**" allows to
declaratively manage user-environments like one would manage the system
environment with nix. Keep in mind that one must not edit the managed
configurations manually, as home-manager overwrites these files!

Nix comes with a simple but not very secure way of running virtual NixOS
instances: **NixOS containers**. They share the host's nix store, which
makes creating such containers efficient, but has the downside that the
container's root can modify the host.

## Nix language

`builtins.langVersion == 6`

*To experiment with the nix language use `nix repl`!*

`#` **comments** the rest of the line, while `/*` starts a comment which
ends with the next `*/`.

**Whitespace** is generally not significant, thus most code may be
written in a single line. An example where a single space makes a
difference is: `let foo=1; bar=foo -1; in bar` (returns the value of
bar: `0`) while the following throws the error "undefined variable
'foo-1'": `let foo=1; bar=foo-1; in bar`.

The nix language requires each file (nix files use the extension ".nix")
to contain *only a single* "**nix-expression**", which is something that
evaluates to a value. `builtins.typeOf` returns the type of a value as a
string:

- **"int"** (integer number): `1`
- **"float"** (floating point number): `3.14`
- **"bool"** (boolean/truth value): `true` and `false`
- **"null"**: `null` (called "nil" nor "none" in some languages)
- **"string"**:
  ```nix

  asdf://example.com    # URI recognized as string: "asdf://example.com"

  "
    strings are not single quoted (')
    strings may span multiple lines
    double quoted strings keep their starting line
    double quoted strings keep all leading whitespace"

  ''
      strings wrapped in *double* single quotes:
      ignore the starting line if it only consists of whitespace
        remove (only) the *common* *leading* whitespace from each line  
      whitespace-only lines like the following line of 2 spaces...
    
      ...do not contribute to the calculation of the common whitespace
      ...get shorter by the number of common whitespace characters
      a whitespace-only final line always becomes a single newline
        ''

  "\\ \"toggles\" special character meaning: \n\\\" \n\\n \n\\r \n\\t"

  # concatenating strings; embedding expressions
  "use \${} for string-interpolation 10+1=${"1"+"1"}"
  # "10+1=${builtins.toString(10+1)}"
  ```
- **"path"**: Careful: Using paths copies it to the nix-store location!

  Paths are unquoted, do not contain "://" which would make it a URI,
  that is a string, and have at least one "/" which is not the last
  char:
  ```nix
  ./relative-path               # relative to the file it is used in
  ../path-in-parent/folder      # may not end in /
  /absolute-path
  ./.                           # current folder
  /.                            # root folder
  ~/.                           # home folder
  ```

  Names in angles (`<name>`) are matched against files and folders
  listed in environment variable "NIX_PATH". This should be avoided as
  it is impure (not reproducible).
- **"list"**: `[1 "two" 3 4]`
- (attribute-)"set": What other languages call "(hash-)map",
  "dictionary" or "table". See below.
- "lambda" (function): Indeed, functions may be used as values.
  See below.

Variable definitions are wrapped in a **"let" statement**, which defines
the local scope for the subsequent expression. As nix is lazy, meaning
it only computes values (including sub-members of sets) when they are
needed, the definitions of a "let" statement may be out of order!
```nix
let b = a + 1 ;     # the order in this block is not significant
    a = 1 ;         # semicolons are required
in a + b            # no semicolon here (would be error)
```

Recursive definitions are allowed. This means an expression has access
to its own name. See also: fixpoint
```nix
let a = a + 1;      # "infinite recursion"- not "unknown variable"-error
in a
```

**Set**s are wrapped in braces (`{}`) and define their attributes like a
"let" statement defines its variables, but they can only refer to each
other if the set is preceded by the keyword `rec` or by indexing the set
itself.

Attribute-names must be strings and are accessed with
`setName.attributeName`. If necessary *attributes* may be quoted
(`setName."attribute name"`) but *such names should be avoided*!

```nix
let s1 = {
        b = s1.a + 1;
        a = 1;
    };
    s2 = rec {
        d = c + 1;
        c = 100;
    };
    "inconvenient name" = rec {
        "this attr" = "no easy access to this from sibling attributes";
        # x = "this attr"           # a string not value of "this attr"
        # x = "inconvenient name"."this attr"   # does not work either!
    };
in s1 // s2             # update set: orig_values // new_values
```

In nix, one cannot reassign a name, thus it is clear that assigning to
the same set again extends the set's current value. Moreover, missing
sets are auto-created, when being assigned to, but accessing a missing
set throws an error which can be be suppressed by providing a fallback
value with keyword `or`:
```nix
let foo.a.b = 1;                    # creates missing sets foo and foo.a
    foo = { c = 3; };               # extends foo
    bar = {a = { b = 1;}; c = 3;};  # equivalent to foo
in [ (foo==bar) foo.a.b (foo.a.b.c.d or "missing") ]
```

Instead of assigning named values to the same name in a set, the
**"inherit(from)" statement** may be used.
```nix
let foo = 1;
    bar = 2;
    baz = { foobar = 3; };
in {
    # from local scope
    inherit foo bar;        # same as foo=foo;bar=bar;
    # from specific set
    inherit (baz) foobar;   # same as foobar=baz.foobar;
    fizz = "buzz";
}
```

The **"with" statement** adds the attributes of a set to the local
scope, except when there would be a name collision:
```nix
let bar = 1;
    foo = { bar = 100; baz = 200; };
in
    with foo;               # only one set allowed, semicolon required
        {
            a = bar;
            b = foo.bar;
            c = baz;
        }                   # no semicolon here
```

Nix **function**s are anonymous (so called "lambdas") closures which
only take a single argument. Anonymous means they do not have a name;
but as they are values, they may be bound to a name in the usual way.
Closure means a function knows about variables in its parent scopes from
the time it was defined. This lets one implement multi-argument
functions by nesting functions: The body goes into the innermost
function, which takes the last argument and is returned by another
function with takes the second to last argument, and so on; this is
called "currying".

The term **closure** is also used by nix in reference to all the
packages a package depends on (as well as the packages they depend on,
etc). Build-dependencies and runtime-dependencies may differ; if not
specified "package closure" usually only means the runtime dependencies.
See also: dependencies

```nix
# You cannot put the following nix-expressions in the same file, as only
# one expression is allowed per file!

# Functions do not need parentheses to execute:
with builtins; length                   # returns a function
with builtins; length [1 2 3]           # returns the result 3
# Exception: in a list functions only evaluate when parenthesized:
with builtins; [ length [1 2 3] ]       # contains function and list
with builtins; [ (length [1 2 3]) ]     # contains integer

# Define a function with 1 argument:
arg : arg + 1                           # increment argument by 1
# Invoke unnamed function:
(arg: arg + 1) 100
# Bind function to a name; then invoke it:
let inc = arg: arg + 1; in inc 100

# Curried function (= multi-argument function by nesting functions):
let sub = x: (y: x - y); in sub 2 3     # () are not necessary:
let sub = x: y: x - y; in sub 2 3       # equivalent

# Functions with named and optional (=default value) arguments take a
# set as argument:
let inc = {x, by ? 1} : x + by;
    in [ ( inc{x=100;} ) ( inc{x=100;by=3;} ) ]
# Allow other named arguments:
let inc = {x, y?1, ...}: x + y;
    in [ ( inc{x=1;} ) ( inc{x=1;y=2;} ) ( inc{x=1;y=2;z=3;} ) ]
# Make supplied arguments accessible as variable "given":
let inc = given@{x, y?1, ...}: with builtins; length(attrNames(given));
    in [ ( inc{x=1;y=2;} ) ( inc{x=1;y=2;z=3;} ) ( inc{x=1;z=3;} ) ]
# equivalent:
let inc = {x, y?1, ...}@given: with builtins; length(attrNames(given));
    in [ ( inc{x=1;y=2;} ) ( inc{x=1;y=2;z=3;} ) ( inc{x=1;z=3;} ) ]
```

Nix **does not have loops**, instead, use one of the builtin functions,
for example `builtins.map` and `builtins.mapAttrs`, which iterate over
list and set elements respectively.

**Conditionals** (`if`, `then`, `else`) must have an else-block! String
interpolation works in attribute names which can be used to
conditionally add items by returning `null` if it should be omitted. It
also works in paths, but only for individual segments: `s.${"foo.bar"}`
is `s."foo.bar"`, not `s.foo.bar`.
```nix
{
    # conditional value
    foo =
        if 3 > 3 then
            "greater"
        else if 3 < 3 then  # combine 2 conditionals to get else-if
            "smaller"
        else                # every conditional MUST have an else clause
            "equal"
    ;

    # string-interpolation in attribute name must return string ...
    ${"a"+"b"} = "ab";

    # ... or null which omits the item:
    ${if false then "add key" else null} = "not added";

# string-interpolation in attribute paths:
}.${if true then "foo" else "ab"}
```

See also: operators

As the examples already indicated, most builtins are not available in
the global namespace and have to be accessed via the set `builtins`.
Documentation at: <https://nix.dev/manual/nix/2.18/language/builtins>

Another common set of functions is the standard library from nixpkgs.
See: modules. Documentation at:
<https://nixos.org/manual/nixpkgs/stable/#sec-functions-library>
The documentation makes it look like the standard library only exposes
other libraries, however, actually it also exposes functions *directly*!
See the `inherit` statements at:
<https://github.com/NixOS/nixpkgs/blob/master/lib/default.nix>

## Installation

### Only installing the nix package manager

The nix package manager can be installed

1. for a **single user**, meaning (only) the user owning `/nix` can
   manage nix. This might be convenient if one does not want to use root
   privileges, but a malicious build could access a user's home.
2. for **multiple users**, meaning root owns `/nix`. Global builds,
   require special privileges, cannot access users' homes, and are
   available to all users. Unprivileged users may install packages for
   themselves, but not pre-built binaries.

### Installing from an .iso

Like most other systems, nix may be installed from an iso image:

- There are ones with a **graphical installer**: one just has to
  follow its instructions.

- The "minimal" iso file is for **manual installations**:
  Manually installing NixOS starts like any other manual install:
  setup the keyboard (with "loadkeys") and networking (with
  "wpa_supplicant"); then create partitions (with "cfdisk") with
  appropriate labels (which depends on BIOS or UEFI setup and
  preference) and format them accordingly (with "mkfs.\*" and
  "mkswap"). Mount root partition on `/mnt`, mount boot partition on
  `/mnt/boot`, (activate swap partition,) and generate a config file
  in `/mnt/etc/nixos/` (`nixos-generate-config --root /mnt`).
  Configure it (with "nano"); important points:

  * Mounting should have been configured by "nixos-generate-config"
    and written to `/mnt/etc/nixos/hardware-configuration.nix`. Make
    sure it is included by `/mnt/etc/nixos/configuration.nix`:
    ```nix
    imports = [ ./hardware-configuration.nix ];
    ```
    Also make sure the appropriate kernel modules are enabled in
    the `boot.initrd.kernelModules` option to be able to mount
    certain special file systems!

  * Configure boot loader:
    ```nix
    # BIOS -> grub
    boot.loader.grub.device = "/dev/DISK_TO_INSTALL_GRUB_TO";
    boot.loader.grub.useOSProber = true;

    # OR: UEFI
        boot.loader.efi.efiSysMountPoint = "/YOUR_BOOT_PARTITION";

        # systemd-boot:
        boot.loader.systemd-boot.enable = true;
        # more boot.loader.systemd-boot.* options are listed here:
        # <https://nixos.org/manual/nixos/stable/options>

        # OR: grub (cannot be used to dual-boot *linux* distros)
        boot.loader.grub.device = "nodev"; # this is a special value
        boot.loader.grub.efiSupport = true;
        boot.loader.grub.useOSProber = true;
    ```

  * Configure network:
    ```nix
    networking.hostName = "YOUR_MACHINE";
    networking.networkmanager.enable = true;
    user.users.YOURUSER.extraGroups = [ "networkmanager" ];
    networking.firewall.enable = true;
    # networking.firewall.allowedTCPPorts = [];
    # networking.firewall.allowedUDPPorts = [];
    networking.wireless.enable = true;
    # the following runs the provided shell script after network setup
    networking.localCommands = ''
        get_my_wpa_config_with_passwords > /etc/wpa_supplicant.conf
        systemctl restart wpa_supplicant.service
    '';
    ```

  Now, install with `nixos-install`, then `reboot` if it worked. If it
  failed, fix the config and rerun `nixos-install`. It will prompt for
  a root password.

### Installing over the internet

NixOS can be **booted over the internet** with PXE or iPXE. See:
<https://nixos.org/manual/nixos/stable/#sec-booting-from-pxe>

### Installing from a running system

- **Temporarily convert some running linux distro into NixOS**: Create
  the 3 needed files `./bzImage`, `./initrd` and `./kexec-boot` with
  `nix-build -A kexec.x86_64-linux '<nixpkgs/nixos/release.nix>'`,
  copy them to the target computer and run `./kexec-boot` there.

- **Converting an existing linux installation** (other distro) into a
  NixOS system: There is an installation variant called "NIXOS_LUSTRATE"
  which permanently converts a running linux system into a NixOS system.
  There, are scripts like "nixos-infect" or "nix-in-place" which
  automate this. Note: This might, in some scripts *by design*, destroy
  all data on the machine -- back it up beforehand!

## Imperative configuration

### Profile management

*See also: unfree packages.*

NixOS is managed via a configuration file, in which one can define,
among other things, which packages shall be installed. The nix package
manager may also be invoked like a traditional package manager, but one
should keep in mind that it still acts differently (see: generations,
garbage-collection, profile)!

The following commands are used to manage the current user's profile.
Thus running them as root influences root's profile -- which is the
global one, whose installed programs are available to all users.

```sh
# create new generation including the specified packages
nix-env --install   regex1 regex2-version regex3
nix-env -i          regex1 regex2-version regex3

# Using --install as shown above matches the regex against all nixpkgs
# and installs the latest matching one. This is slow and might not
# install the intended package. Instead add the --attr or -A option to
# interpret the arguments as attribute paths selecting from the default
# nix-expression (see:
# nixos.org/manual/nix/stable/command-ref/files/default-nix-expression)
# or the result of the expression in the file given with -f or --file .
# This is faster due to nix's lazy evaluation ignoring all parts of the
# set which were not indexed. That this also applies to --upgrade .
nix-env --install --attr    nixos.pkgname1     # on NixOS
nix-env -iA                 nixpkgs.pkgname1   # on other systems
nix-env -iA -f '<nixpkgs>'  pkgname1    # instead of default nix-expr

# create new generation without the specified packages
nix-env --uninstall regex1 regex2
nix-env -e          regex1 regex2
# create new generation with updated versions of all or given packages
nix-env --upgrade   regex1 regex2
nix-env --upgrade
nix-env -u
nix-env -uA nixos.pkgname1  # or nixpkgs.pkgname1 on other systems
# modify current generation to only contain the specified derivation
nix-env --set regex1 # --profile profilename

# modify metadata
# for example pin package to current version by setting "keep" to "true"
nix-env --set-flag "keep" "true" regex1

# listing packages
nix-env --query --installed         # list all or specified if installed
nix-env --query                     # same as with --installed
nix-env --query --available regex1  # include non-installed packages
# Adding --status puts a 3 letter string next to a package indicating
# whether or not (-) it is:
# available in the current generation (I),
# available elsewhere on the system (P),
# available as substitute for building it locally (S).
nix-env -q -a --status regex1       # -q is --query, -a is --available
nix-env -q    --compare-versions    # compare installed to available
nix-env -q -a --compare-versions    # compare available to installed

# activate a specific profile (link to a generation)
nix-env --switch-profile profilepath
nix-env -S               profilepath

# list generations of current profile (current marked with "(current)")
nix-env --list-generations
# activate previous (highest number lower than current) generation
nix-env --rollback
# activate specified generation
nix-env --switch-generation 123 # or any other generation
nix-env -G                  123
# delete specified generations
nix-env --delete-generations 1 2 3 # or any other generations
nix-env --delete-generations "old" # ALL except current generation
```

### Temporary shell environments

Nix also allows to install packages into a temporary environment with
`nix-shell`:
```sh
# interactive shell
cowsay                          # error: command not found
nix-shell --packages cowsay     # interpreted as attributes of nixpkgs
> echo hello world | cowsay     # ok
> exit
cowsay                          # error: command not found
# only run given command and exit
nix-shell -p cowsay --run "echo hello world | cowsay"
```

After exiting the temporary environment the installed packages are not
available anymore, however, they are still in the store until the next
time garbage-collection runs, so running the same `nix-shell` command a
second time should be much faster, than the first time!

#### Nix scripts

Instead of shell scripts where the user needs to install the needed
programs in the required versions himself, there are nix scripts:

Replace shebang lines like `#!/bin/bash` with `#!/usr/bin/env
nix-shell`. The following lines starting with `#! nix-shell` are merged
into a single call to `nix-shell` and define the environment; `--pure`
isolates it from the system; the interpreter to use is specified with
`-i`; `--packages` installs the given dependencies. For even more
reproducibility use `-I nixpkgs=` to specify a certain release of
nixpkgs.

```bash
#!/usr/bin/env nix-shell
#! nix-shell --pure -i bash
#! nix-shell --packages bash cowsay
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/0672315759b3e15e2121365f067c1c8c56bb4722.tar.gz

echo hello world | cowsay
```

## Declarative configuration

### Temporary shell environments

Creating temporary shell environment as described in above is tedious,
instead one may want to configure such environments declaratively, on a
per directory basis: This is what `./shell.nix` is for. Simply run
`nix-shell` without any arguments in the same directory to activate the
environment.

```nix
let
  nixpkgs =             # get a specific release
    fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-23.11";
  pkgs = import nixpkgs {};
in pkgs.mkShellNoCC {   # creates a shell without c compiler toolchain
    # packages to install, no need to specify bash:
    packages = with pkgs; [ cowsay ];
    # commands to execute on startup:
    shellHook = ''
        echo "$MYVAR" | cowsay
        # set variables which cannot be set as nix set-attributes:
        export PS1="> "
    '';
    # set environment variables (if not possible set them in shellHook)
    MYVAR = "Welcome in your temporary bash environment!";
}
```

### Profile management

The main configuration file (itself a module, see below) is
`/etc/nixos/configuration.nix` and usually (for example when generating
a new configuration with `nixos-generate-config`) hardware-specific
options are put into their own module
`/etc/nixos/hardware-configuration.nix`, which allows to use the same
main configuration file on different machines.

If a file `/etc/nixos/flake.nix` exists, it takes precedence over
`/etc/nixos/configuration.nix`, which allows to turn the configuration
into a flake (see below).

After changing the config, the system needs to be rebuilt with the
command `sudo nixos-rebuild`. It takes an *argument* to specify *when*
to activate the new system:
- "switch": immediately
- "boot": on next reboot
- "test": immediately but only temporarily (until next reboot)
- "build": only build, don't activate

The following *options* are useful:
- "--rollback": Instead of building a new generation of the system,
  activate the previous one at the specified time (see above: argument).
- "--upgrade": This is used to **update the system**. It may rebuild the
  system even when the configuration did not change, because it first
  updates the channel, and thus package definitions might have changed.

Global packages are to be added to the configuration option (see below)
`environment.systemPackages` (a list value), while user specific
packages shall be added to `users.user.USERNAME.packages` except when
using home-manager.

Note: Installation of **unfree packages** needs to be enabled on a per
user basis: For the global user this is done with option
`nixpkgs.config.allowUnfree = true;`. However, other users' access to
unfree packages cannot be enabled from the NixOS config; instead they
need to set attribute `allowUnfree = true;` in their
`~/.config/nixpkgs/config.nix`.

### Modules

The module system is not a feature of the nix language but NixOS and
allows to split the configuration into multiple files called modules,
which return a set with certain attributes or a function which returns
such a set.

The set a module (or its function) returns looks like this:
```nix
{
    options = { /* option-declarations */ };
    config =  { /* option-definitions */ };

    # optional:
    imports = [ /* paths to other modules */ ];
    meta = {
        maintainers = [];
        doc = ./path.md;
        buildDocsInSandbox = true;
    };
}
```

If the module does not declare any options (aka has no "options" field),
the returned set may be structured like this instead:
```nix
{
    # options = { /* option-declarations */ };    # missing
    imports =   [ /* paths to other modules */ ]; # optional
    # meta = {};                                  # optional

    /* The "config" field, for example this one ...
    config = {
        networking.hostName = "MY_HOST_NAME";
    };

    ... is replaced by its contents like so: */
    networking.hostName = "MY_HOST_NAME";
}
```

The module system handles loading the modules whose path is specified in
the "import" field. If a module is called "directory/default.nix" it is
also possible to use the path to the directory instead.
(`imports = [ ./directory ];` instead of
`imports = [ ./directory/default.nix ];`)

When a module is a function, it is called by the module system
with a set containing the following items:

- `pkgs`: This provides access to nixpkgs.
- `lib`: This provides access to the **nixpkgs standard library** in a
  *safe* way; contrary to using `pkgs.lib` (essentially
  `import <nixpkgs/lib>`), which might result in an infinite recursion.
- `modulesPath`: The location of the modules directory (see above).
- `config`: All option-definitions; including the options set by the
  module itself, which works (as long as no option references itself)
  because nix is lazily evaluated. (see: options)

  Note: This means option-definitions may depend on each other, however,
  this dependency must not be used to create the "config" value itself,
  only the create its attributes:
  ```nix
  {config, ...}:
  {
      # this is allowed:
      config = {
          some-pkg.enable = if config.other-pkg.enable
              then true
              else false;
      };

      /* however, the following is not allowed:

      config = if config.other-pkg.enable then {
          some-pkg.enable = true;
      } else {
          some-pkg.enable = false;
      };
      */
  }
  ```
- `options`: Similar to the `config` argument but for
  option-declarations.

Here is an example module which is a function and returns a set using
the simplified module structure (meaning no "options" field and does not
put the option-definitions into a "config" field):
```nix
{ pkgs, ... }: # specify which arguments you intend to use
{
    imports = [ ./hardware-configuration.nix ];
    networking.hostName = "MY_HOST_NAME";
    environment.systemPackages = with pkgs; [
        git
        #...
    ];
    users.users.USERNAME.packages = with pkgs; [
        chromium
        #...
    ];
    #...
}
```

Moreover, the module system injects some **utility functions** into the
namespace of each module; see: options,
<https://github.com/NixOS/nixpkgs/blob/c45e6f9dacbe6c67c58a8791162cbd7e376692fa/lib/modules.nix#L1396>.

#### Options

NixOS exposes **options** via the module system for the user to define
the intended system state. These options are "declared" (meaning
created) in some module, and may be "defined" (meaning modified) in some
other module.

Most options come from a module in the **modules directory**
`<nixpkgs/nixos/modules>`. To be able to use an option, the path of the
module which declared it needs to be specified in the "imports" field,
except when it is listed in `<nixpkgs/nixos/modules/module-list.nix>`
(which most non-user-created modules are). This is not to be confused
with using the `import` keyword to load a file!

An option is called by the name used when it was declared in a module's
"options" field. Often this is an attribute path consisting of
option-category (just a convention, see: <https://mynixos.com/options>),
name (as used in in `<nixpkgs/pkgs/top-level/all-packages.nix>`) of the
package it comes from, and specific name. When accessing an option's
final definition or its declaration, this attribute path is used to
index the module's `config` or `options` argument.

Depending on whether an option has a default value, **not defining it**
may be an error nor not.

Depending on the type, **defining an option multiple times** may be an
error or merged in some way. For available types, how to customize
them, and how to create new ones, see:
<https://nixos.org/manual/nixos/stable/#sec-option-types>

Even options which only allow a single definition, may be defined
multiple times when instructing the module system to *ignore* other
definitions with weaker **priority** (weaker=*higher* priority value).
This is done with the injected function `mkOverride`:
`optionName = mkOverride 90 "prioritized definition";`. The priority for
regular option-definitions is `100` and for default values is `1500`.

When an option allows multiple definitions, it merges them into a single
value sorted by each definition's **order** value (*lower* comes first).
How they are merged depends on the option type (for example collected
into a list or joined with newlines). The order value for regular
option-definitions is `1000`. Use the injected function `mkOrder` or one
of its wrappers `mkBefore` (is `mkOrder 500`) and `mkAfter` (is `mkOrder
1500`) like so: `optionName = mkOrder 500 "first";`.

To clarify the difference between order and priority: A definition which
loses in priority is ignored, thus its order value is irrelevant.

```nix
# This is ./some-module.nix

# the nixpkgs-stdlib is needed; don't access it via pkgs.lib but via lib
{ lib, ... }:
{
    options = {

        # Use lib.mkOption ...
        category.some-package.optionName = lib.mkOption {
            default = [];
            type = lib.types.listOf lib.types.singleLineStr;
            description = "Markdown description of *this* option";
        };

        # ... or a wrapper simplifying creating certain option types:
        category.some-package.enable =
            # Create a boolean option defaulting to false, with a
            # description "Whether to enable ${argument}":
            lib.mkEnableOption "some-package";

    };
}
```
```nix
# A module which does not use the simplified structure:
{ ... }:
{
    imports = [ ./some-module.nix ];
    config = {
        category.some-package.enable = false;           # priority: 100
        category.some-package.optionName = [ "c" "b" ]; # sort: 1000
    };
}
```
```nix
# A module which uses the simplified structure:
{ lib, ... }:
{
    imports = [ ./some-module.nix ];

    # Ignore the other definition of this option (has priority 100):
    category.some-package.enable = lib.mkOverride 90 true;

    # Put this before the values from the other option-definition:
    category.some-package.optionName = lib.mkOrder 500 [ "a" ];
    # Thus the final option value is: [ "a" "c" "b" ]
}
```

## Packages

The above definitions differentiated between "package" and "derivation",
not because the documentation does so (in fact, it uses the terms almost
interchangeably), but because the target audience, new nix users, likely
has the presumption, that packages are binaries which the package
manager downloads and puts in the right places on the system. This is
not how nix works, but in some cases effectively what it does, if the
term package is understood as build output. Actually, nix downloads
build instructions (derivations) and checks whether it can find a cache
of their result: if it does, it simply downloads the cached binary and
installs it (to the nix store); if it does not, it builds locally.

However, while packages and derivations are essentially equivalent,
there are some semantic differences in how they are used: To describe
how something is built, one writes a derivation with the `derivation`
function or one of its wrappers. When talking about packages instead of
derivations, the focus is more on their buildability, for which the
needed dependences have to be available. It is not sufficient for a
powerful package manager to make all packages use the same globally
available version of a dependency, thus the nix convention is to wrap
the derivation describing a package in a function, called
**package-function**, whose arguments are the needed dependencies.
```nix
# ./my-package.nix
{ mydependency }:
    derivation { # see: Derivations
        name = "my-package";
        system = builtins.currentSystem;
        builder = "${mydependency}/bin/mydependency";
    }
```

A package is therefore built by executing its package-function with the
dependencies as arguments. For convenience, nix has the
**"callPackage"-convention**: Create a function `callPackage` to
auto-supply the required arguments of a package-function from some
default set of packages:
```nix
let defaultPkgs = import <nixpkgs> {};
    callPackage = callPackageWith defaultPkgs;
    callPackageWith = pkgs: pkgfn_file: args:
        let pkgfn = import pkgfn_file;
        in with builtins;
            pkgfn ((intersectAttrs (functionArgs pkgfn) pkgs) // args)
    ;
    # someOtherVersion = (import (fetchTarball
    #     "https://github.com/NixOS/nixpkgs/archive/0672315759b3e15e2121365f067c1c8c56bb4722.tar.gz"
    # ) {}).mydependency;

/* instead of passing the dependencies manually: ...
in import ./my-package.nix { mydependency = defaultPkgs.mydependency; }

... use callPackage to auto-supply them: */
in callPackage ./my-package.nix {}

/* ... while preserving the ability to specify any argument explicitly:
in callPackage ./my-package.nix { mydependency = someOtherVersion; }
*/
```

Nixpkgs comes with a more robust `lib.callPackageWith`, whose result is
overridable (see: below), and a top level `callPackage` which uses
nixpkgs as the default package set.

If nixpkgs does not have a package (because there is no derivation
describing it), it can be added in two ways:
1. **In-tree**: This means to create a local copy of the nixpkgs repo,
   add the derivation to it and use this local version. (`nixos-rebuild
   switch -I nixpkgs=./nixpkgs`)
2. **Out-of-tree**: Instead of adding the derivation to a local copy of
   nixpkgs, it is specified in a nix configuration file.
   ```nix
   # /etc/nixos/configuration.nix
   { pkgs, ... }: {

       # this only effects this expression
       environment.systemPackages = let
           # create new packages
           new-package = pkgs.stdenv.mkDerivation { /*...*/ };
           another-new-pkg = pkgs.callPackage ./another-new-pkg.nix {};
           # modify some package
           some-package = pkgs.some-package.override { /*...*/ };
       in [ new-package another-new-pkg some-package ];

       # This effects these packages from nixpkgs, config-wide.
       # The argument prev is just pkgs before applying these overrides.
       nixpkgs.config.packageOverrides = prev: {
           some-package = prev.some-package.override { /*...*/ };
       };
   }
   ```

   The nixpkgs version as defined in the NixOS configuration is not
   available outside of the config. Instead, users may specify their own
   modifications to nixpkgs in `~/.config/nixpkgs/config.nix`; *these*
   are available for use in commands such as `nix-env -i some-package`:
   ```nix
   # ~/.config/nixpkgs/config.nix
   {
       packageOverrides = pkgs: {
           some-package = pkgs.some-package.override { /* ... */ };
       };
   }
   ```

### Derivations

Derivations are created ("instantiated") with the builtin function
`derivation` or a wrapper around it. It creates the "\*.drv" file in the
nix store, which contains the actual build instructions used when
building ("realising") the derivation with `nix-build`. (Moreover, it
returns a derivation object, which is a set with the attribute
`type="derivation";`.)

Despite the `derivation` function rarely being used directly it is
useful to understand what arguments it works with:

`derivation` *requires* the following arguments:
- `name`: A string which will be used in the names of files created in
  the nix store.
- `system`: A string such as "x86_64-linux" which specifies for which
  system to build the derivation. Building locally only works if
  `builtins.currentSystem` matches this string.
- `builder`: A path (or its string representation) to the executable to
  use to build the derivation. Examples: `./builder.sh`,
  `"${pkgs.python}/bin/python"`

`derivation` takes the following *optional* arguments:
- Any argument whose name is **not in this list** (or the list of
  required arguments) is exported as an environment variable with an
  appropriately converted value.
- `args`: List of strings to be passed as arguments to `builder`.
- `outputs`: List of strings that defaults to `["out"]`. Each string is
  the name of an environment variable available to the builder script
  containing the path to a nix store object which shall contain the
  respective output. For example `["doc" "out"]` exports the environment
  variables `$doc` and `$out` with the values
  `/nix/store/${hash}-${name}-doc` and `/nix/store/${hash}-${name}`
  ("-out" is always omitted). Note that the order of the list is
  important, as the first element determines the **default output** of
  the derivation, meaning what a simple package name refers to. For
  example, if there is
  `myPkg = derivation { name="mine"; outputs=["doc" "out"]; /*...*/}`
  then `myPkg` is equivalent to `myPkg.doc`.
- `allowedReferences`: List of runtime dependencies, meaning what the
  `outputs` may refer to.
- `disallowedReferences`: List of forbidden runtime dependencies.
- `allowedRequisites`: List of *all* allowed dependencies, including
  build-time dependencies and dependencies of dependencies.
- `disallowedRequisites`: List of forbidden dependencies, including
  build-time dependencies and dependencies of dependencies.
- `exportReferencesGraph`: List of name, store-object pairs. Each name
  (odd elements in list) becomes a file in the build directory and
  contains the reference graph of the store-object which is the
  following (therefore even) element in this list.
- `impureEnvVars`: List of names of environment variables which should
  *not* be cleared when calling the `builder`. This only works for
  fixed-output derivations (FODs).
- `outputHash`, `outputHashAlgo`, `outputHashMode`: These are used to
  create so called **fixed-output derivations (FODs)**, which are
  derivations whose output hash is known in advance and who are
  therefore allowed some impure operations like fetching from the
  network. `outputHashAlgo` may currently be "sha1", "sha256" or
  "sha512". `outputHashMode` specifies from what to compute the hash:
  "flat" (which is the default) means from the output, which must be a
  regular, non-executable file; "recursive" means from the **nix-archive
  (NAR**; they only preserve the information relevant to nix) dump of
  the output.
- `__contentAddressed`: Boolean, whether to put the outputs in
  content-addressed, instead of input-addressed, store location. *Only
  allowed when using the experimental "ca-derivations" feature.*
- `passAsFile`: List of those attribute names whose values would usually
  be exported in an environment variable of the same name, but should
  instead be passed to `builder` by putting them into a temporary file
  and exporting the path as variable "${name}Path".
- `preferLocalBuild`: Boolean. Requires distributed building to be
  enabled.
- `allowSubstitutes`: Boolean; if false, no binary caches are used. This
  is ignored if nix is configured with `always-allow-substitutes =
  true;`.
- `__structuredAttrs`: Boolean; if true all arguments (except this) of
  `derivation` are written to a json file and the path is exported in
  environment variable "NIX_ATTRS_JSON_FILE". Moreover, puts path to
  bash script which exports all bash-representable values as environment
  variables into variable "NIX_ATTRS_SH_FILE".
- `outputChecks`: Set of output names to sets which specify how to check
  the respective output. Available attributes are: `allowedReferences`,
  `allowedRequisites`, `disallowedReferences`, `disallowedRequisites`,
  `maxSize` (in bytes, example: `SIZE_IN_KB * 1024` or `SIZE_IN_MB *
  1024 * 1024`), `maxClosureSize` (see: closure, maxSize),
  `ignoreSelfRefs` (boolean; whether to ignore self references in
  dis/allowed references/requisites).
- `unsafeDiscardReferences`: Set of output names to booleans, whether
  to disable scanning the respective output for runtime dependencies.
- `requiredSystemFeatures`: List of strings such as "kvm" which name
  features which have to be available for this to build.

#### Building

Building, also called realising, is the execution of the standardized
form (a "\*.drv" file in the store) of a derivation, the recipe for a
package. Calling `nixos-rebuild switch` builds the necessary packages as
specified in the NixOS config; `nix-env --install some-package` builds
the specified package and its dependencies. A single file containing a
derivation can be built with `nix-build ./myderivation.nix`, however, it
is also possible to just instantiate it (create the store derivation)
with `nix-instantiate ./myderivation.nix` or even just evaluate it (no
instantiation) with `nix-instantiate --eval ./myderivation.nix`. The
filename may be omitted if it is `./default.nix`.

A builder will *not run* if neither the derivation nor its dependencies
changed; instead it simply returns the old result. Avoid creating
derivations like
`pkgs.runCommand "DRV_NAME" {} "${pkgs.coreutils}/bin/date > $out"`
where nix cannot determine with these rules whether to rebuild.

Moreover, a package won't build if, for example, it is marked as broken,
having security issues, not targeting the current platform, or not
having a free license (see: unfree packages). This is already checked
when evaluating the config and can be overruled temporarily by setting
environment variables
NIXPKGS_ALLOW_{BROKEN,INSECURE,UNSUPPORTED_SYSTEM,UNFREE} to 1. There
are also options to make this permanent, which also allow more granular
control over which insecure, or unfree packages or licenses may be
installed.

When evaluating an expression which reads from the filesystem, the
evaluation stops, the respective store object is realised (built), and
only then evaluation continues. This is called **Import from Derivation
(IFD)**. Setting `allow-import-from-derivation = false;` allows to
finish evaluation and creating a build plan before starting to realise
store objects; thus more store objects may be realised in parallel.

The `builder` runs with `args` in an isolated build-directory in TMPDIR,
with environment variables cleared and set according to the given
derivation arguments, invalidating the HOME and PATH variables, and the
nix environment set according to the derivation arguments. The network
cannot be accessed during the build (there are exceptions). The combined
stdout and stderr are written to `/nix/var/log/nix`. The build is
considered successful, if the builder exits with code 0. If inputs are
referenced by outputs, they are registered as runtime dependencies. The
time-stamp of the outputs is always unix-epoch 1.

When manually building a derivation, a symlink `./result` is then placed
in the current directory and points to the build output in the store. As
long as this link is unchanged (not removed, renamed or modified) the
build result is considered a **garbage-collector root**, meaning the GC
won't remove it. A new build in the same directory overwrites an
existing `./result`! The links for multiple outputs are named
`./result-${n}` (except the first which is still named `./result`).

### Modifying packages

A **fixed point, or "fixpoint"**, is a value, which is mapped to itself
by a function. Therefore, it is defined in terms of a specific function,
of which it is input and output no matter how many times the function is
applied. The mathematical equation `f(x)=x` is an example of this. In
programming languages which are lazily evaluated, and thus prevent the
infinite recursion error, this can be used to create self-referential
values! In nix a commonly used fixpoint is nixpkgs.
```nix
# this function comes with nixpkgs as: lib.fix
let getFixpoint = f:    # a function which takes a function
    let x=f(x);         # the input is the result -> recursive
    in x                # return it
;
in getFixpoint(self: {
    a=1;
    b=2;

    # Since "self" is the result, an attribute obviously cannot depend
    # on itself, as this would change the final state:
    # c = self.c + 1;   # error

    # But it can depend on other attributes; that's the whole point!
    c = self.a + self.b;
})
```

#### Overlays

One can also think of fixpoint-functions as describing a change to a
value, which they receive as argument. To apply the change, a helper
function is needed. The following builds up the helper in incremental
steps until it can be replaced by `lib.extends`, which applies overlays,
changes which are able to refer to the final and the previous state of
the fixpoint:
```nix
# This is the input for a repl session; it cannot be in the same file!

setup = {
    mystate = { a=1; b=10; };
    mychange = self: { a=5; c = self.a + self.b; };
}

# The following approach has problems:
# - it only returns the attributes used by the change
# - it uses the previous state (a=1) instead of the final state
let apply = change: prevState:
    change prevState;
in with setup; apply mychange mystate

# Fix the missing attributes in the return value by merging prevState
# state with the result of the change.
#
# There is still the problem that it should use the final state instead!
let apply = change: prevState:
    prevState // change prevState;
in with setup; apply mychange mystate

# To use the final state instead of prevState, the trick from evaluating
# fixpoint-functions is used: mention the result in the argument!
#
# The problem is that the plain result does mention all attributes of
# the final state.
let apply = change: prevState:
    let x = change (x);
    in prevState // x
;
in with setup; apply mychange mystate

# Combine the above solutions to pass an argument with all final
# attributes:
let apply = change: prevState:
    let x = change (prevState // x);
    in prevState // x
;
in with setup; apply mychange mystate

# It would be nice to be able to modify a recursive set, such that its
# recursive attributes reflect the changes:
setup = {
    mystate = self: { a=1; b=10; c = self.a + self.b; };
    mychange = self: { a=5; d = self.a + self.b; };
}

# This approach fails: Recursive attributes from the original fixpoint
# do not reflect the changes:
let apply = change: fixpointFn:
    let
        prevState = fixpointFn prevState;
        x = change (prevState // x);
    in prevState // x
;
in with setup; apply mychange mystate

# Instead, return a fixpoint-function and use its self-reference as
# substitute for the final state:
let apply = change: fixpointFn:
    self: let
        prevState = fixpointFn self;
        x = change (prevState // x);
    in prevState // x ;
    lib = import <nixpkgs/lib>;
in with setup; lib.fix (apply mychange mystate)

# Now, apply multiple changes in sequence:
setup = {
    initial = self: { a=1; b=10; c = self.a + self.b; };
    change1 = self: { a=5; d = self.a + self.b; };
    change2 = self: { b=100; };
}

# Problem: The result of applying the change does not use the final
# state!
let apply = change: fixpointFn:
    self: let
        prevState = fixpointFn self;
        x = change (prevState // x);
    in prevState // x ;
    lib = import <nixpkgs/lib>;
in with setup;
    lib.fix (apply change2 (apply change1 initial))

# Fix it by using the final state as argument to applying the change!
let apply = change: fixpointFn:
    self: let
        prevState = fixpointFn self;
        x = change self;
    in prevState // x ;
    lib = import <nixpkgs/lib>;
in with setup;
    lib.fix (apply change2 (apply change1 initial))

# Since prevState cannot be removed, it might as well be used to give
# changes more power: Changes which take two arguments representing
# their final and previous states, are called overlays; attributes may
# refer to their previous state!
setup = {
    initial = self: { a=1; b=10; c = self.a + self.b; };
    change1 = final: prev: {a=5; d = final.a + final.b; prevA1=prev.a;};
    change2 = final: prev: {a = prev.a * 10; b=100; prevA2=prev.a;};
                        #   ^^^^^^^^^^^^^^^
}

# Simply pass the prevState as second argument to the change function:
let apply = change: fixpointFn:
    self: let
        prevState = fixpointFn self;
        x = change self prevState;
    in prevState // x ;
    lib = import <nixpkgs/lib>;
in with setup;
    lib.fix (apply change2 (apply change1 initial))

# The apply function comes with nixpkgs as: lib.extends
let lib = import <nixpkgs/lib>;
    fix = lib.fix;
    extends = lib.extends;
in with setup;
    fix (extends change2 (extends change1 initial))
```

In summary: Overlays are functions with two arguments, that describe a
change to a fixpoint, whose final and old state can be accessed via the
two arguments usually called `final` and `prev`, or `self` and `super`
(in older code).

Nixpkgs can be modified with overlays. When doing so, everything which
is not a derivation, for example the script `callPackage`, should
definitely be accessed through `prev` and not `final`!

Overlays are applied as follows:
1. During the evaluation of the NixOS configuration (and only for the
   system packages), the overlays from `nixpkgs.overlays = [/*...*/];`
   are applied.
2. Overlays may be passed explicitly when importing nixpkgs: `import
   <nixpkgs> {overlays = [/*...*/]};`. No other overlays are applied.
3. If `<nixpkgs-overlays>` is set and is a file, it has to contain a
   list of overlays; if it is a directory, its contents are imported in
   *lexicographical order*: A single overlay per import is expected.
4. If `<nixpkgs-overlays>` is not set it tries to fall back to
   `~/.config/nixpkgs/overlays.nix` or a folder
   `~/.config/nixpkgs/overlays`. They may not exist both.

The (above mentioned) option (`nixpkgs.config.`)`packageOverrides` is
like an overlay which only takes the `prev`/`super` argument.

Overlays are sometimes used to make a decision between multiple
**alternative** packages (which implement the same interface):

There are for example multiple implementations of the Message Passing
Interface MPI. Packages using it depend on the generic package `mpi` and
one specifies which provider to use by using an overlay to replace it:
```nix
# ./mpi_overlay.nix
final: prev: { mpi = final.mpich; }
```

BLAS and LAPACK are linear algebra interfaces; packages which use them
shall depend on the generic packages `blas` and `lapack`. Instead of
completely replacing them as in the MPI example above, one needs to
override an attribute of these packages:
```nix
# ./blas_lapack_overlay.nix
# Use Intel's MKL (package mkl) as provider for both blas and lapack:
final: prev: {
    blas = prev.blas.override { blasProvider = final.mkl; };
    lapack = prev.lapack.override { lapackProvider = final.mkl; };
}
```

## Appendix

### Operators

<https://nix.dev/manual/nix/2.18/language/operators> lists the operators
in order of precedence; generally the mathematical precedence is
followed. Note: While function application is listed with one of the
strongest precedences, this does not have effect in list literals,
because they generally disable evaluation of unparenthesized expressions
(except indexing):
```nix
[ builtins.typeOf "a" + "Z" ]   # error: unexpected +
[ builtins.typeOf "aZ" ]        # [ «primop typeOf» "aZ" ]
[(builtins.typeOf "a" + "Z")]   # [ "stringZ" ]
```

Operators and their quirks:
```nix
1 + 2               # add
"hi" + "!"          # concatenate strings
[1 2] ++ [3 4]      # concatenate lists
# literally append the string to the path (never ends in /); return path
~/dir + "file.nix"  # /home/user/dirfile.nix
~/dir + "/file.nix" # /home/user/dir/file.nix
# concatenate paths; return path
~/dir + ./file.nix  # /home/user/dir/home/user/notes-on-nix/file.nix
~/dir + /file.nix   # /home/user/dir/file.nix
# literally prepend to expanded path; path must exist; return string
"~/dir" + /file.nix # error: path '/file.nix' does not exist
"~/dir"+ ./file.nix # "~/dir/nix/store/mvnld3aq3siykz1r7r7z7rcynkn5biwl-file.nix"

- 1                 # negate number
1 - 2               # subtract

2 * 3               # multiply

1 / 2               # 0;    divide two integers -> returns integer!
1 / 2.0             # 0.5;  divide with floating point result
1.0 / 2             # 0.5;  divide with floating point result

# Operators for attribute sets:
s = {attr.path = 1;}
# Indexing -> returns the (fallback) value or throws error
s.attr.path         # 1
s . attr . path     # 1; space around operator allowed
s."attr" . path     # 1; attribute path *elements* may be quoted
s."attr.path"       # error: missing attribute "attr.path"
s."attr.path" or 2  # 2; fallback value
# Membership testing -> returns boolean
s ? attr            # true
s ? path            # false
s ? attr.path       # true
s ? attr."path"     # true; attribute path *elements* may be quoted
s ? "attr.path"     # false
# Update with values from right set; does not change original!
:print s
:print s // { new = 2; }
:print s // { new = 2; attr.path = 3; }
:print s // {attr.new = 3;} # no recursive merging -> removes attr.path
:print s    # unchanged

# Numeric comparisons:
1 < 2               # less than
2 > 1               # greater than
1 == 1.0            # equality; int equals its float version
1 != 2              # inequality
1 <= 1              # less or equal
1 >= 1              # greater or equal
# Strings, paths and lists can be compared to same type:
"/" < "0"           # seems it sorts according to ascii value
"A" < "a"
"a" < "b"
"a" < "aa"
"aa"< "b"
./a < ./b
"a" > ./A           # error: cannot compare path with string
[ "a" "b" ] < [ "a" "c" ]
[ "a" ] < [ "b" "a" ]

# Logic operators (only work with booleans) -> return a boolean
true && true        # AND
false || true       # OR
! false             # NOT
let # (! b1) || b2
    isFalse = false;
    elseThis = false;
in isFalse -> elseThis
# keyword 'or' is not equivalent to || and only valid after indexing
{}.foo or "fallback"
{}.foo || "fallback"    # error
false or true           # error
```

### Dependencies

The list of runtime-dependencies is determined by checking which
dependencies are referenced in the build output. (Sometimes this
includes unnecessary dependencies, which were put into the binary's
runtime path to ensure their correct versions are found, should they be
used. These can be removed with `pathelf` and `strip`.)
```sh
# creates the store-derivation and returns its path
nix-instantiate myderivation.nix

# list *all* dependencies of given store-derivation
nix-store --query --references /nix/store/path/to/file.drv

# builds the given store-derivation and returns its output path
nix-store --realise /nix/store/path/to/file.drv

# lists *runtime* dependencies of given build output from store
nix-store --query --references /nix/store/path/to/build-output

# remove unnecessary runtime-dependencies of a given binary; (this
# should happen after the install phase in a build script, not manually)
patchelf --shrink-rpath '{}' mybinary ; strip '{}' mybinary
```

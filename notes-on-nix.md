status: WIP

---

# Notes on Nix(OS)

Nix is:
1. a programming language
2. a package manager using the nix programming language
3. a linux distribution using the nix package manager

## Overview:

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
a "\*.drv" file in the nix-store. To create it the user calls the
`derivation` function or a wrapper around it. The build process, called
**realisation**, runs in an isolated environment ("sandbox") to ensure
reproducibility on other systems, and uses the instructions from a
"\*.drv" file to produce the build output(s): the **package**.

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

## Nix language

`builtins.langVersion == 6`

`#` **comments** the rest of the line, while `/*` starts a comment which
ends with the next `*/`.

**Whitespace** is generally not significant, thus most code may be
written in a single line. An example where a single space makes a
difference is: `let foo=1; bar=foo -1; bar` (returns the value of bar:
`0`) while the following throws the error "undefined variable 'foo-1'":
`let foo=1; bar=foo-1; bar`.

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

**Set**s are wrapped in braces (`{}`) and define their attributes like a
"let" statement defines its variables, but they can only refer to each
other by the name of the set itself or if the set is preceded by the
keyword `rec`.

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
only take a single argument. Anonymous means they do not have a name,
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
# Make other arguments accessible as variable "other":
let inc = other@{x, y?1, ...}: with builtins; length(attrNames(other));
    in [ ( inc{x=1;y=2;} ) ( inc{x=1;y=2;z=3;} ) ( inc{x=1;z=3;} ) ]
# equivalent:
let inc = {x, y?1, ...}@other: with builtins; length(attrNames(other));
    in [ ( inc{x=1;y=2;} ) ( inc{x=1;y=2;z=3;} ) ( inc{x=1;z=3;} ) ]
```

For manipulating **controlflow** there are the keywords `if`, `then` and
`else` to create conditionals, but none to create loops; use builtins
like `builtins.map` and `builtins.mapAttrs` instead.
```nix
{
    # conditional value
    foo =
        if 3 > 3 then
            "greater"
        else if 3 < 3 then
            "smaller"
        else
            "equal"
    ;

    # using string-interpolation in attribute name (must return string)
    ${"a"+"b"} = "ab";

    # conditionally add attribute using string interpolation
    ${if false then "add key" else null} = "not added";

# string-interpolation in attribute paths:
}.${if true then "foo" else "bar"}
```

For more info about the language see:
<https://nix.dev/manual/nix/2.18/language/>

## Installation

There are many ways to install nixos; this does not describe the
details:

1. Like most other systems, nix may be installed from an iso image:
  - There are ones with a **graphical installer**: one just has to
    follow its instructions.
  - The "minimal" iso file is for **manual installations**:
    Manually installing nixos starts like any other manual install:
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
    Now, install with `nixos-install` and `reboot` if it worked. If it
    failed, fix the config and rerun `nixos-install`. It will prompt for
    a root password.
2. Nixos can be **booted over the internet** with PXE or iPXE. See:
   <https://nixos.org/manual/nixos/stable/#sec-booting-from-pxe>
3. **Temporarily convert some running linux distro into nixos**: Create
   the 3 needed files `./bzImage`, `./initrd` and `./kexec-boot` with
   `nix-build -A kexec.x86_64-linux '<nixpkgs/nixos/release.nix>'` and
   copy them to target computer and run `./kexec-boot` there.
4. **Converting an existing linux installation** (other distro) into a
   nixos system: There is an installation variant called
   "NIXOS_LUSTRATE" which permanently converts a running linux system
   into a nixos system. There, are scripts like "nixos-infect" or
   "nix-in-place" which automate this. Note: This might, in some scripts
   *by design* destroy all data on the machine -- back it up beforehand!

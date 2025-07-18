status: WIP

*These are my notes while learning Nix; they might therefore be
incorrect. I did not try everything described here yet.*

---

**Notes on Nix(OS)**

Nix is:
1. a programming language
2. a package manager using the nix programming language
3. a linux distribution using the nix package manager

# FAQ

## What do I need to know beforehand?

To work with nix, you need a basic understanding how software is usually
built and how bash works; thus this knowledge is assumed here. However,
apart from this, the document (with the exception of the FAQ section)
tries to not refer to concepts it did not at least give an introductory
overview of before. In this attempt it differs from the official docs,
which even (at least in 2024) refer to mathematical topics (fixpoints)
without ever explaining them!

## How to read the official documentation and get help?

0. You might want to start by reading these notes. It's an attempt to
   distill the information from all the different documentation sources
   into one coherent document and explain the missing pieces.
1. Read the official "Nix Pills" article/blog series at
   <https://nixos.org/guides/nix-pills/>. It explains the nix package
   manager and the ideas it is based upon. Check out the `./pills-demos`
   folder of this repo, which contains the code example from the series
   in its different versions.
   The series also contains an article on the basics of the nix
   language; after deciding on learning nix definitely check out the
   full language documentation at
   <https://nixos.org/manual/nix/stable/language/index.html>
2. Read the NixOS manual, to understand how NixOS does things and learn
   about the module system. It contains many examples how to set up
   specific stuff, which you can skip if you don't need it; come back to
   it later, once you do need it.
   <https://nixos.org/manual/nixos/stable/>
3. Read the nixpkgs manual to understand how to create your own packages
   using stdenv and trivial builders, and how to modify packages.
   <https://nixos.org/manual/nixpkgs/stable/>
4. Read about flakes at:
   <https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-flake.html>
5. For help, first look up the examples in the NixOS manual, then see if
   there is an article on the wiki <https://wiki.nixos.org>, and finally
   you can ask for help on <https://discourse.nixos.org>

## Where do I find packages and options?

You can search for packages on <https://search.nixos.org/packages> and
for options on <https://search.nixos.org/options>. The results give a
description, examples and link to the source in the nixpkgs repo.

## What are some drawbacks of nix/NixOS?

- It does not comply with the FHS (Filesystem Hierarchy Standard). While
  this usually is not a problem, should issues arise you have to have a
  very good understanding of nix to resolve them.
- It does not automatically delete old stuff. This allows to easily
  rollback, however, if you are _very_ space constrained it becomes a
  burden, since I find the options to automatically clean up inadequate.
- Updating is slower than on most other distros.
- Build scripts are written in bash, which has very unintuitive syntax;
  casual bash knowledge is not enough to, for example, understand
  parameter expansions. (For this document, advanced bash knowledge
  is not needed.)
- The nix programming language is quite unconventional, so using it
  without studying it first leads to frustration; however it is not hard
  to learn, especially with prior experience with functional languages!
- The nix package manager makes heavy use of the mathematical
  concept of fixpoints, which the documentation does not explain (as of
  2024; fear not: this document explains them thoroughly!). Not
  understanding fixpoints makes it very hard to read nix code and thus
  the nix language gets a bad reputation. However, in reality its lazy
  evaluation makes the nix language exceptionally suitable for
  implementing fixpoints!

# Overview

The idea behind nix is to *declaratively* manage the state of the
operating system: not only which packages are installed, but also which
services are enabled, how programs are configured, etc. Declaratively
means, one states the intended result and the program (nix) figures out
itself, how to achieve that.

Nix uses a hybrid source- and binary-based approach to package
management: Installing a package retrieves build instructions, but only
actually builds it if it cannot find a cached version (either in the
local- or a remote-**cache**).

*Note: Given the name of an executable (but not its path), your shell
looks in every directory named in the PATH environment variable whether
it contains an executable with the given name and executes the first one
it finds. This allows to conveniently run programs without having to
specify their full path.*

*TLDR for the next 2 paragraphs: a profile is a link to a generation,
which is a link to an environment, which is a folder with the links to
executables, which are stored in the nix-store location and made
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
- "nixpkgs-unstable" and "nixos-unstable" (for nix and NixOS users
  respectively; even on NixOS use "nixpkgs-unstable" when setting *user*
  channels) are updated continuously but only use basic tests; failing
  tests can block the entire channel from time to time.
- The stable channels are called "nixos-YY.MM", use more rigorous
  testing, can be used by both, nix and NixOS users, and their packages
  only receive bugfix- and security-updates after the initial release.
  There are usually two stable releases per year.
- The channels called "\*-small" simply have less binary caches. This
  means these channels receive updates faster, however pulling updates
  from them may take longer since more packages have to be built
  locally!
See: Channels

Since channels change over time there is no guarantee that building the
same configuration always produces the same result. Moreover, there is
no standardized way of making the contents of a repo with nix code
discoverable (Does it provide a package, a module, etc?). To fix these
problems nix introduced **flakes** which are officially still
experimental but are already used by most of the community. A flake is a
repo with a `./flake.nix` file which has a certain structure and defines
build outputs, dependencies, etc; a `./flake.lock` file pins the
dependencies to a specific version.

As mentioned, the idea behind nix is not only to install packages in a
declarative way, but also to declaratively configure them. This works
well if these programs are configured globally, but not so much for
programs configured in the user's HOME folder, which nix (with a few
exceptions) does not touch. Configuring a program in the HOME folder is
still possible without any issues, however doing this manually is not in
the spirit of a fully declarative system, which is why there is a
solution by the nix community called "**home-manager**". Home-manager as
a nix module integrates well with the rest of a NixOS configuration,
however _it does overwrite_ the relevant configuration files in HOME.
It will not be covered in this document and is not relevant to
understanding nix.

Nix comes with a simple way of running virtual NixOS instances: **NixOS
containers**. They share the host's nix store, which makes creating such
containers efficient, but has the downside that the container's root can
modify the host. As these are not intended for sandboxing applications
for security purposes, this is ok, but should be kept in mind!

# Nix language

`builtins.langVersion == 6`

*To experiment with the nix language use `nix repl` which starts an
interactive session!*

Nix is a **pure, functional** language. Functions are values and every
function returns a value. There are generally no side-effects:
`builtins.trace`, the function to display a value and only function
which therefore could be considered to have a side-effect, takes an
explicit second argument which is used as the return value.

Nix is **lazily evaluated**, meaning it does not run parts of code whose
value it does not currently need. For example, the contents of a list
within another list will not be evaluated until accessing them. This
means placing `builtins.trace` in the inner list, won't display the
value it wraps, until the inner list evaluates due to being accessed.

The interactive session, `nix repl`, provides a special command `:print`
to recursively evaluate and display the following expression. Repl
specific commands start with ":" and can be listed with `:help`; using
them _within_ other nix code throws a `syntax error, unexpected ':'`.

`#` **comments** the rest of the line, while `/*` starts a comment which
ends with the next `*/`.

**Whitespace** is generally not significant, thus most code may be
written in a single line. An example where a single space makes a
difference is: `let foo=1; bar=foo -1; in bar` (returns the value of
bar: `0`) while the following throws the error "undefined variable
'foo-1'": `let foo=1; bar=foo-1; in bar`.

The nix language requires each file (nix files use the extension ".nix")
to contain *only a single* "**nix-expression**", which is something that
results in a value. This value is returned when loading a file with
function `import`. See also below: paths

_Many codeblocks in this document represent the input of an interactive
session -- not the contents of a nix file. Executing a file containing
the whole codeblock throws an error if it contains multiple
nix-expressions or repl specific commands (`:print`) or syntax (global
assignments)!_

`builtins.typeOf` returns the type of a value as a string:

- **"int"** (integer number): `1`
- **"float"** (floating point number): `3.14`
- **"bool"** (boolean/truth value): `true` and `false`
- **"null"**: `null` (called "nil" nor "none" in some languages)
- **"string"**:
  ```nix

  # URIs are recognized as strings; this is deprecated!
  asdf://example.com    # equivalent to the string: "asdf://example.com"

  "
    strings are not single quoted (')
    strings may span multiple lines
    double quoted strings keep their starting line
    double quoted strings keep all leading whitespace"

  "\\ \"toggles\" special character meaning: \n\\\" \n\\n \n\\r \n\\t"

  # concatenating strings; embedding expressions (string-interpolation)
  "use \${} for string-interpolation 10+1=${"1"+"1"}"
  # "10+1=${builtins.toString(10+1)}"

  ''
      strings wrapped in *double* single quotes:
      escape every \ thus:
        - tabs and newlines must be written	literally	
        - string-interpolation cannot be disabled: \${"foo" + "bar"}
      ignore the starting line if it only consists of whitespace
        remove (only) the *common* *leading* whitespace from each line  
      whitespace-only lines like the following line of 2 spaces...
    
      ...do not contribute to the calculation of the common whitespace
      ...get shorter by the number of common whitespace characters
      a whitespace-only final line always becomes a single newline
        ''
  ```
- **"path"**: Careful: Using paths copies it to the nix-store location!

  Paths are unquoted, do not contain "://" (which would make it a URI,
  that is: a string), and have at least one "/" which must not be in the
  last position:
  ```nix
  ./relative-path               # relative to the file it is used in
  ../path-in-parent/folder      # must not end in /
  /absolute-path
  ./.                           # current folder
  /.                            # root folder
  ~/.                           # home folder
  ```

  **Lookup paths** are also paths, but denoted in a shorthand notation:
  `<name>`. It works similar to the shell's lookup of commands in the
  PATH environment variable, but uses the NIX\_PATH variable instead
  which may contain entries prefixed with "name=" which then are not
  searched recursively but are the exact result to return when queried
  for "name". Note: If a previous entry already matched the given name
  (and exists) or the named entry does not exist, the named entry is not
  the one returned! Lookup paths should be avoided as they are impure
  (=not reproducible because they depend on the value of NIX\_PATH).

  In the common code snippet `import <nixpkgs> {}`
  - `<nixpkgs>` represents the path to the local copy of nixpkgs and is
    therefore a directory
  - Importing this directory works because it contains a file
    `./default.nix` which is loaded instead. It returns a function which
    returns the nixpkgs package set.
  - `{}` is a set (see below) and the argument this function. It could
    be used to customize the returned package set, but here it is not.

- **"list"**: `[1 "two" 3 4]` No comma between elements!
- (attribute-)"set": `{ foo = "bar"; }` What other languages call
  "(hash-)map", "dictionary" or "table". See below.
- "lambda" (function): `arg : arg + 1` Indeed, functions may be used as
  values. See below.

Nix does not have global assignments, however, they are allowed in the
repl for convenience. Instead, variable definitions are wrapped in a
**let expression**, which defines the local scope for the subsequent
expression. As nix is lazy, meaning it only computes values (including
sub-members of sets) when they are needed, the definitions of a "let"
expression may be out of order!
```nix
let b = a + 1 ;     # the order in this block is not significant
    a = 1 ;         # semicolons are required
in a + b            # no semicolon here (would be error)
```

Recursive definitions are allowed. This means an expression has access
to its own name, which is useful in sets to refer to siblings or for
recursive functions like:
`factorial = arg : if arg <= 1 then 1 else arg * factorial (arg - 1);`
See also: fixpoint
```nix
let
    a = a + 1;      # "infinite recursion"- not "unknown variable"-error
in a                # only once used -> evaluated -> error
```

**Set**s are wrapped in braces (`{}`) and define their attributes like a
"let" expression defines its variables, but they can only refer to each
other if the set is preceded by the keyword `rec` or by indexing the set
itself. Once again: the order of the members is irrelevant even when
referencing each other.

Attribute-names must be strings; however, the quotes for identifier-like
ones may be omitted. When indexing sets, attribute-names, but not the
indexed set itself, may be quoted if necessary:
`mustNotBeQuoted."quotes required".noQuotesNecessary`. This means, using
the `rec` keyword to be able to refer to sibling attributes without
having to index the ancestor itself, is useless if the siblings do
not have identifier-like names:

```nix
:print let
    mustNotBeQuoted = rec {
        "quotes required" = rec {
            # referring to later defined member is ok:
            foo = noQuotesNecessary + 1;    # accessing sibling directly
            noQuotesNecessary = 1;
        };
        # cannot index a string
        error = "quotes required".noQuotesNecessary + 1;
        just_a_string = "quotes required";
        # despite using rec, due to the name we must index from parent:
        ok = mustNotBeQuoted."quotes required".noQuotesNecessary + 1;
    };
in mustNotBeQuoted
```

In nix, one cannot reassign a name, thus it is clear that assigning to
the same set again shall extend the set's current value. Moreover,
missing sets are auto-created, when being assigned to, but accessing a
missing set throws an error which can be be suppressed by providing a
fallback value with keyword `or`:
```nix
let foo.a.b = 1;                    # creates missing sets foo and foo.a
    foo = { c = 3; };               # extends foo
    bar = {a = { b = 1;}; c = 3;};  # equivalent to foo
in [ (foo==bar) foo.a.b (foo.a.b.c.d or "missing") ]
```

Nix wants everything to return a value, thus it
**does not have loops**; instead, use one of the builtin functions,
for example `builtins.map` and `builtins.mapAttrs`, which iterate over
list- and set-elements respectively and produce a concrete result.

For the same reason **conditionals** must have an else-block!
String-interpolation works in attribute names as well as attribute paths
(`s.${"foo.bar"}` is `s."foo.bar"`, not `s.foo.bar`); which can be used
to conditionally add items by returning `null` if it should be omitted:
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

Instead of assigning named values to the same name in a set, the
**"inherit(from)" expression** may be used.
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
} # { foo = 1; bar = 2; foobar = 3; fizz = "buzz"; }
```

The **"with" expression** adds the attributes of a set to the local
scope, except when there would be a name collision:
```nix
let bar = 1;
    foo = { bar = 100; baz = 200; };
in
    with foo;               # only one set allowed, semicolon required
        {
            a = bar;        # 1
            b = foo.bar;    # 100
            c = baz;        # 200
        }                   # no semicolon here
```

Nix **function**s are anonymous (so called "lambdas") closures which
take exactly one argument. Anonymous means they do not have a name;
but as they are values, they may be bound to a name in the usual way.
Closure means a function knows about variables in its parent scopes from
the time it was defined. This lets one implement multi-argument
functions by nesting functions: The body goes into the innermost
function, which takes the last argument and is returned by another
function which takes the second to last argument, and so on; this is
called "currying".

_Note: The term **closure** is also used by nix in reference to all the
packages a package depends on (as well as the packages they depend on,
etc). Build-dependencies and runtime-dependencies may differ; if not
specified "package closure" usually only means the runtime dependencies.
See also: Dependencies_

```nix
# Functions do not need parentheses to execute:
with builtins; length                   # returns a function
with builtins; length [1 2 3]           # returns the result 3
# Exception: in a list functions only evaluate when parenthesized:
with builtins; [ length [1 2 3] ]       # contains function and list
with builtins; [ (length [1 2 3]) ]     # contains integer

# Define a function with 1 argument; function bodies are are always a
# single expression which produces the return value:
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

Default arguments may refer to other arguments; this is often used
when writing packages invokable with `nix-build`:
```nix
# nix-build invokable packages must provide default arguments:
{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, stdenv ? pkgs.stdenv # indexes whichever value pkgs ultimately has
}:
stdenv.mkDerivation {/*...*/}
```

**Callable sets** are sets which can be invoked like functions. They
have an attribute `__functor` which has to be callable and take at least
two arguments of which the auto-supplied first one is the set itself.
The example also shows how to use string-interpolation in attribute
paths as **switch expression**:
```nix
let
    state = {
        __functor = self: action:
            {
                inc = self // { state = (self.state or 0) + 1; };
                dec = self // { state = (self.state or 0) - 1; };
            }.${action} or (throw "invalid action")
        ;
    };
in ((state "inc") "inc") "dec"
```

<https://nix.dev/manual/nix/2.18/language/operators> lists the operators
in order of **precedence**; generally the mathematical precedence is
followed. Note: While function application is listed with one of the
strongest precedences, this does not have effect in list literals,
because they generally disable evaluation of unparenthesized expressions
(except indexing):
```nix
[ builtins.typeOf "a" + "Z" ]   # error: unexpected +
[ builtins.typeOf "aZ" ]        # [ «primop typeOf» "aZ" ]
[(builtins.typeOf "a" + "Z")]   # [ "stringZ" ]
```

**Operators** and their quirks:
```nix
1 + 2               # mathematical addition
"hi" + "!"          # concatenate strings
[1 2] ++ [3 4]      # concatenate lists
# literally append the string to the path (never ends in /); return path
~/dir + "file.nix"  # /home/user/dirfile.nix
~/dir + "/file.nix" # /home/user/dir/file.nix
# concatenate paths; return path
~/dir + ./file.nix  # /home/user/dir/home/user/notes-on-nix/file.nix
~/dir + /file.nix   # /home/user/dir/file.nix
# literally prepend to resolved path; path must exist; return string
"~/dir" + /file.nix # error: path '/file.nix' does not exist
"~/dir"+ ./file.nix # "~/dir/nix/store/mvnld3aq3siykz1r7r7z7rcynkn5biwl-file.nix"

- 1                 # negate number
1 - 2               # subtract

2 * 3               # multiply

1 / 2               # 0;    divide two integers -> returns integer!
1 / 2.0             # 0.5;  divide with floating point result
1.0 / 2             # 0.5;  divide with floating point result

# mathematical precedence
2 + 3 * 4           # 14
    3 * 4 + 2       # 14
(2+ 3)* 4           # 20

# Operators for attribute sets; see also: Comparison operators
s = {attr.path = 1;} # equivalent to: s={attr={path=1;};}
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

# Comparison operators:
1 < 2               # less than
2 > 1               # greater than
1 == 1.0            # equality; int equals its float version
1 != 2              # inequality
1 <= 1              # less or equal
1 >= 1              # greater or equal
# Strings and paths can be compared to same type; lexicographically
# meaning item-wise according to ASCII value:
"/" < "0"           # due to ASCII order
"9" < ":"           # due to ASCII order
"B" < "a"           # any uppercase before any lowercase
"a" < "b"           # alphabetic order
"a" < "aa"          # item-wise thus shorter wins over longer
./a < ./b           # comparing paths works the same
"a" > ./A           # error: cannot compare path with string
# Lists and Sets are recursively evaluated before comparison
{ a.b=2; } == { a={b=(1+1);}; } # there is no order in sets
[ 1 2.0 ] == [ 1 2 ]
[ 1 2.0 3 ] != [ 1 2 ]
# Sets only allow the in/equality operators; Lists allow to other
# comparisons in lexicographical order but according to type
 "2.0"  >  "2"  # true
["2.0"] > ["2"] # true
[ 2.0 ] > [ 2 ] # false because numbers are compared numerically
["2.0"] > [ 2 ] # error: cannot compare string with integer
[ 1 ] < [ 1 1 ] # true because lexicographical order (like "a"<"aa")

# Logic operators (only work with booleans) -> return a boolean
true && true        # AND
false || true       # OR
! false             # NOT
# IMPLY: if first is true second must be too; aka: (! b1) || b2
false -> true       # if first is false: no implication thus true!
true -> false       # of all 4 possible combinations only this is false
# keyword 'or' differs from operator || and is only valid after indexing
{}.foo or "fallback"
{}.foo || "fallback"    # error
false or true           # error
```

As the examples already indicated, most builtins are not available in
the global namespace and have to be accessed via the set `builtins`.
Documentation at: <https://nix.dev/manual/nix/2.18/language/builtins>

Another common set of functions is the standard library from nixpkgs.
Documentation at:
<https://nixos.org/manual/nixpkgs/stable/#sec-functions-library>
The documentation makes it look like the standard library only exposes
other libraries, however, actually it also exposes functions *directly*!
See the `inherit` expression at:
<https://github.com/NixOS/nixpkgs/blob/master/lib/default.nix>

# Installation

Optionally see also: Creating a custom NixOS installation medium

## Only installing the nix package manager

The nix package manager can be installed

1. for a **single user**, meaning (only) the user owning `/nix` can
   manage nix. This might be convenient if one does not want to use root
   privileges, but a malicious build could access a user's home.
2. for **multiple users**, meaning root owns `/nix`. Global builds,
   require special privileges, cannot access users' homes, and are
   available to all users. Unprivileged users may install packages for
   themselves, but not pre-built binaries.

## Installing NixOS from an .iso

Like most other systems, nix may be installed from an iso image. The iso
needs to be burned to a CD or a flash drive to boot from. Make sure the
bootloader of the target machine does not have Secure Boot enabled and
does not prioritize another boot option over the one you chose (for
example it might prefer the internal disk over the CD you burned the iso
to).

- There are ones with a **graphical installer**: one just has to
  follow its instructions.

- The "minimal" iso file is for **manual installations**: Manually
  installing NixOS starts like any other manual install: setup the
  keyboard (with `loadkeys`) and networking (with `wpa_cli` from
  wpa\_supplicant); then create partitions (available tools: `parted`,
  `fdisk`, `gdisk`, `cfdisk`, `cgdisk`) with appropriate labels (which
  depends on BIOS or UEFI setup and preference) and format them
  accordingly (with "mkfs.\*" and "mkswap"). Mount root partition on
  `/mnt`, mount boot partition on `/mnt/boot`, (activate swap
  partition,) and generate a config file in `/mnt/etc/nixos/`
  (`nixos-generate-config --root /mnt`).
  ```bash {.summary}
  sudo su

  loadkeys de-latin1

  # uefi is possible if the file exists; number is for x64 or IA32 UEFI
  cat /sys/firmware/efi/fw_platform_size

  # setup wifi if necessary
  systemctl start wpa_supplicant
  wpa_cli # starts a repl

  # partitioning; create a GPT table (not MBR)
  lsblk # show partitions; path is name appended to /dev/
  # wipefs -a /dev/sdX # erase disk if necessary to create new GPT table
  cfdisk /dev/sdX # tui partitioning tool

  # create appropriate filesystems
  lsblk # show new paritions
  mkfs.fat -F 32 -n boot /dev/sdXX
  mkfs.ext4 -L nixos /dev/sdXX
  # swapon /dev/sdaXX

  # mount partitions
  mount /dev/disk/by-label/nixos /mnt
  mkdir -p /mnt/boot
  mount -o umask=077 /dev/disk/by-label/boot /mnt/boot
  ```

  After generating a config file `/mnt/etc/nixos/configuration.nix`,
  modify it to your liking using `nano` or `vim`.
  ```bash {.summary}
  nixos-generate-config --root /mnt
  cd /mnt/etc/nixos
  nano configuration.nix
  ```

  See: Essential NixOS Configuration Snippets

  Afterwards, install with `nixos-install`, then `reboot` if it worked.
  If it failed, fix the config and rerun `nixos-install`. It will prompt
  for a root password.

## Installing NixOS over the internet

NixOS can be **booted over the internet** with PXE or iPXE. See:
<https://nixos.org/manual/nixos/stable/#sec-booting-from-pxe>

## Installing NixOS on a running system

- **Temporarily convert some running linux distro into NixOS**: Create
  the 3 needed files `./bzImage`, `./initrd` and `./kexec-boot` with
  `nix-build -A kexec.x86_64-linux '<nixpkgs/nixos/release.nix>'`,
  copy them to the target computer and run `./kexec-boot` there.

- **Converting an existing linux installation** (other distro) into a
  NixOS system: There is an installation variant called "NIXOS\_LUSTRATE"
  which permanently converts a running linux system into a NixOS system.
  There are scripts like "nixos-infect" or "nix-in-place" which
  automate this. Note: This might, in some scripts *by design*, destroy
  all data on the machine -- back it up beforehand!

# Essential NixOS Configuration Snippets

This section provides important notes for the most fundamental aspects
of your NixOS config.

Using a graphical installer, you will not interact
with the config files until after the installation, at which point the
files we are talking about will be located in `/etc/nixos` not
`/mnt/etc/nixos` and need to be activated differently: see NixOS
configuration

* Keep the `system.stateVersion` value unchanged. This value does not
  specify which version of NixOS is currently used, but which was the
  first version used on this machine! It is used to set default
  versions of some packages which write application data and cannot
  handle upgrading it after being updated to newer versions.
  To change (upgrade) your current NixOS version see: Channels
* Mounting should have been configured by `nixos-generate-config`
  and written to `/mnt/etc/nixos/hardware-configuration.nix`. Make
  sure it is loaded:
  ```nix
  imports = [ ./hardware-configuration.nix ];
  ```
  Also make sure the appropriate kernel modules are enabled in
  the `boot.initrd.kernelModules` option to be able to mount
  certain special file systems!

* Configure boot loader:
  ```nix
  # EITHER: your machine uses BIOS -> then use grub:
      boot.loader.grub.device = "/dev/DISK_TO_INSTALL_GRUB_TO";
      boot.loader.grub.useOSProber = true;

  # OR: your machine uses UEFI
      # defaults to /boot
      boot.loader.efi.efiSysMountPoint = "/YOUR_BOOT_PARTITION";

      # -> you have the choice between grub and systemd-boot:
      # EITHER: systemd-boot
          boot.loader.systemd-boot.enable = true;

      # OR: grub (cannot be used to dual-boot *linux* distros)
          boot.loader.grub.device = "nodev"; # this is a special value
          boot.loader.grub.efiSupport = true;
          boot.loader.grub.useOSProber = true;
  ```

* Configure network:
  ```nix
  networking = {
      hostName = "YOUR_MACHINE";
      networkmanager.enable = true;
      # Note: when defining users, make sure to add "networkmanager"
      # to their extraGroups attribute

      firewall.enable = true;
      # firewall.allowedTCPPorts = [];
      # firewall.allowedUDPPorts = [];

      # runs the provided shell script after network setup:
      #localCommands = ''
      #    get_my_wpa_config_with_passwords > /etc/wpa_supplicant.conf
      #    systemctl restart wpa_supplicant.service
      #'';
  };

  ```

* Set the console keymap correctly, otherwise the password is hard (or
  even impossible) to enter correctly!
  ```nix
  console.keyMap = "de-latin1"; # german keyboard
  ```

* Install some packages. The easiest way to look for packages is
  <https://search.nixos.org>, which also links to the package source,
  that reveals additional build options. See below: Packages
  ```nix
  environment.systemPackages = with pkgs; [
    git
    # to play DRM content chromium needs to be built with WideVine:
    (chromium.override { enableWideVine = true; } ) # a web browser
  ];
  ```

* To enable services or configure something about a service or program
  apart from the package's build options, use
  `services.NAME = { enable = true; }; ` and
  `programs.NAME = { enable = true; };` instead. Not every package has
  such configuration options. These options automatically add the
  relevant packages to `environment.systemPackages`. For example, to
  find out about the available options for the avahi service and the
  vim text editor, go to <https://search.nixos.org/options> and search
  for "avahi" and "vim"; you will see that there are options
  "services.avahi" and "programs.vim"; now search for these terms and
  you will see all their available configuration fields. This example
  uses some of them:

  ```nix
  programs.vim = { # a text editor
      enable = true;
      defaultEditor = true; # sets environment variable EDITOR=vim
  };

  services.avahi = { # discover devices like printers on your network
      enable = true;
      openFirewall = true; # opens UDP port 5353
  };
  ```

* A user may be added like so:
  ```nix
  users.users.YOURUSER = {    # yes, twice the plural
      initialPassword = "change_me_with_passwd"; # world readable!
      isNormalUser = true;
      extraGroups = [
          "wheel"             # allows using sudo
          "networkmanager"    # allows configuring networkmanager
      ];
  };
  ```
  To disable root, set `users.users.root.hashedPassword="!";` and make
  very sure that a user has `sudo` access and an `initialPassword`,
  and that the `console.keyMap` is set correctly.

# Profiles

The terms "profile" and "environment" (see above) are often used loosely
to describe the concept of an environment with versions; in reality
profiles are just links, and environments only know about themselves and
not other versions.

Some commonly used profiles are:
- `/nix/var/nix/profiles/system`: the global profile used by the NixOS
  configuration, for example for packages installed via option
  `environment.systemPackages`. This profile is different from:
- the root user's profile: `/nix/var/nix/profiles/per-user/root`
- `/etc/profiles/per-user/USERNAME` is the user specific profile used
  by the NixOS configuration, for example for package installed with
  the option `users.users.USERNAME.packages`. This profile is different
  from:
- `~/.nix-profile`: the user specific profile used when installing
  packages imperatively with `nix-env` and (usually links to
  `~/.local/state/nix/profiles/profile`)

See also: Imperatively installing packages

# Channels

See also above: channels

As described above, nixpkgs, the default package source, is organized
into release branches, called channels. **Setting channels must be done
imperatively; there is no config option to do so declaratively!**

Root's "nixos" channel is automatically refreshed when passing
`--upgrade` to `nixos-rebuild switch`; passing `--upgrade-all` also
refreshes _root_'s other channels, but not _user_ channels which are
refreshed with `nix-channel --update`. Refreshing a channel just means
to download a new version of its package and option definitions.

On NixOS change the "nixos" channel of the root user to affect which
channel your config uses!

```bash
# A user imperatively installs a package from a specific channel
nix-env -iA nixos.neovim

# Why did it work despite the user's channels not showing a "nixos" one?
nix-channel --list      # probably no channels configured yet
# because root has a channel of this name which was used as fallback:
sudo nix-channel --list

# To upgrade NixOS to a new release, or even become rolling release,
# change root's "nixos" channel and rebuild the system
sudo nix-channel --add https://nixos.org/channels/nixos-25.05 "nixos"
sudo nix-channel --update "nixos"   # downloads/refreshes this channel
sudo nixos-rebuild switch

# Instead of making your NixOS installation rolling release, which means
# your config breaks every time an option you used changes upstream, I
# recommend giving your local user the unstable channel and manually
# installing packages whose newer version you really need from there:
nix-channel --add https://nixos.org/channels/nixpkgs-unstable "nixpkgs"
nix-channel --update "nixpkgs"  # downloads/refreshes channel
nix-channel --list              # shows the new channel "nixpkgs"
nix-env -iA nixpkgs.neovim      # uses our new channel
nix-env -iA nixos.neovim        # still falls back to root's channel

# Let's remove the current user's channel called "nixpkgs"
nix-channel --remove "nixpkgs"
```

# Imperatively installing packages

*See also: unfree packages.*

NixOS is managed via a configuration file, in which one can define,
among other things, which packages shall be installed. The nix package
manager may also be invoked like a traditional package manager from the
commandline, but one should keep in mind that it still acts differently
(see: generations, garbage-collection, profile)!

Managing the current user's profile does not require elevated
privileges. The examples use the command `nix-env`, because its
successor `nix profile` is still experimental; do _not_ invoke `nix
profile` unless you read its documentation and want to switch to using
it instead: after using it your `nix-env` installed packages will not be
available and you cannot use `nix-env` anymore.

```bash
# --query or -q lets you list installed packages and find new ones
nix-env --query             # lists all packages installed with nix-env
nix-env --query --available REGEX   # short flags: -qa
# if packages are listed multiple times, they might differ in the
# version or are available from different channels (see below)

nix-env --list-generations  # a generation is basically a snapshot

# --install or -i installs new packages by creating a new generation
nix-env --install REGEX     # or with a specific version: REGEX-1.2.3

nix-env --list-generations  # you should see new generation was created

# to avoid regex matching all package names, use -A/--attr on a
# specific package set's alias (channel name); by default available:
# on nixos: "nixos", on other systems: "nixpkgs"
nix-env -i -A CHANNELNAME.PKGNAME

# --uninstall or -e creates a new generation without the given packages
nix-env --uninstall REGEX

# the removed package is still available in the previous generation:
nix-env --rollback  # activate generation with highest id < current_id
# it is also possible to go to a specific id, which is listed by running
nix-env --list-generations    # first column is the id
nix-env --switch-generation 2 # activates generation with id 2

# delete specified generations or all except current by specifying "old"
nix-env --delete-generations 1 3
nix-env --delete-generations "old" # incl newer than current generations
# NOTE: still nothing is actually removed! now run: nix-collect-garbage

# --upgrade or -u creates a new generation replacing all or the
# specified packages with newer ones
nix-env --upgrade PKGNAME

# --upgrade does not respect which channel a package came from, thus if
# another channel provides a newer version it is installed; however
# using the command to set metadata, --set-flag, a package can be pinned
nix-env --set-flag keep true PKGNAME # prevents upgrade
```

## Installing packages temporarily

`nix-shell` starts a subshell which has the specified packages from
nixpkgs available:

```sh
echo hi | cowsay | lolcat           # 2x error: command not found
nix-shell --packages cowsay lolcat  # or -p; correct names not regex
# now in the subshell: (> is prompt)
> echo hi | cowsay | lolcat         # ok
> exit
# after exiting the subshell:
echo hi | cowsay | lolcat           # commands not available anymore

# To avoid an interactive subshell use:
nix-shell -p cowsay lolcat --run "echo hi | cowsay | lolcat"
```

After exiting the temporary environment the installed packages are not
available anymore, however, they are still in the store until the next
time garbage-collection runs, so running the same `nix-shell` command a
second time should be much faster, than the first time!

## Nix scripts

Instead of requiring the user to install needed dependencies before
running a shell script, there are nix scripts, which only require the
user to have nix installed and use `nix-shell` to pull the needed
dependencies themselves!

To write such a script replace shebang lines like `#!/bin/bash` with
`#!/usr/bin/env nix-shell`. The following lines starting with
`#! nix-shell` are merged into a single call to `nix-shell` and define
the environment;
* `--pure` unsets most environment variables and sets PATH to only
  contain the packages for this environment and some ones available in
  all nix build environments
* the interpreter to use is specified with `-i`;
* `--packages` installs the given dependencies.
* For even more reproducibility use `-I nixpkgs=` to specify a certain
  release of nixpkgs.

```bash
#!/usr/bin/env nix-shell
#! nix-shell --pure -i bash
#! nix-shell --packages bash cowsay
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/0672315759b3e15e2121365f067c1c8c56bb4722.tar.gz

{ echo "Due to '--pure' PATH only contains:"
  echo -e "${PATH//:/'\n'}"
} | cowsay -W 100
```

To run the script, just make it executable as usual with
`chmod u+x ./myscript` and invoke it: `./myscript`

# Ephemeral environments

Instead of typing out the command to activate a temporary environment,
one can define the environment in a nix file and simply activate it with
just `nix-shell`, which expects a file `./shell.nix` (or as a fallback
`./default.nix`), or `nix develop` if you want to write it as a
`./flake.nix`.

The important helper here is `pkgs.mkShellNoCC` (or `pkgs.mkShell` which
comes with a C compiler as default dependency). See:
<https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-mkShell>

```nix
# put this into ./shell.nix; then run `nix-shell`
let
  pkgs = import <nixpkgs> {};
  # for more reporducibility be more specific:
  # nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-23.11";
  # pkgs = import nixpkgs {};
in pkgs.mkShellNoCC {   # creates a shell without c compiler toolchain
    # packages to install, no need to specify bash:
    packages = with pkgs; [ cowsay ];
    # commands to execute upon activating the environment:
    shellHook = ''
        echo "$MYVAR" | cowsay
        # set variables which cannot be set as nix set-attributes:
        export PS1="> "
    '';
    # set environment variables (if not possible set them in shellHook)
    MYVAR = "Welcome in your temporary bash environment!";
}
```

In a project with a nix package definition `./default.nix`, you do not
even have to write a `shell.nix`: if your package builds with
`nix-build` then you can simply run `nix-shell` instead and will be
dropped into the build environment of your package; now you can invoke
its build steps manually.

# NixOS configuration

This section explains how configuring NixOS works -- not which options
to set. See: Essential NixOS Configuration Snippets; for some examples.

The main configuration file (itself a module, see: Modules) is
`/etc/nixos/configuration.nix` and usually (for example when generating
a new configuration with `nixos-generate-config`) hardware-specific
options are put into their own module
`/etc/nixos/hardware-configuration.nix`, which allows to use the same
main configuration file on different machines.

While `/etc/nixos/configuration.nix` is written as a module,
typically it just looks like a function returning a set whose
attributes are the option names and their values are how you want to
configure the option:
```nix
{ pkgs, ... }:
{ imports = [ ./path/to/some/module.nix ];
  optionName = optionValue;
  environment.systemPackages = [ pkgs.PKGNAME ];
}
```

_Which configuration options and packages are available depends on
root's "nixos" channel which can only be changed imperatively! See:
Channels_

If a file `/etc/nixos/flake.nix` exists, it takes precedence over
`/etc/nixos/configuration.nix`, which allows to turn the configuration
into a flake (see: Flakes).

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

Note: Installation of **unfree packages** cannot be enabled globally:
For the config (and the root user) it is done with option
`nixpkgs.config = { allowUnfree = true; };`. _Other users_ must put
this set into file `~/.config/nixpkgs/config.nix` to enable unfree
packages for all their actions or set environment variable
`NIXPKGS_ALLOW_UNFREE=1` to enable them for a specific action.

## Modules

The NixOS modules system allows to use many different files to declare
(=create) and define (=use) so called options (see below) while still
keeping a unified state. To make this work, loading the different
modules (=configuration parts) must be handled by the modules system and
cannot simply be done using the builtin `import` function.

Instead, the module system automatically loads most of the "in-tree"
modules located in the **modules directory** `<nixpkgs/nixos/modules>`
because they are listed in `<nixpkgs/nixos/modules/module-list.nix>`
and "out-of-tree" modules are either loaded because they are the root of
the configuration (for example `/etc/nixos/configuration.nix`) or, for
example when including `/etc/nixos/hardware-configuration.nix`,
because their path was listed in the loading module's "imports" field
(see below). As with the `import` function, it is allowed to just
specify the directory name for files called `default.nix`.

Modules are attribute sets with a certain structure or functions
returning such.

The structure is as follows:
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

When a module is a function, like the typical configuration.nix whose
structure is shown above, the module system invokes it with the
following named arguments:

- `pkgs`: This provides access to nixpkgs.
- `lib`: This provides access to the **nixpkgs standard library** in a
  *safe* way; contrary to using `pkgs.lib` (essentially
  `import <nixpkgs/lib>`), which might result in an infinite recursion.
- `modulesPath`: The location of the modules directory (see above).
- `config`: All option-definitions; including the options set by the
  module itself, which works (as long as no option references itself)
  because nix is lazily evaluated. (see: Options)

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

Moreover, the module system injects some **utility functions** into the
namespace of each module; see: Options,
<https://github.com/NixOS/nixpkgs/blob/c45e6f9dacbe6c67c58a8791162cbd7e376692fa/lib/modules.nix#L1396>.

### Options

Use `nixos-option name.of.option` to query an option's currently active
value, where it was declared and where it was defined.

Options can only be used when the module that declared them was loaded
(see above).

An option is called by the name used when it was declared in a module's
"options" field. Often this is an attribute path consisting of
option-category (just a convention, see: <https://mynixos.com/options>),
name (as used in in `<nixpkgs/pkgs/top-level/all-packages.nix>`) of the
package it comes from, and specific name. When accessing an option's
final definition or its declaration, this attribute path is used to
index the module's `config` or `options` argument.

For details how to create options see:
<https://nixos.org/manual/nixos/stable/#sec-writing-modules>, the
following is an abstract:

Depending on whether an option has a default value, **not defining it**
may be an error or not.

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

The following example shows 3 modules, one which creates 2 options
(category.some-package.optionName and category.some-package.enable), one
which uses these options normally and another one which overrules the
other declarations.

```nix
# This is ./some-module.nix

# the nixpkgs-stdlib is needed; don't access it via pkgs.lib but via lib
{ lib, ... }:
{
    options = {

        # Use lib.mkOption ...
        category.some-package.optionName = lib.mkOption {
            type = lib.types.listOf lib.types.singleLineStr;
            description = "Markdown description of *this* option";
            default = [];
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
# this module doesn't use the optional simplified structure
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
# this module does use the optional simplified structure
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

# Packages

The above definitions differentiated between "package" and "derivation",
not because the documentation does so (in fact, it uses the terms almost
interchangeably), but because the target audience, new nix users, likely
has the presumption, that packages are binaries which the package
manager downloads and puts in the right places on the system. This is
not how nix works, but in some cases effectively what it does, if the
term package is understood as build output. Actually, nix downloads
build instructions (derivations) and checks whether it can find a cache
of their result: if it does, it simply downloads the cached binary and
installs it (to the nix-store); if it does not, it builds locally.

*Note: Indeed, nix packages are installed to the nix-store and not the
usual locations (like `/bin`). This is usually fine, as in
nix-expressions, it is easy to refer to nix-store locations (see next
example), and when using the standard build environment (see below) PATH
is set up fittingly and shebangs are patched appropriately. However, for
the user it can be hard to reliably refer to specific files, since their
location might change with every system update. This is why many files,
mainly those under `./bin`, from the build results of the currently
active global profile are linked into `/run/current-system/sw`. To
__expose files__ which are not by default, specify their path in this
NixOS option like so:
`environment.pathsToLink = ["/share/foot/themes"];`; this would make the
themes for the foot terminal shipped with the package `foot.themes`
available under `/run/current-system/sw/share/foot/themes` regardless of
the actual nix-store location.* See also: FHS compatible "sandboxes"

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
            pkgfn (
                # takes those items from second arg which have same name
                # as an item from first arg (functionArgs returns set):
                (intersectAttrs (functionArgs pkgfn) pkgs)
                // args # update with user supplied args
            )
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
overridable (see: Modifying packages), and a top level `callPackage`
which uses nixpkgs as the default package set.

If nixpkgs does not have a package (because there is no derivation
describing it), it can be added in two ways:
1. **In-tree**: This means to create a local copy of the nixpkgs repo,
   add the derivation to it and use this local version. (`nixos-rebuild
   switch -I nixpkgs=./nixpkgs`)
2. **Out-of-tree**: Instead of adding the derivation to a local copy of
   nixpkgs, it is specified in-place when used:
   ```nix
   # /etc/nixos/configuration.nix
   { pkgs, ... }: {

       # this only effects this expression
       environment.systemPackages = let
           in-place-created = pkgs.stdenv.mkDerivation { /*...*/ };
           using-pkgfn = pkgs.callPackage ./my-pkg.nix {};
           modified-package = pkgs.some-package.override { /*...*/ };
       in [ in-place-created using-pkgfn modified-package ];

       # This effects these packages from nixpkgs, config-wide.
       # The argument prev is just pkgs before applying these overrides.
       # see: overlay-like functions
       nixpkgs.config.packageOverrides = prev: {
           some-package = prev.some-package.override { /*...*/ };
       };
   }
   ```

   The nixpkgs version as modified in the NixOS configuration is not
   available outside of the config. Instead, users may put their
   overrides to nixpkgs into `~/.config/nixpkgs/config.nix`; *these*
   are available for use in commands such as `nix-env -i some-package`:
   ```nix
   # ~/.config/nixpkgs/config.nix
   {
       packageOverrides = pkgs: {
           some-package = pkgs.some-package.override { /* ... */ };
       };
   }
   ```

## Derivations

Derivations are created ("instantiated") with the builtin function
`derivation` or a wrapper around it. It creates the "\*.drv" file in the
nix-store, which contains the actual build instructions used when
building ("realising") the derivation with `nix-build`. Moreover, it
returns a derivation object, which is a set with the attribute
`type="derivation";` that can be used to reference the derivation and
sometimes has certain properties to modify it (see: Modifying packages).

Despite the `derivation` function rarely being used directly it is
useful to understand what arguments it works with since many wrappers
take, in addition to some arguments specific to them, the same arguments
and simply pass them on.

`derivation` *requires* the following arguments:
- `name`: A string which will be used in the names of files created in
  the nix-store.
- `system`: A string such as "x86\_64-linux" which specifies for which
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
  containing the path to a nix-store object which shall contain the
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
  fixed-output derivations (FOD, see below).
- `outputHash`, `outputHashAlgo`, `outputHashMode`: These are used to
  create so called **fixed-output derivations (FOD)**, which are
  derivations whose output hash is known in advance and who are
  therefore allowed some impure operations like fetching from the
  network. See also: Fetchers; nix-prefetch

  `outputHashAlgo` may currently be "sha1", "sha256" or
  "sha512".

  `outputHashMode` specifies from what to compute the hash:
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
  environment variable "NIX\_ATTRS\_JSON\_FILE". Moreover, puts path to
  bash script which exports all bash-representable values as environment
  variables into variable "NIX\_ATTRS\_SH\_FILE".
- `outputChecks`: Set of output names to sets which specify how to check
  the respective output. Available attributes are: `allowedReferences`,
  `allowedRequisites`, `disallowedReferences`, `disallowedRequisites`,
  `maxSize` (in bytes, example: `SIZE_IN_KB * 1024` or `SIZE_IN_MB *
  1024 * 1024`), `maxClosureSize` (see: closure, maxSize),
  `ignoreSelfRefs` (boolean; whether to ignore self references in
  dis/allowed references/requisites).
- `unsafeDiscardReferences`: Set of output names to booleans, whether
  to disable scanning the respective output for runtime dependencies.
- `requiredSystemFeatures`: List of strings which features have to be
  available to build this derivation. See:
  <https://nixos.org/manual/nix/latest/command-ref/conf-file.html#conf-system-features>

See also the most common wrapper, the: Standard (Build) Environment

### Building

Building, also called realising, is the execution of the standardized
form (a "\*.drv" file in the store) of a derivation, the recipe for a
package.
- Calling `nixos-rebuild` in its various forms builds the necessary
  packages as specified in the NixOS config;
- `nix-env --install some-package` builds the specified package (and
  obviously its dependencies) and installs it for the current user.
- A single file evaluating to a derivation or a package function with
  default arguments, can be built with `nix-build ./myderivation.nix`,
- however, it is also possible to **just instantiate** it (create the store
  derivation) with `nix-instantiate ./myderivation.nix`
- or even **just to evaluate** it (no instantiation) with
  `nix-instantiate --eval ./myderivation.nix`.
- Using `nix-shell ./myderivation.nix` just drops you into the build
  environment and allows to **manually build** the package; this is useful
  for debugging purposes. To manually build stdenv (see: Standard
  (Build) Environment) packages the process usually looks like this:
  ```bash
  # start nix-shell
  nix-shell '<nixpkgs>' -A some-package

  # get a writable output directory
  export out="$(pwd)/out"
  # invoke some build phase via genericBuild
  phases="somePhase" genericBuild
  # if the phase fails edit it and try again; otherwise run next phase
  ```
The filename may be omitted if it is `./default.nix`.

A builder will *not run* if neither the derivation nor its dependencies
changed; instead it simply returns the old result. Here is an example of
a derivation to avoid because here nix cannot determine from the
derivation itself whether to rebuild: `pkgs.runCommand "DRV_NAME" {}
"${pkgs.coreutils}/bin/date > $out"`

Moreover, a package won't build if, for example, it is marked as broken,
having security issues, not targeting the current platform, or not
having a free license (see: unfree packages). This is already checked
when evaluating the config and can be overruled temporarily by setting
environment variables
NIXPKGS\_ALLOW\_{BROKEN,INSECURE,UNSUPPORTED\_SYSTEM,UNFREE} to 1. There
are also options to make this permanent, which also allow more granular
control over which insecure, or unfree packages or licenses may be
installed.

When evaluating an expression which reads from the filesystem, the
evaluation stops, the respective store object is realised (built), and
only then evaluation continues. This is called **Import from Derivation
(IFD)**. Setting `allow-import-from-derivation = false` in your
`nix.conf` file (which you configure on NixOS via option `nix.settings`)
throws an error if the derivation cannot be evaluated completely before
realising store objects; this allows to create a build plan before
starting to realise store objects and thus more store objects can be
realised in parallel which improves performance.

The `builder` runs with `args` in an isolated build-directory in TMPDIR,
with environment variables cleared and set according to the given
derivation arguments, invalidating the HOME and PATH variables, and the
nix environment set according to the derivation arguments. The network
cannot be accessed during the build (there are exceptions, see: FOD,
Fetchers). The combined stdout and stderr are written to
`/nix/var/log/nix`. The build is considered successful, if the builder
exits with code 0. If inputs are referenced by outputs, they are
registered as runtime dependencies. The time-stamp of the outputs is
always unix-epoch 1.

After building a derivation, a symlink `./result` is then placed
in the current directory and points to the build output in the store. As
long as this link is unchanged (not removed, renamed or modified) the
build result is considered a **garbage-collector root**, meaning the GC
won't remove it. A new build in the same directory overwrites an
existing `./result`! The links for multiple outputs are named
`./result-${n}` (except the first which is still named `./result`).

## Standard (Build) Environment

*Due to its customizability, there are many wrappers of stdenv
preconfiguring it for specific languages or frameworks!*

Nixpkgs comes with a **package `stdenv`**, which provides some basic
dependencies commonly used for compiling c code (gnu c and
cpp compiler, coreutils, `find`, `diff`, `cmp`, `sed`, `grep`, `awk`,
`tar`, `gzip`, `bzip2`, `xz`, `make`, `patch`, `patchelf`), as well as a
bash build script (performing a classic `./configure; make; make
install`), which uses the bash utility functions (such as
`genericBuild`) from `"${stdenv}/setup"`.

Packages created with the standard build environment do not call
`derivation` themselves, but rather its wrapper
**`stdenv.mkDerivation`**, which takes at least arguments `name` (which,
like the argument to `derivation`, consists of `"${name}-{version}"`,
but may be replaced by the separate arguments `pname` and `version` to
simplify reusing them in other arguments) and `src` (or if several:
`srcs`).

The power of stdenv comes from how it is implemented: in **customizable
phases**. All necessary utilities come from the `$stdenv/setup` script,
whose `genericBuild` function runs the phases; this script should always
be sourced in custom build scripts as it also handles setting up PATH
with the dependencies. The phases can be replaced by defining an
environment variable or bash function with their name. It is also
possible to inject code before or after them by defining `pre$phasename`
or `post$phasename`. For this to work the phase needs to start with
`runHook pre$phasename` and end with `runHook post$phasename` (the
phasename variable is *not* defined!); follow this pattern when
replacing phases! Like `derivation`, `stdenv.mkDerivation` passes
unknown arguments as environment variables to the builder script, which
makes it easy to define the relevant control variables.

The **default phases** are:
1. **unpackPhase**: This phase copies/unpacks `src` (or if multiple:
   `srcs`) to the build directory and changes directory into this
   folder. The default implementation handles tar archives and, if
   `unzip` is provided as dependency, zip archives. Pass
   `dontUnpack=true;` to skip this phase. The `unpackCmd` can be
   customized and code can be injected before or after this phase with
   `preUnpack` and `postUnpack`. See:
   <https://nixos.org/manual/nixpkgs/stable/#ssec-unpack-phase>
2. **patchPhase**: Applies `patches`, whose format has to be accepted by
   `patch -p1`. Skip this phase by passing `dontPatch=true;`. Inject
   code before or after this phase by passing `prePatch` and
   `postPatch`. See:
   <https://nixos.org/manual/nixpkgs/stable/#ssec-patch-phase>
3. **configurePhase**: This phase prepares the source to be built by
   running `configureScript`, which defaults to `./configure`. Skip this
   phase by passing `dontConfigure=true;`. Inject code before or after
   this phase by passing `preConfigure` and `postConfigure`. See:
   <https://nixos.org/manual/nixpkgs/stable/#ssec-configure-phase>
4. **buildPhase**: Shall compile the sources. By default this runs
   `make`. Skip this phase by passing `dontBuild=true;`. Inject code
   before or after this phase by passing it as `preBuild` or
   `postBuild`. See:
   <https://nixos.org/manual/nixpkgs/stable/#build-phase>
5. **checkPhase**: Shall check the build result **if `doCheck=true;`**;
   never runs when cross-compiling (which is building on one
   architecture for another). Inject code before or after this phase by
   passing it as `preCheck` or `postCheck`. Dependencies for this phase
   are passed as `checkInputs` and `nativeCheckInputs`. See:
   <https://nixos.org/manual/nixpkgs/stable/#ssec-check-phase>
6. **installPhase**: Shall create `out` in the nix-store and put the
   build output there. The default implementation creates a folder `out`
   and runs `make install`. Skip this phase by passing
   `dontInstall=true;`. Inject code before or after this phase by
   passing it as `preInstall` or `postInstall`. See:
   <https://nixos.org/manual/nixpkgs/stable/#ssec-install-phase>
7. **fixupPhase**: Post-process `out`. By default moves
   `$out/{man,doc,info}/` folders to `$out/share/`, strips debug infos
   from libraries and executables, removes unused runtime-path entries,
   and fixes shebangs to point to entries in PATH. Skip this phase with
   `dontFixup=true;`; inject code before or after this phase by passing
   it as `preFixup` or `postFixup`. See:
   <https://nixos.org/manual/nixpkgs/stable/#ssec-fixup-phase>
8. **installCheckPhase**: **If `doInstallCheck=true;`** (and not
   cross-compiling) runs a program's test suite (default: `make
   installcheck`), to verify its correct installation. If tests are not
   part of the sources, they should be passed as `passthrough.tests` and
   not run here. Inject code before or after this phase by passing it as
   `preInstallCheck` or `postInstallCheck`. Dependencies for this phase
   are passed as `installCheckInputs` and `nativeInstallCheckInputs`.
   See:
   <https://nixos.org/manual/nixpkgs/stable/#ssec-installCheck-phase>
9. **distPhase**: The "distribution phase" shall create a source
   distribution of a package (meaning an archive containing a top-level
   directory with the source files of the package) in `$out/tarballs/`,
   **if `doDist=true;`**. Inject code before or after this phase by
   passing it as `preDist` or `postDist`. See:
   <https://nixos.org/manual/nixpkgs/stable/#ssec-distribution-phase>

Additional **custom phases** can be created by defining a variable with
their name (may also be a bash function). Then their name has to be
mentioned in (at least one of these *space separated strings* listing
phase names):
- `phases`: This environment variable defines *all* phases to run and
  their order. It can be used to inject custom phases, reorder phases,
  or just run specific ones. Its use is discouraged unless one just
  wants to run a specific phase for debugging purposes, as one might
  forget important parts.
- `prePhases`: Phases to run before any of the default phases.
- `preConfigurePhases`: Phases to run just before the `configurePhase`.
- `preBuildPhases`: Phases to run just before the `buildPhase`.
- `preInstallPhases`: Phases to run just before the `installPhase`.
- `preFixupPhases`: Phases to run just before the `fixupPhase`.
- `preDistPhases`: Phases to run just before the `distPhase`.
- `postPhases`: Phases to run after all the default phases.

### Setup-Hooks

*Setup-hooks are a powerful way to inject code into other packages'
build processes and should be used with care or better entirely avoided!
They disturb the ideas that dependencies can be added effect-free and
that of modularity, because setup-hooks might interfere with each
other.*

As mentioned above (see: Standard (Build) Environment), hooks inject
code somewhere, usually phases. Setup-hooks allow dependencies to inject
code into the build environment of packages that depend on them:

Every package can create a so called setup-hook as the file
`${pkg}/nix-support/setup-hook`. One of the first things
`${stdenv}/setup` does is to go through all dependencies and sourcing
their setup-hooks. This allows setup-hooks to inject other hooks,
provide utility functions, etc.

Every package sourcing `${stdenv}/setup`, by default, runs the following
builtin setup-hooks (and the hooks of the bintools and cc wrappers, see:
<https://nixos.org/manual/nixpkgs/stable/#bintools-wrapper>,
<https://nixos.org/manual/nixpkgs/stable/#cc-wrapper>):

- **move-docs.sh**: moves documentation to the `./share` subfolder.
- **compress-man-pages.sh**: using gzip.
- **strip.sh**: removes debug symbols, etc.
- **patch-shebangs.sh**: to point to the nix-store. Disable with
  `dontPatchShebangs=true;`.
- **audit-tmpdir.sh**: makes sure the build outputs do not refer to the
  build folder.
- **multiple-outputs.sh**: adds configure flags to install outputs to
  one of the locations listed in `outputs`. Disable with
  `setOutputFlags=false;`.
- **move-sbin.sh**: moves binaries from `./sbin` to `./bin` and
  creates a link to it in `./sbin`.
- **move-lib64**: moves library files from `./lib64` to `./lib` and
  creates a link to it in `./lib64`.
- **move-systemd-user-units.sh**: moves systemd-user-units from `./lib`
  to `./share` and creates a link to it in `./lib`.
- **set-source-date-epoch-to-latest.sh**: sets SOURCE\_DATE\_EPOCH to most
  recently modified file.

Check out this list of packages using setup-hooks:
<https://nixos.org/manual/nixpkgs/stable/#chap-hooks>

## Overlays

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

One can also think of fixpoint-functions as describing a change to a
value, which they receive as argument. To apply the change, a helper
function is needed. The following builds up the helper in incremental
steps until it can be replaced by `lib.extends`, which applies overlays,
changes which are able to refer to the final and the previous state of
the fixpoint:
```nix
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

For convenience, sets can be made extensible with `lib.makeExtensible`.
This means instead of having to call `lib.fix lib.extends myoverlay
myset`, an overlay can be applied by passing it as argument to a value's
attribute `extend`. Do not confuse this with `lib.makeOverridable` (see:
Modifying packages)!
```nix
let
    fixpointfn = self: { a=1; b=10; c = self.a + self.b; };
    overlay1 = final: prev: {a=5; d = final.a+final.b; prevA1=prev.a;};
    overlay2 = final: prev: {a = prev.a * 10; b=100; prevA2=prev.a;};
    lib = import <nixpkgs/lib>;
in ((lib.makeExtensible fixpointfn).extend overlay1).extend overlay2
```

In summary: **Overlays** are functions describing changes to a value,
which is available in specific states within the function because these
states are passed as arguments to it. A classic overlay function takes
the final state of the value as first argument (usually called `final`
or, in older code, `self`) and the old state as second argument (usually
called `prev`, or, in older code, `super`). Sometimes **overlay-like**
functions take the old state as only argument; this is not called
"overlay" but, conceptionally, does the same.

In nix overlays are mainly used to modify the nixpkgs package
collection. When doing so, everything which is not a derivation, for
example the script `callPackage`, should definitely be accessed through
`prev` and not `final` because this avoids recomputing the fixpoint!

Overlays are applied to nixpkgs as follows:
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
   `~/.config/nixpkgs/overlays`. They must not exist both.

The (above mentioned) option (`nixpkgs.config.`)`packageOverrides` is
like an overlay which only takes the `prev`/`super` argument. It is
mainly useful to "declaratively" manage non-NixOS systems by adding a
shell environment with all wanted packages to be installable as a single
package.

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

## Modifying packages

This section introduces convenient ways to create variants of packages
without having to literally copy their code just to make some small
changes. They are often used in overlays to modify nixpkgs.

The pattern here is to get a derivation object, which has a callable
attribute, pass the changes to it and receive a variant of the
derivation back. These attributes are **usually injected when using the
standard build environment**, however, some could also be injected
manually when the derivation is created in some other way. Regardless, a
simple call to `derivation` does not produce a result which has them.

The function `lib.makeOverridable` makes it is possible to change the
arguments with which a function was called by passing the differing
arguments to the injected attribute `override` of the result:
```nix
let lib = import <nixpkgs/lib>;
    fn = { arg }: { foo = "I was called with ${arg} argument."; };

    result = lib.makeOverridable fn { arg = "the original"; };

    changed1 = result.override { arg = "a changed"; };
    # to access the original arguments supply a function:
    changed2 = result.override (orig: { arg = "++NOT++" + orig.arg; });

in [ result.foo changed1.foo changed2.foo ]
```

The **`override` attribute of packages** allows to change the arguments
the package-function receives. In other words, it allows to changes the
dependencies of a package.

`lib.makeOverridable` also always injects `overrideDerivation`, which is
a function taking an overlay-like function as argument, that expects
the derivation itself as argument (usually called "oldAttrs"). Thus
this is only useful for derivation objects (in particular, a sibling
attribute `drvArgs` is required). It creates a new derivation from the
original arguments merged with the overrides.

In other words, the **`overrideDerivation` attribute of packages**
allows to change the arguments with which the `derivation` function, to
which all packages essentially boil down to, is called.

`stdenv.mkDerivation` injects an **attribute `overrideAttrs`** into the
result, that allows to change with which arguments `stdenv.mkDerivation`
(not the `derivation` function!) was called. It can take the differing
attributes directly as a set, or as an overlay or overlay-like function,
which only receives the old state as argument. Note, that the final
state passed to the overlay also includes an attribute `finalPackage`,
which holds the result of the final call to `stdenv.mkDerivation`:
```nix
let nixpkgs = import <nixpkgs> {};
    git = nixpkgs.git;
in (
    (
        git.overrideAttrs { pname = "git-custom1"; }
    ).overrideAttrs (prev: { pname = prev.pname + "-custom2"; })
).overrideAttrs (final: prev: { pname = prev.pname + "-custom3"; }) //
{ type = null; } # override the type attribute to pretty print it
```

When a derivation object has both attributes, `overrideAttrs` and
`overrideDerivation`, `overrideAttrs` should be preferred. (It can, for
example, be called multiple times and only produces a derivation from
the final spec, while every invocation of `overrideDerivation` produces
a new derivation.)

# Flakes

To be able to use flakes:

- using NixOS: set `nix.settings.experimental-features =
  ["nix-command" "flakes"];` in `/etc/nixos/configuration.nix`
- using other distributions: set `experimental-features = nix-command
  flakes` in `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`

This enables the `nix flake` commands and support for
**flake-references ("flakerefs")**, which specify where a flake comes
from (and which of its outputs to target). Flakerefs can be specified as
nix attribute-sets (used in `./flake.lock` files), or as strings of the
form `"${location}#${output}"`. The suffix `#${output}` is not always
specified; there are multiple location types with different syntax:

- `[flake:]<flake-id>(/<rev-or-ref>(/rev)?)?` is type "indirect",
  meaning it resolves the given flake-id using *a* local **flake
  registry** (which can be used to redirect any looked up flake
  reference, for example to a local fork! The global registry can be
  shadowed with a system registry `/etc/nix/registry.json` or a user
  registry `~/.config/nix/registry.json` ). An example would be
  `nixpkgs`, which resolves to `git://github.com/NixOS/nixpkgs`.
- `[path:]<path>(\?<params>)?` is type "path". The path must be `.`, or
  start with `./` or `/`. "path:" may only be omitted if the path is not
  in a repo! Examples: `path:/home/myuser/repo/myflake`,
  `path:/home/myuser/NOTrepo/myflake`
- `[tarball+](http|https|file):(//<server>)?<path>(\?<params>)?` is type
  "tarball". The "tarball+" prefix may be omitted if the URL ends in
  `.zip`, `.tar`, `.tgz`, `.tar.gz`, `.tar.xz`, `.tar.bz2` or
  `.tar.zst`.
- `[file+](http|https|file):(//<server>)?<path>(\?<params>)?` is type
  "file". The "file+" prefix can be omitted if the URL does not end in
  one of the known archives formats (see type "tarball").
- `git(+http|+https|+ssh|+git|+file):(//<server>)?<path>(\?<params>)?`
  is type "git". Parameter "ref" defaults to the resolved HEAD, "rev"
  is a commit reachable from "ref" and defaults to resolved "ref".
  Examples: `git+https://example.org/repo?ref=unstable&rev=1a2b3c`
- `github:<owner>/<repo>(/<rev-or-ref>)?(\?<params>)?` is type "github"
  and more efficient than type "git" because it downloads tarballs
  instead of the entire repo. Use parameter "host" for github enterprise
  servers. Example: `github:NixOS/nixpkgs/nixos-23.11`
- `gitlab:<owner>/<repo>(/<rev-or-ref>)?(\?<params>)?` is type "gitlab"
  and works like type "github" but using the "host" parameter is more
  common. In project subgroups these slashes need to be escaped as
  `%2F`, example: `gitlab:veloren%2Fdev/rfcs`
- `sourcehut:<owner>/<repo>(/<rev-or-ref>)?(\?<params>)?` is type
  "sourcehut". Use parameter "host" for servers other than "git.sr.ht"
  and to specify mercurial repos ("hg.sr.ht"; these require the "rev"
  and forbid the "ref" parameter).
- `hg(+http|+https|+ssh|+file):(//<server>)?<path>(\?<params>)?` is type
  "mercurial".

A flake is a directory containing a `./flake.nix` file, which describes
it in a standardized form. When the flake is a git repo, it only
considers files tracked by git, meaning untracked files do not end up in
the world readable nix-store.

`./flake.nix` returns an attribute set with the following allowed
fields:

- `description`: A string describing the flake.
- `nixConfig`: An attribute set with `nix.conf` settings, most of which
  require confirmation unless the global setting `accept-flake-config`
  is `true`.
- `inputs`: An attribute set defining the flake's dependencies.
  Dependencies may be omitted (meaning only mentioned as arguments of
  `outputs`), making them flakerefs of type "indirect" (resolved using
  the registry).

  ```nix
  inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    # ^^^^^^^ passed to outputs with this name
  };
  ```

  To modify a dependency of an input, simply modify its `inputs`
  attribute! To copy a dependency of an input to another input, specify
  the input to copy as a "/" separated string of input names in the
  copying input's `follows` attribute:

  ```nix
  inputs = {
      aFlake.url = /*...*/;          # depends on nixpkgs

      # use aFlake's nixpkgs dependency as this flake's nixpkgs input:
      nixpkgs.follows = "aFlake/nixpkgs";

      # override bFlake's nixpkgs dependency (use the one from aFlake):
      bFlake.inputs.nixpkgs.follows = "aFlake/nixpkgs";

      # reference self as empty string:
      bFlake.inputs.myflake.follows = "";
  };
  ```

  While it is possible to be explicit with the version of an input (see:
  flakerefs), this is usually not done: Instead, nix automatically
  generates a (json) lock file `./flake.lock` to pin the exact versions;
  this can be invoked with `nix flake lock`. The benefit is that it is
  easy to update the dependencies with `nix flake update` (or only a
  specific one: `nix flake update someInput anotherInput`).

- `outputs`: Function taking the named arguments `self` (as if the flake
  were its own dependency) and the names of the `inputs` set. Each
  argument is extended with these metadata attributes (if applicable)
  about the input:

  + `outPath` (in the nix-store; allows to use the argument as a path,
    for example: `with import nixpkgs {}; ...`),
  + `rev` (commit hash),
  + `revCount` (number of ancestors of the commit),
  + `lastModifiedDate` (commit-time as string in format:
    "%Y%m%d%H%M%S"),
  + `lastModified` (commit-time as integer unix-epoch),
  + `narHash` (sha256 of a flake).

  This function returns an attribute set mapping output classes (for
  example: `packages`) to values of certain types (such as: derivation).
  Some output classes group their items by system type or hostname, and
  sometimes there is a special item "default" (which is the target if
  the relevant command is run without specifying a target in the flake
  reference).

  ```nix
  outputs = { self, nixpkgs }: {
      packages = {
          x86_64-linux = rec {
              mypkg = someDerivation;
              default = mypkg;
          };
      };
  };
  ```

# Appendix

## Dependencies

The list of runtime-dependencies is determined by checking which
dependencies are referenced in the build output. (Sometimes this
includes unnecessary dependencies, which were put into the binary's
runtime path to ensure their correct versions are found, should they be
used. These can be removed with `patchelf` and `strip`.)
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

## Build helpers

*The above described `stdenv.mkDerivation` is the most used build helper
and thus received its own chapter. This section describes other build
helpers.*

Build helpers are functions *producing derivations*.

### Fetchers

It is important to differentiate between the builtin fetchers and the
ones provided by nixpkgs! The builtins ones (such as `with builtins;
[fetchGit fetchTarball fetchurl]`) are *not* build helpers because they
do not return a derivation. They run when evaluated, dump the result
into the nix-store and need network access to determine whether this
result is up-to-date.

The nixpkgs fetchers, on the other hand, run at build time, during which
they are granted network access because they return *fixed-output*
derivations (see: FOD), meaning it is known beforehand what the result
will be. They only try to download their target if the mentioned hash
changed, and can use cache servers, instead of the actual target site.

- get files and archives: `with nixpkgs; [fetchurl fetchzip]` take
  the arguments `url` and `hash`. The difference is that `fetchurl`
  saves the downloaded file unaltered, while `fetchzip`, which also
  works for other archive types, unpacks the result before storing it.
- get patches: `nixpkgs.getpatch` takes arguments `url` and `hash`, and
  normalizes the retrieved patch file before storing it. There is a
  wrapper for patches from <http://sources.debian.org> called
  `nixpkgs.fetchDebianPatch`.
- get repos: There are many fetchers to retrieve from all kinds of
  repositories, like `with nixpkgs, [fetchgit fetchsvn fetchcvs fetchhg
  fetchfossil]`. Depending on the abilities of the specific version
  control system, they can do different things, like get submodules,
  etc.
- get from site: There are many fetchers for specific hosting sites,
  like `nixpkgs.fetchFromGitHub`, which may be more performant than the
  fetcher for the relevant type of repo due to services of these sites,
  allowing to avoid downloading the whole repo.
- get non-distributable files: Some files cannot or must not be
  downloaded automatically. `nixpkgs.requireFile` instructs the user to
  download the file himself and guides him how to put it into the
  nix-store.
- etc

#### `nix-prefetch`

The program `nix-prefetch` is very helpful to determine the hash to
use when calling a fetcher: Invoke it on your (broken because hashes
are missing) source file and it will run the fetchers (download the
files and put them into the nix store), compute the hashes and tell you
how to fix your code.

### Writers (Trivial builders)

These help with running shell commands and writing files at build time.

`nixpkgs.runCommand` runs the shell script provided as a string,
`nixpkgs.runCommandCC` also provides a c compiler, while
`nixpkgs.runCommandLocal` prevents retrieving a cached version of this
derivation.

`nixpkgs.writeTextFile` allows to write text into files in the
nix-store. It takes an attribute set as argument; the following
functions are wrappers for certain use-cases and take positional
arguments instead: `nixpkgs.writeText` makes the nix-store path a file
and writes the given text to it; `nixpkgs.writeTextDir` uses the
nix-store path as a directory into which to write the file;
`nixpkgs.writeScript` makes the nix-store path an executable file;
`nixpkgs.writeScriptBin` makes the nix-store path a directory with the
subfolder `bin` and puts the contents in an executable file there;
`nixpkgs.writeShellScript` and `nixpkgs.writeShellScriptBin` are like
the regular script writers but add a shebang for the bash version in
nixpkgs. `nixpkgs.writeShellApplication` is like `writeShellScriptBin`
but takes an argument set allowing to specify runtime dependencies as
field `runtimeInputs`.

`nixpkgs.concatTextFile` allows to concatenate files into a new file in
the nix-store; it takes an argument set but its wrappers for specific
use-cases take multiple positional arguments instead:
`nixpkgs.concatText` takes a name for the created file and a list of
files to concatenate; `nixpkgs.concatScript` is the same but makes the
result executable.

To create a single derivation from multiple ones, use
`nixpkgs.symlinkJoin`, which puts their outputs into the same directory
tree.

There are some more... See:
<https://github.com/NixOS/nixpkgs/blob/master/doc/build-helpers/trivial-build-helpers.chapter.md>

## FHS (Filesystem Hierarchy Standard)

As mentioned, NixOS does not comply with the FHS (Filesystem Hierarchy
Standard). This is usually not a problem when packaging software with
nix: for example shebangs are patched by default when using stdenv and
often a simple fixupPhase is enough.

### FHS compatible "sandboxes"

To package software which expects an FHS compliant environment while
running there are `nixpkgs.buildFHSEnv` and `nixpkgs.buildFHSUserEnv`,
which use linux namespaces to create an isolated, unprivileged, FHS
compliant root filesystem using the host's nix-store, that is destroyed
again after all child processes exit. Note that this provides no
security relevant separation from the host!

See: <https://nixos.org/manual/nixpkgs/stable/#sec-fhs-environments>

### Running unpatched binaries (no packaging required): `nix-ld`

Unpatched linux binaries which are dynamically linked don't work on
NixOS since they cannot find the dynamic linker. `nix-ld` allows these
binaries to find it and necessary libraries by putting a shim in the
usual places. Where exactly the shim redirects to can be configured
using various environment variables such as NIX\_LD and
NIX\_LD\_LIBRARY\_PATH. Necessary libraries can be figured out using `ldd`
on the binary.

```nix
programs.nix-ld = {
    enable = true;
    # make some libraries globally available:
    #libraries = with pkgs; [];
};
```

## Creating a custom NixOS installation medium

_Note: When installing NixOS somewhere you first boot into the iso file
and then install NixOS to the target computer. Afterwards you boot into
the new system, not the iso anymore. Since you can change your new
system any way you like, there is generally no need to have a custom
iso. However, if you just want to customize the system on the iso, for
example to pre-install some programs to be able to use it as a rescue
live-system (which one does not install but just uses from a usb), here
is how to do it:_

1. `git clone --depth=1 -b nixos-unstable git://github.com/NixOS/nixpkgs.git`
2. `cd nixpkgs`
3. `cd nixos`
4. customize one of the templates in ./modules/installer/cd-dvd/ to your
   liking; this basically works like a regular nixos config if you just
   want to preinstall some basic programs to the iso: add them to
   environment.systemPackages, enable their module or activate their
   service. Obviously much more is possible, but this is not the
   tutorial for that; read the docs and check out the templates!
5. build; the resulting \*.iso file ends up in ./result/iso/
   ```bash
   # make sure to be in the nixos folder of the nixpkgs repo
   nix-build \
     -A config.system.build.isoImage \
     -I nixos-config=modules/installer/cd-dvd/JUST_EDITED.nix \
     ./default.nix`
   ```

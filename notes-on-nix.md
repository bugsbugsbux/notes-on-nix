status: WIP

---

# Notes on Nix(OS)

Nix is:
1. a programming language
2. a package manager using the nix programming language
3. a linux distribution using the nix package manager

The idea behind nix is to declaratively manage the state of the
operating system: From which packages are installed, to which services
are enabled and even how programs are configured. Declaratively means,
one states the intended result and the program figures out itself, how
to achieve that.

First, understand the basics of the nix language:

## Nix language

Whitespace is generally not significant, thus most nix-expressions
may be written in a single line. Here is an example where a space makes
all the difference: `let foo=1; bar=foo -1; bar` (returns value of bar:
`0`) while the following gives an error "undefined variable 'foo-1'":
`let foo=1; bar=foo-1; bar`.

`#` comments the rest of the line, while `/*` starts a comment which
ends at the next `*/`.

The nix language requires each file to contain *only a single*
"nix-expression", which is something that evaluates to a value:

- **integer**: `1`
- **float**: `3.14`
- **boolean**: `true` and `false`
- **null**: `null` (called "nil" in some languages)
- **string**:
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
- **path**: Careful: Using paths copies it to the nix-store location!

  Paths are unquoted, do not contain :// which would make it a URI, that
  is a string, and have at least one "/" which is not the last char:
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
- **list**: `[1 "two" 3 4]`
- (attribute-)set: What other languages call "(hash-)map", "dictionary"
  or "table". See below.
- function: Indeed, functions may be used as values. See below.

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

Nix **function**s are anonymous closures which only take a single
argument. Anonymous means they do not have a name, but as they are
values, they may be bound to a name in the usual way. Closure means a
function knows about variables in its parent scopes from the time it was
defined. This lets one implement multi-argument functions by nesting
functions: The body goes into the innermost function, which takes the
last argument and is returned by another function with takes the second
to last argument, and so on; this is called "currying".

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

For manipulating controlflow there are the keywords `if`, `then` and
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
}.${if true then "foo" else "bar"} # str-interpolation in attribute-path
```

For more info about the language see:
<https://nix.dev/manual/nix/2.18/language/>

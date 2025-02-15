# zh

A toy POSIX shell written in Zig.

```
$ echo \'\"hello world\"\'
'"hello world"'
$ gc
gc  gcc  gcc-13  gcc-14  gcc-ar-13  gcc-ar-14  gcc-nm-13  gcc-nm-14  gcc-ranlib-13  gcc-ranlib-14  gcore  gcov  gcov-13  gcov-14  gcov-dump-13  gcov-dump-14  gcov-tool-13  gcov-tool-14
$ type gcc
gcc is /usr/bin/gcc
$ type ls
ls is /bin/ls
$ ls
LICENSE         build.zig       zig-out
Makefile        build.zig.zon
README.md       src
$ cd ..
$ pwd
/Users/spedon/eden/zig
$ cd zh
$ pwd
/Users/spedon/eden/zig/zh
$ ls > test.txt
$ cat test.txt
LICENSE
Makefile
README.md
build.zig
build.zig.zon
src
test.txt
zig-out
$
```

## Features

* Builtins: `exit`, `echo`, `type`(with HashMap)
* Natigation: `pwd`, `cd`(*absolute* and *relative*)
* Quote Parsing(*State Machine*)
* Redirection to `stdout` or `stderr`
* Auotocompletion powered by Trie

# zshell

A toy shell written in Zig.

```
$ echo \'\"hello world\"\'
'"hello world"'
$ type ls
ls is /bin/ls
$ type pwd
pwd is a shell builtin
$ ls
LICENSE         README.md       build.zig.zon   zig-out
Makefile        build.zig       src
$ cd ..
$ pwd
/Users/spedon/eden/zig
$ cd zshell
$ pwd
/Users/spedon/eden/zig/zshell
$
```

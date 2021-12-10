# Configuration file for latexmk

* Defaults to `xelatex`
* Directories:
  - Source (TeX) files should be put in `$tex_dir/` directory
  - Asymptote plots should be put in `$asy_dir/` directory
  - Document `$tex_dir/document.tex` outputs to `document.pdf`
  - Temporary files are all put in `$tex_dir/document.out/`
  - Options `-auxdir` and `-outdir` are not used, directories are
    achieved by messing with `jobname`, which seemed less troublesome
    for the likes of `minted` package
* If no file is given to the command line, process all files in
  `$tex_dir` that contains a line beginning with `\documentclass`
* Support for `dtx` files
  - Deals with `.sty` and `.cls` dependencies when these files can't be
    found but a `.dtx` file with the same basename is present
  - Generates documentation for `.dtx` files by default
  - Default history and command index using `makeindex` are generated
* Indexes use 'xindy' by default and respect a style file `.xdy` if
  one is available with the same basename as the index
* Filter output (partial)
  - Goal is to make output cleaner, prettier, and less verborrhagic!
  - Currently just a proof of concept is implemented

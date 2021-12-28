# MIT License
#
# Copyright (c) 2021 Caio Alves Garcia Prado
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#
#############################################################################
#
# latexmk configuration file
#
# Features:
#
#   • Defaults to 'xelatex'
#   • Directories:
#     - Source (tex) files should be put in '$tex_dir/' directory
#     - Asymptote plots should be put in '$asy_dir/' directory
#     - Document '$tex_dir/document.tex' outputs to 'document.pdf'
#     - Temporary files are all put in '$tex_dir/document.out/'
#     - Options '-auxdir' and '-outdir' are not used, directories are
#       achieved by messing with 'jobname', which seemed less troublesome
#       for the likes of 'minted'
#   • If no file is given to the command line, process all files in
#     '$tex_dir' that contains a line beginning with \documentclass
#   • Support for 'dtx' files
#     - Deals with '.sty' and '.cls' dependencies when these files can't be
#       found but a '.dtx' file with the same basename is present
#     - Generates documentation for '.dtx' files by default
#     - Default history and command index using 'makeindex' are generated
#   • Indexes use 'xindy' by default and respect a style file '.xdy' if
#     one is available with the same basename as the index
#   • Filter output (partial)
#     - Goal is to make output cleaner, prettier, and less verborrhagic!
#     - Currently just a proof of concept is implemented
#
#############################################################################

use 5.20.0;
use open qw(:encoding(UTF-8) :std);
use strict;
use utf8;
use warnings;

local $/ = "\n";

# • Filter output                                                        {{{1

# before anything, we fork Perl so we can filter all the output
if (my $pid = open(my $dump, '-|') // die "Can't fork filter: $!") {
  {package Filter;

    sub new      { bless { rule => sub {} }, shift; }
    sub readline { s/\R\z// if defined($_ = <$dump>); }

    sub process {
      /Run number (\d+) of rule '(pdf|xe|lua)?(.*)'/
        and shift->newrule($3 =~ s/cusdep (.*?) /$1_/r =~ s/ .*//r, $1)
        or  shift->{rule}();
    }

    sub newrule {
      my ($self, $rule, $number) = @_;

      if ($rule =~ /latex/ and $number == 1) {
        # start a new document
        $self->readline until m|^[(].*?([^/]*?)[.][^.]*$|;
        $self->finish_document;
        $self->{summary}->%* = ();
        message(0, 'Processing document', $1);
      }

      $self->{summary}{$rule}->@* = ();
      $self->{messages} = $self->{summary}{$rule};
      $self->{rule} = {
        latex      => sub { $self->rule_latex; },
        bibtex     => sub { $self->rule_bibtex; },
        asy_tex    => sub { $self->rule_asy2all; },
        asy_pdf    => sub { $self->rule_asy2all; },
        dtx_cls    => sub { $self->rule_dtx2all; },
        dtx_sty    => sub { $self->rule_dtx2all; },
        makeindex  => sub { $self->rule_makeindex; },
        glo_gls    => sub { $self->rule_makeindex; },
      }->{$rule} // sub {};
    }

    sub finish_document {
      use List::Util qw(max);
      my $summary = shift->{summary};
      my $pad = max(map {length($_->{file})} map {@$_} values %$summary);

      for (keys %$summary) {
        message(1, 'Messages for rule', $_) if (@{$summary->{$_}});
        error_print($pad, $_) for @{$summary->{$_}};
      }
    }

    sub message {
      use Term::ANSIColor qw(:constants);
      say BOLD, (' ● ', '   ○ ',  RESET '     - ')[(shift) % 3]
        , (shift)
        , (shift // '') =~ s/(.+)/ '@{[GREEN]}$1@{[BLACK]}'/r
        , (shift // '') =~ s/(.+)/ [$1]/r
        , RESET;
    }

    sub error_print {
      use Term::ANSIColor qw(:constants);
      my ($pad, $type, $file, $line, $message, $ctxt)
        = (shift, @{(shift)}{qw(type file line message context)});

      $type = {EE=>RED, WW=>YELLOW, MM=>BLUE}->{$type} . $type . BLACK;
      $line = sprintf(MAGENTA . '%4s' . BLACK, $line || '');
      $file = sprintf(GREEN . "%-${pad}s" . BLACK, $file);
      $ctxt = ref($ctxt) ? join(FAINT, @$ctxt) : $ctxt;

      say "     [$type] $line:$file $message. ", CYAN, $ctxt, RESET;
    }

    sub error_new {
      push @{shift->{messages}},
        {map {$_ => shift // ''} qw(type line file message context)};
    }

    sub error_set {
      my ($self, $key, $value) = @_;
      $self->{messages}[-1]{($key)} = $value;
    }

    sub error_append {
      my ($context, $append) = (\shift->{messages}[-1]{context}, shift);
      $$context = [$$context, $append];
    }

    sub rule_makeindex {
      /".*[.](.*)" +".*[.](.*)"'/
        and message(1, "Making index [$2 => $1]");
    }

    sub rule_dtx2all {
      /Generating file\(s\) (.*?)\s*$/
        and return message(2, $1);
      /"(.*dtx)"/
        and return message(1, 'Extracting file', $1);
    }

    sub rule_asy2all {
      /^For rule .*y (tex)?.*?([^\/]*?)'/
        and return message(1, 'Making picture', $2, $1 ? 'inline' : '');
      /^.*?([^\/]*[.]asy): (\d+[.]\d+): (.*)/
        and return shift->error_new('EE', $2, $1, $3);
    }

    sub rule_bibtex {
      /Running 'bibtex/
        and return message(1, "Running bibtex");
    }

    sub rule_latex {
      #print "$_\n";
      #and print "$_\n" and error_print(20, $self->{messages}[-1])
      my $self = shift;

      /Latexmk: Examining/
        # latexmk is doing some tests that isn't our business anymore
        and return $self->{rule} = sub{};

      /^> ([^<].*)\.$/
        # \show command
        and return $self->error_new('MM', 0, '', $1);

      /.*?([^\/]*?):([0-9]+): (LaTeX Error: )?(.*)\.$/
        # errors of type 'file:line: message'
        and return ($4 eq 'Emergency stop')
          ? $self->error_set('file', $1)         # missing input file
          : $self->error_new('EE', $2, $1, $4);  # other errors


      /(\w+TeX|Package|Class) ?(.*) (E)?.*?: (.*?)( on input line (\d+))?\.$/
        # generic errors
        and $self->error_new($3 ? 'EE' : 'WW', $6, $2 || $1, $4)
        and return;

      /^(l.(\d+) +(.*))/
        # l.## messages update line number...
        and $self->error_set('line', $2)
        and $self->error_set('context', $3)
        # ...and show more context in next line
        and $self->readline
        and $self->error_append(substr($_, length($1)))
        and return;

      /^! (.*)\.$/
        # messages beginning with '!' show context on next line
        and $self->error_new('EE', 0, '', $1)
        and $self->readline
        and return /^<\*> (.+)/
          ? $self->error_set('file', $1)
          : $self->error_set('context', $_);
    }
  }

  my $filter = new Filter;
  $filter->process while $filter->readline;
  $filter->finish_document;
  waitpid $pid, 0;
  exit ($? > 0);
}
open(STDERR, '>&', STDOUT);

# • Define directories                                                   {{{1

my  $cur_dir     = getcwd();
my  $asy_dir     = 'asy';
my  $tex_dir     = 'tex';

# • Setup latexmk                                                        {{{1

our $jobname     = '%A.out/%A';   # trick to process tex into subdirectory
our $bibtex_use  = 1.5;           # delete .bbl if and only if .bib exists
our $do_cd       = 1;             # change into .tex source directory
our $pdf_mode    = 5;             # pdflatex|ps2pdf|dvipdf|lualatex|xelatex
our $rc_report   = 0;             # do not print which rc files were read

# • Programs and options                                                 {{{1

my  $asymptote   = 'asy -vv -nosafe -f pdf';
our $makeindex   = 'internal makeindex %B';
our $log_wrap    = $ENV{max_print_line} = 1e10;
set_tex_cmds '-shell-escape -file-line-error -interaction=nonstopmode %O %S';
sub makeindex {                                                         #{{{2
  if (our $texfile_name =~ /.dtx$/) {
    # dtx file: we are probably dealing with 'doc' type of index
    my $style = ${our $Psource} =~ /.idx$/ ? 'ind' : 'glo';
    Run_subst("makeindex -s g$style.ist %O -o %D %S");
  }
  else {
    # check latex flavor and search for a xindy style file
    my $style = '';
    my $input = ($pdf_mode > 3) ? 'xelatex' : 'latex';
    for ("$_[0].xdy", basename("$_[0].xdy")) {
      if (-e) {
        rdb_set_source(our $rule, $_);
        $style = "-M $_";
        last;
      }
    }
    Run_subst("texindy -L english -I $input $style %O -o %D %S");
  }
}                                                                       #}}}2

# • Hooks                                                                {{{1

# at the end of processing everything, find and clean empty .out directories
END { rmdir(s|(\.[^.]*)?$|.out|r) for (our @default_files); }

# after processing a document, copy final pdf to ./
our $success_cmd = "cp %D '$cur_dir'";

# after finish parsing command line, prepare .out directories
push @ARGV, qw(-e prepare);
sub prepare {
  our @default_files = our @command_line_file_list;

  # find .tex and .dtx files containing '\documentclass'
  if (!@default_files) {
    while (<$tex_dir/*.{tex,dtx}>) {
      open(my $file, '<', $_);
      push(@default_files, $_) if (grep /^\\documentclass/, <$file>);
      close $file;
    }
  }

  # prepare .out directories
  if (our $cleanup_only == 0) {
    mkdir s|(\.[^.]*)?$|.out|r for (@default_files);
  }

  if (our $cleanup_mode > 0) {
    # clean minted directory
    use File::Path qw(rmtree);
    rmtree s|([^/]*?)(\.[^.]*)?$|$1.out/$1.minted|r for (@default_files);

    if ($cleanup_mode == 1) {
      # cleanup final pdf from ./ when full cleaning
      unlink_or_move(basename s|(\.[^.]*)?$|.pdf|r) for (@default_files);
    }
  }
}

# • Custom dependencies                                                  {{{1

our @generated_exts;
our $cleanup_includes_generated = 1;

#  - glossary (history) for .dtx documentation files
push @generated_exts, qw(gls glo);
add_cus_dep('glo', 'gls', 0, 'makeindex');

#  - class/package files from .dtx
add_cus_dep('dtx', 'cls', 0, 'dtx2all');
add_cus_dep('dtx', 'sty', 0, 'dtx2all');
sub dtx2all {                                                           #{{{2
  rdb_add_generated("$_[0].cls", "$_[0].sty");
  my $rval = Run_subst('tex %S');
  unlink("$_[0].log");
  return $rval;
}                                                                       #}}}2

#  - asymptote plots
ensure_path('TEXINPUTS', "$cur_dir/$asy_dir");
add_cus_dep('asy', 'pdf', 0, 'asy2all');
add_cus_dep('asy', 'tex', 0, 'asy2all');
sub asy2all {                                                           #{{{2
  # parse asymptote output by forking Perl so we avoid writing a new file
  if (my $pid = open(my $dump, '-|') // die "Can't fork: $!") {
    # modification from latexmk project's example folder
    # parse output
    my %dep;
    while (<$dump>) {
      /^(Including|Loading) .* from (.*)\s*$/
        and $dep{$2 =~ s|^([^/].*)$|$cur_dir/$asy_dir/$1|r} = 1;
      warn $_;
    }
    close $dump;
    my $rval = $?;

    # save dependency information and cleanup
    my $dirname  = dirname($_[0]);
    my $basename = basename($_[0]);
    for (<$dirname/$basename*>) {
      /[.]asy$/ and next;
      /[.](pdf|tex)$/
        ? rdb_add_generated($_)
        : unlink($_);
    }
    rdb_set_source(our $rule, keys %dep);
    return $rval;
  }
  open(STDERR, '>&', STDOUT);

  # run asymptote
  my  $dir = "'$cur_dir/$asy_dir'";
  my  $inline = ${our $Pdest} =~ /\.tex$/ ? '-inlinetex' : '';
  our $pdf_method;
  Run_subst("$asymptote $inline -tex $pdf_method -cd '$dir' %S") && die;
  exit;
}                                                                       #}}}2

# vim: ft=perl

vim-js-indent
=============
[![Travis CI](https://img.shields.io/travis/lambdalisue/vim-js-indent/master.svg?style=flat-square&label=Travis%20CI)](https://travis-ci.org/lambdalisue/vim-js-indent)
![Version 1.0.0](https://img.shields.io/badge/version-1.0.0-yellow.svg?style=flat-square)
![Vim License](https://img.shields.io/badge/license-Vim-blue.svg?style=flat-square)
[![Doc](https://img.shields.io/badge/doc-%3Ah%20js--indent-orange.svg?style=flat-square)](doc/js-indent.txt)

My personal fork of [jason0x43/vim-js-indent](https://github.com/jason0x43/vim-js-indent).
I applied some destructive changes.

Difference from the original
---------------------------------

- [PR #9](https://github.com/jason0x43/vim-js-indent/pull/9) has applied
- Unnecessary files have removed 
- Tab characters in the script have substituted to two spaces
- Short names (options, keywords) have substituted to full name
- `abort` keyword has applied to all functions
- Logging feature has removed while the function call in Vim script is expensive
- `doc/js-indent.txt` has added
- Lint by [vim-vint](https://github.com/Kuniwak/vint) on [Travis CI](https://travis-ci.org/lambdalisue/vim-js-indent) has enabled
- etc.


Original license
--------------------------------
Copyright © 2014-2016 Jason Cheatham. Distributed under the same terms as Vim
itself. See `:help license`.

" Vim indent script for JavaScript
" General:
" File:        javascript.vim
" Maintainer:  Jason Cheatham
" Description: JavaScript indenter.

" Only load one indent script per buffer
if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

" Options
" ------------------------------------------------------------------------------
" set to 1 to make case statements align with the containing switch
if !exists('g:js_indent_flat_switch')
  let g:js_indent_flat_switch = 0
endif

" Setup
" ------------------------------------------------------------------------------
" The expression used to calculate the indent for a line
setlocal indentexpr=GetJsIndent(v:lnum)

" The keys that, when typed, will cause the indent to be calculated
setlocal indentkeys=0],0),0},:,!^F,o,O,e

" If this script has already been loaded, exit
if exists('*GetJsIndent')
  finish 
endif

" Get proper shiftwidth value
if exists('*shiftwidth')
  function s:shiftwidth() abort
    return shiftwidth()
  endfunc
else
  function s:shiftwidth() abort
    return &shiftwidth
  endfunc
endif

" Variables
" ----------------------------------------------------------------------------
" Inline comments (for anchoring other statements)
let s:js_line_comment = '\(\/\/.*\)\?'
let s:js_mid_line_comment = '\(\/\*.*\*\/\s*\)*'
let s:js_end_line_comment = s:js_mid_line_comment . s:js_line_comment

let s:fluent_accessor = '^\s*\.\w'

" Indenter
" ----------------------------------------------------------------------------
function GetJsIndent(lnum) abort
  " This calls a helper method so we can easily log the final indent value
  " (GetIndent has many return points).
  let ind = s:GetIndent(a:lnum)
  return ind
endfunction

" Calculate the indent for a line number
function s:GetIndent(lnum) abort
  " In general, a line will either affect indentation or not. Things that
  " affect indentation include:
  "
  "   * Leaving a container open (parenthetical, block, array, case,
  "     default, block comment)
  "   * Starting, but not finishing, a var declaration statement or
  "     assignment
  "   * Closing a container
  "   * Ending a multi-line var declaration or assignment
  "
  " If a line or a previous line doesn't contain something that should
  " affect indentation, the current line's indentation will be the same as
  " the previous line's.

  let pnbnum = prevnonblank(a:lnum - 1)
  let ind = indent(pnbnum)
  if s:IsBlockCommentStart(pnbnum)
    return ind + 1
  endif

  if s:IsBlockCommentEnd(pnbnum)
    return ind - 1
  endif

  if s:IsComment(pnbnum)
    return ind
  endif

  if s:ClosesContainerAtStart(a:lnum)
    return indent(s:GetContainerStart(a:lnum, 0))
  endif

  if s:IsSwitchLabel(a:lnum)
    let csnum = s:GetSwitchStart(a:lnum)
    if csnum != -1
      if g:js_indent_flat_switch
        return indent(csnum)
      else 
        return indent(csnum) + s:shiftwidth()
      endif
    endif
  endif

  if s:StartsFluentAccess(a:lnum)
    return ind + s:shiftwidth()
  endif

  if s:IsSwitchLabel(pnbnum)
    return ind + s:shiftwidth()
  endif

  if s:ClosesContainerAtEnd(pnbnum)
    return indent(s:GetContainerStart(pnbnum, 1))
  endif

  if s:EndsMultiLineVar(pnbnum) || s:EndsMultiLineAssignment(pnbnum)
    return ind - s:shiftwidth()
  endif

  if s:OpensContainer(pnbnum)
    let csnum = s:GetControlBlockStart(pnbnum)
    if csnum != -1
      " If the current line opens a conainer that's associated with a
      " control block, like
      "
      "     function (...,
      "         ...) {
      "
      " we don't want to double-indent, so base the indent off the indent of
      " the start of the control statement.
      return indent(csnum) + s:shiftwidth()
    else 
      return ind + s:shiftwidth()
    endif
  endif

  if s:StartsMultiLineVar(pnbnum) || s:StartsMultiLineAssignment(pnbnum)
    return ind + s:shiftwidth() 
  endif

  return ind
endfunction

" Utility functions
" ----------------------------------------------------------------------------
" Returns a non-zero number if a line starts by closing a container.
function s:ClosesContainerAtStart(lnum) abort
  let line = getline(a:lnum)
  let result = line =~# '^\s*' . s:js_mid_line_comment . '[})\]]'
  return result
endfunction 

" Returns a non-zero number if a line ends by closing some open container.
function s:ClosesContainerAtEnd(lnum) abort
  let line = getline(a:lnum)
  let result = 0
  let close_at_end = line =~# s:js_mid_line_comment . '[})\]][,;]\?' .
        \ s:js_end_line_comment . '$'
  if close_at_end 
    let result = s:OpensOrClosesContainer(a:lnum, 1)
  endif
  return result
endfunction


" Returns a non-zero number if a line ends a multi-line assignment.
"
"     var x = a + b + c
"         + d;            <--- 
"
function s:EndsMultiLineAssignment(lnum) abort
  let result = s:EndsMultiLineStatement(a:lnum, 's:StartsMultiLineAssignment')
  return result
endfunction

" Returns a non-zero number if a multi-line declaration or assignment
" statement ends on the given line.
function s:EndsMultiLineStatement(lnum, check) abort
  let line = getline(a:lnum)
  let ends_statement = line =~# ';\s*' . s:js_end_line_comment . '$'
  let result = 0
  if ends_statement
    " This line ends a statement. Find the previous non-comment line with
    " a lower indent and see if it starts a multi-line statement.
    let dinum = s:GetPreviousDeindent(a:lnum)
    if dinum
      let result = call(a:check, [dinum])
    endif
  endif
  return result
endfunction

" Returns a non-zero number if a multi-line var statement ends on the given
" line.
"
"     var a,
"         b;     <---
"
function s:EndsMultiLineVar(lnum) abort
  let result = s:EndsMultiLineStatement(a:lnum, 's:StartsMultiLineVar')
  return result
endfunction 

" Returns the line number with the pair character for the container character
" that starts the given line.
"
"     arr.push([   <--- container start
"        ...
"     ]);          <--- current line 
"
function s:GetContainerStart(lnum, fromEnd) abort
  let line = getline(a:lnum)

  " \zs resets the match position at that point
  if a:fromEnd
    let container_char_idx = match(line, s:js_mid_line_comment .
          \ '\zs[})\]][;,]\?' . s:js_end_line_comment . '$')
  else 
    let container_char_idx = match(line, '^\s*' . s:js_mid_line_comment .
          \ '\zs[})\]]')
  endif 


  let container_char = line[container_char_idx]

  " If char is a '}', this is the end of a block, and is associated with a
  " control statement or an object
  if container_char ==# '}'
    let snum = s:SearchForPairStart(a:lnum, container_char_idx + 1, '{',
          \ '}')
    let csnum = s:GetControlBlockStart(snum)
    if csnum != -1
      " The block is associated with a control structure, so the indent
      " should be that of the control structure start
      let result = csnum
    else
      " The block isn't associated with a control structure, so use the
      " indent of the block's opening line
      let result = snum 
    endif
  elseif container_char ==# ')'
    let result = s:SearchForPairStart(a:lnum, container_char_idx + 1, '(', ')')
  else
    let result = s:SearchForPairStart(a:lnum, container_char_idx + 1, '\[', ']')
  endif

  return result
endfunction

" Returns the number of the first line of the control statement that the block
" starting on the given line is associated with.
"
"     function (...   <--- control start
"         ...) {      <--- block start
"         ...
"     }               <--- current line
"
function s:GetControlBlockStart(lnum) abort abort
  let result = -1
  let line = getline(a:lnum)
  let paren_end = match(line, ')\s*' . s:js_mid_line_comment . '{' .
        \ s:js_end_line_comment . '$')
  if paren_end != -1
    " Column numbers start at 1
    let result = s:SearchForPairStart(a:lnum, paren_end + 1, '(', ')')
  endif 
  return result
endfunction

" Returns the first non-comment line before the given line with a lower
" indent than the given line's.
function s:GetPreviousDeindent(lnum) abort abort
  let lind = indent(a:lnum)
  let pnum = s:GetPreviousNonCommentLine(a:lnum - 1)
  let pind = indent(pnum)
  while pnum > 0 && pind >= lind 
    let pnum = s:GetPreviousNonCommentLine(pnum - 1)
    let pind = indent(pnum)
  endwhile
  return pnum
endfunction

" Returns the number of the first non-blank line at or before lnum that is not
" in a block comment.
function s:GetPreviousNonCommentLine(lnum) abort abort
  let result = 0 
  let pnum = prevnonblank(a:lnum)
  while pnum > 0 && !result
    if !s:IsInBlockComment(pnum)
      let result = pnum 
    else 
      let pnum = prevnonblank(pnum - 1)
    endif
  endwhile 
  return result
endfunction

" Get the first line of the switch statement that the block starting on the
" given line is associated with
"
"     switch (foo) {    <---
"         case a:
"             ...
"
function s:GetSwitchStart(lnum) abort
  let result = s:SearchForPair(a:lnum, 1, '\<switch\s*(.*)\_s*{', '}', 1)
  return result
endfunction

" Returns a non-zero number if a line ends a block comment.
"
"     /* this is something
"     to write about */       <---
"
function s:IsBlockCommentEnd(lnum) abort
  let line = getline(a:lnum)
  let result = line =~# '^\s*\*\/'
  return result
endfunction

" Returns a non-zero number if a block comment starts, but does not end, on a
" given line.
function s:IsBlockCommentStart(lnum) abort
  let line = getline(a:lnum)
  let result = 0
  if line =~# '^\s*\/\*'
    let incmt = matchstr(line, '^\s*\/\*\*\?\zs.*$')
    let result = incmt !~# '\*\/'
  endif
  return result
endfunction

" Returns a non-zero number if a line is entirely a comment.
function s:IsComment(lnum) abort
  let line = getline(a:lnum)
  let result = line =~# '^\s*\/\/.*$'
  if !result 
    let result = s:IsInBlockComment(a:lnum)
  endif
  return result
endfunction

" Returns a non-zero number if the first character in a line is part of a
" block comment.
"
"     /* this is something
"     to write about */       <---
"
function s:IsInBlockComment(lnum) abort
  let lineType = synIDattr(synID(a:lnum, 1, 1), 'name')
  let result = lineType ==# 'javascriptComment' ||
        \ lineType ==# 'jsBlockComment'
  return result
endfunction

" Returns a non-zero number if a line contains a complete switch label
"
"     switch (foo) {
"         case a:           
"             console.log('bar');
"             break;
"         case b: x = y; break;    <---
"     }
"
function s:IsSingleLineSwitchLabel(lnum) abort
  let result = s:IsSwitchLabel(a:lnum)
  if result != -1
    let line = getline(a:lnum)
    let pos = match(line, '^\s*' . s:js_mid_line_comment .
          \ '\%(\<case\>\s\+.*\|default\)\s*:\zs.*')
    if pos != -1
      let result = line[pos :] !~ '\s*' . s:js_mid_line_comment .
            \ '\<break\>\s*;\?\s*' . s:js_end_line_comment . '$'
    endif
  endif 
  return result
endfunction

" Returns a non-zero number if a line opens a switch label.
"
"     switch (foo) {
"         case a:                  <---
"             console.log('bar');
"             break;
"         case b: x = y; break;
"     }
"
function s:IsSwitchLabel(lnum) abort
  let line = getline(a:lnum)
  let result = line =~# '^\s*' . s:js_mid_line_comment .
        \ '\%(\<case\>\s\+.*\|default\)\s*:'
  return result
endfunction

" Returns a non-zero number if a line is a switch label
"
"     switch (foo) {    <---
"         case a:
"             ...
"
function s:IsSwitchStart(lnum) abort
  let line = getline(a:lnum)
  let switch_start = '\<switch\s*(.*)\_s*{'
  let result = line =~# switch_start . '\s*' . s:js_end_line_comment . '$'
  if !result 
    let pnbnum = s:GetPreviousNonCommentLine(a:lnum - 1)
    let result = line =~# switch_start . '\s*' . s:js_end_line_comment . '$'
  endif
  return result
endfunction

" Returns a non-zero number if a line opens some container ({...}, (...),
" [...]) without closing it.
function s:OpensContainer(lnum) abort
  let result = s:OpensOrClosesContainer(a:lnum, 0)
  return result
endfunction

" Returns a non-zero number if a line opens a container without closing it, or
" closes a previously open container.
function s:OpensOrClosesContainer(lnum, closes) abort
  let line = s:StripComments(getline(a:lnum))
  let len = strlen(line)

  if a:closes
    let chars = ['}', ']', ')']
    let searcher = 's:SearchForPairStart'
  else
    let chars = ['{', '[', '(']
    let searcher = 's:SearchForPairEnd'
  endif

  let i = 0
  let result = 0
  while i < len && !result 
    " ignore strings and comments
    let c = line[i]
    let idx = index(chars, c)
    if idx != -1
      let col = i + 1
      if synIDattr(synID(a:lnum, col, 0), 'name') !~# 'String'
        if idx == 0
          let pair_match = call(searcher, [a:lnum, col, '{', '}'])
        elseif idx == 1
          let pair_match = call(searcher, [a:lnum, col, '\[', ']'])
        else
          let pair_match = call(searcher, [a:lnum, col, '(', ')'])
        endif

        let result = pair_match != a:lnum
      endif
    endif
    let i += 1
  endwhile
  return result
endfunction

" Returns the number of the line containing the matching tag of a given
" begin/end pair. By default, the function looks forward from the given line
" and column.
function s:SearchForPair(lnum, cnum, beg, end, backwards) abort
  " Save the cursor position
  let curpos = getpos('.')

  call cursor(a:lnum, a:cnum)

  " Search for the opening tag
  let flags = 'W'
  if a:backwards 
    let flags = 'bW'
  endif

  " Find a matching pair character that isn't in a comment, string, or regexp
  let pos = searchpairpos(a:beg, '', a:end, flags,
        \ 'synIDattr(synID(line("."), col("."), 0), "name") =~?
        \ "\%(Comment\|String\|Regexp\|jsDoc\)"')
  let result = pos[0]

  " Restore the cursor position
  call cursor(curpos[1], curpos[2])

  return result
endfunction

" Returns the number of the line containing the end tag of a given pair
" starting from the given line.
function s:SearchForPairEnd(lnum, cnum, beg, end) abort
  return s:SearchForPair(a:lnum, a:cnum, a:beg, a:end, 0)
endfunction

" Returns the number of the line containing the beginning tag of a given pair
" starting from the given line.
function s:SearchForPairStart(lnum, cnum, beg, end) abort
  return s:SearchForPair(a:lnum, a:cnum, a:beg, a:end, 1)
endfunction

" Returns true if a line is the first line of a fluent function call chain
function s:StartsFluentAccess(lnum) abort
  let line = getline(a:lnum)
  let result = line =~ s:fluent_accessor
  if result 
    let pnbnum = prevnonblank(a:lnum - 1)
    let pnbline = getline(pnbnum)
    let result = pnbline !~# s:fluent_accessor
  endif
  return result
endfunction

" Returns true if a line starts a multi-line assignment, like
"
"     var x = a + b + c   <---
"         + d;
"
function s:StartsMultiLineAssignment(lnum) abort
  let line = s:StripComments(getline(a:lnum))
  let line = s:StripStrings(line)
  " Count lines that have "x = something" but that don't end with ; or , or
  " {
  let result = line =~# '\w\S*\s*=[^>]' && line !~# '=[^>].*[;,{]\s*$'
  return result
endfunction 

" Returns a non-zero number if a line opens a var block.
"
"     var x,    <--- 
"         y;
"
function s:StartsMultiLineVar(lnum) abort
  let line = getline(a:lnum)
  let result = line =~# '\<var\s\+\w\+\>.*,' . s:js_end_line_comment . '$'
  return result
endfunction

" Returns a string that is the given line with all comments removed.
function s:StripComments(line) abort
  let line = substitute(a:line, '^.*\*\/', '', '')
  let line = substitute(line, s:js_mid_line_comment, '', 'g')
  let line = substitute(line, s:js_end_line_comment, '', '')
  return line
endfunction 

" Returns a string that is the given line with all strings removed. This
" function assumes strings open and close on a single line.
function s:StripStrings(line) abort
  let line = substitute(a:line, "'.\\{-}[^\\\\]'", '', 'g')
  let line = substitute(line, '".\{-}[^\\]"', '', 'g')
  return line
endfunction 

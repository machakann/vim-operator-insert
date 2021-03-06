" operator-insert - operator-insert is an operator for inserting to head(or tail) of textobject
" Version: 0.1.0
" Copyright (C) 2013-2014 deris0126
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}

if exists('g:loaded_operator_insert')
  finish
endif
let g:loaded_operator_insert = 1

let s:save_cpo = &cpo
set cpo&vim


" call operator#user#define('insert-i', 'operator#insert#insert_i', 'call operator#insert#ground_state()')
" call operator#user#define('insert-a', 'operator#insert#insert_a', 'call operator#insert#ground_state()')
nnoremap <silent> <Plug>(operator-insert-i) :<C-u>call operator#insert#map_clerk('i')<CR>
nnoremap <silent> <Plug>(operator-insert-a) :<C-u>call operator#insert#map_clerk('a')<CR>
nnoremap <silent> <Plug>(operator-insert-o) :<C-u>call operator#insert#map_clerk('o')<CR>
nnoremap <silent> <Plug>(operator-insert-O) :<C-u>call operator#insert#map_clerk('O')<CR>
xnoremap <silent> <Plug>(operator-insert-i) :<C-u>setl operatorfunc=operator#insert#insert_i<CR>:call operator#insert#ground_state()<CR>gv:<C-u>call operator#insert#insert_i(visualmode(), 'x')<CR>
xnoremap <silent> <Plug>(operator-insert-a) :<C-u>setl operatorfunc=operator#insert#insert_a<CR>:call operator#insert#ground_state()<CR>gv:<C-u>call operator#insert#insert_a(visualmode(), 'x')<CR>
xnoremap <silent> <Plug>(operator-insert-o) :<C-u>setl operatorfunc=operator#insert#insert_o<CR>:call operator#insert#ground_state()<CR>gv:<C-u>call operator#insert#insert_o(visualmode(), 'x')<CR>
xnoremap <silent> <Plug>(operator-insert-O) :<C-u>setl operatorfunc=operator#insert#insert_O<CR>:call operator#insert#ground_state()<CR>gv:<C-u>call operator#insert#insert_O(visualmode(), 'x')<CR>

onoremap <silent><expr> <Plug>(gn-for-operator-insert-i) operator#insert#textobj#gn_for_operator_insert_i()
onoremap <silent><expr> <Plug>(gN-for-operator-insert-a) operator#insert#textobj#gN_for_operator_insert_a()

let &cpo = s:save_cpo
unlet s:save_cpo

" __END__
" vim: foldmethod=marker

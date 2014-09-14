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

let s:save_cpo = &cpo
set cpo&vim

" Public API {{{1

function! operator#insert#map_clerk(ai)
  return s:operator_insert_map_clerk(a:ai)
endfunction

function! operator#insert#insert_i(motion_wise)
  return s:operator_insert_origin('i', a:motion_wise)
endfunction

function! operator#insert#insert_a(motion_wise)
  return s:operator_insert_origin('a', a:motion_wise)
endfunction



" The variable to stop execution.
" When s:bool_activity is 0, do not execute action.
" Currently it is used only by auxiliary textobjects.
let s:bool_activity = 1

function! operator#insert#deactivate()
  let s:bool_activity = 0
endfunction

function! operator#insert#activate()
  let s:bool_activity = 1
endfunction

"}}}

" Public, but it is *not* recommended to be used by users. {{{1

" Set state to ground state. It is used when keymappings are triggered.
function! operator#insert#ground_state()
  call s:set_info('state', 0)

  " kill quencher
  augroup operator-insert
    autocmd! * <buffer>
  augroup END
endfunction

" It is used for quenching the state from the super-excited state to the first
" excited state. This transition switches off the skipping behavior of
" auxiliary textobjects.
function! operator#insert#quench_state()
  call s:set_info('state', 1)

  " kill quencher
  augroup operator-insert
    autocmd! * <buffer>
  augroup END
endfunction

function! operator#insert#restore_view()
  " restore view
  let view = s:get_info('view')
  if view != {}
    call winrestview(view)
  endif

  " restore marks
  let [head, tail] = s:get_info('modifymarks')
  if head != s:null_pos && tail != s:null_pos
    call setpos("'[", head)
    call setpos("']", tail)
    call s:set_info('modifymarks', copy(s:null_region))
  endif
endfunction

" To bring script-local functions safely as possible
function! operator#insert#funcref_mediator(list)
  let funcrefs = []
  for name in a:list
    let funcrefs += [function('s:' . name)]
  endfor
  return funcrefs
endfunction

"}}}

" Private {{{1

" The definition of null position and region
let s:null_pos    = [0, 0, 0, 0]
let s:null_region = [s:null_pos, s:null_pos]

" motions and textobjects
let s:motions = [
  \ "h", "\<Left>", "\<C-h>", "\<BS>", "l", "\<Right>", "\<Space>", "0",
  \ "\<Home>", "^", "$", "\<End>", "g_", "g0", "g\<Home>", "g^", "gm",
  \ "g$", "g\<End>", "|", ";", ",", "k", "\<Up>", "\<C-p>", "j",
  \ "\<Down>", "\<C-j>", "\<C-n>", "gk", "g\<Up>", "gj", "g\<Down>", "-",
  \ "G", "\<C-End>", "\<C-Home>", "gg", "%", "go", "\<S-Right>", "w",
  \ "\<C-Right>", "W", "e", "E", "\<S-Left>", "b", "\<C-Left>", "B", "ge",
  \ "gE", "(", ")", "{", "}", "]]", "][", "[[", "[]", "[(", "[{", "])",
  \ "]}", "[m", "]m", "[M", "]M", "[#", "]#", '[\*', "[/", ']\*', "]/",
  \ "H", "M", "L", "\<LeftMouse>", "['", "]'", "[`", "]`", "g'a", "g'b",
  \ "g'c", "g'd", "g'e", "g'f", "g'g", "g'h", "g'i", "g'j", "g'k", "g'l",
  \ "g'm", "g'n", "g'o", "g'p", "g'q", "g'r", "g's", "g't", "g'u", "g'v",
  \ "g'w", "g'x", "g'y", "g'z", "g''", "g'`", "g'\"", "g'[", "g']", "g'<",
  \ "g'>", "g'^", "g'.", "g'(", "g')", "g'{", "g'}", "g`a", "g`b", "g`c",
  \ "g`d", "g`e", "g`f", "g`g", "g`h", "g`i", "g`j", "g`k", "g`l", "g`m",
  \ "g`n", "g`o", "g`p", "g`q", "g`r", "g`s", "g`t", "g`u", "g`v", "g`w",
  \ "g`x", "g`y", "g`z", "g`'", "g``", "g`\"", "g`[", "g`]", "g`<", "g`>",
  \ "g`^", "g`.", "g`(", "g`)", "g`{", "g`}"
  \ ]
let s:textobjects = ["aw", "iw", "aW", "iW", "as", "is", "ap", "ip", "a[",
  \ "a]", "i[", "i]", "a(", "a)", "ab", "i(", "i)", "ib", "a<", "a>",
  \ "i<", "i>", "at", "it", "a{", "a}", "aB", "i{", "i}", "iB", 'a"',
  \ "a'", "a`", 'a"', "i'", "i`"
  \ ]



""" The mapping clerk to manage required infomation
" The problem is that a operator can not know which textobjects/motions
" assigned to itself while a textobject/motion can know what operator is
" reserved for it.
" FIXME: Refactoring is requied!
function! s:operator_insert_map_clerk(ai) "{{{
  let pre_count = v:count1

  call s:update_cmdline_echo('')

  " start accepting an user input
  let keyseq = ''
  let c = getchar()
  let c = type(c) == type(0) ? nr2char(c) : c

  let flag_matched = 0
  if !(c ==# "\<Esc>" || c ==# "\<C-c>")
    let keyseq .= c
    call s:update_cmdline_echo(keyseq)

    if c =~# '\d'
      " check user defined keymappings consisting only of number
      let userdef_lhs  = []
      while c =~# '\d'
        let pattern = '\m' . keyseq . '\d*'
        let userdef_lhs += filter(map(s:list_up_user_mappings('o', keyseq),
              \   'v:val[2] ==# "\<Nop>" ? "" : v:val[1]'), 'v:val =~# pattern')
        if userdef_lhs != []
          let temp = filter(copy(userdef_lhs),
                \   'keyseq =~# ''\m^\d*'' . v:val . ''$''')
          if temp != []
            let userdef_lhs = temp
            let flag_matched = 1
            break
          endif
        endif

        let c = getchar()
        let c = type(c) == type(0) ? nr2char(c) : c
        let keyseq .= c
        call s:update_cmdline_echo(keyseq)
      endwhile
    endif

    if flag_matched != 1
      """ rebuild default/userdef_lhs
      " list up concerned lhs in default mappings
      let default_lhs = filter(map(copy(s:textobjects) + copy(s:motions),
            \ '[v:val, s:convert_to_partial_matching_pattern(v:val, [])]'),
            \ 'keyseq =~# ''\m^\d*'' . v:val[1]')

      " list up concerned lhs in user defined mappings
      let userdef_map = []
      for idx in range(strlen(keyseq))
        if keyseq[idx] =~# '\m\d' || keyseq[:idx] =~# '\m^\d*\D'
          let userdef_map += s:list_up_user_mappings('o', keyseq[idx :])
        endif
      endfor

      " remove overwritten default mappings
      let userdef_lhs = map(copy(userdef_map), 'v:val[1]')
      call filter(default_lhs,
            \ 'match(userdef_lhs, ''\m\C^'' . v:val[0] . ''$'') == -1')
      " remove disabled mappings
      let userdef_lhs = filter(map(copy(userdef_map),
            \ 'v:val[2] ==# "\<Nop>" ? "" : v:val[1]'), 'v:val != ""')
      " add partial matching patterns
      let plug_map_list = map(s:list_up_user_mappings('o', '<Plug>'),
            \ 'matchstr(v:val[1], ''^<Plug>\zs.*'')')
      call map(userdef_lhs,
            \ '[v:val, s:convert_to_partial_matching_pattern(v:val, plug_map_list)]')

      let matched_at = ''
      if c =~# '[/?:]'
        if userdef_lhs != []
          let default_lhs = []
          let [keyseq, preserved, matched_at] =
                \   s:match_mapping(keyseq, userdef_lhs, default_lhs)

          if keyseq == ''
            let keyseq = preserved
            call s:set_info('commandline', c)
          endif
        else
          call s:set_info('commandline', c)
        endif
      elseif c =~? '[ft]' || c =~# '[''`]'
        let default_lhs = []
        let [keyseq, preserved, matched_at] =
              \   s:match_mapping(keyseq, userdef_lhs, default_lhs)

        if keyseq == ''
          let c = preserved[-1]
          if (preserved =~# '\m^\d*[ft''`].$') && !(c ==# "\<Esc>" || c ==# "\<C-c>")
            let keyseq = preserved
          else
            let keyseq = ''
          endif
        endif
      else
        let [keyseq, _, matched_at] =
              \   s:match_mapping(keyseq, userdef_lhs, default_lhs)
      endif
    endif

    if matched_at != ''
      if matched_at ==# 'u'
        let lhs_list = userdef_lhs
      else
        if userdef_lhs == []
          let lhs_list = default_lhs
        else
          let lhs_list = userdef_lhs + default_lhs
        endif
      endif
    else
      let lhs_list = []
    endif
  endif

  " To suppress hit-enter prompt
  normal! :
  redraw

  if keyseq != ''
    if len(lhs_list) < 2
      " save count
      call s:set_info('count', pre_count)

      " save key sequence and queue it
      call s:set_info('keyseq', keyseq)
      execute 'setlocal operatorfunc=operator#insert#insert_' . a:ai
      call operator#insert#ground_state()
      call feedkeys(pre_count . 'g@' . keyseq)
    else
      let transferred_mappings = map(lhs_list, 's:transfer_mapping(a:ai, v:val[0])')
      call s:set_info('transferred_mappings', transferred_mappings)

      " save count
      call s:set_info('count', pre_count)

      " save key sequence and queue it
      call s:set_info('keyseq', keyseq)
    endif
  endif
endfunction
"}}}
function! s:list_up_user_mappings(prefix, fraction) "{{{
  redir => map_output
    execute 'silent! ' . a:prefix . 'map ' . a:fraction
  redir END

  let map_output_list = []
  for line in split(map_output, "\n")
    if match(line, '\m\C^[ nvsxo!ilc]\{3}[^ ]\+\s\+[*&@]\?\s\+.*') >= 0
      let map_output_list += [line]
    else
      if map_output_list == []
        break
      else
        let map_output_list[-1] .= line
      endif
    endif
  endfor

  let user_mappings = []
  for line in map_output_list
    let [_, mode, lhs, rhs, _, _, _, _, _, _]
      \ = matchlist(line, '\m\C\(^[ nvsxo!ilc]\{3}\)\([^ ]\+\)\s\+[*&@]\?\s\+\(.*\)')

    let user_mappings += [[mode, lhs, rhs]]
  endfor

  return user_mappings
endfunction
"}}}
function! s:match_mapping(keyseq, userdef_lhs, default_lhs) "{{{
  let keyseq     = a:keyseq
  let preserved  = keyseq
  let matched_at = ''

  while 1
    if a:userdef_lhs != []
      call filter(a:userdef_lhs, 'keyseq =~# ''\m^\d*'' . v:val[1]')
      let temp = filter(copy(a:userdef_lhs),
            \ 'keyseq =~# ''\m^\d*'' . v:val[0] . ''$''')
      if temp != []
        if len(temp) > 1
          call map(copy(a:userdef_lhs), 'v:val[0]')
          call filter(a:userdef_lhs,
                \ 'match(a:userdef_lhs, ''\m\C^\d\+'' . v:val[0]) == -1')
        endif

        let matched_at = 'u'
        break
      endif
    endif

    if a:default_lhs != []
      call filter(a:default_lhs, 'keyseq =~# ''\m^\d*'' . v:val[1]')
      let temp = filter(copy(a:default_lhs),
            \ 'keyseq =~# ''\m^\d*'' . v:val[0] . ''$''')
      if temp != []
        if len(temp) > 1
          call map(copy(a:default_lhs), 'v:val[0]')
          call filter(a:default_lhs,
                \ 'match(a:default_lhs, ''\m\C^\d\+'' . v:val[0]) == -1')
        endif

        let matched_at = 'd'
        break
      endif
    endif

    if a:userdef_lhs == [] && a:default_lhs == []
      " no candidate!
      let keyseq = ''
      break
    endif

    let c = getchar()
    let c = type(c) == type(0) ? nr2char(c) : c
    let keyseq .= c
    let preserved = keyseq
    call s:update_cmdline_echo(keyseq)
  endwhile

  return [keyseq, preserved, matched_at]
endfunction
"}}}
let s:plug_cap = "\<Plug>"
let s:composit_cap = s:plug_cap[0]
function! s:convert_to_partial_matching_pattern(string, plug_map_list)  "{{{
  if strlen(a:string) == 1
    return a:string
  endif

  if a:string =~# '^' . s:composit_cap . '..$'
    return a:string
  endif

  if match(a:string, s:composit_cap) == -1
    let chars = split(a:string, '\zs')
  else
    let idx = 0

    let plug_regions = []
    for item in a:plug_map_list
      let n = 1
      while 1
        let head = match(a:string, escape(item, '~"\.^$[]*'), 0, n)
                      \ - strlen(s:plug_cap)
        let tail = matchend(a:string, escape(item, '~"\.^$[]*'), 0, n)

        if head == -1 || tail == -1
          break
        else
          let plug_regions += [[head, tail]]
          let n += 1
        endif
      endwhile
    endfor

    let chars = []
    let len   = strlen(a:string)
    while idx < len
      if a:string[idx] ==# s:composit_cap
        let includings = filter(copy(plug_regions),
              \             'idx >= v:val[0] && idx <= v:val[1]')
        if len(includings)
          let tail   = max(map(includings, 'v:val[1]'))
          let chars += [a:string[idx : tail-1]]
          let idx    = tail
        else
          let chars += [a:string[idx : idx+2]]
          let idx   += 3
        endif
      else
        let chars += [a:string[idx]]
        let idx   += 1
      endif
    endwhile
  endif

  call insert(chars, '\%[', 1)
  let chars += [']$']
  return join(map(map(chars, 'v:val ==# ''['' ? ''[[]'' : v:val'),
            \ 'v:val ==# '']'' ? ''[]]'' : v:val'), '')
endfunction
"}}}
function! s:transfer_mapping(ai, lhs) "{{{
  execute 'onoremap <silent><buffer> ' . lhs . ' :call <SID>settled_competitive_mappings(' . ai . ', ' . a:lhs . ")\<CR>"
  return maparg(a:lhs, 'o', 0, 1)
endfunction
"}}}
function! s:revert_mapping(map) "{{{
  let cmd  = a:map.noremap ? 'onoremap' : 'omap'
  let attr = join([
        \   a:map.silent ? '<silent>' : '',
        \   a:map.expr   ?  '<expr>'  : '',
        \   a:map.buffer ? '<buffer>' : '',
        \   a:map.nowait ? '<nowait>' : '',
        \ ], '')
  let lhs  = a:map.lhs
  let rhs  = match(a:map.rhs, '<SID>') > -1
        \  ? substitute(a:map.rhs, '<SID>', "\<SNR>" . a:map.sid . '_', 'g')
        \  : rhs
  execute printf('%s %s %s %s', cmd, attr, lhs, rhs)
  return ''
endfunction
"}}}
function! s:settled_competitive_mappings(ai, residue) "{{{
  let l:count = s:get_info('count')
  let keyseq  = s:get_info('keyseq')

  let keyseq .= a:residue

  " save key sequence and queue it
  call s:set_info('keyseq', keyseq)
  execute 'setlocal operatorfunc=operator#insert#insert_' . a:ai
  call operator#insert#ground_state()
  call feedkeys(l:count . 'g@' . keyseq)

  " revert transferred mappings
  let transferred_mappings = s:get_info('transferred_mappings')
  call map(transferred_mappings, 's:revert_mapping(v:val)')
  call s:set_info('transferred_mappings', [])
endfunction
"}}}
function! s:update_cmdline_echo(keyseq) "{{{
  normal! :
  execute 'echon printf("%s%' . (&columns - 11) . 'sg@%.9s", repeat("\n", &cmdheight - 1), "", a:keyseq)'
endfunction
"}}}



""" The original of each operator
function! s:operator_insert_origin(ai, motion_wise) "{{{
  " if it is not active, then quit immediately
  if !s:is_active()
    call operator#insert#activate()
    return
  endif

  let state = s:get_info('state')

  if !state
    let head = getpos("'[")
    let tail = getpos("']")

    " record required infomation
    call s:set_info('motion_wise', a:motion_wise)
    call s:set_info('range', [head, tail])

    " reserve recorder (to save the inserted text)
    augroup operator-insert
      autocmd! * <buffer>
      if a:ai ==# 'i'
        autocmd InsertEnter <buffer> autocmd operator-insert InsertLeave
              \ <buffer> call s:delayed_execution('i')
      else
        autocmd InsertEnter <buffer> autocmd operator-insert InsertLeave
              \ <buffer> call s:delayed_execution('a')
      endif
      " for the safety (in case of the <C-c> use)
      autocmd InsertEnter <buffer> autocmd operator-insert InsertEnter
            \ <buffer> call operator#insert#quench_state()
    augroup END

    " get into insert mode
    call s:start_insert(a:ai, a:motion_wise)
  else
    " dot-repeat
    let insertion = s:get_info('last_insertion')
    if insertion != []
      " execute an action
      let base_indent = s:get_indent(getpos("'[")[1])
      let region = s:insert_{a:motion_wise}wise(a:ai, insertion, base_indent)

      " record the target region
      call s:set_info('last_target', region)

      " excite to the super-excited state
      call s:set_info('state', 2)

      " reserve quencher (to the first excited state)
      augroup operator-insert
        autocmd! * <buffer>
        autocmd TextChanged <buffer> autocmd operator-insert
              \ InsertEnter,CursorMoved,TextChanged,WinLeave,FileChangedShellPost
              \ <buffer> call operator#insert#quench_state()
      augroup END
    else
      " excite to the first excited state
      call s:set_info('state', 1)
    endif
  endif
endfunction
"}}}
function! s:delayed_execution(ai) "{{{
  augroup operator-insert
    autocmd! * <buffer>
  augroup END

  let motion_wise = s:get_info('motion_wise')
  let range       = s:get_info('range')

  let head = getpos("'[")
  let tail = getpos("']")

  if head != tail
    """ something inserted
    " cut and re-insert the text depending on a motion_wise
    let base_indent   = s:get_indent(head[1])
    let insertion     = s:cut_out_insertion()
    let target_region = s:insert_{motion_wise}wise(a:ai, insertion, base_indent, range)

    " record the inserted text
    call s:set_info('last_insertion', insertion)

    " record the target region
    call s:set_info('last_target', target_region)

    " record the modified region
    call s:set_info('modifymarks', [getpos("'["), getpos("']")])

    " excite to the super-excited state
    call s:set_info('state', 2)

    " air-shot just for registering the next dot-repeat candidate
    let l:count = s:get_info('count')
    let keyseq  = s:get_info('keyseq')
    let cmdline = s:get_info('commandline')
    if cmdline == ':'
      let keyseq = ':' . @: . "\<CR>"
    elseif cmdline =~# '[/?]'
      let keyseq = cmdline . @/ . "\<CR>"
    endif
    call s:set_info('commandline', '')
    call s:set_info('view', winsaveview())
    call operator#insert#deactivate()
    call feedkeys(l:count . 'g@' . keyseq)
    call feedkeys(":call operator#insert#restore_view()\<CR>", 'n')

    " reserve quencher (to the first excited state)
    call feedkeys(":autocmd operator-insert
          \ InsertEnter,CursorMoved,TextChanged,WinLeave,FileChangedShellPost
          \ <buffer> call operator#insert#quench_state()\<CR>
          \ :echo ''\<CR>", 'n')
  else
    """ nothing inserted
    " excite to the first excited state
    call s:set_info('state', 1)
  endif
endfunction
"}}}
function! s:start_insert(ai, motion_wise)  "{{{
  if a:ai ==# 'i'
    call cursor(getpos("'[")[1:])
    if a:motion_wise == "line"
      normal! ^
    endif
    startinsert
  else
    call cursor(getpos("']")[1:])
    if col("']") >= col("$") - 1
      startinsert!
    else
      normal! l
      startinsert
    endif
  endif
  call setpos("'[", getpos('.'))
  call setpos("']", getpos('.'))
endfunction
"}}}
function! s:insert_charwise(ai, insertion, base_indent, ...) "{{{
  if a:0 > 0
    call setpos("'[", a:1[0])
    call setpos("']", a:1[1])
  endif

  " memorize the position of target text
  let head_before = getpos("'[")
  let tail_before = getpos("']")

  if a:ai ==# 'i'
    call s:insert_text('', '`[""P', a:insertion, a:base_indent)

    " calculate the position of shifted target region
    if head_before[1] == tail_before[1]
      " the target text does not include any line-breaking
      let head_after = [0, line('.'), col('.') + 1, 0]
      let tail_after = [0, line('.'),
            \ col('.') + tail_before[2] - head_before[2] + 1, 0]
    else
      " the target text consists of several lines
      let head_after = [0, line('.'), col('.') + 1, 0]
      let tail_after = [0, line('.') - head_before[1] + tail_before[1],
            \ tail_before[2], 0]
    endif
    let region = [head_after, tail_after]
  else
    " record the region of target text
    let region = [head_before, tail_before]

    call s:insert_text('', '`]""p', a:insertion, a:base_indent)
  endif

  return region
endfunction
"}}}
function! s:insert_linewise(ai, insertion, base_indent, ...) "{{{
  if a:0 > 0
    call setpos("'[", a:1[0])
    call setpos("']", a:1[1])
  endif

  let [head, tail] = [line("'["), line("']")]

  if a:ai ==# 'i'
    " not sure... removing '^' might be more natural...
    for lnum in reverse(range(head, tail))
      call s:insert_text(lnum, '^""P', a:insertion, a:base_indent)
    endfor
  else
    for lnum in reverse(range(head, tail))
      call s:insert_text(lnum, '$""p', a:insertion, a:base_indent)
    endfor
  endif

  " set marks as wrapping whole lines
  let height = (len(a:insertion) - 1)*(tail - head + 1)
  call setpos("'[", [0, head, 0, 0])
  call setpos("']", [0, tail + height, col([tail + height, '$']), 0])

  " not required to store the target region in a linewise action
  return copy(s:null_region)
endfunction
"}}}
function! s:insert_blockwise(ai, insertion, base_indent, ...)  "{{{
  if a:0 > 0
    call setpos("'[", a:1[0])
    call setpos("']", a:1[1])
  endif

  let processed = []
  let height    = 0
  let increment = len(a:insertion)

  " lines: [lnum, length]
  let lines = reverse(map(range(line("'["), line("']")),
        \               '[v:val, strlen(getline(v:val))]'))

  if a:ai ==# 'i'
    let col   = col("'[")
    for line in lines
      if line[1] >= col
        call cursor(line[0], col)
        call s:insert_text('', '""P', a:insertion, a:base_indent)
        let processed += [line[0]]
        let height    += increment
      elseif line[1] == col - 1
        call cursor(line[0], col)
        call s:insert_text('', '""p', a:insertion, a:base_indent)
        let processed += [line[0]]
        let height    += increment
      endif
    endfor
  else
    let col = col("']")
    for line in lines
      if line[1] >= col
        call cursor(line[0], col)
        call s:insert_text('', '""p', a:insertion, s:get_indent(line[0]))
        let processed += [line[0]]
        let height    += increment
      endif
    endfor
  endif

  " set marks for the topleft and bottomright edge of the processed region
  if processed != []
    if len(a:insertion) > 1
      call setpos("'[", [0, processed[-1], col("'["), 0])
      call setpos("']", [0, processed[0] + height, col("']") - 1, 0])
    else
      call setpos("'[", [0, processed[-1], 0, 0])
      call setpos("']", [0, processed[0] + height,
            \ col([processed[0] + height, '$']), 0])
    endif
  endif

  " not required to store the target region in a blocwise action
  return copy(s:null_region)
endfunction
"}}}
function! s:insert_text(range, cmd, insertion, base_indent)  "{{{
  let insertion = deepcopy(a:insertion)

  " add indent to lines
  let insertion[0] = a:insertion[0][1]
  if len(insertion) > 1
    let insertion[1:-1] = map(insertion[1:-1],
          \ 's:put_tab(a:base_indent + v:val[0]) . v:val[1]')
  endif

  " insert lines
  let unnamed = @"
  let paste = &paste
  try
    let @" = join(insertion, "\n")
    set paste
    execute a:range . 'normal! ' . a:cmd
  finally
    let @" = unnamed
    let &paste = paste
    return
  endtry
endfunction
"}}}
function! s:cut_out_insertion() "{{{
  " save indent
  let shift_width = shiftwidth()
  let indent_list = map(range(line("'["), line("']")),
        \ 'indent(v:val)/shift_width')

  let string = ''
  let unnamed = @"
  try
    if col("']") == col([line("']"), '$'])
      execute 'normal! `[""dv`]'
    else
      execute 'normal! `[""d`]'
    endif
    let string = @"
  finally
    let @" = unnamed

    " split lines and delete indent
    let line_list = map(split(string, "\n", 1),
          \ 'substitute(v:val, ''^\s*\zs	\ze\s*\S'', repeat(" ", &tabstop), "g")')
    if len(line_list) > 1
      let line_list[1:] = map(range(1, len(indent_list) - 1),
            \ 'line_list[v:val][indent_list[v:val]*shift_width :]')
    endif

    " convert to relative indent
    let first_indent = indent_list[0]
    call map(indent_list, 'v:val - first_indent')

    " integrate lines and indentations to a list
    return map(range(len(indent_list)), '[indent_list[v:val], line_list[v:val]]')
  endtry
endfunction
"}}}
function! s:get_line_length(head, tail)  "{{{
  let before_head = map(getline(1, a:head[1]), 'strlen(v:val) + 1')
  let after_tail  = map(getline(a:tail[1], line('$')), 'strlen(v:val) + 1')

  let before_head[-1] = a:head[2]
  let after_tail[0]   = a:tail[2] - col([a:tail[1], '$'])
  return [before_head, after_tail]
endfunction
"}}}
function! s:compare_line_length(before, after)  "{{{
  let n_before = len(a:before[0])
  let n_after  = len(a:after[0])
  if n_before > n_after
    let n = n_before
    let n_after += repeat([0], n_before - n_after)
  elseif n_before < n_after
    let n = n_after
    let n_before += repeat([0], n_after - n_before)
  else
    let n = n_before
  endif

  let head = eval(join(map(range(n),
        \ 'n_before[0][v:val] - n_after[0][v:val]'), '+'))

  let n_before = len(a:before[1])
  let n_after  = len(a:after[1])
  if n_before > n_after
    let n = n_before
    let n_after += repeat([0], n_before - n_after)
  elseif n_before < n_after
    let n = n_after
    let n_before += repeat([0], n_after - n_before)
  else
    let n = n_before
  endif

  let tail = eval(join(map(range(n),
        \ 'n_before[1][v:val] - n_after[1][v:val]'), '+'))

  return [head, tail]
endfunction
"}}}
function! s:get_indent(lnum)  "{{{
  return indent(a:lnum)/shiftwidth()
endfunction
"}}}
function! s:put_tab(indent) "{{{
  let tabwidth = shiftwidth()*a:indent
  if &expandtab
    let tab = repeat(' ', tabwidth)
  else
    let tab = repeat('	', tabwidth/&tabstop) . repeat(' ', tabwidth%&tabstop)
  endif
  return tab
endfunction
"}}}
function! s:is_active() "{{{
  return s:bool_activity
endfunction
"}}}


" History and state management
" The required information is stored to buffer local variable named
" 'b:operator_insert_info' since 'operatorfunc' option is buffer local.

" The 'state' keeps managed to distinguish whether the operatorfunc was called
" by a keymapping or by the dot command. There are two excited states for
" dot-repeat callings. If it is called just after a keymapping action, then it
" is 'hot' calling. Otherwise it is regarded as 'cold' calling. 'Hot' calling
" changes the behavior of auxiliary textobjects, it would skip the closest
" searched word if necessary. After an action, the state is immediately cool
" down to the first excited state (s:get_info('state') == 1) if the next
" action is not the dot-repeat.
" s:get_info('state') == 0 : called by a keymapping
" s:get_info('state') == 1 : called by the dot command (cold-calling)
" s:get_info('state') == 2 : called by the dot command (hot-calling)

function! s:get_info(name)  "{{{
  if !exists('b:operator_insert_info')
    " initialization
    let b:operator_insert_info = {}
    let b:operator_insert_info.state = 0
    let b:operator_insert_info.last_insertion = []
    let b:operator_insert_info.last_target = copy(s:null_region)
    let b:operator_insert_info.modifymarks = copy(s:null_region)
    let b:operator_insert_info.motion_wise = ''
    let b:operator_insert_info.range = copy(s:null_region)
    let b:operator_insert_info.view = {}
    let b:operator_insert_info.count = 1
    let b:operator_insert_info.keyseq = ''
    let b:operator_insert_info.commandline = ''
    let b:operator_insert_info.transferred_mappings = []
  endif
  return b:operator_insert_info[a:name]
endfunction
"}}}
" NOTE: s:set_info() and s:add_info should be called only in the function
"       s:operator_insert_origin except for the case of 'state' key as
"       possible. Otherwise it is really easy to mess up.
function! s:set_info(name, value) "{{{
  if !exists('b:operator_insert_info')
    " initialization
    call s:get_info('state')
  endif
  let b:operator_insert_info[a:name] = a:value
endfunction
"}}}

"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" __END__ "{{{1
" vim: foldmethod=marker

let s:save_cpo = &cpo
set cpo&vim

" Public API {{{1

function! operator#insert#textobj#gn_for_operator_insert_i()
  return s:fixer('i')
endfunction

function! operator#insert#textobj#gN_for_operator_insert_a()
  return s:fixer('a')
endfunction

function! operator#insert#textobj#executer(ai, count, textobj, next)
  return s:executer(a:ai, a:count, a:textobj, a:next)
endfunction

"}}}

" Private {{{1

" The definition of null position and region
let s:null_pos    = [0, 0, 0, 0]
let s:null_region = [s:null_pos, s:null_pos]

" break the seal of funcrefs
" NOTE: s:set_info() should be called only in the function s:prototype except
"       for the case of 'state' key as possible. Otherwise it is really easy
"       to mess up.
let [s:get_info, s:set_info]
      \   = operator#insert#funcref_mediator(['get_info', 'set_info'])



" NOTE: These Textobjects are expected to be used like this:
"
"           nmap <Leader>ign
"             \  <Plug>(operator-insert-i)<Plug>(gn-for-operator-insert-i)
"
"       This method do not affect to the other usage of 'gn' with other
"       operators. A known problem is that one can not give {count} before
"       'gn'. If making several sets of keymappings, it is enough for practical
"       uses although I know it is not smart way...
"
"           nmap <Leader>i2gn
"             \  <Plug>(operator-insert-i)2<Plug>(gn-for-operator-insert-i)
"           nmap <Leader>i3gn
"             \  <Plug>(operator-insert-i)3<Plug>(gn-for-operator-insert-i)
"
"       Actually these textobjects could safely replace 'gn' and 'gN' due to
"       the fail-safe. So it is safe even if a user makes mappings mistakenly.
"
"           nmap gn <Plug>(gn-for-operator-insert-i)
"           nmap gN <Plug>(gN-for-operator-insert-a)
"
"       These mappings shows its unique behavior only when it is employed with
"       the correspondent operator-insert. Otherwise, when it is employed with
"       other operators, operator#insert#textobj#gn_for_operator_insert_i (or
"       operator#insert#textobj#gN_for_operator_insert_a) is called at first
"       keymapping call and it returns 'gn' (or 'gN') with <expr> mapping.
"       After that, never called these functions, just the original 'gn' (or
"       gN) works as usual. If I do not use <expr>, then the same function is
"       always called in each 'gn' (or 'gN') key presses, and there would be a
"       irritating and unsuppressable echoing at command-line.
"
" NOTE: If they are called in 'hot' state, they will try to search the next
"       target textobject (it is different from the one which is processed a
"       little while ago!). For example, a user searched 'bar' and insert
"       'foo' then:
"
"       foobar    bar   bar
"
"       At this moment, the cursor is on the last 'o' of foo. Thus the next
"       target is also the first 'bar', never reaches to the second 'bar'
"       usually. The alternative textobjects are served to overcome this
"       problem. The textobjects push 'n' (or 'N') twice to skip the first
"       'bar'. The first 'n' brings the cursor on the first 'bar' and the
"       following 'n' brings on the second 'bar' which is the very what we
"       want to process. (NOTE: If the cursor is on the searched word, 'gn'
"       and 'gN' do not move and process the current word.)
"
"       However it is not always correct. For instance if the searched pattern
"       is '\<bar', 'foobar' is no longer matched with '\<bar', therefore the
"       first 'n' brings to the appropriate target. The operator-insert saves
"       the region of the last processed target, these textobjects use it to
"       judge whether the second 'n' command is required or not.
"       If the searched command has flag like '/bar/e+1', there is the same
"       problem. In addition, there is the case that it is not needed to try
"       the first 'n' command.
"
"       If there is only one searched word in the buffer, then try 'n' command
"       twice and exit normally to execute for it when 'wrapscan' option is on.
"
"       If the searched word can not be found, then immediately quit loop and
"       cancel the operator.
"
" NOTE: If the searched word can not be found in 'cold' calling, the 'gn'
"       (or 'gN') command in s:operator_range_capture can not find the target
"       and s:operator_range_capture is cancelled. As a result,
"       s:capture_range will return s:null_region and textobjects will decide
"       to cancel the operator. (This is because 'gn' and 'gN' command do not
"       issue any exception like vim error 482 even if the searched word can
"       not be found.)

" Alternative gn, gN

function! s:fixer(ai)
  let [operatorfunc, textobj, next] = a:ai ==# 'i'
        \                           ? ['operator#insert#insert_i', 'gn', 'n']
        \                           : ['operator#insert#insert_a', 'gN', 'N']

  if !(v:operator ==# 'g@' && &operatorfunc ==# operatorfunc)
    " fail-safe
    let cmd = textobj
  else
    let cmd = printf(":\<C-u>call operator#insert#textobj#executer('%s',%d,'%s','%s')\<CR>",
          \           a:ai, v:count1, textobj, next)
  endif

  return cmd
endfunction

function! s:executer(ai, count, textobj, next)
  let state = s:get_info('state')
  let l:count = (state ? v:count1 : a:count)

  " save view
  let view = winsaveview()

  " save marks, '<, '>
  let lt = getpos("'<")
  let gt = getpos("'>")

  if state == 2
    " 'Hot' calling. Skip the closest target if in super-excited state
    let last_target = s:get_info('last_target')
    try
      for i in [1, 2]
        let target = s:capture_range(1, a:textobj, 1)
        " FIXME: Am I sure that this is the appropriate condition?
        if target != last_target | break | endif
        execute "normal! " . a:next
      endfor

      let target = s:capture_range(l:count, a:textobj, 1)
      let [head, tail] = target
    catch /^Vim\%((\a\+)\)\=:E\%(384\|385\|486\)/
      call s:error_handling_no_target(view, lt, gt)
    endtry
  else
    " Keymapping calling or 'cold' calling. Work as usual.
    let [head, tail] = s:capture_range(l:count, a:textobj, 1)
  endif

  if head != s:null_pos && tail != s:null_pos
    " select range
    normal! v
    call cursor(head[1:2])
    normal! o
    call cursor(tail[1:2])

    " counter measure for the 'selection' option being 'exclusive'
    if &selection == 'exclusive'
      normal! l
    endif
  else
    " no target
    call s:error_handling_no_target(view, lt, gt)
  endif
endfunction

function! s:capture_range(count, textobj, bang)
  let s:range = copy(s:null_region)
  let operatorfunc  = &operatorfunc
  let &operatorfunc = '<SID>operator_range_capture'
  try
    if a:bang
      execute 'normal! g@' . a:count . a:textobj
    else
      execute 'normal g@' . a:count . a:textobj
    endif
  finally
    let &operatorfunc = operatorfunc
    return s:range
  endtry
endfunction

function! s:operator_range_capture(motion_wise)
  let s:range = [getpos("'["), getpos("']")]
endfunction

function! s:error_handling_no_target(view, lt, gt)
  " echo error message
  echohl ErrorMsg
  echo 'operator-insert: No target has been found.'
  echohl NONE

  " restore view
  call winrestview(a:view)

  " restore visualmarks
  call setpos("'<", a:lt)
  call setpos("'>", a:gt)

  " deactivate operator-insert
  call operator#insert#deactivate()
endfunction

"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" __END__ "{{{1
" vim: foldmethod=marker

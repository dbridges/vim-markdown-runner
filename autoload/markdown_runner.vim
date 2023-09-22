" Run code block and echo results
function! markdown_runner#Echo() abort
  try
    let runner = s:RunCodeBlock()
    echo runner.result
  catch /.*/
    call s:error(v:exception)
  endtry
endfunction

" Run code block and insert results into buffer.{{{
" IF there is a fenced code block with language 'markdown-runner' below the
" current code block it will be replaced with the new results.
function! markdown_runner#Insert() abort
  try
    let runner = s:RunCodeBlock()
"}}}
    " Remove existing results if present{{{
    if getline(runner.end + 2) ==# '```markdown-runner'
      let save_cursor = getcurpos()
      call cursor(runner.end + 3, 0)
      let end_result_block_line = search('```', 'cW')
      if end_result_block_line
        if getline(end_result_block_line + 1) ==# ''
          call deletebufline(bufname("%"), runner.end + 2, end_result_block_line + 1) 
        else
          call deletebufline(bufname("%"), runner.end + 2, end_result_block_line) 
        endif
      endif
      call setpos('.', save_cursor)
    endif
    "}}}
    " Insert new results
    let result_lines = split(runner.result, '\n')
    call append(runner.end, '')
    call append(runner.end + 1, '```markdown-runner')
    call append(runner.end + 2, result_lines)
    call append(runner.end + len(result_lines) + 2, '```')
  catch /.*/
    call s:error(v:exception)
  endtry
endfunction

function! s:error(error)
  execute 'normal! \<Esc>'
  echohl ErrorMsg
  echo "MarkdownRunner: " . a:error
  echohl None
endfunction

function! s:RunCodeBlock() abort
  let runner = s:ParseCodeBlock()
  let Runner = s:RunnerForLanguage(runner.language)

  let $markdown_runner__embedding_file = expand('%:p')
  let cursorpos = getcurpos()
  let $markdown_runner__line = cursorpos[1]

  if type(Runner) == v:t_func
    let result = Runner(runner.src)
  elseif type(Runner) == v:t_string
    let result = system(Runner, runner.src)
  else
    throw "Invalid runner"
  endif
  if g:markdown_runner_populate_location_list == 1
    let result_lines = split(result, '\n')
    call map(result_lines, {_, val -> {'text': val}})
    call setloclist(0, result_lines)
  endif
  let runner.result = result
  return runner
endfunction

" Parse code block around cursor.
"
" Given
" ```python
" print('test')
" ```
"
" Returns {
"   'src': ["print('test')"],
"   'language': 'python',
"   'start': 10,
"   'end': 13,
"   'result': ''
" }
"
function! s:ParseCodeBlock() abort
  let result = {}

  if match(getline("."), '^```') != -1
    throw "Not in a markdown code block"
  endif
  let start_i = search('^```', 'bnW')
  if start_i == 0
    throw "Not in a markdown code block"
  endif
  let end_i = search('^```', 'nW')
  if end_i == 0
    throw "Not in a markdown code block"
  endif
  let lines = getline(start_i, end_i)
  if len(lines) < 3
    throw "Code block is empty"
  endif

  let result.src = lines[1:-2]
  let result.language = lines[0][3:]
  let result.start = start_i
  let result.end = end_i
  let result.result = ''

  return result
endfunction

function! s:RunnerForLanguage(language) abort
  if exists('b:markdown_runners') && has_key(b:markdown_runners, a:language)
    return b:markdown_runners[a:language]
  endif
  return get(g:markdown_runners, a:language, a:language)
endfunction

" Language specific runners

function! markdown_runner#RunGoBlock(src) abort
  let tmp = tempname() . ".go"
  let src = a:src

  " wrap in main function if it isn't already
  let joined_src = join(src, "\n")
  if match(joined_src, "^func main") == -1
    let src = split("func main() {\n" . joined_src . "\n}", "\n")
  endif

  if match(src[0], "^package") == -1
    call insert(src, "package main", 0)
  endif

  call writefile(src, tmp)
  let src = systemlist("goimports " . tmp)
  call writefile(src, tmp)
  let res = system("go run " . tmp)
  call delete(tmp)
  return res
endfunction

function! markdown_runner#RunVimBlock(src) abort
  let tmp = tempname() . ".vim"
  call writefile(a:src, tmp)
  execute "source " . tmp
  call delete(tmp)
  return ""
endfunction

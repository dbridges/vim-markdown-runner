command! MarkdownRunner call markdown_runner#Echo()
command! MarkdownRunnerInsert call markdown_runner#Insert()

if !exists("g:markdown_runners")
  let g:markdown_runners = {
        \ '': getenv('SHELL'),
        \ 'go': function("markdown_runner#RunGoBlock"),
        \ 'js': 'node',
        \ 'javascript': 'node',
        \ 'vim': function("markdown_runner#RunVimBlock"),
        \ }
endif

if !exists("g:markdown_runner_populate_location_list")
  let g:markdown_runner_populate_location_list = 0
endif

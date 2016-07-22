" Django is detected by looking for clues of a Django project.  Directories
" have been traversed are cached to speed up subsequent scans.
let s:seen = {}
let s:django_app_modules = [
      \ 'admin',
      \ 'apps',
      \ 'managers',
      \ 'migrations',
      \ 'models',
      \ 'templatetags',
      \ 'tests',
      \ 'urls',
      \ 'views',
      \ ]

let s:django_app_dirs = [
      \ 'static',
      \ 'templates',
      \ ]


" Test a file name to see if it's a python module.
function! s:has_module(dirname, module)
  return filereadable(a:dirname.'/'.a:module.'.py')
        \ || filereadable(a:dirname.'/'.a:module.'/__init__.py')
endfunction


" Test a directory for a management script>
function! s:is_django_project(dirname)
  if filereadable(a:dirname.'/manage.py')
    let $_DJANGOPLUS_MANAGEMENT = a:dirname.'/manage.py'
    return 1
  endif
  return 0
endfunction


" Test a directory to see if it looks like a Django app.
function! s:is_django_app(dirname)
  let min_matches = 2
  let dirname = a:dirname

  if filereadable(dirname.'/__init__.py')
    " Apps are modules
    let match_count = 0
    for name in s:django_app_dirs
      if isdirectory(dirname.'/'.name)
        let match_count += 1
        if match_count >= min_matches
          return 1
        endif
      endif
    endfor

    for name in s:django_app_modules
      if s:has_module(dirname, name)
        let match_count += 1
        if match_count >= match_count
          return 1
        endif
      endif
    endfor
  endif

  return 0
endfunction


" Scan parents for a match
function! s:scan(filename, func) abort
  if empty(a:filename)
    return 0
  endif

  let dirname = fnamemodify(a:filename, ':p:h')
  let last_dir = ''
  let depth = 0
  let max_depth = get(g:, 'django_max_scan_depth', 10)

  while depth < max_depth && dirname != last_dir && dirname !~ '^\/*$'
    let last_dir = dirname

    if has_key(s:seen, dirname)
      if s:seen[dirname]
        return 1
      else
        let dirname = fnamemodify(dirname, ':h')
        continue
      endif
    endif

    if call(a:func, [dirname])
      let s:seen[dirname] = 1
      return 1
    endif

    let s:seen[dirname] = 0
    let depth += 1
    let dirname = fnamemodify(dirname, ':h')
  endwhile

  return 0
endfunction


" Perform a quick check to see if the the current directory is a Django
" project.  Returns 0 or 1 if the current directory is a Django project, and
" -1 if it's not.
function! s:simple_django_project(filename)
  let cwd = getcwd()
  if !has_key(s:seen, cwd)
    let s:seen[cwd] = s:is_django_project(cwd)
  endif

  let sep = expand('/') == '\' ? '\\' : '/'
  return s:seen[cwd] ? a:filename =~# '^'.escape(cwd, '.\^$[]').sep : -1
endfunction


" Detect Django related files
function! djangoplus#detect#filetype(filename) abort
  if empty(a:filename) || !filereadable(a:filename)
    return
  endif

  let is_django = s:simple_django_project(a:filename)
  if is_django == -1
    " Since the current directory isn't a Django project, perform a more
    " exhaustive scan.
    let is_django = s:scan(a:filename, 's:is_django_project')
          \ || s:scan(a:filename, 's:is_django_app')
  endif

  if is_django
    let b:is_django = 1
    let filedir = fnamemodify(a:filename, ':h')

    autocmd! CursorHold <buffer> call djangoplus#clear_template_cache()

    if a:filename =~? '\.html\?$'
      setfiletype htmldjango
    elseif a:filename =~# '\<settings\.py$'
          \ || (filereadable(filedir.'/settings.py')
          \     && filereadable(filedir.'/../manage.py'))
      setfiletype python
      let b:is_django_settings = 1
    elseif a:filename =~# '\.py$'
      setfiletype python
    else
      for pat in get(g:, 'django_filetypes', [])
        if a:filename =~# glob2regpat(pat)
          let bft = &l:filetype
          if !empty(bft)
            let bft .= '.django'
          else
            let bft = 'django'
          endif
          execute 'setfiletype' bft
        endif
      endfor

      for ft in split(&l:filetype, '\.')
        execute 'runtime! ftplugin/'.ft.'.vim'
        execute 'runtime! after/ftplugin/'.ft.'.vim'
      endfor
    endif
  endif
endfunction

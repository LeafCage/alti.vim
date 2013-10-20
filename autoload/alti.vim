if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
"=============================================================================
let g:alti_max_history = get(g:, 'alti_max_history', exists('+history')? &hi: 20)
let g:alti_cache_dir = get(g:, 'alti_cache_dir', '~/.cache/alti')
"======================================
aug AltI
  autocmd!
  autocmd BufEnter AltI   if s:enable_autocmd && has_key(s:, 'alti_bufnr') && s:alti_bufnr > 0| exe s:alti_bufnr.'bw!'| end
  autocmd BufLeave AltI   if s:enable_autocmd && has_key(s:, 'cmpwin')| call s:cmpwin.close()| end
aug END
let s:enable_autocmd = 1

let s:prtmaps = {}
let s:prtmaps['PrtBS()'] = ['<BS>', '<C-]>']
let s:prtmaps['PrtDelete()'] = ['<Del>', '<C-d>']
let s:prtmaps['PrtDeleteWord()'] = ['<C-w>']
let s:prtmaps['PrtClear()'] = ['<C-u>']
let s:prtmaps['PrtInsertReg()'] = ['<C-r>']
let s:prtmaps['PrtHistory(-1)'] = ['<C-n>']
let s:prtmaps['PrtHistory(1)'] = ['<C-p>']
let s:prtmaps['PrtCurStart()'] = ['<C-a>']
let s:prtmaps['PrtCurEnd()'] = ['<C-e>']
let s:prtmaps['PrtCurLeft()'] = ['<C-h>', '<Left>']
let s:prtmaps['PrtCurRight()'] = ['<C-l>', '<Right>']
let s:prtmaps['PrtPageNext()'] = ['<C-f>', '<PageDown>', '<kPageDown>']
let s:prtmaps['PrtPagePrevious()'] = ['<C-b>', '<PageUp>', '<kPageUp>']
let s:prtmaps['PrtSelectMove("j")'] = ['<C-j>', '<Down>']
let s:prtmaps['PrtSelectMove("k")'] = ['<C-k>', '<Up>']
let s:prtmaps['PrtSelectMove("t")'] = ['<Home>', '<kHome>']
let s:prtmaps['PrtSelectMove("b")'] = ['<End>', '<kEnd>']
let s:prtmaps['PrtSelectInsert()'] = ['<Tab>', '<C-y>']
let s:prtmaps['PrtExit()'] = ['<Esc>', '<C-c>', '<C-g>']
let s:prtmaps['PrtSubmit()'] = ['<CR>']
let s:prtmaps['Nop()'] = ['<BS>', '<C-]>', '<Del>', '<C-d>', '<C-w>', '<C-u>', '<C-r>', '<C-n>', '<C-p>', '<C-a>', '<C-e>', '<C-h>', '<Left>', '<C-l>', '<Right>', '<C-i>', '<C-o>', '<PageDown>', '<kPageDown>', '<PageUp>', '<kPageUp>', '<C-j>', '<Down>', '<C-k>', '<Up>', '<Home>', '<kHome>', '<End>', '<kEnd>', '<C-v>', '<C-y>', '<Esc>', '<C-c>', '<C-g>', '<CR>', '<C-Tab>', '<S-Tab>', '<C-CR>', '<C-x>', '<C-s>', '<C-t>', '<C-z>', '<C-\>', '<C-^>', '<C-Up>', '<C-Down>', '<C-Left>', '<C-Right>', '<S-Up>', '<S-Down>', '<S-Left>', '<S-Right>', '<Insert>', '<2-LeftMouse>', '<MiddleMouse>', '<RightMouse>',]

call extend(s:prtmaps, get(g:, 'alti_prompt_mappings', {}))
call filter(s:prtmaps, 'v:val!=[]')

let s:getreg_maps = {}
let s:getreg_maps['expr'] = ['=']
let s:getreg_maps['<cword>'] = ['<C-w>']
let s:getreg_maps['<cWORD>'] = ['<C-a>']
let s:getreg_maps['<cfile>'] = ['<C-p>']
call extend(s:getreg_maps, get(g:, 'alti_getreg_mappings', {}))
function! s:quotize(mappings) "{{{
  return map(a:mappings, 'v:val=~"^<.\\+>$" ? eval(substitute(v:val, "^<.\\+>$", ''"\\\0"'', "")) : v:val')
endfunction
"}}}
call map(s:getreg_maps, 's:quotize(v:val)')

"======================================
let s:histholder = {'hists': [], 'idx': 0, 'is_inputsaved': 0}
function! s:histholder.load() "{{{
  let path = expand(g:alti_cache_dir). '/hist'
  let self.hists = g:alti_max_history && filereadable(path) ? readfile(path) : []
  if get(self.hists, 0, "\n")!=''
    call insert(self.hists, '')
  endif
endfunction
"}}}
function! s:histholder.reset() "{{{
  let self.is_inputsaved = 0
  let self.idx = 0
endfunction
"}}}
function! s:histholder.save() "{{{
  let str = s:prompt.get_inputline()
  if str=~'^\s*$' || str==get(self.hists, 1, "\n") || !g:alti_max_history
    return
  end
  call insert(self.hists, str, 1)
  call s:new_dupliexcluder().filter(self.hists)
  if len(self.hists) > g:alti_max_history
    call remove(self.hists, g:alti_max_history, -1)
  end
  call s:_writecachefile('hist', self.hists)
  call self.reset()
endfunction
"}}}
function! s:histholder.get_nexthist(crement) "{{{
  let self.hists[0] = self.is_inputsaved ? self.hists[0] : s:prompt.get_inputline()
  let self.hists[0] = self.hists[0]==get(self.hists, 1, "\n") ? '' : self.hists[0]
  let self.is_inputsaved = 1
  let histlen = len(self.hists)
  let self.idx += a:crement
  let self.idx = self.idx<0 ? 0 : self.idx < histlen ? self.idx : histlen > 1 ? histlen-1 : 0
  return self.hists[self.idx]
endfunction
"}}}
call s:histholder.load()
"==================
let s:_glboptholder = {}
function! s:new_glboptholder(define) "{{{
  let _ = {}
  let _.save_opts = {'magic': &magic, 'timeout': &to, 'timeoutlen': &tm, 'splitbelow': &sb, 'hlsearch': &hls,
    \ 'report': &report, 'showcmd': &sc, 'sidescroll': &ss, 'sidescrolloff': &siso, 'ttimeout': &ttimeout, 'insertmode': &im,
    \ 'guicursor': &gcr, 'ignorecase': &ic, 'langmap': &lmap, 'mousefocus': &mousef, 'imdisable': &imd, 'cmdheight': &ch}
  set magic timeout timeoutlen=0 splitbelow nohls noinsertmode report=9999 noshowcmd sidescroll=0 siso=0 nottimeout ignorecase lmap= nomousef
  let &imdisable = a:define.type_multibyte ? 0 : 1
  call extend(_, s:_glboptholder, 'keep')
  return _
endfunction
"}}}
function! s:_glboptholder.get_optval(optname) "{{{
  return self.save_opts[a:optname]
endfunction
"}}}
function! s:_glboptholder.untap() "{{{
  for [opt, val] in items(self.save_opts)
    exe 'let &'. opt ' = val'
  endfor
  unlet s:glboptholder
endfunction
"}}}
"==================
let s:_regholder = {}
function! s:new_regholder() "{{{
  let _ = {'cword': expand('<cword>', 1), 'cWORD': expand('<cWORD>, 1'), 'cfile': expand('<cfile>', 1)}
  call extend(_, s:_regholder)
  return _
endfunction
"}}}
function! s:get_cword() dict "{{{
  return self.cword
endfunction
"}}}
function! s:get_cWORD() dict "{{{
  return self.cWORD
endfunction
"}}}
function! s:get_cfile() dict "{{{
  return self.cfile
endfunction
"}}}
let s:_regholder['<cword>'] = function('s:get_cword')
let s:_regholder['<cWORD>'] = function('s:get_cWORD')
let s:_regholder['<cfile>'] = function('s:get_cfile')
function! s:_regholder.expr() "{{{
  let save_gcr = &gcr
  set gcr&
  try
    return eval(input('='))
  catch
    return ''
  finally
    let &gcr = save_gcr
    call s:prompt.echo()
  endtry
endfunction
"}}}
"==================
let s:_argleadsholder = {}
function! s:new_argleadsholder(define) "{{{
  let _ = {'arglead': '', 'ordinal': 1, 'save_precursor': '', 'cursoridx': strlen(a:define.static_text)+1}
  call extend(_, s:_argleadsholder)
  return _
endfunction
"}}}
function! s:_argleadsholder.get_funcargs() "{{{
  call self._update_cursoridx()
  call self.update_arglead()
  return [self.arglead, s:prompt.get_inputline(), self.cursoridx]
endfunction
"}}}
function! s:_argleadsholder.update_arglead() "{{{
  if self.save_precursor == s:prompt.input[0]
    return
  end
  let self.save_precursor = s:prompt.input[0]
  let list = split(self.save_precursor, '\%(\%(^\|\\\)\@<!\s\)\+', 1)
  let list[0] = substitute(list[0], '^\s*', '', '')
  let self.arglead = list[-1]
  let self.ordinal = len(list)
endfunction
"}}}
function! s:_argleadsholder._update_cursoridx() "{{{
  if self.save_precursor != s:prompt.input[0]
    let self.cursoridx = strlen(s:prompt.input[0])
  endif
endfunction
"}}}
"==================
let s:_cmpwin = {}
function! s:new_cmpwin(define) "{{{
  let restcmds = {'winrestcmd': winrestcmd(), 'lines': &lines, 'winnr': winnr('$')}
  let cw_opts = s:_get_compwin_opts()
  let s:enable_autocmd = 0
  silent! exe 'keepalt' (cw_opts.pos=='top' ? 'topleft' : 'botright') '1new AltI'
  let s:enable_autocmd = 1
  let s:alti_bufnr = bufnr('%')
  abclear <buffer>
  setl noswf nonu nobl nowrap nolist nospell nocuc winfixheight nohlsearch fdc=0 fdl=99 tw=0 bt=nofile bufhidden=unload nocul
  if v:version > 702
    setl nornu noundofile cc=0
  end
  call s:_guicursor_enter()
  sil! exe 'hi AltILinePre '.( has("gui_running") ? 'gui' : 'cterm' ).'fg=bg'
  sy match AltILinePre '^>'
  let _ = {'rest': restcmds, 'cw': cw_opts, 'compfunc': a:define.comp, 'compsep': a:define.append_compsep ? ' ' : '', 'compinsert': a:define.compinsert, 'candidates': [], 'page': 1, 'lastpage': 1, 'candidates_len': 0, 'do_comp_on_exit': a:define.comp_on_exit}
  if has_key(a:define, 'exit')
    let _.exitfunc = a:define.exit
  endif
  call extend(_, s:_cmpwin, 'keep')
  return _
endfunction
"}}}
function! s:_cmpwin.update_candidates() "{{{
  let self.candidates = call(self.compfunc, s:argleadsholder.get_funcargs())
endfunction
"}}}
function! s:_cmpwin._get_viewcandidates(firstidx, lastidx) "{{{
  let candidates = self.candidates[(a:firstidx):(a:lastidx)]
  return self.cw.order=='btt' ? reverse(candidates) : candidates
endfunction
"}}}
function! s:_cmpwin._get_buildelm() "{{{
  let self.candidates_len = len(self.candidates)
  let height = min([max([self.cw.min, self.candidates_len]), self.cw.max, &lines])
  let self.lastpage = (self.candidates_len-1) / height + 1
  let self.page = self.page > self.lastpage ? self.lastpage : self.page
  let maxlenof_height = height*(self.page-1)
  let candidates = self._get_viewcandidates(maxlenof_height, height*self.page-1)
  if self.page == self.lastpage
    let _ = self.candidates_len % maxlenof_height
    let height = _==0 ? height : _
  end
  return [candidates, height]
endfunction
"}}}
function! s:_cmpwin.select_move(direction) "{{{
  let save_crrrow = line('.')
  let wht = winheight(0)
  let directions = {'t': 'gg','b': 'G','u': wht.'k','d': wht.'j','j': 'j','k': 'k'}
  exe 'keepj norm!' directions[a:direction]
  if line('.')==save_crrrow && a:direction=~'[jk]'
    exe 'keepj norm!' a:direction=='j' ? 'gg' : 'G'
  endif
  let self.selected_row = line('.')
endfunction
"}}}
function! s:_cmpwin.select_insert() "{{{
  let self.selected_row = line('.')
  let candidates = self._get_buildelm()[0]
  let selected = get(candidates, self.selected_row-1, '')
  if selected==''
    return
  end
  call s:argleadsholder.update_arglead()
  let str = call(self.compinsert, [s:argleadsholder.arglead, selected])
  call s:prompt.append(str. self.compsep)
  let save_candidates = copy(self.candidates)
  call self.update_candidates()
  if self.candidates != save_candidates
    unlet! self.selected_row
  end
endfunction
"}}}
function! s:_cmpwin.turn_page(crement) "{{{
  let self.page += a:crement
  let self.page = self.page<1 ? self.lastpage : self.page>self.lastpage ? 1 : self.page
endfunction
"}}}
function! s:_cmpwin.buildview() "{{{
  setl ma
  let [candidates, height]= self._get_buildelm()
  sil! exe '%delete _ | resize' height
  call map(candidates, '"> ". v:val')
  call setline(1, candidates)
  setl noma
  if has_key(self, 'selected_row')
    call cursor(self.selected_row, 1)
  else
    exe 'keepj norm! '. (self.cw.order=='btt' ? 'G' : 'gg'). '1|'
  end
  "call self._refresh_highlight()
endfunction
"}}}
function! s:_cmpwin._refresh_highlight() "{{{
  call clearmatches()
  cal matchadd('AltILinePre', '^>')
endfunction
"}}}
function! s:_cmpwin.comp_on_exit() "{{{
  if self.do_comp_on_exit
    call self.select_insert()
  end
endfunction
"}}}
function! s:_cmpwin.close() "{{{
  let s:enable_autocmd = 0
  if winnr('$')==1
    bwipeout!
  else
    try| bunload!| catch| close| endtry
  end
  let s:enable_autocmd = 1
  call s:glboptholder.untap()
  if self.rest.lines >= &lines && self.rest.winnr == winnr('$')
    exe self.rest.winrestcmd
  end
  if has_key(self, 'exitfunc')
    call eval(self.exitfunc)
  end
  echo
  redraw
  call s:histholder.save()
  unlet s:cmpwin s:prompt s:regholder s:argleadsholder
endfunction
"}}}
"==================
let s:_prompt = {}
function! s:new_prompt(define) "{{{
  exe 'hi link AltIPrtBase' a:define.prompt_hl
  hi link AltIPrtText     Normal
  hi link AltIPrtCursor   Constant
  let _ = {'input': [a:define.default_text, ''], 'prtbasefunc': a:define.prompt, 'submittedfunc': a:define.submitted, 'canceledfunc': a:define.canceled, 'inputline': a:define.default_text, 'static_text': a:define.static_text=='' ? '' : a:define.static_text. ' ' }
  call extend(_, s:_prompt, 'keep')
  return _
endfunction
"}}}
function! s:_prompt.get_inputline() "{{{
  let self.inputline = self.static_text. join(self.input, '')
  return self.inputline
endfunction
"}}}
function! s:_prompt.get_exitfunc_elms(exitfuncname) "{{{
  return [self[a:exitfuncname], self.get_inputline()]
endfunction
"}}}
function! s:_prompt.echo() "{{{
  redraw
  let onpostcurs = matchlist(self.input[1], '^\(.\)\(.*\)')
  let inputs = map([self.input[0], get(onpostcurs, 1, ''), get(onpostcurs, 2, '')], 'escape(v:val, ''"\'')')
  let is_cursorspace = inputs[1]=='' || inputs[1]==' '
  let [hiactive, hicursor] = ['AltIPrtText', (is_cursorspace? 'AltIPrtBase': 'AltIPrtCursor')]
  exe 'echoh AltIPrtBase| echon "'. escape(self._get_prtbase(), '"\'). '"| echoh' hiactive '| echon "'. self.static_text. inputs[0]. '"'
  exe 'echoh' hicursor '| echon "'. (is_cursorspace? '_': inputs[1]). '"| echoh' hiactive '| echon "'. inputs[2].'"| echoh NONE'
endfunction
"}}}
function! s:_prompt._get_prtbase() "{{{
  let prompt = call(self.prtbasefunc, s:argleadsholder.get_funcargs())
  let nlcount = count(split(prompt, '\zs'), "\n")
  let &cmdheight = nlcount >= s:glboptholder.get_optval('cmdheight') ? nlcount+1 : s:glboptholder.get_optval('cmdheight')
  return prompt
endfunction
"}}}
function! s:_prompt.append(str) "{{{
  let self.input[0] .= a:str
endfunction
"}}}
function! s:_prompt.bs() "{{{
  let self.input[0] = substitute(self.input[0], '.$', '', '')
endfunction
"}}}
function! s:_prompt.delete() "{{{
  let self.input[1] = substitute(self.input[1], '^.', '', '')
endfunction
"}}}
function! s:_prompt.delete_word() "{{{
  let str = self.input[0]
  let self.input[0] = str=~'\W\w\+$' ? matchstr(str, '^.\+\W\ze\w\+$') : str=~'\w\W\+$' ? matchstr(str, '^.\+\w\ze\W\+$')
    \ : str=~'\s\+$' ? matchstr(str, '^.*\S\ze\s\+$') : str=~'\v^(\S+|\s+)$' ? '' : str
endfunction
"}}}
function! s:_prompt.clear() "{{{
  let self.input = ['', '']
endfunction
"}}}
function! s:_prompt.insert_history(crement) "{{{
  let self.input = [s:histholder.get_nexthist(a:crement), '']
endfunction
"}}}
function! s:_prompt.cursor_start() "{{{
  if self.input[0]==''
    return 0
  end
  let self.input = ['', self.get_inputline()]
  return 1
endfunction
"}}}
function! s:_prompt.cursor_end() "{{{
  if self.input[1]==''
    return 0
  end
  let self.input = [self.get_inputline(), '']
  return 1
endfunction
"}}}
function! s:_prompt.cursor_left() "{{{
  if self.input[0]==''
    return 0
  endif
  let self.input = [substitute(self.input[0], '.$', '', ''), matchstr(self.input[0], '.$'). self.input[1]]
  return 1
endfunction
"}}}
function! s:_prompt.cursor_right() "{{{
  if self.input[1]==''
    return 0
  endif
  let self.input = [self.input[0]. matchstr(self.input[1], '^.'), substitute(self.input[1], '^.', '', '')]
  return 1
endfunction
"}}}

"=============================================================================
"Main
let s:dfl_define = {'default_text': '', 'static_text': '', 'prompt': 's:default_prompt', 'prompt_hl': 'Comment', 'comp': 's:default_comp', 'compinsert': 's:default_compinsert', 'submitted': 's:default_submitted', 'append_compsep': 1, 'comp_on_exit': 0, 'canceled': 's:default_canceled', 'type_multibyte': 0}
function! alti#init(define)
  call extend(a:define, s:dfl_define, 'keep')
  let s:regholder = s:new_regholder()
  let s:glboptholder = s:new_glboptholder(a:define)
  let s:cmpwin = s:new_cmpwin(a:define)
  let s:prompt = s:new_prompt(a:define)
  let s:argleadsholder = s:new_argleadsholder(a:define)
  call s:_mapping_input()
  call s:_mapping_term_arrowkeys()
  call s:_mapping_prtmaps()
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
  if a:define.type_multibyte
    call s:_keyloop()
  end
endfunction

function! alti#get_arginfo() "{{{
  let ret = {'precursor': s:prompt.input[0], 'postcursor': s:prompt.input[1], 'inputline': s:prompt.inputline, 'cursoridx': s:argleadsholder.cursoridx, 'arglead': s:argleadsholder.arglead, 'ordinal': s:argleadsholder.ordinal}
  let ret.args = split(s:prompt.inputline, '\%(\\\@<!\s\)\+')
  return ret
endfunction
"}}}


"=============================================================================
function! s:default_prompt(arglead, cmdline, cursorpos) "{{{
  return '>>> '
endfunction
"}}}
function! s:default_comp(arglead, cmdline, cursorpos) "{{{
  return []
endfunction
"}}}
function! s:default_compinsert(arglead, selected_candidate) "{{{
  return substitute(substitute(a:selected_candidate, "\t.*$", '', ''), '^'.a:arglead, '', '')
endfunction
"}}}
function! s:default_submitted(input) "{{{
  if a:input =~ '^\s*$'
    return
  end
  exe a:input
endfunction
"}}}
function! s:default_canceled(input) "{{{
endfunction
"}}}
"==================
function! s:_mapping_input() "{{{
  let cmd = "nnoremap \<buffer>\<silent>\<k%s> :\<C-u>call \<SID>PrtAdd(\"%s\")\<CR>"
  for each in range(0, 9)
    exe printf(cmd, each, each)
  endfo
  for [lhs, rhs] in [['Plus', '+'], ['Minus', '-'], ['Divide', '/'], ['Multiply', '*'], ['Point', '.']]
    exe printf(cmd, lhs, rhs)
  endfo
  let cmd = "nnoremap \<buffer>\<silent>\<Char-%d> :\<C-u>call \<SID>PrtAdd(\"%s\")\<CR>"
  for each in [34, 92, 124]
    exe printf(cmd, each, escape(nr2char(each), '"|\'))
  endfo
  for each in [32, 33, 125, 126] + range(35, 91) + range(93, 123)
    exe printf(cmd, each, nr2char(each))
  endfo
endfunction
"}}}
function! s:_mapping_term_arrowkeys() "{{{
  if (has('termresponse') && v:termresponse=~"\<ESC>") || &term=~?'\vxterm|<k?vt|gnome|screen|linux|ansi'
    for each in ['\A <up>','\B <down>','\C <right>','\D <left>']
      exe 'nnoremap <buffer><silent><Esc>['.each
    endfor
  end
endfunction
"}}}
function! s:_mapping_prtmaps() "{{{
  let maps = copy(s:prtmaps)
  let nop = remove(maps, 'Nop()')
  for lhs in nop
    exe 'nnoremap <buffer><silent>' lhs ':<C-u>call <SID>Nop()<CR>'
  endfor
  for [key, vals] in items(maps)
    for lhs in vals
      exe 'nnoremap <buffer><silent>' lhs ':<C-u>call <SID>'.key.'<CR>'
    endfor
  endfor
endfunction
"}}}
let s:TYPE_NUM = type(0)
function! s:_keyloop() "{{{
  while has_key(s:, 'prompt')
    redraw
    let nr = getchar()
    let char = type(nr)==s:TYPE_NUM ? nr2char(nr) : nr
    if nr >=# 0x20
      cal s:PrtAdd(char)
    else
      let cmd = matchstr(maparg(char), ':<C-u>\zs.\+\ze<CR>$')
      exe ( cmd != '' ? cmd : 'norm '.char )
    end
  endwhile
endfunction
"}}}
"==================
let s:_dupliexcluder = {}
function! s:new_dupliexcluder() "{{{
  let _ = {'seens': {}}
  call extend(_, s:_dupliexcluder, 'keep')
  return _
endfunction
"}}}
function! s:_dupliexcluder.filter(list) "{{{
  return filter(a:list, 'self._seen(v:val)')
endfunction
"}}}
function! s:_dupliexcluder._seen(str) "{{{
  if has_key(self.seens, a:str)
    return
  end
  if a:str!=''
    let self.seens[a:str] = 1
  end
  return 1
endfunction
"}}}
"==================
"s:histholder
function! s:_writecachefile(filename, list) "{{{
  let dir = expand(g:alti_cache_dir)
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  end
  call writefile(a:list, dir. '/'. a:filename)
endfunction
"}}}
"s:cmpwin
let s:CWMAX = 10
let s:CWMIN = 1
function! s:_get_compwin_opts() "{{{
  if !has_key(g:, 'alti_comp_window')
    return {'pos': 'bottom', 'order': 'ttb', 'max': s:CWMAX, 'min': s:CWMIN, 'resultslimit': min([s:CWMAX, &lines])}
  end
  let _ = {}
  let comp_window = g:alti_comp_window
  let _.pos = comp_window=~'top\|bottom' ? matchstr(comp_window, 'top\|bottom') : 'bottom'
  let _.order = comp_window=~'order:[^,]\+' ? matchstr(comp_window, 'order:\zs[^,]\+') : 'ttb'
  let _.max = comp_window=~'max:[^,]\+' ? str2nr(matchstr(comp_window, 'max:\zs\d\+')) : s:CWMAX
  let _.min = comp_window=~'min:[^,]\+' ? str2nr(matchstr(comp_window, 'min:\zs\d\+')) : s:CWMIN
  let [_.max, _.min] = [max([_.max, 1]), max(_.min, 1)]
  let _.min = min([_.min, _.max])
  let _.resultslimit = comp_window=~'results:[^,]\+' ? str2nr(matchstr(comp_window, 'results:\zs\d\+')) : min([_.max, &lines])
  let _.resultslimit = max([_.results, 1])
  return _
endfunction
"}}}
function! s:_guicursor_enter() "{{{
  setl cul gcr=a:block-blinkon0-Cursor
endfunction
"}}}

"=============================================================================
function! s:PrtAdd(char) "{{{
  call s:histholder.reset()
  call s:prompt.append(a:char)
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtBS() "{{{
  call s:histholder.reset()
  call s:prompt.bs()
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtDelete() "{{{
  call s:histholder.reset()
  call s:prompt.delete()
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtDeleteWord() "{{{
  call s:histholder.reset()
  call s:prompt.delete_word()
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtClear() "{{{
  call s:histholder.reset()
  call s:prompt.clear()
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtInsertReg() "{{{
  let save_gcr = &gcr
  set gcr&
  let char = nr2char(getchar())
  let &gcr = save_gcr
  for [regname, chars] in items(s:getreg_maps)
    if match(chars, char)!=-1
      if regname=~'^.$'
        let str = getreg(regname)
      else
        let str = s:regholder[regname]()
      end
      break
    end
  endfor
  let str = has_key(l:, 'str') ? str : getreg(char)
  if str!=''
    call s:PrtAdd(substitute(str, "\n", '', 'g'))
  end
endfunction
"}}}
function! s:PrtHistory(crement) "{{{
  if !g:alti_max_history
    return
  end
  call s:prompt.insert_history(a:crement)
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtCurStart() "{{{
  if s:prompt.cursor_start()
    call s:cmpwin.buildview()
    call s:prompt.echo()
  endif
endfunction
"}}}
function! s:PrtCurEnd() "{{{
  if s:prompt.cursor_end()
    call s:cmpwin.buildview()
    call s:prompt.echo()
  endif
endfunction
"}}}
function! s:PrtCurLeft() "{{{
  if s:prompt.cursor_left()
    call s:cmpwin.buildview()
    call s:prompt.echo()
  endif
endfunction
"}}}
function! s:PrtCurRight() "{{{
  if s:prompt.cursor_right()
    call s:cmpwin.buildview()
    call s:prompt.echo()
  endif
endfunction
"}}}
function! s:PrtPageNext() "{{{
  call s:cmpwin.turn_page(1)
  call s:cmpwin.buildview()
endfunction
"}}}
function! s:PrtPagePrevious() "{{{
  call s:cmpwin.turn_page(-1)
  call s:cmpwin.buildview()
endfunction
"}}}
function! s:PrtSelectMove(direction) "{{{
  call s:cmpwin.select_move(a:direction)
endfunction
"}}}
function! s:PrtSelectInsert() "{{{
  call s:histholder.reset()
  call s:cmpwin.select_insert()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtExit() "{{{
  call s:cmpwin.comp_on_exit()
  let [canceledfunc, inputline] = s:prompt.get_exitfunc_elms('canceledfunc')
  call s:cmpwin.close()
  wincmd p
  call call(canceledfunc, [inputline])
endfunction
"}}}
function! s:PrtSubmit() "{{{
  call s:cmpwin.comp_on_exit()
  let [submittedfunc, inputline] = s:prompt.get_exitfunc_elms('submittedfunc')
  call s:cmpwin.close()
  wincmd p
  call call(submittedfunc, [inputline])
endfunction
"}}}
function! s:Nop() "{{{
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo

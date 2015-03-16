if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
aug AltI
  autocmd!
  autocmd BufEnter :[AltI]   if s:enable_autocmd && has_key(s:, 'alti_bufnr') && s:alti_bufnr > 0| exe s:alti_bufnr.'bw!'| end
  autocmd BufLeave :[AltI]   if s:enable_autocmd && has_key(s:, 'cmpwin')| call s:cmpwin.close()| end
aug END
let s:enable_autocmd = 1
"--------------------------------------
let s:TYPE_DIC = type({})

let s:prtmaps = {}
let s:prtmaps['PrtBS()'] = ['<BS>', '<C-]>']
let s:prtmaps['PrtDelete()'] = ['<Del>', '<C-d>']
let s:prtmaps['PrtDeleteWord()'] = ['<C-w>']
let s:prtmaps['PrtClear()'] = ['<C-u>']
let s:prtmaps['PrtInsertReg()'] = ['<C-r>']
let s:prtmaps['PrtHistory(-1)'] = ['<C-n>']
let s:prtmaps['PrtSmartHistory(-1)'] = []
let s:prtmaps['PrtHistory(1)'] = ['<C-p>']
let s:prtmaps['PrtCurStart()'] = ['<C-a>']
let s:prtmaps['PrtCurEnd()'] = ['<C-e>']
let s:prtmaps['PrtCurLeft()'] = ['<C-h>', '<Left>']
let s:prtmaps['PrtCurRight()'] = ['<C-l>', '<Right>']
let s:prtmaps['PrtPage(1)'] = ['<C-v>', '<PageDown>', '<kPageDown>']
let s:prtmaps['PrtPage(-1)'] = ['<C-o>', '<PageUp>', '<kPageUp>']
let s:prtmaps['PrtSelectMove("j")'] = ['<C-j>', '<Down>']
let s:prtmaps['PrtSelectMove("k")'] = ['<C-k>', '<Up>']
let s:prtmaps['PrtSelectMove("t")'] = ['<Home>', '<kHome>']
let s:prtmaps['PrtSelectMove("b")'] = ['<End>', '<kEnd>']
let s:prtmaps['PrtInsertSelection()'] = ['<Tab>']
let s:prtmaps['PrtInsertSelection("\<Space>")'] = ['<Space>']
let s:prtmaps['PrtDetailSelection()'] = ['<C-g>']
let s:prtmaps['PrtActSelection("z")'] = ['<C-z>', '<C-s>']
let s:prtmaps['PrtActSelection("x")'] = ['<C-x>']
let s:prtmaps['PrtActSelection("t")'] = ['<C-t>']
let s:prtmaps['PrtExit()'] = ['<Esc>', '<C-c>']
let s:prtmaps['PrtSubmit()'] = ['<CR>']
let s:prtmaps['ToggleType(1)'] = ['<C-f>', '<C-_>', '<C-Down>']
let s:prtmaps['ToggleType(-1)'] = ['<C-b>', '<C-]>', '<C-^>', '<C-Up>']

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
let s:HistHolder = {'hists': [], 'idx': 0, 'is_inputsaved': 0}
function! s:HistHolder.load() "{{{
  let path = expand(g:alti_cache_dir). '/hist'
  let self.hists = g:alti_max_history && filereadable(path) ? readfile(path) : []
  if get(self.hists, 0, "\n")!=''
    call insert(self.hists, '')
  endif
endfunction
"}}}
function! s:HistHolder.reset() "{{{
  let self.is_inputsaved = 0
  let self.idx = 0
endfunction
"}}}
function! s:HistHolder.save() "{{{
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
function! s:HistHolder.get_nexthist(delta) "{{{
  let self.hists[0] = self.is_inputsaved ? self.hists[0] : s:prompt.get_inputline()
  let self.hists[0] = self.hists[0]==get(self.hists, 1, "\n") ? '' : self.hists[0]
  let self.is_inputsaved = 1
  let histlen = len(self.hists)
  let self.idx += a:delta
  let self.idx = self.idx<0 ? 0 : self.idx < histlen ? self.idx : histlen > 1 ? histlen-1 : 0
  return self.hists[self.idx]
endfunction
"}}}
call s:HistHolder.load()
"==================
let s:GlboptHolder = {}
function! s:newGlboptHolder(define) "{{{
  let obj = copy(s:GlboptHolder)
  let obj.save_opts = {'magic': &magic, 'splitbelow': &sb, 'report': &report,
    \ 'showcmd': &sc, 'sidescroll': &ss, 'sidescrolloff': &siso, 'insertmode': &im,
    \ 'guicursor': &gcr, 't_ve': &t_ve, 'ignorecase': &ic, 'langmap': &lmap, 'mousefocus': &mousef, 'cmdheight': &ch}
  set magic splitbelow noinsertmode report=9999 noshowcmd sidescroll=0 siso=0 ignorecase lmap= nomousef
  return obj
endfunction
"}}}
function! s:GlboptHolder.get_optval(optname) "{{{
  return self.save_opts[a:optname]
endfunction
"}}}
function! s:GlboptHolder.untap() "{{{
  for [opt, val] in items(self.save_opts)
    exe 'let &'. opt ' = val'
  endfor
  unlet s:glboptholder
endfunction
"}}}
"==================
let s:RegHolder = {}
function! s:newRegHolder() "{{{
  let obj = {'cword': expand('<cword>', 1), 'cWORD': expand('<cWORD>', 1), 'cfile': expand('<cfile>', 1)}
  call extend(obj, s:RegHolder)
  return obj
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
let s:RegHolder['<cword>'] = function('s:get_cword')
let s:RegHolder['<cWORD>'] = function('s:get_cWORD')
let s:RegHolder['<cfile>'] = function('s:get_cfile')
function! s:RegHolder.expr() "{{{
  let save_gcr = &gcr
  set gcr&
  try
    return eval(input('=', '', 'expression'))
  catch
    return ''
  finally
    let &gcr = save_gcr
    call s:prompt.echo()
  endtry
endfunction
"}}}
"==================
let s:StlMgr = {}
function! s:newStlMgr(define) "{{{
  let obj = {'crrtype': '<'.(a:define.name=='' ? 'Alti'.(s:defines.idx+1) : a:define.name).'>'}
  let previdx = s:defines.idx-1 <0 ? s:defines.len-1 : s:defines.idx-1
  let nextidx = s:defines.idx+1 >=s:defines.len ? 0 : s:defines.idx+1
  let obj.prevtype = s:defines.len<2 ? '' : has_key(s:defines.list[previdx], 'sname') ? s:defines.list[previdx].sname : get(s:defines.list[previdx], 'name', 'Alti'.previdx+1)
  let obj.nexttype = s:defines.len<3 ? '' : has_key(s:defines.list[nextidx], 'sname') ? s:defines.list[nextidx].sname : get(s:defines.list[nextidx], 'name', 'Alti'.nextidx+1)
  let obj.pat = '%%#StatusLineNC#%12.12s  %%#StatusLine#%s  %%#StatusLineNC#%-12.12s%%*%%=(%d item%s) (page: %d/%d)   AltI%%<'
  let &l:stl = printf(obj.pat, obj.prevtype, obj.crrtype, obj.nexttype, 0, '', 1, 1)
  call extend(obj, s:StlMgr, 'keep')
  return obj
endfunction
"}}}
function! s:StlMgr.on_page_setted() "{{{
  let s = s:cmpwin.candidates_len>1 ? 's' : ''
  let &l:stl = printf(self.pat, self.prevtype, self.crrtype, self.nexttype, s:cmpwin.candidates_len, s, s:cmpwin.page, s:cmpwin.lastpage)
endfunction
"}}}
function! s:StlMgr.on_type_toggled() "{{{
  let crridx = s:defines.idx
  let crrlen = s:defines.len
  let self.crrtype = '<'.(s:defines.list[crridx].name=='' ? 'Alti'.(crridx+1) : s:defines.list[crridx].name).'>'
  let previdx = crridx-1 <0 ? crrlen-1 : crridx-1
  let nextidx = crridx+1 >=crrlen ? 0 : crridx+1
  let self.prevtype = crrlen<2 ? '' : has_key(s:defines.list[previdx], 'sname') ? s:defines.list[previdx].sname : get(s:defines.list[previdx], 'name', 'Alti'.previdx+1)
  let self.nexttype = crrlen<3 ? '' : has_key(s:defines.list[nextidx], 'sname') ? s:defines.list[nextidx].sname : get(s:defines.list[nextidx], 'name', 'Alti'.nextidx+1)
  let s = s:cmpwin.candidates_len>1 ? 's' : ''
  let &l:stl = printf(self.pat, self.prevtype, self.crrtype, self.nexttype, s:cmpwin.candidates_len, s, s:cmpwin.page, s:cmpwin.lastpage)
endfunction
"}}}
"==================
let s:ArgleadsHolder = {}
function! s:newArgleadsHolder(define) "{{{
  let obj = {'arglead': '', 'ordinal': 1, 'save_precursor': '', 'cursoridx': strlen(a:define.static_text)+1, 'action': []}
  call extend(obj, s:ArgleadsHolder)
  return obj
endfunction
"}}}
function! s:ArgleadsHolder.get_funcargs(...) "{{{
  let self.action = a:0 ? a:1 : []
  call self._update_cursoridx()
  call self.update_arglead()
  call s:prompt.get_inputline()
  return [alti#get_arginfo()]
endfunction
"}}}
function! s:ArgleadsHolder.update_arglead() "{{{
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
function! s:ArgleadsHolder._update_cursoridx() "{{{
  if self.save_precursor != s:prompt.input[0]
    let self.cursoridx = strlen(s:prompt.input[0])
  endif
endfunction
"}}}
"==================
let s:CmpWin = {}
function! s:newCmpWin(define) "{{{
  let restcmds = {'winrestcmd': winrestcmd(), 'lines': &lines, 'winnr': winnr('$')}
  let cw_opts = s:_get_cmpwin_opts()
  let s:enable_autocmd = 0
  silent! exe 'keepalt' (cw_opts.pos=='top' ? 'topleft' : 'botright') '1new :[AltI]'
  let s:enable_autocmd = 1
  let s:alti_bufnr = bufnr('%')
  abclear <buffer>
  setl noro noswf nonu nobl nowrap nolist nospell nocuc winfixheight nohls fdc=0 fdl=99 tw=0 bt=nofile bufhidden=unload nocul
  if v:version > 702
    setl nornu noundofile cc=0
  end
  call s:_guicursor_enter()
  sil! exe 'hi AltILinePre '.( has("gui_running") ? 'gui' : 'cterm' ).'fg=bg'
  sy match AltILinePre '^>'
  let obj = {'rest': restcmds, 'cw': cw_opts, 'cmplfunc': a:define.cmpl, 'cmplsep': a:define.append_cmplsep ? ' ' : '', 'insertstr': a:define.insertstr, 'candidates': [], 'page': 1, 'lastpage': 1, 'candidates_len': 0,}
  call extend(obj, s:CmpWin, 'keep')
  return obj
endfunction
"}}}
function! s:CmpWin.update_candidates(...) "{{{
  let self.candidates = call(self.cmplfunc, s:argleadsholder.get_funcargs(a:0 ? a:1 : []), s:funcself)
endfunction
"}}}
function! s:CmpWin._get_viewcandidates(firstidx, lastidx) "{{{
  let candidates = self.candidates[(a:firstidx):(a:lastidx)]
  return self.cw.order=='btt' ? reverse(candidates) : candidates
endfunction
"}}}
function! s:CmpWin._set_page() "{{{
  let self.candidates_len = len(self.candidates)
  let height = min([max([self.cw.min, self.candidates_len]), self.cw.max, &lines])
  let self.lastpage = (self.candidates_len-1) / height + 1
  let self.page = self.page > self.lastpage ? self.lastpage : self.page
  if g:alti_enable_statusline
    call s:stlmgr.on_page_setted()
  end
  return height
endfunction
"}}}
function! s:CmpWin._get_buildelm() "{{{
  let height = self._set_page()
  let maxlenof_height = height*(self.page-1)
  let candidates = self._get_viewcandidates(maxlenof_height, height*self.page-1)
  if self.page == self.lastpage
    let _ = self.candidates_len % maxlenof_height
    let height = _==0 ? height : _
  end
  return [candidates, height]
endfunction
"}}}
function! s:CmpWin.select_move(direction) "{{{
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
function! s:CmpWin.insert_selection() "{{{
  let selected = self._get_selected_word()
  if selected==''
    return
  end
  call s:argleadsholder.update_arglead()
  let self.on_cmpl = 1
  let str = call(self.insertstr, [alti#get_arginfo(), selected], s:funcself)
  unlet self.on_cmpl
  call s:prompt.append(str. self.cmplsep)
  let save_candidates = copy(self.candidates)
  call self.update_candidates()
  if self.candidates != save_candidates
    unlet! self.selected_row
  end
endfunction
"}}}
function! s:CmpWin._get_selected_idx() "{{{
  let height = self._set_page()
  let self.selected_row = line('.')
  return height*(self.page-1) + self.selected_row-1
endfunction
"}}}
function! s:CmpWin._get_selected_word() "{{{
  let selected = get(self.candidates, self._get_selected_idx(), '')
  return type(selected)==s:TYPE_DIC ? get(selected, 'word', '') : selected
endfunction
"}}}
function! s:CmpWin.get_selected_raw() "{{{
  return get(self.candidates, self._get_selected_idx(), '')
endfunction
"}}}
function! s:CmpWin.get_selected_detail() "{{{
  let selected = get(self.candidates, self._get_selected_idx(), '')
  if type(selected)!=s:TYPE_DIC
    return ''
  end
  return get(selected, 'detail', '')
endfunction
"}}}
function! s:CmpWin.turn_page(delta) "{{{
  let self.page += a:delta
  let self.page = self.page<1 ? self.lastpage : self.page>self.lastpage ? 1 : self.page
endfunction
"}}}
function! s:CmpWin.buildview() "{{{
  setl ma
  let [candidates, height]= self._get_buildelm()
  let candidates = type(get(candidates, 0))==s:TYPE_DIC ? map(candidates, 'has_key(v:val, "view") ? v:val.view : get(v:val, "word", "")') : candidates
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
function! s:CmpWin._refresh_highlight() "{{{
  call clearmatches()
  cal matchadd('AltILinePre', '^>')
endfunction
"}}}
function! s:CmpWin.close() "{{{
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
  echo
  redraw
  call s:HistHolder.save()
  unlet! s:cmpwin s:prompt s:regholder s:argleadsholder s:defines s:stlmgr
endfunction
"}}}
"==================
let s:Prompt = {}
function! s:newPrompt(define, firstmess) "{{{
  exe 'hi link AltIPrtBase' a:define.prompt_hl
  hi link AltIPrtText     Normal
  hi link AltIPrtCursor   Cursor
  let obj = {'input': [a:define.default_text, ''], 'prtbasefunc': a:define.prompt, 'submittedfunc': a:define.submitted, 'canceledfunc': a:define.canceled, 'inputline': a:define.default_text, 'static_text': a:define.static_text=='' ? '' : a:define.static_text. ' ', 'firstmess': a:firstmess}
  call extend(obj, s:Prompt, 'keep')
  return obj
endfunction
"}}}
function! s:Prompt.get_inputline() "{{{
  let self.inputline = self.static_text. join(self.input, '')
  return self.inputline
endfunction
"}}}
function! s:Prompt.get_exitfunc_elms(exitfuncname) "{{{
  return self[a:exitfuncname]
endfunction
"}}}
function! s:Prompt.echo() "{{{
  redraw
  let prtbase = call(self.prtbasefunc, s:argleadsholder.get_funcargs(), s:funcself)
  call s:_adjust_cmdheight(prtbase)
  if self.firstmess!=''
    let &cmdheight += s:_get_nlcount(self.firstmess)+1
    echo self.firstmess
  end
  let self.firstmess=''
  let onpostcurs = matchlist(self.input[1], '^\(.\)\(.*\)')
  let inputs = map([self.input[0], get(onpostcurs, 1, ''), get(onpostcurs, 2, '')], 'escape(v:val, ''"\'')')
  let is_cursorspace = inputs[1]=='' || inputs[1]==' '
  let [hiactive, hicursor] = ['AltIPrtText', (is_cursorspace? 'AltIPrtCursor': 'AltIPrtCursor')]
  exe 'echoh AltIPrtBase| echo "'. escape(prtbase, '"\'). '"'
  exe 'echoh' hiactive '| echon "'. self.static_text. inputs[0]. '"'
  exe 'echoh' hicursor '| echon "'. (is_cursorspace? ' ': inputs[1]). '"'
  exe 'echoh' hiactive '| echon "'. inputs[2].'"| echoh NONE'
endfunction
"}}}
function! s:Prompt.append(str) "{{{
  let self.input[0] .= a:str
endfunction
"}}}
function! s:Prompt.rm_arglead() "{{{
  let self.input[0] = substitute(self.input[0], '\s\?\zs\S\{-1,}$', '', '')
endfunction
"}}}
function! s:Prompt.bs() "{{{
  let self.input[0] = substitute(self.input[0], '.$', '', '')
endfunction
"}}}
function! s:Prompt.delete() "{{{
  let self.input[1] = substitute(self.input[1], '^.', '', '')
endfunction
"}}}
function! s:Prompt.delete_word() "{{{
  let str = self.input[0]
  let self.input[0] = str=~'\W\w\+$' ? matchstr(str, '^.\+\W\ze\w\+$') : str=~'\w\W\+$' ? matchstr(str, '^.\+\w\ze\W\+$')
    \ : str=~'\s\+$' ? matchstr(str, '^.*\S\ze\s\+$') : str=~'\v^(\S+|\s+)$' ? '' : str
endfunction
"}}}
function! s:Prompt.clear() "{{{
  let self.input = ['', '']
endfunction
"}}}
function! s:Prompt.insert_history(delta) "{{{
  let self.input = [s:HistHolder.get_nexthist(a:delta), '']
endfunction
"}}}
function! s:Prompt.cursor_start() "{{{
  if self.input[0]==''
    return 0
  end
  let self.input = ['', self.get_inputline()]
  return 1
endfunction
"}}}
function! s:Prompt.cursor_end() "{{{
  if self.input[1]==''
    return 0
  end
  let self.input = [self.get_inputline(), '']
  return 1
endfunction
"}}}
function! s:Prompt.cursor_left() "{{{
  if self.input[0]==''
    return 0
  endif
  let self.input = [substitute(self.input[0], '.$', '', ''), matchstr(self.input[0], '.$'). self.input[1]]
  return 1
endfunction
"}}}
function! s:Prompt.cursor_right() "{{{
  if self.input[1]==''
    return 0
  endif
  let self.input = [self.input[0]. matchstr(self.input[1], '^.'), substitute(self.input[1], '^.', '', '')]
  return 1
endfunction
"}}}

"=============================================================================
"Main:
let s:dfl_define = {'name': '', 'default_text': '', 'static_text': '', 'prompt': 's:default_prompt', 'cmpl': 's:default_cmpl',
  \ 'insertstr': 'alti#insertstr_posttab_annotation', 'canceled': 's:default_canceled', 'submitted': 's:default_submitted',
  \ 'append_cmplsep': 1, 'prompt_hl': 'Comment'}
function! alti#init(define, ...) "{{{
  if has_key(s:, 'cmpwin')| return| end
  let firstmess = a:0 ? substitute(a:1, "^\n", '', '') : ''
  let s:defines = {'idx': 0}
  let s:defines.list = type(a:define)!=type([]) ? [a:define] : a:define==[] ? [{}] : a:define
  let s:defines.len = len(s:defines.list)
  let Define = s:defines.list[0]
  call extend(Define, s:dfl_define, 'keep')
  let s:regholder = s:newRegHolder()
  let s:funcself = {}
  for def in s:defines.list
    call extend(s:funcself, get(def, 'bind', {}))
  endfor
  call extend(s:funcself, get(a:, 2, {}))
  call map(copy(s:defines.list), 'call(get(v:val, "enter", "s:default_enter"), [], s:funcself)')
  let s:glboptholder = s:newGlboptHolder(Define)
  let s:cmpwin = s:newCmpWin(Define)
  let s:prompt = s:newPrompt(Define, firstmess)
  let s:argleadsholder = s:newArgleadsHolder(Define)

  if g:alti_enable_statusline
    let s:stlmgr = s:newStlMgr(Define)
  end
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
  while has_key(s:, 'prompt')
    sil! resize +0
    redraw
    let inputs = alti_l#lim#ui#keybind(s:prtmaps, {'transit':1, 'expand': 1})
    if inputs=={}
      call s:PrtExit()
    elseif inputs.action!=''
      exe 'call s:'. inputs.action
    elseif inputs.surplus !~# "^[\x80[:cntrl:]]"
      exe printf('call s:PrtAdd(''%s'')', inputs.surplus)
    end
  endwhile
endfunction
"}}}

"------------------
function! alti#get_arginfo() "{{{
  if !has_key(s:, 'cmpwin')
    echoerr 'alti: when alti is not running, it is not possible to call alti#get_arginfo().'
    return {}
  end
  let ret = {'precursor': s:prompt.input[0], 'postcursor': s:prompt.input[1], 'inputline': s:prompt.inputline, 'cursoridx': s:argleadsholder.cursoridx, 'arglead': s:argleadsholder.arglead, 'ordinal': s:argleadsholder.ordinal, 'action': s:argleadsholder.action}
  let ret.args = alti#split2args(s:prompt.inputline)
  return ret
endfunction
"}}}
function! alti#on_insertstr_rm_arglead() "{{{
  if !( has_key(s:, 'cmpwin') && get(s:cmpwin, 'on_cmpl') )
    echoerr 'backdraft: この関数は補完実行中にのみ機能します。' | return
  end
  call s:prompt.rm_arglead()
  let s:cmpwin.on_cmpl = 0
endfunction
"}}}
function! alti#get_fuzzy_arglead(arglead) "{{{
  return substitute(a:arglead, '.\_$\@!', '\0[^\0]\\{-}', 'g')
endfunction
"}}}
function! alti#split2args(input) "{{{
  return split(a:input, '\%(\\\@<!\s\)\+')
endfunction
"}}}

"==================
function! alti#insertstr_posttab_annotation(context, selected) "{{{
  call alti#on_insertstr_rm_arglead()
  return substitute(a:selected, '\t.*$', '', '')
endfunction
"}}}
function! alti#insertstr_pretab_annotation(context, selected) "{{{
  call alti#on_insertstr_rm_arglead()
  return substitute(a:selected, '^.*\t', '', '')
endfunction
"}}}
function! alti#insertstr_raw(context, selected) "{{{
  call alti#on_insertstr_rm_arglead()
  return a:selected
endfunction
"}}}

"=============================================================================
function! s:default_enter() "{{{
endfunction
"}}}
function! s:default_prompt(context) "{{{
  return '>>> '
endfunction
"}}}
function! s:default_cmpl(context) "{{{
  return []
endfunction
"}}}
function! s:default_submitted(context, input, lastselected) "{{{
  if a:input =~ '^\s*$'
    return
  end
  exe a:input
endfunction
"}}}
function! s:default_canceled(context, input, lastselected) "{{{
endfunction
"}}}
"==================
let s:TYPE_NUM = type(0)
function! s:_keyloop() "{{{
  while has_key(s:, 'prompt') && get(s:defines, 'enable_keyloop', 1)
    redraw
    let nr = getchar()
    let char = type(nr)==s:TYPE_NUM ? nr2char(nr) : nr
    if nr >= 33
      cal s:PrtAdd(char)
    else
      let cmd = matchstr(maparg(char), ':<C-u>\zs.\+\ze<CR>$')
      exe ( cmd != '' ? cmd : 'norm '.char )
    end
  endwhile
endfunction
"}}}
function! s:_adjust_cmdheight(str) "{{{
  let nlcount = s:_get_nlcount(a:str)
  let &cmdheight = nlcount >= s:glboptholder.get_optval('cmdheight') ? nlcount+1 : s:glboptholder.get_optval('cmdheight')
endfunction
"}}}
function! s:_get_nlcount(str) "{{{
  return count(split(a:str, '\zs'), "\n")
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
"s:HistHolder
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
function! s:_get_cmpwin_opts() "{{{
  if !has_key(g:, 'alti_cmpl_window')
    return {'pos': 'bottom', 'order': 'ttb', 'max': s:CWMAX, 'min': s:CWMIN, 'resultslimit': min([s:CWMAX, &lines])}
  end
  let ret = {}
  let cmpl_window = g:alti_cmpl_window
  let ret.pos = cmpl_window=~'top\|bottom' ? matchstr(cmpl_window, 'top\|bottom') : 'bottom'
  let ret.order = cmpl_window=~'order:[^,]\+' ? matchstr(cmpl_window, 'order:\zs[^,]\+') : 'ttb'
  let ret.max = cmpl_window=~'max:[^,]\+' ? str2nr(matchstr(cmpl_window, 'max:\zs\d\+')) : s:CWMAX
  let ret.min = cmpl_window=~'min:[^,]\+' ? str2nr(matchstr(cmpl_window, 'min:\zs\d\+')) : s:CWMIN
  let [ret.max, ret.min] = [max([ret.max, 1]), max(ret.min, 1)]
  let ret.min = min([ret.min, ret.max])
  let ret.resultslimit = cmpl_window=~'results:[^,]\+' ? str2nr(matchstr(cmpl_window, 'results:\zs\d\+')) : min([ret.max, &lines])
  let ret.resultslimit = max([ret.results, 1])
  return ret
endfunction
"}}}
function! s:_guicursor_enter() "{{{
  setl cul gcr=a:block-blinkon0-NONE t_ve=
endfunction
"}}}
"Prt
function! s:_exit_process(funcname) "{{{
  call s:argleadsholder._update_cursoridx()
  call s:argleadsholder.update_arglead()
  let state = extend(alti#get_arginfo(), {'lastselected': s:cmpwin._get_selected_word()})
  let CanceledFunc = s:prompt.get_exitfunc_elms(a:funcname)
  call s:cmpwin.close()
  wincmd p
  try
    call call(CanceledFunc, [state, state.inputline, state.lastselected], get(s:, 'funcself', {}))
  catch /E118/
    call call(CanceledFunc, [state, state.inputline], get(s:, 'funcself', {}))
  endtry
  let save_imd = &imd
  set imdisable
  let &imd = save_imd
  if !has_key(s:, 'cmpwin')
    unlet! s:funcself
  end
endfunction
"}}}

"=============================================================================
function! s:PrtAdd(char) "{{{
  call s:HistHolder.reset()
  call s:prompt.append(a:char)
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtBS() "{{{
  call s:HistHolder.reset()
  call s:prompt.bs()
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtDelete() "{{{
  call s:HistHolder.reset()
  call s:prompt.delete()
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtDeleteWord() "{{{
  call s:HistHolder.reset()
  call s:prompt.delete_word()
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtClear() "{{{
  call s:HistHolder.reset()
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
function! s:PrtHistory(delta) "{{{
  if !g:alti_max_history
    return
  end
  call s:prompt.insert_history(a:delta)
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtSmartHistory(delta) "{{{
  if s:HistHolder.idx == 0
    call s:PrtInsertSelection()
  else
    call s:PrtHistory(a:delta)
  end
endfunction
"}}}
function! s:PrtCurStart() "{{{
  if !s:prompt.cursor_start()
    return
  end
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtCurEnd() "{{{
  if !s:prompt.cursor_end()
    return
  end
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtCurLeft() "{{{
  if !s:prompt.cursor_left()
    return
  end
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtCurRight() "{{{
  if !s:prompt.cursor_right()
    return
  end
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtPage(delta) "{{{
  call s:cmpwin.turn_page(a:delta)
  call s:cmpwin.buildview()
endfunction
"}}}
function! s:PrtSelectMove(direction) "{{{
  call s:cmpwin.select_move(a:direction)
endfunction
"}}}
function! s:PrtInsertSelection(...) "{{{
  if a:0 && match(s:prompt.input[0], '\%([^\\]\\\)\@<!\\$')!=-1
    call s:PrtAdd(a:1)
    return
  end
  call s:HistHolder.reset()
  call s:cmpwin.insert_selection()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtDetailSelection() "{{{
  let detail = s:cmpwin.get_selected_detail()
  if detail==''
    return
  end
  echo detail
  call getchar()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:PrtActSelection(action) "{{{
  let selected = s:cmpwin.get_selected_raw()
  call s:cmpwin.update_candidates([a:action, selected])
  call s:cmpwin.buildview()
endfunction
"}}}
function! s:PrtExit() "{{{
  call s:_exit_process('canceledfunc')
endfunction
"}}}
function! s:PrtSubmit() "{{{
  call s:_exit_process('submittedfunc')
endfunction
"}}}
function! s:ToggleType(delta) "{{{
  if s:defines.len<2
    return
  end
  let idx = s:defines.idx + a:delta
  let s:defines.idx = idx >= s:defines.len ? 0 : idx<0 ? s:defines.len-1 : idx
  let define = s:defines.list[s:defines.idx]
  call extend(define, s:dfl_define, 'keep')
  let s:cmpwin.cmplfunc = define.cmpl
  let s:cmpwin.cmplsep = define.append_cmplsep ? ' ' : ''
  let s:cmpwin.insertstr = define.insertstr
  let s:prompt.prtbasefunc = define.prompt
  let s:prompt.submittedfunc = define.submitted
  let s:prompt.canceledfunc = define.canceled
  let s:prompt.static_text = define.static_text=='' ? '' : define.static_text. ' '
  exe 'hi link AltIPrtBase' define.prompt_hl
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
  if g:alti_enable_statusline
    call s:stlmgr.on_type_toggled()
  end
endfunction
"}}}
function! s:Nop() "{{{
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo

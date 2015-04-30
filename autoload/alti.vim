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
let s:TYPE_DICT = type({})
let s:TYPE_LIST = type([])
let s:TYPE_STR = type('')
let s:TYPE_NUM = type(0)
let s:TYPE_FLOAT = type(0.0)

function! s:get_getreg_mappings() "{{{
  let ret = {'expr': ['='], '<cword>': ['<C-w>'], '<cWORD>': ['<C-a>'], '<cfile>': ['<C-p>']}
  call extend(ret, get(g:, 'alti_getreg_mappings', {}))
  return map(ret, 'alti_l#lim#misc#expand_keycodes(v:val)')
endfunction
"}}}
function! s:refresh() "{{{
  call s:prompt.update_context()
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
  call s:prompt.echo()
endfunction
"}}}
function! s:keyloop() "{{{
  while exists('s:cmpwin')
    redraw
    try
      let inputs = alti_l#lim#ui#keybind(s:cmpwin.mappings, {'transit':1, 'expand': 1})
    catch
      call s:PrtExit()
    endtry
    if inputs=={}
      call s:PrtExit()
    elseif inputs.action!=''
      try
        exe 'call s:'. inputs.action
      catch /E1[01]7/
      endtry
    elseif inputs.surplus !~# "^[\x80[:cntrl:]]"
      exe printf('call s:PrtAdd(''%s'')', inputs.surplus)
    end
  endwhile
endfunction
"}}}

"==================
function! s:adjust_cmdheight(str) "{{{
  let nlcount = s:get_nlcount(a:str)
  let &cmdheight = nlcount >= s:glboptholder.get_optval('cmdheight') ? nlcount+1 : s:glboptholder.get_optval('cmdheight')
endfunction
"}}}
function! s:get_nlcount(str) "{{{
  return count(split(a:str, '\zs'), "\n")
endfunction
"}}}
"==================
"s:HistHolder
function! s:writecachefile(filename, list) "{{{
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
function! s:get_cw_opts() "{{{
  if !has_key(g:, 'alti_cmpl_window')
    return {'pos': 'bottom', 'order': 'ttb', 'max_height': s:CWMAX, 'min_height': s:CWMIN}
  end
  let ret = extend({'pos': 'bottom', 'order': 'ttb', 'max_height': s:CWMAX, 'min_height': s:CWMIN}, g:alti_cmpl_window)
  let [ret.max, ret.min] = [max([ret.max, 1]), max([ret.min, 1])]
  let ret.min = min([ret.min, ret.max])
  return ret
endfunction
"}}}
function! s:get_mappings() "{{{
  try
    let base = g:alti#mappings#{g:alti_default_mappings_base}#define
  catch /E121/
    echoerr 'invalid value of g:alti_default_mappings_base: '. g:alti_default_mappings_base
    let base = g:alti#mappings#standard#define
  endtry
  return filter(extend(copy(base), get(g:, 'alti_prompt_mappings', {})), 'v:val!=[]')
endfunction
"}}}
function! s:guicursor_enter() "{{{
  setl cul gcr=a:block-blinkon0-NONE t_ve=
endfunction
"}}}
"Prt
function! s:exit_process(funcname) "{{{
  call s:prompt.update_context()
  let context = s:prompt.context
  let line = s:prompt.static_head. context.inputline
  let lastselected = s:cmpwin.get_selection()
  let CanceledFunc = s:prompt.get_exitfunc_elms(a:funcname)
  call s:cmpwin.close()
  wincmd p
  try
    call call(CanceledFunc, [context, line, lastselected], get(s:, 'funcself', {}))
  catch /E118/
    call call(CanceledFunc, [context, line], get(s:, 'funcself', {}))
  endtry
  let save_imd = &imd
  set imdisable
  let &imd = save_imd
  if !has_key(s:, 'cmpwin')
    unlet! s:funcself
  end
endfunction
"}}}
"Context
function! s:split_into_words(cmdline) "{{{
  return split(a:cmdline, '\%(\\\@!<\\\)\@<!\s\+')
endfunction
"}}}
function! s:dictify_{s:TYPE_STR}(candidate) "{{{
  return {'word': a:candidate, 'is_parm': 0, 'division': {}}
endfunction
"}}}
function! s:dictify_{s:TYPE_NUM}(candidate) "{{{
  return {'word': string(a:candidate), 'is_parm': 0, 'division': {}}
endfunction
"}}}
function! s:dictify_{s:TYPE_FLOAT}(candidate) "{{{
  return {'word': string(a:candidate), 'is_parm': 0, 'division': {}}
endfunction
"}}}
function! s:dictify_{s:TYPE_LIST}(candidatelist) "{{{
  if a:candidatelist==[]
    return {}
  end
  let type = type(a:candidatelist[0])
  if !(type==s:TYPE_NUM || type==s:TYPE_FLOAT || type==s:TYPE_STR && a:candidatelist[0]!='')
    return {}
  end
  let ret = {'word': type==s:TYPE_STR ? a:candidatelist[0] : string(a:candidatelist[0]), 'is_parm': 0, 'division': {}}
  call s:_fill_canddict(ret, a:candidatelist[1:])
  return ret
endfunction
"}}}
function! s:dictify_2(invalid) "{{{
  return {}
endfunction
"}}}
function! s:dictify_{s:TYPE_DICT}(invalid) "{{{
  return {}
endfunction
"}}}
function! s:_fill_canddict(canddict, groups) "{{{
  for group in a:groups
    let type = type(group)
    if type==s:TYPE_LIST
      call s:_fill_canddict(a:canddict, group)
    elseif type==s:TYPE_STR
      if group=='__PARM'
        let a:canddict.is_parm = 1
      elseif group!=''
        let a:canddict.division[group] = 1
      end
    elseif type==s:TYPE_NUM || type==s:TYPE_FLOAT
      let a:canddict.division[string(group)] = 1
    end
    unlet group
  endfor
endfunction
"}}}


"======================================
let s:HistHolder = {'_hists': [], 'idx': 0, '_is_inputsaved': 0}
function! s:HistHolder.load() "{{{
  let path = expand(g:alti_cache_dir). '/hist'
  let self._hists = g:alti_max_history && filereadable(path) ? readfile(path) : []
  if get(self._hists, 0, "\n")!=''
    call insert(self._hists, '')
  endif
endfunction
"}}}
function! s:HistHolder.reset() "{{{
  let self._is_inputsaved = 0
  let self.idx = 0
endfunction
"}}}
function! s:HistHolder.save() "{{{
  let str = s:prompt.get_inputline()
  if str=~'^\s*$' || str==get(self._hists, 1, "\n") || !g:alti_max_history
    return
  end
  call insert(self._hists, str, 1)
  call alti_l#lim#misc#uniq(self._hists)
  if len(self._hists) > g:alti_max_history
    call remove(self._hists, g:alti_max_history, -1)
  end
  call s:writecachefile('hist', self._hists)
  call self.reset()
endfunction
"}}}
function! s:HistHolder.get_nexthist(delta) "{{{
  let self._hists[0] = self._is_inputsaved ? self._hists[0] : s:prompt.get_inputline()
  let self._hists[0] = self._hists[0]==get(self._hists, 1, "\n") ? '' : self._hists[0]
  let self._is_inputsaved = 1
  let histlen = len(self._hists)
  let self.idx += a:delta
  let self.idx = self.idx<0 ? 0 : self.idx < histlen ? self.idx : histlen > 1 ? histlen-1 : 0
  return self._hists[self.idx]
endfunction
"}}}
call s:HistHolder.load()

let s:GlboptHolder = {}
function! s:newGlboptHolder() "{{{
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

let s:StlMgr = {}
function! s:newStlMgr(define) "{{{
  let obj = {'_crrtype': '<'.(a:define.name=='' ? 'Alti'.(s:defines.idx+1) : a:define.name).'>'}
  let previdx = s:defines.idx-1 <0 ? s:defines.len-1 : s:defines.idx-1
  let nextidx = s:defines.idx+1 >=s:defines.len ? 0 : s:defines.idx+1
  let obj.prevtype = s:defines.len<2 ? '' : has_key(s:defines.list[previdx], 'sname') ? s:defines.list[previdx].sname : get(s:defines.list[previdx], 'name', 'Alti'.previdx+1)
  let obj.nexttype = s:defines.len<3 ? '' : has_key(s:defines.list[nextidx], 'sname') ? s:defines.list[nextidx].sname : get(s:defines.list[nextidx], 'name', 'Alti'.nextidx+1)
  let obj.pat = '%%#StatusLineNC#%12.12s  %%#StatusLine#%s  %%#StatusLineNC#%-12.12s%%*%%=(%d item%s) (page: %d/%d)   AltI%%<'
  let &l:stl = printf(obj.pat, obj.prevtype, obj._crrtype, obj.nexttype, 0, '', 1, 1)
  call extend(obj, s:StlMgr, 'keep')
  return obj
endfunction
"}}}
function! s:StlMgr.on_page_setted() "{{{
  let s = s:cmpwin.candidates_len>1 ? 's' : ''
  let &l:stl = printf(self.pat, self.prevtype, self._crrtype, self.nexttype, s:cmpwin.candidates_len, s, s:cmpwin.page, s:cmpwin.lastpage)
endfunction
"}}}
function! s:StlMgr.on_type_toggled() "{{{
  let crridx = s:defines.idx
  let crrlen = s:defines.len
  let self._crrtype = '<'.(s:defines.list[crridx].name=='' ? 'Alti'.(crridx+1) : s:defines.list[crridx].name).'>'
  let previdx = crridx-1 <0 ? crrlen-1 : crridx-1
  let nextidx = crridx+1 >=crrlen ? 0 : crridx+1
  let self.prevtype = crrlen<2 ? '' : has_key(s:defines.list[previdx], 'sname') ? s:defines.list[previdx].sname : get(s:defines.list[previdx], 'name', 'Alti'.previdx+1)
  let self.nexttype = crrlen<3 ? '' : has_key(s:defines.list[nextidx], 'sname') ? s:defines.list[nextidx].sname : get(s:defines.list[nextidx], 'name', 'Alti'.nextidx+1)
  let s = s:cmpwin.candidates_len>1 ? 's' : ''
  let &l:stl = printf(self.pat, self.prevtype, self._crrtype, self.nexttype, s:cmpwin.candidates_len, s, s:cmpwin.page, s:cmpwin.lastpage)
endfunction
"}}}

let s:CmpWin = {}
function! s:newCmpWin(define) "{{{
  let restcmds = {'winrestcmd': winrestcmd(), 'lines': &lines, 'winnr': winnr('$')}
  let cw_opts = s:get_cw_opts()
  let s:enable_autocmd = 0
  silent! exe 'keepalt' (cw_opts.pos=='top' ? 'topleft' : 'botright') '1new :[AltI]'
  let s:enable_autocmd = 1
  let s:alti_bufnr = bufnr('%')
  abclear <buffer>
  setl noro noswf nonu nobl nowrap nolist nospell nocuc winfixheight nohls fdc=0 fdl=99 tw=0 bt=nofile bufhidden=unload nocul
  if v:version > 702
    setl nornu noundofile cc=0
  end
  call s:guicursor_enter()
  sil! exe 'hi AltILinePre '.( has("gui_running") ? 'gui' : 'cterm' ).'fg=bg'
  sy match AltILinePre '^>'
  let obj = {'_rest': restcmds, '_cw': cw_opts, 'cmplfunc': a:define.cmpl, '_candidates': [], 'page': 1, 'lastpage': 1, 'candidates_len': 0,}
  let obj.mappings = s:get_mappings()
  call extend(obj, s:CmpWin, 'keep')
  return obj
endfunction
"}}}
function! s:CmpWin.update_candidates() "{{{
  try
    let self._candidates = call(self.cmplfunc, [s:prompt.context], s:funcself)
  catch
    call s:prompt.add_errmsg('In cmpl-function: '. v:throwpoint. ' '. v:exception)
    let self._candidates = []
  endtry
endfunction
"}}}
function! s:CmpWin._get_viewcandidates(firstidx, lastidx) "{{{
  let candidates = self._candidates[(a:firstidx):(a:lastidx)]
  return self._cw.order=='btt' ? reverse(candidates) : candidates
endfunction
"}}}
function! s:CmpWin._set_page() "{{{
  let self.candidates_len = len(self._candidates)
  let height = min([max([self._cw.min_height, self.candidates_len]), self._cw.max_height, &lines])
  let self.lastpage = (self.candidates_len-1) / height + 1
  let self.page = self.page > self.lastpage ? 1 : self.page
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
function! s:CmpWin.update_candidates_after_insert_selection() "{{{
  let save_candidates = copy(self._candidates)
  call self.update_candidates()
  if self._candidates != save_candidates
    unlet! self.__selection_row
  end
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
  let self.__selection_row = line('.')
endfunction
"}}}
function! s:CmpWin._get_selected_idx() "{{{
  let height = self._set_page()
  let self.__selection_row = line('.')
  return height*(self.page-1) + self.__selection_row-1
endfunction
"}}}
function! s:CmpWin.get_selection() "{{{
  let selected = get(self._candidates, self._get_selected_idx(), '')
  return type(selected)==s:TYPE_DICT ? get(selected, 'Word', '') : selected
endfunction
"}}}
function! s:CmpWin.get_selected_raw() "{{{
  return get(self._candidates, self._get_selected_idx(), '')
endfunction
"}}}
function! s:CmpWin.get_selected_detail() "{{{
  let selected = get(self._candidates, self._get_selected_idx(), '')
  if type(selected)!=s:TYPE_DICT
    return ''
  end
  return get(selected, 'Detail', '')
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
  if type(get(candidates, 0))==s:TYPE_DICT
    call map(candidates, 'has_key(v:val, "View") ? v:val.View : get(v:val, "Word", "")')
  end
  sil! exe '%delete _ | resize' height
  call map(candidates, '"> ". v:val')
  call setline(1, candidates)
  setl noma
  if has_key(self, '__selection_row')
    call cursor(self.__selection_row, 1)
  else
    exe 'keepj norm! '. (self._cw.order=='btt' ? 'G' : 'gg'). '1|'
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
  if self._rest.lines >= &lines && self._rest.winnr == winnr('$')
    exe self._rest.winrestcmd
  end
  echo
  redraw
  call s:HistHolder.save()
  unlet! s:cmpwin s:prompt s:regholder s:defines s:stlmgr
endfunction
"}}}

let s:Prompt = {}
function! s:newPrompt(define, firstmess) "{{{
  exe 'hi link AltIPrtBase' a:define.prompt_hl
  hi link AltIPrtText     Normal
  hi link AltIPrtCursor   Cursor
  let obj = copy(s:Prompt)
  let obj.input = [a:define.default_text, '']
  let obj.prtbasefunc = a:define.prompt
  let obj.insertstrfunc = a:define.insertstr
  let obj.insertsep = a:define.append_sep ? ' ' : ''
  let obj.submittedfunc = a:define.submitted
  let obj.canceledfunc = a:define.canceled
  let obj.inputline = a:define.default_text
  let obj.static_head = a:define.static_head=='' ? '' : a:define.static_head=~'\s$' ? a:define.static_head : a:define.static_head. ' '
  let obj._firstmess = a:firstmess
  let obj._errmsgs = []
  let obj.context = s:newContext(obj, [])
  return obj
endfunction
"}}}
function! s:Prompt.get_inputline() "{{{
  let self.inputline = join(self.input, '')
  return self.inputline
endfunction
"}}}
function! s:Prompt.get_exitfunc_elms(exitfuncname) "{{{
  return self[a:exitfuncname]
endfunction
"}}}
function! s:Prompt.add_errmsg(errmsg) "{{{
  call add(self._errmsgs, a:errmsg)
endfunction
"}}}
function! s:Prompt.echo() "{{{
  redraw
  try
    let prtbase = call(self.prtbasefunc, [self.context], s:funcself)
  catch
    call self.add_errmsg('In prompt-function: '.v:throwpoint. ' '. v:exception)
    let prtbase = '>>> '
  endtry
  call s:adjust_cmdheight(prtbase)
  let &cmdheight += len(self._errmsgs) + (self._firstmess=='' ? 0 : s:get_nlcount(self._firstmess)+1)
  echoh Error
  for msg in self._errmsgs
    echom msg
  endfor
  echoh NONE
  if self._firstmess!=''
    echo self._firstmess
  end
  let [self._errmsgs, self._firstmess] =[[], '']
  let onpostcurs = matchlist(self.input[1], '^\(.\)\(.*\)')
  let inputs = map([self.input[0], get(onpostcurs, 1, ''), get(onpostcurs, 2, '')], 'escape(v:val, ''"\'')')
  let is_cursorspace = inputs[1]=='' || inputs[1]==' '
  let [hiactive, hicursor] = ['AltIPrtText', (is_cursorspace? 'AltIPrtCursor': 'AltIPrtCursor')]
  exe 'echoh AltIPrtBase| echo "'. escape(prtbase, '"\'). '"'
  exe 'echoh' hiactive '| echon "'. self.static_head. inputs[0]. '"'
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
function! s:Prompt.insert_selection(selection) "{{{
  call self.update_context()
  let self.OnCmpl = 1
  try
    let str = call(self.insertstrfunc, [self.context, a:selection], s:funcself)
  catch
    call self.add_errmsg('In insertstr-function: '. v:throwpoint. ' '. v:exception)
    return
  endtry
  unlet self.OnCmpl
  call self.append(str. self.insertsep)
  call self.update_context()
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
function! s:Prompt.update_context(...) "{{{
  let action = a:0 ? a:1 : []
  if self._should_update_context()
    let self.context = s:newContext(self, action)
  end
endfunction
"}}}
function! s:Prompt._should_update_context() "{{{
  return !(self.input[0]==#self.context.precursor && self.input[1]==#self.context.postcursor)
endfunction
"}}}

let s:Context = {}
function! s:newContext(prompt, action) "{{{
  let obj = copy(s:Context)
  let obj.action = a:action
  let precursor = a:prompt.input[0]
  let precursorlen = len(precursor)
  let is_on_edge = precursor[precursorlen-1]!=' ' ? precursor[precursorlen-1]=='' : precursor[precursorlen-2]!='/' || precursor[precursorlen-3]=='/'
  let obj.precursor = precursor
  let obj.postcursor = a:prompt.input[1]
  let obj.inputline = a:prompt.get_inputline()
  let obj.inputs = s:split_into_words(obj.inputline)
  let obj.leftwords = s:split_into_words(obj.precursor)
  let obj.arglead = is_on_edge ? '' : obj.leftwords[-1]
  let obj.preword = is_on_edge ? get(obj.leftwords, -1, '') : get(obj.leftwords, -2, '')
  let obj.leftcount = is_on_edge ? len(obj.leftwords) : len(obj.leftwords)-1
  let obj._inputs_exc_curword = copy(obj.inputs)
  if !is_on_edge
    unlet obj._inputs_exc_curword[obj.leftcount]
  end
  let obj.cursoridx = precursorlen
  return obj
endfunction
"}}}
function! s:Context._filtered_by_inputs(candidates) "{{{
  let canddicts = map(deepcopy(a:candidates), 's:dictify_{type(v:val)}(v:val)')
  let should_del_groups = {}
  for canddict in canddicts
    if index(self._inputs_exc_curword, get(canddict, 'word', ''))!=-1
      call extend(should_del_groups, canddict.division)
    end
  endfor
  let expr = should_del_groups=={} ? '' : '!('. join(map(keys(should_del_groups), '"has_key(v:val.division, ''". v:val. "'')"'), '||'). ') &&'
  call filter(canddicts, 'v:val!={} && ( v:val.is_parm || '. expr. ' index(self._inputs_exc_curword, v:val.word)==-1 )')
  return map(canddicts, 'v:val.word')
endfunction
"}}}
function! s:Context.filtered(candidates) "{{{
  let candidates = self._filtered_by_inputs(a:candidates)
  return filter(candidates, 'v:val =~ "^".self.arglead')
endfunction
"}}}
function! s:Context.backward_filtered(candidates) "{{{
  let candidates = self._filtered_by_inputs(a:candidates)
  return filter(candidates, 'v:val =~ self.arglead."$"')
endfunction
"}}}
function! s:Context.partial_filtered(candidates) "{{{
  let candidates = self._filtered_by_inputs(a:candidates)
  return filter(candidates, 'v:val =~ self.arglead')
endfunction
"}}}
function! s:Context.fuzzy_filtered(candidates) "{{{
  let candidates = self._filtered_by_inputs(a:candidates)
  let pat = substitute(self.arglead, '.\_$\@!', '\0[^\0]\\{-}', 'g')
  return filter(candidates, 'v:val =~ pat')
endfunction
"}}}


"=============================================================================
"Main:
let s:dfl_define = {'name': '', 'default_text': '', 'static_head': '', 'prompt': 's:default_prompt', 'cmpl': 's:default_cmpl',
  \ 'insertstr': 'alti#insertstr_posttab_annotation', 'canceled': 's:default_canceled', 'submitted': 's:default_submitted',
  \ 'append_sep': 1, 'prompt_hl': 'Comment'}
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
  let s:glboptholder = s:newGlboptHolder()
  let s:prompt = s:newPrompt(Define, firstmess)
  let s:cmpwin = s:newCmpWin(Define)

  if g:alti_enable_statusline
    let s:stlmgr = s:newStlMgr(Define)
  end
  call s:refresh()
  call s:keyloop()
endfunction
"}}}

"------------------
function! alti#on_insertstr_rm_arglead() "{{{
  if !( has_key(s:, 'cmpwin') && get(s:prompt, 'OnCmpl') )
    echoerr 'alti: この関数は補完実行中にのみ機能します。' | return
  end
  call s:prompt.rm_arglead()
  let s:cmpwin.OnCmpl = 0
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

"======================================
function! s:PrtAdd(char) "{{{
  call s:HistHolder.reset()
  call s:prompt.append(a:char)
  call s:refresh()
endfunction
"}}}
function! s:PrtBS() "{{{
  call s:HistHolder.reset()
  call s:prompt.bs()
  call s:refresh()
endfunction
"}}}
function! s:PrtDelete() "{{{
  call s:HistHolder.reset()
  call s:prompt.delete()
  call s:refresh()
endfunction
"}}}
function! s:PrtDeleteWord() "{{{
  call s:HistHolder.reset()
  call s:prompt.delete_word()
  call s:refresh()
endfunction
"}}}
function! s:PrtClear() "{{{
  call s:HistHolder.reset()
  call s:prompt.clear()
  call s:refresh()
endfunction
"}}}
function! s:PrtInsertReg() "{{{
  let save_gcr = &gcr
  set gcr&
  let char = nr2char(getchar())
  let &gcr = save_gcr
  for [regname, chars] in items(s:get_getreg_mappings())
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
  call s:refresh()
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
  call s:refresh()
endfunction
"}}}
function! s:PrtCurEnd() "{{{
  if !s:prompt.cursor_end()
    return
  end
  call s:refresh()
endfunction
"}}}
function! s:PrtCurLeft() "{{{
  if !s:prompt.cursor_left()
    return
  end
  call s:refresh()
endfunction
"}}}
function! s:PrtCurRight() "{{{
  if !s:prompt.cursor_right()
    return
  end
  call s:refresh()
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
  let substr = a:0 ? a:1 : ''
  let selection = s:cmpwin.get_selection()
  if substr!='' && (selection=='' || match(s:prompt.input[0], '\%([^\\]\\\)\@<!\\$')!=-1)
    call s:PrtAdd(substr)
    return
  elseif selection==''
    return
  end
  call s:HistHolder.reset()
  call s:prompt.insert_selection(selection)
  call s:cmpwin.update_candidates_after_insert_selection()
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
  call s:prompt.update_context([a:action, selected])
  call s:cmpwin.update_candidates()
  call s:cmpwin.buildview()
endfunction
"}}}
function! s:PrtExit() "{{{
  call s:exit_process('canceledfunc')
endfunction
"}}}
function! s:PrtSubmit() "{{{
  call s:exit_process('submittedfunc')
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
  let s:prompt.insertsep = define.append_sep ? ' ' : ''
  let s:prompt.insertstrfunc = define.insertstr
  let s:prompt.prtbasefunc = define.prompt
  let s:prompt.submittedfunc = define.submitted
  let s:prompt.canceledfunc = define.canceled
  let s:prompt.static_head = a:define.static_head=='' ? '' : a:define.static_head=~'\s$' ? a:define.static_head : a:define.static_head. ' '
  exe 'hi link AltIPrtBase' define.prompt_hl
  call s:refresh()
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

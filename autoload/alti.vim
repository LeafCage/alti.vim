if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
aug AltI
  autocmd!
  autocmd BufEnter :[AltI]   if s:enable_autocmd && has_key(s:, 'alti_bufnr') && s:alti_bufnr > 0| exe s:alti_bufnr.'bw!'| end
  autocmd BufLeave :[AltI]   if s:enable_autocmd && exists('b:alti_cmplwin')| call b:alti_cmplwin.close()| end
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
  call b:alti_cmplwin.update_candidates()
  call s:buildview()
  call b:alti_prompt.echo()
endfunction
"}}}
function! s:buildview() "{{{
  call b:alti_cmplwin.buildview()
  call s:Context_set_selection()
endfunction
"}}}
function! s:keyloop() "{{{
  while exists('b:alti_cmplwin')
    redraw
    try
      let inputs = alti_l#lim#ui#keybind(b:alti_cmplwin.mappings, {'transit':1, 'expand': 1})
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
function! s:exit_process(funcname) "{{{
  let context = b:alti_context
  let line = b:alti_prompt.static_head. context.inputline
  let Exit__Func = b:alti_prompt.get_exitfunc_elms(a:funcname)
  call b:alti_cmplwin.close()
  wincmd p
  call call(Exit__Func, [context, line], get(s:, 'funcself', {}))
  call s:_force_imoff()
  if !exists('b:alti_cmplwin')
    unlet! s:funcself
  end
endfunction
"}}}
function! s:_force_imoff() "{{{
  let save_imd = &imd
  set imdisable
  let &imd = save_imd
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
"b:alti_cmplwin
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
    echom 'invalid value of g:alti_default_mappings_base: '. g:alti_default_mappings_base
    let base = g:alti#mappings#standard#define
  endtry
  return filter(extend(copy(base), get(g:, 'alti_prompt_mappings', {})), 'v:val!=[]')
endfunction
"}}}
function! s:guicursor_enter() "{{{
  setl cul gcr=a:block-blinkon0-NONE t_ve=
endfunction
"}}}
"Context
function! s:split_into_words(cmdline) "{{{
  return split(a:cmdline, '\%(\\\@!<\\\)\@<!\s\+')
endfunction
"}}}
function! s:divisionholder(holder, divisions) "{{{
  for division in a:divisions
    let type = type(division)
    if type==s:TYPE_LIST
      call s:divisionholder(a:holder, division)
    elseif type==s:TYPE_STR
      if division!=''
        let a:holder[division] = 1
      end
    elseif type==s:TYPE_NUM || type==s:TYPE_FLOAT
      let a:holder[string(division)] = 1
    end
    unlet division
  endfor
  return a:holder
endfunction
"}}}
let s:Assorter = {}
function! s:newAssorter(inputs) "{{{
  let obj = copy(s:Assorter)
  let obj.inputs = a:inputs
  let obj.should_del_groups = {}
  let obj.candidates = []
  let obj.divisions = []
  return obj
endfunction
"}}}
function! s:Assorter.assort_candidates(candidates) "{{{
  for cand in a:candidates
    let type = type(cand)
    if type!=s:TYPE_LIST
      if index(self.inputs, (type==s:TYPE_STR ? cand : string(cand)))==-1
        call self._add([cand], [{}])
      end
    elseif cand!=[]
      call self._assort_listcand(cand)
    end
    unlet cand
  endfor
endfunction
"}}}
function! s:Assorter._assort_listcand(cand) "{{{
  let type = type(a:cand[0])
  if !(type==s:TYPE_NUM || type==s:TYPE_FLOAT || type==s:TYPE_STR && a:cand[0]!='')
    return
  end
  let division = s:divisionholder({}, a:cand[1:])
  if index(self.inputs, (type==s:TYPE_STR ? a:cand[0] : string(a:cand[0])))==-1
    call self._add([a:cand[0]], [division])
    return
  end
  call extend(self.should_del_groups, division)
  if has_key(division, '__PARM')
    call self._add([a:cand[0]], [division])
  end
endfunction
"}}}
function! s:Assorter._add(cand, division) "{{{
  let self.candidates += a:cand
  let self.divisions += a:division
endfunction
"}}}
function! s:Assorter.remove_del_grouped_candidates() "{{{
  if has_key(self.should_del_groups, '__PARM')
    unlet self.should_del_groups.__PARM
  end
  if self.should_del_groups!={}
    let divisions = self.divisions
    call filter(self.candidates, 'has_key(divisions[v:key], "__PARM") || !('. join(map(keys(self.should_del_groups), '"has_key(divisions[v:key], ''". v:val. "'')"'), '||'). ')')
  end
  return self.candidates
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
  let str = b:alti_prompt.get_inputline()
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
  let self._hists[0] = self._is_inputsaved ? self._hists[0] : b:alti_prompt.get_inputline()
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
    call b:alti_prompt.echo()
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
  let s = b:alti_cmplwin.candidates_len>1 ? 's' : ''
  let &l:stl = printf(self.pat, self.prevtype, self._crrtype, self.nexttype, b:alti_cmplwin.candidates_len, s, b:alti_cmplwin.page, b:alti_cmplwin.lastpage)
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
  let s = b:alti_cmplwin.candidates_len>1 ? 's' : ''
  let &l:stl = printf(self.pat, self.prevtype, self._crrtype, self.nexttype, b:alti_cmplwin.candidates_len, s, b:alti_cmplwin.page, b:alti_cmplwin.lastpage)
endfunction
"}}}

let s:CmplWin = {}
function! s:newCmplWin(define) "{{{
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
  call extend(obj, s:CmplWin, 'keep')
  return obj
endfunction
"}}}
function! s:CmplWin.update_candidates() "{{{
  try
    let self._candidates = call(self.cmplfunc, [b:alti_context], s:funcself)
  catch
    call b:alti_prompt.add_errmsg('cmpl-function: '. v:throwpoint. ' '. v:exception)
    let self._candidates = []
  endtry
endfunction
"}}}
function! s:CmplWin._get_viewcandidates(firstidx, lastidx) "{{{
  let candidates = self._candidates[(a:firstidx):(a:lastidx)]
  return self._cw.order=='btt' ? reverse(candidates) : candidates
endfunction
"}}}
function! s:CmplWin._set_page() "{{{
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
function! s:CmplWin._get_buildelm() "{{{
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
function! s:CmplWin.update_candidates_after_insert_selection() "{{{
  let save_candidates = copy(self._candidates)
  call self.update_candidates()
  if self._candidates != save_candidates
    unlet! self.__selection_row
  end
endfunction
"}}}
function! s:CmplWin.select_move(direction) "{{{
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
function! s:CmplWin._get_selected_idx() "{{{
  let height = self._set_page()
  let self.__selection_row = line('.')
  return height*(self.page-1) + self.__selection_row-1
endfunction
"}}}
function! s:CmplWin.get_rawselection() "{{{
  return get(self._candidates, self._get_selected_idx(), '')
endfunction
"}}}
function! s:CmplWin.get_selected_detail() "{{{
  let selected = get(self._candidates, self._get_selected_idx(), '')
  if type(selected)!=s:TYPE_DICT
    return ''
  end
  return get(selected, 'Detail', '')
endfunction
"}}}
function! s:CmplWin.turn_page(delta) "{{{
  let self.page += a:delta
  let self.page = self.page<1 ? self.lastpage : self.page>self.lastpage ? 1 : self.page
endfunction
"}}}
function! s:CmplWin.buildview() "{{{
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
function! s:CmplWin._refresh_highlight() "{{{
  call clearmatches()
  cal matchadd('AltILinePre', '^>')
endfunction
"}}}
function! s:CmplWin.close() "{{{
  call s:HistHolder.save()
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
  unlet! s:regholder s:defines s:stlmgr
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
    let prtbase = call(self.prtbasefunc, [b:alti_context], s:funcself)
  catch
    call self.add_errmsg('prompt-function: '.v:throwpoint. ' '. v:exception)
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
function! s:Prompt.insert_selection() "{{{
  let self.OnCmpl = 1
  try
    let str = call(self.insertstrfunc, [b:alti_context], s:funcself)
  catch
    call self.add_errmsg('insertstr-function: '. v:throwpoint. ' '. v:exception)
    return
  endtry
  unlet self.OnCmpl
  call self.append(str. self.insertsep)
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
function! s:Prompt.should_update_context() "{{{
  return !(self.input[0] ==# b:alti_context.precursor && self.input[1] ==# b:alti_context.postcursor)
endfunction
"}}}

let s:Context = {}
function! s:newContext(define) "{{{
  let obj = copy(s:Context)
  let obj.static_head = a:define.static_head
  let obj.rawselection = ''
  return obj
endfunction
"}}}
function! s:Context_update_prtinfo() "{{{
  let self = b:alti_context
  let precursor = b:alti_prompt.input[0]
  let precursorlen = len(precursor)
  let is_on_edge = precursor[precursorlen-1]!=' ' ? precursor[precursorlen-1]=='' : precursor[precursorlen-2]!='/' || precursor[precursorlen-3]=='/'
  let self.precursor = precursor
  let self.postcursor = b:alti_prompt.input[1]
  let self.inputline = b:alti_prompt.get_inputline()
  let self.leftwords = s:split_into_words(self.precursor)
  let self.arglead = is_on_edge ? '' : self.leftwords[-1]
  let self.preword = is_on_edge ? get(self.leftwords, -1, '') : get(self.leftwords, -2, '')
  let self.leftcount = is_on_edge ? len(self.leftwords) : len(self.leftwords)-1
  let self.inputs = s:split_into_words(self.inputline)
  if !is_on_edge
    unlet self.inputs[self.leftcount]
  end
  let self.cursoridx = precursorlen
endfunction
"}}}
function! s:Context_set_selection() "{{{
  let self = b:alti_context
  let rawselection = b:alti_cmplwin.get_rawselection()
  unlet self.rawselection
  let self.rawselection = rawselection
  let type = type(rawselection)
  if type==s:TYPE_STR
    let self.selection = rawselection
  elseif type == s:TYPE_DICT
    let selection = has_key(rawselection, 'insert') ? rawselection.insert : get(rawselection, 'word', '')
    let self.selection = type(selection)==s:TYPE_STR ? selection : string(selection)
  else
    let self.selection = string(rawselection)
  end
endfunction
"}}}
function! s:Context_update_as_needed() "{{{
  if b:alti_prompt.should_update_context()
    call s:Context_update_prtinfo()
  end
endfunction
"}}}
function! s:Context._filtered_by_inputs(candidates) "{{{
  let assorter = s:newAssorter(self.inputs)
  call assorter.assort_candidates(a:candidates)
  return assorter.remove_del_grouped_candidates()
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
  if exists('b:alti_cmplwin')
    return
  end
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
  let b:alti_cmplwin = s:newCmplWin(Define)
  let b:alti_prompt = s:newPrompt(Define, firstmess)
  if g:alti_enable_statusline
    let s:stlmgr = s:newStlMgr(Define)
  end
  let b:alti_context = s:newContext(Define)
  call s:Context_update_prtinfo()
  call s:refresh()
  call s:keyloop()
endfunction
"}}}

"------------------
function! alti#on_insertstr_rm_arglead() "{{{
  if !( exists('b:alti_cmplwin') && get(b:alti_prompt, 'OnCmpl') )
    echoerr 'alti: この関数は補完実行中にのみ機能します。' | return
  end
  call b:alti_prompt.rm_arglead()
  let b:alti_cmplwin.OnCmpl = 0
endfunction
"}}}

"==================
function! alti#insertstr_posttab_annotation(context) "{{{
  call alti#on_insertstr_rm_arglead()
  return substitute(a:context.selection, '\t.*$', '', '')
endfunction
"}}}
function! alti#insertstr_pretab_annotation(context) "{{{
  call alti#on_insertstr_rm_arglead()
  return substitute(a:context.selection, '^.*\t', '', '')
endfunction
"}}}
function! alti#insertstr(context) "{{{
  call alti#on_insertstr_rm_arglead()
  return a:contextstr.selection
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
function! s:default_submitted(context, input) "{{{
  if a:input =~ '^\s*$'
    return
  end
  exe a:input
endfunction
"}}}
function! s:default_canceled(context, input) "{{{
endfunction
"}}}

"======================================
function! s:PrtAdd(char) "{{{
  call s:HistHolder.reset()
  call b:alti_prompt.append(a:char)
  call s:Context_update_prtinfo()
  call s:refresh()
endfunction
"}}}
function! s:PrtBS() "{{{
  call s:HistHolder.reset()
  call b:alti_prompt.bs()
  call s:Context_update_as_needed()
  call s:refresh()
endfunction
"}}}
function! s:PrtDelete() "{{{
  call s:HistHolder.reset()
  call b:alti_prompt.delete()
  call s:Context_update_as_needed()
  call s:refresh()
endfunction
"}}}
function! s:PrtDeleteWord() "{{{
  call s:HistHolder.reset()
  call b:alti_prompt.delete_word()
  call s:Context_update_as_needed()
  call s:refresh()
endfunction
"}}}
function! s:PrtClear() "{{{
  call s:HistHolder.reset()
  call b:alti_prompt.clear()
  call s:Context_update_as_needed()
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
  call b:alti_prompt.insert_history(a:delta)
  call s:Context_update_as_needed()
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
  if !b:alti_prompt.cursor_start()
    return
  end
  call s:Context_update_prtinfo()
  call s:refresh()
endfunction
"}}}
function! s:PrtCurEnd() "{{{
  if !b:alti_prompt.cursor_end()
    return
  end
  call s:Context_update_prtinfo()
  call s:refresh()
endfunction
"}}}
function! s:PrtCurLeft() "{{{
  if !b:alti_prompt.cursor_left()
    return
  end
  call s:Context_update_prtinfo()
  call s:refresh()
endfunction
"}}}
function! s:PrtCurRight() "{{{
  if !b:alti_prompt.cursor_right()
    return
  end
  call s:Context_update_prtinfo()
  call s:refresh()
endfunction
"}}}
function! s:PrtPage(delta) "{{{
  call b:alti_cmplwin.turn_page(a:delta)
  call s:buildview()
endfunction
"}}}
function! s:PrtSelectMove(direction) "{{{
  call b:alti_cmplwin.select_move(a:direction)
  call s:Context_set_selection()
endfunction
"}}}
function! s:PrtInsertSelection(...) "{{{
  let substr = a:0 ? a:1 : ''
  if substr!='' && (b:alti_context.selection=='' || match(b:alti_prompt.input[0], '\%([^\\]\\\)\@<!\\$')!=-1)
    call s:PrtAdd(substr)
    return
  elseif b:alti_context.selection==''
    return
  end
  call s:HistHolder.reset()
  call b:alti_prompt.insert_selection()
  call s:Context_update_prtinfo()
  call b:alti_cmplwin.update_candidates_after_insert_selection()
  call s:buildview()
  call b:alti_prompt.echo()
endfunction
"}}}
function! s:PrtDetailSelection() "{{{
  let detail = b:alti_cmplwin.get_selected_detail()
  if detail==''
    return
  end
  echo detail
  call getchar()
  call s:buildview()
  call b:alti_prompt.echo()
endfunction
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
  let b:alti_cmplwin.cmplfunc = define.cmpl
  let b:alti_prompt.insertsep = define.append_sep ? ' ' : ''
  let b:alti_prompt.insertstrfunc = define.insertstr
  let b:alti_prompt.prtbasefunc = define.prompt
  let b:alti_prompt.submittedfunc = define.submitted
  let b:alti_prompt.canceledfunc = define.canceled
  let b:alti_prompt.static_head = define.static_head=='' ? '' : define.static_head=~'\s$' ? define.static_head : define.static_head. ' '
  let b:alti_context.static_head = define.static_head
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

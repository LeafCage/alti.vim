if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:TYPE_STR = type('')
let s:TYPE_LIST = type([])
let s:TYPE_DICT = type({})
function! s:make_menu_mappings() "{{{
  let ret = {'MenuPrev': [], 'MenuNext': [], 'MenuExecute': [], 'MenuExit': [], 'MenuRefineBS': [], 'MenuRefineClear': [], 'PrtInsertSelection': []}
  for [name, binds] in items(b:alti_prompt.mappings)
    try
      exe 'let cmd = s:_make_menu_'. name
    catch /E1[01]7/
      continue
    endtry
    if cmd!=''
      call extend(ret[cmd], binds)
    end
  endfor
  return ret
endfunction
"}}}
function! s:get_menuitems_base() "{{{
  if type(b:alti_context.rawselection)!=s:TYPE_DICT
    return b:alti_cmplwin.menu
  end
  let rawselection = b:alti_context.rawselection
  let menu_type = get(rawselection, 'menu_type', 'post')
  let altmenu = has_key(rawselection, 'menu') ? rawselection.menu : []
  if type(altmenu)!=s:TYPE_LIST
    let s:menu_err = 'menu type of "'. (has_key(rawselection, 'view') ? rawselection.view : get(rawselection, 'word', '')). '" is not List.'
    echoh ErrorMsg
    echom s:menu_err
    return b:alti_cmplwin.menu
  end
  return menu_type==#'override' ? altmenu : menu_type==#'pre' ?  altmenu + b:alti_cmplwin.menu : menu_type==#'post' ? b:alti_cmplwin.menu + altmenu : b:alti_cmplwin.menu
endfunction
"}}}

function! s:_make_menu_PrtHistory(delta) "{{{
  return a:delta < 0 ? 'MenuNext' : a:delta > 0 ? 'MenuPrev' : ''
endfunction
"}}}
function! s:_make_menu_PrtPage(delta) "{{{
  return a:delta > 0 ? 'MenuNext' : a:delta < 0 ? 'MenuPrev' : ''
endfunction
"}}}
function! s:_make_menu_PrtSelectMove(direc) "{{{
  return get({'j': 'MenuNext', 'k': 'MenuPrev'}, a:direc, '')
endfunction
"}}}
function! s:_make_menu_SelectionMenu() "{{{
  return 'MenuExit'
endfunction
"}}}
function! s:_make_menu_PrtBS() "{{{
  return 'MenuRefineBS'
endfunction
"}}}
function! s:_make_menu_PrtDeleteWord() "{{{
  return 'MenuRefineClear'
endfunction
"}}}
function! s:_make_menu_PrtClear() "{{{
  return 'MenuRefineClear'
endfunction
"}}}
function! s:_make_menu_PrtExit() "{{{
  return 'MenuExit'
endfunction
"}}}
function! s:_make_menu_PrtSubmit() "{{{
  return 'MenuExecute'
endfunction
"}}}
function! s:_make_menu_DefaultAction(idx) "{{{
  return 'MenuExecute'
endfunction
"}}}

let s:MenuBase = {}
function! s:newMenuBase(word) "{{{
  let obj = copy(s:MenuBase)
  let items = []
  for m in s:get_menuitems_base()
    let type = type(m)
    let items += (type==s:TYPE_STR ? m=='' ? [] : [{'word': a:word, 'abbr': m, 'dup': 1}] : (type==s:TYPE_LIST && m!=[] && m[0]!='') ? [{'word': a:word, 'abbr': m[0], 'menu': get(m, 1, ''), 'dup': 1}] : [])
    unlet m
  endfor
  let obj.ITEMS = items
  let obj.WORD = a:word
  let obj._input = ''
  return obj
endfunction
"}}}
function! s:MenuBase.createMenu() "{{{
  if self._input==''
    return s:newMenu(self.ITEMS)
  end
  let items = filter(copy(self.ITEMS), 'v:val.abbr =~ "^". self._input')
  if items!=[]
    return s:newMenu(items)
  end
  return s:newEmptyMenu(self.WORD)
endfunction
"}}}
function! s:MenuBase.update_menu() "{{{
  let s:menu = self.createMenu()
  let menu = s:menu
endfunction
"}}}
function! s:MenuBase.refine_add(char) "{{{
  let self._input .= a:char
endfunction
"}}}
function! s:MenuBase.bs() "{{{
  let self._input = substitute(self._input, '.$', '', '')
endfunction
"}}}
function! s:MenuBase.clear() "{{{
  let self._input = ''
endfunction
"}}}

let s:Menu = {}
function! s:newMenu(items) "{{{
  let obj = copy(s:Menu)
  let obj.is_empty = 0
  let obj.items = a:items
  let obj.len = len(a:items)
  let obj.idx = 0
  return obj
endfunction
"}}}
function! s:Menu.begin() "{{{
  return "\<Esc>A\<C-x>\<C-o>\<C-r>=alti#menu#_capture()\<CR>"
endfunction
"}}}
function! s:Menu.prev() "{{{
  let self.idx -= 1
  if self.idx >= 0
    return "\<C-p>\<C-r>=alti#menu#_capture()\<CR>"
  end
  let self.idx = self.len-1
  return "\<C-p>\<C-p>\<C-r>=alti#menu#_capture()\<CR>"
endfunction
"}}}
function! s:Menu.next() "{{{
  let self.idx += 1
  if self.idx < self.len
    return "\<C-n>\<C-r>=alti#menu#_capture()\<CR>"
  end
  let self.idx = 0
  return "\<C-n>\<C-n>\<C-r>=alti#menu#_capture()\<CR>"
endfunction
"}}}
function! s:Menu.get_action() "{{{
  return self.items[self.idx].abbr
endfunction
"}}}

let s:EmptyMenu = {}
function! s:newEmptyMenu(word) "{{{
  let obj = copy(s:EmptyMenu)
  let obj.is_empty = 1
  let obj.items = [{'word': a:word, 'abbr': '==NO ITEM=='}]
  return obj
endfunction
"}}}
function! s:EmptyMenu.begin() "{{{
  return "\<Esc>A\<C-x>\<C-o>\<C-p>\<C-n>\<C-p>\<C-r>=alti#menu#_capture()\<CR>"
endfunction
"}}}
function! s:EmptyMenu.prev() "{{{
  return s:MenuNop()
endfunction
"}}}
function! s:EmptyMenu.next() "{{{
  return s:MenuNop()
endfunction
"}}}
function! s:EmptyMenu.get_action() "{{{
  return ''
endfunction
"}}}


"=============================================================================
"Main:
function! alti#menu#open() "{{{
  if !exists('b:menu_mappings')
    let b:menu_mappings = s:make_menu_mappings()
  end
  call b:alti_prompt.echo()
  setl ma
  unlet! s:menu_base s:menu
  let s:menu_err = ''
  call feedkeys("A\<C-x>\<C-o>\<C-r>=alti#menu#_capture()\<CR>", 'n')
endfunction
"}}}
function! alti#menu#cmpl(findstart, base) "{{{
  if a:findstart
    return exists('b:alti_cmplwin') ? 0 : -1
  elseif !exists('s:menu_base')
    let s:menu_base = s:newMenuBase(a:base)
  end
  let s:menu = s:menu_base.createMenu()
  return s:menu.items
endfunction
"}}}
function! alti#menu#_capture() "{{{
  if !exists('b:alti_cmplwin')
    return "\<Esc>"
  elseif !pumvisible()
    return s:MenuExit()
  end
  call b:alti_prompt.echo()
  if s:menu_err!=''
    echoh ErrorMsg
    echon "\n". s:menu_err
    echoh NONE
  end
  try
    let inputs = alti_l#lim#ui#keybind(b:menu_mappings, {'transit':1, 'expand': 1})
  catch
    return s:MenuExit()
  endtry
  if inputs=={}
    return s:MenuExit()
  elseif inputs.action!=''
    return s:{inputs.action}()
  elseif inputs.surplus !~# "^[\x80[:cntrl:]]"
    return s:MenuRefine(inputs.surplus)
  end
  return s:MenuNop()
endfunction
"}}}


function! s:MenuPrev() "{{{
  return s:menu.prev()
endfunction
"}}}
function! s:MenuNext() "{{{
  return s:menu.next()
endfunction
"}}}
function! s:MenuExecute() "{{{
  let action = s:menu.get_action()
  unlet! s:menu_base s:menu s:menu_err
  if type(action)!=s:TYPE_STR || action==''
    return "\<Esc>:call alti#_reenter_loop()\<CR>"
  end
  return "\<Esc>:call b:alti_cmplwin.do_action(". string(action). ") | call alti#_reenter_loop()\<CR>"
endfunction
"}}}
function! s:MenuExit() "{{{
  unlet! s:menu_base s:menu s:menu_err
  return "\<Esc>:call alti#_reenter_loop()\<CR>"
endfunction
"}}}
function! s:MenuRefine(char) "{{{
  if s:menu.is_empty
    return s:MenuNop()
  end
  call s:menu_base.refine_add(a:char)
  call s:menu_base.update_menu()
  return s:menu.begin()
endfunction
"}}}
function! s:MenuRefineBS() "{{{
  call s:menu_base.bs()
  call s:menu_base.update_menu()
  return s:menu.begin()
endfunction
"}}}
function! s:MenuRefineClear() "{{{
  call s:menu_base.clear()
  call s:menu_base.update_menu()
  return s:menu.begin()
endfunction
"}}}
function! s:MenuNop() "{{{
  return "\<C-n>\<C-p>\<C-r>=alti#menu#_capture()\<CR>"
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo

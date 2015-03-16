if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:TYPE_LIST = type([])
let s:TYPE_STR = type('')

"Misc:
function! s:_expand_keycodes(str) "{{{
  return substitute(a:str, '<\S\{-1,}>', '\=eval(''"\''. submatch(0). ''"'')', 'g')
endfunction
"}}}
function! s:_noexpand(str) "{{{
  return a:str
endfunction
"}}}
function! s:_cnvvimkeycodes(str) "{{{
  try
    let ret = has_key(s:, 'disable_keynotation') ? a:str : alti_l#lim#keynotation#decode(a:str)
    return ret
  catch /E117:/
    let s:disable_keynotation = 1
    return a:str
  endtry
endfunction
"}}}

let s:Inputs = {}
function! s:newInputs(keys, ...) "{{{
  let obj = copy(s:Inputs)
  let obj.is_transit = a:0 ? a:1 : 0
  let obj.neutral_keys = a:keys
  let obj.keys = copy(a:keys)
  let obj.crrinput = ''
  let obj.justmatch = ''
  return obj
endfunction
"}}}
function! s:Inputs.receive() "{{{
  let _ = getchar()
  let char = type(_)==s:TYPE_STR ? _ : nr2char(_)
  while getchar(1)
    let _ = getchar()
    let char .= type(_)==s:TYPE_STR ? _ : nr2char(_)
  endwhile
  let self.crrinput .= char
  call filter(self.keys, 'stridx(v:val, self.crrinput)==0')
  return char
endfunction
"}}}
function! s:Inputs.should_break() "{{{
  if self.keys==[]
    if self.justmatch!='' || self.is_transit
      return 1
    end
    call self._reset()
    return 0
  end
  let justmatchidx = index(self.keys, self.crrinput)
  let self.justmatch = justmatchidx==-1 ? self.justmatch : self.crrinput
  if justmatchidx!=-1 && len(self.keys)==1
    return 1
  end
endfunction
"}}}
function! s:Inputs.get_results() "{{{
  return [self.justmatch, substitute(self.crrinput, '^'.self.justmatch, '', '')]
endfunction
"}}}
function! s:Inputs._reset() "{{{
  let self.keys = copy(self.neutral_keys)
  let self.crrinput = ''
  let self.justmatch = ''
endfunction
"}}}


"=============================================================================
"Main:
function! alti_l#lim#ui#select(prompt, choices, ...) "{{{
  let behavior = a:0 ? a:1 : {}
  if a:choices==[]
    return []
  end
  echo a:prompt
  if !get(behavior, 'silent', 0)
    call s:_show_choices(a:choices, get(behavior, 'sort', 0))
  end
  let cancel_inputs = get(behavior, 'cancel_inputs', ["\<Esc>", "\<C-c>"])
  if cancel_inputs==[]
    call add(cancel_inputs, "\<C-c>")
  end
  let tmp = get(behavior, 'error_inputs', [])
  let error_inputs = type(tmp)==s:TYPE_LIST ? tmp : tmp ? cancel_inputs : []
  let dict = s:_get_choicesdict(a:choices, get(behavior, 'expand', 0))
  let inputs = s:newInputs(keys(dict))
  while 1
    let char = inputs.receive()
    if index(error_inputs, char)!=-1
      redraw!
      throw printf('select: inputed "%s"', s:_cnvvimkeycodes(char))
    elseif index(cancel_inputs, char)!=-1
      redraw!
      return []
    elseif inputs.should_break()
      break
    end
  endwhile
  redraw!
  let input = inputs.get_results()[0]
  return dict[input]
endfunctio
"}}}
function! s:_show_choices(choices, sort_choices) "{{{
  let mess = []
  for choice in a:choices
    if empty(get(choice, 0, '')) || get(choice, 1, '')==''
      continue
    end
    if type(choice[0])==s:TYPE_LIST
      let choices = copy(choice[0])
      if a:sort_choices
        call sort(choices)
      end
      let input = join(map(choices, 's:_cnvvimkeycodes(v:val)'), ', ')
    else
      let input = s:_cnvvimkeycodes(choice[0])
    end
    call add(mess, printf('%-6s: %s', input, choice[1]))
  endfor
  if a:sort_choices
    call sort(mess, 1)
  end
  for mes in mess
    echo mes
  endfor
  echon ' '
endfunction
"}}}
function! s:_get_choicesdict(choices, expand_keycodes) "{{{
  let dict = {}
  for cho in a:choices
    if type(cho[0])==s:TYPE_LIST
      for c in cho[0]
        let chr = a:expand_keycodes ? s:_expand_keycodes(c) : c
        if !(chr=='' || has_key(dict, chr))
          let dict[chr] = insert(cho[1:], c)
        end
      endfor
    else
      let chr = a:expand_keycodes ? s:_expand_keycodes(cho[0]) : cho[0]
      if !(chr=='' || has_key(dict, chr))
        let dict[chr] = insert(cho[1:], cho[0])
      end
    end
  endfor
  return dict
endfunction
"}}}

function! alti_l#lim#ui#keybind(binddefs, ...) "{{{
  let behavior = a:0 ? a:1 : {}
  let bindacts = s:_get_bindacts(a:binddefs, function(get(behavior, 'expand') ? 's:_expand_keycodes' : 's:_noexpand'))
  let inputs = s:newInputs(keys(bindacts), get(behavior, 'transit'))
  while 1
    let char = inputs.receive()
    if !has_key(bindacts, "\<C-c>") && char=="\<C-c>"
      return {}
    elseif inputs.should_break()
      break
    end
  endwhile
  let [justmatch, surplus] = inputs.get_results()
  return {'action': get(bindacts, justmatch, ''), 'surplus': surplus}
endfunction
"}}}
function! s:_get_bindacts(binddefs, expandfunc) "{{{
  let bindacts= {}
  for [act, binds] in items(a:binddefs)
    if type(binds)==s:TYPE_STR
      let bindacts[a:expandfunc(binds)] = act
      continue
    end
    for bind in binds
      let bindacts[a:expandfunc(bind)] = act
    endfor
  endfor
  return bindacts
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo

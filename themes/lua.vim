" Vim syntax file
" Language: Lua

if exists("b:current_syntax")
  finish
endif

" Basic settings
syn case match

" Comments
syn region luaComment start="--\[" end="\]" contains=luaString
syn match   luaComment "--.*"

" Strings
syn region luaString start=+"+ skip=+\\\\\|\\\"+ end=+"+ keepend
syn region luaString start=+'+ skip=+\\\\\|\\'+ end=+'+ keepend

" Keywords
syn keyword luaStatement and break do else elseif end for function if in local nil not or repeat return then until while
syn keyword luaConstant true false

" Numbers
syn match luaNumber "\<\d\+\(.\d\+\)\?\([eE][+-]\=\d\+\)\?\>"
syn match luaNumber "0x\x\+"

" Functions
syn match luaFunction "\<\h\w*\ze\s*("

" Highlight groups
hi def link luaComment Comment
hi def link luaString String
hi def link luaStatement Statement
hi def link luaConstant Constant
hi def link luaNumber Number
hi def link luaFunction Function

let b:current_syntax = "lua"

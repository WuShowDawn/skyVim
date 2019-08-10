" ============================================================================
" Description: An ack/ag/pt/rg powered code search and view tool.
" Author: Ye Ding <dygvirus@gmail.com>
" Licence: Vim licence
" Version: 2.1.2
" ============================================================================

" List of paragraphs, paragraph is main object which stores parsed query result
let s:resultset = []

" Paragraphs orgonized by files
let s:fileset = []

" List of matches
let s:matchlist = []

" Maximum line number
let s:max_lnum = 0

let s:current_file = ''
let s:buffer = []
let s:next_file = ''
let s:pre_ln = -1

"""""""""""""""""""""""""""""""""
" Getter
"""""""""""""""""""""""""""""""""
" ResultSet()
"
func! ctrlsf#db#ResultSet() abort
    return s:resultset
endf

" FileResultSetBy()
"
func! ctrlsf#db#FileResultSetBy(resultset) abort
    " List of result files, generated by resultset
    let fileset   = []

    let cur_file = ''
    for par in a:resultset
        if cur_file !=# par.filename
            let cur_file = par.filename
            call add(fileset, {
                \ "filename"   : cur_file,
                \ "paragraphs" : [],
                \ })
        endif
        call add(fileset[-1].paragraphs, par)
    endfo

    return fileset
endf

" FileResultSet()
"
func! ctrlsf#db#FileResultSet() abort
    return s:fileset
endf

" MatchList()
"
func! ctrlsf#db#MatchList() abort
    return s:matchlist
endf

" MatchListQF()
"
func! ctrlsf#db#MatchListQF() abort
    return ctrlsf#db#MatchList()
endf

" MaxLnum()
"
func! ctrlsf#db#MaxLnum()
    return s:max_lnum
endf

"""""""""""""""""""""""""""""""""
" Setter
"""""""""""""""""""""""""""""""""
func! ctrlsf#db#SetResultSet(resultset) abort
    call ctrlsf#db#Reset()
    for par in a:resultset
        call s:AddParagraph(par)
    endfor
endf

"""""""""""""""""""""""""""""""""
" Parser
"""""""""""""""""""""""""""""""""
" s:DefactorizeLine()
"
" Defactorize result line into [filename, line_number, content].
"
" Expected input is like 'autoload/ctrlsf.vim:182-endif', where '-' serves as
" delimiter.
"
" Note: A subtle difference exists between ack's result and ag's, delimiter
" between path and line number is always ':' in ag, but varies in ack
" depending on whether this line matches.
"
func! s:DefactorizeLine(line, fname_guess) abort
    " filename
    let filename = ''

    if a:fname_guess !=# ''
            \ && stridx(a:line, a:fname_guess) == 0
            \ && match(a:line, '^[-:]\d\+[-:]', strlen(a:fname_guess)) != -1
        let filename = a:fname_guess
    else
        let fname_end = 0
        while fname_end != -1
            let fname_end = match(a:line, '[-:]\d\+[-:]', fname_end + 1)
            let possible_fname = strpart(a:line, 0, fname_end)

            " check possible filename aginst actual file to verify
            if filereadable(possible_fname) && !isdirectory(possible_fname)
                let filename = possible_fname
                break
            endif
        endwh
    endif

    " line number
    let lnum = matchstr(a:line, '\d\+', strlen(filename))

    " content
    let content = strpart(a:line, strlen(filename) + strlen(lnum) + 2)

    call ctrlsf#log#Debug(
                \ "DefactorizeLine: [Factor]: [%s, %s, %s], [Orig]: %s",
                \ filename, lnum, content, a:line)

    return [filename, lnum, content]
endf

" s:AddParagraph()
"
func! s:AddParagraph(paragraph) abort
    " update fileset
    let f = get(s:fileset, -1, {})
    if f == {} || f.filename !=# a:paragraph.filename
        call add(s:fileset, {
            \ "filename"   : a:paragraph.filename,
            \ "paragraphs" : [],
            \ })
    endif
    call add(s:fileset[-1].paragraphs, a:paragraph)

    " update matchlist
    call extend(s:matchlist, a:paragraph.matches())

    " update max lnum
    let mlnum = a:paragraph.lnum() + a:paragraph.range() - 1
    if mlnum > s:max_lnum
        let s:max_lnum = mlnum
    endif

    " add to resultset
    call add(s:resultset, a:paragraph)
endf

" ParseBackendResult()
"
func! ctrlsf#db#ParseBackendResult(result) abort
    call ctrlsf#db#Reset()

    " in case of mixed text from win-style files and unix-style files, breaks
    " result into lines by both <CR><NL> and <NL>.
    let result_lines = split(a:result, '\v(\r\n)|\n')

    call ctrlsf#db#ParseBackendResultIncr(result_lines, 1)
endf

" ParseBackendResultIncr()
"
func! ctrlsf#db#ParseBackendResultIncr(lines, close) abort
    for line in a:lines
        call s:ParseOneLine(line)
    endfo

    if a:close
        call s:MakeParagraph()
    endif
endf

" s:ParseOneLine()
"
func! s:ParseOneLine(line) abort
    " don't rely on division line any longer. ignore it.
    if a:line =~ '^--$' || a:line =~ '^$'
        return
    endif

    let [fname, lnum, content] = s:DefactorizeLine(a:line, s:current_file)

    if fname !=# s:current_file
        let s:next_file = fname
        call s:MakeParagraph()
        call s:ParseOneLine(a:line)
    else
        if (s:pre_ln == -1) || (lnum == s:pre_ln + 1)
            let s:pre_ln = lnum
            call add(s:buffer, [fname, lnum, content])
        else
            call s:MakeParagraph()
            call s:ParseOneLine(a:line)
        endif
    endif
endf

" s:MakeParagraph()
"
func! s:MakeParagraph() abort
    if len(s:buffer) > 0
        call s:AddParagraph(ctrlsf#class#paragraph#New(s:buffer))
    endif

    let s:current_file = s:next_file
    let s:buffer = []
    let s:next_file = ''
    let s:pre_ln = -1
endf

"""""""""""""""""""""""""""""""""
" Misc
"""""""""""""""""""""""""""""""""
" Reset
"
func! ctrlsf#db#Reset() abort
    let s:resultset = []
    let s:fileset = []
    let s:matchlist = []
    let s:max_lnum = 0

    let s:current_file = ''
    let s:buffer = []
    let s:next_file = ''
    let s:pre_ln = -1
endf

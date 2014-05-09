" IndentConsistencyCop.vim: Is the buffer's indentation consistent and does it conform to tab settings?
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher.
"   - Requires IndentConsistencyCop.vim autoload script.
"
" Copyright: (C) 2006-2014 by Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.44.024	08-Jan-2014	BUG: The version 1.43 workaround for the Vim 7.4
"				new regexp engine was ineffective, because the
"				\%#=1 atom needs to be prepended to the entire
"				regular expression, but that's not possible with
"				the configuration value alone. (Also, the
"				workaround mistakenly specified auto-select (0)
"				instead of old engine (1).) Move the workaround
"				to s:GetBeginningWhitespace() instead.
"   1.43.024	14-Dec-2013	XXX: Switch default
"				g:indentconsistencycop_non_indent_pattern to old
"				regexp engine in Vim 7.4; the new NFA-based one
"				has a problem with the pattern; cp.
"				http://article.gmane.org/gmane.editors.vim.devel/43712
"   1.43.023	22-Nov-2013	Improve
"				g:indentconsistencycop_non_indent_pattern to
"				also handle empty comment lines with a sole ' *'
"				prefix. Thanks to Marcelo Montu for reporting
"				this.
"   1.21.022	31-Dec-2010	Moved functions from plugin to separate autoload
"				script.
"				Split off documentation into separate help file.
"	...
"	0.01	08-Oct-2006	file creation

" Avoid installing twice or when in compatible mode
if exists('g:loaded_indentconsistencycop') || (v:version < 700)
    finish
endif
let g:loaded_indentconsistencycop = 1


"- configuration --------------------------------------------------------------

if ! exists('g:indentconsistencycop_highlighting')
    let g:indentconsistencycop_highlighting = 'sglmf:3'
endif

if ! exists('g:indentconsistencycop_non_indent_pattern')
    let g:indentconsistencycop_non_indent_pattern = ' \*\%([*/ \t]\|$\)'
endif

if g:indentconsistencycop_highlighting =~# 'm'
    highlight def link IndentConsistencyCop Error
endif


"- commands ------------------------------------------------------------------

" Ensure indent consistency within the range / buffer, and - if achieved -, also
" check consistency with buffer indent settings.
command! -bar -range=% IndentConsistencyCop call IndentConsistencyCop#IndentConsistencyCop(<line1>, <line2>, 1)

" Remove the highlighting of inconsistent lines and restore the normal view for
" this buffer.
command! -bar IndentConsistencyCopOff call IndentConsistencyCop#ClearHighlighting()

" Only check indent consistency within range / buffer. Don't check the
" consistency with buffer indent settings. Prefer this command to
" IndentConsistencyCop if you don't want your buffer indent settings
" changed, or if you only want to check a limited range of the buffer that you
" know does not conform to the buffer indent settings.
command! -bar -range=% IndentRangeConsistencyCop call IndentConsistencyCop#IndentConsistencyCop(<line1>, <line2>, 0)

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :

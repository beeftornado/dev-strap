" IndentConsistencyCop.vim: Is the buffer's indentation consistent and does it conform to tab settings?
"
" DEPENDENCIES:
"
" Copyright: (C) 2006-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS  {{{1
"   1.44.012	08-Jan-2014	Move workaround of forcing old regexp engine to
"				s:GetBeginningWhitespace().
"				ENH: Close all consistent parts of the buffer
"				when highlighting the inconsistencies via
"				folding, and restore the original 'foldlevel'
"				setting (and therefore the global fold state
"				set by zM / zR) on :IndentConsistencyCopOff.
"				Thanks to Marcelo Montu for the idea.
"				ENH: Enable folding to highlight the
"				inconsistencies when it was previously :set
"				nofoldenable'd.
"				Minor: Made IndentConsistencyCopFoldExpr() an
"				autoload function.
"   1.43.011	14-Jun-2013	Minor: Make matchstr() robust against
"				'ignorecase'.
"   1.42.027	10-Dec-2012	When a perfect or authoritative rating didn't
"				pass the majority rule (inside
"				s:NormalizeRatings()), try to turn around the
"				verdict by checking consistency with buffer
"				settings
"				(s:IsBufferConsistentWithBufferSettings()), as
"				is done for small indents only. For example,
"				this avoids a wrong verdict of inconsistent spc8
"				when there are more spc8 than spc4. Cp.
"				test068-test070. Thanks to Marcelo Montu for
"				reporting this issue.
"   1.41.026	07-Dec-2012	Change the behavior of
"				:IndentRangeConsistencyCop to consider the
"				buffer settings to turn around the verdict of
"				"inconsistent indent" (but still not report
"				inconsistent buffer settings alone). Otherwise,
"				together with the IndentConsistencyCopAutoCmds
"				triggers, it can happen that on opening (i.e.
"				:IndentConsistencyCop), the file is judged okay
"				(considering the buffer settings), but on
"				writing the buffer (:IndentRangeConsistencyCop),
"				a potential inconsistency due to too small
"				indent is reported. Thanks to Marcelo Montu for
"				reporting this issue.
"   1.40.025	10-Oct-2012	The cop can often do a solid assessment when the
"				maximum indent is 8. Only when there are no
"				smaller indents, a higher indent is needed to
"				unequivocally recognize soft tabstops. Start
"				storing the minimum indent and extend the logic
"				for solid assessment.
"				ENH: Better handle integer overflow when rating
"				and normalizing: Limit to MAX_INT instead of
"				carrying on with negative ratings, or just use
"				Float values when Vim has support for it.
"				When we have only a few, widely indented lines,
"				there may be more than one way to interpret them
"				as a perfect setting. Choose one over the other
"				via some simple heuristics instead of the
"				previous assertion error.
"				FIX: Fall back to the old :2match when
"				matchadd() is not available.
"   1.31.024	03-Apr-2012	Use matchadd() instead of :2match to avoid
"				clashes with user highlightings (or other
"				plugins like html_matchtag.vim).
"				ENH: Clear highlighting when another buffer is
"				loaded into the window to avoid that the
"				highlightings persist in a now wrong context.
"   1.30.023	22-Nov-2011	ENH: Avoid the spurious "potential inconsistency
"				with buffer settings" warning when there are
"				only small consistent indents detected as
"				space-indents, but the equivalent
"				softtabstop-indent is consistent with the buffer
"				settings. As many files only have small indents,
"				this warning popped up regularly and has been
"				the most annoying for me, also because to
"				rectify it, one has to answer three questions
"				("[W]rong", "[s]ofttabstop", [N]).
"   1.21.022	31-Dec-2010	Moved functions from plugin to separate autoload
"				script.
"   1.21.021	30-Dec-2010	Added b:indentconsistencycop_result.isIgnore to
"				allow IndentConsistencyCopAutoCmds integration
"				to suspend further invocations of the cop in the
"				buffer.
"				BUG: :IndentRangeConsistencyCop didn't report
"				inconsistencies at all because of a bad
"				conditional statement introduced in 1.20.014.
"   1.20.020	08-Jun-2009	Factored out confirm() calls into s:Query, and
"				using textual comparison with the passed choices
"				instead of index-based comparison.
"				"Headless mode": Added
"				g:indentconsistencycop_choices bypass around
"				user queries for testing purposes.
"				Now using IndentConsistencyCop highlight group
"				instead of hard-coded 'Error' group so that the
"				highlighting can be customized. By default, this
"				links to the 'Error' group. This also avoids
"				script errors in case the 'Error' group does not
"				exist.
"   1.20.019	27-Jan-2009	Made assertions more consistent.
"   1.20.018	22-Jan-2009	Moved (and improved) documentation of
"				configuration settings from source section to
"				header.
"   1.20.017	22-Jul-2008	BF: Undefined variable l:isEntireBuffer in
"				IndentBufferConsistencyCop().
"   1.20.016	19-Jul-2008	BF: If different settings have been chosen by
"				the user ("Wrong, choose correct setting"), this
"				may have resulted in a consistency with buffer
"				settings, too. Added call to
"				s:ReportConsistencyWithBufferSettingsResult().
"   1.20.015	18-Jul-2008	ENH: Completed b:indentconsistencycop_result
"				dictionary with indent and buffer settings
"				identifiers. For that, introduced
"				s:perfectIndentSetting and
"				s:authoritativeIndentSetting. Refactored Rating
"				generation and normalization so that a perfect
"				rating is not represented by a negative number;
"				this simplified the logic.
"				RF: In s:...BufferIndentConsistencyCop(), only
"				passing either a:startLineNum/a:endLineNum or
"				a:isEntireBuffer, not both.
"				RF: Cleaning up dictionaries with script scope
"				by assigning empty dictionary instead of
"				filter()ing out all elements.
"				Consistency is now determined by checking
"				s:perfectIndentSetting, not searching for 100%
"				rating in s:ratings, which should be
"				unsusceptible to rounding errors in s:ratings.
"   1.20.014	08-Jul-2008	ENH: Added b:indentconsistencycop_result
"				buffer-scoped dictionary containing the results
"				of the check, which can be used by other
"				integrations.
"				Do not evaluate indents into occurrences if no
"				indents found.
"   1.20.013	07-Jul-2008	Also check consistency of buffer settings if the
"				buffer/range does not contain indented text.
"				Inconsistent indent settings can then be
"				corrected with a queried setting.
"				Testcase: IndentBufferConsistencyCop56.txt
"				BF: Clear previous highlighting if buffer/range
"				now does not contain indented text.
"   1.10.012	13-Jun-2008	Added -bar to all commands that do not take any
"				arguments, so that these can be chained together.
"   1.10.011	28-Feb-2008	Improved the algorithm so that 'softtabstop' is
"				recognized even when a file only has small
"				indents with either (up to 7) spaces or tabs,
"				but no tab + space combination. Beforehand, the
"				s:ApplyPrecedences() was applied too early; the
"				s:EvaluateIncompatibleIndentSettings() could not
"				take doubtful indent settings into account. In
"				addition, s:ApplyPrecedences() always preferred
"				'spc' when neither 'spc' nor 'sts' indents
"				existed. Now, it chooses 'sts' when 'tab' does
"				exist, because tabs indicate the presence of
"				softtabstops. Precedences are applied after the
"				incompatible indent settings have been
"				determined, and must now be applied to both
"				s:occurrences and s:incompatibles. For this
"				purpose, s:ApplyPrecedences() has been split
"				into s:ApplyPrecedencesToOccurrences() and
"				s:ApplyPrecedencesToIncompatibles(). The latter
"				thing is a little bit complex, because doubtful
"				indent settings can be converted to one or two
"				preferred settings.
"   1.00.010	07-Nov-2007	BF: In an inconsistent and large buffer/range
"				that has only one or a few small inconsistencies
"				and one dominant (i.e. 99%) setting, the text
"				"Some minor / inconclusive potential settings
"				have been omitted." is not printed. In
"				s:RatingsToUserString(), enhanced the condition
"				for this user message: When there's only one
"				rating, others certainly have been dropped.
"				Testcase: IndentBufferConsistencyCop54.txt
"				ENH: In s:CheckConsistencyWithBufferSettings(),
"				print "noexpandtab/expandtab" instead of "
"				expandtab to 0/1", as the user would :setlocal
"				the setting.
"   1.00.009	03-Jun-2007	ENH: Improved detection accuracy for soft
"				tabstops when the maximum indent is too small
"				for a solid assessment. When the maximum indent
"				of the buffer is not enough to be sure of the
"				indent settings (i.e. differentiating between
"				soft tabstops and spaces), an inconsistent
"				indent was reported, even though it is much more
"				likely that the indent is consistent with "soft
"				tabstop n", but that wasn't recognized because
"				of the small indents used in the file. If
"				allowed, the cop now examines the buffer
"				settings to possibly turn around the verdict of
"				"inconsistent indent".
"   1.00.008	02-Apr-2007	Allowing user to override wrongly found
"				consistent setting (e.g. 'sts1' instead of
"				'tab') by choosing 'Wrong, choose correct
"				setting...' in the IndentBufferConsistencyCop.
"   1.00.007	02-Nov-2006	BF: Suppressing 'Not buffer setting' option if
"				the buffer setting is inconsistent ('badset'),
"				which threw an exception when selected.
"   1.00.006	01-Nov-2006	Corrected unreasonable assumption of a
"				consistent small indent setting (of 1 or 2
"				spaces) when actually only some wrong spaces
"				spoil the consistency. Now, a perfect consistent
"				rating is only accepted if its absolute rating
"				number is also the maximum rating.
"				BF: Avoiding runtime error in
"				IndentBufferInconsistencyCop() if s:ratings is
"				empty.
"   1.00.005	30-Oct-2006	Improved g:indentconsistencycop_non_indent_pattern
"				to also allow ' *\t' and ' *****' comments.
"   1.00.004	20-Oct-2006	Improved undo of highlighting;
"				added :IndentConsistencyCopOff.
"				Added check IsEnoughIndentForSolidAssessment();
"				user messages now include 'potentially' if the
"				indent is not sufficient.
"				Print out informational message for large ranges
"				/ buffers.
"				Added user messages when ignoring
"				inconsistencies.
"				BF: s:FoldExpr() is now a global function
"				IndentConsistencyCopFoldExpr() to fix problems
"				with set foldexpr=...
"				BF: SetHighlighting() doesn't save buffer
"				settings it has set itself in a previous run any
"				more.
"	0.03	19-Oct-2006	Added highlighting functionality.
"				Now coping with special comments indents via
"				g:indentconsistencycop_non_indent_pattern.
"				Implemented g:indentconsistencycop_highlighting
"				options 'shlm'.
"				BF: All 'sts n' were treated as compatible to
"				'tab', whereas the multiplicity of the tabstop
"				had to be considered. Added storing of tabstop
"				indents in s:tabstops and corresponding
"				evaluation in
"				GetIncompatiblesForIndentSetting().
"				Implemented highlighting via folding.
"				Correctly cleaning up highlighting.
"	0.02	11-Oct-2006	Completed consistency check for complete buffer.
"				Added check for range of the current buffer.
"				Added user choice to automatically change buffer settings.
"				Now correctly handling 'smarttab' and the
"				'expandtab' ambiguity.
"	0.01	08-Oct-2006	file creation

"- list and dictionary utility functions ---------------------------------{{{1
function! s:IncreaseKeyedBy( dict, key, num ) " {{{2
"****D echo '**** ' . a:key
    if has_key( a:dict, a:key )
	let a:dict[ a:key ] += a:num
    else
	let a:dict[ a:key ] = a:num
    endif
endfunction

function! s:IncreaseKeyed( dict, key ) " {{{2
    call s:IncreaseKeyedBy( a:dict, a:key, 1 )
endfunction

function! s:GetKeyedValue( dict, key ) " {{{2
    if has_key( a:dict, a:key )
	return a:dict[a:key]
    else
	return 0
endfunction

function! s:RemoveKey( dict, key ) " {{{2
    if has_key( a:dict, a:key )
	unlet a:dict[a:key]
    endif
endfunction

function! s:RemoveFromList( list, value ) " {{{2
    return filter( a:list, 'v:val != "' . a:value . '"' )
endfunction

function! s:UniqueReplaceElementWithListContents( list, searchElement, substitutionList ) " {{{2
"*******************************************************************************
"* PURPOSE:
"   Each a:searchElement in a:list is replaced with the elements of
"   a:substitutionList. Any duplicates which are then in a:list are removed (and
"   the order of elements gets shuffled), so only unique elements are finally
"   contained in a:list.
"* ASSUMPTIONS / PRECONDITIONS:
"   none
"* EFFECTS / POSTCONDITIONS:
"   none
"* INPUTS:
"   a:list		source list
"   a:searchElement 	element of a:list to be replaced
"   a:substitutionList	list of elements that replace a:searchElement
"* RETURN VALUES:
"   Modifies a:list in-place, and also returns a:list.
"*******************************************************************************
    let l:hash = {}
    for l:element in a:list
	if l:element == a:searchElement
	    for l:substitutionElement in a:substitutionList
		let l:hash[l:substitutionElement] = 1
	    endfor
	else
	    let l:hash[l:element] = 1
	endif
    endfor
    return keys( l:hash )
endfunction
" }}}2

"- utility functions -----------------------------------------------------{{{1
function! s:IsDivsorOf( newNumber, numbers ) " {{{2
    for l:number in a:numbers
	if l:number % a:newNumber == 0
	    return 1
	endif
    endfor
    return 0
endfunction

function! s:GetMultiplierFromIndentSetting( indentSetting ) " {{{2
    if a:indentSetting == 'tab'
	return 8
    else
	return str2nr( strpart( a:indentSetting, 3 ) )
    endif
endfunction

function! s:GetSettingFromIndentSetting( indentSetting ) " {{{2
    return strpart( a:indentSetting, 0, 3 )
endfunction

function! s:IsBadIndentSetting( indentSetting ) " {{{2
    return s:GetSettingFromIndentSetting( a:indentSetting ) == 'bad'
endfunction

" }}}1

"- Processing of lines in buffer -----------------------------------------{{{1
function! s:CountTabs( tabString ) " {{{2
    " A tab is a tab, and can thus be counted directly.
    " However, the number of tabs, or the equivalent indent, must be captured to
    " be able to resolve possible compatibilities with softtabstops.
    call s:IncreaseKeyed( s:occurrences, 'tab' )
    call s:IncreaseKeyed( s:tabstops, len( substitute( a:tabString, '\t', '        ', 'g' ) ) )
endfunction

function! s:CountDoubtful( spaceString ) " {{{2
    call s:IncreaseKeyed( s:doubtful, len( a:spaceString ) )
endfunction

function! s:CountSpaces( spaceString ) " {{{2
    call s:IncreaseKeyed( s:spaces, len( a:spaceString ) )
endfunction

function! s:CountSofttabstops( stsString ) " {{{2
    call s:IncreaseKeyed( s:softtabstops, len( substitute( a:stsString, '\t', '        ', 'g' ) ) )
endfunction

function! s:CountBadSofttabstop( string ) " {{{2
    call s:IncreaseKeyed( s:occurrences, 'badsts')
endfunction

function! s:CountBadMixOfSpacesAndTabs( string ) " {{{2
    call s:IncreaseKeyed( s:occurrences, 'badmix')
endfunction

if exists('+regexpengine') " {{{2
    " XXX: The new NFA-based regexp engine has a problem with the default
    " pattern; cp. http://article.gmane.org/gmane.editors.vim.devel/43712
    let s:beginningWhitespacePrefix = '\%#=1'
else
    let s:beginningWhitespacePrefix = ''
endif
function! s:GetBeginningWhitespace( lineNum ) " {{{2
    return matchstr(getline(a:lineNum), s:beginningWhitespacePrefix . '^\s\{-}\ze\($\|\S\|' . g:indentconsistencycop_non_indent_pattern . '\)')
endfunction

function! s:UpdateIndentMinMax( beginningWhitespace ) " {{{2
    let l:currentIndent = len( substitute( a:beginningWhitespace, '\t', '        ', 'g' ) )
    if l:currentIndent > s:indentMax
	let s:indentMax = l:currentIndent
    elseif l:currentIndent > 0 && l:currentIndent < s:indentMin
	let s:indentMin = l:currentIndent
    endif
endfunction

function! s:IsEnoughIndentForSolidAssessment() " {{{2
    " When we also have smaller ones, indents of at least the default tabstop
    " value of 8 allow us to unequivocally recognize soft tabstops; in that
    " case, the indent of 8 must be done via a Tab. When there are only indents
    " of 8 (no smaller ones), we need indents *greater than* the default tabstop
    " value.
    return (s:indentMin == s:indentMax ? (s:indentMax > 8) : (s:indentMax >= 8))
endfunction

function! s:InspectLine(lineNum) " {{{2
"*******************************************************************************
"* PURPOSE:
"   Count the whitespace at the beginning of the passed line (until the first
"   non-whitespace character) and increase one of the counters. There are two
"   types of counters:
"   1. The master counter s:occurrences can be directly filled with elements
"      like all-Tabs or bad Tab-Space combinations, where the number of Tabs /
"      Spaces doesn't matter.
"   2. The intermediate counters s:spaces, s:softtabstops and s:doubtful also
"      capture the number of the characters. These counters are later
"      consolidated into s:occurrences.
"   3. The intermediate counter s:tabstops is only necessary to resolve possible
"      compatibilities with other indent settings.
"
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"   updates s:occurrences, s:tabstops, s:spaces, s:softtabstops, s:doubtful
"   updates s:indentMin, s:indentMax
"* INPUTS:
"   lineNum: number of line in the current buffer
"* RETURN VALUES:
"   none
"*******************************************************************************
"****D echo getline(a:lineNum)
    let l:beginningWhitespace = s:GetBeginningWhitespace( a:lineNum )
    if l:beginningWhitespace == ''
	return
    elseif match( l:beginningWhitespace, '^\t\+$' ) != -1
	call s:CountTabs( l:beginningWhitespace )
	" Tabs-only can also be interpreted as a softtabstop-line without
	" balancing spaces.
	" If we discarded this, we would neglect to count an indent of 10 tabs
	" (= 80 characters) as 16 * sts5 (the 10 * sts8 will be dropped by the
	" preference of tab over sts8, though).
	call s:CountSofttabstops( l:beginningWhitespace )
    elseif match( l:beginningWhitespace, '^ \{1,7}$' ) != -1
	" Spaces-only (up to 7) can also be interpreted as a softtabstop-line
	" without tabs.
	call s:CountDoubtful( l:beginningWhitespace )
    elseif match( l:beginningWhitespace, '^ \{8,}$' ) != -1
	call s:CountSpaces( l:beginningWhitespace )
    elseif match( l:beginningWhitespace, '^\t\+ \{1,7}$' ) != -1
	call s:CountSofttabstops( l:beginningWhitespace )
    elseif match( l:beginningWhitespace, '^\t\+ \{8,}$' ) != -1
	call s:CountBadSofttabstop( l:beginningWhitespace )
    else
	call s:CountBadMixOfSpacesAndTabs( l:beginningWhitespace )
    endif

    call s:UpdateIndentMinMax( l:beginningWhitespace )
endfunction
" }}}2

function! s:EvaluateIndentsIntoOccurrences( dict, type ) " {{{1
"*******************************************************************************
"* PURPOSE:
"   An actual indent x translates into occurrences for shiftwidths n,
"   where n is a divisor of x. Divisors that are divisors of other divisors are
"   skipped.
"   e.g. indent of 18 -> shiftwidth of 6 (1,2,3 skipped)
"	 indent of 21 -> shiftwidths of 7,3 (1 skipped)
"	 indent of 17 -> shiftwidth of 1
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   dict: the dictionary of actual indents for a particular type
"   type: either 'spc' or 'sts'
"* RETURN VALUES:
"   Modifies the passed dict reference.
"*******************************************************************************
    for l:indent in keys( a:dict )
	let l:divisors = []
	let l:indentCnt = 8
	while l:indentCnt > 0
	    if l:indent % l:indentCnt == 0
		if ! s:IsDivsorOf( l:indentCnt, l:divisors )
		    "****D echo "**** " . l:indent . " adding " . l:indentCnt
		    call s:IncreaseKeyedBy( s:occurrences, a:type . l:indentCnt, a:dict[ l:indent ] )
		"****D else
		    "****D echo "**** " . l:indent . " discarding " . l:indentCnt . " because already done " . string(l:divisors)
		endif
		let l:divisors += [ l:indentCnt ]
	    endif
	    let l:indentCnt -= 1
	endwhile
    endfor
endfunction

function! s:RemoveSts8() " {{{1
"*******************************************************************************
"* PURPOSE:
"   The occurrence 'sts8' has only been collected because of the parallelism
"   with 'spc8'. Effectively, 'sts8' is the same as 'tab', and is removed.
"* ASSUMPTIONS / PRECONDITIONS:
"   s:occurrences contains raw indent occurrences.
"* EFFECTS / POSTCONDITIONS:
"   Modifies s:occurrences.
"* INPUTS:
"   none
"* RETURN VALUES:
"   none
"*******************************************************************************
    if s:GetKeyedValue( s:occurrences, 'sts8' ) != s:GetKeyedValue( s:occurrences, 'tab' )
	throw 'ASSERT: sts8 == tab'
    endif
    call s:RemoveKey( s:occurrences, 'sts8' )
endfunction

function! s:GetPrecedence(indentSetting) " {{{1
"*******************************************************************************
"* PURPOSE:
"   Converts doubtful indent settings to actual indent settings; the other
"   actual occurrences influence which indent setting(s) are chosen.
"
"   Space indents of up to 7 spaces can be either softtabstop or space-indent,
"   and have been collected in the 'dbt n' keys so far.
"   If there is only either 'sts n' or 'spc n', the 'dbt n' value is converted to
"   that key.
"   If both exist, it is converted to both 'sts n' and 'spc n'.
"   If both are zero / non-existing, the 'dbt n' value is converted to 'sts n'
"   if tabs are present, else to 'spc n'. (Without tabs as an indication of
"   softtabstop, spaces take precedence over softtabstops.)
"* ASSUMPTIONS / PRECONDITIONS:
"   s:occurrences contains consolidated indent occurrences, and has not yet had
"   the precedences applied (via s:ApplyPrecedencesToOccurrences()).
"* EFFECTS / POSTCONDITIONS:
"   none
"* INPUTS:
"   a:indentSetting indent setting to be converted.
"* RETURN VALUES:
"   (Empty list if the passed doubtful indent setting doesn't occur.)
"   One-element list of the original indent setting if it is not doubtful
"   (pass-through to returned list).
"   For doubtful indent settings, a list of indent settings; only 'spc' and
"   'sts' are contained, no 'dbt' is returned.
"*******************************************************************************
    if s:GetSettingFromIndentSetting( a:indentSetting ) != 'dbt'
	return [a:indentSetting]    " Pass-through.
    endif
    let l:multiplier = s:GetMultiplierFromIndentSetting( a:indentSetting )

    if s:GetKeyedValue( s:occurrences, a:indentSetting ) <= 0
	return []   " Bad query.
    endif

    let l:spcKey = 'spc' . l:multiplier
    let l:stsKey = 'sts' . l:multiplier
    let l:spc = s:GetKeyedValue( s:occurrences, l:spcKey )
    let l:sts = s:GetKeyedValue( s:occurrences, l:stsKey )
    let l:settings = []
    if l:spc == 0 && l:sts == 0
	if s:GetKeyedValue( s:occurrences, 'tab' ) > 0
	    let l:settings =  [l:stsKey]
	else
	    let l:settings =  [l:spcKey]
	endif
    else
	if l:spc > 0
	    let l:settings = add( l:settings, l:spcKey )
	endif
	if l:sts > 0
	    let l:settings = add( l:settings, l:stsKey )
	endif
    endif
    return l:settings
endfunction

function! s:ApplyPrecedences() " {{{1
"*******************************************************************************
"* PURPOSE:
"   Replaces doubtful indent settings in the global occurrences and list of
"   incompatible indent settings with the preferred actual indent setting(s).
"* ASSUMPTIONS / PRECONDITIONS:
"   s:occurrences contains consolidated indent occurrences, and has not yet had
"   the precedences applied (via s:ApplyPrecedencesToOccurrences()).
"* EFFECTS / POSTCONDITIONS:
"   Modifies s:occurrences; you cannot call s:GetPrecedence() any more!
"   Modifies s:incompatibles.
"* INPUTS:
"   none
"* RETURN VALUES:
"   none
"*******************************************************************************
    let l:indentCnt = 8
    while l:indentCnt > 0
	let l:dbtKey = 'dbt' . l:indentCnt
	let l:settings = s:GetPrecedence( l:dbtKey )
	call s:ApplyPrecedencesToOccurrences( l:dbtKey, l:settings )
	call s:ApplyPrecedencesToIncompatibles( l:dbtKey, l:settings )

	let l:indentCnt -= 1
    endwhile
endfunction

function! s:ApplyPrecedencesToOccurrences( dbtKey, preferredSettings ) " {{{1
"*******************************************************************************
"* PURPOSE:
"   Replaces a doubtful indent setting and moves the indent setting count with
"   them.
"* ASSUMPTIONS / PRECONDITIONS:
"   s:occurrences contains consolidated indent occurrences, and has not yet had
"   the precedences applied (via s:ApplyPrecedencesToOccurrences()).
"* EFFECTS / POSTCONDITIONS:
"   In s:occurrences, moves doubtful indent settings counts to the preferred
"   indent setting(s), and removes the doubtful indent setting.
"* INPUTS:
"   a:dbtKey    doubtful indent setting to be replaced
"   a:preferredSettings	list of preferred settings to which the count will be
"   moved
"* RETURN VALUES:
"   none
"*******************************************************************************
    let l:dbt = s:GetKeyedValue( s:occurrences, a:dbtKey )
    for l:setting in a:preferredSettings
	call s:IncreaseKeyedBy( s:occurrences, l:setting, l:dbt )
	call s:RemoveKey( s:occurrences, a:dbtKey )
    endfor
endfunction

function! s:ApplyPrecedencesToIncompatibles( dbtKey, preferredSettings ) " {{{1
"*******************************************************************************
"* PURPOSE:
"   Replaces a doubtful indent setting in the list of incompatibles with the
"   preferred indent setting(s).
"* ASSUMPTIONS / PRECONDITIONS:
"   s:incompatibles contains map of indent settings to their respective
"   incompatible settings. Key: indent setting; value: list of indent settings.
"* EFFECTS / POSTCONDITIONS:
"   Modifies values of s:incompatibles.
"* INPUTS:
"   a:dbtKey    doubtful indent setting to be replaced
"   a:preferredSettings	list of preferred settings to which the count will be
"   moved
"* RETURN VALUES:
"   none
"*******************************************************************************
    if empty( a:preferredSettings )
	return
    endif

    " Map all values to the preferred settings; remove any duplicates.
    for l:key in keys( s:incompatibles )
	let s:incompatibles[l:key] = s:UniqueReplaceElementWithListContents( s:incompatibles[l:key], a:dbtKey, a:preferredSettings )
    endfor
endfunction

"- Check for compatible indent settings ----------------------------------{{{1
function! s:IsIndentProduceableWithIndentSetting( indent, indentSetting ) " {{{2
    let l:indentMultiplier = s:GetMultiplierFromIndentSetting( a:indentSetting )
    if l:indentMultiplier == 0
	return 0 " This is for the 'badsts' and 'badmix' indent settings.
    else
	return (a:indent % l:indentMultiplier == 0)
    endif
endfunction

function! s:InspectForCompatibles( incompatibles, indents, baseIndentSetting, testSetting ) " {{{2
"*******************************************************************************
"* PURPOSE:
"   Uses the passed list of indents to find indent settings in a:testSetting
"   that are compatible with a:baseIndentSetting.
"   Candidates are: tabs may count as softtabstops, short indents (captured in
"   s:doubtful) may be both softtabstops or spaces. Spaces and softtabstops may
"   have different multipliers (e.g. sts5 and sts3) that may be compatible (e.g.
"   for indents 15, 30, 45).
"* ASSUMPTIONS / PRECONDITIONS:
"   none
"* EFFECTS / POSTCONDITIONS:
"   Modifies the passed a:incompatibles.
"* INPUTS:
"   a:incompatibles: reference to the pre-initialized list of (possibly)
"	incompatibles. Will contain only *real* incompatibles after the function
"	run.
"   a:indents:	list of actual indents that have occurred in the buffer.
"	The list should exclude indents that are not caused by
"	a:baseIndentSetting, so that no false positives are found.
"   a:baseIndentSetting: indent setting (e.g. 'sts6') on which the search for
"	compatibles is based on
"   a:testSetting: setting (e.g. 'sts') which filters the indent settings to be
"	searched for compatibles.
"* RETURN VALUES:
"   none
"* EXAMPLES:
"   s:InspectForCompatibles( l:incompatibles, [ 6, 12, 48, 60 ], 'sts6', 'sts' )
"	searches for compatibles to 'sts6' that match 'sts', using the passed
"	indent list. It'll return [ 'sts1', 'sts2', 'sts3' ].
"*******************************************************************************
    " Seed possible incompatibles with passed set; filter is testSetting.
    let l:isIncompatibles = {}	" Key: indentSetting; value: boolean (0/1).
    for l:incompatible in a:incompatibles
	if s:GetSettingFromIndentSetting( l:incompatible ) == a:testSetting
	    let l:isIncompatibles[ l:incompatible ] = 0
	endif
    endfor

    for l:isIncompatible in keys( l:isIncompatibles )
	for l:indent in a:indents
	    " Find indents all that match l:isIncompatible and test whether is
	    " also matches with a:baseIndentSetting
	    if s:IsIndentProduceableWithIndentSetting( l:indent, l:isIncompatible )
		if ! s:IsIndentProduceableWithIndentSetting( l:indent, a:baseIndentSetting )
		    " Indent isn't compatible, mark as incompatible.
		    let l:isIncompatibles[ l:isIncompatible ] = 1
		    " We're through with this possible incompatible.
		    break
		endif
	    endif
	endfor
    endfor

    " Remove the incompatibles that have been found compatible from
    " a:incompatibles.
    for l:isIncompatible in keys( l:isIncompatibles )
	if ! l:isIncompatibles[ l:isIncompatible ]
	    call s:RemoveFromList( a:incompatibles, l:isIncompatible )
"****D echo '**** ' . l:isIncompatible . ' is actually compatible with ' . a:baseIndentSetting
	endif
    endfor
endfunction

function! s:GetIncompatiblesForIndentSetting( indentSetting ) " {{{2
"*******************************************************************************
"* PURPOSE:
"   This function encodes the straightforward (i.e. general, settings-wide)
"   compatibility rules for the indent settings. Compatibilities that require
"   inspection of the actual indents in the buffer are delegated to
"   s:InspectForCompatibles().
"* ASSUMPTIONS / PRECONDITIONS:
"   s:occurrences dictionary; key: indent setting; value: number of
"	lines that have that indent setting
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:indentSetting (preferred) indent setting for which the incompatible
"	settings are calculated.
"* RETURN VALUES:
"    list of indent settings.
"*******************************************************************************
    " Start by assuming all indent settings are incompatible.
    let l:incompatibles = keys( s:occurrences )
    " The indent setting is compatible with itself.
    call s:RemoveFromList( l:incompatibles, a:indentSetting )

    let l:setting = s:GetSettingFromIndentSetting( a:indentSetting )
    if l:setting == 'tab'
	" 'sts' could be compatible with 'tab'.
	" softtabstops must be inspected; doubtful contains indents that are too small (<8) for 'tab'.
	call s:InspectForCompatibles( l:incompatibles, keys( s:softtabstops ), a:indentSetting, 'sts' )
    elseif l:setting == 'sts'
	" 'tab' could be compatible with 'sts' if the multipliers are right; tabstops must be inspected.
	call s:InspectForCompatibles( l:incompatibles, keys( s:tabstops ), a:indentSetting, 'tab' )
	" 'spc' is incompatible
	" 'dbt' could be compatible with 'sts' if the multipliers are right; doubtful must be inspected.
	call s:InspectForCompatibles( l:incompatibles, keys( s:doubtful ), a:indentSetting, 'dbt' )
	" Other 'sts' multipliers could be compatible; softtabstops and doubtful must be inspected.
	call s:InspectForCompatibles( l:incompatibles, keys( s:softtabstops ) + keys( s:doubtful ), a:indentSetting, 'sts' )
    elseif l:setting == 'spc'
	" 'tab' is incompatible.
	" 'sts' is incompatible.
	" 'dbt' could be compatible with 'spc' if the multipliers are right; doubtful must be inspected.
	call s:InspectForCompatibles( l:incompatibles, keys( s:doubtful ), a:indentSetting, 'dbt' )
	" Other 'spc' multipliers could be compatible; spaces and doubtful must be inspected.
	call s:InspectForCompatibles( l:incompatibles, keys( s:spaces ) + keys( s:doubtful ), a:indentSetting, 'spc' )
    elseif l:setting == 'bad'
	" for bad, all are incompatible.
    else
	throw 'Unknown indent setting: ' . l:setting
    endif

    return l:incompatibles
endfunction

function! s:EvaluateIncompatibleIndentSettings() " {{{2
"*******************************************************************************
"* PURPOSE:
"   Each found indent setting (in s:occurrences) may be compatible with another
"   (e.g. 'sts4' could be unified with 'sts6', if the actual indents found in
"   s:softtabstops and s:doubtful are 12 and 24 (but not 6, 18)). To do this
"   evaluation, the actual indents in s:spaces, s:softtabstops and s:doubtful
"   must be inspected.
"   The list of incompatible indent settings (returned values) contains doubtful
"   settings (which still need to be converted), because for the elimination of
"   incompatibles, different indent collections must be inspected for doubtful
"   vs. 'spc' / 'sts' settings. To build up the correct initial list of
"   incompatibles, s:occurrences must contain the raw settings, i.e. including
"   doubtful ones.
"   In contrast, the key indent setting is already a preferred setting; it
"   cannot be converted later on because for the determination of incompatible
"   settings, the actual setting must be known.
"   Example: Occurrences of 'tab', 'dbt2', 'spc8'
"	'tab': ['dbt2', 'spc8'], 'dbt2': [], 'spc8': ['tab', 'dbt2']
"   would lead to wrong result 'consistent sts2' ('sts' is preferred because
"   'tab' exists), even though 'sts2' is inconsistent with 'spc8'.
"   Correct evaluation is:
"	'tab': ['dbt2', 'spc8'], 'sts2': ['spc8'], 'spc8': ['tab', 'dbt2']
"   'sts' is incompatible with 'spc', 'dbt' would be compatible.
"
"* ASSUMPTIONS / PRECONDITIONS:
"   s:occurrences dictionary; key: indent setting; value: number of
"	lines that have that indent setting
"   s:occurrences still contains the raw settings, i.e. including doubtful ones.
"* EFFECTS / POSTCONDITIONS:
"   none
"* INPUTS:
"   none
"* RETURN VALUES:
"    Key: indent setting; value: list of indent settings.
"*******************************************************************************
    let l:incompatibles = {}
    for l:indentSetting in keys( s:occurrences )
	for l:preferredSetting in s:GetPrecedence( l:indentSetting )
	    let l:incompatibles[ l:preferredSetting ] = s:GetIncompatiblesForIndentSetting( l:preferredSetting )
	endfor
    endfor
    return l:incompatibles
endfunction
" }}}2

"- Rating generation -----------------------------------------------------{{{1
function! s:Rate( occurrences, incompatibleOccurrences) " {{{2
    if has('float')
	return 1.0 * a:occurrences / a:incompatibleOccurrences
    else
	" Emulate fractional numbers by shifting the decimal point 5 digits.
	" This may cause an integer overflow; avoid returning a negative value
	" and instead limit to the maxiumum integer.
	let l:rate = 10000 * a:occurrences / a:incompatibleOccurrences
	return (l:rate < 0 ? 0x7FFFFFFF : l:rate)
    endif
endfunction
function! s:EvaluateOccurrenceAndIncompatibleIntoRating( incompatibles ) " {{{2
"*******************************************************************************
"* PURPOSE:
"   For each indent setting, calculates a single (unnormalized) rating; the
"   higher, the more probable the indent setting.
"   The formula is
"	rating( indent setting ) = # of indent setting occurrences /
"	    (1 + sum( # of occurrences of incompatible indent settings )).
"   If there are no incompatible indent settings, the rating is deemed
"   "perfect", and the indent setting is stored in s:perfectIndentSetting.
"   If there is (are? - no, there can only be) one indent setting that is only
"   incompatible with bad indent settings, this is deemed the "authoritative"
"   indent setting, even though it isn't perfect. It is stored in
"   s:authoritativeIndentSetting.
"* ASSUMPTIONS / PRECONDITIONS:
"   s:occurrences dictionary; key: indent setting; value: number of
"	lines that have that indent setting
"* EFFECTS / POSTCONDITIONS:
"   Fills s:ratings: dictionary of ratings; key: indent setting; value: rating number
"   s:perfectIndentSetting can contain indent setting.
"   s:authoritativeIndentSetting can contain indent setting, but not both at the
"   same time.
"   There is either one perfect rating, or one authoritative rating, or neither.
"* INPUTS:
"   a:incompatibles: dictionary of incompatibles
"* RETURN VALUES:
"   none
"*******************************************************************************
    let s:ratings = {}
    let s:perfectIndentSetting = ''
    let s:authoritativeIndentSetting = ''

    for l:indentSetting in keys( s:occurrences )
	let l:incompatibles = a:incompatibles[ l:indentSetting ]
	let l:incompatibleOccurrences = 1
	for l:incompatible in l:incompatibles
	    let l:incompatibleOccurrences += s:occurrences[ l:incompatible ]
	endfor

	let s:ratings[ l:indentSetting ] = s:Rate(s:occurrences[ l:indentSetting ], l:incompatibleOccurrences)

	if empty( l:incompatibles )
	    " This is a perfect indent setting.
	    if empty( s:perfectIndentSetting )
		let s:perfectIndentSetting = l:indentSetting
	    else
		" When we have only a few, widely indented lines, there may be
		" more than one way to interpret them as a perfect; e.g.
		" "            " = 2 * spc6 / 3 * spc4;
		" <Tab><Tab><Tab><Tab><Tab> = 5 * tab / 8 * sts5
		"
		" I would probably best to drag along all perfect indent
		" settings, to later reconcile them with the buffer settings, or
		" ask the user. Since this should happen rarely, for the moment
		" just apply some simple heuristics to chose one over the other.
		if s:perfectIndentSetting == 'tab'
		    " Prefer the existing Tab.
		    unlet s:ratings[l:indentSetting]
		elseif l:indentSetting == 'tab'
		    " Prefer the new Tab.
		    unlet s:ratings[s:perfectIndentSetting]
		    let s:perfectIndentSetting = l:indentSetting
		elseif s:GetMultiplierFromIndentSetting(l:indentSetting) < s:GetMultiplierFromIndentSetting(s:perfectIndentSetting)
		    " Prefer the new, smaller multiplier.
		    unlet s:ratings[s:perfectIndentSetting]
		    let s:perfectIndentSetting = l:indentSetting
		else
		    " Prefer the existing smaller multiplier.
		    unlet s:ratings[l:indentSetting]
		endif
	    endif
	elseif empty( filter( copy( l:incompatibles ), '! s:IsBadIndentSetting(v:val)' ) )
	    " This is an authoritative indent setting.
	    if ! empty( s:authoritativeIndentSetting ) | throw 'ASSERT: There is only one authoritative indent setting. ' | endif
	    if ! empty( s:perfectIndentSetting ) | throw 'ASSERT: There can only be either a perfect or an authoritative indent setting. ' | endif
	    let s:authoritativeIndentSetting = l:indentSetting
	endif
    endfor
endfunction
" }}}2

"- Rating normalization --------------------------------------------------{{{1
function! s:NormalizePerfectRating() " {{{2
    " Remove every non-perfect rating.
    call filter( s:ratings, 'v:key == s:perfectIndentSetting' )

    " Normalize to 100%
    let s:ratings[ s:perfectIndentSetting ] = 100
endfunction

function! s:GetRawRatingsSum() "{{{2
    let l:valueSum = 0
    for l:value in values( s:ratings )
	let l:valueSum += l:value
    endfor
    if l:valueSum <= 0 | throw 'ASSERT: valueSum > 0' | endif
    return l:valueSum
endfunction

function! s:Normalize( ratings, ratingsSum ) "{{{2
    if has('float')
	return float2nr(100.0 * a:ratings / a:ratingsSum)
    else
	" Because of the limited range of integers, the multiplication may
	" overflow without a truncation.
	return 100 * min([a:ratings, 0x7FFFFFFF/100]) / a:ratingsSum
    endif
endfunction
function! s:NormalizeAuthoritativeRating() " {{{2
    " Remove every rating except the authoritative and bad indent settings.
    let l:rawRatingsSum = s:GetRawRatingsSum()
    for l:indentSetting in keys( s:ratings )
	let l:newRating = s:Normalize(s:ratings[l:indentSetting], l:rawRatingsSum)
	if l:indentSetting == s:authoritativeIndentSetting || s:IsBadIndentSetting( l:indentSetting )
	    let s:ratings[ l:indentSetting ] = l:newRating
	else
	    unlet s:ratings[ l:indentSetting ]
	endif
    endfor
endfunction

function! s:NormalizeNonPerfectRating() " {{{2
    let l:ratingThreshold = 10	" Remove everything below this percentage. Exception: bad indent settings.

    let l:rawRatingsSum = s:GetRawRatingsSum()
    for l:indentSetting in keys( s:ratings )
	let l:newRating = s:Normalize(s:ratings[l:indentSetting], l:rawRatingsSum)
	if l:newRating < l:ratingThreshold && ! s:IsBadIndentSetting( l:indentSetting )
	    unlet s:ratings[ l:indentSetting ]
	else
	    let s:ratings[ l:indentSetting ] = l:newRating
	endif
    endfor
endfunction

function! s:NormalizeRatings() " {{{2
"*******************************************************************************
"* PURPOSE:
"   Changes the values in the s:ratings dictionary so that the sum of all values
"   is 100; i.e. make percentages out of the ratings.
"   Depending on whether a s:perfectIndentSetting or
"   s:authoritativeIndentSetting has been detected, other elements may be
"   dropped from the s:ratings dictionary, if these stand up to scrutiny.
"   On the other hand, normalization can also demote a perfect or authoritative
"   rating.
"   If there is no perfect or authoritative indent setting, values below a
"   certain percentage threshold are dropped from the dictionary *after* the
"   normalization, in order to remove clutter when displaying the results to the
"   user.
"* ASSUMPTIONS / PRECONDITIONS:
"   s:ratings dictionary; key: indent setting; value: raw rating number;
"   s:perfectIndentSetting represents perfect indent setting, if such exists.
"   s:authoritativeIndentSetting represents authoritative indent setting, if such exists.
"* EFFECTS / POSTCONDITIONS:
"   s:ratings dictionary; key: indent setting; value: percentage rating
"   (100: checked range is consistent; < 100: inconsistent).
"   Modifies values in s:ratings.
"   Removes elements from s:ratings that fall below a threshold or that are
"   driven out by an authoritative setting.
"   May clear s:perfectIndentSetting and s:authoritativeIndentSetting.
"* INPUTS:
"   none
"* RETURN VALUES:
"   Flag whether any perfect or authoritative rating was cleared.
"*******************************************************************************
    let l:hadPerfectOrAuthoritativeRating = 0

    " A perfect or authoritative rating (i.e. an indent setting that is
    " consistent throughout the entire buffer / range) is only accepted if its
    " absolute rating number is also the maximum rating. Without this
    " qualification, a few small indent settings (e.g. sts1, spc2) could be
    " deemed the consistent setting, even though they actually are just indent
    " errors that sabotage the actual, larger desired indent setting (e.g. sts4,
    " spc4). In other words, the cop must not be fooled by some wrong spaces
    " into believing that we have a consistent sts1, although the vast majority
    " of indents suggests an sts4 with some inconsistencies.
    if ! empty(s:perfectIndentSetting) && s:perfectIndentSetting == s:GetBestRatedIndentSetting()
	call s:NormalizePerfectRating()
    elseif ! empty(s:authoritativeIndentSetting) && s:authoritativeIndentSetting == s:GetBestRatedIndentSetting()
	call s:NormalizeAuthoritativeRating()
    else
	" Any perfect or authoritative ratings didn't pass the majority rule, so
	" clear them here to signal a definite inconsistency, but return a flag
	" to allow s:IsBufferConsistentWithBufferSettings() to later turn around
	" this verdict by examining the buffer settings.
	let l:hadPerfectOrAuthoritativeRating = (! empty(s:perfectIndentSetting) || ! empty(s:authoritativeIndentSetting))
	let s:perfectIndentSetting = ''
	let s:authoritativeIndentSetting = ''

	call s:NormalizeNonPerfectRating()
    endif

    return l:hadPerfectOrAuthoritativeRating
endfunction

" }}}1

function! s:CheckBufferConsistency( startLineNum, endLineNum ) " {{{1
"*******************************************************************************
"* PURPOSE:
"   Checks the consistency of the indents in the current buffer, range of
"   startLine to endLine.
"* ASSUMPTIONS / PRECONDITIONS:
"   none
"* EFFECTS / POSTCONDITIONS:
"   Fills the s:occurrences dictionary; key: indent setting; value: number of
"	lines that have that indent setting
"   Fills the s:ratings dictionary; key: indent setting; value: rating
"   percentage (with low percentages removed).
"* INPUTS:
"   a:startLineNum
"   a:endLineNum
"* RETURN VALUES:
"   -1: checked range does not contain indents
"    0: checked range is not consistent
"    1: checked range is consistent
"*******************************************************************************
    if a:startLineNum > a:endLineNum
	throw 'ASSERT: startLineNum <= a:endLineNum'
    endif

    " These variables store the minimum / maximum indent encountered.
    let [s:indentMin, s:indentMax] = [0x7FFFFFFF, 0]

    " This dictionary collects the occurrences of all found indent settings. It
    " is the basis for all evaluations and statistics.
    let s:occurrences = {}  " key: indent setting (e.g. 'sts4'); value: number of lines that have that indent setting.

    " These intermediate dictionaries will be processed into s:occurrences via
    " EvaluateIndentsIntoOccurrences().
    let s:tabstops = {}	    " key: number of indent spaces (8*n); value: number of lines that have the number of indent spaces.
    let s:spaces = {}	    " key: number of indent spaces (>=8); value: number of lines that have the number of indent spaces.
    let s:softtabstops = {} " key: number of indent softtabstops (converted to spaces); value: number of lines that have the number of spaces.
    let s:doubtful = {}	    " key: number of indent spaces (<8) which may be either spaces or softtabstops; value: number of lines that have the number of spaces.

    let l:lineNum = a:startLineNum
    while l:lineNum <= a:endLineNum
	call s:InspectLine(l:lineNum)
	let l:lineNum += 1
    endwhile

    " No need to continue if no indents were found.
    if s:indentMax == 0
	return [-1, 0]
    endif

    " s:tabstops need not be evaluated into occurrences, as there are no
    " multiplicity ambiguities. The tabstops have already been counted in
    " s:occurrences.
    call s:EvaluateIndentsIntoOccurrences( s:spaces, 'spc' )
    call s:EvaluateIndentsIntoOccurrences( s:softtabstops, 'sts' )
    call s:RemoveSts8()
    call s:EvaluateIndentsIntoOccurrences( s:doubtful, 'dbt' )
    " Now, the indent occurrences have been consolidated into s:occurrences.
    " It counts the actual or possible indent settings. An indent of 4 spaces is
    " counted once as 'spc4', the alternatives of 2x 'spc2' or 4x 'spc1' are
    " discarded, because only the largest possible unambiguous indent setting wins.
    " However, an indent of 30 spaces is counted as both 'spc5' and 'spc6',
    " because the indent could result from either one. Again, 'spc3', 'spc2' and
    " 'spc1' are discarded, because they are smaller subsets.
    " Thus, the sum of occurrences can be larger than the number of actual
    " indents examined, because some indents can not unambiguously be assigned
    " to one indent setting.

"****D echo 'Min/Max.   :  ' . s:indentMin s:indentMax
"****D echo 'Tabstops:     ' . string( s:tabstops )
"****D echo 'Spaces:       ' . string( s:spaces )
"****D echo 'Softtabstops: ' . string( s:softtabstops )
"****D echo 'Doubtful:     ' . string( s:doubtful )
"****D echo 'Raw Occurr.   ' . string( s:occurrences )

    if empty( s:occurrences )
	throw 'Should have returned already, because s:indentMax == 0.'
    endif

"****D echo 'This is probably a ' . string( filter( copy( s:occurrences ), 'v:val == max( s:occurrences )') )

    " This dictionary contains the incompatible indent settings for each indent
    " setting.
    let s:incompatibles = s:EvaluateIncompatibleIndentSettings() " Key: indent setting; value: list of indent settings.
"****D echo 'Raw Incomp.:  ' . string( s:incompatibles )

    call s:ApplyPrecedences()
"****D echo 'Occurrences:  ' . string( s:occurrences )
"****D echo 'Incompatibles:' . string( s:incompatibles )

    " The s:ratings dictionary contains the final rating, a combination of high indent settings occurrence and low incompatible occurrences.
    call s:EvaluateOccurrenceAndIncompatibleIntoRating( s:incompatibles ) " Key: indent setting; value: rating number
"****D echo 'Raw   Ratings:' . string( s:ratings )
"****D let l:debugIndentSettings = s:perfectIndentSetting . s:authoritativeIndentSetting | if ! empty(l:debugIndentSettings) | echo 'Found' (empty(s:perfectIndentSetting) ? 'authoritative' : 'perfect') 'indent setting before normalization. ' | endif

    let l:hadPerfectOrAuthoritativeRating = s:NormalizeRatings()
"****D echo 'Norm. Ratings:' . string( s:ratings )
"****D let l:debugIndentSettings = s:perfectIndentSetting . s:authoritativeIndentSetting | if ! empty(l:debugIndentSettings) | echo '  ...' (empty(s:perfectIndentSetting) ? 'authoritative' : 'perfect') 'indent setting after normalization. ' | endif
"****D call confirm('debug')


    " Cleanup dictionaries with script-scope to free memory.
    let s:tabstops = {}
    let s:spaces = {}
    let s:softtabstops = {}
    let s:doubtful = {}
    " Do not free s:indentMin / s:indentMax, they are still accessed by s:IsEnoughIndentForSolidAssessment().
    let s:incompatibles = {}
    " Do not free s:ratings, it is still accessed by s:IndentConsistencyCop().

    let l:isConsistent = ! empty( s:perfectIndentSetting )
    if l:isConsistent && (count( s:ratings, 100 ) != 1) | throw 'ASSERT: If consistent, there should be a 100% rating. ' | endif
    return [l:isConsistent, l:hadPerfectOrAuthoritativeRating]
endfunction


"- consistency of buffer settings functions -------------------------------{{{1
function! s:CheckBufferSettingsConsistency() " {{{2
"*******************************************************************************
"* PURPOSE:
"   Checks the buffer indent settings (tabstop, softtabstop, shiftwidth,
"   expandtab) for consistency.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   none
"* RETURN VALUES:
"   Empty string if settings are consistent, else
"   User string describing the inconsistencies.
"*******************************************************************************
    let l:inconsistencies = ''

    " 'shiftwidth' must be equal to 'tabstop' or 'softtabstop', except when
    " using 'smarttab'.
    if ! &l:smarttab
	if &l:softtabstop > 0
	    if &l:softtabstop != &l:shiftwidth
		let l:inconsistencies .= "\nThe value of softtabstop (" . &l:softtabstop . ") should equal the value of shiftwidth (" . &l:shiftwidth . "). "
	    endif
	else
	    if &l:tabstop != &l:shiftwidth
		let l:inconsistencies .= "\nThe value of tabstop (" . &l:tabstop . ") should equal the value of shiftwidth (" . &l:shiftwidth . "). "
	    endif
	endif
    endif

    " When using 'softtabstop', 'tabstop' remains at the standard value of 8.
    if &l:softtabstop > 0 && &l:tabstop != 8
	let l:inconsistencies .= "\nWhen using soft tabstops, tabstop (" . &l:tabstop . ") should remain at the standard value of 8. "
    endif

    if ! empty( l:inconsistencies )
	let l:inconsistencies = "\n\nThe buffer's indent settings are inconsistent:" . l:inconsistencies
    endif

    return l:inconsistencies
endfunction

function! s:IsBufferSettingsConsistent() " {{{2
    return empty( s:CheckBufferSettingsConsistency() )
endfunction

function! s:GetIndentSettingForBufferSettings() " {{{2
"*******************************************************************************
"* PURPOSE:
"   Translates the buffer indent settings (tabstop, softtabstop, shiftwidth,
"   expandtab) into an indent setting (e.g. 'sts4').
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   none
"* RETURN VALUES:
"   indent setting
"   'badset' if inconsistent buffer indent settings
"*******************************************************************************
    if ! s:IsBufferSettingsConsistent()
	return 'badset'
    endif

    if &l:expandtab
	let l:setting = 'spc'
    elseif &l:softtabstop > 0
	let l:setting = 'sts'
    else
	" No multiplier for 'tab'.
	return 'tab'
    endif

    " We use 'shiftwidth' for the indent multiplier, because it is not only
    " easier to resolve than 'tabstop'/'softtabstop', but it is also valid when
    " 'smarttab' is set.
    let l:multiplier = &l:shiftwidth

    return l:setting . l:multiplier
endfunction
" }}}2

"- consistency with buffer settings functions -----------------------------{{{1
function! s:GetCorrectTabstopSetting( indentSetting ) " {{{2
    if &smarttab == 1
	" When using 'smarttab', front-of-the-line indenting solely uses
	" 'shiftwidth'; 'tabstop' and 'softtabstop' are only used in other
	" places.
	return &l:tabstop
    elseif s:GetSettingFromIndentSetting( a:indentSetting ) == 'tab'
	return &l:tabstop
    elseif s:GetSettingFromIndentSetting( a:indentSetting ) == 'sts'
	return 8
    elseif s:GetSettingFromIndentSetting( a:indentSetting ) == 'spc'
	" If tabstop=8, we prefer changing the indent via softtabstop.
	" If tabstop!=8, we rather modify tabstop than turning on softtabstop.
	if &l:tabstop == 8
	    return 8
	else
	    return s:GetMultiplierFromIndentSetting( a:indentSetting )
	endif
    else
	throw 'ASSERT: Unknown setting. '
    endif
endfunction

function! s:GetCorrectSofttabstopSetting( indentSetting ) " {{{2
    if &smarttab == 1
	" When using 'smarttab', front-of-the-line indenting solely uses
	" 'shiftwidth'; 'tabstop' and 'softtabstop' are only used in other
	" places.
	return &l:softtabstop
    elseif s:GetSettingFromIndentSetting( a:indentSetting ) == 'sts'
	return s:GetMultiplierFromIndentSetting( a:indentSetting )
    elseif s:GetSettingFromIndentSetting( a:indentSetting ) == 'spc'
	" If tabstop=8, we prefer changing the indent via softtabstop.
	" If tabstop!=8, we rather modify tabstop than turning on softtabstop.
	if &l:tabstop == 8 && s:GetMultiplierFromIndentSetting( a:indentSetting ) != 8
	    return s:GetMultiplierFromIndentSetting( a:indentSetting )
	else
	    return 0
	endif
    else
	" Prefers (ts=n sts=0 expandtab) over (ts=8 sts=n expandtab).
	return 0
    endif
endfunction

function! s:GetCorrectShiftwidthSetting( indentSetting ) " {{{2
    if s:GetSettingFromIndentSetting( a:indentSetting ) == 'tab'
	return &l:tabstop
    else
	return s:GetMultiplierFromIndentSetting( a:indentSetting )
    endif
endfunction

function! s:GetCorrectExpandtabSetting( indentSetting ) " {{{2
    return (s:GetSettingFromIndentSetting( a:indentSetting ) == 'spc')
endfunction

function! s:BooleanToSettingNoSetting( settingName, settingValue )
    return a:settingValue ? a:settingName : 'no' . a:settingName
endfunction

function! s:CheckConsistencyWithBufferSettings( indentSetting ) " {{{2
"*******************************************************************************
"* PURPOSE:
"   Checks the consistency of the passed indent setting with the indent settings
"   of the current buffer, i.e. the 'tabstop', 'softtabstop', 'shiftwidth' and
"   'expandtab' settings.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:indentSettings: prescribed indent setting for the buffer
"* RETURN VALUES:
"   empty string: indent setting is consistent with buffer indent settings, else
"   user string describing the necessary changes to adapt the buffer indent
"	settings.
"*******************************************************************************
    let l:isTabstopCorrect     = (s:GetCorrectTabstopSetting( a:indentSetting )	    == &l:tabstop)
    let l:isSofttabstopCorrect = (s:GetCorrectSofttabstopSetting( a:indentSetting ) == &l:softtabstop)
    let l:isShiftwidthCorrect  = (s:GetCorrectShiftwidthSetting( a:indentSetting )  == &l:shiftwidth)
    let l:isExpandtabCorrect   = (s:GetCorrectExpandtabSetting( a:indentSetting )   == &l:expandtab)

    if l:isTabstopCorrect && l:isSofttabstopCorrect && l:isShiftwidthCorrect && l:isExpandtabCorrect
	return ''
    else
	let l:userString = "The buffer's indent settings are " . ( s:IsEnoughIndentForSolidAssessment() ? '' : 'potentially ')
	let l:userString .= "inconsistent with the used indent '" . s:IndentSettingToUserString( a:indentSetting ) . "'; these settings must be changed: "
	if ! l:isTabstopCorrect
	    let l:userString .= "\n- tabstop from " . &l:tabstop . ' to ' . s:GetCorrectTabstopSetting( a:indentSetting )
	endif
	if ! l:isSofttabstopCorrect
	    let l:userString .= "\n- softtabstop from " . &l:softtabstop . ' to ' . s:GetCorrectSofttabstopSetting( a:indentSetting )
	endif
	if ! l:isShiftwidthCorrect
	    let l:userString .= "\n- shiftwidth from " . &l:shiftwidth . ' to ' . s:GetCorrectShiftwidthSetting( a:indentSetting )
	endif
	if ! l:isExpandtabCorrect
	    let l:userString .= "\n- " . s:BooleanToSettingNoSetting( 'expandtab', &l:expandtab ) . ' to ' . s:BooleanToSettingNoSetting( 'expandtab', s:GetCorrectExpandtabSetting( a:indentSetting ) )
	endif

	let l:userString .= s:GetInsufficientIndentUserMessage()

	return l:userString
    endif
endfunction " }}}2
function! s:IsConsistentWithBufferSettings( indentSetting ) " {{{2
    return empty( s:CheckConsistencyWithBufferSettings( a:indentSetting ) )
endfunction

function! s:MakeBufferSettingsConsistentWith( indentSetting ) " {{{2
    let &l:tabstop    = s:GetCorrectTabstopSetting( a:indentSetting )
    let &l:softtabstop = s:GetCorrectSofttabstopSetting( a:indentSetting )
    let &l:shiftwidth = s:GetCorrectShiftwidthSetting( a:indentSetting )
    let &l:expandtab  = s:GetCorrectExpandtabSetting( a:indentSetting )
endfunction

" }}}1

"- output functions -------------------------------------------------------{{{1
function! s:EchoStartupMessage( lineCnt, isEntireBuffer ) " {{{2
    " When the IndentConsistencyCop is triggered by through autocmds
    " (IndentConsistencyCopAutoCmds.vim), the newly created buffer is not yet
    " displayed. To allow the user to see what text IndentConsistencyCop is
    " talking about, we're forcing a redraw.
    redraw

    " For large ranges / buffers, processing may take a while. We print out an
    " informational message so that the user knows what is eating the CPU cycles
    " right now. But we only print the message for large files to avoid the
    " 'Press ENTER to continue' Vim prompt.
    if a:lineCnt > 2000 " empirical value
	echo 'IndentConsistencyCop is investigating ' . s:GetScopeUserString(a:isEntireBuffer) . '...'
    endif
endfunction

function! s:EchoUserMessage( message ) " {{{2
    echomsg a:message
endfunction

function! s:IndentSettingToUserString( indentSetting ) " {{{2
"*******************************************************************************
"* PURPOSE:
"   Converts the internally used 'xxxn' indent setting into a
"   user-understandable string.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:indentSetting: indent setting
"* RETURN VALUES:
"   string describing the indent setting
"*******************************************************************************
    let l:userString = ''

    if a:indentSetting == 'tab'
	let l:userString = 'tabstop'
    elseif a:indentSetting == 'badsts'
	let l:userString = 'soft tabstop with too many trailing spaces'
    elseif a:indentSetting == 'badmix'
	let l:userString = 'bad mix of spaces and tabs'
    elseif a:indentSetting == 'badset'
	let l:userString = 'inconsistent buffer indent settings'
    elseif a:indentSetting == 'notbad'
	let l:userString = 'no bad mixes or soft tabstops with too many spaces'
    else
	let l:setting = s:GetSettingFromIndentSetting( a:indentSetting )
	let l:multiplier = s:GetMultiplierFromIndentSetting( a:indentSetting )
	if l:setting == 'sts'
	    let l:userString = l:multiplier . ' characters soft tabstop'
	elseif l:setting == 'spc'
	    let l:userString = l:multiplier . ' spaces'
	else
	    throw 'unknown indent setting "' . a:indentSetting . '"'
	endif
    endif

    return l:userString
endfunction

function! s:DictCompareDescending( i1, i2 ) " {{{2
    return a:i1[1] == a:i2[1] ? 0 : a:i1[1] > a:i2[1] ? -1 : 1
endfunction

function! s:GetSortedRatingList() "{{{2
"*******************************************************************************
"* PURPOSE:
"   Transforms s:ratings into a list of [ indent setting, rating value ] lists
"   which are sorted from highest to lowest rating.
"* ASSUMPTIONS / PRECONDITIONS:
"   s:ratings is a dictionary that contains numerical values.
"* EFFECTS / POSTCONDITIONS:
"   none
"* INPUTS:
"   none
"* RETURN VALUES:
"   sorted list of [ indent setting, rating value ] lists
"*******************************************************************************
    " In order to output the ratings from highest to lowest, we need to
    " convert the ratings dictionary to a list and sort it with a custom
    " comparator which considers the value part of each list element.
    " There is no built-in sort() function for dictionaries.
    let l:ratingLists = items( s:ratings )
    return sort( l:ratingLists, 's:DictCompareDescending' )
endfunction

function! s:GetBestRatedIndentSetting() "{{{2
    return (empty(s:ratings) ? '' : s:GetSortedRatingList()[0][0])
endfunction

function! s:RatingsToUserString( lineCnt ) " {{{2
"*******************************************************************************
"* PURPOSE:
"   Dresses up the ratings information into a multi-line string that can be
"   displayed to the user. The lines are ordered from high to low ratings. If
"   low ratings have been filtered out, this is reported, too.
"* ASSUMPTIONS / PRECONDITIONS:
"   s:occurrences dictionary; key: indent setting; value: number of
"	lines that have that indent setting
"   s:ratings dictionary; key: indent setting; value: percentage
"	rating (100: checked range is consistent; < 100: inconsistent.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:lineCnt:	Number of lines in the range / buffer that have been inspected.
"* RETURN VALUES:
"   user string describing the ratings information
"*******************************************************************************
    let l:bufferIndentSetting = s:GetIndentSettingForBufferSettings()
    let l:isBufferIndentSettingInRatings = 0
    let l:userString = ''

    let l:ratingSum = 0
    for l:ratingList in s:GetSortedRatingList()
	let l:indentSetting = l:ratingList[0]
	let l:userString .= "\n- " . s:IndentSettingToUserString( l:indentSetting ) . ' (' . s:occurrences[ l:indentSetting ] . ' of ' . a:lineCnt . ' lines)'
	"**** let l:rating = l:ratingList[1] = s:ratings[ l:indentSetting ]
	if l:indentSetting == l:bufferIndentSetting
	    let l:userString .= ' <- buffer setting'
	    let l:isBufferIndentSettingInRatings = 1
	endif
	let l:ratingSum += s:ratings[ l:indentSetting ]
    endfor

    if l:ratingSum < (100 - 1) || len(s:ratings) == 1 " Allow for 1% rounding error. When there's only one rating, others certainly have been dropped.
	let l:userString .= "\nSome minor / inconclusive potential settings have been omitted. "
    endif

    if ! l:isBufferIndentSettingInRatings
	let l:bufferSettingsInconsistencies = s:CheckBufferSettingsConsistency()
	if empty( l:bufferSettingsInconsistencies )
	    let l:userString .= "\nThe buffer setting is " . s:IndentSettingToUserString( l:bufferIndentSetting ) . '. '
	else
	    let l:userString .= l:bufferSettingsInconsistencies
	endif
    endif

    return l:userString
endfunction

function! s:PrintBufferSettings( messageIntro ) " {{{2
    let l:userMessage = a:messageIntro
    let l:userMessage .= 'tabstop=' . &l:tabstop . ' softtabstop=' . &l:softtabstop . ' shiftwidth=' . &l:shiftwidth
    let l:userMessage .= (&l:expandtab ? ' expandtab' : ' noexpandtab')

    call s:EchoUserMessage( l:userMessage )
endfunction

function! s:GetInsufficientIndentUserMessage() " {{{2
    if s:IsEnoughIndentForSolidAssessment()
	return ''
    else
	return "\nWarning: The maximum indent of " . s:indentMax . ' is too small for a solid assessment. '
    endif
endfunction

function! s:GetScopeUserString( isEntireBuffer ) " {{{2
    return (a:isEntireBuffer ? 'buffer' : 'range')
endfunction

" }}}2
" }}}1

"- buffer consistency cops ------------------------------------------------{{{1
function! s:Query( msg, choices, default ) "{{{2
"*******************************************************************************
"* PURPOSE:
"   Ask the user for a choice. This is a wrapper around confirm() which allows
"   to specify and return choices by name, not by index.
"* ASSUMPTIONS / PRECONDITIONS:
"   If g:indentconsistencycop_choices is a non-empty list, the first list
"   item is popped off and returned instead of actually querying the user. This
"   is used for testing purposes.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:msg	Dialog text.
"   a:choices	List of choices. Set the shortcut key by prepending '&'.
"   a:default	Default choice text. Either number (0 for no default, (index +
"		1) for choice) or choice text; omit any shortcut key '&' there.
"* RETURN VALUES:
"   Choice text without the shortcut key '&'. Empty string if the dialog was
"   aborted.
"*******************************************************************************
    let l:plainChoices = map(copy(a:choices), 'substitute(v:val, "&", "", "g")')
    let l:defaultIndex = (type(a:default) == type(0) ? a:default : max([index(l:plainChoices, a:default) + 1, 0]))

    if exists('g:indentconsistencycop_choices') && len(g:indentconsistencycop_choices) > 0
	" Headless mode: Bypass actual confirm so that no user intervention is
	" necesary.

	" Emulate the console output of confirm(), so that it looks for a test
	" driver as if it were real.
	let l:defaultChoice = (l:defaultIndex > 0 ? get(a:choices, l:defaultIndex - 1) : '')
	echo a:msg
	echo join(map(copy(a:choices), 'substitute(v:val, "&\\(.\\)", (v:val ==# l:defaultChoice ? "[\\1]" : "(\\1)"), "g")'), ', ') . ': '

	" Return predefined choice.
	return remove(g:indentconsistencycop_choices, 0)
    endif

    let l:choice = ''
    let l:index = confirm(a:msg, join(a:choices, "\n"), l:defaultIndex, 'Question')
    if l:index > 0
	let l:choice = get(l:plainChoices, l:index - 1, '')
    endif

    return l:choice
endfunction
function! s:IsEntireBuffer( startLineNum, endLineNum ) "{{{2
    return (a:startLineNum == 1 && a:endLineNum == line('$'))
endfunction

function! s:UnindentedBufferConsistencyCop( isEntireBuffer, isBufferSettingsCheck ) " {{{2
"*******************************************************************************
"* PURPOSE:
"   Reports that the buffer does not contain indentation and (if desired)
"   triggers the consistency check with the buffer indent settings, thereby
"   interacting with the user.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:isEntireBuffer:	flag whether complete buffer or limited range is checked
"   a:isBufferSettingsCheck: flag whether consistency with the buffer
"	settings should also be checked.
"* RETURN VALUES:
"   none
"*******************************************************************************
    let l:userMessage = ''
    if a:isBufferSettingsCheck
	let l:userMessage = s:CheckBufferSettingsConsistency()
	if ! empty( l:userMessage )
	    let l:userMessage = 'This ' . s:GetScopeUserString(a:isEntireBuffer) . ' does not contain indented text. ' . l:userMessage
	    let l:userMessage .= "\nHow do you want to deal with the inconsistency?"
	    let l:action = s:Query( l:userMessage, ['&Ignore', '&Correct setting...'], 1 )
	    if empty(l:action) || l:action ==? 'Ignore'
		call s:PrintBufferSettings( 'The buffer settings remain inconsistent: ' )
	    elseif l:action =~? '^Correct'
		let l:chosenIndentSetting = s:QueryIndentSetting()
		if ! empty( l:chosenIndentSetting )
		    call s:MakeBufferSettingsConsistentWith( l:chosenIndentSetting )
		    call s:ReportConsistencyWithBufferSettingsResult( a:isEntireBuffer, 1 )
		    call s:ReportBufferSettingsConsistency( l:chosenIndentSetting )
		    call s:PrintBufferSettings( 'The buffer settings have been changed: ' )
		else
		    call s:PrintBufferSettings( 'The buffer settings remain inconsistent: ' )
		endif
	    else
		throw 'ASSERT: Unhandled action: ' . l:action
	    endif
	endif
    endif
    if empty( l:userMessage )
	call s:EchoUserMessage( 'This ' . s:GetScopeUserString(a:isEntireBuffer) . ' does not contain indented text. ' )
    endif
endfunction
" }}}2
function! s:IndentBufferConsistencyCop( startLineNum, endLineNum, consistentIndentSetting, isBufferSettingsCheck ) " {{{2
"*******************************************************************************
"* PURPOSE:
"   Reports buffer consistency and (if desired) triggers the consistency check
"   with the buffer indent settings, thereby interacting with the user.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:startLineNum, a:endLineNum: range in the current buffer that was to be
"	checked.
"   a:consistentIndentSetting: determined consistent indent setting of the
"      buffer
"   a:isBufferSettingsCheck: flag whether consistency with the buffer
"	settings should also be checked.
"* RETURN VALUES:
"   none
"*******************************************************************************
    let l:userMessage = ''
    let l:consistentIndentSetting = a:consistentIndentSetting
    let l:isEntireBuffer = s:IsEntireBuffer(a:startLineNum, a:endLineNum)
    if a:isBufferSettingsCheck
	let l:userMessage = s:CheckConsistencyWithBufferSettings( l:consistentIndentSetting )
	if ! empty( l:userMessage ) && ! s:IsEnoughIndentForSolidAssessment() && s:GetSettingFromIndentSetting(l:consistentIndentSetting) == 'spc'
	    " Space indents of up to 7 spaces can be either softtabstop or
	    " space-indent, lacking larger indents or other hints they cannot be
	    " told apart, so s:GetPrecedence() defaults to 'spc'. To avoid
	    " spurious buffer settings consistency warnings (which are highly
	    " annoying because many files have only insufficient indents), check
	    " for consistency with 'sts', and assume that is the actual correct
	    " indent setting when it is consistent with the buffer settings.
	    " Note: We do this here after-the-fact instead of modifying the
	    " defaulting logic in s:GetPrecedence() to keep its early evaluation
	    " logic free of dependencies to the buffer settings. (The functional
	    " block of s:GetPrecedence() has no knowledge of
	    " a:isBufferSettingsCheck, and should have none of it.)
	    let l:equivalentConsistentIndentSetting = 'sts' . s:GetMultiplierFromIndentSetting(l:consistentIndentSetting)
	    if s:IsConsistentWithBufferSettings( l:equivalentConsistentIndentSetting )
		let l:userMessage = ''
		let l:consistentIndentSetting = l:equivalentConsistentIndentSetting
	    endif
	endif
	call s:ReportConsistencyWithBufferSettingsResult( l:isEntireBuffer, empty(l:userMessage) )
	if ! empty( l:userMessage )
	    let l:userMessage .= "\nHow do you want to deal with the "
	    let l:userMessage .= (s:IsEnoughIndentForSolidAssessment() ? '' : 'potential ')
	    let l:userMessage .= 'inconsistency?'
	    let l:action = s:Query(l:userMessage, ['&Ignore', '&Change', '&Wrong, choose correct setting...'], 1)
	    if empty(l:action) || l:action ==? 'Ignore'
		call s:PrintBufferSettings( 'The buffer settings remain ' . (s:IsEnoughIndentForSolidAssessment() ? 'inconsistent' : 'at') . ': ' )
	    elseif l:action ==? 'Change'
		call s:MakeBufferSettingsConsistentWith( l:consistentIndentSetting )
		call s:ReportConsistencyWithBufferSettingsResult( l:isEntireBuffer, 1 )
		call s:ReportBufferSettingsConsistency( l:consistentIndentSetting )
		call s:PrintBufferSettings( 'The buffer settings have been changed: ' )
	    elseif l:action =~? '^Wrong'
		let l:chosenIndentSetting = s:QueryIndentSetting()
		if ! empty( l:chosenIndentSetting )
		    call s:HighlightInconsistentIndents( a:startLineNum, a:endLineNum, l:chosenIndentSetting )
		else
		    call s:PrintBufferSettings( 'The buffer settings remain ' . (s:IsEnoughIndentForSolidAssessment() ? 'inconsistent' : 'at') . ': ' )
		endif
	    else
		throw 'ASSERT: Unhandled l:action: ' . l:action
	    endif
	endif
    endif
    if empty( l:userMessage )
	call s:EchoUserMessage( 'This ' . s:GetScopeUserString(l:isEntireBuffer) . " uses '" . s:IndentSettingToUserString( l:consistentIndentSetting ) . "' consistently. " )
    endif
endfunction
" }}}2
" }}}1

"- highlight functions-----------------------------------------------------{{{1
function! s:IsLineCorrect( lineNum, correctIndentSetting ) " {{{2
    let l:beginningWhitespace = s:GetBeginningWhitespace( a:lineNum )
    if empty( l:beginningWhitespace )
	return 1
    endif

    if a:correctIndentSetting == 'tab'
	return l:beginningWhitespace =~ '^\t\+$'
    elseif s:GetSettingFromIndentSetting( a:correctIndentSetting ) == 'spc'
	return l:beginningWhitespace =~ '^ \+$' && s:IsIndentProduceableWithIndentSetting( len( l:beginningWhitespace ), a:correctIndentSetting )
    elseif s:GetSettingFromIndentSetting( a:correctIndentSetting ) == 'sts'
	let l:beginningSpaces = substitute( l:beginningWhitespace, '\t', '        ', 'g' )
	return l:beginningWhitespace =~ '^\t* \{0,7}$' && s:IsIndentProduceableWithIndentSetting( len( l:beginningSpaces ), a:correctIndentSetting )
    elseif a:correctIndentSetting == 'notbad'
	return l:beginningWhitespace =~ '^\(\t\+ \{0,7}\| \+\)$'
    elseif a:correctIndentSetting == 'badsts'
	return l:beginningWhitespace =~ '^\t* \{8,}$'
    elseif a:correctIndentSetting == 'badmix'
	return l:beginningWhitespace =~ ' \t'
    elseif a:correctIndentSetting == 'badset'
	throw 'cannot evaluate lines with badset'
    else
	throw 'unknown indent setting "' . a:indentSetting . '"'
    endif
endfunction

function! IndentConsistencyCop#FoldExpr( lineNum, foldContext ) " {{{2
    let l:lineCnt = a:lineNum - a:foldContext
    while l:lineCnt <= a:lineNum + a:foldContext
	if index( b:indentconsistencycop_lineNumbers, l:lineCnt ) != -1
	    return 0
	endif
	let l:lineCnt += 1
    endwhile
    return 1
endfunction

function! s:ClearMatch()
    if exists('*matchadd')
	if exists('w:indentconsistencycop_match')
	    silent! call matchdelete(w:indentconsistencycop_match)
	    unlet w:indentconsistencycop_match
	endif
    elseif g:indentconsistencycop_highlighting =~# 'm'
	2match none
    endif
endfunction
function! s:SetHighlighting( lineNumbers ) " {{{2
"*******************************************************************************
"* PURPOSE:
"   Highlights the incorrect lines; saves the original values if modifications
"   to buffer settings are done.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"   Sets b:indentconsistencycop_did_highlighting = 1.
"   Saves buffer settings in buffer-local variables if they don't already exist.
"* INPUTS:
"   lineNumbers: List of buffer line numbers.
"* RETURN VALUES:
"   none
"*******************************************************************************
    " Set a buffer-scoped flag that the buffer's settings were modified for
    " highlighting, so that ClearHighlighting() is able to only undo the
    " modifications if there have been any. This is important because
    " ClearHighlighting() is also executed when the buffer is consistent, and in
    " that case we don't know whether there was any highlighting done
    " beforehand.
    let b:indentconsistencycop_did_highlighting = 1

    " Before modifying any buffer setting, the original value is saved in a
    " buffer-local variable. ClearHighlighting() will use those to restore the
    " original buffer settings. SetHighlighting() may be invoked multiple times
    " without a corresponding ClearHighlighting() when the user performs
    " multiple :IndentConsistencyCop sequentially. Thus, the buffer settings
    " must only be saved on the first invocation, or after a
    " ClearHighlighting(), i.e. when the variables used for saving are
    " undefined.

    if g:indentconsistencycop_highlighting  =~# '[sm]'
	let l:linePattern = ''
	for l:lineNum in a:lineNumbers
	    let l:linePattern .= '\|\%' . l:lineNum . 'l'
	endfor
	let l:linePattern = '\(' . strpart( l:linePattern, 2) . '\)\&^\s\+'

	if g:indentconsistencycop_highlighting =~# 's'
	    let @/ = l:linePattern
	endif
	if g:indentconsistencycop_highlighting =~# 'm'
	    call s:ClearMatch()

	    if exists('*matchadd')
		let w:indentconsistencycop_match = matchadd('IndentConsistencyCop', l:linePattern)
	    else
		execute '2match IndentConsistencyCop /' . l:linePattern . '/'
	    endif

	    " Note: The match is installed for the window, but we would like to
	    " have them attached to the buffer. Therefore, we at least have to
	    " do cleanup when another buffer is displayed in the current window.
	    " We do not attempt to restore the match when the buffer is
	    " re-displayed in a window, because that is hard to get right and
	    " requires a lot of autocmds. This should happen rarely enough, and
	    " the user can re-create the highlighting with another
	    " :IndentConsistencyCop command.
	    augroup IndentConsistencyCopMatches
		autocmd! BufWinLeave <buffer> call <SID>ClearMatch() | autocmd! IndentConsistencyCopMatches * <buffer>
	    augroup END
	endif

    endif

    if g:indentconsistencycop_highlighting =~# 'g'
	let l:firstLineNum = min( a:lineNumbers )
	if l:firstLineNum > 0
	    execute 'normal ' . l:firstLineNum . 'G0'
	endif
    endif

    if g:indentconsistencycop_highlighting =~# 'l'
	if ! exists( 'b:indentconsistencycop_save_list' )
	    let b:indentconsistencycop_save_list = &l:list
	endif
	setlocal list
    endif

    let l:foldContext = matchstr( g:indentconsistencycop_highlighting, '\Cf:\zs\d' )
    if ! empty( l:foldContext )
	" The list of lines to be highlighted is copied to a list with
	" buffer-scope, because the (buffer-scoped) foldexpr needs access to it.
	let b:indentconsistencycop_lineNumbers = copy( a:lineNumbers )

	if ! exists( 'b:indentconsistencycop_save_foldexpr' )
	    let b:indentconsistencycop_save_foldexpr = &l:foldexpr
	endif
	let &l:foldexpr='IndentConsistencyCop#FoldExpr(v:lnum,' . l:foldContext . ')'

	" Close all folds, so that only the inconsistent lines (plus context
	" around it) is visible.
	if ! exists( 'b:indentconsistencycop_save_foldlevel' )
	    let b:indentconsistencycop_save_foldlevel = &l:foldlevel
	endif
	setlocal foldlevel=0

	if ! exists( 'b:indentconsistencycop_save_foldmethod' )
	    let b:indentconsistencycop_save_foldmethod = &l:foldmethod
	endif
	setlocal foldmethod=expr

	" Enable folding to be effective.
	if ! &l:foldenable && ! exists( 'b:indentconsistencycop_save_foldenable' )
	    let b:indentconsistencycop_save_foldenable = &l:foldenable
	endif
	setlocal foldenable
    endif
endfunction

function! IndentConsistencyCop#ClearHighlighting() " {{{2
"*******************************************************************************
"* PURPOSE:
"   Undoes the highlighting done by SetHighlighting() and restores the buffer
"   settings to its original values.
"* ASSUMPTIONS / PRECONDITIONS:
"   b:indentconsistencycop_did_highlighting == 1 if highlighting was done
"* EFFECTS / POSTCONDITIONS:
"   Restores the buffer settings and undefines the buffer-local variables used
"   for saving.
"* INPUTS:
"   none
"* RETURN VALUES:
"   none
"*******************************************************************************
    call s:ClearMatch()

    if ! exists( 'b:indentconsistencycop_did_highlighting' ) || ! b:indentconsistencycop_did_highlighting
	return
    endif
    unlet b:indentconsistencycop_did_highlighting

    if g:indentconsistencycop_highlighting =~# 's'
	let @/ = ''
    endif

    " 'g' : There's no need to undo this.

    if g:indentconsistencycop_highlighting =~# 'l'
	if exists( 'b:indentconsistencycop_save_list' )
	    let &l:list = b:indentconsistencycop_save_list
	    unlet b:indentconsistencycop_save_list
	endif
    endif

    if ! empty( matchstr( g:indentconsistencycop_highlighting, '\Cf:\zs\d' ) )
	if exists( 'b:indentconsistencycop_save_foldenable' )
	    let &l:foldenable = b:indentconsistencycop_save_foldenable
	    unlet b:indentconsistencycop_save_foldenable
	endif

	if exists( 'b:indentconsistencycop_save_foldmethod' )
	    let &l:foldmethod = b:indentconsistencycop_save_foldmethod
	    unlet b:indentconsistencycop_save_foldmethod
	endif

	if exists( 'b:indentconsistencycop_save_foldlevel' )
	    let &l:foldlevel = b:indentconsistencycop_save_foldlevel
	    unlet b:indentconsistencycop_save_foldlevel
	endif

	if exists( 'b:indentconsistencycop_save_foldexpr' )
	    let &l:foldexpr = b:indentconsistencycop_save_foldexpr
	    unlet b:indentconsistencycop_save_foldexpr
	endif

	if exists( 'b:indentconsistencycop_lineNumbers' )
	    " Just free the memory here.
	    unlet b:indentconsistencycop_lineNumbers
	endif
    endif
endfunction

function! s:GetInconsistentIndents( startLineNum, endLineNum, correctIndentSetting ) " {{{2
    let l:lineNumbers = []

    let l:lineNum = a:startLineNum
    while l:lineNum <= a:endLineNum
	if ! s:IsLineCorrect( l:lineNum, a:correctIndentSetting )
	    let l:lineNumbers += [ l:lineNum ]
	endif
	let l:lineNum += 1
    endwhile

    return l:lineNumbers
endfunction

function! s:HighlightInconsistentIndents( startLineNum, endLineNum, correctIndentSetting ) " {{{2
    " Patterns for correct tabstops and space indents are easy to come up with.
    " The softtabstops of 1,2,4 are easy, too. The softtabstop indents of 3, 5,
    " 7 are very difficult to express, because you have to consider the number
    " of tabs, too.
    " Negating this match to highlight all incorrect indents plus the possible
    " bad space-tab combinations only makes things worse. Thus, we use the brute
    " approach and examine all lines, and build the pattern with the
    " inconsistent line numbers. (Hoping that this approach scales reasonably
    " well with many inconsistent line numbers.)
    "
    " A search pattern would then look like this:
    "\(\%4l\|\%17l\|\%23l\)\&^\s\+
    "
    " Another benefit of storing the line numbers versus creating a pattern is
    " that this allows different methods of visualization (highlighting,
    " folding, quickfix, ...).
    let l:isEntireBuffer = s:IsEntireBuffer(a:startLineNum, a:endLineNum)
    let l:lineNumbers = s:GetInconsistentIndents( a:startLineNum, a:endLineNum, a:correctIndentSetting )
    if len( l:lineNumbers ) == 0
	" All lines are correct.
	call IndentConsistencyCop#ClearHighlighting()
	let s:perfectIndentSetting = a:correctIndentSetting " Update the consistency rating.
	let s:authoritativeIndentSetting = ''

	" Update report, now that we have found out that the range / buffer has consistent indent.
	call s:ReportConsistencyWithBufferSettingsResult( l:isEntireBuffer, s:IsConsistentWithBufferSettings(a:correctIndentSetting) )	" If different settings have been chosen by the user, this may have resulted in a consistency with buffer settings, too.
	call s:ReportConsistencyResult( l:isEntireBuffer, 1, a:correctIndentSetting )

	call s:EchoUserMessage("No incorrect lines found for setting '" . s:IndentSettingToUserString( a:correctIndentSetting ) . "'!")
    else
	call s:SetHighlighting( l:lineNumbers )
	let s:perfectIndentSetting = ''	" Invalidate the consistency rating.

	" Update report, now that we have found out the range / buffer has inconsistent indent.
	call s:ReportConsistencyResult( l:isEntireBuffer, 0, '' )

	call s:EchoUserMessage( 'Marked ' . len( l:lineNumbers ) . ' incorrect lines. ' )
    endif
endfunction

function! s:QueryIndentSetting() " {{{2
"*******************************************************************************
"* PURPOSE:
"	? What the procedure does (not how).
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"	? Explanation of each argument that isn't obvious.
"* RETURN VALUES:
"   Queried indent setting (e.g. 'spc4'), or empty string if user has canceled.
"*******************************************************************************
    let l:setting = s:Query('Choose the indent setting:', ['&tabstop', '&soft tabstop', 'spa&ces'], 0)
    if empty(l:setting)
	return ''
    elseif l:setting !=? 'tabstop'
	let l:indentValue = s:Query('Choose indent value:', ['&1', '&2', '&3', '&4', '&5', '&6', '&7', '&8'], 0 )
	if empty(l:indentValue)
	    return ''
	endif
	let l:multiplier = str2nr(l:indentValue)
	if l:multiplier < 1 || l:multiplier > 8
	    throw 'ASSERT: Queried indent value out of range: ' . l:indentValue
	endif
    endif

    if l:setting ==? 'tabstop'
	return 'tab'
    elseif l:setting ==? 'soft tabstop'
	return 'sts' . l:multiplier
    elseif l:setting ==? 'spaces'
	return 'spc' . l:multiplier
    else
	throw 'ASSERT: Unhandled l:setting: ' . l:setting
    endif
endfunction
" }}}2
" }}}1

"- reporting functions-----------------------------------------------------{{{1
function! s:InitResults() "{{{2
    if ! exists('b:indentconsistencycop_result')
	let b:indentconsistencycop_result = {}
    endif
endfunction

function! s:ReportIndentSetting( indentSetting ) "{{{2
    if a:indentSetting == 'tab'
	" Internally, there is only one 'tab' indent setting; the actual indent
	" multiplier (as specified by the 'tabstop' setting) isn't important.
	" For reporting, we want to include this information, however.
	return a:indentSetting . &l:tabstop
    elseif a:indentSetting == 'badset'
	" Translate the internal 'badset' to something more meaningful to the
	" user.
	return '???'
    else
	return a:indentSetting
    endif
endfunction

function! s:ReportBufferSettingsConsistency( indentSetting ) "{{{2
"*******************************************************************************
"* PURPOSE:
"	? What the procedure does (not how).
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:indentSetting (optional) indent setting that has been set in the buffer.
"		    If set, it'll be validated against the actual buffer
"		    settings.
"* RETURN VALUES:
"   none
"*******************************************************************************
    let l:indentSetting = s:GetIndentSettingForBufferSettings()
    if ! empty(a:indentSetting) && a:indentSetting != l:indentSetting
	throw 'ASSERT: Passed buffer settings are equal to actual indent settings. '
    endif
    let b:indentconsistencycop_result.bufferSettings = s:ReportIndentSetting(l:indentSetting)
    let b:indentconsistencycop_result.isBufferSettingsConsistent = s:IsBufferSettingsConsistent()
endfunction

function! s:ReportConsistencyWithBufferSettingsResult( isEntireBuffer, isConsistent ) "{{{2
    if a:isEntireBuffer || (! a:isConsistent && s:IsEnoughIndentForSolidAssessment())
	let b:indentconsistencycop_result.isConsistentWithBufferSettings = a:isConsistent
    endif
endfunction

function! s:ReportInconsistentIndentSetting()	"{{{2
    if ! empty( s:perfectIndentSetting ) | throw 'ASSERT: Should be inconsistent when called. ' | endif
    if empty( s:authoritativeIndentSetting )
	" There is a true inconsistency.
	return 'XXX'
    else
	" There is an authoritative indent setting; only some bad mix of spaces
	" and tabs have occured.
	return 'BAD' . s:ReportIndentSetting(s:authoritativeIndentSetting)
    endif
endfunction

function! s:ReportConsistencyResult( isEntireBuffer, isConsistent, consistentIndentSetting ) "{{{2
    call s:InitResults()

    " Only update the buffer result if the entire buffer was checked or if the
    " check of a range yielded a definitive inconsistency.
    if a:isEntireBuffer || (a:isConsistent == 0 && s:IsEnoughIndentForSolidAssessment())
	let b:indentconsistencycop_result.isConsistent = (a:isConsistent != 0)
	let b:indentconsistencycop_result.isDefinite = s:IsEnoughIndentForSolidAssessment()

	if a:isConsistent == 1
	    if ! empty(a:consistentIndentSetting)
		let b:indentconsistencycop_result.indentSetting = s:ReportIndentSetting(a:consistentIndentSetting)
	    endif
	elseif a:isConsistent == 0
	    let b:indentconsistencycop_result.indentSetting = s:ReportInconsistentIndentSetting()
	elseif a:isConsistent == -1
	    let b:indentconsistencycop_result.indentSetting = 'none'
	else
	    throw 'ASSERT: Unhandled a:isConsistent: ' . a:isConsistent
	endif
    endif
    " Update if the entire buffer was checked. Range checks are only allowed to
    " increase this.
    if a:isEntireBuffer || (s:indentMax > get(b:indentconsistencycop_result, 'maxIndent', -1))
	let b:indentconsistencycop_result.maxIndent = s:indentMax
    endif
    if a:isEntireBuffer || (s:indentMin < get(b:indentconsistencycop_result, 'minIndent', 0x7FFFFFFF))
	let b:indentconsistencycop_result.minIndent = s:indentMin
    endif
endfunction
" }}}1

function! s:IndentBufferInconsistencyCop( startLineNum, endLineNum, inconsistentIndentationMessage ) " {{{1
"*******************************************************************************
"* PURPOSE:
"   Reports buffer inconsistency and offers steps to tackle the problem.
"* ASSUMPTIONS / PRECONDITIONS:
"   s:occurrences dictionary; key: indent setting; value: number of
"	lines that have that indent setting
"   s:ratings dictionary; key: indent setting; value: percentage
"	rating (100: checked range is consistent; < 100: inconsistent.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:startLineNum, a:endLineNum: range in the current buffer that is to be
"	checked.
"   a:inconsistentIndentationMessage: user message about the inconsistent
"	indentation and possible conflicting indent settings
"* RETURN VALUES:
"   none
"*******************************************************************************
    let l:action = s:Query(a:inconsistentIndentationMessage, ['&Ignore', '&Highlight wrong indents...'], 1)
    let b:indentconsistencycop_result.isIgnore = (l:action ==# 'Ignore')
    if empty(l:action) || l:action ==# 'Ignore'
	" User chose to ignore the inconsistencies.
	call s:EchoUserMessage('Be careful when modifying the inconsistent indents! ')
    elseif l:action =~? '^Highlight'
	let l:bufferIndentSetting = s:GetIndentSettingForBufferSettings()
	" The buffer indent settings may be 'badset', which cannot be
	" highlighted. So we need to suppress this option if it is bad.
	let l:isBadBufferIndent = (s:IsBadIndentSetting( l:bufferIndentSetting ) ? 1 : 0)

	let l:isBestGuessEqualToBufferIndent = 1 " Suppress best guess option if no guess available.
	if ! empty( s:ratings )
	    let l:bestGuessIndentSetting = s:GetBestRatedIndentSetting()
	    let l:isBestGuessEqualToBufferIndent = (l:bestGuessIndentSetting == l:bufferIndentSetting)
	endif

	let l:highlightMessage = 'What kind of inconsistent indents do you want to highlight?'
	if l:isBestGuessEqualToBufferIndent && l:isBadBufferIndent
	    let l:highlightChoices = []
	elseif l:isBestGuessEqualToBufferIndent && ! l:isBadBufferIndent
	    let l:highlightChoices = ['Not &buffer settings / best guess (' . l:bufferIndentSetting . ')']
	elseif ! l:isBestGuessEqualToBufferIndent && l:isBadBufferIndent
	    let l:highlightChoices = ['Not best &guess (' . l:bestGuessIndentSetting . ')']
	else
	    let l:highlightChoices = ['Not &buffer settings (' . l:bufferIndentSetting . ')', 'Not best &guess (' . l:bestGuessIndentSetting . ')']
	endif
	call add(l:highlightChoices, 'Not &chosen setting...')
	if s:GetKeyedValue( s:occurrences, 'badmix' ) + s:GetKeyedValue( s:occurrences, 'badsts' ) > 0
	    call add(l:highlightChoices, '&Illegal indents only')
	endif

	let l:highlightAction = s:Query(l:highlightMessage, l:highlightChoices, 1)
	if empty(l:highlightAction)
	    " User canceled.
	    call s:EchoUserMessage('Be careful when modifying the inconsistent indents! ')
	elseif l:highlightAction =~? '\<buffer settings\>'
	    call s:HighlightInconsistentIndents( a:startLineNum, a:endLineNum, l:bufferIndentSetting )
	elseif l:highlightAction =~? '\<best guess\>'
	    call s:HighlightInconsistentIndents( a:startLineNum, a:endLineNum, l:bestGuessIndentSetting )
	elseif l:highlightAction =~? '\<chosen setting\>'
	    let l:chosenIndentSetting = s:QueryIndentSetting()
	    if ! empty( l:chosenIndentSetting )
		call s:HighlightInconsistentIndents( a:startLineNum, a:endLineNum, l:chosenIndentSetting )
	    endif
	elseif l:highlightAction ==? 'Illegal indents only'
	    call s:HighlightInconsistentIndents( a:startLineNum, a:endLineNum, 'notbad' )
	else
	    throw 'ASSERT: Unhandled l:highlightAction: ' . l:highlightAction
	endif
    endif
endfunction

function! s:IsBufferConsistentWithBufferSettings( startLineNum, endLineNum ) " {{{1
"*******************************************************************************
"* PURPOSE:
"   Examines the buffer settings to possibly turn around the verdict of
"   "inconsistent indent".
"   When the maximum indent of the buffer is not enough to be sure of the indent
"   settings (i.e. differentiating between soft tabstops and spaces), an
"   inconsistent indent is reported, even though it is much more likely that the
"   indent is consistent with "soft tabstop n", but that wasn't recognized
"   because of the small indents used in the file.
"   The normal process flow of the IndentConsistencyCop is: First check for
"   consistent indents, and only when they are consistent indeed, bother to
"   (optionally) check the buffer settings, too.
"   This function bypasses the normal process flow by peeking to the buffer
"   settings to help solve the uncertainty of its judgement of buffers with
"   small maximum indents.
"* ASSUMPTIONS / PRECONDITIONS:
"   A potential buffer inconsistency has been detected (s:CheckBufferConsistency() == 0).
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:startLineNum, a:endLineNum: range in the current buffer that is to be
"	checked.
"* RETURN VALUES:
"   1 if the uncertainty of small maximum indents has been resolved to
"	"consistent" by examining the buffer settings.
"   0 if the verdict is still "inconsistent".
"*******************************************************************************
    let l:bufferIndentSetting = s:GetIndentSettingForBufferSettings()
    if ! s:IsBadIndentSetting( l:bufferIndentSetting )
	let l:lineNumbers = s:GetInconsistentIndents( a:startLineNum, a:endLineNum, l:bufferIndentSetting )
	if len( l:lineNumbers ) == 0
	    " All lines conform to the buffer indent setting, nothing is
	    " inconsistent.
	    return 1
	endif
	" Inconsistent lines found.
    endif
    " The buffer settings are of no help, because they are inconsistent,
    " too.

    return 0
endfunction

function! IndentConsistencyCop#IndentConsistencyCop( startLineNum, endLineNum, isBufferSettingsCheck ) " {{{1
"*******************************************************************************
"* PURPOSE:
"   Triggers the indent consistency check and presents the results to the user.
"* ASSUMPTIONS / PRECONDITIONS:
"	? List of any external variable, control, or other element whose state affects this procedure.
"* EFFECTS / POSTCONDITIONS:
"	? List of the procedure's effect on each external variable, control, or other element.
"* INPUTS:
"   a:startLineNum, a:endLineNum: range in the current buffer that is to be
"	checked.
"   a:isBufferSettingsCheck: flag whether consistency with the buffer
"	settings should also be checked.
"* RETURN VALUES:
"   none
"*******************************************************************************
    let l:isEntireBuffer = s:IsEntireBuffer(a:startLineNum, a:endLineNum)
    let l:lineCnt = a:endLineNum - a:startLineNum + 1

    call s:EchoStartupMessage( l:lineCnt, l:isEntireBuffer )

    let s:occurrences = {}
    let s:ratings = {}
    let [l:isConsistent, l:hadPerfectOrAuthoritativeRating] = s:CheckBufferConsistency( a:startLineNum, a:endLineNum )
    call s:ReportConsistencyResult( l:isEntireBuffer, l:isConsistent, '' )
    call s:ReportBufferSettingsConsistency('')

    if l:isConsistent == -1
	call IndentConsistencyCop#ClearHighlighting()
	call s:UnindentedBufferConsistencyCop( l:isEntireBuffer, a:isBufferSettingsCheck )
	call s:ReportConsistencyWithBufferSettingsResult( l:isEntireBuffer, 1 )
    elseif l:isConsistent == 0
	if l:hadPerfectOrAuthoritativeRating || ! s:IsEnoughIndentForSolidAssessment()
	    let l:isConsistent = s:IsBufferConsistentWithBufferSettings( a:startLineNum, a:endLineNum )
	endif
	call s:ReportConsistencyWithBufferSettingsResult( l:isEntireBuffer, l:isConsistent )
	if l:isConsistent
	    call IndentConsistencyCop#ClearHighlighting()

	    let l:consistentIndentSetting = s:GetIndentSettingForBufferSettings()
	    call s:ReportConsistencyResult( l:isEntireBuffer, l:isConsistent, l:consistentIndentSetting )	" Update report, now that the verdict has been turned around and we have the consistent indent setting.
	    call s:IndentBufferConsistencyCop( a:startLineNum, a:endLineNum, l:consistentIndentSetting, 0 ) " Pass isBufferSettingsCheck = 0 here (though a:isBufferSettingsCheck == 1) because we've already ensured that the buffer is consistent with the buffer settings, and just want the function to print the user message.
	else
	    let l:inconsistentIndentationMessage = 'Found ' . ( s:IsEnoughIndentForSolidAssessment() ? '' : 'potentially ')
	    let l:inconsistentIndentationMessage .= 'inconsistent indentation in this ' . s:GetScopeUserString(l:isEntireBuffer) . '; generated from these conflicting settings: '
	    let l:inconsistentIndentationMessage .= s:RatingsToUserString( l:lineCnt )
	    let l:inconsistentIndentationMessage .= s:GetInsufficientIndentUserMessage()
	    call s:IndentBufferInconsistencyCop( a:startLineNum, a:endLineNum, l:inconsistentIndentationMessage )
	endif
    elseif l:isConsistent == 1
	call IndentConsistencyCop#ClearHighlighting()

	call s:ReportConsistencyResult( l:isEntireBuffer, l:isConsistent, s:perfectIndentSetting )	" Update report, now that we have the consistent (perfect) indent setting.
	call s:IndentBufferConsistencyCop( a:startLineNum, a:endLineNum, s:perfectIndentSetting, a:isBufferSettingsCheck )
    else
	throw 'ASSERT: Unhandled l:isConsistent: ' . l:isConsistent
    endif
"****D echo 'Consistent   ? ' . l:isConsistent
"****D echo 'Occurrences:   ' . string( s:occurrences )
"****D echo 'Nrm. Ratings:  ' . string( s:ratings )

    " Cleanup remaining dictionaries with script-scope to free memory.
    let s:occurrences = {}
    let s:ratings = {}
endfunction

" }}}1

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=marker :

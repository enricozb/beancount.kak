hook global BufCreate (.*/)?(.*\.beancount) %{
  set-option buffer filetype beancount
}

hook global WinSetOption filetype=beancount %{
  require-module beancount
}

hook -group beancount-highlight global WinSetOption filetype=beancount %{
  add-highlighter window/beancount ref beancount

  hook -once -always window WinSetOption filetype=.* %{
    remove-highlighter window/beancount
    unmap window normal <ret>
  }

  declare-option -hidden str-list beancount_accounts %sh{
    rg \
      --no-filename \
      --only-matching \
      --glob '*.beancount' \
      '(Assets|Liabilities|Equity|Income|Expenses)[:\w-]+' \
      "$(git rev-parse --show-toplevel)" \
    | sort | uniq
  }

  map buffer normal <ret> ': complete-transaction<ret>'
}

provide-module beancount %{
  add-highlighter shared/beancount regions

  add-highlighter shared/beancount/comment region ';' '$' fill comment

  add-highlighter shared/beancount/stack region '(pop|push)tag' $ group
  add-highlighter shared/beancount/stack/keyword regex '(pop|push)tag' 0:keyword
  add-highlighter shared/beancount/stack/tag regex '#[\w-]+' 0:attribute

  # directives start at dates (YYYY-MM-DD) and end with the newline
  add-highlighter shared/beancount/directive region ^\d{4}-\d{2}-\d{2} $ regions
  add-highlighter shared/beancount/directive/comment region ';' '$' fill comment
  add-highlighter shared/beancount/directive/string region '"' '"' fill string
  add-highlighter shared/beancount/directive/code default-region group
  add-highlighter shared/beancount/directive/code/date regex ^\d{4}-\d{2}-\d{2} 0:type
  add-highlighter shared/beancount/directive/code/keyword regex '(open|close|balance|pad|\*)' 0:operator
  add-highlighter shared/beancount/directive/code/incomplete regex '!' 0:error
  add-highlighter shared/beancount/directive/code/tag regex '#[\w-]+' 0:attribute
  add-highlighter shared/beancount/directive/code/account regex '((Assets|Liabilities|Equity|Income|Expenses)[:\w-]+)' 0:identifier
  add-highlighter shared/beancount/directive/code/commodity regex '(?<=\s)[A-Z][A-Z._-]+(?=\s)' 0:value
  add-highlighter shared/beancount/directive/code/value regex '(?<=\h)-?\d+(\.\d+)?' 0:value

  # postings are lines indented with two spaces
  add-highlighter shared/beancount/posting region '^  ' $ regions
  add-highlighter shared/beancount/posting/comment region ';' '$' fill comment
  add-highlighter shared/beancount/posting/code default-region group
  add-highlighter shared/beancount/posting/code/account regex '((Assets|Liabilities|Equity|Income|Expenses)[:\w-]+)' 0:identifier
  add-highlighter shared/beancount/posting/code/commodity regex '(?<=\s)[A-Z]+(?=\s)' 0:value
  add-highlighter shared/beancount/posting/code/value regex '(?<=\h)-?\d+(\.\d+)?' 0:value

  define-command bofa-comments -docstring "format bofa postings to comments" %{
    # prepend `;` to every posting
    execute-keys -draft 's\d{2}/\d{2}\n\d{2}<ret><a-;>i; <esc>'
    # remove newlines within a posting
    execute-keys -draft 's^[^;]<ret>i<backspace> <esc>,'
  }

  define-command chase-comments -docstring "format chase postings to comments" %{
    # prepend `;` to every posting
    execute-keys -draft 's\d{2}/\d{2}<ret><a-;>i; <esc>'
    # remove newlines within a posting
    try %{
      execute-keys -draft 's^[^;]<ret>i<backspace> <esc>,'
    }
  }

  define-command complete-transaction -docstring "next step in transaction completion" %{
    # select the current line
    execute-keys ';xH'

    try %{
      # check if this is a commented line
      execute-keys -draft 's^;<ret>'

      # if so, create a new directive, with the previous transaction's date,
      # or the current date if this is the first transaction
      try %{
        execute-keys -draft 'Z<a-/>^\d{4}-\d{2}-\d{2}<ret>yzo<esc>P'
        execute-keys 'jH<a-;>'
      } catch %{
        execute-keys "o%sh{date --iso}<esc>h4H<a-;>"
      }

    } catch %{
      # otherwise, we're already in a directive and must infer the transaction completion state
      execute-keys %sh{
        # date -> add directive
        if expr match "$kak_selection" '[[:digit:]-]\+$'; then
          printf 'A *<esc>h'

        # date, directive -> add creditor/debtor
        elif expr match "$kak_selection" '[[:digit:]-]\+ [!*]$'; then
          printf 'A ""<esc>hi'

        # date, directive, creditor/debtor -> add memo
        elif expr match "$kak_selection" '[[:digit:]-]\+ [!*] "[^"]*"$'; then
          printf 'A ""<esc>h'

        # date, directive, creditor/debtor, empty memo -> remove memo and add account
        elif expr match "$kak_selection" '[[:digit:]-]\+ [!*] "[^"]*" ""$'; then
          printf ';HHd'
          printf ': complete-first-posting<ret>'

        # date, directive, creditor/debtor, populated memo -> add account
        elif expr match "$kak_selection" '[[:digit:]-]\+ [!*] "[^"]*" "[^"]*"$'; then
          printf ': complete-first-posting<ret>'

        # empty posting -> add account
        elif expr match "$kak_selection" '  $'; then
          printf 'l: complete-account<ret>'

        # explicit posting -> add account
        elif expr match "$kak_selection" '  [[:alpha:]:-]\+ *[[:digit:].-]\+ USD$'; then
          printf 'o  <esc>'
          printf ': complete-account<ret>'

        fi
      }
    }
  }

  define-command complete-account -docstring "prompt for an account with completions" %{
    prompt 'account: ' -shell-script-candidates %{ printf "$kak_opt_beancount_accounts" } %{
      execute-keys "i%val{text}<esc>"
    }
  }

  define-command complete-first-posting -docstring "completes the first posting in a transaction" %{
    # create the first posting using the previous explicit posting if one exists
    try %{
      execute-keys "Z<a-/>^  [^ ]+ +[-\d.]+ +[A-Z]+$<ret>yzo<esc>P"
      execute-keys "s[\d.]+<ret>c"
    } catch %{
      complete-account
    }
  }
}

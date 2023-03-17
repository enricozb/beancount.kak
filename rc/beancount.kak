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

  declare-option -hidden str beancount_account

  declare-option -hidden str-list beancount_accounts %sh{
    rg \
      --no-filename \
      --only-matching \
      --glob '*.beancount' \
      '(Assets|Liabilities|Equity|Income|Expenses)[:\w-]+' \
      "$(git rev-parse --show-toplevel)" \
    | sort | uniq
  }

  map buffer normal <ret> ': beancount-complete<ret>'
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
  add-highlighter shared/beancount/posting/code/commodity regex '(?<=\s)[A-Z][A-Z._-]+(?=\s)' 0:value
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

  define-command beancount-complete -docstring "autocomplete an account or transaction directive" %{
    execute-keys ';x'

    try %{
      # in a comment
      execute-keys 's^;<ret>'
      complete-transaction
    } catch %{
      # in a posting
      execute-keys 's^  <ret>o  <esc>'
      complete-account
    } catch %{
      fail 'not a comment nor a posting'
    }
  }

  define-command complete-transaction -docstring "complete the transaction directive" %{
    # duplicate the comment line
    execute-keys 'xyp'

    # try to remove duplicate date
    try %{
      execute-keys '1s(\d{2}/\d{2} )\d{2}/\d{2}<ret>d'
    }

    # add the date
    execute-keys "ghddi%sh{date +%Y}-<esc>llr-4l"

    # add the rest of the transaction
    execute-keys 'i* ""<ret>  <esc>'

    # remove everything but price
    execute-keys 'x1s  (.*) [^\h]+<ret>d'

    # remove commas or dollar signs (if any) & append USD
    try %{ execute-keys -draft 'xs(,|\$)<ret>d' }

    # add negative sign if one doesn't exist
    # remove it if it does
    try %{
      execute-keys -draft 'xs-<ret>d'
    } catch %{
      execute-keys -draft 'x1s (\d)<ret>i-<esc>'
    }
    execute-keys -draft 'A USD<esc>'

    complete-first-account
  }

  define-command complete-account -docstring "prompt for an account with completions" %{
    prompt 'account: ' -shell-script-candidates %{ printf "$kak_opt_beancount_accounts" } %{
      execute-keys "i%val{text}<esc>"
    }
  }

  define-command complete-first-account -docstring "completes the first posting in a transaction" %{
    # create the first posting using the previous explicit posting if one exists
    try %{
      evaluate-commands -draft %{
        execute-keys 'gk/^\d{4}[^\n]+\n  [A-Z]<ret>t '
        set-option buffer beancount_account %val{selection}
      }

      execute-keys "i%opt{beancount_account}<esc>"
    } catch %{
      complete-account
    }
  }
}

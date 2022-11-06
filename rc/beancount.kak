hook global BufCreate (.*/)?(.*\.beancount) %{
  set-option buffer filetype beancount
}

hook global WinSetOption filetype=beancount %{
  require-module beancount
}

hook -group beancount-highlight global WinSetOption filetype=beancount %{
  add-highlighter window/beancount ref beancount
  hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/beancount }
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
  add-highlighter shared/beancount/directive/code/keyword regex '(open|close|balance|\*)' 0:operator
  add-highlighter shared/beancount/directive/code/incomplete regex '!' 0:error
  add-highlighter shared/beancount/directive/code/tag regex '#[\w-]+' 0:attribute
  add-highlighter shared/beancount/directive/code/commodity regex '(?<=\s)[A-Z]+(?=\s)' 0:value
  add-highlighter shared/beancount/directive/code/account regex '((Assets|Liabilities|Equity|Income|Expenses)[:\w-]+)' 0:identifier

  # postings are lines indented with two spaces
  add-highlighter shared/beancount/posting region '^  ' $ regions
  add-highlighter shared/beancount/posting/comment region ';' '$' fill comment
  add-highlighter shared/beancount/posting/code default-region group
  add-highlighter shared/beancount/posting/code/account regex '((Assets|Liabilities|Equity|Income|Expenses)[:\w-]+)' 0:identifier
  add-highlighter shared/beancount/posting/code/commodity regex '(?<=\s)[A-Z]+(?=\s)' 0:value
  add-highlighter shared/beancount/posting/code/value regex '-?\d+(\.\d+)?' 0:value
}

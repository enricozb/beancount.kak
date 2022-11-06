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

  add-highlighter shared/beancount/comment region '(^|\h)\K;' $ fill comment

  add-highlighter shared/beancount/stack region '(pop|push)tag' $ group
  add-highlighter shared/beancount/stack/keyword regex '(pop|push)tag' 0:keyword
  add-highlighter shared/beancount/stack/tag regex '#[\w-]+' 0:attribute

  # transactions start at dates (YYYY-MM-DD) and end at blank lines (^$)
  add-highlighter shared/beancount/transaction region '^\d{4}-\d{2}-\d{2}' '^$' group
  add-highlighter shared/beancount/transaction/comment regex ';[^\n]*$' 0:comment
  add-highlighter shared/beancount/transaction/tag regex '#[\w-]+' 0:attribute
  add-highlighter shared/beancount/transaction/date regex ^\d{4}-\d{2}-\d{2} 0:type
  add-highlighter shared/beancount/transaction/string regex '"[^"]*"' 0:string
  add-highlighter shared/beancount/transaction/incomplete regex '!' 0:error
  add-highlighter shared/beancount/transaction/complete regex '\*' 0:operator
  add-highlighter shared/beancount/transaction/posting regex '^  ([a-zA-Z0-9-:]*)(\h+[-\d.]+ \w+)?' 1:identifier 2:value

}

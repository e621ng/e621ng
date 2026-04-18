import DTextFormatter from "@/components/dtext_formatter";

$(() => {
  for (const one of $(".dtext-formatter")) {
    new DTextFormatter($(one));
  }
});

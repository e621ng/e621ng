import DTextFormatter from "@/components/DTextFormatter";

$(() => {
  for (const one of $(".dtext-formatter")) {
    new DTextFormatter($(one));
  }
});

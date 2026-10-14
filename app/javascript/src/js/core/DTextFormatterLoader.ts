import DTextFormatter from "@/components/DTextFormatter";

$(() => {
  for (const one of $<HTMLDivElement>("div.dtext-formatter")) {
    new DTextFormatter($(one));
  }
});

// users # show

import E621Type from "@/interfaces/E621";
declare const E621: E621Type;

import "@/components/tabs";
import "@/pages/users/show/staff_notes";
import "@/pages/users/show/users";

E621.Registry.register("v-users-show");

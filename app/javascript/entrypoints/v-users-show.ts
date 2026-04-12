// users # show

import E621Type from "../src/js/interfaces/E621";
declare const E621: E621Type;

import "../src/js/components/tabs";
import "../src/js/pages/users/show/staff_notes";
import "../src/js/pages/users/show/users";

E621.Registry.register("v_users_show");

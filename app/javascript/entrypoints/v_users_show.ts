// users # show

import E621Type from "@/interfaces/E621";
declare const E621: E621Type;

import "@/components/tabs";
import "@/pages/users/show/ProfileCard";
import "@/pages/users/show/ProfileReadMore";
import "@/pages/users/show/ProfileSection";
import "@/pages/users/show/staff_notes";

E621.Registry.register("v_users_show");

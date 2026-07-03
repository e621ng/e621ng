// oauth-applications

import E621Type from "@/interfaces/E621";
declare const E621: E621Type;

import "@/pages/oauth_applications/redirect_uri_list";
import "@/pages/oauth_applications/credential_select";

E621.Registry.register("v_oauth-applications");

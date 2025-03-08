-- for old apiv10
-- name = "Wiki.gg Automated"
-- description = "Scripts to help generating wiki.gg by reading content straight from the game."
-- author = "gibberish"
-- version = "dev"
-- api_version = 10

-- dst_compatible = false
-- forge_compatible = false
-- gorge_compatible = false
-- dont_starve_compatible = false
-- reign_of_giants_compatible = false
-- shipwrecked_compatible = false
-- rotwood_compatible = true

-- client_only_mod = true
-- all_clients_require_mod = false

-- for apiv1
return {
    name = "Wiki.gg Automated",
    description = "Scripts to help generating wiki.gg by reading content straight from the game.",
    author = "gibberish",
    version = "dev",
    mod_version = "dev",
    api_version = 1,

    mod_type = "gameplay",
    supports_mode = {
		rotwood = true,
	},

    client_only_mod = true,
    all_clients_require_mod = false,
}
